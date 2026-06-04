-- AttackSystem: Handles all combat interactions and damage dealing
local AttackSystem = {}
local HealthSystem = require("src.combat.HealthSystem")

-- Process projectile hitting an enemy/boss
-- Returns: explosion data (if MAGENTA effect), or nil
function AttackSystem.projectileHit(projectile, target, onKillCallback)
    if target.dead then return nil end
    
    -- Deal damage
    local died = HealthSystem.takeDamage(target, projectile.damage)
    
    -- Visual feedback: Impact VFX at hit location
    local VFXLibrary = require("src.effects.VFXLibrary")
    if projectile.color then
        VFXLibrary.spawnImpactBurst(
            target.x + target.width / 2,
            target.y + target.height / 2,
            projectile.color,
            5  -- particle count
        )
    end
    
    -- Handle tertiary effects and get explosion data if any
    local explosion = AttackSystem.applyEffects(projectile, target)
    
    -- Call callback if target died
    if died and onKillCallback then
        onKillCallback(target)
    end
    
    -- Return explosion data (if MAGENTA created one)
    return explosion
end

-- Process enemy touching player
function AttackSystem.enemyContactDamage(enemy, player, dt, context)
    if enemy.dead or player.dead then return false end
    
    -- Contact should behave like a discrete hit because Player:takeDamage
    -- already applies post-hit invulnerability frames.
    local damageAmount = enemy.damage or 10
    local died = player:takeDamage(damageAmount, enemy, context)
    
    return died
end

-- Apply special projectile effects (tertiary colors)
function AttackSystem.applyEffects(projectile, target)
    -- Root effect (YELLOW) - slow/stop enemy
    if projectile.canRoot then
        -- Only capture originalSpeed / apply the slow on the FIRST root; re-rooting an
        -- already-slowed enemy would otherwise save the slowed value as "original" and
        -- compound the slow, restoring a permanently reduced speed on expiry.
        if not target.rooted then
            target.originalSpeed = target.speed
            target.speed = target.speed * 0.3  -- 70% slow
        end
        target.rooted = true
        target.rootDuration = projectile.rootDuration or 2.0  -- refresh duration
    end
    
    -- Explode effect (MAGENTA) - AoE damage
    if projectile.canExplode then
        -- Store explosion data for later processing
        return {
            type = "explosion",
            x = target.x + target.width / 2,
            y = target.y + target.height / 2,
            radius = projectile.explodeRadius or 100,
            damage = projectile.explodeDamage or projectile.damage * 0.5,
            lifetime = 0.5,  -- Explosion visual lasts 0.5 seconds
            processed = false
        }
    end
    
    -- DoT effect (CYAN) - damage over time
    if projectile.canDot then
        if not target.dotStacks then
            target.dotStacks = {}
        end
        
        table.insert(target.dotStacks, {
            duration = projectile.dotDuration or 3.0,
            damage = projectile.dotDamage or projectile.damage * 0.2,
            tickRate = 0.5  -- Damage every 0.5 seconds
        })
    end
    
    return nil
end

-- Update DoT effects on all entities
function AttackSystem.updateDoTs(entities, dt, onKillCallback)
    for _, entity in ipairs(entities) do
        if entity.dotStacks and #entity.dotStacks > 0 then
            for i = #entity.dotStacks, 1, -1 do
                local dot = entity.dotStacks[i]
                
                -- Tick damage
                dot.tickRate = dot.tickRate - dt
                if dot.tickRate <= 0 then
                    local died = HealthSystem.takeDamage(entity, dot.damage)
                    if died and onKillCallback then
                        onKillCallback(entity)
                        break
                    end
                    dot.tickRate = 0.5  -- Reset tick
                end
                
                -- Reduce duration
                dot.duration = dot.duration - dt
                if dot.duration <= 0 then
                    table.remove(entity.dotStacks, i)
                end
            end
        end
        
        -- Update root effect
        if entity.rooted then
            entity.rootDuration = entity.rootDuration - dt
            if entity.rootDuration <= 0 then
                entity.rooted = false
                entity.speed = entity.originalSpeed or entity.speed
            end
        end
    end
end

-- Process AoE explosion
function AttackSystem.processExplosion(explosion, targets, onKillCallback)
    local killedTargets = {}
    
    for _, target in ipairs(targets) do
        if not target.dead then
            local dx = (target.x + target.width / 2) - explosion.x
            local dy = (target.y + target.height / 2) - explosion.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance <= explosion.radius then
                local died = HealthSystem.takeDamage(target, explosion.damage)
                
                if died then
                    table.insert(killedTargets, target)
                    if onKillCallback then
                        onKillCallback(target)
                    end
                end
            end
        end
    end
    
    return killedTargets
end

return AttackSystem
