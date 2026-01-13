-- src/Config.lua
-- Centralized static configuration for the game
-- Use this for balance tuning and global constants

local Config = {
    -- Window / Display settings
    screen = {
        width = 1920,
        height = 1080,
        title = "Love2D Bullet Hell Survivor",
        fullscreen = true,
        highDpi = false,
        vsync = true
    },

    -- Player base stats
    player = {
        baseSpeed = 200,
        baseHp = 100,
        width = 32,
        height = 32,
        invulnerabilityDuration = 1.0,
        flashDuration = 0.1,
        vfxInterval = 0.3
    },

    -- Gameplay balance
    gameplay = {
        xpOrbMagnetRange = 150,
        maxEnemiesOnScreen = 500,
        difficultyScaling = 1.05, -- Enemy health multiplier per level
        cellSize = 128 -- Spatial hash cell size
    },

    -- Debug settings
    debug = {
        enabled = true,
        showColliders = false,
        showFPS = true
    }
}

return Config
