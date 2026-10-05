local characterPanel = nil
local UI = nil

local function updateCharacterBase(name, vocation, level, outfit, title)
    UI.CharacterBase:setText(name)
    UI.CharacterBase.Title:setTextOverflowLength(0)
    UI.CharacterBase.Title:setText(title)
    UI.CharacterBase.Title:setTooltip(title)
    UI.CharacterBase.Title:setTextOverflowCharacter('...')
    local titleLength = #title
    while UI.CharacterBase.Title:getTextSize().width > UI.CharacterBase.Title:getWidth() and titleLength > 3 do
        titleLength = titleLength - 1
        UI.CharacterBase.Title:setTextOverflowLength(titleLength)
    end

    local titleHeight = 0
    if title ~= '' then
        titleHeight = UI.CharacterBase.Title:getTextSize().height
    end

    UI.CharacterBase.Title:setHeight(titleHeight)
    UI.CharacterBase.Title:setVisible(titleHeight > 0)
    UI.CharacterBase:setHeight(119 + titleHeight)
    UI.OptionsBase:setMarginBottom(53 - titleHeight)
    UI.CharacterBase.Level:setText(string.format('%s: %d', tr('Level'), level))
    UI.CharacterBase.Vocation:setText(vocation)
    UI.CharacterBase.Outfit:setOutfit(outfit)
end

local function close(parent)
    if table.empty(parent.subCategories) then
        return
    end

    for subId, _ in ipairs(parent.subCategories) do
        local subWidget = parent:getChildById(subId)

        if subWidget then
            subWidget:setVisible(false)
        end
    end

    parent:setHeight(parent.closedSize)
    parent.opened = false
    parent.Button.Arrow:setVisible(true)
end

local function reset()
    characterPanel.InfoBase.inventoryPanel:setVisible(true)
    characterPanel.InfoBase.outfitPanel:setVisible(false)

    if characterPanel.InfoBase.CharacterButton.state ~= 1 then
        Cyclopedia.characterButton(characterPanel.InfoBase.CharacterButton)
    end

    Cyclopedia.selectCharacterPage()
    characterPanel.openedCategory = nil
end

local function open(parent)
    local oldOpen = UI.openedCategory

    for subId, _ in ipairs(parent.subCategories) do
        local subWidget = parent:getChildById(subId)

        if subWidget then
            if tonumber(subWidget:getId()) == 1 then
                subWidget.Button.onClick(subWidget)
            end

            subWidget:setVisible(true)
        end
    end

    if oldOpen ~= nil and oldOpen ~= parent then
        close(oldOpen)
    end

    parent:setHeight(parent.openedSize)
    parent.opened = true
    parent.Button.Arrow:setVisible(false)

    UI.openedCategory = parent
end

function showCharacter()
    characterPanel = g_ui.loadUI("character", contentContainer)
    UI = characterPanel
    characterPanel:show()
    UI.selectedOption = "InfoBase"

    if g_game.isOnline() then
        local player = g_game.getLocalPlayer()
        updateCharacterBase(player:getName(), player:getVocationNameByClientId(), player:getLevel(), player:getOutfit(), '')

        UI.InfoBase.outfitPanel.Sprite:setOutfit(player:getOutfit())
        UI.InfoBase.InspectLabel:setText(tr("You are inspecting") .. ": " .. player:getName())

        for i = InventorySlotFirst, InventorySlotPurse do
            local item = player:getInventoryItem(i)
            local itemWidget = UI.InfoBase.inventoryPanel["slot" .. i]
            if itemWidget then
                if item then
                    itemWidget:setStyle("InventoryItemCyclopedia")
                    itemWidget:setItem(item)
                    ItemsDatabase.setRarityItem(itemWidget, itemWidget:getItem())
                    ItemsDatabase.setTier(itemWidget, itemWidget:getItem())
                    itemWidget:setIcon("")
                else
                    itemWidget:setStyle(Cyclopedia.InventorySlotStyles[i].name)
                    itemWidget:setIcon(Cyclopedia.InventorySlotStyles[i].icon)
                    itemWidget:setItem(nil)
                end
            end
        end

        if g_game.isOnline() then
            Cyclopedia.createCharacterDescription(player:getLevel(), player:getVocationNameByClientId(), '')
            Cyclopedia.configureCharacterCategories()
            g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.BaseInformation)
            g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Ispection)
        end
    end

    reset()
    controllerCyclopedia.ui.CharmsBase:setVisible(true)
    controllerCyclopedia.ui.GoldBase:setVisible(true)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(true)
    end
end

function Cyclopedia.loadCharacterBaseInformation(name, vocation, level, outfit, canViewStoreSummaryAndTitles, title)
    if not UI or not UI.CharacterBase then
        return
    end

    updateCharacterBase(name, vocation, level, outfit, title)

    if UI.InfoBase and not UI.inspectionData then
        UI.InfoBase.InspectLabel:setText(tr("You are inspecting") .. ": " .. name)
        Cyclopedia.createCharacterDescription(level, vocation, title)
        if UI.InfoBase.outfitPanel and UI.InfoBase.outfitPanel.Sprite then
            UI.InfoBase.outfitPanel.Sprite:setOutfit(outfit)
        end
    end

    local storeSummary = UI.OptionsBase:getChildById('6')
    local characterTitles = UI.OptionsBase:getChildById('7')
    if storeSummary then
        storeSummary:setVisible(canViewStoreSummaryAndTitles)
    end
    if characterTitles then
        characterTitles:setVisible(canViewStoreSummaryAndTitles)
    end
end

Cyclopedia.Character = {}
Cyclopedia.Character.Achievements = {}
Cyclopedia.Character.Titles = {
    entries = {},
    filter = 'all',
    query = '',
    currentTitleId = 0
}
Cyclopedia.InventorySlotStyles = {
    [InventorySlotHead] = {
        icon = "/images/game/slots/inventory-head",
        name = "HeadSlot"
    },
    [InventorySlotNeck] = {
        icon = "/images/game/slots/inventory-neck",
        name = "NeckSlot"
    },
    [InventorySlotBack] = {
        icon = "/images/game/slots/inventory-back",
        name = "BackSlot"
    },
    [InventorySlotBody] = {
        icon = "/images/game/slots/inventory-torso",
        name = "BodySlot"
    },
    [InventorySlotRight] = {
        icon = "/images/game/slots/inventory-right-hand",
        name = "RightSlot"
    },
    [InventorySlotLeft] = {
        icon = "/images/game/slots/inventory-left-hand",
        name = "LeftSlot"
    },
    [InventorySlotLeg] = {
        icon = "/images/game/slots/inventory-legs",
        name = "LegSlot"
    },
    [InventorySlotFeet] = {
        icon = "/images/game/slots/inventory-feet",
        name = "FeetSlot"
    },
    [InventorySlotFinger] = {
        icon = "/images/game/slots/inventory-finger",
        name = "FingerSlot"
    },
    [InventorySlotAmmo] = {
        icon = "/images/game/slots/inventory-hip",
        name = "AmmoSlot"
    }
}

function Cyclopedia.characterAppearancesFilter(widget)
    local parent = widget:getParent()
    for i = 1, parent:getChildCount() do
        local child = parent:getChildByIndex(i)
        if child:getId() ~= "show" then
            child:setChecked(false)
        end
    end

    widget:setChecked(true)

    for _, data in ipairs(Cyclopedia.Character.Appearances) do
        if data.type == widget:getId() then
            data.visible = true
        else
            data.visible = false
        end
    end

    Cyclopedia.reloadCharacterAppearances()
end

function Cyclopedia.reloadCharacterAppearances()
    UI.CharacterAppearances.ListBase.list:destroyChildren()

    for _, data in ipairs(Cyclopedia.Character.Appearances) do
        if data.visible then
            local widget = g_ui.createWidget("CharacterAppearance", UI.CharacterAppearances.ListBase.list)
            widget.name:setText(data.name)
            widget.creature:setOutfit(data.outfit)
            widget.creature:getCreature():setStaticWalking(1000)
        end
    end
end

function Cyclopedia.loadCharacterAppearances(color, outfits, mounts, familiars)
    local data = {}

    local function insert(value, type)
        local lookData = value.lookType
        if type == "mounts" then
            lookData = value.mountId
        end

        local data_t = {
            visible = false,
            name = value.name,
            type = type,
            outfit = {
                auxType = 0,
                type = lookData,
                head = color.lookHead,
                body = color.lookBody,
                legs = color.lookLegs,
                feet = color.lookFeet,
                addon = outfits.addons and outfits.addons or 0
            }
        }

        table.insert(data, data_t)
    end

    local function process(container, containerType)
        for i = 0, #container do
            local value = container[i]
            if value then
                insert(value, containerType)
            end
        end
    end

    process(outfits, "outfits")
    process(mounts, "mounts")
    process(familiars, "familiars")

    Cyclopedia.Character.Appearances = data
    Cyclopedia.characterAppearancesFilter(UI.CharacterAppearances.listFilter.outfits)
end

function Cyclopedia.characterItemsSearch(text)
    local filter = UI.CharacterItems.filters
    local activeFilters = {}

    for i = 1, filter:getChildCount() do
        local child = filter:getChildByIndex(i)
        if child:isChecked() then
            table.insert(activeFilters, child:getId())
        end
    end

    for _, item in ipairs(Cyclopedia.Character.Items) do
        local data = item.data
        local name = data.name:lower()
        local meetsSearchCriteria = text == "" or string.find(name, text:lower()) ~= nil
        local meetsFilterCriteria = #activeFilters == 0 or table.contains(activeFilters, data.type)
        data.visible = meetsSearchCriteria and meetsFilterCriteria
    end

    Cyclopedia.reloadCharacterItems()
end

function Cyclopedia.characterItemsFilter(widget, force)
    if force then
        widget:setChecked(true)
    end

    local id = widget:getId()

    for _, item in ipairs(Cyclopedia.Character.Items) do
        local data = item.data
        if data.type == id then
            data.visible = widget:isChecked()
        end
    end

    Cyclopedia.reloadCharacterItems()
end

function Cyclopedia.reloadCharacterItems()
    UI.CharacterItems.ListBase.list:destroyChildren()
    UI.CharacterItems.gridBase.grid:destroyChildren()

    local colors = {"#484848", "#414141"}
    local colorIndex = 1

    for _, item in ipairs(Cyclopedia.Character.Items) do
        local itemId, data = item.itemId, item.data

        if data.visible then
            local listItem = g_ui.createWidget("CharacterListItem", UI.CharacterItems.ListBase.list)
            listItem.item:setItemId(itemId)
            listItem.name:setText(data.name)
            ItemsDatabase.setRarityItem(listItem.item, listItem.item:getItem())
            ItemsDatabase.setTier(listItem.item, item.tier)
            listItem.amount:setText(data.amount)
            listItem:setBackgroundColor(colors[colorIndex])
            local gridItem = g_ui.createWidget("CharacterGridItem", UI.CharacterItems.gridBase.grid)
            gridItem.item:setItemId(itemId)
            gridItem.amount:setText(data.amount)
            ItemsDatabase.setRarityItem(gridItem.item, gridItem.item:getItem())
            ItemsDatabase.setTier(gridItem.item, item.tier)
            colorIndex = 3 - colorIndex
        end
    end
