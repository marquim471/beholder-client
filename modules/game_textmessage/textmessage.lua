local screenColors = {
    [TextColors.red] = '#f86060', [TextColors.orange] = '#ff6600',
    [TextColors.yellow] = '#f0f000', [TextColors.green] = '#00f000',
    [TextColors.lightblue] = '#60f8f8', [TextColors.white] = '#f0f0f0'
}

MessageSettings = {
    none = {},
    consoleYellow = {
        color = TextColors.yellow,
        consoleTab = 'Local Chat'
    },
    consoleRed = {
        color = TextColors.red,
        consoleTab = 'Local Chat'
    },
    consoleOrange = {
        color = TextColors.orange,
        consoleTab = 'Local Chat'
    },
    consoleBlue = {
        color = TextColors.blue,
        consoleTab = 'Local Chat'
    },
    centerRed = {
        color = TextColors.red,
        consoleTab = 'Server Log',
        screenTarget = 'middleCenterLabel'
    },
    centerGreen = {
        color = TextColors.green,
        consoleTab = 'Server Log',
        screenTarget = 'highCenterLabel',
        consoleOption = 'showInfoMessagesInConsole'
    },
    centerHKGreen = {
        color = TextColors.green,
        consoleTab = 'Server Log',
        screenTarget = 'highCenterLabel',
        consoleOption = 'showHotkeyMessagesInConsole'
    },
    centerWhite = {
        color = TextColors.white,
        consoleTab = 'Server Log',
        screenTarget = 'middleCenterLabel',
        consoleOption = 'showEventMessagesInConsole'
    },
    centerQueueGreen = {
        color = TextColors.green,
        consoleTab = 'Server Log',
        screenTarget = 'middleCenterLabel',
        consoleOption = 'showInfoMessagesInConsole'
    },
    lookWhite = {
        color = TextColors.white,
        consoleTab = 'Server Log',
        screenTarget = 'highCenterLabel',
        consoleOption = 'showEventMessagesInConsole'
    },
    bottomWhite = {
        color = TextColors.white,
        consoleTab = 'Server Log',
        screenTarget = 'statusLabel',
        consoleOption = 'showEventMessagesInConsole'
    },
    status = {
        color = TextColors.white,
        consoleTab = 'Server Log',
        screenTarget = 'statusLabel',
        consoleOption = 'showStatusMessagesInConsole'
    },
    consoleEvent = {
        color = TextColors.white,
        consoleTab = 'Server Log'
    },
    statusOwn = {
        color = TextColors.white,
        consoleTab = 'Server Log',
        consoleOption = 'showStatusMessagesInConsole'
    },
    statusBoosted = {
        color = TextColors.white,
        consoleTab = 'Server Log',
        screenTarget = 'statusLabel',
        consoleOption = 'showBoostedMessagesInConsole'
    },
    othersStatus = {
        color = TextColors.white,
        consoleTab = 'Server Log',
        consoleOption = 'showOthersStatusMessagesInConsole'
    },
    statusSmall = {
        color = TextColors.white,
        screenTarget = 'statusLabel'
    },
    private = {
        color = TextColors.lightblue,
        consoleTab = 'Local Chat',
        screenTarget = 'privateLabel'
    },
    privateRed = {
        color = TextColors.red,
        consoleTab = 'Local Chat',
        private = true
    },
    privatePlayerToPlayer = {
        color = TextColors.blue,
        consoleTab = 'Local Chat',
        private = true
    },
    privatePlayerToNpc = {
        color = TextColors.blue,
        consoleTab = 'Local Chat',
        private = true,
        npcChat = true
    },
    privateNpcToPlayer = {
        color = TextColors.lightblue,
        consoleTab = 'Local Chat',
        private = true,
        npcChat = true
    },
    channelYellow = {
        color = TextColors.yellow
    },
    channelWhite = {
        color = TextColors.white
    },
    channelGreen = {
        color = TextColors.green
    },
    channelRed = {
        color = TextColors.red
    },
    channelOrange = {
        color = TextColors.orange
    },
    monsterSay = {
        color = TextColors.orange,
        hideInConsole = true
    },
    monsterYell = {
        color = TextColors.orange,
        hideInConsole = true
    },
    potion = {
        color = TextColors.orange,
        hideInConsole = true
    },
    loot = {
        color = TextColors.white,
        consoleTab = 'Loot',
        screenTarget = 'highCenterLabel',
        consoleOption = 'showInfoMessagesInConsole',
        colored = true
    },
    valuableLoot = {
        color = TextColors.white,
        consoleTab = 'Loot',
        screenTarget = 'statusLabel',
        consoleOption = 'showInfoMessagesInConsole',
        colored = true
    }
}

