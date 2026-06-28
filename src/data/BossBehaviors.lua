-- BossBehaviors.lua
-- Reusable behavior catalog for boss movement, phases, and attacks.

local BossBehaviors = {}
local Projectile = require("src.entities.Projectile")
local BulletPatterns = require("src.data.BulletPatterns")
local MathUtils = require("src.utils.MathUtils")
local GameConfig = require("src.core.GameConfig")
local Config = require("src.Config")

local function bossOrigin(boss)
    return {x = boss.x, y = boss.y}
end

local function angleToPlayer(boss, context)
    return MathUtils.angleBetween(boss.x, boss.y, context.playerX, context.playerY)
end

local function bossDamage(boss, multiplier, fallback)
    return math.floor(((boss and boss.damage) or fallback or 10) * (multiplier or 1))
end

local function patternToProjectiles(patternProjectiles, bossProjectiles, damage, color, projType)
    for _, p in ipairs(patternProjectiles) do
        local proj = Projectile(p.x, p.y, p.vx, p.vy, p.damage or damage, projType or "spread", "boss")
        proj.color = p.color or color
        table.insert(bossProjectiles, proj)
    end
end

local function typedScheduler(scheduler, projType)
    return {
        schedule = function(delay, projData)
            projData.projType = projType
            scheduler.schedule(delay, projData)
        end
    }
end

