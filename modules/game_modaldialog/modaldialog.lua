controllerModal = Controller:new()

local mouseShield

local function destroyWindow()
    if mouseShield then mouseShield:destroy(); mouseShield = nil end
    if controllerModal.ui then
        controllerModal.ui:destroy()
        controllerModal.ui = nil
    end
end

function controllerModal:onInit()
    self:registerEvents(g_game, {onModalDialog = onModalDialog})
    g_ui.importStyle('modaldialog')
end

function controllerModal:onTerminate()
    destroyWindow()
end

function controllerModal:onGameEnd()
    destroyWindow()
end

local function fitText(widget, text, width)
    widget:setTextOverflowCharacter(string.char(133))
    widget:setTextOverflowLength(0)
    widget:setText(text)
    local length = #text
    while length > 1 and widget:getTextSize().width > width do
        length = length - 1
        widget:setTextOverflowLength(length)
    end
    return length < #text
end

local function configureArrow(scroll, button, amount)
    local delayEvent, repeatEvent
    local held, inside, repeating = false, false, false
    local function stop()
        if delayEvent then removeEvent(delayEvent); delayEvent = nil end
        if repeatEvent then removeEvent(repeatEvent); repeatEvent = nil end
        held, inside, repeating = false, false, false
        if not button:isDestroyed() then button:setOn(false) end
    end
    local function repeatStep()
        if not held then return end
        if inside then scroll:increment(amount) end
        repeatEvent = scheduleEvent(repeatStep, 60)
    end
    local function startDelay()
        delayEvent = scheduleEvent(function()
            delayEvent = nil
            repeating = true
            repeatEvent = scheduleEvent(repeatStep, 60)
        end, 350)
    end
    button.onMousePress = function(_, _, mouseButton)
        if mouseButton ~= MouseLeftButton then return false end
        stop()
        held, inside = true, true
        button:setOn(true)
        scroll:increment(amount)
        startDelay()
        return true
    end
    button.onMouseMove = function(_, pos)
        if not held then return false end
        local contained = scroll:containsPoint(pos)
        if inside ~= contained then
            inside = contained
            button:setOn(inside)
            if delayEvent then removeEvent(delayEvent); delayEvent = nil end
            if inside and not repeating then startDelay() end
        end
        return true
    end
    button.onMouseRelease = function(_, _, mouseButton)
        if mouseButton ~= MouseLeftButton then return false end
        stop()
        return true
    end
    connect(scroll, {onDestroy = stop})
end

