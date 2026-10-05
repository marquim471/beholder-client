local iconTopMenu = nil

local inventoryShrink = false

local pvpModeRadioGroup = nil
local compactPvpModeRadioGroup = nil
local updatingExpertMode = false
local monkMirrorItem = nil
local updatingCombatControls = false

local function getInventoryUi()
    if inventoryShrink then
        return inventoryController.ui.offPanel
    end

    return inventoryController.ui.onPanel
end

local getSlotPanelBySlot = {
    [InventorySlotHead] = function(ui) return ui.helmet, ui.helmet.helmet end,
    [InventorySlotNeck] = function(ui) return ui.amulet, ui.amulet.amulet end,
    [InventorySlotBack] = function(ui) return ui.backpack, ui.backpack.backpack end,
    [InventorySlotBody] = function(ui) return ui.armor, ui.armor.armor end,
    [InventorySlotRight] = function(ui) return ui.shield, ui.shield.shield end,
    [InventorySlotLeft] = function(ui) return ui.sword, ui.sword.sword end,
    [InventorySlotLeg] = function(ui) return ui.legs, ui.legs.legs end,
    [InventorySlotFeet] = function(ui) return ui.boots, ui.boots.boots end,
    [InventorySlotFinger] = function(ui) return ui.ring, ui.ring.ring end,
    [InventorySlotAmmo] = function(ui) return ui.tools, ui.tools.tools end
}

local function isPlayerMonk()
    local player = g_game.getLocalPlayer()
    if not player then
        return false
    end
    return player:isMonk()
end

local function updateMonkMirrorItem(leftItem)
    if not g_game.getFeature(GameVocationMonk) then
        return
    end
    if inventoryShrink then
        return
    end

    local ui = getInventoryUi()
    if not ui or not ui.shield or not ui.shield.item then
        return
    end

    local shieldSlot = ui.shield
    local shieldItemWidget = shieldSlot.item

    if not isPlayerMonk() then
        if monkMirrorItem then
            monkMirrorItem = nil
        end
        return
    end

    local player = g_game.getLocalPlayer()
    local realShieldItem = player and player:getInventoryItem(InventorySlotRight)

    if realShieldItem then
        monkMirrorItem = nil
        return
    end

    if leftItem then
        monkMirrorItem = leftItem
        shieldItemWidget:setItem(leftItem)
        shieldSlot:setOpacity(0.5)
        shieldItemWidget:setOpacity(1.0)
        shieldItemWidget:setDraggable(false)
        shieldItemWidget:setEnabled(false)
        shieldItemWidget:setFlipDirection(FlipDirection.Horizontal)
        shieldSlot.shield:setEnabled(false)
    else
        monkMirrorItem = nil
        shieldItemWidget:setItem(nil)
        shieldSlot:setOpacity(1.0)
        shieldItemWidget:setOpacity(1.0)
        shieldItemWidget:setDraggable(true)
        shieldItemWidget:setEnabled(true)
        shieldItemWidget:setFlipDirection(FlipDirection.None)
        shieldSlot.shield:setEnabled(true)
        if shieldItemWidget.tier then
            shieldItemWidget.tier:setVisible(false)
        end
    end
end


local function walkEvent()
    if modules.client_options.getOption('autoChaseOverride') then
        if g_game.isAttacking() and g_game.getChaseMode() == ChaseOpponent then
            selectPosture('stand', false)
        end
    end
end

