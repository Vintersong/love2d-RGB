-- ProjectileCollisionSystem.lua
-- Handles player projectile collisions against enemies and projectile hit behavior.

local ProjectileCollisionSystem = {}

local AttackSystem = require("src.combat.AttackSystem")
local CollisionSystem = require("src.combat.CollisionSystem")
local SpawnController = require("src.spawning.SpawnController")
local VFXLibrary = require("src.effects.VFXLibrary")

function ProjectileCollisionSystem.update(player, enemies, xpOrbs, powerups, explosions)
    for i = #player.projectiles, 1, -1 do
        local proj = player.projectiles[i]

        -- Initialize pierce tracking if not exists
        if not proj.hitEnemies then
            proj.hitEnemies = {}
        end

        local shouldRemove = false

        -- Callback for spawning XP orbs and powerups when enemy dies
        local onKillCallback = function(target)
            -- Delegate to Controller
            SpawnController.handleEnemyDeath(target, player, xpOrbs, powerups)
        end

        -- Use CollisionSystem for spatial query (much faster than checking all enemies)
        local nearbyEnemies = CollisionSystem.checkProjectileEnemyCollisions(proj, enemies)

        for _, enemy in ipairs(nearbyEnemies) do
            -- Check if enemy hasn't been hit by this projectile already
            if not proj.hitEnemies[enemy] and not enemy.inactive then
                -- Use AttackSystem to handle damage and effects
                local explosion = AttackSystem.projectileHit(proj, enemy, onKillCallback)

                -- Mark enemy as hit
                proj.hitEnemies[enemy] = true

                if proj.onAccumulateHit then
                    proj:onAccumulateHit(enemy)
                end
                if proj.onSynchronizedHit then
                    proj:onSynchronizedHit(enemy)
                end

                -- Handle explosion if MAGENTA created one
                if explosion then
                    table.insert(explosions, explosion)
                    VFXLibrary.spawnArtifactEffect("SUPERNOVA", explosion.x, explosion.y)
                end

                if proj.onImpactExplode then
                    for _, spawned in ipairs(proj:onImpactExplode(proj.x, proj.y) or {}) do
                        table.insert(player.projectiles, spawned)
                    end
                    VFXLibrary.spawnArtifactEffect("DIFFRACTION", proj.x, proj.y)
                    shouldRemove = true
                elseif proj.onCompoundExplode then
                    for _, spawned in ipairs(proj:onCompoundExplode(proj.x, proj.y) or {}) do
                        table.insert(player.projectiles, spawned)
                    end
                    VFXLibrary.spawnArtifactEffect("DIFFRACTION", proj.x, proj.y)
                    shouldRemove = true
                end

                if proj.freezing then
                    enemy.frozen = true
                    enemy.frozenTimer = math.max(enemy.frozenTimer or 0, 0.75)
                    enemy.originalSpeed = enemy.originalSpeed or enemy.speed
                    enemy.speed = 0
                end

                -- GREEN: Bounce to nearest enemy
                if shouldRemove then
                    break
                elseif proj.canBounceToNearest then
                    shouldRemove = ProjectileCollisionSystem.handleBounce(proj, enemies, player)
                -- BLUE: Pierce through enemies
                elseif proj.canPierce then
                    shouldRemove = ProjectileCollisionSystem.handlePierce(proj)
                else
                    -- Normal projectile: dies on hit
                    shouldRemove = true
                end

                if shouldRemove then
                    break
                end
            end
        end

        if shouldRemove then
            table.remove(player.projectiles, i)
        end
    end
end

function ProjectileCollisionSystem.handleBounce(proj, enemies, player)
    proj.currentBounces = (proj.currentBounces or 0) + 1

    if proj.currentBounces >= (proj.maxBounces or 1) then
        return true -- Remove projectile
    end

    -- Find nearest enemy to the player that hasn't been hit yet using spatial query
    local nearestEnemy = nil
    local nearestDistSq = math.huge
    local searchRadius = 1000 -- large radius to cover the screen

    if CollisionSystem.world and player then
        local items = CollisionSystem.world:queryRect(
            player.x - searchRadius,
            player.y - searchRadius,
            searchRadius * 2,
            searchRadius * 2,
            function(item)
                return item.type == "enemy" and not item.dead and not item.inactive and not proj.hitEnemies[item]
            end
        )

        for _, otherEnemy in ipairs(items) do
            local dx = otherEnemy.x - player.x
            local dy = otherEnemy.y - player.y
            local distSq = dx * dx + dy * dy

            if distSq < nearestDistSq then
                nearestDistSq = distSq
                nearestEnemy = otherEnemy
            end
        end
    end

    if nearestEnemy then
        -- Redirect projectile toward nearest enemy
        local dx = (nearestEnemy.x + nearestEnemy.width/2) - proj.x
        local dy = (nearestEnemy.y + nearestEnemy.height/2) - proj.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist > 0 then
            proj.vx = (dx / dist) * proj.speed
            proj.vy = (dy / dist) * proj.speed
        end
        return false -- Keep projectile
    end

    return true -- No more enemies, remove projectile
end

function ProjectileCollisionSystem.handlePierce(proj)
    proj.pierceCount = (proj.pierceCount or 0) + 1

    if proj.pierceCount >= (proj.maxPierces or 1) then
        return true -- Max pierces reached, remove
    end

    return false -- Continue piercing
end

return ProjectileCollisionSystem
