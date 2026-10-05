local iconTopMenu = nil
-- @ Minimap
local minimapWidget = nil -- bot fix
local otmm = true
local oldPos = nil
local fullscreenWidget
local virtualFloor = 7
local markersBinFile = nil
local markersBinLastLoadAt = 0
local markersInitialLoadEvent = nil
local markersStartupWarmupEvent = nil
local minimapRestoreWatchdogEvent = nil
local MARKERS_BIN_LOAD_INTERVAL_MS = 180
local MINIMAP_SYNC_OPCODE = 92
local minimapSyncScheduled = false
local MINIMAP_STARTUP_DEBUG = false
local markersPreloadQueueEvent = nil
local markersPreloadStartEvent = nil
local markersLoadedFloors = {}
local markersQueuedFloors = {}
local markersPreloadQueue = {}
local lastMarkersPlayerFloor = nil
local MARKERS_PRELOAD_LOGIN_DELAY_MS = 0
local MARKERS_PRELOAD_STEP_DELAY_MS = 900
local MARKERS_PRELOAD_RADIUS = 2
local PARTY_MINIMAP_ICON_PATHS = {
    [1] = '/images/game/minimap/knight',
    [2] = '/images/game/minimap/paladin',
    [3] = '/images/game/minimap/sorcerer',
    [4] = '/images/game/minimap/druid',
    [5] = '/images/game/minimap/monk'
}
local loadMarkersForCurrentFloor = nil
local partyMinimapMembers = {}
local partyMinimapFlagPositions = {}
local currentDayTime = {
    h = 12,
    m = 0
}
local worldTimeMinutes = 12 * 60
local worldTimeReceivedAt = 0

local minimapKeybinds = {
    { action = 'Center', key = '', callback = function() resetMap() end },
    { action = 'Scroll north', key = 'Alt+Up', direction = 'north' },
    { action = 'Scroll east', key = 'Alt+Right', direction = 'east' },
    { action = 'Scroll south', key = 'Alt+Down', direction = 'south' },
    { action = 'Scroll west', key = 'Alt+Left', direction = 'west' },
    { action = 'Show higher floor', key = 'Alt+PageUp', callback = function() upLayer() end },
    { action = 'Show lower floor', key = 'Alt+PageDown', callback = function() downLayer() end },
    { action = 'Zoom out', key = 'Alt+Home', callback = function() zoomOut() end },
    { action = 'Zoom in', key = 'Alt+End', callback = function() zoomIn() end }
}
local MINIMAP_OTMM_READ_FILE = 'data/minimap/minimap.otmm'
local MINIMAP_OTMM_WRITE_DIR = '/minimap'
local MINIMAP_OTMM_WRITE_FILE = '/minimap/minimap.otmm'
local MINIMAP_MARKERS_BIN_FILE = '/data/minimap/minimapmarkers.bin'
-- Official MinimapPanel: 111 px map plus the panel's top and bottom margins.
local MINIMAP_PANEL_HEIGHT = 119
-- Room the main right panel always leaves for the windows below it when the minimap grows.
local MAIN_PANEL_ROOM_BELOW = 60
-- Shortest minimap where the rose, the floor arrows and the zoom buttons all fit with room to spare.
local MAIN_PANEL_MINIMAP_MIN_HEIGHT = 180
local MAPVIEW_CROSS_BASE_OFFSET_X = -5
local MAPVIEW_CROSS_BASE_OFFSET_Y = -5
local minimapOriginalOnZoomChange = nil
-- Root panel whose height bounds the minimap in the main right panel (see updateMiniMapResizePolicy).
local followedRootPanel = nil
local minimapOriginalOnCameraPositionChange = nil
local SEA_FLOOR = 7
local satellitePreferred = false
local satelliteAssetsDir = nil
local satelliteLoadedFloors = {}

local function minimapStartupDebug(message)
    if not MINIMAP_STARTUP_DEBUG then
        return
    end
    print(string.format('[MINIMAP_STARTUP_DEBUG] %s', message))
end

local function clonePosition(pos)
    if not pos then
        return nil
    end

    return {
        x = pos.x,
        y = pos.y,
        z = pos.z
    }
end

local function isSamePosition(a, b)
    return a and b and a.x == b.x and a.y == b.y and a.z == b.z
end

local function getActiveMinimapWidget()
    if fullscreenWidget and not fullscreenWidget:isDestroyed() then
        return fullscreenWidget
    end

    if mapController and mapController.ui and not mapController.ui:isDestroyed() and
        mapController.ui.minimapBorder and mapController.ui.minimapBorder.minimap then
        return mapController.ui.minimapBorder.minimap
    end

    return nil
end

local function isSurfaceFloor(floor)
    return floor ~= nil and floor <= SEA_FLOOR
end

local function resetSatelliteFloorCache()
    satelliteAssetsDir = nil
    satelliteLoadedFloors = {}
    if g_satelliteMap then
        g_satelliteMap.clear()
    end
end

local function ensureSatelliteFloorsLoaded()
    if not g_satelliteMap then
        return
    end

    local assetsDir = string.format('/data/things/%d', g_game.getClientVersion())
    if satelliteAssetsDir ~= assetsDir then
        resetSatelliteFloorCache()
        satelliteAssetsDir = assetsDir
    end

    local floorMax = virtualFloor <= SEA_FLOOR and SEA_FLOOR or virtualFloor
    local minNeeded = nil
    local maxNeeded = nil

    for floor = virtualFloor, floorMax do
        if not satelliteLoadedFloors[floor] then
            if not minNeeded then
                minNeeded = floor
            end
            maxNeeded = floor
        end
    end

    if minNeeded then
        g_satelliteMap.loadFloors(assetsDir, minNeeded, maxNeeded)
        for floor = minNeeded, maxNeeded do
            satelliteLoadedFloors[floor] = true
        end
    end
end

local function canUseSatelliteOnCurrentFloor()
    return isSurfaceFloor(virtualFloor) and g_satelliteMap and g_satelliteMap.hasChunksForView(virtualFloor)
end

local function refreshSatelliteMode()
    local minimap = getActiveMinimapWidget()
    local satelliteToggle = mapController and mapController.ui and not mapController.ui:isDestroyed() and
        mapController.ui:getChildById('satelliteToggle') or nil

    ensureSatelliteFloorsLoaded()

    local canUseSatellite = canUseSatelliteOnCurrentFloor()
    if minimap then
        minimap:setSatelliteMode(satellitePreferred and canUseSatellite)
    end

    if satelliteToggle then
        satelliteToggle:setEnabled(canUseSatellite)
        satelliteToggle:setChecked(satellitePreferred and canUseSatellite)
    end
end

local function getPartyMinimapIcon(member)
    if member.isLeader then
        return '/images/game/minimap/partyleader'
    end

    return PARTY_MINIMAP_ICON_PATHS[member.vocation] or '/images/game/minimap/partymember'
end

