rewardWallController = Controller:new()
-- /*=============================================
-- =            To-do                  =
-- =============================================*/
-- - otui -> html/css (g_ui.displayUI)
-- - Improve Ids footerGold2 , footerGold1, "test", "displayGeneralBox3"

local ServerPackets = {
    ShowDialog = 0xED,
    DailyRewardCollectionState = 0xDE,
    OpenRewardWall = 0xE2,
    CloseRewardWall = 0xE3,
    DailyRewardBasic = 0xE4,
    DailyRewardHistory = 0xE5
    -- RestingAreaState = 0xA9
}

local ClientPackets = {
    OpenRewardWall = 0xD8,
    OpenRewardHistory = 0xD9,
    SelectReward = 0xDA,
    CollectionResource = 0x14,
    JokerResource = 0x15
}

-- @ widget
local ButtonRewardWall = nil
local windowsPickWindow = nil
local generalBox = nil
-- @ array
local bonuses = {}
local actualUsed = {}
-- @ variable
local bonusShrine = 0
-- @ const
local COLORS = {
    BASE_1 = "#484848",
    BASE_2 = "#414141"
}
local ZONE = {
    RESTING_AREA_ZONE = 1,
    ICON_ID = "condition_Rewards",
    NUMERIC_ICON_ID = 30
}

local bundleType = {
    ITEMS = 1,
    PREY = 2,
    XPBOOST = 3
}

local STATUS = {
    COLLECTED = 1,
    ACTIVE = 2,
    LOCKED = 3,
    COOLDOWN = 4
}

local OPEN_WINDOWS = {
    BUTTON_WIDGET = 0,
    SHRINE = 1 -- itemClientId = 25802
}

local DailyRewardStatus = { -- sendDailyRewardCollectionState 0xDE ?
    DAILY_REWARD_COLLECTED = 0,
    DAILY_REWARD_NOTCOLLECTED = 1,
    DAILY_REWARD_NOTAVAILABLE = 2
}

local CONST_WINDOWS_BOX = {
    ALREADY = 1,
    RELEASE = 2,
    CONFIRMATION_IRA = 3, -- IRA = Instant Reward Access
    NO_IRA = 4
}

local BOX_CONFIGS = {
    [CONST_WINDOWS_BOX.ALREADY] = {
        title = "Warning",
        content = "Sorry, you have already taken your daily reward or you are unable to collect it"
    },
    [CONST_WINDOWS_BOX.CONFIRMATION_IRA] = {
        title = "Confirmation of using Instant Reward Access",
        content = "Remember! You can always collect your daily reward for free by visiting a reward shrine!\n\nYou Currently own 3x Instant Reward Access. Do you really want to use one to claim your daily reward now?",
        okCallback = function()
            -- Canary expects 0 = shrine / 1 = panel (inverse of the OpenRewardWall byte
            -- stored in bonusShrine, where 1 = shrine / 0 = panel)
            g_game.requestGetRewardDaily(bonusShrine == OPEN_WINDOWS.SHRINE and 0 or 1, actualUsed)
            if windowsPickWindow then
                windowsPickWindow:destroy()
                windowsPickWindow = nil
            end
            if generalBox then
                generalBox:destroy()
                generalBox = nil
            end
            show()
        end
    },
    [CONST_WINDOWS_BOX.NO_IRA] = {
        title = "Warning: No Sufficient Instant Reward Access",
        content = "Remember! you can always collect your daily reward for free by visiting a reward shrine!\nyou do not have an Instant Reward Access.\nVisit the store to buy more!"
    }
}

-- /*=============================================
-- =            Local function                  =
-- =============================================*/
local function destroyWindows(windows)
    if type(windows) == "table" then
        for _, window in pairs(windows) do
            if window and not window:isDestroyed() then
                window:destroy()
            end
        end
    else
        if windows and not windows:isDestroyed() then
            windows:destroy()
        end
    end
    return nil
end

function rewardWallController:updatePremiumStatus(isPremium)
    rewardWallController.ui.premiumStatus.premiumMessage:setText(isPremium and
                                                                     "Great! You benefit from the best possible rewards and bonuses due to your premium status." or
                                                                     "With a Premium account, you would benefit from even better rewards and bonuses.")
    rewardWallController.ui.premiumStatus.premiumButton:setOn(isPremium)
    rewardWallController.ui.premiumStatus.premiumButton:setEnabled(not isPremium)
    for _, name in ipairs({'free', 'premium'}) do
        local active = (name == 'premium') == isPremium
        local column = rewardWallController.ui.infoPanel[name]
        column.heading:setColor(active and '#c0c0c0' or '#707070')
        column.details:setColor(active and '#c0c0c0' or '#707070')
    end
    if isPremium then
        for i, widget in pairs(rewardWallController.ui.restingAreaPanel.bonusIcons:getChildren()) do
            if widget then
                widget:setOn(true)
            end
        end
    end
