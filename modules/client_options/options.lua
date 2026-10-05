local options = dofile("data_options")
local basicOptionKeys = {
    'mouseControlMode',
    'lootControlMode',
    'autoChaseOverride',
    'quickLootAllCorpsesInArea',
    'allActionBar13',
    'actionBarShowBottom1',
    'actionBarShowBottom2',
    'actionBarShowBottom3',
    'allActionBar46',
    'actionBarShowLeft1',
    'actionBarShowLeft2',
    'actionBarShowLeft3',
    'allActionBar79',
    'actionBarShowRight1',
    'actionBarShowRight2',
    'actionBarShowRight3',
    'framesRarity',
    'antialiasingMode',
    'fullscreen',
    'masterVolume'
}
local basicDefaultValues = {}
for _, key in ipairs(basicOptionKeys) do
    local option = options[key]
    if type(option) == 'table' then
        basicDefaultValues[key] = option.value
    else
        basicDefaultValues[key] = option
    end
end

local optionChanges
local optionChangeOrigin
panels = {
    generalPanel = nil,
    graphicsPanel = nil,
    soundPanel = nil,
    gameMapPanel = nil,
    graphicsEffectsPanel = nil,
    interfaceHUD = nil,
    interface = nil,
    misc = nil,
    miscHelp = nil,
    keybindsPanel = nil
}

-- Hook into application exit to ensure settings are saved
local function onAppExit()
    g_settings.save()
end

-- Register the exit hook when the module is loaded
connect(g_app, { onExit = onAppExit })

-- LuaFormatter off
local buttons = { {
    text = "Basic",
    icon = "/images/icons/icon_options",
    open = "basicPanel"
}, {

    text = "Controls",
    icon = "/images/icons/icon_controls",
    open = "generalPanel",
    subCategories = { {
        text = "General Hotkeys",
        open = "keybindsPanel",
        callbackFunc = function() showGeneralHotkeys() end
    }, {
        text = "Custom Hotkeys",
        open = "keybindsPanel",
        callbackFunc = function() showCustomHotkeys() end
    } }
}, {
    text = "Interface",
    icon = "/images/icons/icon_interface",
    open = "interface",
    subCategories = { {
        text = "HUD",
        open = "interfaceHUD"
    }, {
        text = "Console",
        open = "interfaceConsole"
    }, {
        text = "Action Bars",
        open = "actionbars"
    } }
}, {
    text = "Graphics",
    icon = "/images/icons/icon_graphics",
    open = "graphicsPanel",
    subCategories = { {
        text = "Effects",
        open = "graphicsEffectsPanel"
    } }
}, {
    text = "Sound",
    icon = "/images/icons/icon_sound",
    open = "soundPanel"
    --[[     subCategories = {{
        text = "Battle Sounds",
        open = "Battle_Sounds"
    }, {
        text = "UI Sounds",
        open = "UI_Sounds"
    }} ]]
}, {
    text = "Misc.",
    icon = "/images/icons/icon_misc",
    open = "misc",
    subCategories = { --[[ {
        text = "GamePlay",
        open = "GamePlay"
    },  {
        text = "Screenshots",
        open = "Screenshots"
    }, ]] {
        text = "Help",
        open = "miscHelp"
    } }
} }

-- LuaFormatter on
local extraWidgets = {
    audioButton = nil,
    optionsButton = nil,
    logoutButton = nil,
    optionsButtons = nil
}

local function toggleDisplays()
    if options['displayNames'].value and options['displayHealth'].value and options['displayMana'].value and options['displayHarmony'].value then
        setOption('displayNames', false)
    elseif options['displayHealth'].value then
        setOption('displayHealth', false)
        setOption('displayMana', false)
        setOption('displayHarmony', false)
    else
        if not options['displayNames'].value and not options['displayHealth'].value then
            setOption('displayNames', true)
        else
            setOption('displayHealth', true)
            setOption('displayMana', true)
            setOption('displayHarmony', true)
        end
    end
end

local function toggleOption(key)
    setOption(key, not getOption(key))
end

