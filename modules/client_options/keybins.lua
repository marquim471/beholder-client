local actionNameLimit = 39
local changedOptions = {}
local changedKeybinds = {}
local changedHotkeys = {}
local presetEdits
local getEditedKeybindKeys
local getEditedHotkeys
local customHotkeysMode = false
local presetWindow = nil
local actionSearchEvent
local keyEditWindow = nil
local chatModeGroup

-- controls and keybinds
function addNewPreset()
    presetWindow:setText(tr('Add hotkey preset'))

    presetWindow.info:setText(tr('Enter a name for the new preset:'))

    presetWindow.field:clearText()
    presetWindow.field:show()
    presetWindow.field:focus()

    presetWindow:setWidth(360)

    presetWindow.action = 'add'

    presetWindow:show()
    presetWindow:raise()
    presetWindow:focus()

    controller.ui:hide()
end

function copyPreset()
    presetWindow:setText(tr('Copy hotkey preset'))

    presetWindow.info:setText(tr('Enter a name for the new preset:'))

    presetWindow.field:clearText()
    presetWindow.field:show()
    presetWindow.field:focus()

    presetWindow.action = 'copy'

    presetWindow:setWidth(360)
    presetWindow:show()
    presetWindow:raise()
    presetWindow:focus()

    controller.ui:hide()
end

function renamePreset()
    presetWindow:setText(tr('Rename hotkey preset'))

    presetWindow.info:setText(tr('Enter a name for the preset:'))

    presetWindow.field:setText(panels.keybindsPanel.presets.list:getCurrentOption().text)
    presetWindow.field:setCursorPos(1000)
    presetWindow.field:show()
    presetWindow.field:focus()

    presetWindow.action = 'rename'

    presetWindow:setWidth(360)
    presetWindow:show()
    presetWindow:raise()
    presetWindow:focus()

    controller.ui:hide()
end

function removePreset()
    presetWindow:setText(tr('Warning'))

    presetWindow.info:setText(tr('Do you really want to delete the hotkey preset %s?',
        panels.keybindsPanel.presets.list:getCurrentOption().text))
    presetWindow.field:hide()
    presetWindow.action = 'remove'

    presetWindow:setWidth(presetWindow.info:getTextSize().width + presetWindow:getPaddingLeft() +
        presetWindow:getPaddingRight())
    presetWindow:show()
    presetWindow:raise()
    presetWindow:focus()

    controller.ui:hide()
end

function beginPresetEdits()
    if presetEdits then return end
    presetEdits = { names = table.recursivecopy(Keybind.presets), entries = {}, operations = {}, selected = Keybind.currentPreset }
    for _, name in ipairs(Keybind.presets) do
        presetEdits.entries[name] = { base = name }
    end
end

local function refreshPresetList()
    local list = panels.keybindsPanel.presets.list
    local callback = list.onOptionChange
    list.onOptionChange = nil
    list:clearOptions()
    for _, name in ipairs(presetEdits.names) do list:addOption(name) end
    list:setCurrentOption(presetEdits.selected, true)
    list.onOptionChange = callback
    updateKeybinds()
end

function discardPresetEdits()
    changedKeybinds = {}
    changedHotkeys = {}
    changedOptions = {}
    presetEdits = nil
    beginPresetEdits()
    refreshPresetList()
end

