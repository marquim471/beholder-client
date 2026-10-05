-- Weapon Proficiency Module
-- Implements the Weapon Proficiency system from Summer Update 2025

WeaponProficiency = WeaponProficiency or {}
WeaponProficiency.__index = WeaponProficiency

-- Preserve enums from gamelib/const.lua if needed
WeaponProficiency.WEAPON_PROFICIENCY_ITEM_INFO = 0
WeaponProficiency.WEAPON_PROFICIENCY_LIST_INFO = 1
WeaponProficiency.WEAPON_PROFICIENCY_RESET_PERKS = 2
WeaponProficiency.WEAPON_PROFICIENCY_APPLY_PERKS = 3

WeaponProficiency.window = nil
WeaponProficiency.shapeWindow = nil
WeaponProficiency.reshapeWindow = nil
WeaponProficiency.shapeOptionsWindow = nil
WeaponProficiency.displayItemPanel = nil
WeaponProficiency.perkPanel = nil
WeaponProficiency.bonusDetailPanel = nil
WeaponProficiency.starProgressPanel = nil
WeaponProficiency.optionFilter = nil
WeaponProficiency.itemListScroll = nil
WeaponProficiency.vocationWarning = nil
WeaponProficiency.button = nil

WeaponProficiency.itemList = {}
WeaponProficiency.cacheList = {} -- [itemId] = {experience, perks}

WeaponProficiency.allProficiencyRequested = false
WeaponProficiency.firstItemRequested = nil
WeaponProficiency.saveWeaponMissing = false

WeaponProficiency.ItemCategory = {
    Axes = 17, Clubs = 18, DistanceWeapons = 19,
    Swords = 20, WandsRods = 21, FistWeapons = 32,
}

WeaponProficiency.perkPanelsName = {
    "oneBonusIconPanel", "twoBonusIconPanel", "threeBonusIconPanel"
}

WeaponProficiency.filters = {
    ["levelButton"] = false,
    ["vocButton"] = false,
    ["oneButton"] = false,
    ["twoButton"] = false,
}

WeaponProficiency.shapeButtonActive = false

-- Search filter
WeaponProficiency.searchFilter = nil

-- Scrollable settings
WeaponProficiency.listWidgetHeight = 34
WeaponProficiency.listCapacity = 0
WeaponProficiency.listMinWidgets = 0
WeaponProficiency.listMaxWidgets = 0
WeaponProficiency.offset = 0
WeaponProficiency.listPool = {}
WeaponProficiency.listData = {}
WeaponProficiency.focusedPerk = nil
WeaponProficiency.shapeContext = nil
WeaponProficiency.shapeOptionsContext = nil
WeaponProficiency.shapeOptionsEntries = {}
WeaponProficiency.pendingModifySlot = nil
WeaponProficiency.modifyRequestPending = false
WeaponProficiency.activeShapeSlot = nil
WeaponProficiency.reshapeContext = nil
WeaponProficiency.reshapeOffers = {}

local weaponProficiencyKeyboardFocusClaimId = nil
local WEAPON_PROFICIENCY_MODIFY_SLOT = 4
local WEAPON_PROFICIENCY_RESHAPE_SLOT = 7
local WEAPON_PROFICIENCY_PICK_OFFER = 8
local WEAPON_PROFICIENCY_CLEAR_SLOT = 9
local requestOpenWindow

local function cloneTableShallow(source)
    local copy = {}
    if type(source) ~= 'table' then
        return copy
    end

    for key, value in pairs(source) do
        copy[key] = value
    end

    return copy
end

local function normalizeSearchText(value)
    return string.lower((value or ''):trim())
end

local function getShapeOptionsEntryKey(perkData)
    if not perkData then
        return nil
    end

    local parts = {
        tostring(perkData.Type or 0),
        tostring(perkData.SkillId or 0),
        tostring(perkData.DamageType or 0),
        tostring(perkData.ElementId or 0),
        tostring(perkData.Range or 0),
        tostring(perkData.SpellId or 0),
        tostring(perkData.AugmentType or 0),
        tostring(perkData.BestiaryName or '')
    }

    return table.concat(parts, ':')
end

local function parseImageClipString(clip)
    local x, y = tostring(clip or '0 0'):match("(%-?%d+)%s+(%-?%d+)")
    return tonumber(x) or 0, tonumber(y) or 0
end

local function isStandaloneProficiencyImage(imagePath)
    return imagePath and string.find(imagePath, "/new spells/", 1, true) ~= nil
end

local function setProficiencyIconImage(widget, imagePath, imageClip, size)
    if not widget then
        return
    end

    widget:setImageSource(imagePath)
    size = size or 64

    if isStandaloneProficiencyImage(imagePath) then
        -- Standalone PNGs are complete icons, not 64x64 atlas tiles. Clipping a
        -- 32/38px standalone image as 64x64 makes the renderer sample/repeat the
        -- texture, which is why some new perks appeared as two/wrong images.
        if widget.setImageClip then
            widget:setImageClip(nil)
        end
        if widget.setImageAutoResize then
            widget:setImageAutoResize(false)
        end
        if widget.setImageSize then
            widget:setImageSize({ width = size, height = size })
        end
        return
    end

    local clipX, clipY = parseImageClipString(imageClip)
    if widget.setImageAutoResize then
        widget:setImageAutoResize(false)
    end
    widget:setImageClip({ x = clipX, y = clipY, width = size, height = size })
    if widget.setImageSize then
        widget:setImageSize({ width = size, height = size })
    end
end

local function interpolateModifiedValue(rank, rank0, rank10)
    rank = tonumber(rank) or 1
    local clampedRank = math.max(1, math.min(10, rank))
    local fraction = (clampedRank - 1) / 9
    return rank0 + (rank10 - rank0) * fraction
end

local function createModifiedPerkData(slot)
    if type(slot) ~= 'table' then
        return nil
    end

    local perkType = tonumber(slot.perkType)
    local rank = tonumber(slot.rank) or 1
    if not perkType then
        return nil
    end

    if perkType >= 251 and perkType <= 271 then
        local bestiaryId = perkType - 250
        return {
            Type = PERK_BESTIARY_DAMAGE,
            BestiaryId = bestiaryId,
            BestiaryName = BestiaryIdToName and BestiaryIdToName[bestiaryId] or nil,
            Value = interpolateModifiedValue(rank, 0.5, 2.5) / 100,
            ModifiedRank = rank,
            ModifiedPerkType = perkType,
        }
    end

    local skillByShapeId = {
        [291] = 1, [292] = 6, [293] = 7, [294] = 8, [295] = 9, [296] = 10, [297] = 11,
        [301] = 1, [302] = 6, [303] = 7, [304] = 8, [305] = 9, [306] = 10, [307] = 11,
        [311] = 1, [312] = 6, [314] = 8, [315] = 9, [316] = 10, [317] = 11,
    }

    local modifiedPerkMap = {
        [281] = { Type = PERK_MANA_LEECH, Value = interpolateModifiedValue(rank, 1, 8) / 100 },
        [282] = { Type = PERK_LIFE_LEECH, Value = interpolateModifiedValue(rank, 1, 16) / 100 },
        [283] = { Type = PERK_MANA_ON_HIT, Value = interpolateModifiedValue(rank, 2, 12) },
        [284] = { Type = PERK_LIFE_ON_HIT, Value = interpolateModifiedValue(rank, 5, 25) },
        [285] = { Type = PERK_MANA_ON_KILL, Value = interpolateModifiedValue(rank, 4, 24) },
        [286] = { Type = PERK_LIFE_ON_KILL, Value = interpolateModifiedValue(rank, 10, 50) },
        [287] = { Type = PERK_ALPHA_STRIKE_DAMAGE, Value = interpolateModifiedValue(rank, 2, 10) / 100 },
        [288] = { Type = PERK_OMEGA_STRIKE_DAMAGE, Value = interpolateModifiedValue(rank, 1, 4) / 100 },
        [321] = { Type = PERK_ARMOR_PENETRATION, Value = interpolateModifiedValue(rank, 5, 15) / 100 },
        [322] = { Type = PERK_ELEMENTAL_PIERCE, ElementId = 4, Value = interpolateModifiedValue(rank, 5, 15) / 100 },
        [323] = { Type = PERK_POWERFUL_FOE_DAMAGE, Value = interpolateModifiedValue(rank, 1, 5) / 100 },
    }

    local perkData = modifiedPerkMap[perkType]
    if not perkData and perkType >= 291 and perkType <= 297 then
        perkData = {
            Type = PERK_MELEE_SKILL_FLAT_DAMAGE,
            SkillId = skillByShapeId[perkType],
            Value = interpolateModifiedValue(rank, 15, 30) / 100,
        }
    elseif not perkData and perkType >= 301 and perkType <= 307 then
        perkData = {
            Type = PERK_SPELL_SKILL_FLAT_DAMAGE,
            SkillId = skillByShapeId[perkType],
            Value = interpolateModifiedValue(rank, 10, 25) / 100,
        }
    elseif not perkData and perkType >= 311 and perkType <= 317 then
        perkData = {
            Type = PERK_HEALING_SKILL_FLAT_DAMAGE,
            SkillId = skillByShapeId[perkType],
            Value = interpolateModifiedValue(rank, 10, 25) / 100,
        }
    end

    if not perkData and perkType < 251 then
        local region = math.floor(perkType / 50)
        local baseType = perkType - (region * 50)
        local regionSkill = ({ [1] = 8, [2] = 1, [3] = 1, [4] = 7, [5] = 9 })[region] or 10
        local regionElement = ({ [1] = 4, [2] = 32, [3] = 16, [4] = 4, [5] = 4 })[region] or 4
        local universalMap = {
            [1] = { Type = PERK_SHIELD_DEFENSE, Value = rank },
            [2] = { Type = PERK_WEAPON_DEFENSE, Value = rank },
            [3] = { Type = PERK_SKILL_BONUS, SkillId = regionSkill, Value = rank },
            [4] = { Type = PERK_MAGIC_BONUS, DamageType = regionElement, Value = rank },
            [11] = { Type = PERK_MELEE_CRITICAL_CHANCE, Value = interpolateModifiedValue(rank, 0.5, 2.5) / 100 },
            [12] = { Type = PERK_CRITICAL_DAMAGE, Value = interpolateModifiedValue(rank, 3, 30) / 100 },
            [13] = { Type = PERK_ELEMENTAL_CRITICAL_DAMAGE, ElementId = regionElement, Value = interpolateModifiedValue(rank, 2, 20) / 100 },
            [14] = { Type = PERK_RUNE_CRITICAL_DAMAGE, Value = interpolateModifiedValue(rank, 2, 20) / 100 },
            [15] = { Type = PERK_MELEE_CRITICAL_DAMAGE, Value = interpolateModifiedValue(rank, 3, 30) / 100 },
            [21] = { Type = PERK_LIFE_ON_KILL, Value = interpolateModifiedValue(rank, 10, 50) },
            [22] = { Type = PERK_PERFECT_SHOT, Range = 3, Value = interpolateModifiedValue(rank, 5, 25) },
            [23] = { Type = PERK_HIT_CHANCE, Value = interpolateModifiedValue(rank, 1, 5) / 100 },
            [24] = { Type = PERK_ATTACK_RANGE, Value = rank },
            [25] = { Type = PERK_MELEE_SKILL_FLAT_DAMAGE, SkillId = regionSkill, Value = interpolateModifiedValue(rank, 15, 30) / 100 },
        }
        perkData = universalMap[baseType]
    end

    if not perkData then
        return nil
    end

    perkData.ModifiedRank = rank
    perkData.ModifiedPerkType = perkType
    return perkData
end

local function getModifiedSlotFor(cacheData, levelIndex, perkIndex)
    local modifiedSlots = cacheData and cacheData.modifiedSlots or nil
    if type(modifiedSlots) ~= 'table' then
        return nil
    end

    for _, slot in ipairs(modifiedSlots) do
        if type(slot) == 'table' and slot.level == levelIndex and slot.perk == perkIndex then
            return slot
        end
    end

    return nil
end

local function slotsMatch(slot, levelIndex, perkIndex)
    return type(slot) == 'table' and slot.level == levelIndex and slot.perk == perkIndex
end

local function getActiveShapeSlot(cacheData)
    local activeSlot = WeaponProficiency.activeShapeSlot
    if activeSlot and activeSlot.itemId == WeaponProficiency.selectedItemId and getModifiedSlotFor(cacheData, activeSlot.level, activeSlot.perk) then
        return activeSlot
    end

    local modifiedSlots = cacheData and cacheData.modifiedSlots or nil
    if type(modifiedSlots) == 'table' and #modifiedSlots > 0 then
        return modifiedSlots[1]
    end

    return nil
end

local function getCurrentModifyCost()
    local cost = 250
    local selectedItemId = WeaponProficiency.selectedItemId
    local cacheData = selectedItemId and WeaponProficiency.cacheList[selectedItemId] or nil
    if cacheData and type(cacheData.modifiedSlots) == 'table' and #cacheData.modifiedSlots > 0 then
        cost = 1000
    end

    return cost
end

local function updateModifyCostLabel()
    if not WeaponProficiency.window then
        return
    end

    local costLabel = WeaponProficiency.window:recursiveGetChildById('modifyCostLabel')
    if not costLabel then
        return
    end

    costLabel:setText(tostring(getCurrentModifyCost()))
end

local function confirmProficiencyCost(title, message, onConfirm)
    local messageBox
    local okCallback = function()
        if messageBox then
            messageBox:ok()
        end
        if onConfirm then
            onConfirm()
        end
    end
    local cancelCallback = function()
        if messageBox then
            messageBox:cancel()
        end
    end

    messageBox = displayGeneralBox(
        tr(title),
        tr(message),
        {
            { text = tr('Ok'), callback = okCallback },
            { text = tr('Cancel'), callback = cancelCallback }
        },
        okCallback,
        cancelCallback
    )
end

local function updateModifyShapeButtons()
    if not WeaponProficiency.window then
        return
    end

    local modifyButton = WeaponProficiency.window:recursiveGetChildById('modifyActionButton')
    local shapeButton = WeaponProficiency.window:recursiveGetChildById('shapeActionButton')
    local costFrame = WeaponProficiency.window:recursiveGetChildById('modifyCostFrame')
    local selectedItemId = WeaponProficiency.selectedItemId
    local cacheData = selectedItemId and WeaponProficiency.cacheList[selectedItemId] or nil
    local hasModifiedSlots = cacheData and type(cacheData.modifiedSlots) == 'table' and #cacheData.modifiedSlots > 0
    local focusedPerk = WeaponProficiency.focusedPerk
    local activeShapeSlot = getActiveShapeSlot(cacheData)
    local selectedModifiedSlot = focusedPerk and activeShapeSlot and slotsMatch(activeShapeSlot, focusedPerk.level, focusedPerk.perk) and getModifiedSlotFor(cacheData, focusedPerk.level, focusedPerk.perk) or nil
    if modifyButton then
        modifyButton:setVisible(not hasModifiedSlots)
        modifyButton:setEnabled(not hasModifiedSlots and not WeaponProficiency.modifyRequestPending)
    end

    if costFrame then
        costFrame:setVisible(not hasModifiedSlots)
    end

    if shapeButton then
        shapeButton:setVisible(hasModifiedSlots)
        shapeButton:setEnabled(selectedModifiedSlot ~= nil)
        if selectedModifiedSlot then
            shapeButton:setTooltip('Shape the selected modified proficiency perk')
        else
            shapeButton:setTooltip('Select a modified proficiency perk first')
        end
    end

    updateModifyCostLabel()
end

