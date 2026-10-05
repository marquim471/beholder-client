local UI = nil

local STAGES = {
    CREATURES = 2,
    SEARCH = 4,
    CATEGORY = 1,
    CREATURE = 3
}

local storedRaceIDs = {}
Cyclopedia.storedTrackerData = Cyclopedia.storedTrackerData or {}
Cyclopedia.storedBosstiaryTrackerData = Cyclopedia.storedBosstiaryTrackerData or {}
local animusMasteryPoints = 0

local function copyTrackerEntry(entry)
    return {unpack(entry)}
end

local function setBestiaryTrackCheck(widget, checked)
    local originalCallback = widget.onCheckChange
    widget.onCheckChange = nil
    widget:setChecked(checked)
    widget.onCheckChange = originalCallback
    widget.bestiaryTrackerState = checked
end

local function addStoredRaceId(raceId)
    if not table.find(storedRaceIDs, raceId) then
        table.insert(storedRaceIDs, raceId)
    end
end

local function removeStoredRaceId(raceId)
    for index, storedRaceId in ipairs(storedRaceIDs) do
        if storedRaceId == raceId then
            table.remove(storedRaceIDs, index)
            return
        end
    end
end

function Cyclopedia.setBestiaryTrackerStatus(raceId, checked, trackerEntry, sendToServer)
    raceId = tonumber(raceId)
    if not raceId then
        return
    end

    Cyclopedia.storedTrackerData = Cyclopedia.storedTrackerData or {}

    local trackerData = {}
    for _, entry in ipairs(Cyclopedia.storedTrackerData) do
        if entry[1] ~= raceId then
            table.insert(trackerData, copyTrackerEntry(entry))
        end
    end

    if checked then
        addStoredRaceId(raceId)
        if trackerEntry then
            table.insert(trackerData, copyTrackerEntry(trackerEntry))
        end
    else
        removeStoredRaceId(raceId)
    end

    Cyclopedia.storedTrackerData = trackerData

    if trackerMiniWindow and Cyclopedia.onParseCyclopediaTracker then
        Cyclopedia.onParseCyclopediaTracker(0, trackerData)
    elseif trackerMiniWindow and trackerMiniWindow.contentsPanel and #trackerData == 0 then
        trackerMiniWindow.contentsPanel:destroyChildren()
    end

    if UI and UI.ListBase and UI.ListBase.CreatureInfo and UI.ListBase.CreatureInfo.LeftBase then
        local trackCheck = UI.ListBase.CreatureInfo.LeftBase.TrackCheck
        if trackCheck and tonumber(trackCheck.raceId) == raceId then
            setBestiaryTrackCheck(trackCheck, checked)
        end
    end

    if sendToServer ~= false then
        g_game.sendStatusTrackerBestiary(raceId, checked)
    end
end

function Cyclopedia.onBestiaryTrackCheckChange(widget)
    local raceId = tonumber(widget.raceId)
    if not raceId then
        return
    end

    local checked = widget:isChecked()
    if widget.bestiaryTrackerState == checked then
        return
    end

    widget.bestiaryTrackerState = checked
    Cyclopedia.setBestiaryTrackerStatus(raceId, checked, widget.trackerData, true)
end

function Cyclopedia.loadBestiaryOverview(name, creatures, animusMasteryPoints)
    if (name == "Result" or name == "") and #creatures > 0 then
        if #creatures == 1 then
            if Cyclopedia.pendingBestiaryDetailBackStage == STAGES.SEARCH then
                Cyclopedia.loadBestiarySearchCreatures(creatures)
            end

            Cyclopedia.openBestiaryCreatureDetail(creatures[1].id,
                Cyclopedia.pendingBestiaryDetailBackStage or Cyclopedia.Bestiary.Stage)
            Cyclopedia.pendingBestiaryDetailBackStage = nil
        else
        Cyclopedia.loadBestiarySearchCreatures(creatures)
        end
    else
        Cyclopedia.loadBestiaryCreatures(creatures)
    end

    if animusMasteryPoints and animusMasteryPoints > 0 then
        animusMasteryPoints = animusMasteryPoints
    end
end

local function setBestiaryCaption(widget, text)
    widget:setTextOverflowLength(0)
    widget:setText(text)
    widget:setTextOverflowCharacter(string.char(133))
    widget:removeTooltip()
    local captionLength = #text
    while widget:getTextSize().width > widget:getWidth() and captionLength > 1 do
        captionLength = captionLength - 1
        widget:setTextOverflowLength(captionLength)
    end
    if captionLength < #text then
        widget:setTooltip(text)
    end
end

local function getBestiaryCharmsPanel()
    if not UI or UI:isDestroyed() or g_game.getClientVersion() < 1410 then
        return nil
    end
    return UI.ListBase.CreatureInfo:getChildById("CharmsPanel")
end

