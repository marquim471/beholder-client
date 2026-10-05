-- Auxiliar miniWindows
local acceptWindow = nil
local changeNameWindow = nil
local transferPointsWindow = nil
local processingWindow = nil
local messageBox = nil


local oldProtocol = false
local a0xF2 = true

local offerDescriptions = {}
local reasonCategory = {}
local bannersHome = {}

local currentIndex = 1
local bannerEvent
local bannerDelay = 10000
local bannerHovered = false
local coinBalance = 0
local transferableBalance = 0
local purchasePending = false
local serverImageUrl
local configurationOffer
local currentProducts
local updatingProducts = false

-- Daily offers: the server sends the time left and the regular prices on its own opcode, right
-- before the home page (the home packet only says the offer is on sale).
local DAILY_OFFERS_OPCODE = 147
local dailyInfo = { endsAt = 0, base = {} }
local dailyTimerEvent

local function stopDailyTimer()
    if dailyTimerEvent then
        removeEvent(dailyTimerEvent)
        dailyTimerEvent = nil
    end
end

-- "Ends in: HH:MM:SS", red in the last 30 minutes, like the RTC store.
local function updateDailyTimer()
    dailyTimerEvent = nil
    local label = controllerShop.ui.HomePanel.DailyOffers.timer
    local left = math.max(0, dailyInfo.endsAt - os.time())
    label:setText(string.format('Ends in: %02d:%02d:%02d', math.floor(left / 3600), math.floor(left % 3600 / 60), left % 60))
    label:setColor(left <= 1800 and '#d33c3c' or '#909090')
    if left > 0 and controllerShop.ui:isVisible() then
        dailyTimerEvent = scheduleEvent(updateDailyTimer, 1000)
    end
end

local function onDailyOffersInfo(protocol, opcode, data)
    if type(data) ~= 'table' or data.type ~= 'daily' then
        return
    end
    dailyInfo.endsAt = os.time() + (tonumber(data.remaining) or 0)
    dailyInfo.base = type(data.base) == 'table' and data.base or {}
end

local function stopBanner()
    if bannerEvent then
        removeEvent(bannerEvent)
        bannerEvent = nil
    end
end

-- /*=============================================
-- =            To-do                  =
-- =============================================*/
-- - Correct HTML string syntax
-- - cache
-- - try on outfit

GameStore = {}
-- == Enums ==--
GameStore.website = {
    WEBSITE_GETCOINS = "",
    --IMAGES_URL =  "http://localhost/images/store/" --./game_store --https://docs.opentibiabr.com/opentibiabr/downloads/website-applications/applications#store-for-client-13-1
}

GameStore.CoinType = {
    Coin = 0,
    Transferable = 1
}

GameStore.ClientOfferTypes = {
	CLIENT_STORE_OFFER_OTHER = 0,
	CLIENT_STORE_OFFER_NAMECHANGE = 1,
	CLIENT_STORE_OFFER_WORLD_TRANSFER = 2,
	CLIENT_STORE_OFFER_HIRELING = 3, --idk
	CLIENT_STORE_OFFER_CHARACTER = 4,--idk
	CLIENT_STORE_OFFER_TOURNAMENT = 5,--idk
	CLIENT_STORE_OFFER_CONFIRM = 6,--idk
}

GameStore.States = {
    STATE_NONE = 0,
    STATE_NEW = 1,
    STATE_SALE = 2,
    STATE_TIMED = 3
}

GameStore.SendingPackets = {
    S_CoinBalance = 0xDF, -- 223
    S_StoreError = 0xE0, -- 224
    S_RequestPurchaseData = 0xE1, -- 225
    S_CoinBalanceUpdating = 0xF2, -- 242
    S_OpenStore = 0xFB, -- 251
    S_StoreOffers = 0xFC, -- 252
    S_OpenTransactionHistory = 0xFD, -- 253
    S_CompletePurchase = 0xFE -- 254
}

GameStore.RecivedPackets = {
    C_StoreEvent = 0xE9, -- 233
    C_TransferCoins = 0xEF, -- 239
    C_ParseHirelingName = 0xEC, -- 236
    C_OpenStore = 0xFA, -- 250
    C_RequestStoreOffers = 0xFB, -- 251
    C_BuyStoreOffer = 0xFC, -- 252
    C_OpenTransactionHistory = 0xFD, -- 253
    C_RequestTransactionHistory = 0xFE -- 254
}

-- /*=============================================
-- =            Local Function auxiliaries      =
-- =============================================*/

local function showPanel(panel)
    stopBanner()
    if panel == "HomePanel" then
        controllerShop.ui.HomePanel:setVisible(true)
        controllerShop.ui.panelItem:setVisible(false)
        controllerShop.ui.transferHistory:setVisible(false)
    elseif panel == "transferHistory" then
        controllerShop.ui.HomePanel:setVisible(false)
        controllerShop.ui.panelItem:setVisible(false)
        controllerShop.ui.transferHistory:setVisible(true)
    elseif panel == "panelItem" then
        controllerShop.ui.HomePanel:setVisible(false)
        controllerShop.ui.panelItem:setVisible(true)
        controllerShop.ui.transferHistory:setVisible(false)
    end
end

local function destroyWindow(windows)
    if type(windows) == "table" then
        for _, window in pairs(windows) do
            if window and not window:isDestroyed() then
                window:destroy()
                window = nil
            end
        end
    else
        if windows and not windows:isDestroyed() then
            windows:destroy()
            windows = nil
        end
    end
end

local function getPageLabelHistory()
    local text = controllerShop.ui.transferHistory.lblPage:getText()
    local currentPage, pageCount = text:match("Page (%d+)/(%d+)")
    return tonumber(currentPage), tonumber(pageCount)
end

local function setImagenHttp(widget, url, isIcon, isBanner)
    local relativePath = url:gsub("^/+", "")
    local localPath = "/game_store/images/" .. relativePath
    widget.storeImage = url
    local function applyImage(path)
        if widget:isDestroyed() or widget.storeImage ~= url then
            return
        end
        if isIcon then
            widget:setIcon(path)
        else
            widget:setImageSource(path)
        end
    end
    if g_resources.fileExists(localPath) then
        applyImage(localPath)
        return
    end
    applyImage(isBanner and "" or "/game_store/images/dynamic-image-error")
    local baseUrl = GameStore.website.IMAGES_URL or serverImageUrl
    if not baseUrl or baseUrl == "" then
        return
    end
    HTTP.downloadImage(baseUrl:gsub("/*$", "/") .. relativePath, function(path, err)
        if not err then
            applyImage(path)
        end
    end)
end

