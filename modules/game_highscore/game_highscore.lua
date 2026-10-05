local highscoreButton = nil
local worldTypeRadioGroup = nil
local currentPage = 0
local countPages = 0
local requestPending = false
local showLoyaltyTitles = false
local applyHighscoreRowLayout
local configureHighscoreColumns

local vocationArray = {}
local Category = {}

local tempFixworldType = {
    {0, "Open PvP"},
    {1, "Optional PvP"},
    {2, "Hardcore PvP"},
    {3, "Retro Open PvP"},
    {4, "Retro Hardcore PvP"}
}

local serverSide = {
    action = 0,
    category = 0,
    vocation = 0xFFFFFFFF,
    world = "",
    worldType = 1,
    battlEye = 1,
    page = 1,
    totalInPages = 20
}

local function getMinutesDifference(t1, t2)
    local diffInSeconds = os.difftime(t2, t1)
    local diffInMinutes = diffInSeconds / 60
    local diffInHours = diffInMinutes / 60

    if diffInHours >= 1 then
        return string.format("Last Update: %.0f Hrs Ago", diffInHours)
    elseif diffInMinutes >= 1 then
        return string.format("Last Update: %.0f minutes Ago", diffInMinutes)
    else
        return string.format("Last Update: %.0f Second Ago", math.abs(diffInSeconds))
    end
end

local function getCategory(arg)
    if type(arg) == "string" then
        for i, cat in ipairs(Category) do
            if cat[2] == arg then
                return cat[1]
            end
        end
    end
    return 0
end

local function getVocation(arg)
    if type(arg) == "number" then
        return vocationNamesByClientId[arg] or "All Vocations"
    elseif type(arg) == "string" then
        -- First, search in vocationArray which comes from server
        for _, voc in ipairs(vocationArray) do
            if voc[2] == arg then
                return voc[1]
            end
        end
        -- If not found in vocationArray, search in vocationNamesByClientId
        for id, name in pairs(vocationNamesByClientId) do
            if name == arg then
                return id
            end
        end
    end
    return "All Vocations"
end

local function centerHighscores()
    local ui = highscoreController.ui
    local parent = ui:getParent():getRect()
    ui:breakAnchors()
    ui:setPosition({
        x = parent.x + math.max(0, math.floor((parent.width - ui:getWidth()) / 2)),
        y = parent.y + math.max(0, math.floor((parent.height - ui:getHeight()) / 2))
    })
end

local function setHighscoreState(text)
    local ui = highscoreController.ui
    local showTable = text == nil
    ui.data:setVisible(showTable)
    ui.TableHeader:setVisible(showTable)
    ui.stateLabel:setText(text or '')
    ui.stateLabel:setVisible(not showTable)
end
highscoreController = Controller:new()
highscoreController:setUI('game_highscore')

function highscoreController:onInit()
    highscoreController.ui:hide()
    highscoreController.ui:enableTitlebarDrag(17, 10)
    centerHighscores()
    connect(highscoreController.ui:getParent(), {onGeometryChange = centerHighscores})
    for _, id in ipairs({"gameWorldBox", "BattlEyeBox", "vocationBox", "categoryBox"}) do
        local selector = highscoreController.ui.filters[id]
        local onMousePress = selector.onMousePress
        selector.onMousePress = function(widget, mousePos, mouseButton)
            if mouseButton ~= MouseLeftButton then
                return false
            end
            local handled = onMousePress(widget, mousePos, mouseButton)
            local menu = g_ui.getRootWidget():getChildById(widget:getId() .. "PopupMenu")
            if menu then
                for index, row in ipairs(menu:getChildren()) do
                    row:setChecked(index == widget.currentIndex)
                    row.onHoverChange = function(option, hovered)
                        if hovered then
                            for _, other in ipairs(menu:getChildren()) do
                                other:setChecked(other == option)
                            end
                        end
                    end
                end
                widget.Arrow:setImageSource("/images/game/cyclopedia/charm-dropdown-pressed")
                connect(menu, {onDestroy = function()
                    if not widget:isDestroyed() then
                        widget.Arrow:setImageSource("/images/game/cyclopedia/charm-dropdown-idle")
                    end
                end})
            end
            return handled
        end
    end
    highscoreController:registerEvents(g_game, {
        onProcessHighscores = onProcessHighscores,
        onHighscoresNoData = onHighscoresNoData
    })