local function combatEvent()
    if g_game.getChaseMode() == ChaseOpponent then
        selectPosture('follow', true)
    else
        selectPosture('stand', true)
    end
    
    if not g_game.getFeature(GameTacticsWithoutFightMode) then
        if g_game.getFightMode() == FightOffensive then
            selectCombat('attack', true)
        elseif g_game.getFightMode() == FightBalanced then
            selectCombat('balanced', true)
        elseif g_game.getFightMode() == FightDefensive then
            selectCombat('defense', true)
        end
    end
    updatingCombatControls = true
    for _, ui in ipairs({inventoryController.ui.onPanel, inventoryController.ui.offPanel}) do
        ui.pvp:setChecked(not g_game.isSafeFight())
        if g_game.isSafeFight() then
            ui.pvp:setTooltip(tr("Secure Mode On: You are able to attack only those players\nyour expert mode allows. You risk skulls and protection zone\nblocks depending on your active expert mode."))
        else
            ui.pvp:setTooltip(tr("Secure Mode Off: You are able to attack someone by targeting,\nregardless of your expert mode. You risk white, red and black\nskulls as well as a protection zone block."))
        end
    end
    updatingCombatControls = false

    local buttonId = 'whiteDoveBox'
    if g_game.getPVPMode() == PVPWhiteHand then
        buttonId = 'whiteHandBox'
    elseif g_game.getPVPMode() == PVPYellowHand then
        buttonId = 'yellowHandBox'
    elseif g_game.getPVPMode() == PVPRedFist then
        buttonId = 'redFistBox'
    end
    if pvpModeRadioGroup then
        pvpModeRadioGroup:selectWidget(inventoryController.ui.onPanel[buttonId], true)
        compactPvpModeRadioGroup:selectWidget(inventoryController.ui.offPanel[buttonId], true)
        for _, ui in ipairs({inventoryController.ui.onPanel, inventoryController.ui.offPanel}) do
            for _, id in ipairs({'whiteDoveBox', 'whiteHandBox', 'yellowHandBox', 'redFistBox'}) do
                ui[id]:setChecked(id == buttonId)
                ui[id]:setVisible(ui.expert:isChecked() and g_game.getFeature(GamePVPMode) and g_game.getExpertPvpMode())
            end
        end
    end
end

local function inventoryEvent(player, slot, item, oldItem)
    if inventoryShrink then
        return
    end

    local ui = getInventoryUi()
    local getSlotInfo = getSlotPanelBySlot[slot]
    if not getSlotInfo then
        return
    end

    if slot == InventorySlotRight and isPlayerMonk() and not item and monkMirrorItem then
        return
    end

    if slot == InventorySlotRight then
        local slotPanel, toggler = getSlotInfo(ui)
        slotPanel:setOpacity(1.0)
        slotPanel.item:setOpacity(1.0)
        slotPanel.item:setDraggable(true)
        slotPanel.item:setEnabled(true)
        slotPanel.item:setFlipDirection(FlipDirection.None)
        monkMirrorItem = nil
    end

    local slotPanel, toggler = getSlotInfo(ui)

    slotPanel.item:setItem(item)
    toggler:setEnabled(not item)
    slotPanel.item:setWidth(34)
    slotPanel.item:setHeight(34)
    
    slotPanel.item:setShowDuration(g_game.getFeature(GameThingClock) and modules.client_options.getOption('showExpiryInInvetory'))
    slotPanel.item:setShowCharges(g_game.getFeature(GameThingCounter) and modules.client_options.getOption('showExpiryInInvetory'))
    slotPanel.item:setShowExpiryOnUnused(modules.client_options.getOption('showExpiryOnUnusedItems'))
    ItemsDatabase.setTier(slotPanel.item, item)

    if slot == InventorySlotLeft then
        if item and modules.game_proficiency then
            g_game.sendWeaponProficiencyAction(WeaponProficiency.WEAPON_PROFICIENCY_ITEM_INFO, item:getId())
            modules.game_proficiency.updateTopBarProficiency()
        end
        updateMonkMirrorItem(item)
    elseif slot == InventorySlotRight and not item then
        updateMonkMirrorItem(player and player:getInventoryItem(InventorySlotLeft))
    end
end

local function onSoulChange(localPlayer, soul)
    local ui = getInventoryUi()
    if not localPlayer then
        return
    end
    if not soul then
        return
    end

    if ui.soulPanel and ui.soulPanel.soul then
        ui.soulPanel.soul:setText(soul)
    end

    if ui.soulAndCapacity and ui.soulAndCapacity.soul then
        ui.soulAndCapacity.soul:setText(soul)
    end
