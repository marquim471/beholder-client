local UI = nil

function showBossSlot()
    UI = g_ui.loadUI("boss_slots", contentContainer)
    UI:show()
    for _, slot in ipairs({UI.LeftBase, UI.RightBase}) do
        local listBase = slot.SelectBoss.ListBase
        Cyclopedia.configureScroll(listBase.List, listBase.ListScrollbar, true)
    end
    UI.LeftBase.Title:setText("Slot 1: Locked")
    UI.RightBase.Title:setText("Slot 2: Locked")
    UI.RightBase.LockLabel:setText("Unlocks at 1500 Boss Points")
    g_game.requestBossSlootInfo()
    controllerCyclopedia.ui.CharmsBase:setVisible(false)
    controllerCyclopedia.ui.GoldBase:setVisible(true)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:hide()
    end
    Cyclopedia.BossSlots.UnlockBosses = {}
end

local CATEGORY = {
    BANE = 0,
    NEMESIS = 2,
    ARCHFOE = 1
}

local SLOT_STATE = {
    EMPTY = 1,
    LOCKED = 0,
    ACTIVE = 2
}

local ICONS = {
    [CATEGORY.BANE] = "/game_cyclopedia/images/boss/icon_bane",
    [CATEGORY.ARCHFOE] = "/game_cyclopedia/images/boss/icon_archfoe",
    [CATEGORY.NEMESIS] = "/game_cyclopedia/images/boss/icon_nemesis"
}

local RARITY_TOOLTIPS = {
    [CATEGORY.BANE] = "Bane\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 5\nExpertise: 15\nMastery: 30",
    [CATEGORY.ARCHFOE] = "Archfoe\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 10\nExpertise: 30\nMastery: 60",
    [CATEGORY.NEMESIS] = "Nemesis\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 10\nExpertise: 30\nMastery: 60"
}

local SLOTS = {
    [1] = "LeftBase",
    [2] = "RightBase"
}

local CONFIG = {
    [0] = {
        EXPERTISE = 100,
        PROWESS = 25,
        MASTERY = 300
    },
    {
        EXPERTISE = 20,
        PROWESS = 5,
        MASTERY = 60
    },
    {
        EXPERTISE = 3,
        PROWESS = 1,
        MASTERY = 5
    }
}

Cyclopedia.BossSlots = {}

