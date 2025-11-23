-- ArtifactManager: Tracks artifact collection and levels (Vampire Survivors style)
-- Each artifact can be collected multiple times to level up

-- Load new artifact implementations
local RefractionArtifact = require("src.artifacts.RefractionArtifact")
local DiffractionArtifact = require("src.artifacts.DiffractionArtifact")
local SupernovaArtifact = require("src.artifacts.SupernovaArtifact")

local ArtifactManager = {}

-- Artifact inventory: [ARTIFACT_TYPE] = level (0 = not collected, 1+ = collected and leveled)
ArtifactManager.artifacts = {}

-- Maximum level for artifacts
ArtifactManager.MAX_LEVEL = 5

-- Artifact level-up definitions (what each level does)
ArtifactManager.levelDefinitions = {
    PRISM = {
        name = "Prism",
        description = "Splits projectiles into multiple beams",
        maxLevel = 5,
        levelEffects = {
            [1] = {desc = "+1 projectile split", effect = function(weapon, player) 
                weapon.prismBonus = (weapon.prismBonus or 0) + 1
            end},
            [2] = {desc = "+1 projectile split", effect = function(weapon, player) 
                weapon.prismBonus = (weapon.prismBonus or 0) + 1
            end},
            [3] = {desc = "+1 projectile split", effect = function(weapon, player) 
                weapon.prismBonus = (weapon.prismBonus or 0) + 1
            end},
            [4] = {desc = "+2 projectile splits", effect = function(weapon, player) 
                weapon.prismBonus = (weapon.prismBonus or 0) + 2
            end},
            [5] = {desc = "+3 projectile splits (MAX)", effect = function(weapon, player) 
                weapon.prismBonus = (weapon.prismBonus or 0) + 3
            end}
        }
    },
    
    HALO = {
        name = "Halo",
        description = "Color-based aura effects",
        maxLevel = 5,
        levelEffects = {
            [1] = {desc = "Aura level 1", effect = function(weapon, player) 
                -- Color-specific behavior handled by HaloArtifact.lua
            end},
            [2] = {desc = "Aura level 2", effect = function(weapon, player) 
                -- Color-specific behavior handled by HaloArtifact.lua
            end},
            [3] = {desc = "Aura level 3", effect = function(weapon, player) 
                -- Color-specific behavior handled by HaloArtifact.lua
            end},
            [4] = {desc = "Aura level 4", effect = function(weapon, player) 
                -- Color-specific behavior handled by HaloArtifact.lua
            end},
            [5] = {desc = "Aura level 5 (MAX)", effect = function(weapon, player) 
                -- Color-specific behavior handled by HaloArtifact.lua
            end}
        }
    },
    
    MIRROR = {
        name = "Mirror",
        description = "Reflects damage back to attackers",
        maxLevel = 5,
        levelEffects = {
            [1] = {desc = "Reflect 50% damage", effect = function(weapon, player) 
                player.mirrorReflection = 0.5
                player.mirrorDuration = 10
            end},
            [2] = {desc = "Reflect 60% damage", effect = function(weapon, player) 
                player.mirrorReflection = 0.6
                player.mirrorDuration = 12
            end},
            [3] = {desc = "Reflect 75% damage", effect = function(weapon, player) 
                player.mirrorReflection = 0.75
                player.mirrorDuration = 15
            end},
            [4] = {desc = "Reflect 100% damage", effect = function(weapon, player) 
                player.mirrorReflection = 1.0
                player.mirrorDuration = 20
            end},
            [5] = {desc = "Reflect 150% damage (MAX)", effect = function(weapon, player) 
                player.mirrorReflection = 1.5
                player.mirrorDuration = 30
            end}
        }
    },
    
    LENS = {
        name = "Lens",
        description = "Focuses damage output",
        maxLevel = 5,
        levelEffects = {
            [1] = {desc = "+50% damage focus", effect = function(weapon, player) 
                weapon.lensBonus = (weapon.lensBonus or 0) + 0.5
                weapon.lensDuration = 8
            end},
            [2] = {desc = "+60% damage focus", effect = function(weapon, player) 
                weapon.lensBonus = (weapon.lensBonus or 0) + 0.6
                weapon.lensDuration = 10
            end},
            [3] = {desc = "+75% damage focus", effect = function(weapon, player) 
                weapon.lensBonus = (weapon.lensBonus or 0) + 0.75
                weapon.lensDuration = 12
            end},
            [4] = {desc = "+100% damage focus", effect = function(weapon, player) 
                weapon.lensBonus = (weapon.lensBonus or 0) + 1.0
                weapon.lensDuration = 15
            end},
            [5] = {desc = "+150% damage focus (MAX)", effect = function(weapon, player) 
                weapon.lensBonus = (weapon.lensBonus or 0) + 1.5
                weapon.lensDuration = 20
            end}
        }
    },
    
    DIFFRACTION = {
        name = "Diffraction",
        description = "Spreading/bursting projectile patterns",
        maxLevel = 5,
        artifactModule = DiffractionArtifact,
        levelEffects = {
            [1] = {desc = "Unlock Diffraction behaviors", effect = function(weapon, player) 
                player.diffractionLevel = 1
                weapon.hasDiffraction = true
            end},
            [2] = {desc = "+20% Diffraction chance", effect = function(weapon, player) 
                player.diffractionLevel = 2
                weapon.diffractionChanceBonus = 0.20
            end},
            [3] = {desc = "+40% Diffraction chance", effect = function(weapon, player) 
                player.diffractionLevel = 3
                weapon.diffractionChanceBonus = 0.40
            end},
            [4] = {desc = "+60% Diffraction effect power", effect = function(weapon, player) 
                player.diffractionLevel = 4
                weapon.diffractionChanceBonus = 0.60
            end},
            [5] = {desc = "MAX Diffraction (MAX)", effect = function(weapon, player) 
                player.diffractionLevel = 5
                weapon.diffractionChanceBonus = 1.0
            end}
        }
    },
    
    DIFFUSION = {
        name = "Diffusion",
        description = "Spreads and softens projectile effects",
        maxLevel = 5,
        levelEffects = {
            [1] = {desc = "Basic diffusion effect", effect = function(weapon, player) 
                weapon.diffusionBonus = (weapon.diffusionBonus or 0) + 1
            end},
            [2] = {desc = "Enhanced diffusion", effect = function(weapon, player) 
                weapon.diffusionBonus = (weapon.diffusionBonus or 0) + 1
            end},
            [3] = {desc = "Strong diffusion", effect = function(weapon, player) 
                weapon.diffusionBonus = (weapon.diffusionBonus or 0) + 1
            end},
            [4] = {desc = "Advanced diffusion", effect = function(weapon, player) 
                weapon.diffusionBonus = (weapon.diffusionBonus or 0) + 2
            end},
            [5] = {desc = "Maximum diffusion (MAX)", effect = function(weapon, player) 
                weapon.diffusionBonus = (weapon.diffusionBonus or 0) + 3
            end}
        }
    },
    
    REFRACTION = {
        name = "Refraction",
        description = "Bends projectile paths (spiral/orbital)",
        maxLevel = 5,
        artifactModule = RefractionArtifact,
        levelEffects = {
            [1] = {desc = "Unlock Refraction behaviors", effect = function(weapon, player) 
                player.refractionLevel = 1
                weapon.hasRefraction = true
            end},
            [2] = {desc = "+20% Refraction chance", effect = function(weapon, player) 
                player.refractionLevel = 2
                weapon.refractionChanceBonus = 0.20
            end},
            [3] = {desc = "+40% Refraction chance", effect = function(weapon, player) 
                player.refractionLevel = 3
                weapon.refractionChanceBonus = 0.40
            end},
            [4] = {desc = "+60% Refraction effect power", effect = function(weapon, player) 
                player.refractionLevel = 4
                weapon.refractionChanceBonus = 0.60
            end},
            [5] = {desc = "MAX Refraction (MAX)", effect = function(weapon, player) 
                player.refractionLevel = 5
                weapon.refractionChanceBonus = 1.0
            end}
        }
    },
    
    SUPERNOVA = {
        name = "Supernova",
        description = "Ultimate screen-clear abilities (cooldown)",
        maxLevel = 5,
        artifactModule = SupernovaArtifact,
        levelEffects = {
            [1] = {desc = "Unlock Supernova ultimate", effect = function(weapon, player) 
                player.supernovaLevel = 1
                player.hasSupernova = true
            end},
            [2] = {desc = "-20% Supernova cooldown", effect = function(weapon, player) 
                player.supernovaLevel = 2
                player.supernovaCooldownReduction = 0.20
            end},
            [3] = {desc = "-40% Supernova cooldown", effect = function(weapon, player) 
                player.supernovaLevel = 3
                player.supernovaCooldownReduction = 0.40
            end},
            [4] = {desc = "+50% Supernova radius", effect = function(weapon, player) 
                player.supernovaLevel = 4
                player.supernovaCooldownReduction = 0.40
                player.supernovaRadiusBonus = 0.50
            end},
            [5] = {desc = "MAX Supernova power (MAX)", effect = function(weapon, player) 
                player.supernovaLevel = 5
                player.supernovaCooldownReduction = 0.60
                player.supernovaRadiusBonus = 1.0
            end}
        }
    },

    DASH = {
        name = "Phase Blink",
        description = "Press SPACE to dash (invulnerable during dash)",
        maxLevel = 5,
        levelEffects = {
            [1] = {desc = "Dash ability (5s cooldown)", effect = function(weapon, player)
                -- Handled by active ability system
            end},
            [2] = {desc = "4.5s cooldown", effect = function(weapon, player)
                -- Handled by active ability system
            end},
            [3] = {desc = "4s cooldown", effect = function(weapon, player)
                -- Handled by active ability system
            end},
            [4] = {desc = "3.5s cooldown", effect = function(weapon, player)
                -- Handled by active ability system
            end},
            [5] = {desc = "3s cooldown (MAX)", effect = function(weapon, player)
                -- Handled by active ability system
            end}
        }
    }
}

