-- Ranked task system window. The server side is data/libs/systems/task_system.lua (Canary); both
-- talk over the extended JSON opcode below.
tasksWindow = nil
tasksConfirmWindow = nil
tasksWindowButton = nil

TASKS_OPCODE = 143

local enums = {
    states = {
        Locked = 0,
        Available = 1,
        Active = 2,
        Finished = 3,
        SecondAvailable = 4,
        SecondActive = 5,
        SecondFinished = 6,
        SecondLocked = 7
    },
    actions = {
        request = 0,
        start = 1,
        cancel = 2,
        claim = 3,
        claimSpecial = 4,
        rerollSpecial = 5
    },
    rewards = {
        locked = 0,
        available = 1,
        claimed = 2
    },
    categories = {
        [1] = {
            name = "Aprendiz",
            description = "Criaturas comuns dos arredores das cidades, cavernas rasas e florestas. Sao tasks curtas, feitas para quem esta comecando: pouca exigencia de equipamento e boa experiencia para o nivel.\n\nConclua todas as tasks deste rank para liberar o proximo e a recompensa do hall.\n\nSeu progresso neste rank:",
            color = "#e6f0d0ff",
            hall = "Hall dos Aprendizes"
        },
        [2] = {
            name = "Caçador",
            description = "Dragoes, gigantes, necromantes e outras criaturas que ja pedem um personagem preparado. As tasks ficam mais longas e as recompensas passam a incluir tokens.\n\nConclua todas as tasks deste rank para liberar o proximo e a recompensa do hall.\n\nSeu progresso neste rank:",
            color = "#d6e6f0ff",
            hall = "Hall dos Caçadores"
        },
        [3] = {
            name = "Veterano",
            description = "Hunts de nivel alto, com criaturas que causam muito dano e aparecem em grande quantidade. Planeje supplies e rotas antes de comecar.\n\nConclua todas as tasks deste rank para liberar o proximo e a recompensa do hall.\n\nSeu progresso neste rank:",
            color = "#f0e0c8ff",
            hall = "Hall dos Veteranos"
        },
        [4] = {
            name = "Campeão",
            description = "Demonios, criaturas de areas avancadas e hunts de party. Cada task exige milhares de abates; em compensacao, as recompensas sao grandes.\n\nConclua todas as tasks deste rank para liberar o proximo e a recompensa do hall.\n\nSeu progresso neste rank:",
            color = "#f0cfcaff",
            hall = "Hall dos Campeões"
        },
        [5] = {
            name = "Lendário",
            description = "O conteudo mais dificil do jogo: criaturas das areas mais recentes, em hunts longas e perigosas. Para os personagens mais fortes.\n\nConclua todas as tasks deste rank para receber a recompensa do hall.\n\nSeu progresso neste rank:",
            color = "#e2d3f0ff",
            hall = "Hall dos Lendários"
        },
    }
}

-- The bitmap fonts draw one byte per glyph (Latin-1); this file is UTF-8, so accented names are converted.
local function latin1(text)
    return (text:gsub('[\194\195][\128-\191]', function(pair)
        local lead, tail = pair:byte(1, 2)
        return string.char((lead - 192) * 64 + (tail - 128))
    end))
end

for index, category in ipairs(enums.categories) do
    category.name = latin1(category.name)
    category.hall = latin1(category.hall)
    category.image = '/game_ranktasks/images/rank_' .. index
    category.icon = '/game_ranktasks/images/tab_' .. index
    category.hallBackground = '/game_ranktasks/images/hall_' .. index
end

-- Helpers ---------------------------------------------------------------------------------------

-- Child widgets reachable as fields (widget.title, widget.count, ...).
local function bindChildren(widget)
    for _, child in ipairs(widget:getChildren()) do
        local id = child:getId()
        if id and id ~= '' then
            widget[id] = child
        end
        bindChildren(child)
    end
end

local function raceOutfit(raceId)
    local raceData = raceId and raceId > 0 and g_things.getRaceData(raceId)
    if not raceData or not raceData.outfit then
        return nil, nil
    end
    return raceData.outfit, raceData.name
end

local function capitalize(text)
    return (tostring(text or ''):gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end))
end

local function formatCount(count)
    if count < 1000 then
        return tostring(count)
    end
    if count < 1000000 then
        local value = count / 1000
        return (value == math.floor(value) and tostring(value) or string.format('%.1f', value)) .. 'k'
    end
    return tostring(math.floor(count / 1000000)) .. 'kk'
end

local function percentOf(kills, total, width)
    if not total or total <= 0 then
        return width
    end
    return math.max(0, math.min(width, math.floor((kills * width) / total)))
