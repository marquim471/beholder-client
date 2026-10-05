-- Stone system window. Server side: data/libs/systems/stone_system.lua (Canary), extended JSON opcode.
stoneSystemWindow = nil
stoneSystemButton = nil

STONE_OPCODE = 145

local COLORS = {
    { key = 'black', name = 'Preta', element = 'death', helmet = 'skill' },
    { key = 'purple', name = 'Roxa', element = 'energy', helmet = 'momentum' },
    { key = 'red', name = 'Vermelha', element = 'fire', helmet = 'ruse' },
    { key = 'white', name = 'Branca', element = 'physical', helmet = 'criticalDamage' },
    { key = 'yellow', name = 'Amarela', element = 'holy', helmet = 'onslaught' },
    { key = 'green', name = 'Verde', element = 'earth', helmet = 'criticalChance' },
    { key = 'blue', name = 'Azul', element = 'ice', helmet = 'transcendence' },
    { key = 'orange', name = 'Laranja', element = 'adaptive', helmet = 'rusePenetration' },
}
local ELEMENT_NAMES = {
    { 'fire', 'Fire' }, { 'ice', 'Ice' }, { 'holy', 'Holy' }, { 'death', 'Death' }, { 'energy', 'Energy' },
    { 'earth', 'Earth' }, { 'physical', 'Physical' }, { 'adaptive', 'Adaptive' }
}
local SPECIAL_NAMES = {
    { 'skill', 'Skill', true }, { 'momentum', 'Momentum' }, { 'ruse', 'Ruse' }, { 'criticalDamage', 'Critical damage' },
    { 'onslaught', 'Onslaught' }, { 'criticalChance', 'Critical chance' }, { 'transcendence', 'Transcendence' },
    { 'rusePenetration', 'Ruse penetration' }
}
-- Values with one stone, by level (same table as the server)
local ELEMENT = { 1.00, 1.40, 2.00, 2.75, 4.00, 6.00, 10.00, 16.00, 28.00 }
local HELMET_DOUBLE = { 2.00, 2.80, 4.00, 5.50, 8.00, 12.00, 20.00, 32.00, 40.00 }
local SKILL = { 0, 1, 1, 2, 3, 4, 5, 10, 16 }

-- Equipment map: position inside the 392x364 panel, slot image, stone slot (nil = not available yet)
local PIECES = {
    { id = 'helmet', slot = 'helmet', icon = 'slot_head', x = 170, y = 14, max = 3, label = 'Capacete' },
    { id = 'armor', slot = 'armor', icon = 'slot_body', x = 170, y = 120, max = 3, label = 'Armadura' },
    { id = 'weapon', slot = 'weapon', icon = 'slot_left_hand', x = 44, y = 150, max = 3, label = 'Arma' },
    { id = 'shield', slot = 'shield', icon = 'slot_right_hand', x = 296, y = 150, max = 4, label = 'Escudo' },
    { id = 'amulet', icon = 'slot_neck', x = 62, y = 50, label = 'Amuleto' },
    { id = 'ring', icon = 'slot_finger', x = 62, y = 262, label = 'Anel' },
    { id = 'legs', icon = 'slot_legs', x = 170, y = 222, label = 'Pernas' },
    { id = 'boots', icon = 'slot_feet', x = 296, y = 262, label = 'Botas' },
}

local state = nil
local selectedStone = nil   -- "color_level" chosen in the inventory list
local selectedUpgrade = nil -- "color_level" chosen in the upgrade list
local pieces = {}

local function stoneId(color, level)
    return 60000 + (color - 1) * 10 + level
end

local function parseKey(key)
    local color, level = tostring(key or ''):match('^(%d+)_(%d+)$')
    return tonumber(color), tonumber(level)
end

local function stoneName(color, level)
    return COLORS[color].name .. ' Stone Nivel ' .. level
end

local function formatPercent(value)
    return string.format('+%s%%', (string.format('%.2f', value):gsub('%.?0+$', '')))
end

local function helmetValue(effect, level)
    if effect == 'skill' then
        return SKILL[level]
    elseif effect == 'momentum' or effect == 'criticalDamage' then
        return HELMET_DOUBLE[level]
    end
    return ELEMENT[level]