end

local function convert_timestamp(timestamp)
    return os.date("%Y-%m-%d, %H:%M:%S", timestamp)
end

local function getBonusStrings(bonuses)
    local result = {}
    for _, bonus in ipairs(bonuses) do
        table.insert(result, bonus["name"])
    end
    return table.concat(result, ", ")
end

local function visibleHistory(bool)
    for i, widget in ipairs(rewardWallController.ui:getChildren()) do
        if widget:getId() == "historyPanel" then
            widget:setVisible(bool)
        else
            widget:setVisible(not bool)
        end
        if i == 5 then -- foot
            break
        end
    end
end

local function updateDailyRewards(dayStreakDay, wasDailyRewardTaken)
    rewardWallController.rewardTimer = nil
    local dailyRewardsPanel = rewardWallController.ui.dailyRewardsPanel.content.rewards
    for i = 1, 7 do
        local rewardWidget = dailyRewardsPanel:getChildById("reward" .. i)
        rewardWidget:getChildById("rewardGold" .. i):destroyChildren()
        local arrow = dailyRewardsPanel:getChildById("arrow" .. i)
        if arrow then
            arrow:setImageClip("0 0 5 7")
        end
    end
    for i = 1, dayStreakDay do
        local rewardWidget = dailyRewardsPanel:getChildById("reward" .. i)
        local rewardArrow = dailyRewardsPanel:getChildById("arrow" .. i)
        if rewardWidget then
            local test = g_ui.createWidget("RewardButton", rewardWidget:getChildById("rewardGold" .. i))
            test:setOn(true)
            test:fill("parent")
            test:setPhantom(true)
            if rewardArrow then
                rewardArrow:setImageClip("5 0 5 7")
            end
            rewardWidget:getChildById("rewardButton" .. i):setOn(true)
            rewardWidget:getChildById("rewardButton" .. i).ditherpattern:setVisible(true)
            rewardWidget:getChildById("rewardGold" .. i).status = 1
        end
    end

    local currentReward = dailyRewardsPanel:getChildById("reward" .. dayStreakDay + 1)
    if currentReward then
        local status = currentReward:getChildById("rewardGold" .. dayStreakDay + 1)
        if wasDailyRewardTaken == 1 then
            local timer = g_ui.createWidget('RewardWallTimer', status)
            timer:fill('parent')
            timer:setPhantom(true)
            status.status = STATUS.COOLDOWN
            rewardWallController.rewardTimer = timer
        else
            local price = g_ui.createWidget('GoldLabel2', status)
            price:fill('parent')
            price:setPhantom(true)
            price.gold:setImageSource('/game_rewardwall/images/instant-reward-access-icon')
            price.text:setText(bonusShrine == OPEN_WINDOWS.SHRINE and '0' or '1')
            local balance = g_game.getLocalPlayer():getResourceBalance(ResourceTypes.DAILYREWARD_STREAK)
            price.text:setColor((bonusShrine == OPEN_WINDOWS.SHRINE or balance >= 1) and '#c0c0c0' or '#d33c3c')
            status.status = STATUS.ACTIVE
        end
        currentReward:setOn(false)
        currentReward:getChildById("rewardButton" .. dayStreakDay + 1).ditherpattern:setVisible(false)
        currentReward:getChildById("rewardButton" .. dayStreakDay + 1):setOn(wasDailyRewardTaken == 1)
    end

    for i = dayStreakDay + 2, 7 do
        local rewardWidget = dailyRewardsPanel:getChildById("reward" .. i)
        if rewardWidget then
            local test = g_ui.createWidget("RewardButton", rewardWidget:getChildById("rewardGold" .. i))
            test:setOn(false)
            test:fill("parent")
            test:setPhantom(true)
            rewardWidget:getChildById("rewardButton" .. i):setOn(true)
            rewardWidget:getChildById("rewardButton" .. i).ditherpattern:setVisible(true)
            rewardWidget:getChildById("rewardGold" .. i).status = 3
        end
    end
end

