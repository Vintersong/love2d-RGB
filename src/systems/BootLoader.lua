-- BootLoader.lua
-- Validates all systems are loaded correctly and performs health checks
-- Provides detailed error messages if something is misconfigured

local BootLoader = {}

-- System validation registry
BootLoader.systems = {}
BootLoader.errors = {}
BootLoader.warnings = {}

-- Register a system for validation
function BootLoader.registerSystem(name, module, requiredFunctions)
    BootLoader.systems[name] = {
        module = module,
        requiredFunctions = requiredFunctions or {}
    }
end

-- Validate a single system
function BootLoader.validateSystem(name, systemData)
    local module = systemData.module
    local requiredFunctions = systemData.requiredFunctions

    -- Check if module loaded
    if not module then
        table.insert(BootLoader.errors, string.format("[%s] Module failed to load", name))
        return false
    end

    -- Check required functions exist
    for _, funcName in ipairs(requiredFunctions) do
        if type(module[funcName]) ~= "function" then
            table.insert(BootLoader.errors, string.format("[%s] Missing required function: %s", name, funcName))
            return false
        end
    end

    return true
end

-- Validate all registered systems
function BootLoader.validateAll()
    print("[BootLoader] Validating systems...")
    local allValid = true

    for name, systemData in pairs(BootLoader.systems) do
        local valid = BootLoader.validateSystem(name, systemData)
        if valid then
            print(string.format("[BootLoader] ✓ %s OK", name))
        else
            print(string.format("[BootLoader] ✗ %s FAILED", name))
            allValid = false
        end
    end

    return allValid
end

-- Initialize all systems with error handling
function BootLoader.initializeSystem(name, initFunc, ...)
    local success, error = pcall(initFunc, ...)

    if success then
        print(string.format("[BootLoader] ✓ %s initialized", name))
        return true
    else
        table.insert(BootLoader.errors, string.format("[%s] Initialization failed: %s", name, error))
        print(string.format("[BootLoader] ✗ %s initialization FAILED: %s", name, error))
        return false
    end
end

-- Check for common issues
function BootLoader.performHealthChecks()
    print("[BootLoader] Performing health checks...")

    -- Check screen resolution
    local w, h = love.graphics.getDimensions()
    if w ~= 1920 or h ~= 1080 then
        table.insert(BootLoader.warnings, string.format(
            "Screen resolution is %dx%d (expected 1920x1080). UI may not display correctly.",
            w, h
        ))
    end

    -- Check Lua version
    local version = _VERSION
    if not version:match("5.1") and not version:match("LuaJIT") then
        table.insert(BootLoader.warnings, string.format(
            "Running on %s (expected Lua 5.1/LuaJIT). Some features may not work.",
            version
        ))
    end

    -- Check LOVE version
    local major, minor, revision = love.getVersion()
    if major ~= 11 then
        table.insert(BootLoader.warnings, string.format(
            "Running on LOVE %d.%d.%d (expected 11.x). Compatibility issues may occur.",
            major, minor, revision
        ))
    end

    -- Check for required directories
    local requiredDirs = {
        "src/systems",
        "src/entities",
        "src/states",
        "src/artifacts",
        "assets/music",
        "libs"
    }

    for _, dir in ipairs(requiredDirs) do
        local info = love.filesystem.getInfo(dir)
        if not info or info.type ~= "directory" then
            table.insert(BootLoader.errors, string.format(
                "Required directory not found: %s",
                dir
            ))
        end
    end

    -- Print warnings
    if #BootLoader.warnings > 0 then
        print("[BootLoader] Warnings:")
        for _, warning in ipairs(BootLoader.warnings) do
            print("  ⚠ " .. warning)
        end
    end

    return #BootLoader.errors == 0
end

-- Print boot report
function BootLoader.printReport()
    print("\n========================================")
    print("         BOOT LOADER REPORT")
    print("========================================")

    if #BootLoader.errors == 0 then
        print("Status: ✓ ALL SYSTEMS OPERATIONAL")
        print(string.format("Systems Loaded: %d", BootLoader.getSystemCount()))

        if #BootLoader.warnings > 0 then
            print(string.format("Warnings: %d", #BootLoader.warnings))
        end
    else
        print("Status: ✗ BOOT FAILED")
        print(string.format("Errors: %d", #BootLoader.errors))
        print("\nError Details:")
        for _, error in ipairs(BootLoader.errors) do
            print("  • " .. error)
        end
    end

    print("========================================\n")
end

-- Get count of loaded systems
function BootLoader.getSystemCount()
    local count = 0
    for _ in pairs(BootLoader.systems) do
        count = count + 1
    end
    return count
end

-- Check if boot was successful
function BootLoader.isHealthy()
    return #BootLoader.errors == 0
end

-- Get all errors
function BootLoader.getErrors()
    return BootLoader.errors
end

-- Get all warnings
function BootLoader.getWarnings()
    return BootLoader.warnings
end

return BootLoader