end

local function onFreeCapacityChange(player, freeCapacity)
    if not player then
        return
    end

    if not freeCapacity then
        return
    end
    local color = '#bfbfbf'
    local totalCapacity = player:getTotalCapacity()
    local baseCapacity = player:getBaseCapacity()
    if player:hasZeroCapacity() then
        color = '#d33c3c'
    elseif baseCapacity > 0 and baseCapacity ~= 4294967295 and totalCapacity > baseCapacity then
        color = '#44ad25'
    end

    local ui = getInventoryUi()
    if ui.capacityPanel and ui.capacityPanel.capacity then
        ui.capacityPanel.capacity:setText(freeCapacity)
        ui.capacityPanel.capacity:setColor(color)
    end
    if ui.soulAndCapacity and ui.soulAndCapacity.capacity then
        ui.soulAndCapacity.capacity:setText(freeCapacity)
        ui.soulAndCapacity.capacity:setColor(color)
    end
end

local function onCapacityChange(player)
    if player then
        onFreeCapacityChange(player, player:getFreeCapacity())
    end
end

function getIconsPanelOn()
    return inventoryController.ui.onPanel.icons
end

function getIconsPanelOff()
    return inventoryController.ui.offPanel.icons
end

local function refreshInventory_panel()
    local player = g_game.getLocalPlayer()
    if player then
        onSoulChange(player, player:getSoul())
        onFreeCapacityChange(player, player:getFreeCapacity())
    end
    if inventoryShrink then
        return
    end

    for i = InventorySlotFirst, InventorySlotPurse do
        if g_game.isOnline() then
            inventoryEvent(player, i, player:getInventoryItem(i))
        else
            inventoryEvent(player, i, nil)
        end
    end
end

local function refreshInventorySizes()
    if inventoryShrink then
        inventoryController.ui:setOn(false)
        inventoryController.ui.onPanel:hide()
        inventoryController.ui.offPanel:show()
    else
        inventoryController.ui:setOn(true)
        inventoryController.ui.onPanel:show()
        inventoryController.ui.offPanel:hide()
        refreshInventory_panel()
    end
    combatEvent()
    walkEvent()
    modules.game_mainpanel.reloadMainPanelSizes()
end

function onSetChaseMode(self, selectedChaseModeButton)
    if selectedChaseModeButton == nil then
        return
    end
    
    local buttonId = selectedChaseModeButton:getId()
    local chaseMode
    if buttonId == 'followPosture' then
        chaseMode = ChaseOpponent
    else
        chaseMode = DontChase
    end
    g_game.setChaseMode(chaseMode)
end

inventoryController = Controller:new()
inventoryController:setUI('inventory', modules.game_interface.getMainRightPanel())