MessageTypes = {
    [MessageModes.Say] = MessageSettings.consoleYellow,
    [MessageModes.Whisper] = MessageSettings.consoleYellow,
    [MessageModes.Yell] = MessageSettings.consoleYellow,
    [MessageModes.MonsterSay] = MessageSettings.monsterSay,
    [MessageModes.MonsterYell] = MessageSettings.monsterYell,
    [MessageModes.BarkLow] = MessageSettings.consoleOrange,
    [MessageModes.BarkLoud] = MessageSettings.consoleOrange,
    [MessageModes.Failure] = MessageSettings.statusSmall,
    [MessageModes.Login] = MessageSettings.bottomWhite,
    [MessageModes.Game] = MessageSettings.centerWhite,
    [MessageModes.Status] = MessageSettings.status,
    [MessageModes.Warning] = MessageSettings.centerRed,
    [MessageModes.Look] = MessageSettings.centerGreen,
    [MessageModes.Loot] = MessageSettings.loot,
    [MessageModes.Red] = MessageSettings.consoleRed,
    [MessageModes.Blue] = MessageSettings.consoleBlue,
    [MessageModes.PrivateFrom] = MessageSettings.private,
    [MessageModes.PrivateTo] = MessageSettings.privatePlayerToPlayer,
    [MessageModes.GamemasterPrivateFrom] = MessageSettings.privateRed,
    [MessageModes.NpcTo] = MessageSettings.privatePlayerToNpc,
    [MessageModes.NpcFrom] = MessageSettings.privateNpcToPlayer,
    [MessageModes.NpcFromStartBlock] = MessageSettings.privateNpcToPlayer,
    [MessageModes.Channel] = MessageSettings.channelYellow,
    [MessageModes.ChannelManagement] = MessageSettings.channelGreen,
    [MessageModes.GamemasterChannel] = MessageSettings.channelRed,
    [MessageModes.ChannelHighlight] = MessageSettings.channelOrange,
    [MessageModes.Spell] = MessageSettings.consoleYellow,
    [MessageModes.RVRChannel] = MessageSettings.channelWhite,
    [MessageModes.RVRContinue] = MessageSettings.consoleYellow,

    [MessageModes.GamemasterBroadcast] = MessageSettings.consoleRed,

    [MessageModes.DamageDealed] = MessageSettings.statusOwn,
    [MessageModes.DamageReceived] = MessageSettings.statusOwn,
    [MessageModes.Heal] = MessageSettings.statusOwn,
    [MessageModes.Exp] = MessageSettings.statusOwn,

    [MessageModes.DamageOthers] = MessageSettings.othersStatus,
    [MessageModes.HealOthers] = MessageSettings.othersStatus,
    [MessageModes.ExpOthers] = MessageSettings.othersStatus,
    [MessageModes.Potion] = MessageSettings.potion,

    [MessageModes.TradeNpc] = MessageSettings.centerGreen,
    [MessageModes.Guild] = MessageSettings.statusOwn,
    [MessageModes.Party] = MessageSettings.statusOwn,
    [MessageModes.PartyManagement] = MessageSettings.centerQueueGreen,
    [MessageModes.TutorialHint] = MessageSettings.statusSmall,
    [MessageModes.BeyondLast] = MessageSettings.lookWhite,
    [MessageModes.Report] = MessageSettings.centerWhite,
    [MessageModes.GameHighlight] = MessageSettings.centerRed,
    [MessageModes.HotkeyUse] = MessageSettings.centerGreen,
    [MessageModes.Attention] = MessageSettings.consoleEvent,
    [MessageModes.BoostedCreature] = MessageSettings.centerWhite,
    [MessageModes.OfflineTrainning] = MessageSettings.centerWhite,
    [MessageModes.Transaction] = MessageSettings.centerWhite,
    [MessageModes.ValuableLoot] = MessageSettings.valuableLoot,

    [254] = MessageSettings.private
}

