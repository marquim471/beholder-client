local UI = nil
local searchEvent = nil
function showBosstiary()
    if searchEvent then
        removeEvent(searchEvent)
        searchEvent = nil
    end
    UI = g_ui.loadUI("bosstiary", contentContainer)
    UI:show()
    Cyclopedia.Bosstiary.Page = 1
    Cyclopedia.Bosstiary.TotalPages = 1
    Cyclopedia.Bosstiary.Creatures = {{}}
    Cyclopedia.Bosstiary.NotVisibleCreatures = {}
    Cyclopedia.Bosstiary.SearchText = ""
    Cyclopedia.verifyBosstiaryButtons()
    g_game.requestBosstiaryInfo()
    UI.FilterBase.BaneIcon:setTooltip(
        "Bane\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 5\nExpertise: 15\nMastery: 30")
    -- UI.FilterBase.BaneIcon:setTooltipAlign(AlignTopLeft)
    UI.FilterBase.ArchfoeIcon:setTooltip(
        "Archfoe\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 10\nExpertise: 30\nMastery: 60")
    -- UI.FilterBase.ArchfoeIcon:setTooltipAlign(AlignTopLeft)
    UI.FilterBase.NemesisIcon:setTooltip(
        "Nemesis\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 10\nExpertise: 30\nMastery: 60")
    -- UI.FilterBase.NemesisIcon:setTooltipAlign(AlignTopLeft)
    UI.StarBase.Info1:setTooltip(
        "Once you have reached the Prowess level, you can assign the boss to a boss slot.")
    -- UI.StarBase.Info1:setTooltipAlign(AlignTopLeft)
    UI.StarBase.Info2:setTooltip(
        "Once you have reached the Expertise level, you can display the boss on a Podium of Vigour.")
    -- UI.StarBase.Info2:setTooltipAlign(AlignTopLeft)
    UI.StarBase.Info3:setTooltip(
        "Once you have reached the Mastery level, you will receive an additional 25% loot bonus when the boss is assigned to a boss slot.")
    -- UI.StarBase.Info3:setTooltipAlign(AlignTopLeft)
    controllerCyclopedia.ui.CharmsBase:setVisible(false)
    controllerCyclopedia.ui.GoldBase:setVisible(false)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(false)
    end
end

Cyclopedia.Bosstiary = {}

local CATEGORY = {
    BANE = 0,
    NEMESIS = 2,
    ARCHFOE = 1
}
local CONFIG = {
    [0] = {
        EXPERTISE = 100,
        PROWESS = 25,
        MASTERY = 300
    },
    {
        EXPERTISE = 20,
        PROWESS = 5,
        MASTERY = 60
    },
    {
        EXPERTISE = 3,
        PROWESS = 1,
        MASTERY = 5
    }
}

local BOSSTIARY_TRACKER_OVERRIDE_TTL = 5000

local function getBosstiaryTrackerOverrides()
    Cyclopedia.BosstiaryTrackerOverrides = Cyclopedia.BosstiaryTrackerOverrides or {}
    return Cyclopedia.BosstiaryTrackerOverrides
end

local function getBosstiaryTrackerOverride(raceId)
    local overrides = getBosstiaryTrackerOverrides()
    local override = overrides[raceId]

    if override and override.expiresAt <= g_clock.millis() then
        overrides[raceId] = nil
        return nil
    end

    return override
end

local function setBosstiaryTrackerOverride(raceId, checked)
    local overrides = getBosstiaryTrackerOverrides()
    overrides[raceId] = {
        checked = checked,
        expiresAt = g_clock.millis() + BOSSTIARY_TRACKER_OVERRIDE_TTL
    }

    scheduleEvent(function()
        local override = overrides[raceId]
        if override and override.expiresAt <= g_clock.millis() then
            overrides[raceId] = nil
        end
    end, BOSSTIARY_TRACKER_OVERRIDE_TTL + 250)
end

local function getEffectiveBosstiaryTrackerState(raceId, serverState, confirmServerState)
    local trackerState = serverState == 1 and 1 or 0
    local override = getBosstiaryTrackerOverride(raceId)

    if not override then
        return trackerState
    end

    local desiredState = override.checked and 1 or 0
    if confirmServerState and trackerState == desiredState then
        getBosstiaryTrackerOverrides()[raceId] = nil
        return trackerState
    end

    return desiredState