local function getDayStreakIcon(dayStreakLevel)
    local IconConsecutiveDays = {
        [24] = "icon-rewardstreak-default",
        [49] = "icon-rewardstreak-bronze",
        [99] = "icon-rewardstreak-silver",
        [100] = "icon-rewardstreak-gold"
    }
    if dayStreakLevel <= 24 then
        return IconConsecutiveDays[24]
    elseif dayStreakLevel <= 49 then
        return IconConsecutiveDays[49]
    elseif dayStreakLevel <= 99 then
        return IconConsecutiveDays[99]
    else
        return IconConsecutiveDays[100]
    end
end

local function getBonusDescription(bonusName, streakCount, activeBonuses)
    local isPremium = g_game.getLocalPlayer():isPremium()

    return string.format(
        "Allow [color=#909090]%s[/color]%s\nThis bonus is active because you are [color=%s]Premium[/color] and reached a reward streak of at least [color=#44AD25]%d[/color].%s",
        bonusName, isPremium and "" or "[color=#ff0000](Locked)[/color]", isPremium and "#44AD25" or "#ff0000",
        streakCount, isPremium and ("\n\nActive bonuses: [color=#909090]%s[/color]."):format(activeBonuses) or "")
end

local function checkRewards(data)
    local premium = g_game.getLocalPlayer():isPremium()
    local rewardType = premium and data.premiumRewards or data.freeRewards
    local altType = premium and data.freeRewards or data.premiumRewards

    for index = 1, #rewardType do
        local reward = rewardType[index]
        local altReward = altType[index]

        local hasSelectableItems = reward.selectableItems and next(reward.selectableItems) ~= nil
        local rewardButton = rewardWallController.ui.dailyRewardsPanel.content.rewards:getChildById("reward" .. index):getChildById(
            "rewardButton" .. index)
        local iconWidget = rewardWallController.ui.dailyRewardsPanel.content.rewards:getChildById("reward" .. index):getChildByIndex(1)
        rewardButton.freeReward = data.freeRewards[index]
        rewardButton.premiumReward = data.premiumRewards[index]

        if hasSelectableItems then
            iconWidget:setIcon("game_rewardwall/images/icon-reward-pickitems")
            rewardButton.bundleType = bundleType.ITEMS
            rewardButton.rewardItem = reward.selectableItems
            rewardButton.itemsToSelect = {reward.itemsToSelect or 0, altReward and altReward.itemsToSelect or 0}
        elseif reward.bundleItems[1] and reward.bundleItems[1].bundleType == bundleType.XPBOOST then
            iconWidget:setIcon("game_rewardwall/images/icon-reward-xpboost")
            rewardButton.bundleType = bundleType.XPBOOST
            rewardButton.itemsToSelect = {reward.bundleItems[1].itemId or 0,
                                          altReward and altReward.bundleItems[1].itemId or 0}
        else
            iconWidget:setIcon("game_rewardwall/images/icon-reward-fixeditems")
            rewardButton.bundleType = bundleType.PREY
            rewardButton.itemsToSelect = {reward.bundleItems[1].count or 0,
                                          altReward and altReward.bundleItems[1].count or 0}
        end
        -- The picker and tooltips expect premium first, then free.
        if not premium then
            rewardButton.itemsToSelect[1], rewardButton.itemsToSelect[2] =
                rewardButton.itemsToSelect[2], rewardButton.itemsToSelect[1]
        end
    end
end
-- /*=============================================
-- =            onParse                  =
-- =============================================*/
--[[
--  0xDE ??
local function onDailyRewardCollectionState(state)
    if not rewardWallController.ui:isVisible() then
        return
    end

    local text = {
        [DailyRewardStatus.DAILY_REWARD_COLLECTED] = "you did not claim your daily reward in time. too bad, you do not have enough Daily Reward Jokers.",
        [DailyRewardStatus.DAILY_REWARD_NOTCOLLECTED] = "You did not claim your daily reward in time. If you don't claim your reward now, your [color=#D33C3C]streak will be reset.[/color]",
        [DailyRewardStatus.DAILY_REWARD_NOTAVAILABLE] ="idk",
    }
    rewardWallController.ui.restingAreaPanel.streakWarning:parseColoredText(text[state],"#c0c0c0")
end 
]]

local function onRestingAreaState(zone, state, message)
    local gameInterface = modules.game_interface
    if zone == ZONE.RESTING_AREA_ZONE then
        gameInterface.processIcon(ZONE.NUMERIC_ICON_ID, function(icon)
            local clip = Icons[ZONE.NUMERIC_ICON_ID].clip + (state == 1 and 1 or 0)
            icon:setImageClip(((clip - 1) * 9) .. ' 0 9 9')
            icon:setTooltip(message)
        end, true)
    else
        gameInterface.processIcon(ZONE.ICON_ID, function(icon)
            icon:destroy()
        end)
    end
