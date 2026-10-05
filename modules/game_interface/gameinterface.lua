gameRootPanel = nil
gameMapPanel = nil
gameMainLeftPanel = nil
gameMainRightTopPanel = nil
gameMainRightPanel = nil
gameRightPanel = nil
gameRightExtraPanel = nil
gameRightExtraPanel2 = nil
gameRightExtraPanel3 = nil
gameLeftPanel = nil
gameLeftExtraPanel = nil
gameLeftExtraPanel2 = nil
gameLeftExtraPanel3 = nil
gameSelectedPanel = nil
panelsList = {}
panelsRadioGroup = nil
gameTopPanel = nil
gameBottomStatsBarPanel = nil
gameBottomPanel = nil
showTopMenuButton = nil
logoutButton = nil
logOutMainButton = nil
mouseGrabberWidget = nil
countWindow = nil
logoutWindow = nil
exitWindow = nil
bottomSplitter = nil
-- timestamp of the last manual keyboard walk, refreshed by game_walk and read
-- by consumers (e.g. game_bot) to pause automation while the player walks;
-- defined here so it is always present whenever this module is loaded
lastManualWalk = 0
limitedZoom = false
currentViewMode = 0
leftIncreaseSidePanels = nil
leftDecreaseSidePanels = nil
rightIncreaseSidePanels = nil
rightDecreaseSidePanels = nil
rightTopDivider = nil
mainRightTopDivider = nil
TOP_PANEL_DEFAULT_HEIGHT = 200 -- height a top panel opens with
TOP_PANEL_MIN_HEIGHT = TOP_PANEL_DEFAULT_HEIGHT -- a top panel never shrinks below the size it opens with
horizontalPanelLeftHeight = TOP_PANEL_DEFAULT_HEIGHT
horizontalPanelRightHeight = TOP_PANEL_DEFAULT_HEIGHT
TOP_PANEL_ROOM_BELOW = 150 -- height kept free for the column under a top panel

gameBottomActionPanel = nil
gameLeftActionPanel = nil
gameRightActionPanel = nil
gameBottomLockPanel = nil
gameRightLockPanel = nil
gameLeftLockPanel = nil

hookedMenuOptions = {}
focusReason = {}
local lastStopAction = 0
local mobileConfig = {
    mobileWidthJoystick = 0,
    mobileWidthShortcuts = 0,
    mobileHeightJoystick = 0,
    mobileHeightShortcuts = 0
}
local isExtendedViewActive = false

local OPCODE_AUTOBANK = 158
local ITEM_AUTOBANK = 41240

local function onAutobankOpcode(protocol, opcode, buffer)
    if opcode ~= OPCODE_AUTOBANK then return end
    local enabled = (buffer == "1" or buffer == "true" or buffer == 1)
    g_game.setAutobankEnabled(enabled)
end

function g_game.isAutobankEnabled()
    if g_game.autobankActive == nil then
        return g_settings.getBoolean('autobank_enabled', true)
    end
    return g_game.autobankActive
end

function g_game.setAutobankEnabled(enabled)
    g_game.autobankActive = enabled
    g_settings.set('autobank_enabled', enabled)
end

function g_game.toggleAutobank()
    local newState = not g_game.isAutobankEnabled()
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        protocolGame:sendExtendedOpcode(OPCODE_AUTOBANK, newState and "1" or "0")
    end
    g_game.setAutobankEnabled(newState)
end

local OPCODE_AUTOLOOT = 159
local ITEM_LOOT_POUCH = 23721

local function onAutolootOpcode(protocol, opcode, buffer)
    if opcode ~= OPCODE_AUTOLOOT then return end
    local enabled = (buffer == "1" or buffer == "true" or buffer == 1)
    g_game.setAutolootEnabled(enabled)
end

function g_game.isAutolootEnabled()
    if g_game.autolootActive == nil then
        return g_settings.getBoolean('autoloot_enabled', true)
    end
    return g_game.autolootActive
end

function g_game.setAutolootEnabled(enabled)
    g_game.autolootActive = enabled
    g_settings.set('autoloot_enabled', enabled)
end

function g_game.toggleAutoloot()
    local newState = not g_game.isAutolootEnabled()
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        protocolGame:sendExtendedOpcode(OPCODE_AUTOLOOT, newState and "1" or "0")
    end
    g_game.setAutolootEnabled(newState)
end

function getQuickLootCorpseVariant()
    return modules.client_options.getOption('quickLootAllCorpsesInArea') and 1 or 0
end

local function quickLootCorpse(item)
    g_game.sendQuickLoot(getQuickLootCorpseVariant(), item)
end

local function updateActionBarTopMargins()
    if not gameRootPanel or gameRootPanel:isDestroyed() then
        return
    end
    for _, entry in ipairs({
        {panel = gameLeftActionPanel, button = leftDecreaseSidePanels, padding = 1},
        {panel = gameRightActionPanel, button = rightDecreaseSidePanels, padding = 0}
    }) do
        local padding = entry.padding
        if entry.button:isVisible() then
            local panelRect = entry.panel:getRect()
            local buttonRect = entry.button:getRect()
            if buttonRect.x < panelRect.x + panelRect.width
                and buttonRect.x + buttonRect.width > panelRect.x then
                padding = math.max(padding, buttonRect.y + buttonRect.height - panelRect.y)
            end
        end
        if entry.panel:getPaddingTop() ~= padding then
            entry.panel:setPaddingTop(padding)
        end
    end
end

local function isHorizontalPanelActive(side)
    if not modules.client_options or not modules.client_options.getOption then
        return false
    end

    if side == 'left' then
        return modules.client_options.getOption('showHorizontalPanelLeft') == true
    elseif side == 'right' then
        return modules.client_options.getOption('showHorizontalPanelRight') == true
    end

    return false
end

local leftColumnsCount = 0
local rightColumnsCount = 0

local function getMaxLeftColumns()
    local available = g_window.getWidth() - 353 - 400
    local maxCols = math.floor(available / 177)
    return math.max(1, math.min(4, maxCols))
end

local function getMaxRightColumns()
    local available = g_window.getWidth() - 353 - 400
    local maxCols = math.floor(available / 177)
    return math.max(1, math.min(4, maxCols))
end

function getLeftColumnsCount()
    return leftColumnsCount
end

function getMaxLeftPanels()
    return getMaxLeftColumns()
end

function getRightColumnsCount()
    return rightColumnsCount
end

function getMaxRightPanels()
    return getMaxRightColumns()
end

local function refreshSidePanelToggleButtons()
    if not modules.client_options or not modules.client_options.getOption then
        return
    end

    local maxLeftCols = getMaxLeftColumns()
    if leftIncreaseSidePanels then
        leftIncreaseSidePanels:setEnabled(leftColumnsCount < maxLeftCols)
    end

    if leftDecreaseSidePanels then
        if g_platform.isMobile() then
            leftDecreaseSidePanels:setEnabled(false)
        else
            leftDecreaseSidePanels:setEnabled(leftColumnsCount > 0)
        end
    end

    local maxRightCols = getMaxRightColumns()
    if rightIncreaseSidePanels then
        rightIncreaseSidePanels:setEnabled(rightColumnsCount < maxRightCols)
    end

    if rightDecreaseSidePanels then
        rightDecreaseSidePanels:setEnabled(rightColumnsCount > 1)
    end
end

local function updateSidePanelButtons()
    local leftWidth = gameLeftPanel:getWidth() + gameLeftExtraPanel:getWidth()
        + gameLeftExtraPanel2:getWidth() + gameLeftExtraPanel3:getWidth()
    leftIncreaseSidePanels:setMarginLeft(leftWidth > 0 and -1 or 1)
    refreshSidePanelToggleButtons()
end

function refreshPanelToggleButtons()
    refreshSidePanelToggleButtons()
end

function updateLeftColumnsLayout(newCount)
    if newCount ~= nil then
        leftColumnsCount = math.max(0, math.min(getMaxLeftColumns(), newCount))
    end

    local count = leftColumnsCount

    if gameLeftPanel then
        gameLeftPanel:setOn(count >= 1)
        gameLeftPanel:setVisible(count >= 1)
    end
    if gameLeftExtraPanel then
        gameLeftExtraPanel:setOn(count >= 2)
        gameLeftExtraPanel:setVisible(count >= 2)
    end
    if gameLeftExtraPanel2 then
        gameLeftExtraPanel2:setOn(count >= 3)
        gameLeftExtraPanel2:setVisible(count >= 3)
    end
    if gameLeftExtraPanel3 then
        gameLeftExtraPanel3:setOn(count >= 4)
        gameLeftExtraPanel3:setVisible(count >= 4)
    end

    local outermostWidget = nil
    if count >= 4 and gameLeftExtraPanel3 then
        outermostWidget = gameLeftExtraPanel3
    elseif count >= 3 and gameLeftExtraPanel2 then
        outermostWidget = gameLeftExtraPanel2
    elseif count >= 2 and gameLeftExtraPanel then
        outermostWidget = gameLeftExtraPanel
    elseif count >= 1 and gameLeftPanel then
        outermostWidget = gameLeftPanel
    end

    local anchorTarget = outermostWidget and outermostWidget:getId() or 'parent'
    local anchorEdge = outermostWidget and AnchorRight or AnchorLeft

    if gameLeftActionPanel then
        gameLeftActionPanel:breakAnchors()
        gameLeftActionPanel:addAnchor(AnchorTop, 'gameTopPanel', AnchorBottom)
        gameLeftActionPanel:addAnchor(AnchorLeft, anchorTarget, anchorEdge)
        gameLeftActionPanel:addAnchor(AnchorBottom, 'bottomSplitter', AnchorTop)
    end

    if bottomSplitter then
        bottomSplitter:addAnchor(AnchorLeft, anchorTarget, anchorEdge)
    end

    if gameTopPanel then
        gameTopPanel:addAnchor(AnchorLeft, anchorTarget, anchorEdge)
    end

    if gameBottomStatsBarPanel then
        gameBottomStatsBarPanel:addAnchor(AnchorLeft, anchorTarget, anchorEdge)
    end

    if leftIncreaseSidePanels then
        leftIncreaseSidePanels:breakAnchors()
        leftIncreaseSidePanels:addAnchor(AnchorTop, 'parent', AnchorTop)
        leftIncreaseSidePanels:addAnchor(AnchorLeft, anchorTarget, anchorEdge)
    end

    if gameMainLeftPanel then
        local leftWidth = 0
        if count > 0 then
            leftWidth = count * 176 + (count - 1)
        end
        gameMainLeftPanel:setWidth(leftWidth)
    end

    refreshSidePanelToggleButtons()

    if modules.game_actionbar and modules.game_actionbar.updateVisibleWidgetsExternal then
        addEvent(function()
            modules.game_actionbar.updateVisibleWidgetsExternal()
        end)
    end
end

local syncingColumnOptions = false
-- Saves the column counts and keeps the panel options in step, so loading the options at the
-- next start does not shrink the columns back.
local function saveColumnsCount()
    g_settings.set('leftColumnsCount', leftColumnsCount)
    g_settings.set('rightColumnsCount', rightColumnsCount)
    if syncingColumnOptions or not modules.client_options or not modules.client_options.setOption then
        return
    end
    syncingColumnOptions = true
    pcall(function()
        modules.client_options.setOption('showLeftPanel', leftColumnsCount >= 1)
        modules.client_options.setOption('showLeftExtraPanel', leftColumnsCount >= 2)
        modules.client_options.setOption('showRightExtraPanel', rightColumnsCount >= 2)
    end)
    syncingColumnOptions = false
end

function setLeftColumnsCount(count)
    updateLeftColumnsLayout(count)
    saveColumnsCount()
end