function okPresetWindow()
    beginPresetEdits()
    local name = presetWindow.field:getText():trim()
    local selected = presetEdits.selected
    local action = presetWindow.action
    if action ~= 'remove' then
        if name == '' or name:find('[\\/:*?"<>|]') or name == '.' or name == '..' then
            presetWindow.info:setText(tr('Please enter a valid preset name.'))
            return
        end
        for _, existing in ipairs(presetEdits.names) do
            if existing:lower() == name:lower() and not (action == 'rename' and existing == selected) then
                presetWindow.info:setText(tr('A preset with this name already exists.'))
                return
            end
        end
    elseif #presetEdits.names == 1 then
        return
    end

    if action == 'add' or action == 'copy' then
        local entry = { base = false }
        local operation = { action = action, name = name }
        if action == 'copy' then
            local source = presetEdits.entries[selected]
            entry.base = source.base
            entry.barSnapshot = source.barSnapshot or modules.game_actionbar.ApiJson.getHotkeySetSnapshot(source.base or selected)
            entry.hotkeys = {}
            changedKeybinds[name] = {}
            for mode = CHAT_MODE.ON, CHAT_MODE.OFF do
                entry.hotkeys[mode] = table.recursivecopy(getEditedHotkeys(selected, mode))
                for _, hotkey in ipairs(entry.hotkeys[mode]) do hotkey.callback = nil end
                changedKeybinds[name][mode] = {}
                for index, keybind in pairs(Keybind.defaultKeybinds) do
                    local keys = getEditedKeybindKeys(keybind.category, keybind.action, mode, selected)
                    changedKeybinds[name][mode][index] = { category = keybind.category, action = keybind.action, primary = keys.primary or '', secondary = keys.secondary or '' }
                end
            end
            entry.keys = table.recursivecopy(changedKeybinds[name])
            operation.source = selected
            operation.barSnapshot = table.recursivecopy(entry.barSnapshot)
        end
        presetEdits.entries[name] = entry
        table.insert(presetEdits.names, name)
        table.insert(presetEdits.operations, operation)
        presetEdits.selected = name
    elseif action == 'rename' and name ~= selected then
        presetEdits.entries[name] = presetEdits.entries[selected]
        presetEdits.entries[selected] = nil
        changedKeybinds[name] = changedKeybinds[selected]
        changedKeybinds[selected] = nil
        changedHotkeys[name] = changedHotkeys[selected]
        changedHotkeys[selected] = nil
        for i, current in ipairs(presetEdits.names) do if current == selected then presetEdits.names[i] = name end end
        table.insert(presetEdits.operations, { action = action, source = selected, name = name })
        presetEdits.selected = name
    elseif action == 'remove' then
        presetEdits.entries[selected] = nil
        changedKeybinds[selected] = nil
        changedHotkeys[selected] = nil
        for i, current in ipairs(presetEdits.names) do if current == selected then table.remove(presetEdits.names, i);break end end
        table.insert(presetEdits.operations, { action = action, name = selected })
        presetEdits.selected = presetEdits.names[1]
    end
    presetWindow:hide()
    show()
    refreshPresetList()
end

function cancelPresetWindow()
    presetWindow:hide()
    show()
end

getEditedKeybindKeys = function(category, action, chatMode, preset)
    local pending = changedKeybinds[preset] and changedKeybinds[preset][chatMode]
    local change = pending and pending[category .. '_' .. action]
    if change then return { primary = change.primary, secondary = change.secondary } end
    local entry = presetEdits and presetEdits.entries[preset]
    local copied = entry and entry.keys and entry.keys[chatMode] and entry.keys[chatMode][category .. '_' .. action]
    if copied then return { primary = copied.primary, secondary = copied.secondary } end
    if entry and not entry.base then
        return table.recursivecopy(Keybind.getAction(category, action).keys[chatMode])
    end
    return table.recursivecopy(Keybind.getKeybindKeys(category, action, chatMode, entry and entry.base or preset))
end

getEditedHotkeys = function(preset, chatMode, writable)
    local pending = changedHotkeys[preset] and changedHotkeys[preset][chatMode]
    if pending then return pending end
    local entry = presetEdits and presetEdits.entries[preset]
    local hotkeys = entry and entry.hotkeys and entry.hotkeys[chatMode] or Keybind.hotkeys[chatMode][entry and entry.base or preset] or {}
    if not writable then return hotkeys end
    changedHotkeys[preset] = changedHotkeys[preset] or {}
    pending = table.recursivecopy(hotkeys)
    for _, hotkey in ipairs(pending) do hotkey.callback = nil end
    changedHotkeys[preset][chatMode] = pending
    return pending
end

