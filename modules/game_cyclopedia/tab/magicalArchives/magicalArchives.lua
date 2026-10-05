local UI = nil

local ARCHIVE_PROFILE = 'Default'
local ARCHIVE_FILTER_VOCATION_ANY = 0

local archiveState = {
    filters = {},
    learned = nil,
    search = '',
    detailTab = 'combat'
}

MagicalArchive = MagicalArchive or {}

local archiveFilterDefaults = {
    currentVocation = false, currentLevel = false, learned = false,
    druid = true, knight = true, paladin = true, sorcerer = true, monk = true,
    attack = true, healing = true, support = true,
    premium = true, free = true, rune = true, instant = true
}
local archiveFilterOptions = {
    {key = 'currentVocation', text = 'Character Vocation'},
    {key = 'currentLevel', text = 'Character Level'},
    {key = 'learned', text = 'Learnt Spells'},
    {},
    {key = 'druid', text = 'Druid', vocation = 2},
    {key = 'knight', text = 'Knight', vocation = 4},
    {key = 'paladin', text = 'Paladin', vocation = 3},
    {key = 'sorcerer', text = 'Sorcerer', vocation = 1},
    {key = 'monk', text = 'Monk', vocation = 9},
    {key = 'allVocations', text = 'All Vocations', members = {'druid', 'knight', 'paladin', 'sorcerer', 'monk'}},
    {},
    {key = 'attack', text = 'Attack', group = 1},
    {key = 'healing', text = 'Healing', group = 2},
    {key = 'support', text = 'Support', group = 3},
    {key = 'allGroups', text = 'All Spell Groups', members = {'attack', 'healing', 'support'}},
    {},
    {key = 'premium', text = 'Premium Account'},
    {key = 'free', text = 'Free Account'},
    {},
    {key = 'rune', text = 'Rune Spells'},
    {key = 'instant', text = 'Instant Spells'}
}
local archiveFilterCloseEvent
local archiveSearchEvent
local archiveUpdatingFilters = false


local function archiveCancelSearch()
    if archiveSearchEvent then removeEvent(archiveSearchEvent); archiveSearchEvent = nil end
end

local function archiveContains(list, value)
    if not list then
        return false
    end
    for i = 1, #list do
        if list[i] == value then
            return true
        end
    end
    return false
end

-- promoted counterpart of a base vocation (server ids): 1-4 -> 5-8, Monk 9 -> Exalted Monk 10
local function archivePromotedId(vocationId)
    if vocationId >= 1 and vocationId <= 4 then
        return vocationId + 4
    end
    if vocationId == 9 then
        return 10
    end
    return nil
end

function MagicalArchive.buildSpellNames(spellInfo)
    local names = {}
    for name in pairs(spellInfo) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function MagicalArchive.matchesVocation(info, vocationId)
    if vocationId == ARCHIVE_FILTER_VOCATION_ANY then
        return true
    end
    return archiveContains(info.vocations, vocationId) or
        archiveContains(info.vocations, archivePromotedId(vocationId))
end

function MagicalArchive.matchesSearch(name, info, searchText)
    if not searchText or searchText == '' then
        return true
    end
    local needle = searchText:lower()
    if name:lower():find(needle, 1, true) then
        return true
    end
    return (info.words or ''):lower():find(needle, 1, true) ~= nil
end

-- promoted vocations are hidden when their base vocation is also present ("Sorcerer" implies "Master Sorcerer")
function MagicalArchive.formatVocations(vocations, vocationNames)
    vocationNames = vocationNames or VocationNames
    local baseOf = { [5] = 1, [6] = 2, [7] = 3, [8] = 4, [10] = 9 }
    local result = ''
    for i = 1, #vocations do
        local vocationId = vocations[i]
        local base = baseOf[vocationId]
        if not base or not archiveContains(vocations, base) then
            result = result .. (result:len() == 0 and '' or ', ') .. (vocationNames[vocationId] or '?')
        end
    end
    return result
end

function MagicalArchive.formatGroupAndCooldown(info, spellGroups)
    spellGroups = spellGroups or SpellGroups
    local cooldown = (info.exhaustion / 1000) .. 's'
    local group = ''
    for groupId, groupName in ipairs(spellGroups) do
        if info.group[groupId] then
            group = group .. (group:len() == 0 and '' or ' / ') .. groupName
            cooldown = cooldown .. ' / ' .. (info.group[groupId] / 1000) .. 's'
        end
    end
    return group, cooldown
