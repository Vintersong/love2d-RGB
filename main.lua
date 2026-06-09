-- main.lua
-- Streamlined main entry point using hump.gamestate for state management

-- Boot validation system
local BootLoader = require("src.core.BootLoader")

-- State management systems
local Gamestate = require("libs.hump-master.gamestate")
local StateManager = require("src.core.StateManager")
local GameConfig = require("src.core.GameConfig")
local Runtime = require("src.core.Runtime")
local MetaProgression = require("src.core.MetaProgression")

-- Game systems (initialized once)
local MusicReactor = require("src.audio.MusicReactor")
local ColorSystem = require("src.gameplay.ColorSystem")
local ColorEconomy = require("src.gameplay.ColorEconomy")
local World = require("src.gameplay.World")
local FloatingTextSystem = require("src.effects.FloatingTextSystem")
local VFXLibrary = require("src.effects.VFXLibrary")
local ShapeLibrary = require("src.render.ShapeLibrary")
local XPParticleSystem = require("src.effects.XPParticleSystem")
local BossSystem = require("src.boss.BossSystem")
local DebugMenu = require("src.debug.DebugMenu")
local CollisionSystem = require("src.combat.CollisionSystem")
local SongLibrary = require("src.audio.SongLibrary")
local BackgroundShader = require("src.render.BackgroundShader")
local SimpleGrid = require("src.gameplay.SimpleGrid")
local AttackSystem = require("src.combat.AttackSystem")
local HealthSystem = require("src.combat.HealthSystem")
local SpawnController = require("src.spawning.SpawnController")
local EnemySpawner = require("src.spawning.EnemySpawner")
local ArtifactManager = require("src.gameplay.ArtifactManager")
local SynergySystem = require("src.gameplay.SynergySystem")
local AbilitySystem = require("src.combat.AbilitySystem")
local UISystem = require("src.ui.UISystem")
local ShieldEffect = require("src.effects.ShieldEffect")
local ProjectileScheduler = require("src.combat.ProjectileScheduler")
local MathUtils = require("src.utils.MathUtils")
local BehaviorSelector = require("src.combat.BehaviorSelector")
local EnemyBehaviors = require("src.data.EnemyBehaviors")
local BossBehaviors = require("src.data.BossBehaviors")
local BossProgression = require("src.data.BossProgression")
local CustomCursor = require("src.render.CustomCursor")
local Viewport = require("src.render.Viewport")

-- Game states
local SplashScreen = require("src.states.SplashScreenState")
local MenuState = require("src.states.MenuState")
local PlayingState = require("src.states.PlayingState")
local LevelUpState = require("src.states.LevelUpState")
local GameOverState = require("src.states.GameOverState")
local VictoryState = require("src.states.VictoryState")
local PauseState = require("src.states.PauseState")
local UISandboxState = require("src.states.UISandboxState")
local OptionsState = require("src.states.OptionsState")
local LoadingState = require("src.states.LoadingState")
local TutorialState = require("src.states.TutorialState")
local AtlasState = require("src.states.AtlasState")
local ProgressionState = require("src.states.ProgressionState")
local ConfirmState = require("src.states.ConfirmState")
local RunSummaryState = require("src.states.RunSummaryState")

-- Constants
local Config = require("src.Config")
local screenWidth = Config.screen.width
local screenHeight = Config.screen.height

local function wrapPointerCallback(name, original)
    if not original then
        return nil
    end

    if name == "mousepressed" or name == "mousereleased" then
        return function(x, y, button, istouch, presses)
            local gx, gy = Viewport.toGameCoords(x, y)
            return original(gx, gy, button, istouch, presses)
        end
    end

    if name == "mousemoved" then
        return function(x, y, dx, dy, istouch)
            local gx, gy = Viewport.toGameCoords(x, y)
            local gdx, gdy = Viewport.toGameDelta(dx, dy)
            return original(gx, gy, gdx, gdy, istouch)
        end
    end

    if name == "touchpressed" then
        return function(id, x, y, dx, dy, pressure)
            local gx, gy = Viewport.toGameCoords(x, y)
            local gdx, gdy = Viewport.toGameDelta(dx or 0, dy or 0)
            return original(id, gx, gy, gdx, gdy, pressure)
        end
    end

    return original
end

local function installViewportCallbacks()
    local gamestateDraw = love.draw
    if gamestateDraw then
        love.draw = function(...)
            Viewport.beginFrame()
            gamestateDraw(...)
            Viewport.endFrame()
        end
    end

    for _, callbackName in ipairs({"mousepressed", "mousereleased", "mousemoved", "touchpressed"}) do
        love[callbackName] = wrapPointerCallback(callbackName, love[callbackName])
    end
end