end

local function itemName(item)
    local market = item.getMarketData and item:getMarketData()
    if market and market.name and market.name ~= '' then
        return market.name
    end
    local thingType = g_things.getThingType(item:getId(), ThingCategoryItem)
    return thingType and thingType:getName() or ''
end

-- This client has no text-truncate: shorten with '...' until the text fits (the tooltip keeps the full name).
local function setFittedText(label, text, maxWidth)
    label:setText(text)
    if label:getTextSize().width <= maxWidth then
        return
    end
    while #text > 1 do
        text = text:sub(1, -2)
        label:setText(text .. '...')
        if label:getTextSize().width <= maxWidth then
            return
        end
    end
end

local function sendAction(action, id)
    local protocol = g_game.getProtocolGame()
    if protocol then
        protocol:sendExtendedJSONOpcode(TASKS_OPCODE, { action = action, id = id or 0 })
    end
end

local function setCreature(widget, raceId)
    local outfit = raceOutfit(raceId)
    if not outfit then
        widget:hide()
        return false
    end
    widget:show()
    widget:setOutfit(outfit)
    return true
end

-- Stackable rewards keep their own amount (capped to a full stack, for the sprite); anything else is one item.
local function setRewardItem(widget, reward)
    widget.item:setItemId(reward.item)
    local thingType = g_things.getThingType(reward.item, ThingCategoryItem)
    widget.item:setItemCount(thingType and thingType:isStackable() and math.max(1, math.min(reward.count, 100)) or 1)
end

local function fillRewards(list, experienceLabel, rewards)
    experienceLabel:setText('0')
    list:destroyChildren()
    for _, reward in ipairs(rewards) do
        if reward.item == 0 then
            experienceLabel:setText(comma_value(reward.count))
        else
            local widget = g_ui.createWidget(reward.special and 'TaskPremiumItem' or 'TaskItem', list)
            bindChildren(widget)
            setRewardItem(widget, reward)
            local item = widget.item:getItem()
            if item then
                local countText = formatCount(reward.count) .. 'x '
                if reward.countMax > 0 then
                    countText = 'De ' .. formatCount(reward.count) .. 'x a ' .. formatCount(reward.countMax) .. 'x '
                end
                widget:setTooltip(countText .. itemName(item))
            end
            if reward.count > 1 or (item and item:isStackable()) then
                widget.count:show()
                if reward.countMax > 0 then
                    widget.count:setText(tostring(reward.count) .. '/' .. tostring(reward.countMax))
                else
                    widget.count:setText(formatCount(reward.count))
                end
            else
                widget.count:hide()
            end
        end
    end
end

-- Window lifecycle -------------------------------------------------------------------------------

function init()
    tasksWindow = g_ui.displayUI('ranktasks')
    tasksWindow:hide()
    bindChildren(tasksWindow)

    tasksWindow.var = {
        currentPage = 1,
        grid = {}
    }

    local minimap = tasksWindow.main.selectedPanel.overall.mapBorder.minimap
    minimap:setZoom(2)
    if minimap.disableAutoWalk then
        minimap:disableAutoWalk()
    end
    minimap.autowalk = false
    if minimap.setUseStaticMinimap then
        minimap:setUseStaticMinimap(true)
    end
    -- Underground floors come from the map generated from the server (data/servermap).
    if minimap.setUseServerMinimap then
        minimap:setUseServerMinimap(true)
    end

    -- The balance at the bottom is in task points, not gold.
    tasksWindow.balance.icon:setImageSource('/game_taskboard/assets/images/icon_tasksystem_promotionpoint')
    tasksWindow.balance.icon:setTooltip('Pontos de task')

    for index, tab in ipairs(tasksWindow.main.gridPanel.tabs:getChildren()) do
        local category = enums.categories[index]
        if category then
            tab:setText(category.name)
        end
    end

    tasksWindowButton = modules.game_mainpanel.addToggleButton('tasksWindowButton', tr('Tasks'),
        '/game_ranktasks/images/button_task_window', tryOpen, false, 25)
    tasksWindowButton:setOn(false)

    ProtocolGame.registerExtendedJSONOpcode(TASKS_OPCODE, onExtendedOpcode)
    connect(g_game, {
        onGameEnd = hide
    })
end

function terminate()
    ProtocolGame.unregisterExtendedJSONOpcode(TASKS_OPCODE)
    disconnect(g_game, {
        onGameEnd = hide
    })

    if tasksConfirmWindow ~= nil then
        tasksConfirmWindow:destroy()
        tasksConfirmWindow = nil
    end
    tasksWindow:destroy()
    tasksWindowButton:destroy()
    tasksWindow = nil
    tasksWindowButton = nil
