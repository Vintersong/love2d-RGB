local collision = require("systems.core.collision")
local BossBehaviors = require("components.enemies.bossBehaviors")
local mathUtils = require("systems.core.mathUtils")

local EnemyManager = {}
EnemyManager.__index = EnemyManager

local ARCHETYPES = {
    BASS = {
        shape = "hex",
        r = 22,
        speed = 72,
        hp = 8,
        damage = 10,
        xp = 14,
        score = 18,
        color = {0.95, 0.2, 0.35},
    },
    MIDS = {
        shape = "square",
        r = 18,
        speed = 104,
        hp = 5,
        damage = 8,
        xp = 10,
        score = 12,
        color = {1.0, 0.75, 0.25},
    },
    TREBLE = {
        shape = "triangle",
        r = 15,
        speed = 145,
        hp = 3,
        damage = 6,
        xp = 8,
        score = 10,
        color = {0.25, 0.9, 1.0},
    },
    SHOOTER = {
        shape = "triangle",
        r = 16,
        speed = 90,
        hp = 6,
        damage = 5,
        xp = 15,
        score = 20,
        color = {0.6, 0.4, 1.0},
    },
}

local FORMATIONS = {
    square_corners = {
        {0, 0, "BASS"},
        {-42, -42, "TREBLE"},
        {42, -42, "TREBLE"},
        {-42, 42, "TREBLE"},
        {42, 42, "TREBLE"},
    },
    hex_star = {
        {0, 0, "BASS"},
        {52, 0, "TREBLE"},
        {26, 45, "TREBLE"},
        {-26, 45, "MIDS"},
        {-52, 0, "TREBLE"},
        {-26, -45, "MIDS"},
        {26, -45, "TREBLE"},
    },
    tri_squares = {
        {0, -48, "MIDS"},
        {-34, 0, "MIDS"},
        {34, 0, "MIDS"},
        {-68, 48, "TREBLE"},
        {0, 48, "TREBLE"},
        {68, 48, "TREBLE"},
    },
    diamond = {
        {0, 0, "BASS"},
        {0, -52, "MIDS"},
        {52, 0, "MIDS"},
        {0, 52, "MIDS"},
        {-52, 0, "MIDS"},
        {0, -96, "TREBLE"},
        {96, 0, "TREBLE"},
        {0, 96, "TREBLE"},
        {-96, 0, "TREBLE"},
    },
    vee = {
        {-60, -45, "TREBLE"},
        {-25, -10, "SHOOTER"},
        {25, -10, "SHOOTER"},
        {60, -45, "TREBLE"},
    },
}

local clamp = mathUtils.clamp
local normalize = mathUtils.normalize

local function distToSegment(px, py, x1, y1, x2, y2)
    local vx = x2 - x1
    local vy = y2 - y1
    local wx = px - x1
    local wy = py - y1
    local lengthSq = vx * vx + vy * vy
    if lengthSq == 0 then
        return collision.distance(px, py, x1, y1)
    end
    local t = clamp((wx * vx + wy * vy) / lengthSq, 0, 1)
    local cx = x1 + vx * t
    local cy = y1 + vy * t
    return collision.distance(px, py, cx, cy)
end

function EnemyManager:new(config)
    local self = setmetatable({}, EnemyManager)
    self.config = config or {}
    self.enemies = {}
    self.enemyPool = {}
    self.spawnTimer = 0
    self.spawnInterval = self.config.spawnInterval or 1.1
    self.maxEnemies = self.config.maxEnemies or 54
    self.nextId = 1
    self.killCount = 0
    self.totalKills = 0
    self.boss = nil
    self.bossSpawned = false
    self.bossDefeated = false
    self.contactTimer = 0
    self.intensityTime = 0
    return self
end

function EnemyManager:getIntensity()
    return 0.85 + math.sin(self.intensityTime * 1.7) * 0.25 + math.sin(self.intensityTime * 0.43) * 0.2
end