end

local function onDailyReward(data)
    bonuses = data.bonuses
    checkRewards(data)
end

local function onServerError(code, error)
    generalBox = destroyWindows(generalBox)
    local cancelCallback = function()
        generalBox = destroyWindows(generalBox)
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end

    local standardButtons = {{
        text = "ok",
        callback = cancelCallback
    }}

    generalBox = displayGeneralBox3(rewardWallController.ui:getText(), error, standardButtons)
end

local function connectOnServerError()
    connect(g_game, {
        onServerError = onServerError
    })
end

local function disconnectOnServerError()
    disconnect(g_game, {
        onServerError = onServerError
    })
end

local function onOpenRewardWall(bonusShrines, nextRewardTime, dayStreakDay, wasDailyRewardTaken, errorMessage, tokens,
    timeLeft, dayStreakLevel)
    if bonusShrines == OPEN_WINDOWS.SHRINE then
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end
    bonusShrine = bonusShrines
    updateDailyRewards(dayStreakDay, wasDailyRewardTaken)
    rewardWallController.ui.restingAreaPanel.streakWarning:setText(
        wasDailyRewardTaken == 1 and "You already claimed your daily reward." or errorMessage)
    rewardWallController.ui.restingAreaPanel.restingAreaInfo.rewardStreakIcon:setText(dayStreakLevel)
    rewardWallController.rewardState = {
        nextRewardTime = nextRewardTime,
        streakDeadline = timeLeft,
        collected = wasDailyRewardTaken == 1,
        streakLevel = dayStreakLevel
    }
    rewardWallController:updateClocks()
    rewardWallController.ui.restingAreaPanel.restingAreaInfo.restingAreaGold.text:setText(0)
    rewardWallController.ui.footerPanel.footerGold1.text:setText(tokens)
    rewardWallController.ui.restingAreaPanel.restingAreaInfo.rewardStreakIcon:setImageSource(
        "/game_rewardwall/images/" .. getDayStreakIcon(dayStreakLevel))

    rewardWallController.ui.footerPanel.footerGold2.text:setText(
        g_game.getLocalPlayer():getResourceBalance(ResourceTypes.DAILYREWARD_STREAK))
end

local function onRewardHistory(rewardHistory)
    local transferHistory = rewardWallController.ui.historyPanel.historyList.List
    transferHistory:destroyChildren()

    local headerRow = g_ui.createWidget("historyData2", transferHistory)
    headerRow:setBackgroundColor("#363636")
    headerRow:setBorderColor("#00000077")
    headerRow:setBorderWidth(1)
    headerRow.date:setText("Date")
    headerRow.Balance:setText("Streak")
    headerRow.Description:setText("Event")

    for i, data in ipairs(rewardHistory) do
        local row = g_ui.createWidget("historyData2", transferHistory)
        row:setHeight(30)
        row.date:setText(convert_timestamp(data[1]))
        row.Balance:setText(data[4])
        row.Description:setText(data[3])
        row.Description:setTextWrap(true)
        row:setBackgroundColor(i % 2 == 0 and "#ffffff12" or "#00000012")
    end
end

-- /*=============================================
-- =            Windows                  =
-- =============================================*/
function show()
    if not rewardWallController.ui then
        return
    end
    g_game.sendOpenRewardWall()
    rewardWallController.ui:show()
    rewardWallController.ui:raise()
    rewardWallController.ui:focus()
    if ButtonRewardWall then
        ButtonRewardWall:setOn(true)
    end
    connectOnServerError()
    rewardWallController:updatePremiumStatus(g_game.getLocalPlayer():isPremium())
end

function hide(bool)
    if not rewardWallController.ui then
        return
    end
    rewardWallController:clearInfo()
    rewardWallController.ui:hide()
    if ButtonRewardWall then
        ButtonRewardWall:setOn(false)
    end
    if bool then
        disconnectOnServerError()
    end
end

function toggle()
    if not rewardWallController.ui then
        return
    end
    if rewardWallController.ui:isVisible() then
        return hide(true)
    end
    show()
end

local function fixCssIncompatibility() -- temp
    for _, frame in ipairs({rewardWallController.ui.historyPanel, rewardWallController.ui.restingAreaPanel,
                             rewardWallController.ui.dailyRewardsPanel}) do
        frame.caption:setText(frame:getText())
        frame:setText("")
    end
    rewardWallController.ui.historyPanel.historyList:fill('parent')

    local restingAreaGold = rewardWallController.ui.restingAreaPanel.restingAreaInfo.restingAreaGold
    restingAreaGold.text:setText('0')
    restingAreaGold.gold:setMarginRight(math.floor((66 - restingAreaGold.text:getTextSize().width - 11) / 2))
    rewardWallController.ui.footerPanel.footerGold2.gold:setImageSource('/game_rewardwall/images/instant-reward-access-icon')