local STORE_ICON_PATH = "/game_store/images/store-icons-inline"
local STORE_ICON_TAGS = {
    ["{info}"]                    = {clip = "0 0 13 13",   text = ""},
    ["{character}"]               = {clip = "13 0 13 13",  text = "only usable by purchasing character"},
    ["{charactericon}"]           = {clip = "13 0 13 13",  text = ""},
    ["{usablebyall}"]             = {clip = "26 0 13 13",  text = "can be used by all characters that have access to the house"},
    ["{usablebyallicon}"]         = {clip = "26 0 13 13",  text = ""},
    ["{box}"]                     = {clip = "39 0 13 13",  text = "comes in a box which can only be unwrapped by purchasing character"},
    ["{boxicon}"]                 = {clip = "39 0 13 13",  text = ""},
    ["{storeinbox}"]              = {clip = "52 0 13 13",  text = "will be sent to your Store inbox and can only be stored there and in depot box"},
    ["{storeinboxicon}"]          = {clip = "52 0 13 13",  text = ""},
    ["{house}"]                   = {clip = "65 0 13 13",  text = "can only be unwrapped in a house owned by the purchasing character"},
    ["{houseicon}"]               = {clip = "65 0 13 13",  text = ""},
    ["{once}"]                    = {clip = "78 0 13 13",  text = "can only be purchased once"},
    ["{onceicon}"]                = {clip = "78 0 13 13",  text = ""},
    ["{backtoinbox}"]             = {clip = "91 0 13 13",  text = "will be wrapped back and sent to inbox if the purchasing character is no longer the house owner"},
    ["{backtoinboxicon}"]         = {clip = "91 0 13 13",  text = ""},
    ["{vocationlevelcheck}"]      = {clip = "104 0 13 13", text = "only buyable if fitting vocation and level of purchasing character"},
    ["{vocationlevelcheckicon}"]  = {clip = "104 0 13 13", text = ""},
    ["{speedboost}"]              = {clip = "117 0 13 13", text = "provides character with a speed boost"},
    ["{speedboosticon}"]          = {clip = "117 0 13 13", text = ""},
    ["{activated}"]               = {clip = "130 0 13 13", text = "activated at purchase"},
    ["{activatedicon}"]           = {clip = "130 0 13 13", text = ""},
    ["{battlesign}"]              = {clip = "143 0 13 13", text = "cannot be purchased by characters with protection zone block or battle sign"},
    ["{battlesignicon}"]          = {clip = "143 0 13 13", text = ""},
    ["{capacity}"]                = {clip = "156 0 13 13", text = "cannot be purchased if capacity is exceeded"},
    ["{capacityicon}"]            = {clip = "156 0 13 13", text = ""},
    ["{use}"]                     = {clip = "169 0 13 13", text = "can be used"},
    ["{useicon}"]                 = {clip = "169 0 13 13", text = ""},
    ["{transferableprice}"]       = {clip = "182 0 13 13", text = "can be purchased with transferable Tibia Coins"},
    ["{transferablepriceicon}"]   = {clip = "182 0 13 13", text = ""},
    ["{star}"]                    = {localImg = "/game_store/images/icon-star-gold", text = ""},
}

local function matchIconTag(line)
    if line:byte(1) ~= 123 then return nil end -- fast bail if not '{'
    local s, e, cap = line:find("^{limit|(%d+)}")
    if s then
        return {clip = "78 0 13 13", text = "maximum amount that can be owned by character: %s"}, e, cap
    end
    local close = line:find("}", 1, true)
    if close then
        local info = STORE_ICON_TAGS[line:sub(1, close)]
        if info then return info, close, nil end
    end
end

local function addDescriptionLine(container, lineText, color)
    if not lineText:match("%S") then return end
    lineText = lineText:gsub("<[^>]+>", ""):gsub("&nbsp;", " "):gsub("&#8226;", "- ")

    local widget = g_ui.createWidget('DescriptionLine', container)
    if not widget then return end

    local iconWidget = widget:getChildById('icon')
    local textWidget = widget:getChildById('text')
    if not iconWidget or not textWidget then return end
    if color then textWidget:setColor(color) end

    local info, tagEnd, cap = matchIconTag(lineText)
    if info then
        iconWidget:setVisible(true)
        if info.localImg then
            iconWidget:setImageSource(info.localImg)
        else
            iconWidget:setImageSource(STORE_ICON_PATH)
            iconWidget:setImageClip(info.clip)
        end
        local tagText = (cap and info.text:format(cap)) or info.text
        local rest    = lineText:sub(tagEnd + 1):match("^%s*(.-)%s*$")
        textWidget:setMarginLeft(16)
        textWidget:setText(tagText ~= "" and (tagText .. " " .. rest) or rest)
    else
        textWidget:setMarginLeft(0)
        textWidget:setText(lineText:match("^%s*(.-)%s*$"))
    end

    widget:setHeight(math.max(14, textWidget:getTextSize().height + 2))
end

local function renderDescription(panel, text, errorText)
    local descPanel = panel:getChildById('descriptionPanel')
    local container = descPanel and descPanel:getChildById('descriptionScrollArea')
    if not container or container:isDestroyed() then return end
    container:destroyChildren()

    if errorText then
        for line in errorText:gmatch("[^\r\n]+") do
            addDescriptionLine(container, line, "#d33c3c")
        end
    end

    if text and text ~= "" then
        for line in text:gmatch("[^\r\n]+") do
            addDescriptionLine(container, line, nil)
        end
    end
end

local function formatNumberWithCommas(value)
    local sign = value < 0 and "-" or ""
    value = math.abs(value)
    local formattedValue = string.format("%d", value)
    formattedValue = formattedValue:reverse():gsub("(%d%d%d)", "%1,")
    formattedValue = formattedValue:reverse():gsub("^,", "")
    return sign .. formattedValue
end

local function setOfferPrice(label, offer)
    label:setText(formatNumberWithCommas(offer.price))
    local priceWidth = label:getTextSize().width
    label:setWidth(math.max(label:getWidth(), priceWidth + 24))
    local basePrice = label.basePrice
    local discounted = offer.state == GameStore.States.STATE_SALE and (offer.basePrice or 0) > offer.price
    if discounted then
        basePrice:setText(formatNumberWithCommas(offer.basePrice))
        basePrice:setMarginRight(priceWidth + 3 - label:getTextOffset().x)
    end
    local function updateBasePrice()
        basePrice:setVisible(discounted and basePrice:getTextSize().width + priceWidth + 24 <= label:getWidth())
    end
    label.onGeometryChange = updateBasePrice
    updateBasePrice()
    if discounted then
        return string.format('Regular price: %s coins\nOffer price: %s coins',
            formatNumberWithCommas(offer.basePrice), formatNumberWithCommas(offer.price))
    end
end

local function getCoinsBalance()
    return coinBalance, transferableBalance
end

local function getOfferBalance(coinType)
    -- The server reports the total balance and accepts combined payment for type 1.
    if coinType == GameStore.CoinType.Transferable then
        return coinBalance
    end
    return math.max(0, coinBalance - transferableBalance)
end

local function fixServerNoSend0xF2()
    local player = g_game.getLocalPlayer()
    if a0xF2 and player then
        onParseStoreGetCoin(player:getResourceBalance(ResourceTypes.COIN_NORMAL),
            player:getResourceBalance(ResourceTypes.COIN_TRANSFERRABLE))
    end
end

local function convert_timestamp(timestamp)
    local fecha_hora = os.date("%Y-%m-%d, %H:%M:%S", timestamp)
    return fecha_hora
end