local function isEditedKeyComboUsed(keyCombo, category, action, chatMode, preset, exceptHotkey)
    if keyCombo == '' then return false end
    if Keybind.reservedKeys[keyCombo] then return true end
    for _, keybind in pairs(Keybind.defaultKeybinds) do
        if keybind.category ~= category or keybind.action ~= action then
            local keys = getEditedKeybindKeys(keybind.category, keybind.action, chatMode, preset)
            if keys.primary == keyCombo or keys.secondary == keyCombo then return true end
        end
    end
    for i, hotkey in ipairs(getEditedHotkeys(preset, chatMode)) do
        if i ~= exceptHotkey and (hotkey.primary == keyCombo or hotkey.secondary == keyCombo) then return true end
    end
    return false
end

local function stageKeybind(category, action, preset, chatMode, primary, secondary)
    changedKeybinds[preset] = changedKeybinds[preset] or {}
    changedKeybinds[preset][chatMode] = changedKeybinds[preset][chatMode] or {}
    changedKeybinds[preset][chatMode][category .. '_' .. action] = {
        category = category, action = action, primary = primary or '', secondary = secondary or ''
    }
end

function editKeybindKeyDown(widget, keyCode, keyboardModifiers)
    keyEditWindow.keyCombo:setText(determineKeyComboDesc(keyCode,
        keyEditWindow.alone:isVisible() and KeyboardNoModifier or keyboardModifiers))

    local category = nil
    local action = nil

    if keyEditWindow.keybind then
        category = keyEditWindow.keybind.category
        action = keyEditWindow.keybind.action
    end

    local keyCombo = keyEditWindow.keyCombo:getText()
    local preset = panels.keybindsPanel.presets.list:getCurrentOption().text
    local keyUsed = isEditedKeyComboUsed(keyCombo, category, action, getChatMode(), preset, keyEditWindow.hotkeyId)
    keyEditWindow.buttons.ok:setEnabled(not keyUsed)
    keyEditWindow.used:setVisible(keyUsed)
end

function editKeybind(keybind)
    keyEditWindow.hotkeyId = nil
    keyEditWindow.buttons.cancel.onClick = function()
        disconnect(keyEditWindow, {
            onKeyDown = editKeybindKeyDown
        })
        keyEditWindow:hide()
        keyEditWindow:ungrabKeyboard()
        show()
    end

    keyEditWindow.info:setText(tr(
        'Click \'Ok\' to assign the keybind. Click \'Clear\' to remove the keybind from \'%s: %s\'.', keybind.category,
        keybind.action))
    keyEditWindow.alone:setVisible(keybind.alone)

    connect(keyEditWindow, {
        onKeyDown = editKeybindKeyDown
    })

    keyEditWindow:show()
    keyEditWindow:raise()
    keyEditWindow:focus()
    keyEditWindow:grabKeyboard()
    controller.ui:hide()
end

local function editActionKey(button, secondary)
    local row = button:getParent():getParent()
    local keybind = Keybind.getAction(row.category, row.action)
    local preset = panels.keybindsPanel.presets.list:getCurrentOption().text
    local chatMode = getChatMode()
    local keys = getEditedKeybindKeys(row.category, row.action, chatMode, preset)
    keyEditWindow.keybind = { category = row.category, action = row.action }
    local title = secondary and 'Edit Secondary Key for \'%s\'' or 'Edit Primary Key for \'%s\''
    keyEditWindow:setText(tr(title, string.format('%s: %s', keybind.category, keybind.action)))
    keyEditWindow.keyCombo:setText((secondary and keys.secondary or keys.primary) or '')
    editKeybind(keybind)
    local used = isEditedKeyComboUsed(keyEditWindow.keyCombo:getText(), keybind.category, keybind.action, chatMode, preset)
    keyEditWindow.buttons.ok:setEnabled(not used)
    keyEditWindow.used:setVisible(used)

    local function accept(keyCombo)
        local used = isEditedKeyComboUsed(keyCombo, keybind.category, keybind.action, chatMode, preset)
        keyEditWindow.buttons.ok:setEnabled(not used)
        keyEditWindow.used:setVisible(used)
        if used then return end
        local current = getEditedKeybindKeys(keybind.category, keybind.action, chatMode, preset)
        if secondary then
            current.secondary = keyCombo
            if current.primary == keyCombo then current.primary = '' end
        else
            current.primary = keyCombo
            if current.secondary == keyCombo then current.secondary = '' end
        end
        stageKeybind(keybind.category, keybind.action, preset, chatMode, current.primary, current.secondary)
        disconnect(keyEditWindow, { onKeyDown = editKeybindKeyDown })
        keyEditWindow:hide()
        keyEditWindow:ungrabKeyboard()
        show()
        updateKeybinds()
    end
    keyEditWindow.buttons.ok.onClick = function() accept(keyEditWindow.keyCombo:getText()) end
    keyEditWindow.buttons.clear.onClick = function() accept('') end