end

function highscoreController:onTerminate()
    disconnect(highscoreController.ui:getParent(), {onGeometryChange = centerHighscores})
    if highscoreButton then
        highscoreButton:destroy()
        highscoreButton = nil
    end

    if worldTypeRadioGroup then
        worldTypeRadioGroup:destroy()
        worldTypeRadioGroup = nil
    end
end

function onHighscoresNoData()
    if not g_game.getLocalPlayer() then
        return
    end
    requestPending = false
    currentPage = 0
    countPages = 0
    local ui = highscoreController.ui
    ui.data:destroyChildren()
    setHighscoreState(tr('No data available.'))
    ui.filters:setEnabled(true)
    disableButtons()
    ui.ownRankButton:setEnabled(ui.filters.categoryBox:getCurrentOption() ~= nil)
    ui.page:setText("0 / 0")
    ui.last_update:clearText()
end

function onProcessHighscores(serverName, world, worldType, battlEye, vocations, categories, page, totalInPages,
    highscores, entriesTs, selectedVocation, selectedCategory, showLoyaltyTitle, valueType)
    if not g_game.getLocalPlayer() then
        return
    end
    requestPending = false
    highscoreController.ui.filters:setEnabled(true)
    vocationArray = table.copy(vocations)
    Category = table.copy(categories)
    currentPage = page
    countPages = totalInPages
    local ui = highscoreController.ui
    local uiFilters = ui.filters

    if not uiFilters.PanelWorld.isFilled then
        worldTypeRadioGroup = UIRadioGroup.create()
        for index, temp in ipairs(tempFixworldType) do
            local label = g_ui.createWidget("WorldType", uiFilters.PanelWorld)
            label:setMarginLeft(math.floor(((index - 1) % 3) * (uiFilters.PanelWorld:getWidth() - 86) / 3 + 0.5))
            label:setMarginTop(math.floor((index - 1) / 3) * 17)
            label.text:setText(temp[2])
            worldTypeRadioGroup:addWidget(label.enabled)
        end
        uiFilters.PanelWorld.isFilled = true
    end

    local filterData = {
        {box = uiFilters.vocationBox, data = vocations, label = "All Vocations"},
        {box = uiFilters.categoryBox, data = categories, label = nil},
    }

    for _, filter in ipairs(filterData) do
        if not filter.box.isFilled then
            if filter.label then
                filter.box:addOption(filter.label, 0xFFFFFFFF)
            end
            for _, item in ipairs(filter.data) do
                filter.box:addOption(item[2], item[1])
            end
            filter.box.isFilled = true
        end
    end

    if selectedVocation ~= nil then
        uiFilters.vocationBox:setCurrentOptionByData(selectedVocation, true)
    end
    if selectedCategory ~= nil then
        uiFilters.categoryBox:setCurrentOptionByData(selectedCategory, true)
    end

    if not uiFilters.BattlEyeBox.isFilled then
        uiFilters.BattlEyeBox:addOption(battlEye)
        uiFilters.BattlEyeBox.isFilled = true
    end

    if not uiFilters.gameWorldBox.isFilled then
        uiFilters.gameWorldBox:addOption(world ~= "" and world or serverName)
        uiFilters.gameWorldBox.isFilled = true
    end

    local isFirstPage = currentPage <= 1
    local isLastPage = currentPage >= countPages

    ui.next:setEnabled(not isLastPage)
    ui.nextLast:setEnabled(not isLastPage)
    ui.prev:setEnabled(not isFirstPage)
    ui.prevLast:setEnabled(not isFirstPage)
    ui.ownRankButton:setEnabled(true)
    ui.page:setText(page .. " / " .. totalInPages)

    local diferenciaEnMinutos = getMinutesDifference(entriesTs, os.time())
    ui.last_update:setText(diferenciaEnMinutos)

    setHighscoreState(nil)
    configureHighscoreColumns(showLoyaltyTitle, valueType)
    createHighscores(highscores)
