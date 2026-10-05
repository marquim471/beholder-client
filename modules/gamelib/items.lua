-- to-do
-- change to ItemsDatabase.setTier(UIitem) to UIitem:setTier()
ItemsDatabase = {}

ItemsDatabase.rarityColors = {
    ["yellow"] = TextColors.yellow,
    ["purple"] = TextColors.purple,
    ["blue"] = TextColors.blue,
    ["green"] = TextColors.green,
    ["grey"] = TextColors.grey,
}

local function getColorForValue(value)
    if value >= 1000000 then
        return "yellow"
    elseif value >= 100000 then
        return "purple"
    elseif value >= 10000 then
        return "blue"
    elseif value >= 1000 then
        return "green"
    elseif value >= 50 then
        return "grey"
    else
        return "white"
    end
end

local function clipfunction(value)
    if value >= 1000000 then
        return "128 0 32 32"
    elseif value >= 100000 then
        return "96 0 32 32"
    elseif value >= 10000 then
        return "64 0 32 32"
    elseif value >= 1000 then
        return "32 0 32 32"
    elseif value >= 50 then
        return "0 0 32 32"
    end
    return ""
end

function ItemsDatabase.getClipAndImagePath(item)
    if not item then
        return nil, nil, nil
    end

    local frameOption = modules.client_options.getOption('framesRarity')
    if frameOption == "none" then
        return nil, nil, nil
    end
    local imagePath = '/images/ui/item'
    local clip = nil

    if type(item) == "number" then
        item = g_things.getThingType(item, ThingCategoryItem)
    end

    if not item then
        return nil, nil, nil
    end

    if item then
        local price = type(item) == "number" and item or (item and item:getMeanPrice()) or 0
        local itemRarity = getColorForValue(price)
        if itemRarity then
            clip = clipfunction(price)
            if clip ~= "" then
                if frameOption == "frames" then
                    imagePath = "/images/ui/rarity_frames"
                elseif frameOption == "corners" then
                    imagePath = "/images/ui/containerslot-coloredges"
                end
            else
                clip = nil
            end
        end
    end

    local clipObject = nil
    if clip then
        local x, y, w, h = clip:match("(%d+) (%d+) (%d+) (%d+)")
        clipObject = { x = tonumber(x), y = tonumber(y), width = tonumber(w), height = tonumber(h) }
    end

    return clip, imagePath, clipObject
end

local rarityCornerOverlayId = 'rarityCornerOverlay'

local function rememberRarityBackground(widget)
    if widget.rarityBackgroundStored then
        return
    end

    widget.rarityBackgroundStored = true
    widget.rarityBackgroundSource = widget:getImageSource()
    widget.rarityBackgroundClip = widget:getImageClip()
end

local function restoreRarityBackground(widget)
    if not widget.rarityBackgroundStored then
        return
    end

    widget:setImageSource(widget.rarityBackgroundSource or '')
    widget:setImageClip(widget.rarityBackgroundClip)
    widget.rarityBackgroundStored = nil
    widget.rarityBackgroundSource = nil
    widget.rarityBackgroundClip = nil
end

local function removeRarityCorner(widget)
    local overlay = widget:getChildById(rarityCornerOverlayId)
    if overlay then
        overlay:destroy()
    end
end

function ItemsDatabase.setRarityItem(widget, item, style)
    if not g_game.getFeature(GameColorizedLootValue) or not widget then
        return
    end

    local clip, imagePath = ItemsDatabase.getClipAndImagePath(item)

    if not clip or not imagePath then
        removeRarityCorner(widget)
        restoreRarityBackground(widget)
        return
    end

    if style then
        widget:setStyle(style)
    end

    rememberRarityBackground(widget)

    if imagePath == '/images/ui/containerslot-coloredges' then
        if widget:getImageSource() == '/images/ui/rarity_frames' then
            widget:setImageSource(widget.rarityBackgroundSource or '')
            widget:setImageClip(widget.rarityBackgroundClip)
        end

        local overlay = widget:getChildById(rarityCornerOverlayId)
        if not overlay then
            overlay = g_ui.createWidget('UIWidget', widget)
            overlay:setId(rarityCornerOverlayId)
            overlay:setPhantom(true)
            overlay:setSize({ width = 32, height = 32 })
            overlay:addAnchor(AnchorTop, 'parent', AnchorTop)
            overlay:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        end
        overlay:setImageSource(imagePath)
        overlay:setImageClip(clip)
        overlay:raise()
        return
    end

    removeRarityCorner(widget)
    widget:setImageClip(clip)
    widget:setImageSource(imagePath)
end
function ItemsDatabase.getColorForRarity(rarity)
    return ItemsDatabase.rarityColors[rarity] or TextColors.white
end

function ItemsDatabase.setColorLootMessage(text)
    local function coloringLootName(match)
        local id, itemName = match:match("(%d+)|(.+)")
        if not id or not itemName then
            -- If pattern doesn't match itemId|itemName format, return the original match with braces
            return "{" .. match .. "}"
        end

        local itemId = tonumber(id)
        if not itemId then
            return itemName or match
        end

        local thingType = g_things.getThingType(itemId, ThingCategoryItem)
        if not thingType then
            return itemName
        end

        local itemInfo = thingType:getMeanPrice()
        if itemInfo then
            local color = ItemsDatabase.getColorForRarity(getColorForValue(itemInfo))
            return "{" .. itemName .. ", " .. color .. "}"
        else
            return itemName
        end
    end
    return text:gsub("{(.-)}", coloringLootName)
end

function ItemsDatabase.getTierClip(tier, isSmall)
    local width = isSmall == false and 18 or 9
    local height = isSmall == false and 16 or 8
    local xOffset = (math.min(math.max(tier, 1), 10) - 1) * width
    return {
        x = xOffset,
        y = 0,
        width = width,
        height = height
    }
end

function ItemsDatabase.setTier(widget, item, isSmall)
    if not g_game.getFeature(GameThingUpgradeClassification) or not widget or not widget.tier then
        return
    end
    if isSmall == nil then
        isSmall = true
    end
    local tier = type(item) == "number" and item or (item and item:getTier()) or 0
    if tier <= 0 then
        widget.tier:setVisible(false)
        return
    end
    local config
    if isSmall then
        local normalizedTier = math.min(math.max(tier, 1), 10)
        config = {
            xOffset = (normalizedTier - 1) * 9,
            width = 9,
            height = 8,
            size = "9 8",
            source = '/images/inventory/tiers-strip'
        }
    else
        local normalizedTier = math.min(math.max(tier, 1), 18)
        local xOffset = (normalizedTier - 1) * 18 + 1
        config = {
            xOffset = xOffset,
            width = 18,
            height = 16,
            size = "18 16",
            source = '/images/inventory/tiers-strip-big'
        }
    end

    widget.tier:setImageClip({
        x = config.xOffset,
        y = 0,
        width = config.width,
        height = config.height
    })
    widget.tier:setSize(config.size)
    widget.tier:setImageSource(config.source)
    widget.tier:setImageSize(config.size)
    widget.tier:setVisible(true)
end