end

local function setBosstiaryTrackCheck(widget, checked)
    local originalCallback = widget.onCheckChange
    widget.onCheckChange = nil
    widget:setChecked(checked)
    widget.onCheckChange = originalCallback
    widget.bosstiaryTrackerState = checked
end

local function updateBosstiaryTrackerState(raceId, checked)
    if not Cyclopedia.Bosstiary then
        return
    end

    local trackerState = checked and 1 or 0

    for _, creatures in ipairs(Cyclopedia.Bosstiary.Creatures or {}) do
        for _, creature in ipairs(creatures) do
            if creature.raceId == raceId then
                creature.isTrackerActived = trackerState
            end
        end
    end

    for _, creature in ipairs(Cyclopedia.Bosstiary.NotVisibleCreatures or {}) do
        if creature.raceId == raceId then
            creature.isTrackerActived = trackerState
        end
    end
end

local function addBosstiaryTrackerEntry(trackerData, data, confirmServerState)
    local config = CONFIG[data.category]
    local trackerState = getEffectiveBosstiaryTrackerState(data.raceId, data.isTrackerActived, confirmServerState)

    if not config or trackerState ~= 1 or data.kills < 1 then
        return
    end

    table.insert(trackerData, {
        data.raceId,
        data.kills,
        config.PROWESS,
        config.EXPERTISE,
        config.MASTERY,
        1
    })
end

local function findBosstiaryTrackerEntry(raceId)
    for _, creatures in ipairs(Cyclopedia.Bosstiary.Creatures or {}) do
        for _, creature in ipairs(creatures) do
            if creature.raceId == raceId then
                local trackerData = {}
                addBosstiaryTrackerEntry(trackerData, creature, false)
                return trackerData[1]
            end
        end
    end

    for _, creature in ipairs(Cyclopedia.Bosstiary.NotVisibleCreatures or {}) do
        if creature.raceId == raceId then
            local trackerData = {}
            addBosstiaryTrackerEntry(trackerData, creature, false)
            return trackerData[1]
        end
    end

    for _, entry in ipairs(Cyclopedia.storedBosstiaryTrackerData or {}) do
        if entry[1] == raceId then
            local copy = {unpack(entry)}
            copy[6] = 1
            return copy
        end
    end
end

function Cyclopedia.mergeBosstiaryTrackerOverrides(data)
    local overrides = getBosstiaryTrackerOverrides()
    local mergedData = {}
    local seenRaceIds = {}
    local sourceData = data or {}

    if #sourceData == 0 and next(overrides) and Cyclopedia.storedBosstiaryTrackerData and
        #Cyclopedia.storedBosstiaryTrackerData > 0 then
        sourceData = Cyclopedia.storedBosstiaryTrackerData
    end

    for _, entry in ipairs(sourceData) do
        local raceId = entry[1]
        local trackerState = getEffectiveBosstiaryTrackerState(raceId, 1, true)

        seenRaceIds[raceId] = true

        if trackerState == 1 then
            local copy = {unpack(entry)}
            copy[6] = 1
            table.insert(mergedData, copy)
        end
    end

    for raceId, override in pairs(overrides) do
        if not seenRaceIds[raceId] and not getBosstiaryTrackerOverride(raceId) then
            override = nil
        end

        if override and override.checked and not seenRaceIds[raceId] then
            local entry = findBosstiaryTrackerEntry(raceId)
            if entry then
                table.insert(mergedData, entry)
            end
        end
    end

    return mergedData
end

local function copyBosstiaryTrackerEntry(entry)
    return {unpack(entry)}
end

local function setBosstiaryTrackerData(trackerData)
    Cyclopedia.BosstiaryTrackerPending = false
    Cyclopedia.storedBosstiaryTrackerData = trackerData

    if trackerMiniWindowBosstiary and Cyclopedia.onParseCyclopediaTracker then
        local previousLocalRender = Cyclopedia.BosstiaryTrackerLocalRender
        Cyclopedia.BosstiaryTrackerLocalRender = true
        Cyclopedia.onParseCyclopediaTracker(1, trackerData)
        Cyclopedia.BosstiaryTrackerLocalRender = previousLocalRender
    elseif trackerMiniWindowBosstiary and trackerMiniWindowBosstiary.contentsPanel then
        trackerMiniWindowBosstiary.contentsPanel:destroyChildren()
    end