function updateRightColumnsLayout(newCount)
    if newCount ~= nil then
        rightColumnsCount = math.max(1, math.min(getMaxRightColumns(), newCount))
    end

    local count = rightColumnsCount

    -- The main gameRightPanel is always visible (count >= 1)
    if gameRightPanel then
        gameRightPanel:setOn(true)
        gameRightPanel:setVisible(true)
    end
    if gameRightExtraPanel then
        gameRightExtraPanel:setOn(count >= 2)
        gameRightExtraPanel:setVisible(count >= 2)
    end
    if gameRightExtraPanel2 then
        gameRightExtraPanel2:setOn(count >= 3)
        gameRightExtraPanel2:setVisible(count >= 3)
    end
    if gameRightExtraPanel3 then
        gameRightExtraPanel3:setOn(count >= 4)
        gameRightExtraPanel3:setVisible(count >= 4)
    end

    -- Determine the outermost right widget (furthest from the right edge)
    local outermostWidget = nil
    if count >= 4 and gameRightExtraPanel3 then
        outermostWidget = gameRightExtraPanel3
    elseif count >= 3 and gameRightExtraPanel2 then
        outermostWidget = gameRightExtraPanel2
    elseif count >= 2 and gameRightExtraPanel then
        outermostWidget = gameRightExtraPanel
    elseif count >= 1 and gameRightPanel then
        outermostWidget = gameRightPanel
    end

    local anchorTarget = outermostWidget and outermostWidget:getId() or 'parent'
    local anchorEdge = outermostWidget and AnchorLeft or AnchorRight

    if gameRightActionPanel then
        gameRightActionPanel:breakAnchors()
        gameRightActionPanel:addAnchor(AnchorTop, 'gameTopPanel', AnchorBottom)
        gameRightActionPanel:addAnchor(AnchorRight, anchorTarget, anchorEdge)
        gameRightActionPanel:addAnchor(AnchorBottom, 'bottomSplitter', AnchorTop)
    end

    if bottomSplitter then
        bottomSplitter:addAnchor(AnchorRight, anchorTarget, anchorEdge)
    end

    if gameTopPanel then
        gameTopPanel:addAnchor(AnchorRight, anchorTarget, anchorEdge)
    end

    if gameBottomStatsBarPanel then
        gameBottomStatsBarPanel:addAnchor(AnchorRight, anchorTarget, anchorEdge)
    end

    if rightIncreaseSidePanels then
        rightIncreaseSidePanels:breakAnchors()
        rightIncreaseSidePanels:addAnchor(AnchorTop, 'parent', AnchorTop)
        rightIncreaseSidePanels:addAnchor(AnchorRight, anchorTarget, anchorEdge)
    end

    if gameMainRightTopPanel then
        local rightWidth = count * 176 + (count - 1)
        gameMainRightTopPanel:setWidth(rightWidth)
    end

    refreshSidePanelToggleButtons()

    if modules.game_actionbar and modules.game_actionbar.updateVisibleWidgetsExternal then
        addEvent(function()
            modules.game_actionbar.updateVisibleWidgetsExternal()
        end)
    end
end

function setRightColumnsCount(count)
    updateRightColumnsLayout(count)
    saveColumnsCount()
end

local function applyMobileMargins()
    if g_platform.isMobile() then
        gameRightPanel:setMarginBottom(mobileConfig.mobileHeightShortcuts)
        gameLeftPanel:setMarginBottom(mobileConfig.mobileHeightJoystick)
    end
end

function init()
    g_ui.importStyle('styles/countwindow')
    g_ui.importStyle('styles/countStashWindow')

    ProtocolGame.registerExtendedOpcode(OPCODE_AUTOBANK, onAutobankOpcode)
    ProtocolGame.registerExtendedOpcode(OPCODE_AUTOLOOT, onAutolootOpcode)

    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onLoginAdvice = onLoginAdvice
    }, true)

    -- Call load AFTER game window has been created and
    -- resized to a stable state, otherwise the saved
    -- settings can get overridden by false onGeometryChange
    -- events
    if g_app.hasUpdater() then
        connect(g_app, {
            onUpdateFinished = load,
        })
    else
        connect(g_app, {
            onRun = load,
        })
    end

    connect(g_app, {
        onExit = save
    })

    gameRootPanel = g_ui.displayUI('gameinterface')
    gameRootPanel:hide()
    gameRootPanel:lower()
    gameRootPanel.onGeometryChange = updateStretchShrink

    mouseGrabberWidget = gameRootPanel:getChildById('mouseGrabber')
    mouseGrabberWidget.onMouseRelease = onMouseGrabberRelease

    bottomSplitter = gameRootPanel:getChildById('bottomSplitter')
    bottomSplitter.vertical = true
    gameMapPanel = gameRootPanel:getChildById('gameMapPanel')
    gameMainLeftPanel = gameRootPanel:getChildById('gameLeftTopPanel')
    gameMainRightTopPanel = gameRootPanel:getChildById('gameRightTopPanel')
    connect(gameMapPanel, {onGeometryChange = function() addEvent(updateStretchShrink) end})
    gameMainRightPanel = gameRootPanel:getChildById('gameMainRightPanel')
    mainRightTopDivider = gameMainRightPanel and gameMainRightPanel:getChildById('mainRightTopDivider') or nil
    rightTopDivider = gameRootPanel:getChildById('rightTopDivider')
    gameRightPanel = gameRootPanel:getChildById('gameRightPanel')
    gameRightExtraPanel = gameRootPanel:getChildById('gameRightExtraPanel')
    gameRightExtraPanel2 = gameRootPanel:getChildById('gameRightExtraPanel2')
    gameRightExtraPanel3 = gameRootPanel:getChildById('gameRightExtraPanel3')
    gameLeftExtraPanel = gameRootPanel:getChildById('gameLeftExtraPanel')
    gameLeftExtraPanel2 = gameRootPanel:getChildById('gameLeftExtraPanel2')
    gameLeftExtraPanel3 = gameRootPanel:getChildById('gameLeftExtraPanel3')
    gameLeftPanel = gameRootPanel:getChildById('gameLeftPanel')
    gameBottomPanel = gameRootPanel:getChildById('gameBottomPanel')
    gameTopPanel = gameRootPanel:getChildById('gameTopPanel')
    gameBottomStatsBarPanel = gameRootPanel:getChildById('gameBottomStatsBarPanel')

    leftIncreaseSidePanels = gameRootPanel:getChildById('leftIncreaseSidePanels')
    leftDecreaseSidePanels = gameRootPanel:getChildById('leftDecreaseSidePanels')
    rightIncreaseSidePanels = gameRootPanel:getChildById('rightIncreaseSidePanels')
    rightDecreaseSidePanels = gameRootPanel:getChildById('rightDecreaseSidePanels')

    gameBottomActionPanel = gameRootPanel:getChildById('gameBottomActionPanel')
    gameRightActionPanel = gameRootPanel:getChildById('gameRightActionPanel')
    gameLeftActionPanel = gameRootPanel:getChildById('gameLeftActionPanel')
    gameBottomLockPanel = gameRootPanel:recursiveGetChildById('bottomLock')
    gameRightLockPanel = gameRootPanel:recursiveGetChildById('rightLock')
    gameLeftLockPanel = gameRootPanel:recursiveGetChildById('leftLock')

    horizontalPanelLeftHeight = math.max(TOP_PANEL_MIN_HEIGHT, g_settings.getNumber('horizontalPanelLeftHeight', 200))
    horizontalPanelRightHeight = math.max(TOP_PANEL_MIN_HEIGHT, g_settings.getNumber('horizontalPanelRightHeight', 200))
    if gameMainLeftPanel and modules.client_options and modules.client_options.getOption then
        local showHorizontalLeft = modules.client_options.getOption('showHorizontalPanelLeft') == true
        gameMainLeftPanel:setHeight(showHorizontalLeft and (horizontalPanelLeftHeight or 200) or 0)
        gameMainLeftPanel:setOn(showHorizontalLeft)
    end
    if gameMainRightTopPanel and modules.client_options and modules.client_options.getOption then
        local showHorizontalRight = modules.client_options.getOption('showHorizontalPanelRight') == true
        local rightH = horizontalPanelRightHeight or 200
        gameMainRightTopPanel:setHeight(showHorizontalRight and rightH or 0)
        gameMainRightTopPanel:setOn(showHorizontalRight)
        gameMainRightTopPanel.onGeometryChange = function(widget, oldRect, newRect)
            if widget:isOn() and widget:getHeight() > 0 then
                horizontalPanelRightHeight = math.max(TOP_PANEL_MIN_HEIGHT, widget:getHeight())
            end
        end
    end
    setupTopPanelResize(gameRootPanel:getChildById('leftTopPanelResizeBorder'), gameMainLeftPanel, false)
    setupTopPanelResize(gameRootPanel:getChildById('rightTopPanelResizeBorder'), gameMainRightTopPanel, true)


    if mainRightTopDivider and gameMainRightPanel then
        gameMainRightPanel:moveChildToIndex(mainRightTopDivider, 1)
    end

    if modules.client_options and modules.client_options.getOption then
        if modules.client_options.getOption('showLeftExtraPanel') then
            leftColumnsCount = 2
        elseif modules.client_options.getOption('showLeftPanel') then
            leftColumnsCount = 1
        else
            leftColumnsCount = 0
        end

        if modules.client_options.getOption('showRightExtraPanel') then
            rightColumnsCount = 2
        else
            rightColumnsCount = 1
        end
    end

    -- The +/- buttons open more columns than the options describe; the count left last session wins,
    -- so the windows saved in those columns find them at login.
    if g_settings.exists('leftColumnsCount') then
        leftColumnsCount = math.max(0, math.min(4, g_settings.getNumber('leftColumnsCount')))
    end
    if g_settings.exists('rightColumnsCount') then
        rightColumnsCount = math.max(1, math.min(4, g_settings.getNumber('rightColumnsCount')))
    end

    for _, panel in ipairs({gameBottomActionPanel, gameBottomStatsBarPanel,
        gameRootPanel:getChildById('gameBottomCooldownPanel')}) do
        connect(panel, {onGeometryChange = function(_, rect, oldRect)
            if rect.height ~= oldRect.height then addEvent(updateStretchShrink) end
        end})
    end

    for _, widget in ipairs({gameRootPanel, gameLeftActionPanel, gameRightActionPanel,
        leftDecreaseSidePanels, rightDecreaseSidePanels}) do
        connect(widget, {
            onGeometryChange = function() addEvent(updateActionBarTopMargins) end,
            onVisibilityChange = function() addEvent(updateActionBarTopMargins) end
        })
    end
    updateActionBarTopMargins()
    updateSidePanelButtons()
    updateHorizontalPanelsGeometry()
    applyMobileMargins()

    panelsList = { {
        panel = gameRightPanel,
        checkbox = gameRootPanel:getChildById('gameSelectRightColumn')
    }, {
        panel = gameRightExtraPanel,
        checkbox = gameRootPanel:getChildById('gameSelectRightExtraColumn')
    }, {
        panel = gameRightExtraPanel2,
        checkbox = gameRootPanel:getChildById('gameSelectRightExtra2Column')
    }, {
        panel = gameRightExtraPanel3,
        checkbox = gameRootPanel:getChildById('gameSelectRightExtra3Column')
    }, {
        panel = gameLeftPanel,
        checkbox = gameRootPanel:getChildById('gameSelectLeftColumn')
    }, {
        panel = gameLeftExtraPanel,
        checkbox = gameRootPanel:getChildById('gameSelectLeftExtraColumn')
    }, {
        panel = gameLeftExtraPanel2,
        checkbox = gameRootPanel:getChildById('gameSelectLeftExtra2Column')
    }, {
        panel = gameLeftExtraPanel3,
        checkbox = gameRootPanel:getChildById('gameSelectLeftExtra3Column')
    } }

    panelsRadioGroup = UIRadioGroup.create()
    for k, v in pairs(panelsList) do
        panelsRadioGroup:addWidget(v.checkbox)
        connect(v.checkbox, {
            onCheckChange = onSelectPanel
        })
    end
    panelsRadioGroup:selectWidget(panelsList[1].checkbox)

    logoutButton = modules.client_topmenu.addTopRightToggleButton('logoutButton', tr('Exit'), '/images/topbuttons/logout',
        tryLogout, true)

    gameMapPanel.onClick = toggleInternalFocus
    gameRightPanel.onClick = toggleInternalFocus
    gameRightExtraPanel.onClick = toggleInternalFocus
    if gameRightExtraPanel2 then
        gameRightExtraPanel2.onClick = toggleInternalFocus
    end
    if gameRightExtraPanel3 then
        gameRightExtraPanel3.onClick = toggleInternalFocus
    end
    gameLeftExtraPanel.onClick = toggleInternalFocus
    if gameLeftExtraPanel2 then
        gameLeftExtraPanel2.onClick = toggleInternalFocus
    end
    if gameLeftExtraPanel3 then
        gameLeftExtraPanel3.onClick = toggleInternalFocus
    end
    gameLeftPanel.onClick = toggleInternalFocus
    if gameMainLeftPanel then
        gameMainLeftPanel.onClick = toggleInternalFocus
    end
    if gameMainRightTopPanel then
        gameMainRightTopPanel.onClick = toggleInternalFocus
    end
    gameBottomPanel.onClick = toggleInternalFocus

    showTopMenuButton = gameMapPanel:getChildById('showTopMenuButton')
    showTopMenuButton.onClick = function()
        modules.client_topmenu.toggle()
    end

    bindKeys()

    if g_game.isOnline() then
        show()
    end

    MapLayout.init()
    StatsBar.init()