end

function editKeybindPrimary(button)
    editActionKey(button, false)
end

function editKeybindSecondary(button)
    editActionKey(button, true)
end

function resetActions()
    local preset = panels.keybindsPanel.presets.list:getCurrentOption().text
    for _, keybind in pairs(Keybind.defaultKeybinds) do
        for chatMode = CHAT_MODE.ON, CHAT_MODE.OFF do
            local keys = keybind.keys[chatMode]
            stageKeybind(keybind.category, keybind.action, preset, chatMode, keys.primary, keys.secondary)
        end
    end
    updateKeybinds()
end

function updateKeybinds()
    if customHotkeysMode then return updateHotkeys() end
    panels.keybindsPanel.tablePanel.keybinds:clearData()

    local sortedKeybinds = {}

    for index, _ in pairs(Keybind.defaultKeybinds) do
        table.insert(sortedKeybinds, index)
    end

    table.sort(sortedKeybinds, function(a, b)
        local keybindA = Keybind.defaultKeybinds[a]
        local keybindB = Keybind.defaultKeybinds[b]

        if keybindA.category ~= keybindB.category then
            return keybindA.category < keybindB.category
        end
        return keybindA.action < keybindB.action
    end)


    local comboBox = panels.keybindsPanel.presets.list:getCurrentOption()
    if not comboBox then
        return
    end
    for _, index in ipairs(sortedKeybinds) do
        local keybind = Keybind.defaultKeybinds[index]
        local keys = getEditedKeybindKeys(keybind.category, keybind.action, getChatMode(), comboBox.text)
        addKeybind(keybind.category, keybind.action, keys.primary, keys.secondary)
    end
end

function showCustomHotkeys()
    customHotkeysMode = true
    panels.keybindsPanel.buttons.reset:hide()
    updateHotkeys()
end

function showGeneralHotkeys()
    customHotkeysMode = false
    panels.keybindsPanel.buttons.reset:show()
    updateKeybinds()
end

function addHotkey(hotkeyId, action, data, primary, secondary)
    local text = data.text or data.words or tr('Object: %d', data.itemId or 0)
    if data.words and data.parameter then text = text .. ' ' .. data.parameter end
    local row = panels.keybindsPanel.tablePanel.keybinds:addRow({
        { text = text, width = 286 }, { style = 'VerticalSeparator' },
        { style = 'EditableKeybindsTableColumn', text = primary or '', width = 100 },
        { style = 'VerticalSeparator' },
        { style = 'EditableKeybindsTableColumn', text = secondary or '', width = 90 }
    })
    row.hotkeyId = hotkeyId
    row:getChildByIndex(3).edit.onClick = editHotkeyPrimary
    row:getChildByIndex(5).edit.onClick = editHotkeySecondary
end

function updateHotkeys()
    panels.keybindsPanel.tablePanel.keybinds:clearData()
    local preset = panels.keybindsPanel.presets.list:getCurrentOption().text
    for i, hotkey in ipairs(getEditedHotkeys(preset, getChatMode())) do
        addHotkey(i, hotkey.action, hotkey.data, hotkey.primary, hotkey.secondary)
    end
end