end

local function archiveSetVocationIcons(panel, vocations, topMargin)
    panel:destroyChildren()
    local count = 0
    for index, vocationId in ipairs({4, 3, 1, 2, 9}) do
        if archiveContains(vocations, vocationId) or
            archiveContains(vocations, archivePromotedId(vocationId)) then
            local icon = g_ui.createWidget('ArchiveVocationIcon', panel)
            icon:setImageClip(((index - 1) * 9) .. ' 0 9 9')
            icon:setMarginLeft(count * 14)
            icon:setMarginTop(topMargin or 2)
            icon:setTooltip(VocationNames[vocationId])
            count = count + 1
        end
    end
    panel:setWidth(math.max(0, count * 14 - 5))
end

local function archiveSetHeaderDetails(info, isRune)
    local header = UI.spellAndRune.DetailPanel.HeaderDetails
    archiveSetVocationIcons(header.Indicators.Vocations, not isRune and info.vocations or {})
    header.Indicators.Premium:setVisible(info.premium)
    local width = header.Indicators.Vocations:getWidth()
    if info.premium then
        width = width + (width > 0 and 5 or 0) + 19
    end
    header.Indicators:setWidth(width)
    header.Restriction:setText(not isRune and tr('Level %s', info.level) or '')
    header:setWidth(math.max(width, header.Restriction:getTextSize().width))
    header.Restriction:setWidth(header:getWidth())
end

local function archiveSetCombatStats(info, isRune)
    local panel = UI.spellAndRune.DetailPanel.DetailRows
    local usage = info
    if isRune then
        usage = nil
        for _, rune in pairs(SpellRunesData) do
            if rune.id == info.id then
                if usage and (usage.group ~= rune.group or usage.exhaustion ~= rune.exhaustion) then
                    usage = nil
                    break
                end
                usage = rune
            end
        end
    end
    local groups, cooldowns = {}, {}
    if usage then
        local groupIds = Spells.getGroupIds(usage)
        table.sort(groupIds)
        for _, groupId in ipairs(groupIds) do
            table.insert(groups, SpellGroups[groupId])
            local cooldown = type(usage.group) == 'table' and usage.group[groupId] or usage.exhaustion
            table.insert(cooldowns, (cooldown / 1000) .. 's')
        end
    end
    local mana = '-'
    if not isRune and (info.mana > 0 or info.soul > 0) then
        mana = tostring(info.mana) .. (info.soul > 0 and (' / ' .. info.soul) or '')
    end
    panel.RowMana.caption:setText(not isRune and info.soul > 0 and tr('Mana / SP') or tr('Mana'))
    local values = {
        RowMana = mana,
        RowGroup = #groups > 0 and table.concat(groups, ' / ') or '-',
        RowCooldown = usage and (usage.exhaustion / 1000) .. 's' or '-',
        RowGroupCooldown = #cooldowns > 0 and table.concat(cooldowns, ' / ') or '-',
        RowMagicType = info.magicType or '-',
        -- The local catalog has no base power, scaling or preview range.
        RowBasePower = '-',
        RowScaling = '-',
        RowRange = '-'
    }
    for rowId, value in pairs(values) do
        panel[rowId].value:setText(value)
    end
end

local function archiveLayoutStatGrid(panel, leftRows, rightRows)
    panel.onGeometryChange = function()
        local previous = 0
        for i = 1, 4 do
            local edge = math.floor(panel:getWidth() * i / 4 + 0.5)
            local column = panel['Column' .. i]
            column:setMarginLeft(previous)
            column:setWidth(edge - previous)
            previous = edge
        end
        local leftValue = math.floor(panel:getWidth() / 4 + 0.5) + 5
        local rightValue = math.floor(panel:getWidth() * 3 / 4 + 0.5) -
            math.floor(panel:getWidth() / 2 + 0.5) + 5
        for _, rowId in ipairs(leftRows) do
            panel[rowId].value:setMarginLeft(leftValue)
        end
        for _, rowId in ipairs(rightRows) do
            panel[rowId].value:setMarginLeft(rightValue)
        end
    end
    panel.onGeometryChange()
end

