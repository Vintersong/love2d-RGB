-- main.lua
-- Streamlined main entry point using hump.gamestate for state management

-- Boot validation system
local BootLoader = require("src.systems.BootLoader")

-- State management systems
local Gamestate = require("libs.hump-master.gamestate")
local StateManager = require("src.systems.StateManager")
local GameConfig = require("src.systems.GameConfig")

-- Game systems (initialized once)
local MusicReactor = require("src.systems.MusicReactor")
local ColorSystem = require("src.systems.ColorSystem")
local World = require("src.systems.World")
local FloatingTextSystem = require("src.systems.FloatingTextSystem")
local VFXLibrary = require("src.systems.VFXLibrary")
local ShapeLibrary = require("src.systems.ShapeLibrary")
local XPParticleSystem = require("src.systems.XPParticleSystem")
local BossSystem = require("src.systems.BossSystem")
local DebugMenu = require("src.systems.DebugMenu")
local CollisionSystem = require("src.systems.CollisionSystem")
local GridAttackSystem = require("src.systems.GridAttackSystem")
local SongLibrary = require("src.systems.SongLibrary")
local BackgroundShader = require("src.systems.BackgroundShader")
local SimpleGrid = require("src.systems.SimpleGrid")
local AttackSystem = require("src.systems.AttackSystem")
local HealthSystem = require("src.systems.HealthSystem")
local SpawnController = require("src.systems.SpawnController")
local EnemySpawner = require("src.systems.EnemySpawner")
local ArtifactManager = require("src.systems.ArtifactManager")
local SynergySystem = require("src.systems.SynergySystem")
local AbilitySystem = require("src.systems.AbilitySystem")
local UISystem = require("src.systems.UISystem")
local LightningEffect = require("src.systems.LightningEffect")
local ShieldEffect = require("src.systems.ShieldEffect")
local ProjectileScheduler = require("src.systems.ProjectileScheduler")
local MathUtils = require("src.systems.MathUtils")
local BehaviorSelector = require("src.systems.BehaviorSelector")
local EnemyBehaviors = require("src.data.EnemyBehaviors")
local BossBehaviors = require("src.data.BossBehaviors")

-- Game states
local SplashScreen = require("src.states.SplashScreenState")
local PlayingState = require("src.states.PlayingState")
local LevelUpState = require("src.states.LevelUpState")
local GameOverState = require("src.states.GameOverState")
local VictoryState = require("src.states.VictoryState")
local PauseState = require("src.states.PauseState")
local UISandboxState = require("src.states.UISandboxState")

-- Constants
local Config = require("src.Config")
local screenWidth = Config.screen.width
local screenHeight = Config.screen.height

