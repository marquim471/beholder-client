BlessingController = Controller:new()

local function fitText(widget, text, width)
    widget:setTextOverflowLength(0)
    widget:setText(text)
    if widget:getTextSize().width <= width then
        return false
    end
    widget:setTextOverflowCharacter(string.char(133))
    local low, high = 1, #text - 1
    while low < high do
        local length = math.floor((low + high + 1) / 2)
        widget:setTextOverflowLength(length)
        if widget:getTextSize().width <= width then
            low = length
        else
            high = length - 1
        end
    end
    widget:setTextOverflowLength(low)
    return true
end

local BLESSINGS_LIST = {
    { flag = Blessings.Adventurer,         name = "Adventurer's Blessing" },
    { flag = Blessings.TwistOfFate,        name = "Twist of Fate", offer = StoreConst.BLESSING_TWIST },
    { flag = Blessings.WisdomOfSolitude,   name = "Wisdom of Solitude", offer = StoreConst.BLESSING_SOLITUDE },
    { flag = Blessings.SparkOfPhoenix,     name = "Spark of the Phoenix", offer = StoreConst.BLESSING_PHOENIX },
    { flag = Blessings.FireOfSuns,         name = "Fire of the Suns", offer = StoreConst.BLESSING_SUNS },
    { flag = Blessings.SpiritualShielding, name = "Spiritual Shielding", offer = StoreConst.BLESSING_SPIRITUAL },
    { flag = Blessings.EmbraceOfTibia,     name = "Embrace of Tibia", offer = StoreConst.BLESSING_EMBRACE },
    { flag = Blessings.HeartOfMountain,    name = "Heart of the Mountain", offer = StoreConst.BLESSING_HEART },
    { flag = Blessings.BloodOfMountain,    name = "Blood of the Mountain", offer = StoreConst.BLESSING_BLOOD },
}

local BLESSING_IMAGES = {
    [Blessings.TwistOfFate] = "1",
    [Blessings.WisdomOfSolitude] = "2",
    [Blessings.SparkOfPhoenix] = "3",
    [Blessings.FireOfSuns] = "4",
    [Blessings.SpiritualShielding] = "5",
    [Blessings.EmbraceOfTibia] = "6",
    [Blessings.HeartOfMountain] = "7",
    [Blessings.BloodOfMountain] = "8",
}

local GLOWSTATE ={
    Disabled = 1,
    Normal = 2,
    Green = 3
}

local VISUAL_STATE_IMAGES = {
    [GLOWSTATE.Disabled] = '/images/inventory/button_blessings_grey',
    [GLOWSTATE.Normal] = '/images/inventory/button_blessings_gold',
    [GLOWSTATE.Green] = '/images/inventory/button_blessings_green',
}

function BlessingController:onInit()
    BlessingController:registerEvents(LocalPlayer, {
        onBlessingsChange = onBlessingsChange
    })
end

function BlessingController:onTerminate()
    -- BlessingController:findWidget("#blessingsWindow"):destroy()
end

function BlessingController:onGameStart()
    if g_game.getClientVersion() >= 1000 then
        BlessingController:registerEvents(g_game, {
            onUpdateBlessDialog = onUpdateBlessDialog
        })
    else
        BlessingController:scheduleEvent(function()
            g_modules.getModule("game_blessing"):unload()
        end, 100, "unloadModule")
    end
end

function BlessingController:onGameEnd()
    hide()
end

function BlessingController:close()
    hide()
end

function BlessingController:showHistory()
    local ui = BlessingController.ui
    if ui.historyPanel:isVisible() then
        BlessingController.historyButtonText = "History"
        setBlessingView()
    else
        BlessingController.historyButtonText = "Back"
        setHistoryView()
    end
end

function setHistoryView()
    local ui = BlessingController.ui
    ui.blessingsRecordPanel:hide()
    ui.promotionPanel:hide()
    ui.deathPenaltyPanel:hide()
    ui.historyPanel:show()
end

function setBlessingView()
    local ui = BlessingController.ui
    ui.historyPanel:hide()
    ui.blessingsRecordPanel:show()
    ui.promotionPanel:show()
    ui.deathPenaltyPanel:show()
end