end

function onExtendedOpcode(protocol, opcode, data)
    if type(data) ~= 'table' then
        return
    end
    if data.points ~= nil and tasksWindow then
        tasksWindow.balance.text:setText(comma_value(data.points))
    end
    if data.type == 'list' then
        local ranks = data.ranks or {}
        onTasksList(data.points or 0, ranks[1] or {}, ranks[2] or {}, ranks[3] or {}, ranks[4] or {}, ranks[5] or {})
    elseif data.type == 'selected' then
        onTaskSelectedCreature(data.id, data.name, data.raceId, data.kills, data.total, data.rewards or {}, data.state,
            data.hunts or {}, data.creatures or {})
    elseif data.type == 'reward' then
        onTaskRewardDay(data.level, data.state, data.rewards or {}, data.tasks or {})
    elseif data.type == 'special' then
        onSpecialTask(data.locked, data.message, data.id, data.name, data.stars, data.background, data.kills, data.total,
            data.reroll, data.balance, data.rewards or {}, data.state, data.creatures or {})
    elseif data.type == 'tracker' then
        if modules.game_ranktaskstracker and modules.game_ranktaskstracker.onTaskTracker then
            modules.game_ranktaskstracker.onTaskTracker(data.list or {})
        end
    end
end

function hide()
    if tasksWindowButton then
        tasksWindowButton:setOn(false)
    end
    if tasksWindow then
        tasksWindow:hide()
    end
    if tasksConfirmWindow ~= nil then
        tasksConfirmWindow:destroy()
        tasksConfirmWindow = nil
    end
end

function backToGrid()
    tasksWindow:setWidth(911)
    tasksWindow:setHeight(670)
    tasksWindow.main.selectedPanel:hide()
    tasksWindow.main.gridPanel:show()
    tasksWindow.main.loading:hide()
    tasksWindow.main.rewardPanel:hide()
    tasksWindow.back:hide()
end

function tryOpen()
    if tasksWindow:isVisible() then
        hide()
        return
    end
    sendAction(enums.actions.request, 0)
end

function show()
    if not tasksWindow:isVisible() then
        tasksWindowButton:setOn(true)
        tasksWindow:show()
        tasksWindow:raise()
        tasksWindow:focus()
    end
end

-- Selected task ---------------------------------------------------------------------------------

-- The hunt map shows the whole world from the client's static map (like the Cyclopedia map),
-- not only what the character has explored.
local loadedMapFloors = {}
function loadMapFloor(floor)
    if loadedMapFloors[floor] then
        return
    end
    if floor > 7 and g_serverMinimap then
        g_serverMinimap.loadFloors('/data/servermap', floor, floor)
    elseif g_satelliteMap then
        g_satelliteMap.loadFloors(string.format("/data/things/%d", g_game.getClientVersion()), floor, floor)
    end
    loadedMapFloors[floor] = true
end

function onClickHuntOption(widget, hunt)
    for _, c in ipairs(tasksWindow.main.selectedPanel.preview.list:getChildren()) do
        if c ~= widget then
            c:setBackgroundColor(c.originBackground)
        end
    end

    widget:setBackgroundColor('#6d6d6d')

    local overall = tasksWindow.main.selectedPanel.overall
    overall.title:setText(hunt.name)
    local position = { x = hunt.position.x, y = hunt.position.y, z = hunt.position.z }
    loadMapFloor(position.z)
    overall.mapBorder.minimap:setCameraPosition(position)
    overall.mapBorder.minimap:setCrossPosition(position)
    overall.mapBorder.layersPanel.layersMark:setMarginTop(((position.z + 1) * 4) - 3)
    overall.mapBorder.layersPanel.automapLayers:setImageClip((position.z * 14) .. ' 0 14 67')
    overall.soloLevel.value:setText(comma_value(hunt.solo))
    overall.partyLevel.value:setText(comma_value(hunt.party))

    for i = 1, 5 do
        local expStar = overall.exp['star' .. i]
        if expStar ~= nil then
            expStar:setEnabled(i <= hunt.experience)
        end
        local lootStar = overall.loot['star' .. i]
        if lootStar ~= nil then
            lootStar:setEnabled(i <= hunt.loot)
        end
    end

    for _, c in ipairs(tasksWindow.main.selectedPanel.creatures.list:getChildren()) do
        local present = table.find(hunt.creatures, c.raceId) ~= nil
        c.mask:setVisible(not present)
        c.icon:setVisible(not present)
    end
end

