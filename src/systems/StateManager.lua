-- StateManager.lua
-- Manages game states with enable/disable functionality for testing
-- Works alongside hump.gamestate for state switching logic

local StateManager = {}

-- State registry with metadata
StateManager.states = {}
StateManager.currentState = nil
StateManager.config = {
    enabledStates = {},  -- States available for use
    testMode = false     -- When true, only enabled states can be switched to
}

-- Initialize the StateManager
function StateManager.init()
    print("[StateManager] Initializing state management system")
end

-- Register a state with metadata
function StateManager.register(name, stateModule, options)
    options = options or {}

    StateManager.states[name] = {
        name = name,
        module = stateModule,
        enabled = options.enabled ~= false,  -- Default to enabled
        description = options.description or "",
        dependencies = options.dependencies or {},  -- Other states this depends on
        systems = options.systems or {},  -- Systems this state requires
        tags = options.tags or {}  -- Tags for filtering (e.g., "menu", "gameplay")
    }

    -- Auto-enable by default
    if StateManager.states[name].enabled then
        StateManager.config.enabledStates[name] = true
    end

    print(string.format("[StateManager] Registered state: %s (%s)",
        name,
        StateManager.states[name].enabled and "enabled" or "disabled"
    ))

    return stateModule
end

-- Enable a state (makes it available for switching)
function StateManager.enable(name)
    if not StateManager.states[name] then
        print(string.format("[StateManager] WARNING: Cannot enable unknown state: %s", name))
        return false
    end

    StateManager.states[name].enabled = true
    StateManager.config.enabledStates[name] = true
    print(string.format("[StateManager] Enabled state: %s", name))
    return true
end

-- Disable a state (prevents switching to it)
function StateManager.disable(name)
    if not StateManager.states[name] then
        print(string.format("[StateManager] WARNING: Cannot disable unknown state: %s", name))
        return false
    end

    -- Don't disable current state
    if StateManager.currentState == name then
        print(string.format("[StateManager] WARNING: Cannot disable current state: %s", name))
        return false
    end

    StateManager.states[name].enabled = false
    StateManager.config.enabledStates[name] = nil
    print(string.format("[StateManager] Disabled state: %s", name))
    return true
end

-- Check if a state is enabled
function StateManager.isEnabled(name)
    return StateManager.states[name] and StateManager.states[name].enabled
end

-- Enable test mode (only enabled states can be switched to)
function StateManager.enableTestMode()
    StateManager.config.testMode = true
    print("[StateManager] Test mode ENABLED - only enabled states can be switched to")
end

-- Disable test mode (all registered states can be switched to)
function StateManager.disableTestMode()
    StateManager.config.testMode = false
    print("[StateManager] Test mode DISABLED - all states available")
end

-- Validate if a state switch is allowed
function StateManager.canSwitchTo(name)
    if not StateManager.states[name] then
        print(string.format("[StateManager] ERROR: Unknown state: %s", name))
        return false
    end

    -- In test mode, only enabled states are allowed
    if StateManager.config.testMode and not StateManager.states[name].enabled then
        print(string.format("[StateManager] ERROR: State '%s' is disabled in test mode", name))
        return false
    end

    -- Check dependencies
    local state = StateManager.states[name]
    for _, dep in ipairs(state.dependencies) do
        if not StateManager.states[dep] or not StateManager.states[dep].enabled then
            print(string.format("[StateManager] ERROR: State '%s' depends on disabled state '%s'", name, dep))
            return false
        end
    end

    return true
end

-- Set current state (call this when switching states)
function StateManager.setCurrent(name)
    if not StateManager.canSwitchTo(name) then
        return false
    end

    StateManager.currentState = name
    print(string.format("[StateManager] Switched to state: %s", name))
    return true
end

-- Get state module by name
function StateManager.getState(name)
    if StateManager.states[name] then
        return StateManager.states[name].module
    end
    return nil
end

-- Get all registered states
function StateManager.getAllStates()
    return StateManager.states
end

-- Get only enabled states
function StateManager.getEnabledStates()
    local enabled = {}
    for name, state in pairs(StateManager.states) do
        if state.enabled then
            enabled[name] = state
        end
    end
    return enabled
end