end

local function send(data)
    local protocol = g_game.getProtocolGame()
    if protocol then
        protocol:sendExtendedJSONOpcode(STONE_OPCODE, data)
    end
end

local function bindChildren(widget)
    for _, child in ipairs(widget:getChildren()) do
        local id = child:getId()
        if id and id ~= '' then
            widget[id] = child
        end
        bindChildren(child)
    end
end

-- Lifecycle --------------------------------------------------------------------------------------

function init()
    stoneSystemWindow = g_ui.displayUI('stonesystem')
    stoneSystemWindow:hide()
    bindChildren(stoneSystemWindow)

    stoneSystemButton = modules.game_mainpanel.addToggleButton('stoneSystemButton', tr('Stones System'),
        '/game_stonesystem/images/button_stones', toggle, false, 27)
    stoneSystemButton:setOn(false)

    stoneSystemWindow.inventoryTab.icon:setItemId(stoneId(7, 7))
    stoneSystemWindow.upgradeTab.icon:setItemId(stoneId(3, 8))

    for _, page in ipairs({ stoneSystemWindow.inventoryPage.listPanel, stoneSystemWindow.upgradePage.listPanel }) do
        page.colorFilter:addOption('Todas cores', 0)
        for index, color in ipairs(COLORS) do
            page.colorFilter:addOption(color.name, index)
        end
        page.levelFilter:addOption('Todos niveis', 0)
        for level = 1, 9 do
            page.levelFilter:addOption('Nivel ' .. level, level)
        end
    end
    local inventoryList = stoneSystemWindow.inventoryPage.listPanel
    inventoryList.colorFilter.onOptionChange = refreshInventoryList
    inventoryList.levelFilter.onOptionChange = refreshInventoryList
    local upgradeList = stoneSystemWindow.upgradePage.listPanel
    upgradeList.colorFilter.onOptionChange = refreshUpgradeList
    upgradeList.levelFilter.onOptionChange = refreshUpgradeList

    buildEquipment()

    ProtocolGame.registerExtendedJSONOpcode(STONE_OPCODE, onExtendedOpcode)
    connect(g_game, { onGameEnd = hide })
end

function terminate()
    ProtocolGame.unregisterExtendedJSONOpcode(STONE_OPCODE)
    disconnect(g_game, { onGameEnd = hide })
    stoneSystemWindow:destroy()
    stoneSystemButton:destroy()
    stoneSystemWindow = nil
    stoneSystemButton = nil
end

function toggle()
    if stoneSystemWindow:isVisible() then
        hide()
    else
        show()
    end
end

function show()
    stoneSystemWindow:show()
    stoneSystemWindow:raise()
    stoneSystemWindow:focus()
    stoneSystemButton:setOn(true)
    send({ action = 'request' })
end

function hide()
    if stoneSystemWindow then
        stoneSystemWindow:hide()
    end
    if stoneSystemButton then
        stoneSystemButton:setOn(false)
    end
end

function selectPage(page)
    stoneSystemWindow.inventoryPage:setVisible(page == 'inventory')
    stoneSystemWindow.upgradePage:setVisible(page == 'upgrade')
    stoneSystemWindow.inventoryTab:setChecked(page == 'inventory')
    stoneSystemWindow.upgradeTab:setChecked(page == 'upgrade')
end

function onExtendedOpcode(protocol, opcode, data)
    if type(data) ~= 'table' then
        return
    end
    if data.type == 'state' then
        state = data
        refreshAll()
    end
end

-- Equipment map ----------------------------------------------------------------------------------