local function archiveSelectDetailTab(tab)
    local detail = UI.spellAndRune.DetailPanel
    archiveState.detailTab = tab
    detail.DetailTabs.CombatTab:setOn(tab == 'combat')
    detail.DetailTabs.AdditionalTab:setOn(tab == 'additional')
    detail.DetailTabs.RuneTab:setOn(tab == 'rune')
    detail.DetailRows:setVisible(tab == 'combat')
    detail.AdditionalSource:setVisible(tab == 'additional')
    detail.AdditionalFrame:setVisible(tab == 'additional')
    detail.AdditionalPanel:setVisible(tab == 'additional')
    detail.DescriptionScrollBar:setVisible(tab == 'additional')
    detail.RunePanel:setVisible(tab == 'rune')
end

local function archiveSelectSpell(widget)
    local name = widget and (widget.spellName or widget:getId())
    local info = name and SpellInfo[ARCHIVE_PROFILE][name]
    local detail = UI.spellAndRune.DetailPanel
    UI.spellAndRune.PlaceholderLabel:setVisible(not info)
    detail:setVisible(info ~= nil)
    local isRune = info and Spells.isRuneSpell(info.id) or false
    detail.DetailTabs.RuneTab:setVisible(isRune)
    if not isRune and archiveState.detailTab == 'rune' then
        archiveSelectDetailTab('combat')
    end
    if not info then
        return
    end

    local iconId = tonumber(info.clientId)
    if iconId then
        detail.SpellIcon:setImageSource(SpelllistSettings[ARCHIVE_PROFILE].iconFile)
        detail.SpellIcon:setImageClip(Spells.getImageClip(iconId, ARCHIVE_PROFILE))
    end

    local list = widget:getParent()
    for _, row in ipairs(list:getChildren()) do
        row.caption:setColor(row == widget and '#f4f4f4' or '#c0c0c0')
    end
    addEvent(function()
        if not list:isDestroyed() and list:getFocusedChild() == widget then
            list:getLayout():update()
            list:updateScrollBars()
            list:ensureChildVisible(widget)
        end
    end)

    archiveSetHeaderDetails(info, isRune)
    detail.NameLabel:setText(name)
    detail.FormulaLabel:setText(info.words)
    detail.AdditionalPanel.Description:setText(info.description or '')
    detail.DescriptionScrollBar:setValue(0)

    archiveSetCombatStats(info, isRune)
    local group = MagicalArchive.formatGroupAndCooldown(info)
    if isRune then
        local groupCooldowns = {}
        for groupId in ipairs(SpellGroups) do
            if info.group[groupId] then
                table.insert(groupCooldowns, (info.group[groupId] / 1000) .. 's')
            end
        end
        local values = {
            RowMana = info.mana .. ' / ' .. info.soul,
            RowGroup = group,
            RowLevel = tr('Level %s', info.level),
            RowAmount = info.runeAmount or '-',
            RowCooldown = (info.exhaustion / 1000) .. 's',
            RowGroupCooldown = table.concat(groupCooldowns, ' / '),
            RowVocation = ''
        }
        for rowId, value in pairs(values) do
            detail.RunePanel[rowId].value:setText(value)
        end
        archiveSetVocationIcons(detail.RunePanel.RowVocation.Vocations, info.vocations, 0)
    end
end

local function archiveMatchesFilters(info)
    local filters = archiveState.filters
    local player = g_game.getLocalPlayer()
    if filters.currentLevel and (not player or info.level > player:getLevel()) then
        return false
    end
    if filters.currentVocation and (not player or not MagicalArchive.matchesVocation(info,
        modules.game_actionbar.translateVocation(player:getVocation()))) then
        return false
    end
    if filters.learned and not archiveState.learned[tostring(info.id)] then
        return false
    end
    local allVocations, vocationMatch, groupMatch = true, false, false
    for _, option in ipairs(archiveFilterOptions) do
        if option.vocation then
            allVocations = allVocations and filters[option.key]
            vocationMatch = vocationMatch or filters[option.key] and MagicalArchive.matchesVocation(info, option.vocation)
        elseif option.group then
            groupMatch = groupMatch or filters[option.key] and info.group[option.group] ~= nil
        end
    end
    if not allVocations and not vocationMatch or not groupMatch then
        return false
    end
    if info.premium and not filters.premium or not info.premium and not filters.free then
        return false
    end
    local rune = Spells.isRuneSpell(info.id)
    return rune and filters.rune or not rune and filters.instant