local function clampBossVertical(boss, screenHeight)
    local minY = boss.minY or 50
    local maxY = boss.maxY or math.floor(screenHeight / 2)
    boss.y = math.max(minY, math.min(maxY, boss.y))
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
            local screenWidth, screenHeight = GameConfig.getScreenSize()
            local oscillation = math.sin((boss.combatTime or 0) * (0.75 + context.energy * 0.4)) * 220
            local targetX = screenWidth / 2 + oscillation
            boss.x = boss.x + (targetX - boss.x) * 2 * dt

            if boss.dashTimer and boss.dashTimer > 0 then
                boss.x = boss.x + (boss.dashVx or 0) * dt
                boss.y = boss.y + (boss.dashVy or 0) * dt
                boss.dashTimer = boss.dashTimer - dt
            end

            local margin = 100
            boss.x = math.max(margin, math.min(screenWidth - margin, boss.x))
            clampBossVertical(boss, screenHeight)
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
            local _, screenHeight = GameConfig.getScreenSize()
            local dx = context.playerX - boss.x
            local dy = context.playerY - boss.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                boss.x = boss.x + (dx / dist) * boss.speed * 0.45 * dt
                boss.y = boss.y + (dy / dist) * boss.speed * 0.25 * dt
            end
            clampBossVertical(boss, screenHeight)
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
            local proj = Projectile(boss.x, boss.y, math.cos(angle) * 390, math.sin(angle) * 390, bossDamage(boss, 0.78, 15), "boss_diamond", "boss")
            proj.color = {1.0, 0.4, 0.8}
            table.insert(context.bossProjectiles, proj)
            return 0.56
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
                count = 7, speed = 330, arc = 0.95, startAngle = angle - 0.475,
            })
            patternToProjectiles(projs, context.bossProjectiles, bossDamage(boss, 0.62, 10), {1.0, 0.6, 0.2}, "boss_bolt")
            return 0.82
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
                count = 22, speed = 305, turnStep = 0.22, delay = 0.026,
            }, typedScheduler(context.scheduler, "boss_orb"))
            patternToProjectiles(projs, context.bossProjectiles, bossDamage(boss, 0.5, 8), {1.0, 0.6, 0.2}, "boss_orb")
            return 1.0
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
            local projs = BulletPatterns.radialBurst(bossOrigin(boss), 0, {count = 16, speed = 280})
            patternToProjectiles(projs, context.bossProjectiles, bossDamage(boss, 0.64, 12), {0.8, 0.2, 1.0}, "boss_shard")
            return 1.15
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
                count = 9, speed = 290, spacing = 18,
            })
            patternToProjectiles(projs, context.bossProjectiles, bossDamage(boss, 0.58, 10), {0.2, 0.8, 1.0}, "boss_crescent")
            return 0.86
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
                axes = 4, bulletsPerAxis = 4, speed = 330,
            }, typedScheduler(context.scheduler, "boss_cross"))
            patternToProjectiles(projs, context.bossProjectiles, bossDamage(boss, 0.64, 12), {0.8, 1.0, 0.3}, "boss_cross")
            return 0.9
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
            local projs = BulletPatterns.radialBurst(bossOrigin(boss), 0, {count = 28, speed = 310})
            patternToProjectiles(projs, context.bossProjectiles, bossDamage(boss, 0.95, 20), {1.0, 0.2, 0.2}, "boss_chevron")
            return 1.0
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
                count = 22, speed = 290, turnStep = 0.2, delay = 0.026,
            }, typedScheduler(context.scheduler, "boss_twinorb"))
            patternToProjectiles(projs, context.bossProjectiles, bossDamage(boss, 0.74, 15), {0.3, 0.9, 1.0}, "boss_twinorb")
            return 1.2
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
            local projs = BulletPatterns.flower(bossOrigin(boss), 0, {petals = 7, rotations = 2, speed = 250})
            patternToProjectiles(projs, context.bossProjectiles, bossDamage(boss, 0.62, 12), {1.0, 0.45, 0.8}, "boss_petal")
            return 1.25
        end,
    },
    {
        -- Opt-in demonstration that the standalone BulletPatternLibrary fires in-game through
        -- the shared PatternSpawner bridge. Gated by Config.boss.patternLibAttacks (default
        -- OFF) via canRun, so even though its id is in the archetype attack lists it is never
        -- selected unless the flag is on -- the stock attack mix is unchanged by default.
        id = "pattern_pillar_curtain",
        kind = "attack",
        validFor = "boss",
        tags = {"ranged", "mids"},
        cooldown = 6.0,
        canRun = function(boss, context)
            return Config.boss and Config.boss.patternLibAttacks == true
        end,
        weight = function(boss, context)
            return 1.4 + (context.mids or 0) * 1.5
        end,
        execute = function(boss, context)
            local BulletPatternLibrary = require("src.patterns.BulletPatternLibrary")
            local PatternSpawner = require("src.combat.PatternSpawner")
            local screenW, screenH = GameConfig.getScreenSize()
            -- A descending curtain of vertical pillars with a safe lane, spanning from the
            -- boss line down to the floor. Resolve stage -> live bullets (telegraph markers
            -- come from the warning stage and are rendered elsewhere; the bridge skips them).
            local descriptors = BulletPatternLibrary.pillars({x = boss.x, y = boss.y}, 1.0, {
                pillarCount = 5,
                fieldLeft = 0, fieldRight = screenW,
                fieldTop = boss.y, fieldBottom = screenH,
                bulletsPerPillar = 8,
                gaps = {{pos = 0.5, width = 0.24}},
                descendSpeed = 210,
                color_axis = "mids",
                stage = "resolve",
            })
            PatternSpawner.spawn(descriptors, context.bossProjectiles, {
                damage = bossDamage(boss, 0.45, 9),
                projType = "boss_orb",
            })
            return 1.4
        end,
    },
}

BossBehaviors.archetypes = {
    -- "pattern_pillar_curtain" is listed for every archetype but only fires when
    -- Config.boss.patternLibAttacks is true (its canRun gate); default OFF leaves the mix as-is.
    berserker = {
        phase = {"dash_strike", "phase_low_health"},
        attack = {"single_shot", "slam", "pattern_pillar_curtain"},
    },
    mage = {
        phase = {"phase_low_health"},
        attack = {"single_shot", "spread_cone", "spiral", "circle_burst", "wave", "cross", "slam", "double_spiral", "flower", "pattern_pillar_curtain"},
    },
    warrior = {
        phase = {"dash_strike", "phase_low_health"},
        attack = {"single_shot", "spread_cone", "wave", "slam", "pattern_pillar_curtain"},
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
