-- ProjectileCollisionSystem.lua
-- Handles player projectile collisions against enemies and projectile hit behavior.

local ProjectileCollisionSystem = {}

local AttackSystem = require("src.systems.AttackSystem")
local CollisionSystem = require("src.systems.CollisionSystem")
local SpawnController = require("src.systems.SpawnController")
local VFXLibrary = require("src.systems.VFXLibrary")

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

                -- Handle explosion if MAGENTA created one
                if explosion then
                    table.insert(explosions, explosion)
                    VFXLibrary.spawnArtifactEffect("SUPERNOVA", explosion.x, explosion.y)
                end

                -- GREEN: Bounce to nearest enemy
                if proj.canBounceToNearest then
                    shouldRemove = ProjectileCollisionSystem.handleBounce(proj, enemies)
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

function ProjectileCollisionSystem.handleBounce(proj, enemies)
    proj.currentBounces = (proj.currentBounces or 0) + 1

    if proj.currentBounces >= (proj.maxBounces or 1) then
        return true -- Remove projectile
    end

    -- Find nearest enemy that hasn't been hit yet
    local nearestEnemy = nil
    local nearestDist = math.huge

    for _, otherEnemy in ipairs(enemies) do
        if not proj.hitEnemies[otherEnemy] and not otherEnemy.dead and not otherEnemy.inactive then
            local dx = otherEnemy.x - proj.x
            local dy = otherEnemy.y - proj.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < nearestDist then
                nearestDist = dist
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
