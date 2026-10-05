-- Skills window. Layout, colours, fonts and wording follow the RTC (RubinOT) skills widget; the data
-- comes from our LocalPlayer events (14.12+ stats, experience rates and the store XP boost).
skillController = Controller:new()

skillsWindow = nil
skillsButton = nil
storeXPButton = nil

local ExpRating = {}
local skillWidgetsOptions = {}
local expSpeedEvent = nil
local rateHighlightEvent = nil
local shownGainRate = nil -- last XP gain rate shown; the label only flashes when it changes
local gainRateSettledAt = 0 -- the rates arrive in several packets at login; changes in the first 2s don't flash
local storeBoostTimerEvent = nil
local storeBoostTime = 0
local healthUpdateEvent = nil
local manaUpdateEvent = nil

local SETTINGS_NODE = 'skills-widget'
local ROW_HEIGHT = 21

-- Offence/defence/misc values arrive as fractions (0.05 = 5%).
local statsCache = {
    flatDamageHealing = 0, attackValue = 0, attackElement = 0, convertedDamage = 0, convertedElement = 0,
    lifeLeech = 0, manaLeech = 0, critChance = 0, critDamage = 0, onslaught = 0,
    defense = 0, armor = 0, mantra = 0, mitigation = 0, dodge = 0, damageReflection = 0,
    combatAbsorbValues = {}, momentum = 0, transcendence = 0, amplification = 0
}

local skillNames = {
    [0] = 'Fist', [1] = 'Club', [2] = 'Sword', [3] = 'Axe', [4] = 'Distance', [5] = 'Shielding', [6] = 'Fishing'
}

local combatNames = {
    [0] = 'Physical', [1] = 'Fire', [2] = 'Earth', [3] = 'Energy', [4] = 'Ice', [5] = 'Holy', [6] = 'Death',
    [7] = 'Healing', [8] = 'Drowning', [9] = 'Life Drain', [10] = 'Mana Drain', [11] = 'Agony'
}

local specialTooltips = {
    convertedDamage = '+%s%% of your attack value will be converted into %s damage.',
    lifeLeech = 'You get +%s%% of the damage dealt as hit points.',
    manaLeech = 'You get +%s%% of the damage dealt as mana.',
    criticalChance = 'You have a +%s%% chance to cause +%s%% extra damage',
    criticalDamage = 'You have a +%s%% chance to cause +%s%% extra damage',
    onslaught = ' You have a +%s%% chance to trigger Onslaught, granting you 60%%\nincreased damage for all attacks.',
    protection = 'Any %s damage you receive from attacks is %s by +%s%%.\n%s',
    protection_note = 'Note that the damage reduction is calculated from the individual\ndamage reductions of your equipment as well as from bonuses\nunlocked in the Wheel of Destiny. However, these values are not\nsimply added up. It depends on various factors to which extent the\ndamage reduction is added to your overall damage reduction. For\nexample, the benefit of damage reduction diminishes when wearing\nequipment with the same damage resistance.',
    reflectionValue = 'You reflect %s of the taken damage to the attacker',
    ruseValue = 'When attacked, you have a %s chance to trigger Ruse, which\nwill fully mitigate the damage.',
    momentumValue = 'During combat, you have a +%s%% chance to trigger Momentum,\nwich reduced all spell cooldowns by 2 seconds.',
    transcendenceValue = 'During combat, you have a +%s%% chance to trigger\nTranscendence, wich transforms your character into a vocation\nspecific avatar for 7 seconds. While in this form, you will benefit\nfrom a 15%% damage reduction and guaranteed critical hits that\ndeal an additional 15%% damage.',
    amplificationValue = 'Effects of tiered items are amplified by +%s%%.'
}

-- 0.1001 -> "10.01", 0.05 -> "5"
local function percentText(fraction)
    local value = math.floor((fraction or 0) * 10000 + 0.5) / 100
    if value == math.floor(value) then
        return tostring(math.floor(value))
    end
    return (string.format('%.2f', value):gsub('0+$', ''))
end

local function child(id)
    return skillsWindow and skillsWindow:recursiveGetChildById(id)
end

local function scheduleHeightUpdate()
    scheduleEvent(function()
        if skillsWindow then
            skillsWindow:setContentMaximumHeight(math.max(125, getContentPanelHeight() + 6))
        end
    end, 100)
end

-- ---------------------------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------------------------