local SHAPE_OPTIONS_TEST_ENTRIES = {
    {
        key = 'alpha_strike_extra_damage',
        name = 'Alpha Strike Extra Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '960 0',
        rank0Text = '+2.00% damage against targets above 95% hit points',
        rank10Text = '+10.00% damage against targets above 95% hit points',
    },
    {
        key = 'armor_penetration',
        name = 'Armor Penetration',
        imagePath = '/images/game/proficiency/new spells/Proficiency_Type_Armor_Penetration',
        imageClip = nil,
        rank0Text = '+5% armor penetration',
        rank10Text = '+15% armor penetration',
    },
    {
        key = 'auto_attack_critical_extra_damage',
        name = 'Auto-Attack Critical Extra Damage',
        imagePath = '/images/game/proficiency/icons-0',
        imageClip = '576 0',
        rank0Text = '+3.00% critical extra damage for auto-attacks',
        rank10Text = '+30.00% critical extra damage for auto-attacks',
    },
    {
        key = 'auto_attack_critical_hit_chance',
        name = 'Auto-Attack Critical Hit Chance',
        imagePath = '/images/game/proficiency/icons-0',
        imageClip = '384 0',
        rank0Text = '+0.50% critical hit chance for auto-attacks',
        rank10Text = '+2.50% critical hit chance for auto-attacks',
    },
    {
        key = 'bestiary_damage_amphibic',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '0 0',
        rank0Text = '+0.50% damage against Amphibic',
        rank10Text = '+2.50% damage against Amphibic',
    },
    {
        key = 'bestiary_damage_aquatic',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '64 0',
        rank0Text = '+0.50% damage against Aquatic',
        rank10Text = '+2.50% damage against Aquatic',
    },
    {
        key = 'bestiary_damage_bird',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '128 0',
        rank0Text = '+0.50% damage against Bird',
        rank10Text = '+2.50% damage against Bird',
    },
    {
        key = 'bestiary_damage_construct',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '192 0',
        rank0Text = '+0.50% damage against Construct',
        rank10Text = '+2.50% damage against Construct',
    },
    {
        key = 'bestiary_damage_demon',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '256 0',
        rank0Text = '+0.50% damage against Demon',
        rank10Text = '+2.50% damage against Demon',
    },
    {
        key = 'bestiary_damage_dragon',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '320 0',
        rank0Text = '+0.50% damage against Dragon',
        rank10Text = '+2.50% damage against Dragon',
    },
    {
        key = 'bestiary_damage_elemental',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '384 0',
        rank0Text = '+0.50% damage against Elemental',
        rank10Text = '+2.50% damage against Elemental',
    },
    {
        key = 'bestiary_damage_extra_dimensional',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '1216 0',
        rank0Text = '+0.50% damage against Extra Dimensional',
        rank10Text = '+2.50% damage against Extra Dimensional',
    },
    {
        key = 'bestiary_damage_fey',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '448 0',
        rank0Text = '+0.50% damage against Fey',
        rank10Text = '+2.50% damage against Fey',
    },
    {
        key = 'bestiary_damage_giant',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '512 0',
        rank0Text = '+0.50% damage against Giant',
        rank10Text = '+2.50% damage against Giant',
    },
    {
        key = 'bestiary_damage_human',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '576 0',
        rank0Text = '+0.50% damage against Human',
        rank10Text = '+2.50% damage against Human',
    },
    {
        key = 'bestiary_damage_humanoid',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '640 0',
        rank0Text = '+0.50% damage against Humanoid',
        rank10Text = '+2.50% damage against Humanoid',
    },
    {
        key = 'bestiary_damage_inkborn',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '1280 0',
        rank0Text = '+0.50% damage against Inkborn',
        rank10Text = '+2.50% damage against Inkborn',
    },
    {
        key = 'bestiary_damage_lycanthrope',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '704 0',
        rank0Text = '+0.50% damage against Lycanthrope',
        rank10Text = '+2.50% damage against Lycanthrope',
    },
    {
        key = 'bestiary_damage_magical',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '768 0',
        rank0Text = '+0.50% damage against Magical',
        rank10Text = '+2.50% damage against Magical',
    },
    {
        key = 'bestiary_damage_mammal',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '832 0',
        rank0Text = '+0.50% damage against Mammal',
        rank10Text = '+2.50% damage against Mammal',
    },
    {
        key = 'bestiary_damage_plant',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '896 0',
        rank0Text = '+0.50% damage against Plant',
        rank10Text = '+2.50% damage against Plant',
    },
    {
        key = 'bestiary_damage_reptile',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '960 0',
        rank0Text = '+0.50% damage against Reptile',
        rank10Text = '+2.50% damage against Reptile',
    },
    {
        key = 'bestiary_damage_slime',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '1024 0',
        rank0Text = '+0.50% damage against Slime',
        rank10Text = '+2.50% damage against Slime',
    },
    {
        key = 'bestiary_damage_undead',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '1088 0',
        rank0Text = '+0.50% damage against Undead',
        rank10Text = '+2.50% damage against Undead',
    },
    {
        key = 'bestiary_damage_vermin',
        name = 'Bestiary Damage',
        imagePath = '/images/game/proficiency/icons-3',
        imageClip = '1152 0',
        rank0Text = '+0.50% damage against Vermin',
        rank10Text = '+2.50% damage against Vermin',
    },
    {
        key = 'life_gain_on_hit',
        name = 'Life Gain on Hit',
        imagePath = '/images/game/proficiency/icons-0',
        imageClip = '768 0',
        rank0Text = '+5 hit points on hit',
        rank10Text = '+25 hit points on hit',
    },
    {
        key = 'life_gain_on_kill',
        name = 'Life Gain on Kill',
        imagePath = '/images/game/proficiency/icons-0',
        imageClip = '896 0',
        rank0Text = '+10 hit points on kill',
        rank10Text = '+50 hit points on kill',
    },
    {
        key = 'mana_gain_on_hit',
        name = 'Mana Gain on Hit',
        imagePath = '/images/game/proficiency/icons-0',
        imageClip = '832 0',
        rank0Text = '+2 mana on hit',
        rank10Text = '+12 mana on hit',
    },
    {
        key = 'mana_gain_on_kill',
        name = 'Mana Gain on Kill',
        imagePath = '/images/game/proficiency/icons-0',
        imageClip = '960 0',
        rank0Text = '+4 mana on kill',
        rank10Text = '+24 mana on kill',
    },
    {
        key = 'omega_strike_extra_damage',
        name = 'Omega Strike Extra Damage',
        imagePath = '/images/game/proficiency/new spells/Proficiency_Type_Omega_Dmg',
        imageClip = nil,
        rank0Text = '+1.00% damage against targets below 30% hit points',
        rank10Text = '+4.00% damage against targets below 30% hit points',
    },
    {
        key = 'rune_critical_extra_damage',
        name = 'Rune Critical Extra Damage',
        imagePath = '/images/game/proficiency/new spells/rune_critical_extra_damage',
        imageClip = nil,
        rank0Text = '+2.00% critical extra damage for offensive runes',
        rank10Text = '+20.00% critical extra damage for offensive runes',
    },
    {
        key = 'rune_critical_hit_chance',
        name = 'Rune Critical Hit Chance',
        imagePath = '/images/game/proficiency/new spells/rune_critical_hit_chance',
        imageClip = nil,
        rank0Text = '+0.50% critical hit chance for offensive runes',
        rank10Text = '+1.50% critical hit chance for offensive runes',
    },
    {
        key = 'skill_percentage_auto_attack_axe',
        name = 'Skill Percentage Auto-Attack Damage',
        imagePath = '/images/game/proficiency/icons-4',
        imageClip = '64 0',
        rank0Text = '+15.00% of your Axe Fighting as extra damage for auto-attacks',
        rank10Text = '+30.00% of your Axe Fighting as extra damage for auto-attacks',
    },
    {
        key = 'skill_percentage_auto_attack_club',
        name = 'Skill Percentage Auto-Attack Damage',
        imagePath = '/images/game/proficiency/icons-4',
        imageClip = '128 0',
        rank0Text = '+15.00% of your Club Fighting as extra damage for auto-attacks',
        rank10Text = '+30.00% of your Club Fighting as extra damage for auto-attacks',
    },
    {
        key = 'skill_percentage_auto_attack_distance',
        name = 'Skill Percentage Auto-Attack Damage',
        imagePath = '/images/game/proficiency/icons-4',
        imageClip = '384 0',
        rank0Text = '+15.00% of your Distance Fighting as extra damage for auto-attacks',
        rank10Text = '+30.00% of your Distance Fighting as extra damage for auto-attacks',
    },
    {
        key = 'skill_percentage_auto_attack_fist',
        name = 'Skill Percentage Auto-Attack Damage',
        imagePath = '/images/game/proficiency/icons-4',
        imageClip = '192 0',
        rank0Text = '+15.00% of your Fist Fighting as extra damage for auto-attacks',
        rank10Text = '+30.00% of your Fist Fighting as extra damage for auto-attacks',
    },
    {
        key = 'skill_percentage_auto_attack_magic_level',
        name = 'Skill Percentage Auto-Attack Damage',
        imagePath = '/images/game/proficiency/icons-4',
        imageClip = '256 0',
        rank0Text = '+15.00% of your Magic Level as extra damage for auto-attacks',
        rank10Text = '+30.00% of your Magic Level as extra damage for auto-attacks',
    },
    {
        key = 'skill_percentage_auto_attack_shielding',
        name = 'Skill Percentage Auto-Attack Damage',
        imagePath = '/images/game/proficiency/icons-4',
        imageClip = '320 0',
        rank0Text = '+15.00% of your Shielding as extra damage for auto-attacks',
        rank10Text = '+30.00% of your Shielding as extra damage for auto-attacks',
    },
    {
        key = 'skill_percentage_auto_attack_sword',
        name = 'Skill Percentage Auto-Attack Damage',
        imagePath = '/images/game/proficiency/icons-4',
        imageClip = '0 0',
        rank0Text = '+15.00% of your Sword Fighting as extra damage for auto-attacks',
        rank10Text = '+30.00% of your Sword Fighting as extra damage for auto-attacks',
    },
    {
        key = 'skill_percentage_spell_axe',
        name = 'Skill Percentage Spell Damage',
        imagePath = '/images/game/proficiency/icons-5',
        imageClip = '64 0',
        rank0Text = '+10.00% of your Axe Fighting as extra damage for your spells',
        rank10Text = '+25.00% of your Axe Fighting as extra damage for your spells',
    },
    {
        key = 'skill_percentage_spell_club',
        name = 'Skill Percentage Spell Damage',
        imagePath = '/images/game/proficiency/icons-5',
        imageClip = '128 0',
        rank0Text = '+10.00% of your Club Fighting as extra damage for your spells',
        rank10Text = '+25.00% of your Club Fighting as extra damage for your spells',
    },
    {
        key = 'skill_percentage_spell_distance',
        name = 'Skill Percentage Spell Damage',
        imagePath = '/images/game/proficiency/icons-5',
        imageClip = '384 0',
        rank0Text = '+10.00% of your Distance Fighting as extra damage for your spells',
        rank10Text = '+25.00% of your Distance Fighting as extra damage for your spells',
    },
    {
        key = 'skill_percentage_spell_fist',
        name = 'Skill Percentage Spell Damage',
        imagePath = '/images/game/proficiency/icons-5',
        imageClip = '192 0',
        rank0Text = '+10.00% of your Fist Fighting as extra damage for your spells',
        rank10Text = '+25.00% of your Fist Fighting as extra damage for your spells',
    },
    {
        key = 'skill_percentage_spell_magic_level',
        name = 'Skill Percentage Spell Damage',
        imagePath = '/images/game/proficiency/icons-5',
        imageClip = '256 0',
        rank0Text = '+10.00% of your Magic Level as extra damage for your spells',
        rank10Text = '+25.00% of your Magic Level as extra damage for your spells',
    },
    {
        key = 'skill_percentage_spell_shielding',
        name = 'Skill Percentage Spell Damage',
        imagePath = '/images/game/proficiency/icons-5',
        imageClip = '320 0',
        rank0Text = '+10.00% of your Shielding as extra damage for your spells',
        rank10Text = '+25.00% of your Shielding as extra damage for your spells',
    },
    {
        key = 'skill_percentage_spell_sword',
        name = 'Skill Percentage Spell Damage',
        imagePath = '/images/game/proficiency/icons-5',
        imageClip = '0 0',
        rank0Text = '+10.00% of your Sword Fighting as extra damage for your spells',
        rank10Text = '+25.00% of your Sword Fighting as extra damage for your spells',
    },
    {
        key = 'skill_percentage_healing_axe',
        name = 'Skill Percentage Spell Healing',
        imagePath = '/images/game/proficiency/icons-6',
        imageClip = '64 0',
        rank0Text = '+10.00% of your Axe Fighting as extra healing for your spells, except heal-over-time spells',
        rank10Text = '+25.00% of your Axe Fighting as extra healing for your spells, except heal-over-time spells',
    },
    {
        key = 'skill_percentage_healing_club',
        name = 'Skill Percentage Spell Healing',
        imagePath = '/images/game/proficiency/icons-6',
        imageClip = '128 0',
        rank0Text = '+10.00% of your Club Fighting as extra healing for your spells, except heal-over-time spells',
        rank10Text = '+25.00% of your Club Fighting as extra healing for your spells, except heal-over-time spells',
    },
    {
        key = 'skill_percentage_healing_distance',
        name = 'Skill Percentage Spell Healing',
        imagePath = '/images/game/proficiency/icons-6',
        imageClip = '384 0',
        rank0Text = '+10.00% of your Distance Fighting as extra healing for your spells, except heal-over-time spells',
        rank10Text = '+25.00% of your Distance Fighting as extra healing for your spells, except heal-over-time spells',
    },
    {
        key = 'skill_percentage_healing_fist',
        name = 'Skill Percentage Spell Healing',
        imagePath = '/images/game/proficiency/icons-6',
        imageClip = '192 0',
        rank0Text = '+10.00% of your Fist Fighting as extra healing for your spells, except heal-over-time spells',
        rank10Text = '+25.00% of your Fist Fighting as extra healing for your spells, except heal-over-time spells',
    },
    {
        key = 'skill_percentage_healing_magic_level',
        name = 'Skill Percentage Spell Healing',
        imagePath = '/images/game/proficiency/icons-6',
        imageClip = '256 0',
        rank0Text = '+10.00% of your Magic Level as extra healing for your spells, except heal-over-time spells',
        rank10Text = '+25.00% of your Magic Level as extra healing for your spells, except heal-over-time spells',
    },
    {
        key = 'skill_percentage_healing_shielding',
        name = 'Skill Percentage Spell Healing',
        imagePath = '/images/game/proficiency/icons-6',
        imageClip = '320 0',
        rank0Text = '+10.00% of your Shielding as extra healing for your spells, except heal-over-time spells',
        rank10Text = '+25.00% of your Shielding as extra healing for your spells, except heal-over-time spells',
    },
    {
        key = 'skill_percentage_healing_sword',
        name = 'Skill Percentage Spell Healing',
        imagePath = '/images/game/proficiency/icons-6',
        imageClip = '0 0',
        rank0Text = '+10.00% of your Sword Fighting as extra healing for your spells, except heal-over-time spells',
        rank10Text = '+25.00% of your Sword Fighting as extra healing for your spells, except heal-over-time spells',
    },
    {
        key = 'spell_augment_berserk_base_damage',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '704 0',
        augmentClip = '192 0',
        rank0Text = '+1% base damage for Berserk',
        rank10Text = '+5% base damage for Berserk',
    },
    {
        key = 'spell_augment_berserk_critical_damage',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '704 0',
        augmentClip = '224 0',
        rank0Text = '+5% critical extra damage for Berserk',
        rank10Text = '+30% critical extra damage for Berserk',
    },
    {
        key = 'spell_augment_berserk_critical_chance',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '704 0',
        augmentClip = '224 0',
        rank0Text = '+1% critical hit chance for Berserk',
        rank10Text = '+5% critical hit chance for Berserk',
    },
    {
        key = 'spell_augment_berserk_life_leech',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '704 0',
        augmentClip = '352 0',
        rank0Text = '+1% life leech for Berserk',
        rank10Text = '+16% life leech for Berserk',
    },
    {
        key = 'spell_augment_berserk_mana_leech',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '704 0',
        augmentClip = '384 0',
        rank0Text = '+1% mana leech for Berserk',
        rank10Text = '+8% mana leech for Berserk',
    },
    {
        key = 'spell_augment_executioners_throw_base_damage',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '384 128',
        augmentClip = '192 0',
        rank0Text = "+1% base damage for Executioner's Throw",
        rank10Text = "+5% base damage for Executioner's Throw",
    },
    {
        key = 'spell_augment_executioners_throw_critical_damage',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '384 128',
        augmentClip = '224 0',
        rank0Text = "+5% critical extra damage for Executioner's Throw",
        rank10Text = "+30% critical extra damage for Executioner's Throw",
    },
    {
        key = 'spell_augment_executioners_throw_critical_chance',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '384 128',
        augmentClip = '224 0',
        rank0Text = "+1% critical hit chance for Executioner's Throw",
        rank10Text = "+5% critical hit chance for Executioner's Throw",
    },
    {
        key = 'spell_augment_executioners_throw_life_leech',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '384 128',
        augmentClip = '352 0',
        rank0Text = "+1% life leech for Executioner's Throw",
        rank10Text = "+16% life leech for Executioner's Throw",
    },
    {
        key = 'spell_augment_executioners_throw_mana_leech',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '384 128',
        augmentClip = '384 0',
        rank0Text = "+1% mana leech for Executioner's Throw",
        rank10Text = "+8% mana leech for Executioner's Throw",
    },
    {
        key = 'spell_augment_fierce_berserk_base_damage',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '1024 0',
        augmentClip = '192 0',
        rank0Text = '+1% base damage for Fierce Berserk',
        rank10Text = '+5% base damage for Fierce Berserk',
    },
    {
        key = 'spell_augment_fierce_berserk_critical_damage',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '1024 0',
        augmentClip = '224 0',
        rank0Text = '+5% critical extra damage for Fierce Berserk',
        rank10Text = '+30% critical extra damage for Fierce Berserk',
    },
    {
        key = 'spell_augment_fierce_berserk_critical_chance',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '1024 0',
        augmentClip = '224 0',
        rank0Text = '+1% critical hit chance for Fierce Berserk',
        rank10Text = '+5% critical hit chance for Fierce Berserk',
    },
    {
        key = 'spell_augment_fierce_berserk_life_leech',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '1024 0',
        augmentClip = '352 0',
        rank0Text = '+1% life leech for Fierce Berserk',
        rank10Text = '+16% life leech for Fierce Berserk',
    },
    {
        key = 'spell_augment_fierce_berserk_mana_leech',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '1024 0',
        augmentClip = '384 0',
        rank0Text = '+1% mana leech for Fierce Berserk',
        rank10Text = '+8% mana leech for Fierce Berserk',
    },
    {
        key = 'spell_augment_front_sweep_base_damage',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '512 0',
        augmentClip = '192 0',
        rank0Text = '+1% base damage for Front Sweep',
        rank10Text = '+5% base damage for Front Sweep',
    },
    {
        key = 'spell_augment_front_sweep_critical_damage',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '512 0',
        augmentClip = '224 0',
        rank0Text = '+5% critical extra damage for Front Sweep',
        rank10Text = '+30% critical extra damage for Front Sweep',
    },
    {
        key = 'spell_augment_front_sweep_critical_chance',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '512 0',
        augmentClip = '224 0',
        rank0Text = '+1% critical hit chance for Front Sweep',
        rank10Text = '+5% critical hit chance for Front Sweep',
    },
    {
        key = 'spell_augment_front_sweep_life_leech',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '512 0',
        augmentClip = '352 0',
        rank0Text = '+1% life leech for Front Sweep',
        rank10Text = '+16% life leech for Front Sweep',
    },
    {
        key = 'spell_augment_front_sweep_mana_leech',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '512 0',
        augmentClip = '384 0',
        rank0Text = '+1% mana leech for Front Sweep',
        rank10Text = '+8% mana leech for Front Sweep',
    },
    {
        key = 'spell_augment_groundshaker_base_damage',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '1088 0',
        augmentClip = '192 0',
        rank0Text = '+1% base damage for Groundshaker',
        rank10Text = '+5% base damage for Groundshaker',
    },
    {
        key = 'spell_augment_groundshaker_critical_damage',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '1088 0',
        augmentClip = '224 0',
        rank0Text = '+5% critical extra damage for Groundshaker',
        rank10Text = '+30% critical extra damage for Groundshaker',
    },
    {
        key = 'spell_augment_groundshaker_critical_chance',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '1088 0',
        augmentClip = '224 0',
        rank0Text = '+1% critical hit chance for Groundshaker',
        rank10Text = '+5% critical hit chance for Groundshaker',
    },
    {
        key = 'spell_augment_groundshaker_life_leech',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '1088 0',
        augmentClip = '352 0',
        rank0Text = '+1% life leech for Groundshaker',
        rank10Text = '+16% life leech for Groundshaker',
    },
    {
        key = 'spell_augment_groundshaker_mana_leech',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/icons-9',
        imageClip = '1088 0',
        augmentClip = '384 0',
        rank0Text = '+1% mana leech for Groundshaker',
        rank10Text = '+8% mana leech for Groundshaker',
    },
    {
        key = 'spell_augment_shield_slam_base_damage',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/new spells/Shield_Slam',
        imageClip = nil,
        augmentClip = '192 0',
        rank0Text = '+1% base damage for Shield Slam',
        rank10Text = '+5% base damage for Shield Slam',
    },
    {
        key = 'spell_augment_shield_slam_critical_damage',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/new spells/Shield_Slam',
        imageClip = nil,
        augmentClip = '224 0',
        rank0Text = '+5% critical extra damage for Shield Slam',
        rank10Text = '+30% critical extra damage for Shield Slam',
    },
    {
        key = 'spell_augment_shield_slam_critical_chance',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/new spells/Shield_Slam',
        imageClip = nil,
        augmentClip = '224 0',
        rank0Text = '+1% critical hit chance for Shield Slam',
        rank10Text = '+5% critical hit chance for Shield Slam',
    },
    {
        key = 'spell_augment_shield_slam_life_leech',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/new spells/Shield_Slam',
        imageClip = nil,
        augmentClip = '352 0',
        rank0Text = '+1% life leech for Shield Slam',
        rank10Text = '+16% life leech for Shield Slam',
    },
    {
        key = 'spell_augment_shield_slam_mana_leech',
        name = 'Spell Augment',
        imagePath = '/images/game/proficiency/new spells/Shield_Slam',
        imageClip = nil,
        augmentClip = '384 0',
        rank0Text = '+1% mana leech for Shield Slam',
        rank10Text = '+8% mana leech for Shield Slam',
    },
}