function onModalDialog(id, title, message, buttons, enterButton, escapeButton, choices, priority)
    destroyWindow()
    mouseShield = g_ui.createWidget('ServerModalShield', rootWidget)
    local ui = g_ui.createWidget('ServerModalWindow', rootWidget)
    controllerModal.ui = ui
    ui:enableTitlebarDrag(17, 10)
    if fitText(ui, title, 225) then
        local caption = g_ui.createWidget('UIWidget', ui)
        caption:setId('captionTooltipArea')
        caption:setFocusable(false)
        caption:setSize({width = 225, height = 17})
        caption:addAnchor(AnchorTop, 'parent', AnchorTop)
        caption:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        caption:setMarginTop(0)
        caption:setMarginLeft(10)
        caption.onMousePress = function(_, pos, button) return signalcall(ui.onMousePress, ui, pos, button) end
        caption.onMouseMove = function(_, pos, delta) return signalcall(ui.onMouseMove, ui, pos, delta) end
        caption.onMouseRelease = function(_, pos, button) return signalcall(ui.onMouseRelease, ui, pos, button) end
        UIHoverTooltip.configure(caption, title)
    end
    local label = ui.messageLabel
    label:setText(message)
    label:setWidth(213)
    label:setTextWrap(true)
    label:setHeight(label:getTextSize().height)

    local list, frame = ui.choiceList, ui.choiceFrame
    local listHeight = #choices > 0 and math.max(3, math.min(10, #choices)) * 16 + 2 or 0
    local extraHeight = #choices > 0 and listHeight + 5 or 0
    frame:setVisible(#choices > 0)
    list:setVisible(#choices > 0)
    ui.choiceScroll:setVisible(#choices > 0)
    frame:setHeight(listHeight)
    frame:setMarginTop(label:getHeight() + 34)
    list:setHeight(math.max(0, listHeight - 2))
    list:setMarginTop(label:getHeight() + 35)
    ui.choiceScroll:setHeight(math.max(0, listHeight - 2))
    ui.choiceScroll:setMarginTop(label:getHeight() + 35)
    list:setVerticalScrollBar(ui.choiceScroll)
    ui.choiceScroll.proportionalHandle = true
    ui.choiceScroll.minimumHandleLength = 14
    ui.choiceScroll:setStep(20)
    ui.choiceScroll:setIncrementStep(20)
    ui.choiceScroll:setVirtualChilds(#choices)
    ui.choiceScroll:setVisibleItems(math.min(10, math.max(3, #choices)))

    local scroll = ui.choiceScroll
    configureArrow(scroll, scroll:getChildById('decrementButton'), -20)
    configureArrow(scroll, scroll:getChildById('incrementButton'), 20)
    scroll.onDecrement = function(self) self:decrement(20) end
    scroll.onIncrement = function(self) self:increment(20) end
    local function wheel(_, _, direction)
        local distance = (g_keyboard.isCtrlPressed() or g_keyboard.isShiftPressed()) and list:getHeight() or 20
        if direction == MouseWheelUp then scroll:decrement(distance)
        else scroll:increment(distance) end
        return true
    end
    scroll.onMouseWheel = wheel
    list.onMouseWheel = wheel
    local function moveHandle(pos)
        local handle = scroll:getChildById('sliderButton')
        local track = scroll:getHeight() - 24 - handle:getHeight()
        if track > 0 then
            local offset = pos.y - scroll:getY() - 12 - handle:getHeight() / 2
            scroll:setValue(scroll:getMinimum() + offset / track * (scroll:getMaximum() - scroll:getMinimum()))
        end
    end
    scroll.onClick = function() end
    scroll.onMousePress = function(_, pos, button)
        if button ~= MouseLeftButton then return false end
        moveHandle(pos)
        return true
    end
    scroll.onMouseMove = function(self, pos)
        if not self:isPressed() then return false end
        moveHandle(pos)
        return true
    end

    local selected = #choices > 0 and 1 or nil
    local rows = {}
    local current = 0
    local function highlight(index)
        if #choices == 0 then return end
        selected = math.max(1, math.min(#choices, index))
        for i, row in ipairs(rows) do
            row:setOn(i == selected)
            row:setBackgroundColor(i == selected and '#585858' or (i % 2 == 1 and '#484848' or '#414141'))
            row.label:setColor(i == selected and '#f4f4f4' or '#c0c0c0')
        end
    end
    local function select(index)
        if #choices == 0 then return end
        current = math.max(1, math.min(#choices, index))
        highlight(current)
        list:ensureChildVisible(rows[current])
    end
    local dragDirection, dragEvent = 0
    local function stopDrag()
        dragDirection = 0
        if dragEvent then removeEvent(dragEvent); dragEvent = nil end
    end
    local function dragStep()
        if dragDirection == 0 then return end
        select(current + dragDirection)
        local offset = scroll:getValue() + (dragDirection > 0 and list:getHeight() or 0)
        local index = math.floor(offset / 16) + 1
        highlight(index <= #choices and index or 1)
        dragEvent = scheduleEvent(dragStep, 20)
    end
    local function moveSelection(row, pos)
        if not row:isPressed() then return false end
        local direction = pos.y < list:getY() and -1 or (pos.y > list:getY() + list:getHeight() and 1 or 0)
        if direction ~= dragDirection then
            stopDrag()
            dragDirection = direction
            if direction ~= 0 then dragEvent = scheduleEvent(dragStep, 20) end
        end
        if list:containsPoint(pos) then
            local index = math.floor((pos.y - list:getY() + scroll:getValue()) / 16) + 1
            if index <= #choices then select(index) end
        end
        return true
    end
    connect(ui, {onDestroy = stopDrag})
    local validButtons = {}
    for _, button in ipairs(buttons) do validButtons[button[1]] = true end
    local answered = false
    local function answer(buttonId)
        if answered or controllerModal.ui ~= ui then return end
        answered = true
        local choiceId = selected and choices[selected][1] or 255
        g_game.answerModalDialog(id, validButtons[buttonId] and buttonId or 255, choiceId)
        destroyWindow()
    end
    for i, choice in ipairs(choices) do
        local row = g_ui.createWidget('ServerModalChoice', list)
        row:setId('choice' .. i)
        row.choiceId = choice[1]
        row:setBackgroundColor(i % 2 == 1 and '#484848' or '#414141')
        local truncated = fitText(row.label, choice[2], 192)
        row.onMousePress = function(_, _, button)
            if button ~= MouseLeftButton then return false end
            select(i)
            return true
        end
        row.onMouseMove = moveSelection
        row.onMouseRelease = function() stopDrag(); return true end
        row.onDoubleClick = function() select(i); answer(enterButton) end
        UIHoverTooltip.configure(row, truncated and choice[2] or '', nil, 450)
        rows[i] = row
    end
    if selected then select(selected); current = 0 end
    local previous
    for i = #buttons, 1, -1 do
        local data = buttons[i]
        local button = g_ui.createWidget('ServerModalButton', ui)
        button:setId('button' .. i)
        button.buttonId = data[1]
        local truncated = fitText(button, data[2], 43)
        UIHoverTooltip.configure(button, truncated and data[2] or '')
        button:addAnchor(AnchorTop, 'parent', AnchorTop)
        button:setMarginTop(label:getHeight() + extraHeight + 56)
        if previous then
            button:addAnchor(AnchorRight, previous:getId(), AnchorLeft)
            button:setMarginRight(11)
        else
            button:addAnchor(AnchorRight, 'parent', AnchorRight)
            button:setMarginRight(16)
        end
        button.onClick = function() answer(data[1]) end
        previous = button
    end
    ui.separator:setMarginTop(label:getHeight() + extraHeight + 44)
    ui:setHeight(label:getHeight() + extraHeight + (#buttons > 0 and 92 or 72))
    ui.onKeyPress = function(_, key, modifiers)
        if key == KeyEnter then answer(enterButton)
        elseif key == KeyEscape then answer(escapeButton)
        elseif key == KeyUp and selected then if current > 1 then select(current - 1) end
        elseif key == KeyDown and selected then if current < #choices then select(current + 1) end
        elseif key == KeyPageUp and selected then ui.choiceScroll:decrement(list:getHeight())
        elseif key == KeyPageDown and selected then ui.choiceScroll:increment(list:getHeight())
        else return false end
        return true
    end
    ui:show()
    ui:raise()
    ui:focus()
    ui:grabKeyboard()
end