function inventoryController:onInit()
    refreshInventory_panel()
    local ui = getInventoryUi()

    connect(inventoryController.ui.onPanel.pvp, {
        onCheckChange = onSetSafeFight
    })
    connect(inventoryController.ui.offPanel.pvp, {
        onCheckChange = onSetSafeFight
    })
    connect(inventoryController.ui.onPanel.expert, {
        onCheckChange = expertMode
    })
    connect(inventoryController.ui.offPanel.expert, {
        onCheckChange = expertMode
    })
    pvpModeRadioGroup = UIRadioGroup.create()
    pvpModeRadioGroup:addWidget(inventoryController.ui.onPanel.whiteDoveBox)
    pvpModeRadioGroup:addWidget(inventoryController.ui.onPanel.whiteHandBox)
    pvpModeRadioGroup:addWidget(inventoryController.ui.onPanel.yellowHandBox)
    pvpModeRadioGroup:addWidget(inventoryController.ui.onPanel.redFistBox)
    connect(pvpModeRadioGroup, {
        onSelectionChange = onSetPVPMode
    })
    compactPvpModeRadioGroup = UIRadioGroup.create()
    compactPvpModeRadioGroup:addWidget(inventoryController.ui.offPanel.whiteDoveBox)
    compactPvpModeRadioGroup:addWidget(inventoryController.ui.offPanel.whiteHandBox)
    compactPvpModeRadioGroup:addWidget(inventoryController.ui.offPanel.yellowHandBox)
    compactPvpModeRadioGroup:addWidget(inventoryController.ui.offPanel.redFistBox)
    connect(compactPvpModeRadioGroup, {
        onSelectionChange = onSetPVPMode
    })
    for _, panel in ipairs({inventoryController.ui.onPanel, inventoryController.ui.offPanel}) do
        for _, id in ipairs({'whiteDoveBox', 'whiteHandBox', 'yellowHandBox', 'redFistBox'}) do
            connect(panel[id], {onClick = combatEvent})
        end
    end

    -- Register player events at module init (connected at startup, before any
    -- login). If registered in onGameStart (deferred via addEvent), the login
    -- packet burst can win the race against the connection: LuaObject::callLuaField
    -- negative-caches "no handler" per object/field and never calls Lua again for
    -- that event, leaving the inventory frozen for the whole session (stale slot
    -- widgets + "Sorry, not possible" when dragging them).
    inventoryController:registerEvents(LocalPlayer, {
        onInventoryChange = inventoryEvent,
        onSoulChange = onSoulChange,
        onFreeCapacityChange = onFreeCapacityChange,
        onTotalCapacityChange = onCapacityChange,
        onBaseCapacityChange = onCapacityChange
    })
end

function inventoryController:onGameStart()
    local player = g_game.getLocalPlayer()
    if player then
        local char = g_game.getCharacterName()
        local lastCombatControls = g_settings.getNode('LastCombatControls')
        if not table.empty(lastCombatControls) then
            if lastCombatControls[char] then
                if not g_game.getFeature(GameTacticsWithoutFightMode) then
                    g_game.setFightMode(lastCombatControls[char].fightMode)
                end
                g_game.setChaseMode(lastCombatControls[char].chaseMode)
                g_game.setSafeFight(lastCombatControls[char].safeFight)
                if g_game.getExpertPvpMode() and lastCombatControls[char].pvpMode then
                    g_game.setPVPMode(lastCombatControls[char].pvpMode)
                end
            end
        end
    end
    -- LocalPlayer events are registered in onInit (see note there).
    inventoryController:registerEvents(g_game, {
        onWalk = walkEvent,
        onAutoWalk = walkEvent,
        onFightModeChange = combatEvent,
        onChaseModeChange = combatEvent,
        onSafeFightChange = combatEvent,
        onPVPModeChange = combatEvent
    }):execute()

    local modernTactics = g_game.getFeature(GameTacticsWithoutFightMode)
    for _, panel in ipairs({inventoryController.ui.onPanel, inventoryController.ui.offPanel}) do
        panel.attack:setVisible(not modernTactics)
        panel.balanced:setVisible(not modernTactics)
        panel.defense:setVisible(not modernTactics)
        panel.expert:setEnabled(g_game.getFeature(GamePVPMode) and g_game.getExpertPvpMode())
    end
    inventoryController.ui.onPanel.standPosture:setMarginRight(modernTactics and 30 or 7)
    local compactStand = inventoryController.ui.offPanel.standPosture
    compactStand:addAnchor(AnchorTop, modernTactics and 'changeSize' or 'attack', modernTactics and AnchorTop or AnchorBottom)
    compactStand:setMarginTop(modernTactics and 12 or 4)
    compactStand:addAnchor(AnchorLeft, modernTactics and 'parent' or 'attack', AnchorLeft)
    compactStand:setMarginLeft(modernTactics and 56 or 0)

    inventoryShrink = g_settings.getBoolean('mainpanel_shrink_inventory')
    refreshInventorySizes()
    refreshInventory_panel()

    local elements = {
        {inventoryController.ui.offPanel.blessings, inventoryController.ui.onPanel.blessings},
        {inventoryController.ui.offPanel.expert, inventoryController.ui.onPanel.expert},
        {inventoryController.ui.onPanel.whiteDoveBox},
        {inventoryController.ui.onPanel.whiteHandBox},
        {inventoryController.ui.onPanel.yellowHandBox},
        {inventoryController.ui.onPanel.redFistBox}
    }
    
    local showBlessings = g_game.getClientVersion() >= 1000
    local showPVPMode = g_game.getFeature(GamePVPMode)
    
    for i, elementGroup in ipairs(elements) do
        local show = (i == 1 and showBlessings) or (i > 1 and showPVPMode)
        for _, element in ipairs(elementGroup) do
            if show then
                element:show()
            else
                element:hide()
            end
        end
    end
    inventoryController.ui.onPanel.purseButton:setVisible(g_game.getFeature(GamePurseSlot))
    expertMode(inventoryController.ui.onPanel.expert, inventoryController.ui.onPanel.expert:isChecked())

    if isPlayerMonk() and player then
        local leftItem = player:getInventoryItem(InventorySlotLeft)
        if leftItem then
            updateMonkMirrorItem(leftItem)
        end
    end