function love.load(args)
    Runtime.init(args)
    love.window.setTitle(Config.screen.title or "CHROMATIC")

    Viewport.init(screenWidth, screenHeight)

    -- Apply custom glowing cursor (hardware cursor image).
    CustomCursor.init()

    -- Register systems for validation
    BootLoader.registerSystem("ColorSystem", ColorSystem, {"init", "getDominantColor", "getProjectileColor"})
    BootLoader.registerSystem("ColorEconomy", ColorEconomy, {"init", "classify", "registerKill", "update"})
    BootLoader.registerSystem("World", World, {"init", "update", "draw"})
    BootLoader.registerSystem("FloatingTextSystem", FloatingTextSystem, {"init"})
    BootLoader.registerSystem("VFXLibrary", VFXLibrary, {"clear"})
    BootLoader.registerSystem("ShapeLibrary", ShapeLibrary, {"circle", "triangle", "atom", "prism"})
    BootLoader.registerSystem("XPParticleSystem", XPParticleSystem, {"init"})
    BootLoader.registerSystem("BossSystem", BossSystem, {"init"})
    BootLoader.registerSystem("DebugMenu", DebugMenu, {"init"})
    BootLoader.registerSystem("CollisionSystem", CollisionSystem, {"init", "add", "update", "remove"})
    BootLoader.registerSystem("BackgroundShader", BackgroundShader, {"init", "update", "draw"})
    BootLoader.registerSystem("SimpleGrid", SimpleGrid, {"init", "update", "draw"})
    BootLoader.registerSystem("GameConfig", GameConfig, {"init", "getMusicReactor", "getScreenSize", "isDebugMode"})
    BootLoader.registerSystem("MetaProgression", MetaProgression, {"load", "save", "recordRun", "reset"})
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
    BootLoader.registerSystem("ShieldEffect", ShieldEffect, {"trigger", "setPosition", "update", "draw"})
    BootLoader.registerSystem("ProjectileScheduler", ProjectileScheduler, {"schedule", "update", "clear"})
    BootLoader.registerSystem("MathUtils", MathUtils, {"atan2", "angleBetween"})
    BootLoader.registerSystem("BehaviorSelector", BehaviorSelector, {"buildContext", "select", "execute", "updateCooldowns"})
    BootLoader.registerSystem("EnemyBehaviors", EnemyBehaviors, {"getAll", "getById", "listByKind"})
    BootLoader.registerSystem("BossBehaviors", BossBehaviors, {"getAll", "getById", "listByKind"})
    BootLoader.registerSystem("BossProgression", BossProgression, {"getForEncounter", "getTierCount"})

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
    BootLoader.initializeSystem("ColorEconomy", ColorEconomy.init)
    BootLoader.initializeSystem("World", World.init)
    BootLoader.initializeSystem("FloatingTextSystem", FloatingTextSystem.init)
    BootLoader.initializeSystem("VFXLibrary", VFXLibrary.clear)
    BootLoader.initializeSystem("XPParticleSystem", XPParticleSystem.init)
    BootLoader.initializeSystem("BossSystem", BossSystem.init)
    BootLoader.initializeSystem("DebugMenu", DebugMenu.init)
    BootLoader.initializeSystem("CollisionSystem", CollisionSystem.init, Config.gameplay.cellSize)
    BootLoader.initializeSystem("BackgroundShader", BackgroundShader.init, screenWidth, screenHeight)
    BootLoader.initializeSystem("SimpleGrid", SimpleGrid.init, screenWidth, screenHeight)
    BootLoader.initializeSystem("MetaProgression", MetaProgression.load)

    -- Load persisted player preferences (mirrors known keys into Config)
    require("src.core.Settings").load()

    -- Apply master volume mute or set from configuration
    if love.audio then
        if Config.debug.muteAudio then
            love.audio.setVolume(0)
            print("[Game] Audio muted at startup due to muteAudio debug configuration")
        else
            love.audio.setVolume(Config.sound.volume or 0.8)
            print(string.format("[Game] Master volume set to %.0f%% at startup", (Config.sound.volume or 0.8) * 100))
        end
    end

    -- Initialize menu music with Song 1 as the CHROMATIC OST identity.
    local musicReactor = MusicReactor:new()
    local startingSong = SongLibrary.getSongByIndex(1) or SongLibrary.getRandomSong()

    local success, song = pcall(function()
        return musicReactor:loadSingleSongData(startingSong, {
            skipAnalysis = Runtime.isWeb(),
            bpm = startingSong.bpm,
            sourceType = Runtime.isWeb() and "static" or "stream",
            looping = true,
        })
    end)

    if success and song then
        if Runtime.isWeb() then
            print(string.format("[Game] Music loaded for browser playback after input: %s (%d songs available)", startingSong.name, SongLibrary.getSongCount()))
        else
            musicReactor:play()
            print(string.format("[Game] Music loaded and playing: %s (%d songs available)", startingSong.name, SongLibrary.getSongCount()))
        end
        print(string.format("[Game] BPM: %.1f", musicReactor:getCurrentBPM()))
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
    StateManager.register("Menu", MenuState, {
        description = "Main menu screen",
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
    StateManager.register("Options", OptionsState, {
        description = "Options and settings menu",
        tags = {"menu", "settings"}
    })
    StateManager.register("Loading", LoadingState, {
        description = "Run loading and preparation",
        tags = {"system", "transition"}
    })
    StateManager.register("Tutorial", TutorialState, {
        description = "Onboarding and replayable tutorial deck",
        tags = {"menu", "tutorial"}
    })
    StateManager.register("Atlas", AtlasState, {
        description = "Color and artifact reference atlas",
        tags = {"menu", "reference"}
    })
    StateManager.register("Progression", ProgressionState, {
        description = "Persistent profile and unlock screen",
        tags = {"menu", "meta"}
    })
    StateManager.register("Confirm", ConfirmState, {
        description = "Generic confirmation modal",
        tags = {"menu", "modal"}
    })
    StateManager.register("RunSummary", RunSummaryState, {
        description = "Post-run summary and unlock recap",
        tags = {"menu", "meta", "end"}
    })

    -- Validate state dependencies
    if not StateManager.validateAll() then
        error("[StateManager] State validation failed! See console for details.")
    end
    StateManager.printReport()

    -- Register gamestate events and start with SplashScreen
    Gamestate.registerEvents()
    installViewportCallbacks()

    -- Use StateManager to track current state
    if not StateManager.switch("Splash") then
        error("[StateManager] Cannot start game - Splash state is disabled!")
    end
end

function love.resize(w, h)
    Viewport.resize(w, h)
end
