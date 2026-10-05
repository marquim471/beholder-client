local textWindow
local mouseShield

function init()
    g_ui.importStyle('textwindow')
    connect(g_game, {
        onEditText = onGameEditText,
        onEditList = onGameEditList,
        onGameEnd = destroyWindows
    })
end

function terminate()
    disconnect(g_game, {
        onEditText = onGameEditText,
        onEditList = onGameEditList,
        onGameEnd = destroyWindows
    })
    destroyWindows()
end

function destroyWindows()
    if textWindow then textWindow:destroy(); textWindow = nil end
    if mouseShield then mouseShield:destroy(); mouseShield = nil end
end

local function configureScroll(ui)
    local edit, scroll = ui:getChildById('text'), ui:getChildById('textScroll')
    local slider = scroll:getChildById('sliderButton')
    slider:breakAnchors()
    local range, value, handleLength, handlePosition = 0, 0, 0, 0
    local updating = false
    local function update()
        if updating or ui:isDestroyed() then return end
        updating = true
        local visible = edit:getHeight()
        local total = edit:getTextTotalSize().height + 8
        range = math.max(0, total - visible)
        value = math.max(0, math.min(range, edit:getTextVirtualOffset().y))
        local track = math.max(0, scroll:getHeight() - 24)
        local fraction = math.min(1, math.max(visible / math.max(1, total), 38 / math.max(1, visible)))
        local extent = track * fraction
        handleLength = value == range and math.floor(extent + 0.5) or math.floor(extent)
        handlePosition = range > 0 and math.floor((track - extent) * value / range + 0.5) or 0
        slider:setSize({width = 12, height = handleLength})
        slider:setPosition({x = scroll:getX(), y = scroll:getY() + 12 + handlePosition})
        updating = false
    end
    local function setValue(nextValue)
        edit:setTextVirtualOffset({x = 0, y = math.floor(math.max(0, math.min(range, nextValue)) + 0.5)})
        update()
    end
    local function wheel(_, _, direction)
        local now = g_clock.millis()
        local elapsed = now - (scroll.lastWheel or -1000)
        local amount = elapsed < 20 and 60 or (elapsed < 50 and 40 or 20)
        scroll.lastWheel = now
        setValue(value + (direction == MouseWheelUp and -amount or amount))
        return true
    end
    edit.onTextAreaUpdate = update
    edit.onMouseWheel = wheel
    scroll.onMouseWheel = wheel
    connect(scroll, {onGeometryChange = update})
    local function configureArrow(button, amount)
        local event, held, inside
        local function stop()
            if event then removeEvent(event); event = nil end
            held, inside = false, false
        end
        local function repeatStep()
            event = nil
            if held and inside then
                setValue(value + amount)
                event = scheduleEvent(repeatStep, 60)
            end
        end
        button.onMousePress = function(_, _, mouseButton)
            if mouseButton ~= MouseLeftButton then return false end
            stop()
            held, inside = true, true
            event = scheduleEvent(repeatStep, 410)
            return true
        end
        button.onMouseMove = function(_, pos)
            if not held then return false end
            local contained = button:containsPoint(pos)
            if inside ~= contained then
                inside = contained
                if event then removeEvent(event); event = nil end
                if inside then event = scheduleEvent(repeatStep, 410) end
            end
            return true
        end
        button.onMouseRelease = function(_, pos, mouseButton)
            if mouseButton ~= MouseLeftButton then return false end
            if held and button:containsPoint(pos) then setValue(value + amount) end
            stop()
            return true
        end
        connect(ui, {onDestroy = stop})
    end
    configureArrow(scroll:getChildById('decrementButton'), -20)
    configureArrow(scroll:getChildById('incrementButton'), 20)
    local dragging, grabOffset
    local function moveHandle(pos)
        local travel = scroll:getHeight() - 24 - handleLength
        if travel > 0 then setValue((pos.y - scroll:getY() - 12 - grabOffset) * range / travel) end
    end
    scroll.onMousePress = function(_, pos, button)
        if button ~= MouseLeftButton then return false end
        dragging, grabOffset = true, handleLength / 2
        scroll:grabMouse()
        moveHandle(pos)
        return true
    end
    slider.onMousePress = function(_, pos, button)
        if button ~= MouseLeftButton then return false end
        dragging, grabOffset = true, pos.y - slider:getY()
        scroll:grabMouse()
        return true
    end
    scroll.onMouseMove = function(_, pos)
        if not dragging then return false end
        moveHandle(pos)
        return true
    end
    scroll.onMouseRelease = function(_, _, button)
        if button ~= MouseLeftButton or not dragging then return false end
        dragging = false
        scroll:ungrabMouse()
        return true
    end
    update()
end