function buildEquipment()
    local panel = stoneSystemWindow.inventoryPage.equipmentPanel
    for _, def in ipairs(PIECES) do
        local piece = g_ui.createWidget('EquipPiece', panel)
        bindChildren(piece)
        piece:setId('piece_' .. def.id)
        piece:addAnchor(AnchorTop, 'parent', AnchorTop)
        piece:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        piece:setMarginTop(def.y)
        piece:setMarginLeft(def.x)
        piece.icon:setImageSource('/game_stonesystem/images/' .. def.icon)
        piece:setTooltip(def.label .. (def.slot and '' or ' (em breve)'))
        piece.sockets = {}
        if not def.slot then
            piece.lock:show()
            piece.icon:setOpacity(0.35)
        else
            local width = def.max * 22 + (def.max - 1) * 2
            for index = 1, def.max do
                local socket = g_ui.createWidget('StoneSocket', panel)
                bindChildren(socket)
                socket:addAnchor(AnchorTop, piece:getId(), AnchorBottom)
                socket:addAnchor(AnchorLeft, piece:getId(), AnchorLeft)
                socket:setMarginTop(4)
                socket:setMarginLeft(26 - width / 2 + (index - 1) * 24)
                socket.slot = def.slot
                socket.index = index
                socket.onMouseRelease = function(widget, mousePos, button)
                    onSocketClick(widget, button)
                    return true
                end
                piece.sockets[index] = socket
            end
        end
        pieces[def.id] = piece
    end
end

function onSocketClick(socket, button)
    if not state or socket.locked then
        return
    end
    if button == MouseRightButton then
        send({ action = 'unequip', slot = socket.slot, index = socket.index })
    elseif selectedStone then
        send({ action = 'equip', slot = socket.slot, index = socket.index, stone = selectedStone })
    end
end

local function refreshEquipment()
    local preset = state.presets[state.active]
    for _, def in ipairs(PIECES) do
        local piece = pieces[def.id]
        if def.slot then
            local capacity = state.capacity[def.slot] or 0
            for index, socket in ipairs(piece.sockets) do
                socket.locked = index > capacity
                socket.lock:setVisible(socket.locked)
                local color, level = parseKey(preset and preset.slots[def.slot][index])
                if color and not socket.locked then
                    socket.item:setItemId(stoneId(color, level))
                    socket.item:show()
                    socket.level:setText(level)
                    socket:setTooltip(stoneName(color, level) .. '\nBotao direito: tirar')
                else
                    socket.item:setItemId(0)
                    socket.item:hide()
                    socket.level:setText('')
                    socket:setTooltip(socket.locked and 'Encaixe bloqueado (VIP ou Permanent Stones Slots)' or 'Encaixe livre')
                end
            end
        end
    end
end

-- Inventory list ---------------------------------------------------------------------------------

local function matchesFilters(panel, color, level)
    local wantedColor = panel.colorFilter:getCurrentOption() and panel.colorFilter:getCurrentOption().data or 0
    local wantedLevel = panel.levelFilter:getCurrentOption() and panel.levelFilter:getCurrentOption().data or 0
    if wantedColor ~= 0 and wantedColor ~= color then
        return false
    end
    if wantedLevel ~= 0 and wantedLevel ~= level then
        return false
    end
    local search = panel.search:getText():lower()
    return search == '' or stoneName(color, level):lower():find(search, 1, true) ~= nil
end

function refreshInventoryList()
    if not state then
        return
    end
    local panel = stoneSystemWindow.inventoryPage.listPanel
    panel.list:destroyChildren()
    for _, entry in ipairs(state.inventory) do
        local show = matchesFilters(panel, entry.color, entry.level)
        if show and not panel.showEquipped:isChecked() and entry.free <= 0 then
            show = false
        end
        if show then
            local widget = g_ui.createWidget('StoneListItem', panel.list)
            local key = entry.color .. '_' .. entry.level
            widget:setItemId(entry.item)
            widget:setItemCount(entry.count)
            widget:getChildById('level'):setText(entry.level)
            widget:setTooltip(string.format('%s\nQuantidade: %d (livres: %d)\nClique e depois clique num encaixe.', stoneName(entry.color, entry.level), entry.count, entry.free))
            widget:setBorderWidth(key == selectedStone and 1 or 0)
            widget.onClick = function()
                selectedStone = key
                refreshInventoryList()
            end
        end
    end
end

-- Summary and presets ------------------------------------------------------------------------------