function Cyclopedia.updateBestiaryCharms()
    local panel = getBestiaryCharmsPanel()
    if not panel or not UI.bestiaryCharmRaceId then
        return
    end

    local entries = UI.bestiaryCharms and UI.bestiaryCharms.charms or {}
    local slots = {panel.MajorCharmSlot, panel.MinorCharmSlot}
    local assigned = {}
    for _, entry in ipairs(entries) do
        local info = Cyclopedia.getCharmInfo(entry.id)
        if info and entry.asignedStatus and entry.raceId == UI.bestiaryCharmRaceId then
            assigned[info.category] = entry
        end
    end

    for index, slot in ipairs(slots) do
        local entry = assigned[index]
        slot.charmId = entry and entry.id or nil
        slot.Background:setVisible(not entry)
        slot.Grade:setVisible(entry ~= nil)
        slot.Icon:setVisible(entry ~= nil)
        slot.Backdrop:setVisible(entry ~= nil)
        slot.Selection:setVisible(UI.bestiaryCharmSlot == index)
        slot.Selection:setImageSource(entry and "/game_cyclopedia/images/charms/border/border_charmgrades" or "")
        slot.Selection:setBorderWidth(entry and 0 or 1)
        if entry then
            local info = Cyclopedia.getCharmInfo(entry.id)
            slot.Grade:setImageSource("/game_cyclopedia/images/charms/border/backdrop_charmgrade" .. entry.tier)
            slot.Icon:setImageClip((entry.id * 32) .. " 0 32 32")
            slot:setTooltip(info.name .. "\n\n" .. info.description)
        else
            slot:setTooltip(index == 1 and tr("Major Charm Slot") or tr("Minor Charm Slot"))
        end
    end

    local selector = panel.Selector
    local selectedOption = selector:getCurrentOption()
    local selectedId = selectedOption and selectedOption.data
    local onOptionChange = selector.onOptionChange
    selector.onOptionChange = nil
    selector:clearOptions()
    local selected = assigned[UI.bestiaryCharmSlot]
    panel.assignedCharm = selected
    if selected then
        selector:addOption(Cyclopedia.getCharmInfo(selected.id).name, selected.id)
    elseif UI.bestiaryCharmSlot then
        local options = {}
        local canAssign = UI.bestiaryCharms and (UI.bestiaryCharms.availableCharmSlots or 0) > 0 and
            table.find(UI.bestiaryCharms.finishedMonsters, UI.bestiaryCharmRaceId)
        if canAssign then
            for _, entry in ipairs(entries) do
                local info = Cyclopedia.getCharmInfo(entry.id)
                if info and info.category == UI.bestiaryCharmSlot and entry.tier > 0 and not entry.asignedStatus then
                    table.insert(options, {id = entry.id, name = info.name})
                end
            end
        end
        table.sort(options, function(a, b) return a.name:lower() < b.name:lower() end)
        for _, option in ipairs(options) do
            selector:addOption(option.name, option.id)
        end
        if #options == 0 then
            selector:addOption(UI.bestiaryCharmSlot == 1 and tr("No Major Charms usable") or
                tr("No Minor Charms usable"), -1)
        elseif selectedId then
            selector:setCurrentOptionByData(selectedId, true)
        end
    end
    selector.onOptionChange = onOptionChange
    selector:setEnabled(not selected and #selector.options > 0)
    panel.Cost:setVisible(selected ~= nil)
    panel.ActionButton:setText(selected and tr("Clear Charm") or tr("Assign Charm"))
    panel.ActionButton:setMarginTop(selected and 1 or 14)
    panel.ActionButton:removeTooltip()
    if selected then
        local player = g_game.getLocalPlayer()
        local canAfford = player and player:getTotalMoney() >= selected.removeRuneCost
        panel.Cost.Value:setText(Cyclopedia.formatGold(selected.removeRuneCost))
        panel.Cost.Value:setMarginLeft(math.floor((panel.Cost:getWidth() -
            panel.Cost.Value:getTextSize().width - panel.Cost.Icon:getWidth()) / 2) + 1)
        panel.Cost.Value:setColor(canAfford and "#c0c0c0" or "#d33c3c")
        panel.ActionButton:setEnabled(canAfford or false)
        if not canAfford then
            panel.ActionButton:setTooltip(tr("You do not have enough gold to clear this Charm."))
        end
    else
        selectedOption = selector:getCurrentOption()
        panel.ActionButton:setEnabled(selectedOption ~= nil and selectedOption.data ~= -1)
    end
end

function Cyclopedia.resetBestiaryCharms()
    if not getBestiaryCharmsPanel() then
        return
    end
    UI.bestiaryCharms = nil
    UI.bestiaryCharmSlot = nil
    Cyclopedia.updateBestiaryCharms()
    UI.bestiaryCharmRaceId = nil
    UI = nil
end

function Cyclopedia.loadBestiaryCharms(data)
    if not getBestiaryCharmsPanel() then
        return
    end
    UI.bestiaryCharms = data
    Cyclopedia.updateBestiaryCharms()
end

function Cyclopedia.selectBestiaryCharmSlot(slot)
    if not getBestiaryCharmsPanel() then
        return
    end
    UI.bestiaryCharmSlot = UI.bestiaryCharmSlot ~= slot and slot or nil
    Cyclopedia.updateBestiaryCharms()
end

function Cyclopedia.openBestiaryCharm(slot)
    if slot.charmId then
        Cyclopedia.Charms.redirect = slot.charmId
        Cyclopedia.openTab("charms")
    end
end

function Cyclopedia.actionBestiaryCharm()
    local panel = getBestiaryCharmsPanel()
    if not panel or not panel.ActionButton:isEnabled() then
        return
    end
    if panel.assignedCharm then
        Cyclopedia.clearCharm(panel.assignedCharm)
    else
        local option = panel.Selector:getCurrentOption()
        if option and option.data ~= -1 then
            Cyclopedia.confirmCharmAssignment({id = option.data, name = option.text}, UI.bestiaryCharmRaceId)
        end
    end
end

function showBestiary()
    UI = g_ui.loadUI("bestiary", contentContainer)
    UI:show()

    if g_game.getClientVersion() >= 1410 then
        local info = UI.ListBase.CreatureInfo
        for _, id in ipairs({"CharmBase", "CharmLabel", "SelectButton", "CharmSelector", "BalanceBase"}) do
            info[id]:hide()
        end
        info.ProgressBorder2:setMarginLeft(78)
        info.ProgressBorder2:setMarginTop(37)
        info.StarBase:setMarginTop(6)
        info.DiamondBase:setMarginTop(6)
        info.SubTextLabel:setMarginTop(4)
        info.BonusValue:setFont("verdana-bold-11px-native")
        info.BonusValue:setColor("#c0c0c0")
        info.BonusValue:setMarginLeft(6)
        info.IconsSep:removeAnchor(AnchorBottom)
        info.IconsSep:setHeight(73)
        info.IconsSep:setMarginTop(4)
        info.IconsSep:setMarginLeft(18)
        for i = 1, 5 do
            info["Icon" .. i]:setMarginLeft(3)
        end
        info.ItemsBase:removeAnchor(AnchorTop)
        info.ItemsBase:setHeight(178)
        info.LeftBase:addAnchor(AnchorBottom, "ItemsBase", AnchorTop)
        info.LeftBase:setMarginBottom(11)
        info.CharmsPanel:show()
        for _, slot in ipairs({info.CharmsPanel.MajorCharmSlot, info.CharmsPanel.MinorCharmSlot}) do
            slot.onMouseRelease = function(widget, mousePos, mouseButton)
                if mouseButton == MouseRightButton then
                    Cyclopedia.openBestiaryCharm(widget)
                    return true
                end
                return false
            end
        end
        local selector = info.CharmsPanel.Selector
        connect(selector, {onDestroy = function()
            local menu = g_ui.getRootWidget():getChildById(selector:getId() .. "PopupMenu")
            if menu then
                menu:destroy()
            end
        end})
        local onMousePress = selector.onMousePress
        selector.onMousePress = function(widget, mousePos, mouseButton)
            if mouseButton ~= MouseLeftButton then
                return false
            end
            local handled = onMousePress(widget, mousePos, mouseButton)
            local menu = g_ui.getRootWidget():getChildById(widget:getId() .. "PopupMenu")
            if menu then
                for index, row in ipairs(menu:getChildren()) do
                    row:setChecked(index == widget.currentIndex)
                    row.onHoverChange = function(option, hovered)
                        if hovered then
                            for _, other in ipairs(menu:getChildren()) do
                                other:setChecked(other == option)
                            end
                        end
                    end
                end
                widget.Arrow:setImageSource("/images/game/cyclopedia/charm-dropdown-pressed")
                connect(menu, {onDestroy = function()
                    if not widget:isDestroyed() then
                        widget.Arrow:setImageSource("/images/game/cyclopedia/charm-dropdown-idle")
                    end
                end})
            end
            return handled
        end
    end

    UI.ListBase.CategoryList:setVisible(true)
    UI.ListBase.CreatureList:setVisible(false)
    UI.ListBase.CreatureInfo:setVisible(false)

    Cyclopedia.Bestiary.Stage = STAGES.CATEGORY
    controllerCyclopedia.ui.CharmsBase:setVisible(true)
    controllerCyclopedia.ui.GoldBase:setVisible(true)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(true)
    controllerCyclopedia.ui.CharmsBase1410:setVisible(g_game.getClientVersion() >= 1410)
    Cyclopedia.onResourcesBalanceChange()
    
    Cyclopedia.initializeTrackerData()
    Cyclopedia.ensureStoredRaceIDsPopulated()

    -- Bind Enter key to search when SearchEdit is focused
    g_keyboard.bindKeyDown('Enter', function()
        if UI and UI:isVisible() and UI.SearchEdit:getText() ~= "" then
            Cyclopedia.BestiarySearch()
        end
    end, UI.SearchEdit)

    Cyclopedia.Bestiary.Page = 1
    g_game.requestBestiary()
end

Cyclopedia.Bestiary = {}
Cyclopedia.Bestiary.Stage = STAGES.CATEGORY
Cyclopedia.Bestiary.DetailBackStage = STAGES.CATEGORY

function Cyclopedia.SetBestiaryProgress(fit, firstBar, secondBar, thirdBar, killCount, firstGoal, secondGoal, thirdGoal)
    local function calculateWidth(value, max)
        return math.min(math.floor((value / max) * fit), fit)
    end

    local function setBarVisibility(bar, isVisible, width, isCompleted)
        isVisible = isVisible and width > 0
        bar:setVisible(isVisible)
        if isVisible then
            -- Use fill image only when bestiary is completed, otherwise use orange progress bar
            if isCompleted then
                bar:setImageRect({
                    height = 12,
                    x = 0,
                    y = 0,
                    width = width
                })
                bar:setImageSource("/game_cyclopedia/images/bestiary/fill")
            else
                -- For orange progress bar, set the widget width and use image as background
                bar:setWidth(width)
                bar:setImageSource("/game_cyclopedia/images/bestiary/progressbar-orange-small")
                -- Clear any image rect to use the full image as background
                bar:setImageRect({})
            end
        end
    end

    -- Check if bestiary is completed (reached final goal)
    local isCompleted = killCount >= thirdGoal

    local firstWidth = calculateWidth(math.min(killCount, firstGoal), firstGoal)
    setBarVisibility(firstBar, killCount > 0, firstWidth, isCompleted)

    local secondWidth = 0
    if killCount > firstGoal then
        secondWidth = calculateWidth(math.min(killCount - firstGoal, secondGoal - firstGoal), secondGoal - firstGoal)
    end
    setBarVisibility(secondBar, killCount > firstGoal, secondWidth, isCompleted)

    local thirdWidth = 0
    if killCount > secondGoal then
        thirdWidth = calculateWidth(math.min(killCount - secondGoal, thirdGoal - secondGoal), thirdGoal - secondGoal)
    end
    setBarVisibility(thirdBar, killCount > secondGoal, thirdWidth, isCompleted)
end

function Cyclopedia.SetBestiaryStars(value)
    UI.ListBase.CreatureInfo.StarFill:setWidth(math.max(0, math.min(value, 5) * 11 - 2))
end

function Cyclopedia.SetBestiaryDiamonds(value)
    UI.ListBase.CreatureInfo.DiamondFill:setWidth(math.max(0, math.min(value, 4) * 11 - 2))
end

function Cyclopedia.CreateCreatureItems(data)
    UI.ListBase.CreatureInfo.ItemsBase.Itemlist:destroyChildren()
    local itemsPerRow = 15
    local itemSlotSpacing = 36
    for index, _ in pairs(data) do
        local widget = g_ui.createWidget("BestiaryItemGroup", UI.ListBase.CreatureInfo.ItemsBase.Itemlist)
        widget:setId(index)
        local rowCount = math.max(1, math.ceil(#data[index] / itemsPerRow))
        local slotCount = rowCount * itemsPerRow
        widget:setHeight(45 + ((rowCount - 1) * itemSlotSpacing))
        widget.Title:breakAnchors()
        widget.Title:addAnchor(AnchorLeft, "parent", AnchorLeft)
        widget.Title:addAnchor(AnchorTop, "parent", AnchorTop)
        widget.Title:setMarginLeft(5)
        widget.Title:setMarginTop(16)

        if index == 0 then
            widget.Title:setText(tr("Common") .. ":")
        elseif index == 1 then
            widget.Title:setText(tr("Uncommon") .. ":")
        elseif index == 2 then
            widget.Title:setText(tr("Semi-Rare") .. ":")
        elseif index == 3 then
            widget.Title:setText(tr("Rare") .. ":")
        else
            widget.Title:setText(tr("Very Rare") .. ":")
        end

        local itemRows = {}
        local itemWidgets = {}
        for rowIndex = 1, rowCount do
            local row = g_ui.createWidget("UIWidget", widget.Items)
            row:setId("row" .. rowIndex)
            row:setHeight(34)
            row:addAnchor(AnchorLeft, "parent", AnchorLeft)
            row:addAnchor(AnchorRight, "parent", AnchorRight)

            if rowIndex == 1 then
                row:addAnchor(AnchorTop, "parent", AnchorTop)
                row:setMarginTop(5)
            else
                row:addAnchor(AnchorTop, "row" .. (rowIndex - 1), AnchorBottom)
                row:setMarginTop(2)
            end

            itemRows[rowIndex] = row
        end

        for i = 1, slotCount do
            local rowIndex = math.ceil(i / itemsPerRow)
            local item = g_ui.createWidget("BestiaryItem", itemRows[rowIndex])
            item:setId(i)
            itemWidgets[i] = item
        end

        for itemIndex, itemData in ipairs(data[index]) do
            local thing = g_things.getThingType(itemData.id, ThingCategoryItem)
            local itemWidget = itemWidgets[itemIndex]
            itemWidget:setItemId(itemData.id)
            itemWidget.id = itemData.id
            itemWidget.classification = thing:getClassification()

            if itemData.id == 0 then
                itemWidget.undefinedItem:setVisible(true)
            end

            if itemData.id > 0 then
                if itemData.stackable then
                    itemWidget.Stackable:setText("1+")
                else
                    itemWidget.Stackable:setText("1")
                end
            end

            ItemsDatabase.setRarityItem(itemWidget, itemWidget:getItem())

            itemWidget.onMouseRelease = onAddLootClick
        end
    end
end

local function updateBestiaryProgressBars(bars, kills, completed)
    local fillSource = "/game_cyclopedia/images/bestiary/progressbar-" ..
        (completed and "green" or "orange") .. "-large"
    for _, bar in ipairs(bars) do
        local maximum = math.max(bar[4] - bar[3], 1)
        local fraction = completed and 1 or math.min(math.max((kills - bar[3]) / maximum, 0), 1)
        local width = math.ceil((bar[1]:getWidth() - 2) * fraction - 0.5)
        bar[2]:setImageSource(fillSource)
        bar[2]:setWidth(width)
        bar[2]:setVisible(width > 0)
        bar[1]:setTooltip(string.format("%s / %s%s", Cyclopedia.formatGold(kills),
            Cyclopedia.formatGold(bar[4]), completed and " (fully unlocked)" or ""))
    end
end

local function updateBestiaryDetailProgress(data)
    local info = UI.ListBase.CreatureInfo
    local bars = {
        {info.ProgressBorder1, info.ProgressBack, 0, data.thirdDifficulty},
        {info.ProgressBorder2, info.ProgressBack33, data.thirdDifficulty, data.secondUnlock},
        {info.ProgressBorder3, info.ProgressBack55, data.secondUnlock, data.lastProgressKillCount}
    }
    updateBestiaryProgressBars(bars, data.killCounter, data.currentLevel >= 4)
    info.ProgressValue:setText(Cyclopedia.formatGold(data.killCounter))
end

function Cyclopedia.loadBestiarySelectedCreature(data)
    local occurence = {
        [0] = 1,
        2,
        3,
        4
    }

    local raceData = g_things.getRaceData(data.id)
    local formattedName = raceData.name:gsub("(%l)(%w*)", function(first, rest)
        return first:upper() .. rest
    end)

    if UI.bestiaryCharmRaceId ~= data.id then
        UI.bestiaryCharmSlot = nil
    end
    UI.bestiaryCharmRaceId = data.id
    Cyclopedia.updateBestiaryCharms()
    setBestiaryCaption(UI.ListBase.CreatureInfo.Caption, formattedName)
    Cyclopedia.SetBestiaryDiamonds(occurence[data.ocorrence])
    Cyclopedia.SetBestiaryStars(data.difficulty)
    UI.ListBase.CreatureInfo.LeftBase.Sprite:setOutfit(raceData.outfit)
    UI.ListBase.CreatureInfo.LeftBase.Sprite:getCreature():setStaticWalking(1000)

    updateBestiaryDetailProgress(data)

    UI.ListBase.CreatureInfo.LeftBase.TrackCheck.raceId = data.id
    UI.ListBase.CreatureInfo.LeftBase.TrackCheck.trackerData = {
        data.id,
        data.killCounter,
        data.thirdDifficulty,
        data.secondUnlock,
        data.lastProgressKillCount,
        1
    }

    -- TODO investigate when it can be track-- idk when
    --[[     if data.currentLevel == 1 then
        UI.ListBase.CreatureInfo.LeftBase.TrackCheck:enable()
    else
        UI.ListBase.CreatureInfo.LeftBase.TrackCheck:disable()
    end ]]

    Cyclopedia.ensureStoredRaceIDsPopulated()

    if table.find(storedRaceIDs, data.id) then
        setBestiaryTrackCheck(UI.ListBase.CreatureInfo.LeftBase.TrackCheck, true)
    else
        setBestiaryTrackCheck(UI.ListBase.CreatureInfo.LeftBase.TrackCheck, false)
    end

    if data.currentLevel > 1 then
        UI.ListBase.CreatureInfo.Value1:setText(data.maxHealth)
        UI.ListBase.CreatureInfo.Value2:setText(data.experience)
        UI.ListBase.CreatureInfo.Value3:setText(data.speed)
        UI.ListBase.CreatureInfo.Value4:setText(data.armor)
        UI.ListBase.CreatureInfo.Value5:setText(data.mitigation .. "%")
        UI.ListBase.CreatureInfo.BonusValue:setText(data.charmValue)
    else
        UI.ListBase.CreatureInfo.Value1:setText("?")
        UI.ListBase.CreatureInfo.Value2:setText("?")
        UI.ListBase.CreatureInfo.Value3:setText("?")
        UI.ListBase.CreatureInfo.Value4:setText("?")
        UI.ListBase.CreatureInfo.Value5:setText("?")
        UI.ListBase.CreatureInfo.BonusValue:setText("?")
    end

    local attackModes = {
        [0] = {icon = "melee", tooltip = tr("Creature attacks in melee range")},
        [1] = {icon = "ranged", tooltip = tr("Creature attacks from a distance")},
        [2] = {icon = "noattack", tooltip = tr("Creature does not attack")}
    }
    local attackMode = data.currentLevel > 1 and attackModes[data.attackMode]
    local attackIndicator = UI.ListBase.CreatureInfo.SubTextLabel
    attackIndicator:setText(attackMode and "" or "?")
    attackIndicator:setImageSource(attackMode and
        "/game_cyclopedia/images/bestiary/icons/monster-icon-" .. attackMode.icon or "")
    attackIndicator:setTooltip(attackMode and attackMode.tooltip or tr("Attack Range: Unknown"))

    local resists = {"PhysicalProgress", "FireProgress", "EarthProgress", "EnergyProgress", "IceProgress",
                     "HolyProgress", "DeathProgress", "HealingProgress"}

    for i = 1, 8 do
        local progress = UI.ListBase.CreatureInfo[resists[i]]
        local percent = data.combat and data.combat[i]
        progress.Fill:setVisible(percent ~= nil)
        if percent ~= nil then
            local combat = Cyclopedia.calculateCombatValues(percent)
            progress.Fill:setMarginRight(combat.margin)
            progress.Fill:setBackgroundColor(combat.color)
            progress:setTooltip(string.format("Sensitive to %s: %s", string.gsub(
                resists[i], "Progress", ""):lower(), combat.tooltip))
        else
            progress:setTooltip("?")
        end
    end

    local lootData = {}
    for _, value in ipairs(data.loot) do
        local loot = {
            name = value.name,
            id = value.itemId,
            type = value.type,
            difficulty = value.diffculty,
            stackable = value.stackable == 1 and true or false
        }

        if not lootData[value.diffculty] then
            lootData[value.diffculty] = {}
        end

        table.insert(lootData[value.diffculty], loot)
    end

    Cyclopedia.CreateCreatureItems(lootData)
    UI.ListBase.CreatureInfo.LocationField.Textlist.Text:setText(data.location)

    if data.AnimusMasteryPoints and data.AnimusMasteryPoints > 1 then
        UI.ListBase.CreatureInfo.AnimusMastery:setTooltip("The Animus Mastery for this creature is unlocked.\nIt yields "..(data.AnimusMasteryBonus / 10).."% bonus experience points, plus an additional 0.1% for every 10 Animus Masteries unlocked, up to a maximum of 4%.\nYou currently benefit from "..(data.AnimusMasteryBonus / 10).."% bonus experience points due to having unlocked ".. data.AnimusMasteryPoints .." Animus Masteries.")
        UI.ListBase.CreatureInfo.AnimusMastery:setVisible(true)
    else
        UI.ListBase.CreatureInfo.AnimusMastery:removeTooltip()
        UI.ListBase.CreatureInfo.AnimusMastery:setVisible(false)
    end
end

function Cyclopedia.ShowBestiaryCreature()
    Cyclopedia.Bestiary.Stage = STAGES.CREATURE
    Cyclopedia.onStageChange()
end

function Cyclopedia.openBestiaryCreatureDetail(raceId, backStage)
    raceId = tonumber(raceId)
    if not raceId then
        return false
    end

    Cyclopedia.Bestiary.DetailBackStage = backStage or Cyclopedia.Bestiary.Stage or STAGES.CATEGORY
    g_game.requestBestiarySearch(raceId)
    Cyclopedia.ShowBestiaryCreature()
    return true
end

function Cyclopedia.ShowBestiaryCreatures(Category)
    UI.ListBase.CreatureList:destroyChildren()
    UI.ListBase.CategoryList:setVisible(false)
    UI.ListBase.CreatureInfo:setVisible(false)
    UI.ListBase.CreatureList:setVisible(true)
    g_game.requestBestiaryOverview(Category, false, {})
end

function Cyclopedia.CreateBestiaryCategoryItem(Data)
    local widget = g_ui.createWidget("BestiaryCategory", UI.ListBase.CategoryList)
    setBestiaryCaption(widget.Caption, Data.name)
    widget.ClassBase:setIcon("/game_cyclopedia/images/bestiary/creatures/" .. Data.name:lower():gsub(" ", "_"))
    widget.Category = Data.name
    widget.TotalValue:setText(string.format("Total: %d", Data.amount))
    widget.KnownValue:setText(string.format("Known: %d", Data.know))

    function widget.ClassBase:onClick()
        UI.BackPageButton:setEnabled(true)
        Cyclopedia.ShowBestiaryCreatures(self:getParent().Category)
        Cyclopedia.Bestiary.Stage = STAGES.CREATURES
        Cyclopedia.onStageChange()
    end
end

function Cyclopedia.loadBestiarySearchCreatures(data)
    UI.ListBase.CategoryList:setVisible(false)
    UI.ListBase.CreatureInfo:setVisible(false)
    UI.ListBase.CreatureList:setVisible(true)
    UI.BackPageButton:setEnabled(true)

    Cyclopedia.Bestiary.Stage = STAGES.SEARCH
    Cyclopedia.onStageChange()
    Cyclopedia.Bestiary.Search = {}
    Cyclopedia.Bestiary.Page = Cyclopedia.Bestiary.Page or 1

    local maxCategoriesPerPage = 15
    Cyclopedia.Bestiary.TotalSearchPages = math.ceil(#data / maxCategoriesPerPage)

    if Cyclopedia.Bestiary.TotalSearchPages < 1 then
        Cyclopedia.Bestiary.TotalSearchPages = 1
    end

    if Cyclopedia.Bestiary.Page > Cyclopedia.Bestiary.TotalSearchPages then
        Cyclopedia.Bestiary.Page = Cyclopedia.Bestiary.TotalSearchPages
    end

    UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bestiary.Page, Cyclopedia.Bestiary.TotalSearchPages))

    local page = 1
    Cyclopedia.Bestiary.Search[page] = {}

    for i = 1, #data do
        if (i - 1) % maxCategoriesPerPage == 0 and i > 1 then
            page = page + 1
            Cyclopedia.Bestiary.Search[page] = {}
        end
        local creature = {
            id = data[i].id,
            currentLevel = data[i].currentLevel,
            AnimusMasteryBonus = data[i].creatureAnimusMasteryBonus or 0,
        }

        table.insert(Cyclopedia.Bestiary.Search[page], creature)
    end

    Cyclopedia.Bestiary.Stage = STAGES.SEARCH
    Cyclopedia.loadBestiaryCreature(Cyclopedia.Bestiary.Page, true)
    Cyclopedia.verifyBestiaryButtons()
end

function Cyclopedia.loadBestiaryCreatures(data)
    Cyclopedia.Bestiary.Creatures = {}
    Cyclopedia.Bestiary.Page = Cyclopedia.Bestiary.Page or 1

    local maxCategoriesPerPage = 15
    Cyclopedia.Bestiary.TotalCreaturesPages = math.ceil(#data / maxCategoriesPerPage)

    if Cyclopedia.Bestiary.TotalCreaturesPages < 1 then
        Cyclopedia.Bestiary.TotalCreaturesPages = 1
    end

    if Cyclopedia.Bestiary.Page > Cyclopedia.Bestiary.TotalCreaturesPages then
        Cyclopedia.Bestiary.Page = Cyclopedia.Bestiary.TotalCreaturesPages
    end

    UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bestiary.Page, Cyclopedia.Bestiary.TotalCreaturesPages))

    local page = 1
    Cyclopedia.Bestiary.Creatures[page] = {}

    for i = 1, #data do
        if (i - 1) % maxCategoriesPerPage == 0 and i > 1 then
            page = page + 1
            Cyclopedia.Bestiary.Creatures[page] = {}
        end

        local creature = {
            id = data[i].id,
            currentLevel = data[i].currentLevel,
            AnimusMasteryBonus = data[i].creatureAnimusMasteryBonus,

        }

        table.insert(Cyclopedia.Bestiary.Creatures[page], creature)
    end

    Cyclopedia.loadBestiaryCreature(Cyclopedia.Bestiary.Page, false)
    Cyclopedia.verifyBestiaryButtons()
end

-- note: this one needs refactor
-- expected result:
-- when a string is entered
-- the list should generate client-side
-- the list of search results that match the search string
-- looks identical to category view
function Cyclopedia.BestiarySearch()
    local text = UI.SearchEdit:getText()
    local raceList = g_things.getRacesByName(text)
    local list = {}
    for _, race in pairs(raceList) do
        list[#list + 1] = race.raceId
    end

    g_game.requestBestiaryOverview("Result", true, list)
    UI.SearchEdit:setText("")
end

function Cyclopedia.BestiarySearchText(text)
    if text ~= "" then
        UI.SearchButton:enable(true)
    else
        UI.SearchButton:disable(false)
    end
end

function Cyclopedia.CreateBestiaryCreaturesItem(data)
    local raceData = g_things.getRaceData(data.id)

    local widget = g_ui.createWidget("BestiaryCreature", UI.ListBase.CreatureList)
    widget:setId(data.id)

    local formattedName = raceData.name:gsub("(%l)(%w*)", function(first, rest)
        return first:upper() .. rest
    end)

    widget.Name:setText(formattedName)
    widget.Sprite:setOutfit(raceData.outfit)
    widget.Sprite:getCreature():setStaticWalking(1000)

    if data.AnimusMasteryBonus > 0 then
        widget.AnimusMastery:setTooltip("The Animus Mastery for this creature is unlocked.\nIt yields ".. data.AnimusMasteryBonus.. "% bonus experience points, plus an additional 0.1% for every 10 Animus Masteries unlocked, up to a maximum of 4%.\nYou currently benefit from ".. data.AnimusMasteryBonus.. "% bonus experience points due to having unlocked ".. animusMasteryPoints.." Animus Masteries.")
        widget.AnimusMastery:setVisible(true)
    else
        widget.AnimusMastery:removeTooltip()
        widget.AnimusMastery:setVisible(false)
    end

    if data.currentLevel >= 4 then
        widget.Finalized:setVisible(true)
        widget.KillsLabel:setVisible(false)
        widget.Sprite:getCreature():setShader("")
    else
        widget.Finalized:setVisible(false)
        widget.KillsLabel:setVisible(true)
        if data.currentLevel < 1 then
            widget.KillsLabel:setText("?")
            widget.Sprite:getCreature():setShader("Outfit - cyclopedia-black")
            widget.Name:setText("Unknown")
            widget.AnimusMastery:setVisible(false)
        else
            widget.KillsLabel:setText(string.format("%d / 3", data.currentLevel - 1))
            widget.Sprite:getCreature():setShader("")
        end
    end

    widget.ClassBase:setEnabled(data.currentLevel > 0)
    setBestiaryCaption(widget.Name, widget.Name:getText())

    function widget.ClassBase:onClick()
        if data.currentLevel < 1 then
            return
        end

        UI.BackPageButton:setEnabled(true)
        Cyclopedia.openBestiaryCreatureDetail(widget:getId(), Cyclopedia.Bestiary.Stage)
    end
end

function Cyclopedia.loadBestiaryCreature(page, search)
    local state = "Creatures"
    if search then
        state = "Search"
    end

    if not Cyclopedia.Bestiary[state][page] then
        return
    end

    UI.ListBase.CreatureList:destroyChildren()

    for _, data in ipairs(Cyclopedia.Bestiary[state][page]) do
        Cyclopedia.CreateBestiaryCreaturesItem(data)
    end
end

function Cyclopedia.loadBestiaryCategories(data)
    Cyclopedia.Bestiary.Categories = {}
    Cyclopedia.Bestiary.Page = 1

    local maxCategoriesPerPage = 15
    Cyclopedia.Bestiary.TotalCategoriesPages = math.ceil(#data / maxCategoriesPerPage)

    if UI == nil or UI.PageValue == nil then -- I know, don't change it
        return
    end

    UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bestiary.Page, Cyclopedia.Bestiary.TotalCategoriesPages))

    local page = 1
    Cyclopedia.Bestiary.Categories[page] = {}

    for i = 1, #data do
        if (i - 1) % maxCategoriesPerPage == 0 and i > 1 then
            page = page + 1
            Cyclopedia.Bestiary.Categories[page] = {}
        end

        local category = {
            name = data[i].bestClass,
            amount = data[i].count,
            know = data[i].unlockedCount,
            AnimusMasteryBonus = data[i].AnimusMasteryBonus,
        }

        table.insert(Cyclopedia.Bestiary.Categories[page], category)
    end

    Cyclopedia.loadBestiaryCategory(Cyclopedia.Bestiary.Page)
    Cyclopedia.verifyBestiaryButtons()
end

function Cyclopedia.loadBestiaryCategory(page)
    if not Cyclopedia.Bestiary.Categories[page] then
        return
    end

    UI.ListBase.CategoryList:destroyChildren()

    for _, data in ipairs(Cyclopedia.Bestiary.Categories[page]) do
        Cyclopedia.CreateBestiaryCategoryItem(data)
    end
end

function Cyclopedia.onStageChange()
    Cyclopedia.Bestiary.Page = 1

    if Cyclopedia.Bestiary.Stage == STAGES.CATEGORY then
        UI.BackPageButton:setEnabled(false)
        UI.ListBase.CategoryList:setVisible(true)
        UI.ListBase.CreatureList:setVisible(false)
        UI.ListBase.CreatureInfo:setVisible(false)
    end

    if Cyclopedia.Bestiary.Stage == STAGES.CREATURES then
        UI.BackPageButton:setEnabled(true)
        UI.ListBase.CategoryList:setVisible(false)
        UI.ListBase.CreatureList:setVisible(true)
        UI.ListBase.CreatureInfo:setVisible(false)

        function UI.BackPageButton.onClick()
            Cyclopedia.Bestiary.Stage = STAGES.CATEGORY
            Cyclopedia.onStageChange()
        end
    end

    if Cyclopedia.Bestiary.Stage == STAGES.SEARCH then
        UI.BackPageButton:setEnabled(true)
        UI.ListBase.CategoryList:setVisible(false)
        UI.ListBase.CreatureList:setVisible(true)
        UI.ListBase.CreatureInfo:setVisible(false)

        function UI.BackPageButton.onClick()
            Cyclopedia.Bestiary.Stage = STAGES.CATEGORY
            Cyclopedia.onStageChange()
        end
    end

    if Cyclopedia.Bestiary.Stage == STAGES.CREATURE then
        UI.BackPageButton:setEnabled(true)
        UI.ListBase.CategoryList:setVisible(false)
        UI.ListBase.CreatureList:setVisible(false)
        UI.ListBase.CreatureInfo:setVisible(true)

        function UI.BackPageButton.onClick()
            Cyclopedia.Bestiary.Stage = Cyclopedia.Bestiary.DetailBackStage or STAGES.CREATURES
            Cyclopedia.onStageChange()
        end
    end

    Cyclopedia.verifyBestiaryButtons()
end

function Cyclopedia.changeBestiaryPage(prev, next)
    if next then
        Cyclopedia.Bestiary.Page = Cyclopedia.Bestiary.Page + 1
    end

    if prev then
        Cyclopedia.Bestiary.Page = Cyclopedia.Bestiary.Page - 1
    end

    local stage = Cyclopedia.Bestiary.Stage
    if stage == STAGES.CATEGORY then
        Cyclopedia.loadBestiaryCategory(Cyclopedia.Bestiary.Page)
    elseif stage == STAGES.CREATURES then
        Cyclopedia.loadBestiaryCreature(Cyclopedia.Bestiary.Page, false)
    elseif stage == STAGES.SEARCH then
        Cyclopedia.loadBestiaryCreature(Cyclopedia.Bestiary.Page, true)
    end

    Cyclopedia.verifyBestiaryButtons()
end

function Cyclopedia.verifyBestiaryButtons()
    local function updateButtonState(button, condition)
        if condition then
            button:enable()
        else
            button:disable()
        end
    end

    local function updatePageValue(currentPage, totalPages)
        UI.PageValue:setText(string.format("%d / %d", currentPage, totalPages))
    end

    updateButtonState(UI.SearchButton, UI.SearchEdit:getText() ~= "")

    local stage = Cyclopedia.Bestiary.Stage
    local totalSearchPages = Cyclopedia.Bestiary.TotalSearchPages
    local page = Cyclopedia.Bestiary.Page
    if stage == STAGES.SEARCH and totalSearchPages then
        local totalPages = totalSearchPages
        updateButtonState(UI.PrevPageButton, page > 1)
        updateButtonState(UI.NextPageButton, page < totalPages)
        updatePageValue(page, totalPages)
        return
    end

    if stage == STAGES.CREATURE then
        UI.PrevPageButton:disable()
        UI.NextPageButton:disable()
        updatePageValue(1, 1)
        return
    end

    local totalCategoriesPages = Cyclopedia.Bestiary.TotalCategoriesPages
    local totalCreaturesPages = Cyclopedia.Bestiary.TotalCreaturesPages
    if stage == STAGES.CATEGORY and totalCategoriesPages or stage == STAGES.CREATURES and totalCreaturesPages then
        local totalPages = stage == STAGES.CATEGORY and totalCategoriesPages or totalCreaturesPages
        updateButtonState(UI.PrevPageButton, page > 1)
        updateButtonState(UI.NextPageButton, page < totalPages)
        updatePageValue(page, totalPages)
    end
end

--[[
===================================================
=                     Tracker                     =
===================================================
]]

function Cyclopedia.refreshBestiaryTracker()
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end

    Cyclopedia.initializeTrackerData()

    if trackerMiniWindow and trackerMiniWindow.contentsPanel then
        Cyclopedia.onParseCyclopediaTracker(0, Cyclopedia.storedTrackerData)
    end
    g_game.requestBestiary()
end

function Cyclopedia.refreshBosstiaryTracker()
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end

    Cyclopedia.initializeTrackerData()

    if trackerMiniWindowBosstiary and trackerMiniWindowBosstiary.contentsPanel then
        trackerMiniWindowBosstiary.contentsPanel:destroyChildren()
    end

    -- Bosstiary tracker state comes from BosstiaryInfo, not the bestiary request.
    Cyclopedia.BosstiaryTrackerPending = true
    g_game.requestBosstiaryInfo()
end

function Cyclopedia.openTrackedCreature(trackerType, raceId)
    raceId = tonumber(raceId)
    if not raceId then
        return false
    end

    if trackerType == 1 then
        Cyclopedia.pendingBosstiaryRaceId = raceId
        if not Cyclopedia.openTab or not Cyclopedia.openTab("bosstiary") then
            return false
        end

        if Cyclopedia.focusBosstiaryRace then
            Cyclopedia.focusBosstiaryRace(raceId)
        end
        return true
    end

    if not Cyclopedia.openTab or not Cyclopedia.openTab("bestiary") then
        return false
    end

    Cyclopedia.pendingBestiaryDetailBackStage = STAGES.SEARCH
    g_game.requestBestiaryOverview("Result", true, {raceId})
    return true
end

function Cyclopedia.scheduleBosstiaryTrackerRetry(delay)
    if Cyclopedia.BosstiaryTrackerRetryScheduled then
        return
    end

    Cyclopedia.BosstiaryTrackerRetryScheduled = true
    scheduleEvent(function()
        Cyclopedia.BosstiaryTrackerRetryScheduled = false

        if trackerMiniWindowBosstiary and trackerMiniWindowBosstiary:isVisible() and Cyclopedia.BosstiaryTrackerPending then
            Cyclopedia.refreshBosstiaryTracker()
        end
    end, delay or 1000)
end

function Cyclopedia.toggleBestiaryTracker()
    if not trackerMiniWindow then
        return
    end

    if trackerButton:isOn() then
        trackerMiniWindow:close()
        trackerButton:setOn(false)
    else
        if not trackerMiniWindow:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(trackerMiniWindow,
            trackerMiniWindow:getMinimumHeight())
            if not panel then
                return
            end
            panel:addChild(trackerMiniWindow)
        end

        trackerMiniWindow:open()
    end
end

function Cyclopedia.toggleBosstiaryTracker()
    if not trackerMiniWindowBosstiary then
        return
    end

    if trackerButtonBosstiary:isOn() then
        trackerMiniWindowBosstiary:close()
        trackerButtonBosstiary:setOn(false)
    else
        if not trackerMiniWindowBosstiary:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(trackerMiniWindowBosstiary,
            trackerMiniWindowBosstiary:getMinimumHeight())
            if not panel then
                return
            end
            panel:addChild(trackerMiniWindowBosstiary)
        end

        trackerMiniWindowBosstiary:open()
    end
end

function Cyclopedia.onTrackerClose(temp)
end

function Cyclopedia.setBarPercent(widget, percent)
    if percent > 92 then
        widget.killsBar:setBackgroundColor("#00BC00")
    elseif percent > 60 then
        widget.killsBar:setBackgroundColor("#50A150")
    elseif percent > 30 then
        widget.killsBar:setBackgroundColor("#A1A100")
    elseif percent > 8 then
        widget.killsBar:setBackgroundColor("#BF0A0A")
    elseif percent > 3 then
        widget.killsBar:setBackgroundColor("#910F0F")
    else
        widget.killsBar:setBackgroundColor("#850C0C")
    end

    widget.killsBar:setPercent(percent)
end

function Cyclopedia.onParseCyclopediaTracker(trackerType, data)
    if not data then
        return
    end

    local isBoss = trackerType == 1
    local window = isBoss and trackerMiniWindowBosstiary or trackerMiniWindow

    if isBoss and Cyclopedia.mergeBosstiaryTrackerOverrides and not Cyclopedia.BosstiaryTrackerLocalRender then
        data = Cyclopedia.mergeBosstiaryTrackerOverrides(data)
    end

    if isBoss then
        Cyclopedia.BosstiaryTrackerPending = false
        Cyclopedia.storedBosstiaryTrackerData = data
    else
        Cyclopedia.storedTrackerData = data
        -- Keep checkbox state available even when the miniwindow is still closed.
        storedRaceIDs = {}
        for _, entry in ipairs(data) do
            addStoredRaceId(entry[1])
        end
    end

    if #data == 0 then
        if window and window.contentsPanel then
            window.contentsPanel:destroyChildren()
        end
        return
    end

    if not window or not window.contentsPanel then
        return
    end

    window.contentsPanel:destroyChildren()

    local trackerTypeStr = isBoss and "bosstiary" or "bestiary"
    data = Cyclopedia.sortTrackerData(data, trackerTypeStr)

    for _, entry in ipairs(data) do
        local raceId, kills, uno, dos, maxKills = unpack(entry)
        
        local raceData = g_things.getRaceData(raceId)
        local name = raceData.name

        local widget = g_ui.createWidget("TrackerButton", window.contentsPanel)
        widget:setId(raceId)
        widget.trackerType = trackerType
        widget.creature:setOutfit(raceData.outfit)
        widget.kills:setText(Cyclopedia.formatGold(kills))
        local function updateLayout()
            local available = math.max(widget:getWidth() - 2, 0)
            local first = math.floor(available / 3 + 0.5)
            local second = math.floor(available * 2 / 3 + 0.5)
            widget.ProgressBorder1:setWidth(first)
            widget.ProgressBorder2:setWidth(second - first)
            widget.ProgressBorder3:setWidth(available - second)
            setBestiaryCaption(widget.label, name)
            updateBestiaryProgressBars({
                {widget.ProgressBorder1, widget.killsBar2, 0, uno},
                {widget.ProgressBorder2, widget.ProgressBack33, uno, dos},
                {widget.ProgressBorder3, widget.ProgressBack55, dos, maxKills}
            }, kills, kills >= maxKills)
        end
        widget.onGeometryChange = updateLayout
        widget.label.onGeometryChange = function() setBestiaryCaption(widget.label, name) end
        updateLayout()

        bindTrackerWidgetClicks(widget.creature, widget)
        bindTrackerWidgetClicks(widget.spacer, widget)
        bindTrackerWidgetClicks(widget.label, widget)
        bindTrackerWidgetClicks(widget.kills, widget)
    end
end

local BESTIATYTRACKER_FILTERS = {
    ["sortByName"] = false,
    ["ShortByPercentage"] = false,
    ["sortByKills"] = true,
    ["sortByAscending"] = true,
    ["sortByDescending"] = false
}

local BOSSTIARYTRACKER_FILTERS = {
    ["sortByName"] = false,
    ["ShortByPercentage"] = false,
    ["sortByKills"] = true,
    ["sortByAscending"] = true,
    ["sortByDescending"] = false
}

function Cyclopedia.loadTrackerFilters(trackerType)
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        local defaultFilters = trackerType == "bosstiary" and BOSSTIARYTRACKER_FILTERS or BESTIATYTRACKER_FILTERS
        return defaultFilters
    end
    
    local filterKey = trackerType == "bosstiary" and "bosstiaryTracker" or "bestiaryTracker"
    local charFilterKey = string.format("%s_%s", filterKey, char)
    local defaultFilters = trackerType == "bosstiary" and BOSSTIARYTRACKER_FILTERS or BESTIATYTRACKER_FILTERS
    
    local settings = g_settings.getNode(charFilterKey)
    if not settings or not settings['filters'] then
        -- Save default filters for first time use
        g_settings.mergeNode(charFilterKey, {
            ['filters'] = defaultFilters,
            ['character'] = char
        })
        return defaultFilters
    end
    return settings['filters']
end

function Cyclopedia.saveTrackerFilters(trackerType)
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end
    
    local filterKey = trackerType == "bosstiary" and "bosstiaryTracker" or "bestiaryTracker"
    local charFilterKey = string.format("%s_%s", filterKey, char)
    
    g_settings.mergeNode(charFilterKey, {
        ['filters'] = Cyclopedia.loadTrackerFilters(trackerType),
        ['character'] = char
    })
end

function Cyclopedia.initializeTrackerData()
    Cyclopedia.storedTrackerData = Cyclopedia.storedTrackerData or {}
    Cyclopedia.storedBosstiaryTrackerData = Cyclopedia.storedBosstiaryTrackerData or {}
end

function Cyclopedia.ensureStoredRaceIDsPopulated()
    Cyclopedia.initializeTrackerData()

    storedRaceIDs = {}
    for _, entry in ipairs(Cyclopedia.storedTrackerData) do
        addStoredRaceId(entry[1])
    end
end

function Cyclopedia.clearTrackerDataForCharacterChange()
    Cyclopedia.storedTrackerData = {}
    Cyclopedia.storedBosstiaryTrackerData = {}
    Cyclopedia.BosstiaryTrackerPending = false
    Cyclopedia.BosstiaryTrackerRetryScheduled = false
    storedRaceIDs = {}

    if trackerMiniWindow and trackerMiniWindow.contentsPanel then
        trackerMiniWindow.contentsPanel:destroyChildren()
    end
    if trackerMiniWindowBosstiary and trackerMiniWindowBosstiary.contentsPanel then
        trackerMiniWindowBosstiary.contentsPanel:destroyChildren()
    end
end

function Cyclopedia.getTrackerFilter(trackerType, filter)
    return Cyclopedia.loadTrackerFilters(trackerType)[filter] or false
end

function Cyclopedia.setTrackerFilter(trackerType, filter, value)
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end
    
    local filterKey = trackerType == "bosstiary" and "bosstiaryTracker" or "bestiaryTracker"
    local charFilterKey = string.format("%s_%s", filterKey, char)
    local filters = Cyclopedia.loadTrackerFilters(trackerType)
    
    -- Handle mutual exclusion for sorting methods
    if filter == "sortByName" or filter == "ShortByPercentage" or filter == "sortByKills" then
        filters["sortByName"] = false
        filters["ShortByPercentage"] = false
        filters["sortByKills"] = false
        filters[filter] = true
    -- Handle mutual exclusion for sorting direction
    elseif filter == "sortByAscending" or filter == "sortByDescending" then
        filters["sortByAscending"] = false
        filters["sortByDescending"] = false
        filters[filter] = true
    else
        filters[filter] = value
    end
    
    g_settings.mergeNode(charFilterKey, {
        ['filters'] = filters,
        ['character'] = char
    })
    
    -- Refresh the tracker display
    Cyclopedia.refreshTracker(trackerType)
end

function Cyclopedia.refreshTracker(trackerType)
    if trackerType == "bosstiary" then
        if trackerMiniWindowBosstiary and Cyclopedia.storedBosstiaryTrackerData and not Cyclopedia.BosstiaryTrackerPending then
            Cyclopedia.onParseCyclopediaTracker(1, Cyclopedia.storedBosstiaryTrackerData)
        end
    else
        if trackerMiniWindow and Cyclopedia.storedTrackerData then
            Cyclopedia.onParseCyclopediaTracker(0, Cyclopedia.storedTrackerData)
        end
    end
end

function Cyclopedia.sortTrackerData(data, trackerType)
    local filters = Cyclopedia.loadTrackerFilters(trackerType)
    local isDescending = filters.sortByDescending
    
    -- Create a copy of the data to avoid modifying the original
    local sortedData = {}
    for i, v in ipairs(data) do
        sortedData[i] = v
    end
    
    if filters.sortByName then
        table.sort(sortedData, function(a, b)
            local nameA = g_things.getRaceData(a[1]).name:lower()
            local nameB = g_things.getRaceData(b[1]).name:lower()
            if isDescending then
                return nameA > nameB
            else
                return nameA < nameB
            end
        end)
    elseif filters.ShortByPercentage then
        table.sort(sortedData, function(a, b)
            local raceIdA, killsA, _, _, maxKillsA = unpack(a)
            local raceIdB, killsB, _, _, maxKillsB = unpack(b)
            local percentA = maxKillsA > 0 and (killsA / maxKillsA * 100) or 0
            local percentB = maxKillsB > 0 and (killsB / maxKillsB * 100) or 0
            if isDescending then
                return percentA > percentB
            else
                return percentA < percentB
            end
        end)
    elseif filters.sortByKills then
        table.sort(sortedData, function(a, b)
            local remainingA = a[5] - a[2] -- maxKills - kills
            local remainingB = b[5] - b[2] -- maxKills - kills
            if isDescending then
                return remainingA > remainingB
            else
                return remainingA < remainingB
            end
        end)
    end
    
    return sortedData
end

-- Shared function to create tracker context menu
function Cyclopedia.createTrackerContextMenu(trackerType, mousePos)
    local menu = g_ui.createWidget('bestiaryTrackerMenu')
    menu:setGameMenu(true)
    local shortCreature = UIRadioGroup.create()
    local shortAlphabets = UIRadioGroup.create()

    for i, choice in ipairs(menu:getChildren()) do
        if i >= 1 and i <= 3 then
            shortCreature:addWidget(choice)
        elseif i == 5 or i == 6 then
            shortAlphabets:addWidget(choice)
        end
    end

    -- Set default selections
    local filters = Cyclopedia.loadTrackerFilters(trackerType)
    
    -- Set sorting method (default: sortByKills)
    if filters.sortByName then
        menu:getChildById('sortByName'):setChecked(true)
    elseif filters.ShortByPercentage then
        menu:getChildById('ShortByPercentage'):setChecked(true)
    elseif filters.sortByKills then
        menu:getChildById('sortByKills'):setChecked(true)
    else
        menu:getChildById('sortByKills'):setChecked(true)
    end
    
    -- Set sorting direction (default: ascending)
    if filters.sortByDescending then
        menu:getChildById('sortByDescending'):setChecked(true)
    else
        menu:getChildById('sortByAscending'):setChecked(true)
    end

    -- Add click handlers for menu options
    menu:getChildById('sortByName').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'sortByName', true); menu:destroy() end
    menu:getChildById('ShortByPercentage').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'ShortByPercentage', true); menu:destroy() end
    menu:getChildById('sortByKills').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'sortByKills', true); menu:destroy() end
    menu:getChildById('sortByAscending').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'sortByAscending', true); menu:destroy() end
    menu:getChildById('sortByDescending').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'sortByDescending', true); menu:destroy() end

    menu:display(mousePos)
    return true
