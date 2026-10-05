-- Shop tab logic — methods added to TaskBoardController
local confirmBox = nil

--  Server data handler 

function TaskBoardController:onShopData(items)
    local parsed = {}
    for _, raw in ipairs(items or {}) do
        table.insert(parsed, self:parseShopItem(raw))
    end
    -- The packet only keeps "bought" from the offer state, so the "requires the base outfit" state
    -- is rebuilt here with the server's rule: an addon needs the base offer of the same outfit.
    local baseBought = {}
    for _, item in ipairs(parsed) do
        if item.isOutfit and (item.lookAddons or 0) == 0 then
            baseBought[item.lookType] = item.bought
        end
    end
    for _, item in ipairs(parsed) do
        item.requiresBase = item.isOutfit and (item.lookAddons or 0) > 0 and baseBought[item.lookType] == false
        self:refreshShopItemState(item)
    end
    self.shopItems = parsed
end

-- Official 15.33 texts: taskboard_shop_tooltip_requires_base_outfit, _cannot_afford, _already_owned
-- (the official apostrophe is a typographic one the bitmap fonts do not have).
function TaskBoardController:refreshShopItemState(item)
    item.canBuy = item.canAfford and not item.requiresBase
    if item.requiresBase then
        item.buyTooltip = tr('Requires the base outfit.')
    elseif not item.canAfford then
        item.buyTooltip = tr("You don't have enough Hunting Task Points.")
    else
        item.buyTooltip = ''
    end
end

function TaskBoardController:onShopResult(itemId, result)
    if result == 0 then
        -- Success — server will send updated shop data
        return
    end
    local errorMessages = {
        [SHOP_ERR_NOT_FOUND] = "Item not found.",
        [SHOP_ERR_ALREADY_BOUGHT] = "Already purchased.",
        [SHOP_ERR_NO_POINTS] = "Not enough Hunting Task Points.",
        [SHOP_ERR_NEED_BASE] = "You need the base outfit first.",
        [SHOP_ERR_STORE_INBOX] = "Store inbox error."
    }
    local msg = errorMessages[result] or ("Purchase failed (code " .. result .. ").")
    local errBox
    local function close()
        if errBox then
            errBox:destroy();
            errBox = nil
        end
    end
    errBox = displayGeneralBox(tr('Purchase Failed'), msg, {{
        text = tr('Ok'),
        callback = close
    }}, close, close)
end

--  Actions 