messagesPanel = nil
local clearRequests = 0
local clearGeneration = 0

local function positionMessage(label)
    local panel = label:getParent()
    local height = panel:getHeight()
    local y = label:getId() == 'statusLabel' and height - label:getHeight() - 3
        or label:getId() == 'highCenterLabel' and math.floor(height / 2 - label:getHeight())
        or label:getId() == 'privateLabel' and math.floor(height / 4 - label:getHeight())
        or math.floor(height / 2)
    label:setMarginLeft(math.floor((panel:getWidth() - label:getWidth()) / 2))
    label:setMarginTop(y)
end

local function setupMessageLabel(label)
    local layers = {}
    local offsets = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}, {0, 0}}
    for _, offset in ipairs(offsets) do
        local layer = g_ui.createWidget('TextMessageLayer', label)
        layer:setFont('verdana-bold-11px-native')
        layer:setTextAlign(AlignTopCenter)
        layer:setColor('black')
        layer:setPhantom(true)
        table.insert(layers, layer)
    end
    local text = layers[5]
    local function update()
        text:setTextWrap(false)
        local width = math.min(288, text:getTextSize().width)
        text:setWidth(width)
        text:setTextWrap(true)
        local height = text:getTextSize().height
        label:setSize({width = width, height = height})
        for i, layer in ipairs(layers) do
            if i < 5 then layer:setText(text:getText()); layer:setTextWrap(true) end
            layer:setSize({width = width, height = height})
            layer:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            layer:addAnchor(AnchorTop, 'parent', AnchorTop)
            layer:setMarginLeft(offsets[i][1])
            layer:setMarginTop(offsets[i][2])
        end
        positionMessage(label)
    end
    label.setText = function(_, value) text:setText(value); update() end
    label.setColoredText = function(_, value) text:setColoredText(value); update() end
    label.setColor = function(_, value) text:setColor(value) end
    label.getText = function() return text:getText() end
    label.getTextSize = function() return text:getTextSize() end
end

function init()
    for messageMode, _ in pairs(MessageTypes) do
        registerMessageMode(messageMode, displayMessage)
    end

    Keybind.new('Misc', 'Clear Oldest Message', 'Alt+W', '')
    Keybind.bind('Misc', 'Clear Oldest Message', {{type = KEY_PRESS, callback = clearOldestMessage}},
        modules.game_interface.getRootPanel())
    connect(g_game, 'onGameEnd', clearMessages)
    messagesPanel = g_ui.loadUI('textmessage', modules.game_interface.getRootPanel())
    for _, label in ipairs(messagesPanel:getChildren()) do setupMessageLabel(label) end
    messagesPanel.onGeometryChange = function()
        for _, label in ipairs(messagesPanel:getChildren()) do positionMessage(label) end
    end
end

function terminate()
    for messageMode, _ in pairs(MessageTypes) do
        unregisterMessageMode(messageMode, displayMessage)
    end

    Keybind.delete('Misc', 'Clear Oldest Message')
    disconnect(g_game, 'onGameEnd', clearMessages)
    clearMessages()
    messagesPanel:destroy()
    messagesPanel = nil
