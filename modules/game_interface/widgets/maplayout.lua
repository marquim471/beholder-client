MapLayout = {}

local mode = 'map'
local preferredMapHeight
local preferredBottomHeight
local dragging = false
local hideEvent
local overlay
local splitter
local mouseX = 0
local icons = {
    both = 'icon-resize-mapwindow-and-chat',
    map = 'icon-resize-mapwindow',
    chat = 'icon-resize-chat'
}

local function rememberHeights()
    preferredMapHeight = gameMapPanel:getHeight()
    preferredBottomHeight = splitter:getMarginBottom()
end

local function hideLater()
    if hideEvent then removeEvent(hideEvent) end
    hideEvent = scheduleEvent(function()
        hideEvent = nil
        if not dragging and not splitter:isHovered() and not overlay:isHovered()
            and not overlay:getChildById('modeFrame'):isHovered()
            and not overlay:recursiveGetChildById('modeButton'):isHovered()
            and not overlay:getChildById('scaleFrame'):isHovered() then
            overlay:hide()
        end
    end, 500)
end

function MapLayout.updateOverlay()
    if not overlay then return end
    local rect = splitter:getRect()
    local x = math.max(rect.x, math.min(rect.x + rect.width - 60, mouseX - 30))
    overlay:setPosition({x = x, y = rect.y - 22})
    overlay:getChildById('scaleFrame'):getChildById('scale'):setText(
        math.floor(gameMapPanel:getMapRect().width / 480 * 100) .. '%')
    if overlay.resizeMode ~= mode then
        local button = overlay:recursiveGetChildById('modeButton')
        local size = mode == 'both' and 14 or 13
        button:setIconClip({x = 0, y = 0, width = size, height = size})
        button:setIcon('/images/game/interface/' .. icons[mode])
        overlay.resizeMode = mode
    end
end

function MapLayout.setMode(value)
    if not icons[value] or value == mode then return end
    mode = value
    rememberHeights()
    MapLayout.updateOverlay()
    updateStretchShrink()
end

function MapLayout.getMode()
    return mode
end

function MapLayout.nextMode()
    MapLayout.setMode(mode == 'both' and 'map' or mode == 'map' and 'chat' or 'both')
end

function MapLayout.updateTiles()
    if not splitter then return end
    local texture = splitter:getChildById('texture')
    local count = math.ceil(splitter:getWidth() / 200)
    while texture:getChildCount() > count do texture:getLastChild():destroy() end
    while texture:getChildCount() < count do
        local tile = g_ui.createWidget('UIWidget', texture)
        tile:setPhantom(true)
        tile:setSize({width = 200, height = 7})
        tile:setImageSource('/images/game/interface/divider-horizontal')
    end
end

function MapLayout.init()
    splitter = bottomSplitter
    overlay = gameRootPanel:getChildById('mapResizeOverlay')
    overlay:recursiveGetChildById('modeButton').onClick = MapLayout.nextMode
    for _,widget in ipairs({splitter, overlay, overlay:getChildById('scaleFrame'),
        overlay:getChildById('modeFrame'), overlay:recursiveGetChildById('modeButton')}) do
        connect(widget, {onHoverChange = hideLater})
    end
    connect(splitter, {onGeometryChange = function()
        MapLayout.updateTiles()
        MapLayout.updateOverlay()
    end})
    splitter.onMousePress = function(self, position, button)
        if button ~= MouseLeftButton then return false end
        dragging = true
        mouseX = position.x
        overlay:show()
        overlay:raise()
        MapLayout.updateOverlay()
        return true
    end
    splitter.onMouseMove = function(self, position, moved)
        mouseX = position.x
        MapLayout.updateOverlay()
        return UISplitter.onMouseMove(self, position, moved)
    end
    splitter.onMouseRelease = function(self, position, button)
        UISplitter.onMouseRelease(self, position, button)
        if button ~= MouseLeftButton or not dragging then return end
        addEvent(function()
            if not splitter or splitter:isDestroyed() then return end
            rememberHeights()
            dragging = false
            hideLater()
        end)
    end
    MapLayout.updateTiles()
end

function MapLayout.requestedBottomHeight()
    if dragging then return splitter:getMarginBottom() end
    if not preferredMapHeight or not preferredBottomHeight then rememberHeights() end
    local available = gameMapPanel:getHeight() + splitter:getMarginBottom()
    if mode == 'chat' then return available - preferredMapHeight end
    if mode == 'both' then
        local total = preferredMapHeight + preferredBottomHeight
        return available - math.floor(available * preferredMapHeight / math.max(1, total))
    end
    return preferredBottomHeight
end

function MapLayout.save(settings)
    settings.resizingMode = mode
    settings.preferredMapHeight = preferredMapHeight
    settings.preferredBottomHeight = preferredBottomHeight
end

function MapLayout.load(settings)
    if icons[settings.resizingMode] then mode = settings.resizingMode end
    if tonumber(settings.preferredMapHeight) and tonumber(settings.preferredMapHeight) > 0 then
        preferredMapHeight = tonumber(settings.preferredMapHeight)
    end
    if tonumber(settings.preferredBottomHeight) and tonumber(settings.preferredBottomHeight) > 0 then
        preferredBottomHeight = tonumber(settings.preferredBottomHeight)
    end
end

function MapLayout.hide()
    if hideEvent then removeEvent(hideEvent) end
    hideEvent = nil
    if dragging and splitter and not splitter:isDestroyed() then rememberHeights() end
    dragging = false
    if overlay then overlay:hide() end
end

function MapLayout.terminate()
    MapLayout.hide()
    overlay = nil
    splitter = nil
end