local function clearPartyMinimapFlags()
    local widget = getActiveMinimapWidget()
    if widget then
        for _, marker in pairs(partyMinimapFlagPositions) do
            widget:removeFlag(marker.position)
        end
    end

    partyMinimapFlagPositions = {}
end

local function syncPartyMinimapFlags()
    local widget = getActiveMinimapWidget()
    if not widget then
        return
    end

    for memberId, marker in pairs(partyMinimapFlagPositions) do
        local member = partyMinimapMembers[memberId]
        local nextIcon = member and getPartyMinimapIcon(member) or nil
        if not member or not member.position or not isSamePosition(marker.position, member.position) or marker.icon ~= nextIcon then
            widget:removeFlag(marker.position)
            partyMinimapFlagPositions[memberId] = nil
        end
    end

    for memberId, member in pairs(partyMinimapMembers) do
        if member.position then
            local icon = getPartyMinimapIcon(member)
            local oldMarker = partyMinimapFlagPositions[memberId]
            if oldMarker and (not isSamePosition(oldMarker.position, member.position) or oldMarker.icon ~= icon) then
                widget:removeFlag(oldMarker.position)
            end

            local markerPos = clonePosition(member.position)
            partyMinimapFlagPositions[memberId] = {
                position = markerPos,
                icon = icon
            }
            widget:addFlag(markerPos, icon, member.memberName or '', true)
        end
    end
end

local function onPartyMinimapPositions(members)
    partyMinimapMembers = {}

    for _, member in ipairs(members or {}) do
        if member.memberID and member.position then
            partyMinimapMembers[member.memberID] = member
        end
    end

    syncPartyMinimapFlags()
end

local function getPreferredOtmmLoadFile()
    if g_resources.fileExists(MINIMAP_OTMM_WRITE_FILE) then
        return MINIMAP_OTMM_WRITE_FILE
    end
    if g_resources.fileExists(MINIMAP_OTMM_READ_FILE) then
        return MINIMAP_OTMM_READ_FILE
    end
    return nil
end

local function ensureOtmmWriteDir()
    if not (g_resources and g_resources.directoryExists and g_resources.makeDir) then
        return
    end

    local dirs = { MINIMAP_OTMM_WRITE_DIR, 'minimap' }
    for _, dir in ipairs(dirs) do
        if dir and dir:len() > 0 and not g_resources.directoryExists(dir) then
            pcall(function()
                g_resources.makeDir(dir)
            end)
        end
    end
end

local function refreshMainRightPanelLimit()
    if modules.game_interface and modules.game_interface.updateRightTopDividerLimit then
        modules.game_interface.updateRightTopDividerLimit()
    end

    if modules.game_mainpanel and modules.game_mainpanel.reloadMainPanelSizes then
        modules.game_mainpanel.reloadMainPanelSizes()
    end
end

local function applyMapViewCrossOffset(widget)
    if not widget or widget:isDestroyed() or not widget.cross then
        return
    end

    local cross = widget.cross
    if cross and cross.setIconOffsetX and cross.setIconOffsetY then
        if cross.setClipping then
            cross:setClipping(false)
        end
        cross:setIconOffsetX(MAPVIEW_CROSS_BASE_OFFSET_X)
        cross:setIconOffsetY(MAPVIEW_CROSS_BASE_OFFSET_Y)
    end
end

local function isHorizontalMiniMapParent(parent)
    if not parent or parent:isDestroyed() then
        return false
    end

    local parentId = parent:getId()
    return parentId == 'gameLeftTopPanel' or parentId == 'gameRightTopPanel'
end

local function applyHorizontalMiniMapHeight()
    if not mapController or not mapController.ui or mapController.ui:isDestroyed() then
        return
    end

    local ui = mapController.ui
    local parent = ui:getParent()
    if not isHorizontalMiniMapParent(parent) then
        return
    end

    -- Fills what the other windows of the top panel leave free, down to the panel's bottom.
    local targetHeight = parent:getHeight()
    if parent.getPaddingTop then
        targetHeight = targetHeight - parent:getPaddingTop() - parent:getPaddingBottom()
    end
    for _, sibling in ipairs(parent:getChildren()) do
        if sibling ~= ui and sibling:isVisible() then
            targetHeight = targetHeight - sibling:getHeight()
        end
    end

    targetHeight = math.max(ui:getMinimumHeight(), targetHeight)
    if ui:getHeight() ~= targetHeight then
        ui:setHeight(targetHeight)
    end
end

local function updateMiniMapResizePolicy()
    if not mapController or not mapController.ui or mapController.ui:isDestroyed() then
        return
    end

    local ui = mapController.ui
    local parent = ui:getParent()
    local resizeBorder = ui:getChildById('bottomResizeBorder')
    local isDefaultParent = parent and parent:getId() == 'gameMainRightPanel'
    local isHorizontalParent = isHorizontalMiniMapParent(parent)

    if resizeBorder then
        if isHorizontalParent then
            resizeBorder:disable()
            resizeBorder:hide()
        else
            resizeBorder:show()
            resizeBorder:enable()
        end
    end

    -- In the main right panel the height comes from panelHeight (see reloadMainPanelSizes), so the
    -- bottom border drags panelHeight itself, as the RTC's minimap does; the map fills the window.
    if isDefaultParent then
        ui.defaultPanelHeight = ui.defaultPanelHeight or ui.panelHeight
        -- The saved height belongs to the character, so it is read once per login.
        local character = g_game.isOnline() and g_game.getCharacterName() or nil
        if character and ui.mainPanelHeightFor ~= character then
            ui.mainPanelHeightFor = character
            local saved = tonumber(ui:getSettings('mainPanelHeight')) or ui.defaultPanelHeight
            ui.panelHeight = math.max(MAIN_PANEL_MINIMAP_MIN_HEIGHT, saved)
            refreshMainRightPanelLimit()
        end
        if resizeBorder then
            -- Room from the panel's top (lower when the right top panel is open) to the bottom of the screen.
            local root = modules.game_interface.getRootPanel()
            local others = parent:getHeight() - ui.panelHeight
            local room = root:getY() + root:getHeight() - parent:getY()
            local maximum = math.max(MAIN_PANEL_MINIMAP_MIN_HEIGHT, room - others - MAIN_PANEL_ROOM_BELOW)
            resizeBorder.defaultLimits = resizeBorder.defaultLimits or
                { resizeBorder:getMinimum(), resizeBorder:getMaximum() }
            resizeBorder:setMinimum(MAIN_PANEL_MINIMAP_MIN_HEIGHT)
            resizeBorder:setMaximum(maximum)

            -- When the client gets shorter the minimap shrinks so the windows below stay on screen, and
            -- when it grows again the minimap goes back up to the height the player chose.
            if not resizeBorder:isPressed() then
                local chosen = tonumber(ui:getSettings('mainPanelHeight')) or ui.defaultPanelHeight
                local height = math.max(MAIN_PANEL_MINIMAP_MIN_HEIGHT, math.min(chosen, maximum))
                if height ~= ui.panelHeight then
                    ui.panelHeight = height
                    refreshMainRightPanelLimit()
                end
            end
        end
    elseif resizeBorder and resizeBorder.defaultLimits then
        resizeBorder:setMinimum(resizeBorder.defaultLimits[1])
        resizeBorder:setMaximum(resizeBorder.defaultLimits[2])
        resizeBorder.defaultLimits = nil
    end
    if not isDefaultParent and not isHorizontalParent and ui:getHeight() < ui:getMinimumHeight() then
        ui:setHeight(ui:getMinimumHeight())
    end

    -- In a top panel the minimap follows the panel's height while its bottom border is dragged,
    -- both ways; the panel then counts only the minimap's minimum height as its content.
    ui.followsPanelHeight = isHorizontalParent
    local followed = isHorizontalParent and parent or nil
    if ui.followedPanel ~= followed then
        if ui.followedPanel and not ui.followedPanel:isDestroyed() then
            disconnect(ui.followedPanel, { onGeometryChange = applyHorizontalMiniMapHeight })
        end
        ui.followedPanel = followed
        if followed then
            connect(followed, { onGeometryChange = applyHorizontalMiniMapHeight })
        end
    end

    if isHorizontalParent then
        applyHorizontalMiniMapHeight()
    end
