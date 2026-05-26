-- BossBehaviors.lua
-- Reusable behavior catalog for boss movement, phases, and attacks.

local BossBehaviors = {}
local Projectile = require("src.entities.Projectile")
local BulletPatterns = require("src.data.BulletPatterns")
local MathUtils = require("src.utils.MathUtils")

local function bossOrigin(boss)
    return {x = boss.x, y = boss.y}
end

local function angleToPlayer(boss, context)
    return MathUtils.angleBetween(boss.x, boss.y, context.playerX, context.playerY)
end

local function patternToProjectiles(patternProjectiles, bossProjectiles, damage, color)
    for _, p in ipairs(patternProjectiles) do
        local proj = Projectile(p.x, p.y, p.vx, p.vy, p.damage or damage, "spread", "boss")
        proj.color = p.color or color
        table.insert(bossProjectiles, proj)
    end
end

BossBehaviors.catalog = {
    {
        id = "enter_from_top",
        kind = "movement",
        validFor = "boss",
        tags = {"phase", "entering"},
        canRun = function(boss, context)
            return context.bossPhase == "entering"
        end,
        update = function(boss, dt)
            boss.y = boss.y + boss.speed * dt
            if boss.y >= boss.targetY then
                boss.y = boss.targetY
                boss.phase = "combat"
                boss.invulnerable = false
            end
        end,
    },
    {
        id = "horizontal_oscillate",
        kind = "movement",
        validFor = "boss",
        tags = {"combat", "mids"},
        canRun = function(boss, context)
            return context.bossPhase == "combat"
        end,
        weight = 5,
        update = function(boss, dt, context)
            local oscillation = math.sin((boss.combatTime or 0) * (0.75 + context.energy * 0.4)) * 220
            local targetX = love.graphics.getWidth() / 2 + oscillation
            boss.x = boss.x + (targetX - boss.x) * 2 * dt

            if boss.dashTimer and boss.dashTimer > 0 then
                boss.x = boss.x + (boss.dashVx or 0) * dt
                boss.y = boss.y + (boss.dashVy or 0) * dt
                boss.dashTimer = boss.dashTimer - dt
            end

            local margin = 100
            boss.x = math.max(margin, math.min(love.graphics.getWidth() - margin, boss.x))
            boss.y = math.max(50, math.min(love.graphics.getHeight() / 2, boss.y))
        end,
    },
    {
        id = "track_player_slow",
        kind = "movement",
        validFor = "boss",
        tags = {"combat", "closeRange"},
        canRun = function(boss, context)
            return context.bossPhase == "combat"
        end,
        weight = function(boss, context)
            return context.distanceToPlayer < 260 and 2.5 or 0.7
        end,
        update = function(boss, dt, context)
            local dx = context.playerX - boss.x
            local dy = context.playerY - boss.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                boss.x = boss.x + (dx / dist) * boss.speed * 0.45 * dt
                boss.y = boss.y + (dy / dist) * boss.speed * 0.25 * dt
            end
        end,
    },
    {
        id = "dash_strike",
        kind = "phase",
        validFor = "boss",
        tags = {"melee", "closeRange"},
        cooldown = 3.0,
        canRun = function(boss, context)
            return context.distanceToPlayer < 330
        end,
        weight = function(boss, context)
            return context.distanceToPlayer < 180 and 5 or 2
        end,
        execute = function(boss, context)
            local dx = context.playerX - boss.x
            local dy = context.playerY - boss.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                boss.dashVx = (dx / dist) * 420
                boss.dashVy = (dy / dist) * 420
                boss.dashTimer = 0.3
            end
            return 0.5
        end,
    },
    {
        id = "phase_low_health",
        kind = "phase",
        validFor = "boss",
        tags = {"lowHealth"},
        cooldown = 10.0,
        canRun = function(boss, context)
            return context.healthPercent < 0.5 and not boss.lowHealthPhaseTriggered
        end,
        weight = 10,
        execute = function(boss)
            boss.lowHealthPhaseTriggered = true
            boss.attackRate = math.max(0.45, (boss.attackRate or 0.8) * 0.75)
            boss.speed = boss.speed * 1.12
            return 0.4
        end,
    },
    {
        id = "single_shot",
        kind = "attack",
        validFor = "boss",
        tags = {"ranged", "mids"},
        cooldown = 1.5,
        weight = function(boss, context)
            return 2 + context.mids
        end,
        execute = function(boss, context)
            local angle = angleToPlayer(boss, context)
            local proj = Projectile(boss.x, boss.y, math.cos(angle) * 350, math.sin(angle) * 350, 15, "basic", "boss")
            proj.color = {1.0, 0.4, 0.8}
            table.insert(context.bossProjectiles, proj)
            return 0.7
        end,
    },
    {
        id = "spread_cone",
        kind = "attack",
        validFor = "boss",
        tags = {"ranged", "treble"},
        cooldown = 3.0,
        weight = function(boss, context)
            return 1.2 + context.treble * 2
        end,
        execute = function(boss, context)
            local angle = angleToPlayer(boss, context)
            local projs = BulletPatterns.radialBurst(bossOrigin(boss), angle, {
                count = 5, speed = 300, arc = 0.8, startAngle = angle - 0.4,
            })
            patternToProjectiles(projs, context.bossProjectiles, 10, {1.0, 0.6, 0.2})
            return 1.0
        end,
    },
    {
        id = "spiral",
        kind = "attack",
        validFor = "boss",
        tags = {"ranged", "highEnergy"},
        cooldown = 4.0,
        weight = function(boss, context)
            return 1 + context.energy * 2
        end,
        execute = function(boss, context)
            local projs = BulletPatterns.spiral(bossOrigin(boss), angleToPlayer(boss, context), {
                count = 16, speed = 280, turnStep = 0.22, delay = 0.03,
            }, context.scheduler)
            patternToProjectiles(projs, context.bossProjectiles, 8, {1.0, 0.6, 0.2})
            return 1.2
        end,
    },
    {
        id = "circle_burst",
        kind = "attack",
        validFor = "boss",
        tags = {"ranged", "balanced"},
        cooldown = 5.0,
        weight = 1.2,
        execute = function(boss, context)
            local projs = BulletPatterns.radialBurst(bossOrigin(boss), 0, {count = 12, speed = 250})
            patternToProjectiles(projs, context.bossProjectiles, 12, {0.8, 0.2, 1.0})
            return 1.5
        end,
    },
    {
        id = "wave",
        kind = "attack",
        validFor = "boss",
        tags = {"ranged", "mids"},
        cooldown = 3.5,
        weight = function(boss, context)
            return 1 + context.mids * 2
        end,
        execute = function(boss, context)
            local projs = BulletPatterns.wave(bossOrigin(boss), angleToPlayer(boss, context), {
                count = 7, speed = 260, spacing = 20,
            })
            patternToProjectiles(projs, context.bossProjectiles, 10, {0.2, 0.8, 1.0})
            return 1.0
        end,
    },
    {
        id = "cross",
        kind = "attack",
        validFor = "boss",
        tags = {"ranged", "bass"},
        cooldown = 4.0,
        weight = function(boss, context)
            return 1 + context.bass * 1.5
        end,
        execute = function(boss, context)
            local projs = BulletPatterns.cross(bossOrigin(boss), 0, {
                axes = 4, bulletsPerAxis = 3, speed = 300,
            }, context.scheduler)
            patternToProjectiles(projs, context.bossProjectiles, 12, {0.8, 1.0, 0.3})
            return 1.0
        end,
    },
    {
        id = "slam",
        kind = "attack",
        validFor = "boss",
        tags = {"aoe", "bass"},
        cooldown = 6.0,
        weight = function(boss, context)
            return context.distanceToPlayer < 360 and 2.5 or 0.8 + context.bass
        end,
        execute = function(boss, context)
            local projs = BulletPatterns.radialBurst(bossOrigin(boss), 0, {count = 24, speed = 280})
            patternToProjectiles(projs, context.bossProjectiles, 20, {1.0, 0.2, 0.2})
            return 1.2
        end,
    },
    {
        id = "double_spiral",
        kind = "attack",
        validFor = "boss",
        tags = {"aoe", "highEnergy"},
        cooldown = 7.0,
        weight = function(boss, context)
            return 0.8 + context.energy * 2
        end,
        execute = function(boss, context)
            local projs = BulletPatterns.doubleSpiral(bossOrigin(boss), 0, {
                count = 16, speed = 260, turnStep = 0.2, delay = 0.03,
            }, context.scheduler)
            patternToProjectiles(projs, context.bossProjectiles, 15, {0.3, 0.9, 1.0})
            return 1.5
        end,
    },
    {
        id = "flower",
        kind = "attack",
        validFor = "boss",
        tags = {"aoe", "treble"},
        cooldown = 8.0,
        weight = function(boss, context)
            return 0.8 + context.treble * 2
        end,
        execute = function(boss, context)
            local projs = BulletPatterns.flower(bossOrigin(boss), 0, {petals = 6, rotations = 2, speed = 220})
            patternToProjectiles(projs, context.bossProjectiles, 12, {1.0, 0.45, 0.8})
            return 1.5
        end,
    },
}

