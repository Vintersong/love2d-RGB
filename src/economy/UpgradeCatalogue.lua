-- UpgradeCatalogue.lua
-- Defines every purchasable upgrade, their costs, tiers, and effects.
-- This file is DATA ONLY - no logic, no side effects.
-- ShopSystem reads this table. UpgradeSystem applies the effects.
--
-- STRUCTURE per upgrade entry:
--   id          (string)  - unique key, used as reference everywhere
--   name        (string)  - display name
--   description (string)  - tooltip shown in shop
--   icon        (string)  - icon key for HUD/shop (maps to Icons module)
--   category    (string)  - "combat", "defense", "utility", "artifact_slot"
--   maxTier     (number)  - how many times purchasable (1 = one-shot)
--   costs       (table)   - shard cost per tier: costs[1] = tier-1 cost, etc.
--   unlocks     (table?)  - list of artifact IDs unlocked when this is purchased
--                           (optional; only on artifact_slot upgrades)
--   requires    (table?)  - list of {id, tier} prerequisites
--                           e.g. { {id="DMG_BOOST", tier=2} }
--
-- STAT EFFECT KEYS (used by UpgradeSystem when wiring in):
--   statKey     (string)  - player stat field to modify (e.g. "maxHp", "speed")
--   statMode    (string)  - "add" | "multiply"
--   statValues  (table)   - per-tier delta: statValues[1] applied at tier 1, etc.

local UpgradeCatalogue = {}

-- ============================================================================
-- COMBAT UPGRADES
-- ============================================================================

UpgradeCatalogue.DAMAGE_BOOST = {
    id          = "DAMAGE_BOOST",
    name        = "Prismatic Edge",
    description = "Increase projectile damage by 10% per tier.",
    icon        = "sword",
    category    = "combat",
    maxTier     = 5,
    costs       = {15, 25, 40, 60, 90},
    statKey     = "weaponDamageMult",  -- applied to weapon.damageMult
    statMode    = "multiply",
    statValues  = {1.10, 1.10, 1.10, 1.10, 1.10},
}

UpgradeCatalogue.FIRE_RATE = {
    id          = "FIRE_RATE",
    name        = "Rapid Refraction",
    description = "Reduce weapon fire interval by 8% per tier.",
    icon        = "zap",
    category    = "combat",
    maxTier     = 4,
    costs       = {20, 35, 55, 80},
    statKey     = "weaponFireRateMult",
    statMode    = "multiply",
    statValues  = {0.92, 0.92, 0.92, 0.92},
}

UpgradeCatalogue.PROJECTILE_SPEED = {
    id          = "PROJECTILE_SPEED",
    name        = "Waveform Burst",
    description = "Increase projectile travel speed by 15% per tier.",
    icon        = "wind",
    category    = "combat",
    maxTier     = 3,
    costs       = {20, 40, 65},
    statKey     = "weaponSpeedMult",
    statMode    = "multiply",
    statValues  = {1.15, 1.15, 1.15},
}

UpgradeCatalogue.MULTISHOT = {
    id          = "MULTISHOT",
    name        = "Split Beam",
    description = "Fire one additional projectile per tier (spread pattern).",
    icon        = "git-branch",
    category    = "combat",
    maxTier     = 3,
    costs       = {40, 70, 110},
    statKey     = "weaponExtraProjectiles",
    statMode    = "add",
    statValues  = {1, 1, 1},
    requires    = {{id = "DAMAGE_BOOST", tier = 2}},
}

-- ============================================================================
-- DEFENSE UPGRADES
-- ============================================================================

UpgradeCatalogue.MAX_HEALTH = {
    id          = "MAX_HEALTH",
    name        = "Resonant Shell",
    description = "Increase maximum HP by 20 per tier.",
    icon        = "heart",
    category    = "defense",
    maxTier     = 5,
    costs       = {15, 25, 40, 60, 85},
    statKey     = "maxHp",
    statMode    = "add",
    statValues  = {20, 20, 20, 20, 20},
}

UpgradeCatalogue.REGEN = {
    id          = "REGEN",
    name        = "Harmonic Mend",
    description = "Passively regenerate 1 HP per second per tier.",
    icon        = "activity",
    category    = "defense",
    maxTier     = 3,
    costs       = {30, 55, 85},
    statKey     = "hpRegenPerSec",
    statMode    = "add",
    statValues  = {1, 1, 1},
    requires    = {{id = "MAX_HEALTH", tier = 2}},
}

UpgradeCatalogue.SHIELD_DURATION = {
    id          = "SHIELD_DURATION",
    name        = "Chromatic Barrier",
    description = "Extend SHIELD ability active duration by 0.5s per tier.",
    icon        = "shield",
    category    = "defense",
    maxTier     = 3,
    costs       = {25, 45, 70},
    statKey     = "shieldDurationBonus",
    statMode    = "add",
    statValues  = {0.5, 0.5, 0.5},
}

