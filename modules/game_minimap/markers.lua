local function showMarkerMenu(map, mousePos, mapPos, flag)
    local menu = g_ui.createWidget('MinimapMarkerMenu')
    menu:setGameMenu(true)
    menu:getLayout():setSpacing(3)
    local function addOption(text, callback)
        local button = g_ui.createWidget('MinimapMarkerMenuButton', menu)
        local label
        for _, offset in ipairs({{-1, 0}, {1, 0}, {0, -1}, {0, 1}, {0, 0}}) do
            label = g_ui.createWidget('UIWidget', button)
            label:setFont('verdana-bold-11px-native')
            label:setText(text)
            label:setTextAlign(AlignLeft)
            label:setColor(offset[1] == 0 and offset[2] == 0 and '#f7f7f7' or 'black')
            label:setSize(label:getTextSize())
            label:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            label:addAnchor(AnchorTop, 'parent', AnchorTop)
            label:setMarginLeft(2 + offset[1])
            label:setMarginTop(2 + offset[2])
            label:setPhantom(true)
        end
        menu:setWidth(math.max(menu:getWidth(), label:getTextSize().width + 52))
        button.onClick = function()
            menu:destroy()
            callback()
        end
    end
    if flag then
        addOption(tr('Edit Mark'), function() map:createFlagWindow(mapPos, flag) end)
        addOption(tr('Delete mark'), function() flag:destroy() end)
    else
        addOption(tr('Create Mark'), function() map:createFlagWindow(mapPos) end)
    end
    local destroy = menu.onDestroy
    menu.onDestroy = function(self)
        if map.markerMenu == self then map.markerMenu = nil end
        destroy(self)
    end
    map.markerMenu = menu
    menu:display(mousePos)
end

local function highlightMarker(map, flag)
    if not flag.highlight then
        flag.highlight = g_ui.createWidget('UIWidget', flag)
        flag.highlight:setSize({width = 15, height = 15})
        flag.highlight:setImageSource('/images/automap/marker-highlight')
        local index = tonumber(flag.icon)
        if index and index >= 0 and index < 20 then
            flag.highlight:setIcon('/images/automap/markers')
            flag.highlight:setIconClip({x = index * 11, y = 0, width = 11, height = 11})
        else
            flag.highlight:setIcon(flag.icon)
        end
        flag.highlight:setIconSize({width = 11, height = 11})
        flag.highlight:setIconOffset({x = 2, y = 2})
        flag.highlight:setPhantom(true)
        flag.highlight:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
        flag.highlight:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        flag:lowerChild(flag.highlight)
    end
    flag:setClipping(false)
    flag.highlightUntil = g_clock.millis() + 15000
    flag.highlight:setVisible(map.markerHighlightsVisible)
    flag.highlightEvent = scheduleEvent(function()
        flag.highlight:hide()
        flag.highlightUntil = nil
        flag.highlightEvent = nil
    end, 15000)
end

local function createMarkerDialog(map, pos, existing)
    if map.flagWindow or not pos then return end
    local window = g_ui.createWidget('MinimapMarkerDialog', rootWidget)
    map.flagWindow = window
    local group = UIRadioGroup.create()
    for index = 0, 19 do
        local choice = g_ui.createWidget('MinimapMarkerChoice', window.symbols)
        choice.icon = index
        choice:setIconClip({x = index * 11, y = 0, width = 11, height = 11})
        group:addWidget(choice)
        if index == (existing and tonumber(existing.icon) or 0) then group:selectWidget(choice) end
    end
    window.description:setText(existing and existing.description or '')
    window.description:focus()
    local function cancel() map:destroyFlagWindow() end
    local function accept()
        local selected = group:getSelectedWidget()
        if not selected then return end
        local temporary = existing and existing.temporary or false
        local old = map:getFlag(pos)
        if old then old:destroy() end
        map:addFlag({x = pos.x, y = pos.y, z = pos.z}, selected.icon,
            window.description:getText(), temporary)
        cancel()
    end
    window.okButton.onClick = accept
    window.cancelButton.onClick = cancel
    window.onEnter = accept
    window.onEscape = cancel
    window.onDestroy = function()
        group:destroy()
        if map.flagWindow == window then map.flagWindow = nil end
    end
end

function configureMinimapMarkers(map)
    g_ui.importStyle('markers.otui')
    map.createFlagWindow = createMarkerDialog
    local releaseMap = map.onMouseRelease
    map.onMouseRelease = function(self, pos, button)
        if button ~= MouseRightButton then return releaseMap(self, pos, button) end
        if not self.allowNextRelease then return true end
        self.allowNextRelease = false
        local mapPos = self:getTilePosition(pos)
        if not mapPos then return false end
        showMarkerMenu(self, pos, mapPos)
        return true
    end
    map.markerHighlightsVisible = false
    local function blinkMarkers()
        map.markerHighlightsVisible = not map.markerHighlightsVisible
        local now = g_clock.millis()
        for _, flag in pairs(map.flags) do
            if flag.highlight then
                flag.highlight:setVisible(flag.highlightUntil ~= nil and
                    flag.highlightUntil > now and map.markerHighlightsVisible)
            end
        end
        map.markerBlinkEvent = scheduleEvent(blinkMarkers, 500)
    end
    map.markerBlinkEvent = scheduleEvent(blinkMarkers, 500)
    local destroyMap = map.onDestroy
    map.onDestroy = function(self)
        if self.markerMenu then self.markerMenu:destroy() end
        removeEvent(self.markerBlinkEvent)
        for _, flag in pairs(self.flags) do
            if flag.highlightEvent then removeEvent(flag.highlightEvent) end
        end
        destroyMap(self)
    end
    local addFlag = map.addFlag
    map.addFlag = function(self, pos, icon, description, temporary)
        local previous = pos and self:getFlag(pos)
        addFlag(self, pos, icon, description, temporary)
        local flag = pos and self:getFlag(pos)
        if not flag or previous then return end
        local index = tonumber(icon)
        if index and index >= 0 and index < 20 then
            flag:setIcon('/images/automap/markers')
            flag:setIconClip({x = index * 11, y = 0, width = 11, height = 11})
            flag:setIconSize({width = 11, height = 11})
        end
        flag:setDraggable(true)
        flag:setDragThreshold(10)
        flag.onDragEnter = function(widget)
            local clicked = widget:getLastClickPosition()
            self.dragReference = {x = clicked.x, y = clicked.y}
            self.draggingMarker = widget
            self.allowNextRelease = false
            return true
        end
        flag.onDragMove = function(widget, mousePos)
            return self.onDragMove(self, mousePos)
        end
        flag.onDragLeave = function()
            self.draggingMarker = nil
            return true
        end
        local release = flag.onMouseRelease
        flag.onMouseRelease = function(widget, mousePos, button)
            if not widget:containsPoint(mousePos) then return false end
            if button ~= MouseRightButton then return release(widget, mousePos, button) end
            showMarkerMenu(self, mousePos, flag.pos, flag)
            return true
        end
        local destroy = flag.onDestroy
        flag.onDestroy = function()
            if self.draggingMarker == flag then self.draggingMarker = nil end
            if flag.highlightEvent then removeEvent(flag.highlightEvent) end
            destroy()
        end
        configureMinimapTooltip(flag, description, false)
        if not self.loadingMarkers then highlightMarker(self, flag) end
    end
    local load = map.load
    map.load = function(self)
        self.loadingMarkers = true
        load(self)
        self.loadingMarkers = false
    end
end
