function configureMinimapTooltip(widget, text, hideOnMove)
    text = text or widget.tooltip
    widget.tooltip = nil
    if not text or text == '' then return end
    local label
    local timer
    local hovered = false
    local function hide()
        if timer then removeEvent(timer); timer = nil end
        if label then label:destroy(); label = nil end
        widget.minimapTooltip = nil
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
        label = g_ui.createWidget('UIWidget', rootWidget)
        label:setId('minimapTooltip')
        label:setBackgroundColor('#c0c0c0')
        label:setBorderColor('#000000')
        label:setBorderWidth(1)
        label:setPhantom(true)
        local content = g_ui.createWidget('UILabel', label)
        content:setFont('verdana-bold-11px-native')
        content:setColor('#3f3f3f')
        content:setTextAlign(AlignLeft)
        content:setPhantom(true)
        content:setText(text)
        content:setWidth(math.min(content:getTextSize().width, g_window.getSize().width - 8))
        content:setTextWrap(true)
        content:setHeight(content:getTextSize().height)
        content:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        content:addAnchor(AnchorTop, 'parent', AnchorTop)
        content:setMarginLeft(4)
        content:setMarginTop(4)
        label:setSize({width = content:getWidth() + 8, height = content:getHeight() + 8})
        position()
        label:raise()
        widget.minimapTooltip = label
    end
    local function restart()
        hide()
        if hovered then timer = scheduleEvent(show, 500) end
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
