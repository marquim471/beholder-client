local presetWindow = nil
local selectIconWindow = nil
local radioIconGroup = nil
local currentButton = nil

local PresetSlotStyles = {
    [InventorySlotHead] = "Slot1",
    [InventorySlotNeck] = "Slot2",
    [InventorySlotBack] = "Slot3",
    [InventorySlotBody] = "Slot4",
    [InventorySlotRight] = "Slot5",
    [InventorySlotLeft] = "Slot6",
    [InventorySlotLeg] = "Slot7",
    [InventorySlotFeet] = "Slot8",
    [InventorySlotFinger] = "Slot9",
    [InventorySlotAmmo] = "Slot10"
}

local presetDefaultStruct = {
    equipSlot1 = { itemId = 0, tier = 0, identifier = "", smartMode = false },
    equipSlot2 = { itemId = 0, tier = 0, identifier = "", smartMode = false },
    equipSlot3 = { itemId = 0, tier = 0, identifier = "", smartMode = false },
    equipSlot4 = { itemId = 0, tier = 0, identifier = "", smartMode = false },
    equipSlot5 = { itemId = 0, tier = 0, identifier = "", smartMode = false },
    equipSlot6 = { itemId = 0, tier = 0, identifier = "", smartMode = false },
    equipSlot7 = { itemId = 0, tier = 0, identifier = "", smartMode = false },
    equipSlot8 = { itemId = 0, tier = 0, identifier = "", smartMode = false },
    equipSlot9 = { itemId = 0, tier = 0, identifier = "", smartMode = false },
    equipSlot10 = { itemId = 0, tier = 0, identifier = "", smartMode = false }
}

local DynamicItems = {
    [3086] = 3049, [3087] = 3050, [3088] = 3051, [3089] = 3052,
    [3090] = 3053, [3094] = 3091, [3095] = 3092, [3096] = 3093,
    [3099] = 3097, [3100] = 3098, [3549] = 6529, [6300] = 6299,
    [9018] = 9019, [9392] = 9393, [16264] = 16114, [22134] = 22061,
    [23476] = 23477, [23530] = 23529, [23532] = 23531, [23534] = 23533,
    [23526] = 23542, [23527] = 23543, [23528] = 23544, [30343] = 30342,
    [30345] = 30344, [30402] = 30403, [31616] = 31557, [32635] = 32621,
    [39178] = 39177, [39181] = 39180, [39184] = 39183, [39187] = 39186,
    [39234] = 39233, [50148] = 50147, [50151] = 50150, [50153] = 50152,
    [50155] = 50154, [23475] = 23474
}

local function getCurrentItemId(itemPtr)
    if not itemPtr then
        return 0
    end

    local inventoryItemId = itemPtr:getId()
    if DynamicItems[inventoryItemId] then
        inventoryItemId = DynamicItems[inventoryItemId]
    end
    return inventoryItemId
end

local function getEquipmentPresetSlots()
    if type(EquipmentPresetSlots) == "table" and #EquipmentPresetSlots > 0 then
        return EquipmentPresetSlots
    end

    local slots = {}
    local function push(v)
        if type(v) == "number" then
            table.insert(slots, v)
        end
    end

    push(InventorySlotHead)
    push(InventorySlotNeck or InventorySlotNecklace)
    push(InventorySlotBack or InventorySlotBackpack)
    push(InventorySlotBody or InventorySlotArmor)
    push(InventorySlotRight)
    push(InventorySlotLeft)
    push(InventorySlotLeg or InventorySlotLegs)
    push(InventorySlotFeet)
    push(InventorySlotFinger or InventorySlotRing)
    push(InventorySlotAmmo)

    return slots
end

function isPresetWindowVisible()
    return presetWindow and presetWindow:isVisible() or false
end

function closePresetWindow()
    if presetWindow then
        presetWindow:hide()
        presetWindow:destroy()
        presetWindow = nil
    end
end

local function getPresetSlotWidget(slotId)
    if not presetWindow then
        return nil
    end
    return presetWindow:recursiveGetChildById(string.format("equipSlot%d", slotId))
end

local function setPresetSlotItem(widget, itemId, tier)
    if not widget then
        return
    end

    itemId = itemId or 0
    tier = tier or 0
    if itemId > 0 then
        local item = Item.create(itemId)
        if item and item.setTier then
            item:setTier(tier)
        end
        if widget.setItem then
            widget:setItem(item)
        else
            widget:setItemId(itemId)
            if widget.setTier then
                widget:setTier(tier)
            end
        end
    else
        if widget.setItem then
            widget:setItem(nil)
        else
            widget:setItemId(0)
            if widget.setTier then
                widget:setTier(0)
            end
        end
    end
    local slot = tonumber(string.match(widget:getId(), "%d+")) or 0
    widget:setStyle(itemId > 0 and "PresetEmptyItem" or PresetSlotStyles[slot])
