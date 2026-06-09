-- ColorEconomy.lua
-- Single owner of the moment-to-moment XP routing economy.
--
-- Enemies carry a color affinity (RED/GREEN/BLUE, assigned in the spawn path).
-- On each kill we classify the enemy's affinity against the player's committed
-- ColorSystem state and pay an XP multiplier. The economy is inactive until the
-- player locks both primaries; after that, matching your dominant primary pays
-- best, matching the other committed primary is neutral, and the locked-out
-- third primary is penalized (but never worthless — see the floor in Config).
--
-- This module NEVER caches ColorSystem state; it re-derives on every call so a
-- future respec (Divergent Lens) needs no teardown here.
--
-- Expected-value sanity check (see DESIGN_DOC §4):
--   Under a uniform spawn distribution (1/3 of each affinity) for a committed
--   pair, one affinity is dominant (1.5x), one committed (1.0x), one off (0.5x):
--       (1.5 + 1.0 + 0.5) / 3 = 1.0
--   So a player who ignores routing averages ~1.0x — within ±10% of the
--   pre-economy build. The <= affinityClampPct clamp in EnemySpawner keeps a
--   music-skewed track from breaking this. Skilled streak play can push intake
--   above baseline; that is flagged for review, NOT silently retuned here.

local Config = require("src.Config")
local ColorSystem = require("src.gameplay.ColorSystem")

local ColorEconomy = {}

-- Run state (reset per run).
ColorEconomy.streak = 0           -- consecutive dominant-match kills
ColorEconomy._wasActive = false   -- rising-edge flag for the activation banner

function ColorEconomy.init()
    ColorEconomy.streak = 0
    ColorEconomy._wasActive = false
end

-- Alias so callers can use either name.
ColorEconomy.reset = ColorEconomy.init

-- Economy activates once the player has committed (locked) both primaries.
function ColorEconomy.isActive()
    return ColorSystem.commitment.locked == true
end

-- Of the two committed primaries, the higher-level one is "dominant".
-- Ties resolve to primary1 (the first commitment).
function ColorEconomy.getDominantPrimary()
    local c = ColorSystem.commitment
    if not c.primary1 then return nil end
    if not c.primary2 then return c.primary1 end
    local l1 = ColorSystem.primary[c.primary1].level
    local l2 = ColorSystem.primary[c.primary2].level
    if l2 > l1 then return c.primary2 end
    return c.primary1
end

-- True once any secondary (YELLOW/MAGENTA/CYAN) has unlocked. After this point
-- EITHER committed primary counts as a dominant match — the late-run payoff for
-- full commitment.
local function secondaryUnlocked()
    for _, data in pairs(ColorSystem.secondary) do
        if data.unlocked then return true end
    end
    return false
end

-- Classify an affinity ("RED"/"GREEN"/"BLUE") against current color state.
-- Returns killType ("dominant"|"committed"|"off"|"precommit") and the base
-- multiplier (before streak bonus).
function ColorEconomy.classify(affinity)
    local mult = Config.colorEconomy.xpMult
    if not ColorEconomy.isActive() or not affinity then
        return "precommit", mult.preCommit
    end

    local c = ColorSystem.commitment
    local isCommitted = (affinity == c.primary1 or affinity == c.primary2)

    if not isCommitted then
        -- Locked-out third primary.
        return "off", mult.off
    end

    if secondaryUnlocked() then
        -- Graduation: either committed primary pays dominant.
        return "dominant", mult.dominant
    end

    if affinity == ColorEconomy.getDominantPrimary() then
        return "dominant", mult.dominant
    end
    return "committed", mult.committed
end

-- Streak bonus added to the dominant multiplier, capped.
local function streakBonus()
    local s = Config.colorEconomy.streak
    local milestones = math.floor(ColorEconomy.streak / s.perMilestone)
    return math.min(milestones * s.bonusPerMilestone, s.maxBonus)
end

-- Brand neon color for an affinity, for floating-text feedback.
local function affinityColor(affinity)
    local key = affinity and affinity:lower()
    return key and Config.theme.colors[key] or {1, 1, 1}
end

-- Classify a kill, advance the streak, and return feedback data:
--   { multiplier, killType, color, milestone }
-- `milestone` is the streak count when a new milestone is crossed (else nil).
function ColorEconomy.registerKill(enemy)
    local affinity = enemy and enemy.affinity
    local killType, baseMult = ColorEconomy.classify(affinity)
    local s = Config.colorEconomy.streak

    local milestone = nil
    if killType == "dominant" then
        ColorEconomy.streak = ColorEconomy.streak + 1
        if ColorEconomy.streak % s.perMilestone == 0 then
            milestone = ColorEconomy.streak
        end
    elseif killType == "off" then
        ColorEconomy.streak = 0
    end
    -- "committed" and "precommit" leave the streak untouched.

    local multiplier = baseMult
    if killType == "dominant" then
        multiplier = baseMult + streakBonus()
    end

    local color
    if killType == "off" then
        color = {0.55, 0.55, 0.6}        -- dimmed gray: absence of color is the signal
    elseif killType == "precommit" then
        color = {0.85, 0.85, 0.9}        -- neutral; economy not yet active
    else
        color = affinityColor(affinity)  -- matched: pay in the matched color
    end

    return {
        multiplier = multiplier,
        killType = killType,
        color = color,
        milestone = milestone,
    }
end

-- Poll once per frame. Fires the one-time activation banner on the rising edge
-- of isActive() (the moment the second primary locks in).
function ColorEconomy.update(dt)
    local active = ColorEconomy.isActive()
    if active and not ColorEconomy._wasActive then
        local FloatingTextSystem = require("src.effects.FloatingTextSystem")
        FloatingTextSystem.addAchievement(
            "COLOR ECONOMY ACTIVE",
            "hunt your colors",
            Config.theme.colors.accent
        )
    end
    ColorEconomy._wasActive = active
end

-- Debug: current economy snapshot (multipliers + streak).
function ColorEconomy.getState()
    local mult = Config.colorEconomy.xpMult
    return {
        active = ColorEconomy.isActive(),
        dominantPrimary = ColorEconomy.getDominantPrimary(),
        secondaryUnlocked = secondaryUnlocked(),
        streak = ColorEconomy.streak,
        streakBonus = streakBonus(),
        dominantMult = mult.dominant + (ColorEconomy.isActive() and streakBonus() or 0),
        committedMult = mult.committed,
        offMult = mult.off,
    }
end

return ColorEconomy
