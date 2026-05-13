-- EnemyBehaviors.lua
-- Reusable behavior catalog for regular enemies.

local EnemyBehaviors = {}
local MathUtils = require("src.systems.MathUtils")

local function moveToward(enemy, targetX, targetY, speed)
    local cx = enemy.x + enemy.width / 2
    local cy = enemy.y + enemy.height / 2
    local dx = targetX - cx
    local dy = targetY - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist <= 0 then return 0, 0 end
    return (dx / dist) * speed, (dy / dist) * speed
end

local function enemyCenter(enemy)
    return enemy.x + enemy.width / 2, enemy.y + enemy.height / 2
end

local function addProjectile(enemy, vx, vy, damage, color, radius)
    enemy.projectiles = enemy.projectiles or {}
    local x, y = enemyCenter(enemy)
    table.insert(enemy.projectiles, {
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        damage = damage or enemy.damage or 10,
        color = color or enemy.projectileColor or {1, 0.4, 0.4},
        radius = radius or 5,
        lifetime = 5.0,
        owner = enemy,
    })
end

EnemyBehaviors.catalog = {
    {
        id = "descend_straight",
        kind = "movement",
        validFor = "enemy",
        tags = {"lowLevel", "lowEnergy"},
        weight = function(enemy, context)
            return 2.0 + math.max(0, 0.5 - context.energy) + (context.playerLevel < 8 and 1 or 0)
        end,
        update = function(enemy, dt)
            enemy.vx = 0
            enemy.vy = enemy.speed
            enemy.y = enemy.y + enemy.vy * dt
        end,
    },
    {
        id = "formation_sway",
        kind = "movement",
        validFor = "enemy",
        tags = {"formation"},
        canRun = function(enemy)
            return enemy.formationData ~= nil
        end,
        weight = function(enemy, context)
            return context.formationName and 5 or 1
        end,
        update = function(enemy, dt, context)
            local formation = enemy.formationData or {}
            local swaySpeed = 0.5 + context.mids * 0.8
            local swayAmount = 12 + context.energy * 24
            local targetX = (formation.centerX or enemy.x) + (formation.offsetX or 0) + math.sin(enemy.age * swaySpeed) * swayAmount
            enemy.x = enemy.x + (targetX - enemy.x) * 2 * dt
            enemy.y = enemy.y + enemy.speed * 0.15 * dt
            enemy.vx = 0
            enemy.vy = enemy.speed * 0.15
        end,
    },
    {
        id = "chase_player",
        kind = "movement",
        validFor = "enemy",
        tags = {"mids", "closeRange"},
        weight = function(enemy, context)
            return 1.0 + context.mids * 3 + math.min(context.playerLevel / 20, 2)
        end,
        update = function(enemy, dt, context)
            local vx, vy = moveToward(enemy, context.playerX, context.playerY, enemy.speed * 1.35)
            enemy.vx, enemy.vy = vx, vy
            enemy.x = enemy.x + vx * dt
            enemy.y = enemy.y + vy * dt
        end,
    },
    {
        id = "strafe_player",
        kind = "movement",
        validFor = "enemy",
        tags = {"treble", "highMids"},
        weight = function(enemy, context)
            return 0.8 + context.treble * 4
        end,
        update = function(enemy, dt, context)
            enemy.strafeTime = (enemy.strafeTime or 0) + dt
            local cx, cy = enemyCenter(enemy)
            local angle = MathUtils.atan2(context.playerY - cy, context.playerX - cx) + math.pi / 2
            if enemy.strafeTime > 3 then
                angle = angle + math.pi
                if enemy.strafeTime > 6 then
                    enemy.strafeTime = 0
                end
            end
            local towardX, towardY = moveToward(enemy, context.playerX, context.playerY, enemy.speed * 0.35)
            enemy.vx = math.cos(angle) * enemy.speed + towardX
            enemy.vy = math.sin(angle) * enemy.speed + towardY
            enemy.x = enemy.x + enemy.vx * dt
            enemy.y = enemy.y + enemy.vy * dt
        end,
    },
    {
        id = "float_wave",
        kind = "movement",
        validFor = "enemy",
        tags = {"balanced"},
        weight = function(enemy, context)
            local range = math.max(context.bass, context.mids, context.treble) - math.min(context.bass, context.mids, context.treble)
            return range < 0.3 and 3 or 0.8
        end,
        update = function(enemy, dt, context)
            enemy.floatTime = (enemy.floatTime or 0) + dt
            enemy.vx = math.sin(enemy.floatTime * (1.5 + context.energy)) * enemy.speed * 0.65
            enemy.vy = enemy.speed * (0.35 + context.bass * 0.25)
            enemy.x = enemy.x + enemy.vx * dt
            enemy.y = enemy.y + enemy.vy * dt
        end,
    },
    {
        id = "dash_probe",
        kind = "movement",
        validFor = "enemy",
        tags = {"highEnergy", "treble"},
        cooldown = 2.5,
        canRun = function(enemy, context)
            return context.playerLevel >= 10 or context.energy > 0.75
        end,
        weight = function(enemy, context)
            return context.energy > 0.7 and 2.5 or 0.3
        end,
        update = function(enemy, dt, context)
            enemy.dashProbeTimer = (enemy.dashProbeTimer or 0) - dt
            if enemy.dashProbeTimer <= 0 then
                enemy.dashProbeTimer = 1.4
                enemy.dashProbeVx, enemy.dashProbeVy = moveToward(enemy, context.playerX, context.playerY, enemy.speed * 2.4)
            end
            enemy.vx = enemy.dashProbeVx or 0
            enemy.vy = enemy.dashProbeVy or enemy.speed
            enemy.x = enemy.x + enemy.vx * dt
            enemy.y = enemy.y + enemy.vy * dt
        end,
    },
    {
        id = "teleport_reposition",
        kind = "movement",
        validFor = "enemy",
        tags = {"highLevel"},
        cooldown = 5.0,
        canRun = function(enemy, context)
            return context.playerLevel >= 20
        end,
        weight = function(enemy, context)
            return context.playerLevel >= 20 and 0.6 + context.energy or 0
        end,
        update = function(enemy, dt, context)
            enemy.teleportTimer = (enemy.teleportTimer or 0) + dt
            if enemy.teleportTimer >= 5 then
                local angle = math.random() * math.pi * 2
                local distance = 180 + math.random() * 120
                enemy.x = context.playerX + math.cos(angle) * distance
                enemy.y = context.playerY + math.sin(angle) * distance
                enemy.teleportTimer = 0
                enemy.teleportFlash = 0.3
            end
            local vx, vy = moveToward(enemy, context.playerX, context.playerY, enemy.speed * 0.8)
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
        cooldown = 2.0,
        weight = 8,
        execute = function() end,
    },
    {
        id = "aimed_shot",
        kind = "attack",
        validFor = "enemy",
        tags = {"mids"},
        cooldown = 5.5,
        weight = function(enemy, context)
            return 0.5 + context.mids * 2 + math.min(context.playerLevel / 30, 1)
        end,
        execute = function(enemy, context)
            local vx, vy = moveToward(enemy, context.playerX, context.playerY, 210)
            addProjectile(enemy, vx, vy, 12, enemy.projectileColor or {1, 0.4, 0.4}, 5)
        end,
    },
    {
        id = "spread_pepper",
        kind = "attack",
        validFor = "enemy",
        tags = {"treble", "highEnergy"},
        cooldown = 6.5,
        canRun = function(enemy, context)
            return context.playerLevel >= 8 or context.treble > 0.65
        end,
        weight = function(enemy, context)
            return context.treble * 2.5 + context.energy
        end,
        execute = function(enemy, context)
            local cx, cy = enemyCenter(enemy)
            local baseAngle = MathUtils.atan2(context.playerY - cy, context.playerX - cx)
            for i = -1, 1 do
                local angle = baseAngle + i * 0.2
                addProjectile(enemy, math.cos(angle) * 230, math.sin(angle) * 230, 9, enemy.projectileColor, 4)
            end
        end,
    },
    {
        id = "bass_pulse",
        kind = "attack",
        validFor = "enemy",
        tags = {"bass"},
        cooldown = 7.0,
        weight = function(enemy, context)
            return context.bass > 0.6 and context.bass * 3 or 0.2
        end,
        execute = function(enemy)
            for i = 0, 5 do
                local angle = i * (math.pi * 2 / 6)
                addProjectile(enemy, math.cos(angle) * 150, math.sin(angle) * 150, 10, enemy.projectileColor, 6)
            end
        end,
    },
    {
        id = "warning_charge",
        kind = "attack",
        validFor = "enemy",
        tags = {"charger", "closeRange"},
        cooldown = 5.0,
        weight = function(enemy, context)
            return context.distanceToPlayer < 260 and (1 + context.energy * 2) or 0
        end,
        execute = function(enemy, context)
            enemy.chargeWarning = 0.35
            enemy.dashProbeTimer = 0
            enemy.dashProbeVx, enemy.dashProbeVy = moveToward(enemy, context.playerX, context.playerY, enemy.speed * 2.8)
        end,
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
