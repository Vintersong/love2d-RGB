-- EnemyBehaviors.lua
-- Minimal regular enemy behavior catalog.
-- Boss behavior lives separately in BossBehaviors.lua.

local EnemyBehaviors = {}

local function moveToward(enemy, targetX, targetY, speed)
    local cx = enemy.x + enemy.width / 2
    local cy = enemy.y + enemy.height / 2
    local dx = targetX - cx
    local dy = targetY - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist <= 0 then return 0, 0 end
    return (dx / dist) * speed, (dy / dist) * speed
end

EnemyBehaviors.catalog = {
    {
        id = "chase_player",
        kind = "movement",
        validFor = "enemy",
        tags = {"default"},
        weight = 1,
        update = function(enemy, dt, context)
            local vx, vy = moveToward(enemy, context.playerX, context.playerY, enemy.speed * 1.5)
            enemy.vx, enemy.vy = vx, vy
            enemy.x = enemy.x + vx * dt
            enemy.y = enemy.y + vy * dt
        end,
    },
    {
        id = "passive",
        kind = "attack",
        validFor = "enemy",
        tags = {"default"},
        cooldown = 999,
        weight = 1,
        execute = function() end,
    },
    {
        id = "tank_scaling",
        kind = "modifier",
        validFor = "enemy",
        tags = {"bass", "heavy"},
        execute = function(enemy)
            enemy.hp = math.floor(enemy.hp * 1.25)
            enemy.maxHp = math.floor(enemy.maxHp * 1.25)
            enemy.damage = math.floor(enemy.damage * 1.15)
        end,
    },
    {
        id = "scout_scaling",
        kind = "modifier",
        validFor = "enemy",
        tags = {"treble", "scout"},
        execute = function(enemy)
            enemy.speed = enemy.speed * 1.2
            enemy.hp = math.max(1, math.floor(enemy.hp * 0.85))
            enemy.maxHp = enemy.hp
        end,
    },
    {
        id = "affinity_red",
        kind = "modifier",
        validFor = "enemy",
        tags = {"affinity", "red"},
        execute = function(enemy)
            enemy.affinity = "RED"
            enemy.projectileColor = {1, 0.3, 0.3}
            enemy.overlayColor = enemy.overlayColor or {0.9, 0.2, 0.2}
        end,
    },
    {
        id = "affinity_green",
        kind = "modifier",
        validFor = "enemy",
        tags = {"affinity", "green"},
        execute = function(enemy)
            enemy.affinity = "GREEN"
            enemy.projectileColor = {0.3, 1, 0.3}
            enemy.overlayColor = enemy.overlayColor or {0.2, 0.9, 0.2}
        end,
    },
    {
        id = "affinity_blue",
        kind = "modifier",
        validFor = "enemy",
        tags = {"affinity", "blue"},
        execute = function(enemy)
            enemy.affinity = "BLUE"
            enemy.projectileColor = {0.3, 0.4, 1}
            enemy.overlayColor = enemy.overlayColor or {0.2, 0.2, 0.9}
        end,
    },
    {
        id = "affinity_yellow",
        kind = "modifier",
        validFor = "enemy",
        tags = {"affinity", "yellow"},
        execute = function(enemy)
            enemy.affinity = "YELLOW"
            enemy.projectileColor = {1, 1, 0.3}
            enemy.overlayColor = enemy.overlayColor or {0.9, 0.9, 0.2}
        end,
    },
    {
        id = "affinity_magenta",
        kind = "modifier",
        validFor = "enemy",
        tags = {"affinity", "magenta"},
        execute = function(enemy)
            enemy.affinity = "MAGENTA"
            enemy.projectileColor = {1, 0.3, 1}
            enemy.overlayColor = enemy.overlayColor or {0.9, 0.2, 0.9}
        end,
    },
    {
        id = "affinity_cyan",
        kind = "modifier",
        validFor = "enemy",
        tags = {"affinity", "cyan"},
        execute = function(enemy)
            enemy.affinity = "CYAN"
            enemy.projectileColor = {0.3, 1, 1}
            enemy.overlayColor = enemy.overlayColor or {0.2, 0.9, 0.9}
        end,
    },
    {
        id = "prestige_rings",
        kind = "modifier",
        validFor = "enemy",
        tags = {"visual"},
        execute = function() end,
    },
}

local byId = {}
for _, behavior in ipairs(EnemyBehaviors.catalog) do
    byId[behavior.id] = behavior
end

function EnemyBehaviors.getAll()
    return EnemyBehaviors.catalog
end

function EnemyBehaviors.getById(id)
    return byId[id]
end

function EnemyBehaviors.listByKind(kind)
    local list = {}
    for _, behavior in ipairs(EnemyBehaviors.catalog) do
        if behavior.kind == kind then
            table.insert(list, behavior)
        end
    end
    return list
end

return EnemyBehaviors
