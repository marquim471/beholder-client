UIHoverTooltip = {}

function UIHoverTooltip.configure(widget, text, hideOnMove, maxWidth, delay)
    text = text or widget.tooltip
    widget.tooltip = nil
    if not text or text == '' then return end
    local label
    local timer
    local hovered = false
    local function hide()
        if timer then removeEvent(timer); timer = nil end
        if label then label:destroy(); label = nil end
        widget.hoverTooltip = nil
    end
    local function position()
        local pos = g_window.getMousePosition()
        local size = g_window.getSize()
        label:setPosition({x = math.max(0, math.min(pos.x, size.width - label:getWidth())),
            y = math.max(0, math.min(pos.y - label:getHeight(), size.height - label:getHeight()))})
    end
    local function show()
        timer = nil
        if not hovered or not widget:isVisible() or g_mouse.isPressed() then return end
        local currentText = text
        if type(text) == 'function' then currentText = text(widget) end
        if not currentText or currentText == '' then return end
        label = g_ui.createWidget('UIWidget', rootWidget)
        label:setId('hoverTooltip')
        label:setBackgroundColor('#c0c0c0')
        label:setBorderColor('#000000')
        label:setBorderWidth(1)
        label:setPhantom(true)
        local content = g_ui.createWidget('UILabel', label)
        content:setFont('verdana-bold-11px-native')
        content:setColor('#3f3f3f')
        content:setTextAlign(AlignLeft)
        content:setPhantom(true)
        content:setId('content')
        if maxWidth then content:applyStyle({['trim-line-end-spaces'] = true}) end
        content:setText(currentText)
        content:setWidth(math.min(content:getTextSize().width, math.min(g_window.getSize().width, maxWidth or g_window.getSize().width) - 8))
        content:setTextWrap(true)
        content:setHeight(content:getTextSize().height)
        content:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        content:addAnchor(AnchorTop, 'parent', AnchorTop)
        content:setMarginLeft(4)
        content:setMarginTop(4)
        label:setSize({width = (maxWidth and content:getTextSize().width or content:getWidth()) + 8, height = content:getHeight() + 8})
        position()
        label:raise()
        widget.hoverTooltip = label
    end
    widget.refreshHoverTooltip = function()
        if not label then return end
        local currentText = text
        if type(text) == 'function' then currentText = text(widget) end
        if not currentText or currentText == '' then hide(); return end
        local content = label:getChildById('content')
        content:setTextWrap(false)
        content:setText(currentText)
        content:setWidth(math.min(content:getTextSize().width, math.min(g_window.getSize().width, maxWidth or g_window.getSize().width) - 8))
        content:setTextWrap(true)
        content:setHeight(content:getTextSize().height)
        label:setSize({width = (maxWidth and content:getTextSize().width or content:getWidth()) + 8, height = content:getHeight() + 8})
        position()
    end
    local function restart()
        hide()
        if hovered then timer = scheduleEvent(show, delay or 500) end
    end
    connect(widget, {
        onHoverChange = function(self, value)
            hovered = value
            restart()
        end,
        onMouseMove = function()
            if hideOnMove ~= false then restart()
            elseif label then position() end
        end,
        onMousePress = hide,
        onVisibilityChange = function(self) if not self:isVisible() then hovered = false; hide() end end,
        onDestroy = hide
    }, true)
end
