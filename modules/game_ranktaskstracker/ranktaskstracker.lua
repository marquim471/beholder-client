-- Side window with the ranked tasks in progress (game_ranktasks). The official Task Board keeps its own
-- kill tracker; this one only lists the ranked tasks.
TaskSystemTrackerWindow = nil

-- Square over the game map ("Show Tracker" in the Tasks window): the creatures of the active
-- tasks take turns every 3 s, with the task's kills/total below (DeusOT TaskTrackerWidget).
local MAP_TRACKER_SETTING = 'rankTaskMapTracker'
local MAP_TRACKER_CYCLE = 3000
local MAP_TRACKER_MARGIN_RIGHT = 7
local MAP_TRACKER_MARGIN_BOTTOM = 9
local mapTracker = nil
local mapTrackerVisible = false
local mapTrackerEntries = {}
local mapTrackerIndex = 1
local mapTrackerEvent = nil
local mapTrackerFollowEvent = nil
local mapTrackerPlacedFor = nil
local lastTrackerList = {}

local function bindChildren(widget)
    for _, child in ipairs(widget:getChildren()) do
        local id = child:getId()
        if id and id ~= '' then
            widget[id] = child
        end
        bindChildren(child)
    end
end

local function capitalize(text)
    return (tostring(text or ''):gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end))
end

local function percent(entry)
    if not entry.total or entry.total <= 0 then
        return 100
    end
    return math.floor((math.min(entry.total, entry.kills) * 100) / entry.total)
end

function init()
    TaskSystemTrackerWindow = g_ui.loadUI('ranktaskstracker', modules.game_interface.getRightPanel())
    bindChildren(TaskSystemTrackerWindow)
    if TaskSystemTrackerWindow.lockButton then
        TaskSystemTrackerWindow.lockButton:hide()
    end

    g_ui.importStyle('maptracker')
    createMapTracker()

    TaskSystemTrackerWindow:setup()
    TaskSystemTrackerWindow:close(true)
    TaskSystemTrackerWindow.menuButton.onMousePress = openMenu

    connect(g_game, {
        onGameStart = onGameStart
    })
    if g_game.isOnline() then
        onGameStart()
    end
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart
    })
    destroyMapTracker()
    TaskSystemTrackerWindow:destroy()
    TaskSystemTrackerWindow = nil
end

function onGameStart()
    local settings = g_settings.getNode('TaskTracker') or {}
    local cSettings = settings[g_game.getCharacterName()] or {}
    TaskSystemTrackerWindow.sortingType = cSettings['sortingType'] or 'name'
    TaskSystemTrackerWindow.sortingOrder = cSettings['sortingOrder'] or 'asc'
    TaskSystemTrackerWindow.contentsPanel:destroyChildren()

    -- Back to the panel and state this character left it in; closed unless it was left open.
    TaskSystemTrackerWindow:setupOnStart()
    if TaskSystemTrackerWindow:getSettings('closed') ~= false then
        TaskSystemTrackerWindow:close(true)
    end

    lastTrackerList = {}
    setMapTrackerVisible(g_settings.getBoolean(MAP_TRACKER_SETTING, false))
end

local function updateCreatures(widget, entry)
    local count = #(entry.creatures or {})
    widget:setHeight(42 + (count > 0 and 5 or 0) + (count * 15))
    if count == 0 then
        widget.creatures:hide()
        widget.creatures:setHeight(0)
        widget.creatures:destroyChildren()
        return
    end
    widget.creatures:show()
    widget.creatures:setHeight(count * 15)
    for _, block in ipairs(entry.creatures) do
        local cWidget = widget.creatures:getChildById('Monster_' .. block.raceId)
        if cWidget == nil then
            cWidget = g_ui.createWidget('TaskTrackerKillEntry', widget.creatures)
            cWidget:setId('Monster_' .. block.raceId)
            bindChildren(cWidget)
            local raceData = g_things.getRaceData(block.raceId)
            if raceData and raceData.name then
                cWidget.title:setText(capitalize(raceData.name) .. ":")
            end
        end
        cWidget.amount:setText(comma_value(block.kills))
        cWidget.amountInt = block.kills
    end
    local children = widget.creatures:getChildren()
    table.sort(children, function(a, b)
        return (a.amountInt or 0) > (b.amountInt or 0)
    end)
    widget.creatures:reorderChildren(children)