function love.load()
    -- Register systems for validation
    BootLoader.registerSystem("ColorSystem", ColorSystem, {"init", "getDominantColor", "getProjectileColor"})
    BootLoader.registerSystem("World", World, {"init", "update", "draw"})
    BootLoader.registerSystem("FloatingTextSystem", FloatingTextSystem, {"init"})
    BootLoader.registerSystem("VFXLibrary", VFXLibrary, {"clear"})
    BootLoader.registerSystem("ShapeLibrary", ShapeLibrary, {"circle", "triangle", "atom", "prism"})
    BootLoader.registerSystem("XPParticleSystem", XPParticleSystem, {"init"})
    BootLoader.registerSystem("BossSystem", BossSystem, {"init"})
    BootLoader.registerSystem("DebugMenu", DebugMenu, {"init"})
    BootLoader.registerSystem("CollisionSystem", CollisionSystem, {"init", "add", "update", "remove"})
    BootLoader.registerSystem("GridAttackSystem", GridAttackSystem, {"init", "update", "draw"})
    BootLoader.registerSystem("BackgroundShader", BackgroundShader, {"init", "update", "draw"})
    BootLoader.registerSystem("SimpleGrid", SimpleGrid, {"init", "update", "draw"})
    BootLoader.registerSystem("GameConfig", GameConfig, {"init", "getMusicReactor", "getScreenSize", "isDebugMode"})
    BootLoader.registerSystem("MusicReactor", MusicReactor, {"new"})
    BootLoader.registerSystem("SongLibrary", SongLibrary, {"getRandomSong", "getSongCount"})
    BootLoader.registerSystem("AttackSystem", AttackSystem, {"projectileHit", "enemyContactDamage", "updateDoTs", "processExplosion"})
    BootLoader.registerSystem("HealthSystem", HealthSystem, {"register", "takeDamage", "reset"})
    BootLoader.registerSystem("SpawnController", SpawnController, {"init", "update", "handleEnemyDeath"})
    BootLoader.registerSystem("EnemySpawner", EnemySpawner, {"update", "returnToPool"})
    BootLoader.registerSystem("ArtifactManager", ArtifactManager, {"collect", "getLevel", "reset"})
    BootLoader.registerSystem("SynergySystem", SynergySystem, {"checkAndActivate", "reset", "getCount"})
    BootLoader.registerSystem("AbilitySystem", AbilitySystem, {"register", "activate", "update"})
    BootLoader.registerSystem("UISystem", UISystem, {"drawPlayerHUD", "drawArtifactPanel", "drawEnemyInfo"})
    BootLoader.registerSystem("LightningEffect", LightningEffect, {"trigger", "fireChain", "update", "draw"})
    BootLoader.registerSystem("ShieldEffect", ShieldEffect, {"trigger", "setPosition", "update", "draw"})
    BootLoader.registerSystem("ProjectileScheduler", ProjectileScheduler, {"schedule", "update", "clear"})
    BootLoader.registerSystem("MathUtils", MathUtils, {"atan2", "angleBetween"})
    BootLoader.registerSystem("BehaviorSelector", BehaviorSelector, {"buildContext", "select", "execute", "updateCooldowns"})
    BootLoader.registerSystem("EnemyBehaviors", EnemyBehaviors, {"getAll", "getById", "listByKind"})
    BootLoader.registerSystem("BossBehaviors", BossBehaviors, {"getAll", "getById", "listByKind"})

    -- Validate all systems loaded correctly
    if not BootLoader.validateAll() then
        error("[BootLoader] System validation failed! See console for details.")
    end

    -- Perform health checks
    BootLoader.performHealthChecks()

    -- Print boot report
    BootLoader.printReport()

    -- Abort if critical errors found
    if not BootLoader.isHealthy() then
        error("[BootLoader] Boot failed! See report above.")
    end

    -- Initialize systems with error handling
    BootLoader.initializeSystem("ColorSystem", ColorSystem.init)
    BootLoader.initializeSystem("World", World.init)
    BootLoader.initializeSystem("FloatingTextSystem", FloatingTextSystem.init)
    BootLoader.initializeSystem("VFXLibrary", VFXLibrary.clear)
    BootLoader.initializeSystem("XPParticleSystem", XPParticleSystem.init)
    BootLoader.initializeSystem("BossSystem", BossSystem.init)
    BootLoader.initializeSystem("DebugMenu", DebugMenu.init)
    BootLoader.initializeSystem("CollisionSystem", CollisionSystem.init, Config.gameplay.cellSize)
    BootLoader.initializeSystem("GridAttackSystem", GridAttackSystem.init, screenWidth, screenHeight)
    BootLoader.initializeSystem("BackgroundShader", BackgroundShader.init, screenWidth, screenHeight)
    BootLoader.initializeSystem("SimpleGrid", SimpleGrid.init, screenWidth, screenHeight)

    -- Initialize music with random song selection
    local musicReactor = MusicReactor:new()
    local randomSong = SongLibrary.getRandomSong()

    local success, song = pcall(function()
        return musicReactor:loadSong(randomSong.audioPath, randomSong.structure)
    end)

    if success and song then
        musicReactor:play()
        print(string.format("[Game] Music loaded and playing: %s (%d songs available)", randomSong.name, SongLibrary.getSongCount()))
        print(string.format("[Game] Detected BPM: %.1f", musicReactor:getCurrentBPM()))
    else
        print("[Game] Could not load music, continuing without audio")
    end

    -- Initialize GameConfig with music reactor and screen dimensions
    GameConfig.init(musicReactor, screenWidth, screenHeight)

    -- Initialize StateManager and register all states
    StateManager.init()
    StateManager.register("Splash", SplashScreen, {
        description = "Initial splash screen",
        tags = {"menu", "start"}
    })
    StateManager.register("Playing", PlayingState, {
        description = "Main gameplay state",
        systems = {"ColorSystem", "World", "CollisionSystem", "MusicReactor"},
        tags = {"gameplay", "core"}
    })
    StateManager.register("LevelUp", LevelUpState, {
        description = "Artifact selection screen",
        dependencies = {"Playing"},
        tags = {"menu", "gameplay"}
    })
    StateManager.register("GameOver", GameOverState, {
        description = "Game over screen",
        tags = {"menu", "end"}
    })
    StateManager.register("Victory", VictoryState, {
        description = "Victory screen",
        tags = {"menu", "end"}
    })
    StateManager.register("Pause", PauseState, {
        description = "Pause overlay",
        dependencies = {"Playing"},
        tags = {"menu", "gameplay"}
    })
    StateManager.register("UISandbox", UISandboxState, {
        description = "HUD sandbox",
        tags = {"menu", "debug"}
    })

    -- Validate state dependencies
    if not StateManager.validateAll() then
        error("[StateManager] State validation failed! See console for details.")
    end
    StateManager.printReport()

    -- Register gamestate events and start with SplashScreen
    Gamestate.registerEvents()

    -- Use StateManager to track current state
    if not StateManager.switch("Splash") then
        error("[StateManager] Cannot start game - Splash state is disabled!")
    end
end

function love.resize(w, h)
    -- UI is designed for 1920x1080 fixed resolution - ignore resize events
end
