-- BossCoordinator.lua
-- Wraps active boss orchestration and boss projectile updates.

local BossCoordinator = {}

local BossSystem = require("src.systems.BossSystem")
local CollisionSystem = require("src.systems.CollisionSystem")

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

function BossCoordinator.update(dt, player, playerProjectiles, bossProjectiles, musicReactor, enemies)
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
                    activeBoss:takeDamage(proj.damage or 10)
                    table.remove(playerProjectiles, i)
                end
            end
        end

        -- Check if boss is defeated
        activeBoss = BossSystem.activeBoss
        if activeBoss and not activeBoss.alive then
            cleanupBossRefs(activeBoss)
            BossSystem.activeBoss = nil
        end
    else
        cleanupBossRefs(activeBoss)
    end

    -- Update boss projectiles
    for i = #BossCoordinator.bossProjectiles, 1, -1 do
        local proj = BossCoordinator.bossProjectiles[i]
        proj:update(dt)

        -- Remove if dead or off screen
        if proj.dead or proj.y > 1080 or proj.y < -50 or proj.x < -50 or proj.x > 1970 then
            table.remove(BossCoordinator.bossProjectiles, i)
        else
            -- Check collision with player using CollisionSystem
            if CollisionSystem.checkBossProjectilePlayerCollision(proj, player) then
                if not player.invulnerable then
                    player.hp = player.hp - proj.damage
                    player.invulnerable = true
                    player.invulnerableTime = 0.5
                    player.damageFlashTime = 0.1

                    if player.hp <= 0 then
                        player.hp = 0
                        local StateManager = require("src.systems.StateManager")
                        StateManager.switch("GameOver", {
                            player = player,
                            enemies = enemies,
                            musicReactor = musicReactor
                        })
                        return
                    end
                end
                table.remove(BossCoordinator.bossProjectiles, i)
            end
        end
    end
end

return BossCoordinator