BossBehaviors.archetypes = {
    berserker = {
        phase = {"dash_strike", "phase_low_health"},
        attack = {"single_shot", "slam"},
    },
    mage = {
        phase = {"phase_low_health"},
        attack = {"single_shot", "spread_cone", "spiral", "circle_burst", "wave", "cross", "slam", "double_spiral", "flower"},
    },
    warrior = {
        phase = {"dash_strike", "phase_low_health"},
        attack = {"single_shot", "spread_cone", "wave", "slam"},
    },
}

local byId = {}
for _, behavior in ipairs(BossBehaviors.catalog) do
    byId[behavior.id] = behavior
end

local function idSet(ids)
    local set = {}
    for _, id in ipairs(ids or {}) do
        set[id] = true
    end
    return set
end

function BossBehaviors.randomArchetype()
    local names = {"berserker", "mage", "warrior"}
    return names[math.random(#names)]
end

function BossBehaviors.getAllowedIds(archetypeName, kind)
    local archetype = BossBehaviors.archetypes[archetypeName] or BossBehaviors.archetypes.mage
    return idSet(archetype[kind])
end

function BossBehaviors.getAll()
    return BossBehaviors.catalog
end

function BossBehaviors.getById(id)
    return byId[id]
end

function BossBehaviors.listByKind(kind)
    local list = {}
    for _, behavior in ipairs(BossBehaviors.catalog) do
        if behavior.kind == kind then
            table.insert(list, behavior)
        end
    end
    return list
end

return BossBehaviors