end



function updateDockedMiniMapResize()
    updateMiniMapResizePolicy()
end

local function findMiniMapDockTarget(mousePos, draggedWidget)
    if not mousePos then
        return nil
    end

    local root = g_ui.getRootWidget()
    if not root then
        return nil
    end

    local clickedWidget = root:recursiveGetChildByPos(mousePos, false)
    while clickedWidget do
        if clickedWidget ~= draggedWidget and clickedWidget:getClassName() == 'UIMiniWindowContainer' then
            return clickedWidget
        end
        clickedWidget = clickedWidget:getParent()
    end

    return nil
end

local function dockMiniMapToParent(targetParent, ui)
    if not targetParent or not ui or ui:isDestroyed() or targetParent:isDestroyed() then
        return false
    end

    if targetParent == ui:getParent() then
        updateMiniMapResizePolicy()
        return true
    end

    if targetParent:fits(ui, ui:getMinimumHeight(), 0) < 0 then
        return false
    end

    local oldParent = ui:getParent()
    if oldParent then
        oldParent:removeChild(ui)
    end

    ui:setParent(targetParent)
    if ui:getParent() ~= targetParent then
        return false
    end

    ui.free = false
    ui.movingReference = nil
    ui.oldParentDrag = nil
    ui.oldParentDragIndex = nil
    ui:setPosition({ x = 0, y = 0 })

    if ui.open then
        ui:open(true)
    end
    ui:show()

    if targetParent.fitAll then
        targetParent:fitAll(ui)
    end
    if targetParent.updateLayout then
        targetParent:updateLayout()
    end
    if targetParent.updateParentLayout then
        targetParent:updateParentLayout()
    end

    updateMiniMapResizePolicy()
    refreshMainRightPanelLimit()
    return true
end

local function setupMiniMapWindowUi(ui)
    if not ui or ui:isDestroyed() then
        return
    end

    if ui.setup then
        ui:setup()
    end

    -- Make sure the minimap behaves like a regular dockable miniwindow.
    ui.UIMiniWindowContainer = true
    ui.allowMixedDrop = true
    ui.moveOnlyToMain = false
    ui.onlyPhantomDrop = false

    local defaultOnDragLeave = ui.onDragLeave
    ui.onDragLeave = function(widget, droppedWidget, mousePos)
        local result = true
        if defaultOnDragLeave then
            result = defaultOnDragLeave(widget, droppedWidget, mousePos)
        end
        addEvent(updateMiniMapResizePolicy)
        addEvent(refreshMainRightPanelLimit)
        return result
    end

    local defaultOnDragEnter = ui.onDragEnter
    ui.onDragEnter = function(widget, mousePos)
        local result = true
        if defaultOnDragEnter then
            result = defaultOnDragEnter(widget, mousePos)
        end
        addEvent(updateMiniMapResizePolicy)
        addEvent(refreshMainRightPanelLimit)
        return result
    end

    local defaultOnMouseRelease = ui.onMouseRelease
    ui.onMouseRelease = function(widget, mousePos, mouseButton)
        local wasDragging = widget and not widget:isDestroyed() and widget.isDragging and widget:isDragging()
        local result = true

        if defaultOnMouseRelease then
            result = defaultOnMouseRelease(widget, mousePos, mouseButton)
        end

        local targetParent = nil
        if wasDragging and mouseButton == MouseLeftButton then
            targetParent = findMiniMapDockTarget(mousePos, widget)
            if targetParent then
                dockMiniMapToParent(targetParent, widget)
            end
        end

        addEvent(updateMiniMapResizePolicy)
        addEvent(refreshMainRightPanelLimit)

        return result
    end

    -- The client's height bounds the minimap in the main right panel, so follow the root panel too.
    local rootPanel = modules.game_interface.getRootPanel()
    if rootPanel and followedRootPanel ~= rootPanel then
        if followedRootPanel and not followedRootPanel:isDestroyed() then
            disconnect(followedRootPanel, { onGeometryChange = updateMiniMapResizePolicy })
        end
        followedRootPanel = rootPanel
        connect(rootPanel, { onGeometryChange = updateMiniMapResizePolicy })
    end

    local defaultOnGeometryChange = ui.onGeometryChange
    ui.onGeometryChange = function(widget, oldRect, newRect)
        if defaultOnGeometryChange then
            defaultOnGeometryChange(widget, oldRect, newRect)
        end
        updateMiniMapResizePolicy()
    end

    -- Dragging the bottom border in the main right panel resizes the panel first, so the
    -- container's fitAll (run by the default onHeightChange) finds room and keeps the new height.
    local defaultOnHeightChange = ui.onHeightChange
    ui.onHeightChange = function(widget, height)
        local parent = widget:getParent()
        local resizeBorder = widget:getChildById('bottomResizeBorder')
        if parent and parent:getId() == 'gameMainRightPanel' and resizeBorder and resizeBorder:isPressed() and
            height ~= widget.panelHeight then
            widget.panelHeight = height
            widget:setSettings({ mainPanelHeight = height })
            refreshMainRightPanelLimit()
        end
        if defaultOnHeightChange then
            defaultOnHeightChange(widget, height)
        end
    end

    local headerButtons = {
        'closeButton',
        'minimizeButton',
        'toggleFilterButton',
        'contextMenuButton',
        'newWindowButton',
        'lockButton'
    }

    for _, buttonId in ipairs(headerButtons) do
        local button = ui:recursiveGetChildById(buttonId)
        if button then
            button:hide()
            button:setEnabled(false)
        end
    end

    -- The official minimap panel has no caption bar and never scrolls.
    for _, headerId in ipairs({ 'miniwindowHeader', 'miniwindowHeaderBevel', 'miniwindowHeaderBorder', 'miniwindowTitle',
                                'miniwindowScrollBar' }) do
        local header = ui:getChildById(headerId)
        if header then
            header:hide()
        end
    end

    if ui.setText then
        ui:setText('')
    end

    if ui.minimapBorder and ui.minimapBorder.minimap then
        local minimap = ui.minimapBorder.minimap
        local floorUpButton = minimap:getChildById('floorUpButton')
        local floorDownButton = minimap:getChildById('floorDownButton')
        local zoomInButton = minimap:getChildById('zoomInButton')
        local zoomOutButton = minimap:getChildById('zoomOutButton')
        local resetButton = minimap:getChildById('resetButton')
        if floorUpButton then floorUpButton:hide() end
        if floorDownButton then floorDownButton:hide() end
        if zoomInButton then zoomInButton:hide() end
        if zoomOutButton then zoomOutButton:hide() end
        if resetButton then resetButton:hide() end
    end

    updateMiniMapResizePolicy()
    refreshMainRightPanelLimit()