function preAddHotkey(action, data)
    local preset = panels.keybindsPanel.presets.list:getCurrentOption().text
    local hotkeys = getEditedHotkeys(preset, getChatMode(), true)
    table.insert(hotkeys, { hotkeyId = #hotkeys + 1, action = action, data = table.recursivecopy(data), primary = '', secondary = '' })
    updateHotkeys()
end

function addKeybind(category, action, primary, secondary)
    local rawText = string.format('%s: %s', category, action)
    local text = string.format('[color=#ffffff]%s:[/color] %s', category, action)
    local tooltip = nil

    if rawText:len() > actionNameLimit then
        tooltip = rawText
        -- 15 and 8 are length of color codes
        text = text:sub(1, actionNameLimit + 15 + 8) .. '...'
    end

    local row = panels.keybindsPanel.tablePanel.keybinds:addRow({ {
        coloredText = {
            text = text,
            color = '#c0c0c0'
        },
        width = 286
    }, {
        style = 'VerticalSeparator'
    }, {
        style = 'EditableKeybindsTableColumn',
        text = primary,
        width = 100
    }, {
        style = 'VerticalSeparator'
    }, {
        style = 'EditableKeybindsTableColumn',
        text = secondary,
        width = 90
    } })

    row.category = category
    row.action = action

    if tooltip then
        row:setTooltip(tooltip)
    end

    row:getChildByIndex(3).edit.onClick = editKeybindPrimary
    row:getChildByIndex(5).edit.onClick = editKeybindSecondary
end

function clearHotkey(row)
    local preset = panels.keybindsPanel.presets.list:getCurrentOption().text
    local hotkeys = getEditedHotkeys(preset, getChatMode(), true)
    table.remove(hotkeys, row.hotkeyId)
    for i, hotkey in ipairs(hotkeys) do hotkey.hotkeyId = i end
    updateHotkeys()
end

function editHotkeyKey(text)
    keyEditWindow.keybind = nil
    keyEditWindow.buttons.cancel.onClick = function()
        disconnect(keyEditWindow, {
            onKeyDown = editKeybindKeyDown
        })
        keyEditWindow:hide()
        keyEditWindow:ungrabKeyboard()
        show()
    end

    keyEditWindow.info:setText(tr(
        'Click \'Ok\' to assign the keybind. Click \'Clear\' to remove the keybind from \'%s\'.', text))
    keyEditWindow.alone:setVisible(false)

    connect(keyEditWindow, {
        onKeyDown = editKeybindKeyDown
    })

    keyEditWindow:show()
    keyEditWindow:raise()
    keyEditWindow:focus()
    keyEditWindow:grabKeyboard()
    controller.ui:hide()
end

local function editCustomHotkey(button, secondary)
    local row = button:getParent():getParent()
    local hotkeyId = row.hotkeyId
    local preset = panels.keybindsPanel.presets.list:getCurrentOption().text
    local chatMode = getChatMode()
    local hotkey = getEditedHotkeys(preset, chatMode)[hotkeyId]
    if not hotkey then return end
    local text = row:getChildByIndex(1):getText()
    local title = secondary and 'Edit Secondary Key for \'%s\'' or 'Edit Primary Key for \'%s\''
    keyEditWindow:setText(tr(title, text))
    keyEditWindow.keyCombo:setText((secondary and hotkey.secondary or hotkey.primary) or '')
    editHotkeyKey(text)
    keyEditWindow.hotkeyId = hotkeyId
    local used = isEditedKeyComboUsed(keyEditWindow.keyCombo:getText(), nil, nil, chatMode, preset, hotkeyId)
    keyEditWindow.buttons.ok:setEnabled(not used)
    keyEditWindow.used:setVisible(used)

    local function accept(value)
        local conflict = isEditedKeyComboUsed(value, nil, nil, chatMode, preset, hotkeyId)
        keyEditWindow.buttons.ok:setEnabled(not conflict)
        keyEditWindow.used:setVisible(conflict)
        if conflict then return end
        local edited = getEditedHotkeys(preset, chatMode, true)[hotkeyId]
        if secondary then
            edited.secondary = value
            if edited.primary == value then edited.primary = '' end
        else
            edited.primary = value
            if edited.secondary == value then edited.secondary = '' end
        end
        disconnect(keyEditWindow, { onKeyDown = editKeybindKeyDown })
        keyEditWindow:hide()
        keyEditWindow:ungrabKeyboard()
        show()
        updateHotkeys()
    end
    keyEditWindow.buttons.ok.onClick = function() accept(keyEditWindow.keyCombo:getText()) end
    keyEditWindow.buttons.clear.onClick = function() accept('') end
end

function editHotkeyPrimary(button)
    editCustomHotkey(button, false)
end

function editHotkeySecondary(button)
    editCustomHotkey(button, true)
end

function searchActions(field, text, oldText)
    if actionSearchEvent then
        removeEvent(actionSearchEvent)
    end

    actionSearchEvent = scheduleEvent(performeSearchActions, 200)
end

function performeSearchActions()
    local searchText = panels.keybindsPanel.search.field:getText():trim():lower():gsub("%+", "%%+")

    local rows = panels.keybindsPanel.tablePanel.keybinds.dataSpace:getChildren()
    if searchText:len() > 0 then
        for _, row in ipairs(rows) do
            row:hide()
        end

        for _, row in ipairs(rows) do
            local actionText = row:getChildByIndex(1):getText():lower()
            local primaryText = row:getChildByIndex(3):getText():lower()
            local secondaryText = row:getChildByIndex(5):getText():lower()
            if actionText:find(searchText) or primaryText:find(searchText) or secondaryText:find(searchText) then
                row:show()
            end
        end
    else
        for _, row in ipairs(rows) do
            row:show()
        end
    end

    removeEvent(actionSearchEvent)
    actionSearchEvent = nil
end

function chatModeChange()

    panels.keybindsPanel.search.field:clearText()

    updateKeybinds()
end

function getChatMode()
    if chatModeGroup:getSelectedWidget() == panels.keybindsPanel.panel.chatMode.on then
        return CHAT_MODE.ON
    end

    return CHAT_MODE.OFF
end

function discardChangedKeybinds()
    changedKeybinds = {}
    updateKeybinds()
end

local function showPresetApplyError()
    displayErrorBox(tr('Hotkey Presets'), tr('The hotkey preset changes could not be applied. Review the preset names and try again.'))
    return false
end

local function preflightPresetEdits(bars)
    local keyNames = {}
    local keyCount = 0
    for _, name in ipairs(Keybind.presets) do
        keyNames[name] = true
        keyCount = keyCount + 1
    end

    local barNames = {}
    local knownBars = {}
    local function hasBar(name)
        if not knownBars[name] then
            barNames[name] = bars.hotkeySetExists(name)
            knownBars[name] = true
        end
        return barNames[name]
    end

    for _, operation in ipairs(presetEdits.operations) do
        local source = operation.source
        local name = operation.name
        if operation.action == 'add' or operation.action == 'copy' then
            if keyNames[name] or hasBar(name) then return false end
            if operation.action == 'copy' and (not keyNames[source] or type(operation.barSnapshot) ~= 'table') then return false end
            keyNames[name] = true
            barNames[name] = true
            knownBars[name] = true
            keyCount = keyCount + 1
        elseif operation.action == 'rename' then
            if not keyNames[source] or not hasBar(source) or keyNames[name] or hasBar(name) then return false end
            keyNames[source] = nil
            barNames[source] = false
            knownBars[source] = true
            keyNames[name] = true
            barNames[name] = true
            knownBars[name] = true
        elseif operation.action == 'remove' then
            if keyCount <= 1 or not keyNames[name] or not hasBar(name) then return false end
            keyNames[name] = nil
            barNames[name] = false
            knownBars[name] = true
            keyCount = keyCount - 1
        end
    end

    return keyNames[presetEdits.selected] and hasBar(presetEdits.selected)
end

local function applyPresetEdits()
    if not presetEdits then return true end
    if #presetEdits.operations == 0 and not presetEdits.selectionChanged then
        presetEdits = nil
        return true
    end

    local bars = modules.game_actionbar
    if not bars or not bars.hotkeySetExists or not preflightPresetEdits(bars) then
        return showPresetApplyError()
    end

    for _, operation in ipairs(presetEdits.operations) do
        local status
        local result
        if operation.action == 'add' then
            status, result = pcall(bars.createHotkeySet, operation.name)
            if not status or not result then return showPresetApplyError() end
            status = pcall(Keybind.newPreset, operation.name)
            if not status or not Keybind.presetToIndex[operation.name] then
                bars.removeHotkeySet(operation.name)
                return showPresetApplyError()
            end
        elseif operation.action == 'copy' then
            status, result = pcall(bars.createHotkeySet, operation.name, operation.source, operation.barSnapshot)
            if not status or not result then return showPresetApplyError() end
            status, result = pcall(Keybind.copyPreset, operation.source, operation.name)
            if not status or not result then
                bars.removeHotkeySet(operation.name)
                return showPresetApplyError()
            end
        elseif operation.action == 'rename' then
            status, result = pcall(bars.renameHotkeySet, operation.source, operation.name)
            if not status or not result then return showPresetApplyError() end
            status = pcall(Keybind.renamePreset, operation.source, operation.name)
            if not status or not Keybind.presetToIndex[operation.name] or Keybind.presetToIndex[operation.source] then
                bars.renameHotkeySet(operation.name, operation.source)
                return showPresetApplyError()
            end
        elseif operation.action == 'remove' then
            local barSnapshot = bars.ApiJson.getHotkeySetSnapshot(operation.name)
            status, result = pcall(bars.removeHotkeySet, operation.name)
            if not status or not result then return showPresetApplyError() end
            if Keybind.currentPreset == operation.name then
                for _, name in ipairs(Keybind.presets) do
                    if name ~= operation.name then Keybind.selectPreset(name);break end
                end
            end
            status, result = pcall(Keybind.removePreset, operation.name)
            if not status or not result then
                bars.createHotkeySet(operation.name, nil, barSnapshot)
                return showPresetApplyError()
            end
        end
    end
    for name, entry in pairs(presetEdits.entries) do
        if entry.keys then
            changedKeybinds[name] = changedKeybinds[name] or {}
            for mode, keys in pairs(entry.keys) do
                changedKeybinds[name][mode] = changedKeybinds[name][mode] or {}
                for index, value in pairs(keys) do
                    if not changedKeybinds[name][mode][index] then changedKeybinds[name][mode][index] = table.recursivecopy(value) end
                end
            end
        end
        if entry.hotkeys then
            Keybind.selectPreset(name)
            for mode = CHAT_MODE.ON, CHAT_MODE.OFF do
                for i in ipairs(Keybind.hotkeys[mode][name] or {}) do Keybind.unbindHotkey(i, mode) end
                Keybind.hotkeys[mode][name] = table.recursivecopy(entry.hotkeys[mode])
                Keybind.configs.hotkeys[name]:setNode(mode, Keybind.hotkeys[mode][name])
                for i in ipairs(Keybind.hotkeys[mode][name]) do Keybind.bindHotkey(i, mode) end
            end
            Keybind.configs.hotkeys[name]:save()
        end
    end
    Keybind.selectPreset(presetEdits.selected)
    if not bars.selectHotkeySet(presetEdits.selected) then return showPresetApplyError() end
    g_settings.setValue('controls-preset-current', presetEdits.selected)
    presetEdits = nil
    return true
end

function applyChangedOptions()
    if not applyPresetEdits() then return false end
    local needKeybindsUpdate = false
    local needHotkeysUpdate = false

    for key, option in pairs(changedOptions) do
        if key == 'resetKeybinds' then
            Keybind.resetKeybindsToDefault(option.value, option.chatMode)
            needKeybindsUpdate = true
        end
    end
    changedOptions = {}

    for preset, modes in pairs(changedKeybinds) do
        for chatMode, keybinds in pairs(modes) do
            for _, keybind in pairs(keybinds) do
                Keybind.setPrimaryActionKey(keybind.category, keybind.action, preset, keybind.primary, chatMode)
                Keybind.setSecondaryActionKey(keybind.category, keybind.action, preset, keybind.secondary, chatMode)
                needKeybindsUpdate = true
            end
        end
        Keybind.configs.keybinds[preset]:save()
    end
    changedKeybinds = {}

    local selected = Keybind.currentPreset
    for preset, modes in pairs(changedHotkeys) do
        Keybind.selectPreset(preset)
        for mode, hotkeys in pairs(modes) do
            for i in ipairs(Keybind.hotkeys[mode][preset] or {}) do Keybind.unbindHotkey(i, mode) end
            Keybind.hotkeys[mode][preset] = table.recursivecopy(hotkeys)
            Keybind.configs.hotkeys[preset]:setNode(mode, Keybind.hotkeys[mode][preset])
            for i in ipairs(Keybind.hotkeys[mode][preset]) do Keybind.bindHotkey(i, mode) end
        end
        Keybind.configs.hotkeys[preset]:save()
        needKeybindsUpdate = true
    end
    changedHotkeys = {}
    Keybind.selectPreset(selected)

    if needKeybindsUpdate then
        updateKeybinds()
    end
    g_settings.save()
    return true
end

function presetOption(widget, key, value, force)
    if not controller.ui:isVisible() then
        return
    end

    changedOptions[key] = { widget = widget, value = value, force = force }
    if key == "currentPreset" then
        beginPresetEdits()
        if not presetEdits.entries[value] then return end
        presetEdits.selected = value
        presetEdits.selectionChanged = true
        panels.keybindsPanel.presets.list:setCurrentOption(value, true)
    end
end

function init_binds()
    chatModeGroup = UIRadioGroup.create()
    chatModeGroup:addWidget(panels.keybindsPanel.panel.chatMode.on)
    chatModeGroup:addWidget(panels.keybindsPanel.panel.chatMode.off)
    chatModeGroup.onSelectionChange = chatModeChange
    chatModeGroup:selectWidget(panels.keybindsPanel.panel.chatMode.on)

    keyEditWindow = g_ui.displayUI("styles/controls/key_edit")
    keyEditWindow:hide()
    presetWindow = g_ui.displayUI("styles/controls/preset")
    presetWindow:hide()
    panels.keybindsPanel.presets.add.onClick = addNewPreset
    panels.keybindsPanel.presets.copy.onClick = copyPreset
    panels.keybindsPanel.presets.rename.onClick = renamePreset
    panels.keybindsPanel.presets.remove.onClick = removePreset
    panels.keybindsPanel.buttons.newAction:disable()
    panels.keybindsPanel.buttons.newAction.onClick = newHotkeyAction
    panels.keybindsPanel.buttons.reset.onClick = resetActions
    panels.keybindsPanel.search.field.onTextChange = searchActions
    panels.keybindsPanel.search.clear.onClick = function() panels.keybindsPanel.search.field:clearText() end
    presetWindow.onEnter = okPresetWindow
    presetWindow.onEscape = cancelPresetWindow
    presetWindow.buttons.ok.onClick = okPresetWindow
    presetWindow.buttons.cancel.onClick = cancelPresetWindow
    if g_platform.isMobile() then
        panels.keybindsPanel.tablePanel:hide()
    end
end

function terminate_binds()
    if presetWindow then
        presetWindow:destroy()
        presetWindow = nil
    end

    if chatModeGroup then
        chatModeGroup:destroy()
        chatModeGroup = nil
    end

    if keyEditWindow then
        if keyEditWindow:isVisible() then
            keyEditWindow:ungrabKeyboard()
            disconnect(keyEditWindow, { onKeyDown = editKeybindKeyDown })
        end
        keyEditWindow:destroy()
        keyEditWindow = nil
    end

    actionSearchEvent = nil
end

function listKeybindsComboBox(value)
    local widget = panels.keybindsPanel.presets.list
    presetOption(widget, 'currentPreset', value, false)
    updateKeybinds()
end

function debug()
    local currentOptionText = Keybind.currentPreset
    local chatMode = Keybind.chatMode
    local chatModeText = (chatMode == 1) and "Chat mode ON" or (chatMode == 2) and "Chat mode OFF" or "Unknown chat mode"
    print(string.format("The current configuration is: %s, and the mode is: %s", currentOptionText, chatModeText))
end