end

function Cyclopedia.loadCharacterItems(data)
    local inventory = data.inventory
    local store = data.store
    local stash = data.stash
    local depot = data.depot
    local inbox = data.inbox
    Cyclopedia.Character.Items = {}

    local function insert(data, type)
        if not data then
            return
        end

        local thing = g_things.getThingType(data.itemId, ThingCategoryItem)
        local name = thing:getMarketData().name:lower()
        name = name ~= "" and name or "?"

        local data_t = {
            visible = false,
            name = name,
            amount = data.amount,
            type = type
        }

        local itemKey = data.itemId .. "-" .. (data.tier or "no_tier")
        local insertedItem = Cyclopedia.Character.Items[itemKey]
        if insertedItem and insertedItem.amount then
            insertedItem.amount = insertedItem.amount + data.amount
        else
            Cyclopedia.Character.Items[itemKey] = {
                itemId = data.itemId,
                tier = data.tier,
                data = data_t
            }
        end
    end

    local function processContainer(container, containerType)
        for i = 0, #container do
            local data = container[i]
            if data then
                insert(data, containerType)
            end
        end
    end

    processContainer(inventory, "inventory")
    processContainer(store, "store")
    processContainer(stash, "stash")
    processContainer(depot, "depot")
    processContainer(inbox, "inbox")

    local sortedItems = {}

    for _, itemData in pairs(Cyclopedia.Character.Items) do
        table.insert(sortedItems, itemData)
    end

    local function compareByName(a, b)
        local nameA = a.data.name:lower()
        local nameB = b.data.name:lower()

        if nameA ~= "?" and nameB == "?" then
            return true
        elseif nameA == "?" and nameB ~= "?" then
            return false
        else
            return nameA < nameB
        end
    end

    table.sort(sortedItems, compareByName)
    Cyclopedia.Character.Items = sortedItems
    Cyclopedia.characterItemsFilter(UI.CharacterItems.filters.inventory, true)
end

local function updateAchievementCounters(points, gradeCounts)
    local counters = UI.CharacterAchievements.achievements
    counters.Points:setText(tr('Achievements Points: ') .. points)
    counters.gradeOne:setText(tr('Grade 1: ') .. gradeCounts[1])
    counters.gradeTwo:setText(tr('Grade 2: ') .. gradeCounts[2])
    counters.gradeThree:setText(tr('Grade 3: ') .. gradeCounts[3])
    counters.gradeFour:setText(tr('Grade 4: ') .. gradeCounts[4])
end

local function renderCharacterAchievements()
    local state = Cyclopedia.Character.Achievements
    local list = UI.CharacterAchievements.ListBase.List
    list:destroyChildren()

    local achievements = {}
    for _, achievement in ipairs(state.entries or {}) do
        local visible = state.filter == 'all'
            or (state.filter == 'locked' and not achievement.unlocked)
            or (state.filter == 'accomplished' and achievement.unlocked)
        if visible then
            achievements[#achievements + 1] = achievement
        end
    end

    if state.lastSort == 2 then
        table.sort(achievements, function(a, b)
            if a.grade ~= b.grade then
                return a.grade > b.grade
            end
            if a.name ~= b.name then
                return a.name < b.name
            end
            return a.id < b.id
        end)
    elseif state.lastSort == 3 then
        table.sort(achievements, function(a, b)
            if a.timestamp ~= b.timestamp then
                return a.timestamp > b.timestamp
            end
            return a.id < b.id
        end)
    else
        table.sort(achievements, function(a, b)
            if a.name ~= b.name then
                return a.name < b.name
            end
            return a.id < b.id
        end)
    end

    for _, data in ipairs(achievements) do
        local widget = g_ui.createWidget('Achievement', list)
        widget:setId(data.id)
        widget.title:setText(data.name)
        widget:setText(data.description)
        widget.icon:setWidth(11 * data.grade)
        widget.grade = data.grade
        widget.unlocked = data.unlocked
        widget.timestamp = data.timestamp
    end
end

function Cyclopedia.loadCharacterAchievements()
    local state = Cyclopedia.Character.Achievements
    if not state.Loaded then
        UI.CharacterAchievements.sort:addOption('Alphabetically', 1, true)
        UI.CharacterAchievements.sort:addOption('By Grade', 2, true)
        UI.CharacterAchievements.sort:addOption('By Unlock Date', 3, true)
        state.lastSort = 1
        state.filter = 'all'
        state.entries = {}
        UI.CharacterAchievements.filters.all:setChecked(true)
        UI.CharacterAchievements.filters.locked:setChecked(false)
        UI.CharacterAchievements.filters.accomplished:setChecked(false)
        state.Loaded = true
    end

    g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Achievements)
    renderCharacterAchievements()
end