end

function highscoreController:onGameStart()
    if g_game.getClientVersion() < 1310 then
        return
    end

    highscoreButton = modules.client_topmenu.addRightGameToggleButton('highscore', tr('Highscores'),
        '/images/options/highscores', toggle, false)
    highscoreButton:setOn(false)
end

function highscoreController:onGameEnd()
    hide()
    requestPending = false
    currentPage = 0
    countPages = 0
    vocationArray = {}
    Category = {}
    local ui = highscoreController.ui
    ui.data:destroyChildren()
    for _, id in ipairs({"vocationBox", "categoryBox", "BattlEyeBox", "gameWorldBox"}) do
        ui.filters[id]:clearOptions()
        ui.filters[id].isFilled = false
    end
    if worldTypeRadioGroup then
        worldTypeRadioGroup:destroy()
        worldTypeRadioGroup = nil
    end
    ui.filters.PanelWorld:destroyChildren()
    ui.filters.PanelWorld.isFilled = false
    disableButtons()
    ui.page:setText("0 / 0")
    ui.last_update:clearText()
end

function hide()
    if not highscoreController.ui then
        return
    end
    for _, id in ipairs({"gameWorldBox", "BattlEyeBox", "vocationBox", "categoryBox"}) do
        local menu = g_ui.getRootWidget():getChildById(id .. "PopupMenu")
        if menu then
            menu:destroy()
        end
    end
    highscoreController.ui:hide()
    if highscoreButton then
        highscoreButton:setOn(false)
    end
end

function show()
    if not highscoreController.ui or not highscoreButton then
        return
    end

    highscoreController.ui:show()
    highscoreController.ui:raise()
    highscoreController.ui:focus()
    if highscoreButton then
        highscoreButton:setOn(true)
    end
    requestInfo()
end

function toggle()
    if not highscoreController.ui then
        return
    end

    if highscoreController.ui:isVisible() then
        return hide()
    end

    show()
end

local function setHighscoreText(widget, text)
    widget:setTextOverflowLength(0)
    widget:setText(text)
    widget:setTextOverflowCharacter(string.char(133))
    widget:removeTooltip()
    local length = #widget:getText()
    while widget:getTextSize().width > widget:getWidth() and length > 1 do
        length = length - 1
        widget:setTextOverflowLength(length)
    end
    if length < #widget:getText() then
        widget:setTooltip(widget:getText())
    end
end

applyHighscoreRowLayout = function(row)
    if showLoyaltyTitles then
        row.name:setWidth(145)
        row.separatorName:setMarginLeft(192)
        row.voc:setMarginLeft(196)
        row.separatorVocation:setMarginLeft(310)
        row.world:setMarginLeft(314)
        row.separatorWorld:setMarginLeft(396)
        row.level:setMarginLeft(400)
        row.separatorLevel:setMarginLeft(438)
        row.title:setVisible(true)
        row.separatorTitle:setVisible(true)
        row.points:setMarginLeft(582)
    else
        row.name:setWidth(220)
        row.separatorName:setMarginLeft(267)
        row.voc:setMarginLeft(271)
        row.separatorVocation:setMarginLeft(385)
        row.world:setMarginLeft(389)
        row.separatorWorld:setMarginLeft(471)
        row.level:setMarginLeft(475)
        row.separatorLevel:setMarginLeft(513)
        row.title:setVisible(false)
        row.separatorTitle:setVisible(false)
        row.points:setMarginLeft(517)
    end