local function setupComboBox()
    local crosshairCombo = panels.interface:recursiveGetChildById('crosshair')
    local antialiasingModeCombobox = panels.graphicsPanel:recursiveGetChildById('antialiasingMode')
    local floorViewModeCombobox = panels.graphicsEffectsPanel:recursiveGetChildById('floorViewMode')
    local framesRarityCombobox = panels.interface:recursiveGetChildById('frames')
    local vocationPresetsCombobox = panels.keybindsPanel:recursiveGetChildById('list')
    local listKeybindsPanel = panels.keybindsPanel:recursiveGetChildById('list')
    local mouseControlModeCombobox = panels.generalPanel:recursiveGetChildById('mouseControlMode')
    local lootControlModeCombobox = panels.generalPanel:recursiveGetChildById('lootControlMode')

    for k, v in pairs({ { 'Disabled', 'disabled' }, { 'Default', 'default' }, { 'Full', 'full' }, { 'Animation', 'animation' } }) do
        crosshairCombo:addOption(v[1], v[2])
    end

    crosshairCombo.onOptionChange = function(comboBox, option)
        setOptionFromUI('crosshair', comboBox:getCurrentOption().data)
    end

    mouseControlModeCombobox:addOption('Regular Controls', 0)
    mouseControlModeCombobox:addOption('Classic Controls', 1)
    mouseControlModeCombobox:addOption('Left Smart-Click', 2)

    lootControlModeCombobox:addOption('Loot: Right', 0)
    lootControlModeCombobox:addOption('Loot: SHIFT+Right', 1)
    lootControlModeCombobox:addOption('Loot: Left', 2)
    
    lootControlModeCombobox.onOptionChange = function(comboBox, option)
        setOptionFromUI('lootControlMode', comboBox:getCurrentOption().data)
    end

    mouseControlModeCombobox.onOptionChange = function(comboBox, option)
        local selectedOption = comboBox:getCurrentOption().data
        setOptionFromUI('mouseControlMode', selectedOption)
        
        -- The mouseControlMode action handler will take care of updating
        -- classicControl and smartLeftClick, and their UI visibility
    end

    for k, t in pairs({ 'None', 'Antialiasing', 'Smooth Retro' }) do
        antialiasingModeCombobox:addOption(t, k - 1)
    end

    local hdGraphicsCombobox = panels.graphicsPanel:recursiveGetChildById('hdGraphics')
    for _, v in ipairs({ { 'Off', 1 }, { '2x', 2 }, { '3x', 3 }, { '4x', 4 } }) do
        hdGraphicsCombobox:addOption(v[1], v[2])
    end

    hdGraphicsCombobox.onOptionChange = function(comboBox, option)
        setOption('hdGraphics', comboBox:getCurrentOption().data)
    end

    antialiasingModeCombobox.onOptionChange = function(comboBox, option)
        setOptionFromUI('antialiasingMode', comboBox:getCurrentOption().data)
    end


    for _, entry in ipairs({
        { 'mouseControlMode', mouseControlModeCombobox },
        { 'lootControlMode', lootControlModeCombobox },
        { 'antialiasingMode', antialiasingModeCombobox }
    }) do
        local combo = panels.basicPanel:recursiveGetChildById(entry[1])
        for _, option in ipairs(entry[2].options) do
            combo:addOption(option.text, option.data)
        end
        combo.onOptionChange = function(widget)
            setOptionFromUI(widget:getId(), widget:getCurrentOption().data)
        end
    end

    for k, t in pairs({ 'Normal', 'Fade', 'Locked', 'Always', 'Always with transparency' }) do
        floorViewModeCombobox:addOption(t, k - 1)
    end

    floorViewModeCombobox.onOptionChange = function(comboBox, option)
        setOptionFromUI('floorViewMode', comboBox:getCurrentOption().data)
    end

    for k, v in pairs({ { 'None', 'none' }, { 'Frames', 'frames' }, { 'Corners', 'corners' } }) do
        framesRarityCombobox:addOption(v[1], v[2])
    end

    local basicFrames = panels.basicPanel:recursiveGetChildById('framesRarity')
    for _, option in ipairs(framesRarityCombobox.options) do
        basicFrames:addOption(option.text, option.data)
    end
    basicFrames.onOptionChange = function(widget)
        setOptionFromUI('framesRarity', widget:getCurrentOption().data)
    end

    framesRarityCombobox.onOptionChange = function(comboBox, option)
        setOptionFromUI('framesRarity', comboBox:getCurrentOption().data)
    end

    local profileCombobox = panels.misc:recursiveGetChildById('profile')

    for i = 1, 10 do
        profileCombobox:addOption(tostring(i), i)
    end

    profileCombobox.onOptionChange = function(comboBox, option)
        setOptionFromUI('profile', comboBox:getCurrentOption().data)
    end

    for _, preset in ipairs(Keybind.presets) do
        listKeybindsPanel:addOption(preset)
    end
    listKeybindsPanel.onOptionChange = function(comboBox, option)
        listKeybindsComboBox(option)
    end
    panels.keybindsPanel.presets.list:setCurrentOption(Keybind.currentPreset)
