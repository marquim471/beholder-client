-- @docclass
UIWindow = extends(UIWidget, 'UIWindow')

function UIWindow.create()
    local window = UIWindow.internalCreate()
    window:setTextAlign(AlignTopCenter)
    window:setDraggable(true)
    window:setAutoFocusPolicy(AutoFocusFirst)
    window.hotkeyBlock = false
    return window
end

function UIWindow:onKeyPress(keyCode, keyboardModifiers)
    if keyboardModifiers == KeyboardNoModifier then
        if keyCode == KeyEnter then
            signalcall(self.onEnter, self)
        elseif keyCode == KeyEscape then
            signalcall(self.onEscape, self)
        end
    end
end

function UIWindow:onFocusChange(focused)
    if focused then
        self:raise()
    end
end

function UIWindow:onDragEnter(mousePos)
    self:breakAnchors()
    self.movingReference = {
        x = mousePos.x - self:getX(),
        y = mousePos.y - self:getY()
    }
    return true
end

function UIWindow:onDragLeave(droppedWidget, mousePos)
    -- TODO: auto detect and reconnect anchors
end

function UIWindow:onDragMove(mousePos, mouseMoved)
    local pos = {
        x = mousePos.x - self.movingReference.x,
        y = mousePos.y - self.movingReference.y
    }
    self:setPosition(pos)
    self:bindRectToParent()
end

function UIWindow:onDestroy()
    if self.hotkeyBlock then
        self.hotkeyBlock.release()
        self.hotkeyBlock = false
    end
end

function UIWindow:enableTitlebarDrag(height, threshold, topOffset)
    self:setDraggable(false)
    local drag
    local function release()
        if drag then self:ungrabMouse(); drag = nil end
    end
    connect(self, {
        onMousePress = function(widget, pos, button)
            if drag then return true end
            if button ~= MouseLeftButton and button ~= MouseRightButton then return false end
            local top = widget:getY() + (topOffset or 0)
            if pos.y < top or pos.y >= top + height then return false end
            drag = {button = button, pointer = pos, origin = widget:getPosition(), active = false}
            widget:grabMouse()
            return true
        end,
        onMouseMove = function(widget, pos)
            if not drag then return false end
            local dx, dy = pos.x - drag.pointer.x, pos.y - drag.pointer.y
            local parent = widget:getParent():getRect()
            local x = math.max(parent.x, math.min(drag.origin.x + dx, parent.x + parent.width - widget:getWidth()))
            local y = math.max(parent.y, math.min(drag.origin.y + dy, parent.y + parent.height - widget:getHeight()))
            if not drag.active then
                if (math.abs(dx) > threshold and x ~= drag.origin.x)
                    or (math.abs(dy) > threshold and y ~= drag.origin.y) then
                    drag.active = true
                    drag.pointer = pos
                    widget:breakAnchors()
                end
                return true
            end
            widget:setPosition({x = x, y = y})
            return true
        end,
        onMouseRelease = function(widget, pos, button)
            if not drag or drag.button ~= button then return false end
            release()
            return true
        end,
        onVisibilityChange = function(widget) if not widget:isVisible() then release() end end,
        onDestroy = release
    }, true)
end