end

local function updateProgress(widget, entry)
    local value = percent(entry)
    widget.percentValue = value
    widget.killsValue = entry.kills
    widget.progress:setWidth(math.floor(value * 105 / 100))
    widget.progressBar:setText(value .. "%")
    widget.progress:setBackgroundColor(entry.kills >= entry.total and '#00ff2a' or '#2effe7')
    widget.progressBar:setTooltip("Voce derrotou " .. comma_value(entry.kills) .. " de " .. comma_value(entry.total) .. " criaturas.")
end

function onTaskTracker(list)
    lastTrackerList = list or {}
    updateMapTracker()

    local panel = TaskSystemTrackerWindow.contentsPanel
    for _, c in ipairs(panel:getChildren()) do
        c.entryFound = false
    end

    for _, entry in ipairs(list) do
        local widget = panel:getChildById('TaskUID_' .. entry.raceId)
        if widget == nil then
            local raceData = g_things.getRaceData(entry.raceId)
            if raceData and raceData.outfit then
                widget = g_ui.createWidget('TaskTrackerEntry', panel)
                widget:setId('TaskUID_' .. entry.raceId)
                bindChildren(widget)
                widget.creature:setOutfit(raceData.outfit)
                if widget.creature.setCenter then
                    widget.creature:setCenter(true)
                end
                widget.title:setText(entry.name)
            end
        end
        if widget then
            updateProgress(widget, entry)
            updateCreatures(widget, entry)
            widget.entryFound = true
        end
    end

    local toRemove = {}
    for _, c in ipairs(panel:getChildren()) do
        if not c.entryFound then
            table.insert(toRemove, c)
        end
    end
    for _, c in ipairs(toRemove) do
        c:destroy()
    end

    reloadSorting()
end

function saveSettings()
    local settings = g_settings.getNode('TaskTracker') or {}
    settings[g_game.getCharacterName()] = {
        ['sortingType'] = TaskSystemTrackerWindow.sortingType,
        ['sortingOrder'] = TaskSystemTrackerWindow.sortingOrder,
    }
    g_settings.setNode('TaskTracker', settings)
end

function reloadSorting()
    local children = TaskSystemTrackerWindow.contentsPanel:getChildren()
    local sortingType = TaskSystemTrackerWindow.sortingType
    local ascending = TaskSystemTrackerWindow.sortingOrder ~= 'desc'
    table.sort(children, function(a, b)
        local x, y
        if sortingType == 'stage' then
            x, y = a.percentValue or 0, b.percentValue or 0
        elseif sortingType == 'kills' then
            x, y = a.killsValue or 0, b.killsValue or 0
        else
            x, y = a.title:getText():lower(), b.title:getText():lower()
        end
        if x == y then
            return a.title:getText():lower() < b.title:getText():lower()
        end
        if ascending then
            return x < y
        end
        return x > y
    end)
    TaskSystemTrackerWindow.contentsPanel:reorderChildren(children)
end

function toggle()
    if TaskSystemTrackerWindow:isVisible() then
        TaskSystemTrackerWindow:close()
    else
        if not TaskSystemTrackerWindow:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(TaskSystemTrackerWindow, TaskSystemTrackerWindow:getMinimumHeight())
            if panel then
                panel:addChild(TaskSystemTrackerWindow)
            end
        end
        TaskSystemTrackerWindow:open()
    end
end

function hide()
    TaskSystemTrackerWindow:close()
end