end

local function setup()
    panels.gameMapPanel = modules.game_interface.getMapPanel()

    setupComboBox()

    -- load options
    for k, obj in pairs(options) do
        local v = obj.value

        if type(v) == 'boolean' then
            local value = g_settings.getBoolean(k)
            setOption(k, value, true)
        elseif type(v) == 'number' then
            local value = g_settings.getNumber(k)
            setOption(k, value, true)
        elseif type(v) == 'string' then
            local value = g_settings.getString(k)
            setOption(k, value, true)
        end
    end
    
    -- Special handling for mouseControlMode to ensure it's in sync with the underlying options
    local mouseControlMode = g_settings.getNumber('mouseControlMode')
    if mouseControlMode ~= nil then
        setOption('mouseControlMode', mouseControlMode, true)
    else
        -- Derive from classicControl and smartLeftClick if mouseControlMode isn't set
        local classicControl = g_settings.getBoolean('classicControl')
        local smartLeftClick = g_settings.getBoolean('smartLeftClick')
        
        if classicControl then
            setOption('mouseControlMode', 1, true)
        elseif smartLeftClick then
            setOption('mouseControlMode', 2, true)
        else
            setOption('mouseControlMode', 0, true)
        end
    end
    
    -- Schedule combobox updates to ensure they happen after UI setup is complete
    scheduleEvent(function()
        local mouseControlModeCombobox = panels.generalPanel:recursiveGetChildById('mouseControlMode')
        local lootControlModeCombobox = panels.generalPanel:recursiveGetChildById('lootControlMode')
        
        if mouseControlModeCombobox then
            -- Use setCurrentOptionByData for more precise control
            for i = 0, 2 do
                if i == options.mouseControlMode.value then
                    mouseControlModeCombobox:setCurrentOptionByData(i)
                    break
                end
            end
        end
        
        if lootControlModeCombobox then
            -- Use setCurrentOptionByData for more precise control
            for i = 0, 2 do
                if i == options.lootControlMode.value then
                    lootControlModeCombobox:setCurrentOptionByData(i)
                    break
                end
            end
        end
        
        -- Update loot control mode visibility
        if lootControlModeCombobox and mouseControlModeCombobox then
            if options.mouseControlMode.value == 1 then
                lootControlModeCombobox:setVisible(true)
            else
                lootControlModeCombobox:setVisible(false)
            end
        end
    end, 100)

    local talkOnRightClick = panels.generalPanel:recursiveGetChildById('talkOnRightClick')
    if talkOnRightClick then
        local parent = talkOnRightClick:getParent()
        parent:setVisible(false)
        parent:setHeight(0)
        parent:setMarginTop(0)
    end
end


controller = Controller:new()
controller:setUI('options')

