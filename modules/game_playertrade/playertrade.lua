tradeWindow = nil
local tradeMenu = nil

local function closeTradeMenu()
    if tradeMenu and not tradeMenu:isDestroyed() then
        tradeMenu:destroy()
    end
    tradeMenu = nil
end

function init()
    g_ui.importStyle('tradewindow')

    connect(g_game, {
        onOwnTrade = onGameOwnTrade,
        onCounterTrade = onGameCounterTrade,
        onCloseTrade = onGameCloseTrade,
        onGameEnd = onGameCloseTrade
    })
end

function terminate()
    closeTradeMenu()
    disconnect(g_game, {
        onOwnTrade = onGameOwnTrade,
        onCounterTrade = onGameCounterTrade,
        onCloseTrade = onGameCloseTrade,
        onGameEnd = onGameCloseTrade
    })

    if tradeWindow then
        tradeWindow:destroy()
    end
end

function createTrade()
    tradeWindow = g_ui.createWidget('TradeWindow', modules.game_interface.getRightPanel())
    tradeWindow.onClose = function()
        closeTradeMenu()
        g_game.rejectTrade()
        tradeWindow:hide()
    end
    tradeWindow:recursiveGetChildById('tradeViewport'):setVerticalScrollBar(tradeWindow.miniwindowScrollBar)
    tradeWindow.onMaximize = function()
        tradeWindow:setHeight(math.min(tradeWindow:getHeight(), tradeWindow.bottomResizeBorder.maximum))
    end
    tradeWindow:setup()
end

function fillTrade(name, items, counter)
    closeTradeMenu()
    if not tradeWindow then
        createTrade()
    end

    local tradeContainer
    local label
    if counter then
        tradeContainer = tradeWindow:recursiveGetChildById('counterTradeContainer')
        label = tradeWindow:recursiveGetChildById('counterTradeLabel')
    else
        tradeContainer = tradeWindow:recursiveGetChildById('ownTradeContainer')
        label = tradeWindow:recursiveGetChildById('ownTradeLabel')
    end
    label:setText(name)
    tradeContainer:destroyChildren()

    for index, item in ipairs(items) do
        local itemWidget = g_ui.createWidget('TradeItem', tradeContainer)
        itemWidget:setItem(item)
        ItemsDatabase.setTier(itemWidget, item)
        itemWidget:setVirtual(true)
        itemWidget:setMargin(0)
        itemWidget.onClick = function()
            if not itemWidget:isDestroyed() then
                g_game.inspectTrade(counter, index - 1)
            end
        end
        itemWidget.onMouseRelease = function(widget, mousePosition, mouseButton)
            if mouseButton ~= MouseRightButton or not widget:containsPoint(mousePosition) then
                return UIItem.onMouseRelease(widget, mousePosition, mouseButton)
            end
            closeTradeMenu()
            tradeMenu = UIContextMenu.create({})
            tradeMenu:addOption(tr('Look'), itemWidget.onClick)
            tradeMenu:display(mousePosition)
            return true
        end
    end

    local ownContainer = tradeWindow:recursiveGetChildById('ownTradeContainer')
    local counterContainer = tradeWindow:recursiveGetChildById('counterTradeContainer')
    local ownHeight = math.ceil(ownContainer:getChildCount() / 2) * 37
    local counterHeight = math.ceil(counterContainer:getChildCount() / 2) * 37
    ownContainer:setHeight(ownHeight)
    counterContainer:setHeight(counterHeight)
    local contentHeight = math.max(37, ownHeight, counterHeight)
    tradeWindow:recursiveGetChildById('tradeBody'):setHeight(contentHeight)
    tradeWindow.bottomResizeBorder.maximum = math.max(100, contentHeight + 57)
    if not tradeWindow:isOn() and tradeWindow:getHeight() > tradeWindow.bottomResizeBorder.maximum then
        tradeWindow:setHeight(tradeWindow.bottomResizeBorder.maximum)
    end

    local hasCounterOffer = counterContainer:getChildCount() > 0
    tradeWindow:recursiveGetChildById('acceptButton'):setVisible(hasCounterOffer)
    tradeWindow:recursiveGetChildById('rejectButton'):setText(hasCounterOffer and tr('Reject') or tr('Cancel'))
    local status = tradeWindow:recursiveGetChildById('statusText')
    status:setText(tr('Please wait for a\ncounteroffer'))
    status:setVisible(not hasCounterOffer)
end

function acceptTrade()
    if not tradeWindow then
        return
    end
    local acceptButton = tradeWindow:recursiveGetChildById('acceptButton')
    if not acceptButton:isExplicitlyVisible() then
        return
    end
    acceptButton:hide()
    local status = tradeWindow:recursiveGetChildById('statusText')
    status:setText(tr('Please wait for\nyour partner to accept.'))
    status:show()
    g_game.acceptTrade()
end

function fitTradeName(label)
    if label:getWidth() <= 0 then
        return
    end
    label:setTextOverflowLength(0)
    label:setTextOverflowCharacter(string.char(133))
    local text = label:getText()
    local length = #text
    local truncated = label:getTextSize().width > label:getWidth()
    while label:getTextSize().width > label:getWidth() and length > 1 do
        length = length - 1
        label:setTextOverflowLength(length)
    end
    if truncated then
        label:setTooltip(text)
    else
        label:removeTooltip()
    end
end

function onGameOwnTrade(name, items)
    fillTrade(name, items, false)
end

function onGameCounterTrade(name, items)
    fillTrade(name, items, true)
end

function onGameCloseTrade()
    closeTradeMenu()
    if tradeWindow then
        tradeWindow:destroy()
        tradeWindow = nil
    end
end
