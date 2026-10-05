spelllistSidebar = nil
local searchEvent
local sidebarMenu
local dragImage
local selectedSpell
local knownSpellsOnly = false
local learnedSpells = {}
local focusParents = {}
local initialHeight
local sidebarFilters = {}
local filterDefaults = {currentVocation = false, currentLevel = false, druid = true, knight = true,
    paladin = true, sorcerer = true, monk = true, attack = true, healing = true, support = true,
    premium = true, free = true, rune = true, instant = true}
local vocationFilters = {{'Druid', 'druid', 2, 6}, {'Knight', 'knight', 4, 8},
    {'Paladin', 'paladin', 3, 7}, {'Sorcerer', 'sorcerer', 1, 5}, {'Monk', 'monk', 9, 10}}
local groupFilters = {{'Attack', 'attack', 1}, {'Healing', 'healing', 2}, {'Support', 'support', 3}}

local function loadSidebarFilters()
    local saved = spelllistSidebar:getSettings('spellFilters') or {}
    for key, value in pairs(filterDefaults) do
        sidebarFilters[key] = saved[key]
        if sidebarFilters[key] == nil then sidebarFilters[key] = value end
    end
end

local function matchesSidebarFilters(info)
    local player = g_game.getLocalPlayer()
    if sidebarFilters.currentLevel and (not player or info.level > player:getLevel()) then return false end
    if sidebarFilters.currentVocation then
        if not player then return false end
        local vocation = modules.game_actionbar.translateVocation(player:getVocation())
        if not table.contains(info.vocations, vocation) then return false end
    end
    local allVocations, vocationMatch = true, false
    for _, filter in ipairs(vocationFilters) do
        allVocations = allVocations and sidebarFilters[filter[2]]
        if sidebarFilters[filter[2]] and (table.contains(info.vocations, filter[3]) or
            table.contains(info.vocations, filter[4])) then vocationMatch = true end
    end
    if not allVocations and not vocationMatch then return false end
    local groupMatch = false
    for _, filter in ipairs(groupFilters) do
        if sidebarFilters[filter[2]] and info.group[filter[3]] then groupMatch = true end
    end
    if not groupMatch then return false end
    if info.premium and not sidebarFilters.premium or not info.premium and not sidebarFilters.free then return false end
    local rune = Spells.isRuneSpell(info.id)
    return rune and sidebarFilters.rune or not rune and sidebarFilters.instant
end

local function refreshSidebarFocus()
    if spelllistSidebar then
        local search = spelllistSidebar.contentsPanel.search
        spelllistSidebar.focusFrame:setOn(search:isActive() and search:isVisible())
    end
end

local function disconnectSidebarFocus()
    for _, parent in ipairs(focusParents) do
        disconnect(parent, {onChildFocusChange = refreshSidebarFocus})
    end
    focusParents = {}
end

