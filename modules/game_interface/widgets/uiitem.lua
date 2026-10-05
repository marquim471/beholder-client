function UIItem:onDragEnter(mousePos)
    if self:isVirtual() then
        return false
    end

    local item = self:getItem()
    if not item then
        return false
    end

    UIDragIcon:display(item)
    self:setBorderWidth(1)
    self.currentDragThing = item
    -- Use native cursor when enabled, otherwise use custom cursor
    if modules.client_options and modules.client_options.getOption('nativeCursor') then
        g_window.setSystemCursor('cross')
    else
        g_mouse.pushCursor('target')
    end
    return true
end

function UIItem:onDragLeave(droppedWidget, mousePos)
    if self:isVirtual() then
        return false
    end
    self.currentDragThing = nil
    -- Restore cursor
    if modules.client_options and modules.client_options.getOption('nativeCursor') then
        g_window.restoreMouseCursor()
    else
        g_mouse.popCursor('target')
    end
    UIDragIcon:hide()
    self:setBorderWidth(0)
    self.hoveredWho = nil
    return true
end

function UIItem:onDrop(widget, mousePos, forced)
    self:setBorderWidth(0)

    if not self:canAcceptDrop(widget, mousePos) and not forced then
        return false
    end

    local item = widget.currentDragThing
    if not item or not item:isItem() then
        return false
    end

    if self:isVirtual() then
        UIDragIcon:hide()
    end

    local itemPos = item:getPosition()
    local itemTile = item:getTile()
    local toPos = self.position
    if not (toPos) and self:getParent() and self:getParent().slotPosition then
        toPos = self:getParent().slotPosition
    end
    if modules.game_actionbar and modules.game_actionbar.tryAssignActionButtonFromDrop(mousePos, widget, item:getId()) then
        return true
    end

    if self.selectable then
        if item:isPickupable() then
            self:setItem(Item.create(item:getId(), item:getCountOrSubType()))
            return true
        end
        return false
    end

    if not itemPos then
        return false
    end

    if itemPos.x ~= 65535 and not itemTile then
        return false
    end

    if itemPos.x == toPos.x and itemPos.y == toPos.y and itemPos.z == toPos.z then
        return false
    end

    if item:getCount() > 1 then
        modules.game_interface.moveStackableItem(item, toPos)
    else
        g_game.move(item, toPos, 1)
    end

    return true
end

function UIItem:onDestroy()
    if self == g_ui.getDraggingWidget() and self.hoveredWho then
        self.hoveredWho:setBorderWidth(0)
    end

    if self:isVirtual() then
        UIDragIcon:hide()
    end

    if self.hoveredWho then
        self.hoveredWho = nil
    end
end

function UIItem:onHoverChange(hovered)
    UIWidget.onHoverChange(self, hovered)

    if self:isVirtual() or not self:isDraggable() then
        local draggingWidget = g_ui.getDraggingWidget()
        if not draggingWidget or draggingWidget == self then
            UIDragIcon:hide()
        end
        return
    end

    local draggingWidget = g_ui.getDraggingWidget()
    if draggingWidget and self ~= draggingWidget then
        local gotMap = draggingWidget:getClassName() == 'UIGameMap'
        local gotItem = draggingWidget:getClassName() == 'UIItem' and not draggingWidget:isVirtual()
        if hovered and (gotItem or gotMap) then
            self:setBorderWidth(1)
            draggingWidget.hoveredWho = self
        else
            self:setBorderWidth(0)
            draggingWidget.hoveredWho = nil
        end
    end

    if g_game.getFeature(GameItemTooltipV8) then
        local tooltip = ""
        local function splitTextIntoLines(text, maxLineLength)
            local words = {}
            for word in text:gmatch("%S+") do
                table.insert(words, word)
            end

            local lines = {}
            local currentLine = words[1]
            for i = 2, #words do
                if currentLine:len() + 1 + words[i]:len() > maxLineLength then
                    table.insert(lines, currentLine)
                    currentLine = words[i]
                else
                    currentLine = currentLine .. " " .. words[i]
                end
            end
            table.insert(lines, currentLine)

            return table.concat(lines, "\n")
        end

        if self:getItem() and self:getItem():getTooltip():len() > 0 then
            tooltip = splitTextIntoLines(self:getItem():getTooltip(), 80)
            if tooltip then
                self:setTooltip(tooltip)
            end
        end
    end
end

function UIItem:onMouseRelease(mousePosition, mouseButton)
    if self.cancelNextRelease then
        self.cancelNextRelease = false
        return true
    end

    if self:isVirtual() then
        UIDragIcon:hide()
        return false
    end

    local item = self:getItem()
    if not item or not self:containsPoint(mousePosition) then
        return false
    end

    if modules.client_options.getOption('classicControl') and not g_platform.isMobile() and
        ((g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton) or
            (g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton)) then
        g_game.look(item)
        self.cancelNextRelease = true
        return true
    elseif modules.game_interface.processMouseAction(mousePosition, mouseButton, nil, item, item, nil, nil) then
        return true
    end
    return false
end

