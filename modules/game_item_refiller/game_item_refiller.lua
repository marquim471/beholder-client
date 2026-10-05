local OPCODE_ITEM_REFILLER = 156

local window = nil
local refillerType = nil
local itemsData = {}
local selectedSlot = nil
local selectedItem = nil
local selectedQuantityBtn = nil
local selectedQty = nil
local selectedPrice = nil
local playerMoney = 0
local playerCap = 0
local optionSlots = {}
local quantityButtons = {}

local function formatNumber(n)
    if not n then return "0" end
    local formatted = tostring(math.floor(n))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function toTitleCase(str)
    if not str then return "" end
    return (str:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end))
end

local function updateGoldBoxes()
    if not window then return end

    local costBox = window:recursiveGetChildById('costGoldBox')
    local playerBox = window:recursiveGetChildById('playerGoldBox')
    local playerCapLabel = window:recursiveGetChildById('playerCapLabel')

    if costBox then
        local valueLabel = costBox:getChildById('value')
        if valueLabel then
            valueLabel:setText(formatNumber(selectedPrice or 0))
            if selectedPrice and playerMoney < selectedPrice then
                valueLabel:setColor("#ff6060")
            else
                valueLabel:setColor("#BDBDBD")
            end
        end
    end

    if playerBox then
        local valueLabel = playerBox:getChildById('value')
        if valueLabel then
            valueLabel:setText(formatNumber(playerMoney))
            if selectedPrice and playerMoney < selectedPrice then
                valueLabel:setColor("#ff6060")
            else
                valueLabel:setColor("#BDBDBD")
            end
        end
    end

    if playerCapLabel then
        playerCapLabel:setText(string.format("Free Cap: %.2f oz", playerCap / 100))
    end
end

local function updateFeedback()
    if not window then return end

    local statusLabel = window:recursiveGetChildById('statusLabel')
    local buyBtn = window:recursiveGetChildById('buyButton')
    local upper = window:getChildById('upperPanel')

    updateGoldBoxes()

    if not selectedItem or not selectedQty or not selectedPrice then
        if statusLabel then
            statusLabel:setText(tr("Select an item and quantity above."))
            statusLabel:setColor("#a0a0a0")
        end
        if buyBtn then
            buyBtn:setEnabled(false)
        end
        return
    end

    local totalWeight = (selectedItem.weight or 0) * selectedQty

    if upper then
        local weightLabel = upper:getChildById('currentWeightLabel')
        if weightLabel then
            weightLabel:setText(string.format("Weight: %.2f oz (%dx)", totalWeight / 100, selectedQty))
        end
    end

    if playerMoney < selectedPrice then
        if statusLabel then
            statusLabel:setText(string.format("Selected: %dx %s - Insufficient Gold!", selectedQty, selectedItem.name))
            statusLabel:setColor("#ff6060")
        end
        if buyBtn then
            buyBtn:setEnabled(false)
        end
    elseif playerCap < totalWeight then
        if statusLabel then
            statusLabel:setText(string.format("Selected: %dx %s - Insufficient Capacity!", selectedQty, selectedItem.name))
            statusLabel:setColor("#ff6060")
        end
        if buyBtn then
            buyBtn:setEnabled(false)
        end
    else
        if statusLabel then
            statusLabel:setText(string.format("Selected: %dx %s (%s gp)", selectedQty, selectedItem.name, formatNumber(selectedPrice)))
            statusLabel:setColor("#ffcc00")
        end
        if buyBtn then
            buyBtn:setEnabled(true)
        end
    end
end

local function selectQuantity(btn, priceData)
    if not btn or not priceData then return end

    if selectedQuantityBtn and selectedQuantityBtn ~= btn then
        selectedQuantityBtn:setChecked(false)
    end

    selectedQuantityBtn = btn
    btn:setChecked(true)
    selectedQty = priceData.qty
    selectedPrice = priceData.price

    updateFeedback()
end

local function selectItem(slot, itemData)
    if not slot or not itemData then return end

    if selectedSlot and selectedSlot ~= slot then
        selectedSlot:setChecked(false)
    end

    selectedSlot = slot
    slot:setChecked(true)
    selectedItem = itemData

    if not window then return end

    local upper = window:getChildById('upperPanel')
    if upper then
        local currentItem = upper:recursiveGetChildById('currentItem')
        if currentItem then
            currentItem:setItemId(itemData.id)
        end

        local nameLabel = upper:getChildById('currentNameLabel')
        if nameLabel then
            nameLabel:setText(toTitleCase(itemData.name))
        end

        local catLabel = upper:getChildById('currentCategoryLabel')
        if catLabel then
            catLabel:setText(string.format("Category: %s", itemData.category or "Other"))
        end
    end

    local quantityContainer = window:recursiveGetChildById('quantityContainer')
    if quantityContainer then
        quantityContainer:destroyChildren()
        quantityButtons = {}
        selectedQuantityBtn = nil
        selectedQty = nil
        selectedPrice = nil

        local defaultBtn = nil
        local defaultPriceData = nil

        if itemData.prices then
            for idx, priceData in ipairs(itemData.prices) do
                local qBtn = g_ui.createWidget('QuantityButton', quantityContainer)
                qBtn:setText(string.format("%dx", priceData.qty))
                qBtn:setTooltip(string.format("%dx %s\nCost: %s gp\nWeight: %.2f oz",
                    priceData.qty,
                    itemData.name,
                    formatNumber(priceData.price),
                    ((itemData.weight or 0) * priceData.qty) / 100
                ))

                qBtn.onClick = function()
                    selectQuantity(qBtn, priceData)
                end

                table.insert(quantityButtons, qBtn)

                -- Default selection: first option or 100x if available
                if not defaultBtn or priceData.qty == 100 then
                    defaultBtn = qBtn
                    defaultPriceData = priceData
                end
            end
        end

        if defaultBtn and defaultPriceData then
            selectQuantity(defaultBtn, defaultPriceData)
        else
            updateFeedback()
        end
    end