local function setShapeOptionsRowBackground(row, isAlternate)
    if not row then
        return
    end

    local backgroundColor = isAlternate and '#414141' or '#484848'
    local perkCell = row:recursiveGetChildById('perkCell')

    if perkCell then
        perkCell:setBackgroundColor(backgroundColor)
    end
end

local function setShapeOptionsEntryVisual(row, entry, index)
    if not row or not entry then
        return
    end

    setShapeOptionsRowBackground(row, index and index % 2 == 0)

    local perkName = row:recursiveGetChildById('perkName')
    local perkIcon = row:recursiveGetChildById('perkIcon')
    local perkAugmentIcon = row:recursiveGetChildById('perkAugmentIcon')
    local rank0Text = row:recursiveGetChildById('rank0Text')
    local rank10Text = row:recursiveGetChildById('rank10Text')

    if perkName then
        perkName:setText(entry.name or '')
        perkName:setTooltip(entry.name or '')
    end

    if perkIcon then
        perkIcon:setImageSource(entry.imagePath or '/images/game/proficiency/icons-0')
        if entry.imageClip then
            local clipX, clipY = parseImageClipString(entry.imageClip)
            perkIcon:setImageAutoResize(false)
            perkIcon:setImageClip({ x = clipX, y = clipY, width = 64, height = 64 })
        else
            perkIcon:setImageAutoResize(true)
            perkIcon:setImageClip(nil)
        end
    end

    if perkAugmentIcon then
        if entry.augmentClip then
            local clipX = tonumber(tostring(entry.augmentClip):match("(%-?%d+)")) or 0
            perkAugmentIcon:setImageClip({ x = clipX, y = 0, width = 32, height = 32 })
            perkAugmentIcon:setVisible(true)
        else
            perkAugmentIcon:setVisible(false)
        end
    end

    if rank0Text then
        rank0Text:setText(entry.rank0Text or '')
        rank0Text:setTooltip(entry.rank0Text or '')
    end

    if rank10Text then
        rank10Text:setText(entry.rank10Text or '')
        rank10Text:setTooltip(entry.rank10Text or '')
    end
end

local function collectShapeOptionsEntries(shapeContext)
    local testEntries = {}
    for _, entry in ipairs(SHAPE_OPTIONS_TEST_ENTRIES) do
        local copy = cloneTableShallow(entry)
        copy.searchText = string.lower(string.format('%s %s %s', copy.name or '', copy.rank0Text or '', copy.rank10Text or ''))
        table.insert(testEntries, copy)
    end
    return testEntries
end

function WeaponProficiency:refreshShapeOptionsList(searchText)
    if not self.shapeOptionsWindow then
        return
    end

    local listPanel = self.shapeOptionsWindow:recursiveGetChildById('shapeOptionsList')
    if not listPanel then
        return
    end

    listPanel:destroyChildren()

    local query = normalizeSearchText(searchText)
    local visibleIndex = 0
    for _, entry in ipairs(self.shapeOptionsEntries or {}) do
        if query == '' or string.find(entry.searchText or '', query, 1, true) then
            visibleIndex = visibleIndex + 1
            local row = g_ui.createWidget('ShapeOptionsRow', listPanel)
            setShapeOptionsEntryVisual(row, entry, visibleIndex)
        end
    end
end

local function focusWeaponProficiencySearchInput()
    if not WeaponProficiency.window or not WeaponProficiency.window:isVisible() then
        return
    end

    local searchText = WeaponProficiency.window:recursiveGetChildById('searchText')
    if not searchText then
        return
    end

    local consoleModule = modules.game_console
    if not consoleModule or not consoleModule.claimKeyboardFocus then
        return
    end

    weaponProficiencyKeyboardFocusClaimId = consoleModule.claimKeyboardFocus(WeaponProficiency.window, {
        target = searchText,
        editable = true,
        cursorToEnd = true,
        name = "weapon_proficiency_search"
    })
end

local function releaseWeaponProficiencyKeyboardFocus(options)
    local consoleModule = modules.game_console
    if consoleModule and consoleModule.releaseKeyboardFocus and weaponProficiencyKeyboardFocusClaimId then
        consoleModule.releaseKeyboardFocus(weaponProficiencyKeyboardFocusClaimId, options)
        weaponProficiencyKeyboardFocusClaimId = nil
    end
end

local function restoreWeaponProficiencyNavigationFocus()
    if modules.game_console and modules.game_console.restoreChatFocus and modules.game_console.isChatEnabled and
        modules.game_console.isChatEnabled() then
        modules.game_console.restoreChatFocus()
    elseif modules.game_interface and modules.game_interface.getRootPanel then
        modules.game_interface.getRootPanel():focus()
    end
end

local function setWeaponProficiencySearchEnabled(enabled)
    if not WeaponProficiency.window then
        return
    end

    local searchText = WeaponProficiency.window:recursiveGetChildById('searchText')
    if not searchText then
        return
    end

    searchText:setEnabled(enabled)
    if searchText.setEditable then
        searchText:setEditable(enabled)
    end

    if not enabled and searchText.ungrabKeyboard then
        searchText:ungrabKeyboard()
    end
end

function init()
    -- Load proficiency JSON data
    ProficiencyData:loadProficiencyJson()
    
    -- Create item cache from market data
    WeaponProficiency:createItemCache()
    
    -- Connect to game events
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onWeaponProficiency = onWeaponProficiency,
        onWeaponProficiencyExperience = onWeaponProficiencyExperience,
        onWeaponProficiencyReshapeOffers = onWeaponProficiencyReshapeOffers
    })

    initMainPanelProficiencyButton()

    if g_game.isOnline() then
        onGameStart()
    end
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onWeaponProficiency = onWeaponProficiency,
        onWeaponProficiencyExperience = onWeaponProficiencyExperience,
        onWeaponProficiencyReshapeOffers = onWeaponProficiencyReshapeOffers
    })
    
    if proficiencyButton then
        proficiencyButton:destroy()
        proficiencyButton = nil
    end
    WeaponProficiency.button = nil

    if WeaponProficiency.window then
        local consoleModule = modules.game_console
        if consoleModule and consoleModule.releaseKeyboardFocus and weaponProficiencyKeyboardFocusClaimId then
            consoleModule.releaseKeyboardFocus(weaponProficiencyKeyboardFocusClaimId, { restoreChat = false })
            weaponProficiencyKeyboardFocusClaimId = nil
        end
        WeaponProficiency.window:destroy()
        WeaponProficiency.window = nil
    end

    if WeaponProficiency.shapeWindow then
        WeaponProficiency.shapeWindow:destroy()
        WeaponProficiency.shapeWindow = nil
    end

    if WeaponProficiency.reshapeWindow then
        WeaponProficiency.reshapeWindow:destroy()
        WeaponProficiency.reshapeWindow = nil
    end

    if WeaponProficiency.shapeOptionsWindow then
        WeaponProficiency.shapeOptionsWindow:destroy()
        WeaponProficiency.shapeOptionsWindow = nil
    end
end

function onGameStart()
    WeaponProficiency.allProficiencyRequested = false
    WeaponProficiency.saveWeaponMissing = false
    WeaponProficiency.firstItemRequested = nil
    WeaponProficiency.cacheList = {}
    WeaponProficiency.currentEquippedExp = 0
    WeaponProficiency.currentEquippedMaxExp = 0
    
    -- Recreate item cache on each login (may have been cleared by reset())
    WeaponProficiency:createItemCache()
    
    initMainPanelProficiencyButton()
    
    -- Initialize topbar proficiency widget
    initTopBarProficiency()
end

local proficiencyButton = nil

function initMainPanelProficiencyButton(attempts)
    attempts = attempts or 0

    if not modules.game_mainpanel or not modules.game_mainpanel.addToggleButton then
        if attempts < 20 then
            scheduleEvent(function() initMainPanelProficiencyButton(attempts + 1) end, 250)
        end
        return
    end

    if proficiencyButton and not proficiencyButton:isDestroyed() then
        proficiencyButton:setVisible(true)
        proficiencyButton:setOn(false)
        WeaponProficiency.button = proficiencyButton
        return
    end

    proficiencyButton = modules.game_mainpanel.addToggleButton(
        'ProficiencyButton',
        tr('Open Weapon Proficiency'),
        '/images/options/button_proficiency',
        function() toggle() end,
        false,
        22
    )

    if not proficiencyButton then
        if attempts < 20 then
            scheduleEvent(function() initMainPanelProficiencyButton(attempts + 1) end, 250)
        end
        return
    end

    proficiencyButton.index = 22
    proficiencyButton:setVisible(true)
    proficiencyButton:setOn(false)
    WeaponProficiency.button = proficiencyButton

    if modules.game_mainpanel then
        if modules.game_mainpanel.initControlButtons then
            modules.game_mainpanel.initControlButtons()
        end
        if modules.game_mainpanel.reloadMainPanelSizes then
            modules.game_mainpanel.reloadMainPanelSizes()
        end
    end
end

-- Initialize the proficiency widget in the top stats bar
function initTopBarProficiency(attempts)
    attempts = attempts or 0
    local maxRetries = 15
    
    -- Delay initialization to ensure StatsBar is fully loaded
    scheduleEvent(function()
        -- Access StatsBar through modules.game_interface
        local StatsBarModule = modules.game_interface and modules.game_interface.StatsBar
        if not StatsBarModule then 
            if attempts < maxRetries then
                scheduleEvent(initTopBarProficiency, 500, attempts + 1)
            end
            return 
        end
        
        local statsBar = StatsBarModule.getCurrentStatsBarWithPosition and StatsBarModule.getCurrentStatsBarWithPosition()
        if statsBar then
            local profWidget = statsBar:recursiveGetChildById('proficiencyTopBar')
            if profWidget then
                local shouldShow = g_game.getClientVersion() >= 1500
                profWidget:setVisible(shouldShow)
                
                if shouldShow then
                    -- Request proficiency data for equipped weapon
                    local player = g_game.getLocalPlayer()
                    if player then
                        local leftSlotItem = player:getInventoryItem(InventorySlotLeft)
                        if leftSlotItem and g_game.sendWeaponProficiencyAction then
                            local itemId = leftSlotItem:getId()
                            g_game.sendWeaponProficiencyAction(0, itemId)
                        end
                    end
                    updateTopBarProficiency()
                end
            end
        else
            if attempts < maxRetries then
                scheduleEvent(initTopBarProficiency, 500, attempts + 1)
            end
        end
    end, 500) -- 500ms delay
end

-- Update the proficiency progress bar in the top bar
function updateTopBarProficiency()
    -- Access StatsBar through modules.game_interface
    local StatsBarModule = modules.game_interface and modules.game_interface.StatsBar
    if not StatsBarModule then return end
    
    local statsBar = StatsBarModule.getCurrentStatsBarWithPosition and StatsBarModule.getCurrentStatsBarWithPosition()
    if not statsBar then return end
    
    local profWidget = statsBar:recursiveGetChildById('proficiencyTopBar')
    if not profWidget then return end
    
    -- Get equipped weapon
    local player = g_game.getLocalPlayer()
    if not player then return end
    
    local leftSlotItem = player:getInventoryItem(InventorySlotLeft)
    if not leftSlotItem then
        -- No weapon equipped - show 0%
        local progressBar = profWidget:getChildById('proficiencyProgress')
        local label = profWidget:getChildById('proficiencyLabel')
        if progressBar then progressBar:setPercent(0) end
        if label then label:setText('0%') end
        return
    end
    
    local itemId = leftSlotItem:getId()
    local cacheData = WeaponProficiency.cacheList[itemId]
    
    if cacheData then
        local exp = cacheData.exp or 0
        
        -- Get thingType for calculations
        local thingType = nil
        if leftSlotItem.getThingType then
            thingType = leftSlotItem:getThingType()
        end
        
        -- Calculate percent for next level (not total)
        local percent = 0
        local currentLevel = 0
        local nextLevelExp = 0
        local currentLevelExp = 0
        
        if ProficiencyData and ProficiencyData.getCurrentLevelByExp and ProficiencyData.getLevelPercent then
            -- Get current level
            currentLevel = ProficiencyData:getCurrentLevelByExp(leftSlotItem, exp, false, thingType) or 0
            -- Get percent progress to next level
            local nextLevel = currentLevel + 1
            percent = ProficiencyData:getLevelPercent(exp, nextLevel, leftSlotItem, thingType) or 0
            
            -- Get exp values for tooltip
            if ProficiencyData.getMaxExperienceByLevel then
                currentLevelExp = currentLevel > 0 and (ProficiencyData:getMaxExperienceByLevel(currentLevel, leftSlotItem, thingType) or 0) or 0
                nextLevelExp = ProficiencyData:getMaxExperienceByLevel(nextLevel, leftSlotItem, thingType) or 0
            end
        end
        
        percent = math.min(100, math.max(0, percent))
        
        local progressBar = profWidget:getChildById('proficiencyProgress')
        local label = profWidget:getChildById('proficiencyLabel')
        local bg = profWidget:getChildById('proficiencyBg')
        
        if progressBar then progressBar:setPercent(percent) end
        if label then label:setText(percent .. '%') end
        if bg then 
            local expInLevel = exp - currentLevelExp
            local expNeeded = nextLevelExp - currentLevelExp
            bg:setTooltip(string.format("Proficiency Progress: %s / %s", tostring(expInLevel), tostring(expNeeded))) 
        end
        
        -- Show/hide highlight based on unused perk
        local highlight = profWidget:getChildById('highlightProficiencyButton')
        if highlight then
            highlight:setVisible(WeaponProficiency.hasUnusedPerk == true)
        end
        -- Official status bar: the tree icon lights up while a perk can be chosen.
        local icon = profWidget:getChildById('proficiencyIcon')
        if icon then
            local available = WeaponProficiency.hasUnusedPerk == true
            icon:setOn(available)
            icon:setPhantom(not available)
            icon:setTooltip(available and tr("New perks are available for your current weapon's Proficiency!") or '')
        end
        
        -- Store for reference
        WeaponProficiency.currentEquippedExp = exp
        WeaponProficiency.currentEquippedMaxExp = nextLevelExp
    else
        -- No cache data yet - request it
        if g_game.sendWeaponProficiencyAction then
            g_game.sendWeaponProficiencyAction(0, itemId)
        end
    end
end

function onGameEnd()
    if WeaponProficiency.window then
        WeaponProficiency.window:hide()
    end
    
    if WeaponProficiency.button then
        local btn = WeaponProficiency.button:getChildById('button') or WeaponProficiency.button
        if btn then
            btn:setOn(false)
        end
    end
    
    WeaponProficiency:reset()
end