function UIItem:canAcceptDrop(widget, mousePos)
    if not self.selectable and (self:isVirtual() or not self:isDraggable()) then
        return false
    end

    if not widget or not widget.currentDragThing then
        return false
    end

    local children = rootWidget:recursiveGetChildrenByPos(mousePos)
    for i = 1, #children do
        local child = children[i]
        if child == self then
            return true
        elseif not child:isPhantom() then
            return false
        end
    end

    error('Widget ' .. self:getId() .. ' not in drop list.')
    return false
end

function UIItem:onClick(mousePos)
    if not self.selectable or not self.editable then
        return
    end

    if modules.game_itemselector then
        modules.game_itemselector.show(self)
    end
end

-- Object categories in the order of the Manage Containers dialog, with the official market names.
local MANAGED_CONTAINER_CATEGORIES = {
    { 31, 'Unassigned' }, { 30, 'Gold' }, { 1, 'Armors' }, { 2, 'Amulets' }, { 3, 'Boots' },
    { 4, 'Containers' }, { 24, 'Creature Products' }, { 5, 'Decoration' }, { 6, 'Food' },
    { 7, 'Helmets and Hats' }, { 8, 'Legs' }, { 9, 'Others' }, { 10, 'Potions' }, { 11, 'Rings' },
    { 12, 'Runes' }, { 13, 'Shields' }, { 14, 'Tools' }, { 15, 'Valuables' }, { 16, 'Weapons: Ammo' },
    { 17, 'Weapons: Axes' }, { 18, 'Weapons: Clubs' }, { 19, 'Weapons: Distance' },
    { 20, 'Weapons: Swords' }, { 21, 'Weapons: Wands' }, { 27, 'Weapons: Fist' }, { 25, 'Quivers' }
}

local function categoryList(caption, flags)
    local lines = {}
    for _, category in ipairs(MANAGED_CONTAINER_CATEGORIES) do
        if bit.band(flags, bit.lshift(1, category[1])) ~= 0 then
            lines[#lines + 1] = category[2]
        end
    end
    if #lines == 0 then
        return nil
    end
    return caption .. '\n' .. table.concat(lines, '\n')
end

-- Official ContainerSlot: a 7x9 loot bag 1 px inside the bottom-right corner of a container that
-- Manage Containers uses, moved to the top-right when the slot shows a count; hovering it lists
-- the categories.
function UIItem:updateManagedContainerIcon()
    local item = self:getItem()
    local tooltip
    -- Only real slots: not virtual previews such as the 15x15 container window title icon.
    if item and item:isContainer() and item.getQuickLootFlags and not self:isVirtual() then
        local lootFlags, obtainFlags = item:getQuickLootFlags(), item:getObtainFlags()
        -- The server falls back to the main backpack for Unassigned on its own; that default is not a
        -- container the player linked, so it does not mark the backpack.
        local player = g_game.getLocalPlayer()
        if player and player:getInventoryItem(InventorySlotBack) == item then
            local unassigned = bit.bnot(bit.lshift(1, 31))
            lootFlags, obtainFlags = bit.band(lootFlags, unassigned), bit.band(obtainFlags, unassigned)
        end
        local parts = {}
        parts[#parts + 1] = categoryList(tr('Loot container for:'), lootFlags)
        parts[#parts + 1] = categoryList(tr('Obtain container for:'), obtainFlags)
        if #parts > 0 then
            tooltip = table.concat(parts, '\n\n')
        end
    end

    local icon = self.managedContainerIcon
    self.managedContainerTooltip = tooltip
    if not tooltip then
        if icon then
            icon:hide()
        end
        return
    end
    if not icon then
        -- The icon is phantom so the slot keeps its clicks and drags; its tooltip follows the mouse instead.
        icon = g_ui.createWidget('ManagedContainerIcon', self)
        self.managedContainerIcon = icon
        local function refreshIconTooltip(widget, mousePos)
            local over = widget.managedContainerTooltip ~= nil and widget:isHovered() and icon:isVisible()
                and icon:containsPoint(mousePos or g_window.getMousePosition())
            if over == (widget.overManagedContainerIcon == true) then
                return
            end
            widget.overManagedContainerIcon = over
            g_tooltip.hide()
            if over then
                g_tooltip.display(widget.managedContainerTooltip)
            elseif widget.tooltip then
                g_tooltip.display(widget.tooltip)
            end
        end
        connect(self, {
            onMouseMove = function(widget, mousePos) refreshIconTooltip(widget, mousePos) end,
            onHoverChange = function(widget) refreshIconTooltip(widget) end
        })
    end
    local showsCount = item:getCount() > 1
    icon:breakAnchors()
    icon:addAnchor(AnchorRight, 'parent', AnchorRight)
    if showsCount then
        icon:addAnchor(AnchorTop, 'parent', AnchorTop)
    else
        icon:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    end
    icon:setTooltip(tooltip)
    icon:show()
    icon:raise()
end

function UIItem:onItemChange()
    local tooltip = ""
    if self:getItem() and self:getItem():getTooltip():len() > 0 then
        tooltip = self:getItem():getTooltip()
    end
    self:setTooltip(tooltip)
    self:updateManagedContainerIcon()
end