function Cyclopedia.loadCharacterAchievementsData(data)
    local state = Cyclopedia.Character.Achievements
    local unlocked = {}
    local gradeCounts = { 0, 0, 0, 0 }

    for _, entry in ipairs(data.entries or {}) do
        local definition = ACHIEVEMENTS[entry.id]
        local grade = entry.grade > 0 and entry.grade or (definition and definition.grade or 1)
        local achievement = {
            id = entry.id,
            name = entry.name ~= '' and entry.name or (definition and definition.name or tr('Unknown Achievement')),
            description = entry.description ~= '' and entry.description or (definition and definition.description or ''),
            grade = grade,
            secret = entry.secret or (definition and definition.secret) or false,
            timestamp = entry.timestamp or 0,
            unlocked = true
        }
        unlocked[entry.id] = achievement
        if gradeCounts[grade] then
            gradeCounts[grade] = gradeCounts[grade] + 1
        end
    end

    local entries = {}
    for id, definition in pairs(ACHIEVEMENTS) do
        local achievement = unlocked[id]
        if achievement then
            entries[#entries + 1] = achievement
            unlocked[id] = nil
        elseif not definition.secret then
            entries[#entries + 1] = {
                id = id,
                name = definition.name,
                description = definition.description,
                grade = definition.grade,
                secret = false,
                timestamp = 0,
                unlocked = false
            }
        end
    end

    for _, achievement in pairs(unlocked) do
        entries[#entries + 1] = achievement
    end

    local totalRegular = 0
    local totalSecret = 0
    for _, definition in pairs(ACHIEVEMENTS) do
        if definition.secret then
            totalSecret = totalSecret + 1
        else
            totalRegular = totalRegular + 1
        end
    end

    local unlockedRegular = 0
    local unlockedSecret = 0
    for _, achievement in ipairs(data.entries or {}) do
        local definition = ACHIEVEMENTS[achievement.id]
        if achievement.secret or (definition and definition.secret) then
            unlockedSecret = unlockedSecret + 1
        else
            unlockedRegular = unlockedRegular + 1
        end
    end
    unlockedSecret = data.secretsUnlocked or unlockedSecret

    local function updateProgress(widget, unlockedCount, totalCount)
        widget.value:setText(string.format('%d/%d', unlockedCount, totalCount))
        local availableWidth = math.max(widget:getWidth() - 2, 1)
        local fillWidth = totalCount > 0 and math.floor(availableWidth * unlockedCount / totalCount) or 0
        widget.fill:setWidth(math.max(fillWidth, 1))
        widget.fill:setVisible(unlockedCount > 0)
    end

    state.entries = entries
    updateAchievementCounters(data.points or 0, gradeCounts)
    updateProgress(UI.CharacterAchievements.regular, unlockedRegular, totalRegular)
    updateProgress(UI.CharacterAchievements.secret, unlockedSecret, totalSecret)
    renderCharacterAchievements()
end

local function renderCharacterTitles()
    local panel = UI.CharacterTitles
    local state = Cyclopedia.Character.Titles
    local list = panel.AvailableTitles.List
    list:destroyChildren()

    local currentTitle = tr('No title selected')
    local query = state.query:lower()
    local entries = {}
    for _, title in ipairs(state.entries) do
        if title.id == state.currentTitleId then
            currentTitle = title.name
        end

        local matchesFilter = state.filter == 'all'
            or (state.filter == 'permanent' and title.permanent)
            or (state.filter == 'temporary' and not title.permanent)
            or (state.filter == 'unlocked' and title.unlocked)
            or (state.filter == 'locked' and not title.unlocked)
        local matchesQuery = query == '' or title.name:lower():find(query, 1, true) ~= nil
        if matchesFilter and matchesQuery then
            entries[#entries + 1] = title
        end
    end

    table.sort(entries, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.id < b.id
    end)

    panel.CurrentTitle.Value:setText(currentTitle)
    panel.CurrentTitle.Clear:setEnabled(state.currentTitleId ~= 0)

    for _, data in ipairs(entries) do
        local widget = g_ui.createWidget('CharacterTitle', list)
        widget:setId(data.id)
        widget.Name:setText(data.name)
        widget:setTooltip(data.description)
        widget.permanentIcon = widget:recursiveGetChildById('Permanent')
        widget.unlockedIcon = widget:recursiveGetChildById('Unlocked')
        widget.permanentIcon:setImageSource(data.permanent and '/images/ui/icon-yes' or '/images/ui/icon-no')
        widget.unlockedIcon:setImageSource(data.unlocked and '/images/ui/icon-yes' or '/images/ui/icon-no')
        widget.Action:setVisible(data.unlocked)
        widget:setChecked(data.id == state.currentTitleId)
        widget.titleData = data
        function widget.Action:onClick()
            Cyclopedia.selectCharacterTitle(data.id)
        end
        function widget:onDoubleClick()
            if data.unlocked then
                Cyclopedia.selectCharacterTitle(data.id)
            end
            return true
        end
    end
end

function Cyclopedia.loadCharacterTitles()
    local state = Cyclopedia.Character.Titles
    state.entries = {}
    state.currentTitleId = 0
    state.filter = 'all'
    state.query = ''
    UI.CharacterTitles.AvailableTitles.Filters.SearchEdit:setText('')
    Cyclopedia.characterTitleFilter(UI.CharacterTitles.AvailableTitles.Filters.all)
    g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Titles)
    renderCharacterTitles()
end

function Cyclopedia.loadCharacterTitlesData(data)
    local state = Cyclopedia.Character.Titles
    state.currentTitleId = data.currentTitleId or 0
    state.entries = data.entries or {}
    renderCharacterTitles()
end

function Cyclopedia.characterTitleFilter(widget)
    local filters = UI.CharacterTitles.AvailableTitles.Filters
    for _, id in ipairs({ 'all', 'permanent', 'temporary', 'unlocked', 'locked' }) do
        filters[id]:setChecked(filters[id] == widget)
    end
    Cyclopedia.Character.Titles.filter = widget:getId()
    renderCharacterTitles()
end

function Cyclopedia.characterTitleSearch(text)
    Cyclopedia.Character.Titles.query = text or ''
    renderCharacterTitles()
end

function Cyclopedia.selectCharacterTitle(titleId)
    g_game.setCharacterTitle(titleId)
end

function Cyclopedia.characterItemListFilter(widget)
    local parent = widget:getParent()
    for i = 1, parent:getChildCount() do
        local child = parent:getChildByIndex(i)
        if child then
            child:setChecked(false)
        end
    end

    widget:setChecked(true)

    if widget:getId() == "list" then
        UI.CharacterItems.ListBase:setVisible(true)
        UI.CharacterItems.gridBase:setVisible(false)
    else
        UI.CharacterItems.ListBase:setVisible(false)
        UI.CharacterItems.gridBase:setVisible(true)
    end
end

function Cyclopedia.achievementFilter(widget)
    local parent = widget:getParent()
    for i = 1, parent:getChildCount() do
        local child = parent:getChildByIndex(i)
        if child then
            child:setChecked(child == widget)
        end
    end

    Cyclopedia.Character.Achievements.filter = widget:getId()
    renderCharacterAchievements()
end

function Cyclopedia.achievementSort(option)
    Cyclopedia.Character.Achievements.lastSort = option
    renderCharacterAchievements()
end

local function updateBattleResultsPagination(panel, data)
    local currentPage = math.max(1, data.currentPage or 1)
    local numberOfPages = math.max(1, data.numberOfPages or 1)

    panel.currentPage = currentPage
    panel.numberOfPages = numberOfPages
    panel.previous:setEnabled(currentPage > 1)
    panel.next:setEnabled(currentPage < numberOfPages)
    panel.pages:setText(string.format(tr('Page %d / %d'), currentPage, numberOfPages))
end

local battleResultStatusInfo = {
    [0] = {text = tr('Justified'), color = '#44ad25'},
    [1] = {text = tr('Unjustified'), color = '#d33c3c'},
    [2] = {text = tr('Guild War'), color = '#ff9854'}
}
function Cyclopedia.changeCharacterBattleResultsPage(infoType, offset)
    local panel
    if infoType == CyclopediaCharacterInfoTypes.RecentDeaths then
        panel = UI.RecentDeaths
    elseif infoType == CyclopediaCharacterInfoTypes.RecentPVPKills then
        panel = UI.RecentKills
    end

    if not panel then return end

    local currentPage = panel.currentPage or 1
    local numberOfPages = panel.numberOfPages or 1
    local requestedPage = math.max(1, math.min(numberOfPages, currentPage + offset))
    if requestedPage == currentPage then return end

    panel.previous:setEnabled(false)
    panel.next:setEnabled(false)
    g_game.requestCharacterInfo(0, infoType, 23, requestedPage)
end

function Cyclopedia.loadCharacterRecentKills(data)
    UI.RecentKills.ListBase.List:destroyChildren()
    updateBattleResultsPagination(UI.RecentKills, data)

    if #data > 0 then
        local color = "#484848"

        for i = 1, #data do
            local entry = data[i]
            local time = entry.timestamp
            local description = entry.description
            local status = entry.status
            local displayStatus = battleResultStatusInfo[status] or {text = tostring(status), color = '#c0c0c0'}
            local widget = g_ui.createWidget("CharacterKill", UI.RecentKills.ListBase.List)

            widget:setId(i)
            widget.date:setText(os.date("%Y-%m-%d, %H:%M:%S", time))
            widget.description:setText(description)
            widget.status:setText(displayStatus.text)
            widget.status:setColor(displayStatus.color)
            widget.color = color
            widget:setBackgroundColor(color)

            color = color == "#484848" and "#414141" or "#484848"

            function widget:onClick()
                local parent = widget:getParent()
                for y = 1, parent:getChildCount() do
                    local child = parent:getChildByIndex(y)
                    child:setChecked(false)
                    child.date:setOn(false)
                    child.description:setOn(false)
                    child.status:setOn(false)
                end

                self:setChecked(not self:isChecked())
            end

            function widget:onCheckChange()
                if self:isChecked() then
                    self:setBackgroundColor("#585858")
                else
                    self:setBackgroundColor(self.color)
                end

                self.date:setOn(not self:isOn())
                self.description:setOn(not self:isOn())
                self.status:setOn(not self:isOn())
            end

            if i == 1 then
                widget:setChecked(true)
            end
        end
    end
end

function Cyclopedia.loadCharacterRecentDeaths(data)

    UI.RecentDeaths.ListBase.List:destroyChildren()
    updateBattleResultsPagination(UI.RecentDeaths, data)

    if #data > 0 then
        local color = "#484848"

        for i = 1, #data do
            local entry = data[i]
            local widget = g_ui.createWidget("CharacterDeath", UI.RecentDeaths.ListBase.List)

            widget:setId(i)
            widget.date:setText(os.date("%Y-%m-%d, %H:%M:%S", entry.timestamp))
            widget.cause:setText(entry.cause)
            widget.color = color
            widget:setBackgroundColor(color)
            color = color == "#484848" and "#414141" or "#484848"

            function widget:onClick()
                local parent = widget:getParent()
                for y = 1, parent:getChildCount() do
                    local child = parent:getChildByIndex(y)
                    child:setChecked(false)
                    child.cause:setOn(false)
                    child.date:setOn(false)
                end

                self:setChecked(not self:isChecked())
            end

            function widget:onCheckChange()
                if self:isChecked() then
                    self:setBackgroundColor("#585858")
                else
                    self:setBackgroundColor(self.color)
                end

                self.cause:setOn(not self:isOn())
                self.date:setOn(not self:isOn())
            end

            if i == 1 then
                widget:setChecked(true)
            end
        end
    end
end

function Cyclopedia.loadCharacterCombatStats(data, mitigation, additionalSkillsArray, forgeSkillsArray,
    perfectShotDamageRanges, combatsArray, concoctionsArray)
    UI.CombatStats.attack.icon:setImageSource("/images/game/states/player-state-flags")
    UI.CombatStats.attack.icon:setImageClip((data.weaponElement * 9) .. ' 0 9 9')
    UI.CombatStats.attack.value:setText(data.weaponMaxHitChance)

    if data.weaponElementDamage > 0 then
        UI.CombatStats.converted.none:setVisible(false)
        UI.CombatStats.converted.value:setVisible(true)
        UI.CombatStats.converted.icon:setVisible(true)
        UI.CombatStats.converted.icon:setImageSource("/images/game/states/player-state-flags")
        UI.CombatStats.converted.icon:setImageClip((data.weaponElementType * 9) .. ' 0 9 9')
        UI.CombatStats.converted.value:setText(data.weaponElementDamage .. "%")
    else
        UI.CombatStats.converted.none:setVisible(true)
        UI.CombatStats.converted.value:setVisible(false)
        UI.CombatStats.converted.icon:setVisible(false)
    end

    UI.CombatStats.defence.value:setText(data.defense)
    UI.CombatStats.armor.value:setText(data.armor)
    UI.CombatStats.mitigation.value:setText(string.format("%.2f%%", mitigation))
    UI.CombatStats.blessings.value:setText(string.format("%d/8", data.haveBlessings))

    for i = 0, 6 do
        local id = "reduction_" .. i
        if UI.CombatStats[id] then
            UI.CombatStats[id]:destroy()
        end
    end
    UI.CombatStats.reductionNone:destroyChildren()

    if (next(combatsArray) == nil) then
        UI.CombatStats.reductionNone:setVisible(true)
    else
        UI.CombatStats.reductionNone:setVisible(true)
        for i = 1, #combatsArray do
            local widget = g_ui.createWidget("CharacterElementReduction", UI.CombatStats.reductionNone)
            widget:setId("reduction_" .. i)

            local element = Cyclopedia.clientCombat[combatsArray[i][1]]

            if element then
                widget.icon:setImageSource(element.path)
                widget.icon:setImageSize({
                    width = 9,
                    height = 9
                })
            else
                print(string.format("WARNING: Element not found for combat array index %d with key %s.", i, tostring(combatsArray[i][1])))
            end
            local valor = combatsArray[i][2]
            local porcentaje = valor / 100
            local diferencia = 65535 - valor
            local porcentaje_negativo = diferencia / 100
            local resultado
            if porcentaje <= porcentaje_negativo then
                resultado = string.format("+%.2f%%", porcentaje)
                widget.value:setColor("green")
            else
                resultado = string.format("-%.2f%%", porcentaje_negativo)
                widget.value:setColor("red")
            end
            widget.value:setText(resultado)
            if element  then
                widget.name:setText(element.id)
            end
            widget:setMarginLeft(13)
        end
    end

    -- concoctions
    UI.CombatStats.concoctionPanel:destroyChildren()
    if concoctionsArray or next(concoctionsArray) ~= nil then
        for i = 1, #concoctionsArray do
            local widget = g_ui.createWidget("CharacterGridItem", UI.CombatStats.concoctionPanel)
            local itemId = concoctionsArray[i][1]
            widget:setId("concoction_" .. itemId)
            widget.item:setItemId(itemId)
            widget.item:setVirtual(true)
            local minutes = concoctionsArray[i][2] / 60
            local itemName = widget.item:getItem():getMarketData().name
            widget.item:setTooltip(string.format("%s: %.0f minutes", itemName, minutes))
            widget.amount:setVisible(false)
        end
    end

    local skillsIndexes = {
        [Skill.CriticalChance] = 1,
        [Skill.CriticalDamage] = 2,
        [Skill.LifeLeechAmount] = 3,
        [Skill.ManaLeechAmount] = 4
    }

    -- Critical Chance
    local skillIndex = skillsIndexes[Skill.CriticalChance]
    local skill = additionalSkillsArray[skillIndex][2]
    UI.CombatStats.criticalChance.value:setText(string.format("%.2f%%", skill / 100))
    if skill > 0 then
        UI.CombatStats.criticalChance.value:setColor("#44AD25")
    else
        UI.CombatStats.criticalChance.value:setColor("#C0C0C0")
    end

    -- Critical Damage
    skillIndex = skillsIndexes[Skill.CriticalDamage]
    skill = additionalSkillsArray[skillIndex][2]
    UI.CombatStats.criticalDamage.value:setText(string.format("%.2f%%", skill / 100))
    if skill > 0 then
        UI.CombatStats.criticalDamage.value:setColor("#44AD25")
    else
        UI.CombatStats.criticalDamage.value:setColor("#C0C0C0")
    end

    -- Life Leech Amount
    skillIndex = skillsIndexes[Skill.LifeLeechAmount]
    skill = additionalSkillsArray[skillIndex][2]
    if skill > 0 then
        UI.CombatStats.lifeLeech.value:setColor("#44AD25")
        UI.CombatStats.lifeLeech.value:setText(string.format("%.2f%%", skill / 100))
    else
        UI.CombatStats.lifeLeech.value:setColor("#C0C0C0")
        UI.CombatStats.lifeLeech.value:setText(string.format("%d%%", skill))
    end

    -- Mana Leech Amount
    skillIndex = skillsIndexes[Skill.ManaLeechAmount]
    skill = additionalSkillsArray[skillIndex][2]
    if skill > 0 then
        UI.CombatStats.manaLeech.value:setColor("#44AD25")
        UI.CombatStats.manaLeech.value:setText(string.format("%.2f%%", skill / 100))
    else
        UI.CombatStats.manaLeech.value:setColor("#C0C0C0")
        UI.CombatStats.manaLeech.value:setText(string.format("%d%%", skill))
    end

    for i = 1, #forgeSkillsArray do
        local skillId = forgeSkillsArray[i][1]
        local id = "special_" .. skillId
        if UI.CombatStats[id] then
            UI.CombatStats[id]:destroy()
        end
    end

    local firstSpecial = true

    for i = 1, #forgeSkillsArray do
        local skillId = forgeSkillsArray[i][1]
        local percent = forgeSkillsArray[i][2]

        if percent > 0 then
            local widget = g_ui.createWidget("CharacterSkillBase", UI.CombatStats)
            widget:setId("special_" .. skillId)

            local specialName = {
                [13] = "Onslaught",
                [14] = "Ruse",
                [15] = "Momentum",
                [16] = "Transcendence"
            }

            if firstSpecial then
                widget:addAnchor(AnchorTop, "manaLeech", AnchorBottom)
                widget:addAnchor(AnchorLeft, "criticalHit", AnchorLeft)
                widget:addAnchor(AnchorRight, "parent", AnchorRight)
                widget:setMarginTop(5)
            else
                widget:addAnchor(AnchorTop, "prev", AnchorBottom)
                widget:addAnchor(AnchorLeft, "criticalHit", AnchorLeft)
                widget:addAnchor(AnchorRight, "parent", AnchorRight)
                widget:setMarginTop(0)
            end

            widget:setMarginLeft(0)

            local name = g_ui.createWidget("SkillNameLabel", widget)
            name:setText(specialName[skillId])
            name:setColor("#C0C0C0")

            local value = g_ui.createWidget("SkillValueLabel", widget)
            value:setText(string.format("%.2f%%", percent / 100))
            value:setColor("#C0C0C0")
            value:setMarginRight(2)
            value:setColor("#C0C0C0")
            firstSpecial = firstSpecial and false
        end
    end
end

function Cyclopedia.loadCharacterGeneralStats(data, skills)
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    local function format(value)
        local totalMinutes = value / 60
        local hours = math.floor(totalMinutes / 60)
        local minutes = math.floor(totalMinutes % 60)

        if hours < 10 then
            hours = "0" .. hours
        end

        if minutes < 10 then
            minutes = "0" .. minutes
        end

        return hours .. ":" .. minutes
    end

    Cyclopedia.setCharacterSkillValue("level", comma_value(data.level))

    local text = tr("You have %s percent to go ", 100 - data.levelPercent)
    Cyclopedia.setCharacterSkillPercent("level", data.levelPercent, text)
    Cyclopedia.setCharacterSkillValue("experience", comma_value(data.experience))

    local staminaMultiplier = data.staminaExpBonus > 0 and data.staminaExpBonus or 100
    local expGainRate = (data.baseExpGain + data.lowLevelExpBonus + data.XpBoostPercent) *
                            staminaMultiplier / 100
    local storeExpBonusTime = format(data.XpBoostBonusRemainingTime)
    local expGainRateTooltip = string.format(
        "Your current XP gain rate amounts to %d%%.\nYour XP gain rate is calculated as follows:\n- Base XP gain rate: %d%%",
        math.floor(expGainRate), data.baseExpGain)

    if data.XpBoostPercent > 0 then
        expGainRateTooltip = expGainRateTooltip ..
                                 string.format("\n- XP boost: +%d%% (%s h remaining)", data.XpBoostPercent,
                storeExpBonusTime)
    end

    if data.lowLevelExpBonus > 0 then
        expGainRateTooltip = expGainRateTooltip ..
                                 string.format("\n- Low level bonus: +%d%% (until level 50)",
                data.lowLevelExpBonus)
    end

    if staminaMultiplier ~= 100 then
        local staminaBonusMinutes = math.max(data.staminaMinutes - 2340, 0)
        local staminaBonusTime = string.format("%02d:%02d", math.floor(staminaBonusMinutes / 60),
            staminaBonusMinutes % 60)
        expGainRateTooltip = expGainRateTooltip ..
                                 string.format("\n- Stamina bonus: x%.1f (%s h remaining)",
                staminaMultiplier / 100, staminaBonusTime)
    end

    UI.CharacterStats.expGainRate:setTooltip(expGainRateTooltip)
    Cyclopedia.setCharacterSkillValue("expGainRate", comma_value(math.floor(expGainRate)) .. "%")
    Cyclopedia.setCharacterSkillValue("health", comma_value(data.maxHealth))
    Cyclopedia.setCharacterSkillValue("mana", comma_value(data.maxMana))
    Cyclopedia.setCharacterSkillValue("soul", data.soul)
    Cyclopedia.setCharacterSkillValue("capacity", comma_value(math.floor(data.freeCapacity)))
    Cyclopedia.setCharacterSkillValue("speed", comma_value(math.floor(data.speed)))
    Cyclopedia.setCharacterSkillBase("speed", data.speed, data.baseSpeed)
    Cyclopedia.setCharacterSkillValue("food", format(data.regenerationCondition))

    local function formatTime(time)
        local hours = math.floor(time / 60)
        local minutes = time % 60
        if minutes < 10 then
            minutes = "0" .. minutes
        end
        return hours, minutes
    end

    local staminaPercent = math.floor(100 * data.staminaMinutes / 2520)
    local staminaHours, staminaMinutes = formatTime(data.staminaMinutes)

    Cyclopedia.setCharacterSkillValue("stamina", staminaHours .. ":" .. staminaMinutes)

    if data.staminaMinutes > 2400 and g_game.getClientVersion() >= 1038 and player:isPremium() then
        local text = tr("You have %s hours and %s minutes left", staminaHours, staminaMinutes) .. "\n" ..
                         tr("Now you will gain 50%% more experience")

        Cyclopedia.setCharacterSkillPercent("stamina", staminaPercent, text, "green")
    elseif data.staminaMinutes > 2400 and g_game.getClientVersion() >= 1038 and not player:isPremium() then
        local text = tr("You have %s hours and %s minutes left", staminaHours, staminaMinutes) .. "\n" ..
                         tr(
                "You will not gain 50%% more experience because you aren't premium player, now you receive only 1x experience points")

        Cyclopedia.setCharacterSkillPercent("stamina", staminaPercent, text, "#89F013")
    elseif data.staminaMinutes <= 840 and data.staminaMinutes > 0 then
        local text = tr("You have %s hours and %s minutes left", staminaHours, staminaMinutes) .. "\n" ..
                         tr("You gain only 50%% experience and you don't may gain loot from monsters")

        Cyclopedia.setCharacterSkillPercent("stamina", staminaPercent, text, "red")
    elseif data.staminaMinutes == 0 then
        local text = tr("You have %s hours and %s minutes left", staminaHours, staminaMinutes) .. "\n" ..
                         tr("You don't may receive experience and loot from monsters")

        Cyclopedia.setCharacterSkillPercent("stamina", staminaPercent, text, "black")
    end

    local trainerHours, trainerMinutes = formatTime(data.offlineTrainingTime)
    local trainerPercent = 100 * data.offlineTrainingTime / 720

    Cyclopedia.setCharacterSkillValue("trainer", trainerHours .. ":" .. trainerMinutes)
    Cyclopedia.setCharacterSkillPercent("trainer", trainerPercent, tr("You have %s percent", trainerPercent))
    Cyclopedia.setCharacterSkillValue("magiclevel", data.magicLevel)
    Cyclopedia.setCharacterSkillPercent("magiclevel", data.magicLevelPercent / 100,
        tr("You have %s percent to go", 100 - data.magicLevelPercent / 100))
    Cyclopedia.setCharacterSkillBase("magiclevel", data.magicLevel, data.baseMagicLevel)

    for i = Skill.Fist + 1, Skill.Fishing + 1 do
        local skillLevel, baseSkill, skillPercent = unpack(skills[i])
        local skillId = "skillId" .. (i - 1)
        Cyclopedia.setCharacterSkillValue(skillId, skillLevel)
        Cyclopedia.setCharacterSkillPercent(skillId, skillPercent,
            tr("You have %s percent to go", 100 - skillPercent))
        Cyclopedia.setCharacterSkillBase(skillId, skillLevel, baseSkill)
    end
end

function Cyclopedia.setCharacterSkillValue(id, value, color)
    local skill = UI.CharacterStats:recursiveGetChildById(id)
    local widget = skill:getChildById("value")
    widget:setText(value)
    widget:setColor(color)
end

function Cyclopedia.setCharacterSkillPercent(id, percent, tooltip, color)
    local skill = UI.CharacterStats:recursiveGetChildById(id)
    local widget = skill:getChildById("percent")
    if widget then
        widget:setPercent(math.floor(percent))

        if tooltip then
            widget:setTooltip(tooltip)
        end

        if color then
            widget:setBackgroundColor(color)
        end
    end
end

function Cyclopedia.setCharacterSkillBase(id, value, baseValue)
    if baseValue <= 0 or value < 0 then
        return
    end

    local skill = UI.CharacterStats:recursiveGetChildById(id)
    local widget = skill:getChildById("value")

    if baseValue < value then
        widget:setColor("#44AD25")
        skill:setTooltip(baseValue .. " +" .. value - baseValue)
    elseif value < baseValue then
        widget:setColor("#b22222")
        skill:setTooltip(baseValue .. " " .. value - baseValue)
    else
        widget:setColor("#bbbbbb")
        skill:removeTooltip()
    end
end

function Cyclopedia.onBaseCharacterSkillChange(localPlayer, id, baseLevel)
    Cyclopedia.setCharacterSkillBase("skillId" .. id, localPlayer:getSkillLevel(id), baseLevel)
end

function Cyclopedia.onSkillChange(localPlayer, id, level, percent)
    Cyclopedia.setCharacterSkillValue("skillId" .. id, level)
    Cyclopedia.setCharacterSkillPercent("skillId" .. id, percent, tr("You have %s percent to go", 100 - percent))
    Cyclopedia.onBaseCharacterSkillChange(localPlayer, id, localPlayer:getSkillBaseLevel(id))
end

function Cyclopedia.selectCharacterPage()
    local selectedOption = UI.selectedOption
    UI[selectedOption]:setVisible(false)
    UI.InfoBase:setVisible(true)
    Cyclopedia.closeCharacterButtons()

    local oldOpen = UI.openedCategory
    if oldOpen ~= nil then
        close(oldOpen)
    end

    UI.selectedOption = "InfoBase"
end

function Cyclopedia.closeCharacterButtons()
    local size = UI.OptionsBase:getChildCount()
    for i = 1, size do
        local widget = UI.OptionsBase:getChildByIndex(i)
        if widget then
            if widget.subCategories ~= nil then
                for subId, _ in ipairs(widget.subCategories) do
                    local subWidget = widget:getChildById(subId)

                    if subWidget then
                        subWidget.Button:setChecked(false)
                        subWidget.Button.Arrow:setVisible(false)
                        subWidget.Button.Icon:setChecked(false)
                    end
                end
            else
                widget.Button:setChecked(false)
                widget.Button.Arrow:setVisible(false)
                widget.Button.Icon:setChecked(false)
            end
        end
    end
end

function Cyclopedia.configureCharacterCategories()
    UI.OptionsBase:destroyChildren()

    local buttons = {
        {
            text = "General Stats",
            icon = "/game_cyclopedia/images/character_icons/icon_generalstats",
            subCategories = function()
                local categories = {
                    {
                        text = "Character Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-overview",
                        open = "CharacterStats"
                    }
                }
                
                if g_game.getClientVersion() < 1410 then
                    table.insert(categories, {
                        text = "Combat Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-combatstats",
                        open = "CombatStats"
                    })
                else
                    table.insert(categories, {
                        text = "Offence Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-combatstats",
                        open = "OffenceStats"
                    })
                    table.insert(categories, {
                        text = "Defence Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-defence",
                        open = "DeffenceStats"
                    })
                    table.insert(categories, {
                        text = "Misc. Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-misc",
                        open = "MiscStats"
                    })
                end
                
                return categories
            end
        },
        {
            text = "Battle Results",
            icon = "/game_cyclopedia/images/character_icons/icon_battleresults",
            subCategories = {
                {
                    text = "Recent Deaths",
                    icon = "/game_cyclopedia/images/character_icons/icon-character-battleresults-recentdeaths",
                    open = "RecentDeaths"
                },
                {
                    text = "Recent PvP Kills",
                    icon = "/game_cyclopedia/images/character_icons/icon-character-battleresults-recentpvpkills",
                    open = "RecentKills"
                }
            }
        },
        {
            text = "Achievements",
            icon = "/game_cyclopedia/images/character_icons/icon_achievement",
            open = "CharacterAchievements"
        },
        {
            text = "Item Summary",
            icon = "/game_cyclopedia/images/character_icons/icon_items",
            open = "CharacterItems"
        },
        {
            text = "Appearances",
            icon = "/game_cyclopedia/images/character_icons/icon_outfitsmounts",
            open = "CharacterAppearances"
        },
        {
            text = "Store Summary",
            icon = "/game_cyclopedia/images/character_icons/icon-character-store",
            open = "StoreSummary"
        },
        {
            text = "Character Titles",
            icon = "/game_cyclopedia/images/character_icons/icon-character-titles",
            open = "CharacterTitles"
        }
    }

    for id, button in ipairs(buttons) do
        local widget = g_ui.createWidget("CharacterCategoryItem", UI.OptionsBase)
        widget:setId(id)
        widget.Button.Icon:setIcon(button.icon)
        widget.Button.Title:setText(button.text)

        if button.open ~= nil then
            widget.open = button.open
        end

        if button.subCategories ~= nil then
            local subCats = button.subCategories
            if type(subCats) == "function" then
                subCats = subCats()
            end
            
            widget.subCategories = subCats
            widget.subCategoriesSize = #subCats
            widget.Button.Arrow:setVisible(true)

            for subId, subButton in ipairs(subCats) do
                local subWidget = g_ui.createWidget("CharacterCategoryItem", widget)
                subWidget:setId(subId)
                subWidget.Button.Icon:setIcon(subButton.icon)
                subWidget.Button.Title:setText(subButton.text)
                subWidget:setVisible(false)
                subWidget.open = subButton.open

                function subWidget.Button:onClick(test)
                    local selectedOption = UI.selectedOption
                    Cyclopedia.closeCharacterButtons()
                    subWidget.Button:setChecked(true)
                    subWidget.Button.Arrow:setVisible(true)
                    subWidget.Button.Arrow:setImageSource("/game_cyclopedia/images/icon-arrow7x7-right")
                    subWidget.Button.Icon:setChecked(true)
                    UI[selectedOption]:setVisible(false)
                    UI[subWidget.open]:setVisible(true)

                    if subWidget.open == "CharacterStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.GeneralStats)
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Badges)
                    elseif subWidget.open == "CombatStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.CombatStats)
                    elseif subWidget.open == "OffenceStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Offencestats)
                    elseif subWidget.open == "DeffenceStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Defencestats)
                    elseif subWidget.open == "MiscStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Miscstats)
                    elseif subWidget.open == "RecentDeaths" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.RecentDeaths, 23, 1)
                    elseif subWidget.open == "RecentKills" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.RecentPVPKills, 23, 1)
                    end

                    UI.selectedOption = subWidget.open
                end

                if subId == 1 then
                    subWidget:addAnchor(AnchorTop, "parent", AnchorTop)
                    subWidget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
                    subWidget:setMarginTop(20)
                else
                    subWidget:addAnchor(AnchorTop, "prev", AnchorBottom)
                    subWidget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
                    subWidget:setMarginTop(-1)
                end
            end
        end

        if id == 1 then
            widget:addAnchor(AnchorTop, "parent", AnchorTop)
            widget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
            widget:setMarginTop(5)
        else
            widget:addAnchor(AnchorTop, "prev", AnchorBottom)
            widget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
            widget:setMarginTop(5)
        end

        function widget.Button.onClick(this)
            if widget.open == "CharacterAchievements" then
                Cyclopedia.loadCharacterAchievements()
            elseif widget.open == "CharacterTitles" then
                Cyclopedia.loadCharacterTitles()
            elseif widget.open == "CharacterItems" then
                g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.ItemSummary)
                Cyclopedia.characterItemListFilter(UI.CharacterItems.listFilter.list)
            elseif widget.open == "CharacterAppearances" then
                g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.OutfitsAndMounts)
            elseif widget.open == "StoreSummary" then
                g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.StoreSummary)
            end

            local parent = this:getParent()
            if parent.subCategoriesSize ~= nil then
                if parent.closedSize == nil then
                    parent.closedSize = parent:getHeight() / (parent.subCategoriesSize + 1) + 15
                end

                if parent.openedSize == nil then
                    parent.openedSize = parent:getHeight() * (parent.subCategoriesSize + 1) - 6
                end

                open(parent)
            else
                local oldOpen = UI.openedCategory
                local selectedOption = UI.selectedOption

                Cyclopedia.closeCharacterButtons()
                this.Arrow:setImageSource("/game_cyclopedia/images/icon-arrow7x7-right")
                this.Arrow:setVisible(true)

                if oldOpen ~= nil and oldOpen ~= parent then
                    close(oldOpen)
                end

                this:setChecked(true)
                this.Icon:setChecked(true)
                UI[selectedOption]:setVisible(false)
                UI[parent.open]:setVisible(true)
                UI.selectedOption = parent.open
            end
        end
    end
