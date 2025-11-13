-- XPParticleSystem.lua
-- Particle-based XP orbs with magnetic collection

local XPParticleSystem = {}
XPParticleSystem.__index = XPParticleSystem
local ShapeLibrary = require("src.systems.ShapeLibrary")

-- Initialize particle textures (call once on load)
function XPParticleSystem.init()
    -- No longer needed - using direct drawing instead of particles
end

-- Create new XP orb
function XPParticleSystem.new(x, y, value)
    local orb = setmetatable({}, XPParticleSystem)
    
    orb.x = x
    orb.y = y
    orb.value = value or 1
    orb.alive = true
    
    -- Collision (larger for easier pickup)
    orb.collisionRadius = 12
    
    -- Magnetic pull (stronger attraction)
    orb.magnetRadius = 200
    orb.pullSpeed = 400
    
    -- Sonar pulse effect
    orb.pulseTimer = 0
    orb.pulseInterval = 1.0  -- Pulse every 1.0 seconds (less frequent)
    orb.pulseRadius = 0
    orb.pulseAlpha = 0
    orb.maxPulseRadius = 20  -- Max radius before fading (smaller)
    
    -- Set color based on value
    if value >= 40 then
        orb.color = {1.0, 0.4, 1.0}  -- Magenta
        orb.coreSize = 10  -- Smaller cores
    elseif value >= 20 then
        orb.color = {0.0, 1.0, 1.0}  -- Cyan
        orb.coreSize = 8
    else
        orb.color = {0.4, 1.0, 0.6}  -- Green
        orb.coreSize = 7
    end
    
    return orb
end

function XPParticleSystem:update(dt, playerX, playerY)
    -- Update sonar pulse
    self.pulseTimer = self.pulseTimer + dt
    
    if self.pulseTimer >= self.pulseInterval then
        self.pulseTimer = 0
        self.pulseRadius = 0
        self.pulseAlpha = 1.0
    end
    
    -- Expand pulse
    if self.pulseAlpha > 0 then
        self.pulseRadius = self.pulseRadius + 80 * dt  -- Slower expansion
        self.pulseAlpha = math.max(0, self.pulseAlpha - 1.5 * dt)  -- Faster fade
        
        -- Stop expanding at max radius
        if self.pulseRadius >= self.maxPulseRadius then
            self.pulseAlpha = 0
        end
    end
    
    -- Calculate distance to player
    local dx = playerX - self.x
    local dy = playerY - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    
    -- Magnetic pull when in range
    if dist < self.magnetRadius and dist > 0 then
        -- Stronger pull when closer
        local pullStrength = 1.0 - (dist / self.magnetRadius)
        local velocity = self.pullSpeed * pullStrength
        
        -- Move toward player
        self.x = self.x + (dx / dist) * velocity * dt
        self.y = self.y + (dy / dist) * velocity * dt
    end
    
    -- Check collection
    if dist < self.collisionRadius then
        return self:collect()
    end
    
    return nil
end

function XPParticleSystem:collect()
    self.alive = false
    return self.value
end

function XPParticleSystem:draw(debugMode)
    -- Draw sonar pulse ring using ShapeLibrary
    if self.pulseAlpha > 0 then
        ShapeLibrary.sonarRing(self.x, self.y, self.pulseRadius, self.color, self.pulseAlpha)
    end
    
    -- Draw core dodecagon with glow using ShapeLibrary
    ShapeLibrary.glow(self.x, self.y, self.coreSize, self.color, {
        layers = 1,
        expansion = 3,
        baseAlpha = 0.2
    })
    
    ShapeLibrary.dodecagon(self.x, self.y, self.coreSize, self.color, {
        core = {size = self.coreSize * 0.5, color = {1, 1, 1}, alpha = 0.8}
    })
    
    -- Debug: Show collision circles
    if debugMode then
        love.graphics.setColor(0, 1, 0, 0.3)
        love.graphics.circle("fill", self.x, self.y, self.collisionRadius)
        love.graphics.setColor(0, 1, 0, 0.1)
        love.graphics.circle("line", self.x, self.y, self.magnetRadius)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return XPParticleSystem