end

local function rebuildBosstiaryTrackerDataFromCreatures()
    local trackerData = {}

    for _, creatures in ipairs(Cyclopedia.Bosstiary.Creatures or {}) do
        for _, creature in ipairs(creatures) do
            addBosstiaryTrackerEntry(trackerData, creature, false)
        end
    end

    for _, creature in ipairs(Cyclopedia.Bosstiary.NotVisibleCreatures or {}) do
        addBosstiaryTrackerEntry(trackerData, creature, false)
    end

    setBosstiaryTrackerData(trackerData)
end

function Cyclopedia.syncBosstiaryTrackerFromBosstiaryInfo(data)
    local trackerData = {}

    for _, dataEntry in ipairs(data or {}) do
        addBosstiaryTrackerEntry(trackerData, dataEntry, true)
    end

    setBosstiaryTrackerData(trackerData)
end

function Cyclopedia.setBosstiaryTrackerStatus(raceId, checked, sendToServer)
    raceId = tonumber(raceId)
    if not raceId then
        return
    end

    setBosstiaryTrackerOverride(raceId, checked)
    updateBosstiaryTrackerState(raceId, checked)

    if UI and UI.ListBase and UI.ListBase.BossList then
        for _, child in ipairs(UI.ListBase.BossList:getChildren()) do
            if tonumber(child:getId()) == raceId and child.TrackCheck then
                setBosstiaryTrackCheck(child.TrackCheck, checked)
            end
        end
    end

    local trackerData = {}
    for _, entry in ipairs(Cyclopedia.storedBosstiaryTrackerData or {}) do
        if entry[1] ~= raceId then
            table.insert(trackerData, copyBosstiaryTrackerEntry(entry))
        end
    end

    if checked then
        local entry = findBosstiaryTrackerEntry(raceId)
        if entry then
            table.insert(trackerData, entry)
        end
    end

    setBosstiaryTrackerData(trackerData)

    if sendToServer ~= false then
        g_game.sendStatusTrackerBestiary(raceId, checked)
    end
end

function Cyclopedia.onBosstiaryTrackCheckChange(widget)
    local raceId = tonumber(widget.raceId or widget:getParent():getId())
    if not raceId then
        return
    end

    local checked = widget:isChecked()
    if widget.bosstiaryTrackerState == checked then
        return
    end

    widget.bosstiaryTrackerState = checked
    Cyclopedia.setBosstiaryTrackerStatus(raceId, checked, true)
end

--[[ function Cyclopedia.SetBosstiaryProgress(object, value, maxValue)
    local rect = {
        height = 12,
        x = 0,
        y = 0,
        width = (maxValue < value and maxValue or value) / maxValue * 141
    }

    if value >= 0 and rect.width < 1 then
        object.fill:setVisible(false)
    else
        object.fill:setVisible(true)
    end

    object.fill:setImageRect(rect)
    object.ProgressValue:setText(value)
    object.fill:setImageSource("/game_cyclopedia/images/bestiary/fill")

end ]]

