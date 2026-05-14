local flux = require("libs.flux-master.flux")
local PlayingUpdateLoop = {}

function PlayingUpdateLoop.update(state, dt, deps)
    local SpawnController = deps.SpawnController
    local BackgroundShader = deps.BackgroundShader
    local SimpleGrid = deps.SimpleGrid
    local World = deps.World
    local FloatingTextSystem = deps.FloatingTextSystem
    local VFXLibrary = deps.VFXLibrary
    local LightningEffect = deps.LightningEffect
    local ShieldEffect = deps.ShieldEffect
    local AttackSystem = deps.AttackSystem
    local ProjectileCollisionSystem = deps.ProjectileCollisionSystem
    local PickupSystem = deps.PickupSystem
    local BossCoordinator = deps.BossCoordinator
    local enemyFlow = deps.enemyFlow

    if state.musicReactor then
        state.musicReactor:update(dt)
    end

    BackgroundShader.update(dt, state.musicReactor, state.player)
    SimpleGrid.update(dt, state.musicReactor)
    World.update(dt, state.musicReactor)
    flux.update(dt)
    FloatingTextSystem.update(dt)
    VFXLibrary.update(dt)
    VFXLibrary.updateImpactBursts(dt)

    state.gameTime = state.gameTime + dt

    local centerX = state.player.x + state.player.width / 2
    local centerY = state.player.y + state.player.height / 2

    state.player:update(dt, state.enemies)
    state.player:checkDashCollisions(state.enemies)
    state.player:autoFire(state.enemies, BossCoordinator.getActiveBoss())

    LightningEffect.update(dt)
    ShieldEffect.update(dt)
    SpawnController.update(dt, state.player.level, state.musicReactor, state.enemies)

    enemyFlow.updateEnemies(state, dt, centerX, centerY, deps)
    enemyFlow.updateEnemyProjectileCollisions(state, deps)

    local dotKillCallback = function(target)
        SpawnController.handleEnemyDeath(target, state.player, state.xpOrbs, state.powerups)
    end
    AttackSystem.updateDoTs(state.enemies, dt, dotKillCallback)

    ProjectileCollisionSystem.update(state.player, state.enemies, state.xpOrbs, state.powerups, state.explosions)
    enemyFlow.updateExplosions(state, dt, deps)
    enemyFlow.updateSupernovaEffects(state, dt, deps)

    PickupSystem.updateXPOrbs(dt, state.player, state.xpOrbs, centerX, centerY)
    PickupSystem.updatePowerups(dt, state.player, state.enemies, state.powerups, centerX, centerY)

    if state.player:canLevelUp() then
        local StateManager = require("src.systems.StateManager")
        StateManager.push("LevelUp", {
            player = state.player,
            enemies = state.enemies,
            xpOrbs = state.xpOrbs,
            powerups = state.powerups,
            explosions = state.explosions,
            bossProjectiles = state.bossProjectiles,
            supernovaEffects = state.supernovaEffects,
            gameTime = state.gameTime,
            enemyKillCount = SpawnController.enemyKillCount,
            musicReactor = state.musicReactor
        })
        return
    end

    local activeBossBefore = BossCoordinator.getActiveBoss()
    BossCoordinator.update(dt, state.player, state.player.projectiles, state.bossProjectiles, state.musicReactor, state.enemies)
    if activeBossBefore and not activeBossBefore.alive and not BossCoordinator.getActiveBoss() then
        local StateManager = require("src.systems.StateManager")
        StateManager.switch("Victory", {
            player = state.player,
            enemies = state.enemies,
            xpOrbs = state.xpOrbs,
            musicReactor = state.musicReactor,
            gameTime = state.gameTime,
            enemyKillCount = SpawnController.enemyKillCount,
        })
        return
    end
end

return PlayingUpdateLoop