end

local function archiveFitSpellName(label)
    label:setTextOverflowLength(0)
    label:setTextOverflowCharacter(string.char(133))
    local length = #label:getText()
    while label:getTextSize().width > label:getWidth() and length > 1 do
        length = length - 1
        label:setTextOverflowLength(length)
    end
end

function MagicalArchive.refreshAvailability()
    if not UI or UI:isDestroyed() then return end
    local actionbar = modules.game_actionbar
    local online = g_game.isOnline()
    for _, row in ipairs(UI.InformationBase.selectSpell.SpellListBase.questList:getChildren()) do
        local info = SpellInfo[ARCHIVE_PROFILE][row:getId()]
        -- Rune entries describe conjuration, not the requirements for using the rune.
        local unavailable = online and not Spells.isRuneSpell(info.id) and actionbar and
            actionbar.playerCanUseSpell(info) == false
        row.unavailable:setVisible(not not unavailable)
    end
end

local function archiveRebuildList()
    local list = UI.InformationBase.selectSpell.SpellListBase.questList
    local focusedChild = list:getFocusedChild()
    local selectedName = focusedChild and focusedChild:getId()
    local detailTab = archiveState.detailTab
    archiveSelectSpell(nil)
    list:destroyChildren()
    for _, name in ipairs(MagicalArchive.buildSpellNames(SpellInfo[ARCHIVE_PROFILE])) do
        local info = SpellInfo[ARCHIVE_PROFILE][name]
        if archiveMatchesFilters(info) and
            MagicalArchive.matchesSearch(name, info, archiveState.search) then
            local row = g_ui.createWidget('ArchiveSpellLabel', list)
            row:setId(name)
            row.spellName = name
            row.caption:setText(name)
            row:setTooltip(name)
            connect(row.caption, {onGeometryChange = archiveFitSpellName})
            row:setImageSource(SpelllistSettings[ARCHIVE_PROFILE].iconsForGameCooldown)
            row:setImageClip((info.clientId * 20) .. ' 0 20 20')
            row.onClick = archiveSelectSpell
        end
    end
    local rows = list:getChildren()
    for i, row in ipairs(rows) do
        local top = i == 1 and 2 or 1
        row:setHeight(22 + ((i == 1 or i == #rows) and 1 or 0))
        row:setImageOffset({x = 2, y = top})
        row.caption:setMarginTop(top + 4)
        row.unavailable:setMarginTop(top)
    end
    MagicalArchive.refreshAvailability()
    local selectedRow = selectedName and list:getChildById(selectedName)
    selectedRow = selectedRow or list:getChildByIndex(1)
    if selectedRow then
        list:focusChild(selectedRow, ActiveFocusReason)
        archiveSelectSpell(selectedRow)
        if detailTab == 'rune' and Spells.isRuneSpell(SpellInfo[ARCHIVE_PROFILE][selectedRow:getId()].id) then
            archiveSelectDetailTab('rune')
        end
    end
end

local function archiveRefreshFilterChecks()
    archiveUpdatingFilters = true
    local panel = UI.InformationBase.selectSpell.FilterPanel
    for _, option in ipairs(archiveFilterOptions) do
        if option.key then
            local checked = archiveState.filters[option.key]
            if option.members then
                checked = true
                for _, key in ipairs(option.members) do
                    checked = checked and archiveState.filters[key]
                end
            end
            panel[option.key]:setChecked(checked)
        end
    end
    archiveUpdatingFilters = false
end

local function archiveSetFiltersExpanded(expanded)
    if archiveFilterCloseEvent then
        removeEvent(archiveFilterCloseEvent)
        archiveFilterCloseEvent = nil
    end
    local selection = UI.InformationBase.selectSpell
    local panel = selection.FilterPanel
    panel.expanded = expanded
    panel:setHeight(expanded and panel.expandedHeight or 19)
    panel.Header.Expand:setOn(expanded)
    for _, child in ipairs(panel:getChildren()) do
        if child ~= panel.Header then
            child:setVisible(expanded)
        end
    end
    selection.SpellListBase:setVisible(not expanded)
    selection.SearchBase:setVisible(not expanded)
end

local function archiveCreateFilters()
    local panel = UI.InformationBase.selectSpell.FilterPanel
    local top = 22
    for _, option in ipairs(archiveFilterOptions) do
        local widget = g_ui.createWidget(option.key and 'ArchiveFilterCheckBox' or 'ArchiveFilterSeparator', panel)
        widget:setMarginTop(top)
        if option.key then
            widget:setId(option.key)
            widget:setText(tr(option.text))
            widget.onCheckChange = function(self, checked)
                if archiveUpdatingFilters then return end
                if option.members then
                    for _, key in ipairs(option.members) do archiveState.filters[key] = checked end
                else
                    archiveState.filters[option.key] = checked
                end
                archiveRefreshFilterChecks()
                archiveRebuildList()
            end
        end
        top = top + widget:getHeight() + 5
    end
    panel.expandedHeight = top + 2
    panel.Header.onClick = function() archiveSetFiltersExpanded(not panel.expanded) end
    panel.onHoverChange = function(self, hovered)
        if archiveFilterCloseEvent then removeEvent(archiveFilterCloseEvent); archiveFilterCloseEvent = nil end
        if not hovered and self.expanded then
            archiveFilterCloseEvent = scheduleEvent(function()
                archiveFilterCloseEvent = nil
                if UI and not UI:isDestroyed() and not self:isDestroyed() and
                    not self:containsPoint(g_window.getMousePosition()) then
                    archiveSetFiltersExpanded(false)
                end
            end, 400)
        end
    end
    UI.onMousePress = function(self, position)
        if panel.expanded and not panel:containsPoint(position) then archiveSetFiltersExpanded(false) end
        return false
    end
    UI.onVisibilityChange = function(self, visible)
        if not visible then archiveCancelSearch() end
    end
    UI.onDestroy = function()
        archiveCancelSearch()
        if archiveFilterCloseEvent then removeEvent(archiveFilterCloseEvent); archiveFilterCloseEvent = nil end
    end
    archiveRefreshFilterChecks()
    archiveSetFiltersExpanded(false)
end

function MagicalArchive.onSpellsChange(player, spells)
    archiveState.learned = {}
    for _, id in ipairs(spells) do
        if id > 0 then archiveState.learned[tostring(id)] = true end
    end
    if UI and not UI:isDestroyed() and archiveState.filters.learned then archiveRebuildList() end
    addEvent(MagicalArchive.refreshAvailability)
end

function MagicalArchive.onPlayerFilterChange()
    if UI and not UI:isDestroyed() and
        (archiveState.filters.currentVocation or archiveState.filters.currentLevel) then
        archiveRebuildList()
    else
        MagicalArchive.refreshAvailability()
    end
end

function MagicalArchive.onGameEnd()
    archiveCancelSearch()
    if archiveFilterCloseEvent then removeEvent(archiveFilterCloseEvent); archiveFilterCloseEvent = nil end
    archiveState.learned = {}
    UI = nil
end

function showMagicalArchives()
    UI = g_ui.loadUI("magicalArchives", contentContainer)
    UI:show()
    controllerCyclopedia.ui.CharmsBase:setVisible(false)
    controllerCyclopedia.ui.GoldBase:setVisible(false)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(false)
    end

    archiveState.filters = table.copy(archiveFilterDefaults)
    if archiveState.learned == nil then
        archiveState.learned = g_game.isOnline() and modules.game_actionbar and
            table.copy(modules.game_actionbar.spellListData or {}) or {}
    end
    archiveState.search = ''
    archiveCreateFilters()

    local searchEdit = UI.InformationBase.selectSpell.SearchBase.SearchEdit
    searchEdit.onTextChange = function(widget, text)
        archiveCancelSearch()
        archiveSearchEvent = scheduleEvent(function()
            archiveSearchEvent = nil
            if UI and not UI:isDestroyed() then
                archiveState.search = text
                archiveRebuildList()
            end
        end, 250)
    end
    UI.InformationBase.selectSpell.SearchBase.SearchClearButton.onClick = function()
        searchEdit:clearText()
        archiveCancelSearch()
        archiveState.search = ''
        archiveRebuildList()
    end

    local list = UI.InformationBase.selectSpell.SpellListBase.questList
    list:setPaddingRight(13)
    local scrollbar = UI.InformationBase.selectSpell.SpellListBase.spellsScrollBar
    scrollbar:setMarginRight(2)
    scrollbar:setMarginTop(1)
    scrollbar:setMarginBottom(1)
    scrollbar.sliderButton:setImageBorderTop(6)
    scrollbar.sliderButton:setImageBorderBottom(6)
    scrollbar:configureScrollArea(list)
    connect(list, {
        onChildFocusChange = function(self, focusedChild)
            archiveSelectSpell(focusedChild)
        end
    })

    local descriptionScrollbar = UI.spellAndRune.DetailPanel.DescriptionScrollBar
    descriptionScrollbar.sliderButton:setImageBorderTop(6)
    descriptionScrollbar.sliderButton:setImageBorderBottom(6)
    descriptionScrollbar:configureScrollArea(UI.spellAndRune.DetailPanel.AdditionalPanel)

    local tabs = UI.spellAndRune.DetailPanel.DetailTabs
    tabs.onGeometryChange = function()
        local width = math.floor(tabs:getWidth() / 3)
        -- Center the fixed captions within Qt's 15-pixel left text inset.
        local textOffset = 7 + width % 2
        for _, button in ipairs({tabs.CombatTab, tabs.AdditionalTab, tabs.RuneTab}) do
            button:setWidth(width)
            button:mergeStyle({
                ['text-offset'] = textOffset .. ' 1',
                ['$pressed'] = {['text-offset'] = (textOffset + 1) .. ' 2'},
                ['$on'] = {['text-offset'] = (textOffset + 1) .. ' 2'}
            })
        end
    end
    tabs.onGeometryChange()
    tabs.CombatTab.onClick = function() archiveSelectDetailTab('combat') end
    tabs.AdditionalTab.onClick = function() archiveSelectDetailTab('additional') end
    tabs.RuneTab.onClick = function() archiveSelectDetailTab('rune') end
    archiveSelectDetailTab('combat')

    local detailRows = UI.spellAndRune.DetailPanel.DetailRows
    local captions = {
        RowGroup = tr('Spell group'),
        RowBasePower = tr('Base Power'),
        RowScaling = tr('Scales with'),
        RowCooldown = tr('Cooldown'),
        RowGroupCooldown = tr('Group Cooldown'),
        RowMagicType = tr('Magic Type'),
        RowRange = tr('Range')
    }
    for rowId, caption in pairs(captions) do
        detailRows[rowId].caption:setText(caption)
    end
    archiveLayoutStatGrid(detailRows,
        {'RowMana', 'RowGroup', 'RowBasePower', 'RowScaling'},
        {'RowCooldown', 'RowGroupCooldown', 'RowMagicType', 'RowRange'})
    archiveLayoutStatGrid(UI.spellAndRune.DetailPanel.RunePanel,
        {'RowMana', 'RowGroup', 'RowLevel', 'RowAmount'}, {'RowCooldown', 'RowGroupCooldown', 'RowVocation'})

    local runeCaptions = {
        RowMana = tr('Mana / SP'),
        RowGroup = tr('Spell group'),
        RowLevel = tr('Restriction'),
        RowAmount = tr('Amount'),
        RowCooldown = tr('Cooldown'),
        RowGroupCooldown = tr('Group Cooldown'),
        RowVocation = tr('Vocations')
    }
    for rowId, caption in pairs(runeCaptions) do
        UI.spellAndRune.DetailPanel.RunePanel[rowId].caption:setText(caption)
    end

    archiveRebuildList()
end

function MagicalArchive.openSpell(name)
    if not g_game.isOnline() or not SpellInfo[ARCHIVE_PROFILE][name] or
        not contentContainer or not controllerCyclopedia.ui then
        return false
    end
    if not Cyclopedia.openTab('magicalArchives') then
        return false
    end

    local selection = UI.InformationBase.selectSpell
    archiveState.filters = table.copy(archiveFilterDefaults)
    archiveRefreshFilterChecks()
    archiveSetFiltersExpanded(false)
    selection.SearchBase.SearchEdit:setText('')
    archiveCancelSearch()
    archiveState.search = ''
    archiveRebuildList()
    local list = selection.SpellListBase.questList
    local row = list:getChildById(name)
    if not row then
        return false
    end
    list:focusChild(row, ActiveFocusReason)
    archiveSelectSpell(row)
    controllerCyclopedia.ui:raise()
    controllerCyclopedia.ui:focus()
    return true
end
