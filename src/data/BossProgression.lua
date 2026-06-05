-- BossProgression.lua
-- Defines run boss tiers. Each encounter can restrict mechanics and tune stats.

local BossProgression = {}

local TIERS = {
    {
        name = "Vector Warden",
        archetype = "warrior",
        color = {0.1, 0.82, 1.0},
        health = 3200,
        damage = 24,
        speed = 84,
        size = 128,
        attackRate = 0.72,
        movement = {"horizontal_oscillate"},
        phase = {"phase_low_health"},
        attack = {"single_shot", "spread_cone", "wave"},
        intro = "BOSS 01: VECTOR WARDEN",
    },
    {
        name = "Phase Lancer",
        archetype = "berserker",
        color = {1.0, 0.25, 0.35},
        health = 4300,
        damage = 29,
        speed = 108,
        size = 136,
        attackRate = 0.62,
        movement = {"horizontal_oscillate", "track_player_slow"},
        phase = {"dash_strike", "phase_low_health"},
        attack = {"single_shot", "spread_cone", "wave"},
        intro = "BOSS 02: PHASE LANCER",
    },
    {
        name = "Prism Architect",
        archetype = "mage",
        color = {1.0, 0.22, 0.9},
        health = 5600,
        damage = 33,
        speed = 98,
        size = 145,
        attackRate = 0.54,
        movement = {"horizontal_oscillate"},
        phase = {"phase_low_health"},
        attack = {"spread_cone", "spiral", "circle_burst", "cross"},
        intro = "BOSS 03: PRISM ARCHITECT",
    },
    {
        name = "Nova Engine",
        archetype = "mage",
        color = {1.0, 0.9, 0.05},
        health = 7200,
        damage = 38,
        speed = 112,
        size = 152,
        attackRate = 0.48,
        movement = {"horizontal_oscillate", "track_player_slow"},
        phase = {"phase_low_health"},
        attack = {"circle_burst", "slam", "double_spiral", "flower"},
        intro = "BOSS 04: NOVA ENGINE",
    },
}

local function copyArray(source)
    local result = {}
    for i, value in ipairs(source or {}) do
        result[i] = value
    end
    return result
end

local function copyColor(color)
    return {color[1], color[2], color[3], color[4]}
end

local function buildAllowedSet(ids)
    local set = {}
    for _, id in ipairs(ids or {}) do
        set[id] = true
    end
    return set
end

local function scaledTier(index)
    local base = TIERS[((index - 1) % #TIERS) + 1]
    local cycle = math.floor((index - 1) / #TIERS)
    local healthScale = 1 + cycle * 0.62
    local damageScale = 1 + cycle * 0.22
    local speedScale = 1 + cycle * 0.1
    local rateScale = math.max(0.62, 1 - cycle * 0.07)

    return {
        index = index,
        name = cycle > 0 and string.format("%s Mk %d", base.name, cycle + 1) or base.name,
        archetype = base.archetype,
        color = copyColor(base.color),
        health = math.floor(base.health * healthScale),
        damage = math.floor(base.damage * damageScale),
        speed = math.floor(base.speed * speedScale),
        size = base.size + cycle * 8,
        attackRate = base.attackRate * rateScale,
        movement = copyArray(base.movement),
        phase = copyArray(base.phase),
        attack = copyArray(base.attack),
        intro = cycle > 0
            and string.format("BOSS %02d: %s MK %d", index, string.upper(base.name), cycle + 1)
            or base.intro,
    }
end

function BossProgression.getTierCount()
    return #TIERS
end

function BossProgression.getForEncounter(index)
    index = math.max(1, math.floor(index or 1))
    local tier = scaledTier(index)
    tier.allowedIds = {
        movement = buildAllowedSet(tier.movement),
        phase = buildAllowedSet(tier.phase),
        attack = buildAllowedSet(tier.attack),
    }
    return tier
end

return BossProgression