-- Called when server sends proficiency info (opcode 0xC4)
function onWeaponProficiency(itemId, experience, perks, marketCategory, modifiedSlots)
    if WeaponProficiency.modifyRequestPending and WeaponProficiency.pendingModifySlot and WeaponProficiency.pendingModifySlot.itemId == itemId then
        WeaponProficiency.modifyRequestPending = false
    end

    -- Ensure perks is a table
    if type(perks) ~= "table" then
        perks = {}
    end
    if type(modifiedSlots) ~= "table" then
        modifiedSlots = {}
    end
    
    -- IMPORTANT: Server sends perks in 0-indexed format, convert to 1-indexed for Lua
    -- Also filter out invalid perks (values >= 200 are clearly invalid, likely from uninitialized data)
    local convertedPerks = {}
    for _, perk in ipairs(perks) do
        if type(perk) == "table" and #perk >= 2 then
            local level = perk[1]
            local perkPos = perk[2]
            -- Filter out invalid values (255 becomes 256 after +1, which is invalid)
            -- Valid levels are 0-6 (0-indexed), valid perk positions are 0-2 (0-indexed)
            if level >= 0 and level <= 10 and perkPos >= 0 and perkPos <= 10 then
                -- Convert from 0-indexed (server) to 1-indexed (Lua)
                table.insert(convertedPerks, {level + 1, perkPos + 1})
            end
        end
    end

    local convertedModifiedSlots = {}
    for _, slot in ipairs(modifiedSlots) do
        if type(slot) == "table" and #slot >= 4 then
            local level = tonumber(slot[1])
            local perkPos = tonumber(slot[2])
            local perkType = tonumber(slot[3])
            local rank = tonumber(slot[4])
            if level and perkPos and perkType and rank then
                table.insert(convertedModifiedSlots, {
                    level = level + 1,
                    perk = perkPos + 1,
                    perkType = perkType,
                    rank = rank,
                })
            end
        end
    end
    
    -- Always trust server state for perks
    WeaponProficiency.cacheList[itemId] = { exp = experience, perks = convertedPerks, modifiedSlots = convertedModifiedSlots }
    local cachePerks = WeaponProficiency.cacheList[itemId].perks
    local pendingModifySlot = WeaponProficiency.pendingModifySlot
    if pendingModifySlot and pendingModifySlot.itemId == itemId and getModifiedSlotFor(WeaponProficiency.cacheList[itemId], pendingModifySlot.level, pendingModifySlot.perk) then
        WeaponProficiency.activeShapeSlot = { itemId = itemId, level = pendingModifySlot.level, perk = pendingModifySlot.perk }
        WeaponProficiency.pendingModifySlot = nil
    elseif #convertedModifiedSlots > 0 then
        local currentActive = WeaponProficiency.activeShapeSlot
        if not currentActive or not getModifiedSlotFor(WeaponProficiency.cacheList[itemId], currentActive.level, currentActive.perk) then
            WeaponProficiency.activeShapeSlot = { itemId = itemId, level = convertedModifiedSlots[1].level, perk = convertedModifiedSlots[1].perk }
        end
    else
        WeaponProficiency.activeShapeSlot = nil
        WeaponProficiency.pendingModifySlot = nil
    end
    
    -- Re-sort the item list when we receive new proficiency data
    if marketCategory then
        sortWeaponProficiency(marketCategory)
        sortWeaponProficiency(MarketCategory.WeaponsAll)
    end
    
    if WeaponProficiency.window and WeaponProficiency.window:isVisible() then
        -- Refresh item list to update stars and order
        WeaponProficiency:refreshItemList()
        
        WeaponProficiency:onUpdateSelectedProficiency(itemId)
        
        -- If this is the currently selected item, update display with cached perks
        if WeaponProficiency.selectedItemId == itemId then
            WeaponProficiency:displayProficiencyData(itemId, experience, cachePerks)
            updateModifyShapeButtons()
        end
    end

    if WeaponProficiency.shapeWindow and WeaponProficiency.shapeWindow:isVisible() and
        WeaponProficiency.shapeContext and WeaponProficiency.shapeContext.selectedItemId == itemId then
        showShapeWindow(WeaponProficiency.shapeContext)
    end
    
    -- Update top bar proficiency display
    updateTopBarProficiency()
end

function onWeaponProficiencyReshapeOffers(itemId, level0, perk0, offers)
    local convertedOffers = {}
    if type(offers) == 'table' then
        for _, offer in ipairs(offers) do
            local perkType = nil
            local rank = nil
            if type(offer) == 'table' then
                perkType = tonumber(offer[1] or offer.perkType)
                rank = tonumber(offer[2] or offer.rank)
            end

            if perkType then
                table.insert(convertedOffers, {
                    perkType = perkType,
                    rank = rank or 1
                })
            end
        end
    end

    if #convertedOffers == 0 then
        if modules and modules.game_textmessage and modules.game_textmessage.displayFailureMessage then
            modules.game_textmessage.displayFailureMessage('No reshape offers available.')
        end
        return
    end

    WeaponProficiency:showReshapeWindow(convertedOffers, {
        itemId = itemId,
        level = (tonumber(level0) or 0) + 1,
        perk = (tonumber(perk0) or 0) + 1
    })
end

-- Called when server sends proficiency experience update (opcode 0x5C)
function onWeaponProficiencyExperience(itemId, experience, hasUnusedPerk)
    local itemCache = WeaponProficiency.cacheList[itemId]
    if not itemCache then
        WeaponProficiency.cacheList[itemId] = { exp = experience, perks = {} }
    else
        if experience > 0 then
            itemCache.exp = experience
        end
    end
    
    -- Re-sort all categories when experience changes
    sortWeaponProficiency(MarketCategory.WeaponsAll)
    for _, categoryId in pairs(WeaponProficiency.ItemCategory) do
        sortWeaponProficiency(categoryId)
    end
    
    -- Store the unused perk state globally
    WeaponProficiency.hasUnusedPerk = hasUnusedPerk
    
    -- Show/hide highlight on proficiency button based on unused perks
    updateProficiencyHighlight()
    
    -- Refresh item list if window is visible
    if WeaponProficiency.window and WeaponProficiency.window:isVisible() then
        WeaponProficiency:refreshItemList()
    end
    
    -- Update top bar proficiency display
    updateTopBarProficiency()
end

-- Update the proficiency button highlight based on unused perk state
function updateProficiencyHighlight()
    if WeaponProficiency.button then
        local highlight = WeaponProficiency.button:getChildById('highlight')
        local bright = WeaponProficiency.button:getChildById('brightButton')
        local shouldShow = WeaponProficiency.hasUnusedPerk == true
        if highlight then highlight:setVisible(shouldShow) end
        if bright then bright:setVisible(shouldShow) end
    end
end

-- Public function to open the proficiency window
function show()
    if not WeaponProficiency.window then
        createWindow()
    end
    
    -- Reset search filter and clear search text
    WeaponProficiency.searchFilter = nil
    local searchText = WeaponProficiency.window:recursiveGetChildById('searchText')
    if searchText then
        searchText:setText('')
    end
    
    -- Reset filter buttons visual state (but keep filter state)
    -- The filters persist across open/close
    
    WeaponProficiency.window:show()
    WeaponProficiency.window:raise()
    WeaponProficiency.window:focus()
    setWeaponProficiencySearchEnabled(true)
    releaseWeaponProficiencyKeyboardFocus({ restoreChat = false })
    
    -- Update button state (for highlight widget, use child button)
    if WeaponProficiency.button then
        local btn = WeaponProficiency.button:getChildById('button') or WeaponProficiency.button
        if btn then
            btn:setOn(true)
        end
        -- Hide highlight when window is opened
        local highlight = WeaponProficiency.button:getChildById('highlight')
        local bright = WeaponProficiency.button:getChildById('brightButton')
        if highlight then highlight:setVisible(false) end
        if bright then bright:setVisible(false) end
    end
    
    -- Refresh item list to show all items
    WeaponProficiency:refreshItemList()
    
    -- Auto-select item when window opens (equipped weapon or first in list)
    -- Use longer delay to ensure items are loaded, with retry
    WeaponProficiency.autoSelectRetries = 0
    scheduleEvent(function()
        autoSelectItem()
    end, 300)
end

-- Auto-select an item (equipped weapon or first in list)
function autoSelectItem()
    if not WeaponProficiency.window or not WeaponProficiency.window:isVisible() then
        return
    end
    
    -- Already has a selected item with perks displayed? Skip
    if WeaponProficiency.selectedMarketItem and WeaponProficiency.selectedMarketItem.displayItem then
        local perkPanel = WeaponProficiency.perkPanel
        if perkPanel and perkPanel:getChildCount() > 0 then
            return
        end
    end
    
    local targetItemId = nil
    local targetMarketItem = nil
    
    -- Get all items from all categories
    local allItems = WeaponProficiency.itemList[MarketCategory.WeaponsAll] or {}
    
    -- First, check if player has an equipped weapon
    local player = g_game.getLocalPlayer()
    if player then
        local leftSlotItem = player:getInventoryItem(InventorySlotLeft)
        if leftSlotItem then
            local equippedId = leftSlotItem:getId()
            -- Search for this item in our list
            for _, marketItem in ipairs(allItems) do
                local itemId = marketItem.originalId or (marketItem.displayItem and marketItem.displayItem:getId())
                local displayId = marketItem.displayId or itemId
                if itemId == equippedId or displayId == equippedId then
                    targetItemId = itemId
                    targetMarketItem = marketItem
                    break
                end
            end
        end
    end
    
    -- If no equipped weapon found, select first item from the allItems list
    if not targetItemId and #allItems > 0 then
        -- Just take the first item from the list
        local firstItem = allItems[1]
        if firstItem then
            targetItemId = firstItem.originalId or (firstItem.displayItem and firstItem.displayItem:getId())
            targetMarketItem = firstItem
        end
    end
    
    -- Fallback: check UI item list if allItems is empty
    if not targetItemId then
        local itemList = WeaponProficiency.window:recursiveGetChildById("itemList")
        if itemList then
            local children = itemList:getChildren()
            for _, child in ipairs(children) do
                local itemWidget = child:getChildById('item')
                if itemWidget then
                    local displayItem = itemWidget:getItem()
                    if displayItem and displayItem:getId() > 0 then
                        local displayItemId = displayItem:getId()
                        -- Find the marketItem for this display
                        for _, marketItem in ipairs(allItems) do
                            local mItemId = marketItem.originalId or (marketItem.displayItem and marketItem.displayItem:getId())
                            local mDisplayId = marketItem.displayId or mItemId
                            if mDisplayId == displayItemId or mItemId == displayItemId then
                                targetItemId = mItemId
                                targetMarketItem = marketItem
                                break
                            end
                        end
                        if targetItemId then break end
                    end
                end
            end
        end
    end
    
    -- Select the target item
    if targetItemId and targetMarketItem then
        WeaponProficiency:selectItem(targetItemId, targetMarketItem)
    else
        -- Retry if no item found yet (cache might not be ready)
        WeaponProficiency.autoSelectRetries = (WeaponProficiency.autoSelectRetries or 0) + 1
        if WeaponProficiency.autoSelectRetries < 5 then
            scheduleEvent(function()
                autoSelectItem()
            end, 200)
        end
    end
end

function hide()
    if not WeaponProficiency.window then return end
    
    -- Check if there are pending selections
    local hasPending = WeaponProficiency.pendingSelections and next(WeaponProficiency.pendingSelections) ~= nil
    
    if hasPending then
        -- For now, just apply and close (we can add dialog later)
        WeaponProficiency:applyPendingSelections()
    end

    releaseWeaponProficiencyKeyboardFocus()
    setWeaponProficiencySearchEnabled(false)
    
    -- Close window
    WeaponProficiency.window:hide()
    
    -- Update button state (for highlight widget, use child button)
    if WeaponProficiency.button then
        local btn = WeaponProficiency.button:getChildById('button') or WeaponProficiency.button
        if btn then
            btn:setOn(false)
        end
    end
    
    -- Re-show highlight if there are still unused perks
    updateProficiencyHighlight()

    addEvent(function()
        restoreWeaponProficiencyNavigationFocus()
    end)
    
    -- Reset selected item state so auto-select works on next open
    WeaponProficiency.selectedItemId = nil
    WeaponProficiency.selectedDisplayId = nil
    WeaponProficiency.selectedMarketItem = nil
end

function toggle()
    if WeaponProficiency.window and WeaponProficiency.window:isVisible() then
        hide()
    else
        requestOpenWindow()
    end
end

-- Request to open proficiency window with optional item redirect
requestOpenWindow = function(redirectItem)
    local category = "Weapons: All"
    local targetItemId = nil
    
    -- Check left hand slot for equipped weapon
    local player = g_game.getLocalPlayer()
    if player then
        local leftSlotItem = player:getInventoryItem(InventorySlotLeft)
        if leftSlotItem then
            local weaponType = leftSlotItem.getWeaponType and leftSlotItem:getWeaponType() or 0
            if weaponType > 0 then
                category = getWeaponCategoryString(weaponType)
                targetItemId = leftSlotItem:getId()
            end
        end
    end

    if redirectItem then
        local weaponType = redirectItem.getWeaponType and redirectItem:getWeaponType() or 0
        if weaponType > 0 then
            category = getWeaponCategoryString(weaponType)
            targetItemId = redirectItem:getId()
        end
    end
    
    -- Request all proficiencies from server
    if not WeaponProficiency.allProficiencyRequested then
        g_game.sendWeaponProficiencyAction(1) -- Request all weapons
        WeaponProficiency.allProficiencyRequested = true
        WeaponProficiency.firstItemRequested = redirectItem
    end
    
    show()
end

modules.game_proficiency.requestOpenWindow = requestOpenWindow

-- Helper function to get weapon category string
function getWeaponCategoryString(weaponType)
    local categoryMap = {
        [1] = "Weapons: Clubs",     -- WEAPON_CLUB
        [2] = "Weapons: Axes",      -- WEAPON_AXE
        [3] = "Weapons: Swords",    -- WEAPON_SWORD
        [4] = "Weapons: Wands",     -- WEAPON_WANDROD
        [7] = "Weapons: Distance",  -- WEAPON_BOW
        [8] = "Weapons: Distance",  -- WEAPON_THROW
        [9] = "Weapons: Distance",  -- WEAPON_CROSSBOW
        [0] = "Weapons: Fist",      -- WEAPON_FIST
    }
    return categoryMap[weaponType] or "Weapons: All"
end

-- Create the proficiency window
function createWindow()
    WeaponProficiency.window = g_ui.displayUI('proficiency')
    WeaponProficiency.window:hide()
    setWeaponProficiencySearchEnabled(false)
    
    WeaponProficiency.displayItemPanel = WeaponProficiency.window:recursiveGetChildById("itemPanel")
    WeaponProficiency.perkPanel = WeaponProficiency.window:recursiveGetChildById("bonusProgressBackground")
    WeaponProficiency.bonusDetailPanel = WeaponProficiency.window:recursiveGetChildById("bonusDetailBackground")
    WeaponProficiency.optionFilter = WeaponProficiency.window:recursiveGetChildById("classFilter")
    WeaponProficiency.starProgressPanel = WeaponProficiency.window:recursiveGetChildById("starsPanelBackground")
    WeaponProficiency.itemListScroll = WeaponProficiency.window:recursiveGetChildById("itemListScroll")
    WeaponProficiency.vocationWarning = WeaponProficiency.window:recursiveGetChildById("vocationWarning")
    
    -- Debug: verify panels are found
    
    -- Setup category dropdown options
    if WeaponProficiency.optionFilter then
        WeaponProficiency.optionFilter:clearOptions()
        WeaponProficiency.optionFilter:addOption("Weapons: All")
        WeaponProficiency.optionFilter:addOption("Weapons: Swords")
        WeaponProficiency.optionFilter:addOption("Weapons: Axes")
        WeaponProficiency.optionFilter:addOption("Weapons: Clubs")
        WeaponProficiency.optionFilter:addOption("Weapons: Distance")
        WeaponProficiency.optionFilter:addOption("Weapons: Wands")
        WeaponProficiency.optionFilter:addOption("Weapons: Fist")
        WeaponProficiency.optionFilter.onOptionChange = function(widget, option)
            WeaponProficiency:refreshItemList()
        end
    end
    
    -- Setup search text handler
    local searchText = WeaponProficiency.window:recursiveGetChildById('searchText')
    if searchText then
        searchText.onTextChange = function(widget, text)
            WeaponProficiency.searchFilter = text
            WeaponProficiency:refreshItemList()
        end
        searchText.onFocusChange = function(widget, focused)
            if focused then
                focusWeaponProficiencySearchInput()
            else
                releaseWeaponProficiencyKeyboardFocus({ restoreChat = false })
            end
        end
        searchText.onMousePress = function(widget)
            focusWeaponProficiencySearchInput()
            return false
        end
    end
    
    -- Setup clear search button
    local clearButton = WeaponProficiency.window:recursiveGetChildById('clearSearchButton')
    if clearButton then
        clearButton.onClick = function()
            local searchWidget = WeaponProficiency.window:recursiveGetChildById('searchText')
            if searchWidget then
                searchWidget:setText('')
                WeaponProficiency.searchFilter = nil
                WeaponProficiency:refreshItemList()
            end
        end
    end

    -- Initialize item list
    WeaponProficiency:refreshItemList()
end


-- Reset proficiency data
function WeaponProficiency:reset()
    self.cacheList = {}
    self.allProficiencyRequested = false
    self.itemList = {}
end

-- -- Create item cache from proficiency things
function WeaponProficiency:createItemCache()
    self.itemList = self.itemList or {}
    self.ItemCategory = self.ItemCategory or {
        Axes = 17, Clubs = 18, DistanceWeapons = 19,
        Swords = 20, WandsRods = 21, FistWeapons = 32,
    }
    self.itemList[MarketCategory.WeaponsAll] = {}
    for _, v in pairs(self.ItemCategory) do
        self.itemList[v] = {}
    end
    
    -- Weapon categories that support proficiency
    local weaponCategories = {
        [MarketCategory.Axes] = true,
        [MarketCategory.Clubs] = true,
        [MarketCategory.DistanceWeapons] = true,
        [MarketCategory.Swords] = true,
        [MarketCategory.WandsRods] = true,
        [MarketCategory.FistWeapons] = true,
    }
    
    -- Get all item types and filter by weapon categories
    local allItems = g_things.getThingTypes(ThingCategoryItem)
    
    for _, itemType in pairs(allItems) do
        local marketData = itemType.getMarketData and itemType:getMarketData() or {}
        
        -- Check if item has market data and is a weapon category
        if marketData and marketData.name and marketData.name ~= "" then
            local category = marketData.category
            
            -- Only process weapon categories
            if weaponCategories[category] then
                local originalId = itemType:getId()
                local item = Item.create(originalId)
                
                if not self.itemList[category] then
                    category = getUnknownMarketCategory(itemType)
                end
                
                -- Use showAs for display, but fall back to originalId if showAs is 0 or nil
                local showAs = marketData.showAs
                if not showAs or showAs == 0 then
                    showAs = originalId
                end
                item:setId(showAs)
                
                -- Store both originalId (server uses this for cache) and showAs (display ID)
                local marketItem = { 
                    displayItem = item, 
                    thingType = itemType, 
                    marketData = marketData,
                    originalId = originalId,  -- The server uses this ID for proficiency data
                    displayId = showAs        -- The display/showAs ID (never 0)
                }
                if self.itemList[category] then
                    table.insert(self.itemList[category], marketItem)
                end
                table.insert(self.itemList[MarketCategory.WeaponsAll], marketItem)
            end
        end
    end
    
    -- Sort by name initially
    local function sortByName(a, b)
        local nameA = (a.marketData.name or ""):lower()
        local nameB = (b.marketData.name or ""):lower()
        return nameA < nameB
    end
    
    for _, v in pairs(self.itemList) do
        table.sort(v, sortByName)
    end
    