local function refreshSummary()
    local list = stoneSystemWindow.inventoryPage.summaryPanel.list
    list:destroyChildren()
    local bonuses = state.bonuses or {}
    local function header(text)
        local widget = g_ui.createWidget('SummaryHeader', list)
        widget:setText(text)
    end
    local function row(name, value, isFlat)
        local widget = g_ui.createWidget('SummaryRow', list)
        bindChildren(widget)
        widget.name:setText(name .. ':')
        widget.value:setText(isFlat and ('+' .. (value or 0)) or formatPercent(value or 0))
        if (value or 0) > 0 then
            widget.value:setColor('#c0dea0')
        end
    end
    header('Danos adicionais')
    for _, e in ipairs(ELEMENT_NAMES) do
        row(e[2] .. ' damage', (bonuses.damage or {})[e[1]])
    end
    header('Resistencias elementais')
    for _, e in ipairs(ELEMENT_NAMES) do
        row(e[2] .. ' resistance', (bonuses.protection or {})[e[1]])
    end
    header('Especiais')
    for _, s in ipairs(SPECIAL_NAMES) do
        row(s[2], (bonuses.special or {})[s[1]], s[3])
    end
    header('Resistencia a magias (escudo)')
    for _, e in ipairs(ELEMENT_NAMES) do
        row(e[2] .. ' spells', (bonuses.spell or {})[e[1]])
    end
end

local function refreshPresets()
    local list = stoneSystemWindow.inventoryPage.presetsPanel.list
    list:destroyChildren()
    for index, preset in ipairs(state.presets) do
        local label = g_ui.createWidget('Label', list)
        label:setText(preset.name .. (index == state.active and '  (ativo)' or ''))
        label:setPhantom(false)
        label:setFocusable(true)
        label:setHeight(16)
        label.presetIndex = index
        label:setColor(index == state.active and '#e8c26a' or '#c0c0c0')
        if index == state.active then
            list:focusChild(label, ActiveFocusReason)
        end
    end
    local preset = state.presets[state.active]
    stoneSystemWindow.presetLabel:setText("Preset selecionado: '" .. (preset and preset.name or '') .. "'")
end

local function focusedPreset()
    local focused = stoneSystemWindow.inventoryPage.presetsPanel.list:getFocusedChild()
    return focused and focused.presetIndex
end