function controller:onInit()
    for k, obj in pairs(options) do
        if type(obj) ~= "table" then
            obj = { value = obj }
            options[k] = obj
        end
        g_settings.setDefault(k, obj.value)
    end

    extraWidgets.audioButton = modules.client_topmenu.addTopRightToggleButton('audioButton', tr('Audio'),
        '/images/topbuttons/button_mute_up', function() toggleOption('enableAudio') end)

    extraWidgets.optionsButton = modules.client_topmenu.addTopRightToggleButton('optionsButton', tr('Options'),
        '/images/topbuttons/button_options', toggle)

    extraWidgets.logoutButton = modules.client_topmenu.addTopRightToggleButton('logoutButton', tr('Exit'),
        '/images/topbuttons/logout', toggle)

    panels.basicPanel = g_ui.loadUI('styles/basic', controller.ui.optionsTabContent)
    panels.generalPanel = g_ui.loadUI('styles/controls/general', controller.ui.optionsTabContent)
    panels.keybindsPanel = g_ui.loadUI('styles/controls/keybinds', controller.ui.optionsTabContent)

    panels.graphicsPanel = g_ui.loadUI('styles/graphics/graphics', controller.ui.optionsTabContent)
    panels.graphicsEffectsPanel = g_ui.loadUI('styles/graphics/effects', controller.ui.optionsTabContent)

    panels.interface = g_ui.loadUI('styles/interface/interface', controller.ui.optionsTabContent)
    panels.interfaceConsole = g_ui.loadUI('styles/interface/console', controller.ui.optionsTabContent)
    panels.interfaceHUD = g_ui.loadUI('styles/interface/HUD', controller.ui.optionsTabContent)
    panels.actionbars = g_ui.loadUI('styles/interface/actionbars', controller.ui.optionsTabContent)

    panels.soundPanel = g_ui.loadUI('styles/sound/audio', controller.ui.optionsTabContent)

    panels.misc = g_ui.loadUI('styles/misc/misc', controller.ui.optionsTabContent)
    panels.miscHelp = g_ui.loadUI('styles/misc/help', controller.ui.optionsTabContent)

    self.ui:hide()

    configureCharacterCategories()
    addEvent(setup)
    
    -- Add a special delayed event to update comboboxes after everything is loaded
    scheduleEvent(function()
        local mouseControlModeCombobox = panels.generalPanel:recursiveGetChildById('mouseControlMode')
        local lootControlModeCombobox = panels.generalPanel:recursiveGetChildById('lootControlMode')
        
        if mouseControlModeCombobox then
            for i = 0, 2 do
                if i == options.mouseControlMode.value then
                    mouseControlModeCombobox:setCurrentOptionByData(i)
                    break
                end
            end
        end
        
        if lootControlModeCombobox then
            for i = 0, 2 do
                if i == options.lootControlMode.value then
                    lootControlModeCombobox:setCurrentOptionByData(i)
                    break
                end
            end
        end
    end, 1000)  -- 1 second delay to make sure everything is loaded
    
    init_binds()

    Keybind.new("UI", "Toggle Fullscreen", "Ctrl+Shift+F", "")
    Keybind.bind("UI", "Toggle Fullscreen", {
        {
            type = KEY_DOWN,
            callback = function() toggleOption('fullscreen') end,
        }
    })
    Keybind.new("UI", "Show/hide FPS / lag indicator", "", "")
    Keybind.bind("UI", "Show/hide FPS / lag indicator", { {
        type = KEY_DOWN,
        callback = function()
            toggleOption('showPing')
            toggleOption('showFps')
        end
    } })

    Keybind.new("UI", "Show/hide Creature Names and Bars", "Ctrl+N", "")
    Keybind.bind("UI", "Show/hide Creature Names and Bars", {
        {
            type = KEY_DOWN,
            callback = toggleDisplays,
        }
    })

    Keybind.new("Sound", "Mute/unmute", "", "")
    Keybind.bind("Sound", "Mute/unmute", {
        {
            type = KEY_DOWN,
            callback = function() toggleOption('enableAudio') end,
        }
    })
end

function controller:onTerminate()
    optionChanges = nil
    -- Make sure all settings are saved before terminating
    g_settings.save()
    
    -- Disconnect from app exit
    disconnect(g_app, { onExit = onAppExit })
    
    extraWidgets.optionsButton:destroy()
    extraWidgets.audioButton:destroy()
    panels = {}
    extraWidgets = {}
    buttons = {}
    Keybind.delete("UI", "Toggle Fullscreen")
    Keybind.delete("UI", "Show/hide Creature Names and Bars")
    Keybind.delete("UI", "Show/hide FPS / lag indicator")
    Keybind.delete("Sound", "Mute/unmute")

    terminate_binds()
end

function controller:onGameStart()
    if g_settings.getBoolean("autoSwitchPreset") then
        local name = g_game.getCharacterName()
        if Keybind.selectPreset(name) then
            panels.keybindsPanel.presets.list:setCurrentOption(name, true)
            updateKeybinds()
            if modules.game_actionbar and modules.game_actionbar.selectHotkeySet then
                if not modules.game_actionbar.selectHotkeySet(name) then
                    g_logger.warning(string.format("[client_options] Failed to sync action bar hotkey set '%s' on startup.", name))
                end
            end
        end
    end
    if not g_game.getFeature(GameEffectSource) then
        panels.graphicsEffectsPanel.clientEffectOpacity:show()
        panels.graphicsEffectsPanel.clientMissileOpacity:show()
        panels.graphicsEffectsPanel.GameEffectSource:hide()
    else
        g_client.setEffectAlpha(1)
        g_client.setMissileAlpha(1)
        panels.graphicsEffectsPanel.clientEffectOpacity:hide()
        panels.graphicsEffectsPanel.clientMissileOpacity:hide()
        panels.graphicsEffectsPanel.GameEffectSource:show()
    end
end