end

-- Sort weapons by experience (highest first), then by name
function sortWeaponProficiency(marketCategory)
    local itemList = WeaponProficiency.itemList[marketCategory]
    if not itemList then return end
    
    table.sort(itemList, function(a, b)
        -- Proficiency cache is keyed by original server itemId
        local idA = a.originalId or a.displayId
        local idB = b.originalId or b.displayId
        
        local expA = WeaponProficiency.cacheList[idA] and WeaponProficiency.cacheList[idA].exp or 0
        local expB = WeaponProficiency.cacheList[idB] and WeaponProficiency.cacheList[idB].exp or 0
        
        if expA == expB then
            local nameA = (a.marketData.name or ""):lower()
            local nameB = (b.marketData.name or ""):lower()
            return nameA < nameB
        end
        return expA > expB
    end)
end

-- Check if mastery is achieved for an item
function isMasteryAchieved(displayItem, cacheId, thingType)
    if not displayItem then
        return false
    end
    
    local itemId = cacheId or displayItem:getId()
    local weaponEntry = WeaponProficiency.cacheList[itemId]
    local currentExperience = weaponEntry and weaponEntry.exp or 0
    
    -- Get proficiency data
    local tt = thingType or (displayItem.getThingType and displayItem:getThingType())
    local proficiencyId = ProficiencyData:getProficiencyIdForItem(displayItem, tt)
    local perkCount = ProficiencyData:getPerkLaneCount(proficiencyId)
    local maxExperience = ProficiencyData:getMaxExperience(perkCount, displayItem, tt)
    
    return currentExperience >= maxExperience
end

-- Get unknown market category for item
function getUnknownMarketCategory(itemType)
    local weaponType = itemType.getWeaponType and itemType:getWeaponType() or 0
    return UnknownCategories[weaponType] or MarketCategory.WeaponsAll
end

-- Update selected proficiency display
function WeaponProficiency:onUpdateSelectedProficiency(itemId)
    if not self.displayItemPanel then 
        return 
    end
    
    -- Check if the itemId matches the currently selected item's originalId
    local selectedOriginalId = self.selectedMarketItem and self.selectedMarketItem.originalId
    if not selectedOriginalId or selectedOriginalId ~= itemId then
        return
    end
    
    -- Get display item from selected market item
    local displayItem = self.selectedMarketItem and self.selectedMarketItem.displayItem
    if not displayItem then 
        return 
    end
    
    local currentData = self.cacheList[itemId] or {exp = 0, perks = {}}
    self:updateExperienceProgress(currentData.exp, displayItem)
end

-- Update experience progress display
function WeaponProficiency:updateExperienceProgress(currentExp, displayItem)
    if not self.window then return end
    if not displayItem then return end
    
    local experienceWidget = self.window:recursiveGetChildById("progressDescription")
    local experienceLeftWidget = self.window:recursiveGetChildById("nextLevelDescription")
    local totalProgressWidget = self.window:recursiveGetChildById("proficiencyProgress")
    
    if not experienceWidget or not experienceLeftWidget then return end
    
    local thingType = self.selectedMarketItem and self.selectedMarketItem.thingType
    local marketData = self.selectedMarketItem and self.selectedMarketItem.marketData
    local proficiencyId = ProficiencyData:getProficiencyIdForItem(displayItem, thingType, marketData)
    local perkCount = ProficiencyData:getPerkLaneCount(proficiencyId)
    local currentCeilExperience = ProficiencyData:getCurrentCeilExperience(currentExp, displayItem, thingType)
    local maxExperience = ProficiencyData:getMaxExperience(perkCount, displayItem, thingType)
    local masteryAchieved = currentExp >= maxExperience
    
    
    experienceWidget:setText(string.format("%s / %s", comma_value(currentExp), comma_value(currentCeilExperience)))
    
    if masteryAchieved then
        experienceLeftWidget:setText("Mastery achieved")
    else
        experienceLeftWidget:setText(string.format("%s XP for next level", comma_value(currentCeilExperience - currentExp)))
    end
    
    if totalProgressWidget then
        local progressBackground = totalProgressWidget:getParent()
        local percent = ProficiencyData:getTotalPercent(currentExp, perkCount, displayItem, thingType)
        local availableWidth = progressBackground and math.max(progressBackground:getWidth() - 2, 0) or 0
        local fillWidth = percent <= 0 and 0 or math.max(1, math.floor((availableWidth * percent) / 100))
        totalProgressWidget:setWidth(fillWidth)
    end
end

