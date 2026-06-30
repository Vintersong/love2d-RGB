local flux = require("libs.flux-master.flux")
local FirstEncounter = require("src.gameplay.FirstEncounter")
local RunSummary = require("src.core.RunSummary")
local OnboardingSequence = require("src.gameplay.OnboardingSequence")
local Config = require("src.Config")
local RingBoss = require("src.patterns.RingBoss")
local PlayingUpdateLoop = {}

function PlayingUpdateLoop.update(state, dt, deps)
    local SpawnController = deps.SpawnController
    local SimpleGrid = deps.SimpleGrid
    local World = deps.World
    local FloatingTextSystem = deps.FloatingTextSystem
    local VFXLibrary = deps.VFXLibrary
    local ShieldEffect = deps.ShieldEffect
    local AttackSystem = deps.AttackSystem
    local ProjectileCollisionSystem = deps.ProjectileCollisionSystem
    local PickupSystem = deps.PickupSystem
    local BossCoordinator = deps.BossCoordinator
    local enemyFlow = deps.enemyFlow

    -- Win-condition routing.
    -- ORIGINAL (preserved, default): track-completion -- the run is WON when the music song
    -- finishes playing. This `songEnded` check must be evaluated BEFORE musicReactor:update,
    -- which would call advancePlaylist internally and reset isPlaying = true.
    -- NEW (flag-gated by Config.boss.ringBoss.use_ring_boss_wincon, default false): the player
    -- wins only by destroying the exposed ring-boss core during Phase 4. The original path is
    -- left fully intact for reconciliation; routing lives in RingBoss.evaluateWincon.
    local ringCfg = (Config.boss and Config.boss.ringBoss) or {}
    -- Debug endless mode: suppress the track-completion win so the run never auto-ends; the
    -- playlist's own autoAdvance then loops/cycles the music. Lets you reach + balance bosses.
    local endlessMode = Config.debug and Config.debug.endlessMode
    local songEnded = (not endlessMode) and state.musicReactor and state.musicReactor.isPlaying
        and state.musicReactor.currentSong
        and not state.musicReactor.currentSong:isPlaying()
    local activeBoss = deps.BossCoordinator and deps.BossCoordinator.getActiveBoss()
    -- Auto-pair the core-kill win condition: while a ring boss is alive the win is its P4
    -- core kill (song-end suppressed for the duration); with no ring boss the original
    -- track-completion path is unchanged. So enabling Config.boss.ringBoss.enabled alone
    -- yields a winnable finale -- no second flag needed. RingBoss.evaluateWincon is untouched.
    local ringBossActive = activeBoss and activeBoss.ringPhase ~= nil
    local won = RingBoss.evaluateWincon({
        useRingWincon = (ringCfg.use_ring_boss_wincon or ringBossActive) and true or false,
        songEnded = songEnded and true or false,
        phase = activeBoss and activeBoss.ringPhase or nil,
        coreDestroyed = activeBoss and activeBoss.coreDestroyed or false,
    })
    if won then
        local StateManager = require("src.core.StateManager")
        StateManager.switch("Victory", {
            player = state.player,
            enemies = state.enemies,
            xpOrbs = state.xpOrbs or {},
            musicReactor = state.musicReactor,
            summary = RunSummary.build("victory", state)
        })
        return
    end

    if state.musicReactor then
        state.musicReactor:update(dt)
    end

    SimpleGrid.update(dt, state.musicReactor)
    World.update(dt, state.musicReactor)
    flux.update(dt)
    FloatingTextSystem.update(dt)
    FirstEncounter.update(dt)
    require("src.gameplay.ColorEconomy").update(dt)
    VFXLibrary.update(dt)
    VFXLibrary.updateImpactBursts(dt)

    state.gameTime = state.gameTime + dt

    local centerX = state.player.x + state.player.width / 2
    local centerY = state.player.y + state.player.height / 2

    state.player:update(dt, state.enemies)
    -- Wrap dash collisions in a reward sweep: dash damage now routes through
    -- HealthSystem.takeDamage, so a dash-only kill must be picked up here for XP/drops.
    local dashAliveBefore = enemyFlow.captureAliveEnemies(state)
    state.player:checkDashCollisions(state.enemies)
    enemyFlow.rewardNewEnemyDeaths(state, dashAliveBefore, deps)
    state.player:autoFire(state.enemies, BossCoordinator.getActiveBoss())

    OnboardingSequence.update(dt, state.player, state)

    ShieldEffect.update(dt)
    if not OnboardingSequence.isActive() then
        SpawnController.update(dt, state.player.level, state.musicReactor, state.enemies)
    end
    state.enemyKillCount = SpawnController.enemyKillCount

    enemyFlow.updateEnemies(state, dt, centerX, centerY, deps)
    enemyFlow.updateEnemyProjectileCollisions(state, deps)

    local dotKillCallback = function(target)
        SpawnController.handleEnemyDeath(target, state.player, state.xpOrbs, state.powerups)
    end
    AttackSystem.updateDoTs(state.enemies, dt, dotKillCallback)
    VFXLibrary.updateGroundEffects(dt, state.enemies, state.player, dotKillCallback)

    ProjectileCollisionSystem.update(state.player, state.enemies, state.xpOrbs, state.powerups, state.explosions)
    enemyFlow.updateExplosions(state, dt, deps)
    enemyFlow.updateSupernovaEffects(state, dt, deps)

    PickupSystem.updateXPOrbs(dt, state.player, state.xpOrbs, centerX, centerY)
    PickupSystem.updatePowerups(dt, state.player, state.enemies, state.powerups, centerX, centerY)

    if state.player:canLevelUp() and not OnboardingSequence.isActive() then
        local StateManager = require("src.core.StateManager")
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

    -- Bosses recur every 100 kills (SpawnController); defeating one returns to
    -- normal play instead of ending the run. BossCoordinator clears the boss and
    -- runs its exit animation on death.
    BossCoordinator.update(dt, state.player, state.player.projectiles, state.bossProjectiles, state.musicReactor, state.enemies, state)
end

return PlayingUpdateLoop