end

local function getPresetSlotItemData(widget)
    if not widget then
        return 0, 0
    end

    local item = widget:getItem()
    if item then
        return item:getId() or 0, item:getTier() or 0
    end

    local itemId = widget.getItemId and widget:getItemId() or 0
    local tier = widget.getTier and widget:getTier() or 0
    return itemId or 0, tier or 0
end

function assignEquipment(button)
    if presetWindow then
        presetWindow:destroy()
    end

    presetWindow = g_ui.loadUI("equippreset", g_ui.getRootWidget())
    if not presetWindow then
        return
    end

    presetWindow:show()
    presetWindow:raise()
    scheduleEvent(function()
        if presetWindow then
            presetWindow:focus()
        end
    end, 50)

    currentButton = button

    local player = g_game.getLocalPlayer()
    local backpackWidget = getPresetSlotWidget(InventorySlotBack)
    local backpackItem = player and player:getInventoryItem(InventorySlotBack)
    local backpackItemId = getCurrentItemId(backpackItem)
    setPresetSlotItem(backpackWidget, backpackItemId, backpackItem and backpackItem:getTier() or 0)

    for slotKey, slotData in pairs(button.cache.equipmentPreset or {}) do
        local widget = presetWindow:recursiveGetChildById(slotKey)
        if widget then
            setPresetSlotItem(widget, slotData.itemId or 0, slotData.tier or 0)
        end
    end

    local iconSource = presetWindow:recursiveGetChildById("imageContainer")
    local currentIcon = button.cache.equipmentPresetIcon or ""
    if currentIcon ~= "" then
        iconSource:setImageSource("/images/game/actionbar/equip-preset/" .. currentIcon)
    end

    presetWindow.contentPanel.apply:setEnabled(currentIcon ~= "")
    presetWindow.contentPanel.missingIcon:setVisible(currentIcon == "")

    presetWindow.contentPanel.apply.onClick = function()
        local iconWidget = presetWindow:recursiveGetChildById("imageContainer")
        local source = iconWidget and iconWidget:getImageSource() or ""
        local filename = string.match(source or "", "([^/]+)$") or ""

        local equippedCount = 0
        local slots = getEquipmentPresetSlots()
        for _, slotId in pairs(slots) do
            local widget = getPresetSlotWidget(slotId)
            if widget then
                if not button.cache.equipmentPreset[widget:getId()] then
                    button.cache.equipmentPreset[widget:getId()] = table.copy(presetDefaultStruct[widget:getId()] or { itemId = 0, tier = 0, identifier = "", smartMode = false })
                end

                local itemId, itemTier = getPresetSlotItemData(widget)
                button.cache.equipmentPreset[widget:getId()].itemId = itemId
                button.cache.equipmentPreset[widget:getId()].tier = itemTier

                if itemId > 0 then
                    equippedCount = equippedCount + 1
                end
            end
        end

        local barID, buttonID = string.match(button:getId(), "(.*)%.(.*)")
        if equippedCount == 0 then
            button.cache.equipmentPreset = {}
            button.cache.equipmentPresetIcon = ""
            ApiJson.removeAction(tonumber(barID), tonumber(buttonID))
            updateButton(button)
            closePresetWindow()
            return true
        end

        button.cache.equipmentPresetIcon = filename
        ApiJson.createOrUpdatePreset(tonumber(barID), tonumber(buttonID), button.cache.equipmentPreset, filename)
        updateButton(button)
        closePresetWindow()
    end

    presetWindow.contentPanel.close.onClick = closePresetWindow
end

function assignItemPreset(widget, mousePos, mouseButton)
    if mouseButton ~= MouseRightButton then
        return
    end

    local menu = g_ui.createWidget("PopupMenu")
    menu:setGameMenu(true)

    if widget:getItemId() == 0 then
        menu:addOption(tr("Select Item"), function()
            selectPresetItem(widget)
        end)
    else
        menu:addOption(tr("Edit Item"), function()
            selectPresetItem(widget)
        end)
        menu:addOption(tr("Remove Item"), function()
            onRemovePresetItem(widget)
        end)
    end

    menu:display(mousePos)
end

