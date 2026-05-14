-- EnemyAbilities: simple shared data for procedural regular enemies.
local EnemyAbilities = {}

EnemyAbilities.Affinities = {
    RED = {
        name = "Red Affinity",
        color = {0.9, 0.2, 0.2},
        resistance = 0.5,
        weakness = "BLUE",
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

EnemyAbilities.AttackPatterns = {
    PASSIVE = {
        name = "Contact Only",
        cooldown = 999,
        projectileCount = 0,
        spread = 0,
        projectileSpeed = 0,
        damage = 0,
        canShoot = false,
        execute = function()
            return {}
        end
    }
}

EnemyAbilities.MovementBehaviors = {
    CHASE = {
        name = "Track Player",
        speedMultiplier = 1.5,
        update = function(enemy, dt, playerX, playerY)
            local dx = playerX - (enemy.x + enemy.width / 2)
            local dy = playerY - (enemy.y + enemy.height / 2)
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                enemy.vx = (dx / dist) * enemy.speed
                enemy.vy = (dy / dist) * enemy.speed
            end
        end
    }
}

function EnemyAbilities.generateRandom(level)
    local config = {}
    local affinityKeys = {"RED", "GREEN", "BLUE"}
    if level >= 10 then
        table.insert(affinityKeys, "YELLOW")
        table.insert(affinityKeys, "MAGENTA")
        table.insert(affinityKeys, "CYAN")
    end

    config.affinity = affinityKeys[math.random(#affinityKeys)]
    config.attackPattern = "PASSIVE"
    config.movementBehavior = "CHASE"
    config.hpMultiplier = 1.0 + (level * 0.1)
    config.damageMultiplier = 1.0 + (level * 0.05)
    config.speedMultiplier = 1.0 + (level * 0.02)

    return config
end

return EnemyAbilities
