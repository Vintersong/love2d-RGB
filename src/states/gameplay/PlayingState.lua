-- PlayingState.lua
-- Main gameplay state where the player fights enemies and collects XP.

local PlayingState = {}
local Config = require("src.Config")

local PlayingUpdateLoop = require("src.states.gameplay.playing.PlayingUpdateLoop")
local PlayingRenderLayers = require("src.states.gameplay.playing.PlayingRenderLayers")
local PlayingInputHandlers = require("src.states.gameplay.playing.PlayingInputHandlers")
local PlayingEnemyFlow = require("src.states.gameplay.playing.PlayingEnemyFlow")

-- Forward declarations for systems
local MusicReactor, ColorSystem, SpawnController, World, HealthSystem
local AttackSystem, UISystem, FloatingTextSystem, VFXLibrary
local XPParticleSystem, CollisionSystem, BackgroundShader, SimpleGrid
local ShieldEffect, ProjectileCollisionSystem, PickupSystem, BossCoordinator

PlayingState.player = nil
PlayingState.enemies = {}
PlayingState.xpOrbs = {}
PlayingState.powerups = {}
PlayingState.explosions = {}
PlayingState.bossProjectiles = {}
PlayingState.gameTime = 0
PlayingState.musicReactor = nil
PlayingState.screenWidth = Config.screen.width
PlayingState.screenHeight = Config.screen.height
PlayingState.supernovaEffects = {}

local function getDeps()
    return {
        MusicReactor = MusicReactor,
        ColorSystem = ColorSystem,
        SpawnController = SpawnController,
        World = World,
        HealthSystem = HealthSystem,
        AttackSystem = AttackSystem,
        UISystem = UISystem,
        FloatingTextSystem = FloatingTextSystem,
        VFXLibrary = VFXLibrary,
        XPParticleSystem = XPParticleSystem,
        CollisionSystem = CollisionSystem,
        BackgroundShader = BackgroundShader,
        SimpleGrid = SimpleGrid,
        ShieldEffect = ShieldEffect,
        ProjectileCollisionSystem = ProjectileCollisionSystem,
        PickupSystem = PickupSystem,
        BossCoordinator = BossCoordinator,
        enemyFlow = PlayingEnemyFlow,
    }
end

