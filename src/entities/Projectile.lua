local class = require("libs.hump-master.class")
local Entity = require("src.entities.Entity")
local Projectile = class{__includes = Entity}
local ShapeLibrary = require("src.render.ShapeLibrary")
local MathUtils = require("src.utils.MathUtils")
local GameConfig = require("src.core.GameConfig")
local Config = require("src.Config")

local function getScreenSize()
    local w, h = GameConfig.getScreenSize()
    return w or Config.screen.width, h or Config.screen.height
end

function Projectile:init(x, y, vx, vy, damage, projType, owner)
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
    
    -- Check bounds
    local screenWidth, screenHeight = getScreenSize()
    
    if self.x < -10 or self.x > screenWidth + 10 or
       self.y < -10 or self.y > screenHeight + 10 then
        self.dead = true
    end
end

function Projectile:draw()
    if self.dead then return end
    
    local color = self.color or {1, 1, 1}
    local size = self.size or 4
    
    -- Draw trail using ShapeLibrary
    ShapeLibrary.trail(self.trail, size, color, {fadeAlpha = 0.5})
    
    -- Draw projectile based on type using ShapeLibrary
    if self.type == "spread" then
        -- HYDROGEN ATOM
        ShapeLibrary.atom(self.x, self.y, size, color, {
            age = self.age,
            orbitSpeed = 8,
            uniqueSeed = self.x + self.y
        })
        
    elseif self.type == "ricochet" then
        -- CRESCENT MOON
        local angle = MathUtils.atan2(self.vy, self.vx)
        ShapeLibrary.crescent(self.x, self.y, size, color, {
            angle = angle,
            outlineWidth = 1
        })
        
    elseif self.type == "pierce" then
        -- ISOSCELES TRIANGLE
        local angle = MathUtils.atan2(self.vy, self.vx) + math.pi/2
        ShapeLibrary.triangle(self.x, self.y, size, color, {
            rotation = angle,
            outline = {1, 1, 1, 0.5},
            outlineWidth = 1
        })
        
    else
        -- DEFAULT: Simple circle with bright core
        ShapeLibrary.circle(self.x, self.y, size, color, {
            core = {size = size * 0.5, color = {1, 1, 1}, alpha = 0.8}
        })
    end
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
