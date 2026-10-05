local OPCODE_EXERCISE_EXCHANGE = 155
local COST_PER_CHARGE = 100

local window = nil
local currentExerciseItem = nil
local currentCharges = 0
local totalCost = 0
local playerMoney = 0
local selectedSlot = nil
local selectedTargetId = nil
local selectedWeaponData = nil
local optionSlots = {}

local EXERCISE_GROUPS = {
    [1] = {
        name = "Training",
        weapons = {
            { id = 28540, name = "Training Sword", displayName = "Exercise Sword", type = "Sword (Melee)" },
            { id = 28541, name = "Training Axe", displayName = "Exercise Axe", type = "Axe (Melee)" },
            { id = 28542, name = "Training Club", displayName = "Exercise Club", type = "Club (Melee)" },
            { id = 28543, name = "Training Bow", displayName = "Exercise Bow", type = "Bow (Distance)" },
            { id = 28544, name = "Training Rod", displayName = "Exercise Rod", type = "Rod (Druid)" },
            { id = 28545, name = "Training Wand", displayName = "Exercise Wand", type = "Wand (Sorcerer)" },
            { id = 44064, name = "Training Shield", displayName = "Exercise Shield", type = "Shield (Defense)" },
            { id = 50292, name = "Training Wraps", displayName = "Exercise Wraps", type = "Wraps (Fist)" },
        }
    },
    [2] = {
        name = "Exercise",
        weapons = {
            { id = 28552, name = "Exercise Sword", displayName = "Exercise Sword", type = "Sword (Melee)" },
            { id = 28553, name = "Exercise Axe", displayName = "Exercise Axe", type = "Axe (Melee)" },
            { id = 28554, name = "Exercise Club", displayName = "Exercise Club", type = "Club (Melee)" },
            { id = 28555, name = "Exercise Bow", displayName = "Exercise Bow", type = "Bow (Distance)" },
            { id = 28556, name = "Exercise Rod", displayName = "Exercise Rod", type = "Rod (Druid)" },
            { id = 28557, name = "Exercise Wand", displayName = "Exercise Wand", type = "Wand (Sorcerer)" },
            { id = 44065, name = "Exercise Shield", displayName = "Exercise Shield", type = "Shield (Defense)" },
            { id = 50293, name = "Exercise Wraps", displayName = "Exercise Wraps", type = "Wraps (Fist)" },
        }
    },
    [3] = {
        name = "Durable",
        weapons = {
            { id = 35279, name = "Durable Exercise Sword", displayName = "Exercise Sword", type = "Sword (Melee)" },
            { id = 35280, name = "Durable Exercise Axe", displayName = "Exercise Axe", type = "Axe (Melee)" },
            { id = 35281, name = "Durable Exercise Club", displayName = "Exercise Club", type = "Club (Melee)" },
            { id = 35282, name = "Durable Exercise Bow", displayName = "Exercise Bow", type = "Bow (Distance)" },
            { id = 35283, name = "Durable Exercise Rod", displayName = "Exercise Rod", type = "Rod (Druid)" },
            { id = 35284, name = "Durable Exercise Wand", displayName = "Exercise Wand", type = "Wand (Sorcerer)" },
            { id = 44066, name = "Durable Exercise Shield", displayName = "Exercise Shield", type = "Shield (Defense)" },
            { id = 50294, name = "Durable Exercise Wraps", displayName = "Exercise Wraps", type = "Wraps (Fist)" },
        }
    },
    [4] = {
        name = "Lasting",
        weapons = {
            { id = 35285, name = "Lasting Exercise Sword", displayName = "Exercise Sword", type = "Sword (Melee)" },
            { id = 35286, name = "Lasting Exercise Axe", displayName = "Exercise Axe", type = "Axe (Melee)" },
            { id = 35287, name = "Lasting Exercise Club", displayName = "Exercise Club", type = "Club (Melee)" },
            { id = 35288, name = "Lasting Exercise Bow", displayName = "Exercise Bow", type = "Bow (Distance)" },
            { id = 35289, name = "Lasting Exercise Rod", displayName = "Exercise Rod", type = "Rod (Druid)" },
            { id = 35290, name = "Lasting Exercise Wand", displayName = "Exercise Wand", type = "Wand (Sorcerer)" },
            { id = 44067, name = "Lasting Exercise Shield", displayName = "Exercise Shield", type = "Shield (Defense)" },
            { id = 50295, name = "Lasting Exercise Wraps", displayName = "Exercise Wraps", type = "Wraps (Fist)" },
        }
    },
    [5] = {
        name = "Boosted",
        weapons = {
            { id = 41080, name = "Boosted Exercise Sword", displayName = "Exercise Sword", type = "Sword (Melee)" },
            { id = 41081, name = "Boosted Exercise Axe", displayName = "Exercise Axe", type = "Axe (Melee)" },
            { id = 41082, name = "Boosted Exercise Club", displayName = "Exercise Club", type = "Club (Melee)" },
            { id = 41085, name = "Boosted Exercise Bow", displayName = "Exercise Bow", type = "Bow (Distance)" },
            { id = 41084, name = "Boosted Exercise Rod", displayName = "Exercise Rod", type = "Rod (Druid)" },
            { id = 41086, name = "Boosted Exercise Wand", displayName = "Exercise Wand", type = "Wand (Sorcerer)" },
            { id = 41083, name = "Boosted Exercise Shield", displayName = "Exercise Shield", type = "Shield (Defense)" },
            { id = 41087, name = "Boosted Exercise Wraps", displayName = "Exercise Wraps", type = "Wraps (Fist)" },
        }
    }
}

