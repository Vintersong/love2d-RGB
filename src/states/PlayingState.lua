-- PlayingState.lua
-- Main gameplay state where the player fights enemies and collects XP.

local PlayingState = {}
local Config = require("src.Config")

local PlayingUpdateLoop = require("src.states.playing.PlayingUpdateLoop")
local PlayingRenderLayers = require("src.states.playing.PlayingRenderLayers")
local PlayingInputHandlers = require("src.states.playing.PlayingInputHandlers")
local PlayingEnemyFlow = require("src.states.playing.PlayingEnemyFlow")

-- Forward declarations for systems
local MusicReactor, ColorSystem, SpawnController, World, HealthSystem
local AttackSystem, UISystem, FloatingTextSystem, VFXLibrary
local XPParticleSystem, CollisionSystem, GridAttackSystem, BackgroundShader, SimpleGrid
local LightningEffect, ShieldEffect, ProjectileCollisionSystem, PickupSystem, BossCoordinator

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
        GridAttackSystem = GridAttackSystem,
        BackgroundShader = BackgroundShader,
        SimpleGrid = SimpleGrid,
        LightningEffect = LightningEffect,
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
    local GameConfig = require("src.systems.GameConfig")
    local ColorSystemLocal = require("src.systems.ColorSystem")
    local SynergySystem = require("src.systems.SynergySystem")
    local ArtifactManager = require("src.systems.ArtifactManager")
    local SpawnControllerLocal = require("src.systems.SpawnController")
    local BossSystem = require("src.systems.BossSystem")
    local CollisionSystemLocal = require("src.systems.CollisionSystem")
    local VFXLibraryLocal = require("src.systems.VFXLibrary")

    if PlayingState.player and PlayingState.player.destroy then
        PlayingState.player:destroy()
    end

    ColorSystemLocal.init()
    SynergySystem.reset()
    ArtifactManager.reset()
    CollisionSystemLocal.init(Config.gameplay.cellSize)
    VFXLibraryLocal.clear()

    PlayingState.screenWidth, PlayingState.screenHeight = GameConfig.getScreenSize()
    SpawnControllerLocal.init(PlayingState.screenWidth, PlayingState.screenHeight)
    BossSystem.reset()

    PlayingState.player = Player(512, 360, Weapon())
    PlayingState.enemies = {}
    PlayingState.xpOrbs = {}
    PlayingState.powerups = {}
    PlayingState.explosions = {}
    PlayingState.bossProjectiles = {}
    PlayingState.supernovaEffects = {}
    PlayingState.gameTime = 0
    PlayingState.enemyKillCount = 0
    PlayingState.musicReactor = GameConfig.getMusicReactor()

    return PlayingState
end

function PlayingState:enter(previous, data)
    if not MusicReactor then
        MusicReactor = require("src.systems.MusicReactor")
        ColorSystem = require("src.systems.ColorSystem")
        SpawnController = require("src.systems.SpawnController")
        World = require("src.systems.World")
        HealthSystem = require("src.systems.HealthSystem")
        AttackSystem = require("src.systems.AttackSystem")
        UISystem = require("src.systems.UISystem")
        FloatingTextSystem = require("src.systems.FloatingTextSystem")
        VFXLibrary = require("src.systems.VFXLibrary")
        XPParticleSystem = require("src.systems.XPParticleSystem")
        CollisionSystem = require("src.systems.CollisionSystem")
        GridAttackSystem = require("src.systems.GridAttackSystem")
        BackgroundShader = require("src.systems.BackgroundShader")
        SimpleGrid = require("src.systems.SimpleGrid")
        LightningEffect = require("src.systems.LightningEffect")
        ShieldEffect = require("src.systems.ShieldEffect")
        ProjectileCollisionSystem = require("src.systems.ProjectileCollisionSystem")
        PickupSystem = require("src.systems.PickupSystem")
        BossCoordinator = require("src.systems.BossCoordinator")

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

function PlayingState:activateSupernova()
    return PlayingEnemyFlow.activateSupernova(self, getDeps())
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
