cooldownWindow = nil
contentsPanel = nil
cooldownPanel = nil
cooldown = {}
groupCooldown = {}
tierUpgradeFeatureEnabled = false

local groupIcons = {}
local spellTimers = {}
local groupTimers = {}
local updateEvent
local groupOrder = {1, 2, 3, 4, 6, 7, 8, 9, 10, 11}
local groupNames = {
    [1] = 'Attack', [2] = 'Healing', [3] = 'Support', [4] = 'Special',
    [6] = 'Crippling', [7] = 'Focus', [8] = 'Ultimate Strikes',
    [9] = 'Great Beams', [10] = 'Bursts of Nature', [11] = 'Stance'
}

local function paintCooldown(icon, remaining, total)
    icon.shade:setVisible(remaining <= 0)
    local width = math.ceil(20 * math.min(math.max(remaining, 0) / math.max(total, 1), 1) - 0.5)
    icon.track:getChildById('fill'):setVisible(width > 0)
    if width > 0 then icon.track:getChildById('fill'):setWidth(width) end
end

local function updateCooldowns()
    updateEvent = nil
    local now = g_clock.millis()
    for id, timer in pairs(groupTimers) do
        local remaining = timer.expires - now
        paintCooldown(timer.icon, remaining, timer.total)
        if remaining <= 0 then
            groupTimers[id] = nil
            groupCooldown[id] = nil
        end
    end
    for id, timer in pairs(spellTimers) do
        local remaining = timer.expires - now
        if remaining <= 0 then
            timer.icon:destroy()
            spellTimers[id] = nil
            cooldown[id] = nil
        else
            paintCooldown(timer.icon, remaining, timer.total)
        end
    end
    if next(groupTimers) or next(spellTimers) then
        updateEvent = scheduleEvent(updateCooldowns, 16)
    end
end

local function startUpdates()
    if updateEvent then removeEvent(updateEvent) end
    updateCooldowns()
end

local function setGroupIcons()
    local modern = g_game.getClientVersion() > 1100
    local monk = g_game.getFeature(GameVocationMonk)
    for id, icon in pairs(groupIcons) do
        icon:setVisible(id <= 4 or modern and (id ~= 11 or monk))
    end
end

function init()
    cooldownWindow = g_ui.loadUI('cooldown', modules.game_interface.getBottomPanel())
    contentsPanel = cooldownWindow:getChildById('contentsPanel2')
    cooldownPanel = contentsPanel:getChildById('cooldownPanel')
    for _, id in ipairs(groupOrder) do
        local icon = g_ui.createWidget('CooldownIcon', contentsPanel.groupPanel)
        icon:setId('groupIcon' .. SpellGroups[id])
        icon.image:setImageSource('/images/game/cooldown/spellgroup-icons-20x20')
        icon.image:setImageClip({x = (id - 1) * 20, y = 0, width = 20, height = 20})
        paintCooldown(icon, 0, 1)
        UIHoverTooltip.configure(icon, tr(groupNames[id]))
        groupIcons[id] = icon
    end
    connect(g_game, {
        onGameEnd = offline,
        onGameStart = online,
        onSpellGroupCooldown = onSpellGroupCooldown,
        onSpellCooldown = onSpellCooldown
    })
    setSpellGroupCooldownsVisible(modules.client_options.getOption('showSpellGroupCooldowns'))
    if g_game.isOnline() then online() end
end

function terminate()
    disconnect(g_game, {
        onGameEnd = offline,
        onGameStart = online,
        onSpellGroupCooldown = onSpellGroupCooldown,
        onSpellCooldown = onSpellCooldown
    })
    refresh()
    cooldownWindow:destroy()
    cooldownWindow = nil
    groupIcons = {}
end

function loadIcon(iconId)
    local spell, profile, spellName = Spells.getSpellByIcon(iconId)
    if not spell or not profile or not spellName then return nil end
    local icon = cooldownPanel:getChildById(tostring(iconId))
    if not icon then
        icon = g_ui.createWidget('CooldownIcon', cooldownPanel)
        icon:setId(tostring(iconId))
        local source = SpelllistSettings[profile].iconsForGameCooldown
        icon.image:setImageSource(source)
        icon.image:setImageClip({x = spell.clientId * 20, y = 0, width = 20, height = 20})
        icon.spellName = spellName
        UIHoverTooltip.configure(icon, spellName .. ' (' .. math.floor(spell.exhaustion / 1000) .. ' sec. cooldown)')
        local position = 1
        for _, child in ipairs(cooldownPanel:getChildren()) do
            if child ~= icon and tonumber(child:getId()) < iconId then position = position + 1 end
        end
        cooldownPanel:moveChildToIndex(icon, position)
    end
    return icon, spellName, spell
end

function online()
    tierUpgradeFeatureEnabled = g_game.getFeature(GameForgeSkillStats) or g_game.getFeature(GameCharacterSkillStats)
    refresh()
    setGroupIcons()
    local console = modules.game_console.consolePanel
    if console then console:addAnchor(AnchorTop, cooldownWindow:getId(), AnchorBottom) end
    setSpellGroupCooldownsVisible(g_game.getFeature(GameSpellList)
        and modules.client_options.getOption('showSpellGroupCooldowns'))
end

function offline()
    refresh()
    tierUpgradeFeatureEnabled = false
    local console = modules.game_console.consolePanel
    if console then
        console:removeAnchor(AnchorTop)
        console:fill('parent')
    end
end

function refresh()
    if updateEvent then removeEvent(updateEvent); updateEvent = nil end
    spellTimers = {}
    groupTimers = {}
    cooldown = {}
    groupCooldown = {}
    if cooldownPanel then cooldownPanel:destroyChildren() end
    for _, icon in pairs(groupIcons) do paintCooldown(icon, 0, 1) end
end

function hasTierUpgradeFeature()
    return tierUpgradeFeatureEnabled
end

function isGroupCooldownIconActive(groupId)
    local timer = groupTimers[groupId]
    return timer ~= nil and g_clock.millis() < timer.expires
end

function isCooldownIconActive(iconId)
    local timer = spellTimers[iconId]
    return timer ~= nil and g_clock.millis() < timer.expires
end

function onSpellCooldown(iconId, duration)
    if duration <= 0 then
        local timer = spellTimers[iconId]
        if timer then timer.icon:destroy() end
        spellTimers[iconId] = nil
        cooldown[iconId] = nil
        return
    end
    local icon, _, spell = loadIcon(iconId)
    if not icon then return end
    local expires = g_clock.millis() + duration
    spellTimers[iconId] = {icon = icon, expires = expires, total = math.max(spell.exhaustion, 1)}
    cooldown[iconId] = hasTierUpgradeFeature() and expires or true
    startUpdates()
end

function onSpellGroupCooldown(groupId, duration)
    local icon = groupIcons[groupId]
    if not icon then return end
    if duration <= 0 then
        groupTimers[groupId] = nil
        groupCooldown[groupId] = nil
        paintCooldown(icon, 0, 1)
        return
    end
    local expires = g_clock.millis() + duration
    groupTimers[groupId] = {icon = icon, expires = expires, total = duration}
    groupCooldown[groupId] = hasTierUpgradeFeature() and expires or true
    startUpdates()
end

function setSpellGroupCooldownsVisible(visible)
    if not cooldownWindow then return end
    cooldownWindow:setVisible(visible)
    cooldownWindow:setHeight(visible and 28 or 0)
end