end
-- /*=============================================
-- =            Controller                  =
-- =============================================*/
function rewardWallController:onInit()
    g_ui.importStyle("styles/style.otui")
    rewardWallController:loadHtml('game_rewardwall.html')
    rewardWallController.ui:hide()

    rewardWallController:registerEvents(g_game, {
        onOpenRewardWall = onOpenRewardWall,
        onDailyReward = onDailyReward,
        onRewardHistory = onRewardHistory,
        onRestingAreaState = onRestingAreaState
        -- onDailyRewardCollectionState
    })
    fixCssIncompatibility()
end

function rewardWallController:onTerminate()
    generalBox, windowsPickWindow, ButtonRewardWall = destroyWindows({generalBox, windowsPickWindow, ButtonRewardWall})
end

function rewardWallController:onGameStart()
    self:cycleEvent(function()
        if self.ui and self.ui:isVisible() then self:updateClocks() end
    end, 1000, 'rewardClock')
    if g_game.getClientVersion() > 1140 then -- Summer Update 2017
        if not ButtonRewardWall then
            ButtonRewardWall = modules.game_mainpanel.addToggleButton("rewardWall", tr("Open rewardWall"),
                "/images/options/rewardwall", toggle, false, 21)
        end
    else
        scheduleEvent(function()
            g_modules.getModule("game_rewardwall"):unload()
        end, 100)
    end
end

function rewardWallController:onGameEnd()
    self.rewardState = nil
    self.rewardTimer = nil
    self:clearInfo()
    if rewardWallController.ui:isVisible() then
        rewardWallController.ui:hide()
        ButtonRewardWall:setOn(false)
    end
    generalBox, windowsPickWindow = destroyWindows({generalBox, windowsPickWindow})
end
-- /*=============================================
-- =            Call css onClick                =
-- =============================================*/
function rewardWallController:onClickshowHistory()
    visibleHistory(not rewardWallController.ui.historyPanel:isVisible())
    if rewardWallController.ui.historyPanel:isVisible() then
        g_game.requestOpenRewardHistory()
    end
    rewardWallController.ui.footerPanel.historyButton:setText(
    rewardWallController.ui.historyPanel:isVisible() and "Back" or "History")
end

function rewardWallController:onClickToggle()
    toggle()
end

function rewardWallController:onClickSendStoreRewardWall()
    modules.game_store.toggle()
    g_game.sendRequestStorePremiumBoost()
end

function rewardWallController:onClickbuyInstantRewardAccess()
    modules.game_store.toggle()
    g_game.sendRequestUsefulThings(StoreConst.InstantRewardAccess)
end

function rewardWallController:onClickDisplayWindowsPickRewardWindow(event)
    if event.target:isOn() then
        return
    end

    if event.target.bundleType == bundleType.ITEMS then
        local isPremium = g_game.getLocalPlayer():isPremium()
        local itemsToSelect = event.target.itemsToSelect
        if not windowsPickWindow then
            if type(itemsToSelect) == "table" then
                itemsToSelect = isPremium and itemsToSelect[1] or itemsToSelect[2]
            else
                itemsToSelect = itemsToSelect or 1
            end
            windowsPickWindow = g_ui.displayUI('styles/pickreward')
            windowsPickWindow:show()
            windowsPickWindow:getChildById('capacity'):setText("Free capacity: " ..
                                                                   g_game:getLocalPlayer():getFreeCapacity() .. " oz")

            local text = string.format("You have selected [color=#D33C3C]0[/color] of %d reward items", itemsToSelect)
            windowsPickWindow:getChildById('rewardLabel'):parseColoredText(text, "#c0c0c0")

            for i, item in pairs(event.target.rewardItem) do
                local getItem = g_ui.createWidget('ItemReward', windowsPickWindow:getChildById('rewardList'))
                getItem:getChildById('item'):setItemId(item.itemId)
                getItem:getChildById('title'):setText(item.name)
                getItem:setBackgroundColor((i % 2 == 0) and COLORS.BASE_1 or COLORS.BASE_2)
                getItem.totalWeight = item.weight or 1
                getItem.itemsToSelect = itemsToSelect

            end
            actualUsed = {}
            hide()
        else
            windowsPickWindow:show()
            windowsPickWindow:raise()
            windowsPickWindow:focus()
        end

    elseif event.target.bundleType == bundleType.XPBOOST or event.target.bundleType == bundleType.PREY then
        hide()
        actualUsed = {}
        managerMessageBoxWindow(CONST_WINDOWS_BOX.CONFIRMATION_IRA)
    end