function onTaskRewardDay(level, state, rewards, tasks)
    local info = enums.categories[level]
    if info == nil then
        return
    end

    local main = tasksWindow.main.rewardPanel.main
    main.image:setImageSource(info.image)
    main.text:setText(info.name)
    main.text:setColor(info.color)
    for _, location in ipairs({ "_left_", "_right_" }) do
        for i = 1, 5 do
            main["star" .. location .. i]:setEnabled(i <= level)
        end
    end

    local rewardsPanel = tasksWindow.main.rewardPanel.rewards
    rewardsPanel.list:destroyChildren()
    for _, reward in ipairs(rewards) do
        local widget = g_ui.createWidget('TaskPremiumItem', rewardsPanel.list)
        bindChildren(widget)
        setRewardItem(widget, reward)
        local item = widget.item:getItem()
        if item then
            widget:setTooltip(formatCount(reward.count) .. 'x ' .. itemName(item))
        end
        if reward.count > 1 or (item and item:isStackable()) then
            widget.count:show()
            widget.count:setText(formatCount(reward.count))
        else
            widget.count:hide()
        end
    end

    local claim = rewardsPanel.claim
    claim.onClick = nil
    if state == enums.rewards.locked then
        claim:setImageSource('/game_ranktasks/images/button_red')
        claim:setEnabled(false)
        claim:setText('Bloqueada')
    elseif state == enums.rewards.available then
        claim:setImageSource('/game_ranktasks/images/button_blue')
        claim:setEnabled(true)
        claim:setText('Resgatar')
        claim.onClick = function()
            sendAction(enums.actions.claim, level * 1000)
        end
    elseif state == enums.rewards.claimed then
        claim:setImageSource('/game_ranktasks/images/button_blue')
        claim:setEnabled(false)
        claim:setText('Resgatado')
    end

    local overview = tasksWindow.main.rewardPanel.overview
    overview.description:setText(info.description)
    overview.list:destroyChildren()
    for _, task in ipairs(tasks) do
        local widget = g_ui.createWidget('TaskResumeEntry', overview.list)
        bindChildren(widget)
        widget.name:setText(task.name .. ":")
        widget.value:setText(task.progress .. "%")
        if task.second or task.progress >= 100 then
            widget.iconYes:show()
            if task.second and task.progress < 100 then
                widget.second:show()
            end
        elseif task.progress > 0 then
            widget.iconTimer:show()
        else
            widget.iconNo:show()
        end
    end

    tasksWindow:setWidth(865)
    tasksWindow:setHeight(600)
    tasksWindow.main.rewardPanel:show()
    tasksWindow.main.selectedPanel:hide()
    tasksWindow.main.gridPanel:hide()
    tasksWindow.main.loading:hide()
    tasksWindow.back:show()
    show()
end