function Cyclopedia.CreateBosstiaryCreature(data)
    if not data.visible then
        return
    end

    local widget = g_ui.createWidget("BosstiaryItem", UI.ListBase.BossList)
    widget:setId(data.raceId)
    local raceData = g_things.getRaceData(data.raceId)
    local icons = {
        [CATEGORY.BANE] = "/game_cyclopedia/images/boss/icon_bane",
        [CATEGORY.ARCHFOE] = "/game_cyclopedia/images/boss/icon_archfoe",
        [CATEGORY.NEMESIS] = "/game_cyclopedia/images/boss/icon_nemesis"
    }

    local fullText = ""

    if data.kills >= CONFIG[data.category].MASTERY then
        fullText = "(fully unlocked)"
    end

    widget.ProgressBorder1:setTooltip(string.format(" %d / %d %s", data.kills, CONFIG[data.category].PROWESS, fullText))
    widget.ProgressBorder2:setTooltip(
        string.format(" %d / %d %s", data.kills, CONFIG[data.category].EXPERTISE, fullText))
    widget.ProgressBorder3:setTooltip(string.format(" %d / %d %s", data.kills, CONFIG[data.category].MASTERY, fullText))

    local config = CONFIG[data.category]
    for _, star in ipairs({
        {widget.bronzeStar, config.PROWESS, "bronze"},
        {widget.silverStar, config.EXPERTISE, "silver"},
        {widget.goldStar, config.MASTERY, "gold"}
    }) do
        local source = "/game_cyclopedia/images/boss/icon_star_" ..
            (data.kills >= star[2] and star[3] or "dark")
        star[1]:setImageSource(source)
        for _, child in ipairs(star[1]:getChildren()) do
            child:setImageSource(source)
        end
    end

    widget.TypeIcon:setImageSource(icons[data.category])

    if data.category == CATEGORY.BANE then
        widget.TypeIcon:setTooltip(
            "Bane\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 5\nExpertise: 15\nMastery: 30")
        -- widget.TypeIcon:setTooltipAlign(AlignTopLeft)
    elseif data.category == CATEGORY.ARCHFOE then
        widget.TypeIcon:setTooltip(
            "Archfoe\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 10\nExpertise: 30\nMastery: 60")
        -- widget.TypeIcon:setTooltipAlign(AlignTopLeft)
    elseif data.category == CATEGORY.NEMESIS then
        widget.TypeIcon:setTooltip(
            "Nemesis\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 10\nExpertise: 30\nMastery: 60")
        -- widget.TypeIcon:setTooltipAlign(AlignTopLeft)
    end
    widget.ProgressValue:setText(Cyclopedia.formatGold(data.kills))

    local completed = data.kills >= config.MASTERY
    for _, bar in ipairs({
        {widget.ProgressBorder1, widget.ProgressBack, 0, config.PROWESS},
        {widget.ProgressBorder2, widget.ProgressBack33, config.PROWESS, config.EXPERTISE},
        {widget.ProgressBorder3, widget.ProgressBack55, config.EXPERTISE, config.MASTERY}
    }) do
        local fraction = completed and 1 or math.min(math.max(
            (data.kills - bar[3]) / math.max(bar[4] - bar[3], 1), 0), 1)
        local width = math.ceil((bar[1]:getWidth() - 2) * fraction - 0.5)
        bar[2]:setImageSource("/game_cyclopedia/images/bestiary/progressbar-" ..
            (completed and "green" or "orange") .. "-large")
        bar[2]:setWidth(width)
        bar[2]:setVisible(width > 0)
    end

    widget.Sprite:setOutfit(raceData.outfit)
    widget.Sprite:getCreature():setStaticWalking(1000)
    if data.unlocked then
        widget.Sprite:getCreature():setShader("")
        widget.Name:setText(data.name)
        widget.Name:setTextOverflowCharacter(string.char(133))
        local captionLength = #data.name
        while widget.Name:getTextSize().width > widget.Name:getWidth() and captionLength > 1 do
            captionLength = captionLength - 1
            widget.Name:setTextOverflowLength(captionLength)
        end
        if captionLength < #data.name then
            widget.Name:setTooltip(data.name)
        end
        if g_game.getClientVersion() >= 1320 then
            widget.TrackCheck:enable()
            widget.TrackCheck.raceId = data.raceId
            setBosstiaryTrackCheck(widget.TrackCheck, data.isTrackerActived == 1)
        else
            widget.TrackCheck:hide()
        end
    else
        widget.Sprite:getCreature():setShader("Outfit - cyclopedia-black")
        widget.TrackCheck:hide()

    end
end

