-- BossCoordinator.lua
-- Wraps active boss orchestration and boss projectile updates.

local BossCoordinator = {}

local BossSystem = require("src.boss.BossSystem")
local CollisionSystem = require("src.combat.CollisionSystem")
local GameConfig = require("src.core.GameConfig")
local Config = require("src.Config")
local EconomySystem = require("src.economy.EconomySystem")
local RunSummary = require("src.core.RunSummary")
local SpawnController = require("src.spawning.SpawnController")

BossCoordinator.bossProjectiles = {}

local function cleanupBossRefs(boss)
    if boss then
        boss._playerRef = nil
        boss._bossProjectiles = nil
    end
end

function BossCoordinator.getActiveBoss()
    return BossSystem.activeBoss
end

function BossCoordinator.update(dt, player, playerProjectiles, bossProjectiles, musicReactor, enemies, state)
    BossCoordinator.bossProjectiles = bossProjectiles or BossCoordinator.bossProjectiles

    local activeBoss = BossSystem.activeBoss
    if activeBoss then
        -- Provide references for archetype behavior AI during the boss update only.
        activeBoss._playerRef = player
        activeBoss._bossProjectiles = BossCoordinator.bossProjectiles
        local newProjectiles = activeBoss:update(
            dt,
            player.x + player.width / 2,
            player.y + player.height / 2
        )
        cleanupBossRefs(activeBoss)

        -- Add boss projectiles if any were fired
        if newProjectiles then
            for _, proj in ipairs(newProjectiles) do
                table.insert(BossCoordinator.bossProjectiles, proj)
            end
        end

        -- Check player projectile collisions with boss
        for i = #playerProjectiles, 1, -1 do
            local proj = playerProjectiles[i]
            activeBoss = BossSystem.activeBoss
            if activeBoss and not activeBoss.invulnerable then
                -- Use CollisionSystem for circle-to-circle collision
                if CollisionSystem.checkProjectileBossCollision(proj, activeBoss) then
                    activeBoss:takeDamage(proj.damage or 10, proj.colorName)
                    table.remove(playerProjectiles, i)
                end
            end
        end

        -- Ring-boss (opt-in) laser beams: an ACTIVE beam overlapping the player deals damage,
        -- mirroring the boss-projectile path. Beams live on the boss; this is a no-op unless
        -- ring state was attached (Config.boss.ringBoss.enabled, default off).
        activeBoss = BossSystem.activeBoss
        if activeBoss and activeBoss._ringLasers and #activeBoss._ringLasers > 0 then
            local LaserBeam = require("src.combat.LaserBeam")
            local px = player.x + (player.width or 0) / 2
            local py = player.y + (player.height or 0) / 2
            for _, beam in ipairs(activeBoss._ringLasers) do
                if LaserBeam.isActive(beam) and LaserBeam.hitsPoint(beam.seg, px, py, beam.halfWidth) then
                    local died = player:takeDamage(beam.damage or 0, {x = px, y = py}, {
                        enemies = enemies,
                        onEnemyKilled = function(target)
                            if state then
                                SpawnController.handleEnemyDeath(target, player, state.xpOrbs or {}, state.powerups or {})
                            end
                        end,
                    })
                    if died then
                        local StateManager = require("src.core.StateManager")
                        StateManager.switch("GameOver", {
                            player = player,
                            enemies = enemies,
                            xpOrbs = state and state.xpOrbs or {},
                            powerups = state and state.powerups or {},
                            explosions = state and state.explosions or {},
                            bossProjectiles = state and state.bossProjectiles or {},
                            supernovaEffects = state and state.supernovaEffects or {},
                            gameTime = state and state.gameTime or 0,
                            enemyKillCount = state and state.enemyKillCount or 0,
                            musicReactor = musicReactor,
                            summary = RunSummary.build("defeat", state or {
                                player = player,
                                enemies = enemies,
                                musicReactor = musicReactor,
                            })
                        })
                        return
                    end
                    break -- one beam hit per frame is enough; player now has i-frames
                end
            end
        end

        -- Check if boss is defeated
        activeBoss = BossSystem.activeBoss
        if activeBoss and not activeBoss.alive then
            cleanupBossRefs(activeBoss)
            BossSystem.activeBoss = nil
            local earned = EconomySystem.onBossClear()
            local FloatingTextSystem = require("src.effects.FloatingTextSystem")
            local screenWidth = GameConfig.getScreenSize()
            FloatingTextSystem.add(
                string.format("+%d CHROMA", earned),
                activeBoss.x or (screenWidth / 2),
                activeBoss.y or 300,
                "SYNERGY"
            )
        end
    else
        cleanupBossRefs(activeBoss)
    end

    -- Update boss projectiles
    local screenWidth, screenHeight = GameConfig.getScreenSize()
    screenWidth = screenWidth or Config.screen.width
    screenHeight = screenHeight or Config.screen.height
    for i = #BossCoordinator.bossProjectiles, 1, -1 do
        local proj = BossCoordinator.bossProjectiles[i]
        proj:update(dt)

        -- Remove if dead or off screen
        if proj.dead or proj.y > screenHeight or proj.y < -50 or proj.x < -50 or proj.x > (screenWidth + 50) then
            table.remove(BossCoordinator.bossProjectiles, i)
        else
            -- Check collision with player using CollisionSystem
            if CollisionSystem.checkBossProjectilePlayerCollision(proj, player) then
                local died = player:takeDamage(proj.damage or 0, proj, {
                    enemies = enemies,
                    onEnemyKilled = function(target)
                        if state then
                            SpawnController.handleEnemyDeath(target, player, state.xpOrbs or {}, state.powerups or {})
                        end
                    end,
                })
                if died then
                    local StateManager = require("src.core.StateManager")
                    StateManager.switch("GameOver", {
                        player = player,
                        enemies = enemies,
                        xpOrbs = state and state.xpOrbs or {},
                        powerups = state and state.powerups or {},
                        explosions = state and state.explosions or {},
                        bossProjectiles = state and state.bossProjectiles or {},
                        supernovaEffects = state and state.supernovaEffects or {},
                        gameTime = state and state.gameTime or 0,
                        enemyKillCount = state and state.enemyKillCount or 0,
                        musicReactor = musicReactor,
                        summary = RunSummary.build("defeat", state or {
                            player = player,
                            enemies = enemies,
                            musicReactor = musicReactor,
                        })
                    })
                    return
                end
                table.remove(BossCoordinator.bossProjectiles, i)
            end
        end
    end
end

return BossCoordinator
