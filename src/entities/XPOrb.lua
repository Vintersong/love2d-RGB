-- XP Orb that drops from enemies and floats toward player when nearby
local class = require("class")
local Entity = require("src.entities.Entity")

local XPOrb = Entity:derive("XPOrb")

function XPOrb:new(x, y, value, orbType, color)
    self.x = x
    self.y = y
    self.width = 8
    self.height = 8
    self.value = value or 20
    self.orbType = orbType or "basic"  -- "basic", "primary", "secondary"
    
    -- Visual properties based on type
    if orbType == "primary" then
        self.radius = 12
        self.color = color or {1, 0.2, 0.2}
        self.glowSize = 2.0
        self.sparkles = true
    elseif orbType == "secondary" then
        self.radius = 9
        self.color = color or {0.2, 1, 0.2}
        self.glowSize = 1.5
        self.sparkles = false
    else
        self.radius = 6
        self.color = {1, 0.8, 0}  -- Yellow/gold
        self.glowSize = 1.0
        self.sparkles = false
    end
    
    self.pulseTimer = 0
    self.pulseSpeed = 4
    
    -- Movement properties
    self.floatOffsetY = 0
    self.floatSpeed = 2
    self.outerRadius = 150  -- Start drifting toward player
    self.innerRadius = 50   -- Acceleration zone
    self.baseSpeed = 50     -- Initial drift speed
    self.acceleration = 300 -- Acceleration in inner zone
    self.maxSpeed = 600     -- Terminal velocity
    self.velocityX = 0
    self.velocityY = 0
    self.collectionRadius = 20  -- Distance for collection
    
    -- Random initial float offset for variety
    self.floatPhase = math.random() * math.pi * 2
    
    self.collected = false
end

function XPOrb:update(dt, playerX, playerY)
    -- Gentle floating motion
    self.pulseTimer = self.pulseTimer + dt * self.pulseSpeed
    self.floatOffsetY = math.sin(self.pulseTimer + self.floatPhase) * 3
    
    -- Calculate distance to player
    local dx = playerX - self.x
    local dy = playerY - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Physics-based magnetic attraction
    if distance > 0 and distance < self.outerRadius then
        local angle = math.atan(dy, dx)
        local attractionForce
        
        if distance < self.innerRadius then
            -- Inner zone: Strong acceleration
            attractionForce = self.baseSpeed + self.acceleration * (1 - distance / self.innerRadius)
        else
            -- Outer zone: Gentle drift
            local outerZoneFactor = 1 - (distance - self.innerRadius) / (self.outerRadius - self.innerRadius)
            attractionForce = self.baseSpeed * outerZoneFactor
        end
        
        -- Apply force to velocity
        self.velocityX = self.velocityX + math.cos(angle) * attractionForce * dt
        self.velocityY = self.velocityY + math.sin(angle) * attractionForce * dt
        
        -- Clamp to max speed
        local currentSpeed = math.sqrt(self.velocityX * self.velocityX + self.velocityY * self.velocityY)
        if currentSpeed > self.maxSpeed then
            local scale = self.maxSpeed / currentSpeed
            self.velocityX = self.velocityX * scale
            self.velocityY = self.velocityY * scale
        end
    end
    
    -- Apply velocity
    self.x = self.x + self.velocityX * dt
    self.y = self.y + self.velocityY * dt
    
    -- Check if collected
    if distance < self.collectionRadius then
        self.collected = true
    end
end

function XPOrb:draw()
    -- Pulsing effect
    local pulseScale = 1 + math.sin(self.pulseTimer) * 0.15
    local currentRadius = self.radius * pulseScale
    
    -- Outer glow
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.3)
    love.graphics.circle("fill", self.x, self.y + self.floatOffsetY, currentRadius * self.glowSize)
    
    -- Main orb
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y + self.floatOffsetY, currentRadius)
    
    -- Core highlight
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", self.x - 2, self.y + self.floatOffsetY - 2, currentRadius * 0.4)
    
    -- Sparkles for primary orbs
    if self.sparkles then
        local sparkleRadius = currentRadius + 6
        for i = 0, 3 do
            local angle = (i / 4) * math.pi * 2 + self.pulseTimer * 2
            local sx = self.x + math.cos(angle) * sparkleRadius
            local sy = self.y + self.floatOffsetY + math.sin(angle) * sparkleRadius
            
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.circle("fill", sx, sy, 2)
        end
    end
end

function XPOrb:checkCollision(entity)
    -- Simple circle collision with entity
    local dx = self.x - (entity.x + entity.width / 2)
    local dy = self.y - (entity.y + entity.height / 2)
    local distance = math.sqrt(dx * dx + dy * dy)
    return distance < (self.radius + 15)  -- 15 is approximate player radius
end

return XPOrb