-- Official 15.33 purchase dialog (template/otui/shop_confirm.otui): caption "Confirm" and
-- 'Would you like to buy "%1" for %2<points icon>?'. Labels only draw text, so the sentence keeps
-- blank room after the price and the points icon is laid over it; like the official nowrap span,
-- the price goes to the next line with the icon when the whole sentence does not fit.
local function displayShopPurchaseConfirmation(item, yes, cancel)
    local window = g_ui.displayUI('/game_taskboard/template/otui/shop_confirm')
    local preview = window:getChildById('previewBox')
    if item.previewType == 'creature' then
        local creature = preview:getChildById('creature')
        creature:setOutfit({
            type = item.lookType, head = item.lookHead or 0, body = item.lookBody or 0, legs = item.lookLegs or 0,
            feet = item.lookFeet or 0, addons = item.lookAddons or 0, mount = item.lookMount or 0
        })
        creature:show()
    elseif item.previewType == 'item' then
        local widget = preview:getChildById('item')
        widget:setItemId(item.itemId)
        widget:show()
    elseif item.previewType == 'icon' then
        local icon = preview:getChildById('icon')
        icon:setImageSource(item.imageSource)
        icon:show()
    end

    local message = window:getChildById('message')
    local width = window:getWidth() - window:getPaddingLeft() - window:getPaddingRight()
    local probe = g_ui.createWidget('Label', rootWidget)
    local function measure(text)
        probe:setText(text)
        probe:resizeToText()
        return probe:getWidth(), probe:getHeight()
    end
    -- Word wrap done here so that, like the official nowrap span, the price, the icon room and
    -- the question mark always stay on one line; the icon then sits on the last line.
    local spaceWidth = math.max(1, measure('a a') - measure('aa'))
    local iconGap = 1
    local tail = comma_value(item.price) .. string.rep(' ', math.ceil((iconGap + 11) / spaceWidth)) .. '?'
    local words = {}
    for word in string.format('Would you like to buy "%s" for', item.title):gmatch('%S+') do
        table.insert(words, word)
    end
    table.insert(words, tail)
    local lines, current = {}, nil
    for _, word in ipairs(words) do
        local candidate = current and (current .. ' ' .. word) or word
        if current and measure(candidate) > width then
            table.insert(lines, current)
            current = word
        else
            current = candidate
        end
    end
    table.insert(lines, current)
    local lastLine = lines[#lines]
    local iconLeft = measure(lastLine:sub(1, #lastLine - #tail) .. comma_value(item.price))
    local _, lineHeight = measure('A')
    probe:destroy()

    message:setTextWrap(false)
    message:setWidth(width)
    message:setText(table.concat(lines, string.char(10)))
    local pointsIcon = message:getChildById('pointsIcon')
    pointsIcon:setMarginLeft(iconLeft + iconGap)
    pointsIcon:setMarginTop((#lines - 1) * lineHeight + math.floor((lineHeight - pointsIcon:getHeight()) / 2))

    -- 80 px preview row + sentence + separator + buttons
    window:setHeight(window:getPaddingTop() + 80 + message:getHeight() + 10 + 2 + 10 + 20 +
                         window:getPaddingBottom())

    window:getChildById('buyButton').onClick = yes
    window:getChildById('cancelButton').onClick = cancel
    window.onEnter = yes
    window.onEscape = cancel
    window:raise()
    window:focus()
    return window
end

function TaskBoardController:buyItem(itemId)
    local item = nil
    local itemIndex = nil
    for index, it in ipairs(self.shopItems or {}) do
        if it.id == tonumber(itemId) then
            item = it
            itemIndex = index
            break
        end
    end
    if not item then
        return
    end
    local function yes()
        g_game.taskHuntingShopPurchase(item.id)
        if confirmBox then
            confirmBox:destroy();
            confirmBox = nil
        end
    end
    local function cancel()
        if confirmBox then
            confirmBox:destroy();
            confirmBox = nil
        end
    end
    confirmBox = displayShopPurchaseConfirmation(item, yes, cancel)
end

function TaskBoardController:updateShopBalance(balance)
    balance = tonumber(balance) or 0
    self.shopBalance = balance
    -- shopItems canAfford field needs to be updated
    for i, item in ipairs(self.shopItems or {}) do
        self.shopItems[i].canAfford = balance >= item.price
        self:refreshShopItemState(self.shopItems[i])
    end
    self.shopItems = self.shopItems
end

--  Item parser 

function TaskBoardController:parseShopItem(raw)
    local offerType = tonumber(raw.offerType) or SHOP_OFFER_TYPE_ITEM
    local data = {
        id = tonumber(raw.id) or 0,
        title = raw.title or "",
        description = raw.description or "",
        price = tonumber(raw.price) or 0,
        bought = (tonumber(raw.bought) or 0) == 1,
        offerType = offerType,
        backdrop = SHOP_BACKDROP_IMAGES[offerType] or SHOP_BACKDROP_IMAGES[SHOP_OFFER_TYPE_ITEM],
        canAfford = false,
        lookMount = 0,
        previewType = nil
    }

    if offerType == SHOP_OFFER_TYPE_OUTFIT then
        local parsedLookType = tonumber(raw.lookType) or 0
        if parsedLookType > 0 then
            data.lookType = parsedLookType
        else
            g_logger.warning(string.format("[TaskBoard][Shop] Outfit without lookType (id=%s, title=%s)",
                tostring(data.id), tostring(data.title)))
        end
        data.lookHead = tonumber(raw.lookHead) or 0
        data.lookBody = tonumber(raw.lookBody) or 0
        data.lookLegs = tonumber(raw.lookLegs) or 0
        data.lookFeet = tonumber(raw.lookFeet) or 0
        data.lookAddons = tonumber(raw.lookAddons) or 0
        data.lookMount = 0
        data.isOutfit = parsedLookType > 0
        data.isCreaturePreview = data.isOutfit
        data.previewType = data.isCreaturePreview and 'creature' or nil
    elseif offerType == SHOP_OFFER_TYPE_MOUNT then
        local parsedMountType = tonumber(raw.lookType) or 0
        if parsedMountType > 0 then
            data.lookMount = parsedMountType
        else
            g_logger.warning(string.format("[TaskBoard][Shop] Mount without lookType (id=%s, title=%s)",
                tostring(data.id), tostring(data.title)))
        end
        -- The mount is drawn on its own, as in the official shop: a rider on top made the preview
        -- show the citizen with only the mount's legs below it.
        data.lookType = parsedMountType
        data.lookMount = 0
        data.lookHead = 0
        data.lookBody = 0
        data.lookLegs = 0
        data.lookFeet = 0
        data.lookAddons = 0
        data.isMount = parsedMountType > 0
        data.isCreaturePreview = data.isMount
        data.previewType = data.isCreaturePreview and 'creature' or nil
    elseif offerType == SHOP_OFFER_TYPE_ITEM or offerType == SHOP_OFFER_TYPE_ITEM_DOUBLE then
        data.itemId = tonumber(raw.itemId) or 0
        data.lookMount = 0
        data.isItem = (data.itemId > 0)
        data.previewType = data.isItem and 'item' or nil
    elseif offerType == SHOP_OFFER_TYPE_BONUS_PROMOTION then
        local defaults = SHOP_BONUS_DEFAULTS[SHOP_OFFER_TYPE_BONUS_PROMOTION] or {}
        data.title = defaults.title or data.title
        data.description = defaults.description or data.description
        data.imageSource = defaults.image or ""
        data.maxPurchases = tonumber(raw.maxPurchases) or 0
        data.currentPurchases = tonumber(raw.currentPurchases) or 0
        data.nextCost = tonumber(raw.nextCost) or 0
        data.price = data.nextCost
        data.description = string.format(data.description, data.currentPurchases)
        data.lookMount = 0
        data.isBonus = true
        data.previewType = 'icon'
    end

    local balance = tonumber(self.shopBalance)
    if not balance or balance <= 0 then
        local player = g_game.getLocalPlayer()
        balance = player and player:getResourceBalance(ResourceTypes.TASK_HUNTING) or balance or 0
    end

    data.canAfford = balance >= data.price
    data.displayPrice = comma_value(data.price)

    return data
end