local function bindSidebarFocus()
    disconnectSidebarFocus()
    local parent = spelllistSidebar.contentsPanel
    while parent do
        connect(parent, {onChildFocusChange = refreshSidebarFocus})
        focusParents[#focusParents + 1] = parent
        parent = parent:getParent()
    end
    refreshSidebarFocus()
end

local function cancelSidebarDrag()
    if dragImage then dragImage:destroy(); dragImage = nil end
end

local function fitSidebarText(label)
    label:setTextOverflowLength(0)
    label.fullTextWidth = label:getTextSize().width
    label:setTextOverflowCharacter(string.char(133))
    local length = #label:getText()
    while label:getTextSize().width > label:getWidth() and length > 1 do
        length = length - 1
        label:setTextOverflowLength(length)
    end
end

local function updateSidebarDetails(row)
    for _, child in ipairs(spelllistSidebar.contentsPanel.spells:getChildren()) do
        if child.caption and child.formula then
            local color = child == row and '#f4f4f4' or '#c0c0c0'
            child.caption:setColor(color)
            child.formula:setColor(color)
        end
    end
    selectedSpell = row and row:getId()
    updateSpellInformation(row)
    local info = selectedSpell and SpellInfo[getSpelllistProfile()][selectedSpell]
    local values = {formulaValueLabel:getText(), vocationValueLabel:getText(), groupValueLabel:getText(),
        typeValueLabel:getText(), info and info.magicType or '', cooldownValueLabel:getText(), manaValueLabel:getText(),
        levelValueLabel:getText(), info and (info.premium and 'Yes' or 'No') or ''}
    local details = spelllistSidebar.contentsPanel.details
    details.name:setText(nameValueLabel:getText())
    for i, value in ipairs(values) do
        details['value' .. i]:setText(value)
    end
    spelllistSidebar.contentsPanel.showMore:setEnabled(selectedSpell ~= nil)
end

function refreshSpelllistAvailability()
    if not spelllistSidebar then return end
    local actionbar = modules.game_actionbar
    for _, row in ipairs(spelllistSidebar.contentsPanel.spells:getChildren()) do
        local info = SpellInfo[getSpelllistProfile()][row:getId()]
        row.unavailable:setVisible(not (actionbar and actionbar.playerCanUseSpell(info)))
    end
end

function refreshSpelllistSidebar()
    if not spelllistSidebar then return end
    local list = spelllistSidebar.contentsPanel.spells
    local query = spelllistSidebar.contentsPanel.search:getText():lower()
    local selected
    local visible = {}
    for _, row in ipairs(list:getChildren()) do
        local info = SpellInfo[getSpelllistProfile()][row:getId()]
        local matches = row:getId():lower():find(query, 1, true) or info.words:lower():find(query, 1, true)
        matches = matches and (not knownSpellsOnly or learnedSpells[tostring(info.id)] ~= nil) and matchesSidebarFilters(info)
        row:setVisible(not not matches)
        if matches then
            visible[#visible + 1] = row
            selected = selected or row
        end
    end
    local size = SpelllistSettings[getSpelllistProfile()].iconSize
    local height = math.max(size.height, 26)
    for i, row in ipairs(visible) do
        local top = i == 1 and 2 or 1
        row:setHeight(height + 2 + ((i == 1 or i == #visible) and 1 or 0))
        row:setImageOffset({x = 2, y = top + math.floor((height - size.height) / 2)})
        row.unavailable:setMarginTop(top + math.floor((height - size.height) / 2))
        local textTop = top + math.floor((height - 26) / 2)
        row.caption:setMarginTop(textTop)
        row.formula:setMarginTop(textTop + 13)
    end
    refreshSpelllistAvailability()
    list:focusChild(selected, KeyboardFocusReason)
    updateSidebarDetails(selected)
    spelllistSidebar.miniwindowScrollBar:setValue(0)
end

function rebuildSpelllistSidebar()
    if not spelllistSidebar then return end
    local list = spelllistSidebar.contentsPanel.spells
    list:destroyChildren()
    local profile = getSpelllistProfile()
    local names = {}
    for name in pairs(SpellInfo[profile]) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local info = SpellInfo[profile][name]
        local row = g_ui.createWidget('SpellListLabel', list)
        row:setId(name)
        local unavailable = g_ui.createWidget('UIWidget', row)
        unavailable:setId('unavailable')
        unavailable:setPhantom(true)
        unavailable:setImageSource('/images/ui/ditherpattern')
        unavailable:setImageRepeated(true)
        unavailable:setShader('UI - Premultiplied Alpha')
        unavailable:setSize(SpelllistSettings[profile].iconSize)
        unavailable:addAnchor(AnchorTop, 'parent', AnchorTop)
        unavailable:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        unavailable:setMarginLeft(2)
        for i, text in ipairs({name, info.words}) do
            local label = g_ui.createWidget('UILabel', row)
            label:setId(i == 1 and 'caption' or 'formula')
            label:setFont('verdana-bold-11px-native')
            label:setColor('#c0c0c0')
            label:setTextAlign(AlignTopLeft)
            label:setPhantom(true)
            label:setHeight(13)
            label:addAnchor(AnchorTop, 'parent', AnchorTop)
            label:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            label:addAnchor(AnchorRight, 'parent', AnchorRight)
            label:setMarginLeft(SpelllistSettings[profile].iconSize.width + 4)
            label:setMarginRight(2)
            connect(label, {onTextChange = fitSidebarText, onGeometryChange = fitSidebarText})
            label:setText(text)
        end
        UIHoverTooltip.configure(row, function(self)
            local pos = g_window.getMousePosition()
            for _, label in ipairs({self.caption, self.formula}) do
                if label:containsPoint(pos) and label.fullTextWidth > label:getWidth() then
                    return label:getText()
                end
            end
        end)
        row:setImageSource(SpelllistSettings[profile].iconFile)
        row:setImageClip(Spells.getImageClip(info.clientId, profile))
        row:setImageSize(SpelllistSettings[profile].iconSize)
        row:setPhantom(false)
        row:mergeStyle({['$focus'] = {['background-color'] = '#81818155'}})
        row.onClick = function()
            list:focus()
            list:focusChild(row, MouseFocusReason)
        end
        row:setDraggable(true)
        row.onDragEnter = function(self, pos)
            cancelSidebarDrag()
            list:focusChild(self, MouseFocusReason)
            dragImage = g_ui.createWidget('UIWidget', rootWidget)
            dragImage:setId('spellDragImage')
            dragImage:setPhantom(true)
            dragImage:setImageSource(self:getImageSource())
            dragImage:setImageClip(self:getImageClip())
            dragImage:setSize(SpelllistSettings[profile].iconSize)
            dragImage:setPosition({x = pos.x - math.floor(dragImage:getWidth() / 2),
                y = pos.y - math.floor(dragImage:getHeight() / 2)})
            dragImage:raise()
            return true
        end
        row.onDragMove = function(self, pos)
            if dragImage then
                dragImage:setPosition({x = pos.x - math.floor(dragImage:getWidth() / 2),
                    y = pos.y - math.floor(dragImage:getHeight() / 2)})
            end
            return true
        end
        row.onDragLeave = function(self, droppedWidget, pos)
            local dragging = dragImage ~= nil
            cancelSidebarDrag()
            if dragging and modules.game_actionbar then modules.game_actionbar.tryAssignSpellFromDrop(pos, info) end
            return true
        end
    end
    refreshSpelllistSidebar()
end

function showSidebarSpellDetails()
    if not selectedSpell or not g_game.isOnline() then return end
    local cyclopedia = modules.game_cyclopedia
    if cyclopedia and cyclopedia.MagicalArchive and cyclopedia.MagicalArchive.openSpell(selectedSpell) then
        return
    end
    showSpellDetails(selectedSpell)
end

local function onSidebarSpellsChange(player, spells)
    learnedSpells = {}
    for _, id in ipairs(spells) do
        if id > 0 then learnedSpells[tostring(id)] = true end
    end
    if knownSpellsOnly or sidebarFilters.currentVocation then refreshSpelllistSidebar() else refreshSpelllistAvailability() end
end

local function onSidebarLevelChange()
    if sidebarFilters.currentLevel then refreshSpelllistSidebar() else refreshSpelllistAvailability() end
end

local function onSidebarVocationChange()
    if sidebarFilters.currentVocation then refreshSpelllistSidebar() else refreshSpelllistAvailability() end
end

local function onSidebarGameEnd()
    onSidebarSpellsChange(nil, {})
end

function initSpelllistSidebar()
    if spelllistSidebar then return end
    g_ui.importStyle('spelllist_sidebar')
    learnedSpells = g_game.isOnline() and modules.game_actionbar and modules.game_actionbar.spellListData or {}
    connect(LocalPlayer, {onSpellsChange = onSidebarSpellsChange,
        onManaChange = refreshSpelllistAvailability, onLevelChange = onSidebarLevelChange,
        onSoulChange = refreshSpelllistAvailability, onVocationChange = onSidebarVocationChange})
    connect(g_game, {onGameStart = refreshSpelllistAvailability, onGameEnd = onSidebarGameEnd})
    spelllistSidebar = g_ui.createWidget('SpellListSidebar')
    initialHeight = spelllistSidebar:getHeight()
    loadSidebarFilters()
    local content = spelllistSidebar.contentsPanel
    local details = content.details
    local name = g_ui.createWidget('UILabel', details)
    name:setId('name')
    name:setFont('verdana-bold-11px-native')
    name:setColor('#f4f4f4')
    name:setTextAlign(AlignCenter)
    name:setHeight(13)
    name:addAnchor(AnchorTop, 'parent', AnchorTop)
    name:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    name:addAnchor(AnchorRight, 'parent', AnchorRight)
    local captions = {'Formula:', 'Vocation:', 'Group:', 'Type:', 'Magic Type:', 'Cooldown:', 'Mana / SP:', 'Min Level:', 'Premium:'}
    local tooltips = {[3] = 'Spell Group', [6] = 'Spell / Primary Spell Group / Secondary Spell Group',
        [7] = 'Mana / Soul Points'}
    local y = 12
    for i, caption in ipairs(captions) do
        local label = g_ui.createWidget('UILabel', details)
        label:setFont('verdana-bold-11px-native')
        label:setColor('#c0c0c0')
        label:setTextAlign(AlignTopRight)
        label:setText(caption)
        if tooltips[i] then
            label:setPhantom(false)
            UIHoverTooltip.configure(label, tooltips[i])
        end
        label:setSize({width = 77, height = 13})
        label:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        label:addAnchor(AnchorTop, 'parent', AnchorTop)
        label:setMarginTop(y)
        local value = g_ui.createWidget('UILabel', details)
        value:setId('value' .. i)
        value:setFont('verdana-bold-11px-native')
        value:setColor('#f4f4f4')
        value:setTextAlign(AlignTopLeft)
        value:setHeight(i == 1 and 26 or 13)
        value:setTextWrap(i == 1)
        value:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        value:addAnchor(AnchorRight, 'parent', AnchorRight)
        value:addAnchor(AnchorTop, 'parent', AnchorTop)
        value:setMarginLeft(82)
        value:setMarginTop(y)
        y = y + (i == 1 and 25 or 12)
    end
    spelllistSidebar:setup()
    spelllistSidebar:setContentMinimumHeight(224)
    content.spells.onKeyPress = function(self, keyCode)
        if keyCode == KeyLeft or keyCode == KeyRight then return true end
        if keyCode ~= KeyUp and keyCode ~= KeyDown then return false end
        local rows, selected = {}, 0
        for _, row in ipairs(self:getChildren()) do
            if row:isExplicitlyVisible() then
                rows[#rows + 1] = row
                if row == self:getFocusedChild() then selected = #rows end
            end
        end
        local index = math.max(1, math.min(#rows, selected + (keyCode == KeyUp and -1 or 1)))
        if rows[index] then
            self:focusChild(rows[index], KeyboardFocusReason)
            self:ensureChildVisible(rows[index])
        end
        return true
    end
    content.spells:setVerticalScrollBar(spelllistSidebar.miniwindowScrollBar)
    spelllistSidebar.miniwindowScrollBar:configureScrollArea(content.spells)
    connect(content.spells, {onChildFocusChange = function(self, row) updateSidebarDetails(row) end})
    connect(content.search, {onFocusChange = refreshSidebarFocus, onVisibilityChange = refreshSidebarFocus,
        onMousePress = bindSidebarFocus})
    connect(spelllistSidebar, {onGeometryChange = function()
        if spelllistSidebar and focusParents[3] ~= spelllistSidebar:getParent() then bindSidebarFocus() end
    end})
    bindSidebarFocus()
    content.search.onKeyPress = function(self, keyCode)
        if keyCode == KeyEscape then self:getParent():focusChild(nil) end
        return false
    end
    content.search.onTextChange = function(self)
        -- The placeholder renderer centres its text separately.
        self:setTextAlign(self:getText() == '' and AlignTopLeft or AlignLeftCenter)
        self:setPaddingBottom(self:getText() == '' and 3 or 2)
        if searchEvent then removeEvent(searchEvent) end
        searchEvent = scheduleEvent(function() searchEvent = nil; refreshSpelllistSidebar() end, 250)
    end
    content.clearSearch.onClick = function()
        content.search:setText('')
        if searchEvent then removeEvent(searchEvent); searchEvent = nil end
        refreshSpelllistSidebar()
    end
    content.showMore.onClick = showSidebarSpellDetails
    knownSpellsOnly = spelllistSidebar:getSettings('knownSpellsOnly') or false
    local function showMenu(pos)
        if sidebarMenu then sidebarMenu:destroy() end
        local menu = UIContextMenu.create({})
        sidebarMenu = menu
        connect(menu, {onDestroy = function() sidebarMenu = nil end})
        local function addFilter(text, key)
            menu:addCheckBox(tr(text), sidebarFilters[key], function(_, checked)
                sidebarFilters[key] = checked
                spelllistSidebar:setSettings({spellFilters = sidebarFilters})
                refreshSpelllistSidebar()
            end)
        end
        local function addGroup(text, filters)
            local checked = true
            for _, filter in ipairs(filters) do checked = checked and sidebarFilters[filter[2]] end
            menu:addCheckBox(tr(text), checked, function(_, value)
                for _, filter in ipairs(filters) do sidebarFilters[filter[2]] = value end
                spelllistSidebar:setSettings({spellFilters = sidebarFilters})
                refreshSpelllistSidebar()
            end)
        end
        addFilter('Character Vocation', 'currentVocation')
        addFilter('Character Level', 'currentLevel')
        menu:addCheckBox(tr('Learnt Spells'), knownSpellsOnly, function()
            knownSpellsOnly = not knownSpellsOnly
            spelllistSidebar:setSettings({knownSpellsOnly = knownSpellsOnly})
            refreshSpelllistSidebar()
        end)
        menu:addSeparator()
        for _, filter in ipairs(vocationFilters) do addFilter(filter[1], filter[2]) end
        addGroup('All Vocations', vocationFilters)
        menu:addSeparator()
        for _, filter in ipairs(groupFilters) do addFilter(filter[1], filter[2]) end
        addGroup('All Spell Groups', groupFilters)
        menu:addSeparator()
        addFilter('Premium Account', 'premium')
        addFilter('Free Account', 'free')
        menu:addSeparator()
        addFilter('Rune Spells', 'rune')
        addFilter('Instant Spells', 'instant')
        menu:display(pos or g_window.getMousePosition())
    end
    spelllistSidebar.menuButton.onClick = function() showMenu() end
    spelllistSidebar.onMouseRelease = function(self, pos, button)
        if button == MouseRightButton then
            showMenu(pos)
            return true
        end
        return false
    end
    UIHoverTooltip.configure(spelllistSidebar.menuButton, 'Click here to configure the filters of the spell list.')
    UIHoverTooltip.configure(content.clearSearch, 'Clear all text from the search field.')
    spelllistSidebar.onOpen = function()
        refreshSpelllistAvailability()
        bindSidebarFocus()
        if spelllistButton then spelllistButton:setOn(true) end
    end
    spelllistSidebar.onClose = function()
        cancelSidebarDrag()
        if sidebarMenu then sidebarMenu:destroy(); sidebarMenu = nil end
        if spelllistButton then spelllistButton:setOn(false) end
    end
    rebuildSpelllistSidebar()
    spelllistSidebar:close(true)
end

function setupSpelllistSidebar()
    loadSidebarFilters()
    local closed = spelllistSidebar:getSettings('closed') ~= false
    local height = spelllistSidebar:getSettings('height') or initialHeight
    if spelllistSidebar:isOn() then spelllistSidebar:maximize(true) end
    spelllistSidebar:setHeight(height)
    knownSpellsOnly = spelllistSidebar:getSettings('knownSpellsOnly') or false
    spelllistSidebar.contentsPanel.search:setText('')
    spelllistSidebar:setupOnStart()
    if closed then spelllistSidebar:close(true) end
    refreshSpelllistSidebar()
end

function toggleSpelllistSidebar()
    if spelllistSidebar:isExplicitlyVisible() then
        spelllistSidebar:close()
    else
        if not spelllistSidebar:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(spelllistSidebar, spelllistSidebar:getMinimumHeight())
            if not panel then return end
            spelllistSidebar:setParent(panel)
        end
        spelllistSidebar:open()
    end
end

function terminateSpelllistSidebar()
    disconnectSidebarFocus()
    cancelSidebarDrag()
    disconnect(g_game, {onGameStart = refreshSpelllistAvailability, onGameEnd = onSidebarGameEnd})
    disconnect(LocalPlayer, {onSpellsChange = onSidebarSpellsChange,
        onManaChange = refreshSpelllistAvailability, onLevelChange = onSidebarLevelChange,
        onSoulChange = refreshSpelllistAvailability, onVocationChange = onSidebarVocationChange})
    if sidebarMenu then sidebarMenu:destroy(); sidebarMenu = nil end
    selectedSpell = nil
    learnedSpells = {}
    if searchEvent then removeEvent(searchEvent); searchEvent = nil end
    if spelllistSidebar then spelllistSidebar:destroy(); spelllistSidebar = nil end
end