function createPreset()
    send({ action = 'preset_create', name = 'Preset ' .. ((state and #state.presets or 0) + 1) })
end

function removePreset()
    local index = focusedPreset()
    if index then
        send({ action = 'preset_remove', index = index })
    end
end

function selectPreset()
    local index = focusedPreset()
    if index then
        send({ action = 'preset_select', index = index })
    end
end

-- Upgrade page -----------------------------------------------------------------------------------

local function owned(key)
    for _, entry in ipairs(state.inventory) do
        if entry.color .. '_' .. entry.level == key then
            return entry
        end
    end
    return { count = 0, free = 0 }
end

function refreshUpgradeList()
    if not state then
        return
    end
    local panel = stoneSystemWindow.upgradePage.listPanel
    panel.list:destroyChildren()
    for color = 1, #COLORS do
        for level = 1, 9 do
            if matchesFilters(panel, color, level) then
                local key = color .. '_' .. level
                local entry = owned(key)
                local widget = g_ui.createWidget('StoneListItem', panel.list)
                widget:setItemId(stoneId(color, level))
                widget:setItemCount(math.max(1, entry.count))
                widget:getChildById('level'):setText(level)
                widget:setShowCount(entry.count > 0)
                widget:setOpacity(entry.count > 0 and 1 or 0.4)
                widget:setTooltip(string.format('%s\nVoce tem: %d (livres: %d)', stoneName(color, level), entry.count, entry.free))
                widget:setBorderWidth(key == selectedUpgrade and 1 or 0)
                widget.onClick = function()
                    selectedUpgrade = key
                    refreshUpgradeList()
                    refreshAltar()
                end
            end
        end
    end
end

function refreshAltar()
    local page = stoneSystemWindow.upgradePage
    local altar, info = page.altarPanel, page.infoPanel
    local color, level = parseKey(selectedUpgrade)
    if not color then
        altar.banner:setText('Escolha uma pedra na lista')
        for i = 1, 3 do
            altar['socket' .. i].item:setItemId(0)
        end
        altar.result.item:setItemId(0)
        info.item:setItemId(0)
        info.name:setText('')
        info.stage:setText('')
        info.color:setText('')
        info.bonuses:destroyChildren()
        info.chanceBox.chance:setText('')
        info.chanceBox.progressBar:setWidth(0)
        info.chanceBox.requirement:setText('')
        info.chanceBox.upgrade:setEnabled(false)
        info.cost.text:setText('-')
        return
    end
    local entry = owned(selectedUpgrade)
    local nextLevel = math.min(9, level + 1)
    altar.banner:setText(stoneName(color, level))
    for i = 1, 3 do
        local item = altar['socket' .. i].item
        item:setItemId(stoneId(color, level))
        item:setOpacity(entry.free >= i and 1 or 0.3)
    end
    altar.result.item:setItemId(level < 9 and stoneId(color, nextLevel) or 0)

    info.item:setItemId(stoneId(color, nextLevel))
    info.name:setText(stoneName(color, nextLevel))
    info.stage:setText('Estagio: ' .. nextLevel)
    info.color:setText('Cor: ' .. COLORS[color].name)
    info.bonuses:destroyChildren()
    local def = COLORS[color]
    local helmetLabel = def.helmet
    for _, sName in ipairs(SPECIAL_NAMES) do
        if sName[1] == def.helmet then
            helmetLabel = sName[2]
        end
    end
    local rows = {
        { helmetLabel, 'Apenas no capacete', def.helmet == 'skill' and ('+' .. SKILL[nextLevel]) or formatPercent(helmetValue(def.helmet, nextLevel)) },
        { def.element .. ' damage', 'Apenas na arma', formatPercent(ELEMENT[nextLevel]) },
        { def.element .. ' resistance', 'Apenas na armadura', formatPercent(ELEMENT[nextLevel]) },
    }
    for _, r in ipairs(rows) do
        local widget = g_ui.createWidget('UpgradeBonusRow', info.bonuses)
        bindChildren(widget)
        widget.item:setItemId(stoneId(color, nextLevel))
        widget.title:setText(r[1]:gsub('^%l', string.upper))
        widget.where:setText(r[2])
        widget.value:setText('Valor: ' .. r[3])
    end

    local upgrade = state.upgrade and state.upgrade[level]
    local box = info.chanceBox
    if level >= 9 or not upgrade then
        box.chance:setText('Nivel maximo')
        box.progressBar:setWidth(0)
        box.requirement:setText('')
        box.upgrade:setEnabled(false)
        info.cost.text:setText('-')
        return
    end
    box.chance:setText('Chance de sucesso: ' .. upgrade.chance .. '%')
    -- Same wooden bar as the special task: 186 px is full.
    box.progressBar:setWidth(math.floor(186 * math.min(100, upgrade.chance) / 100))
    local hasStones = entry.free >= 3
    local hasGold = (state.gold or 0) >= upgrade.cost
    if not hasStones then
        box.requirement:setText('Faltam pedras livres (' .. entry.free .. '/3)')
        box.requirement:setColor('#de7575')
    elseif not hasGold then
        box.requirement:setText('Gold insuficiente')
        box.requirement:setColor('#de7575')
    else
        box.requirement:setText('Pronto para evoluir')
        box.requirement:setColor('#88de75')
    end
    box.upgrade:setEnabled(hasStones and hasGold and not state.pzLocked)
    info.cost.text:setText(comma_value(upgrade.cost))
end

function upgradeSelected()
    if selectedUpgrade then
        send({ action = 'upgrade', stone = selectedUpgrade })
    end
end

-- Everything -------------------------------------------------------------------------------------

function refreshAll()
    if not state then
        return
    end
    refreshEquipment()
    refreshInventoryList()
    refreshSummary()
    refreshPresets()
    refreshUpgradeList()
    refreshAltar()
    stoneSystemWindow.gold.text:setText(comma_value(state.gold or 0))
    stoneSystemWindow.pzWarning:setVisible(state.pzLocked == true)
    if not stoneSystemWindow.inventoryTab:isChecked() and not stoneSystemWindow.upgradeTab:isChecked() then
        selectPage('inventory')
    end
end
