local Weapon = require("src.Weapon")

-- SPREAD SHOT (RED path)
-- Fires 2-6 projectiles in a cone pattern
local SpreadShot = Weapon:derive("SpreadShot")

function SpreadShot:new()
    self.weaponType = "Spread Shot"
    self.name = "Spread Shot"
    self.colors = {r = 0, g = 0, b = 0}
    self.fireRate = 0.25
    self.fireTimer = 0
    self.damage = 10
    self.projectileSpeed = 350
    self.bulletCount = 2  -- Start with 2 projectiles
    self.spreadAngle = math.pi / 6 -- 30 degrees total spread
end

function SpreadShot:createProjectiles(x, y, targetX, targetY)
    local projectiles = {}
    local color = self:calculateProjectileColor()
    
    -- Calculate base angle toward target
    local baseAngle = math.atan(targetY - y, targetX - x)
    
    -- Create spread pattern around the base angle
    local halfSpread = self.spreadAngle / 2
    
    if self.bulletCount == 1 then
        -- Single bullet goes straight to target
        local proj = {
            x = x,
            y = y,
            damage = self.damage,
            speed = self.projectileSpeed,
            vx = math.cos(baseAngle) * self.projectileSpeed,
            vy = math.sin(baseAngle) * self.projectileSpeed,
            type = "spread",
            color = color,
            shape = "circle"
        }
        table.insert(projectiles, proj)
    else
        -- Multiple bullets spread evenly
        for i = 1, self.bulletCount do
            local t = (i - 1) / (self.bulletCount - 1) -- 0 to 1
            local angle = baseAngle - halfSpread + t * self.spreadAngle
            local proj = {
                x = x,
                y = y,
                damage = self.damage,
                speed = self.projectileSpeed,
                vx = math.cos(angle) * self.projectileSpeed,
                vy = math.sin(angle) * self.projectileSpeed,
                type = "spread",
                color = color,
                shape = "circle"
            }
            table.insert(projectiles, proj)
        end
    end
    
    return projectiles
end

-- RICOCHET SHOT (GREEN path)
-- Single projectile with 60-100% chance to bounce between enemies
local RicochetShot = Weapon:derive("RicochetShot")

function RicochetShot:new()
    self.weaponType = "Ricochet Shot"
    self.name = "Ricochet Shot"
    self.colors = {r = 0, g = 0, b = 0}
    self.fireRate = 0.2
    self.fireTimer = 0
    self.damage = 15  -- Higher single-target damage
    self.bulletCount = 1
    self.projectileSpeed = 400
    self.bounceChance = 0.6  -- 60% base chance
    self.maxBounces = 1
end

function RicochetShot:createProjectiles(x, y, targetX, targetY)
    local color = self:calculateProjectileColor()
    
    -- Calculate direction toward target
    local dx = targetX - x
    local dy = targetY - y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 0 then
        dx = dx / distance
        dy = dy / distance
    end
    
    local proj = {
        x = x,
        y = y,
        damage = self.damage,
        speed = self.projectileSpeed,
        vx = dx * self.projectileSpeed,
        vy = dy * self.projectileSpeed,
        type = "ricochet",
        color = color,
        shape = "circle",
        -- Bounce mechanics
        bounceChance = self.bounceChance,
        maxBounces = self.maxBounces,
        currentBounces = 0,
        lastHitEnemy = nil
    }
    
    return {proj}
end

-- PIERCE SHOT (BLUE path)
-- Single projectile with 60-100% chance to pass through enemies
local PierceShot = Weapon:derive("PierceShot")

function PierceShot:new()
    self.weaponType = "Pierce Shot"
    self.name = "Pierce Shot"
    self.colors = {r = 0, g = 0, b = 0}
    self.fireRate = 0.3
    self.fireTimer = 0
    self.damage = 20
    self.bulletCount = 1
    self.projectileSpeed = 450
    self.pierceChance = 0.6
    self.maxPierceCount = 1
end

function PierceShot:createProjectiles(x, y, targetX, targetY)
    local color = self:calculateProjectileColor()
    
    local dx = targetX - x
    local dy = targetY - y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 0 then
        dx = dx / distance
        dy = dy / distance
    end
    
    local proj = {
        x = x,
        y = y,
        damage = self.damage,
        speed = self.projectileSpeed,
        vx = dx * self.projectileSpeed,
        vy = dy * self.projectileSpeed,
        type = "pierce",
        color = color,
        shape = "circle",
        pierceChance = self.pierceChance,
        maxPierceCount = self.maxPierceCount,
        currentPierceCount = 0,
        hitEnemies = {}
    }
    
    return {proj}
end

-- Export weapon types
return {
    SpreadShot = SpreadShot,
    RicochetShot = RicochetShot,
    PierceShot = PierceShot,
    AOEBlast = PierceShot  -- Alias for backwards compatibility
}