-- Collect an artifact (level it up)
function ArtifactManager.collect(artifactType, weapon, player)
    -- Initialize if not collected yet
    if not ArtifactManager.artifacts[artifactType] then
        ArtifactManager.artifacts[artifactType] = 0
    end
    
    local currentLevel = ArtifactManager.artifacts[artifactType]
    local definition = ArtifactManager.levelDefinitions[artifactType]
    
    if not definition then
        return {success = false, message = "Unknown artifact: " .. artifactType}
    end
    
    -- Check if already at max level
    if currentLevel >= definition.maxLevel then
        return {
            success = false, 
            message = string.format("%s already at MAX level (%d)", definition.name, definition.maxLevel)
        }
    end
    
    -- Level up
    currentLevel = currentLevel + 1
    ArtifactManager.artifacts[artifactType] = currentLevel

    -- Apply the level effect (all artifacts are passive)
    local levelEffect = definition.levelEffects[currentLevel]
    if levelEffect then
        levelEffect.effect(weapon, player)

        local message = string.format("%s Level %d: %s",
            definition.name,
            currentLevel,
            levelEffect.desc)

        print(string.format("[ARTIFACT] %s collected (Level %d/%d)",
            definition.name, currentLevel, definition.maxLevel))

        -- Return structured data for floating text
        return {
            success = true,
            message = message,
            artifactName = definition.name,
            level = currentLevel,
            maxLevel = definition.maxLevel,
            isMaxLevel = currentLevel >= definition.maxLevel,
            type = artifactType
        }
    end
    
    return {
        success = true,
        message = string.format("%s upgraded to level %d", definition.name, currentLevel),
        artifactName = definition.name,
        level = currentLevel,
        maxLevel = definition.maxLevel,
        isMaxLevel = currentLevel >= definition.maxLevel,
        type = artifactType
    }