end

-- /*=============================================
-- =            Call onHover css                  =
-- =============================================*/

local function formatRewardTime(seconds)
    if seconds <= 0 then return 'Expired' end
    if seconds < 60 then return '< 1 min' end
    return string.format('%02d:%02d', math.floor(seconds / 3600), math.floor(seconds / 60) % 60)
end

local function updateRewardTimer(widget, seconds, icon)
    widget.caption:setText(icon and '' or formatRewardTime(seconds))
    widget.caption:setIcon(icon or '')
    widget.progress:setImageSource(icon and '/game_rewardwall/images/progressbar-grey-large' or
                                         '/game_rewardwall/images/progressbar-orange-large')
    local progress = icon and 1 or math.max(0, math.min(1, seconds / 86400))
    widget.progress:setWidth(math.floor((widget:getWidth() - 2) * progress))
end

function rewardWallController:updateClocks(now)
    if not self.rewardState or not self.ui then return end
    now = now or os.time()
    local state = self.rewardState
    local icon = (state.collected or state.streakLevel == 0) and '/game_rewardwall/images/icon-checkmark' or nil
    updateRewardTimer(self.ui.restingAreaPanel.restingAreaInfo.timeLeft, state.streakDeadline - now, icon)
    if self.rewardTimer and not self.rewardTimer:isDestroyed() then
        updateRewardTimer(self.rewardTimer, state.nextRewardTime - now)
    end
end

function rewardWallController:clearInfo()
    if not self.ui then return end
    local panel = self.ui.infoPanel
    panel:setText('')
    for _, name in ipairs({'free', 'premium'}) do
        panel[name].heading:setText('')
        panel[name].details:setText('')
        panel[name]:hide()
    end
    self.infoHoverTarget = nil
end

function rewardWallController:beginInfoHover(event)
    if not event.value then
        if self.infoHoverTarget == event.target then self:clearInfo() end
        return false
    end
    self:clearInfo()
    self.infoHoverTarget = event.target
    return true
end

function rewardWallController:onhoverBonus(event)
    if not self:beginInfoHover(event) then return end

    local id = event.target:getId()
    local index = tonumber(id:match("%d+"))
    local bonus = bonuses[index]

    if not bonus then
        rewardWallController.ui.infoPanel:setText("Unknown bonus.")
        return
    end

    local isPremium = g_game.getLocalPlayer():isPremium()
    local bonusText = string.format(
        "Allow [color=#909090]%s[/color]%s\nThis bonus is active because you are [color=%s]Premium[/color] and reached a reward streak of at least [color=#44AD25]%d[/color].%s",
        bonus.name, isPremium and "" or "[color=#ff0000](Locked)[/color]", isPremium and "#44AD25" or "#ff0000",
        bonus.id,
        isPremium and ("\n\nActive bonuses: [color=#909090]%s[/color]."):format(getBonusStrings(bonuses)) or "")

    rewardWallController.ui.infoPanel:parseColoredText(bonusText)
end

function rewardWallController:onhoverStatusPlayer(event)
    if not self:beginInfoHover(event) then return end

    local playerStatus = {
        rewardStreakIcon = "This explains the reward streak system. You need to claim your daily reward between regular server saves to maintain your streak. At a streak of 2+, your character gets resting area bonuses. Free accounts can reach a maximum bonus at streak level 3, while premium players can reach higher levels. Characters on the same account share the streak.",
        timeLeft = "This is an urgent notification to claim your daily reward within one minute (before the next server save) to raise your reward streak by 1. It mentions that 3 Daily Reward Jokers will be used to prevent resetting your streak. It also encourages raising your streak to benefit from bonuses in resting areas.",
        restingAreaGold = "This explains how Daily Reward Jokers work. They help you maintain your streak on days when you can't claim your daily reward. Each character receives one Daily Reward Joker on the first day of each month. The message recommends collecting rewards daily to stay safe."
    }

    local DEFAULT_MESSAGE = "Unknown bonus."

    local id = event.target:getId()
    local info = playerStatus[id]
    rewardWallController.ui.infoPanel:parseColoredText(info or DEFAULT_MESSAGE)
end