function onTaskSelectedCreature(id, name, raceId, kills, total, rewards, state, hunts, creatures)
    local panel = tasksWindow.main.selectedPanel
    panel.preview.title:setText(name)
    panel.preview.progress.bar:setWidth(percentOf(kills, total, 161))
    panel.preview.progress.text:setText(comma_value(kills) .. " / " .. comma_value(total))
    panel.preview.progress.bar:setBackgroundColor(kills >= total and '#00ff2a' or '#2effe7')

    setCreature(panel.preview.creature, raceId)

    panel.creatures.list:destroyChildren()
    for _, cInfo in ipairs(creatures) do
        local outfit, raceName = raceOutfit(cInfo.raceId)
        if outfit then
            local cWidget = g_ui.createWidget('TaskMonsterBlock', panel.creatures.list)
            bindChildren(cWidget)
            cWidget.raceId = cInfo.raceId
            cWidget:setTooltip(capitalize(raceName))
            setFittedText(cWidget.title, capitalize(raceName), 79)
            cWidget.creature:setOutfit(outfit)
            for i = 1, 5 do
                local star = cWidget.starBackground['star' .. i]
                if star ~= nil then
                    star:setEnabled(i <= cInfo.stars)
                end
            end
        end
    end

    table.sort(hunts, function(a, b)
        if a.stars ~= b.stars then
            return a.stars > b.stars
        end
        if a.experience ~= b.experience then
            return a.experience > b.experience
        end
        if a.loot ~= b.loot then
            return a.loot > b.loot
        end
        if #a.creatures ~= #b.creatures then
            return #a.creatures > #b.creatures
        end
        return a.name:lower() < b.name:lower()
    end)

    panel.preview.list:destroyChildren()
    for index, hunt in ipairs(hunts) do
        local widget = g_ui.createWidget('TaskHuntOption', panel.preview.list)
        bindChildren(widget)
        widget.originBackground = (index % 2) ~= 0 and '#484848' or 'alpha'
        widget:setBackgroundColor(widget.originBackground)
        widget:setTooltip(hunt.name)
        widget.text:setText(hunt.name)
        local lastVisibleStar = nil
        for i = 1, 5 do
            local star = widget['star' .. i]
            if star ~= nil then
                star:setVisible(i <= hunt.stars)
                if i <= hunt.stars then
                    lastVisibleStar = i
                end
            end
        end
        if lastVisibleStar ~= nil then
            widget.text:addAnchor(AnchorRight, 'star' .. lastVisibleStar, AnchorLeft)
        else
            widget.text:addAnchor(AnchorRight, 'parent', AnchorRight)
        end
        widget.onClick = function()
            onClickHuntOption(widget, hunt)
        end
        if index == 1 then
            onClickHuntOption(widget, hunt)
        end
    end

    fillRewards(panel.actions.list, panel.actions.experience.text, rewards)

    panel.preview.progress:show()
    panel.preview.list:setMarginTop(25)
    panel.preview.background:setMarginTop(10)

    local claim = panel.actions.claim
    claim.onClick = nil
    if state == enums.states.Locked or state == enums.states.SecondLocked then
        panel.preview.progress:hide()
        panel.preview.list:setMarginTop(10)
        panel.preview.background:setMarginTop(20)
        claim:setImageSource('/game_ranktasks/images/button_red')
        claim:setEnabled(false)
        claim:setText('Bloqueada')
    elseif state == enums.states.Active or state == enums.states.SecondActive then
        claim:setImageSource('/game_ranktasks/images/button_red')
        claim:setEnabled(true)
        claim:setText('Cancelar')
        claim.onClick = function()
            sendAction(enums.actions.cancel, id)
        end
    elseif state == enums.states.Finished or state == enums.states.SecondFinished then
        claim:setImageSource('/game_ranktasks/images/button_blue')
        claim:setEnabled(true)
        claim:setText('Resgatar')
        claim.onClick = function()
            sendAction(enums.actions.claim, id)
        end
    elseif state == enums.states.Available or state == enums.states.SecondAvailable then
        panel.preview.progress:hide()
        panel.preview.list:setMarginTop(10)
        panel.preview.background:setMarginTop(20)
        claim:setImageSource('/game_ranktasks/images/button_green')
        claim:setText(state == enums.states.Available and 'Iniciar' or 'Repetir')
        claim:setEnabled(true)
        claim.onClick = function()
            sendAction(enums.actions.start, id)
        end
    end

    tasksWindow:setWidth(865)
    tasksWindow:setHeight(600)
    panel:show()
    tasksWindow.main.gridPanel:hide()
    tasksWindow.main.rewardPanel:hide()
    tasksWindow.main.loading:hide()
    tasksWindow.back:show()
    show()
end

-- Grid ------------------------------------------------------------------------------------------

function switchPage(increment)
    tasksWindow.var.currentPage = tasksWindow.var.currentPage + increment
    reloadPageContent(tasksWindow.var.search, false)
end

function getCurrentTaskSelectedStage()
    for index, c in ipairs(tasksWindow.main.gridPanel.tabs:getChildren()) do
        if c:isChecked() then
            return index
        end
    end
    return 0
end

local function isDone(status)
    return status == enums.states.Finished or status == enums.states.SecondLocked or status == enums.states.SecondFinished
        or status == enums.states.SecondActive or status == enums.states.SecondAvailable
end

