local BossBehaviors = {}

-- Melee behavior patterns
BossBehaviors.melee = {
    basic = {
        execute = function(boss, attackSystem, target)
            -- Logic for basic melee (e.g. contact damage is usually handled elsewhere, 
            -- but we can use this for animation/triggers)
            return 0.8 -- Duration
        end,
        cooldown = 1.2,
        range = 120
    },
    dash = {
        execute = function(boss, attackSystem, target)
            -- Implementation of dash toward player
            -- We'll handle the actual physics in EnemyManager:updateBoss based on the state
            return 0.5
        end,
        cooldown = 3.0,
        range = 240
    }
}

-- Ranged behavior patterns
BossBehaviors.ranged = {
    single = {
        execute = function(boss, attackSystem, target)
            if not target or not attackSystem then return 0.5 end
            
            local angle = math.atan2(target.y - boss.y, target.x - boss.x)
            local speed = 350
            
            attackSystem:spawn({
                x = boss.x,
                y = boss.y,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed,
                radius = 12,
                color = {1.0, 0.4, 0.8},
                pattern = "straight",
                damage = 15,
                ttl = 4
            })
            
            return 0.7
        end,
        cooldown = 1.5,
        range = 500
    },
    spread = {
        execute = function(boss, attackSystem, target)
            if not target or not attackSystem then return 0.5 end
            
            local angle = math.atan2(target.y - boss.y, target.x - boss.x)
            local spreadAngles = {-0.2, 0, 0.2} -- Radians
            local speed = 300
            
            for _, offset in ipairs(spreadAngles) do
                local a = angle + offset
                attackSystem:spawn({
                    x = boss.x,
                    y = boss.y,
                    vx = math.cos(a) * speed,
                    vy = math.sin(a) * speed,
                    radius = 8,
                    color = {1.0, 0.6, 0.2},
                    pattern = "straight",
                    damage = 10,
                    ttl = 4
                })
            end
            
            return 1.0
        end,
        cooldown = 3.0,
        range = 600
    },
    circle = {
        execute = function(boss, attackSystem, target)
            if not attackSystem then return 0.5 end
            
            local numProjectiles = 12
            local speed = 250
            for i = 1, numProjectiles do
                local angle = (i / numProjectiles) * math.pi * 2
                attackSystem:spawn({
                    x = boss.x,
                    y = boss.y,
                    vx = math.cos(angle) * speed,
                    vy = math.sin(angle) * speed,
                    radius = 10,
                    color = {0.8, 0.2, 1.0},
                    pattern = "straight",
                    damage = 12,
                    ttl = 5
                })
            end
            
            return 1.5
        end,
        cooldown = 5.0,
        range = 500
    }
}

-- AOE behavior patterns
BossBehaviors.aoe = {
    slam = {
        execute = function(boss, attackSystem, target)
            -- Trigger a radial burst or something similar
            if not attackSystem then return 0.5 end
            
            local ctx = attackSystem:createPatternContext(love.timer.getTime())
            local patternLibrary = require("bulletPatterns")
            
            patternLibrary.radialBurst(ctx, {x = boss.x, y = boss.y}, {
                count = 24,
                speed = 280,
                radius = 15,
                color = {1.0, 0.2, 0.2},
                damage = 20
            })
            
            return 1.2
        end,
        cooldown = 6.0,
        range = 300
    }
}

-- Behavior sets (Archetypes)
BossBehaviors.archetypes = {
    berserker = {
        melee = {"basic", "dash"},
        ranged = {"single"},
        aoe = {"slam"},
        meleeChance = 0.7,
        rangedChance = 0.2,
        aoeChance = 0.1
    },
    mage = {
        melee = {"basic"},
        ranged = {"single", "spread", "circle"},
        aoe = {"slam"},
        meleeChance = 0.2,
        rangedChance = 0.6,
        aoeChance = 0.2
    },
    warrior = {
        melee = {"basic", "dash"},
        ranged = {"single", "spread"},
        aoe = {"slam"},
        meleeChance = 0.5,
        rangedChance = 0.4,
        aoeChance = 0.3
    }
}

return BossBehaviors
