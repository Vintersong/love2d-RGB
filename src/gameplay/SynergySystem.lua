-- SynergySystem: Manages artifact + color ability interactions (Vampire Survivors style)
-- Centralized synergy definitions for easy balancing

local SynergySystem = {}
local ColorSystem = require("src.gameplay.ColorSystem")

-- Active synergies (populated when artifacts are collected)
SynergySystem.activeSynergies = {}

-- Synergy definitions: [ARTIFACT_TYPE][COLOR] = effect data
SynergySystem.definitions = {
    -- PRISM synergies (projectile splitting)
    PRISM = {
        CYAN = {
            name = "Orbit Freeze",
            description = "When an orbiting shot triggers its freeze, the chill chains to nearby enemies",
            effect = function(weapon, player)
                weapon.prismOrbitChainFreeze = true
                weapon.orbitFreezeChainRadius = 80
                weapon.orbitFreezeChainDuration = 2.0
                return "Orbit Freeze! Freeze chains to nearby enemies"
            end,
            visualEffect = {
                color = {0.4, 1, 1},
                particle = "chain_frost"
            }
        },
        MAGENTA = {
            name = "Seeking Volley",
            description = "Wall shots home toward the nearest enemy after firing",
            effect = function(weapon, player)
                weapon.prismWallHoming = true
                weapon.prismHomingStrength = 1.5
                return "Seeking Volley! Wall shots track enemies"
            end,
            visualEffect = {
                color = {1, 0.3, 1},
                particle = "homing_trail"
            }
        },
        BLUE = {
            name = "Prism Array",
            description = "Growing pierce shots fracture into three piercing shards at maximum size",
            effect = function(weapon, player)
                weapon.prismFracture = true
                weapon.prismFractureCount = 3
                return "Prism Array! Max-size shots shatter into shards"
            end,
            visualEffect = {
                color = {0.4, 0.7, 1},
                particle = "fracture_shards"
            }
        },
        GREEN = {
            name = "Orbit Siphon",
            description = "Orbiting projectiles drain life on each hit, healing the player",
            effect = function(weapon, player)
                weapon.prismOrbitHeal = true
                weapon.orbitHealPerHit = 2
                return "Orbit Siphon! Orbiting shots restore HP"
            end,
            visualEffect = {
                color = {0.3, 1, 0.4},
                particle = "drain_orbit"
            }
        },
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
        CYAN = {
            name = "Glacial Convergence",
            description = "The frost pull shot chains its slow to three nearby enemies on impact",
            effect = function(weapon, player)
                weapon.lensChainSlow = true
                weapon.chainSlowCount = 3
                weapon.chainSlowRange = 120
                return "Glacial Convergence! Frost shot chains slow to 3 enemies"
            end,
            visualEffect = {
                color = {0.35, 0.9, 1},
                particle = "frost_chain"
            }
        },
        YELLOW = {
            name = "Thunderball",
            description = "Merged electric shot explodes on impact, leaving a damaging lightning field",
            effect = function(weapon, player)
                weapon.lensThunderball = true
                weapon.thunderfieldRadius = 80
                weapon.thunderfieldDPS = 15
                weapon.thunderfieldDuration = 2.0
                return "Thunderball! Merged shot leaves a lightning field"
            end,
            visualEffect = {
                color = {1, 1, 0.25},
                particle = "thunder_field"
            }
        },
        GREEN = {
            name = "Singularity Shot",
            description = "Enemies pulled to close range by the gravitational field take bonus damage",
            effect = function(weapon, player)
                weapon.lensPullBonus = true
                weapon.lensPullDamageBonus = 0.5
                weapon.lensPullBonusRange = 40
                return "Singularity Shot! Pulled enemies take +50% damage"
            end,
            visualEffect = {
                color = {0.4, 1, 0.5},
                particle = "gravity_crush"
            }
        },
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
        MAGENTA = {
            name = "Phantom Echo",
            description = "The temporal echo clone fires a homing copy of the shot at full damage",
            effect = function(weapon, player)
                weapon.mirrorPhantomHoming = true
                weapon.phantomHomingStrength = 2.0
                weapon.phantomFullDamage = true
                return "Phantom Echo! Echo clones home at full damage"
            end,
            visualEffect = {
                color = {1, 0.25, 0.9},
                particle = "phantom_trail"
            }
        },
        YELLOW = {
            name = "Arc Flash",
            description = "Electric dual-wall shots discharge on hit, stunning the target briefly",
            effect = function(weapon, player)
                weapon.mirrorArcStun = true
                weapon.mirrorStunDuration = 0.4
                return "Arc Flash! Mirror shots stun on impact"
            end,
            visualEffect = {
                color = {1, 1, 0.3},
                particle = "arc_discharge"
            }
        },
        BLUE = {
            name = "Prismatic Shards",
            description = "Split projectiles each gain an extra pierce, cutting through more enemies",
            effect = function(weapon, player)
                weapon.mirrorSplitPierce = true
                weapon.mirrorSplitPierceBonus = 1
                return "Prismatic Shards! Split shots pierce through enemies"
            end,
            visualEffect = {
                color = {0.5, 0.8, 1},
                particle = "shard_pierce"
            }
        },
        RED = {
            name = "Searing Reflection",
            description = "Mirrored projectiles leave fire trails that burn on contact",
            effect = function(weapon, player)
                weapon.mirrorFireTrail = true
                weapon.mirrorTrailDamage = 8
                weapon.mirrorTrailDuration = 2.0
                return "Searing Reflection! Mirror shots ignite trails"
            end,
            visualEffect = {
                color = {1, 0.4, 0.1},
                particle = "trail_fire"
            }
        },
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
        CYAN = {
            name = "Glacial Ward",
            description = "Enemies killed inside the frost aura leave ice patches that slow others",
            effect = function(weapon, player)
                player.haloGlacialPatches = true
                player.glacialPatchRadius = 60
                player.glacialPatchSlow = 0.4
                player.glacialPatchDuration = 4.0
                return "Glacial Ward! Aura kills leave slowing ice patches"
            end,
            visualEffect = {
                color = {0.3, 0.95, 1},
                particle = "ice_patch"
            }
        },
        MAGENTA = {
            name = "Temporal Ward",
            description = "Enemies inside the time bubble take 25% increased damage from all sources",
            effect = function(weapon, player)
                player.haloTemporalAmp = true
                player.temporalDamageBonus = 0.25
                return "Temporal Ward! Time bubble amplifies all damage taken"
            end,
            visualEffect = {
                color = {1, 0.2, 1},
                particle = "time_distort"
            }
        },
        YELLOW = {
            name = "Storm Halo",
            description = "Each pulse kill discharges a lightning bolt to the nearest additional enemy",
            effect = function(weapon, player)
                player.haloStormChain = true
                player.haloChainRange = 150
                player.haloChainDamage = weapon.damage * 0.3
                return "Storm Halo! Pulse kills chain lightning"
            end,
            visualEffect = {
                color = {1, 1, 0.2},
                particle = "chain_bolt"
            }
        },
        GREEN = {
            name = "Harvest Ring",
            description = "Enemies killed inside the drain aura release a burst of healing energy",
            effect = function(weapon, player)
                player.haloHarvestOrbs = true
                player.haloHarvestHeal = 8
                return "Harvest Ring! Aura kills heal the player"
            end,
            visualEffect = {
                color = {0.2, 1, 0.4},
                particle = "harvest_burst"
            }
        },
        RED = {
            name = "Inferno Ring",
            description = "Enemies killed inside the fire aura explode, damaging nearby foes",
            effect = function(weapon, player)
                player.haloKillExplosion = true
                player.haloExplosionRadius = 60
                player.haloExplosionDamage = weapon.damage * 0.4
                return "Inferno Ring! Aura kills detonate"
            end,
            visualEffect = {
                color = {1, 0.3, 0.1},
                particle = "detonation"
            }
        },
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
        MAGENTA = {
            name = "Temporal Regen",
            description = "Each HP regen tick ripples outward, briefly slowing nearby enemies",
            effect = function(weapon, player)
                player.auroraTemporalSlow = true
                player.temporalSlowRadius = 120
                player.temporalSlowAmount = 0.3
                player.temporalSlowDuration = 1.0
                return "Temporal Regen! Regen ticks slow nearby enemies"
            end,
            visualEffect = {
                color = {1, 0.3, 0.9},
                particle = "time_ripple"
            }
        },
        BLUE = {
            name = "Ion Surge",
            description = "Each HP regen tick ionizes projectiles, granting a brief pierce charge",
            effect = function(weapon, player)
                player.auroraIonSurge = true
                player.ionPierceBonus = 1
                player.ionPierceDuration = 0.5
                return "Ion Surge! Regen ticks grant pierce charge"
            end,
            visualEffect = {
                color = {0.5, 0.7, 1},
                particle = "ion_pulse"
            }
        },
        RED = {
            name = "Ignite Aura",
            description = "While the aurora regen is active, nearby enemies are set on fire",
            effect = function(weapon, player)
                player.auroraIgnite = true
                player.auroraIgniteRadius = 100
                player.auroraIgniteDPS = 8
                return "Ignite Aura! Regen field burns enemies"
            end,
            visualEffect = {
                color = {1, 0.5, 0.1},
                particle = "flame_aura"
            }
        },
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
                weapon.cloudDamageRatio = 0.3
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
        MAGENTA = {
            name = "Gravity Collapse",
            description = "Cone shots curve toward the nearest enemy after the initial spread angle",
            effect = function(weapon, player)
                weapon.diffractionHomingCone = true
                weapon.coneHomingStrength = 1.5
                return "Gravity Collapse! Cone shots bend toward enemies"
            end,
            visualEffect = {
                color = {1, 0.2, 0.85},
                particle = "bend_trail"
            }
        },
        BLUE = {
            name = "Resonance Wave",
            description = "Radial shots gain pierce; each enemy pierced adds +15% damage to remaining hits",
            effect = function(weapon, player)
                weapon.diffractionPierceScaling = true
                weapon.pierceDamageBonus = 0.15
                weapon.pierceCount = (weapon.pierceCount or 1) + 1
                return "Resonance Wave! Pierce shots amplify on each hit"
            end,
            visualEffect = {
                color = {0.4, 0.65, 1},
                particle = "resonance_ring"
            }
        },
        RED = {
            name = "Scatter Burn",
            description = "Cone spread shots leave burn zones at their travel end",
            effect = function(weapon, player)
                weapon.diffractionBurnZone = true
                weapon.burnZoneRadius = 50
                weapon.burnZoneDPS = 6
                weapon.burnZoneDuration = 2.5
                return "Scatter Burn! Cone shots ignite the ground"
            end,
            visualEffect = {
                color = {1, 0.35, 0.1},
                particle = "burn_zone"
            }
        },
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
                weapon.bloomDamageRatio = 2
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
        CYAN = {
            name = "Cryo Refraction",
            description = "Every orbital hit leaves a frost patch that slows enemies passing through",
            effect = function(weapon, player)
                weapon.refractionFrostPatches = true
                weapon.frostPatchRadius = 50
                weapon.frostPatchSlow = 0.4
                weapon.frostPatchDuration = 2.0
                return "Cryo Refraction! Orbital hits leave frost patches"
            end,
            visualEffect = {
                color = {0.4, 1, 1},
                particle = "frost_patch"
            }
        },
        YELLOW = {
            name = "Lightning Spiral",
            description = "Kills by the spinning orbital chain lightning to three nearby enemies",
            effect = function(weapon, player)
                weapon.refractionLightningKill = true
                weapon.lightningChainCount = 3
                weapon.lightningChainDamage = weapon.damage * 0.5
                return "Lightning Spiral! Orbital kills chain to 3 enemies"
            end,
            visualEffect = {
                color = {1, 1, 0.2},
                particle = "kill_lightning"
            }
        },
        GREEN = {
            name = "Bio-Orbital",
            description = "Orbital satellites restore health to the player on each hit",
            effect = function(weapon, player)
                weapon.refractionHealSatellites = true
                weapon.satelliteHealPerHit = 2
                return "Bio-Orbital! Satellites restore HP on hit"
            end,
            visualEffect = {
                color = {0.3, 1, 0.45},
                particle = "heal_satellite"
            }
        },
        RED = {
            name = "Burning Spiral",
            description = "Spiral projectile arms leave fire trails that deal damage over time",
            effect = function(weapon, player)
                weapon.refractionFireArms = true
                weapon.spiralTrailDPS = 5
                weapon.spiralTrailDuration = 1.0
                return "Burning Spiral! Spiral arms ignite air trails"
            end,
            visualEffect = {
                color = {1, 0.4, 0.2},
                particle = "spiral_fire"
            }
        },
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
        CYAN = {
            name = "Glacial Nova",
            description = "The explosion leaves a massive slow field that lingers on the battlefield",
            effect = function(weapon, player)
                weapon.supernovaGlacialField = true
                weapon.glacialFieldRadius = 300
                weapon.glacialFieldSlow = 0.6
                weapon.glacialFieldDuration = 8.0
                return "Glacial Nova! Explosion leaves a vast slow field"
            end,
            visualEffect = {
                color = {0.3, 0.9, 1},
                particle = "cryo_field"
            }
        },
        YELLOW = {
            name = "Solar Storm",
            description = "Screen clear spawns orbiting electric balls that persist and damage enemies",
            effect = function(weapon, player)
                weapon.supernovaSolarStorm = true
                weapon.solarOrbCount = 3
                weapon.solarOrbDuration = 15
                weapon.solarOrbDPS = 20
                return "Solar Storm! Screen clear spawns electric orbs"
            end,
            visualEffect = {
                color = {1, 0.95, 0.2},
                particle = "solar_orbs"
            }
        },
        BLUE = {
            name = "Shockfront",
            description = "The explosion launches a piercing ring wave that tears through enemies",
            effect = function(weapon, player)
                weapon.supernovaShockwave = true
                weapon.shockwaveSpeed = 400
                weapon.shockwaveDamage = 100
                return "Shockfront! Explosion sends a piercing ring outward"
            end,
            visualEffect = {
                color = {0.5, 0.75, 1},
                particle = "shockwave_ring"
            }
        },
        GREEN = {
            name = "Life Nova",
            description = "Screen clear heals the player for each enemy destroyed in the blast",
            effect = function(weapon, player)
                weapon.supernovaHeal = true
                weapon.supernovaHealPerKill = 10
                return "Life Nova! Screen clear restores HP per kill"
            end,
            visualEffect = {
                color = {0.3, 1, 0.4},
                particle = "nova_heal"
            }
        },
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
                weapon.chainRadiusMultiplier = 1.5
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
    local colors = ColorSystem.getActiveColorNames()
    
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