end

local function restoreMiniMapDockAfterLogin()
    if not mapController or not mapController.ui or mapController.ui:isDestroyed() then
        return
    end

    local ui = mapController.ui
    local savedParentId = nil
    local savedIndex = nil
    if ui.getSettings then
        savedParentId = ui:getSettings('parentId')
        savedIndex = ui:getSettings('index')
    end

    if savedParentId then
        local root = g_ui.getRootWidget()
        local savedParent = root and root:recursiveGetChildById(savedParentId) or nil
        if savedParent and savedParent:isVisible() then
            if ui:getParent() ~= savedParent then
                ui:setParent(savedParent, true)
            end

            if savedParent:getClassName() == 'UIMiniWindowContainer' and savedIndex then
                ui.miniIndex = savedIndex
                savedParent:moveChildToIndex(ui, math.max(1, math.min(savedIndex, savedParent:getChildCount())))
            else
                local savedPosition = ui:getSettings('position')
                if savedPosition then
                    ui:setPosition(topoint(savedPosition))
                end
            end

            ui:open(true)
            ui:show()
            -- Raising a docked window changes its position in the container layout.
            if savedParent:getClassName() ~= 'UIMiniWindowContainer' then
                ui:raise()
            end

            if savedParent.fitAll and savedParent:getClassName() == 'UIMiniWindowContainer' then
                savedParent:fitAll(ui)
                addEvent(function()
                    if savedParent and not savedParent:isDestroyed() and ui and not ui:isDestroyed() and ui:getParent() == savedParent then
                        savedParent:fitAll(ui)
                    end
                end)
            end

            updateMiniMapResizePolicy()
            refreshMainRightPanelLimit()
            return
        end
    end

    local targetParent = modules.game_interface and modules.game_interface.getMainRightPanel and
        modules.game_interface.getMainRightPanel() or nil
    local targetIndex = 1

    if targetParent and not targetParent:isDestroyed() then
        local sameParent = ui:getParent() == targetParent
        if not sameParent then
            ui:setParent(targetParent, true)
        end

        targetParent:moveChildToIndex(ui, targetIndex)

        ui:open(true)
        ui:show()
        if targetParent.fitAll and targetParent:getClassName() == 'UIMiniWindowContainer' then
            targetParent:fitAll(ui)
            addEvent(function()
                if targetParent and not targetParent:isDestroyed() and ui and not ui:isDestroyed() and ui:getParent() == targetParent then
                    targetParent:fitAll(ui)
                end
            end)
        end
        ui.miniIndex = targetIndex
        if ui.saveParentIndex and targetParent.getId then
            ui:saveParentIndex(targetParent:getId(), targetIndex)
        end
        updateMiniMapResizePolicy()
        refreshMainRightPanelLimit()
    end
end

local function ensureMiniMapDockRestored(remainingAttempts)
    if remainingAttempts <= 0 then
        return
    end

    restoreMiniMapDockAfterLogin()
    updateMiniMapResizePolicy()
    refreshMainRightPanelLimit()

    if not mapController or not mapController.ui or mapController.ui:isDestroyed() then
        return
    end

    local ui = mapController.ui
    local parent = ui:getParent()
    local dockReady = parent and not parent:isDestroyed() and parent:getClassName() == 'UIMiniWindowContainer' and
        parent:isVisible() and ui:isVisible()

    if not dockReady then
        addEvent(function()
            ensureMiniMapDockRestored(remainingAttempts - 1)
        end)
    end
end

local function refreshVirtualFloors()
    local minimap = mapController.ui and mapController.ui.minimapBorder and
        mapController.ui.minimapBorder.minimap
    if minimap then
        local cameraPosition = minimap:getCameraPosition()
        if cameraPosition then
            virtualFloor = cameraPosition.z
        end
    end
    refreshSatelliteMode()
end

local function resolveMarkersBinFile()
    if markersBinFile and g_resources.fileExists(markersBinFile) then
        return markersBinFile
    end

    if g_resources.fileExists(MINIMAP_MARKERS_BIN_FILE) then
        markersBinFile = MINIMAP_MARKERS_BIN_FILE
        return markersBinFile
    end

    return nil
end

local function onMinimapSyncOpcode(protocol, opcode, data)
    if type(data) ~= 'table' or data.action ~= 'sync_result' then
        return
    end

    if data.needUpdate then
        local reason = data.reason or 'minimap data mismatch'
        modules.game_textmessage.displayStatusMessage(string.format('[Minimap Sync] Update suggested: %s', reason))
    end
end

local function sendMinimapSyncCheck()
    local protocol = g_game.getProtocolGame()
    if not protocol or not protocol.sendExtendedJSONOpcode then
        return
    end

    local payload = {
        action = 'sync_check',
        version = g_game.getClientVersion(),
        otmmChecksum = '',
        markersChecksum = ''
    }

    local otmmFile = getPreferredOtmmLoadFile()
    if otmmFile and g_resources.fileExists(otmmFile) then
        payload.otmmChecksum = g_resources.fileChecksum(otmmFile) or ''
    end

    local markerFile = resolveMarkersBinFile()
    if markerFile then
        payload.markersChecksum = g_resources.fileChecksum(markerFile) or ''
    end

    protocol:sendExtendedJSONOpcode(MINIMAP_SYNC_OPCODE, payload)
end

local function stopStartupMarkersWarmup()
    if markersStartupWarmupEvent then
        removeEvent(markersStartupWarmupEvent)
        markersStartupWarmupEvent = nil
    end
end

local function stopMarkersPreloadQueue()
    if markersPreloadQueueEvent then
        removeEvent(markersPreloadQueueEvent)
        markersPreloadQueueEvent = nil
    end
    if markersPreloadStartEvent then
        removeEvent(markersPreloadStartEvent)
        markersPreloadStartEvent = nil
    end
    markersPreloadQueue = {}
    markersQueuedFloors = {}
end