local function describeReward(reward)
    if not reward then return '' end
    if reward.selectableItems and #reward.selectableItems > 0 then
        local names = {}
        for i = 1, math.min(3, #reward.selectableItems) do
            names[i] = reward.selectableItems[i].name
        end
        return string.format('Pick %d items from the list. Among other items it contains: %s.',
            reward.itemsToSelect or 0, table.concat(names, ', '))
    end
    local lines = {}
    for _, item in ipairs(reward.bundleItems or {}) do
        if item.bundleType == bundleType.XPBOOST then
            table.insert(lines, string.format('\149 %d minutes 50%% XP Boost', item.itemId or 0))
        else
            table.insert(lines, string.format('\149 %dx %s', item.count or 0, item.name or ''))
        end
    end
    return table.concat(lines, '\n')
end

function rewardWallController:onhoverRewardType(event)
    if not self:beginInfoHover(event) then return end
    local panel = self.ui.infoPanel
    panel.free.heading:setText('Reward for Free Accounts:')
    panel.premium.heading:setText('Reward for Premium Accounts:')
    panel.free.details:setText(describeReward(event.target.freeReward))
    panel.premium.details:setText(describeReward(event.target.premiumReward))
    panel.free:show()
    panel.premium:show()
end

function rewardWallController:onhoverStatusReward(event)
    local statusReward = {
        [STATUS.COLLECTED] = "You have already collected this daily reward.\nThe daily rewards follow a specific cycle where each day you claim it, you get another reward. The cycle repeats after 7 claimed rewards. You will be able to claim this daily reward again as soon as you have reached this postion in the next cycle.",
        [STATUS.ACTIVE] = "The daily reward can be claimed now.\nIf you claim this reward now, it will cost you one Instant Reward Access.\nGet your daily reward for free by visiting a reward shrine.\nYou did not claim your daily reward in time.\nToo bad, you do not have enough Daily Reward Jokers.",
        [STATUS.LOCKED] = "This daily reward is still locked.\nFirst collect the previous daily rewards of this cycle.",
        [STATUS.COOLDOWN] = "You already claimed your daily reward. Wait until the next daily reward becomes available."
    }
    if not self:beginInfoHover(event) then return end
    rewardWallController.ui.infoPanel:setText(statusReward[event.target.status])
end

-- /*=============================================
-- =            Auxiliar Windows pickReward      =
-- =============================================*/

function onClickBtnOk()
    if table.empty(actualUsed) then
        return
    end
    if bonusShrine == OPEN_WINDOWS.SHRINE then
        -- Collecting at a reward shrine is free: no Instant Reward Access confirmation.
        -- Canary expects 0 = shrine on the collect packet.
        g_game.requestGetRewardDaily(0, actualUsed)
        if windowsPickWindow then
            windowsPickWindow:destroy()
            windowsPickWindow = nil
        end
        show()
        return
    end
    managerMessageBoxWindow(CONST_WINDOWS_BOX.CONFIRMATION_IRA)
end

function destroyPickReward(bool)
    windowsPickWindow = destroyWindows(windowsPickWindow)

    if bool then
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end
end

function onTextChangeChangeNumber(getPanel)
    if not getPanel.itemsToSelect then
        return
    end

    local alreadyUsed = 0
    local itemId = getPanel:getChildById('item'):getItemId()
    local thisPanelUsed = actualUsed[itemId] or 0

    for _, count in pairs(actualUsed) do
        alreadyUsed = alreadyUsed + (count or 0)
    end

    local numberField = getPanel:getChildById('number')
    local currentValue = tonumber(numberField:getText()) or 0
    local maxAllowed = getPanel.itemsToSelect - (alreadyUsed - thisPanelUsed)

    if currentValue > maxAllowed then
        numberField:setText(maxAllowed)
    end
    actualUsed[itemId] = tonumber(numberField:getText()) or 0
    alreadyUsed = 0
    for _, count in pairs(actualUsed) do
        alreadyUsed = alreadyUsed + (count or 0)
    end
    local color = alreadyUsed == 0 and "#D33C3C" or "#00FF00"
    windowsPickWindow:getChildById('btnOk'):setEnabled(alreadyUsed > 0)

    local text = string.format("You have selected [color=%s]%d[/color] of %d reward items", color, alreadyUsed,
        getPanel.itemsToSelect)
    windowsPickWindow:getChildById('rewardLabel'):parseColoredText(text)
    getPanel:getChildById('weight'):setText(string.format("%.2f oz", actualUsed[itemId] * getPanel.totalWeight))
    local totalWeight = 0
    for i, widget in pairs(getPanel:getParent():getChildren()) do
        local weightLabel = widget:getChildById('weight')
        if weightLabel then
            local weightText = weightLabel:getText()
            local weightValue = tonumber(weightText:match("(%d+)"))
            if weightValue then
                totalWeight = totalWeight + weightValue
            end
        end
    end
    windowsPickWindow:getChildById("weight"):setText(string.format("Total weight: %.2f oz", totalWeight))
    windowsPickWindow:getChildById("weight"):resizeToText()
end

-- /*=============================================
-- =            Auxiliar GeneralBox             =
-- =============================================*/
function displayGeneralBox3(title, message, buttons, onEnterCallback, onEscapeCallback)
    if generalBox then
        generalBox = destroyWindows(generalBox)
    end

    generalBox = g_ui.createWidget('MessageBoxWindow', rootWidget)
    if not generalBox then
        return nil
    end

    local titleWidget = generalBox:getChildById('title')
    if titleWidget then
        titleWidget:setText(title)
    end

    local holder = generalBox:getChildById('holder')
    if holder and buttons then
        for i = 1, #buttons do
            local button = g_ui.createWidget('Button', holder)
            local buttonId = buttons[i].text:lower():gsub(" ", "_")

            button:setId(buttonId)
            button:setText(buttons[i].text)
            button:setWidth(math.max(86, 10 + (string.len(buttons[i].text) * 8)))
            button:setHeight(20)
            button:setMarginTop(-5)

            if i == 1 then
                button:addAnchor(AnchorTop, 'parent', AnchorTop)
                button:addAnchor(AnchorRight, 'parent', AnchorRight)
            else
                button:addAnchor(AnchorTop, 'parent', AnchorTop)
                button:addAnchor(AnchorRight, 'prev', AnchorLeft)
                button:setMarginRight(5)
            end
            button.onClick = buttons[i].callback
        end
    end
    if onEnterCallback then
        generalBox.onEnter = onEnterCallback
    end
    if onEscapeCallback then
        generalBox.onEscape = onEscapeCallback
    end

    local content = generalBox:getChildById('content')
    if not content then
        generalBox = destroyWindows(generalBox)

        return nil
    end

    content:setText(message)
    content:resizeToText()

    local contentWidth = content:getWidth() + 32
    local contentHeight = content:getHeight() + 42 + (holder and holder:getHeight() or 0)
    generalBox:setWidth(math.min(916, math.max(300, contentWidth)))
    generalBox:setHeight(math.min(616, math.max(119, contentHeight)))

    generalBox.setContent = function(self, newMessage)
        local content = generalBox:getChildById('content')
        if not content then
            return
        end

        content:setText(newMessage)
        content:resizeToText()
        content:setTextWrap(false)
        content:setTextAutoResize(false)

        local holder = generalBox:getChildById('holder')
        if not holder then
            return
        end

        local contentWidth = content:getWidth() + 32
        local contentHeight = content:getHeight() + 50 + holder:getHeight()
        generalBox:setWidth(math.min(736, math.max(300, contentWidth)))
        generalBox:setHeight(math.min(300, math.max(89, contentHeight)))
    end

    generalBox.setTitle = function(self, newTitle)
        local titleWidget = generalBox:getChildById('title')
        if not titleWidget then
            return
        end

        titleWidget:setText(newTitle)
    end
    generalBox.modifyButton = function(self, buttonId, newText, newCallback)
        local holder = generalBox:getChildById('holder')
        if not holder then
            return nil
        end

        local button = holder:getChildById(buttonId)
        if button then
            if newText then
                button:setText(newText)
                button:setWidth(math.max(86, 10 + (string.len(newText) * 8)))
            end
            if newCallback then
                disconnect(button, {
                    onClick = button.onClick
                })
                connect(button, {
                    onClick = newCallback
                })
                button.onClick = newCallback
            end
        end
        return button
    end
    generalBox:show()
    generalBox:raise()
    generalBox:focus()
    return generalBox
end

function managerMessageBoxWindow(id)
    local config = BOX_CONFIGS[id]
    if not config then
        return
    end

    local cancelCallback = function()
        generalBox, windowsPickWindow = destroyWindows({generalBox, windowsPickWindow})
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end

    local okCallback = config.okCallback or function()
        generalBox, windowsPickWindow = destroyWindows({generalBox, windowsPickWindow})
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end

    local standardButtons = {{
        text = "cancel",
        callback = cancelCallback
    }, {
        text = "ok",
        callback = okCallback
    }}

    generalBox = displayGeneralBox3(config.title, config.content, standardButtons)

    rewardWallController.ui:hide()

    if windowsPickWindow then
        windowsPickWindow = destroyWindows(windowsPickWindow)
    end
end