function updateBasicLayout()
    local panel = panels.basicPanel
    if not panel then return end
    local content = panel:recursiveGetChildById('basicContent')
    local compact = content:getWidth() < 474
    local classic = options.mouseControlMode.value == 1
    local mouse = panel:recursiveGetChildById('mouseControlMode')
    local loot = panel:recursiveGetChildById('lootControlMode')
    mouse:addAnchor(AnchorLeft, compact and 'parent' or 'mouseLabel', compact and AnchorLeft or AnchorRight)
    mouse:addAnchor(AnchorTop, 'mouseLabel', compact and AnchorBottom or AnchorTop)
    mouse:setMarginLeft(compact and 0 or 5)
    mouse:setMarginTop(compact and 5 or 0)
    loot:addAnchor(AnchorLeft, compact and 'parent' or 'mouseControlMode', compact and AnchorLeft or AnchorRight)
    loot:addAnchor(AnchorTop, 'mouseControlMode', compact and AnchorBottom or AnchorTop)
    loot:setMarginLeft(compact and 0 or 5)
    loot:setMarginTop(compact and 5 or 0)
    local chase = panel:recursiveGetChildById('autoChaseOverride')
    chase:addAnchor(AnchorTop, compact and (classic and 'lootControlMode' or 'mouseControlMode') or 'mouseLabel', AnchorBottom)
    panel:recursiveGetChildById('gameplay'):setHeight(compact and (classic and 137 or 112) or 87)

    for row, group in ipairs({ { 'Bottom', 'allActionBar13' }, { 'Left', 'allActionBar46' }, { 'Right', 'allActionBar79' } }) do
        panel:recursiveGetChildById(group[1]:lower() .. 'Label'):setMarginTop((row - 1) * (compact and 38 or 19))
        for column = 0, 3 do
            local id = column == 0 and group[2] or ('actionBarShow' .. group[1] .. column)
            local checkbox = panel:recursiveGetChildById(id)
            checkbox:setMarginLeft((compact and 0 or 175) + column * 65)
            checkbox:setMarginTop((row - 1) * (compact and 38 or 19) + (compact and 19 or 0))
        end
    end
    panel:recursiveGetChildById('actionBars'):setHeight(compact and 124 or 67)
    for _, entry in ipairs({ { 'framesRarity', 'lootLabel' }, { 'antialiasingMode', 'antialiasingLabel' } }) do
        local combo = panel:recursiveGetChildById(entry[1])
        combo:addAnchor(AnchorLeft, compact and 'parent' or entry[2], compact and AnchorLeft or AnchorRight)
        combo:addAnchor(AnchorTop, entry[2], compact and AnchorBottom or AnchorTop)
        combo:setMarginLeft(compact and 0 or 5)
        combo:setMarginTop(compact and 5 or 0)
    end
    panel:recursiveGetChildById('interface'):setHeight(compact and 203 or 124)
    panel:recursiveGetChildById('graphics'):setHeight(compact and 93 or 68)
    panel:recursiveGetChildById('fullscreen'):addAnchor(AnchorTop, compact and 'antialiasingMode' or 'antialiasingLabel', AnchorBottom)
end

local function applyOption(key, value, force)
    if not modules.game_interface then
        return
    end

    local option = options[key]
    if option == nil then
        g_logger.warning(string.format("[client_options] Attempted to set unknown option: '%s'", key))
        return
    end
    
    if not force and option.value == value then
        return
    end

    if option.action then
        option.action(value, options, controller, panels, extraWidgets)
    end


    -- Shared controls must see the new value before emitting check-change callbacks.
    option.value = value
    for _, panel in pairs(panels) do
        local widget = panel:recursiveGetChildById(key)
        if widget then
            if widget:getStyle().__class == 'UICheckBox' then
                widget:setChecked(value)
            elseif widget:getStyle().__class == 'UIComboBox' then
                widget:setCurrentOptionByData(value, true)
            elseif widget:getStyle().__class == 'UIScrollBar' then
                widget:setValue(value)
            elseif widget:recursiveGetChildById('valueBar') then
                widget:recursiveGetChildById('valueBar'):setValue(value)
            end
        end
    end

    if panels.basicPanel then
        panels.basicPanel:recursiveGetChildById('mouseControlMode'):setCurrentOptionByData(options.mouseControlMode.value, true)
        panels.basicPanel:recursiveGetChildById('lootControlMode'):setVisible(options.mouseControlMode.value == 1)
        for _, group in ipairs({ { 'Bottom', 'allActionBar13' }, { 'Left', 'allActionBar46' }, { 'Right', 'allActionBar79' } }) do
            for i = 1, 3 do
                panels.basicPanel:recursiveGetChildById('actionBarShow' .. group[1] .. i):setEnabled(options[group[2]].value)
            end
        end
    end
    updateBasicLayout()
    g_settings.set(key, value)
end