local function stopMinimapRestoreWatchdog()
    if minimapRestoreWatchdogEvent then
        removeEvent(minimapRestoreWatchdogEvent)
        minimapRestoreWatchdogEvent = nil
    end
end

local function ensureMiniMapAliveAfterLogin(attempt)
    if attempt > 25 then
        stopMinimapRestoreWatchdog()
        return
    end

    if not mapController then
        stopMinimapRestoreWatchdog()
        return
    end

    if mapController.ui and mapController.ui:isDestroyed() then
        mapController.ui = nil
    end

    if not mapController.ui then
        mapController:loadUI()
        if mapController.ui then
            setupMiniMapWindowUi(mapController.ui)
            if mapController.ui.setupOnStart then
                mapController.ui:setupOnStart()
            end
        end
    end

    if mapController.ui and not mapController.ui:isDestroyed() then
        if mapController.ui.open then
            mapController.ui:open(true)
        end
        mapController.ui:show()
        ensureMiniMapDockRestored(1)

        local desiredParentId = 'gameMainRightPanel'
        local parent = mapController.ui:getParent()
        local parentId = parent and parent:getId() or ''
        if parentId == desiredParentId and mapController.ui:isVisible() then
            stopMinimapRestoreWatchdog()
            return
        end
    end

    minimapRestoreWatchdogEvent = scheduleEvent(function()
        ensureMiniMapAliveAfterLogin(attempt + 1)
    end, 120)
end

local function startupWarmupMarkersCache(attempt)
    if attempt > 25 then
        minimapStartupDebug('warmup attempts exhausted')
        stopStartupMarkersWarmup()
        return
    end

    local markerFile = resolveMarkersBinFile()
    if not markerFile or not g_minimap.loadMarkersBin then
        minimapStartupDebug(string.format('warmup attempt=%d waiting markerFile=%s loader=%s', attempt, tostring(markerFile), tostring(g_minimap.loadMarkersBin ~= nil)))
        markersStartupWarmupEvent = scheduleEvent(function()
            startupWarmupMarkersCache(attempt + 1)
        end, 120)
        return
    end

    -- Aggressive startup warmup:
    -- even without local player, this triggers/keeps the background cache parse alive.
    local loaded = g_minimap.loadMarkersBin(markerFile)
    minimapStartupDebug(string.format('warmup attempt=%d file=%s loaded=%s', attempt, markerFile, tostring(loaded)))

    if attempt < 6 then
        markersStartupWarmupEvent = scheduleEvent(function()
            startupWarmupMarkersCache(attempt + 1)
        end, 80)
    else
        stopStartupMarkersWarmup()
    end
end

local function canUseFullFloorMarkersLoader()
    return g_minimap.loadMarkersBinFullFloorAtPosition ~= nil or g_minimap.loadMarkersBinFullFloor ~= nil
end

local function tryLoadMarkersForFloor(z)
    if not g_game.isOnline() then
        return false
    end

    local player = g_game.getLocalPlayer()
    if not player then
        return false
    end

    local pos = player:getPosition()
    if not pos then
        return false
    end

    local markerFile = resolveMarkersBinFile()
    if not markerFile then
        return false
    end

    if canUseFullFloorMarkersLoader() then
        local centerPos = { x = pos.x, y = pos.y, z = z }
        local loaded = false
        if g_minimap.loadMarkersBinFullFloorAtPosition then
            loaded = g_minimap.loadMarkersBinFullFloorAtPosition(markerFile, centerPos) == true
        else
            if z ~= pos.z then
                return false
            end
            loaded = g_minimap.loadMarkersBinFullFloor(markerFile) == true
        end
        if loaded then
            markersLoadedFloors[z] = true
        end
        return loaded
    end

    if z ~= pos.z then
        return false
    end

    local loaded = loadMarkersForCurrentFloor(true)
    if loaded then
        markersLoadedFloors[z] = true
    end
    return loaded
end

local function processMarkersPreloadQueue()
    markersPreloadQueueEvent = nil

    if not g_game.isOnline() then
        stopMarkersPreloadQueue()
        return
    end

    local nextFloor = table.remove(markersPreloadQueue, 1)
    if nextFloor == nil then
        return
    end
    markersQueuedFloors[nextFloor] = nil

    local loaded = tryLoadMarkersForFloor(nextFloor)
    if not loaded then
        -- Cache/parser may not be ready yet. Requeue floor and try later.
        if not markersQueuedFloors[nextFloor] then
            table.insert(markersPreloadQueue, nextFloor)
            markersQueuedFloors[nextFloor] = true
        end
    end

    if #markersPreloadQueue > 0 then
        markersPreloadQueueEvent = scheduleEvent(processMarkersPreloadQueue, MARKERS_PRELOAD_STEP_DELAY_MS)
    end
end

local function scheduleMarkersPreloadQueueStart(delayMs)
    if markersPreloadStartEvent then
        removeEvent(markersPreloadStartEvent)
        markersPreloadStartEvent = nil
    end
    if markersPreloadQueueEvent then
        return
    end
    markersPreloadStartEvent = scheduleEvent(function()
        markersPreloadStartEvent = nil
        if #markersPreloadQueue > 0 and not markersPreloadQueueEvent then
            processMarkersPreloadQueue()
        end
    end, delayMs or 1)
end

local function enqueueMarkersFloor(z, prioritize)
    if z == nil or z < 0 or z > 15 then
        return
    end
    if markersLoadedFloors[z] or markersQueuedFloors[z] then
        return
    end

    if prioritize then
        table.insert(markersPreloadQueue, 1, z)
    else
        table.insert(markersPreloadQueue, z)
    end
    markersQueuedFloors[z] = true
end

local function enqueueMarkersFloorsAround(baseZ, radius, prioritizeBase)
    if baseZ == nil then
        return
    end

    radius = radius or MARKERS_PRELOAD_RADIUS
    if prioritizeBase ~= false then
        enqueueMarkersFloor(baseZ, true)
    else
        enqueueMarkersFloor(baseZ, false)
    end

    for offset = 1, radius do
        enqueueMarkersFloor(baseZ - offset, false)
        enqueueMarkersFloor(baseZ + offset, false)
    end
end

loadMarkersForCurrentFloor = function(forceReload)
    if not g_minimap.loadMarkersBin or not g_game.isOnline() then
        return false
    end

    local player = g_game.getLocalPlayer()
    if not player then
        return false
    end

    local pos = player:getPosition()
    if not pos then
        return false
    end

    local now = g_clock.millis()
    if not forceReload and (now - markersBinLastLoadAt) < MARKERS_BIN_LOAD_INTERVAL_MS then
        return false
    end

    local markerFile = resolveMarkersBinFile()
    if not markerFile then
        return false
    end

    local loaded = g_minimap.loadMarkersBin(markerFile)
    markersBinLastLoadAt = now
    return loaded == true
end

local function stopInitialMarkersLoad()
    if markersInitialLoadEvent then
        removeEvent(markersInitialLoadEvent)
        markersInitialLoadEvent = nil
    end
