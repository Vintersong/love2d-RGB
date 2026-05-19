-- src/Config.lua
-- Centralized static configuration for the game
-- Use this for balance tuning and global constants

local Config = {
    -- Runtime state populated at startup.
    runtime = {
        web = false,
        musicStarted = false
    },

    -- Window / Display settings
    screen = {
        width = 1920,
        height = 1080,
        title = "Love2D Bullet Hell Survivor",
        fullscreen = false,
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

    -- Lightning bolt ability
    lightning = {
        cooldown = 3.0,
        duration = 0.22,
        damageMultiplier = 3.0,
        chainCount = 3,
        chainRange = 150,
        maxDisplacement = 96,
        segments = 15,
    },

    -- Bullet pattern settings
    patterns = {
        patternCooldown = 0.6,
        schedulerMaxQueue = 256,
    },

    -- Post-FX shader settings
    postFX = {
        chromasep = { enabled = true, angle = 0.15, radius = 1.5 },
        filmgrain = { enabled = true, opacity = 0.15, size = 1 },
        vignette  = { enabled = true, radius = 0.85, opacity = 0.5, softness = 0.5 },
    },

    -- Sound settings
    sound = {
        volume = 0.5
    },

    -- Debug settings
    debug = {
        enabled = true,
        showColliders = false,
        showFPS = true,
        muteAudio = false -- Set to true to disable/mute all audio during debugging
    }
}

return Config