end

function bindKeys()
    gameRootPanel:setAutoRepeatDelay(50)

    g_keyboard.bindKeyPress('Ctrl+=', function()
        gameMapPanel:zoomIn()
    end, gameRootPanel)
    g_keyboard.bindKeyPress('Ctrl+-', function()
        gameMapPanel:zoomOut()
    end, gameRootPanel)

    Keybind.new("Movement", "Stop All Actions", "Escape", "", true)
    Keybind.bind("Movement", "Stop All Actions", {
        {
            type = KEY_PRESS,
            callback = function()
                if lastStopAction + 50 > g_clock.millis() then return end
                lastStopAction = g_clock.millis()
                g_game.cancelAttackAndFollow()
            end,
        }
    }, gameRootPanel)

    Keybind.new("Misc", "Logout", "Ctrl+L", "Ctrl+Q")
    Keybind.bind("Misc", "Logout", {
        {
            type = KEY_PRESS,
            callback = function() tryLogout(false) end,
        }
    }, gameRootPanel)

    Keybind.new("UI", "Clear All Texts", "Ctrl+W", "")
    Keybind.bind("UI", "Clear All Texts", {
        {
            type = KEY_DOWN,
            callback = function()
                g_map.cleanTexts()
                modules.game_textmessage.clearMessages()
            end,
        }
    }, gameRootPanel)

    g_keyboard.bindKeyDown('Ctrl+.', nextViewMode, gameRootPanel)
end

function terminate()
    ProtocolGame.unregisterExtendedOpcode(OPCODE_AUTOBANK)
    ProtocolGame.unregisterExtendedOpcode(OPCODE_AUTOLOOT)

    MapLayout.terminate()
    StatsBar.terminate()

    hide()
    if g_app.hasUpdater() then
        disconnect(g_app, {
            onUpdateFinished = load,
        })
    else
        disconnect(g_app, {
            onRun = load,
        })
    end
    disconnect(g_app, {
        onExit = save,
    })

    hookedMenuOptions = {}

    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onLoginAdvice = onLoginAdvice
    })

    for k, v in pairs(panelsList) do
        disconnect(v.checkbox, {
            onCheckChange = onSelectPanel
        })
    end

    logoutButton:destroy()
    gameRootPanel:destroy()
    Keybind.delete("Movement", "Stop All Actions")
    Keybind.delete("Misc", "Logout")
    Keybind.delete("UI", "Clear All Texts")
end

local layoutLiveEvent = nil

-- The side windows come back from each module's onGameStart and the containers from the server
-- right after login. Once they are all in place the layout goes live: from then on what the player
-- does is saved, and the panels make room once for everything that came back.
local function startLiveLayout()
    layoutLiveEvent = nil
    MiniWindowLayout.live = true
    for _, panel in ipairs({ gameMainLeftPanel, gameMainRightTopPanel, gameMainRightPanel, gameLeftPanel, gameLeftExtraPanel,
        gameLeftExtraPanel2, gameLeftExtraPanel3, gameRightPanel, gameRightExtraPanel, gameRightExtraPanel2,
        gameRightExtraPanel3 }) do
        if panel and panel:getClassName() == 'UIMiniWindowContainer' then
            panel:fitAll()
        end
    end
end

function onGameStart()
    g_game.autobankActive = g_settings.getBoolean('autobank_enabled', true)
    g_game.autolootActive = g_settings.getBoolean('autoloot_enabled', true)
    MiniWindowLayout.live = false
    removeEvent(layoutLiveEvent)
    layoutLiveEvent = scheduleEvent(startLiveLayout, 1500)
    show()
    updateSidePanelButtons()
    applyMobileMargins()
end

function onGameEnd()
    MiniWindowLayout.live = false
    removeEvent(layoutLiveEvent)
    layoutLiveEvent = nil
    hide()
end

function show()
    connect(g_app, {
        onClose = tryExit
    })
    modules.client_background.hide()
    gameRootPanel:show()
    gameRootPanel:focus()
    gameMapPanel:followCreature(g_game.getLocalPlayer())

    updateStretchShrink()
    logoutButton:setTooltip(tr('Logout'))

    if g_platform.isMobile() then
        mobileConfig.mobileWidthJoystick = modules.game_joystick.getPanel():getWidth()
        mobileConfig.mobileWidthShortcuts = modules.game_shortcuts.getPanel():getWidth()
        mobileConfig.mobileHeightJoystick = modules.game_joystick.getPanel():getHeight()
        mobileConfig.mobileHeightShortcuts = modules.game_shortcuts.getPanel():getHeight()
    end

    setupViewMode(0)
    if g_platform.isMobile() or g_gameConfig.isExtendedViewUI() then
        setupViewMode(1)
        setupViewMode(2)
    end

    addEvent(function()
        if not limitedZoom or g_game.isGM() then
            gameMapPanel:setMaxZoomOut(513)
            gameMapPanel:setLimitVisibleRange(false)
        else
            gameMapPanel:setMaxZoomOut(11)
            gameMapPanel:setLimitVisibleRange(true)
        end
    end)
end

function hide()
    MapLayout.hide()
    setupViewMode(0)

    disconnect(g_app, {
        onClose = tryExit
    })
    logoutButton:setTooltip(tr('Exit'))

    if logoutWindow then
        logoutWindow:destroy()
        logoutWindow = nil
    end
    if exitWindow then
        exitWindow:destroy()
        exitWindow = nil
    end
    if countWindow then
        countWindow:destroy()
        countWindow = nil
    end
    gameRootPanel:hide()
    modules.client_background.show()
end

function save()
    -- The client is closing: windows the modules close or move from here on are not the player's doing.
    MiniWindowLayout.live = false
    local settings = {}
    settings.splitterMarginBottom = bottomSplitter:getMarginBottom()
    MapLayout.save(settings)
    g_settings.setNode('game_interface', settings)
end

function load()
    local settings = g_settings.getNode('game_interface')
    if settings then
        MapLayout.load(settings)
        if settings.splitterMarginBottom then
            bottomSplitter:setMarginBottom(settings.splitterMarginBottom)
        end
    end
end

function onLoginAdvice(message)
    displayInfoBox(tr('For Your Information'), message)
end

function forceExit()
    g_game.cancelLogin()
    scheduleEvent(exit, 10)
    return true
end

function tryExit()
    if exitWindow then
        return true
    end

    local exitFunc = function()
        g_game.safeLogout()
        forceExit()
    end
    local logoutFunc = function()
        g_game.safeLogout()
        exitWindow:destroy()
        exitWindow = nil
    end
    local cancelFunc = function()
        exitWindow:destroy()
        exitWindow = nil
    end

    exitWindow = displayGeneralBox(tr('Exit'), tr(
            'If you shut down the program, your character might stay in the game.\nClick on \'Logout\' to ensure that you character leaves the game properly.\nClick on \'Exit\' if you want to exit the program without logging out your character.'),
        {
            {
                text = tr('Cancel'),
                callback = cancelFunc
            },
            {
                text = tr('Logout'),
                callback = logoutFunc
            },
            {
                text = tr('Force Exit'),
                callback = exitFunc
            },
            anchor = AnchorHorizontalCenter
        }, logoutFunc, cancelFunc)

    return true
end

function tryLogout(prompt)
    if type(prompt) ~= 'boolean' then
        prompt = true
    end
    if not g_game.isOnline() then
        exit()
        return
    end

    if logoutWindow then
        return
    end

    local msg, yesCallback
    if not g_game.isConnectionOk() then
        msg =
        'Your connection is failing, if you logout now your character will be still online, do you want to force logout?'

        yesCallback = function()
            g_game.forceLogout()
            if logoutWindow then
                logoutWindow:destroy()
                logoutWindow = nil
            end
        end
    else
        msg = 'Are you sure you want to logout?'

        yesCallback = function()
            g_game.safeLogout()
            if logoutWindow then
                logoutWindow:destroy()
                logoutWindow = nil
            end
        end
    end

    local noCallback = function()
        logoutWindow:destroy()
        logoutWindow = nil
    end

    if prompt then
        logoutWindow = displayGeneralBox(tr('Logout'), tr(msg), {
            {
                text = tr('No'),
                callback = noCallback
            },
            {
                text = tr('Yes'),
                callback = yesCallback
            },
            anchor = AnchorHorizontalCenter
        }, yesCallback, noCallback)
    else
        yesCallback()
    end
end

function constrainBottomPanelHeight(requestedHeight)
    if not gameMapPanel or not bottomSplitter or currentViewMode == 2 or g_platform.isMobile() then
        return requestedHeight
    end
    local minimumMapHeight = 186
    local maximumMapHeight = math.max(minimumMapHeight, math.floor((gameMapPanel:getWidth() - 10) * 11 / 15) + 10)
    local bottomContentHeight = math.max(0, gameBottomPanel:getY() - bottomSplitter:getY() - bottomSplitter:getHeight())
    local minimumBottomHeight = 90 + bottomContentHeight
    local availableHeight = gameMapPanel:getHeight() + bottomSplitter:getMarginBottom()
    maximumMapHeight = math.min(maximumMapHeight, math.max(minimumMapHeight, availableHeight - minimumBottomHeight))
    local mapHeight = availableHeight - requestedHeight
    if modules.client_options.getOption('dontStretchShrink') then
        mapHeight = 362
    else
        local scale = (mapHeight - 10) / 352
        local nearest = math.floor(scale + 0.5)
        if math.abs(scale - nearest) <= 0.05 then mapHeight = nearest * 352 + 10 end
    end
    mapHeight = math.max(minimumMapHeight, math.min(mapHeight, maximumMapHeight))
    return math.floor(availableHeight - mapHeight)
end

local updatingLayout = false
function updateStretchShrink()
    if not gameMapPanel or not bottomSplitter or not gameBottomActionPanel or not gameBottomStatsBarPanel
        or not gameRootPanel:isVisible() or updatingLayout then return end
    updatingLayout = true
    updateSidePanelButtons()
    if currentViewMode ~= 2 and not g_platform.isMobile() then
        bottomSplitter:setMarginBottom(constrainBottomPanelHeight(MapLayout.requestedBottomHeight()))
    end
    updatingLayout = false
    if modules.game_actionbar and modules.game_actionbar.updateVisibleWidgetsExternal then
        addEvent(function() modules.game_actionbar.updateVisibleWidgetsExternal() end)
    end
    updateLeftColumnsLayout()
end

function onMouseGrabberRelease(self, mousePosition, mouseButton)
    if selectedThing == nil then
        return false
    end
    if mouseButton == MouseLeftButton then
        local clickedWidget = gameRootPanel:recursiveGetChildByPos(mousePosition, false)
        if clickedWidget then
            if selectedType == 'use' then
                onUseWith(clickedWidget, mousePosition)
            elseif selectedType == 'trade' then
                onTradeWith(clickedWidget, mousePosition)
            end
        end
    end

    selectedThing = nil
    -- Restore cursor
    if modules.client_options and modules.client_options.getOption('nativeCursor') then
        g_window.restoreMouseCursor()
    else
        g_mouse.popCursor('target')
    end
    self:ungrabMouse()
    return true
end

function onUseWith(clickedWidget, mousePosition)
    if clickedWidget:getClassName() == 'UIGameMap' then
        local tile = clickedWidget:getTile(mousePosition)
        if tile then
            if selectedThing:isFluidContainer() or selectedThing:isMultiUse() then
                g_game.useWith(selectedThing, tile:getTopMultiUseThing())
            else
                g_game.useWith(selectedThing, tile:getTopUseThing())
            end
        end
    elseif clickedWidget:getClassName() == 'UIItem' and not clickedWidget:isVirtual() then
        g_game.useWith(selectedThing, clickedWidget:getItem())
    elseif clickedWidget:getClassName() == 'UICreatureButton' then
        local creature = clickedWidget:getCreature()
        if creature then
            g_game.useWith(selectedThing, creature)
        end
    end