end

local function scheduleInitialMarkersLoad(attempt)
    if attempt > 20 then
        stopInitialMarkersLoad()
        return
    end

    markersInitialLoadEvent = scheduleEvent(function()
        if not g_game.isOnline() then
            stopInitialMarkersLoad()
            return
        end

        if loadMarkersForCurrentFloor(true) then
            stopInitialMarkersLoad()
            return
        end

        scheduleInitialMarkersLoad(attempt + 1)
    end, 120)
end

local function onPositionChange()
    if not mapController or not mapController.ui or mapController.ui:isDestroyed() then
        return
    end
    if not mapController.ui.minimapBorder or not mapController.ui.minimapBorder.minimap then
        return
    end

    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    local pos = player:getPosition()
    if not pos then
        return
    end

    local minimapWidget = mapController.ui.minimapBorder.minimap
    if not minimapWidget or minimapWidget:isDragging() or minimapWidget.draggingMarker then
        return
    end

    if not minimapWidget.fullMapView then
        minimapWidget:setCameraPosition(pos)
    end

    minimapWidget:setCrossPosition(pos)
    applyMapViewCrossOffset(minimapWidget)
    local oldFloor = virtualFloor
    virtualFloor = pos.z
    refreshVirtualFloors()

    if oldFloor ~= pos.z or lastMarkersPlayerFloor ~= pos.z then
        lastMarkersPlayerFloor = pos.z
        enqueueMarkersFloorsAround(pos.z, MARKERS_PRELOAD_RADIUS, true)
        scheduleMarkersPreloadQueueStart(1)
    end
end

mapController = Controller:new()
mapController:setUI('minimap', modules.game_interface.getMainRightPanel())

local function updateClock()
    if not mapController.ui or mapController.ui:isDestroyed() or not mapController.ui.rosePanel or
       not mapController.ui.rosePanel.ambients or not mapController.ui.rosePanel.ambients.main then
        return
    end

    local elapsed = math.max(0, g_clock.millis() - worldTimeReceivedAt)
    local minutes = (worldTimeMinutes + elapsed / 2500) % (24 * 60)
    currentDayTime.h = math.floor(minutes / 60)
    currentDayTime.m = math.floor(minutes % 60)

    local main = mapController.ui.rosePanel.ambients.main
    local secondary = mapController.ui.rosePanel.ambients.secondary
    if not secondary then
        local offset = (124 * (minutes / (24 * 60) + 0.5)) % 124 + 6
        local frame = (math.floor(offset + 0.5) - 6) % 124
        main:setImageClip((frame * 31) .. ' 0 31 31')
        return
    end

    local position = math.floor((124 / (24 * 60)) * minutes)
    local mainWidth = 31
    local secondaryWidth = 0

    if (position + 31) >= 124 then
        secondaryWidth = ((position + 31) - 124) + 1
        mainWidth = 31 - secondaryWidth
    end

    main:setWidth(mainWidth)
    secondary:setWidth(secondaryWidth)

    if secondaryWidth == 0 then
        secondary:hide()
    else
        secondary:setImageClip('0 0 ' .. secondaryWidth .. ' 31')
        secondary:show()
    end

    if mainWidth == 0 then
        main:hide()
    else
        main:setImageClip(position .. ' 0 ' .. mainWidth .. ' 31')
        main:show()
    end
end

function onChangeWorldTime(hour, minute)
    worldTimeMinutes = (hour * 60 + minute) % (24 * 60)
    worldTimeReceivedAt = g_clock.millis()
    updateClock()
end

local function configureMinimapInteractions(ui)
    if not ui or ui:isDestroyed() or ui.minimapInteractionsConfigured or
       not ui.minimapBorder or not ui.minimapBorder.minimap then
        return
    end

    ui.minimapInteractionsConfigured = true
    local minimap = ui.minimapBorder.minimap
    configureMinimapMarkers(minimap)

    minimap.setCrossPosition = function(widget, pos)
        if not pos then
            return
        end
        if not widget.cross then
            widget.cross = g_ui.createWidget('MinimapCross', widget)
            widget.cross:setIcon('')
            widget.cross:setSize({ width = 6, height = 6 })
            widget.cross:setMarginLeft(-1)
            widget.cross:setMarginTop(-1)
        end
        local position = { x = pos.x, y = pos.y, z = pos.z }
        local color = g_map.getMinimapColor(position)
        local dark = color > 0 and color < 216 and color % 6 == 5
        widget.cross:setImageSource('/images/automap/crosshair-' .. (dark and 'dark' or 'light'))
        widget.cross.pos = position
        widget:centerInPosition(widget.cross, position)
        widget.cross:setVisible(position.z == widget:getCameraPosition().z)
        applyMapViewCrossOffset(widget)
    end

    minimap.dragRemainder = { x = 0, y = 0 }
    minimap.onDragEnter = function(widget)
        local pos = widget:getLastClickPosition()
        widget.dragReference = { x = pos.x, y = pos.y }
        return true
    end
    minimap.onDragMove = function(widget, pos)
        local scale = widget:getScale()
        local dx = (widget.dragReference.x - pos.x) / scale + widget.dragRemainder.x
        local dy = (widget.dragReference.y - pos.y) / scale + widget.dragRemainder.y
        local tilesX = dx < 0 and math.ceil(dx - 0.5) or math.floor(dx + 0.5)
        local tilesY = dy < 0 and math.ceil(dy - 0.5) or math.floor(dy + 0.5)
        widget.dragRemainder = { x = dx - tilesX, y = dy - tilesY }
        widget.dragReference = { x = pos.x, y = pos.y }
        local camera = widget:getCameraPosition()
        camera.x = camera.x + tilesX
        camera.y = camera.y + tilesY
        widget:setCameraPosition(camera)
        return true
    end
    minimap.onMouseWheel = function(widget, pos, direction)
        if direction == MouseWheelUp then
            widget:zoomIn()
        elseif direction == MouseWheelDown then
            widget:zoomOut()
        end
        return true
    end

    for _, id in ipairs({ 'floorUpButton', 'floorDownButton', 'zoomInButton', 'zoomOutButton', 'resetButton' }) do
        local button = minimap:getChildById(id)
        if button then
            button:hide()
        end
    end

    if ui.rosePanel then
        ui.rosePanel.onMouseRelease = onRoseMouseRelease
    end
    if ui.layersPanel then
        ui.layersPanel.onMouseWheel = onLayerMouseWheel
    end

    local tooltipWidgets = {
        ui.rosePanel,
        ui.layersPanel,
        ui.fullMap,
        ui.satelliteToggle,
        ui.zoomIn,
        ui.zoomOut,
        ui.floorUp,
        ui.floorDown,
        ui.zoomPanel and ui.zoomPanel.zoomIn,
        ui.zoomPanel and ui.zoomPanel.zoomOut,
        ui.layersPanel and ui.layersPanel.floorUp,
        ui.layersPanel and ui.layersPanel.floorDown,
    }
    for _, widget in ipairs(tooltipWidgets) do
        if widget then
            configureMinimapTooltip(widget)
        end
    end