function PlayingState.startNewRun()
    local Player = require("src.entities.Player")
    local Weapon = require("src.Weapon")
    local GameConfig = require("src.core.GameConfig")
    local Runtime = require("src.core.Runtime")
    local SongLibrary = require("src.audio.SongLibrary")
    local ColorSystemLocal = require("src.gameplay.ColorSystem")
    local ColorEconomyLocal = require("src.gameplay.ColorEconomy")
    local SynergySystem = require("src.gameplay.SynergySystem")
    local ArtifactManager = require("src.gameplay.ArtifactManager")
    local SpawnControllerLocal = require("src.spawning.SpawnController")
    local BossSystem = require("src.boss.BossSystem")
    local EconomySystem = require("src.economy.EconomySystem")
    local CollisionSystemLocal = require("src.combat.CollisionSystem")
    local VFXLibraryLocal = require("src.effects.VFXLibrary")

    if PlayingState.player and PlayingState.player.destroy then
        PlayingState.player:destroy()
    end

    ColorSystemLocal.init()
    ColorEconomyLocal.reset()
    SynergySystem.reset()
    ArtifactManager.reset()
    CollisionSystemLocal.init(Config.gameplay.cellSize)
    VFXLibraryLocal.clear()
    require("src.gameplay.TutorialSystem").beginRun()

    PlayingState.screenWidth, PlayingState.screenHeight = GameConfig.getScreenSize()
    SpawnControllerLocal.init(PlayingState.screenWidth, PlayingState.screenHeight)
    BossSystem.reset()
    EconomySystem.reset()

    local playerWidth = 32
    local playerHeight = 32
    local playerX = (PlayingState.screenWidth - playerWidth) * 0.5
    local playerY = (PlayingState.screenHeight - playerHeight) * 0.5
    PlayingState.player = Player(playerX, playerY, Weapon())
    PlayingState.enemies = {}
    PlayingState.xpOrbs = {}
    PlayingState.powerups = {}
    PlayingState.explosions = {}
    PlayingState.bossProjectiles = {}
    PlayingState.supernovaEffects = {}
    PlayingState.gameTime = 0
    PlayingState.enemyKillCount = 0
    PlayingState.musicReactor = GameConfig.getMusicReactor()
    if PlayingState.musicReactor then
        local fullPlaylist = SongLibrary.getGameplayPlaylist()
        if #fullPlaylist > 0 then
            local pick = math.random(1, #fullPlaylist)
            local runSong = { fullPlaylist[pick] }  -- one song defines the run length
            local source = PlayingState.musicReactor:loadPlaylist(runSong, 1, {
                skipAnalysis = Runtime.isWeb(),
                sourceType = Runtime.isWeb() and "static" or "stream",
            })
            if source and (not Runtime.isWeb() or (Config.runtime and Config.runtime.musicStarted)) then
                PlayingState.musicReactor:play()
            end
            local songInfo = PlayingState.musicReactor.currentSongInfo
            if songInfo then
                print(string.format("[Game] Run song: %s", songInfo.name))
            end
        end
    end
    GameConfig.setActiveRun(true)

    return PlayingState
end

function PlayingState:enter(previous, data)
    if not MusicReactor then
        MusicReactor = require("src.audio.MusicReactor")
        ColorSystem = require("src.gameplay.ColorSystem")
        SpawnController = require("src.spawning.SpawnController")
        World = require("src.gameplay.World")
        HealthSystem = require("src.combat.HealthSystem")
        AttackSystem = require("src.combat.AttackSystem")
        UISystem = require("src.ui.UISystem")
        FloatingTextSystem = require("src.effects.FloatingTextSystem")
        VFXLibrary = require("src.effects.VFXLibrary")
        XPParticleSystem = require("src.effects.XPParticleSystem")
        CollisionSystem = require("src.combat.CollisionSystem")
        BackgroundShader = require("src.render.BackgroundShader")
        SimpleGrid = require("src.gameplay.SimpleGrid")
        ShieldEffect = require("src.effects.ShieldEffect")
        ProjectileCollisionSystem = require("src.combat.ProjectileCollisionSystem")
        PickupSystem = require("src.gameplay.PickupSystem")
        BossCoordinator = require("src.boss.BossCoordinator")

        SpawnController.init(self.screenWidth, self.screenHeight)
    end

    if data then
        self.player = data.player
        self.enemies = data.enemies or {}
        self.xpOrbs = data.xpOrbs or {}
        self.powerups = data.powerups or {}
        self.explosions = data.explosions or {}
        self.bossProjectiles = data.bossProjectiles or {}
        self.supernovaEffects = data.supernovaEffects or {}
        self.gameTime = data.gameTime or 0
        SpawnController.enemyKillCount = data.enemyKillCount or 0
        self.musicReactor = data.musicReactor
    end

    if self.player and CollisionSystem.world and not CollisionSystem.world:hasItem(self.player) then
        CollisionSystem.add(self.player, "player")
    end

    BossCoordinator.bossProjectiles = self.bossProjectiles
end

function PlayingState:update(dt)
    PlayingUpdateLoop.update(self, dt, getDeps())
end

function PlayingState:draw()
    PlayingRenderLayers.draw(self, getDeps())
end

function PlayingState:keypressed(key)
    PlayingInputHandlers.keypressed(self, key, getDeps())
end

function PlayingState:captureAliveEnemies()
    return PlayingEnemyFlow.captureAliveEnemies(self)
end

function PlayingState:rewardNewEnemyDeaths(aliveBefore)
    PlayingEnemyFlow.rewardNewEnemyDeaths(self, aliveBefore, getDeps())
end

function PlayingState:updateSupernovaEffects(dt)
    PlayingEnemyFlow.updateSupernovaEffects(self, dt, getDeps())
end

function PlayingState:updateEnemies(dt, centerX, centerY)
    PlayingEnemyFlow.updateEnemies(self, dt, centerX, centerY, getDeps())
end

function PlayingState:updateEnemyProjectileCollisions(centerX, centerY)
    PlayingEnemyFlow.updateEnemyProjectileCollisions(self, getDeps())
end

function PlayingState:updateExplosions(dt)
    PlayingEnemyFlow.updateExplosions(self, dt, getDeps())
end

function PlayingState:calculateDropChance(orbType, playerLevel, time)
    return PickupSystem.calculateDropChance(orbType, playerLevel, time)
end

function PlayingState:spawnOrbsForEnemy(enemy)
    return PickupSystem.spawnOrbsForEnemy(enemy, self.player, self.gameTime, self.screenWidth, self.screenHeight)
end

return PlayingState