function reloadPageContent(search, resetPage)
    if tasksWindow == nil then
        return
    end
    local gridPanel = tasksWindow.main.gridPanel
    if getCurrentTaskSelectedStage() == 6 then
        gridPanel.specialPanel:show()
        tasksWindow.balanceGold:show()
        return
    end
    gridPanel.specialPanel:hide()
    tasksWindow.balanceGold:hide()

    local stage = getCurrentTaskSelectedStage()
    if #(tasksWindow.var.grid) == 0 or tasksWindow.var.grid[stage] == nil then
        gridPanel.list:destroyChildren()
        return
    end

    if resetPage then
        tasksWindow.var.currentPage = 1
    end

    local searchText = gridPanel.search:getText()
    if not search or searchText == "" then
        gridPanel.search:clearText()
        search = false
        searchText = ""
    end
    tasksWindow.var.search = search

    local hasStageUnlocked = false
    local finishedCount = 0
    local availableList = {}
    local flags = gridPanel.filters.flags
    for _, entry in ipairs(tasksWindow.var.grid[stage]) do
        if entry.status ~= enums.states.Locked then
            hasStageUnlocked = true
        end
        if isDone(entry.status) then
            finishedCount = finishedCount + 1
        end
        if search then
            if entry.name:lower():find(searchText:lower(), 1, true) then
                table.insert(availableList, entry)
            end
        else
            local show = true
            if (entry.status == enums.states.Finished or entry.status == enums.states.SecondFinished or entry.status == enums.states.SecondLocked)
                and not flags.showCompleted:isChecked() then
                show = false
            end
            if entry.status == enums.states.Locked and not flags.showLocked:isChecked() then
                show = false
            end
            if (entry.status == enums.states.Active or entry.status == enums.states.SecondActive) and not flags.showActives:isChecked() then
                show = false
            end
            if (entry.status == enums.states.Available or entry.status == enums.states.SecondAvailable) and not flags.showAvailables:isChecked() then
                show = false
            end
            local starFilter = gridPanel.filters.starsBackground['star' .. math.min(5, entry.stars)]
            if show and (not starFilter or starFilter:isChecked()) then
                table.insert(availableList, entry)
            end
        end
    end

    -- The hall block takes the last slot of the last page, but only outside a search.
    local entriesPerPage = 8
    local slots = #availableList + (search and 0 or 1)
    local pages = math.max(1, math.ceil(slots / entriesPerPage))
    tasksWindow.var.currentPage = math.max(1, math.min(tasksWindow.var.currentPage, pages))
    local fromIndex = (tasksWindow.var.currentPage - 1) * entriesPerPage

    gridPanel.pages:setText("Pagina: " .. tasksWindow.var.currentPage .. "/" .. pages)
    gridPanel.prevPage:setEnabled(tasksWindow.var.currentPage > 1)
    gridPanel.nextPage:setEnabled(tasksWindow.var.currentPage < pages)

    gridPanel.list:destroyChildren()
    for i = fromIndex + 1, fromIndex + entriesPerPage do
        local entry = availableList[i]
        if entry ~= nil then
            createTaskBlock(entry)
        end
    end

    if not search and tasksWindow.var.currentPage == pages then
        createHallBlock(stage, hasStageUnlocked, finishedCount)
    end
end

function createTaskBlock(entry)
    local widget = g_ui.createWidget('TaskElementBlock', tasksWindow.main.gridPanel.list)
    bindChildren(widget)

    -- The card shows the task's own hunt (rendered from the game map); generic art when there is none.
    local huntImage = '/game_ranktasks/images/hunts/task_' .. entry.id
    if not g_resources.fileExists(huntImage .. '.png') then
        huntImage = '/game_ranktasks/images/hunt_' .. (entry.background or 0)
    end
    widget.background:setImageSource(huntImage)
    widget.title:setText(entry.name)
    widget.kills.text:setText(comma_value(entry.kills))
    for i = 1, 5 do
        widget.starBackground['star' .. i]:setEnabled(i <= entry.stars)
        widget.exp['star' .. i]:setEnabled(i <= entry.exp)
        widget.loot['star' .. i]:setEnabled(i <= entry.loot)
    end

    local status = { text = "", color = "" }
    if entry.status == enums.states.Active or entry.status == enums.states.SecondActive then
        status.text = entry.progress .. "%"
        status.color = "#bde8e4"
        widget.background:setBorderWidth(1)
        widget.background:setBorderColor('#bde8e457')
    elseif entry.status == enums.states.Finished or entry.status == enums.states.SecondFinished then
        status.text = "Resgatar"
        status.color = "#88de75"
        widget.background:setBorderWidth(1)
        widget.background:setBorderColor('#88de7587')
        widget.yes:show()
    elseif entry.status == enums.states.Locked or entry.status == enums.states.SecondLocked then
        status.text = "Bloqueada"
        status.color = "#de7575"
        widget.background:setBorderWidth(1)
        widget.background:setBorderColor('#de757587')
        widget.locker:show()
        widget.backgroundGrid:show()
    elseif entry.status == enums.states.Available then
        status.text = "Disponivel"
        status.color = "#c0de75"
        widget.background:setBorderWidth(1)
        widget.background:setBorderColor('#c0de7587')
    elseif entry.status == enums.states.SecondAvailable then
        status.text = "Repetir"
        status.color = "#c0de75"
        widget.background:setBorderWidth(1)
        widget.background:setBorderColor('#c0de7587')
    end
    widget.status:setText(status.text)
    widget.status:setColor(status.color)

    -- One creature goes to the middle, two to the sides, three fill the card.
    local raceIds = {}
    for i = 1, 3 do
        local raceId = entry['monster' .. i] or 0
        if raceId > 0 then
            table.insert(raceIds, raceId)
        end
        widget['creature' .. i]:hide()
    end
    local slots = #raceIds == 1 and { 'creature2' } or (#raceIds == 2 and { 'creature1', 'creature3' } or { 'creature1', 'creature2', 'creature3' })
    for index, raceId in ipairs(raceIds) do
        setCreature(widget[slots[index]], raceId)
    end

    widget.onClick = function()
        tasksWindow.main.selectedPanel:hide()
        tasksWindow.main.gridPanel:hide()
        tasksWindow.main.rewardPanel:hide()
        tasksWindow.main.loading:show()
        tasksWindow.back:show()
        sendAction(enums.actions.request, entry.id)
    end
    widget.kills.icon.onClick = function()
        widget.onClick()
    end
    connect(widget.kills.icon, {
        onHoverChange = function(_, hovered)
            widget:setBorderWidth(hovered and 1 or 0)
        end
    })