end

-- Legacy functions for backwards compatibility
function Cyclopedia.loadBestiaryTrackerFilters()
    return Cyclopedia.loadTrackerFilters("bestiary")
end

function Cyclopedia.saveBestiaryTrackerFilters()
    return Cyclopedia.saveTrackerFilters("bestiary")
end

function Cyclopedia.getBestiaryTrackerFilter(filter)
    return Cyclopedia.getTrackerFilter("bestiary", filter)
end

function Cyclopedia.setBestiaryTrackerFilter(filter, value)
    return Cyclopedia.setTrackerFilter("bestiary", filter, value)
end

-- trackerMiniWindow.contentsPanel:moveChildToIndex(battleButton, index)
-- TODO Add sort by name, kills, percentage, ascending, descending
function test(index)
    trackerMiniWindow.contentsPanel:moveChildToIndex(trackerMiniWindow.contentsPanel:getLastChild(), index)
end

function bindTrackerWidgetClicks(clickableWidget, trackerWidget)
    if not clickableWidget then
        return
    end

    clickableWidget.onMouseRelease = function(_, mousePosition, mouseButton)
        return onTrackerClick(trackerWidget, mousePosition, mouseButton)
    end
end

function onTrackerClick(widget, mousePosition, mouseButton)
    if mouseButton == MouseLeftButton then
        return Cyclopedia.openTrackedCreature(widget.trackerType, widget:getId())
    end

    if mouseButton ~= MouseRightButton then
        return false
    end

    local taskId = tonumber(widget:getId())
    local menu = g_ui.createWidget("PopupMenu")

    menu:setGameMenu(true)
    menu:addOption("stop Tracking " .. widget.label:getText(), function()
        if widget.trackerType == 1 and Cyclopedia.setBosstiaryTrackerStatus then
            Cyclopedia.setBosstiaryTrackerStatus(taskId, false, true)
        elseif Cyclopedia.setBestiaryTrackerStatus then
            Cyclopedia.setBestiaryTrackerStatus(taskId, false, nil, true)
        else
            g_game.sendStatusTrackerBestiary(taskId, false)
        end
    end)
    menu:display(mousePosition)

    return true
end

function onAddLootClick(widget, mousePosition, mouseButton)
    local itemId = widget:getItemId()
    local quickLoot = modules.game_quickloot.QuickLoot
    local lootFilterValue = quickLoot.data.filter
    local menu = g_ui.createWidget("PopupMenu")

    menu:setGameMenu(true)

    if not quickLoot.lootExists(itemId, lootFilterValue) then
        menu:addOption("Add to Loot List",
        function()
            quickLoot.addLootList(itemId, lootFilterValue)
        end)
    else
        menu:addOption("Remove from Loot List", 
        function() 
            quickLoot.removeLootList(itemId, lootFilterValue)
        end)
    end

    menu:display(menuPosition)

    return true
end
