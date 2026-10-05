-- Customise Podium: the window the server opens (0xC2) when a Podium of Vigour or a Podium of
-- Tenacity is used. Layout from the RTC module, which follows the official
-- ConfigureCreaturePodiumDialog; the choice goes back to the server as 0x9F.
local window = nil
local creatureList = nil
local previewItem = nil
local previewCreature = nil

-- What the open window configures.
local podium = nil
-- Entries the server allows: { raceId, name, outfit }.
local entries = {}
local selectedRaceId = 0
local selectedWidget = nil

function init()
    window = g_ui.displayUI('podium')
    window:hide()
    creatureList = window:recursiveGetChildById('creatureList')
    previewCreature = window:recursiveGetChildById('creature')

    connect(g_game, {
        onParseMonsterPodium = onParseMonsterPodium,
        onGameEnd = hide
    })
end

function terminate()
    disconnect(g_game, {
        onParseMonsterPodium = onParseMonsterPodium,
        onGameEnd = hide
    })
    if window then
        window:destroy()
        window = nil
    end
    creatureList = nil
    previewItem = nil
    previewCreature = nil
end

local function isSameLook(a, b)
    return a and b and a.type == b.type and (a.auxType or 0) == (b.auxType or 0)
end

local function updatePreviewCreature()
    if not podium.showCreature or not podium.outfit then
        previewCreature:hide()
        return
    end

    previewCreature:setOutfit(podium.outfit)
    previewCreature:setDirection(podium.direction)
    -- Stands on the pedestal like a creature on an elevated item (scale 2).
    local elevation = 0
    local thingType = podium.podiumVisible and g_things.getThingType(podium.itemId, ThingCategoryItem)
    if thingType then
        elevation = thingType:getElevation()
    end
    previewCreature:setMarginTop(31 - elevation * 2)
    previewCreature:show()
end

local function selectWidget(widget)
    if selectedWidget and not selectedWidget:isDestroyed() then
        selectedWidget.checkBox:setChecked(false)
    end
    selectedWidget = widget
    if widget then
        widget.checkBox:setChecked(true)
    end
end

local function fillList(filter)
    selectedWidget = nil
    creatureList:destroyChildren()
    filter = filter and filter:lower() or ''

    for _, entry in ipairs(entries) do
        if #filter == 0 or entry.name:lower():find(filter, 1, true) then
            local widget = g_ui.createWidget('PodiumCreatureBox', creatureList)
            widget.raceId = entry.raceId
            widget.outfit = entry.outfit
            widget.checkBox.name:setText(entry.name)
            widget.checkBox.creature:setOutfit(entry.outfit)
            local chosen = selectedRaceId ~= 0 and entry.raceId == selectedRaceId
            if chosen or (selectedRaceId == 0 and isSameLook(entry.outfit, podium.currentOutfit)) then
                selectWidget(widget)
            else
                widget.checkBox:setChecked(false)
            end
        end
    end
end

function onParseMonsterPodium(currentOutfit, bossPodium, bosses, monsters, position, itemId, stackPos, podiumVisible,
                              creatureVisible, direction)
    entries = {}
    if bossPodium then
        for _, boss in ipairs(bosses) do
            table.insert(entries, { raceId = boss[1], name = string.capitalize(boss[2]), outfit = boss[3] })
        end
    else
        for _, raceId in ipairs(monsters) do
            local race = g_things.getRaceData(raceId)
            if race and race.raceId ~= 0 then
                table.insert(entries, { raceId = raceId, name = string.capitalize(race.name), outfit = race.outfit })
            end
        end
    end
    table.sort(entries, function(a, b) return a.name < b.name end)

    local shown = creatureVisible and currentOutfit and (currentOutfit.type ~= 0 or (currentOutfit.auxType or 0) ~= 0)
    podium = {
        position = position,
        itemId = itemId,
        stackPos = stackPos,
        direction = direction,
        podiumVisible = podiumVisible,
        showCreature = creatureVisible,
        -- The server keeps the podium's creature when 0 is sent back.
        currentOutfit = shown and currentOutfit or nil,
        outfit = shown and currentOutfit or nil
    }
    selectedRaceId = 0

    local itemWidget = window:recursiveGetChildById('item')
    itemWidget:setItemId(itemId)
    previewItem = itemWidget:getItem()
    if previewItem then
        previewItem:setPodiumVisible(podiumVisible)
    end
    updatePreviewCreature()

    window:recursiveGetChildById('creatureShow'):setChecked(creatureVisible)
    window:recursiveGetChildById('podiumShow'):setChecked(podiumVisible)
    window:recursiveGetChildById('floorShow'):setChecked(true)
    window:recursiveGetChildById('searchText'):clearText()
    fillList()

    window:show()
    window:raise()
    window:focus()
end

function hide()
    if window then
        window:hide()
    end
    podium = nil
    previewItem = nil
    selectedWidget = nil
    if creatureList then
        creatureList:destroyChildren()
    end
end

function selectCreature(widget)
    if not podium then
        return
    end
    selectWidget(widget)
    selectedRaceId = widget.raceId
    podium.outfit = widget.outfit
    updatePreviewCreature()
end

function showCreature(checked)
    if not podium then
        return
    end
    podium.showCreature = checked
    updatePreviewCreature()
end

function showPodium(checked)
    if not podium then
        return
    end
    podium.podiumVisible = checked
    if previewItem then
        previewItem:setPodiumVisible(checked)
    end
    updatePreviewCreature()
end

function showFloor(checked)
    if not window then
        return
    end
    local ground = window:recursiveGetChildById('previewGround')
    ground:setImageSource(checked and '/game_podium_monster/images/outfit_ground' or
                              '/game_podium_monster/images/panel-background')
end

function rotate(toRight)
    if not podium then
        return
    end
    -- Directions go North, East, South, West (0..3); the right arrow steps back, as in the RTC.
    podium.direction = (podium.direction + (toRight and 3 or 1)) % 4
    updatePreviewCreature()
end

function onSearchChange(text)
    if podium then
        fillList(text)
    end
end

function apply()
    if not podium then
        return
    end
    local raceId = podium.showCreature and selectedRaceId or 0
    g_game.setMonsterPodium(raceId, podium.position, podium.itemId, podium.stackPos, podium.direction,
        podium.podiumVisible, podium.showCreature)
    hide()
end