local idToGroup = {}
local idToWeapon = {}

for groupId, group in pairs(EXERCISE_GROUPS) do
    for _, w in ipairs(group.weapons) do
        idToGroup[w.id] = groupId
        idToWeapon[w.id] = w
    end
end

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

function isExerciseWeapon(itemId)
    return idToGroup[itemId] ~= nil
end

local function updateSelectionFeedback()
    if not window then return end

    local targetInfoLabel = window:recursiveGetChildById('targetInfoLabel')
    local exchangeBtn = window:recursiveGetChildById('exchangeButton')

    if not selectedWeaponData then
        if targetInfoLabel then
            targetInfoLabel:setText(tr("Click on a weapon slot above to select it."))
            targetInfoLabel:setColor("#a0a0a0")
        end
        if exchangeBtn then
            exchangeBtn:setEnabled(false)
        end
        return
    end

    local weaponName = selectedWeaponData.displayName or selectedWeaponData.name

    if playerMoney > 0 and playerMoney < totalCost then
        if targetInfoLabel then
            targetInfoLabel:setText(string.format("Selected: %s - Insufficient Gold!", weaponName))
            targetInfoLabel:setColor("#ff6060")
        end
        if exchangeBtn then
            exchangeBtn:setEnabled(false)
        end
    else
        if targetInfoLabel then
            targetInfoLabel:setText(string.format("Selected: %s", weaponName))
            targetInfoLabel:setColor("#ffcc00")
        end
        if exchangeBtn then
            exchangeBtn:setEnabled(true)
        end
    end
end

local function selectTargetSlot(slot, weapon)
    if not slot or not slot:isEnabled() then
        return
    end

    if selectedSlot == slot then
        return
    end

    -- Strict single selection: deselect previous slot
    if selectedSlot and selectedSlot ~= slot then
        selectedSlot:setChecked(false)
    end

    selectedSlot = slot
    selectedTargetId = weapon.id
    selectedWeaponData = weapon
    slot:setChecked(true)

    updateSelectionFeedback()
end

local function sendExchange()
    if not currentExerciseItem or not selectedTargetId then
        return
    end

    local protocol = g_game.getProtocolGame()
    if not protocol then
        return
    end

    local pos = currentExerciseItem:getPosition()
    local payload = {
        action = "exchange",
        fromId = currentExerciseItem:getId(),
        toId = selectedTargetId,
        position = pos and { x = pos.x, y = pos.y, z = pos.z } or nil,
        stackPos = currentExerciseItem:getStackPos() or 0
    }

    protocol:sendExtendedOpcode(OPCODE_EXERCISE_EXCHANGE, json.encode(payload))

    -- Real-time instant close requested by user
    destroy()
end

local function populateWeaponsGrid(weaponsList, currentId)
    if not window then return end
    local container = window:recursiveGetChildById('slotsContainer')
    if not container then return end

    container:destroyChildren()
    optionSlots = {}
    selectedSlot = nil
    selectedTargetId = nil
    selectedWeaponData = nil

    for _, weapon in ipairs(weaponsList) do
        local slot = g_ui.createWidget('WeaponSlot', container)
        local itemWidget = slot:getChildById('item')
        if itemWidget then
            itemWidget:setItemId(weapon.id)
        end

        local displayName = weapon.displayName or weapon.name
        if displayName == weapon.name then
            displayName = displayName:gsub("^%a+%s+[eE]xercise%s+", "Exercise ")
        end

        if weapon.id == currentId then
            slot:setEnabled(false)
            slot:setChecked(false)
            slot:setTooltip(string.format("%s\n[Current Weapon]", displayName))
        else
            slot:setEnabled(true)
            slot:setChecked(false)
            slot:setTooltip(displayName)

            slot.onClick = function()
                selectTargetSlot(slot, weapon)
            end

            table.insert(optionSlots, slot)
        end
    end
end

local function updateGoldBoxes()
    if not window then return end

    local costBox = window:recursiveGetChildById('costGoldBox')
    local playerBox = window:recursiveGetChildById('playerGoldBox')

    if costBox then
        local valueLabel = costBox:getChildById('value')
        if valueLabel then
            valueLabel:setText(formatNumber(totalCost))
            if playerMoney > 0 and playerMoney < totalCost then
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
            if playerMoney > 0 and playerMoney < totalCost then
                valueLabel:setColor("#ff6060")
            else
                valueLabel:setColor("#BDBDBD")
            end
        end
    end