local function changeOption(key, value, force, fromUI)
    if optionChangeOrigin ~= nil then
        return applyOption(key, value, force)
    end

    local before
    if optionChanges then
        before = {}
        for name, option in pairs(options) do
            before[name] = option.value
        end
    end
    optionChangeOrigin = fromUI
    local ok, result = pcall(applyOption, key, value, force)
    optionChangeOrigin = nil

    if before then
        for name, option in pairs(options) do
            if before[name] ~= option.value then
                if fromUI then
                    local change = optionChanges[name]
                    local original = before[name]
                    if change then original = change.before end
                    if original == option.value then
                        optionChanges[name] = nil
                    else
                        optionChanges[name] = { before = original, value = option.value }
                    end
                else
                    optionChanges[name] = nil
                end
            end
        end
        if not fromUI then
            -- External changes own the current value, including an explicit same-value write.
            optionChanges[key] = nil
            for _, group in ipairs({
                { 'mouseControlMode', 'classicControl', 'smartLeftClick' },
                { 'nativeCursor', 'showAnimatedCursor' }
            }) do
                for _, name in ipairs(group) do
                    if name == key then
                        for _, related in ipairs(group) do optionChanges[related] = nil end
                        break
                    end
                end
            end
        end
    end
    if not ok then error(result) end
    return result
end

function setOption(key, value, force)
    return changeOption(key, value, force, false)
end

function setOptionFromUI(key, value)
    return changeOption(key, value, false, true)
end

function getOptionChanges()
    return table.recursivecopy(optionChanges or {})
end

function resetBasicOptions()
    for _, key in ipairs(basicOptionKeys) do
        setOptionFromUI(key, basicDefaultValues[key])
    end
end

function setupOptionsMainButton()
    if extraWidgets.optionsButtons then
        return
    end

    extraWidgets.optionsButtons = modules.game_mainpanel.addSpecialToggleButton('optionsMainButton', tr('Options'),
        '/images/options/button_options', toggle, true)
end

function getOption(key)
    local option = options[key]
    if option == nil then
        g_logger.warning(string.format("[client_options] Attempted to get unknown option: '%s'", key))
        return nil
    end
    return option.value
end

local function closeOptionsWindow()
    controller.ui:hide()
    if extraWidgets.optionsButton then
        extraWidgets.optionsButton:setOn(false)
    end
end

local function rollbackOptionChanges()
    local changes = optionChanges
    if not changes then return end

    optionChanges = nil
    optionChangeOrigin = false
    local grouped = {
        mouseControlMode = true,
        classicControl = true,
        smartLeftClick = true,
        nativeCursor = true,
        showAnimatedCursor = true
    }
    local ok, message = pcall(function()
        for name, change in pairs(changes) do
            if not grouped[name] then applyOption(name, change.before, true) end
        end

        if changes.mouseControlMode or changes.classicControl or changes.smartLeftClick then
            local function before(name)
                return changes[name] and changes[name].before or options[name].value
            end
            applyOption('classicControl', before('classicControl'), true)
            applyOption('smartLeftClick', before('smartLeftClick'), true)
            applyOption('mouseControlMode', before('mouseControlMode'), true)
        end

        if changes.nativeCursor or changes.showAnimatedCursor then
            local nativeCursor = changes.nativeCursor and changes.nativeCursor.before or options.nativeCursor.value
            local animatedCursor = changes.showAnimatedCursor and changes.showAnimatedCursor.before or options.showAnimatedCursor.value
            if nativeCursor then
                applyOption('showAnimatedCursor', false, true)
                applyOption('nativeCursor', true, true)
            elseif animatedCursor then
                applyOption('nativeCursor', false, true)
                applyOption('showAnimatedCursor', true, true)
            else
                applyOption('nativeCursor', false, true)
                applyOption('showAnimatedCursor', false, true)
            end
        end
    end)
    optionChangeOrigin = nil
    if not ok then error(message) end
end

function show()
    beginPresetEdits()
    optionChanges = optionChanges or {}
    if not controller.ui.selectedOption then
        local firstCategory = controller.ui.optionsTabBar:getChildByIndex(1)
        if firstCategory then
            firstCategory.Button:onClick()
        end
    end
    controller.ui:show()
    controller.ui:raise()
    controller.ui:focus()
    if extraWidgets.optionsButton then
        extraWidgets.optionsButton:setOn(true)
    end
end

function hide()
    if not applyChangedOptions() then return false end
    optionChanges = nil
    g_settings.save()
    closeOptionsWindow()
    return true
end

function saveOptions()
    if not applyChangedOptions() then return false end
    g_settings.save()
    optionChanges = {}
    beginPresetEdits()
    return true
end

function cancelOptions()
    rollbackOptionChanges()
    discardPresetEdits()
    optionChanges = nil
    g_settings.save()
    closeOptionsWindow()
    return true