end

function onTradeWith(clickedWidget, mousePosition)
    if clickedWidget:getClassName() == 'UIGameMap' then
        local tile = clickedWidget:getTile(mousePosition)
        if tile then
            g_game.requestTrade(selectedThing, tile:getTopCreature())
        end
    elseif clickedWidget:getClassName() == 'UICreatureButton' then
        local creature = clickedWidget:getCreature()
        if creature then
            g_game.requestTrade(selectedThing, creature)
        end
    end
end

function startUseWith(thing)
    if not thing then
        return
    end
    if g_ui.isMouseGrabbed() then
        if selectedThing then
            selectedThing = thing
            selectedType = 'use'
        end
        return
    end
    selectedType = 'use'
    selectedThing = thing
    mouseGrabberWidget:grabMouse()
    -- Use native cursor when enabled, otherwise use custom cursor
    if modules.client_options and modules.client_options.getOption('nativeCursor') then
        g_window.setSystemCursor('cross')
    else
        g_mouse.pushCursor('target')
    end
end

function startTradeWith(thing)
    if not thing then
        return
    end
    if g_ui.isMouseGrabbed() then
        if selectedThing then
            selectedThing = thing
            selectedType = 'trade'
        end
        return
    end
    selectedType = 'trade'
    selectedThing = thing
    mouseGrabberWidget:grabMouse()
    -- Use native cursor when enabled, otherwise use custom cursor
    if modules.client_options and modules.client_options.getOption('nativeCursor') then
        g_window.setSystemCursor('cross')
    else
        g_mouse.pushCursor('target')
    end
end

function isMenuHookCategoryEmpty(category)
    if category then
        for _, opt in pairs(category) do
            if opt then
                return false
            end
        end
    end
    return true
end

function addMenuHook(category, name, callback, condition, shortcut)
    if not hookedMenuOptions[category] then
        hookedMenuOptions[category] = {}
    end
    hookedMenuOptions[category][name] = {
        callback = callback,
        condition = condition,
        shortcut = shortcut
    }
end

function removeMenuHook(category, name)
    if not name then
        hookedMenuOptions[category] = {}
    else
        hookedMenuOptions[category][name] = nil
    end
end

function createThingMenu(menuPosition, lookThing, useThing, creatureThing)
    if not g_game.isOnline() then
        return
    end

    local menu = UIContextMenu.create({})

    local classic = modules.client_options.getOption('classicControl')
    local smartLeftClick = modules.client_options.getOption('smartLeftClick')
    local mobile = g_platform.isMobile()
    local shortcut = nil

    if not classic and not mobile and not smartLeftClick then
        shortcut = '(Shift)'
    else
        shortcut = nil
    end
    if lookThing then
        menu:addOption(tr('Look'), function()
            g_game.look(lookThing)
        end, shortcut)
        local clientVersion = g_game.getClientVersion()
        local canInspect = lookThing:isItem() and not lookThing:isNotMoveable() and lookThing:isPickupable()
        if clientVersion >= 1281 and modules.game_inspect and (lookThing:isCreature() or canInspect) then
            menu:addOption(tr('Inspect'), function()
                if lookThing:isCreature() then
                    g_game.inspectCharacter(lookThing:getId(), InspectCreaturesTypes.INSPECT_CREATURE)
                elseif canInspect then
                    local pos = lookThing:getPosition()
                    if pos and pos.x and pos.y and pos.z then
                        g_game.inspectionNormalObject(pos)
                    else
                        g_game.inspectionObject(InspectObjectTypes.INSPECT_CYCLOPEDIA, lookThing:getId())
                    end
                end
            end)
        end
        if clientVersion >= 1310 and canInspect and modules.game_cyclopedia and lookThing:getCyclopediaType() > 0 then
            menu:addOption(tr('Cyclopedia'), function()
                modules.game_cyclopedia.Cyclopedia.openItem(lookThing:getId())
            end)
        end
        if lookThing:isItem() and modules.game_exercise_exchange and modules.game_exercise_exchange.isExerciseWeapon(lookThing:getId()) then
            menu:addOption(tr('Change Weapon Type'), function()
                modules.game_exercise_exchange.open(lookThing)
            end)
        end
        if lookThing:isItem() and modules.game_item_refiller then
            local thingId = lookThing:getId()
            if thingId == 41543 then
                menu:addOption(tr('Open Rune Refiller'), function()
                    g_game.use(lookThing)
                end)
            elseif thingId == 41544 then
                menu:addOption(tr('Open Ammunition Refiller'), function()
                    g_game.use(lookThing)
                end)
            end
        end
        if lookThing:isItem() and lookThing:getId() == ITEM_AUTOBANK and not useThing then
            local isEnabled = g_game.isAutobankEnabled()
            local text = isEnabled and tr('Autobank ON') or tr('Autobank OFF')
            local icon = isEnabled and '/images/ui/icon-yes' or '/images/ui/icon-no'
            menu:addOptionWithIcon(text, function()
                g_game.toggleAutobank()
            end, icon)
        end
        if lookThing:isItem() and lookThing:getId() == ITEM_LOOT_POUCH and not useThing then
            local isEnabled = g_game.isAutolootEnabled()
            local text = isEnabled and tr('Autoloot ON') or tr('Autoloot OFF')
            local icon = isEnabled and '/images/ui/icon-yes' or '/images/ui/icon-no'
            menu:addOptionWithIcon(text, function()
                g_game.toggleAutoloot()
            end, icon)
        end
        local canOpenProficiency = false
        if modules.game_proficiency and modules.game_proficiency.requestOpenWindow then
            if lookThing.getProficiencyId and lookThing:getProficiencyId() > 0 then
                canOpenProficiency = true
            elseif lookThing.getWeaponType and lookThing:getWeaponType() > 0 then
                canOpenProficiency = true
            else
                local thingType = g_things.getThingType(lookThing:getId(), ThingCategoryItem)
                if thingType then
                    if thingType.getWeaponType and thingType:getWeaponType() > 0 then
                        canOpenProficiency = true
                    elseif thingType.getMarketData then
                        local md = thingType:getMarketData()
                        local cat = md and md.category
                        if cat == 17 or cat == 18 or cat == 19 or cat == 20 or cat == 21 or cat == 32 then
                            canOpenProficiency = true
                        end
                    end
                end
            end
        end
        if canOpenProficiency then
            menu:addOption(tr("Weapon Proficiency"), function()
                modules.game_proficiency.requestOpenWindow(lookThing)
            end)
        end
    end

    if not classic and not mobile then
        shortcut = '(Ctrl)'
    else
        shortcut = nil
    end
    if useThing then
        if useThing:isContainer() then
            if useThing:getParentContainer() then
                menu:addOption(tr('Open'), function()
                    g_game.open(useThing, useThing:getParentContainer())
                end, shortcut)
                menu:addOption(tr('Open in new window'), function()
                    g_game.open(useThing)
                end)
            else
                menu:addOption(tr('Open'), function()
                    g_game.open(useThing)
                end, shortcut)
            end

            if useThing:getId() == ITEM_LOOT_POUCH then
                local isEnabled = g_game.isAutolootEnabled()
                local text = isEnabled and tr('Autoloot ON') or tr('Autoloot OFF')
                local icon = isEnabled and '/images/ui/icon-yes' or '/images/ui/icon-no'
                menu:addOptionWithIcon(text, function()
                    g_game.toggleAutoloot()
                end, icon)
            end
        else
            if useThing:isMultiUse() then
                menu:addOption(tr('Use with ...'), function()
                    startUseWith(useThing)
                end, shortcut)
            else
                local thingId = useThing:getId()
                if thingId == ITEM_AUTOBANK then
                    menu:addOption(tr('Use'), function()
                        g_game.use(useThing)
                    end, shortcut)
                    local isEnabled = g_game.isAutobankEnabled()
                    local text = isEnabled and tr('Autobank ON') or tr('Autobank OFF')
                    local icon = isEnabled and '/images/ui/icon-yes' or '/images/ui/icon-no'
                    menu:addOptionWithIcon(text, function()
                        g_game.toggleAutobank()
                    end, icon)
                else
                    menu:addOption(tr('Use'), function()
                        g_game.use(useThing)
                    end, shortcut)
                end
            end
        end

        -- The server turns podiums through the same rotate request.
        if useThing:isRotateable() or useThing:isPodium() then
            menu:addOption(tr('Rotate'), function()
                g_game.rotate(useThing)
            end)
        end

        -- Vigour and Tenacity open "Customise Podium"; Renown opens the outfit window in podium mode.
        if useThing:isPodium() then
            menu:addOption(tr('Customise Podium'), function()
                g_game.configureShowOffSocket(useThing)
            end)
        end

        local onWrapItem = function()
            g_game.wrap(useThing)
        end
        if useThing:isWrapable() then
            menu:addOption(tr('Wrap'), onWrapItem)
        end
        if useThing:isUnwrapable() then
            menu:addOption(tr('Unwrap'), onWrapItem)
        end

        if g_game.getFeature(GameBrowseField) and useThing and useThing:getPosition() and useThing:getPosition().x ~= 0xffff then
            menu:addOption(tr('Browse Field'), function()
                g_game.browseField(useThing:getPosition())
            end)
        end
        if useThing:isLyingCorpse() and g_game.getFeature(GameThingQuickLoot) and modules.game_quickloot and useThing:getPosition().x ~= 0xffff then
            menu.addOption(menu, tr("Loot corpse"), function()
                quickLootCorpse(useThing)
            end)
        end
    end

    if lookThing and not lookThing:isCreature() and not lookThing:isNotMoveable() and lookThing:isPickupable() then
        menu:addSeparator()
        menu:addOption(tr('Trade with ...'), function()
            startTradeWith(lookThing)
        end)
    end

    if lookThing then
        local parentContainer = lookThing:getParentContainer()
        if parentContainer and parentContainer:hasParent() then
            menu:addOption(tr('Move up'), function()
                g_game.moveToParentContainer(lookThing, lookThing:getCount())
            end)
        end
    end

    if creatureThing then
        local localPlayer = g_game.getLocalPlayer()
        menu:addSeparator()

        if creatureThing:isLocalPlayer() then
            menu:addOption(tr(g_game.getClientVersion() >= 1000 and "Customise Character" or "Set Outfit"), function()
                g_game.requestOutfit()
            end)

            if g_game.getFeature(GamePrey) then
                menu:addOption(tr('Prey Dialog'), function()
                    modules.game_prey.show()
                end)
            end

            if g_game.getFeature(GamePlayerMounts) then
                if not localPlayer:isMounted() then
                    menu:addOption(tr('Mount'), function()
                        localPlayer:mount()
                    end)
                else
                    menu:addOption(tr('Dismount'), function()
                        localPlayer:dismount()
                    end)
                end
            end

            if creatureThing:isPartyMember() then
                if creatureThing:isPartyLeader() then
                    if creatureThing:isPartySharedExperienceActive() then
                        menu:addOption(tr('Disable Shared Experience'), function()
                            g_game.partyShareExperience(false)
                        end)
                    else
                        menu:addOption(tr('Enable Shared Experience'), function()
                            g_game.partyShareExperience(true)
                        end)
                    end
                end
                menu:addOption(tr('Leave Party'), function()
                    g_game.partyLeave()
                end)
            end
        else
            local localPosition = localPlayer:getPosition()
            if not classic and not mobile then
                shortcut = '(Alt)'
            else
                shortcut = nil
            end
            if creatureThing:getPosition().z == localPosition.z then
                if creatureThing:isNpc() then
                    menu:addOption(tr('Talk'), function()
                        g_game.talk("hi")
                    end)
                end

                if g_game.getAttackingCreature() ~= creatureThing then
                    menu:addOption(tr('Attack'), function()
                        g_game.attack(creatureThing)
                    end, shortcut)
                else
                    menu:addOption(tr('Stop Attack'), function()
                        g_game.cancelAttack()
                    end, shortcut)
                end

                if g_game.getFollowingCreature() ~= creatureThing then
                    menu:addOption(tr('Follow'), function()
                        g_game.follow(creatureThing)
                    end)
                else
                    menu:addOption(tr('Stop Follow'), function()
                        g_game.cancelFollow()
                    end)
                end
            end

            if creatureThing:isPlayer() then
                menu:addSeparator()
                local creatureName = creatureThing:getName()
                menu:addOption(tr('Message to %s', creatureName), function()
                    g_game.openPrivateChannel(creatureName)
                end)
                if modules.game_console.getOwnPrivateTab() then
                    menu:addOption(tr('Invite to private chat'), function()
                        g_game.inviteToOwnChannel(creatureName)
                    end)
                    menu:addOption(tr('Exclude from private chat'), function()
                        g_game.excludeFromOwnChannel(creatureName)
                    end) -- [TODO] must be removed after message's popup labels been implemented
                end
                if not localPlayer:hasVip(creatureName) then
                    menu:addOption(tr('Add to VIP list'), function()
                        g_game.addVip(creatureName)
                    end)
                end

                if modules.game_console.isIgnored(creatureName) then
                    menu:addOption(tr('Unignore') .. ' ' .. creatureName, function()
                        modules.game_console.removeIgnoredPlayer(creatureName)
                    end)
                else
                    menu:addOption(tr('Ignore') .. ' ' .. creatureName, function()
                        modules.game_console.addIgnoredPlayer(creatureName)
                    end)
                end

                local localPlayerShield = localPlayer:getShield()
                local creatureShield = creatureThing:getShield()

                if localPlayerShield == ShieldNone or localPlayerShield == ShieldWhiteBlue then
                    if creatureShield == ShieldWhiteYellow then
                        menu:addOption(tr('Join %s\'s Party', creatureThing:getName()), function()
                            g_game.partyJoin(creatureThing:getId())
                        end)
                    else
                        menu:addOption(tr('Invite to Party'), function()
                            g_game.partyInvite(creatureThing:getId())
                        end)
                    end
                elseif localPlayerShield == ShieldWhiteYellow then
                    if creatureShield == ShieldWhiteBlue then
                        menu:addOption(tr('Revoke %s\'s Invitation', creatureThing:getName()), function()
                            g_game.partyRevokeInvitation(creatureThing:getId())
                        end)
                    end
                elseif localPlayerShield == ShieldYellow or localPlayerShield == ShieldYellowSharedExp or
                    localPlayerShield == ShieldYellowNoSharedExpBlink or localPlayerShield == ShieldYellowNoSharedExp then
                    if creatureShield == ShieldWhiteBlue then
                        menu:addOption(tr('Revoke %s\'s Invitation', creatureThing:getName()), function()
                            g_game.partyRevokeInvitation(creatureThing:getId())
                        end)
                    elseif creatureShield == ShieldBlue or creatureShield == ShieldBlueSharedExp or creatureShield ==
                        ShieldBlueNoSharedExpBlink or creatureShield == ShieldBlueNoSharedExp then
                        menu:addOption(tr('Pass Leadership to %s', creatureThing:getName()), function()
                            g_game.partyPassLeadership(creatureThing:getId())
                        end)
                    else
                        menu:addOption(tr('Invite to Party'), function()
                            g_game.partyInvite(creatureThing:getId())
                        end)
                    end
                end
            end
        end

        -- Level to share experience
        do
            local ok, level = pcall(function() return creatureThing:getLevel() end)
            if ok and level and level > 0 then
                menu:addOption(tr('Level to share experience'), function()
                    local minLevel = math.ceil(level * 2 / 3)
                    local maxLevel = math.floor(level * 3 / 2)
                    local coloredText = string.format(
                        '{The level , #ffffff}{%d, #00ebff}{ character shares experience with levels , #ffffff}{%d, #00ebff}{ to , #ffffff}{%d, #00ebff}{., #ffffff}',
                        level, minLevel, maxLevel
                    )
                    local plainText = string.format(
                        'The level %d character shares experience with levels %d to %d.',
                        level, minLevel, maxLevel
                    )
                    if modules.game_textmessage and modules.game_textmessage.displayCustomColoredMessage then
                        modules.game_textmessage.displayCustomColoredMessage('middleCenterLabel', coloredText, plainText, 'Server Log')
                    elseif modules.game_textmessage then
                        modules.game_textmessage.displayGameMessage(plainText)
                    end
                end)
            end
        end

        if modules.game_ruleviolation.hasWindowAccess() and creatureThing:isPlayer() then
            menu:addSeparator()
            menu:addOption(tr('Rule Violation'), function()
                modules.game_ruleviolation.show(creatureThing:getName())
            end)
        end

        menu:addSeparator()
        menu:addOption(tr('Copy Name'), function()
            g_window.setClipboardText(creatureThing:getName())
        end)
    end

    -- hooked menu options
    for _, category in pairs(hookedMenuOptions) do
        if not isMenuHookCategoryEmpty(category) then
            menu:addSeparator()
            for name, opt in pairs(category) do
                if opt and opt.condition(menuPosition, lookThing, useThing, creatureThing) then
                    menu:addOption(name, function()
                        opt.callback(menuPosition, lookThing, useThing, creatureThing)
                    end, opt.shortcut)
                end
            end
        end
    end

    if modules.game_bot and useThing and useThing:isItem() then
        menu:addSeparator()
        local useThingId = useThing:getId()
        menu:addOption("ID: " .. useThingId, function() g_window.setClipboardText(useThingId) end)
    end

    if g_game.getFeature(GameThingQuickLoot) and modules.game_quickloot and lookThing and not lookThing:isCreature() and lookThing:isPickupable() then
        local quickLoot = modules.game_quickloot.QuickLoot
        menu.addSeparator(menu)

        if lookThing:isContainer() then
            menu.addOption(menu, tr("Manage Loot Containers"), function()
                quickLoot.toggle()
            end)
        end

        local lootExists = quickLoot.lootExists(lookThing:getId())
        local optionText = lootExists and "Remove from" or "Add to"
        local actionFunction = lootExists and quickLoot.removeLootList or quickLoot.addLootList

        menu.addOption(menu, tr(optionText .. " loot list"), function()
            actionFunction(lookThing:getId())
        end)
    end

    if g_game.getClientVersion() >= 1410 then
        if lookThing and not lookThing:isCreature() and not lookThing:isNotMoveable() and lookThing:isPickupable() then
            local player = g_game.getLocalPlayer()
            if player and player:isSupplyStashAvailable() then
                local itemTier = lookThing:getTier() or 0
                if itemTier <= 0 then
                    menu:addSeparator()
                    menu:addOption(tr("Stow"), function()
                        stashItem(lookThing)
                    end)
                    menu:addOption(tr("Stow all items of this type"), function()
                        g_game.stashStowItem(lookThing:getPosition(), lookThing:getId(), 0,
                            lookThing:getStackPos(), 2)
                    end)

                    local isContainer = lookThing:isContainer()
                    if isContainer then
                        menu:addOption(tr('Stow container\'s content'), function()
                            g_game.stashStowItem(lookThing:getPosition(), lookThing:getId(), 0,
                                lookThing:getStackPos(), 1)
                        end)
                    end
                end
            end
        end
    end

    menu:display(menuPosition)