function skillController:onInit()
    skillController:registerEvents(LocalPlayer, {
        onExperienceChange = onExperienceChange,
        onLevelChange = onLevelChange,
        onHealthChange = onHealthChange,
        onManaChange = onManaChange,
        onSoulChange = onSoulChange,
        onFreeCapacityChange = onFreeCapacityChange,
        onTotalCapacityChange = onTotalCapacityChange,
        onBaseCapacityChange = onBaseCapacityChange,
        onStaminaChange = onStaminaChange,
        onOfflineTrainingChange = onOfflineTrainingChange,
        onRegenerationChange = onRegenerationChange,
        onSpeedChange = onSpeedChange,
        onBaseSpeedChange = onBaseSpeedChange,
        onMagicLevelChange = onMagicLevelChange,
        onBaseMagicLevelChange = onBaseMagicLevelChange,
        onSkillChange = onSkillChange,
        onBaseSkillChange = onBaseSkillChange,
        onExpBoostChange = onExpBoostChange,
        -- 14.12
        onFlatDamageHealingChange = onFlatDamageHealingChange,
        onAttackInfoChange = onAttackInfoChange,
        onConvertedDamageChange = onConvertedDamageChange,
        onImbuementsChange = onImbuementsChange,
        onDefenseInfoChange = onDefenseInfoChange,
        onCombatAbsorbValuesChange = onCombatAbsorbValuesChange,
        onForgeBonusesChange = onForgeBonusesChange,
        onExperienceRateChange = onExperienceRateChange,
        -- 15.24
        onMultiOfflineTrainingDialog = onMultiOfflineTrainingDialog
    })

    skillsButton = modules.game_mainpanel.addToggleButton('skillsButton', tr('Skills') .. ' (Alt+S)',
        '/images/options/button_skills', toggle, false, 1)
    skillsButton:setOn(true)

    skillsWindow = g_ui.loadUI('skills')
    storeXPButton = skillsWindow:recursiveGetChildById('boostButton')

    -- The RTC keeps the scrollbar visible.
    local scrollbar = skillsWindow:getChildById('miniwindowScrollBar')
    if scrollbar then
        scrollbar:mergeStyle({ ['$!on'] = {} })
    end

    skillsWindow.onMouseRelease = function(widget, mousePos, mouseButton)
        if mouseButton == MouseRightButton then
            showSkillsPopUp(mousePos)
            return true
        end
    end

    Keybind.new('Windows', 'Show/hide skills windows', 'Alt+S', '')
    Keybind.bind('Windows', 'Show/hide skills windows', {
        { type = KEY_DOWN, callback = toggle }
    })

    skillsWindow:setup()
end

function skillController:onTerminate()
    Keybind.delete('Windows', 'Show/hide skills windows')
    stopEvents()
    skillsWindow:destroy()
    skillsButton:destroy()
    skillsWindow = nil
    skillsButton = nil
    storeXPButton = nil
end

function stopEvents()
    if healthUpdateEvent then removeEvent(healthUpdateEvent) healthUpdateEvent = nil end
    if manaUpdateEvent then removeEvent(manaUpdateEvent) manaUpdateEvent = nil end
    if expSpeedEvent then expSpeedEvent:cancel() expSpeedEvent = nil end
    if storeBoostTimerEvent then removeEvent(storeBoostTimerEvent) storeBoostTimerEvent = nil end
    if rateHighlightEvent then removeEvent(rateHighlightEvent) rateHighlightEvent = nil end
end

function skillController:onGameStart()
    skillsWindow:setupOnStart()
    loadOptions()
    refresh()
end

function skillController:onGameEnd()
    saveOptions()
    stopEvents()
    resetPercentVisibility()
    for key, value in pairs(statsCache) do
        statsCache[key] = type(value) == 'table' and {} or 0
    end
    ExpRating = {}
    shownGainRate = nil
    skillsWindow:setParent(nil, true)
end

function loadOptions()
    local node = g_settings.getNode(SETTINGS_NODE) or {}
    local options = node[g_game.getCharacterName()] or {}
    skillWidgetsOptions = {
        invisibleProgressBars = options.invisibleProgressBars or {},
        offenceStatsVisible = options.offenceStatsVisible ~= false,
        defenceStatsVisible = options.defenceStatsVisible ~= false,
        miscStatsVisible = options.miscStatsVisible ~= false
    }
end

function saveOptions()
    local name = g_game.getCharacterName()
    if not name or name == '' or table.empty(skillWidgetsOptions) then
        return
    end
    local node = g_settings.getNode(SETTINGS_NODE) or {}
    node[name] = skillWidgetsOptions
    g_settings.setNode(SETTINGS_NODE, node)
end

function refresh()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    updateVisblePercentBar()
    manageOffenceStats(skillWidgetsOptions.offenceStatsVisible)
    manageDefenceStats(skillWidgetsOptions.defenceStatsVisible)
    manageMiscStats(skillWidgetsOptions.miscStatsVisible)

    if expSpeedEvent then expSpeedEvent:cancel() end
    expSpeedEvent = cycleEvent(checkExpSpeed, 30 * 1000)

    onExperienceChange(player, player:getExperience())
    onLevelChange(player, player:getLevel(), player:getLevelPercent())
    onHealthChange(player, player:getHealth(), player:getMaxHealth())
    onManaChange(player, player:getMana(), player:getMaxMana())
    onSoulChange(player, player:getSoul())
    onFreeCapacityChange(player, player:getFreeCapacity())
    onStaminaChange(player, player:getStamina())
    onMagicLevelChange(player, player:getMagicLevel(), player:getMagicLevelPercent())
    onOfflineTrainingChange(player, player:getOfflineTrainingTime())
    onRegenerationChange(player, player:getRegenerationTime())
    onSpeedChange(player, player:getSpeed())
    for i = Skill.Fist, Skill.Fishing do
        onSkillChange(player, i, player:getSkillLevel(i), player:getSkillLevelPercent(i))
    end
    onExpBoostChange(player, player:getStoreExpBoostTime(), player:canBuyExpBoost())

    update()
    skillsWindow:setContentMinimumHeight(44)
    skillsWindow:setContentMaximumHeight(g_game.getFeature(GameAdditionalSkills) and 680 or 390)
    scheduleHeightUpdate()
