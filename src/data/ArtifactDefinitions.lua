-- ArtifactDefinitions.lua
-- Data-driven artifact definitions
-- Artifacts are pure data that reference effects from EffectLibrary

return {
    -- ========================================================================
    -- HALO ARTIFACT - Aura effects based on color
    -- ========================================================================
    HALO = {
        name = "Halo",
        description = "Color-based aura effects",
        maxLevel = 5,

        -- Color variants reference effects from EffectLibrary
        colors = {
            RED = {
                name = "Crimson Halo",
                effects = {"pulseDamage", "pulsingRing"},
                visual = "red_pulsing_ring",

                -- State initialization per level
                init = function(level)
                    return {
                        minRadius = 30,
                        maxRadius = 60 + (level * 10),
                        pulseSpeed = 1.5,
                        damage = 10 * level,
                        pulsePhase = 0,
                        color = {1, 0.2, 0.2}
                    }
                end
            },

            GREEN = {
                name = "Verdant Halo",
                effects = {"drainDamage", "staticRing"},
                visual = "green_drain_tendrils",

                init = function(level)
                    return {
                        radius = 80 + (level * 10),
                        drainRate = 5 * level,
                        healPercent = 0.5,
                        color = {0.2, 1, 0.2}
                    }
                end
            },

            BLUE = {
                name = "Azure Halo",
                effects = {"slowEffect", "staticRing"},
                visual = "blue_frost_mist",

                init = function(level)
                    return {
                        radius = 90 + (level * 10),
                        slowPercent = 0.3 + (level * 0.05),
                        color = {0.2, 0.4, 1}
                    }
                end
            },

            YELLOW = {
                name = "Electric Halo",
                effects = {"pulseDamage", "drainDamage", "pulsingRing"},
                visual = "yellow_electric_ring",

                init = function(level)
                    return {
                        radius = 70 + (level * 8),
                        pulseSpeed = 3.0,
                        damage = 15 * level,
                        drainRate = 8 * level,
                        healPercent = 0.3,
                        color = {1, 1, 0.2}
                    }
                end
            },

            MAGENTA = {
                name = "Temporal Halo",
                effects = {"pulseDamage", "slowEffect", "staticRing"},
                visual = "magenta_time_bubble",

                init = function(level)
                    return {
                        radius = 85 + (level * 10),
                        damage = 8 * level,
                        slowPercent = 0.6,
                        color = {1, 0.2, 1}
                    }
                end
            },

            CYAN = {
                name = "Glacial Halo",
                effects = {"drainDamage", "slowEffect", "staticRing"},
                visual = "cyan_frost_drain",

                init = function(level)
                    return {
                        radius = 80 + (level * 10),
                        drainRate = 4 * level,
                        slowPercent = 0.4,
                        healPercent = 0.4,
                        color = {0.2, 1, 1}
                    }
                end
            }
        }
    },

    -- ========================================================================
    -- PRISM ARTIFACT - Projectile splitting
    -- ========================================================================
    PRISM = {
        name = "Prism",
        description = "Splits projectiles into multiple beams",
        maxLevel = 5,

        colors = {
            RED = {
                name = "Crimson Prism",
                effects = {"splitProjectile"},
                chance = function(level) return 0.20 + (level * 0.02) end,

                init = function(level)
                    return {
                        splitCount = 5 + level,
                        splitDistance = 100,
                        spreadAngle = math.pi / 3  -- 60 degrees
                    }
                end
            },

            GREEN = {
                name = "Verdant Prism",
                effects = {"homingProjectile"},
                chance = function(level) return 0.15 + (level * 0.02) end,

                init = function(level)
                    return {
                        turnRate = 2.0 + (level * 0.5),
                        lockRange = 200
                    }
                end
            },

            BLUE = {
                name = "Azure Prism",
                effects = {"duplicateProjectile"},
                chance = function(level) return 0.25 + (level * 0.03) end,

                init = function(level)
                    return {
                        duplicateCount = 1 + math.floor(level / 2)
                    }
                end
            }
        }
    },

    -- ========================================================================
    -- LENS ARTIFACT - Focus and magnification
    -- ========================================================================
    LENS = {
        name = "Lens",
        description = "Focuses damage output",
        maxLevel = 5,

        -- Lens doesn't have color variants, just levels
        effects = {"damageMultiplier", "sizeIncrease"},

        init = function(level)
            return {
                damageBonus = 0.5 + (level * 0.25),  -- +50%, +75%, +100%, etc.
                sizeBonus = 0.1 * level  -- +10% per level
            }
        end
    },

    -- ========================================================================
    -- MIRROR ARTIFACT - Reflection
    -- ========================================================================
    MIRROR = {
        name = "Mirror",
        description = "Reflects damage back to attackers",
        maxLevel = 5,

        colors = {
            RED = {
                name = "Crimson Mirror",
                effects = {"duplicateProjectile"},

                init = function(level)
                    return {
                        duplicateCount = 1,
                        reflectAngle = math.pi  -- 180 degrees (backward)
                    }
                end
            }
        }
    },

    -- ========================================================================
    -- DASH ARTIFACT - Active ability: Color-reactive dash with invulnerability
    -- ========================================================================
    DASH = {
        name = "Phase Blink",
        description = "Press SPACE to dash (invulnerable). Effects based on color affinity:\nRED: Speed boost after | GREEN: Heal | BLUE: Pierce enemies\nYELLOW: Heal + Speed | PURPLE: Pierce + DoT | CYAN: Pierce + Life steal",
        maxLevel = 5,
        abilityType = "active",  -- Mark as active ability
        cooldown = 5.0,  -- Base cooldown in seconds

        -- Level-based improvements
        levels = {
            {cooldown = 5.0, description = "5s cooldown"},
            {cooldown = 4.5, description = "4.5s cooldown"},
            {cooldown = 4.0, description = "4s cooldown"},
            {cooldown = 3.5, description = "3.5s cooldown"},
            {cooldown = 3.0, description = "3s cooldown"}
        }
    }
}