end

local function showCharacterInspection(name, descriptions, imbuements)
    local panel = UI.InfoBase
    panel.InspectLabel:setText(tr('You are inspecting') .. ': ' .. name)
    panel.InspectLabel:setTooltip(name)
    local list = panel.DetailsBase.List
    list:destroyChildren()
    for _, description in ipairs(descriptions or {}) do
        local row = g_ui.createWidget('CharacterInspectionDescription', list)
        row:setText(description.key .. ': ' .. description.value)
        row:setTooltip(description.key .. ': ' .. description.value)
        row:setHeight(math.max(22, row:getTextSize().height + 4))
    end
    panel.Imbuements:destroyChildren()
    for _, iconId in ipairs(imbuements or {}) do
        local icon = g_ui.createWidget('CharacterInspectionImbuement', panel.Imbuements)
        local path = '/images/game/imbuing/icons/' .. iconId
        if iconId > 0 and g_resources.fileExists(path .. '.png') then
            icon:setImageSource(path)
        end
    end
    panel.DetailsBase.ListScrollbar:setValue(0)
end

function Cyclopedia.loadCharacterInspection(data)
    if not UI or UI:isDestroyed() or not controllerCyclopedia.ui:isVisible() then return end
    UI.inspectionData = data
    UI.inspectionItems = {}
    local inventory = UI.InfoBase.inventoryPanel
    for slot = InventorySlotFirst, InventorySlotLast do
        local widget = inventory:getChildById('slot' .. slot)
        if widget then
            widget:setItem(nil)
            local style = Cyclopedia.InventorySlotStyles[slot]
            if style then widget:setIcon(style.icon) end
            widget:setBorderWidth(0)
            widget.onMousePress = function(self, _, button)
                if button == MouseLeftButton then
                    Cyclopedia.selectCharacterInspectionSlot(slot)
                    return true
                end
                return false
            end
        end
    end
    for _, entry in ipairs(data.inventoryItems) do
        local widget = inventory:getChildById('slot' .. entry.slot)
        if widget then
            UI.inspectionItems[entry.slot] = entry
            widget:setItem(entry.item)
            widget:setIcon('')
        end
    end
    UI.InfoBase.outfitPanel.Sprite:setOutfit(data.outfit)
    showCharacterInspection(data.playerName, data.playerDescriptions)