end

function calculateVisibleTime(text)
    return 3000 + #text * 50
end

local function showScreenMessage(label, text, msgtype, coloredText)
    local queued = label:getId() == 'middleCenterLabel' or label:getId() == 'privateLabel'
    local message = {text = text, color = screenColors[msgtype.color] or msgtype.color, colored = msgtype.colored, coloredText = coloredText,
        duration = label:getId() == 'statusLabel' and 5000 or calculateVisibleTime(text)}
    if queued and label:isVisible() then
        label.pendingMessages = label.pendingMessages or {}
        if #label.pendingMessages >= 9 then table.remove(label.pendingMessages, 1) end
        table.insert(label.pendingMessages, message)
        return
    end
    if queued then message.duration = message.duration * 2 end
    local function show(nextMessage)
        label:setColor(nextMessage.color)
        if nextMessage.coloredText then
            label:setColoredText(nextMessage.coloredText)
        elseif nextMessage.colored then
            label:setColoredText(ItemsDatabase.setColorLootMessage(nextMessage.text))
        else
            label:setText(nextMessage.text)
        end
        label.shownAt = g_clock.millis()
        label:setVisible(true)
        removeEvent(label.hideEvent)
        label.advanceMessage = function()
            label.hideEvent = nil
            if label.pendingMessages and #label.pendingMessages > 0 then
                show(table.remove(label.pendingMessages, 1))
            else
                label:hide()
            end
        end
        label.hideEvent = scheduleEvent(label.advanceMessage, nextMessage.duration)
    end
    show(message)
end

function displayMessage(mode, text, channelId)

    if not g_game.isOnline() then
        return
    end
    if g_game.getClientVersion() >= 1300 then
        MessageTypes[MessageModes.Loot] = MessageSettings.loot
        MessageTypes[MessageModes.ValuableLoot] = MessageSettings.valuableLoot
        MessageTypes[MessageModes.Guild] = MessageSettings.statusOwn
        MessageTypes[MessageModes.Party] = MessageSettings.statusOwn
    else
        MessageTypes[MessageModes.PrivateFrom] = MessageSettings.privateNpcToPlayer
        MessageTypes[MessageModes.Loot] = MessageSettings.centerGreen
        MessageTypes[MessageModes.ValuableLoot] = MessageSettings.centerGreen
        MessageTypes[MessageModes.Guild] = MessageSettings.centerGreen
        MessageTypes[MessageModes.Party] = MessageSettings.centerGreen
        MessageTypes[MessageModes.MonsterSay] = MessageSettings.consoleOrange
        MessageTypes[MessageModes.MonsterYell] = MessageSettings.consoleOrange
    end
    local msgtype = MessageTypes[mode]
    if not msgtype then
        return
    end

    if msgtype == MessageSettings.none then
        return
    end

    local channelMessage = channelId and channelId >= 0
    if channelMessage then
        local tab = modules.game_console.getChannelTab(channelId)
        if tab then modules.game_console.addTabText(text, msgtype, tab) end
    end
    if not channelMessage and msgtype.consoleTab ~= nil and
        (msgtype.consoleOption == nil or modules.client_options.getOption(msgtype.consoleOption)) then
        if msgtype == MessageSettings.loot or msgtype == MessageSettings.valuableLoot then
            local lootColoredText = ItemsDatabase.setColorLootMessage(text)
            local lootTabName = tr(msgtype.consoleTab)
            local targetTab = modules.game_console.getTab(lootTabName) and lootTabName or tr("Server Log")
            modules.game_console.addText(lootColoredText, msgtype, targetTab)
        else
            modules.game_console.addText(text, msgtype, tr(msgtype.consoleTab))
        end
    end

    if msgtype.screenTarget then
        if not modules.client_options.getOption('showMessagesOnScreen') then return end
        local option = ({[MessageModes.PrivateFrom] = 'showPrivateMessagesOnScreen', [MessageModes.HotkeyUse] = 'showHotkeyMessagesOnScreen',
            [MessageModes.BoostedCreature] = 'showBoostedMessagesOnScreen',
            [MessageModes.OfflineTrainning] = 'showOfflineTrainingMessagesOnScreen',
            [MessageModes.Transaction] = 'showTransactionMessagesOnScreen'})[mode]
        if option and not modules.client_options.getOption(option) then return end
        local label = messagesPanel:recursiveGetChildById(msgtype.screenTarget)
        if msgtype == MessageSettings.loot and not modules.client_options.getOption('showLootMessagesOnScreen') then
            return
        end
        showScreenMessage(label, text, msgtype)
    end