function selectPresetItem(widget)
    local grabber = modules.game_actionbar.getGrabberWidget()
    if not grabber then
        return
    end

    grabber:grabMouse()
    if modules.client_options and modules.client_options.getOption('nativeCursor') then
        g_window.setSystemCursor('cross')
    else
        g_mouse.pushCursor('target')
    end

    grabber.onMouseRelease = function(self, mousePosition, mouseButton)
        onSelectPresetItem(self, mousePosition, mouseButton, widget)
    end
end

function onSelectPresetItem(self, mousePosition, mouseButton, widget)
    local grabber = modules.game_actionbar.getGrabberWidget()
    local rootPanel = modules.game_actionbar.getRootPanel() or (modules.game_interface and modules.game_interface.getRootPanel())

    if grabber then
        grabber:ungrabMouse()
        if modules.client_options and modules.client_options.getOption('nativeCursor') then
            g_window.restoreMouseCursor()
        else
            g_mouse.popCursor('target')
        end
        grabber.onMouseRelease = modules.game_actionbar.onDropActionButton
    end

    if mouseButton == MouseRightButton then
        return true
    end

    if not rootPanel then
        return true
    end

    local clickedWidget = rootPanel:recursiveGetChildByPos(mousePosition, false)
    if not clickedWidget then
        return true
    end

    local item = nil
    if clickedWidget:getClassName() == "UIItem" and not clickedWidget:isVirtual() and clickedWidget:getItem() then
        item = clickedWidget:getItem()
    elseif clickedWidget:getClassName() == "UIGameMap" then
        local tile = clickedWidget:getTile(mousePosition)
        if tile then
            item = tile:getTopUseThing()
        end
    end

    if not item then
        return
    end

    if not item:isPickupable() then
        modules.game_textmessage.displayFailureMessage("This item can't be assigned to this slot.")
        return true
    end

    local slotId = tonumber(string.match(widget:getId(), "%d+"))
    local canEquip, message = isValidEquipSlot(item, slotId)
    if not canEquip then
        modules.game_textmessage.displayFailureMessage(message)
        return
    end

    local newItemId = getCurrentItemId(item)
    if newItemId == 0 then
        return
    end

    local newItem = Item.create(newItemId)
    newItem:setTier(item:getTier() or 0)
    widget:setStyle("PresetEmptyItem")
    widget:setItem(newItem)
end

function onDropPresetItem(widget, item)
    if not isPresetWindowVisible() then
        return
    end

    local slotId = tonumber(widget:getId():match("%d+"))
    local canEquip = isValidEquipSlot(item, slotId)
    if not canEquip then
        return
    end

    local newItemId = getCurrentItemId(item)
    if newItemId == 0 then
        return
    end

    local newItem = Item.create(newItemId)
    newItem:setTier(item:getTier() or 0)
    widget:setStyle("PresetEmptyItem")
    widget:setItem(newItem)
end

function assignPlayerEquipments()
    if not isPresetWindowVisible() then
        return
    end

    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    local slots = getEquipmentPresetSlots()
    for _, slotId in pairs(slots) do
        local widget = getPresetSlotWidget(slotId)
        local inventoryItem = player:getInventoryItem(slotId)
        if widget then
            local itemId = getCurrentItemId(inventoryItem)
            local tier = inventoryItem and inventoryItem:getTier() or 0
            setPresetSlotItem(widget, itemId, tier)
        end
    end
end

function onRemovePresetItem(widget)
    local slot = tonumber(string.match(widget:getId(), "%d+"))
    widget:setItem(nil)
    widget:setStyle(PresetSlotStyles[slot])
end

function editPresetIcon(widget, mousePos, mouseButton)
    if not presetWindow then
        return
    end
    presetWindow:hide()

    selectIconWindow = g_ui.createWidget("SelectEquipPresetIcon", g_ui.getRootWidget())
    if not selectIconWindow then
        presetWindow:show()
        return
    end

    if g_ui.setInputLockWidget then
        g_ui.setInputLockWidget(selectIconWindow)
    end
    local iconList = selectIconWindow:recursiveGetChildById("selectEquipPresetPanel")
    radioIconGroup = UIRadioGroup.create()
    for _, iconWidget in pairs(iconList:getChildren()) do
        radioIconGroup:addWidget(iconWidget)
    end

    radioIconGroup.onSelectionChange = function(widget, currentWidget, prevWidget)
        if prevWidget then
            prevWidget:recursiveGetChildById("selectedFrame"):setVisible(false)
        end
        currentWidget:recursiveGetChildById("selectedFrame"):setVisible(true)
        selectIconWindow:recursiveGetChildById("selectButton"):setEnabled(true)
    end