end

function Cyclopedia.selectCharacterInspectionSlot(slot)
    if not UI or UI:isDestroyed() or not UI.inspectionItems then return end
    local entry = UI.inspectionItems[slot]
    if not entry or not entry.item then return end
    for _, widget in ipairs(UI.InfoBase.inventoryPanel:getChildren()) do
        widget:setBorderWidth(0)
    end
    local widget = UI.InfoBase.inventoryPanel:getChildById('slot' .. slot)
    widget:setBorderWidth(1)
    widget:setBorderColor('white')
    showCharacterInspection(entry.name, entry.descriptions, entry.imbuements)
end

function Cyclopedia.createCharacterDescription(level, vocation, title)
    local list = UI.InfoBase.DetailsBase.List
    list:destroyChildren()

    local descriptions = {
        { label = tr('Level'), value = level },
        { label = tr('Vocation'), value = vocation }
    }
    if title and title ~= '' then
        descriptions[#descriptions + 1] = { label = tr('Character Title'), value = title }
    end

    for _, description in ipairs(descriptions) do
        local widget = g_ui.createWidget("CharacterInspectionDescription", list)
        widget:setText(string.format("%s: %s", description.label, description.value))
        widget:setColor("#C0C0C0")
        widget:setTextWrap(true)
    end
end

function Cyclopedia.characterButton(widget)
    if UI.inspectionData then
        for _, slot in ipairs(UI.InfoBase.inventoryPanel:getChildren()) do slot:setBorderWidth(0) end
        showCharacterInspection(UI.inspectionData.playerName, UI.inspectionData.playerDescriptions)
    end
    if widget.state == 1 then
        widget.state = 2
        widget:setImageSource("/game_cyclopedia/images/character/inspect-equipment")
        UI.InfoBase.inventoryPanel:setVisible(false)
        UI.InfoBase.outfitPanel:setVisible(true)
    else
        widget.state = 1
        widget:setImageSource("/game_cyclopedia/images/character/inspect-player")
        UI.InfoBase.inventoryPanel:setVisible(true)
        UI.InfoBase.outfitPanel:setVisible(false)
    end
end

function Cyclopedia.loadCharacterBadges(showAccountInformation, playerOnline, playerPremium, loyaltyTitle, badgesVector)
    UI.CharacterStats.ListBadge:destroyChildren()

    local playerOnlineStatus = "Offline"
    local playerOnlineStatusColor = "#ff0000"
    if playerOnline == 1 then
        playerOnlineStatus = "Online"
        playerOnlineStatusColor = "#00ff00"
    end

    local accountStatus = "Free"
    local accountStatusColor = "#ff0000"
    if playerPremium == 1 then
        accountStatus = "Premium"
        accountStatusColor = "#00ff00"
    end

    if not loyaltyTitle or loyaltyTitle == "" then
        loyaltyTitle = "None"
    end

    Cyclopedia.setCharacterSkillValue("accountStatus", accountStatus, accountStatusColor)
    Cyclopedia.setCharacterSkillValue("accountOnline", playerOnlineStatus, playerOnlineStatusColor)
    Cyclopedia.setCharacterSkillValue("loyaltyTitle", loyaltyTitle)

    for _, badge in ipairs(badgesVector) do
        local cell = g_ui.createWidget("CharacterBadge", UI.CharacterStats.ListBadge)
        if cell then
            cell:setImageClip(getImageClip(badge[1]))
            cell:setTooltip(badge[2])
        end
    end
end

function getImageClip(elementIndex)
    local elementSize = 64
    local elementsPerRow = 21
    local y = 0
    local x = (elementIndex - 1) * elementSize
    local imageClip = string.format("%d %d %d %d", x, y, elementSize, elementSize)
    return imageClip
end

local hirelingSkillNames = {
    [1001] = "Banker",
    [1002] = "Cooker",
    [1003] = "Steward",
    [1004] = "Trader"
}

local function formatStoreCount(value)
    return string.format("x%d", value)
end

function Cyclopedia.onParseCyclopediaStoreSummary(xpBoostTime, dailyRewardXpBoostTime, blessings, preySlotsUnlocked,
    preyWildcards, hasPermanentWeeklyTaskExpansion, instantRewards, hasCharmExpansion, hirelingsObtained, hirelingSkills, houseItems)

    local list = UI.StoreSummary.ListBase.List
    list.XPBoosts.RemainingStoreXPBoostTimeValue:setText(string.format("%02d:%02d",
        math.floor(xpBoostTime / 3600), math.floor((xpBoostTime % 3600) / 60)))
    list.XPBoosts.RemainingDailyRewardXPBoostTimeValue:setText(string.format("%02d:%02d",
        math.floor(dailyRewardXpBoostTime / 3600), math.floor((dailyRewardXpBoostTime % 3600) / 60)))

    local blessingsPanel = list.Blessings.PurchasedBlessings
    blessingsPanel:destroyChildren()
    list.Blessings.NoneLabel:setVisible(#blessings == 0)
    list.Blessings:setHeight(math.max(52, 32 + math.ceil(#blessings / 2) * 20))
    for _, blessing in ipairs(blessings) do
        local row = g_ui.createWidget('BlessCreate', blessingsPanel)
        row.text1:setText(blessing[1])
        row.text2:setText(formatStoreCount(blessing[2]))
    end

    list.preyPanel.PermanentPreySlotsValue:setText(formatStoreCount(preySlotsUnlocked))
    list.preyPanel.PreyWildcardsValue:setText(formatStoreCount(preyWildcards))
    list.taskBoard.permanentWeeklyTaskExpansionValue:setText(hasPermanentWeeklyTaskExpansion and tr('Yes') or tr('No'))
    list.dailyReward.InstantRewardAccessValue:setText(formatStoreCount(instantRewards))
    list.CharmPanel.CharmExpansionValue:setText(hasCharmExpansion and tr('Yes') or tr('No'))
    list.hirelings.PurchasedHirelingsValue:setText(formatStoreCount(hirelingsObtained))

    local jobs = {}
    for _, skillId in ipairs(hirelingSkills) do
        jobs[#jobs + 1] = hirelingSkillNames[skillId] or string.format("#%d", skillId)
    end
    list.hirelings.hirelingjobs:setText(tr('Hireling Jobs') .. ': ' .. (#jobs > 0 and table.concat(jobs, ', ') or tr('None')))
    list.hirelings.hirelingOutfits:setText(tr('Hireling Outfits') .. ': ' .. tr('None'))

    local houseItemsPanel = list.houseItems.PurchasedHouseItems
    houseItemsPanel:destroyChildren()
    list.houseItems.NoneLabel:setVisible(#houseItems == 0)
    list.houseItems:setHeight(math.max(52, 20 + math.ceil(#houseItems / 2) * 78))
    for _, item in ipairs(houseItems) do
        local row = g_ui.createWidget('RowStore2', houseItemsPanel)
        row.lblName:setText(string.format("%s (%s)", item[2], formatStoreCount(item[3])))
        local itemWidget = g_ui.createWidget('Item', row.image)
        itemWidget:setId(item[1])
        itemWidget:setItemId(item[1])
        itemWidget:fill('parent')
        row.lblPrice:setVisible(false)
    end
end
-- Mapping from HardcodedSkillIds (protocol 15.x) to display names
-- Used for extra damage/spell/healing skills from the server
local hardcodedSkillNames = {
    [1]  = "Magic Level",
    [6]  = "Shielding",
    [7]  = "Distance Fighting",
    [8]  = "Sword Fighting",
    [9]  = "Club Fighting",
    [10] = "Axe Fighting",
    [11] = "Fist Fighting",
    [13] = "Fishing"
}

local function getHardcodedSkillName(skillType)
    return hardcodedSkillNames[skillType] or "Fighting Skill"
end

local weaponSkillNames = {
    [0] = "Fist Fighting",
    [1] = "Club Fighting",
    [2] = "Sword Fighting",
    [3] = "Axe Fighting",
    [4] = "Distance Fighting",
    [5] = "Shielding",
    [6] = "Fishing",
    [7] = "Magic Level",
    [8] = "Critical Hits",
    [9] = "Life Leech",
    [10] = "Mana Leech"
}

local function getWeaponSkillName(skillType)
    if skillType == 6 then
        return "Shielding"
    end
    return weaponSkillNames[skillType] or "Fighting Skill"
end

local elementNames = {
    [0] = "Physical",
    [1] = "Fire",
    [2] = "Earth",
    [3] = "Energy",
    [4] = "Ice",
    [5] = "Holy",
    [6] = "Death",
    [7] = "Healing",
    [8] = "Drowning",
    [9] = "Life Drain",
    [10] = "Mana Drain",
    [11] = "Agony"
}

local function getElementName(id)
    return elementNames[id] or "Unknown"
end

-- Shared rendering function for Offence/Defence/Misc stat panels
-- combatTable: the element-to-info mapping table (e.g. clientCombat or Cyclopedia.clientCombat)
local function renderCharacterStat(stat, leftPanel, rightPanel, combatTable)
    local parent = stat.parent == "right" and rightPanel or leftPanel

    if stat.align == "center" then
        local widget = g_ui.createWidget("Label", parent)
        local valueText = stat.value
        if type(valueText) == "number" and stat.percent then
            local percentValue = math.floor(valueText * 10000) / 100
            local sign = percentValue > 0 and "+ " or ""
            valueText = sign .. percentValue .. "%"
        elseif type(valueText) == "number" then
            valueText = tostring(valueText)
        end
        widget:setText("   " .. valueText .. " " .. stat.name)
        widget:setTextOffset("29 0")
        widget:setHeight(16)
        return widget
    else
        local widget = g_ui.createWidget("CharacterSkillBase", parent)
        local nameLabel = g_ui.createWidget("SkillNameLabel", widget)
        nameLabel:setText(stat.name .. ":")

        if string.find(stat.name, "\n") then
            nameLabel:setTextWrap(true)
            nameLabel:setTextAutoResize(true)
            widget:setHeight(math.max(widget:getHeight(), nameLabel:getHeight() + 4))
        end

        local valueLabel = g_ui.createWidget("SkillValueLabel", widget)
        if stat.percent and type(stat.value) == "number" then
            local percentValue = math.floor(stat.value * 10000) / 100
            local sign = percentValue > 0 and "+ " or ""
            valueLabel:setText(sign .. percentValue .. "%")
        else
            valueLabel:setText(tostring(stat.value))
        end

        if stat.color then
            valueLabel:setColor(stat.color)
        end

        if stat.icon then
            valueLabel:setMarginRight(12)
            local icon = g_ui.createWidget("SkillCharacterIcon", widget)
            icon:setMarginTop(2)
            icon:addAnchor(AnchorRight, "parent", AnchorRight)
            local elementKey = stat.element or stat.weaponElement
            if elementKey and combatTable then
                local element = combatTable[elementKey]
                if element then
                    icon:setImageSource(element.path)
                    icon:setImageSize({ width = 9, height = 9 })
                end
            end
        end

        return widget
    end
end

local function renderAndSkipZeroStats(stats, leftPanel, rightPanel, combatTable)
    for _, stat in ipairs(stats) do
        if stat.align ~= "center" and type(stat.value) == "number" and stat.value == 0 then
            -- Skip stats with zero values (headers use "" which won't match)
        else
            renderCharacterStat(stat, leftPanel, rightPanel, combatTable)
        end
    end
end
    function Cyclopedia.onCyclopediaCharacterOffenceStats(data)
        -- TODO UI/UX , verticalScroll, add new stats
        local container = UI.OffenceStats.content.statsContainer
        local leftPanel = container.leftPanel
        local rightPanel = container.rightPanel
        
        rightPanel:destroyChildren()
        leftPanel:destroyChildren()

        -- Initial Stats List
        local stats = {
            -- Left Panel Items
            {name = "Flat Damage and Healing", value = data.flatDamage or 0, icon = false, percent = false},
            {name = "From Character Level",  value = data.flatDamageBase or 0, align = "center", percent = false, icon = false},
            {name = "From Wheel of Destiny",  value = data.flatDamageWheel or 0, align = "center", percent = false, icon = false},

            {name = "Attack Value", value = data.weaponAttack, icon = true, weaponElement = data.weaponElementType},
            {name = "From Flat Bonus", value = data.weaponFlatModifier or 0, align = "center", icon = false},
            {name = "From Magic Level", value = data.weaponDamage or 0, align = "center", icon = false},
            {name = "From Equipment", value = data.weaponSkillLevel or 0, align = "center", icon = false},
            {name = "From Offensive Tactics", value = data.weaponSkillModifier or 0, align = "center", icon = false},
    
            {name = "Converted Damage", value = data.weaponElementDamage, icon = true, weaponElement = data.weaponElementType, percent = true},

            {name = "Life Leech", value = data.lifeLeechTotal or data.lifeLeech or 0, icon = false, percent = true},
            {name = "From Equipment", value = data.lifeLeechEquipament or 0, align = "center", percent = true, icon = false},
            {name = "From Imbuement", value = data.lifeLeechImbuement or 0, align = "center", percent = true, icon = false},
            {name = "From Wheel of Destiny", value = data.lifeLeechWheel or 0, align = "center", percent = true, icon = false},
            {name = "From Event Bonus", value = data.lifeLeechEventBonus or 0, align = "center", percent = true, icon = false},

            {name = "Life Gain on Hit", value = data.lifeGainHit or 0, icon = false, percent = false},
            {name = "Life Gain on Kill", value = data.lifeGainKill or 0, icon = false, percent = false},

            {name = "Mana Leech", value = data.manaLeechTotal or data.manaLeech or 0, icon = false, percent = true},
            {name = "From Equipment", value = data.manaLeechEquipament or 0, align = "center", percent = true, icon = false},
            {name = "From Imbuement", value = data.manaLeechImbuement or 0, align = "center", percent = true, icon = false},
            {name = "From Wheel of Destiny", value = data.manaLeechWheel or 0, align = "center", percent = true, icon = false},
            {name = "From Event Bonus", value = data.manaLeechEventBonus or 0, align = "center", percent = true, icon = false},
    
            {name = "Mana Gain on Hit", value = data.manaGainHit or 0, icon = false, percent = false},
            {name = "Mana Gain on Kill", value = data.manaGainKill or 0, icon = false, percent = false},

            {name = "Onslaught", value = data.onslaught or 0, icon = false, percent = true},
            {name = "From Base", value = data.onslaughtBase or 0, align = "center", percent = true, icon = false},
            {name = "From Amplification", value = data.onslaughtBonus or 0, align = "center", percent = true, icon = false},
            {name = "From Event Bonus", value = data.onslaughtEventBonus or 0, align = "center", percent = true, icon = false},

            {name = "Damage against Specific Targets", value = "", icon = false, percent = false},
            {name = "against Powerful Foes", value = data.damagePowerfulFoes or 0, align = "center", percent = true, icon = false},
        }

        -- Dynamic Left/Mixed Panel Lists
        -- Dynamic target-specific damage entries from the server
        if data.damageSpecificTargets and #data.damageSpecificTargets > 0 then
            for _, target in ipairs(data.damageSpecificTargets) do
                table.insert(stats, {name = "against " .. (target.name or "Unknown"), value = target.value or 0, align = "center", percent = true, icon = false})
            end
        end

        if data.extraDamageSkills and #data.extraDamageSkills > 0 then
            table.insert(stats, {name = "Auto-Attack Extra Damage", value = "", icon = false, percent = false})
            for _, skill in ipairs(data.extraDamageSkills) do
                table.insert(stats, {name = "from " .. getHardcodedSkillName(skill.skillId), value = skill.valueA or 0, align = "center", percent = false, icon = false})
            end
        end

        if data.extraDamageSpells and #data.extraDamageSpells > 0 then
            table.insert(stats, {name = "Extra Spell Damage", value = "", icon = false, percent = false})
            for _, skill in ipairs(data.extraDamageSpells) do
                table.insert(stats, {name = "from " .. getHardcodedSkillName(skill.skillId), value = skill.valueA or 0, align = "center", percent = false, icon = false})
            end
        end

        if data.extraHealingSpells and #data.extraHealingSpells > 0 then
            table.insert(stats, {name = "Extra Spell Healing", value = "", icon = false, percent = false})
            for _, skill in ipairs(data.extraHealingSpells) do
                table.insert(stats, {name = "from " .. getHardcodedSkillName(skill.skillId), value = skill.valueA or 0, align = "center", percent = false, icon = false})
            end
        end

        -- Right Panel Items (Critical Hit Section)
        table.insert(stats, {name = "Critical Hit", parent = "right", value = "", icon = false})
        table.insert(stats, {name = "  Chance", parent = "right", value = data.critChanceTotal or data.critChance or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Flat Bonus", parent = "right", align = "center", value = data.critChanceFlat or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Equipment", parent = "right", align = "center", value = data.critChanceEquipament or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Imbuements", parent = "right", align = "center", value = data.critChanceImbuement or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Wheel of Destiny", parent = "right", align = "center", value = data.critChanceWheel or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Concoction", parent = "right", align = "center", value = data.critChanceConcoction or 0, percent = true, icon = false})
        
        -- Critical Chance by Type
        table.insert(stats, {name = "Critical Chance by Type", parent = "right", value = "", percent = false, icon = false})
        if data.damageElements and #data.damageElements > 0 then
             for _, el in ipairs(data.damageElements) do
                 table.insert(stats, {
                     name = "     from " .. getElementName(el.element),
                     parent = "right",
                     value = el.value,
                     align = "center",
                     percent = true,
                     icon = false
                 })
             end
        end
        table.insert(stats, {name = "     from Offensive Runes", parent = "right", value = data.offensiveRuneDamage or 0, align = "center", percent = true, icon = false})
        table.insert(stats, {name = "     from Auto Attack", parent = "right", value = data.autoAttackDamage or 0, align = "center", percent = true, icon = false})

        -- Critical Damage
        table.insert(stats, {name = "  Extra Damage", parent = "right", value = data.critDamageTotal or 0, icon = false, percent = true})
        table.insert(stats, {name = "     from Flat Bonus", parent = "right", align = "center", value = data.critDamageFlat or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Equipment", parent = "right", align = "center", value = data.critDamageEquipament or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Imbuements", parent = "right", align = "center", value = data.critDamageImbuement or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Wheel of Destiny", parent = "right", align = "center", value = data.critDamageWheel or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Concoction", parent = "right", align = "center", value = data.critDamageConcoction or 0, percent = true, icon = false})
        
        -- Critical Damage by Type
        table.insert(stats, {name = "Critical Damage by Type", parent = "right", value = "", percent = false, icon = false})
        if data.critDamageElements and #data.critDamageElements > 0 then
             for _, el in ipairs(data.critDamageElements) do
                 table.insert(stats, {
                     name = "     from " .. getElementName(el.element),
                     parent = "right",
                     value = el.value,
                     align = "center",
                     percent = true,
                     icon = false
                 })
             end
        end
        table.insert(stats, {name = "     from Offensive Runes", parent = "right", value = data.critDamageOffensiveRunes or 0, align = "center", percent = true, icon = false})
        table.insert(stats, {name = "     from Auto Attack", parent = "right", value = data.critDamageAutoAttack or 0, align = "center", percent = true, icon = false})

        -- Cleave & Distance
        table.insert(stats, {name = "Cleave", parent = "right", value = data.cleavePercent or 0, icon = false, percent = true})
        -- Distance Fighting Accuracy: render dynamically from parsed accuracy data
        if data.weaponAccuracy and #data.weaponAccuracy > 0 then
            table.insert(stats, {name = "Distance Fighting Accuracy", parent = "right", value = "", icon = false, percent = false})
            for _, acc in ipairs(data.weaponAccuracy) do
                table.insert(stats, {
                    name = "     Range " .. acc.range,
                    parent = "right",
                    value = acc.chance or 0,
                    align = "center",
                    percent = true,
                    icon = false
                })
            end
        end

        -- Perfect Shot
        if data.perfectShotDamage then
            for i = 1, #data.perfectShotDamage do
                if data.perfectShotDamage[i] and data.perfectShotDamage[i] > 0 then
                    if i == 1 then
                         table.insert(stats, {name = "Perfect Shot Damage Bonus", parent = "right", value = "", icon = false})
                    end
                    table.insert(stats, {
                        name = "     from Range " .. i, 
                        parent = "right", 
                        value = "+" .. data.perfectShotDamage[i], 
                        align = "center", 
                        icon = false
                    })
                end
            end
        end

        -- Target Specific & Armor Pen
        table.insert(stats, {name = "Damage Against Targets \nAbove 95% hit points", parent = "right", value = data.damageHighHp or 0, icon = false, percent = true})
        table.insert(stats, {name = "Damage Against Targets \nBelow 30% hit points", parent = "right", value = data.damageLowHp or 0, icon = false, percent = true})
        table.insert(stats, {name = "Armor Penetration", parent = "right", value = data.armorPenetration or 0, icon = false, percent = true})

        -- Elemental Pierce
        table.insert(stats, {name = "Elemental Pierce", parent = "right", value = "", icon = false, percent = true})
        if data.elementalPierce and #data.elementalPierce > 0 then
             for _, el in ipairs(data.elementalPierce) do
                 table.insert(stats, {
                     name = "     from " .. getElementName(el.element),
                     parent = "right",
                     value = el.value,
                     align = "center",
                     percent = true,
                     icon = false
                 })
             end
        end

        renderAndSkipZeroStats(stats, leftPanel, rightPanel, Cyclopedia.clientCombat)

        -- temp fix
        controllerCyclopedia:scheduleEvent(function()
            local height = math.max(leftPanel:getHeight() + leftPanel:getMarginTop(), rightPanel:getHeight() + rightPanel:getMarginTop())
            container:setHeight(height + 10)
        end, 50)
    end
    function Cyclopedia.onCyclopediaCharacterDefenceStats(data)
        UI.DeffenceStats.rightPanel:destroyChildren()
        UI.DeffenceStats.leftPanel:destroyChildren()
    
        local stats = {
            {name = "Defence Value", value = data.defense or 0, icon = false, percent = false},
            {name = "From Equipment", value = data.defenseEquipment or 0, align = "center", icon = false},
            {name = "From Wheel of Destiny", value = data.defenseWheel or 0, align = "center", icon = false},
            {name = "From " .. getWeaponSkillName(data.defenseSkillType), value = data.shieldingSkill or 0, align = "center", icon = false},
            
            {name = "Armor Value", value = data.armor or 0, icon = false, percent = false},
            {name = "Mantra Value", value = data.mantra or 0, icon = false, percent = false},
            
            {name = "Mitigation", value = data.mitigation or 0, icon = false, percent = true},
            {name = "From Defence", value = data.mitigationShield or 0, align = "center", percent = true, icon = false},
            {name = "From Base", value = data.mitigationBase or 0, align = "center", percent = true, icon = false},
            {name = "From Equipment", value = data.mitigationEquipment or 0, align = "center", percent = true, icon = false},
            {name = "From Wheel of Destiny", value = data.mitigationWheel or 0, align = "center", percent = true, icon = false},
            
            {name = "Dodge", value = data.dodgeTotal or 0, icon = false, percent = true},
            {name = "From Base", value = data.dodgeBase or 0, align = "center", percent = true, icon = false},
            {name = "From Amplification", value = data.dodgeBonus or 0, align = "center", percent = true, icon = false},
            {name = "From Event Bonus", value = data.dodgeEvent or 0, align = "center", percent = true, icon = false},
            {name = "From Wheel of Destiny", value = data.dodgeWheel or 0, align = "center", percent = true, icon = false},
            
            {name = "Magic Shield Capacity", value = data.magicShieldCapacity or 0, icon = false, percent = false},
            {name = "From Direct Bonus", value = data.magicShieldCapacityFlat or 0, align = "center", icon = false},
            {name = "From Percentage Bonus", value = data.magicShieldCapacityPercent or 0, align = "center", percent = true, icon = false},
            
            {name = "Damage Reflection Amount", value = data.reflectPhysical or 0, icon = false, percent = false},
            
            {name = "Damage Reduction", parent = "right", value = "", icon = false}
        }
        
        if data.resistances then
            for _, resistance in ipairs(data.resistances) do
                local elementInfo = Cyclopedia.clientCombat[resistance.element]
                if elementInfo then
                    local percentValue = resistance.value * 100
                    local color = "#FFFFFF"

                    if percentValue > 0 then
                        color = "#44AD25"
                    elseif percentValue < 0 then
                        color = "#FF9900"
                    end

                    local sign = percentValue >= 0 and "+" or ""
                    table.insert(stats, {
                        name = "     " .. elementInfo.id,
                        parent = "right",
                        value = sign .. string.format("%.2f", percentValue) .. "%",
                        percent = false,
                        element = resistance.element,
                        icon = true,
                        color = color
                    })
                end
            end
        end
        renderAndSkipZeroStats(stats, UI.DeffenceStats.leftPanel, UI.DeffenceStats.rightPanel, Cyclopedia.clientCombat)
    end

    local function formatCharacterEffectDuration(seconds)
        seconds = math.max(0, math.floor(seconds or 0))

        if seconds >= 86400 then
            local days = math.floor(seconds / 86400)
            local hours = math.floor(seconds % 86400 / 3600)
            return days .. "d", string.format("%dd %dh", days, hours)
        elseif seconds >= 3600 then
            local hours = math.floor(seconds / 3600)
            local minutes = math.floor(seconds % 3600 / 60)
            return hours .. "h", string.format("%dh %dm", hours, minutes)
        elseif seconds >= 60 then
            local minutes = math.floor(seconds / 60)
            local remainingSeconds = seconds % 60
            return minutes .. "m", string.format("%dm %ds", minutes, remainingSeconds)
        end

        return seconds .. "s", seconds .. "s"
    end
    function Cyclopedia.onCyclopediaCharacterMiscStats(data)
        if not UI or not UI.MiscStats then return end
        if not UI.MiscStats.miscStatsContent then return end

        local container = UI.MiscStats.miscStatsContent.miscStatsContainer
        if not container or not container.leftPanel or not container.rightPanel then return end

        local leftPanel = container.leftPanel
        local rightPanel = container.rightPanel

        if rightPanel.concoctions then rightPanel.concoctions:destroyChildren() end
        if rightPanel.cooldowns then rightPanel.cooldowns:destroyChildren() end
        leftPanel:destroyChildren()

        local stats = {
            -- Momentum
            {name = "Momentum", value = data.momentumTotal or 0, icon = false, percent = true},
            {name = "From Equipment", value = data.momentumBase or 0, align = "center", percent = true, icon = false},
            {name = "From Amplification", value = data.momentumBonus or 0, align = "center", percent = true, icon = false},
            {name = "From Wheel of Destiny", value = data.momentumWheel or 0, align = "center", percent = true, icon = false},
            {name = "From Event Bonus", value = data.momentumEvent or 0, align = "center", percent = true, icon = false},

            -- Transcendence
            {name = "Transcendence", value = data.transcendenceTotal or 0, icon = false, percent = true},
            {name = "From Equipment", value = data.transcendenceBase or 0, align = "center", percent = true, icon = false},
            {name = "From Amplification", value = data.transcendenceBonus or 0, align = "center", percent = true, icon = false},
            {name = "From Wheel of Destiny", value = data.transcendenceWheel or 0, align = "center", percent = true, icon = false},
            -- Amplification
            {name = "Amplification", value = data.amplificationTotal or 0, icon = false, percent = true},
            {name = "From Equipment", value = data.amplificationEquipment or 0, align = "center", percent = true, icon = false},
            {name = "From Event Bonus", value = data.amplificationEventBonus or 0, align = "center", percent = true, icon = false},
            {name = "Blessings", value = string.format("%d/%d", data.haveBlesses or 0, data.totalBlesses or 0), icon = false, percent = false}
        }

        local augmentTypes = {
            [1] = { name = "Mana Cost", percent = false, sign = "+" },
            [2] = { name = "Base Damage", percent = true, sign = "+" },
            [3] = { name = "Base Healing", percent = true, sign = "+" },
            [4] = { name = "Cooldown", percent = false, sign = "-", suffix = "s" },
            [5] = { name = "Critical Extra Damage", percent = true, sign = "+" },
            [6] = { name = "Life Leech", percent = true, sign = "+" },
            [7] = { name = "Mana Leech", percent = true, sign = "+" },
        }

        local function addAugments(augments, header)
            if not augments or #augments == 0 then return end
            table.insert(stats, {name = header, value = "", icon = false})
            for _, augment in ipairs(augments) do
                local spell = Spells.getSpellDataById(augment.spellId)
                local spellName = spell and spell.name or "Unknown Spell (" .. augment.spellId .. ")"
                table.insert(stats, {name = "     " .. spellName, value = "", align = "center", icon = false})
                
                local typeInfo = augmentTypes[augment.type] or { name = "Augment Type " .. augment.type, percent = false, sign = "+" }
                local valueText = augment.value
                if typeInfo.percent then
                    local percentValue = math.floor(augment.value * 10000) / 100
                    valueText = typeInfo.sign .. percentValue .. "%"
                else
                    valueText = typeInfo.sign .. string.format("%.1f", augment.value) .. (typeInfo.suffix or "")
                end
                
                table.insert(stats, {name = "          " .. valueText .. " " .. typeInfo.name, value = "", align = "center", icon = false})
            end
        end

        addAugments(data.weaponProficiencyAugments, "Weapon Proficiency Spell Augments")
        addAugments(data.wheelAugments, "Wheel of Destiny Spell Augments")
        addAugments(data.equippedAugments, "Equipment Spell Augments")



        renderAndSkipZeroStats(stats, leftPanel, rightPanel, Cyclopedia.clientCombat)

        -- Item grids (Concoctions)
        local hasConcoctions = data.concoctions and #data.concoctions > 0
        if rightPanel.activeConcoctions then rightPanel.activeConcoctions:setVisible(hasConcoctions) end
        if rightPanel.concoctions then rightPanel.concoctions:setVisible(hasConcoctions) end
        if hasConcoctions then
            for _, v in ipairs(data.concoctions) do
                local widget = g_ui.createWidget("CharacterEffectItem", rightPanel.concoctions)
                widget:setItemId(v.id)
                widget:setVirtual(true)
                widget:setShowCount(false)
                
                local itemName = "unknown item"
                local thing = g_things.getThingType(v.id, ThingCategoryItem)
                if thing then
                    local marketData = thing:getMarketData()
                    if marketData and marketData.name and marketData.name ~= "" then
                        itemName = marketData.name
                    end
                end
                
                local slotDuration, tooltipDuration = formatCharacterEffectDuration(v.duration)
                widget.duration:setText(slotDuration)
                
                widget:setTooltip(tr("%s: %s", itemName, tooltipDuration))
            end
        end

        -- Item grids (Foods -> cooldowns)
        local hasFoods = data.activeFoods and #data.activeFoods > 0
        if rightPanel.consumables then rightPanel.consumables:setVisible(hasFoods) end
        if rightPanel.cooldowns then rightPanel.cooldowns:setVisible(hasFoods) end

        if hasFoods then
            for _, v in ipairs(data.activeFoods) do
                local widget = g_ui.createWidget("CharacterEffectItem", rightPanel.cooldowns)
                widget:setItemId(v.id)
                widget:setVirtual(true)
                widget:setShowCount(false)
                local slotDuration, tooltipDuration = formatCharacterEffectDuration(v.duration)
                widget.duration:setText(slotDuration)

                local itemName = "unknown item"
                local thing = g_things.getThingType(v.id, ThingCategoryItem)
                if thing then
                    local marketData = thing:getMarketData()
                    if marketData and marketData.name and marketData.name ~= "" then
                        itemName = marketData.name
                    end
                end
              
                widget:setTooltip(tr("%s: %s", itemName, tooltipDuration))
            end
        end
        -- Update container height
        controllerCyclopedia:scheduleEvent(function()
            local height = math.max(leftPanel:getHeight() + leftPanel:getMarginTop(), rightPanel:getHeight() + rightPanel:getMarginTop())
            container:setHeight(height + 20)
        end, 50)
    end