end

function mapController:onInit()
    minimapStartupDebug('onInit: startup warmup begin')
    startupWarmupMarkersCache(1)

    mapController:registerEvents(g_game, {
        onPartyMinimapPositions = onPartyMinimapPositions
    })

    pcall(function()
        ProtocolGame.registerExtendedJSONOpcode(MINIMAP_SYNC_OPCODE, onMinimapSyncOpcode)
    end)

    if self.ui then
        setupMiniMapWindowUi(self.ui)
        configureMinimapInteractions(self.ui)
    end

    for _, binding in ipairs(minimapKeybinds) do
        local direction = binding.direction
        local callback = binding.callback or function()
            onClickRoseButton(direction)
        end
        Keybind.new('Minimap', binding.action, binding.key, '')
        Keybind.bind('Minimap', binding.action, {{ type = KEY_PRESS, callback = callback }},
            modules.game_interface.getRootPanel())
    end
end

function mapController:onGameStart()
    stopMarkersPreloadQueue()
    markersLoadedFloors = {}
    markersQueuedFloors = {}
    markersPreloadQueue = {}
    lastMarkersPlayerFloor = nil
    stopMinimapRestoreWatchdog()
    resetSatelliteFloorCache()

    if self.ui and self.ui:isDestroyed() then
        self.ui = nil
    end

    if not self.ui then
        self:loadUI()
        if self.ui then
            setupMiniMapWindowUi(self.ui)
            configureMinimapInteractions(self.ui)
        end
    end

    if self.ui and self.ui.setupOnStart then
        self.ui:setupOnStart()
        self.ui:open(true)
    end

    if not self.ui or self.ui:isDestroyed() or not self.ui.minimapBorder or not self.ui.minimapBorder.minimap then
        return
    end

    worldTimeReceivedAt = g_clock.millis()
    self:cycleEvent(updateClock, 10000, 'dayTime')

    mapController:registerEvents(g_game, {
        onChangeWorldTime = onChangeWorldTime
    })

    mapController:registerEvents(LocalPlayer, {
        onPositionChange = onPositionChange
    }):execute()

    -- Defer heavier minimap I/O/widget hydration to the next event tick so gameplay UI appears sooner.
    addEvent(function()
        if not mapController or not mapController.ui or mapController.ui:isDestroyed() or
           not mapController.ui.minimapBorder or not mapController.ui.minimapBorder.minimap then
            return
        end

        g_minimap.clean()

        local minimapFile = '/minimap'
        local loadFnc = nil

        if otmm then
            minimapFile = getPreferredOtmmLoadFile() or MINIMAP_OTMM_READ_FILE
            loadFnc = g_minimap.loadOtmm
        else
            minimapFile = minimapFile .. '_' .. g_game.getClientVersion() .. '.otcm'
            loadFnc = g_map.loadOtcm
        end

        if g_resources.fileExists(minimapFile) then
            loadFnc(minimapFile)
        end

        local minimap = mapController.ui.minimapBorder.minimap
        minimap:load()
        minimap.zoomMinimap = math.max(-1, math.min(2, minimap.zoomMinimap or 0))
        minimap:setZoom(minimap.zoomMinimap)
        if not minimapOriginalOnZoomChange then
            minimapOriginalOnZoomChange = mapController.ui.minimapBorder.minimap.onZoomChange
            mapController.ui.minimapBorder.minimap.onZoomChange = function(self, zoom, oldZoom)
                if minimapOriginalOnZoomChange then
                    minimapOriginalOnZoomChange(self, zoom, oldZoom)
                end
                applyMapViewCrossOffset(self)
            end
        end
        if not minimapOriginalOnCameraPositionChange then
            minimapOriginalOnCameraPositionChange = mapController.ui.minimapBorder.minimap.onCameraPositionChange
        end
        mapController.ui.minimapBorder.minimap.onCameraPositionChange = function(self, cameraPos)
            if minimapOriginalOnCameraPositionChange then
                minimapOriginalOnCameraPositionChange(self, cameraPos)
            end
            if cameraPos then
                virtualFloor = cameraPos.z
                refreshVirtualFloors()
            end
        end
        applyMapViewCrossOffset(mapController.ui.minimapBorder.minimap)
        refreshSatelliteMode()
        partyMinimapFlagPositions = {}
        syncPartyMinimapFlags()
        if g_game.isOnline() and g_game.getLocalPlayer() then
            local playerPos = g_game.getLocalPlayer():getPosition()
            if playerPos then
                lastMarkersPlayerFloor = playerPos.z
                enqueueMarkersFloorsAround(playerPos.z, MARKERS_PRELOAD_RADIUS, true)
                scheduleMarkersPreloadQueueStart(MARKERS_PRELOAD_LOGIN_DELAY_MS)
                scheduleInitialMarkersLoad(1)
            end
        end
    end)
    if not minimapSyncScheduled then
        minimapSyncScheduled = true
        scheduleEvent(function()
            minimapSyncScheduled = false
            if g_game.isOnline() then
                sendMinimapSyncCheck()
            end
        end, 1200)
    end

    -- Re-apply minimap docking right after login without fixed delays.
    addEvent(function()
        ensureMiniMapDockRestored(20)
    end)

    minimapRestoreWatchdogEvent = scheduleEvent(function()
        ensureMiniMapAliveAfterLogin(1)
    end, 60)
end

function mapController:onGameEnd()
    -- Save Map
    if otmm then
        ensureOtmmWriteDir()
        g_minimap.saveOtmm(MINIMAP_OTMM_WRITE_FILE)
    else
        g_map.saveOtcm('/minimap_' .. g_game.getClientVersion() .. '.otcm')
    end

    if self.ui and not self.ui:isDestroyed() and self.ui.minimapBorder and self.ui.minimapBorder.minimap then
        self.ui.minimapBorder.minimap:save()
    end

    markersBinLastLoadAt = 0
    clearPartyMinimapFlags()
    partyMinimapMembers = {}
    stopMarkersPreloadQueue()
    markersLoadedFloors = {}
    markersQueuedFloors = {}
    lastMarkersPlayerFloor = nil
    stopInitialMarkersLoad()
    stopMinimapRestoreWatchdog()
    resetSatelliteFloorCache()
end

function mapController:onTerminate()
    stopStartupMarkersWarmup()
    stopMarkersPreloadQueue()
    stopInitialMarkersLoad()
    stopMinimapRestoreWatchdog()

    pcall(function()
        ProtocolGame.unregisterExtendedJSONOpcode(MINIMAP_SYNC_OPCODE)
    end)

    for _, binding in ipairs(minimapKeybinds) do
        Keybind.delete('Minimap', binding.action)
    end

    if iconTopMenu then
        iconTopMenu:destroy()
        iconTopMenu = nil
    end

    if followedRootPanel and not followedRootPanel:isDestroyed() then
        disconnect(followedRootPanel, { onGeometryChange = updateMiniMapResizePolicy })
    end
    followedRootPanel = nil