end

function open(item)
    if not item or not isExerciseWeapon(item:getId()) then
        return
    end

    currentExerciseItem = item
    selectedTargetId = nil
    selectedSlot = nil
    selectedWeaponData = nil
    optionSlots = {}

    local currentId = item:getId()
    local groupId = idToGroup[currentId]
    local group = EXERCISE_GROUPS[groupId]

    if not group then
        return
    end

    -- Initial charges estimation from client (fallback before server response)
    local charges = 0
    if item.getCharges and type(item.getCharges) == "function" then
        charges = item:getCharges() or 0
    end
    if charges <= 1 then
        charges = (group.name == "Lasting" and 14400)
               or (group.name == "Boosted" and 14400)
               or (group.name == "Durable" and 1800)
               or 500
    end
    currentCharges = charges
    totalCost = currentCharges * COST_PER_CHARGE

    if window then
        window:destroy()
    end

    window = g_ui.displayUI('exercise_exchange')
    if not window then
        return
    end

    -- Header Panel
    local upper = window:getChildById('upperPanel')
    upper:recursiveGetChildById('currentItem'):setItemId(currentId)

    local currentData = idToWeapon[currentId]
    local rawName = currentData and currentData.name or (item:getName() or "Exercise Weapon")
    local weaponName = toTitleCase(rawName)

    upper:getChildById('currentNameLabel'):setText(weaponName)
    upper:getChildById('currentChargesLabel'):setText(tr("Charges: %s", formatNumber(currentCharges)))
    upper:getChildById('currentTierLabel'):setText(tr("Tier: %s (100 GP / charge)", group.name))

    -- Gold Boxes (Cyclopedia style)
    updateGoldBoxes()

    -- Populate weapon slots
    populateWeaponsGrid(group.weapons, currentId)

    -- Action Buttons
    local exchangeBtn = window:getChildById('exchangeButton')
    exchangeBtn:setEnabled(false)
    exchangeBtn.onClick = sendExchange

    window:show()
    window:raise()
    window:focus()

    -- Request authoritative details from server
    local protocol = g_game.getProtocolGame()
    if protocol then
        local pos = item:getPosition()
        protocol:sendExtendedOpcode(OPCODE_EXERCISE_EXCHANGE, json.encode({
            action = "open",
            fromId = currentId,
            position = pos and { x = pos.x, y = pos.y, z = pos.z } or nil,
            stackPos = item:getStackPos() or 0
        }))
    end
end

function destroy()
    if window then
        window:destroy()
        window = nil
    end
    currentExerciseItem = nil
    selectedTargetId = nil
    selectedSlot = nil
    selectedWeaponData = nil
    optionSlots = {}
end

local function onExtendedOpcode(protocol, opcode, buffer)
    if opcode ~= OPCODE_EXERCISE_EXCHANGE then
        return
    end

    local status, data = pcall(json.decode, buffer)
    if not status or type(data) ~= "table" then
        return
    end

    if data.action == "open" then
        if not window then return end

        currentCharges = data.charges or currentCharges
        totalCost = data.totalCost or (currentCharges * COST_PER_CHARGE)
        playerMoney = data.playerMoney or 0

        local upper = window:getChildById('upperPanel')
        if upper then
            upper:getChildById('currentNameLabel'):setText(toTitleCase(data.fromName) or "Exercise Weapon")
            upper:getChildById('currentChargesLabel'):setText(tr("Charges: %s", formatNumber(currentCharges)))
            upper:getChildById('currentTierLabel'):setText(tr("Tier: %s (100 GP / charge)", data.tier or "Exercise"))
        end

        updateGoldBoxes()
        updateSelectionFeedback()
        return
    end

    if not window then
        return
    end

    if data.action == "success" then
        -- Real-time instant close on success confirmation
        destroy()
    elseif data.action == "error" then
        local targetInfoLabel = window:recursiveGetChildById('targetInfoLabel')
        if targetInfoLabel then
            targetInfoLabel:setText(data.message or tr("Failed to exchange weapon."))
            targetInfoLabel:setColor("#ff6060")
        end
        local exchangeBtn = window:recursiveGetChildById('exchangeButton')
        if exchangeBtn and selectedTargetId and playerMoney >= totalCost then
            exchangeBtn:setEnabled(true)
        end
    end
end

local function onGameEnd()
    destroy()
end

function init()
    ProtocolGame.registerExtendedOpcode(OPCODE_EXERCISE_EXCHANGE, onExtendedOpcode)
    connect(g_game, {
        onGameEnd = onGameEnd
    })
end

function terminate()
    ProtocolGame.unregisterExtendedOpcode(OPCODE_EXERCISE_EXCHANGE)
    disconnect(g_game, {
        onGameEnd = onGameEnd
    })
    destroy()
end
