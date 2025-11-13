-- HealthSystem: Manages health for all entities (player, enemies, boss)
local HealthSystem = {}

-- Track all entities with health
HealthSystem.entities = {}

function HealthSystem.register(entity, maxHp, onDeath)
    entity.hp = maxHp
    entity.maxHp = maxHp
    entity.dead = false
    entity.onDeath = onDeath  -- Optional callback when entity dies
    
    table.insert(HealthSystem.entities, entity)
    return entity
end

function HealthSystem.unregister(entity)
    for i = #HealthSystem.entities, 1, -1 do
        if HealthSystem.entities[i] == entity then
            table.remove(HealthSystem.entities, i)
            break
        end
    end
end

function HealthSystem.takeDamage(entity, amount)
    if entity.dead or entity.invulnerable then
        return false
    end
    
    entity.hp = entity.hp - amount
    
    if entity.hp <= 0 then
        entity.hp = 0
        entity.dead = true
        
        -- Call death callback if exists
        if entity.onDeath then
            entity.onDeath(entity)
        end
        
        return true  -- Entity died
    end
    
    return false  -- Entity survived
end

function HealthSystem.heal(entity, amount)
    if entity.dead then return end
    
    entity.hp = math.min(entity.hp + amount, entity.maxHp)
end

function HealthSystem.getHealthPercent(entity)
    if not entity.maxHp or entity.maxHp == 0 then return 0 end
    return entity.hp / entity.maxHp
end

function HealthSystem.isAlive(entity)
    return not entity.dead and entity.hp > 0
end

function HealthSystem.reset()
    HealthSystem.entities = {}
end

return HealthSystem
