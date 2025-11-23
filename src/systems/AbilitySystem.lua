-- AbilitySystem.lua
-- Core system for managing player abilities (dash, special moves, etc.)
-- Data-driven design: ability definitions live in AbilityLibrary
-- This system handles: activation, cooldowns, state management, and effects

local AbilitySystem = {}

-- Active abilities state (per-entity tracking)
-- Structure: { [entity] = { [abilityName] = abilityState } }
local activeAbilities = {}

-- ============================================================================
-- ABILITY STATE MANAGEMENT
-- ============================================================================

-- Register an entity with abilities
function AbilitySystem.register(entity, abilities)
    if not entity then return end

    activeAbilities[entity] = activeAbilities[entity] or {}

    for _, abilityName in ipairs(abilities) do
        activeAbilities[entity][abilityName] = {
            cooldown = 0,
            isActive = false,
            state = {}  -- Ability-specific state data
        }
    end
end

-- Unregister an entity (cleanup)
function AbilitySystem.unregister(entity)
    activeAbilities[entity] = nil
end

-- Get ability state for an entity
function AbilitySystem.getState(entity, abilityName)
    if not entity or not activeAbilities[entity] then return nil end
    return activeAbilities[entity][abilityName]
end

-- Check if ability is off cooldown
function AbilitySystem.isReady(entity, abilityName)
    local state = AbilitySystem.getState(entity, abilityName)
    if not state then return false end
    return state.cooldown <= 0 and not state.isActive
end

-- Check if ability is currently active
function AbilitySystem.isActive(entity, abilityName)
    local state = AbilitySystem.getState(entity, abilityName)
    if not state then return false end
    return state.isActive
end

-- Get cooldown progress (0 to 1, where 1 = ready)
function AbilitySystem.getCooldownProgress(entity, abilityName, abilityDef)
    local state = AbilitySystem.getState(entity, abilityName)
    if not state or not abilityDef then return 1 end

    if state.cooldown <= 0 then return 1 end
    return 1 - (state.cooldown / abilityDef.cooldown)
end

-- ============================================================================
-- ABILITY ACTIVATION
-- ============================================================================

-- Activate an ability
-- Returns: success (boolean), result data (table or nil)
function AbilitySystem.activate(entity, abilityName, abilityDef, context)
    if not entity or not abilityDef then
        return false, "Missing entity or ability definition"
    end

    -- Check if ability is ready
    if not AbilitySystem.isReady(entity, abilityName) then
        return false, "Ability not ready"
    end

    local state = AbilitySystem.getState(entity, abilityName)
    if not state then
        return false, "Ability not registered"
    end

    -- Call onActivate callback if exists
    local success = true
    local result = nil

    if abilityDef.onActivate then
        success, result = pcall(abilityDef.onActivate, entity, state.state, context)
        if not success then
            print(string.format("[AbilitySystem] Error activating %s: %s", abilityName, tostring(result)))
            return false, result
        end
    end

    -- Set ability state
    state.isActive = true
    state.cooldown = abilityDef.cooldown or 0

    print(string.format("[AbilitySystem] %s activated (cooldown: %.1fs)", abilityName, state.cooldown))

    return true, result
end

-- ============================================================================
-- UPDATE LOOP
-- ============================================================================

-- Update all abilities for an entity
function AbilitySystem.update(entity, abilityDefs, dt, context)
    if not entity or not activeAbilities[entity] then return end

    for abilityName, state in pairs(activeAbilities[entity]) do
        local abilityDef = abilityDefs[abilityName]

        if abilityDef then
            -- Update cooldown
            if state.cooldown > 0 then
                state.cooldown = state.cooldown - dt
                if state.cooldown < 0 then
                    state.cooldown = 0
                end
            end

            -- Update active ability logic
            if state.isActive and abilityDef.onUpdate then
                local continueActive = abilityDef.onUpdate(entity, state.state, dt, context)

                -- If onUpdate returns false, deactivate ability
                if continueActive == false then
                    AbilitySystem.deactivate(entity, abilityName, abilityDef, context)
                end
            end
        end
    end
end

-- ============================================================================
-- DEACTIVATION
-- ============================================================================

-- Manually deactivate an ability
function AbilitySystem.deactivate(entity, abilityName, abilityDef, context)
    local state = AbilitySystem.getState(entity, abilityName)
    if not state or not state.isActive then return end

    -- Call onDeactivate callback if exists
    if abilityDef and abilityDef.onDeactivate then
        pcall(abilityDef.onDeactivate, entity, state.state, context)
    end

    state.isActive = false
    -- Clear ability-specific state
    state.state = {}

    print(string.format("[AbilitySystem] %s deactivated", abilityName))
end

-- ============================================================================
-- UTILITY
-- ============================================================================

-- Get all abilities for an entity
function AbilitySystem.getAbilities(entity)
    if not activeAbilities[entity] then return {} end
    local abilities = {}
    for abilityName, _ in pairs(activeAbilities[entity]) do
        table.insert(abilities, abilityName)
    end
    return abilities
end

-- Debug: Print ability states
function AbilitySystem.debug(entity)
    if not activeAbilities[entity] then
        print("[AbilitySystem] No abilities registered for entity")
        return
    end

    print("[AbilitySystem] Ability States:")
    for abilityName, state in pairs(activeAbilities[entity]) do
        print(string.format("  %s: cooldown=%.2f, active=%s",
            abilityName, state.cooldown, tostring(state.isActive)))
    end
end

return AbilitySystem