end

function processMouseAction(menuPosition, mouseButton, autoWalkPos, lookThing, useThing, creatureThing, attackCreature)
    local keyboardModifiers = g_keyboard.getModifiers()

    local smartLeftClick = modules.client_options.getOption('smartLeftClick')
    local classicControls = modules.client_options.getOption('classicControl')

    -- Classic controls: right-click on NPC says "hi"
    if creatureThing and creatureThing:isNpc() and mouseButton == MouseRightButton and 
    keyboardModifiers == KeyboardNoModifier then
        -- In classic controls, always allow NPC interaction
        -- In non-classic controls, check the talkOnRightClick option
        if classicControls or modules.client_options.getOption('talkOnRightClick') then
            local player = g_game.getLocalPlayer()
            if player then
                local playerPos = player:getPosition()
                local npcPos = creatureThing:getPosition()
                if playerPos.z == npcPos.z then
                    local dist = math.max(math.abs(playerPos.x - npcPos.x), math.abs(playerPos.y - npcPos.y))
                    if dist <= 3 then
                        g_game.talk("hi")
                        return true
                    end
                end
            end
        end
    end

    if g_platform.isMobile() then
        if mouseButton == MouseRightButton then
            createThingMenu(menuPosition, lookThing, useThing, creatureThing)
            return true
        end
        local shortcut = modules.game_shortcuts.getShortcut()
        if shortcut == "look" then
            if lookThing then
                modules.game_shortcuts.resetShortcuts()
                g_game.look(lookThing)
                return true
            end
            return true
        elseif shortcut == "use" then
            if useThing then
                modules.game_shortcuts.resetShortcuts()
                if useThing:isContainer() then
                    if useThing:getParentContainer() then
                        g_game.open(useThing, useThing:getParentContainer())
                    else
                        g_game.open(useThing)
                    end
                    return true
                elseif useThing:isMultiUse() then
                    startUseWith(useThing)
                    return true
                else
                    g_game.use(useThing)
                    return true
                end
            end
            return true
        elseif shortcut == "attack" then
            if attackCreature and attackCreature ~= player then
                modules.game_shortcuts.resetShortcuts()
                g_game.attack(attackCreature)
                return true
            elseif creatureThing and creatureThing ~= player and autoWalkPos and creatureThing:getPosition().z == autoWalkPos.z then
                modules.game_shortcuts.resetShortcuts()
                g_game.attack(creatureThing)
                return true
            end
            return true
        elseif shortcut == "follow" then
            if attackCreature and attackCreature ~= player then
                modules.game_shortcuts.resetShortcuts()
                g_game.follow(attackCreature)
                return true
            elseif creatureThing and creatureThing ~= player and autoWalkPos and creatureThing:getPosition().z == autoWalkPos.z then
                modules.game_shortcuts.resetShortcuts()
                g_game.follow(creatureThing)
                return true
            end
            return true
        elseif not autoWalkPos and useThing then
            createThingMenu(menuPosition, lookThing, useThing, creatureThing)
            return true
        end
    elseif not modules.client_options.getOption('classicControl') then
        local smartLeftClick = modules.client_options.getOption('smartLeftClick')

        if smartLeftClick and mouseButton == MouseLeftButton and keyboardModifiers == KeyboardNoModifier then
            local player = g_game.getLocalPlayer()

            -- Handle NPCs first - they should not be attacked
            if creatureThing and creatureThing:isNpc() then
                local playerPos = player:getPosition()
                local npcPos = creatureThing:getPosition()
                if playerPos.z == npcPos.z then
                    local dist = math.max(math.abs(playerPos.x - npcPos.x), math.abs(playerPos.y - npcPos.y))
                    if dist <= 3 then
                        g_game.talk("hi")
                        return true
                    end
                end
            end

            -- Handle creature attacks (but not NPCs)
            if attackCreature and attackCreature ~= player and not attackCreature:isNpc() then
                g_game.attack(attackCreature)
                return true
            elseif creatureThing and creatureThing ~= player and not creatureThing:isNpc() and autoWalkPos and creatureThing:getPosition().z == autoWalkPos.z then
                g_game.attack(creatureThing)
                return true
            elseif useThing then
                -- Handle interactive items first, without looking at them
                if useThing:isUsable() then
                    -- Only use the item, don't look at it
                    if useThing:isContainer() then
                        if useThing:getParentContainer() then
                            g_game.open(useThing, useThing:getParentContainer())
                        else
                            g_game.open(useThing)
                        end
                        return true
                    elseif useThing:isMultiUse() then
                        startUseWith(useThing)
                        return true
                    else
                        g_game.use(useThing)
                        return true
                    end
                end

                -- Standard handling for other usable items
                -- For containers (including corpses), only execute quicklooting with Smart Left-Click
                -- Exception: If container has a parent container, open it instead of quicklooting
                if useThing:isContainer() or useThing:isLyingCorpse() then
                    -- Prioritize containers/corpses even if there are creatures on the same tile
                    if useThing:getParentContainer() then
                        -- For containers inside other containers, we want to open them, not quickloot
                        g_game.open(useThing, useThing:getParentContainer())
                        return true
                    elseif useThing:isPickupable() then
                        -- For pickupable containers like quivers, backpacks, etc., open them instead of quicklooting
                        g_game.open(useThing)
                        return true
                    elseif g_game.getFeature(GameThingQuickLoot) and modules.game_quickloot then
                        -- For containers in the world (not inside another container), quickloot
                        quickLootCorpse(useThing)
                        return true
                    end
                elseif useThing:isMultiUse() then
                    startUseWith(useThing)
                    return true
                else
                    local useResult = g_game.use(useThing)

                    if useResult ~= nil then
                        return true
                    end
                end

                -- If we couldn't use the item through any of the above methods,
                -- but it's pickupable, try to pick it up (like in Classic Control mode)
                if useThing:isPickupable() then
                    g_game.move(useThing, useThing:getPosition(), 1)
                    return true
                end

                -- If we couldn't use or pick up the item, try to walk to its position if possible
                local position = useThing:getPosition()
                if position and position.x ~= 0 and autoWalkPos then
                    local player = g_game.getLocalPlayer()
                    player:autoWalk(autoWalkPos)
                    return true
                end

                return true
            end

            -- Only look at things if no usable item was found
            if lookThing and lookThing ~= useThing then
                local lookPosition = lookThing:getPosition()
                local lookTile = nil

                if lookPosition and lookPosition.x ~= 0 then
                    lookTile = g_map.getTile(lookPosition)
                end

                -- For walkable tiles, we want to walk
                if lookTile and lookTile:isWalkable() and autoWalkPos then
                    local player = g_game.getLocalPlayer()
                    player:autoWalk(autoWalkPos)
                    return true
                else
                    -- Only look at the thing if we haven't used it already
                    g_game.look(lookThing)
                    return true
                end
            end

            if autoWalkPos then
                local player = g_game.getLocalPlayer()
                player:autoWalk(autoWalkPos)
                return true
            end
        end

        if keyboardModifiers == KeyboardNoModifier and mouseButton == MouseRightButton then
            createThingMenu(menuPosition, lookThing, useThing, creatureThing)
            return true
        elseif lookThing and keyboardModifiers == KeyboardShiftModifier and
            (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
            g_game.look(lookThing)
            return true
        elseif useThing and g_keyboard.isPrimaryModifierOnly(keyboardModifiers) and
            (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
            local smartLeftClick = modules.client_options.getOption('smartLeftClick')

            if smartLeftClick then
                local player = g_game.getLocalPlayer()
                -- For containers in the world, Ctrl+Left Click opens them even if there's a creature
                if (useThing:isContainer() or useThing:isLyingCorpse()) and not useThing:getParentContainer() then
                    g_game.open(useThing)
                    return true
                else
                    createThingMenu(menuPosition, lookThing, useThing, creatureThing)
                    return true
                end
            else
                if useThing:isContainer() then
                    if useThing:getParentContainer() then
                        g_game.open(useThing, useThing:getParentContainer())
                    else
                        g_game.open(useThing)
                    end
                    return true
                elseif useThing:isMultiUse() then
                    startUseWith(useThing)
                    return true
                else
                    g_game.use(useThing)
                    return true
                end
            end
            return true
        elseif useThing and useThing:isContainer() and g_keyboard.isPrimaryShiftModifierOnly(keyboardModifiers) and
            (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
            g_game.open(useThing)
            return true
        elseif attackCreature and not attackCreature:isNpc() and g_keyboard.isAltPressed() and
            (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
            g_game.attack(attackCreature)
            return true
        elseif creatureThing and not creatureThing:isNpc() and autoWalkPos and creatureThing:getPosition().z == autoWalkPos.z and g_keyboard.isAltPressed() and
            (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
            g_game.attack(creatureThing)
            return true
        end

        -- classic control
    else
        local lootControlMode = modules.client_options.getOption('lootControlMode')
        local player = g_game.getLocalPlayer()

        -- ###############################
        -- ### MODE 0: LOOT RIGHT CLICK ##
        -- ###############################
        if lootControlMode == 0 then
            -- Right click with no modifiers: main loot functionality
            if mouseButton == MouseRightButton and keyboardModifiers == KeyboardNoModifier then
                -- Handle NPCs first - they should not be attacked
                if creatureThing and creatureThing:isNpc() then
                    local playerPos = player:getPosition()
                    local npcPos = creatureThing:getPosition()
                    if playerPos.z == npcPos.z then
                        local dist = math.max(math.abs(playerPos.x - npcPos.x), math.abs(playerPos.y - npcPos.y))
                        if dist <= 3 then
                            g_game.talk("hi")
                            return true
                        end
                    end
                end
                
                -- Handle creature attacks (match Smart Left-Click behavior)
                if attackCreature and attackCreature ~= player then
                    g_game.attack(attackCreature)
                    return true
                elseif creatureThing and creatureThing ~= player and autoWalkPos and creatureThing:getPosition().z == autoWalkPos.z then
                    g_game.attack(creatureThing)
                    return true
                elseif useThing then
                    -- For containers/corpses
                    if useThing:isContainer() or useThing:isLyingCorpse() then
                        -- For containers inside other containers, we want to open them
                        if useThing:getParentContainer() then
                            g_game.open(useThing, useThing:getParentContainer())
                            return true
                        elseif useThing:isPickupable() then
                            -- For pickupable containers like quivers, backpacks, etc., open them instead of quicklooting
                            g_game.open(useThing)
                            return true
                        elseif table.find({ 3497, 3498, 3499, 3500, 3502, 12902 }, useThing:getId()) then
                            -- For depot chests, lockers, depot boxes, inbox, etc., always open them
                            g_game.open(useThing)
                            return true
                        elseif g_game.getFeature(GameThingQuickLoot) and modules.game_quickloot then
                            -- For containers in the world, quickloot
                            quickLootCorpse(useThing)
                            return true
                        else
                            g_game.open(useThing)
                            return true
                        end
                    elseif useThing:isMultiUse() then
                        startUseWith(useThing)
                        return true
                    else
                        g_game.use(useThing)
                        return true
                    end
                end

                -- Handle pickupable items if no container/corpse was handled
                if lookThing and not lookThing:isCreature() and lookThing:isPickupable() then
                    g_game.move(lookThing, lookThing:getPosition(), 1)
                    return true
                end
            end

            -- SHIFT+Right click: opens containers without quicklooting
            if mouseButton == MouseRightButton and keyboardModifiers == KeyboardShiftModifier then
                if useThing then
                    if useThing:isContainer() or useThing:isLyingCorpse() then
                        if useThing:getParentContainer() then
                            g_game.open(useThing, useThing:getParentContainer())
                        else
                            g_game.open(useThing)
                        end
                        return true
                    elseif useThing:isMultiUse() then
                        startUseWith(useThing)
                        return true
                    else
                        g_game.use(useThing)
                        return true
                    end
                end
            end

            -- #################################
            -- ### MODE 1: LOOT SHIFT+RIGHT  ###
            -- #################################
        elseif lootControlMode == 1 then
            -- Right click with no modifiers: use or open containers
            if mouseButton == MouseRightButton and keyboardModifiers == KeyboardNoModifier then
                -- Handle NPCs first - they should not be attacked
                if creatureThing and creatureThing:isNpc() then
                    local playerPos = player:getPosition()
                    local npcPos = creatureThing:getPosition()
                    if playerPos.z == npcPos.z then
                        local dist = math.max(math.abs(playerPos.x - npcPos.x), math.abs(playerPos.y - npcPos.y))
                        if dist <= 3 then
                            g_game.talk("hi")
                            return true
                        end
                    end
                end
                
                -- Handle creature attacks
                if attackCreature and attackCreature ~= player then
                    g_game.attack(attackCreature)
                    return true
                elseif creatureThing and creatureThing ~= player and autoWalkPos and creatureThing:getPosition().z == autoWalkPos.z then
                    g_game.attack(creatureThing)
                    return true
                elseif useThing then
                    -- For containers
                    if useThing:isContainer() or useThing:isLyingCorpse() then
                        if useThing:getParentContainer() then
                            g_game.open(useThing, useThing:getParentContainer())
                        else
                            g_game.open(useThing)
                        end
                        return true
                    elseif useThing:isMultiUse() then
                        startUseWith(useThing)
                        return true
                    else
                        g_game.use(useThing)
                        return true
                    end
                end
            end

            -- SHIFT+Right click: quickloot on containers
            if mouseButton == MouseRightButton and keyboardModifiers == KeyboardShiftModifier then
                if useThing and (useThing:isContainer() or useThing:isLyingCorpse()) then
                    if g_game.getFeature(GameThingQuickLoot) and modules.game_quickloot then
                        quickLootCorpse(useThing)
                        return true
                    end
                end

                -- Handle pickupable items
                if lookThing and not lookThing:isCreature() and lookThing:isPickupable() then
                    g_game.move(lookThing, lookThing:getPosition(), 1)
                    return true
                end
            end

            -- #############################
            -- ### MODE 2: LOOT LEFT     ###
            -- #############################
        elseif lootControlMode == 2 then
            -- Left click with no modifiers: ONLY for loot functionality
            if mouseButton == MouseLeftButton and keyboardModifiers == KeyboardNoModifier then
                -- ONLY for quicklooting and picking up items, NOT for attacking
                if useThing then
                    -- ONLY quickloot containers/corpses in the game world
                    if (useThing:isContainer() or useThing:isLyingCorpse()) and not useThing:getParentContainer() then
                        -- Only handle containers that are in the game world (not in inventory)
                        if table.find({ 3497, 3498, 3499, 3500, 3502, 12902 }, useThing:getId()) then
                            -- For depot chests, lockers, depot boxes, inbox, etc., always open them
                            g_game.open(useThing)
                            return true
                        elseif g_game.getFeature(GameThingQuickLoot) and modules.game_quickloot then
                            quickLootCorpse(useThing)
                            return true
                        else
                            g_game.open(useThing)
                            return true
                        end
                    end
                end

                -- Handle pickupable items in the game world
                if lookThing and not lookThing:isCreature() and lookThing:isPickupable() then
                    g_game.move(lookThing, lookThing:getPosition(), 1)
                    return true
                end
            end

            -- Right click for Loot: Left mode - use items instead of showing context menu
            if mouseButton == MouseRightButton and keyboardModifiers == KeyboardNoModifier then
                -- Handle NPCs first - they should not be attacked
                if creatureThing and creatureThing:isNpc() then
                    local playerPos = player:getPosition()
                    local npcPos = creatureThing:getPosition()
                    if playerPos.z == npcPos.z then
                        local dist = math.max(math.abs(playerPos.x - npcPos.x), math.abs(playerPos.y - npcPos.y))
                        if dist <= 3 then
                            g_game.talk("hi")
                            return true
                        end
                    end
                end
                
                -- Handle creature attacks
                if attackCreature and attackCreature ~= player then
                    g_game.attack(attackCreature)
                    return true
                elseif creatureThing and creatureThing ~= player and autoWalkPos and creatureThing:getPosition().z == autoWalkPos.z then
                    g_game.attack(creatureThing)
                    return true
                    -- Use the item if it's a container in inventory or use other items
                elseif useThing then
                    if useThing:isContainer() or useThing:isLyingCorpse() then
                        if useThing:getParentContainer() then
                            g_game.open(useThing, useThing:getParentContainer())
                            return true
                        else
                            g_game.open(useThing)
                            return true
                        end
                    elseif useThing:isMultiUse() then
                        startUseWith(useThing)
                        return true
                    else
                        g_game.use(useThing)
                        return true
                    end
                end

                -- Only show context menu when no usable item is present
                if not useThing then
                    createThingMenu(menuPosition, lookThing, useThing, creatureThing)
                    return true
                end
            end
        end

        -- Common key combinations for all Classic Control modes
        if useThing and useThing:isContainer() and g_keyboard.isPrimaryShiftModifierOnly(keyboardModifiers) and
            (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
            g_game.open(useThing)
            return true
        elseif lookThing and keyboardModifiers == KeyboardShiftModifier and
            (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
            g_game.look(lookThing)
            return true
        elseif lookThing and ((g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton) or
                (g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton)) then
            g_game.look(lookThing)
            return true
        elseif useThing and g_keyboard.isPrimaryModifierOnly(keyboardModifiers) and
            (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
            createThingMenu(menuPosition, lookThing, useThing, creatureThing)
            return true
        elseif attackCreature and not attackCreature:isNpc() and g_keyboard.isAltPressed() and
            (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
            g_game.attack(attackCreature)
            return true
        elseif creatureThing and not creatureThing:isNpc() and autoWalkPos and creatureThing:getPosition().z == autoWalkPos.z and g_keyboard.isAltPressed() and
            (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
            g_game.attack(creatureThing)
            return true
        end
    end

    local player = g_game.getLocalPlayer()
    player:stopAutoWalk()

    if autoWalkPos and keyboardModifiers == KeyboardNoModifier and mouseButton == MouseLeftButton then
        -- In Classic Control with Loot: Left option, we want to avoid walking when trying to loot
        local classicControl = modules.client_options.getOption('classicControl')
        local lootControlMode = modules.client_options.getOption('lootControlMode')

        if classicControl and lootControlMode == 2 then
            -- Check if there's a corpse or item we should be looting instead of walking
            -- If not, proceed with autowalk
            local isCorpseOrContainer = useThing and (useThing:isContainer() or useThing:isLyingCorpse())

            if not isCorpseOrContainer and
                not (lookThing and not lookThing:isCreature() and lookThing:isPickupable()) then
                player:autoWalk(autoWalkPos)
                if g_game.isAttacking() and g_game.getChaseMode() == ChaseOpponent then
                    g_game.setChaseMode(DontChase)
                end
            end
        else
            player:autoWalk(autoWalkPos)
            if g_game.isAttacking() and g_game.getChaseMode() == ChaseOpponent then
                g_game.setChaseMode(DontChase)
            end
        end
        return true
    end

    return false
end

local function handleItemInteraction(item, widget, callback)
    local count = item:getCount()
    widget.hotkeyBlock = modules.game_hotkeys.createHotkeyBlock("stackable_item_dialog")
    local itembox = widget:getChildById('item')
    local scrollbar = widget:getChildById('countScrollBar')
    itembox:setItemId(item:getId())
    itembox:setItemCount(count)
    scrollbar:setMaximum(count)
    scrollbar:setMinimum(1)
    scrollbar:setValue(count)

    local spinbox = widget:getChildById('spinBox')
    spinbox:setMaximum(count)
    spinbox:setMinimum(0)
    spinbox:setValue(0)
    spinbox:hideButtons()
    spinbox:focus()
    spinbox.firstEdit = true

    local spinBoxValueChange = function(self, value)
        spinbox.firstEdit = false
        scrollbar:setValue(value)
    end
    spinbox.onValueChange = spinBoxValueChange

    local check = function()
        if spinbox.firstEdit then
            spinbox:setValue(spinbox:getMaximum())
            spinbox.firstEdit = false
        end
    end
    g_keyboard.bindKeyPress('Up', function()
        check()
        spinbox:upSpin()
    end, spinbox)
    g_keyboard.bindKeyPress('Down', function()
        check()
        spinbox:downSpin()
    end, spinbox)
    g_keyboard.bindKeyPress('Right', function()
        check()
        spinbox:upSpin()
    end, spinbox)
    g_keyboard.bindKeyPress('Left', function()
        check()
        spinbox:downSpin()
    end, spinbox)
    g_keyboard.bindKeyPress('PageUp', function()
        check()
        spinbox:setValue(spinbox:getValue() + 10)
    end, spinbox)
    g_keyboard.bindKeyPress('PageDown', function()
        check()
        spinbox:setValue(spinbox:getValue() - 10)
    end, spinbox)

    scrollbar.onValueChange = function(self, value)
        itembox:setItemCount(value)
        spinbox.onValueChange = nil
        spinbox:setValue(value)
        spinbox.onValueChange = spinBoxValueChange
    end

    local okButton = widget:getChildById('buttonOk')
    local moveFunc = function()
        callback(itembox:getItemCount())
        okButton:getParent():destroy()
        widget = nil
    end
    local cancelButton = widget:getChildById('buttonCancel')
    local cancelFunc = function()
        cancelButton:getParent():destroy()
        countWindow = nil
        widget = nil
    end

    widget.onEnter = moveFunc
    widget.onEscape = cancelFunc

    okButton.onClick = moveFunc
    cancelButton.onClick = cancelFunc
end

function stashItem(item)
    local count = item:getCount()
    if count == 1 then
        g_game.stashStowItem(item:getPosition(), item:getId(), count,
            item:getStackPos(), 0)
        return
    end
    if countWindow then
        if countWindow:isDestroyed() then
            countWindow = nil
        else
            return
        end
    end
    countWindow = g_ui.createWidget('CountStashWindow', rootWidget)

    handleItemInteraction(item, countWindow, function(amount)
        g_game.stashStowItem(item:getPosition(), item:getId(), amount,
            item:getStackPos(), 0)
        countWindow = nil
    end)
end

function moveStackableItem(item, toPos)
    if countWindow then
        if countWindow:isDestroyed() then
            countWindow = nil
        else
            return
        end
    end
    if g_keyboard.isShiftPressed() then
        g_game.move(item, toPos, 1)
        return
    elseif g_keyboard.isCtrlPressed() ~= modules.client_options.getOption('moveStack') then
        g_game.move(item, toPos, item:getCount())
        return
    end

    countWindow = g_ui.createWidget('CountWindow', rootWidget)
    handleItemInteraction(item, countWindow, function(count)
        g_game.move(item, toPos, count)
        countWindow = nil
    end)
end

function onSelectPanel(self, checked)
    if checked then
        for k, v in pairs(panelsList) do
            if v.checkbox == self then
                gameSelectedPanel = v.panel
                break
            end
        end
    end
end

function getRootPanel()
    return gameRootPanel
end

function getMapPanel()
    return gameMapPanel
end

function getRightPanel()
    return gameRightPanel
end

function getMainRightPanel()
    return gameMainRightPanel
end

function getMainLeftPanel()
    return gameMainLeftPanel
end

function getMainRightTopPanel()
    return gameMainRightTopPanel
end

function getLeftPanel()
    return gameLeftPanel
end

function getRightExtraPanel()
    return gameRightExtraPanel
end

function getRightExtraPanel2()
    return gameRightExtraPanel2
end

function getRightExtraPanel3()
    return gameRightExtraPanel3
end

function getLeftExtraPanel()
    return gameLeftExtraPanel
end

function getLeftExtraPanel2()
    return gameLeftExtraPanel2
end

function getLeftExtraPanel3()
    return gameLeftExtraPanel3
end

function getSelectedPanel()
    return gameSelectedPanel
end

function getBottomPanel()
    return gameBottomPanel
end

function getShowTopMenuButton()
    return showTopMenuButton
end

function getGameTopStatsBar()
    return gameTopPanel
end

function getGameBottomStatsBar()
    return gameBottomStatsBarPanel
end

function getGameMapPanel()
    return gameMapPanel
end

function getBottomActionPanel()
    return gameBottomActionPanel
end

function getLeftActionPanel()
    return gameLeftActionPanel
end

function getRightActionPanel()
    return gameRightActionPanel
end

function getBottomLockPanel()
    return gameBottomLockPanel
end

function getRightLockPanel()
    return gameRightLockPanel
end

function getLeftLockPanel()
    return gameLeftLockPanel
end

function getBottomSplitter()
    return bottomSplitter
end

function getHorizontalPanelLeftHeight()
    return horizontalPanelLeftHeight or 200
end

function setHorizontalPanelLeftHeight(h)
    horizontalPanelLeftHeight = math.max(TOP_PANEL_MIN_HEIGHT, math.floor(h))
end

function getHorizontalPanelRightHeight()
    return horizontalPanelRightHeight or 200
end

function setHorizontalPanelRightHeight(h)
    horizontalPanelRightHeight = math.max(TOP_PANEL_MIN_HEIGHT, math.floor(h))
end

-- The top panels drop windows that no longer fit when one of them opens or resizes, so a panel is
-- never made shorter than what it holds. Below it there must stay room for the column (and, on the
-- right, for the inventory panel).
function topPanelContentHeight(panel)
    local height = panel:getPaddingTop() + panel:getPaddingBottom()
    local visible = {}
    for _, child in ipairs(panel:getChildren()) do
        if child:isVisible() then
            table.insert(visible, child)
        end
    end
    for index, child in ipairs(visible) do
        local isLast = index == #visible
        if child.followsPanelHeight and child.getMinimumHeight then
            -- sized by the panel (the minimap), so it never stops the panel from shrinking
            height = height + child:getMinimumHeight()
        elseif isLast and child.isResizeable and child:isResizeable() and child.getMinimumHeight then
            height = height + child:getMinimumHeight()
        else
            height = height + child:getHeight()
        end
    end
    return height
end

function topPanelHeightLimits(panel, isRight)
    local minimum = math.max(TOP_PANEL_MIN_HEIGHT, topPanelContentHeight(panel))
    local below = TOP_PANEL_ROOM_BELOW
    if isRight and gameMainRightPanel and gameMainRightPanel:isVisible() then
        below = below + gameMainRightPanel:getHeight()
    end
    local maximum = gameRootPanel:getHeight() - (panel:getY() - gameRootPanel:getY()) - below
    return minimum, math.max(minimum, maximum)
end

function setupTopPanelResize(border, panel, isRight)
    if not border or not panel then
        return
    end
    border.onMouseMove = function(self, mousePos)
        if not self:isPressed() then
            return false
        end
        if not panel:isOn() then
            return true
        end
        local minimum, maximum = topPanelHeightLimits(panel, isRight)
        local height = math.min(math.max(mousePos.y - panel:getY(), minimum), maximum)
        panel:setHeight(height)
        if isRight then
            setHorizontalPanelRightHeight(height)
            g_settings.set('horizontalPanelRightHeight', horizontalPanelRightHeight)
        else
            setHorizontalPanelLeftHeight(height)
            g_settings.set('horizontalPanelLeftHeight', horizontalPanelLeftHeight)
        end
        return true
    end
    local function refresh()
        border:setVisible(panel:isOn() and panel:getHeight() > 0)
    end
    connect(panel, { onGeometryChange = refresh, onStyleApply = refresh })
    refresh()
end

function findContentPanelAvailable(child, minContentHeight)
    if gameSelectedPanel and gameSelectedPanel:isVisible() and gameSelectedPanel:fits(child, minContentHeight, 0) >= 0 then
        return gameSelectedPanel
    end

    if gameMainRightTopPanel and gameMainRightTopPanel:isVisible() and gameMainRightTopPanel:fits(child, minContentHeight, 0) >= 0 then
        return gameMainRightTopPanel
    end

    if gameMainLeftPanel and gameMainLeftPanel:isVisible() and gameMainLeftPanel:fits(child, minContentHeight, 0) >= 0 then
        return gameMainLeftPanel
    end

    for k, v in pairs(panelsList) do
        if v.panel ~= gameSelectedPanel and v.panel:isVisible() and v.panel:fits(child, minContentHeight, 0) >= 0 then
            return v.panel
        end
    end

    return gameSelectedPanel
end

function nextViewMode()
    setupViewMode((currentViewMode + 1) % 3)
end

function setupViewMode(mode)
    if mode == currentViewMode then
        return
    end

    updateSidePanelButtons()

    if currentViewMode == 2 then
        gameMapPanel:addAnchor(AnchorLeft, 'gameLeftActionPanel', AnchorRight)
        gameMapPanel:addAnchor(AnchorRight, 'gameRightActionPanel', AnchorLeft)
        gameMapPanel:setOn(false)
        gameMapPanel:addAnchor(AnchorBottom, 'bottomSplitter', AnchorTop)
        gameMapPanel:addAnchor(AnchorTop, 'gameTopPanel', AnchorBottom)
        gameRootPanel:addAnchor(AnchorTop, 'parent', AnchorTop)
        updateLeftColumnsLayout()
        updateRightColumnsLayout()
        gameLeftPanel:setImageColor('white')
        gameRightPanel:setImageColor('white')
        gameRightExtraPanel:setImageColor('white')
        if gameRightExtraPanel2 then gameRightExtraPanel2:setImageColor('white') end
        if gameRightExtraPanel3 then gameRightExtraPanel3:setImageColor('white') end
        gameLeftExtraPanel:setImageColor('white')
        if gameLeftExtraPanel2 then gameLeftExtraPanel2:setImageColor('white') end
        if gameLeftExtraPanel3 then gameLeftExtraPanel3:setImageColor('white') end
        gameLeftPanel:setMarginTop(0)
        gameRightPanel:setMarginTop(1)
        gameRightExtraPanel:setMarginTop(0)
        if gameRightExtraPanel2 then gameRightExtraPanel2:setMarginTop(0) end
        if gameRightExtraPanel3 then gameRightExtraPanel3:setMarginTop(0) end
        gameLeftExtraPanel:setMarginTop(0)
        if gameLeftExtraPanel2 then gameLeftExtraPanel2:setMarginTop(0) end
        if gameLeftExtraPanel3 then gameLeftExtraPanel3:setMarginTop(0) end
        gameBottomPanel:setImageColor('white')
    end

    if mode == 0 then
        gameMapPanel:setKeepAspectRatio(true)
        gameMapPanel:setLimitVisibleRange(false)
        gameMapPanel:setZoom(11)
        gameMapPanel:setVisibleDimension({
            width = 15,
            height = 11
        })
    elseif mode == 1 then
        gameMapPanel:setKeepAspectRatio(false)
        gameMapPanel:setLimitVisibleRange(true)
        gameMapPanel:setZoom(11)
        gameMapPanel:setVisibleDimension({
            width = 15,
            height = 11
        })
    elseif mode == 2 then
        local limit = limitedZoom and not g_game.isGM()
        gameMapPanel:setLimitVisibleRange(limit)
        gameMapPanel:setZoom(11)
        gameMapPanel:setVisibleDimension({
            width = 15,
            height = 11
        })
        gameMapPanel:fill('parent')
        gameRootPanel:fill('parent')
        gameLeftPanel:setImageColor('alpha')
        gameRightPanel:setImageColor('alpha')
        gameRightExtraPanel:setImageColor('alpha')
        if gameRightExtraPanel2 then gameRightExtraPanel2:setImageColor('alpha') end
        if gameRightExtraPanel3 then gameRightExtraPanel3:setImageColor('alpha') end
        gameLeftExtraPanel:setImageColor('alpha')
        if gameLeftExtraPanel2 then gameLeftExtraPanel2:setImageColor('alpha') end
        if gameLeftExtraPanel3 then gameLeftExtraPanel3:setImageColor('alpha') end
        gameLeftPanel:setOn(true)
        gameLeftPanel:setVisible(true)
        gameRightPanel:setOn(true)
        gameRightExtraPanel:setOn(false)
        gameRightExtraPanel:setVisible(false)
        if gameRightExtraPanel2 then
            gameRightExtraPanel2:setOn(false)
            gameRightExtraPanel2:setVisible(false)
        end
        if gameRightExtraPanel3 then
            gameRightExtraPanel3:setOn(false)
            gameRightExtraPanel3:setVisible(false)
        end
        gameLeftExtraPanel:setOn(false)
        gameLeftExtraPanel:setVisible(false)
        if gameLeftExtraPanel2 then
            gameLeftExtraPanel2:setOn(false)
            gameLeftExtraPanel2:setVisible(false)
        end
        if gameLeftExtraPanel3 then
            gameLeftExtraPanel3:setOn(false)
            gameLeftExtraPanel3:setVisible(false)
        end
        gameMapPanel:setOn(true)
        gameBottomPanel:setImageColor('#ffffff88')
    end

    applyMobileMargins()
    currentViewMode = mode
    applyExtendedViewLayout(mode == 2)
end

function limitZoom()
    limitedZoom = true
end

function updateStatsBar(dimension, placement)
    StatsBar.updateCurrentStats(dimension, placement)
    StatsBar.updateStatsBarOption()
end

local function movePanel(mainpanel)
    if not mainpanel then return end
    for _, widget in pairs(mainpanel:getChildren()) do
        if widget then
            local panel = modules.game_interface.findContentPanelAvailable(widget, widget:getMinimumHeight())
            if panel then
                if not panel:hasChild(widget) then
                    widget:close()
                    panel:addChild(widget)
                else
                    print("Error: Attempt to add a widget that already exists in the target panel")
                end
            else
                print("Warning: No suitable panel found for widget, unable to move")
            end
        end
    end
end

function movePanelToAvailable(mainpanel)
    movePanel(mainpanel)
end

function onIncreaseLeftPanels()
    local maxCols = getMaxLeftColumns()
    if leftColumnsCount < maxCols then
        setLeftColumnsCount(leftColumnsCount + 1)
    end
end

function onDecreaseLeftPanels()
    if leftColumnsCount > 0 then
        local panelToMove = nil
        if leftColumnsCount == 4 then
            panelToMove = gameLeftExtraPanel3
        elseif leftColumnsCount == 3 then
            panelToMove = gameLeftExtraPanel2
        elseif leftColumnsCount == 2 then
            panelToMove = gameLeftExtraPanel
        elseif leftColumnsCount == 1 then
            panelToMove = gameLeftPanel
        end
        if panelToMove then
            movePanel(panelToMove)
        end
        setLeftColumnsCount(leftColumnsCount - 1)
    end
end

function onIncreaseRightPanels()
    local maxCols = getMaxRightColumns()
    if rightColumnsCount < maxCols then
        setRightColumnsCount(rightColumnsCount + 1)
    end
end

function onDecreaseRightPanels()
    if rightColumnsCount > 1 then
        local panelToMove = nil
        if rightColumnsCount == 4 then
            panelToMove = gameRightExtraPanel3
        elseif rightColumnsCount == 3 then
            panelToMove = gameRightExtraPanel2
        elseif rightColumnsCount == 2 then
            panelToMove = gameRightExtraPanel
        end
        if panelToMove then
            movePanel(panelToMove)
        end
        setRightColumnsCount(rightColumnsCount - 1)
    end
end

function setupOptionsMainButton()
    if logOutMainButton then
        return
    end

    logOutMainButton = modules.game_mainpanel.addSpecialToggleButton('logoutButton', tr('Exit'),
        '/images/options/button_logout',
        tryLogout)
end

function checkAndOpenLeftPanel()
    if leftColumnsCount == 0 then
        updateLeftColumnsLayout(1)
    end
end

function applyExtendedViewLayout(extendedView)
    if extendedView == isExtendedViewActive then return end
    isExtendedViewActive = extendedView
    gameRootPanel:getChildById('gameLowerPanelBackground'):setVisible(not extendedView)
    MapLayout.hide()

    local buttons = { leftIncreaseSidePanels, rightIncreaseSidePanels,
        rightDecreaseSidePanels, leftDecreaseSidePanels }

    if extendedView then
        for _, btn in ipairs(buttons) do
            btn:hide()
        end

        if not g_platform.isMobile() then
            gameBottomPanel:breakAnchors()
            gameBottomPanel:setWidth(1020)
            gameBottomPanel:setHeight(200)
            gameBottomPanel:setDraggable(true)
            gameBottomPanel:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
            gameBottomPanel:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
            gameBottomPanel:getChildById('bottomResizeBorder'):setMarginTop(2)
        else
            gameBottomPanel:setWidth(g_window.getWidth() - mobileConfig.mobileWidthJoystick -
                mobileConfig.mobileWidthShortcuts)
            gameBottomPanel:setPosition({
                x = mobileConfig.mobileWidthJoystick,
                y = gameBottomPanel:getY()
            })
        end
        gameBottomPanel:getChildById('bottomResizeBorder'):setMaximum(gameBottomPanel:getHeight())
        gameBottomPanel:getChildById('rightResizeBorder'):setMaximum(gameBottomPanel:getWidth())
        gameBottomPanel:getChildById('bottomResizeBorder'):enable()
        gameBottomPanel:getChildById('rightResizeBorder'):enable()
        gameMainRightPanel:setHeight(0)
        gameMainRightPanel:setImageColor('alpha')
        if gameMainRightTopPanel then
            gameMainRightTopPanel:setImageColor('alpha')
        end
        gameBottomPanel:addAnchor(AnchorTop, 'gameBottomActionPanel', AnchorBottom)
        gameBottomPanel:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        gameLeftActionPanel:setImageSource(nil)
        gameRightActionPanel:setImageSource(nil)
        gameLeftActionPanel:setBorderWidthRight(0)
        gameRightActionPanel:setBorderWidthLeft(0)
    else
        -- Reset to normal view
        gameMainRightPanel:setHeight(200)
        gameMainRightPanel:setMarginTop(0)
        gameMainRightPanel:setImageColor('white')
        if gameMainRightTopPanel then
            local rightH = horizontalPanelRightHeight or 200
            gameMainRightTopPanel:setHeight(modules.client_options.getOption('showHorizontalPanelRight') == true and rightH or 0)
            gameMainRightTopPanel:setMarginTop(0)
            gameMainRightTopPanel:setImageColor('white')
            gameMainRightTopPanel:setOn(modules.client_options.getOption('showHorizontalPanelRight') == true)
        end
        if gameMainLeftPanel then
            gameMainLeftPanel:setHeight(modules.client_options.getOption('showHorizontalPanelLeft') == true and (horizontalPanelLeftHeight or 200) or 0)
            gameMainLeftPanel:setOn(modules.client_options.getOption('showHorizontalPanelLeft') == true)
        end
        updateHorizontalPanelsGeometry()
        gameLeftActionPanel:setImageSource('/images/ui/actionbar/actionbar_background-light')
        gameRightActionPanel:setImageSource('/images/ui/actionbar/actionbar_background-light')
        gameLeftActionPanel:setBorderWidthRight(1)
        gameRightActionPanel:setBorderWidthLeft(1)
        for _, btn in ipairs(buttons) do
            btn:setMarginTop(0)
            btn:show()
        end

        -- Reset bottom panel
        gameBottomPanel:setDraggable(false)

        -- Set anchors
        if not g_platform.isMobile() then
            gameBottomPanel:breakAnchors()
            gameBottomPanel:addAnchor(AnchorLeft, 'bottomSplitter', AnchorLeft)
            gameBottomPanel:addAnchor(AnchorRight, 'bottomSplitter', AnchorRight)
            gameBottomPanel:addAnchor(AnchorTop, 'gameBottomCooldownPanel', AnchorBottom)
            gameBottomPanel:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        end
        gameBottomPanel:getChildById('bottomResizeBorder'):disable()
        gameBottomPanel:getChildById('rightResizeBorder'):disable()

        -- Move children back to gameMainRightPanel
        local children = gameRightPanel:getChildren()
        for _, child in ipairs(children) do
            if child.moveOnlyToMain then
                child:setParent(gameMainRightPanel)
            end
        end
    end

    addEvent(function()
        modules.game_console.setExtendedView(extendedView)
        modules.game_minimap.extendedView(extendedView)
        modules.game_healthinfo.extendedView(extendedView)
        modules.game_inventory.extendedView(extendedView)
        modules.client_topmenu.extendedView(extendedView)
        modules.game_mainpanel.toggleExtendedViewButtons(extendedView)
    end)
end

function toggleInternalFocus()
    for reason, _ in pairs(focusReason) do
        if reason == 'bosscooldown' then
            modules.game_analyser.toggleBossCDFocus(false)
        end
    end
end

function isInternalLocked()
    if not focusReason or table.empty(focusReason) then
        return false
    end
    return true
end

function toggleFocus(value, reason)
    if not reason then
        reason = ''
    end
    if not value then
        getBottomPanel():focus()
        if not reason then
            reason = ''
        end

        focusReason[reason] = nil
    else
        focusReason[reason] = true
    end

    if not value and #focusReason ~= 0 then
        return
    end

    gameRightPanel:setFocusable(value)
    gameLeftPanel:setFocusable(value)
    gameRightExtraPanel:setFocusable(value)
    if gameRightExtraPanel2 then
        gameRightExtraPanel2:setFocusable(value)
    end
    if gameRightExtraPanel3 then
        gameRightExtraPanel3:setFocusable(value)
    end
    gameLeftExtraPanel:setFocusable(value)
    if gameLeftExtraPanel2 then
        gameLeftExtraPanel2:setFocusable(value)
    end
    if gameLeftExtraPanel3 then
        gameLeftExtraPanel3:setFocusable(value)
    end
end

function updateHorizontalPanelsGeometry()
    if not modules.client_options or not modules.client_options.getOption then
        return
    end

    if gameMainRightPanel then
        gameMainRightPanel:setWidth(176)
    end

    updateRightColumnsLayout()

    -- Handle horizontal panel visibility (separate from column layout)
    local showRightH = isHorizontalPanelActive('right')
    if gameMainRightTopPanel then
        local rightH = horizontalPanelRightHeight or 200
        gameMainRightTopPanel:setHeight(showRightH and rightH or 0)
        gameMainRightTopPanel:setOn(showRightH)
    end

    updateLeftColumnsLayout()

    -- Handle left horizontal panel visibility (separate from column layout)
    local showLeftH = isHorizontalPanelActive('left')
    if gameMainLeftPanel then
        gameMainLeftPanel:setHeight(showLeftH and (horizontalPanelLeftHeight or 200) or 0)
        gameMainLeftPanel:setOn(showLeftH)
    end
end