UpgradeCatalogue.DASH_CHARGES = {
    id          = "DASH_CHARGES",
    name        = "Phase Burst",
    description = "Gain one extra DASH charge per tier (max 2 tiers).",
    icon        = "chevrons-right",
    category    = "defense",
    maxTier     = 2,
    costs       = {35, 65},
    statKey     = "dashCharges",
    statMode    = "add",
    statValues  = {1, 1},
}

-- ============================================================================
-- UTILITY UPGRADES
-- ============================================================================

UpgradeCatalogue.MOVE_SPEED = {
    id          = "MOVE_SPEED",
    name        = "Frequency Shift",
    description = "Increase player movement speed by 10% per tier.",
    icon        = "trending-up",
    category    = "utility",
    maxTier     = 4,
    costs       = {15, 28, 45, 68},
    statKey     = "speed",
    statMode    = "multiply",
    statValues  = {1.10, 1.10, 1.10, 1.10},
}

UpgradeCatalogue.MAGNET_RANGE = {
    id          = "MAGNET_RANGE",
    name        = "Gravity Well",
    description = "Increase XP orb magnetic pull range by 40px per tier.",
    icon        = "compass",
    category    = "utility",
    maxTier     = 3,
    costs       = {20, 38, 60},
    statKey     = "orbMagnetBonus",
    statMode    = "add",
    statValues  = {40, 40, 40},
}

UpgradeCatalogue.SHARD_INCOME = {
    id          = "SHARD_INCOME",
    name        = "Prismatic Greed",
    description = "Multiply all Prism Shard drops by 10% per tier.",
    icon        = "gem",
    category    = "utility",
    maxTier     = 3,
    costs       = {30, 55, 85},
    -- Effect applied via EconomySystem.setMultiplier() - not a plain statKey.
    -- UpgradeSystem special-case: id == "SHARD_INCOME" -> call EconomySystem.setMultiplier()
    statKey     = "shardMultiplier",
    statMode    = "multiply",
    statValues  = {1.10, 1.10, 1.10},
}

-- ============================================================================
-- ARTIFACT SLOT UPGRADES
-- These are one-shot purchases that UNLOCK artifact drop eligibility.
-- Artifacts will not drop in-run until their corresponding slot is purchased.
-- ============================================================================

UpgradeCatalogue.ARTIFACT_SLOT_1 = {
    id          = "ARTIFACT_SLOT_1",
    name        = "Resonance Chamber I",
    description = "Unlocks artifact drops in-run. Artifacts can now appear as world pickups.",
    icon        = "box",
    category    = "artifact_slot",
    maxTier     = 1,
    costs       = {50},
    unlocks     = {"HALO", "LENS", "PRISM"},
}

UpgradeCatalogue.ARTIFACT_SLOT_2 = {
    id          = "ARTIFACT_SLOT_2",
    name        = "Resonance Chamber II",
    description = "Unlocks advanced artifact drops: Mirror, Aurora, Diffraction.",
    icon        = "layers",
    category    = "artifact_slot",
    maxTier     = 1,
    costs       = {100},
    requires    = {{id = "ARTIFACT_SLOT_1", tier = 1}},
    unlocks     = {"MIRROR", "AURORA", "DIFFRACTION"},
}

UpgradeCatalogue.ARTIFACT_SLOT_3 = {
    id          = "ARTIFACT_SLOT_3",
    name        = "Resonance Chamber III",
    description = "Unlocks rare artifact drops: Refraction, Supernova.",
    icon        = "star",
    category    = "artifact_slot",
    maxTier     = 1,
    costs       = {180},
    requires    = {{id = "ARTIFACT_SLOT_2", tier = 1}},
    unlocks     = {"REFRACTION", "SUPERNOVA"},
}

-- ============================================================================
-- ORDERED LIST for shop iteration (controls display order)
-- ============================================================================

UpgradeCatalogue.ALL = {
    -- Combat
    UpgradeCatalogue.DAMAGE_BOOST,
    UpgradeCatalogue.FIRE_RATE,
    UpgradeCatalogue.PROJECTILE_SPEED,
    UpgradeCatalogue.MULTISHOT,
    -- Defense
    UpgradeCatalogue.MAX_HEALTH,
    UpgradeCatalogue.REGEN,
    UpgradeCatalogue.SHIELD_DURATION,
    UpgradeCatalogue.DASH_CHARGES,
    -- Utility
    UpgradeCatalogue.MOVE_SPEED,
    UpgradeCatalogue.MAGNET_RANGE,
    UpgradeCatalogue.SHARD_INCOME,
    -- Artifact slots
    UpgradeCatalogue.ARTIFACT_SLOT_1,
    UpgradeCatalogue.ARTIFACT_SLOT_2,
    UpgradeCatalogue.ARTIFACT_SLOT_3,
}

--- Helper: look up an upgrade by id string.
function UpgradeCatalogue.get(id)
    for _, upgrade in ipairs(UpgradeCatalogue.ALL) do
        if upgrade.id == id then return upgrade end
    end
    return nil
end

return UpgradeCatalogue