function openMenu(widget, mousePos, button)
    if widget ~= nil and widget:getId() == 'menuButton' then
        if button ~= MouseLeftButton then
            return
        end
    elseif button ~= MouseRightButton then
        return
    end

    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    local function option(text, field, value)
        menu:addCheckBox(text, TaskSystemTrackerWindow[field] == value, function()
            TaskSystemTrackerWindow[field] = value
            reloadSorting()
            saveSettings()
        end)
    end
    option('Ordenar por nome', 'sortingType', 'name')
    option('Ordenar por progresso', 'sortingType', 'stage')
    option('Ordenar por abates', 'sortingType', 'kills')
    menu:addSeparator()
    option('Crescente', 'sortingOrder', 'asc')
    option('Decrescente', 'sortingOrder', 'desc')
    menu:display(mousePos)
end

-- Map square

-- Sits in the corner of the drawn map, which is letterboxed inside the map panel.
local function placeMapTracker()
    local mapPanel = mapTracker and mapTracker:getParent()
    if not mapPanel then
        return
    end
    local panelRect = mapPanel:getRect()
    local mapRect = mapPanel.getMapRect and mapPanel:getMapRect() or panelRect
    local rightEdge = mapRect.x + mapRect.width
    local bottomEdge = mapRect.y + mapRect.height

    -- Full-screen view: the right columns, the action bars and the chat are drawn over the map, so
    -- the card keeps to the corner the player still sees, left of the columns and above the bars.
    local gameInterface = modules.game_interface
    local root = gameInterface.getRootPanel()
    if gameInterface.currentViewMode == 2 and root then
        local function shown(panel)
            return panel and panel:isVisible() and panel:getWidth() > 0 and panel:getHeight() > 0
        end
        for _, id in ipairs({ 'gameMainRightPanel', 'gameRightPanel', 'gameRightExtraPanel', 'gameRightExtraPanel2',
            'gameRightExtraPanel3', 'gameRightActionPanel' }) do
            local panel = root:getChildById(id)
            if shown(panel) then
                rightEdge = math.min(rightEdge, panel:getX())
            end
        end
        for _, id in ipairs({ 'gameBottomActionPanel', 'gameBottomCooldownPanel', 'gameBottomStatsBarPanel',
            'gameBottomPanel' }) do
            local panel = root:getChildById(id)
            if shown(panel) and panel:getX() < rightEdge then
                bottomEdge = math.min(bottomEdge, panel:getY())
            end
        end
    end

    local right = math.max(0, (panelRect.x + panelRect.width) - rightEdge)
    local bottom = math.max(0, (panelRect.y + panelRect.height) - bottomEdge)
    -- Anchors to the parent start inside its padding.
    mapTracker:setMarginRight(right + MAP_TRACKER_MARGIN_RIGHT - mapPanel:getPaddingRight())
    mapTracker:setMarginBottom(bottom + MAP_TRACKER_MARGIN_BOTTOM - mapPanel:getPaddingBottom())
end

-- The drawn map moves when side panels open or close, the client is resized or the view mode
-- changes, often after the map panel's own geometry event and sometimes without one. So while the
-- card is shown it checks the map's corner every 100 ms and moves only when that corner changed.
local function followMapCorner()
    local mapPanel = mapTracker and mapTracker:getParent()
    if not mapPanel or not mapTracker:isVisible() then
        return
    end
    local p, m = mapPanel:getRect(), mapPanel.getMapRect and mapPanel:getMapRect() or mapPanel:getRect()
    local key = table.concat({ p.x, p.y, p.width, p.height, m.x, m.y, m.width, m.height,
        modules.game_interface.currentViewMode or 0 }, ',')
    if key ~= mapTrackerPlacedFor then
        mapTrackerPlacedFor = key
        placeMapTracker()
    end
end

local function onMapGeometryChange()
    addEvent(placeMapTracker)
end

local function startFollowingMap()
    if not mapTrackerFollowEvent then
        mapTrackerPlacedFor = nil
        mapTrackerFollowEvent = cycleEvent(followMapCorner, 100)
    end
    followMapCorner()
end

local function stopFollowingMap()
    if mapTrackerFollowEvent then
        removeEvent(mapTrackerFollowEvent)
        mapTrackerFollowEvent = nil
    end
end

