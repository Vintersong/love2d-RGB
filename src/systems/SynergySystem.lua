-- SynergySystem: Manages artifact + color ability interactions (Vampire Survivors style)
-- Centralized synergy definitions for easy balancing

local SynergySystem = {}
local ColorSystem = require("src.systems.ColorSystem")

-- Active synergies (populated when artifacts are collected)
SynergySystem.activeSynergies = {}

-- Synergy definitions: [ARTIFACT_TYPE][COLOR] = effect data
SynergySystem.definitions = {
    -- PRISM synergies (projectile splitting)
    PRISM = {
        RED = {
            name = "Rainbow Cascade",
            description = "Spread projectiles split again on hit",
            effect = function(weapon, player)
                weapon.prismBonus = (weapon.prismBonus or 0) + 1  -- Double the split effect
                return "Rainbow Cascade activated! (+1 split)"
            end,
            visualEffect = {
                color = {1, 0.5, 1},  -- Pink
                particle = "fractal"
            }
        },
        YELLOW = {
            name = "Crystal Prison",
            description = "Rooted enemies grow prismatic crystals",
            effect = function(weapon, player)
                weapon.prismRootBonus = true
                weapon.rootRadius = (weapon.rootRadius or 0) + 30  -- Expand root effect
                return "Crystal Prison unlocked!"
            end,
            visualEffect = {
                color = {1, 1, 0.5},
                particle = "crystal"
            }
        }
    },
    
    -- LENS synergies (damage focus)
    LENS = {
        RED = {
            name = "Focal Burst",
            description = "Spread projectiles converge then explode",
            effect = function(weapon, player)
                weapon.lensBonus = (weapon.lensBonus or 0) + 0.3  -- +30% more damage
                weapon.focalBurst = true
                return "Focal Burst activated! (+30% focus)"
            end,
            visualEffect = {
                color = {1, 0.7, 0.3},
                particle = "converge"
            }
        },
        BLUE = {
            name = "Laser Focus",
            description = "Pierce damage increases per enemy hit",
            effect = function(weapon, player)
                weapon.lensBonus = (weapon.lensBonus or 0) + 0.25
                weapon.accumulatingPierce = true  -- Each pierce adds +10% damage
                return "Laser Focus activated! Pierce accumulates damage"
            end,
            visualEffect = {
                color = {0.5, 0.8, 1},
                particle = "beam"
            }
        },
        MAGENTA = {
            name = "Focused Detonation",
            description = "Explosions deal double damage in cone",
            effect = function(weapon, player)
                weapon.explodeDamage = weapon.explodeDamage * 1.5
                weapon.coneExplosion = true
                return "Focused Detonation! Explosions +50% damage"
            end,
            visualEffect = {
                color = {1, 0.3, 1},
                particle = "cone"
            }
        }
    },
    
    -- MIRROR synergies (reflection)
    MIRROR = {
        GREEN = {
            name = "Kaleidoscope",
            description = "Bounces create mirror reflections",
            effect = function(weapon, player)
                weapon.mirrorBounce = true
                weapon.bounceCount = (weapon.bounceCount or 1) + 1
                return "Kaleidoscope activated! Bounces reflect"
            end,
            visualEffect = {
                color = {0.5, 1, 0.8},
                particle = "mirror"
            }
        },
        CYAN = {
            name = "Reflected Suffering",
            description = "DoT bounces to nearest enemy on death",
            effect = function(weapon, player)
                weapon.dotChain = true
                weapon.dotChainRange = 150
                return "Reflected Suffering! DoT chains on death"
            end,
            visualEffect = {
                color = {0.5, 1, 1},
                particle = "chain"
            }
        }
    },
    
    -- HALO synergies (shield)
    HALO = {
        BLUE = {
            name = "Orbital Pierce",
            description = "Shield shoots piercing beams",
            effect = function(weapon, player)
                player.orbitalPierce = true
                player.orbitalDamage = weapon.damage * 0.5
                player.orbitalCooldown = 2.0  -- Fire every 2 seconds
                return "Orbital Pierce activated! Shield attacks"
            end,
            visualEffect = {
                color = {0.7, 0.9, 1},
                particle = "orbital"
            }
        }
    },
    
    -- AURORA synergies (health regen)
    AURORA = {
        GREEN = {
            name = "Chain Lightning",
            description = "Bounces leave electric trails",
            effect = function(weapon, player)
                weapon.electricTrail = true
                weapon.trailDamage = 5  -- DPS of trail
                weapon.trailDuration = 1.5  -- Trail lasts 1.5 seconds
                return "Chain Lightning! Bounces electrify"
            end,
            visualEffect = {
                color = {0.5, 1, 0.5},
                particle = "lightning"
            }
        },
        YELLOW = {
            name = "Static Field",
            description = "Rooted enemies pulse electricity",
            effect = function(weapon, player)
                weapon.staticPulse = true
                weapon.staticDamage = 3  -- Damage per pulse
                weapon.staticRadius = 80
                weapon.staticInterval = 0.5  -- Pulse every 0.5s
                return "Static Field! Roots electrify nearby"
            end,
            visualEffect = {
                color = {1, 1, 0.3},
                particle = "pulse"
            }
        },
        CYAN = {
            name = "Corrosive Cloud",
            description = "DoT creates spreading fog",
            effect = function(weapon, player)
                weapon.dotCloud = true
                weapon.cloudRadius = 60
                weapon.cloudDamage = weapon.dotDamage * 0.3
                return "Corrosive Cloud! DoT spreads as fog"
            end,
            visualEffect = {
                color = {0.3, 1, 0.8},
                particle = "cloud"
            }
        }
    },
    
    -- DIFFRACTION synergies (XP magnet)
    DIFFRACTION = {
        GREEN = {
            name = "Wave Echo",
            description = "Bounces create harmonic waves",
            effect = function(weapon, player)
                weapon.waveEcho = true
                weapon.wavePullForce = 50  -- Pull strength
                weapon.waveRadius = 100
                return "Wave Echo! Bounces pull enemies"
            end,
            visualEffect = {
                color = {0.5, 1, 0.5},
                particle = "wave"
            }
        },
        YELLOW = {
            name = "Gravity Well",
            description = "Rooted enemies become black holes",
            effect = function(weapon, player)
                weapon.gravityWell = true
                weapon.wellPullForce = 80
                weapon.wellRadius = 120
                return "Gravity Well! Roots pull enemies"
            end,
            visualEffect = {
                color = {1, 0.8, 0.3},
                particle = "gravity"
            }
        },
        CYAN = {
            name = "Poison Bloom",
            description = "DoT enemies explode into toxin",
            effect = function(weapon, player)
                weapon.poisonBloom = true
                weapon.bloomRadius = 90
                weapon.bloomDamage = weapon.dotDamage * 2
                return "Poison Bloom! DoT enemies explode"
            end,
            visualEffect = {
                color = {0.3, 1, 0.5},
                particle = "bloom"
            }
        }
    },
    
    -- REFRACTION synergies (speed boost)
    REFRACTION = {
        BLUE = {
            name = "Light Ray",
            description = "Pierce projectiles bend and multi-hit",
            effect = function(weapon, player)
                weapon.bendingPierce = true
                weapon.pierceCount = (weapon.pierceCount or 1) + 2  -- Pierce 2 more times
                return "Light Ray! Pierce bends around enemies"
            end,
            visualEffect = {
                color = {0.6, 0.4, 1},
                particle = "ray"
            }
        },
        MAGENTA = {
            name = "Shockwave",
            description = "Explosions send energy rings",
            effect = function(weapon, player)
                weapon.shockwave = true
                weapon.shockwaveSpeed = 200
                weapon.shockwaveDamage = weapon.explodeDamage * 0.4
                return "Shockwave! Explosions create rings"
            end,
            visualEffect = {
                color = {1, 0.4, 1},
                particle = "ring"
            }
        }
    },
    
    -- SUPERNOVA synergies (screen clear)
    SUPERNOVA = {
        RED = {
            name = "Solar Flare",
            description = "Screen clear leaves fire projectiles",
            effect = function(weapon, player)
                weapon.solarFlare = true
                weapon.flareCount = 12  -- 12 fire projectiles
                weapon.flareDamage = weapon.damage * 0.8
                return "Solar Flare! Screen clear spawns fire"
            end,
            visualEffect = {
                color = {1, 0.5, 0.2},
                particle = "flare"
            }
        },
        MAGENTA = {
            name = "Chain Reaction",
            description = "Explosions trigger cascade",
            effect = function(weapon, player)
                weapon.chainReaction = true
                weapon.chainChance = 0.5  -- 50% chance to chain
                weapon.chainRadius = weapon.explodeRadius * 1.5
                return "Chain Reaction! Explosions cascade"
            end,
            visualEffect = {
                color = {1, 0.2, 0.8},
                particle = "cascade"
            }
        }
    }
}

