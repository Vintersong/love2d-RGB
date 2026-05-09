local BossArchetypes = {}

local Projectile = require("src.entities.Projectile")
local BulletPatterns = require("src.data.BulletPatterns")

-- Helper: create Projectile objects from pattern data tables
local function patternToProjectiles(patternProjectiles, bossProjectiles, damage, color)
    for _, p in ipairs(patternProjectiles) do
        local proj = Projectile(p.x, p.y, p.vx, p.vy, damage, "spread", "boss")
        proj.color = color
        table.insert(bossProjectiles, proj)
    end
end

-- Melee behaviors
BossArchetypes.melee = {
    basic = {
        execute = function(boss, player, bossProjectiles)
            return 0.8
        end,
        cooldown = 1.2,
        range = 120,
    },
    dash = {
        execute = function(boss, player, bossProjectiles)
            local dx = player.x + player.width / 2 - boss.x
            local dy = player.y + player.height / 2 - boss.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                boss.dashVx = (dx / dist) * 400
                boss.dashVy = (dy / dist) * 400
                boss.dashTimer = 0.3
            end
            return 0.5
        end,
        cooldown = 3.0,
        range = 300,
    },
}

-- Ranged behaviors (using BulletPatterns)
BossArchetypes.ranged = {
    single = {
        execute = function(boss, player, bossProjectiles)
            local angle = math.atan2(
                player.y + player.height / 2 - boss.y,
                player.x + player.width / 2 - boss.x
            )
            local proj = Projectile(
                boss.x, boss.y,
                math.cos(angle) * 350, math.sin(angle) * 350,
                15, "basic", "boss"
            )
            proj.color = {1.0, 0.4, 0.8}
            table.insert(bossProjectiles, proj)
            return 0.7
        end,
        cooldown = 1.5,
        range = 500,
    },
    spread = {
        execute = function(boss, player, bossProjectiles)
            local angle = math.atan2(
                player.y + player.height / 2 - boss.y,
                player.x + player.width / 2 - boss.x
            )
            local origin = {x = boss.x, y = boss.y}
            local projs = BulletPatterns.radialBurst(origin, angle, {
                count = 5, speed = 300, arc = 0.8,
                startAngle = angle - 0.4,
            })
            patternToProjectiles(projs, bossProjectiles, 10, {1.0, 0.6, 0.2})
            return 1.0
        end,
        cooldown = 3.0,
        range = 600,
    },
    spiral = {
        execute = function(boss, player, bossProjectiles)
            local angle = math.atan2(
                player.y + player.height / 2 - boss.y,
                player.x + player.width / 2 - boss.x
            )
            local origin = {x = boss.x, y = boss.y}
            local projs = BulletPatterns.spiral(origin, angle, {
                count = 16, speed = 280, turnStep = 0.22, delay = 0.03,
            }, boss._scheduler)
            patternToProjectiles(projs, bossProjectiles, 8, {1.0, 0.6, 0.2})
            return 1.2
        end,
        cooldown = 4.0,
        range = 600,
    },
    circle = {
        execute = function(boss, player, bossProjectiles)
            local origin = {x = boss.x, y = boss.y}
            local projs = BulletPatterns.radialBurst(origin, 0, {
                count = 12, speed = 250,
            })
            patternToProjectiles(projs, bossProjectiles, 12, {0.8, 0.2, 1.0})
            return 1.5
        end,
        cooldown = 5.0,
        range = 500,
    },
    wave = {
        execute = function(boss, player, bossProjectiles)
            local angle = math.atan2(
                player.y + player.height / 2 - boss.y,
                player.x + player.width / 2 - boss.x
            )
            local origin = {x = boss.x, y = boss.y}
            local projs = BulletPatterns.wave(origin, angle, {
                count = 7, speed = 260, spacing = 20,
            })
            patternToProjectiles(projs, bossProjectiles, 10, {0.2, 0.8, 1.0})
            return 1.0
        end,
        cooldown = 3.5,
        range = 500,
    },
    cross = {
        execute = function(boss, player, bossProjectiles)
            local origin = {x = boss.x, y = boss.y}
            local projs = BulletPatterns.cross(origin, 0, {
                axes = 4, bulletsPerAxis = 3, speed = 300,
            }, boss._scheduler)
            patternToProjectiles(projs, bossProjectiles, 12, {0.8, 1.0, 0.3})
            return 1.0
        end,
        cooldown = 4.0,
        range = 500,
    },
}

-- AOE behaviors (using BulletPatterns)
BossArchetypes.aoe = {
    slam = {
        execute = function(boss, player, bossProjectiles)
            local origin = {x = boss.x, y = boss.y}
            local projs = BulletPatterns.radialBurst(origin, 0, {
                count = 24, speed = 280,
            })
            patternToProjectiles(projs, bossProjectiles, 20, {1.0, 0.2, 0.2})
            return 1.2
        end,
        cooldown = 6.0,
        range = 300,
    },
    doubleSpiral = {
        execute = function(boss, player, bossProjectiles)
            local origin = {x = boss.x, y = boss.y}
            local projs = BulletPatterns.doubleSpiral(origin, 0, {
                count = 16, speed = 260, turnStep = 0.2, delay = 0.03,
            }, boss._scheduler)
            patternToProjectiles(projs, bossProjectiles, 15, {0.3, 0.9, 1.0})
            return 1.5
        end,
        cooldown = 7.0,
        range = 400,
    },
    flower = {
        execute = function(boss, player, bossProjectiles)
            local origin = {x = boss.x, y = boss.y}
            local projs = BulletPatterns.flower(origin, 0, {
                petals = 6, rotations = 2, speed = 220,
            })
            patternToProjectiles(projs, bossProjectiles, 12, {1.0, 0.45, 0.8})
            return 1.5
        end,
        cooldown = 8.0,
        range = 400,
    },
}

-- Archetype definitions
BossArchetypes.archetypes = {
    berserker = {
        melee = {"basic", "dash"},
        ranged = {"single"},
        aoe = {"slam"},
        meleeChance = 0.7,
        rangedChance = 0.2,
        aoeChance = 0.1,
    },
    mage = {
        melee = {"basic"},
        ranged = {"single", "spread", "spiral", "circle", "wave", "cross"},
        aoe = {"slam", "doubleSpiral", "flower"},
        meleeChance = 0.1,
        rangedChance = 0.6,
        aoeChance = 0.3,
    },
    warrior = {
        melee = {"basic", "dash"},
        ranged = {"single", "spread", "wave"},
        aoe = {"slam"},
        meleeChance = 0.5,
        rangedChance = 0.35,
        aoeChance = 0.15,
    },
}

function BossArchetypes.randomArchetype()
    local names = {"berserker", "mage", "warrior"}
    return names[math.random(#names)]
end

function BossArchetypes.selectBehavior(archetypeName, distToPlayer)
    local arch = BossArchetypes.archetypes[archetypeName]
    if not arch then return nil, nil end

    local roll = math.random()
    local category, pool

    if distToPlayer < 150 and roll < arch.meleeChance then
        category = "melee"
        pool = arch.melee
    elseif roll < arch.meleeChance + arch.rangedChance then
        category = "ranged"
        pool = arch.ranged
    else
        category = "aoe"
        pool = arch.aoe
    end

    if not pool or #pool == 0 then return nil, nil end

    local behaviorName = pool[math.random(#pool)]
    return category, behaviorName
end

return BossArchetypes