local function updateDeathLayout(ui)
    if BlessingController.ui ~= ui then
        return
    end
    local baseHeight = 37 + 6
    for _, id in ipairs({ "fightRulesLabel", "expLossLabel", "containerLossLabel", "equipmentLossLabel" }) do
        local height = ui.deathPenaltyPanel[id]:getTextSize().height
        if BlessingController[id .. "Height"] ~= height then
            BlessingController[id .. "Height"] = height
        end
        baseHeight = baseHeight + height
    end
    if BlessingController.deathBaseHeight ~= baseHeight then
        BlessingController.deathBaseHeight = baseHeight
    end
    local extraHeight = 0
    for _, id in ipairs({ "adventurerWarning", "amuletWarning", "skullWarning" }) do
        local label = ui.deathPenaltyPanel[id]
        local height = label:getText() ~= "" and label:getTextSize().height or 0
        if BlessingController[id .. "Height"] ~= height then
            BlessingController[id .. "Height"] = height
        end
        if height > 0 then
            extraHeight = extraHeight + height + 2
        end
    end
    if BlessingController.deathExtraHeight ~= extraHeight then
        BlessingController.deathExtraHeight = extraHeight
    end
end

function show()
    hide()
    BlessingController.historyButtonText = "History"
    BlessingController.deathExtraHeight = 0
    BlessingController.deathBaseHeight = 95
    BlessingController.fightRulesLabelHeight = 13
    BlessingController.expLossLabelHeight = 13
    BlessingController.containerLossLabelHeight = 13
    BlessingController.equipmentLossLabelHeight = 13
    BlessingController.blessingListWidth = 0
    BlessingController.adventurerWarningHeight = 0
    BlessingController.amuletWarningHeight = 0
    BlessingController.skullWarningHeight = 0
    g_ui.importStyle("style.otui")
    BlessingController:loadHtml('blessing.html')
    local ui = BlessingController.ui
    ui:setStyle("BlessingWindow")
    ui:enableTitlebarDrag(17, 10)
    g_ui.createWidget("BlessingSeparator", ui.footerSeparator)
    ui.onKeyPress = function(_, key)
        if key == KeyEnter or key == KeyEscape then
            BlessingController:close()
            return true
        end
        return false
    end
    for _, id in ipairs({ "blessingsRecordPanel", "promotionPanel", "deathPenaltyPanel", "historyPanel" }) do
        local panel = ui[id]
        panel:setStyle("BlessingFrame")
        local caption = g_ui.createWidget("BlessingFrameCaption", panel)
        caption:setText(panel:getText())
        panel:setText("")
    end
    for _, id in ipairs({ "fightRulesLabel", "expLossLabel", "containerLossLabel", "equipmentLossLabel", "adventurerWarning", "amuletWarning", "skullWarning" }) do
        local label = ui.deathPenaltyPanel[id]
        local bullet = g_ui.createWidget("BlessingDeathBullet", label)
        bullet:setText(string.char(149))
        connect(label, { onGeometryChange = function()
            addEvent(function() updateDeathLayout(ui) end)
        end }, true)
    end
    g_ui.createWidget("BlessingHistoryFrame", ui.historyPanel)
    local historyScrollArea = BlessingController.ui.historyPanel.historyScrollArea
    historyScrollArea:setAutoFocusPolicy(AutoFocusNone)
    historyScrollArea.verticalScrollBar:setImageSource("")
    g_ui.createWidget("BlessingHistoryScrollTrack", historyScrollArea.verticalScrollBar):lower()
    historyScrollArea.verticalScrollBar:getChildById("sliderButton"):setStyle("BlessingHistoryScrollHandle")
    historyScrollArea.verticalScrollBar.proportionalHandle = true
    historyScrollArea.verticalScrollBar.minimumHandleLength = 14
    historyScrollArea.verticalScrollBar:setStep(20)
    historyScrollArea.verticalScrollBar:setIncrementStep(20)
    local pagePress = 0
    local historyScrollbar = historyScrollArea.verticalScrollBar
    historyScrollbar.onClick = nil
    g_mouse.bindPress(historyScrollbar, function(mousePos)
        pagePress = pagePress + 1
        local press = pagePress
        local slider = historyScrollbar:getChildById("sliderButton")
        local direction = mousePos.y < slider:getY() and -1 or 1
        local function advancePage()
            historyScrollbar:increment(direction * historyScrollbar:getHeight())
        end
        advancePage()
        periodicalEvent(advancePage, function()
            return not historyScrollbar:isDestroyed() and historyScrollbar:isPressed() and pagePress == press
        end, 60, 410)
    end, MouseLeftButton)
    local function updateHistoryScrollHandle()
        if historyScrollArea:isDestroyed() then
            return
        end
        local scrollbar = historyScrollArea.verticalScrollBar
        local visibleHeight = historyScrollArea:getPaddingRect().height
        scrollbar:setVisibleItems(visibleHeight)
        scrollbar:setVirtualChilds(visibleHeight + scrollbar:getMaximum() - scrollbar:getMinimum())
    end
    connect(historyScrollArea, {
        onScrollHeightChange = function() addEvent(updateHistoryScrollHandle) end,
        onLayoutUpdate = function() addEvent(updateHistoryScrollHandle) end,
        onGeometryChange = function() addEvent(updateHistoryScrollHandle) end
    }, true)
    updateHistoryScrollHandle()
    g_keyboard.bindKeyPress('Down', function()
        historyScrollArea:focusNextChild(KeyboardFocusReason, false)
    end, historyScrollArea)
    g_keyboard.bindKeyPress('Up', function()
        historyScrollArea:focusPreviousChild(KeyboardFocusReason, false)
    end, historyScrollArea)
    g_keyboard.bindKeyPress('PageDown', function()
        historyScrollArea.verticalScrollBar:increment(historyScrollArea:getHeight())
    end, historyScrollArea)
    g_keyboard.bindKeyPress('PageUp', function()
        historyScrollArea.verticalScrollBar:decrement(historyScrollArea:getHeight())
    end, historyScrollArea)
    g_game.requestBless()
    BlessingController.ui:show()
    BlessingController.ui:raise()
    BlessingController.ui:focus()
    setBlessingView()