-- Check if a synergy exists and activate it
function SynergySystem.checkAndActivate(artifactType, weapon, player)
    local primary = ColorSystem.primaryColor
    local secondary = ColorSystem.secondaryColor
    local tertiary = ColorSystem.tertiaryColor
    
    -- Check synergies in order: tertiary > secondary > primary
    local colors = {}
    if tertiary then table.insert(colors, tertiary:upper()) end
    if secondary then table.insert(colors, secondary:upper()) end
    if primary then table.insert(colors, primary:upper()) end
    
    -- Check each color for synergy
    for _, color in ipairs(colors) do
        if SynergySystem.definitions[artifactType] and 
           SynergySystem.definitions[artifactType][color] then
            
            local synergy = SynergySystem.definitions[artifactType][color]
            local synergyKey = artifactType .. "_" .. color
            
            -- Only activate once
            if not SynergySystem.activeSynergies[synergyKey] then
                SynergySystem.activeSynergies[synergyKey] = {
                    name = synergy.name,
                    description = synergy.description,
                    visual = synergy.visualEffect
                }
                
                -- Apply the synergy effect
                local message = synergy.effect(weapon, player)
                
                print("[SYNERGY] " .. synergy.name .. " activated!")
                
                return message  -- Return message to display to player
            end
        end
    end
    
    return nil  -- No synergy found
end

-- Get all active synergies (for UI display)
function SynergySystem.getActiveSynergies()
    local synergies = {}
    for key, data in pairs(SynergySystem.activeSynergies) do
        table.insert(synergies, data)
    end
    return synergies
end

-- Reset synergies (on game restart)
function SynergySystem.reset()
    SynergySystem.activeSynergies = {}
end

-- Get synergy count (for UI)
function SynergySystem.getCount()
    local count = 0
    for _ in pairs(SynergySystem.activeSynergies) do
        count = count + 1
    end
    return count
end

return SynergySystem