local function getProductData(product)
    if product.itemId or product.itemType then
        return {
            VALOR = "item",
            ID = product.itemId or product.itemType
        }
    elseif product.icon then
        return {
            VALOR = "icon",
            ID = product.icon
        }
    elseif product.outfitId or product.mountId or product.mountClientId or product.sexId then
        return {
            VALOR = "mountId",
            ID = product.outfitId or product.mountId or product.mountClientId or product.sexId,
            head = product.outfitHead or (product.outfit and product.outfit.lookHead) or 0,
            body = product.outfitBody or (product.outfit and product.outfit.lookBody) or 0,
            legs = product.outfitLegs or (product.outfit and product.outfit.lookLegs) or 0,
            feet = product.outfitFeet or (product.outfit and product.outfit.lookFeet) or 0
        }
    elseif product.maleOutfitId then
        return {
            VALOR = "outfitId",
            ID = product.maleOutfitId
        }
    end
end

local function createProductImage(imageParent, data, displaySize)
    local widget
    if data.VALOR == "item" then
        widget = g_ui.createWidget('UIItem', imageParent)
        widget:setItemId(data.ID)
        widget:setVirtual(true)
    elseif data.VALOR == "icon" then
        widget = g_ui.createWidget('UIWidget', imageParent)
        setImagenHttp(widget, "64/" .. data.ID, false)
    elseif data.VALOR == "mountId" or data.VALOR == "outfitId" then
        widget = g_ui.createWidget('UICreature', imageParent)
        widget:setOutfit({type = data.ID, head = data.head or 0, body = data.body or 0,
            legs = data.legs or 0, feet = data.feet or 0})
    end
    if widget then
        local size = displaySize or (data.VALOR == 'item' and math.min(64, math.max(32, widget:getItem():getExactSize())) or 64)
        widget:setSize({width = size, height = size})
        widget:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
        widget:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        widget:setPhantom(true)
        widget:setImageSmooth(false)
    end
end

local function setOfferHighlight(row, state)
    local color = '#c0c0c0'
    local source
    if state == GameStore.States.STATE_NEW then
        color, source = '#44ad25', 'new'
    elseif state == GameStore.States.STATE_SALE then
        color, source = '#f7af48', 'store-flag-sale'
    elseif state == GameStore.States.STATE_TIMED then
        color, source = '#1872c3', 'store-flag-expires'
    end
    row.lblName:setColor(color)
    row.highlight:setVisible(source ~= nil)
    if source then
        row.highlight:setImageSource('/game_store/images/' .. source)
        row.highlight:setSize(state == GameStore.States.STATE_NEW and '78 78' or
            state == GameStore.States.STATE_TIMED and '10 15' or '28 28')
    end
end

-- /*=============================================
-- =    behavior categories and subcategories    =
-- =============================================*/

local function disableAllButtons()
    local panel = controllerShop.ui.panelItem
    panel:getChildById('StackOffers'):destroyChildren()
    panel:getChildById('image'):destroyChildren()
    for i = 1, controllerShop.ui.listCategory:getChildCount() do
        local widget = controllerShop.ui.listCategory:getChildByIndex(i)
        if widget and widget.Button then
            widget.Button:setEnabled(widget == controllerShop.ui.openedCategory and widget.subCategories ~= nil)
            if widget.subCategories then
                for subId, _ in ipairs(widget.subCategories) do
                    local subWidget = widget:getChildById(subId)
                    if subWidget and subWidget.Button then
                        subWidget.Button:setEnabled(false)
                    end
                end
            end
        end
    end
    offerDescriptions = {}
end

local function enableAllButtons()
    for i = 1, controllerShop.ui.listCategory:getChildCount() do
        local widget = controllerShop.ui.listCategory:getChildByIndex(i)
        if widget and widget.Button then
            widget.Button:setEnabled(true)
            if widget.subCategories then
                for subId, _ in ipairs(widget.subCategories) do
                    local subWidget = widget:getChildById(subId)
                    if subWidget and subWidget.Button then
                        subWidget.Button:setEnabled(true)
                    end
                end
            end
        end
    end
end