end

function displayPrivateMessage(text)
    if not g_game.isOnline() or not modules.client_options.getOption('showMessagesOnScreen')
        or not modules.client_options.getOption('showPrivateMessagesOnScreen') then
        return
    end
    
    local msgtype = MessageSettings.private
    if not msgtype or not msgtype.screenTarget then
        return
    end
    
    local label = messagesPanel:recursiveGetChildById(msgtype.screenTarget)
    if not label then
        return
    end
    
    showScreenMessage(label, text, msgtype)
end

function displayStatusMessage(text)
    displayMessage(MessageModes.Status, text)
end

function displayFailureMessage(text)
    displayMessage(MessageModes.Failure, text)
end

function displayGameMessage(text)
    displayMessage(MessageModes.Game, text)
end

function displayBroadcastMessage(text)
    displayMessage(MessageModes.Warning, text)
end

function displayCustomColoredMessage(targetLabelId, coloredText, plainText, consoleTab)
    if not g_game.isOnline() or not messagesPanel then
        return
    end

    local label = messagesPanel:recursiveGetChildById(targetLabelId or 'middleCenterLabel')
    if label then
        showScreenMessage(label, plainText or coloredText, {color = TextColors.white}, coloredText)
    end

    if consoleTab and modules.game_console then
        local tabName = tr(consoleTab)
        local targetTab = modules.game_console.getTab(tabName) and tabName or tr('Server Log')
        local consoleSetting = {
            color = TextColors.white,
            consoleTab = 'Server Log',
            colored = true
        }
        modules.game_console.addText(coloredText, consoleSetting, targetTab)
    end
end

local function processClearRequest()
    local oldest
    for _, id in ipairs({'highCenterLabel', 'middleCenterLabel', 'privateLabel'}) do
        local label = messagesPanel:recursiveGetChildById(id)
        if label:isVisible() and label.shownAt and (not oldest or label.shownAt < oldest.shownAt) then
            oldest = label
        end
    end
    local shownAt = oldest and oldest.shownAt
    local generation = clearGeneration
    g_map.clearOldestStaticText(shownAt or 9007199254740991, function(removed)
        if generation ~= clearGeneration then return end
        if not removed and oldest and oldest:isVisible() and oldest.shownAt == shownAt then
            removeEvent(oldest.hideEvent)
            oldest.advanceMessage()
        end
        clearRequests = clearRequests - 1
        if clearRequests > 0 then processClearRequest() end
    end)
end

function clearOldestMessage()
    if not g_game.isOnline() then return false end
    clearRequests = clearRequests + 1
    if clearRequests == 1 then processClearRequest() end
    return true
end

function clearMessages()
    clearGeneration = clearGeneration + 1
    clearRequests = 0
    for _i, child in pairs(messagesPanel:recursiveGetChildren()) do
        if child:getId():match('Label') then
            child:hide()
            removeEvent(child.hideEvent)
            child.hideEvent = nil
            child.pendingMessages = nil
            child.advanceMessage = nil
            child.shownAt = nil
        end
    end
end

function LocalPlayer:onAutoWalkFail(player)
    modules.game_textmessage.displayFailureMessage(tr('There is no way.'))
end
