-- EnemyAbilities: Composable abilities for procedural enemy generation
local EnemyAbilities = {}

-- Color Affinities (affect projectile color and resistance)
EnemyAbilities.Affinities = {
    RED = {
        name = "Red Affinity",
        color = {0.9, 0.2, 0.2},
        resistance = 0.5,  -- Takes 50% damage from RED projectiles
        weakness = "BLUE",  -- Takes 150% damage from BLUE
        projectileColor = {1, 0.3, 0.3},
    },
    GREEN = {
        name = "Green Affinity",
        color = {0.2, 0.9, 0.2},
        resistance = 0.5,
        weakness = "RED",
        projectileColor = {0.3, 1, 0.3},
    },
    BLUE = {
        name = "Blue Affinity",
        color = {0.2, 0.2, 0.9},
        resistance = 0.5,
        weakness = "GREEN",
        projectileColor = {0.3, 0.3, 1},
    },
    YELLOW = {
        name = "Yellow Affinity",
        color = {0.9, 0.9, 0.2},
        resistance = 0.5,
        weakness = "MAGENTA",
        projectileColor = {1, 1, 0.3},
    },
    MAGENTA = {
        name = "Magenta Affinity",
        color = {0.9, 0.2, 0.9},
        resistance = 0.5,
        weakness = "CYAN",
        projectileColor = {1, 0.3, 1},
    },
    CYAN = {
        name = "Cyan Affinity",
        color = {0.2, 0.9, 0.9},
        resistance = 0.5,
        weakness = "YELLOW",
        projectileColor = {0.3, 1, 1},
    },
    NEUTRAL = {
        name = "Neutral",
        color = {0.7, 0.7, 0.7},
        resistance = 1.0,
        weakness = nil,
        projectileColor = {0.8, 0.8, 0.8},
    }
}

-- Attack Patterns (how enemies shoot)
EnemyAbilities.AttackPatterns = {
    STRAIGHT = {
        name = "Sniper Shot",
        cooldown = 6.0,  -- Increased from 3.5s to 6s
        projectileCount = 1,
        spread = 0,
        projectileSpeed = 200,
        damage = 12,
        canShoot = true,  -- Only this pattern can shoot
        execute = function(enemy, playerX, playerY)
            local dx = playerX - enemy.x
            local dy = playerY - enemy.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                return {{
                    vx = (dx / dist) * 200,
                    vy = (dy / dist) * 200
                }}
            end
            return {}
        end
    },
    MELEE = {
        name = "Melee Rush",
        cooldown = 999,  -- Never shoots
        projectileCount = 0,
        spread = 0,
        projectileSpeed = 0,
        damage = 0,
        canShoot = false,  -- Disabled shooting
        execute = function(enemy, playerX, playerY)
            return {}  -- No projectiles
        end
    },
    PASSIVE = {
        name = "Passive Drift",
        cooldown = 999,  -- Never shoots
        projectileCount = 0,
        spread = 0,
        projectileSpeed = 0,
        damage = 0,
        canShoot = false,  -- Disabled shooting
        execute = function(enemy, playerX, playerY)
            return {}  -- No projectiles
        end
    },
    CHARGER = {
        name = "Charging Ram",
        cooldown = 999,  -- Never shoots
        projectileCount = 0,
        spread = 0,
        projectileSpeed = 0,
        damage = 0,
        canShoot = false,  -- Disabled shooting
        execute = function(enemy, playerX, playerY)
            return {}  -- No projectiles
        end
    }
}

-- Movement Behaviors
EnemyAbilities.MovementBehaviors = {
    CHASE = {
        name = "Aggressive Chase",
        speedMultiplier = 1.5,
        update = function(enemy, dt, playerX, playerY)
            local dx = playerX - enemy.x
            local dy = playerY - enemy.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                enemy.vx = (dx / dist) * enemy.speed * 1.5
                enemy.vy = (dy / dist) * enemy.speed * 1.5
            end
        end
    },
    STRAFE = {
        name = "Strafe",
        speedMultiplier = 1.0,
        update = function(enemy, dt, playerX, playerY)
            local dx = playerX - enemy.x
            local dy = playerY - enemy.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                -- Move perpendicular to player
                enemy.strafeTime = (enemy.strafeTime or 0) + dt
                local perpAngle = math.atan(dy, dx) + math.pi / 2
                if enemy.strafeTime > 3 then
                    perpAngle = perpAngle + math.pi
                    if enemy.strafeTime > 6 then
                        enemy.strafeTime = 0
                    end
                end
                enemy.vx = math.cos(perpAngle) * enemy.speed
                enemy.vy = math.sin(perpAngle) * enemy.speed
            end
        end
    },
    FLOAT = {
        name = "Floating",
        speedMultiplier = 0.5,
        update = function(enemy, dt, playerX, playerY)
            enemy.floatTime = (enemy.floatTime or 0) + dt
            local waveX = math.sin(enemy.floatTime * 2) * 50
            local waveY = math.cos(enemy.floatTime * 1.5) * 30
            enemy.vx = waveX * dt * 10
            enemy.vy = waveY * dt * 10 + enemy.speed * 0.3  -- Slowly descend
        end
    },
    TELEPORT = {
        name = "Teleporter",
        speedMultiplier = 0.8,
        teleportCooldown = 5.0,
        update = function(enemy, dt, playerX, playerY)
            enemy.teleportTimer = (enemy.teleportTimer or 0) + dt
            
            if enemy.teleportTimer >= 5.0 then
                -- Teleport to random position near player
                local angle = math.random() * math.pi * 2
                local distance = 150 + math.random() * 100
                enemy.x = playerX + math.cos(angle) * distance
                enemy.y = playerY + math.sin(angle) * distance
                enemy.teleportTimer = 0
                
                -- Visual flash effect
                enemy.teleportFlash = 0.3
            end
            
            -- Slow drift toward player
            local dx = playerX - enemy.x
            local dy = playerY - enemy.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                enemy.vx = (dx / dist) * enemy.speed * 0.8
                enemy.vy = (dy / dist) * enemy.speed * 0.8
            end
        end
    }
}

-- Generate random enemy configuration
function EnemyAbilities.generateRandom(level)
    local config = {}
    
    -- Random affinity (more variety at higher levels)
    local affinityKeys = {"RED", "GREEN", "BLUE"}
    if level >= 10 then
        table.insert(affinityKeys, "YELLOW")
        table.insert(affinityKeys, "MAGENTA")
        table.insert(affinityKeys, "CYAN")
    end
    config.affinity = affinityKeys[math.random(#affinityKeys)]
    
    -- Random attack pattern (only 10% enemies are shooters, reduced from 20%)
    local patternKeys
    if math.random() < 0.1 then
        -- Shooter enemy
        patternKeys = {"STRAIGHT"}
    else
        -- Non-shooter enemies
        patternKeys = {"MELEE", "PASSIVE", "CHARGER"}
    end
    config.attackPattern = patternKeys[math.random(#patternKeys)]
    
    -- Random movement behavior
    local behaviorKeys = {"CHASE", "STRAFE", "FLOAT"}
    if level >= 20 then
        table.insert(behaviorKeys, "TELEPORT")
    end
    config.movementBehavior = behaviorKeys[math.random(#behaviorKeys)]
    
    -- Scale stats with level
    config.hpMultiplier = 1.0 + (level * 0.1)
    config.damageMultiplier = 1.0 + (level * 0.05)
    config.speedMultiplier = 1.0 + (level * 0.02)
    
    return config
end

return EnemyAbilities
