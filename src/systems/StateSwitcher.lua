-- StateSwitcher.lua
-- Wrapper around hump.gamestate that integrates with StateManager
-- Provides controlled state switching with validation

local Gamestate = require("libs.hump-master.gamestate")
local StateManager = require("src.systems.StateManager")

local StateSwitcher = {}

-- Switch to a state (validates with StateManager first)
function StateSwitcher.switch(stateName, ...)
    if not StateManager.canSwitchTo(stateName) then
        print(string.format("[StateSwitcher] ERROR: Cannot switch to '%s' - state is disabled or invalid", stateName))
        return false
    end

    local state = StateManager.getState(stateName)
    if not state then
        print(string.format("[StateSwitcher] ERROR: State '%s' not found in StateManager", stateName))
        return false
    end

    -- Track current state in StateManager
    StateManager.setCurrent(stateName)

    -- Perform actual switch using hump.gamestate
    Gamestate.switch(state, ...)
    return true
end

-- Push a state onto the stack (validates first)
function StateSwitcher.push(stateName, ...)
    if not StateManager.canSwitchTo(stateName) then
        print(string.format("[StateSwitcher] ERROR: Cannot push '%s' - state is disabled or invalid", stateName))
        return false
    end

    local state = StateManager.getState(stateName)
    if not state then
        print(string.format("[StateSwitcher] ERROR: State '%s' not found in StateManager", stateName))
        return false
    end

    -- Note: Don't update current state for push (it's on stack)
    Gamestate.push(state, ...)
    return true
end

-- Pop the current state
function StateSwitcher.pop(...)
    -- Pop from hump.gamestate
    Gamestate.pop(...)

    -- Update StateManager current state (would need to track stack)
    -- For now, just log
    print("[StateSwitcher] Popped state from stack")
    return true
end

-- Get current state name
function StateSwitcher.current()
    return StateManager.currentState
end

return StateSwitcher