end

local function populateItemsGrid(items)
    if not window then return end
    local container = window:recursiveGetChildById('slotsContainer')
    if not container then return end

    container:destroyChildren()
    optionSlots = {}
    selectedSlot = nil
    selectedItem = nil

    local firstSlot = nil
    local firstItem = nil

    for _, item in ipairs(items) do
        local slot = g_ui.createWidget('RefillerItemSlot', container)
        local itemWidget = slot:getChildById('item')
        if itemWidget then
            itemWidget:setItemId(item.id)
        end

        slot:setTooltip(string.format("%s\nCategory: %s", toTitleCase(item.name), item.category or "Other"))

        slot.onClick = function()
            selectItem(slot, item)
        end

        table.insert(optionSlots, slot)

        if not firstSlot then
            firstSlot = slot
            firstItem = item
        end
    end

    if firstSlot and firstItem then
        selectItem(firstSlot, firstItem)
    end
end

function sendBuy()
    if not window or not selectedItem or not selectedQty then
        return
    end

    local buyBtn = window:recursiveGetChildById('buyButton')
    if not buyBtn or not buyBtn:isEnabled() then
        return
    end

    local protocol = g_game.getProtocolGame()
    if not protocol then
        return
    end

    buyBtn:setEnabled(false)

    local payload = {
        action = "buy",
        refillerType = refillerType,
        itemId = selectedItem.id,
        qty = selectedQty
    }

    protocol:sendExtendedOpcode(OPCODE_ITEM_REFILLER, json.encode(payload))
end

function open(data)
    if window then
        window:destroy()
    end

    window = g_ui.displayUI('item_refiller')
    if not window then
        return
    end

    refillerType = data.refillerType or "rune"
    playerMoney = data.playerMoney or 0
    playerCap = data.playerCapacity or 0
    itemsData = data.items or {}

    if data.title then
        window:setText(tr(data.title))
    end

    local buyBtn = window:getChildById('buyButton')
    if buyBtn then
        buyBtn.onClick = sendBuy
        buyBtn:setEnabled(false)
    end

    populateItemsGrid(itemsData)

    window:show()
    window:raise()
    window:focus()
end

function destroy()
    if window then
        window:destroy()
        window = nil
    end
    refillerType = nil
    itemsData = {}
    selectedSlot = nil
    selectedItem = nil
    selectedQuantityBtn = nil
    selectedQty = nil
    selectedPrice = nil
    optionSlots = {}
    quantityButtons = {}
end

local function onExtendedOpcode(protocol, opcode, buffer)
    if opcode ~= OPCODE_ITEM_REFILLER then
        return
    end

    local status, data = pcall(json.decode, buffer)
    if not status or type(data) ~= "table" then
        return
    end

    if data.action == "open" then
        open(data)
        return
    end

    if not window then
        return
    end

    local statusLabel = window:recursiveGetChildById('statusLabel')
    local buyBtn = window:recursiveGetChildById('buyButton')

    if data.action == "success" then
        playerMoney = data.playerMoney or playerMoney
        playerCap = data.playerCap or playerCap

        updateFeedback()

        if statusLabel then
            statusLabel:setText(data.message or tr("Purchase completed successfully!"))
            statusLabel:setColor("#00e676")
        end
    elseif data.action == "error" then
        updateFeedback()

        if statusLabel then
            statusLabel:setText(data.message or tr("Purchase failed."))
            statusLabel:setColor("#ff6060")
        end
    end
end

local function onGameEnd()
    destroy()
end

function init()
    ProtocolGame.registerExtendedOpcode(OPCODE_ITEM_REFILLER, onExtendedOpcode)
    connect(g_game, {
        onGameEnd = onGameEnd
    })
end

function terminate()
    ProtocolGame.unregisterExtendedOpcode(OPCODE_ITEM_REFILLER)
    disconnect(g_game, {
        onGameEnd = onGameEnd
    })
    destroy()
end