end

function toggle()
    if controller.ui:isVisible() then
        hide()
        return
    end
    if not controller.ui.openedCategory then
        local firstCategory = controller.ui.optionsTabBar:getChildByIndex(1)
        controller.ui.openedCategory = firstCategory
        firstCategory.Button:onClick()
        local panelToShow = panels[firstCategory.open]
        if panelToShow then
            panelToShow:show()
            controller.ui.selectedOption = panelToShow
        end
    end
    show()
    updateKeybinds()
end

function addTab(name, panel, icon)
    print("to prevent the error use Ex = g_ui.loadUI('option_healthcircle',modules.client_options:getPanel()) ")
end

function removeTab(v)
    print("to prevent the error use Ex   modules.client_options.addButton('Interface', 'HP/MP Circle', optionPanel)")
end

local function toggleSubCategories(parent, isOpen)
    for subId, _ in ipairs(parent.subCategories) do
        local subWidget = parent:getChildById(subId)
        if subWidget then
            subWidget:setVisible(isOpen)
        end
    end
    parent:setHeight(isOpen and parent.openedSize or parent.closedSize)
    parent.opened = isOpen
    parent.Button.Arrow:setVisible(not isOpen)
end

local function close(parent)
    if parent.subCategories then
        toggleSubCategories(parent, false)
    end
end

local function open(parent)
    local oldOpen = controller.ui.openedCategory
    if oldOpen and oldOpen ~= parent then
        close(oldOpen)
    end
    toggleSubCategories(parent, true)
    controller.ui.openedCategory = parent
end

function selectCharacterPage()
    local selectedOption = controller.ui.selectedOption
    if selectedOption then
        selectedOption:hide()
    end
    if controller.ui.InfoBase then
        controller.ui.InfoBase:setVisible(true)
        controller.ui.InfoBase:show()
    end
end

local function createSubWidget(parent, subId, subButton)
    local subWidget = g_ui.createWidget("OptionsCategory", parent)
    subWidget:setId(subId)
    subWidget.Button.Icon:setIcon(subButton.icon)
    subWidget.Button.Title:setText(subButton.text)
    subWidget:setVisible(false)
    subWidget.open = subButton.open
    subWidget.callbackFunc = subButton.callbackFunc

    function subWidget.Button.onClick()
        local selectedOption = controller.ui.selectedOption
        closeCharacterButtons()
        parent.Button:setChecked(false)
        parent.Button.Arrow:setVisible(true)
        parent.Button.Arrow:setImageSource("")
        subWidget.Button:setChecked(true)
        subWidget.Button.Arrow:setVisible(true)
        subWidget.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-right")

        if selectedOption then
            selectedOption:hide()
        end

        local panelToShow = panels[subWidget.open]
        if panelToShow then
            panelToShow:show()
            panelToShow:setVisible(true)
            controller.ui.selectedOption = panelToShow
        else
            print("Error: panelToShow is nil or does not exist in panels")
        end
        if subWidget.callbackFunc then
            subWidget.callbackFunc()
        end
    end

    subWidget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
    if subId == 1 then
        subWidget:addAnchor(AnchorTop, "parent", AnchorTop)
        subWidget:setMarginTop(20)
    else
        subWidget:addAnchor(AnchorTop, "prev", AnchorBottom)
        subWidget:setMarginTop(-1)
    end

    return subWidget
end

function configureCharacterCategories()
    controller.ui.optionsTabBar:destroyChildren()

    for id, button in ipairs(buttons) do
        local widget = g_ui.createWidget("OptionsCategory", controller.ui.optionsTabBar)
        widget:setId(id)
        widget.Button.Icon:setIcon(button.icon)
        widget.Button.Title:setText(button.text)
        widget.open = button.open

        if button.subCategories then
            widget.subCategories = button.subCategories
            widget.subCategoriesSize = #button.subCategories
            widget.Button.Arrow:setVisible(true)

            for subId, subButton in ipairs(button.subCategories) do
                local subWidget = createSubWidget(widget, subId, subButton)
                if button.text == "Controls" then
                    subWidget.Button.Title:setMarginLeft(-5)
                end
            end
        end

        widget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
        if id == 1 then
            widget:addAnchor(AnchorTop, "parent", AnchorTop)
            widget:setMarginTop(10)
        else
            widget:addAnchor(AnchorTop, "prev", AnchorBottom)
            widget:setMarginTop(10)
        end

        function widget.Button.onClick()
            local parent = widget
            local oldOpen = controller.ui.openedCategory

            if oldOpen and oldOpen ~= parent then
                if oldOpen.Button then
                    oldOpen.Button:setChecked(false)
                    oldOpen.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-down")
                end

                close(oldOpen)
            end

            if parent.subCategoriesSize then
                parent.closedSize = parent.closedSize or parent:getHeight() / (parent.subCategoriesSize + 1) + 15
                parent.openedSize = parent.openedSize or parent:getHeight() * (parent.subCategoriesSize + 1) - 6

                if not parent.opened then
                    open(parent)
                end
            end

            widget.Button:setChecked(true)
            widget.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-right")
            widget.Button.Arrow:setVisible(true)

            if controller.ui.selectedOption then
                controller.ui.selectedOption:hide()
            end

            local panelToShow = panels[parent.open]
            if panelToShow then
                closeCharacterButtons()
                panelToShow:show()
                panelToShow:setVisible(true)
                controller.ui.selectedOption = panelToShow
            else
                print("Error: panelToShow is nil or does not exist in panels")
            end

            controller.ui.openedCategory = parent
        end
    end