-- Helper function to format numbers with comma separators
function comma_value(n)
    if not n then return "0" end
    local left, num, right = string.match(tostring(n), '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

-- Toggle filter option (Level, Voc, 1H, 2H buttons)
function WeaponProficiency:toggleFilterOption(button)
    if not button then return end
    
    local buttonId = button:getId()
    self.filters[buttonId] = not self.filters[buttonId]
    
    -- Update button visual state
    if self.filters[buttonId] then
        button:setOn(true)
    else
        button:setOn(false)
    end
    
    -- Refresh item list with new filters
    self:refreshItemList()
end

function WeaponProficiency:onShapeButtonClick(button)
    if not button then return end

    local cacheData = self.selectedItemId and self.cacheList[self.selectedItemId] or nil
    local focusedPerk = self.focusedPerk
    local activeShapeSlot = getActiveShapeSlot(cacheData)
    local modifiedSlot = focusedPerk and activeShapeSlot and slotsMatch(activeShapeSlot, focusedPerk.level, focusedPerk.perk) and getModifiedSlotFor(cacheData, focusedPerk.level, focusedPerk.perk) or nil

    if not focusedPerk or not modifiedSlot then
        if modules and modules.game_textmessage and modules.game_textmessage.displayFailureMessage then
            modules.game_textmessage.displayFailureMessage('Select a modified proficiency perk first.')
        end
        updateModifyShapeButtons()
        return
    end

    local shapeContext = {
        selectedItemId = self.selectedItemId,
        selectedMarketItem = self.selectedMarketItem,
        selectedDisplayId = self.selectedDisplayId,
        focusedPerk = self.focusedPerk,
    }

    self.shapeContext = shapeContext
    hide()
    showShapeWindow(shapeContext)
end

function WeaponProficiency:onModifyButtonClick(button, confirmed)
    if not button then return end
    if self.modifyRequestPending then
        return
    end

    if not confirmed then
        local cost = getCurrentModifyCost()
        confirmProficiencyCost(
            'Confirm Modify',
            string.format('Do you want to spend %s dust to modify this proficiency perk?', comma_value(cost)),
            function()
                WeaponProficiency:onModifyButtonClick(button, true)
            end
        )
        return
    end

    self.shapeContext = {
        selectedItemId = self.selectedItemId,
        selectedMarketItem = self.selectedMarketItem,
        selectedDisplayId = self.selectedDisplayId,
        focusedPerk = self.focusedPerk,
    }

    local focusedLevel = self.focusedPerk and self.focusedPerk.level or nil
    local focusedPerk = self.focusedPerk and self.focusedPerk.perk or nil
    self.pendingModifySlot = focusedLevel and focusedPerk and {
        itemId = self.selectedItemId,
        level = focusedLevel,
        perk = focusedPerk,
    } or nil

    if not self.pendingModifySlot then
        self.modifyRequestPending = false
        self:sendShapeAction(WEAPON_PROFICIENCY_MODIFY_SLOT)
        return
    end

    self.modifyRequestPending = true
    updateModifyShapeButtons()
    scheduleEvent(function()
        if not WeaponProficiency.modifyRequestPending then
            return
        end

        WeaponProficiency.modifyRequestPending = false
        WeaponProficiency.pendingModifySlot = nil
        updateModifyShapeButtons()
    end, 2000)
    self:sendShapeAction(WEAPON_PROFICIENCY_MODIFY_SLOT)
end

local function createShapeWindow()
    WeaponProficiency.shapeWindow = g_ui.displayUI('shape')
    WeaponProficiency.shapeWindow:hide()

    local percentButton = WeaponProficiency.shapeWindow:recursiveGetChildById('percentButton')
    if percentButton then
        percentButton.onClick = function()
            WeaponProficiency:showShapeOptionsWindow()
        end
    end

    local scrollIcon = WeaponProficiency.shapeWindow:recursiveGetChildById('scrollIcon')
    if scrollIcon then
        scrollIcon.onClick = function()
            WeaponProficiency:showShapeOptionsWindow()
        end
    end

    local refineButton = WeaponProficiency.shapeWindow:recursiveGetChildById('refineButton')
    if refineButton then
        refineButton.onClick = function()
            confirmProficiencyCost(
                'Confirm Refine',
                'Do you want to spend 200 dust to refine this proficiency perk?',
                function()
                    WeaponProficiency:sendShapeAction(WEAPON_PROFICIENCY_REFINE_SLOT)
                end
            )
        end
    end

    local maximiseButton = WeaponProficiency.shapeWindow:recursiveGetChildById('maximiseButton')
    if maximiseButton then
        maximiseButton.onClick = function()
            confirmProficiencyCost(
                'Confirm Maximise',
                'Do you want to spend 1 Lunar Ascension Orb to maximise this proficiency perk?',
                function()
                    WeaponProficiency:sendShapeAction(WEAPON_PROFICIENCY_MAXIMISE_SLOT)
                end
            )
        end
    end

    local reshapeButton = WeaponProficiency.shapeWindow:recursiveGetChildById('reshapeButton')
    if reshapeButton then
        reshapeButton.onClick = function()
            confirmProficiencyCost(
                'Confirm Reshape',
                'Do you want to spend 250 dust to reshape this proficiency perk?',
                function()
                    WeaponProficiency:sendShapeAction(WEAPON_PROFICIENCY_RESHAPE_SLOT)
                end
            )
        end
    end

    local clearButton = WeaponProficiency.shapeWindow:recursiveGetChildById('clearButton')
    if clearButton then
        clearButton.onClick = function()
            WeaponProficiency:sendShapeAction(WEAPON_PROFICIENCY_CLEAR_SLOT)
        end
    end
end

local function createReshapeWindow()
    local rootPanel = modules.game_interface and modules.game_interface.getRootPanel and modules.game_interface.getRootPanel() or nil
    WeaponProficiency.reshapeWindow = g_ui.createWidget('ReshapeWindow', rootPanel)
    WeaponProficiency.reshapeWindow:hide()

    for offerIndex = 1, 3 do
        local button = WeaponProficiency.reshapeWindow:recursiveGetChildById('reshapeOfferButton' .. offerIndex)
        if button then
            button.onClick = function()
                WeaponProficiency:pickReshapeOffer(offerIndex)
            end
        end
    end
end

local function clearReshapeOffer(offerIndex)
    if not WeaponProficiency.reshapeWindow then
        return
    end

    local title = WeaponProficiency.reshapeWindow:recursiveGetChildById('reshapeOfferTitle' .. offerIndex)
    local panel = WeaponProficiency.reshapeWindow:recursiveGetChildById('reshapeOfferPanel' .. offerIndex)
    local frame = WeaponProficiency.reshapeWindow:recursiveGetChildById('reshapeOfferInnerFrame' .. offerIndex)
    local button = WeaponProficiency.reshapeWindow:recursiveGetChildById('reshapeOfferButton' .. offerIndex)
    if title then
        title:setText(tr('Offer'))
    end
    if button then
        button:setEnabled(false)
    end
    if not panel or not frame then
        return
    end

    local border = panel:recursiveGetChildById('offerPerkBorder')
    local icon = panel:recursiveGetChildById('offerPerkIcon')
    local augmentIcon = panel:recursiveGetChildById('offerPerkAugmentIcon')
    local levelBadge = panel:recursiveGetChildById('offerPerkLevelBadge')
    local levelLabel = panel:recursiveGetChildById('offerPerkLevelLabel')
    local description = frame:recursiveGetChildById('offerPerkDescription')

    if border then border:setVisible(false) end
    if icon then icon:setVisible(false) end
    if augmentIcon then augmentIcon:setVisible(false) end
    if levelBadge then levelBadge:setVisible(false) end
    if levelLabel then levelLabel:setText('0') end
    if description then description:setText('') end
end

local function populateReshapeOffer(offerIndex, offer)
    clearReshapeOffer(offerIndex)
    if not WeaponProficiency.reshapeWindow or type(offer) ~= 'table' then
        return
    end

    local perkData = createModifiedPerkData({ perkType = offer.perkType, rank = offer.rank })
    if not perkData then
        return
    end

    local title = WeaponProficiency.reshapeWindow:recursiveGetChildById('reshapeOfferTitle' .. offerIndex)
    local panel = WeaponProficiency.reshapeWindow:recursiveGetChildById('reshapeOfferPanel' .. offerIndex)
    local frame = WeaponProficiency.reshapeWindow:recursiveGetChildById('reshapeOfferInnerFrame' .. offerIndex)
    local button = WeaponProficiency.reshapeWindow:recursiveGetChildById('reshapeOfferButton' .. offerIndex)
    if not panel or not frame then
        return
    end

    local bonusName, bonusTooltip = ProficiencyData:getBonusNameAndTooltip(perkData)
    local imagePath, imageClip = ProficiencyData:getImageSourceAndClip(perkData)

    if title then
        title:setText(bonusName or tr('Offer'))
    end
    if button then
        button:setEnabled(true)
    end

    local border = panel:recursiveGetChildById('offerPerkBorder')
    local icon = panel:recursiveGetChildById('offerPerkIcon')
    local augmentIcon = panel:recursiveGetChildById('offerPerkAugmentIcon')
    local levelBadge = panel:recursiveGetChildById('offerPerkLevelBadge')
    local levelLabel = panel:recursiveGetChildById('offerPerkLevelLabel')
    local description = frame:recursiveGetChildById('offerPerkDescription')

    if border then
        border:setMarginTop(21)
        border:setVisible(true)
    end
    if icon then
        setProficiencyIconImage(icon, imagePath, imageClip, 64)
        icon:setVisible(true)
    end
    if augmentIcon then
        if perkData.Type == PERK_SPELL_AUGMENT and perkData.AugmentType then
            local augmentClip = ProficiencyData:getAugmentIconClip(perkData)
            local augX = tonumber(augmentClip:match("(%d+)")) or 0
            augmentIcon:setImageClip({ x = augX, y = 0, width = 32, height = 32 })
            augmentIcon:setVisible(true)
        else
            augmentIcon:setVisible(false)
        end
    end
    if levelBadge then
        levelBadge:setVisible(true)
    end
    if levelLabel then
        levelLabel:setText(tostring(offer.rank or 0))
    end
    if description then
        description:setMarginTop(15)
        description:setTextAlign(AlignTopLeft)
        description:setText(bonusTooltip or '')
    end
end

local function populateReshapeWindow()
    for offerIndex = 1, 3 do
        populateReshapeOffer(offerIndex, WeaponProficiency.reshapeOffers and WeaponProficiency.reshapeOffers[offerIndex] or nil)
    end
end

function WeaponProficiency:showReshapeWindow(offers, context)
    if not self.shapeWindow then
        return
    end

    if not self.reshapeWindow then
        createReshapeWindow()
    end

    self.reshapeOffers = offers or self.reshapeOffers or {}
    self.reshapeContext = context or self.reshapeContext
    populateReshapeWindow()

    self.shapeWindow:hide()
    self.reshapeWindow:show()
    self.reshapeWindow:raise()
    self.reshapeWindow:focus()
end

function WeaponProficiency:pickReshapeOffer(offerIndex)
    local context = self.reshapeContext
    if not context or not context.itemId or not context.level or not context.perk then
        return
    end

    local offer = self.reshapeOffers and self.reshapeOffers[offerIndex] or nil
    if not offer then
        return
    end

    if g_game.sendWeaponProficiencyPickOffer then
        g_game.sendWeaponProficiencyPickOffer(context.itemId, context.level - 1, context.perk - 1, offerIndex - 1)
    else
        g_game.sendWeaponProficiencyAction(WEAPON_PROFICIENCY_PICK_OFFER, context.itemId, context.level - 1, context.perk - 1, offerIndex - 1)
    end

    hideReshapeWindow()
end

function hideReshapeWindow()
    if not WeaponProficiency.reshapeWindow then
        return
    end

    WeaponProficiency.reshapeWindow:hide()
    WeaponProficiency.reshapeOffers = {}
    WeaponProficiency.reshapeContext = nil

    if WeaponProficiency.shapeWindow then
        WeaponProficiency.shapeWindow:show()
        WeaponProficiency.shapeWindow:raise()
        WeaponProficiency.shapeWindow:focus()
    end
end

local function createShapeOptionsWindow()
    WeaponProficiency.shapeOptionsWindow = g_ui.displayUI('shape_options')
    WeaponProficiency.shapeOptionsWindow:hide()

    local searchText = WeaponProficiency.shapeOptionsWindow:recursiveGetChildById('searchText')
    if searchText then
        searchText.onTextChange = function(widget, text)
            WeaponProficiency:refreshShapeOptionsList(text or widget:getText())
        end
    end
end

local function updateShapeResourceLabels()
    if not WeaponProficiency.shapeWindow then
        return
    end

    local balanceLabel = WeaponProficiency.shapeWindow:recursiveGetChildById('shapeDustBalanceLabel')
    local lunarOrbCountLabel = WeaponProficiency.shapeWindow:recursiveGetChildById('shapeLunarOrbCountLabel')
    if not balanceLabel and not lunarOrbCountLabel then
        return
    end

    local currentDust = 0
    local dustMax = 0
    local lunarOrbCount = 0

    local player = g_game.getLocalPlayer()
    if player and player.getResourceBalance then
        currentDust = player:getResourceBalance(ResourceTypes.FORGE_DUST or 70) or 0
        dustMax = player:getResourceBalance(ResourceTypes.FORGE_DUST_LIMIT or 73) or 0
        if player.getItemsCount then
            lunarOrbCount = player:getItemsCount(53695) or 0
        end
    end

    if dustMax <= 0 and ForgeController and ForgeController.conversion then
        dustMax = ForgeController.conversion.dustMax or 0
    end

    if balanceLabel then
        balanceLabel:setText(string.format("%s / %s", comma_value(currentDust), comma_value(dustMax)))
    end

    if lunarOrbCountLabel then
        lunarOrbCountLabel:setText(comma_value(lunarOrbCount))
    end
end

function WeaponProficiency:sendShapeAction(actionType)
    if not g_game.sendWeaponProficiencyAction then
        return
    end

    local shapeContext = self.shapeContext
    if not shapeContext or not shapeContext.selectedItemId or not shapeContext.focusedPerk then
        if modules and modules.game_textmessage and modules.game_textmessage.displayFailureMessage then
            modules.game_textmessage.displayFailureMessage('Select a shaped perk first.')
        end
        return
    end

    local levelIndex = shapeContext.focusedPerk.level
    local perkIndex = shapeContext.focusedPerk.perk
    if not levelIndex or not perkIndex then
        return
    end

    g_game.sendWeaponProficiencyAction(actionType, shapeContext.selectedItemId, levelIndex - 1, perkIndex - 1)
end

local function populateShapeWindow(shapeContext)
    if not WeaponProficiency.shapeWindow then
        return
    end

    updateShapeResourceLabels()

    local selectedMarketItem = shapeContext and shapeContext.selectedMarketItem or nil
    if not selectedMarketItem then
        return
    end

    local displayItem = selectedMarketItem.displayItem
    local marketData = selectedMarketItem.marketData or {}
    local thingType = selectedMarketItem.thingType
    local focusedPerk = shapeContext and shapeContext.focusedPerk or nil

    local borderWidget = WeaponProficiency.shapeWindow:recursiveGetChildById('shapePerkBorder')
    local iconWidget = WeaponProficiency.shapeWindow:recursiveGetChildById('shapePerkIcon')
    local augmentWidget = WeaponProficiency.shapeWindow:recursiveGetChildById('shapePerkIconAugment')
    local perkLevelBadge = WeaponProficiency.shapeWindow:recursiveGetChildById('shapePerkLevelBadge')
    local perkLevelLabel = perkLevelBadge and perkLevelBadge:getChildById('shapePerkLevelLabel') or nil
    local descriptionWidget = WeaponProficiency.shapeWindow:recursiveGetChildById('shapePerkDescription')

    if borderWidget then borderWidget:setVisible(false) end
    if iconWidget then iconWidget:setVisible(false) end
    if augmentWidget then augmentWidget:setVisible(false) end
    if perkLevelBadge then perkLevelBadge:setVisible(false) end
    if perkLevelLabel then perkLevelLabel:setText('0') end
    if descriptionWidget then descriptionWidget:setText('') end

    if not displayItem or not focusedPerk then
        return
    end

    local proficiencyId = ProficiencyData:getProficiencyIdForItem(displayItem, thingType, marketData)
    local profEntry = ProficiencyData:getContentById(proficiencyId)
    if not profEntry or not profEntry.Levels then
        return
    end

    local levelData = profEntry.Levels[focusedPerk.level]
    if not levelData or not levelData.Perks then
        return
    end

    local perkData = levelData.Perks[focusedPerk.perk]
    if not perkData then
        return
    end
    local selectedItemId = shapeContext and shapeContext.selectedItemId or nil
    local cacheData = selectedItemId and WeaponProficiency.cacheList[selectedItemId] or nil
    local activeShapeSlot = getActiveShapeSlot(cacheData)
    local modifiedSlot = activeShapeSlot and slotsMatch(activeShapeSlot, focusedPerk.level, focusedPerk.perk) and getModifiedSlotFor(cacheData, focusedPerk.level, focusedPerk.perk) or nil
    local modifiedPerkData = createModifiedPerkData(modifiedSlot)
    perkData = modifiedPerkData or perkData

    local imagePath, imageClip = ProficiencyData:getImageSourceAndClip(perkData)

    if borderWidget then
        borderWidget:setVisible(true)
    end

    if iconWidget then
        setProficiencyIconImage(iconWidget, imagePath, imageClip, 64)
        iconWidget:setVisible(true)
    end

    if perkLevelBadge then
        perkLevelBadge:setVisible(modifiedSlot ~= nil)
    end

    if perkLevelLabel then
        perkLevelLabel:setText(tostring(modifiedSlot and modifiedSlot.rank or 0))
    end

    if perkData.Type == PERK_SPELL_AUGMENT and perkData.AugmentType and augmentWidget then
        local augmentClip = ProficiencyData:getAugmentIconClip(perkData)
        local augX = tonumber(augmentClip:match("(%d+)")) or 0
        augmentWidget:setImageClip({ x = augX, y = 0, width = 32, height = 32 })
        augmentWidget:setVisible(true)
    end

    if descriptionWidget then
        local _, bonusTooltip = ProficiencyData:getBonusNameAndTooltip(perkData)
        descriptionWidget:setText(bonusTooltip or '')
    end
end

function showShapeWindow(shapeContext)
    if not WeaponProficiency.shapeWindow then
        createShapeWindow()
    end

    populateShapeWindow(shapeContext)

    WeaponProficiency.shapeWindow:show()
    WeaponProficiency.shapeWindow:raise()
    WeaponProficiency.shapeWindow:focus()
end

function WeaponProficiency:showShapeOptionsWindow()
    if not self.shapeWindow then
        return
    end

    if not self.shapeOptionsWindow then
        createShapeOptionsWindow()
    end

    self.shapeOptionsContext = cloneTableShallow(self.shapeContext or {})
    self.shapeOptionsEntries = collectShapeOptionsEntries(self.shapeOptionsContext)

    local searchText = self.shapeOptionsWindow:recursiveGetChildById('searchText')
    local currentSearch = ''
    if searchText then
        currentSearch = searchText:getText() or ''
    end

    self:refreshShapeOptionsList(currentSearch)

    self.shapeWindow:hide()
    self.shapeOptionsWindow:show()
    self.shapeOptionsWindow:raise()
    self.shapeOptionsWindow:focus()

    if searchText then
        addEvent(function()
            if searchText and not searchText:isDestroyed() then
                searchText:focus()
            end
        end)
    end
end

function hideShapeOptionsWindow()
    if not WeaponProficiency.shapeOptionsWindow then
        return
    end

    WeaponProficiency.shapeOptionsWindow:hide()
    WeaponProficiency.shapeOptionsEntries = {}

    if WeaponProficiency.shapeWindow then
        WeaponProficiency.shapeWindow:show()
        WeaponProficiency.shapeWindow:raise()
        WeaponProficiency.shapeWindow:focus()
    end
end

function hideShapeWindow()
    if not WeaponProficiency.shapeWindow then
        return
    end

    WeaponProficiency.shapeWindow:hide()

    show()

    if WeaponProficiency.shapeContext and WeaponProficiency.shapeContext.selectedMarketItem then
        local shapeContext = WeaponProficiency.shapeContext
        scheduleEvent(function()
            if not WeaponProficiency.window or not WeaponProficiency.window:isVisible() then
                return
            end

            local selectedDisplayId = shapeContext.selectedDisplayId or shapeContext.selectedItemId
            WeaponProficiency:selectItem(selectedDisplayId, shapeContext.selectedMarketItem)
            WeaponProficiency.focusedPerk = shapeContext.focusedPerk

            if shapeContext.focusedPerk and shapeContext.focusedPerk.level then
                WeaponProficiency:updatePerkVisualState(shapeContext.focusedPerk.level)
            end
        end, 50)
    end

    addEvent(function()
        restoreWeaponProficiencyNavigationFocus()
    end)
end

-- Refresh item list based on current filters and category
function WeaponProficiency:refreshItemList()
    if not self.window then return end
    
    local itemList = self.window:recursiveGetChildById('itemList')
    if not itemList then return end
    
    -- Get current category from dropdown
    local categoryDropdown = self.window:recursiveGetChildById('classFilter')
    local currentCategory = MarketCategory.WeaponsAll
    
    if categoryDropdown then
        local selectedText = categoryDropdown:getText()
        currentCategory = WeaponStringToCategory[selectedText] or MarketCategory.WeaponsAll
    end
    
    -- Ensure item cache is populated
    if not self.itemList or not self.itemList[MarketCategory.WeaponsAll] or #self.itemList[MarketCategory.WeaponsAll] == 0 then
        self:createItemCache()
    end

    -- Sort items by experience (highest first)
    sortWeaponProficiency(currentCategory)
    
    -- Get items for current category
    local items = self.itemList[currentCategory] or {}
    
    -- Apply filters
    items = self:applyLevelFilter(items)
    items = self:applyVocationFilter(items)
    
    -- Apply 1H/2H filters
    local oneActive = self.filters["oneButton"]
    local twoActive = self.filters["twoButton"]
    
    if oneActive and not twoActive then
        -- Only show one-handed weapons
        local filteredItems = {}
        for _, item in ipairs(items) do
            local thingType = item.thingType
            if thingType then
                local slotType = thingType.getClothSlot and thingType:getClothSlot() or 0
                if slotType ~= 2 then -- Not two-handed (slotType 2 is two-handed)
                    table.insert(filteredItems, item)
                end
            else
                table.insert(filteredItems, item)
            end
        end
        items = filteredItems
    elseif twoActive and not oneActive then
        -- Only show two-handed weapons
        local filteredItems = {}
        for _, item in ipairs(items) do
            local thingType = item.thingType
            if thingType then
                local slotType = thingType.getClothSlot and thingType:getClothSlot() or 0
                if slotType == 2 then -- Two-handed
                    table.insert(filteredItems, item)
                end
            end
        end
        items = filteredItems
    end
    -- If both active or neither, show all
    
    -- Apply search text filter
    if self.searchFilter and self.searchFilter ~= '' then
        local searchLower = string.lower(self.searchFilter)
        local filteredItems = {}
        for _, item in ipairs(items) do
            local itemName = item.marketData and item.marketData.name or ""
            if string.find(string.lower(itemName), searchLower, 1, true) then
                table.insert(filteredItems, item)
            end
        end
        items = filteredItems
    end
    
    -- Clear existing items
    local children = itemList:getChildren()
    for _, child in ipairs(children) do
        local itemWidget = child:getChildById('item')
        if itemWidget then
            itemWidget:setItemId(0)
        end
        if child.setTooltip then
            child:setTooltip("")
        end
        -- Clear stars
        local starPanel = child:getChildById('starsBackground')
        if starPanel then
            starPanel:destroyChildren()
        end
        -- Remove old click callback
        child.onClick = nil
        child:setEnabled(false)
    end
    
    -- Populate items with click handlers
    local index = 1
    for _, marketItem in ipairs(items) do
        local child = itemList:getChildByIndex(index)
        if child then
            child:setEnabled(true)
            local itemWidget = child:getChildById('item')
            if itemWidget and marketItem.displayItem then
                -- Use stored displayId (guaranteed non-zero) instead of displayItem:getId()
                local displayId = marketItem.displayId or marketItem.originalId
                -- Proficiency cache is keyed by original server itemId
                local cacheId = marketItem.originalId or displayId
                itemWidget:setItemId(displayId)
                
                -- Add tooltip with item name
                if child.setTooltip then
                    child:setTooltip(marketItem.marketData.name or "")
                end
                
                -- Add stars based on proficiency level
                local starPanel = child:getChildById('starsBackground')
                if starPanel then
                    starPanel:destroyChildren()
                    
                    -- Get experience and calculate level
                    local cacheEntry = self.cacheList[cacheId]
                    local exp = cacheEntry and cacheEntry.exp or 0
                    local weaponLevel = ProficiencyData:getCurrentLevelByExp(marketItem.displayItem, exp, false, marketItem.thingType) or 0
                    
                    -- Create star widgets for each level achieved
                    if weaponLevel > 0 then
                        local mastery = isMasteryAchieved(marketItem.displayItem, cacheId, marketItem.thingType)
                        for i = 1, weaponLevel do
                            local star = g_ui.createWidget("MiniStar", starPanel)
                            if star then
                                if mastery then
                                    star:setImageSource("/images/game/proficiency/icon-star-tiny-gold")
                                end
                            end
                        end
                    end
                end
                
                -- Add click handler
                child.onClick = function()
                    WeaponProficiency:selectItem(displayId, marketItem)
                end
            else
                if child.setTooltip then
                    child:setTooltip("")
                end
                child.onClick = nil
                child:setEnabled(false)
            end
            index = index + 1
        end
        
        if index > 45 then break end -- Max 45 items visible
    end
end

-- Handle category change from dropdown
function WeaponProficiency:onCategoryChange(dropdown)
    self:refreshItemList()
end

-- Select an item from the list
function WeaponProficiency:selectItem(itemId, marketItem)
    if not self.window then return end
    
    -- Use originalId for cache lookups (server uses this ID)
    local cacheId = marketItem.originalId or itemId
    
    self.selectedItemId = cacheId  -- Use cacheId for proficiency data lookup
    self.selectedDisplayId = itemId  -- Keep display ID for UI
    self.selectedMarketItem = marketItem
    
    
    -- Get the item panel
    local itemPanel = self.window:recursiveGetChildById('itemPanel')
    if not itemPanel then 
        return 
    end
    
    -- Update item display panel
    local itemNameLabel = itemPanel:getChildById('itemNameTitle')
    local itemIconWidget = itemPanel:recursiveGetChildById('item')
    local displayItem = marketItem.displayItem
    
    -- Ensure displayItem has a valid ID (fix for items where showAs was 0)
    local actualDisplayId = marketItem.displayId or marketItem.originalId
    if displayItem and displayItem:getId() == 0 and actualDisplayId > 0 then
        displayItem:setId(actualDisplayId)
    end
    
    
    if itemNameLabel and marketItem then
        itemNameLabel:setText(marketItem.marketData.name or "Unknown Item")
    end
    
    -- Set item using setItem method
    if itemIconWidget and displayItem then
        itemIconWidget:setItem(displayItem)
    end
    
    -- Destroy and recreate perk panels for fresh display
    if self.perkPanel then
        self.perkPanel:destroyChildren()
    end
    if self.bonusDetailPanel then
        self.bonusDetailPanel:destroyChildren()
    end
    if self.starProgressPanel then
        self.starProgressPanel:destroyChildren()
    end
    
    -- Initialize cache entry if not exists
    if not self.cacheList[cacheId] then
        self.cacheList[cacheId] = { exp = 0, perks = {} }
    end
    
    local currentData = self.cacheList[cacheId]
    
    -- Get proficiency ID using wrapper function, passing thingType and marketData for proper category lookup
    local thingType = marketItem.thingType
    local marketData = marketItem.marketData
    local proficiencyId = ProficiencyData:getProficiencyIdForItem(displayItem, thingType, marketData)
    local profEntry = ProficiencyData:getContentById(proficiencyId)
    
    
    if profEntry then
        -- Update experience display
        self:updateExperienceProgress(currentData.exp, displayItem)
        
        -- Create star widgets
        for i = 1, #profEntry.Levels do
            local starWidget = g_ui.createWidget('StarWidget', self.starProgressPanel)
            if starWidget then
                starWidget:setId('starWidget' .. i)
            end
        end
        
        -- Create perk column panels
        for i, levelData in ipairs(profEntry.Levels) do
            local perkColumn = g_ui.createWidget('BonusSelectPanel', self.perkPanel)
            if perkColumn then
                perkColumn:setId('perkColumn_' .. i)
                local progress = perkColumn:getChildById('bonusSelectProgress')
                if progress then
                    progress:setWidth(0)
                end
            end
            
            local bonusDetail = g_ui.createWidget('BonusDetailPanel', self.bonusDetailPanel)
            if bonusDetail then
                bonusDetail:setId('bonusDetail_' .. i)
            end
        end
        
        -- Pending selections are only for not-yet-applied changes.
        self.pendingSelections = {}

        -- Keep the window neutral on open; applied perks can still be focused by click.
        self.focusedPerk = nil
        
        -- Display perks and update UI
        self:displayPerks(cacheId, currentData.perks, displayItem)
        updateModifyShapeButtons()
    else
        -- Fallback: show basic info without perks
        self:updateExperienceProgress(currentData.exp, displayItem)
        updateModifyShapeButtons()
    end
    
    -- Request proficiency info from server if needed - use cacheId (originalId)
    if g_game.sendWeaponProficiencyAction then
        g_game.sendWeaponProficiencyAction(0, cacheId)
    end
end

-- Display proficiency data for selected item
function WeaponProficiency:displayProficiencyData(itemId, experience, perks)
    if not self.window then return end
    if self.selectedItemId ~= itemId then return end
    
    local displayItem = self.selectedMarketItem and self.selectedMarketItem.displayItem
    local thingType = self.selectedMarketItem and self.selectedMarketItem.thingType
    if not displayItem then return end
    
    -- Update experience display
    self:updateExperienceProgress(experience, displayItem)
    
    -- Get proficiency content using wrapper function (with thingType and marketData)
    local marketData = self.selectedMarketItem and self.selectedMarketItem.marketData
    local proficiencyId = ProficiencyData:getProficiencyIdForItem(displayItem, thingType, marketData)
    local profEntry = ProficiencyData:getContentById(proficiencyId)
    
    if not profEntry then return end
    
    local levels = profEntry.Levels or {}
    local currentLevel = ProficiencyData:getCurrentLevelByExp(displayItem, experience, false, thingType)
    local maxExperience = ProficiencyData:getMaxExperience(#levels, displayItem, thingType)
    local masteryAchieved = experience >= maxExperience
    
    -- Update perk columns for each level
    for i, levelData in ipairs(levels) do
        local perkColumn = self.perkPanel:getChildById('perkColumn_' .. i)
        local starWidget = self.starProgressPanel:getChildById('starWidget' .. i)
        
        if perkColumn then
            self:updatePerkColumn(perkColumn, levelData, i, currentLevel, perks, experience, displayItem, masteryAchieved, thingType)
        end
        
        if starWidget then
            self:updateStarWidget(starWidget, i, currentLevel, experience, displayItem, masteryAchieved, thingType)
        end
    end
    
    -- Update bonus detail panels
    self:updateBonusDetails(profEntry, perks)
    
    -- Update item frame
    self:updateItemAddons(experience, displayItem, masteryAchieved, thingType)
end

-- Display perks in the perk panel
function WeaponProficiency:displayPerks(itemId, perks, displayItem)
    if not self.window or not self.perkPanel then 
        return 
    end
    
    if not displayItem then
        return
    end
    
    -- Get proficiency content using wrapper function (with thingType and marketData for proper category lookup)
    local thingType = self.selectedMarketItem and self.selectedMarketItem.thingType
    local marketData = self.selectedMarketItem and self.selectedMarketItem.marketData
    local proficiencyId = ProficiencyData:getProficiencyIdForItem(displayItem, thingType, marketData)
    local proficiencyContent = ProficiencyData:getContentById(proficiencyId)
    
    if not proficiencyContent then
        return
    end
    
    -- Use cacheId (originalId) for cache lookups
    local cacheId = self.selectedMarketItem and self.selectedMarketItem.originalId or itemId
    
    
    local levels = proficiencyContent.Levels or {}
    local experience = self.cacheList[cacheId] and self.cacheList[cacheId].exp or 0
    
    -- Calculate current level based on experience (starts at 0 if no experience)
    local currentLevel = ProficiencyData:getCurrentLevelByExp(displayItem, experience, false, thingType)
    
    -- Check if mastery is achieved
    local maxExperience = ProficiencyData:getMaxExperience(#levels, displayItem, thingType)
    local masteryAchieved = experience >= maxExperience
    
    -- Update perk columns for each level
    for i, levelData in ipairs(levels) do
        local perkColumn = self.perkPanel:getChildById('perkColumn_' .. i)
        local starWidget = self.starProgressPanel:getChildById('starWidget' .. i)
        
        if perkColumn and levelData then
            self:updatePerkColumn(perkColumn, levelData, i, currentLevel, perks, experience, displayItem, masteryAchieved, thingType)
        end
        
        -- Update star widget
        if starWidget then
            self:updateStarWidget(starWidget, i, currentLevel, experience, displayItem, masteryAchieved, thingType)
        end
    end
    
    -- Update bonus detail panels
    self:updateBonusDetails(proficiencyContent, perks)
    
    -- Update item frame/addons based on level
    self:updateItemAddons(experience, displayItem, masteryAchieved)
end


-- Update a single star widget - matching RTC implementation
function WeaponProficiency:updateStarWidget(starWidget, levelIndex, currentLevel, experience, displayItem, masteryAchieved, thingType)
    if not starWidget then return end
    
    local starProgress = starWidget:getChildById('starProgress')
    local starIcon = starWidget:getChildById('star')
    
    if starProgress then
        -- Calculate percent for this level (same as perk column)
        local percent = ProficiencyData:getLevelPercent(experience or 0, levelIndex, displayItem, thingType)
        local availableWidth = math.max(starWidget:getWidth() - 2, 0)
        local fillWidth = percent <= 0 and 0 or math.max(1, math.floor((availableWidth * percent) / 100))
        starProgress:setWidth(fillWidth)
        
        -- Set tooltip with experience info
        local maxLevelExp = ProficiencyData:getMaxExperienceByLevel(levelIndex, displayItem, thingType)
        starProgress:setTooltip(string.format("%s / %s", comma_value(experience or 0), comma_value(maxLevelExp or 0)))
    end
    
    -- Update star icon color based on completion (100% = complete)
    if starIcon then
        local percent = ProficiencyData:getLevelPercent(experience or 0, levelIndex, displayItem, thingType)
        if percent >= 100 then
            -- Level complete - show gold or silver star
            local iconType = masteryAchieved and "gold" or "silver"
            starIcon:setImageSource('/images/game/proficiency/icon-star-tiny-' .. iconType)
        else
            -- Level not complete - show dark star
            starIcon:setImageSource('/images/game/proficiency/icon-star-dark')
                    end
                end
end

-- Update item frame/addons based on weapon level
function WeaponProficiency:updateItemAddons(currentExp, displayItem, masteryAchieved, thingType)
    if not self.window then return end
    if not displayItem then return end
    
    local weaponLevel = math.min(7, ProficiencyData:getCurrentLevelByExp(displayItem, currentExp, false, thingType) or 0)
    local iconLevelWidget = self.window:recursiveGetChildById("iconMasteryLevel")
    local weaponLevelWidget = self.window:recursiveGetChildById("itemMasteryLevel")
    
    if iconLevelWidget then
        iconLevelWidget:setImageSource("/images/game/proficiency/icon-masterylevel-" .. weaponLevel)
    end
    
    if weaponLevelWidget then
        weaponLevelWidget:setVisible(weaponLevel > 0)
        if weaponLevel > 0 then
            local color = masteryAchieved and "gold" or "silver"
            weaponLevelWidget:setImageSource(string.format("/images/game/proficiency/icon-masterylevel-%d-%s", weaponLevel, color))
        end
    end
end

-- Update a single perk column
function WeaponProficiency:updatePerkColumn(perkColumn, levelData, levelIndex, currentLevel, selectedPerks, experience, displayItem, masteryAchieved, thingType)
    if not perkColumn or not levelData then return end
    
    local perksData = levelData.Perks or {}
    local perkCount = #perksData
    
    -- Show appropriate panel based on perk count
    local oneBonusPanel = perkColumn:getChildById('oneBonusIconPanel')
    local twoBonusPanel = perkColumn:getChildById('twoBonusIconPanel')
    local threeBonusPanel = perkColumn:getChildById('threeBonusIconPanel')
    
    if oneBonusPanel then oneBonusPanel:setVisible(perkCount == 1) end
    if twoBonusPanel then twoBonusPanel:setVisible(perkCount == 2) end
    if threeBonusPanel then threeBonusPanel:setVisible(perkCount == 3) end
    
    -- Determine which panel to use
    local activePanel = nil
    if perkCount == 1 and oneBonusPanel then
        activePanel = oneBonusPanel
    elseif perkCount == 2 and twoBonusPanel then
        activePanel = twoBonusPanel
    elseif perkCount == 3 and threeBonusPanel then
        activePanel = threeBonusPanel
    end
    
    if not activePanel then return end
    
    -- Store currentPerkPanel reference for later use
    perkColumn.currentPerkPanel = activePanel
    
    -- Level is unlocked if we have enough experience
    local isLevelUnlocked = levelIndex <= currentLevel
    local cacheId = self.selectedMarketItem and self.selectedMarketItem.originalId or self.selectedItemId
    local cacheData = cacheId and self.cacheList[cacheId] or nil
    
    -- Update progress bar for this column - use height for vertical fill effect
    local progressBar = perkColumn:getChildById('bonusSelectProgress')
    if progressBar then
        local percent = ProficiencyData:getLevelPercent(experience or 0, levelIndex, displayItem, thingType)
        
        -- Set progress bar width (horizontal fill from left to right)
        -- Max width is 106 (108 panel width - 2 margin)
        local maxWidth = 106
        local fillWidth = math.floor((percent / 100) * maxWidth)
        progressBar:setWidth(fillWidth)
        
        -- Unlock perks if this level is complete (100%)
        if percent >= 100 then
            for _, widget in pairs(activePanel:getChildren()) do
                if widget.blocked then
                    widget.blocked = false
                end
            end
        end
    end
    
    -- Update each perk icon
    for perkIndex, perkData in ipairs(perksData) do
        local bonusIcon = activePanel:getChildById('bonusIcon' .. (perkIndex - 1))
        if bonusIcon then
            local modifiedSlot = getModifiedSlotFor(cacheData, levelIndex, perkIndex)
            local modifiedPerkData = createModifiedPerkData(modifiedSlot)
            local displayPerkData = modifiedPerkData or perkData

            -- Get image source and clip
            local imagePath, imageClip = ProficiencyData:getImageSourceAndClip(displayPerkData)
            local iconWidget = bonusIcon:getChildById('icon')
            local iconGreyWidget = bonusIcon:getChildById('icon-grey')
            local lockedWidget = bonusIcon:getChildById('locked-perk')
            local borderWidget = bonusIcon:getChildById('border')
            local highlightWidget = bonusIcon:getChildById('highlight')
            local arrowUpWidget = bonusIcon:getChildById('selectArrowUp')
            local arrowDownWidget = bonusIcon:getChildById('selectArrowDown')
            local arrowLeftWidget = bonusIcon:getChildById('selectArrowLeft')
            local arrowRightWidget = bonusIcon:getChildById('selectArrowRight')
            local perkLevelBadge = bonusIcon:getChildById('perkLevelBadge')
            local perkLevelLabel = perkLevelBadge and perkLevelBadge:getChildById('perkLevelLabel') or nil
            
            -- Check if this perk is selected
            local isSelected = false
            if selectedPerks and type(selectedPerks) == "table" then
                -- Format 1: Array format from server/cache: {{level, perkPos}, ...} (1-indexed)
                if #selectedPerks > 0 and type(selectedPerks[1]) == "table" then
                for _, perk in ipairs(selectedPerks) do
                        if type(perk) == "table" and #perk >= 2 and perk[1] == levelIndex and perk[2] == perkIndex then
                        isSelected = true
                        break
                    end
                    end
                -- Format 2: Indexed format from pendingSelections: {[levelIndex] = perkIndex} (1-indexed)
                elseif selectedPerks[levelIndex] ~= nil then
                    isSelected = (selectedPerks[levelIndex] == perkIndex)
                end
            end
            
            if iconWidget then
                setProficiencyIconImage(iconWidget, imagePath, imageClip, 64)
            end
            
            -- Handle grey icon - spell augments use separate -off image, others use Y+64 offset
            if iconGreyWidget then
                if isStandaloneProficiencyImage(imagePath) then
                    -- Standalone new spell/perk images use generated grayscale
                    -- companions with the same name plus "-off". This keeps
                    -- locked/unselected perks grey and lets the selected,
                    -- unlocked icon use the original colored art.
                    setProficiencyIconImage(iconGreyWidget, imagePath .. "-off", nil, 64)
                elseif displayPerkData.Type == PERK_SPELL_AUGMENT then
                    -- Spell augments have a separate -off image source
                    iconGreyWidget:setImageSource(imagePath .. "-off")
                    local clipX, clipY = parseImageClipString(imageClip)
                    iconGreyWidget:setImageClip({x = clipX, y = clipY, width = 64, height = 64})
                else
                    -- Other perks use Y+64 for grey version
                    local clipX, clipY = parseImageClipString(imageClip)
                    iconGreyWidget:setImageSource(imagePath)
                    iconGreyWidget:setImageClip({x = clipX, y = clipY + 64, width = 64, height = 64})
                end
            end
            
            -- Handle augment overlay icons for spell augments
            local iconPerks = bonusIcon:getChildById('iconPerks')
            local iconPerksGrey = bonusIcon:getChildById('iconPerks-grey')
            if displayPerkData.Type == PERK_SPELL_AUGMENT and displayPerkData.AugmentType then
                local augmentClip = ProficiencyData:getAugmentIconClip(displayPerkData)
                local augX = tonumber(augmentClip:match("(%d+)")) or 0
                if iconPerks then
                    iconPerks:setVisible(true)
                    iconPerks:setImageClip({x = augX, y = 0, width = 32, height = 32})
                end
                if iconPerksGrey then
                    iconPerksGrey:setVisible(true)
                    iconPerksGrey:setImageClip({x = augX, y = 32, width = 32, height = 32})
                end
            else
                if iconPerks then iconPerks:setVisible(false) end
                if iconPerksGrey then iconPerksGrey:setVisible(false) end
            end
            
            -- Show/hide based on unlock state and selection
            local showColorIcon = isLevelUnlocked and isSelected
            local showGreyIcon = not isLevelUnlocked or (isLevelUnlocked and not isSelected)
            
            if iconWidget then
                iconWidget:setVisible(showColorIcon)
            end
            
            if iconGreyWidget then
                iconGreyWidget:setVisible(showGreyIcon)
                iconGreyWidget:setOpacity(1.0)
            end
            
            -- Handle augment overlay icons visibility for spell augments
            local iconPerks = bonusIcon:getChildById('iconPerks')
            local iconPerksGrey = bonusIcon:getChildById('iconPerks-grey')
            if displayPerkData.Type == PERK_SPELL_AUGMENT then
                if iconPerks then
                    iconPerks:setVisible(showColorIcon)
                end
                if iconPerksGrey then
                    iconPerksGrey:setVisible(showGreyIcon)
                    iconPerksGrey:setOpacity(1.0)
                end
            end
            
            -- Show locked icon if level not reached
            if lockedWidget then
                lockedWidget:setVisible(not isLevelUnlocked)
            end

            if perkLevelBadge then
                perkLevelBadge:setVisible(modifiedSlot ~= nil)
            end
            if perkLevelLabel then
                perkLevelLabel:setText(tostring(modifiedSlot and modifiedSlot.rank or 0))
            end
            
            -- Update border based on state
            if borderWidget then
                if isSelected and isLevelUnlocked then
                    borderWidget:setImageSource('/images/game/proficiency/border-weaponmasterytreeicons-active')
                else
                    borderWidget:setImageSource('/images/game/proficiency/border-weaponmasterytreeicons-inactive')
                end
            end
            
            -- Highlight selected perk
            if highlightWidget then
                highlightWidget:setVisible(isSelected and isLevelUnlocked)
            end

            local isFocusedPerk = self.focusedPerk
                and self.focusedPerk.level == levelIndex
                and self.focusedPerk.perk == perkIndex
            local showSelectionArrows = isFocusedPerk and isLevelUnlocked
            if arrowUpWidget then arrowUpWidget:setVisible(showSelectionArrows) end
            if arrowDownWidget then arrowDownWidget:setVisible(showSelectionArrows) end
            if arrowLeftWidget then arrowLeftWidget:setVisible(showSelectionArrows) end
            if arrowRightWidget then arrowRightWidget:setVisible(showSelectionArrows) end
            
            -- Set tooltip
            local bonusName, bonusTooltip = ProficiencyData:getBonusNameAndTooltip(displayPerkData)
            bonusIcon:setTooltip(string.format("%s\n\n%s", bonusName, bonusTooltip))
            
            -- Store perk data for later use
            bonusIcon.perkData = displayPerkData
            bonusIcon.modifiedSlot = modifiedSlot
            bonusIcon.blocked = not isLevelUnlocked
            bonusIcon.locked = false
            bonusIcon.active = isSelected
            bonusIcon.levelIndex = levelIndex
            bonusIcon.perkIndex = perkIndex
            
            -- Add click handler for selecting perk
            bonusIcon.onClick = function(widget)
                if widget.blocked then
                    return
                end
                WeaponProficiency:onPerkClick(widget)
            end
        end
    end
end

-- Handle perk icon click
function WeaponProficiency:onPerkClick(bonusIcon)
    if not bonusIcon then return end
    
    local levelIndex = bonusIcon.levelIndex
    local perkIndex = bonusIcon.perkIndex
    local previousFocusedLevel = self.focusedPerk and self.focusedPerk.level or nil
    local previousFocusedPerk = self.focusedPerk and self.focusedPerk.perk or nil
    
    
    -- Initialize pending selections if not exists
    if not self.pendingSelections then
        self.pendingSelections = {}
    end
    
    -- Get currently saved perk for this level from cache
    local savedPerk = nil
    if self.selectedItemId and self.cacheList[self.selectedItemId] then
        local cachedPerks = self.cacheList[self.selectedItemId].perks or {}
        for _, perk in ipairs(cachedPerks) do
            if type(perk) == "table" and perk[1] == levelIndex then
                savedPerk = perk[2]
                break
            end
        end
    end

    local hasAppliedPerks = self.selectedItemId
        and self.cacheList[self.selectedItemId]
        and self.cacheList[self.selectedItemId].perks
        and #self.cacheList[self.selectedItemId].perks > 0
    local cacheData = self.selectedItemId and self.cacheList[self.selectedItemId] or nil
    local clickedModifiedSlot = getModifiedSlotFor(cacheData, levelIndex, perkIndex)

    if hasAppliedPerks then
        -- After applying, the sequence is locked.
        -- The click now only changes the focused applied perk for visual arrows.
        if savedPerk == perkIndex then
            self.focusedPerk = { level = levelIndex, perk = perkIndex }
            if previousFocusedLevel and previousFocusedLevel ~= levelIndex then
                self:updatePerkVisualState(previousFocusedLevel)
            end
            self:updatePerkVisualState(levelIndex)
        else
            self.focusedPerk = nil
            if previousFocusedLevel then
                self:updatePerkVisualState(previousFocusedLevel)
            end
            if previousFocusedLevel ~= levelIndex or previousFocusedPerk ~= perkIndex then
                self:updatePerkVisualState(levelIndex)
            end
        end
        self:updateApplyButtonState()
        updateModifyShapeButtons()
        return
    end

    -- Before applying, clicking still chooses the pending sequence.
    self.pendingSelections[levelIndex] = perkIndex
    self.focusedPerk = { level = levelIndex, perk = perkIndex }
    
    if previousFocusedLevel and previousFocusedLevel ~= levelIndex then
        self:updatePerkVisualState(previousFocusedLevel)
    end

    -- Update visual state for all perks in this level column
    self:updatePerkVisualState(levelIndex)
    
    -- Update button states
    self:updateApplyButtonState()
    updateModifyShapeButtons()
end

-- Update visual state for perks in a level column
function WeaponProficiency:updatePerkVisualState(levelIndex)
    local perkColumn = self.perkPanel:getChildById('perkColumn_' .. levelIndex)
    if not perkColumn or not perkColumn.currentPerkPanel then return end
    
    -- Get pending selection first, then fall back to cached perk
    local selectedPerkIndex = self.pendingSelections and self.pendingSelections[levelIndex]

    if not selectedPerkIndex and self.selectedItemId and self.cacheList[self.selectedItemId] then
        local cachedPerks = self.cacheList[self.selectedItemId].perks or {}
        for _, perk in ipairs(cachedPerks) do
            if type(perk) == "table" and perk[1] == levelIndex then
                selectedPerkIndex = perk[2]
                break
            end
        end
    end
    
    -- If no pending selection, check cached perks
    if not selectedPerkIndex and self.selectedItemId and self.cacheList[self.selectedItemId] then
        local cachedPerks = self.cacheList[self.selectedItemId].perks or {}
        for _, perk in ipairs(cachedPerks) do
            if type(perk) == "table" and perk[1] == levelIndex then
                selectedPerkIndex = perk[2]
                break
            end
        end
    end
    
    -- Update each perk icon in this column
    for perkIdx = 0, 2 do
        local bonusIcon = perkColumn.currentPerkPanel:getChildById('bonusIcon' .. perkIdx)
        if bonusIcon then
            local isSelected = (selectedPerkIndex == (perkIdx + 1))
            local isLevelUnlocked = not bonusIcon.blocked
            
            local iconWidget = bonusIcon:getChildById('icon')
            local iconGreyWidget = bonusIcon:getChildById('icon-grey')
            local borderWidget = bonusIcon:getChildById('border')
            local highlightWidget = bonusIcon:getChildById('highlight')
            local arrowUpWidget = bonusIcon:getChildById('selectArrowUp')
            local arrowDownWidget = bonusIcon:getChildById('selectArrowDown')
            local arrowLeftWidget = bonusIcon:getChildById('selectArrowLeft')
            local arrowRightWidget = bonusIcon:getChildById('selectArrowRight')
            
            -- Show color icon only if unlocked AND selected
            if iconWidget then
                iconWidget:setVisible(isLevelUnlocked and isSelected)
            end
            
            if iconGreyWidget then
                iconGreyWidget:setVisible(not isSelected or not isLevelUnlocked)
            end
            
            -- Update border
            if borderWidget then
                if isSelected and isLevelUnlocked then
                    borderWidget:setImageSource('/images/game/proficiency/border-weaponmasterytreeicons-active')
                else
                    borderWidget:setImageSource('/images/game/proficiency/border-weaponmasterytreeicons-inactive')
        end
    end
            
            -- Highlight selected
            if highlightWidget then
                highlightWidget:setVisible(isSelected and isLevelUnlocked)
            end

            local isFocusedPerk = self.focusedPerk
                and self.focusedPerk.level == levelIndex
                and self.focusedPerk.perk == (perkIdx + 1)
            local showSelectionArrows = isFocusedPerk and isLevelUnlocked
            if arrowUpWidget then arrowUpWidget:setVisible(showSelectionArrows) end
            if arrowDownWidget then arrowDownWidget:setVisible(showSelectionArrows) end
            if arrowLeftWidget then arrowLeftWidget:setVisible(showSelectionArrows) end
            if arrowRightWidget then arrowRightWidget:setVisible(showSelectionArrows) end
            if perkLevelBadge then perkLevelBadge:setVisible(modifiedSlot ~= nil) end
            if perkLevelLabel then perkLevelLabel:setText(tostring(modifiedSlot and modifiedSlot.rank or 0)) end
            
            bonusIcon.active = isSelected
        end
    end
    
    -- Update bonus detail panel
    self:updateBonusDetailForLevel(levelIndex)
end

-- Update bonus detail panel for a specific level
function WeaponProficiency:updateBonusDetailForLevel(levelIndex)
    local bonusDetailPanel = self.window:recursiveGetChildById('bonusDetailBackground')
    if not bonusDetailPanel then return end
    
    local detailPanel = bonusDetailPanel:getChildById('bonusDetail_' .. levelIndex)
    if not detailPanel then return end
    
    local bonusNameWidget = detailPanel:getChildById('bonusName')
    if not bonusNameWidget then return end
    
    local perkColumn = self.perkPanel and self.perkPanel:getChildById('perkColumn_' .. levelIndex)
    if perkColumn and perkColumn.currentPerkPanel then
        for perkIdx = 0, 2 do
            local activeBonusIcon = perkColumn.currentPerkPanel:getChildById('bonusIcon' .. perkIdx)
            if activeBonusIcon and activeBonusIcon.active and activeBonusIcon.perkData then
                local _, tooltip = ProficiencyData:getBonusNameAndTooltip(activeBonusIcon.perkData)
                bonusNameWidget:setText(tooltip)
                bonusNameWidget:setTooltip(tooltip)
                bonusNameWidget:setImageSource("")
                return
            end
        end
    end

    local selectedPerkIndex = self.pendingSelections and self.pendingSelections[levelIndex]

    if not selectedPerkIndex and self.selectedItemId and self.cacheList[self.selectedItemId] then
        local cachedPerks = self.cacheList[self.selectedItemId].perks or {}
        for _, perk in ipairs(cachedPerks) do
            if type(perk) == "table" and perk[1] == levelIndex then
                selectedPerkIndex = perk[2]
                break
            end
        end
    end
    
    if selectedPerkIndex then
        -- Get perk data from the perk column
        if perkColumn and perkColumn.currentPerkPanel then
            local bonusIcon = perkColumn.currentPerkPanel:getChildById('bonusIcon' .. (selectedPerkIndex - 1))
            if bonusIcon and bonusIcon.perkData then
                local bonusName, tooltip = ProficiencyData:getBonusNameAndTooltip(bonusIcon.perkData)
                bonusNameWidget:setText(tooltip)
                bonusNameWidget:setTooltip(tooltip)
                bonusNameWidget:setImageSource("")
                return
            end
        end
    end
    
    -- No selection - show lock icon
    bonusNameWidget:setText("")
    bonusNameWidget:setImageSource("/images/game/proficiency/icon-lock-grey")
end

-- Update bonus detail panels at the bottom
function WeaponProficiency:updateBonusDetails(proficiencyContent, selectedPerks)
    local bonusDetailPanel = self.window:recursiveGetChildById('bonusDetailBackground')
    if not bonusDetailPanel then return end
    
    local levels = proficiencyContent.Levels or {}
    local cacheId = self.selectedMarketItem and self.selectedMarketItem.originalId or self.selectedItemId
    local cacheData = cacheId and self.cacheList[cacheId] or nil
    
    for i = 1, #levels do
        local detailPanel = bonusDetailPanel:getChildById('bonusDetail_' .. i)
        if detailPanel then
            local bonusNameWidget = detailPanel:getChildById('bonusName')
            local levelData = levels[i]
            
            if bonusNameWidget and levelData then
                -- Find selected perk for this level
                local selectedPerkIndex = nil
                if selectedPerks and type(selectedPerks) == "table" then
                    -- Check array format first: {{level, perkPos}, ...} (from cache/server)
                    local isArrayFormat = false
                    if #selectedPerks > 0 and type(selectedPerks[1]) == "table" then
                        isArrayFormat = true
                    for _, perk in ipairs(selectedPerks) do
                            if type(perk) == "table" and #perk >= 2 and perk[1] == i then
                                selectedPerkIndex = perk[2] -- Already 1-indexed from cache
                            break
                            end
                        end
                    end
                    
                    -- Check indexed format: {[levelIndex] = perkIndex} (from pendingSelections)
                    if not isArrayFormat and not selectedPerkIndex then
                        local key = i -- pendingSelections uses 1-indexed level
                        if selectedPerks[key] ~= nil then
                            local value = selectedPerks[key]
                            if type(value) == "number" then
                                selectedPerkIndex = value -- Already 1-indexed from pendingSelections
                            end
                        end
                    end
                end
                
                if selectedPerkIndex then
                    local perksData = levelData.Perks or {}
                    local perkData = perksData[selectedPerkIndex]
                    local modifiedSlot = getModifiedSlotFor(cacheData, i, selectedPerkIndex)
                    local modifiedPerkData = createModifiedPerkData(modifiedSlot)
                    perkData = modifiedPerkData or perkData
                    if perkData then
                        local bonusName, tooltip = ProficiencyData:getBonusNameAndTooltip(perkData)
                        bonusNameWidget:setText(tooltip)
                        bonusNameWidget:setTooltip(tooltip)
                        bonusNameWidget:setImageSource("") -- Hide lock icon
                    else
                        bonusNameWidget:setText("")
                        bonusNameWidget:setImageSource("/images/game/proficiency/icon-lock-grey")
                    end
                else
                    bonusNameWidget:setText("")
                    bonusNameWidget:setImageSource("/images/game/proficiency/icon-lock-grey")
                end
            elseif bonusNameWidget then
                bonusNameWidget:setText("")
                bonusNameWidget:setImageSource("/images/game/proficiency/icon-lock-grey")
            end
        end
    end
end

-- Handle item box click in the list
function WeaponProficiency:onItemBoxClick(widget)
    if not widget then return end
    
    local itemWidget = widget:getChildById('item')
    if not itemWidget then return end
    
    local itemId = itemWidget:getItemId()
    if not itemId or itemId == 0 then return end
    
    -- Find the market item data
    local categoryDropdown = self.window:recursiveGetChildById('classFilter')
    local currentCategory = MarketCategory.WeaponsAll
    
    if categoryDropdown then
        local selectedText = categoryDropdown:getText()
        currentCategory = WeaponStringToCategory[selectedText] or MarketCategory.WeaponsAll
    end
    
    local items = self.itemList[currentCategory] or {}
    local marketItem = nil
    
    for _, item in ipairs(items) do
        if item.displayItem and item.displayItem:getId() == itemId then
            marketItem = item
            break
        end
    end
    
    if marketItem then
        self:selectItem(itemId, marketItem)
    end
end

-- Apply filter for Level button
function WeaponProficiency:applyLevelFilter(items)
    if not self.filters["levelButton"] then return items end
    
    local player = g_game.getLocalPlayer()
    if not player then return items end
    
    local playerLevel = player:getLevel()
    local filteredItems = {}
    
    for _, item in ipairs(items) do
        local requiredLevel = item.marketData.requiredLevel or 0
        if playerLevel >= requiredLevel then
            table.insert(filteredItems, item)
        end
    end
    
    return filteredItems
end

-- Apply filter for Vocation button
function WeaponProficiency:applyVocationFilter(items)
    if not self.filters["vocButton"] then return items end
    
    local player = g_game.getLocalPlayer()
    if not player then return items end
    
    local playerVocation = player:getVocation()
    local filteredItems = {}
    
    for _, item in ipairs(items) do
        local restrictVocation = item.marketData.restrictVocation or 0
        -- If no restriction (0), show item - any vocation can use it
        if restrictVocation == 0 then
            table.insert(filteredItems, item)
        else
            -- Check if player's vocation bit is set in the restriction mask
            -- restrictVocation is a bitmask: bit N is set if vocation N can use the item
            -- playerVocation is 1-based (1=Knight, 2=Paladin, etc.)
            -- Ensure playerVocation is valid (>=1)
            if playerVocation >= 1 then
                -- Compute integer bit mask
                local vocBit
                if bit32 then
                    -- Use bit32 library if available
                    vocBit = bit32.lshift(1, playerVocation - 1)
                else
                    -- Fallback: build the mask with integer multiplication
                    vocBit = 1
                    for i = 1, playerVocation - 1 do
                        vocBit = vocBit * 2
                    end
                end
                
                if bit32 then
                    -- Use bit32 library if available
                    if bit32.band(restrictVocation, vocBit) ~= 0 then
                        table.insert(filteredItems, item)
                    end
                else
                    -- Fallback: use modulo arithmetic for bitwise AND
                    local shifted = math.floor(restrictVocation / vocBit)
                    if shifted % 2 == 1 then
                        table.insert(filteredItems, item)
                    end
                end
            end
        end
    end
    
    return filteredItems
end

-- Apply filter for 1H (one-handed) weapons
function WeaponProficiency:applyOneHandedFilter(items)
    if not self.filters["oneButton"] then return items end
    
    local filteredItems = {}
    for _, item in ipairs(items) do
        local thingType = item.thingType
        if thingType then
            -- Check if weapon is one-handed (not two-handed slot)
            local slotType = thingType.getClothSlot and thingType:getClothSlot() or 0
            if slotType ~= 2 then -- Not two-handed
                table.insert(filteredItems, item)
            end
        else
            table.insert(filteredItems, item)
        end
    end
    return filteredItems
end

-- Apply filter for 2H (two-handed) weapons
function WeaponProficiency:applyTwoHandedFilter(items)
    if not self.filters["twoButton"] then return items end
    
    local filteredItems = {}
    for _, item in ipairs(items) do
        local thingType = item.thingType
        if thingType then
            local slotType = thingType.getClothSlot and thingType:getClothSlot() or 0
            if slotType == 2 then -- Two-handed
                table.insert(filteredItems, item)
            end
        end
    end
    return filteredItems
end

-- Apply button click handler
function WeaponProficiency:onApplyClick()
    local success, err = pcall(function()
        self:applyPendingSelections()
    end)
    if not success then
        -- Log error with context before clearing
        warn("Failed to apply pending selections: " .. tostring(err))
        -- Clear pending selections on error to allow closing
        self.pendingSelections = {}
        self:updateApplyButtonState()
    end
end

-- Ok button click handler
function WeaponProficiency:onOkClick()
    -- Apply pending selections if any
    if self.pendingSelections and next(self.pendingSelections) ~= nil then
        local success, err = pcall(function()
            self:applyPendingSelections()
        end)
        if not success then
            -- Log error with context before clearing
            warn("Failed to apply pending selections in onOkClick: " .. tostring(err))
            -- Clear on error to allow closing
            self.pendingSelections = {}
        end
    end
    -- Always close window, even if there was an error
    hide()
end

-- Reset button click handler
function WeaponProficiency:onResetClick()
    self.pendingSelections = {}
    self.focusedPerk = nil
    
    -- Send empty perks list to server to clear all perks
    -- This is more reliable than using action type 2 (reset)
    if g_game.sendWeaponProficiencyApply and self.selectedItemId then
        -- Send empty arrays to clear all perks
        g_game.sendWeaponProficiencyApply(self.selectedItemId, {}, {})
    end
    
    -- Clear local cache and refresh display
    if self.selectedItemId and self.selectedMarketItem then
        local displayItem = self.selectedMarketItem.displayItem
        local cacheData = self.cacheList[self.selectedItemId]
        if displayItem and cacheData then
            -- Clear cached perks since we reset them
            cacheData.perks = {}
            self:displayPerks(self.selectedItemId, cacheData.perks, displayItem)
        end
    end
    
    self:updateApplyButtonState()
end

-- Apply pending perk selections to server
function WeaponProficiency:applyPendingSelections()
    if not self.selectedItemId then
        return
    end
    
    -- Build complete perk selection list for server
    -- Start with cached perks (already saved on server)
    local allPerks = {} -- {[levelIndex] = perkIndex} in 1-indexed format
    
    -- First, load existing cached perks
    if self.cacheList[self.selectedItemId] and self.cacheList[self.selectedItemId].perks then
        for _, perk in ipairs(self.cacheList[self.selectedItemId].perks) do
            if type(perk) == "table" and #perk >= 2 then
                allPerks[perk[1]] = perk[2]  -- level -> perkIndex (1-indexed)
            end
        end
    end
    
    -- Then, merge with pending selections (these override cached perks)
    if self.pendingSelections then
        for levelIndex, perkIndex in pairs(self.pendingSelections) do
            allPerks[levelIndex] = perkIndex  -- level -> perkIndex (1-indexed)
        end
    end
    
    -- Convert to array format for sending: {level (0-indexed), perkPosition (0-indexed)}
    local selections = {}
    for levelIndex, perkIndex in pairs(allPerks) do
        table.insert(selections, {levelIndex - 1, perkIndex - 1})
    end
    
    -- Sort by level for consistency
    table.sort(selections, function(a, b) return a[1] < b[1] end)
    
    if #selections == 0 then
        return
    end
    
    
    -- Build two parallel arrays for C++ (levels and perkPositions)
    local levels = {}
    local perkPositions = {}
    
    -- Log selection details (0-indexed in Lua, will be converted to 1-indexed in C++)
    for i, sel in ipairs(selections) do
        table.insert(levels, sel[1])
        table.insert(perkPositions, sel[2])
    end
    
    -- Send to server using the protocol function with two parallel arrays
    -- g_game.sendWeaponProficiencyApply(itemId, levelsArray, perkPositionsArray)
    if g_game.sendWeaponProficiencyApply then
        g_game.sendWeaponProficiencyApply(self.selectedItemId, levels, perkPositions)
        
        -- Update cache with ALL applied perks (convert back to server format: 1-indexed)
        -- This includes both cached perks and new pending selections
        if self.cacheList[self.selectedItemId] then
            local appliedPerks = {}
            for _, sel in ipairs(selections) do
                table.insert(appliedPerks, {sel[1] + 1, sel[2] + 1}) -- Convert back to 1-indexed for cache
            end
            self.cacheList[self.selectedItemId].perks = appliedPerks
            self.focusedPerk = nil
            
            -- Clear pendingSelections - perks are now saved in cache, no longer "pending"
            self.pendingSelections = {}
            
            -- Update UI immediately with applied perks (using cache format)
            -- This keeps the visual selection active
            if self.selectedMarketItem and self.selectedMarketItem.displayItem then
                self:displayPerks(self.selectedItemId, appliedPerks, self.selectedMarketItem.displayItem)
            end
        end
        
        -- Update button states (Apply should be disabled since we just applied)
        self:updateApplyButtonState()
        
        -- Clear the hasUnusedPerk flag and hide highlight after applying
        -- The user has now used their perks, so no notification needed
        self.hasUnusedPerk = false
        updateProficiencyHighlight()
        
        -- Request updated proficiency info from server to confirm
        scheduleEvent(function()
            if g_game.sendWeaponProficiencyAction and self.selectedItemId then
                g_game.sendWeaponProficiencyAction(0, self.selectedItemId)
            end
        end, 200)
    end
    
    -- Pending selections already cleared above
end

-- Update Apply/Ok/Reset button enabled state based on pending selections
function WeaponProficiency:updateApplyButtonState()
    if not self.window then return end
    
    local applyBtn = self.window:getChildById('apply')
    local okBtn = self.window:getChildById('ok')
    local resetBtn = self.window:getChildById('reset')
    
    local hasPendingSelections = self.pendingSelections and next(self.pendingSelections) ~= nil
    
    -- Check if there are applied perks in cache
    local hasAppliedPerks = false
    if self.selectedItemId and self.cacheList[self.selectedItemId] then
        local cachedPerks = self.cacheList[self.selectedItemId].perks
        hasAppliedPerks = cachedPerks and #cachedPerks > 0
    end
    
    -- Apply/Ok: enabled when there are pending selections (changes to apply)
    if applyBtn then
        applyBtn:setEnabled(hasPendingSelections)
    end
    if okBtn then
        okBtn:setEnabled(true) -- Always enabled to allow closing
    end
    
    -- Reset: enabled when there are applied perks
    if resetBtn then
        resetBtn:setEnabled(hasAppliedPerks)
    end
end