end

function update()
    local offlineTraining = child('offlineTraining')
    offlineTraining:setVisible(g_game.getFeature(GameOfflineTrainingTime))

    local regenerationTime = child('regenerationTime')
    regenerationTime:setVisible(g_game.getFeature(GamePlayerRegenerationTime))
end

function toggle()
    if skillsButton:isOn() then
        skillsWindow:close()
        skillsButton:setOn(false)
    else
        if not skillsWindow:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(skillsWindow, skillsWindow:getMinimumHeight())
            if not panel then
                return
            end
            panel:addChild(skillsWindow)
        end
        skillsWindow:open()
        skillsButton:setOn(true)
        scheduleHeightUpdate()
    end
end

function onMiniWindowOpen()
    if skillsButton then
        skillsButton:setOn(true)
    end
end

function onMiniWindowClose()
    if skillsButton then
        skillsButton:setOn(false)
    end
end

-- ---------------------------------------------------------------------------------------------
-- Widget helpers (RTC)
-- ---------------------------------------------------------------------------------------------

function expForLevel(level)
    return math.floor((50 * level * level * level) / 3 - 100 * level * level + (850 * level) / 3 - 200)
end

function expToAdvance(currentLevel, currentExp)
    return expForLevel(currentLevel + 1) - currentExp
end

function resetSkillColor(id)
    local skill = child(id)
    if skill then
        skill:getChildById('value'):setColor('#bbbbbb')
    end
end

function toggleSkill(id, state)
    local skill = child(id)
    if skill then
        skill:setVisible(state)
        scheduleHeightUpdate()
    end
end

local PERCENT_BAR_ROWS = { 'level', 'stamina', 'offlineTraining', 'magiclevel' }
local function percentBarRows()
    local rows = { unpack(PERCENT_BAR_ROWS) }
    for i = Skill.Fist, Skill.Fishing do
        table.insert(rows, 'skillId' .. i)
    end
    return rows
end

local function setPercentBarShown(skillId, shown)
    local skill = child(skillId)
    if not skill then
        return
    end
    local percentBar = skill:getChildById('percent')
    local skillIcon = skill:getChildById('skillIcon')
    percentBar:setVisible(shown)
    if skillIcon then
        skillIcon:setVisible(shown)
    end
    skill:setHeight(shown and ROW_HEIGHT or ROW_HEIGHT - 7)
end

function showOrHidePercentBar(skillId)
    local hidden = skillWidgetsOptions.invisibleProgressBars
    if skillId then
        local shown = table.find(hidden, skillId) ~= nil
        setPercentBarShown(skillId, shown)
        if shown then
            table.removevalue(hidden, skillId)
        else
            table.insert(hidden, skillId)
        end
    else
        local showAll = #hidden > 0
        for _, id in ipairs(percentBarRows()) do
            setPercentBarShown(id, showAll)
            table.removevalue(hidden, id)
            if not showAll then
                table.insert(hidden, id)
            end
        end
    end
    saveOptions()
    scheduleHeightUpdate()
end

function updateVisblePercentBar()
    for _, id in ipairs(percentBarRows()) do
        setPercentBarShown(id, table.find(skillWidgetsOptions.invisibleProgressBars, id) == nil)
    end
end

function resetPercentVisibility()
    for _, id in ipairs(percentBarRows()) do
        local skill = child(id)
        if skill then
            skill:getChildById('percent'):setVisible(true)
            local skillIcon = skill:getChildById('skillIcon')
            if skillIcon then
                skillIcon:setVisible(true)
            end
            skill:setHeight(ROW_HEIGHT)
        end
    end
end

function getContentPanelHeight()
    local calculatedHeight = 0
    local contentPanel = child('contentsPanel')
    if not contentPanel then
        return 0
    end
    for _, widget in pairs(contentPanel:getChildren()) do
        if widget:isVisible() then
            calculatedHeight = calculatedHeight + widget:getHeight()
            if widget:getMarginTop() > 0 then
                calculatedHeight = calculatedHeight + widget:getMarginTop()
            end
            if widget:getId() == 'miscPanel' and widget:getMarginBottom() > 0 then
                calculatedHeight = calculatedHeight + widget:getMarginBottom() + 8
            end
        end
    end
    return calculatedHeight
end