end

function createHallBlock(stage, hasStageUnlocked, finishedCount)
    local info = enums.categories[stage]
    if info == nil then
        return
    end
    local widget = g_ui.createWidget('TaskElementHallBlock', tasksWindow.main.gridPanel.list)
    bindChildren(widget)

    widget.title:setText(info.hall)
    widget.icon:setImageSource(info.icon)
    widget.background:setImageSource(info.hallBackground)

    local total = #(tasksWindow.var.grid[stage])
    if hasStageUnlocked and total > 0 then
        widget.status:setText(math.floor((finishedCount * 100) / total) .. "%")
        widget.status:setColor("#bde8e4")
    else
        widget.status:setText("Bloqueado")
        widget.status:setColor("#de7575")
        widget.backgroundGrid:show()
    end

    widget.onClick = function()
        tasksWindow.main.selectedPanel:hide()
        tasksWindow.main.gridPanel:hide()
        tasksWindow.main.rewardPanel:hide()
        tasksWindow.main.loading:show()
        tasksWindow.back:show()
        sendAction(enums.actions.request, stage * 1000)
    end
end

function onTasksList(points, list1, list2, list3, list4, list5)
    tasksWindow.var.grid = { list1, list2, list3, list4, list5 }

    if getCurrentTaskSelectedStage() == 0 then
        local first = tasksWindow.main.gridPanel.tabs:getChildByIndex(1)
        first.ignoreCallback = true
        first:setChecked(true)
        first.ignoreCallback = nil
    end
    reloadPageContent()

    tasksWindow:setWidth(911)
    tasksWindow:setHeight(670)
    tasksWindow.main.selectedPanel:hide()
    tasksWindow.main.gridPanel:show()
    tasksWindow.main.loading:hide()
    tasksWindow.main.rewardPanel:hide()
    tasksWindow.back:hide()
    tasksWindow.balance.text:setText(comma_value(points))
    show()
end

-- Special task ----------------------------------------------------------------------------------

local SPECIAL_BACKGROUNDS = { 'special_green', 'special_green', 'special_yellow', 'special_red', 'special_purple' }