local function toggleSubCategories(parent, isOpen)
    for subId, _ in ipairs(parent.subCategories) do
        local subWidget = parent:getChildById(subId)
        if subWidget then
            subWidget:setVisible(isOpen)
        end
    end
    parent:setHeight(isOpen and parent.openedSize or parent.closedSize)
    parent.opened = isOpen
    parent.subPanel:setVisible(isOpen)
    parent.SelectionArrow:setVisible(isOpen and parent.selectedSubCategory ~= nil)
    parent.subPanel:setHeight(#parent.subCategories * 20 + (#parent.subCategories < 3 and 2 or 1))
    parent.Button.Arrow:setVisible(true)
    if not isOpen then
        parent.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-down")
    end
end

local function close(parent)
    if parent.subCategories then
        toggleSubCategories(parent, false)
    end
end

local function open(parent)
    local oldOpen = controllerShop.ui.openedCategory
    if oldOpen and oldOpen ~= parent then
        close(oldOpen)
    end
    toggleSubCategories(parent, true)
    controllerShop.ui.openedCategory = parent
end

local function closeCategoryButtons()
    for i = 1, controllerShop.ui.listCategory:getChildCount() do
        local widget = controllerShop.ui.listCategory:getChildByIndex(i)
        if widget and widget.subCategories then
            widget.SelectionArrow:hide()
            for subId, _ in ipairs(widget.subCategories) do
                local subWidget = widget:getChildById(subId)
                if subWidget then
                    subWidget.Button:setChecked(false)
                    subWidget.Button.Title:setColor('#c0c0c0')
                end
            end
        end
    end
end

local function createSubWidget(parent, subId, subButton)
    local subWidget = g_ui.createWidget("storeSubCategory", parent)
    subWidget:setId(subId)
    setImagenHttp(subWidget.Button.Icon, subButton.icon, true)
    subWidget.Button.Title:setText(subButton.text)
    subWidget:setVisible(false)
    subWidget.open = subButton.open
    subWidget:setMarginRight(2)
    function subWidget.Button.onClick()
        disableAllButtons()
        local selectedOption = controllerShop.ui.selectedOption
        closeCategoryButtons()
        parent.Button:setChecked(false)
        subWidget.Button:setChecked(true)
        subWidget.Button.Title:setColor('#f4f4f4')
        parent.selectedSubCategory = subId
        parent.SelectionArrow:setMarginTop((subId - 1) * 20 + 6)
        parent.SelectionArrow:show()
        controllerShop.ui.openedSubCategory = subWidget

        if selectedOption then
            selectedOption:hide()
        end
        if subWidget.open == "Home" then
            g_game.sendRequestStoreHome()
        else
            g_game.requestStoreOffers(subButton.text,"", 0, 1)
        end
    end

    subWidget:addAnchor(AnchorRight, "parent", AnchorRight)
    if subId == 1 then
        subWidget:addAnchor(AnchorTop, "parent", AnchorTop)
        subWidget:setMarginTop(18)
    else
        subWidget:addAnchor(AnchorTop, "prev", AnchorBottom)
        subWidget:setMarginTop(1)
    end

    return subWidget
end

-- /*=============================================
-- =            Controller                   =
-- =============================================*/
controllerShop = Controller:new()
g_ui.importStyle("style/ui.otui")
controllerShop:setUI('game_store')
function controllerShop:onInit()
    controllerShop.ui:hide()

    for k, v in pairs({{'Most Popular First', 'popular'}, {'Alphabetically', 'alphabetical'},
                       {'Newest First', 'newest'}}) do
        controllerShop.ui.panelItem.comboBoxContainer.MostPopularFirst:addOption(v[1], v[2])
    end

    controllerShop.ui.transferPoints.onClick = transferPoints
    controllerShop.ui.panelItem.listProduct.onChildFocusChange = chooseOffert
    controllerShop.ui.panelItem.comboBoxContainer.MostPopularFirst.onOptionChange = refreshProducts
    controllerShop.ui.panelItem.comboBoxContainer.showAll.onOptionChange = refreshProducts
    controllerShop.ui.btnCoins:setEnabled(GameStore.website.WEBSITE_GETCOINS ~= "")
    if GameStore.website.WEBSITE_GETCOINS == "" then
        controllerShop.ui.btnCoins:setTooltip('Coin purchases are currently unavailable.')
    end
    -- /*=============================================
    -- =            Parse                         =
    -- =============================================*/

    controllerShop:registerEvents(g_game, {
        onParseStoreGetCoin = onParseStoreGetCoin,
        onParseStoreGetCategories = onParseStoreGetCategories,
        onParseStoreCreateHome = onParseStoreCreateHome,
        onParseStoreCreateProducts = onParseStoreCreateProducts,
        onParseStoreGetHistory = onParseStoreGetHistory,
        onParseStoreGetPurchaseStatus = onParseStoreGetPurchaseStatus,
        onParseStoreOfferDescriptions = onParseStoreOfferDescriptions,
        onParseStoreError = onParseStoreError,
        onStoreInit = onStoreInit,
        onStoreRequestPurchaseData = onStoreRequestPurchaseData,
        onModalDialog = function()
            if configurationOffer then purchasePending = false end
        end
    })
    ProtocolGame.registerExtendedJSONOpcode(DAILY_OFFERS_OPCODE, onDailyOffersInfo)
end

function controllerShop:onGameStart()
    a0xF2 = true
    oldProtocol = g_game.getClientVersion() < 1310
end

function controllerShop:onGameEnd()
    stopBanner()
    stopDailyTimer()
    dailyInfo.endsAt, dailyInfo.base = 0, {}
    purchasePending = false
    configurationOffer = nil
    coinBalance, transferableBalance = 0, 0
    bannersHome, currentProducts = {}, nil
    controllerShop.ui.HomePanel.HomeImagen.storeImage = nil
    controllerShop.ui.HomePanel.HomeImagen:setImageSource('')
    controllerShop.ui.panelItem.listProduct:destroyChildren()
    controllerShop.ui.panelItem.StackOffers:destroyChildren()
    controllerShop.ui.panelItem.image:destroyChildren()
    controllerShop.ui.listCategory:destroyChildren()
    controllerShop.ui.openedCategory = nil
    controllerShop.ui.openedSubCategory = nil
    controllerShop.ui.HomePanel.HomeRecentlyAdded.HomeProductos:destroyChildren()
    controllerShop.ui.HomePanel.DailyOffers.offers:destroyChildren()
    controllerShop.ui.HomePanel.DailyOffers.empty:show()
    if controllerShop.ui:isVisible() then
        controllerShop.ui:hide()
    end

    destroyWindow({transferPointsWindow, changeNameWindow, acceptWindow, processingWindow,messageBox})
end

function controllerShop:onTerminate()
    stopBanner()
    stopDailyTimer()
    ProtocolGame.unregisterExtendedJSONOpcode(DAILY_OFFERS_OPCODE)
    destroyWindow({transferPointsWindow, changeNameWindow, acceptWindow, processingWindow,messageBox})
end

-- /*=============================================
-- =            Parse                           =
-- =============================================*/

function onStoreInit(url, coinsPacketSize)
    serverImageUrl = url
end

function onParseStoreGetCoin(getTibiaCoins, getTransferableCoins)
    a0xF2 = false
    coinBalance = getTibiaCoins
    transferableBalance = getTransferableCoins
    local balance = controllerShop.ui.lblCoins
    balance.lblTibiaCoins:setText(formatNumberWithCommas(coinBalance))
    balance.lblTibiaTransfer:setText(formatNumberWithCommas(transferableBalance))
    controllerShop.ui.lblCoins:setTooltip(string.format('%s coins, including %s transferable coins.',
        formatNumberWithCommas(coinBalance), formatNumberWithCommas(transferableBalance)))
    local focused = controllerShop.ui.panelItem.listProduct:getFocusedChild()
    if focused and not purchasePending then
        chooseOffert(nil, focused)
    end
end

function onParseStoreOfferDescriptions(offerId, description)
    offerDescriptions[offerId] = {
        id = offerId,
        description = description
    }
    local panel = controllerShop.ui.panelItem
    local focused = panel.listProduct:getFocusedChild()
    if focused then
        local product = focused.product
        local offer = product.subOffers and product.subOffers[1] or product
        if offer and offer.id == offerId then
            renderDescription(panel, description, focused.descriptionError)
        end
    end
end

function onParseStoreGetPurchaseStatus(purchaseStatus)
    purchasePending = false
    configurationOffer = nil
    destroyWindow({processingWindow, messageBox})
    controllerShop.ui:hide()
    messageBox = g_ui.createWidget('confirmarSHOP', g_ui.getRootWidget())
    local window = messageBox
    window.Box:setText(purchaseStatus)
    local function close()
        if window:isDestroyed() then return end
        window:destroy()
        if not g_game.isOnline() then return end
        controllerShop.ui:show()
        local selected = controllerShop.ui.panelItem.listProduct:getFocusedChild()
        if selected and selected.product.subOffers and selected.product.subOffers[1] then
            g_game.sendRequestStoreOfferById(selected.product.subOffers[1].id)
        end
    end
    window.buttonAnimation.onClick = function()
        if not window.buttonAnimation:isEnabled() then return end
        window.buttonAnimation:disable()
        local phase = 0
        window.buttonAnimation.animation:setImageSource('/game_store/images/purchase_animation')
        window.buttonAnimation.animation:setImageClip('0 0 108 108')
        periodicalEvent(function()
            if not window:isDestroyed() then
                window.buttonAnimation.animation:setImageClip((math.min(phase, 12) * 108) .. ' 0 108 108')
                phase = phase + 1
            end
        end, function() return not window:isDestroyed() end, 100, 100)
        controllerShop:scheduleEvent(close, 1000)
    end
    window.onEnter = window.buttonAnimation.onClick
    window.onEscape = close
end

function onParseStoreCreateProducts(storeProducts)
    if not storeProducts then return end
    currentProducts = storeProducts
    reasonCategory = storeProducts.disableReasons
    updatingProducts = true
    local comboBox = controllerShop.ui.panelItem.comboBoxContainer.showAll
    comboBox:clearOptions()
    comboBox:addOption('Show All', 'all')
    comboBox:addOption('Available Offers', 'available')
    updatingProducts = false
    refreshProducts()
end

function refreshProducts()
    if updatingProducts or not currentProducts then return end
    local storeProducts = currentProducts
    local panel = controllerShop.ui.panelItem
    local listProduct = panel.listProduct
    listProduct:destroyChildren()
    panel.StackOffers:destroyChildren()
    panel.offerScrollbar:hide()
    panel.StackOffers:setPaddingRight(0)
    panel.image:destroyChildren()
    panel.lblName:setText('')
    panel.lblName:removeTooltip()
    renderDescription(panel, '')
    local offers = {}
    local filter = panel.comboBoxContainer.showAll:getCurrentOption().data
    for index, product in ipairs(storeProducts.offers) do
        local available = false
        for _, offer in ipairs(product.subOffers or {product}) do
            if not offer.disabled then available = true end
        end
        if filter ~= 'available' or available then
            table.insert(offers, {product = product, index = index})
        end
    end
    local order = panel.comboBoxContainer.MostPopularFirst:getCurrentOption().data
    table.sort(offers, function(a, b)
        if order == 'alphabetical' and a.product.name ~= b.product.name then
            return a.product.name:lower() < b.product.name:lower()
        end
        local key = order == 'newest' and 'stateNewUntil' or 'popularityScore'
        local left, right = a.product[key] or 0, b.product[key] or 0
        return left ~= right and left > right or left == right and a.index < b.index
    end)
    for _, entry in ipairs(offers) do
        local product = entry.product
        local row = g_ui.createWidget('RowStore', listProduct)
        row.product, row.type = product, product.type

        local nameLabel = row:getChildById('lblName')
        nameLabel:setText(product.name)
        nameLabel:setTextAlign(AlignTopLeft)
        nameLabel:setMarginRight(4)

        local subOffers = product.subOffers or { product }
        setOfferHighlight(row, subOffers[1] and subOffers[1].state)
        local nameHeight = nameLabel:getTextSize().height
        nameLabel:setHeight(nameHeight)
        row:setHeight(math.max(82, nameHeight + 14 + #subOffers * 22))
        local lastOffer = subOffers[#subOffers]
        local clipY = lastOffer and lastOffer.coinType == GameStore.CoinType.Transferable and 0 or 159
        row:setImageClip(string.format('0 %d 240 82', clipY + (#subOffers > 1 and 80 or 0)))
        if row:getHeight() > 82 then
            row:setImageSource('/images/ui/2pixel-up-frame-borderimage')
            row:setImageClip('0 0 0 0')
            row:setImageBorder(2)
            row.image:setImageSource('/images/ui/1pixel-down-frame')
            row.image:setImageBorder(1)
            row.image:setSize('70 70')
            row.image:setMarginTop(4)
            row.image:setMarginLeft(4)
        end
        for _, subOffer in ipairs(subOffers) do
            local offerI = g_ui.createWidget('stackOfferPanel', row:getChildById('StackOffers'))
            offerI:setId(subOffer.id)
            if subOffer.disabled then
                offerI:disable()
                row:setOpacity(0.5)
            end
            local priceLabel = offerI:getChildById('lblPrice')
            local priceTooltip = setOfferPrice(priceLabel, subOffer)
            if priceTooltip then
                row:setTooltip((row:getTooltip() and row:getTooltip() .. "\n" or "") .. priceTooltip)
            end

            if subOffer.count and (subOffer.count > 1 or #subOffers > 1) then
                offerI:getChildById('count'):setText(subOffer.count .. "x")
            end
            fixServerNoSend0xF2()
            local isTransferable = subOffer.coinType == GameStore.CoinType.Transferable
            local price = subOffer.price
            local balance = getOfferBalance(subOffer.coinType)
            priceLabel:setColor(balance < price and "#d33c3c" or "white")

            if isTransferable then
                priceLabel:setIcon("/game_store/images/icon-tibiacointransferable")
            end
        end
        local data = getProductData(product)
        if data then
            createProductImage(row:getChildById('image'), data)
        end
    end

    controllerShop:scheduleEvent(function()
        local redirectId = storeProducts.redirectId
        if redirectId and type(redirectId) == "number" and redirectId ~= 0 then -- home behavior 
            for _, child in ipairs(listProduct:getChildren()) do
                for _, subOffer in ipairs(child.product.subOffers or { child.product }) do
                    if subOffer.id == redirectId then
                        listProduct:focusChild(child)
                        listProduct:ensureChildVisible(child)
                        return
                    end
                end
            end
        else
            local firstChild = listProduct:getFirstChild()
            if firstChild and firstChild:isEnabled() then
                listProduct:focusChild(firstChild)
                listProduct:ensureChildVisible(firstChild)
            end
        end
    end, 300, 'onParseStoreOfferDescriptionsSafeDelay')

    enableAllButtons()
    showPanel("panelItem")
    fixServerNoSend0xF2()
end

function onParseStoreCreateHome(offer)
    local homeProductos = controllerShop.ui.HomePanel.HomeRecentlyAdded.HomeProductos
    homeProductos:destroyChildren()
    local daily = controllerShop.ui.HomePanel.DailyOffers
    daily.offers:destroyChildren()
    for _, product in ipairs(offer.offers) do
        local isDailyOffer = product.unknownByte2 == GameStore.States.STATE_SALE
        local row = g_ui.createWidget('HomeStoreOffer', isDailyOffer and daily.offers or homeProductos)
        row.product, row.type = product, product.type
        row.lblName:setText(' ' .. product.name)
        setOfferHighlight(row, product.unknownByte2)
        local price = g_ui.createWidget('stackOfferPanel', row.StackOffers)
        if isDailyOffer then
            -- regular price struck through beside the sale price
            product.state = GameStore.States.STATE_SALE
            product.basePrice = tonumber(dailyInfo.base[tostring(product.id)]) or 0
            local tooltip = setOfferPrice(price.lblPrice, product)
            if tooltip then
                row:setTooltip(tooltip)
            end
        else
            price.lblPrice:setText(formatNumberWithCommas(product.price))
        end
        if product.coinType == GameStore.CoinType.Transferable then
            price.lblPrice:setIcon('/game_store/images/icon-tibiacointransferable')
        end
        price.lblPrice:setColor(getOfferBalance(product.coinType) < product.price and '#d33c3c' or '#c0c0c0')
        local data = getProductData(product)
        if data then
            createProductImage(row.image, data)
        end
        if product.disabled then
            row:setOpacity(0.5)
        end
        row.onClick = function() chooseHome(nil, row) end
    end
    daily.empty:setVisible(daily.offers:getChildCount() == 0)
    stopDailyTimer()
    daily.timer:setVisible(daily.offers:getChildCount() > 0 and dailyInfo.endsAt > 0)
    if daily.timer:isVisible() then
        updateDailyTimer()
    end
    bannersHome = offer.banners or {}
    bannerDelay = math.max(1, offer.bannerDelay or 10) * 1000
    currentIndex = 1
    enableAllButtons()
    showPanel('HomePanel')
    changeImagenHome()
    fixServerNoSend0xF2()
end

function onParseStoreGetHistory(currentPage, pageCount, historyData)
    local transferHistory = controllerShop.ui.transferHistory.historyPanel
    transferHistory:destroyChildren()
    transferHistory.onScrollHeightChange = function(list)
        controllerShop.ui.transferHistory.historyScrollBar:setVisible(list:getChildrenRect().height > list:getHeight())
    end
    controllerShop.ui.transferHistory.historyScrollBar:setValue(0)
    pageCount = math.max(1, pageCount)
    controllerShop.ui.transferHistory.lblPage:setText(string.format("Page %d/%d", currentPage + 1, pageCount))
    controllerShop.ui.transferHistory.btnPrevPage:setEnabled(currentPage > 0)
    controllerShop.ui.transferHistory.btnNextPage:setEnabled(currentPage + 1 < pageCount)
    for i, data in ipairs(historyData) do
        local row = g_ui.createWidget("historyData2", transferHistory)
        row.date:setText(convert_timestamp(data[1]))
        row.date:setTooltip(row.date:getText())
        local balance = data[3]
        row.Balance:setText((balance >= 0 and "+" or "") .. formatNumberWithCommas(balance))
        row.Balance:setTooltip(row.Balance:getText())
        row.Balance:setColor(balance < 0 and "#D33C3C" or "#44ad25")
        row.Description:setText(data[5])
        row.Description:setTooltip(data[5])
        row.Balance:setIcon(data[4] == GameStore.CoinType.Transferable and 
                            "/game_store/images/icon-tibiacointransferable" or 
                            "images/ui/tibiaCoin")
        row:setBackgroundColor(i % 2 == 0 and "#414141" or "#484848")
    end
    showPanel("transferHistory")
end

function onParseStoreGetCategories(buttons)
    if controllerShop.ui.listCategory:getChildCount() > 0 then
        return
    end
    controllerShop.ui.listCategory:destroyChildren()

    local categories = {}
    if not oldProtocol then
        categories = {
            ["Home"] = {
                ["subCategories"] = {},
                ["name"] = "Home",
                ["icons"] = {
                    [1] = "icon-store-home.png"
                },
                ["state"] = 0
            }
        }
    end

    local subcategories = {}

    for _, button in ipairs(buttons) do
        if not button.parent then
            categories[button.name] = button
            categories[button.name].subCategories = {}
        else
            table.insert(subcategories, button)
        end
    end

    for _, subcat in ipairs(subcategories) do
        if categories[subcat.parent] then
            table.insert(categories[subcat.parent].subCategories, subcat)
        end
    end

    local orderedCategoryNames = {
        "Home",
        "Special",
        "VIP",
        "Starter Pack",
        "Consumables",
        "Cosmetics",
        "House",
        "Extras",
    }

    local priority = {}
    for index, name in ipairs(orderedCategoryNames) do
        priority[name:lower()] = index
    end

    local categoryArray = {}
    for name, data in pairs(categories) do
        table.insert(categoryArray, data)
    end

    -- Ordenar el array
    table.sort(categoryArray, function(a, b)
        local prioA = priority[a.name:lower()] or math.huge
        local prioB = priority[b.name:lower()] or math.huge
        return prioA < prioB
    end)

    for _, category in ipairs(categoryArray) do
        local widget = g_ui.createWidget("storeCategory", controllerShop.ui.listCategory)
        widget:setId(category.name)
            -- widget.Button.Icon:setIcon("/game_store/images/13/" .. category.icons[1])
            if category.icons[1] == "icon-store-home.png" then
                widget.Button.Icon:setIcon("/game_store/images/icon-store-home")
            else
                setImagenHttp(widget.Button.Icon, "/13/" .. category.icons[1], true)
            end

            widget.Button.Title:setText(category.name)
            widget.open = category.name

            if #category.subCategories > 0 then
                widget.subCategories = category.subCategories
                widget.subCategoriesSize = #category.subCategories
                widget.Button.Arrow:setVisible(true)

                for subId, subButton in ipairs(category.subCategories) do
                    local subWidget = createSubWidget(widget, subId, {
                        text = subButton.name,
                        icon = "/13/" .. subButton.icons[1],
                        open = subButton.name
                    })
                end
            end

            widget:setMarginTop(controllerShop.ui.listCategory:getChildCount() == 1 and 5 or 10)

            widget.Button.onClick = function()
                if widget.subCategories and controllerShop.ui.openedCategory == widget then
                    toggleSubCategories(widget, not widget.opened)
                    return
                end
                disableAllButtons()
                for _, other in ipairs(controllerShop.ui.listCategory:getChildren()) do
                    if other ~= widget and other.Button then
                        other.Button:setChecked(false)
                    end
                end
                local parent = widget
                local oldOpen = controllerShop.ui.openedCategory
                local panel = controllerShop.ui.panelItem
                local btnBuy = panel:getChildById('btnBuy')
                local image = panel:getChildById('image')
                local lblPrice = panel:getChildById('lblPrice')
                local btnBuy = panel:getChildById('StackOffers')

                btnBuy:destroyChildren()

                local firstChild = image:getFirstChild()
                if image:getChildCount() ~= 0 and firstChild then
                    local styleClass = firstChild:getStyle().__class
                    if styleClass == "UIItem" then
                        firstChild:setItemId(nil)
                    elseif styleClass == "UICreature" then
                        firstChild:setOutfit({
                            type = nil
                        })
                    else
                        firstChild:setImageSource("")
                    end
                end

                if oldOpen and oldOpen ~= parent then
                    if oldOpen.Button then
                        oldOpen.Button:setChecked(false)
                        oldOpen.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-down")
                    end
                    close(oldOpen)
                end

                if parent.subCategoriesSize then
                    parent.closedSize = 20
                    parent.openedSize = 20 + parent.subCategoriesSize * 20

                    if parent.opened then
                        close(parent)
                        closeCategoryButtons()
                        widget.Button:setChecked(true)
                    else
                        open(parent)
                        parent:getChildById(1).Button.onClick()
                        return
                    end
                else
                    widget.Button:setChecked(true)
                end

                widget.Button.Arrow:setImageSource(parent.subCategoriesSize and "/images/ui/icon-arrow7x7-down" or "/images/ui/icon-arrow7x7-right")
                widget.Button.Arrow:setVisible(widget.subCategoriesSize ~= nil)

                if controllerShop.ui.selectedOption then
                    controllerShop.ui.selectedOption:hide()
                end
                if category.name == "Home" then
                    controllerShop.ui.HomePanel.HomeRecentlyAdded.HomeProductos:destroyChildren()
                    g_game.sendRequestStoreHome()
                else
                    g_game.requestStoreOffers(category.name,"", 0, 1)
                end
                controllerShop.ui.openedCategory = parent
            end
        end
        local firstCategory = controllerShop.ui.listCategory:getChildByIndex(1)
        if controllerShop.ui.openedCategory == nil and firstCategory then
            controllerShop.ui.openedCategory = firstCategory
            firstCategory.Button:onClick()
        end

end

function onParseStoreError(errorMessage)
    purchasePending = false
    configurationOffer = nil
    enableAllButtons()
    destroyWindow(processingWindow)
    displayErrorBox(controllerShop.ui:getText(), errorMessage)
end

-- /*=============================================
-- =            buttons                          =
-- =============================================*/

function hide()
    stopBanner()
    if not controllerShop.ui then
        return
    end
    controllerShop.ui:hide()
end

function toggle()
    if not controllerShop.ui then
        return
    end

    if controllerShop.ui:isVisible() then
        return hide()
    end
    show()
end

function show()
    if not controllerShop.ui then
        return
    end

    controllerShop.ui:show()
    controllerShop.ui:raise()
    controllerShop.ui:focus()
    controllerShop.ui.SearchEdit:focus()

    g_game.openStore()
    if controllerShop.ui.listCategory:getChildCount() > 0 then
        controllerShop.ui.listCategory:getChildById("Home").Button.onClick()
    end
    controllerShop:scheduleEvent(function()
        if controllerShop.ui.listCategory:getChildCount() == 0 then
            g_game.sendRequestStoreHome() -- fix 13.10
            local packet1 = GameStore.RecivedPackets.C_OpenStore
            g_logger.warning(string.format("[game_store BUG] Check 0x%X (%d) L827", packet1, packet1))
        end
    end, 1000, function() return 'serverNoSendPackets0xF20xFA' end)
end



function getUI()
    return controllerShop.ui
end

function getCoinsWebsite()
    if GameStore.website.WEBSITE_GETCOINS ~= "" then
        g_platform.openUrl(GameStore.website.WEBSITE_GETCOINS)
    else
        return
    end
end
-- /*=============================================
-- =            History                         =
-- =============================================*/

function toggleTransferHistory()
    if controllerShop.ui.transferHistory:isVisible() then
        if controllerShop.ui.openedCategory and controllerShop.ui.openedCategory:getId() == "Home" then
            showPanel("HomePanel")
        else
            showPanel("panelItem")
        end
    else
        g_game.openTransactionHistory(25)
    end
end

function requestTransactionHistory(widget)
    local currentPage, pageCount = getPageLabelHistory()
    local newPage = currentPage + (widget:getId() == "btnNextPage" and 1 or -1)
    
    if newPage > 0 and newPage <= pageCount then
        g_game.requestTransactionHistory(newPage - 1, 25)
    end
end

-- /*=============================================
-- =            focusedChild                     =
-- =============================================*/

function chooseOffert(self, focusedChild)
    if not focusedChild then
        return
    end

    local product = focusedChild.product
    local panel = controllerShop.ui.panelItem
    local nameLabel = panel:getChildById('lblName')
    nameLabel:setText(product.name)
    nameLabel:setTooltip(product.name)
    nameLabel:setTextAlign(nameLabel:getTextSize().width > nameLabel:getWidth() and AlignLeft or AlignCenter)
    local description = product.description or ""
    local subOffers = product.subOffers or {}
    if not table.empty(subOffers) then
        local descriptionInfo = offerDescriptions[subOffers[1].id] or { id = 0xFFFF, description = "" }
        description = descriptionInfo.description
    end

    focusedChild.descriptionError = nil
    renderDescription(panel, description)

    local data = getProductData(product)
    local imagePanel = panel:getChildById('image')
    imagePanel:destroyChildren()
    if data then
        createProductImage(imagePanel, data, 128)
    end
    fixServerNoSend0xF2()

    local offerStackPanel = panel:getChildById('StackOffers')
    offerStackPanel:destroyChildren()

    local offers = not table.empty(subOffers) and subOffers or { product }
    panel.offerScrollbar:setVisible(#offers > 2)
    offerStackPanel:setPaddingRight(#offers > 2 and 14 or 0)
    for _, offer in ipairs(offers) do
        local offerPanel = g_ui.createWidget('OfferPanel2', offerStackPanel)

        local priceLabel = offerPanel:getChildById('lblPrice')
        local priceTooltip = setOfferPrice(priceLabel, offer)
        if priceTooltip then
            offerPanel.btnBuy:setTooltip(priceTooltip)
        end

        local itemCount = (offer.count and offer.count > 0) and offer.count or 1
        if itemCount > 1 then
            offerPanel:getChildById('btnBuy'):setText("Buy " .. itemCount .. "x")
        end

        if product.configurable then
            offerPanel:getChildById('btnBuy'):setText("Configurable")
        end

        local isTransferable = offer.coinType == GameStore.CoinType.Transferable
        local currentBalance = getOfferBalance(offer.coinType)

        if isTransferable then
            priceLabel:setIcon("/game_store/images/icon-tibiacointransferable")
        else
            priceLabel:setIcon("/game_store/images/icon-tibiacoin")
        end

        if currentBalance < offer.price then
            priceLabel:setColor("#d33c3c")
            offerPanel:getChildById('btnBuy'):disable()
        else
            priceLabel:setColor("white")
            offerPanel:getChildById('btnBuy'):enable()
        end

        if offer.disabled then
            local btnBuy = offerPanel:getChildById('btnBuy')
            btnBuy:disable()
            btnBuy:setOpacity(0.8)
            focusedChild.descriptionError =
                "The product is currently not available for this character. See the buy button tooltip for details."
            renderDescription(panel, description, focusedChild.descriptionError)
            if offer.reasonIdDisable then
                local tooltipOverlay = g_ui.createWidget('UIWidget', offerPanel)
                tooltipOverlay:setId('tooltipOverlay')
                tooltipOverlay:setFocusable(false)
                tooltipOverlay:setSize(btnBuy:getSize())
                tooltipOverlay:setPosition(btnBuy:getPosition())
                local reasonText = (oldProtocol and offer.reasonIdDisable or reasonCategory[offer.reasonIdDisable + 1]) or "This offer is unavailable."
                tooltipOverlay:parseColoreDisplayToolTip(string.format(
                    "[color=#ff0000]The product is not available for this character:\n\n- %s[/color]",
                    reasonText
                ))
                tooltipOverlay:setOpacity(0)
                tooltipOverlay:addAnchor(AnchorLeft, btnBuy:getId(), AnchorLeft)
                tooltipOverlay:addAnchor(AnchorTop, btnBuy:getId(), AnchorTop)
            end
        end

        offerPanel:getChildById('btnBuy').onClick = function(widget)
            if purchasePending then return end
            if acceptWindow then
                destroyWindow(acceptWindow)
            end

            if product.configurable or product.name == "Character Name Change" then
                configurationOffer = offer
                purchasePending = true
                g_game.buyStoreOffer(offer.id, GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_OTHER)
                return
            end

            local submitted = false
            local function acceptFunc()
                if submitted or purchasePending or not g_game.isOnline() then return end
                submitted = true
                fixServerNoSend0xF2()
                local latestCurrentBalance = getOfferBalance(offer.coinType)

                if latestCurrentBalance >= offer.price then
                    purchasePending = true
                    g_game.buyStoreOffer(offer.id, GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_OTHER)
                    local closeWindow = function() destroyWindow(processingWindow) end
                    controllerShop.ui:hide()
                    processingWindow = displayGeneralBox(
                        'Processing purchase.', 
                        'Your purchase is being processed',
                        {
                          { text = tr('ok'),  callback = closeWindow },
                          anchor = 50
                        }, 
                        closeWindow, 
                        closeWindow
                    )
                else
                    displayErrorBox(controllerShop.ui:getText(), tr("You don't have enough coins"))
                end
                destroyWindow(acceptWindow)
            end

            local function cancelFunc()
                destroyWindow(acceptWindow)
            end

            local itemCountConfirm = (offer.count and offer.count > 0) and offer.count or 1
            local productName = string.format('%dx %s', itemCountConfirm, product.name)
            local confirmationMessage = string.format('Do you want to buy the product "%s"?', productName)

            acceptWindow = g_ui.createWidget('StorePurchaseWindow', rootWidget)
            acceptWindow.content:setText(confirmationMessage)
            acceptWindow.details:setText(productName)
            acceptWindow.price:setText(string.format('Price: %s', formatNumberWithCommas(offer.price)))
            acceptWindow.coin:setImageSource(offer.coinType == GameStore.CoinType.Transferable and
                '/game_store/images/icon-tibiacointransferable' or '/game_store/images/icon-tibiacoin')
            local window = acceptWindow
            local function resizeConfirmation()
                window.detailsPanel:setHeight(math.max(80, window.details:getHeight() + 65))
                window:setHeight(math.max(235, window.content:getHeight() + window.details:getHeight() + 190))
            end
            window.content.onGeometryChange = resizeConfirmation
            window.details.onGeometryChange = resizeConfirmation
            resizeConfirmation()
            acceptWindow.buy.onClick = acceptFunc
            acceptWindow.cancel.onClick = cancelFunc
            acceptWindow.onEnter = acceptFunc
            acceptWindow.onEscape = cancelFunc
            if data then
                createProductImage(acceptWindow.Box, data)
            end
        end
    end
end


-- /*=============================================
-- =            Home                             =
-- =============================================*/

function chooseHome(self, focusedChild)
    if not focusedChild then
        return
    end
    local product = focusedChild.product
    local panel = controllerShop.ui.HomePanel.HomeRecentlyAdded.HomeProductos
    g_game.sendRequestStoreOfferById(product.id)
end

function changeImagenHome(direction)
    stopBanner()
    local home = controllerShop.ui.HomePanel
    local count = #bannersHome
    home.brand:setVisible(count == 0)
    home.prevImagen:setVisible(count > 1)
    home.nextImagen:setVisible(count > 1)
    if count == 0 then
        home.HomeImagen.storeImage = nil
        home.HomeImagen:setImageSource('')
        return
    end
    if direction == 'nextImagen' then
        currentIndex = currentIndex % count + 1
    elseif direction == 'prevImagen' then
        currentIndex = (currentIndex - 2) % count + 1
    end
    setImagenHttp(home.HomeImagen, bannersHome[currentIndex].image, false, true)
    if count > 1 and not bannerHovered and controllerShop.ui:isVisible() and home:isVisible() then
        bannerEvent = scheduleEvent(function() changeImagenHome('nextImagen') end, bannerDelay)
    end
end

function setBannerHover(hovered)
    bannerHovered = hovered
    if hovered then
        stopBanner()
    else
        changeImagenHome()
    end
end

function openBanner()
    local banner = bannersHome[currentIndex]
    if banner and banner.offerId and banner.offerId > 0 then
        g_game.sendRequestStoreOfferById(banner.offerId)
    end
end

-- /*=============================================
-- =            Behavior  Change Name            =
-- =============================================*/

function onStoreRequestPurchaseData(offerId, productType)
    purchasePending = false
    local offer = configurationOffer
    if not offer or offer.id ~= offerId then return end
    if productType ~= GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_NAMECHANGE and
        productType ~= GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_HIRELING then
        configurationOffer = nil
        return displayErrorBox('Store', 'This offer cannot be configured by this client.')
    end
    destroyWindow(changeNameWindow)
    local hireling = productType == GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_HIRELING
    changeNameWindow = g_ui.displayUI(hireling and 'style/hireling' or 'style/changename')
    local window = changeNameWindow
    if hireling then
        window.sex:addOption('Male', 1)
        window.sex:addOption('Female', 2)
    end
    window.buttonOk:setTooltip(string.format('Price: %s %s', formatNumberWithCommas(offer.price),
        offer.coinType == GameStore.CoinType.Transferable and 'transferable coins' or 'coins'))
    window.buttonOk:setEnabled(false)
    local field = window.transferPointsText
    field.onTextChange = function()
        window.buttonOk:setEnabled(#field:getText():trim() >= 3)
    end
    local function cancel()
        configurationOffer = nil
        destroyWindow(window)
    end
    local function submit()
        if purchasePending or window:isDestroyed() then return end
        local name = field:getText():trim()
        if #name < 3 then return end
        if getOfferBalance(offer.coinType) < offer.price then
            return displayErrorBox('Store', "You don't have enough coins")
        end
        purchasePending = true
        local sex = hireling and window.sex:getCurrentOption().data or 0
        g_game.buyStoreOffer(offer.id, productType, name, sex)
        destroyWindow(window)
    end
    window.closeButton.onClick = cancel
    window.buttonOk.onClick = submit
    window.onEscape = cancel
    window.onEnter = submit
    window:show()
    window:raise()
    window:focus()
    field:focus()
end

-- /*=============================================
-- =            Button TransferPoints            =
-- =============================================*/

function transferPoints()
    destroyWindow(transferPointsWindow)
    transferPointsWindow = g_ui.displayUI('style/transferpoints')
    transferPointsWindow:show()

    local playerBalance = g_game.getLocalPlayer():getResourceBalance(ResourceTypes.COIN_TRANSFERRABLE)
    fixServerNoSend0xF2()

    local normalCoins, transferableCoins = getCoinsBalance()

    if playerBalance == 0 then
        playerBalance = transferableCoins -- temp fix canary 1340
    end

    transferPointsWindow.giftable:setText(formatNumberWithCommas(playerBalance))
    local balanceWidth = transferPointsWindow.transferableAmount:getTextSize().width +
        transferPointsWindow.giftable:getTextSize().width + 60
    transferPointsWindow:setWidth(math.max(transferPointsWindow:getWidth(), balanceWidth))

    local initialValue, minimumValue = 0, 0
    if playerBalance >= 25 then
        initialValue = 25
        minimumValue = 25
    end

    transferPointsWindow.amountBar:setStep(25)
    transferPointsWindow.amountBar:setMinimum(minimumValue)
    local maxStep = math.floor(playerBalance / 25) * 25 -- coins multiple 25
    transferPointsWindow.amountBar:setMaximum(maxStep)
    transferPointsWindow.amountBar:setValue(initialValue)
    transferPointsWindow.amount:setText(formatNumberWithCommas(initialValue))

    local sliderButton = transferPointsWindow.amountBar:getChildById('sliderButton')
    if sliderButton then
        sliderButton:setEnabled(true)
        sliderButton:setVisible(true)
    end

    transferPointsWindow.onEscape = function()
        destroyWindow(transferPointsWindow)
    end

    local lastDisplayedValue = initialValue
    transferPointsWindow.amountBar.onValueChange = function(scrollbar, value)
        local val = math.floor((value + 12) / 25) * 25
        if scrollbar:getValue() ~= val then
            scrollbar:setValue(val)
            return
        end

        if val ~= lastDisplayedValue then
            lastDisplayedValue = val
            transferPointsWindow.amount:setText(formatNumberWithCommas(val))
        end
    end

    transferPointsWindow.closeButton.onClick = function()
        destroyWindow(transferPointsWindow)
    end

    transferPointsWindow.buttonOk.onClick = function()
        local receipient = transferPointsWindow.transferPointsText:getText():trim()
        local amount = transferPointsWindow.amountBar:getValue()

        if receipient:len() < 3 then
            return
        end
        if amount < 1 or playerBalance < amount then
            return
        end

        g_game.transferCoins(receipient, amount)
        destroyWindow(transferPointsWindow)
    end
end




-- /*=============================================
-- =            Search Button            =
-- =============================================*/

function updateSearch()
    controllerShop.ui.SearchClearButton:setEnabled(#controllerShop.ui.SearchEdit:getText():trim() >= 3)
end

function search()
    if #controllerShop.ui.SearchEdit:getText():trim() < 3 then return end
    if  controllerShop.ui.openedCategory ~= nil then
        close(controllerShop.ui.openedCategory)
    end
    g_game.sendRequestStoreSearch(controllerShop.ui.SearchEdit:getText(), 0, 1)
end