function showSkillsPopUp(mousePosition)
    local hidden = skillWidgetsOptions.invisibleProgressBars
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption(tr('Reset Experience Counter'), function()
        local player = g_game.getLocalPlayer()
        if player then
            player.expSpeed = 0
            player.lastExps = nil
        end
    end)
    menu:addSeparator()
    menu:addCheckBoxOption(tr('Level'), function() showOrHidePercentBar('level') end, '', table.find(hidden, 'level') == nil)
    menu:addCheckBoxOption(tr('Stamina'), function() showOrHidePercentBar('stamina') end, '', table.find(hidden, 'stamina') == nil)
    menu:addCheckBoxOption(tr('Offline Training'), function() showOrHidePercentBar('offlineTraining') end, '', table.find(hidden, 'offlineTraining') == nil)
    menu:addCheckBoxOption(tr('Magic'), function() showOrHidePercentBar('magiclevel') end, '', table.find(hidden, 'magiclevel') == nil)
    for i = Skill.Fist, Skill.Fishing do
        menu:addCheckBoxOption(tr(skillNames[i]), function() showOrHidePercentBar('skillId' .. i) end, '', table.find(hidden, 'skillId' .. i) == nil)
    end
    menu:addSeparator()
    menu:addCheckBoxOption(tr('Offence Stats'), function()
        skillWidgetsOptions.offenceStatsVisible = not skillWidgetsOptions.offenceStatsVisible
        manageOffenceStats(skillWidgetsOptions.offenceStatsVisible)
        saveOptions()
    end, '', skillWidgetsOptions.offenceStatsVisible)
    menu:addCheckBoxOption(tr('Defence Stats'), function()
        skillWidgetsOptions.defenceStatsVisible = not skillWidgetsOptions.defenceStatsVisible
        manageDefenceStats(skillWidgetsOptions.defenceStatsVisible)
        saveOptions()
    end, '', skillWidgetsOptions.defenceStatsVisible)
    menu:addCheckBoxOption(tr('Misc. Stats'), function()
        skillWidgetsOptions.miscStatsVisible = not skillWidgetsOptions.miscStatsVisible
        manageMiscStats(skillWidgetsOptions.miscStatsVisible)
        saveOptions()
    end, '', skillWidgetsOptions.miscStatsVisible)
    menu:addSeparator()
    menu:addCheckBoxOption(tr('Show all Skill Bars'), function() showOrHidePercentBar(nil) end, '', #hidden == 0)
    menu:display(mousePosition)
end

function setSkillBase(id, value, baseValue)
    local skill = child(id)
    if not skill then
        return
    end
    local widget = skill:getChildById('value')
    local percentWidget = skill:getChildById('percent')

    skill:removeTooltip()
    widget:setColor('#bbbbbb')

    if baseValue <= 0 or value < 0 or baseValue == value then
        if percentWidget then
            local percent = tr('You have %s percent to go', 100 - percentWidget:getPercent())
            percentWidget:setTooltip(percent)
            skill:setTooltip(percent)
        end
        return
    end

    if value > baseValue then
        local tooltip = tr('%s = %s', value, baseValue) .. tr(' +%s', value - baseValue)
        widget:setColor('#44ad25') -- green
        if percentWidget then
            tooltip = tooltip .. '\n' .. tr('You have %s percent to go', 100 - percentWidget:getPercent())
            percentWidget:setTooltip(tooltip)
        end
        skill:setTooltip(tooltip)
    else
        widget:setColor('#c00000') -- red
        skill:setTooltip(baseValue .. ' ' .. (value - baseValue))
    end
end

function setSkillValue(id, value)
    local skill = child(id)
    if not skill then
        return
    end

    local widget = skill:getChildById('value')
    if value == 0 then
        widget:setColor('#bbbbbb')
    end

    if id == 'capacity' then
        local player = g_game.getLocalPlayer()
        if value == 0 then
            widget:setColor('#D33C3C')
        elseif player and player:getTotalCapacity() ~= player:getBaseCapacity() then
            widget:setColor('#44ad25')
        else
            widget:setColor('#bbbbbb')
        end
        value = math.floor(value)
    end

    if id == 'regenerationTime' then
        local tooltip = 'You are hungry.\nEat something to regenerate your and mana over time'
        local hours, minutes, seconds = string.match(value, '(%d%d):(%d%d):(%d%d)')
        if value ~= '00:00:00' then
            if tonumber(hours) > 0 then
                tooltip = tr('You are regenerating hit points and mana for %s hours and %s minutes', hours, minutes)
            else
                tooltip = tr('You are regenerating hit points and mana for %s minutes and %s seconds', minutes, seconds)
            end
        end
        value = hours .. ':' .. minutes
        skill:setTooltip(tooltip)
    end

    widget:setText(value)

    if id == 'experience' then
        local expLabel = child('expLabel')
        expLabel:setText(widget:getWidth() > 75 and 'XP' or 'Experience')
    end
end

function setSkillColor(id, value)
    local skill = child(id)
    if skill then
        skill:getChildById('value'):setColor(value)
    end
end

function setSkillTooltip(id, value)
    local skill = child(id)
    if skill then
        skill:getChildById('value'):setTooltip(value)
    end
end

function setSkillPercent(id, percent, tooltip, color)
    local skill = child(id)
    if not skill then
        return
    end
    local widget = skill:getChildById('percent')
    if not widget then
        return
    end
    widget:setPercent(percent)
    if id == 'offlineTraining' or id == 'stamina' then
        widget:setPercent(math.floor(percent))
    end
    if id == 'offlineTraining' then
        widget:setBackgroundColor('#c00000')
    end
    if color then
        widget:setBackgroundColor(color)
    end
    if tooltip then
        widget:setTooltip(tooltip)
    end
    if table.find(skillWidgetsOptions.invisibleProgressBars or {}, id) then
        widget:setVisible(false)
    end
end

-- ---------------------------------------------------------------------------------------------
-- Player values
-- ---------------------------------------------------------------------------------------------

function checkExpSpeed()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end
    local currentExp = player:getExperience()
    local currentTime = g_clock.seconds()
    if player.lastExps ~= nil then
        player.expSpeed = (currentExp - player.lastExps[1][1]) / (currentTime - player.lastExps[1][2])
        onLevelChange(player, player:getLevel(), player:getLevelPercent())
    else
        player.lastExps = {}
    end
    table.insert(player.lastExps, { currentExp, currentTime })
    if #player.lastExps > 30 then
        table.remove(player.lastExps, 1)
    end
end

function onExperienceChange(localPlayer, value)
    if value >= 1000000000000000 then
        setSkillValue('experience', '1kkkk+')
    else
        setSkillValue('experience', comma_value(value))
    end
end

function onLevelChange(localPlayer, value, percent)
    setSkillValue('level', comma_value(value))
    child('level'):getChildById('percent'):setTooltip(tr('You have %s percent to go', 100 - percent))

    local text = tr('%s XP for next level', comma_value(expToAdvance(localPlayer:getLevel(), localPlayer:getExperience())))
    if localPlayer.expSpeed ~= nil then
        local expPerHour = math.floor(localPlayer.expSpeed * 3600)
        if expPerHour > 0 then
            local nextLevelExp = expForLevel(localPlayer:getLevel() + 1)
            local hoursLeft = (nextLevelExp - localPlayer:getExperience()) / expPerHour
            local minutesLeft = math.floor((hoursLeft - math.floor(hoursLeft)) * 60)
            hoursLeft = math.floor(hoursLeft)
            text = text .. '\n' .. tr('currently %s XP per hour, next level in %d hours and %d minutes',
                comma_value(expPerHour), hoursLeft, minutesLeft)
        end
    end
    child('experience'):setTooltip(text)
    setSkillPercent('level', percent)
end

function onHealthChange(localPlayer, health)
    if healthUpdateEvent then
        removeEvent(healthUpdateEvent)
    end
    healthUpdateEvent = scheduleEvent(function()
        setSkillValue('health', health)
        healthUpdateEvent = nil
    end, 50)
end

function onManaChange(localPlayer, mana)
    if manaUpdateEvent then
        removeEvent(manaUpdateEvent)
    end
    manaUpdateEvent = scheduleEvent(function()
        setSkillValue('mana', mana)
        manaUpdateEvent = nil
    end, 50)
end

function onSoulChange(localPlayer, soul)
    setSkillValue('soul', soul)
end

function onFreeCapacityChange(localPlayer, freeCapacity)
    setSkillValue('capacity', freeCapacity)
end

function onTotalCapacityChange(localPlayer)
    setSkillValue('capacity', localPlayer:getFreeCapacity())
end

function onBaseCapacityChange(localPlayer)
    setSkillValue('capacity', localPlayer:getFreeCapacity())
end

function onStaminaChange(localPlayer, stamina)
    local hours = math.floor(stamina / 60)
    local minutes = stamina % 60
    if minutes < 10 then
        minutes = '0' .. minutes
    end
    local percent = math.floor(100 * stamina / (42 * 60))

    setSkillValue('stamina', hours .. ':' .. minutes)

    if stamina > 39 * 60 then
        local text = tr('You have %s hours and %s minutes left and receive ', hours, minutes) .. '50% more\nexperience (Premium Only)'
        setSkillPercent('stamina', percent, text, 'green')
    elseif stamina > 840 then
        setSkillPercent('stamina', percent, tr('You have %s hours and %s minutes left', hours, minutes), 'orange')
    elseif stamina > 0 then
        local text = tr('You have %s hours and %s minutes left', hours, minutes) .. '\n' ..
            tr("You gain only 50%% experience and you don't may gain loot from monsters")
        setSkillPercent('stamina', percent, text, 'red')
    else
        local text = tr('You have %s hours and %s minutes left', hours, minutes) .. '\n' ..
            tr("You don't may receive experience and loot from monsters")
        setSkillPercent('stamina', percent, text, 'black')
    end
    updateExperienceRate(localPlayer)
end

function onOfflineTrainingChange(localPlayer, offlineTrainingTime)
    if not g_game.getFeature(GameOfflineTrainingTime) then
        return
    end
    local hours = math.floor(offlineTrainingTime / 60)
    local minutes = offlineTrainingTime % 60
    if minutes < 10 then
        minutes = '0' .. minutes
    end
    local percent = 100 * offlineTrainingTime / (12 * 60)
    setSkillValue('offlineTraining', hours .. ':' .. minutes)
    setSkillPercent('offlineTraining', percent,
        tr('You have %s hours and %s minutes of offline training time left', hours, tostring(tonumber(minutes))))
end

function onRegenerationChange(localPlayer, regenerationTime)
    if not g_game.getFeature(GamePlayerRegenerationTime) or regenerationTime < 0 then
        return
    end
    local hours = math.floor(regenerationTime / 3600)
    local minutes = math.floor((regenerationTime % 3600) / 60)
    local seconds = regenerationTime % 60
    setSkillValue('regenerationTime', string.format('%02d:%02d:%02d', hours, minutes, seconds))
end

function onSpeedChange(localPlayer, speed)
    setSkillValue('speed', speed)
    onBaseSpeedChange(localPlayer, localPlayer:getBaseSpeed())
end

function onBaseSpeedChange(localPlayer, baseSpeed)
    setSkillBase('speed', localPlayer:getSpeed(), baseSpeed)
end

function onMagicLevelChange(localPlayer, magiclevel, percent)
    setSkillValue('magiclevel', magiclevel)
    setSkillPercent('magiclevel', percent / 100)
    onBaseMagicLevelChange(localPlayer, localPlayer:getBaseMagicLevel())
end

function onBaseMagicLevelChange(localPlayer, baseMagicLevel)
    setSkillBase('magiclevel', localPlayer:getMagicLevel(), baseMagicLevel)
end

function onSkillChange(localPlayer, id, level, percent)
    if id > Skill.Fishing then
        return
    end
    setSkillValue('skillId' .. id, level)
    setSkillPercent('skillId' .. id, percent / 100)
    onBaseSkillChange(localPlayer, id, localPlayer:getSkillBaseLevel(id))
end

function onBaseSkillChange(localPlayer, id, baseLevel)
    if id > Skill.Fishing then
        return
    end
    setSkillBase('skillId' .. id, localPlayer:getSkillLevel(id), baseLevel)
end

-- ---------------------------------------------------------------------------------------------
-- XP gain rate and the store XP boost
-- ---------------------------------------------------------------------------------------------

function onExperienceRateChange(localPlayer, type, value)
    ExpRating[type] = value
    updateExperienceRate(localPlayer)
end

function updateExperienceRate(localPlayer)
    local baseRate = ExpRating[ExperienceRate.BASE] or 100
    local lowLevelBonus = ExpRating[ExperienceRate.LOW_LEVEL] or 0
    local expBoost = (ExpRating[ExperienceRate.XP_BOOST] or 0) + (ExpRating[ExperienceRate.VOUCHER] or 0)
    local staminaMulti = ExpRating[ExperienceRate.STAMINA_MULTIPLIER] or 100
    onUpdateGainRate(localPlayer, baseRate, lowLevelBonus, expBoost, staminaMulti)
end

function onExpBoostChange(localPlayer, time, canBuy)
    if storeXPButton then
        storeXPButton:setVisible(canBuy)
    end
    storeBoostTime = time
    if storeBoostTimerEvent then
        removeEvent(storeBoostTimerEvent)
        storeBoostTimerEvent = nil
    end
    updateExperienceRate(localPlayer)
    if time > 0 then
        storeBoostTimerEvent = cycleEvent(function()
            if storeBoostTime <= 0 then
                removeEvent(storeBoostTimerEvent)
                storeBoostTimerEvent = nil
                return
            end
            storeBoostTime = storeBoostTime - 1
            updateExperienceRate(localPlayer)
        end, 1000)
    else
        local storeBoostValue = child('storeBoostValue')
        storeBoostValue:setText('00:00')
        storeBoostValue:setColor('#D33C3C')
    end
end

function onBoostClick()
    modules.game_store.toggle()
    g_game.sendRequestStorePremiumBoost()
end

function onUpdateGainRate(localPlayer, baseRate, lowLevelBonus, expBoost, staminaMulti)
    if not g_game.isOnline() or not skillsWindow then
        return
    end
    local rate = child('xpGainRate')
    if not rate then
        return
    end

    local totalGainRate = math.floor((baseRate + lowLevelBonus + expBoost) * staminaMulti / 100)
    local tooltip = tr('Your current XP gain rate amounts to %s%s.', totalGainRate, '%') ..
        '\nYour XP gain rate is calculated as follows:\n' .. tr('- Base XP gain rate: %s%s', baseRate, '%')
    if lowLevelBonus ~= 0 then
        tooltip = tr('%s\n- Low level bonus: +%s%s ', tooltip, lowLevelBonus, '%') .. '(until level 50)'
    end

    local formattedTime = formatTimeBySeconds(storeBoostTime)
    local storeBoostValue = child('storeBoostValue')
    if expBoost ~= 0 then
        tooltip = tr('%s\n- XP boost: +%s%s ', tooltip, expBoost, '%') .. tr('(%s remaining)', formattedTime)
    end
    storeBoostValue:setText(formattedTime)
    storeBoostValue:setColor(storeBoostTime <= 300 and '#D33C3C' or '#44ad25')

    local storeBoostWidget = child('storeBoost')
    storeBoostWidget:setTooltip(tr('XP boost remaining time: %s', formattedTime .. '\n- Click here to increase your experience gain'))
    storeBoostWidget.onClick = onBoostClick

    if staminaMulti > 100 then
        tooltip = tr('%s\n- Stamina bonus: x%s ', tooltip, staminaMulti / 100) ..
            tr('(%s h remaining)', formatTimeByMinutes(localPlayer:getStamina() - 2340))
    end

    local widget = rate:getChildById('value')
    widget:setText(totalGainRate .. '%')
    widget:setColor('#44ad25')
    rate:setTooltip(tooltip)

    -- The boost countdown refreshes this every second; flashing on each refresh kept the label blinking.
    if shownGainRate == nil then
        gainRateSettledAt = g_clock.millis() + 2000
    end
    local changed = shownGainRate ~= nil and shownGainRate ~= totalGainRate and g_clock.millis() >= gainRateSettledAt
    shownGainRate = totalGainRate
    if changed and not rateHighlightEvent then
        local endTime = g_clock.millis() + 6000
        rateHighlightEvent = cycleEvent(function()
            if not g_game.isOnline() or not doHighlight then
                removeEvent(rateHighlightEvent)
                rateHighlightEvent = nil
                return
            end
            doHighlight(endTime)
        end, 200)
    end
end

function doHighlight(endTime)
    local widget = child('gainLabel')
    if not widget then
        removeEvent(rateHighlightEvent)
        rateHighlightEvent = nil
        return
    end
    local steps = { '#ebebeb', '#dfdfdf', '#d6d6d6', '#cecece', '#c0c0c0' }
    local step = (widget.highlightStep or 0) % #steps + 1
    widget.highlightStep = step
    widget:setColor(steps[step])
    if g_clock.millis() >= endTime then
        removeEvent(rateHighlightEvent)
        rateHighlightEvent = nil
        widget:setColor('#c0c0c0')
    end
end

-- Kept for other modules (analysers).
function getExpRating(type)
    if type then
        return ExpRating[type] or 0
    end
    return ExpRating
end

function getTotalExpRateMultiplier()
    local baseRate = ExpRating[ExperienceRate.BASE] or 100
    local expRateTotal = baseRate
    for type, value in pairs(ExpRating) do
        if type ~= ExperienceRate.BASE and type ~= ExperienceRate.STAMINA_MULTIPLIER then
            expRateTotal = expRateTotal + (value or 0)
        end
    end
    local staminaMultiplier = ExpRating[ExperienceRate.STAMINA_MULTIPLIER] or 100
    return expRateTotal * staminaMultiplier / 100 / 100
end

-- ---------------------------------------------------------------------------------------------
-- Offence / defence / misc stats (14.12+)
-- ---------------------------------------------------------------------------------------------

local function managePanel(panelId, separatorId, state)
    child(panelId):setVisible(state)
    child(separatorId):setVisible(state)
    scheduleHeightUpdate()
end

function manageOffenceStats(state) managePanel('attackPanel', 'attackSeparator', state) end
function manageDefenceStats(state) managePanel('defencePanel', 'defenceSeparator', state) end
function manageMiscStats(state) managePanel('miscPanel', 'miscSeparator', state) end

function getCombatName(combatId)
    return combatNames[combatId] or 'Unkown'
end

local function elementIcon(element)
    return '/game_cyclopedia/images/icons/stats/element_' .. (element or 0)
end

local function updateOffence()
    child('damageHealingLabel'):setText(statsCache.flatDamageHealing)

    local attackWidget = child('attackValue')
    attackWidget:getChildById('value'):setText(statsCache.attackValue)
    attackWidget:getChildById('combatIcon'):setImageSource(elementIcon(statsCache.attackElement))

    local converted = percentText(statsCache.convertedDamage)
    local convertedWidget = child('convertedDamage')
    convertedWidget:getChildById('value'):setText('+' .. converted .. '%')
    convertedWidget:getChildById('combatIcon'):setImageSource(elementIcon(statsCache.convertedElement))
    convertedWidget:setTooltip(tr(specialTooltips.convertedDamage, converted, getCombatName(statsCache.convertedElement)))
    convertedWidget:setVisible(statsCache.convertedDamage > 0)
    if statsCache.convertedDamage > 0.1 then
        convertedWidget:getChildById('nameLabel'):setText('Convert...')
    end

    local function leech(id, value, tooltipKey)
        local widget = child(id)
        local text = percentText(value)
        widget:getChildById('value'):setText('+' .. text .. '%')
        widget:setTooltip(tr(specialTooltips[tooltipKey], text))
        widget:setVisible(value > 0)
    end
    leech('lifeLeech', statsCache.lifeLeech, 'lifeLeech')
    leech('manaLeech', statsCache.manaLeech, 'manaLeech')

    local chance, damage = percentText(statsCache.critChance), percentText(statsCache.critDamage)
    local chanceWidget, damageWidget = child('criticalChance'), child('criticalDamage')
    chanceWidget:getChildById('value'):setText('+' .. chance .. '%')
    chanceWidget:setTooltip(tr(specialTooltips.criticalChance, chance, damage))
    damageWidget:getChildById('value'):setText('+' .. damage .. '%')
    damageWidget:setTooltip(tr(specialTooltips.criticalDamage, chance, damage))
    child('skillIdHitSeparator'):setVisible(statsCache.critChance > 0 or statsCache.critDamage > 0)
    chanceWidget:setVisible(statsCache.critChance > 0)
    damageWidget:setVisible(statsCache.critDamage > 0)

    leech('onslaught', statsCache.onslaught, 'onslaught')
    scheduleHeightUpdate()
end

function onFlatDamageHealingChange(localPlayer, flatBonus)
    statsCache.flatDamageHealing = flatBonus or 0
    updateOffence()
end

function onAttackInfoChange(localPlayer, attackValue, attackElement)
    statsCache.attackValue = attackValue or 0
    statsCache.attackElement = attackElement or 0
    updateOffence()
end

function onConvertedDamageChange(localPlayer, convertedDamage, convertedElement)
    statsCache.convertedDamage = convertedDamage or 0
    statsCache.convertedElement = convertedElement or 0
    updateOffence()
end

function onImbuementsChange(localPlayer, lifeLeech, manaLeech, critChance, critDamage, onslaught)
    statsCache.lifeLeech = lifeLeech or 0
    statsCache.manaLeech = manaLeech or 0
    statsCache.critChance = critChance or 0
    statsCache.critDamage = critDamage or 0
    statsCache.onslaught = onslaught or 0
    updateOffence()
end

function onCombatAbsorbValuesChange(localPlayer, absorbValues)
    statsCache.combatAbsorbValues = absorbValues or {}
    for i = 0, 11 do
        local value = statsCache.combatAbsorbValues[i] or 0
        local elementWidget = child('elementalDefense_' .. i)
        if elementWidget then
            local text = percentText(value)
            local valueWidget = elementWidget:getChildById('value')
            elementWidget:setVisible(value ~= 0)
            valueWidget:setText(value < 0 and (text .. '%') or ('+' .. text .. '%'))
            valueWidget:setColor(value < 0 and '#ff9854' or '#44ad25')
            elementWidget:setTooltip(tr(specialTooltips.protection, getCombatName(i),
                value < 0 and 'increased' or 'reduced', text, specialTooltips.protection_note))
        end
    end
    scheduleHeightUpdate()
end

function onDefenseInfoChange(localPlayer, defense, armor, mantra, mitigation, dodge, damageReflection)
    statsCache.defense = defense or 0
    statsCache.armor = armor or 0
    statsCache.mantra = mantra or 0
    statsCache.mitigation = mitigation or 0
    statsCache.dodge = dodge or 0
    statsCache.damageReflection = damageReflection or 0

    child('defenseValue'):getChildById('value'):setText(statsCache.defense)
    child('armorValue'):getChildById('value'):setText(statsCache.armor)
    child('mantraValue'):getChildById('value'):setText(statsCache.mantra)
    child('mitigationValue'):getChildById('value'):setText('+' .. percentText(statsCache.mitigation) .. '%')

    local ruseWidget = child('ruseValue')
    local ruse = percentText(statsCache.dodge)
    ruseWidget:getChildById('value'):setText('+' .. ruse .. '%')
    ruseWidget:setTooltip(tr(specialTooltips.ruseValue, ruse))
    ruseWidget:setVisible(statsCache.dodge > 0)

    local reflectionWidget = child('reflectionValue')
    reflectionWidget:getChildById('value'):setText(statsCache.damageReflection)
    reflectionWidget:setTooltip(tr(specialTooltips.reflectionValue, statsCache.damageReflection))
    reflectionWidget:setVisible(statsCache.damageReflection > 0)
    scheduleHeightUpdate()
end

function onForgeBonusesChange(localPlayer, momentum, transcendence, amplification)
    statsCache.momentum = momentum or 0
    statsCache.transcendence = transcendence or 0
    statsCache.amplification = amplification or 0
    for _, entry in ipairs({
        { 'momentumValue', statsCache.momentum },
        { 'transcendenceValue', statsCache.transcendence },
        { 'amplificationValue', statsCache.amplification }
    }) do
        local widget = child(entry[1])
        local text = percentText(entry[2])
        widget:getChildById('value'):setText('+' .. text .. '%')
        widget:setTooltip(tr(specialTooltips[entry[1]], text))
        widget:setVisible(entry[2] > 0)
    end
    scheduleHeightUpdate()
end