-- Get states by tag
function StateManager.getStatesByTag(tag)
    local tagged = {}
    for name, state in pairs(StateManager.states) do
        for _, stateTag in ipairs(state.tags) do
            if stateTag == tag then
                table.insert(tagged, state)
                break
            end
        end
    end
    return tagged
end

-- Print state report
function StateManager.printReport()
    print("\n========================================")
    print("       STATE MANAGER REPORT")
    print("========================================")
    print(string.format("Test Mode: %s", StateManager.config.testMode and "ENABLED" or "DISABLED"))
    print(string.format("Current State: %s", StateManager.currentState or "None"))
    print("\nRegistered States:")
    print("----------------------------------------")

    local stateList = {}
    for name, _ in pairs(StateManager.states) do
        table.insert(stateList, name)
    end
    table.sort(stateList)

    for _, name in ipairs(stateList) do
        local state = StateManager.states[name]
        local status = state.enabled and "✓ ENABLED " or "✗ DISABLED"
        local current = (name == StateManager.currentState) and " [CURRENT]" or ""
        print(string.format("  %s %s%s", status, name, current))

        if state.description ~= "" then
            print(string.format("    → %s", state.description))
        end

        if #state.dependencies > 0 then
            print(string.format("    Dependencies: %s", table.concat(state.dependencies, ", ")))
        end

        if #state.tags > 0 then
            print(string.format("    Tags: %s", table.concat(state.tags, ", ")))
        end
    end

    print("========================================\n")
end

-- Validate all states (check dependencies)
function StateManager.validateAll()
    print("[StateManager] Validating state dependencies...")
    local allValid = true

    for name, state in pairs(StateManager.states) do
        -- Check dependencies exist
        for _, dep in ipairs(state.dependencies) do
            if not StateManager.states[dep] then
                print(string.format("[StateManager] ERROR: State '%s' depends on unregistered state '%s'",
                    name, dep))
                allValid = false
            end
        end

        -- Check module has required functions
        local requiredFunctions = {"enter", "update", "draw"}
        for _, func in ipairs(requiredFunctions) do
            if not state.module[func] then
                print(string.format("[StateManager] WARNING: State '%s' missing function: %s",
                    name, func))
            end
        end
    end

    if allValid then
        print("[StateManager] ✓ All state dependencies valid")
    else
        print("[StateManager] ✗ State validation failed")
    end

    return allValid
end

-- Quick enable/disable functions for testing
function StateManager.enableOnly(names)
    -- Disable all states
    for name, _ in pairs(StateManager.states) do
        StateManager.states[name].enabled = false
        StateManager.config.enabledStates[name] = nil
    end

    -- Enable only specified states
    for _, name in ipairs(names) do
        StateManager.enable(name)
    end

    print(string.format("[StateManager] Enabled only: %s", table.concat(names, ", ")))
end

function StateManager.enableAll()
    for name, _ in pairs(StateManager.states) do
        StateManager.enable(name)
    end
    print("[StateManager] All states enabled")
end

function StateManager.disableAll()
    -- Don't disable current state
    for name, _ in pairs(StateManager.states) do
        if name ~= StateManager.currentState then
            StateManager.disable(name)
        end
    end
    print("[StateManager] All states disabled (except current)")
end

-- Debug command interface
function StateManager.command(cmd, ...)
    local args = {...}

    if cmd == "enable" then
        return StateManager.enable(args[1])
    elseif cmd == "disable" then
        return StateManager.disable(args[1])
    elseif cmd == "list" then
        StateManager.printReport()
    elseif cmd == "test" then
        StateManager.enableTestMode()
    elseif cmd == "notest" then
        StateManager.disableTestMode()
    elseif cmd == "only" then
        StateManager.enableOnly(args)
    elseif cmd == "all" then
        StateManager.enableAll()
    elseif cmd == "none" then
        StateManager.disableAll()
    elseif cmd == "validate" then
        return StateManager.validateAll()
    elseif cmd == "help" then
        print([[
StateManager Commands:
  enable <state>     - Enable a state
  disable <state>    - Disable a state
  list               - Print state report
  test               - Enable test mode
  notest             - Disable test mode
  only <s1> <s2>...  - Enable only specified states
  all                - Enable all states
  none               - Disable all states (except current)
  validate           - Validate all state dependencies
  help               - Show this help
]])
    else
        print(string.format("[StateManager] Unknown command: %s", cmd))
        print("Type 'help' for available commands")
    end
end

return StateManager
