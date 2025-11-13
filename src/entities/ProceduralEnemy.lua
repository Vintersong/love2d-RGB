-- ProceduralEnemy: Enemy with randomized abilities and affinity
local entity = require("src.entities.Entity")
local EnemyAbilities = require("src.components.EnemyAbilities")
local ProceduralEnemy = entity:derive("ProceduralEnemy")

function ProceduralEnemy:new(x, y, level, config)
    self.x = x or 0
    self.y = y or 0
    self.width = 24
    self.height = 24
    self.level = level or 1
    self.dead = false
    self.age = 0
    
    -- Use provided config or generate random
    config = config or EnemyAbilities.generateRandom(level)
    
    -- Apply affinity
    self.affinity = config.affinity or "NEUTRAL"
    local affinityData = EnemyAbilities.Affinities[self.affinity]
    self.color = affinityData.color
    self.resistance = affinityData.resistance
    self.weakness = affinityData.weakness
    self.projectileColor = affinityData.projectileColor
    
    -- Apply attack pattern
    self.attackPatternName = config.attackPattern or "STRAIGHT"
    self.attackPattern = EnemyAbilities.AttackPatterns[self.attackPatternName]
    self.attackCooldown = 0
    self.projectiles = {}  -- Enemy projectiles
    
    -- Apply movement behavior
    self.movementBehaviorName = config.movementBehavior or "CHASE"
    self.movementBehavior = EnemyAbilities.MovementBehaviors[self.movementBehaviorName]
    
    -- Base stats (scaled by level and config)
    self.speed = 50 * (config.speedMultiplier or 1) * self.movementBehavior.speedMultiplier
    self.hp = math.floor(50 * (config.hpMultiplier or 1))
    self.maxHp = self.hp
    self.damage = math.floor(20 * (config.damageMultiplier or 1))
    self.expReward = math.floor(30 + (level * 5))
    
    -- Visual
    self.shape = "square"  -- Can be extended with more shapes
    self.vx = 0
    self.vy = 0
    
    -- Effects
    self.teleportFlash = 0
    self.spiralAngle = math.random() * math.pi * 2
end

function ProceduralEnemy:update(dt, playerX, playerY)
    if self.dead then return end
    
    self.age = self.age + dt
    
    -- Update movement using behavior
    if self.movementBehavior and self.movementBehavior.update then
        self.movementBehavior.update(self, dt, playerX, playerY)
    end
    
    -- Apply velocity
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    
    -- Update attack cooldown
    self.attackCooldown = self.attackCooldown - dt
    
    -- Attack when ready (only if this enemy can shoot)
    if self.attackCooldown <= 0 and self.attackPattern and self.attackPattern.canShoot then
        self:attack(playerX, playerY)
        self.attackCooldown = self.attackPattern.cooldown
    end
    
    -- Update projectiles
    for i = #self.projectiles, 1, -1 do
        local proj = self.projectiles[i]
        proj.x = proj.x + proj.vx * dt
        proj.y = proj.y + proj.vy * dt
        proj.lifetime = proj.lifetime - dt
        
        -- Remove expired projectiles
        if proj.lifetime <= 0 then
            table.remove(self.projectiles, i)
        end
    end
    
    -- Update visual effects
    if self.teleportFlash then
        self.teleportFlash = self.teleportFlash - dt
        if self.teleportFlash <= 0 then
            self.teleportFlash = nil
        end
    end
end

function ProceduralEnemy:attack(playerX, playerY)
    if not self.attackPattern or not self.attackPattern.execute then return end
    
    local projectileData = self.attackPattern.execute(self, playerX, playerY)
    
    for _, data in ipairs(projectileData) do
        local proj = {
            x = self.x + self.width / 2,
            y = self.y + self.height / 2,
            vx = data.vx,
            vy = data.vy,
            damage = self.attackPattern.damage,
            color = self.projectileColor,
            radius = 4,
            lifetime = 5.0,  -- 5 seconds
            owner = self
        }
        table.insert(self.projectiles, proj)
    end
end

function ProceduralEnemy:takeDamage(amount, projectileAffinity)
    if self.dead then return false end
    
    -- Apply resistance/weakness based on projectile affinity
    local damageMultiplier = 1.0
    
    if projectileAffinity then
        if projectileAffinity == self.affinity then
            -- Same affinity = resistance
            damageMultiplier = self.resistance
        elseif projectileAffinity == self.weakness then
            -- Weakness = extra damage
            damageMultiplier = 1.5
        end
    end
    
    self.hp = self.hp - (amount * damageMultiplier)
    
    if self.hp <= 0 then
        self.dead = true
        return true
    end
    
    return false
end

function ProceduralEnemy:draw()
    if self.dead then return end
    
    -- Draw teleport flash effect
    if self.teleportFlash then
        love.graphics.setColor(1, 1, 1, self.teleportFlash / 0.3)
        love.graphics.circle("fill", self.x + self.width / 2, self.y + self.height / 2, self.width * 1.5)
    end
    
    -- Draw enemy
    love.graphics.setColor(self.color)
    if self.shape == "square" then
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    elseif self.shape == "circle" then
        love.graphics.circle("fill", self.x + self.width / 2, self.y + self.height / 2, self.width / 2)
    end
    
    -- Draw HP bar
    local hpPercent = self.hp / self.maxHp
    love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
    love.graphics.rectangle("fill", self.x, self.y - 8, self.width, 4)
    love.graphics.setColor(0.2, 1, 0.2)
    love.graphics.rectangle("fill", self.x, self.y - 8, self.width * hpPercent, 4)
    
    -- Draw projectiles
    for _, proj in ipairs(self.projectiles) do
        love.graphics.setColor(proj.color)
        love.graphics.circle("fill", proj.x, proj.y, proj.radius)
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

function ProceduralEnemy:checkCollision(other)
    -- Handle projectile collision (projectiles have x, y but no width/height)
    if not other.width or not other.height then
        return self:checkProjectileCollision(other)
    end
    
    -- Handle entity collision (entities have x, y, width, height)
    return self.x < other.x + other.width and
           self.x + self.width > other.x and
           self.y < other.y + other.height and
           self.y + self.height > other.y
end

function ProceduralEnemy:checkProjectileCollision(playerProj)
    local ex = self.x + self.width / 2
    local ey = self.y + self.height / 2
    local px = playerProj.x
    local py = playerProj.y
    local dist = math.sqrt((ex - px) * (ex - px) + (ey - py) * (ey - py))
    return dist < (self.width / 2 + 4)  -- 4 is projectile radius
end

return ProceduralEnemy
