-- GameConfig.lua
-- Central configuration for game-wide settings and shared instances
-- Replaces global variable usage for better encapsulation

local GameConfig = {}
local Config = require("src.Config")

-- Screen dimensions (constant for this game)
GameConfig.screenWidth = 1920
GameConfig.screenHeight = 1080

-- Music reactor instance (set during initialization)
GameConfig.musicReactor = nil

-- Debug mode follows the canonical static config unless explicitly changed.
GameConfig.debugMode = Config.debug.enabled

-- Boss system color (used for visual effects)
GameConfig.currentShipColor = nil

-- Initialize config with game systems
function GameConfig.init(musicReactor, screenWidth, screenHeight)
    GameConfig.musicReactor = musicReactor
    GameConfig.screenWidth = screenWidth or 1920
    GameConfig.screenHeight = screenHeight or 1080
    
    print(string.format("[GameConfig] Initialized: %dx%d, music: %s",
        GameConfig.screenWidth,
        GameConfig.screenHeight,
        musicReactor and "enabled" or "disabled"
    ))
end

-- Get music reactor instance
function GameConfig.getMusicReactor()
    return GameConfig.musicReactor
end

-- Get screen dimensions
function GameConfig.getScreenSize()
    return GameConfig.screenWidth, GameConfig.screenHeight
end

-- Check if debug mode is enabled
function GameConfig.isDebugMode()
    return GameConfig.debugMode
end

-- Set debug mode (useful for build configurations)
function GameConfig.setDebugMode(enabled)
    GameConfig.debugMode = enabled
    print(string.format("[GameConfig] Debug mode: %s", enabled and "enabled" or "disabled"))
end

return GameConfig