function Cyclopedia.LoadBosstiaryCreatures(data)
    Cyclopedia.syncBosstiaryTrackerFromBosstiaryInfo(data)

    if not UI or UI:isDestroyed() or not UI.PageValue then
        return
    end
    local maxCategoriesPerPage = 8

    Cyclopedia.Bosstiary.Creatures = {}
    Cyclopedia.Bosstiary.NotVisibleCreatures = {}
    Cyclopedia.Bosstiary.Page = Cyclopedia.Bosstiary.Page or 1
    Cyclopedia.Bosstiary.TotalPages = math.ceil(#data / maxCategoriesPerPage)

    if Cyclopedia.Bosstiary.TotalPages < 1 then
        Cyclopedia.Bosstiary.TotalPages = 1
    end

    if Cyclopedia.Bosstiary.Page > Cyclopedia.Bosstiary.TotalPages then
        Cyclopedia.Bosstiary.Page = Cyclopedia.Bosstiary.TotalPages
    end

    UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bosstiary.Page, Cyclopedia.Bosstiary.TotalPages))

    local page = 1

    Cyclopedia.Bosstiary.Creatures[page] = {}

    local validCreatures = {}

    for i, dataEntry in ipairs(data) do
        local raceData = g_things.getRaceData(dataEntry.raceId)
        local creature = {
            visible = true,
            raceId = dataEntry.raceId,
            name = raceData and raceData.name or "?",
            kills = dataEntry.kills,
            category = dataEntry.category,
            isTrackerActived = getEffectiveBosstiaryTrackerState(dataEntry.raceId, dataEntry.isTrackerActived, true),
            unlocked = dataEntry.kills > 0 and true or false
        }

        table.insert(validCreatures, creature)
    end

    table.sort(validCreatures, function(a, b)
        if a.name == "?" and b.name ~= "?" then
            return false
        elseif a.name ~= "?" and b.name == "?" then
            return true
        elseif a.unlocked and not b.unlocked then
            return true
        elseif not a.unlocked and b.unlocked then
            return false
        else
            return a.name < b.name
        end
    end)

    for i = 1, #validCreatures do
        local creature = validCreatures[i]

        if creature.visible then
            table.insert(Cyclopedia.Bosstiary.Creatures[page], creature)
        else
            table.insert(Cyclopedia.Bosstiary.NotVisibleCreatures[page], creature)
        end

        if i % maxCategoriesPerPage == 0 and i < #validCreatures then
            page = page + 1
            Cyclopedia.Bosstiary.Creatures[page] = {}
        end
    end

    Cyclopedia.ReadjustPages()

    if Cyclopedia.pendingBosstiaryRaceId and Cyclopedia.focusBosstiaryRace and
        Cyclopedia.focusBosstiaryRace(Cyclopedia.pendingBosstiaryRaceId) then
        Cyclopedia.pendingBosstiaryRaceId = nil
        return
    end

end

function Cyclopedia.LoadBosstiaryCreature(page)
    if not Cyclopedia.Bosstiary.Creatures[page] then
        return
    end

    UI.ListBase.BossList:destroyChildren()

    for _, data in ipairs(Cyclopedia.Bosstiary.Creatures[page]) do
        Cyclopedia.CreateBosstiaryCreature(data)
    end
end

function Cyclopedia.focusBosstiaryRace(raceId)
    raceId = tonumber(raceId)
    if not raceId or not Cyclopedia.Bosstiary or not Cyclopedia.Bosstiary.Creatures then
        return false
    end

    for page, creatures in ipairs(Cyclopedia.Bosstiary.Creatures) do
        for _, creature in ipairs(creatures) do
            if creature.raceId == raceId then
                Cyclopedia.Bosstiary.Page = page
                Cyclopedia.LoadBosstiaryCreature(page)
                Cyclopedia.verifyBosstiaryButtons()
                return true
            end
        end
    end

    return false
end

function Cyclopedia.verifyBosstiaryButtons()
    if not UI or UI:isDestroyed() or not UI.PageValue then
        return
    end
    local page = Cyclopedia.Bosstiary.Page
    local totalPages = Cyclopedia.Bosstiary.TotalPages

    local function updateButtonState(button, condition)
        if condition then
            button:enable()
        else
            button:disable()
        end
    end

    local function updatePageValue(currentPage, maxPages)
        UI.PageValue:setText(string.format("%d / %d", currentPage, maxPages))
    end

    updateButtonState(UI.PrevPageButton, page > 1)
    updateButtonState(UI.NextPageButton, page < totalPages)
    updatePageValue(page, totalPages)
end

function Cyclopedia.changeBosstiaryPage(prev, next)
    local page = Cyclopedia.Bosstiary.Page or 1
    local totalPages = Cyclopedia.Bosstiary.TotalPages or 1
    local newPage = page + (next and 1 or 0) - (prev and 1 or 0)
    if newPage < 1 or newPage > totalPages or newPage == page then
        return
    end
    Cyclopedia.Bosstiary.Page = newPage
    Cyclopedia.LoadBosstiaryCreature(newPage)
    Cyclopedia.verifyBosstiaryButtons()
end

function Cyclopedia.scheduleBosstiarySearch(text)
    if searchEvent then
        removeEvent(searchEvent)
    end
    local searchUI = UI
    searchEvent = scheduleEvent(function()
        searchEvent = nil
        if UI == searchUI and UI and not UI:isDestroyed() then
            Cyclopedia.BosstiarySearchText(text)
        end
    end, 250)