function onSpecialTask(locked, message, id, name, stars, background, kills, total, reroll, balance, rewards, state, creatures)
    local specialPanel = tasksWindow.main.gridPanel.specialPanel
    local centerPanel = specialPanel.centerPanel
    if locked then
        centerPanel:hide()
        specialPanel.creatures:hide()
        specialPanel.rewards:hide()
        specialPanel.disabled:show()
        specialPanel.background:setImageSource('/game_ranktasks/images/special_green')
        specialPanel.disabled:setText(message or '')
        tasksWindow.balanceGold:hide()
        return
    end

    specialPanel.background:setImageSource('/game_ranktasks/images/' .. (SPECIAL_BACKGROUNDS[background] or 'special_green'))
    centerPanel:show()
    specialPanel.creatures:show()
    specialPanel.rewards:show()
    specialPanel.disabled:hide()
    tasksWindow.balanceGold.text:setText(comma_value(balance))

    setSpecialTaskTitle(name)

    for i = 1, 3 do
        local widget = centerPanel['star' .. i]
        if widget ~= nil then
            widget:setEnabled(i <= stars)
        end
    end

    local podiums, uiCreatures
    if #creatures == 2 then
        podiums = { centerPanel.leftPodium, centerPanel.rightPodium, centerPanel.centerPodium }
        uiCreatures = { centerPanel.leftCreature, centerPanel.rightCreature, centerPanel.centerCreature }
    else
        podiums = { centerPanel.centerPodium, centerPanel.leftPodium, centerPanel.rightPodium }
        uiCreatures = { centerPanel.centerCreature, centerPanel.leftCreature, centerPanel.rightCreature }
    end

    specialPanel.creatures.list:destroyChildren()
    for index = 1, 3 do
        local block = creatures[index]
        local podium, uiCreature = podiums[index], uiCreatures[index]
        if block ~= nil and setCreature(uiCreature, block.raceId) then
            podium:show()
            local outfit, raceName = raceOutfit(block.raceId)
            local widget = g_ui.createWidget('TaskMonsterBlock', specialPanel.creatures.list)
            bindChildren(widget)
            widget.raceId = block.raceId
            widget:setTooltip(capitalize(raceName))
            setFittedText(widget.title, capitalize(raceName), 79)
            widget.creature:setOutfit(outfit)
            widget.mask:hide()
            widget.icon:hide()
            for i = 1, 5 do
                local star = widget.starBackground['star' .. i]
                if star ~= nil then
                    star:setEnabled(i <= block.stars)
                end
            end
        else
            uiCreature:hide()
            podium:hide()
        end
    end

    fillRewards(specialPanel.rewards.list, specialPanel.rewards.experience.text, rewards)

    specialPanel.creatures.minimizeButton:setEnabled(true)
    specialPanel.creatures:show()
    centerPanel:setHeight(368)
    for i = 1, 3 do
        centerPanel['star' .. i]:show()
    end
    centerPanel.rerollTitle:show()
    centerPanel.price:show()
    centerPanel.reroll:show()
    centerPanel.progressText:setText(comma_value(kills) .. " / " .. comma_value(total))
    centerPanel.progressBar:setWidth(percentOf(kills, total, 186))

    centerPanel.price.text:setText(comma_value(reroll))
    centerPanel.reroll.onClick = nil
    if balance >= reroll then
        centerPanel.reroll:setEnabled(true)
        centerPanel.reroll:setImageSource('/game_ranktasks/images/button_green')
        centerPanel.price.text:setColor('#C0C0C0')
        centerPanel.reroll.onClick = function()
            local function closeConfirm()
                if tasksConfirmWindow ~= nil then
                    tasksConfirmWindow:destroy()
                    tasksConfirmWindow = nil
                end
                tasksWindow:show()
                tasksWindow:focus()
            end
            local yesCallback = function()
                closeConfirm()
                sendAction(enums.actions.rerollSpecial, 0)
            end
            tasksWindow:hide()
            tasksConfirmWindow = displayGeneralBox('Sortear outra task especial',
                "Trocar a task especial '" .. name .. "' por outra?\nSerao cobrados " .. comma_value(reroll) ..
                " gold coins e o progresso atual sera perdido.", {
                    { text = 'Nao', callback = closeConfirm },
                    { text = 'Sim', callback = yesCallback },
                    anchor = AnchorHorizontalCenter
                }, yesCallback, closeConfirm)
        end
    else
        centerPanel.reroll:setEnabled(false)
        centerPanel.reroll:setImageSource('/game_ranktasks/images/button_red')
        centerPanel.price.text:setColor('#D33C3C')
    end

    local claim = centerPanel.claim
    claim.onClick = nil
    if state == 4 then
        claim:setEnabled(true)
        claim:setImageSource('/game_ranktasks/images/button_green')
        claim.onClick = function()
            sendAction(enums.actions.claimSpecial, id)
        end
    else
        claim:setEnabled(false)
        claim:setImageSource('/game_ranktasks/images/button_red')
    end
end

function setSpecialTaskTitle(text)
    local nameWidget = tasksWindow.main.gridPanel.specialPanel.centerPanel.name
    nameWidget:destroyChildren()

    local words = {}
    for w in tostring(text or ''):gmatch('%S+') do
        table.insert(words, w)
    end
    if #words == 0 then
        return
    end

    local container = g_ui.createWidget('UIWidget', nameWidget)
    container:setId('specialTaskTitleContainer')
    container:setPhantom(true)
    container:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    container:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    container:setHeight(20)

    local layout = UIHorizontalLayout.create(container)
    layout:setFitChildren(true)
    layout:setSpacing(0)
    container:setLayout(layout)

    local function label(textValue, font, color)
        local widget = g_ui.createWidget('Label', container)
        widget:setPhantom(true)
        widget:setTextAutoResize(true)
        widget:setText(textValue)
        widget:setFont(font)
        widget:setColor(color)
    end

    for i, word in ipairs(words) do
        label(word:sub(1, 1):upper(), 'Verdana Bold-13px', '#e8c26a')
        if #word > 1 then
            label(word:sub(2):lower(), 'verdana-11px-rounded', 'white')
        end
        if i < #words then
            label(' ', 'verdana-11px-rounded', 'white')
        end
    end
    container:updateLayout()
end