function createMapTracker()
    local mapPanel = modules.game_interface.getMapPanel()
    if not mapPanel then
        return
    end
    mapTracker = g_ui.createWidget('RankTaskMapTracker', mapPanel)
    mapTracker:hide()
    connect(mapPanel, {
        onGeometryChange = onMapGeometryChange
    })
    addEvent(placeMapTracker)
end

local function stopMapTrackerCycle()
    if mapTrackerEvent then
        removeEvent(mapTrackerEvent)
        mapTrackerEvent = nil
    end
end

function destroyMapTracker()
    stopMapTrackerCycle()
    stopFollowingMap()
    if mapTracker then
        local mapPanel = mapTracker:getParent()
        if mapPanel then
            disconnect(mapPanel, {
                onGeometryChange = onMapGeometryChange
            })
        end
        mapTracker:destroy()
        mapTracker = nil
    end
end

local function showMapTrackerEntry(index)
    local entry = mapTrackerEntries[index]
    if not mapTracker or not entry then
        return
    end
    local raceData = g_things.getRaceData(entry.raceId)
    local creature = mapTracker:getChildById('creature')
    creature:show()
    if raceData and raceData.outfit then
        creature:setOutfit(raceData.outfit)
        if creature.setCenter then
            creature:setCenter(true)
        end
    end
    mapTracker:getChildById('counter'):setText(entry.kills .. '/' .. entry.total)
    if entry.total > 0 and entry.kills >= entry.total then
        mapTracker:getChildById('counter'):setColor('#00ff00')
    elseif entry.kills > 0 then
        mapTracker:getChildById('counter'):setColor('#ffff00')
    else
        mapTracker:getChildById('counter'):setColor('#ffffff')
    end
    mapTracker:setTooltip(entry.taskName)
end

function updateMapTracker()
    if not mapTracker then
        return
    end
    stopMapTrackerCycle()

    -- Every creature of every active task, each showing its task's overall progress.
    mapTrackerEntries = {}
    for _, task in ipairs(lastTrackerList) do
        local creatures = task.creatures or {}
        if #creatures == 0 then
            creatures = { { raceId = task.raceId } }
        end
        for _, creature in ipairs(creatures) do
            table.insert(mapTrackerEntries, {
                raceId = creature.raceId,
                taskName = task.name or '',
                kills = tonumber(task.kills) or 0,
                total = tonumber(task.total) or 0
            })
        end
    end

    if not mapTrackerVisible then
        mapTracker:hide()
        stopFollowingMap()
        return
    end
    if #mapTrackerEntries == 0 then
        -- Show Tracker is on but no task is active: an empty card, so the option visibly works.
        mapTracker:getChildById('creature'):hide()
        mapTracker:getChildById('counter'):setText('Sem task')
        mapTracker:getChildById('counter'):setColor('#c0c0c0')
        mapTracker:setTooltip('Nenhuma task ativa. Inicie uma task na janela de Tasks.')
        mapTracker:show()
        mapTracker:raise()
        startFollowingMap()
        return
    end
    if mapTrackerIndex > #mapTrackerEntries then
        mapTrackerIndex = 1
    end
    showMapTrackerEntry(mapTrackerIndex)
    if #mapTrackerEntries > 1 then
        mapTrackerEvent = cycleEvent(function()
            mapTrackerIndex = mapTrackerIndex % #mapTrackerEntries + 1
            showMapTrackerEntry(mapTrackerIndex)
        end, MAP_TRACKER_CYCLE)
    end
    mapTracker:show()
    mapTracker:raise()
    startFollowingMap()
end

function isMapTrackerVisible()
    return mapTrackerVisible
end

function setMapTrackerVisible(visible)
    mapTrackerVisible = visible == true
    g_settings.set(MAP_TRACKER_SETTING, mapTrackerVisible)
    local tasks = modules.game_ranktasks
    local checkbox = tasks and tasks.tasksWindow and tasks.tasksWindow:recursiveGetChildById('showTracker')
    if checkbox and checkbox:isChecked() ~= mapTrackerVisible then
        checkbox:setChecked(mapTrackerVisible)
    end
    updateMapTracker()
end