end

function Cyclopedia.BosstiarySearchText(text, clear)
    if not UI or UI:isDestroyed() then
        return
    end
    if clear then
        text = ""
        UI.SearchEdit:setText("")
    end
    if searchEvent then
        removeEvent(searchEvent)
        searchEvent = nil
    end
    Cyclopedia.Bosstiary.SearchText = text or ""
    Cyclopedia.ReadjustPages()
end

function Cyclopedia.changeBosstiaryFilter(widget, isCheck)
    widget:setChecked(not isCheck)
    Cyclopedia.ReadjustPages()
end

local function isBosstiaryCreatureVisible(creature)
    local config = CONFIG[creature.category]
    local categoryFilters = {
        [CATEGORY.BANE] = "BaneCheck",
        [CATEGORY.ARCHFOE] = "ArchfoeCheck",
        [CATEGORY.NEMESIS] = "NemesisCheck"
    }
    if not config or not UI.FilterBase[categoryFilters[creature.category]]:isChecked() then
        return false
    end

    local grade
    if creature.kills < 1 then
        grade = "NoKillsCheck"
    elseif creature.kills < config.PROWESS then
        grade = "FewKillsCheck"
    elseif creature.kills < config.EXPERTISE then
        grade = "ProwessCheck"
    elseif creature.kills < config.MASTERY then
        grade = "ExpertiseCheck"
    else
        grade = "MasteryCheck"
    end
    if not UI.FilterBase[grade]:isChecked() then
        return false
    end

    local search = (Cyclopedia.Bosstiary.SearchText or ""):lower()
    return search == "" or (creature.unlocked and creature.name:lower():find(search, 1, true) ~= nil)
end

function Cyclopedia.ReadjustPages()
    if not UI or UI:isDestroyed() then
        return
    end
    local maxCategoriesPerPage = 8
    local allCreatures = {}

    for _, creatures in ipairs(Cyclopedia.Bosstiary.Creatures or {}) do
        for _, creature in ipairs(creatures) do
            table.insert(allCreatures, creature)
        end
    end

    for _, creature in ipairs(Cyclopedia.Bosstiary.NotVisibleCreatures or {}) do
        table.insert(allCreatures, creature)
    end

    table.sort(allCreatures, function(a, b)
        if a.name == "?" and b.name ~= "?" then
            return false
        elseif a.name ~= "?" and b.name == "?" then
            return true
        elseif a.unlocked and not b.unlocked then
            return true
        elseif not a.unlocked and b.unlocked then
            return false
        else
            return a.name < b.name
        end
    end)

    Cyclopedia.Bosstiary.Creatures = {}
    Cyclopedia.Bosstiary.NotVisibleCreatures = {}

    local page = 1

    Cyclopedia.Bosstiary.Creatures[page] = {}

    for _, creature in ipairs(allCreatures) do
        creature.visible = isBosstiaryCreatureVisible(creature)
        if creature.visible then
            if #Cyclopedia.Bosstiary.Creatures[page] == maxCategoriesPerPage then
                page = page + 1
                Cyclopedia.Bosstiary.Creatures[page] = {}
            end
            table.insert(Cyclopedia.Bosstiary.Creatures[page], creature)
        else
            table.insert(Cyclopedia.Bosstiary.NotVisibleCreatures, creature)
        end
    end

    local totalVisible = 0

    for _, pageCreatures in ipairs(Cyclopedia.Bosstiary.Creatures or {}) do
        totalVisible = totalVisible + #pageCreatures
    end

    Cyclopedia.Bosstiary.TotalPages = math.max(1, math.ceil(totalVisible / maxCategoriesPerPage))

    if Cyclopedia.Bosstiary.Page < 1 or Cyclopedia.Bosstiary.Page > Cyclopedia.Bosstiary.TotalPages then
        Cyclopedia.Bosstiary.Page = 1
    end

    if not UI or UI:isDestroyed() or not UI.PageValue then
        return
    end
    UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bosstiary.Page, Cyclopedia.Bosstiary.TotalPages))
    Cyclopedia.LoadBosstiaryCreature(Cyclopedia.Bosstiary.Page)
    Cyclopedia.verifyBosstiaryButtons()
end
