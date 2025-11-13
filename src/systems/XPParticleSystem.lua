-- XPParticleSystem.lua
-- Particle-based XP orbs with magnetic collection

local XPParticleSystem = {}
XPParticleSystem.__index = XPParticleSystem

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
    -- Draw sonar pulse ring (thinner, more subtle)
    if self.pulseAlpha > 0 then
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.pulseAlpha * 0.4)  -- More transparent
        love.graphics.setLineWidth(2)  -- Thinner line
        love.graphics.circle("line", self.x, self.y, self.pulseRadius)
    end
    
    -- Draw core dodecagon with subtle glow
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.2)  -- Less glow
    love.graphics.circle("fill", self.x, self.y, self.coreSize + 3)
    
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 1.0)
    
    -- Draw 12-sided dodecagon for the core
    local vertices = {}
    for i = 0, 11 do
        local angle = (i / 12) * math.pi * 2
        table.insert(vertices, self.x + math.cos(angle) * self.coreSize)
        table.insert(vertices, self.y + math.sin(angle) * self.coreSize)
    end
    love.graphics.polygon("fill", vertices)
    
    -- Draw bright center
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", self.x, self.y, self.coreSize * 0.5)
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    
    -- Debug: Show collision circle
    if debugMode then
        love.graphics.setColor(0, 1, 0, 0.3)
        love.graphics.circle("fill", self.x, self.y, self.collisionRadius)
        love.graphics.setColor(0, 1, 0, 0.1)
        love.graphics.circle("line", self.x, self.y, self.magnetRadius)
    end
end

return XPParticleSystem
