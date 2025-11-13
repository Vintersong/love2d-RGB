local entity = require("src.entities.Entity")
local Projectile = entity:derive("Projectile")

function Projectile:new(x, y, vx, vy, damage, projType, owner)
    self.x = x
    self.y = y
    self.vx = vx or 0
    self.vy = vy or 0
    self.damage = damage or 10
    self.type = projType or "spread"
    self.owner = owner or "player" -- "player" or "enemy"
    self.dead = false
    self.lifetime = 10 -- seconds
    self.age = 0
    
    -- Special properties
    self.piercing = 0
    self.bounces = 0
    self.explosionRadius = 0
    self.homing = false
    self.homingStrength = 0
    
    -- Pierce tracking: Prevent hitting same enemy twice
    self.hitEnemies = {}
    
    -- Visual properties
    self.size = 4  -- Base size for all projectiles
    self.color = {1, 1, 1}  -- Start white, tinted by RGB upgrades
    self.trail = {}  -- Trail of previous positions
    self.trailLength = 8
end

function Projectile:update(dt)
    if self.dead then return end
    
    self.age = self.age + dt
    
    -- Check lifetime
    if self.age >= self.lifetime then
        self.dead = true
        return
    end
    
    -- Add current position to trail
    table.insert(self.trail, 1, {x = self.x, y = self.y})
    if #self.trail > self.trailLength then
        table.remove(self.trail)
    end
    
    -- Move projectile
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    
    -- Check bounds (using constant resolution)
    local SCREEN_WIDTH = 1920
    local SCREEN_HEIGHT = 1080
    
    if self.x < -10 or self.x > SCREEN_WIDTH + 10 or 
       self.y < -10 or self.y > SCREEN_HEIGHT + 10 then
        self.dead = true
    end
end

function Projectile:draw()
    if self.dead then return end
    
    local color = self.color or {1, 1, 1}
    local size = self.size or 4
    
    -- Draw trail
    for i, pos in ipairs(self.trail) do
        local alpha = (1 - i / #self.trail) * 0.5
        love.graphics.setColor(color[1], color[2], color[3], alpha)
        local trailSize = size * (1 - i / #self.trail)
        love.graphics.circle("fill", pos.x, pos.y, trailSize)
    end
    
    -- Draw projectile based on type
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    
    if self.type == "spread" then
        -- HYDROGEN ATOM: Outer ring + core + orbiting electron
        love.graphics.setColor(color)
        
        -- Outer ring
        love.graphics.circle("line", 0, 0, size * 1.5)
        
        -- Inner core
        love.graphics.circle("fill", 0, 0, size * 0.6)
        
        -- Orbiting electron
        local angle = (self.age or 0) * 8 + (self.x + self.y) * 0.1
        local orbitRadius = size * 1.5
        local electronX = math.cos(angle) * orbitRadius
        local electronY = math.sin(angle) * orbitRadius
        love.graphics.circle("fill", electronX, electronY, size * 0.3)
        
    elseif self.type == "ricochet" then
        -- CRESCENT MOON: 180° arc facing direction of travel
        local angle = math.atan(self.vy, self.vx)
        love.graphics.rotate(angle)
        
        love.graphics.setColor(color)
        love.graphics.arc("fill", 0, 0, size, -math.pi/2, math.pi/2)
        
        -- Outline for definition
        love.graphics.setLineWidth(1)
        love.graphics.arc("line", 0, 0, size, -math.pi/2, math.pi/2)
        
    elseif self.type == "pierce" then
        -- ISOSCELES TRIANGLE: Points in direction of travel
        local angle = math.atan(self.vy, self.vx) - math.pi/2
        love.graphics.rotate(angle)
        
        love.graphics.setColor(color)
        
        -- Triangle vertices
        local vertices = {
            0, -size * 1.5,           -- Top
            -size, size * 1.5,         -- Bottom-left
            size, size * 1.5           -- Bottom-right
        }
        
        -- Fill
        love.graphics.polygon("fill", vertices)
        
        -- Outline
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", vertices)
        
    else
        -- DEFAULT: Simple circle
        love.graphics.setColor(color)
        love.graphics.circle("fill", 0, 0, size)
        
        -- Bright core
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("fill", 0, 0, size * 0.5)
    end
    
    love.graphics.pop()
end

function Projectile:bounce(normalX, normalY)
    if self.bounces <= 0 then
        self.dead = true
        return
    end
    
    -- Reflect velocity
    local dot = self.vx * normalX + self.vy * normalY
    self.vx = self.vx - 2 * dot * normalX
    self.vy = self.vy - 2 * dot * normalY
    
    self.bounces = self.bounces - 1
end

function Projectile:hit()
    if self.piercing > 0 then
        self.piercing = self.piercing - 1
        return false -- Don't die yet
    else
        self.dead = true
        return true -- Projectile is destroyed
    end
end

return Projectile
