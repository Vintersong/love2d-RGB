-- ArtifactEngine.lua
-- Data-driven artifact system that composes effects from EffectLibrary
-- Artifacts are defined as pure data in ArtifactDefinitions.lua

local ArtifactEngine = {}

local EffectLibrary = require("src.systems.EffectLibrary")
local ArtifactDefinitions = require("src.data.ArtifactDefinitions")

-- Active artifact instances (player state)
ArtifactEngine.activeArtifacts = {}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function ArtifactEngine.init()
    ArtifactEngine.activeArtifacts = {}
end

function ArtifactEngine.reset()
    ArtifactEngine.activeArtifacts = {}
end

-- ============================================================================
-- ARTIFACT ACTIVATION
-- ============================================================================

-- Activate an artifact for a player
function ArtifactEngine.activate(artifactType, level, color, player)
    local def = ArtifactDefinitions[artifactType]
    if not def then
        print("[ArtifactEngine] Unknown artifact: " .. artifactType)
        return false
    end

    -- Get color variant or base definition
    local variant = color and def.colors and def.colors[color] or def
    if not variant then
        print("[ArtifactEngine] Unknown color variant: " .. color)
        return false
    end

    -- Initialize state
    local state = variant.init(level)
    state.level = level
    state.artifactType = artifactType
    state.color = color
    state.effects = variant.effects or def.effects

    -- Store on player
    local key = artifactType .. (color or "")
    if not player.artifacts then
        player.artifacts = {}
    end
    player.artifacts[key] = state

    print(string.format("[ArtifactEngine] Activated %s (Level %d, Color: %s)",
                        artifactType, level, color or "NONE"))

    return true
end

-- ============================================================================
-- UPDATE LOOP
-- ============================================================================

-- Update all active artifacts
function ArtifactEngine.update(player, dt, enemies)
    if not player.artifacts then return end

    for key, state in pairs(player.artifacts) do
        -- Apply each effect in the artifact's effect list
        for _, effectName in ipairs(state.effects) do
            local effect = EffectLibrary.get(effectName)

            if effect and effect.update then
                effect.update(state, dt, enemies, player)
            end
        end
    end
end

-- ============================================================================
-- RENDERING
-- ============================================================================

-- Draw all active artifact visuals
function ArtifactEngine.draw(player)
    if not player.artifacts then return end

    for key, state in pairs(player.artifacts) do
        -- Apply each visual effect
        for _, effectName in ipairs(state.effects) do
            local effect = EffectLibrary.get(effectName)

            if effect and effect.draw then
                effect.draw(state, player, state.color or {1, 1, 1})
            end
        end
    end
end

-- ============================================================================
-- PROJECTILE MODIFICATION
-- ============================================================================

-- Apply artifact effects to newly created projectiles
function ArtifactEngine.applyToProjectiles(projectiles, player, targetX, targetY)
    if not player.artifacts then return projectiles end

    local modifiedProjectiles = projectiles

    for key, state in pairs(player.artifacts) do
        -- Apply each projectile effect
        for _, effectName in ipairs(state.effects) do
            local effect = EffectLibrary.get(effectName)

            if effect and effect.apply then
                modifiedProjectiles = effect.apply(modifiedProjectiles, state.level, state)
            end
        end
    end

    return modifiedProjectiles
end

-- Update projectile behaviors (homing, etc.)
function ArtifactEngine.updateProjectiles(projectiles, enemies, dt, player)
    if not player.artifacts then return end

    for key, state in pairs(player.artifacts) do
        -- Apply each projectile update effect
        for _, effectName in ipairs(state.effects) do
            local effect = EffectLibrary.get(effectName)

            if effect and effect.update and effectName:match("Projectile") then
                effect.update(projectiles, enemies, dt, state)
            end
        end
    end
end

-- ============================================================================
-- QUERIES
-- ============================================================================

-- Check if player has an artifact
function ArtifactEngine.hasArtifact(player, artifactType, color)
    if not player.artifacts then return false end

    local key = artifactType .. (color or "")
    return player.artifacts[key] ~= nil
end

-- Get artifact state
function ArtifactEngine.getState(player, artifactType, color)
    if not player.artifacts then return nil end

    local key = artifactType .. (color or "")
    return player.artifacts[key]
end

-- Get artifact level
function ArtifactEngine.getLevel(player, artifactType, color)
    local state = ArtifactEngine.getState(player, artifactType, color)
    return state and state.level or 0
end

-- Get all active artifacts
function ArtifactEngine.getActiveArtifacts(player)
    return player.artifacts or {}
end

-- ============================================================================
-- UTILITIES
-- ============================================================================

-- Get artifact definition
function ArtifactEngine.getDefinition(artifactType)
    return ArtifactDefinitions[artifactType]
end

-- Check if artifact/color combo exists
function ArtifactEngine.isValid(artifactType, color)
    local def = ArtifactDefinitions[artifactType]
    if not def then return false end

    if color then
        return def.colors and def.colors[color] ~= nil
    end

    return true
end

return ArtifactEngine
