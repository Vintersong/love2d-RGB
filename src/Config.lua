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
        difficultyScaling = 0.75, -- Enemy health multiplier per level
        cellSize = 128, -- Spatial hash cell size
        -- Guided color-theory tutorial arc. Defaults on for first-run players;
        -- auto-disables itself after a completed run (one-off), and is togglable
        -- in Options > GAMEPLAY. Persisted to disk via src/core/Settings.lua.
        tutorialEnabled = true
    },

    -- Bullet pattern settings
    patterns = {
        patternCooldown = 0.6,
        schedulerMaxQueue = 256,
    },

    -- Post-FX shader settings
    postFX = {
        bloomEnabled = true,
        chromasep = { enabled = true, angle = 0.15, radius = 1.5 },
        filmgrain = { enabled = true, opacity = 0.15, size = 1 },
        vignette  = { enabled = true, radius = 0.85, opacity = 0.5, softness = 0.5 },
    },

    -- Sound settings
    sound = {
        volume = 0.3
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