end

function onCloseSelectPresetIcon()
    if selectIconWindow then
        selectIconWindow:hide()
        selectIconWindow:destroy()
        selectIconWindow = nil
    end

    if radioIconGroup then
        radioIconGroup:destroy()
        radioIconGroup = nil
    end

    if g_ui.setInputLockWidget then
        g_ui.setInputLockWidget(nil)
    end
    if presetWindow then
        presetWindow:show()
    end
end

function onSelectPresetIcon()
    local selectedWidget = radioIconGroup and radioIconGroup:getSelectedWidget()
    if selectedWidget and presetWindow then
        presetWindow:recursiveGetChildById("imageContainer"):setImageSource(selectedWidget.imageContainer:getImageSource())
        presetWindow.contentPanel.apply:setEnabled(true)
        presetWindow.contentPanel.missingIcon:setVisible(false)
    end
    onCloseSelectPresetIcon()
end

function isValidEquipSlot(item, slotId)
    if not isPresetWindowVisible() then
        return false
    end

    local cloth = item:getClothSlot()
    local isTwoHanded = cloth == 0 and item:getClassification() > 0

    if (slotId ~= cloth and not (isTwoHanded and slotId == InventorySlotLeft)) or (cloth == 0 and not isTwoHanded) then
        return false, "You cannot dress this object there"
    end

    local itemType = g_things.getThingType(item:getId(), ThingCategoryItem)
    if not itemType then
        return false, "Invalid item"
    end

    local marketData = itemType:getMarketData() or {}
    local restrictVocation = marketData.restrictVocation or {}
    local requiredLevel = marketData.requiredLevel or 0

    if item:getId() == 28494 and marketData then
        marketData.category = MarketCategory.Shields
    end

    if slotId == InventorySlotRight then
        local leftWidget = getPresetSlotWidget(InventorySlotLeft)
        local leftItemId = leftWidget and leftWidget:getItemId() or 0
        if leftItemId > 0 then
            local leftType = g_things.getThingType(leftItemId, ThingCategoryItem)
            if leftType then
                local leftMarket = leftType:getMarketData() or {}
                local leftIsTwoHanded = leftType:getClothSlot() == 0 and
                    ((leftMarket.category == MarketCategory.Shields) or leftType:getClassification() > 0)
                if marketData.category == MarketCategory.Shields and leftIsTwoHanded then
                    return false, "Both hands need to be free"
                end
            end
        end
    end

    if slotId == InventorySlotLeft then
        local rightWidget = getPresetSlotWidget(InventorySlotRight)
        local rightItemId = rightWidget and rightWidget:getItemId() or 0
        if rightItemId > 0 then
            local rightType = g_things.getThingType(rightItemId, ThingCategoryItem)
            if rightType then
                local rightMarket = rightType:getMarketData() or {}
                if rightMarket.category == MarketCategory.Shields and itemType:getClothSlot() == 0 then
                    return false, "Both hands need to be free"
                end
            end
        end
    end

    if (slotId == InventorySlotNeck or slotId == InventorySlotFinger) and item:hasWearout() and item:hasCharges() then
        return false, "Items with charges are not allowed"
    end

    local player = g_game.getLocalPlayer()
    local playerVocation = translateWheelVocation(player:getVocation())

    if type(restrictVocation) == "table" and #restrictVocation > 0 and not table.contains(restrictVocation, playerVocation) then
        return false, "You don't have the required profession"
    end

    if requiredLevel > player:getLevel() then
        return false, "You do not have enough level"
    end
    return true
end

function offLineEvents()
    onCloseSelectPresetIcon()
    closePresetWindow()
    currentButton = nil
end

function onEditSmartMode(widget)
    if not currentButton or not currentButton.cache then
        return
    end
    if not currentButton.cache.equipmentPreset[widget:getId()] then
        currentButton.cache.equipmentPreset[widget:getId()] = { itemId = 0, tier = 0, identifier = "", smartMode = true }
        return
    end

    local currentState = currentButton.cache.equipmentPreset[widget:getId()].smartMode
    currentButton.cache.equipmentPreset[widget:getId()].smartMode = not currentState
end

function smartModeEnabled(widget)
    if not currentButton or not currentButton.cache or not currentButton.cache.equipmentPreset[widget:getId()] then
        return false
    end
    return currentButton.cache.equipmentPreset[widget:getId()].smartMode
end
