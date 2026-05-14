local PlayingEnemyFlow = {}

local function captureAliveEnemies(state)
    local alive = {}
    for _, enemy in ipairs(state.enemies) do
        if not enemy.dead then
            alive[enemy] = true
        end
    end
    return alive
end

function PlayingEnemyFlow.rewardNewEnemyDeaths(state, aliveBefore, deps)
    local SpawnController = deps.SpawnController
    for _, enemy in ipairs(state.enemies) do
        if aliveBefore[enemy] and enemy.dead and not enemy._deathRewarded then
            SpawnController.handleEnemyDeath(enemy, state.player, state.xpOrbs, state.powerups)
        end
    end
end

function PlayingEnemyFlow.activateSupernova(state, deps)
    local VFXLibrary = deps.VFXLibrary
    local FloatingTextSystem = deps.FloatingTextSystem

    local aliveBefore = captureAliveEnemies(state)
    local success, effectData, color = state.player:useActiveAbility(state.enemies)
    if not success then
        return false
    end

    PlayingEnemyFlow.rewardNewEnemyDeaths(state, aliveBefore, deps)

    local centerX = state.player.x + state.player.width / 2
    local centerY = state.player.y + state.player.height / 2
    VFXLibrary.spawnArtifactEffect("SUPERNOVA", centerX, centerY)
    FloatingTextSystem.add((color or "RED") .. " SUPERNOVA", centerX, centerY - 80, "SYNERGY")

    if effectData and effectData.field then
        table.insert(state.supernovaEffects, {
            type = effectData.type,
            field = effectData.field,
            color = effectData.color or {1, 0.3, 0.2},
            radius = effectData.radius or 120,
        })
    end

    return true
end

function PlayingEnemyFlow.updateSupernovaEffects(state, dt, deps)
    for i = #state.supernovaEffects, 1, -1 do
        local effect = state.supernovaEffects[i]
        if effect.field and effect.field.update then
            local aliveBefore = captureAliveEnemies(state)
            local stillActive = effect.field:update(dt, state.player, state.enemies)
            PlayingEnemyFlow.rewardNewEnemyDeaths(state, aliveBefore, deps)

            if not stillActive then
                table.remove(state.supernovaEffects, i)
            end
        else
            table.remove(state.supernovaEffects, i)
        end
    end
end

function PlayingEnemyFlow.updateEnemies(state, dt, centerX, centerY, deps)
    local CollisionSystem = deps.CollisionSystem
    local SpawnController = deps.SpawnController
    local AttackSystem = deps.AttackSystem

    CollisionSystem.update(state.player, state.player.x, state.player.y)

    for i = #state.enemies, 1, -1 do
        local enemy = state.enemies[i]
        enemy:update(dt, centerX, centerY, {
            player = state.player,
            musicReactor = state.musicReactor,
            enemyCount = #state.enemies,
            gameTime = state.gameTime,
        })

        if CollisionSystem.world:hasItem(enemy) then
            CollisionSystem.update(enemy, enemy.x, enemy.y)
        end

        if not enemy.dead and not enemy.inactive then
            local HaloArtifact = require("src.artifacts.HaloArtifact")
            HaloArtifact.processEffects(enemy, state.player, function(killedEnemy)
                SpawnController.handleEnemyDeath(killedEnemy, state.player, state.xpOrbs, state.powerups)
            end)
        end

        if enemy.dead then
            CollisionSystem.remove(enemy)
            table.remove(state.enemies, i)
            local EnemySpawner = require("src.systems.EnemySpawner")
            EnemySpawner.returnToPool(enemy)
        end
    end

    local collidingEnemies = CollisionSystem.checkPlayerEnemyCollisions(state.player)
    for _, enemy in ipairs(collidingEnemies) do
        local died = AttackSystem.enemyContactDamage(enemy, state.player, dt)
        if died then
            local StateManager = require("src.systems.StateManager")
            StateManager.switch("GameOver", {
                player = state.player,
                enemies = state.enemies,
                musicReactor = state.musicReactor
            })
            return
        end
    end
end

function PlayingEnemyFlow.updateEnemyProjectileCollisions(state, deps)
    local CollisionSystem = deps.CollisionSystem
    local HealthSystem = deps.HealthSystem

    for _, enemy in ipairs(state.enemies) do
        if not enemy.dead and enemy.projectiles then
            for i = #enemy.projectiles, 1, -1 do
                local proj = enemy.projectiles[i]
                if CollisionSystem.checkEnemyProjectilePlayerCollision(proj, state.player) then
                    local died = HealthSystem.takeDamage(state.player, proj.damage)
                    table.remove(enemy.projectiles, i)
                    if died then
                        local StateManager = require("src.systems.StateManager")
                        StateManager.switch("GameOver", {
                            player = state.player,
                            enemies = state.enemies,
                            musicReactor = state.musicReactor
                        })
                        return
                    end
                end
            end
        end
    end
end

function PlayingEnemyFlow.updateExplosions(state, dt, deps)
    local SpawnController = deps.SpawnController
    local AttackSystem = deps.AttackSystem

    for i = #state.explosions, 1, -1 do
        local explosion = state.explosions[i]
        explosion.lifetime = explosion.lifetime - dt

        if not explosion.processed then
            local explosionKillCallback = function(target)
                SpawnController.handleEnemyDeath(target, state.player, state.xpOrbs, state.powerups)
            end
            AttackSystem.processExplosion(explosion, state.enemies, explosionKillCallback)
            explosion.processed = true
        end

        if explosion.lifetime <= 0 then
            table.remove(state.explosions, i)
        end
    end
end

function PlayingEnemyFlow.captureAliveEnemies(state)
    return captureAliveEnemies(state)
end

return PlayingEnemyFlow