end

configureHighscoreColumns = function(showLoyaltyTitle, valueType)
    showLoyaltyTitles = showLoyaltyTitle == true
    local header = highscoreController.ui.TableHeader

    header.header1:setWidth(showLoyaltyTitles and 152 or 227)
    header.header2:setMarginLeft(showLoyaltyTitles and 194 or 269)
    header.header3:setMarginLeft(showLoyaltyTitles and 312 or 387)
    header.header4:setMarginLeft(showLoyaltyTitles and 398 or 473)
    header.header5:setVisible(showLoyaltyTitles)
    header.header6:setMarginLeft(showLoyaltyTitles and 582 or 515)

    local scoreTitles = {[0] = tr('Points'), [1] = tr('Level'), [2] = tr('Score')}
    header.header6.value:setText(scoreTitles[valueType] or tr('Points'))
end
function createHighscores(list)
    local data = highscoreController.ui.data
    data:getLayout():disableUpdates()
    data:destroyChildren()

    for index, entry in ipairs(list) do
        local row = g_ui.createWidget("HighScoreData", data)
        applyHighscoreRowLayout(row)
        row:setBackgroundColor(index % 2 == 0 and "#414141" or "#484848")
        setHighscoreText(row.rank, entry[1] .. ".")
        setHighscoreText(row.name, entry[2])
        setHighscoreText(row.voc, entry[4] == 0 and "None" or getVocation(entry[4]))
        setHighscoreText(row.world, entry[5])
        setHighscoreText(row.level, entry[6])
        setHighscoreText(row.title, entry[3])
        setHighscoreText(row.points, comma_value(entry[8]))
        if entry[7] == 1 then
            for _, widget in pairs({"rank", "name", "voc", "world", "level", "title", "points"}) do
                row[widget]:setColor("#60f860")
            end
        end
    end

    data:getLayout():enableUpdates()
    data:getLayout():update()
end

local function changePage(newPage)
    if newPage < 1 or newPage > countPages or newPage == currentPage then
        return
    end
    highscoreRequest(newPage, 0)
end

function nextPage() changePage(currentPage + 1) end
function nextEndPage() changePage(countPages) end
function prevPage() changePage(currentPage - 1) end
function prevEndPage() changePage(1) end

function disableButtons()
    for _, btn in ipairs({"next", "nextLast", "prev", "prevLast", "ownRankButton"}) do
        highscoreController.ui[btn]:setEnabled(false)
    end
end

function submit()
    highscoreRequest(1, 0)
end

function showOwnRank()
    highscoreRequest(1, 1)
end

function highscoreRequest(currentPage, typex)
    local filters = highscoreController.ui.filters
    local vocation = filters.vocationBox:getCurrentOption()
    local category = filters.categoryBox:getCurrentOption()
    if requestPending or not vocation or not category then
        return
    end
    requestPending = true
    setHighscoreState(tr('Loading...'))
    disableButtons()
    filters:setEnabled(false)
    local id = getVocation(vocation.text)
    id = (id == "All Vocations" and 0xFFFFFFFF or id)

    local categoryId = getCategory(category.text)

    g_game.requestHighscore(typex, categoryId, id, serverSide.world, serverSide.worldType, serverSide.battlEye,
        currentPage, serverSide.totalInPages)
end

function requestInfo()
    local filters = highscoreController.ui.filters
    if filters.vocationBox:getCurrentOption() and filters.categoryBox:getCurrentOption() then
        requestPending = false
        highscoreRequest(serverSide.page, serverSide.action)
        return
    end

    requestPending = true
    setHighscoreState(tr('Loading...'))
    disableButtons()
    highscoreController.ui.filters:setEnabled(false)
    g_game.requestHighscore(serverSide.action, serverSide.category, serverSide.vocation, serverSide.world,
        serverSide.worldType, serverSide.battlEye, serverSide.page, serverSide.totalInPages)
end