local function setBossSlotCaption(widget, text, tooltipWidget)
    widget:setTextOverflowLength(0)
    widget:setText(text)
    widget:setTextOverflowCharacter(string.char(133))
    local captionLength = #text
    while widget:getTextSize().width > widget:getWidth() and captionLength > 1 do
        captionLength = captionLength - 1
        widget:setTextOverflowLength(captionLength)
    end
    tooltipWidget = tooltipWidget or widget:getParent()
    tooltipWidget:setTooltip(captionLength < #text and text or "")
end

function Cyclopedia.loadBossSlots(data)
    if not UI or not UI.Sprite then
        return
    end

    Cyclopedia.BossSlots.UnlockBosses = {}

    local todaySlot = data.todaySlotData
    local raceData = todaySlot and g_things.getRaceData(data.boostedBossId)
    UI.Sprite:setVisible(raceData ~= nil and raceData ~= false)
    if raceData then
        UI.Sprite:setOutfit(raceData.outfit)
        UI.Sprite:getCreature():setStaticWalking(1000)
    end
    UI.TopBase.InfoLabel:setText(string.format("Equipment Loot Bonus: %d%% Next: %d%%", data.currentBonus,
        data.nextBonus))

    UI.MainLabel:setText(string.format("Equipment loot bonus: %d%%\nKill bonus: %dx", todaySlot and todaySlot.lootBonus or 0,
        todaySlot and todaySlot.killBonus or 0))

    Cyclopedia.setBosstiarySlotsProgress(data.playerPoints, data.totalPointsNextBonus)

    setBossSlotCaption(UI.MidTitle, string.format("Boosted Boss: %s", raceData and raceData.name or ""), UI.MidTitle)
    Cyclopedia.setBosstiarySlotsBossProgress(UI.BoostedProgress, todaySlot and todaySlot.killCount or 0,
        todaySlot and CONFIG[todaySlot.bossRace] or {PROWESS = 0, EXPERTISE = 0, MASTERY = 0})
    UI.TypeIcon:setVisible(todaySlot ~= nil)
    if todaySlot then
        UI.TypeIcon:setImageSource(ICONS[todaySlot.bossRace])
        UI.TypeIcon:setTooltip(RARITY_TOOLTIPS[todaySlot.bossRace])
    end

    for i, unlockData in ipairs(data.bossesUnlockedData) do
        if not unlockData then
            break
        end

        local uRaceData = g_things.getRaceData(unlockData.bossId)
        local data_t = {
            visible = true,
            bossId = unlockData.bossId,
            category = unlockData.bossRace,
            name = uRaceData.name
        }

        table.insert(Cyclopedia.BossSlots.UnlockBosses, data_t)
    end

    if Cyclopedia.BossSlots.UnlockBosses then
        table.sort(Cyclopedia.BossSlots.UnlockBosses, function(a, b)
            return a.name < b.name
        end)

        Cyclopedia.BossSlotChangeSlot(data)
    end
end

function Cyclopedia.BossSlotChangeSlot(data)
    local slots = {{
        isUnlocked = data.isSlotOneUnlocked,
        slotNumber = 1,
        slotData = data.slotOneData,
        bossId = data.bossIdSlotOne
    }, {
        isUnlocked = data.isSlotTwoUnlocked,
        slotNumber = 2,
        slotData = data.slotTwoData,
        bossId = data.bossIdSlotTwo
    }}

    for _, slotInfo in ipairs(slots) do
        local widget = UI[SLOTS[slotInfo.slotNumber]]
        if not slotInfo.isUnlocked then
            Cyclopedia.setEmptySlot(widget, slotInfo.slotNumber, slotInfo.bossId)
        elseif slotInfo.slotData then
            Cyclopedia.setActiveSlot(widget, slotInfo.slotNumber, slotInfo.slotData, data, slotInfo.bossId)
        else
            Cyclopedia.setLockedSlot(widget, slotInfo.slotNumber)
        end
    end
end

function Cyclopedia.setEmptySlot(widget, slot, unlockBossPoints)
    widget.LockLabel:setVisible(true)
    widget.SelectBoss:setVisible(false)
    widget.ActivedBoss:setVisible(false)
    setBossSlotCaption(widget.Title, string.format("Slot %d: Locked", slot), widget.Title)
    if unlockBossPoints > 0 then
        widget.LockLabel:setText(string.format("Unlocks at %d Boss Points", unlockBossPoints))
    else
        widget.LockLabel:setText("Unlocks if you reach the Prowess level for any boss")
    end
end

local function restoreBossSlotSelection(selectBoss)
    local selected = selectBoss.selectedBossId and
        selectBoss.ListBase.List:getChildById(tostring(selectBoss.selectedBossId))
    if selected then
        selected:setChecked(true)
    end
    selectBoss.SelectButton:setEnabled(selected ~= nil and selected ~= false)
end


function Cyclopedia.setLockedSlot(widget, slot)
    widget.LockLabel:setVisible(false)
    widget.SelectBoss:setVisible(true)
    widget.ActivedBoss:setVisible(false)
    setBossSlotCaption(widget.Title, string.format("Slot %d: Select Boss", slot), widget.Title)
    widget.SelectBoss.ListBase.List:destroyChildren()

    for _, internalData in ipairs(Cyclopedia.BossSlots.UnlockBosses) do
        local raceData = g_things.getRaceData(internalData.bossId)
        local internalWidget = g_ui.createWidget("SelectBossBossSlots", widget.SelectBoss.ListBase.List)
        internalWidget:setId(internalData.bossId)
        internalWidget.Sprite:setOutfit(raceData.outfit)
        setBossSlotCaption(internalWidget.Name, raceData.name)
        internalWidget.Sprite:getCreature():setStaticWalking(1000)
        internalWidget.TypeIcon:setImageSource(ICONS[internalData.category])

        internalWidget.TypeIcon:setTooltip(RARITY_TOOLTIPS[internalData.category])
    end

    restoreBossSlotSelection(widget.SelectBoss)
    widget.SelectBoss.ListBase.List:updateScrollBars()
    widget.SelectBoss.SelectButton.onClick = function()
        local selectedId = widget.SelectBoss.selectedBossId
        local selected = selectedId and widget.SelectBoss.ListBase.List:getChildById(tostring(selectedId))
        if selected and selected:isChecked() then
            g_game.requestBossSlotAction(slot, selectedId)
        end
    end
end

function Cyclopedia.updateBossSlotBalance()
    if not UI or UI:isDestroyed() then
        return
    end
    local player = g_game.getLocalPlayer()
    local playerMoney = player and player:getTotalMoney() or 0
    for _, slot in ipairs({UI.LeftBase, UI.RightBase}) do
        local active = slot.ActivedBoss
        if active.removePrice then
            local affordable = playerMoney >= active.removePrice
            active.Value:setColor(affordable and "#C0C0C0" or "#D33C3C")
            active.RemoveButton:setEnabled(affordable)
        end
    end
end

function Cyclopedia.setActiveSlot(widget, slot, slotData, data, bossId)
    local raceData = g_things.getRaceData(bossId)
    widget.LockLabel:setVisible(false)
    widget.SelectBoss:setVisible(false)
    widget.ActivedBoss:setVisible(true)
    setBossSlotCaption(widget.Title, string.format("Slot %d: %s", slot, raceData.name), widget.Title)
    widget.ActivedBoss.TypeIcon:setImageSource(ICONS[slotData.bossRace])

    Cyclopedia.setBosstiarySlotsBossProgress(widget.ActivedBoss.Progress, slotData.killCount,
        CONFIG[slotData.bossRace])

    widget.ActivedBoss.TypeIcon:setTooltip(RARITY_TOOLTIPS[slotData.bossRace])

    widget.ActivedBoss.Sprite:setOutfit(raceData.outfit)
    widget.ActivedBoss.Sprite:getCreature():setStaticWalking(1000)
    if slotData.inactive == 1 then
        widget.ActivedBoss.EquipmentLabel:setText("The boss in this slot has been set to inactive because it is boosted today. You can remove this boss from this slot for free.")
    else
        widget.ActivedBoss.EquipmentLabel:setText(string.format("Equipment loot bonus: %d%%", slotData.lootBonus))
    end
    widget.ActivedBoss.Value:setText(comma_value(slotData.removePrice))

    widget.ActivedBoss.removePrice = slotData.removePrice
    Cyclopedia.updateBossSlotBalance()

    widget.ActivedBoss.RemoveButton.onClick = function()
        Cyclopedia.updateBossSlotBalance()
        if widget.ActivedBoss.RemoveButton:isEnabled() then
            g_game.requestBossSlotAction(slot, 0)
        end
    end

    widget.ActivedBoss.RemoveButton:setTooltip(string.format(
        "It will cost you %s gold to remove the currently selected boss from this slot.",
        comma_value(slotData.removePrice)))
end

function Cyclopedia.setBosstiarySlotsProgress(value, maxValue)
    local bar = UI.TopBase.PointsBar
    local maximum = math.max(maxValue, 1)
    local fraction = math.min(math.max(value, 0), maximum) / maximum
    local function updateFill()
        local width = math.ceil((bar:getWidth() - 2) * fraction - 0.5)
        bar.fill:setWidth(width)
        bar.fill:setVisible(width > 0)
    end
    bar.onGeometryChange = updateFill
    updateFill()
    bar.Value:setText(string.format("%d/%d", value, maxValue))
end

function Cyclopedia.setBosstiarySlotsBossProgress(object, value, config)
    local completed = value >= config.MASTERY
    local goals = {config.PROWESS, config.EXPERTISE, config.MASTERY}
    local stars = {object.bronzeStar, object.silverStar, object.goldStar}
    local colors = {"bronze", "silver", "gold"}
    for index, goal in ipairs(goals) do
        local minimum = goals[index - 1] or 0
        local fraction = completed and 1 or math.min(math.max(
            (value - minimum) / math.max(goal - minimum, 1), 0), 1)
        local border = object["ProgressBorder" .. index]
        local fill = object["Fill" .. index]
        local width = math.ceil((border:getWidth() - 2) * fraction - 0.5)
        fill:setWidth(width)
        fill:setVisible(width > 0)
        fill:setImageSource("/game_cyclopedia/images/bestiary/progressbar-" ..
            (completed and "green" or "orange") .. "-large")
        border:setTooltip(string.format("%s / %s%s", Cyclopedia.formatGold(value),
            Cyclopedia.formatGold(goal), completed and " (fully unlocked)" or ""))
        local source = "/game_cyclopedia/images/boss/icon_star_" ..
            (value >= goal and colors[index] or "dark")
        stars[index]:setImageSource(source)
        for _, child in ipairs(stars[index]:getChildren()) do
            child:setImageSource(source)
        end
    end
    object.ProgressValue:setText(Cyclopedia.formatGold(value))
end

function Cyclopedia.bossSlotSelectBoss(widget)
    local selectBoss = widget:getParent():getParent():getParent()

    for i = 1, widget:getParent():getChildCount() do
        local child = widget:getParent():getChildByIndex(i)
        child:setChecked(false)
    end

    widget:setChecked(true)
    selectBoss.selectedBossId = tonumber(widget:getId())
    selectBoss.SelectButton:setEnabled(true)
end

function Cyclopedia.readjustSelectBoss(selectBoss, text)
    local icons = {
        [CATEGORY.BANE] = "/game_cyclopedia/images/boss/icon_bane",
        [CATEGORY.ARCHFOE] = "/game_cyclopedia/images/boss/icon_archfoe",
        [CATEGORY.NEMESIS] = "/game_cyclopedia/images/boss/icon_nemesis"
    }

    if not selectBoss then
        return
    end

    text = text or ""
    selectBoss.ListBase.List:destroyChildren()

    for _, internalData in ipairs(Cyclopedia.BossSlots.UnlockBosses) do
        if text == "" or string.find(internalData.name:lower(), text:lower(), 1, true) ~= nil then
            local raceData = g_things.getRaceData(internalData.bossId)
            local internalWidget = g_ui.createWidget("SelectBossBossSlots", selectBoss.ListBase.List)
            internalWidget:setId(internalData.bossId)
            internalWidget.Sprite:setOutfit(raceData.outfit)
            setBossSlotCaption(internalWidget.Name, raceData.name)
            internalWidget.Sprite:getCreature():setStaticWalking(1000)
            internalWidget.TypeIcon:setImageSource(icons[internalData.category])

            internalWidget.TypeIcon:setTooltip(RARITY_TOOLTIPS[internalData.category])
        end
    end

    restoreBossSlotSelection(selectBoss)
    selectBoss.ListBase.List:updateScrollBars()
end

function Cyclopedia.scheduleBossSlotSearch(text, widget)
    local selectBoss = widget:getParent()
    if selectBoss.searchEvent then
        removeEvent(selectBoss.searchEvent)
    end
    local searchUI = UI
    selectBoss.searchEvent = scheduleEvent(function()
        selectBoss.searchEvent = nil
        if UI == searchUI and UI and not UI:isDestroyed() and not selectBoss:isDestroyed() then
            Cyclopedia.SelectBossSearchText(text, false, selectBoss)
        end
    end, 250)
end

function Cyclopedia.SelectBossSearchText(text, clear, widget)
    local selectBoss = nil

    if widget then
        selectBoss = widget:getId() == "SelectBoss" and widget or widget:getParent()
    end

    if clear and selectBoss then
        selectBoss.SearchEdit:setText("")
        text = ""
    end

    if selectBoss and selectBoss.searchEvent then
        removeEvent(selectBoss.searchEvent)
        selectBoss.searchEvent = nil
    end
    Cyclopedia.readjustSelectBoss(selectBoss, text)
end