end

function hide()
    if BlessingController.ui then
        BlessingController:unloadHtml()
    end
end

function toggle()
    if BlessingController.ui and BlessingController.ui:isVisible() then
        hide()
    else
        show()
    end
end

function onUpdateBlessDialog(data)
    local ui = BlessingController.ui
    if not ui then
        return
    end
    local blessingsList = ui.blessingsRecordPanel.blessingsList
    blessingsList:destroyChildren()
    for _, entry in ipairs(data.blesses) do
        if entry.blessBitwise ~= Blessings.Adventurer then
            local label = g_ui.createWidget("blessingTEST", blessingsList)
            label.text:setVisible(entry.playerBlessCount > 0)
            label.storeButton:setVisible(entry.playerBlessCount == 0)
            if fitText(label.text, entry.playerBlessCount .. " (" .. entry.store .. ")", 60) then
                label.text:setTextAlign(AlignRightCenter)
                label.text:setTextOffset({ x = -3, y = 1 })
            end
            if entry.playerBlessCount > 0 then
                label.text:setPhantom(false)
                UIHoverTooltip.configure(label.text, "You own this blessing " .. entry.playerBlessCount ..
                    " x. " .. entry.store .. " of them have been bought in the Store.")
            end
            for _, blessing in ipairs(BLESSINGS_LIST) do
                if blessing.flag == entry.blessBitwise then
                    UIHoverTooltip.configure(label.enabled, blessing.name)
                    if blessing.offer then
                        label.storeButton:setEnabled(true)
                        local offer = blessing.offer
                        label.storeButton.onClick = function()
                            modules.game_store.show()
                            g_game.sendRequestUsefulThings(offer)
                            hide()
                        end
                    end
                    break
                end
            end
            local image = BLESSING_IMAGES[entry.blessBitwise]
            if image then
                label.enabled:setImageSource("images/" .. image .. (entry.playerBlessCount > 0 and "_on" or ""))
            end
        end
    end
    local blessingCount = blessingsList:getChildCount()
    BlessingController.blessingListWidth = blessingCount * 66 + math.max(0, blessingCount - 1) * 5
    local player = g_game.getLocalPlayer()
    local isPremium = player and player:isPremium()
    -- The dialog's first status byte carries promotion, not account Premium status.
    local isPromoted = data.premium ~= 0
    local reduction = "{" .. data.promotion .. "%, #f75f5f}"
    local promotionText
    if isPremium and isPromoted then
        promotionText = "Your character is promoted and your account has Premium status. As a result, your XP loss is reduced by " .. reduction .. "."
    elseif isPremium then
        promotionText = "If your character were promoted, your XP loss would be " .. reduction .. " lower."
    elseif isPromoted then
        promotionText = "If your account had Premium status, your XP loss would be " .. reduction .. " lower."
    else
        promotionText = "If your character were promoted your account had Premium status, your XP loss would be " .. reduction .. " lower."
    end
    ui.promotionPanel.promotionStatusLabel:setColoredText(promotionText)
    if data.pvpMinXpLoss == data.pvpMaxXpLoss then
        ui.deathPenaltyPanel.fightRulesLabel:setColoredText("You will lose {" .. data.pvpMinXpLoss ..
            "%, #f75f5f} less XP and skill points upon you next PvP death.")
    else
        ui.deathPenaltyPanel.fightRulesLabel:setColoredText(
            "Depending on the fair fight rules, you will lose between {" .. data.pvpMinXpLoss .. ", #f75f5f} and {" ..
                data.pvpMaxXpLoss .. "%, #f75f5f} less XP and skill points upon your next PvP death.")
    end
    ui.deathPenaltyPanel.expLossLabel:setColoredText("You will lose {" .. data.pveExpLoss ..
                                                         "%, #f75f5f} less XP and skill points upon your next PvE death.")
    ui.deathPenaltyPanel.containerLossLabel:setColoredText("There is a {" .. data.equipPvpLoss ..
                                                               "%, #f75f5f} chance that you will lose your equipped container on your next death.")

    ui.deathPenaltyPanel.equipmentLossLabel:setColoredText("There is a {" .. data.equipPveLoss ..
                                                               "%, #f75f5f} chance that you will lose items upon your next death.")
    local hasAdventurerBlessing = false
    for _, entry in ipairs(data.blesses) do
        if entry.blessBitwise == Blessings.Adventurer and entry.playerBlessCount > 0 then
            hasAdventurerBlessing = true
            break
        end
    end
    local hasSkull = data.skull and data.skull ~= 0
    local hasAmulet = data.aol and data.aol ~= 0
    local warnings = {
        { id = "adventurerWarning", visible = hasAdventurerBlessing, text = "You are protected by the Adventurer's Blessing. If you die in a PvP fight, you will not lose any items, experience and skill points. But beware! As soon as your character attacks another character first or reaches level 21 for the first time, the blessing will be lost for good." },
        { id = "amuletWarning", visible = hasAmulet, text = hasSkull and "As long as you are marked with a red or black skull, you will lose all items whenever you die, even if you are wearing an Amulet of Loss." or "You are protected by an Amulet of Loss. You will not lose any items upon your next death." },
        { id = "skullWarning", visible = hasSkull, text = "As long as you have a red or black skull, you will lose all items upon your next death." },
    }
    for _, warning in ipairs(warnings) do
        local label = ui.deathPenaltyPanel[warning.id]
        label:setWidth(551)
        label:setTextWrap(true)
        label:setText(warning.visible and warning.text or "")
    end
    -- HTML text layout is deferred; measure after the new text has been applied.
    addEvent(function() updateDeathLayout(ui) end)
    ui.historyPanel.historyScrollArea:destroyChildren()
    ui.historyPanel.historyHeader:destroyChildren()
    local headerRow = g_ui.createWidget("BlessingHistoryHeader", ui.historyPanel.historyHeader)
    headerRow:setBackgroundColor("#363636")
    headerRow.rank:setMarginBottom(2)
    headerRow.name:setMarginBottom(2)
    headerRow.name:setWidth(388)
    headerRow.rank:setText("Date")
    headerRow.name:setText("Event")
    headerRow.rank:setColor("#c0c0c0")
    headerRow.name:setColor("#c0c0c0")
    for index, entry in ipairs(data.logs) do
        local row = g_ui.createWidget("historyData", ui.historyPanel.historyScrollArea)
        local date = os.date("%Y-%m-%d, %H:%M:%S", entry.timestamp)
        row:setFocusable(true)
        row.rank:setText(date)
        if fitText(row.name, entry.historyMessage, row.name:getWidth()) then
            row.name:setPhantom(false)
            UIHoverTooltip.configure(row.name, entry.historyMessage)
        end
        local blessingWasLost = entry.colorMessage == 0 or entry.colorMessage == 5
        row.onFocusChange = function(widget, focused)
            local textColor = focused and "#f4f4f4" or "#c0c0c0"
            widget:setBackgroundColor(focused and "#585858" or (index % 2 == 0 and "#414141" or "#484848"))
            widget.rank:setColor(textColor)
            widget.name:setColor(blessingWasLost and "#f75f5f" or textColor)
        end
        row.onFocusChange(row, row:isFocused())
    end
end

function BlessingController:onClickSendStore()
    modules.game_store.show()
    g_game.sendRequestStorePremiumBoost()
    hide()
end

function onBlessingsChange(player, blessings, oldBlessings, blessVisualState)
    local hasAdventurerBlessing = Bit.hasBit(blessings, Blessings.Adventurer)
    if hasAdventurerBlessing ~= Bit.hasBit(oldBlessings, Blessings.Adventurer) then
        modules.game_inventory.toggleAdventurerStyle(hasAdventurerBlessing)
    end
    local tooltip
    if blessings == Blessings.None then
        tooltip = 'You are currently not protected by any blessing.'
    else
        local lines = {'You are protected by the following blessings:'}
        for _, blessing in ipairs(BLESSINGS_LIST) do
            if Bit.hasBit(blessings, blessing.flag) then
                lines[#lines + 1] = '- ' .. blessing.name
            end
        end
        tooltip = table.concat(lines, '\n')
    end
    local image = VISUAL_STATE_IMAGES[blessVisualState]
    for _, blessedButton in ipairs(modules.game_inventory.getButtonsBlessings()) do
        blessedButton:setTooltip(tooltip)
        if image then
            blessedButton:setImageSource(image)
        end
    end
end
