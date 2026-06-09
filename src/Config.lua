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
        title = "CHROMATIC",
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

    -- Boss color affinity (bonus-only; regular enemies are intentionally unaffected).
    -- A player projectile whose dominant color matches the boss archetype's `weak`
    -- color deals `bonus`x damage. There is no resistance penalty for a mismatch.
    -- Color names are ColorSystem dominant-color strings
    -- (RED / GREEN / BLUE / YELLOW / MAGENTA / CYAN). Per-archetype weaknesses below
    -- are starting values — tune freely.
    boss = {
        affinity = {
            bonus = 1.25,
            weak = {
                berserker = "BLUE",   -- the rusher folds to pierce/control
                mage      = "RED",    -- the caster folds to aggression
                warrior   = "GREEN",  -- the bruiser folds to adaptation/chains
            },
        },
    },

    -- ------------------------------------------------------------------
    -- Color economy (moment-to-moment XP routing). Enemies carry a color
    -- affinity (RED/GREEN/BLUE) derived from their music archetype; killing
    -- enemies that match the player's committed colors pays more XP. The
    -- economy only activates once the player has locked both primaries.
    -- All tunables live here — logic files read these, never hardcode.
    -- ------------------------------------------------------------------
    colorEconomy = {
        -- Music archetype -> affinity (Enemy.frequencyType is lowercase).
        -- "full" is the fallback for boss / non-banded enemies.
        archetypeAffinity = {
            bass   = "RED",
            mids   = "GREEN",
            treble = "BLUE",
            full   = "RED",
        },
        -- XP multiplier by kill classification.
        xpMult = {
            dominant  = 1.5,  -- affinity == current dominant committed primary
            committed = 1.0,  -- affinity == the other committed primary
            off       = 0.5,  -- affinity == locked-out third primary (floor)
            preCommit = 1.0,  -- economy inactive (both primaries not yet locked)
        },
        -- Dominant-match streak: every `perMilestone` consecutive dominant
        -- kills adds `bonusPerMilestone` to the dominant multiplier, up to
        -- `maxBonus` (so 1.5 + 0.5 = 2.0x ceiling). Off-color kills reset it.
        streak = {
            perMilestone      = 10,
            bonusPerMilestone = 0.1,
            maxBonus          = 0.5,
        },
        -- Clamp any single affinity to <= this fraction of live enemies per
        -- spawn pulse, so a bass-heavy track never makes a commitment wrong.
        affinityClampPct = 0.5,
    },

    -- Boss progress meter (HUD). Surfaces SpawnController.enemyKillCount as a
    -- thin glass panel filling toward the next boss wave.
    bossMeter = {
        bossInterval   = 100,  -- kills per boss (mirrors SpawnController trigger)
        pulseThreshold = 90,   -- kills-into-cycle at which the meter pulses on beat
        pulseScale     = 0.4,  -- extra brightness/scale driven by beatIntensity
        width          = 320,
        height         = 14,
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

    -- ------------------------------------------------------------------
    -- Design system tokens (CHROMATIC Design System — colors_and_type.css).
    -- The game draws immediate-mode and consumes RGB floats (0-1), so every
    -- color below is a {r, g, b} triple that maps 1:1 into
    -- love.graphics.setColor(...). Consumed via src/render/Theme.lua.
    -- These are the refined neon UI *targets*; gameplay build logic still
    -- lives in src/gameplay/ColorSystem.lua.
    -- ------------------------------------------------------------------
    theme = {
        colors = {
            -- THE SIX (additive RGB identity) — hues carry game meaning.
            red     = {1.00, 0.18, 0.33}, -- aggression / split
            green   = {0.22, 1.00, 0.08}, -- adaptation / bounce
            blue    = {0.18, 0.48, 1.00}, -- control / pierce
            yellow  = {1.00, 0.90, 0.00}, -- R+G velocity / electric
            magenta = {1.00, 0.24, 0.94}, -- R+B arcane / detonate
            cyan    = {0.12, 0.90, 0.90}, -- G+B frost / slow
            white   = {1.00, 1.00, 1.00}, -- R+G+B transcendence (ultimate)

            -- Dim "committed but not dominant" tints (level-up card fills).
            redDeep     = {0.302, 0.000, 0.067},
            greenDeep   = {0.039, 0.302, 0.000},
            blueDeep    = {0.000, 0.122, 0.302},
            yellowDeep  = {0.302, 0.271, 0.000},
            magentaDeep = {0.302, 0.000, 0.278},
            cyanDeep    = {0.000, 0.302, 0.302},

            -- UI ACCENT — the interface signal color (#00D9FF). Drives
            -- brackets, focus, panel edges, sliders. Distinct from brand cyan.
            accent    = {0.000, 0.851, 1.000},
            accentDim = {0.000, 0.451, 0.651}, -- defocused / pressed (#0073A6)

            -- NEUTRAL SCAFFOLD — near-black cool-tinted space.
            bgVoid   = {0.015, 0.012, 0.020}, -- deepest clear color (#040305)
            bgBase   = {0.027, 0.039, 0.059}, -- primary background (#070A0F)
            bgRaised = {0.051, 0.063, 0.094}, -- lifted surface (#0D1018)

            -- TEXT.
            fg1 = {0.918, 0.949, 1.000}, -- primary off-white (#EAF2FF)
            fg2 = {0.718, 0.761, 0.839}, -- secondary body (#B7C2D6)
            fg3 = {0.494, 0.541, 0.627}, -- muted labels / captions (#7E8AA0)

            -- STATUS (HP / feedback ramp).
            ok        = {0.20, 1.00, 0.20},
            warn      = {1.00, 1.00, 0.20},
            danger    = {1.00, 0.20, 0.20},
            toggleOn  = {0.00, 1.00, 0.50}, -- LED enabled pip
            toggleOff = {1.00, 0.10, 0.40}, -- LED disabled pip
        },

        -- Bundled OFL typefaces (see assets/fonts/OFL.txt). Loaded lazily and
        -- cached per-size by src/render/Theme.lua. Missing files fall back to
        -- LÖVE's default font, so the game still boots if an asset is absent.
        fonts = {
            display    = "assets/fonts/Michroma-Regular.ttf",     -- wide techno wordmark / hero
            ui         = "assets/fonts/ChakraPetch-Regular.ttf",  -- UI body
            uiMedium   = "assets/fonts/ChakraPetch-Medium.ttf",   -- subtitles / labels
            uiSemiBold = "assets/fonts/ChakraPetch-SemiBold.ttf", -- titles
            uiBold     = "assets/fonts/ChakraPetch-Bold.ttf",     -- recap headlines
            mono       = "assets/fonts/ShareTechMono-Regular.ttf",-- numerics / keycaps
        },

        -- Type scale (px @ 1920x1080 reference).
        typeScale = {
            hero = 150, title = 75, display = 48, subtitle = 24,
            body = 18, ui = 16, small = 14, micro = 12,
        },
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
