-- @docclass
UIMiniWindowContainer = extends(UIWidget, 'UIMiniWindowContainer')

-- Side-panel layout of the current character. While the windows are being brought back at login
-- (and after logout) the layout is not live: nothing is closed to make room and nothing is saved,
-- so a half-restored panel can never overwrite the layout the player left.
MiniWindowLayout = {
    live = false
}

-- Each panel records the ids of its windows in order, so a window restored at login, or a
-- container the server reopens, goes back between the same neighbours whatever order the
-- modules bring their windows back in.
local ORDER_NODE = 'CharPanelOrder'

local function currentCharacter()
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return nil
    end
    return char
end

function UIMiniWindowContainer:getSavedOrder()
    local ranks, ids = {}, {}
    local char = currentCharacter()
    if not char then
        return ranks, ids
    end

    local node = g_settings.getNode(ORDER_NODE)
    local list = node and node[char] and node[char][self:getId()]
    if type(list) == 'string' then
        for id in list:gmatch('[^,]+') do
            ids[#ids + 1] = id
            ranks[id] = #ids
        end
        return ranks, ids
    end

    -- Layouts saved before the order was recorded only have the per-window index.
    local windows = g_settings.getNode('CharMiniWindows')
    windows = windows and windows[char]
    if windows then
        for id, settings in pairs(windows) do
            if type(settings) == 'table' and settings.parentId == self:getId() and tonumber(settings.index) then
                ranks[id] = tonumber(settings.index)
            end
        end
    end
    return ranks, ids
end

-- Inserts the window before the first window that came after it last session.
function UIMiniWindowContainer:insertByOrder(widget, ranks)
    ranks = ranks or self:getSavedOrder()
    local oldParent = widget:getParent()
    if oldParent then
        oldParent:removeChild(widget)
    end

    local rank = ranks[widget:getId()]
    if rank then
        local children = self:getChildren()
        for i = 1, #children do
            local childRank = ranks[children[i]:getId()]
            if childRank and childRank > rank then
                self:insertChild(i, widget)
                return
            end
        end
    end
    self:addChild(widget)
end

local function placedInOtherPanel(id, panel)
    local widget = rootWidget:recursiveGetChildById(id)
    local parent = widget and widget:getParent()
    return parent and parent ~= panel and parent:getClassName() == 'UIMiniWindowContainer'
end

function UIMiniWindowContainer:saveOrder()
    local char = currentCharacter()
    if not char or not MiniWindowLayout.live or not g_game.isOnline() then
        return
    end

    local result = {}
    for _, child in ipairs(self:getChildren()) do
        local id = child:getId()
        if id and #id > 0 then
            result[#result + 1] = id
        end
    end

    -- Windows that are not open right now (a closed backpack, a module not loaded yet) keep
    -- their slot after the neighbour they had.
    local _, saved = self:getSavedOrder()
    for i, id in ipairs(saved) do
        if not table.contains(result, id) and not placedInOtherPanel(id, self) then
            local position = 0
            for j = i - 1, 1, -1 do
                local found = table.find(result, saved[j])
                if found then
                    position = found
                    break
                end
            end
            table.insert(result, position + 1, id)
        end
    end

    local node = g_settings.getNode(ORDER_NODE) or {}
    node[char] = node[char] or {}
    node[char][self:getId()] = table.concat(result, ',')
    g_settings.setNode(ORDER_NODE, node)
end

function UIMiniWindowContainer:scheduleSaveOrder()
    if self.orderSavePending then
        return
    end
    self.orderSavePending = true
    addEvent(function()
        self.orderSavePending = false
        if not self:isDestroyed() then
            self:saveOrder()
        end
    end)
end

function UIMiniWindowContainer.create()
    local container = UIMiniWindowContainer.internalCreate()
    container.scheduledWidgets = {}
    container:setFocusable(false)
    container:setPhantom(true)
    return container
end

-- TODO: connect to window onResize event
-- TODO: try to resize another widget?
-- TODO: try to find another panel?
function UIMiniWindowContainer:fitAll(noRemoveChild)
    if not self:isVisible() then
        return
    end

    if self.ignoreFillAll or not MiniWindowLayout.live then
        return
    end

    if not noRemoveChild then
        local children = self:getChildren()
        if #children > 0 then
            noRemoveChild = children[#children]
        else
            return
        end
    end

    local sumHeight = 0
    local children = self:getChildren()
    for i = 1, #children do
        if children[i]:isVisible() then
            sumHeight = sumHeight + children[i]:getHeight()
        end
    end

    local selfHeight = self:getHeight() - (self:getPaddingTop() + self:getPaddingBottom())
    if sumHeight <= selfHeight then
        return
    end

    local removeChildren = {}

    -- try to resize noRemoveChild
    local maximumHeight = selfHeight - (sumHeight - noRemoveChild:getHeight())
    if noRemoveChild:isResizeable() and noRemoveChild:getMinimumHeight() <= maximumHeight then
        sumHeight = sumHeight - noRemoveChild:getHeight() + maximumHeight
        addEvent(function()
            noRemoveChild:setHeight(maximumHeight)
        end)
    end

    -- try to remove no-save widget
    for i = #children, 1, -1 do
        if sumHeight <= selfHeight then
            break
        end

        local child = children[i]
        if child ~= noRemoveChild and type(child.close) == 'function' and not child.save then
            local childHeight = child:getHeight()
            sumHeight = sumHeight - childHeight
            table.insert(removeChildren, child)
        end
    end

    -- try to remove save widget
    for i = #children, 1, -1 do
        if sumHeight <= selfHeight then
            break
        end

        local child = children[i]
        if child ~= noRemoveChild and type(child.close) == 'function' and child:isVisible() then
            local childHeight = child:getHeight()
            sumHeight = sumHeight - childHeight
            table.insert(removeChildren, child)
        end
    end

    for i = 1, #removeChildren do
        if type(removeChildren[i].close) == 'function' then
            removeChildren[i]:close()
        end
    end
end

function UIMiniWindowContainer:fits(child, minContentHeight, maxContentHeight)
    if self.ignoreFillAll then
        return 0
    end

    local containerPanel = child:getChildById('contentsPanel')
    local indispensableHeight = 0
    if containerPanel then
        indispensableHeight = containerPanel:getMarginTop() + containerPanel:getMarginBottom() +
            containerPanel:getPaddingTop() + containerPanel:getPaddingBottom()
    end

    local totalHeight = 0
    local children = self:getChildren()
    for i = 1, #children do
        if children[i]:isVisible() then
            totalHeight = totalHeight + children[i]:getHeight()
        end
    end

    local available = self:getHeight() - (self:getPaddingTop() + self:getPaddingBottom()) - totalHeight

    if maxContentHeight > 0 and available >= (maxContentHeight + indispensableHeight) then
        return maxContentHeight + indispensableHeight
    elseif available >= (minContentHeight + indispensableHeight) then
        return available
    else
        return -1
    end
end

function UIMiniWindowContainer:onDrop(widget, mousePos)
    if not widget.allowMixedDrop and ((self.onlyPhantomDrop and not widget.moveOnlyToMain) or
        (widget.moveOnlyToMain and not self.onlyPhantomDrop)) then
        return true
    end

    if widget.UIMiniWindowContainer then
        local oldParent = widget:getParent()
        if oldParent == self then
            return true
        end

        if oldParent then
            oldParent:removeChild(widget)
        end

        if widget.movedWidget then
            local index = self:getChildIndex(widget.movedWidget)
            self:insertChild(index + widget.movedIndex, widget)
        else
            self:addChild(widget)
        end

        local pId = widget:getParent():getId()
        if widget:getId() == "botWindow" and
            (pId == "gameLeftPanel" or pId == "gameLeftExtraPanel" or
                pId == "gameLeftExtraPanel2" or pId == "gameLeftExtraPanel3" or
                pId == "gameRightExtraPanel" or pId == "gameRightExtraPanel2" or
                pId == "gameRightExtraPanel3") then
            widget:getParent():setWidth(190)
        end
        self:fitAll(widget)
        return true
    end
end

function UIMiniWindowContainer:swapInsert(widget, index)
    local oldParent = widget:getParent()
    local oldIndex = self:getChildIndex(widget)

    if oldParent == self and oldIndex ~= index then
        local oldWidget = self:getChildByIndex(index)
        if oldWidget then
            self:removeChild(oldWidget)
            self:insertChild(oldIndex, oldWidget)
        end
        self:removeChild(widget)
        self:insertChild(index, widget)
    end
end

function UIMiniWindowContainer:scheduleInsert(widget, index)
    if index - 1 > self:getChildCount() then
        if self.scheduledWidgets[index] then
            pdebug('replacing scheduled widget id ' .. widget:getId())
        end
        self.scheduledWidgets[index] = widget
    else
        local oldParent = widget:getParent()
        if oldParent ~= self then
            if oldParent then
                oldParent:removeChild(widget)
            end
            self:insertChild(index, widget)
        end

        while true do
            local placed = false
            for nIndex, nWidget in pairs(self.scheduledWidgets) do
                if nIndex - 1 <= self:getChildCount() then
                    local nOldParent = nWidget:getParent()
                    if nOldParent ~= self then
                        if nOldParent then
                            nOldParent:removeChild(nWidget)
                        end
                        self:insertChild(nIndex, nWidget)
                    end
                    self.scheduledWidgets[nIndex] = nil
                    placed = true
                    break
                end
            end
            if not placed then
                break
            end
        end
    end
end

function UIMiniWindowContainer:order()
    local ranks = self:getSavedOrder()
    local ranked = {}
    for _, child in ipairs(self:getChildren()) do
        if ranks[child:getId()] then
            ranked[#ranked + 1] = child
        end
    end
    -- Highest rank first: each window then lands right before the ones already sorted after it.
    table.sort(ranked, function(a, b)
        return ranks[a:getId()] > ranks[b:getId()]
    end)
    for _, child in ipairs(ranked) do
        self:insertByOrder(child, ranks)
    end
end

function UIMiniWindowContainer:saveChildren()
    local children = self:getChildren()
    local ignoreIndex = 0
    for i = 1, #children do
        if children[i].save then
            children[i]:saveParentIndex(self:getId(), i - ignoreIndex)
        else
            ignoreIndex = ignoreIndex + 1
        end
    end
    self:scheduleSaveOrder()
end