end

-- Get artifact level (0 if not collected)
function ArtifactManager.getLevel(artifactType)
    return ArtifactManager.artifacts[artifactType] or 0
end

-- Check if artifact is at max level
function ArtifactManager.isMaxLevel(artifactType)
    local definition = ArtifactManager.levelDefinitions[artifactType]
    if not definition then return false end
    
    local level = ArtifactManager.getLevel(artifactType)
    return level >= definition.maxLevel
end

-- Get all collected artifacts with levels
function ArtifactManager.getCollectedArtifacts()
    local collected = {}
    for artifactType, level in pairs(ArtifactManager.artifacts) do
        if level > 0 then
            local definition = ArtifactManager.levelDefinitions[artifactType]
            table.insert(collected, {
                type = artifactType,
                name = definition.name,
                level = level,
                maxLevel = definition.maxLevel,
                description = definition.description,
                isWIP = definition.isWIP or false
            })
        end
    end
    return collected
end

-- Reset artifacts (on game restart)
function ArtifactManager.reset()
    ArtifactManager.artifacts = {}
end

-- Get total artifact count
function ArtifactManager.getCount()
    local count = 0
    for _, level in pairs(ArtifactManager.artifacts) do
        if level > 0 then
            count = count + 1
        end
    end
    return count
end

-- Get artifact module for a given type
function ArtifactManager.getArtifactModule(artifactType)
    local definition = ArtifactManager.levelDefinitions[artifactType]
    if definition and definition.artifactModule then
        return definition.artifactModule
    end
    return nil
end

-- Apply artifact behavior based on player's color affinity
function ArtifactManager.applyArtifactBehavior(artifactType, colorAffinity, projectiles, level, targetX, targetY, player)
    local module = ArtifactManager.getArtifactModule(artifactType)
    if not module then return projectiles end
    
    -- Get the color-specific behavior
    local colorBehavior = module[colorAffinity]
    if not colorBehavior or not colorBehavior.behavior then 
        return projectiles 
    end
    
    -- Apply the behavior
    return colorBehavior.behavior(projectiles, level, targetX, targetY, player)
end

-- Check if player has a specific artifact
function ArtifactManager.hasArtifact(artifactType)
    return ArtifactManager.getLevel(artifactType) > 0
end

-- Update Supernova cooldowns
function ArtifactManager.updateSupernovaCooldowns(dt)
    if SupernovaArtifact then
        for _, colorVariant in pairs(SupernovaArtifact) do
            if type(colorVariant) == "table" and colorVariant.update then
                colorVariant:update(dt)
            end
        end
    end
end

-- Try to activate Supernova
function ArtifactManager.tryActivateSupernova(colorAffinity, player, enemies, level)
    if not SupernovaArtifact then return false end
    
    local colorVariant = SupernovaArtifact[colorAffinity]
    if not colorVariant or not colorVariant.activate then return false end
    
    -- Check if player has SUPERNOVA artifact
    if not ArtifactManager.hasArtifact("SUPERNOVA") then return false end
    
    -- Try to activate
    local success, effectData = colorVariant:activate(player, enemies, level)
    return success, effectData
end

return ArtifactManager