local function openWindow(caption, description, text, maximum, editable, item, submit, phishing, recentlyTraded)
    destroyWindows()
    mouseShield = g_ui.createWidget('UIWidget', rootWidget)
    mouseShield:addAnchor(AnchorTop, 'parent', AnchorTop)
    mouseShield:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    mouseShield:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    mouseShield:addAnchor(AnchorRight, 'parent', AnchorRight)
    mouseShield:setFocusable(false)
    mouseShield.onMousePress = function() return true end
    mouseShield.onMouseRelease = function() return true end
    mouseShield.onMouseWheel = function() return true end
    local ui = g_ui.createWidget('TextWindow', rootWidget)
    textWindow = ui
    ui:enableTitlebarDrag(17, 10)
    ui:setText(caption)
    local label = ui:getChildById('description')
    label:setText(description)
    local rowHeight = math.max(32, label:getTextSize().height)
    label:setMarginTop(29 + math.floor((rowHeight - label:getTextSize().height) / 2 + 0.5))
    ui:getChildById('listLogo'):setMarginTop(29 + math.floor((rowHeight - 32) / 2 + 0.5))
    ui:getChildById('listLogo'):setVisible(not item)
    ui:getChildById('textItem'):setVisible(item ~= nil)
    if item then ui:getChildById('textItem'):setItem(item) end
    local frame = ui:getChildById('textFrame')
    frame:addAnchor(AnchorTop, 'parent', AnchorTop)
    local nextTop = 29 + rowHeight + 10
    local function addNotice(id, message, color, image, iconSize)
        local row = g_ui.createWidget('TextWindowNotice', ui)
        row:setId(id)
        row:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        row:addAnchor(AnchorTop, 'parent', AnchorTop)
        row:setMarginLeft(16)
        row:setMarginTop(nextTop)
        local label = row:getChildById('message')
        label:setColor(color)
        label:setText(message)
        local height = math.max(32, label:getTextSize().height)
        row:setHeight(height)
        label:setMarginTop(math.floor((height - label:getTextSize().height) / 2 + 0.5))
        local icon = row:getChildById('icon')
        icon:setImageSource(image)
        icon:setSize({width = iconSize, height = iconSize})
        icon:setMarginLeft(math.floor((32 - iconSize) / 2))
        nextTop = nextTop + height + 10
    end
    if phishing then
        addNotice('phishingNotice', tr('Beware of hacking! Do not follow any links in this letter!'),
            '#d33c3c', '/images/ui/textwindow/warning-triangle', 32)
    end
    if recentlyTraded then
        addNotice('tradedNotice', tr('Traded character: This character has been transferred from another account within the last 30 days. Be careful since this usually means that the character is now used by another player.'),
            '#ff9854', '/images/ui/textwindow/show-gui-help-orange', 12)
    end
    frame:setMarginTop(nextTop)
    local edit = ui:getChildById('text')
    edit:setEditable(editable)
    edit:setCursorVisible(editable)
    edit.onTextChange = function(_, value)
        if maximum > 0 and #value > maximum then
            edit:setText(value:sub(1, maximum))
            edit:setCursorPos(maximum)
        end
        edit:setMaxLength(#value >= maximum and maximum or 0)
    end
    edit:setText(text)
    configureScroll(ui)
    local ok = ui:getChildById('okButton')
    local cancel = ui:getChildById('cancelButton')
    local function done()
        if editable then submit(edit:getText()) end
        destroyWindows()
    end
    ok:setVisible(editable)
    ok.onClick = done
    cancel:setText(editable and tr('Cancel') or tr('Ok'))
    cancel.onClick = destroyWindows
    ui.onEnter = function() if editable then done() end end
    ui.onEscape = destroyWindows
    edit.onKeyPress = function(_, key)
        if key == KeyTab then return true end
        return false
    end
    ui:focus()
    edit:focus()
    ui:grabKeyboard()
    edit:setCursorPos(editable and #text or 0)
end

function onGameEditText(id, itemId, maxLength, text, writer, date, item, recentlyTraded)
    local thing = g_things.getThingType(itemId, ThingCategoryItem)
    local editable = thing:isWritable() or (thing:isWritableOnce() and #text == 0)
    local description
    if #text == 0 then
        description = editable and tr('It is currently empty.') or tr('It is empty.')
    elseif #writer > 0 and #date > 0 then
        description = tr('You read the following, written by %s on %s.', writer, date)
    elseif #writer > 0 then
        description = tr('You read the following, written by %s.', writer)
    else
        description = tr('You read the following.')
    end
    if editable then description = description .. '\n' .. tr('You can enter new text.') end
    openWindow(editable and tr('Edit Text') or tr('Show Text'), description,
        text, maxLength, editable, item or Item.create(itemId), function(value) g_game.editText(id, value) end,
        itemId == g_things.getStampedLetterId() and #writer > 0, recentlyTraded)
end

function onGameEditList(id, doorId, text)
    openWindow(tr('Edit List'), tr('Enter one name per line.'), text, 1999, true, nil,
        function(value) g_game.editList(id, doorId, value) end)
end