end

function zoomIn()
    mapController.ui.minimapBorder.minimap:zoomIn()
end

function zoomOut()
    mapController.ui.minimapBorder.minimap:zoomOut()
end

function setSatelliteModeEnabled(enabled)
    satellitePreferred = enabled == true
    refreshSatelliteMode()
end

function openCyclopediaMap()
    if g_game.getClientVersion() >= 1310 then
        modules.game_cyclopedia.toggle('map')
    else
        return fullscreen()
    end
end

function fullscreen()
    local minimapWidget = mapController.ui.minimapBorder.minimap
    if not minimapWidget then
        minimapWidget = fullscreenWidget
    end
    local zoom;

    if not minimapWidget then
        return
    end

    if minimapWidget.fullMapView then
        fullscreenWidget = nil
        minimapWidget:setParent(mapController.ui.minimapBorder)
        minimapWidget:fill('parent')
        mapController.ui:show()
        zoom = minimapWidget.zoomMinimap
        g_keyboard.unbindKeyDown('Escape')
        minimapWidget.fullMapView = false
    else
        fullscreenWidget = minimapWidget
        mapController.ui:hide(true)
        minimapWidget:setParent(modules.game_interface.getRootPanel())
        minimapWidget:fill('parent')
        zoom = minimapWidget.zoomFullmap
        g_keyboard.bindKeyDown('Escape', fullscreen)
        minimapWidget.fullMapView = true
    end

    local pos = oldPos or minimapWidget:getCameraPosition()
    oldPos = minimapWidget:getCameraPosition()
    minimapWidget:setZoom(zoom)
    minimapWidget:setCameraPosition(pos)
    refreshSatelliteMode()
end

function upLayer()
    if virtualFloor == 0 then
        return
    end

    mapController.ui.minimapBorder.minimap:floorUp(1)
    virtualFloor = virtualFloor - 1
    refreshVirtualFloors()
end

function downLayer()
    if virtualFloor == 15 then
        return
    end

    mapController.ui.minimapBorder.minimap:floorDown(1)
    virtualFloor = virtualFloor + 1
    refreshVirtualFloors()
end

function onClickRoseButton(dir)
    local directions = {
        north = { 0, -1 }, ['north-east'] = { 1, -1 }, east = { 1, 0 },
        ['south-east'] = { 1, 1 }, south = { 0, 1 }, ['south-west'] = { -1, 1 },
        west = { -1, 0 }, ['north-west'] = { -1, -1 }
    }
    local direction = directions[dir]
    if not direction then
        return
    end
    local minimap = getMiniMapUi()
    local position = minimap:getCameraPosition()
    local distance = math.floor(12 / minimap:getScale())
    position.x = position.x + direction[1] * distance
    position.y = position.y + direction[2] * distance
    minimap:setCameraPosition(position)
end

function resetMap()
    mapController.ui.minimapBorder.minimap:reset()
    local player = g_game.getLocalPlayer()
    if player then
        virtualFloor = player:getPosition().z
        refreshVirtualFloors()
    end
end

function getMiniMapUi()
    return mapController.ui.minimapBorder.minimap
end

function getCurrentDayTime()
    return currentDayTime.h, currentDayTime.m
end

function extendedView(extendedView)
    if extendedView then
        if not iconTopMenu then
            iconTopMenu = modules.client_topmenu.addTopRightToggleButton('miniMap', tr('Show miniMap'),
                '/images/topbuttons/minimap', toggle)
            iconTopMenu:setOn(mapController.ui:isVisible())
            mapController.ui:setBorderColor('black')
            mapController.ui:setBorderWidth(2)
        end
    else
        if iconTopMenu then
            iconTopMenu:destroy()
            iconTopMenu = nil
        end
        mapController.ui:setBorderColor('alpha')
        mapController.ui:setBorderWidth(0)
        local mainRightPanel = modules.game_interface.getMainRightPanel()
        if mainRightPanel and not mainRightPanel:hasChild(mapController.ui) then
            mainRightPanel:insertChild(1, mapController.ui)
        end
        mapController.ui:show()

    end
    -- Let the map viewer dock in side panels too; the default parent is still restored on login.
    mapController.ui.moveOnlyToMain = false
end

function toggle()
    if iconTopMenu:isOn() then
        mapController.ui:hide()
        iconTopMenu:setOn(false)
    else
        mapController.ui:show()
        iconTopMenu:setOn(true)
    end
end

function clearPath()
    local minimap = getMiniMapUi()
    if minimap and minimap.clearWaypoints then
        minimap:clearWaypoints()
    end
end

function setPath(waypointsByFloor)
    local minimap = getMiniMapUi()
    if not minimap or not minimap.makeWaypoints then
        return
    end

    clearPath()
    for floor, coordinates in pairs(waypointsByFloor or {}) do
        floor = tonumber(floor)
        if floor then
            minimap:makeWaypoints(coordinates, floor)
        end
    end
end

function clearRoutePath()
    local minimap = getMiniMapUi()
    if minimap and minimap.clearRoutePath then
        minimap:clearRoutePath()
    end
end

function setRoutePath(routeByFloor)
    local minimap = getMiniMapUi()
    if not minimap or not minimap.makeRouth then
        return
    end

    clearRoutePath()
    for floor, coordinates in pairs(routeByFloor or {}) do
        floor = tonumber(floor)
        if floor then
            minimap:makeRouth(coordinates, floor)
        end
    end
end

local roseDirections = {
    { 'north-west', 'north', 'north-east' },
    { 'west', 'center', 'east' },
    { 'south-west', 'south', 'south-east' }
}

local function roseDirection(widget, pos)
    local x = (pos.x - widget:getX()) / (widget:getWidth() - 1)
    local y = (pos.y - widget:getY()) / (widget:getHeight() - 1)
    local dx, dy = 0, 0
    if math.sqrt((x * 2 - 1)^2 + (y * 2 - 1)^2) >= 0.33 then
        dx = x >= 0.66 and 1 or (x <= 0.33 and -1 or 0)
        dy = y >= 0.66 and 1 or (y <= 0.33 and -1 or 0)
    end
    return roseDirections[dy + 2][dx + 2]
end

function onRoseMouseRelease(widget, pos, button)
    if button ~= MouseLeftButton or not widget:containsPoint(pos) then
        return false
    end
    -- The rose is the single-frame time display glass, so the pointed direction is not highlighted:
    -- clipping 43 px frames out of that 47x47 image read past it in the texture atlas.
    local direction = roseDirection(widget, pos)
    if direction == 'center' then
        resetMap()
    else
        onClickRoseButton(direction)
    end
    return true
end

function onLayerMouseWheel(widget, pos, direction)
    if direction == MouseWheelUp then
        upLayer()
    else
        downLayer()
    end
    return true
end