function EnemyManager:chooseFormation()
    local names = {"square_corners", "hex_star", "tri_squares", "diamond", "vee"}
    if math.random() < 0.25 then
        return "vee" -- Vee formation often has shooters or mids
    end
    return names[math.random(1, #names)]
end

function EnemyManager:getSpawnAnchor()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local side = math.random(1, 4)
    if side == 1 then
        return math.random(80, w - 80), -70
    elseif side == 2 then
        return w + 70, math.random(80, h - 160)
    elseif side == 3 then
        return math.random(80, w - 80), h + 70
    end
    return -70, math.random(80, h - 160)
end

function EnemyManager:spawnEnemy(x, y, typeName)
    if #self.enemies >= self.maxEnemies then
        return
    end

    local proto = ARCHETYPES[typeName] or ARCHETYPES.MIDS
    local enemy = table.remove(self.enemyPool)
    if not enemy then
        enemy = {
            id = 0, x = 0, y = 0, r = 0, speed = 0, hp = 0, maxHp = 0, damage = 0, xp = 0, score = 0,
            color = {0, 0, 0}, shape = "", type = "", slowTimer = 0, slowFactor = 1, wobble = 0
        }
    end

    enemy.id = self.nextId
    enemy.x = x
    enemy.y = y
    enemy.r = proto.r
    enemy.speed = proto.speed
    enemy.hp = proto.hp
    enemy.maxHp = proto.hp
    enemy.damage = proto.damage
    enemy.xp = proto.xp
    enemy.score = proto.score
    enemy.color[1] = proto.color[1]
    enemy.color[2] = proto.color[2]
    enemy.color[3] = proto.color[3]
    enemy.shape = proto.shape
    enemy.type = typeName
    enemy.slowTimer = 0
    enemy.slowFactor = 1
    enemy.wobble = math.random() * math.pi * 2
    enemy.shotTimer = math.random() * 2 -- Randomize first shot

    self.nextId = self.nextId + 1
    table.insert(self.enemies, enemy)
end

function EnemyManager:spawnFormation()
    local name = self:chooseFormation()
    local formation = FORMATIONS[name]
    local ax, ay = self:getSpawnAnchor()
    for _, entry in ipairs(formation) do
        self:spawnEnemy(ax + entry[1], ay + entry[2], entry[3])
    end
end

function EnemyManager:spawnBoss()
    if self.boss or self.bossDefeated then
        return
    end

    self.bossSpawned = true
    self.boss = {
        id = 900000 + self.nextId,
        x = love.graphics.getWidth() * 0.5,
        y = -90,
        r = 64,
        hp = 180,
        maxHp = 180,
        damage = 18,
        phase = "entering",
        color = {1.0, 0.25, 0.95},
        slowTimer = 0,
        slowFactor = 1,
        
        -- New state logic
        archetype = BossBehaviors.archetypes[({"berserker", "mage", "warrior"})[math.random(3)]],
        state = "idle",
        stateTimer = 0,
        meleeTimer = 0,
        rangedTimer = 0,
        aoeTimer = 0,
        currentMelee = nil,
        currentRanged = nil,
        currentAOE = nil,
        moveTargetX = love.graphics.getWidth() * 0.5,
        moveTargetY = 120
    }
    
    -- Select initial behaviors
    local a = self.boss.archetype
    self.boss.currentMelee = a.melee[math.random(#a.melee)]
    self.boss.currentRanged = a.ranged[math.random(#a.ranged)]
    self.boss.currentAOE = a.aoe[math.random(#a.aoe)]
end

local function targetIterator(self, index)
    if index < #self.enemies then
        return index + 1, self.enemies[index + 1]
    elseif index == #self.enemies and self.boss then
        return index + 1, self.boss
    end
    return nil
end

function EnemyManager:eachTarget()
    return targetIterator, self, 0
end

function EnemyManager:getNearestEnemy(x, y)
    local best
    local bestDistance = math.huge
    for _, enemy in self:eachTarget() do
        if enemy.hp > 0 then
            local d = collision.distanceSq(x, y, enemy.x, enemy.y)
            if d < bestDistance then
                best = enemy
                bestDistance = d
            end
        end
    end
    return best
end

function EnemyManager:damageArea(x, y, radius, damage, sourceId, xpManager, playerStats)
    if radius <= 0 then
        return
    end
    for _, enemy in self:eachTarget() do
        if enemy.id ~= sourceId and enemy.hp > 0 and collision.circleSq(x, y, radius, enemy.x, enemy.y, enemy.r) then
            self:damageTarget(enemy, damage, xpManager, playerStats)
        end
    end
end

function EnemyManager:damageEnemiesAlongLine(x1, y1, x2, y2, radius, damage)
    for _, enemy in self:eachTarget() do
        if enemy.hp > 0 and distToSegment(enemy.x, enemy.y, x1, y1, x2, y2) <= radius + enemy.r then
            self:damageTarget(enemy, damage)
        end
    end
end

function EnemyManager:damageTarget(target, amount, xpManager, playerStats)
    target.hp = target.hp - amount
    if target.hp > 0 then
        return false
    end

    if target == self.boss then
        self.bossDefeated = true
        if playerStats then
            playerStats.score = playerStats.score + 1000
        end
        self.boss = nil
        return true
    end

    for i = #self.enemies, 1, -1 do
        if self.enemies[i] == target then
            local deadEnemy = table.remove(self.enemies, i)
            table.insert(self.enemyPool, deadEnemy)
            break
        end
    end

    self.killCount = self.killCount + 1
    self.totalKills = self.totalKills + 1
    if playerStats then
        playerStats.score = playerStats.score + (target.score or 10)
    end
    if xpManager then
        xpManager:addXP(target.xp or 8)
    end
    return true
end

function EnemyManager:updateSpawning(dt)
    if #self.enemies >= self.maxEnemies then
        return
    end

    local intensity = self:getIntensity()
    self.spawnTimer = self.spawnTimer + dt * intensity
    if self.spawnTimer >= self.spawnInterval then
        self.spawnTimer = self.spawnTimer - self.spawnInterval
        self:spawnFormation()
    end
end

function EnemyManager:updateEnemies(dt, player, enemyAttack)
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        if enemy.slowTimer > 0 then
            enemy.slowTimer = enemy.slowTimer - dt
            if enemy.slowTimer <= 0 then
                enemy.slowFactor = 1
            end
        end

        local dx = player.x - enemy.x
        local dy = player.y - enemy.y
        local dist = math.sqrt(dx * dx + dy * dy)
        local nx, ny = normalize(dx, dy)
        local speed = enemy.speed * enemy.slowFactor
        enemy.wobble = enemy.wobble + dt * 2
        
        if enemy.type == "SHOOTER" then
            -- Shooter behavior: try to stay at a certain distance
            local targetDist = 300
            if dist > targetDist + 50 then
                -- Move closer
                enemy.x = enemy.x + nx * speed * dt
                enemy.y = enemy.y + ny * speed * dt
            elseif dist < targetDist - 50 then
                -- Move away
                enemy.x = enemy.x - nx * speed * dt
                enemy.y = enemy.y - ny * speed * dt
            else
                -- Strafe or stay
                local sx, sy = -ny, nx -- Perpendicular
                enemy.x = enemy.x + sx * speed * 0.5 * dt
                enemy.y = enemy.y + sy * speed * 0.5 * dt
            end
            
            -- Fire logic
            enemy.shotTimer = enemy.shotTimer - dt
            if enemy.shotTimer <= 0 and dist < 600 then
                if enemyAttack then
                    enemyAttack:spawn({
                        x = enemy.x,
                        y = enemy.y,
                        vx = nx * 320,
                        vy = ny * 320,
                        radius = 6,
                        color = enemy.color,
                        damage = enemy.damage,
                        ttl = 3
                    })
                end
                enemy.shotTimer = 2.5 + math.random() * 1.5
            end
        else
            -- Basic chaser behavior
            enemy.x = enemy.x + nx * speed * dt + math.cos(enemy.wobble) * 8 * dt
            enemy.y = enemy.y + ny * speed * dt + math.sin(enemy.wobble) * 8 * dt
        end
    end
end

function EnemyManager:updateBoss(dt, player, enemyAttack)
    if not self.boss then
        return
    end

    local boss = self.boss
    
    -- Update timers
    boss.meleeTimer = boss.meleeTimer + dt
    boss.rangedTimer = boss.rangedTimer + dt
    boss.aoeTimer = boss.aoeTimer + dt
    
    if boss.phase == "entering" then
        boss.y = boss.y + 115 * dt
        if boss.y >= 120 then
            boss.y = 120
            boss.phase = "combat"
        end
        return
    end

    -- Combat logic
    local dx = player.x - boss.x
    local dy = player.y - boss.y
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if boss.state == "idle" then
        -- Movement: Oscillate or move toward target
        boss.x = love.graphics.getWidth() * 0.5 + math.sin(love.timer.getTime() * 0.8) * 220
        
        -- Attack selection logic
        local a = boss.archetype
        local melee = BossBehaviors.melee[boss.currentMelee]
        local ranged = BossBehaviors.ranged[boss.currentRanged]
        local aoe = BossBehaviors.aoe[boss.currentAOE]
        
        if dist <= (melee and melee.range or 150) then
            if melee and boss.meleeTimer >= melee.cooldown and math.random() < a.meleeChance then
                boss.state = "melee"
                boss.stateTimer = melee.execute(boss, enemyAttack, player)
                boss.meleeTimer = 0
                boss.currentMelee = a.melee[math.random(#a.melee)]
            end
        else
            if ranged and boss.rangedTimer >= ranged.cooldown and math.random() < a.rangedChance then
                boss.state = "ranged"
                boss.stateTimer = ranged.execute(boss, enemyAttack, player)
                boss.rangedTimer = 0
                boss.currentRanged = a.ranged[math.random(#a.ranged)]
            elseif aoe and boss.aoeTimer >= aoe.cooldown and math.random() < a.aoeChance then
                boss.state = "aoe"
                boss.stateTimer = aoe.execute(boss, enemyAttack, player)
                boss.aoeTimer = 0
                boss.currentAOE = a.aoe[math.random(#a.aoe)]
            end
        end
    else
        -- Currently performing an attack
        boss.stateTimer = boss.stateTimer - dt
        if boss.stateTimer <= 0 then
            boss.state = "idle"
        end
        
        -- Slow down during most attacks
        if boss.state ~= "melee" then 
            -- (Melee might want to dash, so we don't always slow down)
        end
    end
end

function EnemyManager:updateContacts(dt, playerStats, player, abilities)
    self.contactTimer = math.max(0, self.contactTimer - dt)
    if self.contactTimer > 0 or (abilities and abilities:isShielded()) then
        return
    end

    for _, enemy in self:eachTarget() do
        if collision.circleSq(player.x, player.y, player.radius or 18, enemy.x, enemy.y, enemy.r) then
            playerStats:takeDamage(enemy.damage or 8)
            self.contactTimer = 0.35
            return
        end
    end
end

function EnemyManager:updateProjectileCollisions(attackProjectiles, xpManager, playerStats)
    local cellSize = 120
    local grid = {}

    for _, enemy in self:eachTarget() do
        if enemy.hp > 0 then
            local cx = math.floor(enemy.x / cellSize)
            local cy = math.floor(enemy.y / cellSize)
            local key = cx .. "," .. cy
            if not grid[key] then grid[key] = {} end
            table.insert(grid[key], enemy)
        end
    end

    for pi = #attackProjectiles, 1, -1 do
        local projectile = attackProjectiles[pi]
        if not projectile.dead then
            local minCx = math.floor((projectile.x - projectile.radius) / cellSize)
            local maxCx = math.floor((projectile.x + projectile.radius) / cellSize)
            local minCy = math.floor((projectile.y - projectile.radius) / cellSize)
            local maxCy = math.floor((projectile.y + projectile.radius) / cellSize)
            
            local removeProjectile = false
            local hitSomething = false

            for cx = minCx, maxCx do
                for cy = minCy, maxCy do
                    local key = cx .. "," .. cy
                    local cell = grid[key]
                    if cell then
                        for _, enemy in ipairs(cell) do
                            if enemy.hp > 0
                                and not projectile.hitEnemyIds[enemy.id]
                                and collision.circleSq(projectile.x, projectile.y, projectile.radius, enemy.x, enemy.y, enemy.r) then
                                
                                projectile.hitEnemyIds[enemy.id] = true
                                if projectile.slowDuration and projectile.slowDuration > 0 then
                                    enemy.slowTimer = projectile.slowDuration
                                    enemy.slowFactor = projectile.slowFactor or 0.55
                                end

                                local killed = self:damageTarget(enemy, projectile.damage or 1, xpManager, playerStats)
                                if projectile.aoeRadius and projectile.aoeRadius > 0 then
                                    self:damageArea(projectile.x, projectile.y, projectile.aoeRadius, math.max(1, (projectile.damage or 1) * 0.65), enemy.id, xpManager, playerStats)
                                end

                                if projectile.pierce and projectile.pierce > 0 then
                                    projectile.pierce = projectile.pierce - 1
                                else
                                    removeProjectile = true
                                end

                                if killed and projectile.pierce <= 0 then
                                    removeProjectile = true
                                end
                                
                                hitSomething = true
                                break
                            end
                        end
                    end
                    if hitSomething or removeProjectile then break end
                end
                if hitSomething or removeProjectile then break end
            end

            if removeProjectile then
                projectile.dead = true
            end
        end
    end
end

function EnemyManager:update(dt, attackProjectiles, playerStats, xpManager, player, abilities, enemyAttack)
    self.intensityTime = self.intensityTime + dt
    player = player or {x = love.graphics.getWidth() * 0.5, y = love.graphics.getHeight() * 0.8, radius = 18}

    if not self.bossSpawned and self.killCount >= 100 then
        self:spawnBoss()
    end

    self:updateSpawning(dt)
    self:updateEnemies(dt, player, enemyAttack)
    self:updateBoss(dt, player, enemyAttack)
    self:updateProjectileCollisions(attackProjectiles, xpManager, playerStats)
    self:updateContacts(dt, playerStats, player, abilities)
end

local function drawTriangle(x, y, r)
    love.graphics.polygon("fill", x, y - r, x - r * 0.86, y + r * 0.55, x + r * 0.86, y + r * 0.55)
end

local function drawHex(x, y, r)
    love.graphics.circle("fill", x, y, r, 6)
end

function EnemyManager:drawEnemy(enemy)
    love.graphics.setColor(enemy.color[1], enemy.color[2], enemy.color[3], 1)
    if enemy.shape == "triangle" then
        drawTriangle(enemy.x, enemy.y, enemy.r)
    elseif enemy.shape == "square" then
        love.graphics.rectangle("fill", enemy.x - enemy.r, enemy.y - enemy.r, enemy.r * 2, enemy.r * 2, 3, 3)
    else
        drawHex(enemy.x, enemy.y, enemy.r)
    end

    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.circle("line", enemy.x, enemy.y, enemy.r + 3)

    if enemy.hp < enemy.maxHp then
        local ratio = math.max(0, enemy.hp / enemy.maxHp)
        love.graphics.setColor(0.05, 0.05, 0.08, 0.8)
        love.graphics.rectangle("fill", enemy.x - enemy.r, enemy.y - enemy.r - 10, enemy.r * 2, 4)
        love.graphics.setColor(1.0, 0.95, 0.3, 0.9)
        love.graphics.rectangle("fill", enemy.x - enemy.r, enemy.y - enemy.r - 10, enemy.r * 2 * ratio, 4)
    end
end

function EnemyManager:drawBoss()
    if not self.boss then
        return
    end

    local boss = self.boss
    love.graphics.setColor(boss.color[1], boss.color[2], boss.color[3], 0.95)
    drawHex(boss.x, boss.y, boss.r)
    
    -- Attack state visualizations
    if boss.state == "melee" then
        love.graphics.setColor(1, 0.5, 0, 0.5)
        love.graphics.circle("line", boss.x, boss.y, boss.r * 2.5 + math.sin(love.timer.getTime() * 20) * 10)
    elseif boss.state == "ranged" then
        love.graphics.setColor(0, 0.7, 1, 0.5)
        love.graphics.circle("line", boss.x, boss.y, boss.r + 20 + math.sin(love.timer.getTime() * 15) * 5)
    elseif boss.state == "aoe" then
        love.graphics.setColor(1, 0.3, 0.3, 0.6)
        love.graphics.circle("line", boss.x, boss.y, boss.r * 4 + math.sin(love.timer.getTime() * 10) * 20)
    end

    love.graphics.setColor(1, 1, 1, 0.22)
    love.graphics.circle("line", boss.x, boss.y, boss.r + 12)

    local barW = 520
    local barX = (love.graphics.getWidth() - barW) * 0.5
    love.graphics.setColor(0.08, 0.05, 0.12, 0.9)
    love.graphics.rectangle("fill", barX, 56, barW, 14, 4, 4)
    love.graphics.setColor(1.0, 0.25, 0.95, 1)
    love.graphics.rectangle("fill", barX, 56, barW * math.max(0, boss.hp / boss.maxHp), 14, 4, 4)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.rectangle("line", barX, 56, barW, 14, 4, 4)
    love.graphics.printf("PRISM WARDEN", 0, 34, love.graphics.getWidth(), "center")
end

function EnemyManager:draw()
    for _, enemy in ipairs(self.enemies) do
        self:drawEnemy(enemy)
    end
    self:drawBoss()
    love.graphics.setColor(1, 1, 1, 1)
end

return EnemyManager