end

function inventoryController:onGameEnd()
    monkMirrorItem = nil

    local lastCombatControls = g_settings.getNode('LastCombatControls')
    if not lastCombatControls then
        lastCombatControls = {}
    end
    local player = g_game.getLocalPlayer()
    if player then
        local char = g_game.getCharacterName()
        lastCombatControls[char] = {
            fightMode = g_game.getFightMode(),
            chaseMode = g_game.getChaseMode(),
            safeFight = g_game.isSafeFight()
        }
        if g_game.getFeature(GamePVPMode) then
            lastCombatControls[char].pvpMode = g_game.getPVPMode()
        end
        g_settings.setNode('LastCombatControls', lastCombatControls)
    end
    toggleAdventurerStyle(false)
end

function inventoryController:onTerminate()
    if iconTopMenu then
        iconTopMenu:destroy()
        iconTopMenu = nil
    end
    if pvpModeRadioGroup then
        disconnect(pvpModeRadioGroup, {
            onSelectionChange = onSetPVPMode
        })
        pvpModeRadioGroup:destroy()
        pvpModeRadioGroup = nil
    end
    if compactPvpModeRadioGroup then
        disconnect(compactPvpModeRadioGroup, {
            onSelectionChange = onSetPVPMode
        })
        compactPvpModeRadioGroup:destroy()
        compactPvpModeRadioGroup = nil
    end
end

function onSetSafeFight(self, checked)
    if updatingCombatControls then
        return
    end
    g_game.setSafeFight(not checked)
    if not checked then
        g_game.cancelAttack()
    end
    combatEvent()
end

function selectPosture(key, ignoreUpdate)
    if key ~= 'stand' and key ~= 'follow' then
        return
    end
    for _, ui in ipairs({inventoryController.ui.onPanel, inventoryController.ui.offPanel}) do
        ui.standPosture:setOn(key == 'stand')
        ui.followPosture:setOn(key == 'follow')
    end
    if not ignoreUpdate then
        g_game.setChaseMode(key == 'follow' and ChaseOpponent or DontChase)
    end
end

function selectCombat(combat, ignoreUpdate)
    if g_game.getFeature(GameTacticsWithoutFightMode) then
        return
    end
    if combat ~= 'attack' and combat ~= 'balanced' and combat ~= 'defense' then
        return
    end

    for _, ui in ipairs({inventoryController.ui.onPanel, inventoryController.ui.offPanel}) do
        ui.attack:setOn(combat == 'attack')
        ui.balanced:setOn(combat == 'balanced')
        ui.defense:setOn(combat == 'defense')
    end

    if not ignoreUpdate and not g_game.getFeature(GameTacticsWithoutFightMode) then
        if combat == 'attack' then
            g_game.setFightMode(FightOffensive)
        elseif combat == 'balanced' then
            g_game.setFightMode(FightBalanced)
        elseif combat == 'defense' then
            g_game.setFightMode(FightDefensive)
        end
    end