end

function closeCharacterButtons()
    for i = 1, controller.ui.optionsTabBar:getChildCount() do
        local widget = controller.ui.optionsTabBar:getChildByIndex(i)
        if widget and widget.subCategories then
            for subId, _ in ipairs(widget.subCategories) do
                local subWidget = widget:getChildById(subId)
                if subWidget then
                    subWidget.Button:setChecked(false)
                    subWidget.Button.Arrow:setVisible(false)
                end
            end
        end
    end
end

function createCategory(text, icon, openPanel, subCategories)
    local newCategory = {
        text = text,
        icon = icon,
        open = type(openPanel) == "string" and openPanel or getPanelName(openPanel),
        subCategories = subCategories
    }
    table.insert(buttons, newCategory)
    if type(openPanel) ~= "string" then
        panels[getPanelName(openPanel)] = openPanel
    end
    configureCharacterCategories()
end

function removeCategory(categoryText, subcategoryText)
    for i, category in ipairs(buttons) do
        if category.text == categoryText then
            if subcategoryText then
                if category.subCategories then
                    for j, subcategory in ipairs(category.subCategories) do
                        if subcategory.text == subcategoryText then
                            panels[subcategory.open] = nil
                            table.remove(category.subCategories, j)
                            break
                        end
                    end
                end
            else
                panels[category.open] = nil
                if category.subCategories then
                    for _, subcategory in ipairs(category.subCategories) do
                        panels[subcategory.open] = nil
                    end
                end
                table.remove(buttons, i)
            end
            configureCharacterCategories()
            return
        end
    end
end

function removeButton(categoryText, buttonText)
    for _, category in ipairs(buttons) do
        if category.text == categoryText then
            if category.subCategories then
                for i, subcategory in ipairs(category.subCategories) do
                    if subcategory.text == buttonText then
                        panels[subcategory.open] = nil
                        table.remove(category.subCategories, i)
                        configureCharacterCategories()
                        return
                    end
                end
            end
        end
    end
end

function addButton(categoryText, buttonText, openPanel, callback)
    for _, category in ipairs(buttons) do
        if category.text == categoryText then
            if not category.subCategories then
                category.subCategories = {}
            end
            local panelName = type(openPanel) == "string" and openPanel or getPanelName(openPanel)
            table.insert(category.subCategories, {
                text = buttonText,
                open = panelName,
                callbackFunc = callback
            })
            if type(openPanel) ~= "string" then
                panels[panelName] = openPanel
            end
            configureCharacterCategories()
            return
        end
    end
end

function getPanelName(panel)
    for name, p in pairs(panels) do
        if p == panel then
            return name
        end
    end
    return "panel_" .. tostring(panel):match("userdata: 0x(%x+)")
end

function addSubcategoryToCategory(categoryText, newSubcategory)
    addButtonToCategory(categoryText, newSubcategory)
end

function getPanel()
    return controller.ui.optionsTabContent
end

function openOptionsCategory(category, subcategory)
    if not controller.ui:isVisible() then
        show()
    end
    for i = 1, controller.ui.optionsTabBar:getChildCount() do
        local widget = controller.ui.optionsTabBar:getChildByIndex(i)
        if widget and widget.Button.Title:getText() == category then
            widget.Button:onClick()
            if subcategory and widget.subCategories then
                for subId, _ in ipairs(widget.subCategories) do
                    local subWidget = widget:getChildById(subId)
                    if subWidget and subWidget.Button.Title:getText() == subcategory then
                        subWidget.Button:onClick()
                        return true
                    end
                end
            end
            return true
        end
    end
    return false
end
