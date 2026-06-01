local class = require("libs.hump-master.class")
local Entity = require("src.entities.Entity")
local Projectile = class{__includes = Entity}
local ShapeLibrary = require("src.render.ShapeLibrary")
local MathUtils = require("src.utils.MathUtils")
local GameConfig = require("src.core.GameConfig")
local Config = require("src.Config")

local BOSS_ROT_SPEEDS = {
    boss_diamond = 4.0,
    boss_orb     = 3.0,
    boss_shard   = 2.5,
    boss_cross   = 2.0,
    boss_twinorb = 2.0,
    boss_petal   = 1.0,
}

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
    self.trailLength = 18
    self.rotation = 0
    self.innerRotation = 0
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

    -- Boss projectile rotation
    local rs = BOSS_ROT_SPEEDS[self.type]
    if rs then
        self.rotation = self.rotation + rs * dt
    end
    if self.type == "boss_twinorb" then
        self.innerRotation = self.innerRotation - 3.5 * dt
    end
end

function Projectile:draw()
    if self.dead then return end
    
    local color = self.color or {1, 1, 1}
    local size = self.size or 4
    
    -- Two-pass neon trail
    if #self.trail > 1 then
        local r, g, b = color[1], color[2], color[3]
        local len = #self.trail

        -- Pass 1: wide glow (additive blend)
        love.graphics.setBlendMode("add")
        for i = 2, len do
            local t = 1 - (i - 1) / len
            love.graphics.setColor(r, g, b, t * 0.18)
            love.graphics.setLineWidth(t * 10)
            love.graphics.line(
                self.trail[i-1].x, self.trail[i-1].y,
                self.trail[i].x,   self.trail[i].y
            )
        end
        love.graphics.setBlendMode("alpha")

        -- Pass 2: sharp neon line
        for i = 2, len do
            local t = 1 - (i - 1) / len
            love.graphics.setColor(r, g, b, t * 0.85)
            love.graphics.setLineWidth(t * 2.5)
            love.graphics.line(
                self.trail[i-1].x, self.trail[i-1].y,
                self.trail[i].x,   self.trail[i].y
            )
        end
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")

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

    elseif self.type == "boss_diamond" then
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.rotation)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(color[1], color[2], color[3], 0.3)
        love.graphics.polygon("fill", 0,-9, 9,0, 0,9, -9,0)
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.polygon("line", 0,-7, 7,0, 0,7, -7,0)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", 0, 0, 2)
        love.graphics.pop()

    elseif self.type == "boss_bolt" then
        local angle = MathUtils.atan2(self.vy, self.vx) + math.pi * 0.5
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(angle)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.polygon("line", 0,-10, 3,-2, 2,10, -2,10, -3,-2)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(color[1], color[2], color[3], 0.35)
        love.graphics.ellipse("fill", 0, 0, 2.5, 7)
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", 0, 0, 1.5)
        love.graphics.pop()

    elseif self.type == "boss_orb" then
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.rotation)
        love.graphics.setColor(color[1], color[2], color[3], 0.9)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", 0, 0, 6)
        love.graphics.setColor(color[1], color[2], color[3], 0.6)
        love.graphics.circle("line", 0, 0, 3)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.circle("fill", 0, 0, 1.5)
        love.graphics.pop()

    elseif self.type == "boss_shard" then
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.rotation)
        local verts = {}
        for k = 0, 7 do
            local a = (k / 8) * math.pi * 2
            local r2 = (k % 2 == 0) and 8 or 3.5
            table.insert(verts, math.cos(a) * r2)
            table.insert(verts, math.sin(a) * r2)
        end
        love.graphics.setBlendMode("add")
        love.graphics.setColor(color[1], color[2], color[3], 0.2)
        love.graphics.polygon("fill", verts)
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.polygon("line", verts)
        love.graphics.pop()

    elseif self.type == "boss_crescent" then
        local angle = MathUtils.atan2(self.vy, self.vx)
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(angle)
        love.graphics.setColor(color[1], color[2], color[3], 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", 0, 0, 7, 0.5, math.pi - 0.5)
        love.graphics.arc("line", "open", 3, 0, 5, math.pi + 0.35, math.pi * 2 - 0.35)
        love.graphics.pop()

    elseif self.type == "boss_cross" then
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.rotation)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.rectangle("fill", -1.5, -9, 3, 18)
        love.graphics.rectangle("fill", -9, -1.5, 18, 3)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.circle("fill", 0, 0, 2)
        love.graphics.pop()

    elseif self.type == "boss_chevron" then
        local angle = MathUtils.atan2(self.vy, self.vx)
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(angle)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(-6, 5, 0, -8)
        love.graphics.line(0, -8, 6, 5)
        love.graphics.setLineWidth(1.5)
        love.graphics.setColor(color[1], color[2], color[3], 0.6)
        love.graphics.line(-4, 10, 0, 1)
        love.graphics.line(0, 1, 4, 10)
        love.graphics.pop()

    elseif self.type == "boss_twinorb" then
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.rotation)
        love.graphics.setColor(color[1], color[2], color[3], 0.9)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", 0, 0, 7)
        local ir = (self.innerRotation or 0) - self.rotation
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", math.cos(ir) * 4,           math.sin(ir) * 4,           2)
        love.graphics.circle("fill", math.cos(ir + math.pi) * 4, math.sin(ir + math.pi) * 4, 2)
        love.graphics.pop()

    elseif self.type == "boss_petal" then
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.rotation)
        love.graphics.setColor(color[1], color[2], color[3], 0.85)
        love.graphics.setLineWidth(1.5)
        for k = 0, 5 do
            local a = (k / 6) * math.pi * 2
            love.graphics.push()
            love.graphics.rotate(a)
            love.graphics.ellipse("line", 0, -5, 2.5, 4.5)
            love.graphics.pop()
        end
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("fill", 0, 0, 2)
        love.graphics.pop()

    else
        -- DEFAULT: Simple circle with bright core
        ShapeLibrary.circle(self.x, self.y, size, color, {
            core = {size = size * 0.5, color = {1, 1, 1}, alpha = 0.8}
        })
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
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