end

function expertMode(self, checked)
    if updatingExpertMode then
        return
    end

    local allowed = g_game.getFeature(GamePVPMode) and g_game.getExpertPvpMode()
    checked = checked == true and allowed
    updatingExpertMode = true
    for _, ui in ipairs({inventoryController.ui.onPanel, inventoryController.ui.offPanel}) do
        ui.expert:setChecked(checked)
    end
    updatingExpertMode = false

    if not checked and allowed then
        g_game.setPVPMode(PVPWhiteDove)
    end
    combatEvent()
end

function onSetPVPMode(self, selectedPVPButton)
    if selectedPVPButton == nil or not g_game.getFeature(GamePVPMode) or not g_game.getExpertPvpMode() then
        return
    end

    local buttonId = selectedPVPButton:getId()
    local pvpMode = PVPWhiteDove

    if buttonId == 'whiteDoveBox' then
        pvpMode = PVPWhiteDove
    elseif buttonId == 'whiteHandBox' then
        pvpMode = PVPWhiteHand
    elseif buttonId == 'yellowHandBox' then
        pvpMode = PVPYellowHand
    elseif buttonId == 'redFistBox' then
        pvpMode = PVPRedFist
    end
    g_game.setPVPMode(pvpMode)
end

function changeInventorySize()
    inventoryShrink = not inventoryShrink
    g_settings.set('mainpanel_shrink_inventory', inventoryShrink)
    refreshInventorySizes()
    modules.game_mainpanel.reloadMainPanelSizes()
    local player = g_game.getLocalPlayer()
    if player and g_game.isOnline() then
        onFreeCapacityChange(player, player:getFreeCapacity())
        onSoulChange(player, player:getSoul())
    end
end

function getSlot5()
    return inventoryController.ui.onPanel.shield
end

function reloadInventory()
    if inventoryShrink then
        return
    end

    for slot, getSlotInfo in pairs(getSlotPanelBySlot) do
        local ui = getInventoryUi()
        local slotPanel, toggler = getSlotInfo(ui)
        if slotPanel then
            local player = g_game.getLocalPlayer()
            if player then
                inventoryEvent(player, slot, player:getInventoryItem(slot))
            end
        end
    end
end

function extendedView(extendedView)
    if extendedView then
        if not iconTopMenu then
            iconTopMenu = modules.client_topmenu.addTopRightToggleButton('inventory', tr('Show inventory'),
                '/images/topbuttons/inventory', toggle)
            iconTopMenu:setOn(inventoryController.ui:isVisible())
            inventoryController.ui:setBorderColor('black')
            inventoryController.ui:setBorderWidth(2)
        end
    else
        if iconTopMenu then
            iconTopMenu:destroy()
            iconTopMenu = nil
        end
        inventoryController.ui:setBorderColor('alpha')
        inventoryController.ui:setBorderWidth(0)
        local mainRightPanel = modules.game_interface.getMainRightPanel()
        if not mainRightPanel:hasChild(inventoryController.ui) then
            mainRightPanel:insertChild(3, inventoryController.ui)
        end
        inventoryController.ui:show()
    end
    inventoryController.ui.moveOnlyToMain = not extendedView

end

function toggle()
    if iconTopMenu:isOn() then
        inventoryController.ui:hide()
        iconTopMenu:setOn(false)
    else
        inventoryController.ui:show()
        iconTopMenu:setOn(true)
    end
end

function toggleAdventurerStyle(hasBlessing)
    local ui = inventoryController.ui.onPanel
    for _, getSlotInfo in pairs(getSlotPanelBySlot) do
        local slotPanel = getSlotInfo(ui)
        if slotPanel then
            slotPanel:setOn(hasBlessing)
            slotPanel.golden:setVisible(hasBlessing)
        end
    end
end

function getButtonBlessings()
    return getInventoryUi().blessings
end

function getButtonsBlessings()
    return {inventoryController.ui.onPanel.blessings, inventoryController.ui.offPanel.blessings}
end
