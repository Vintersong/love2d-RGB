-- XPParticleSystem.lua
-- Particle-based XP orbs with magnetic collection

local XPParticleSystem = {}
XPParticleSystem.__index = XPParticleSystem
local ShapeLibrary = require("src.render.ShapeLibrary")

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
    orb.collisionRadius = 14

    -- Magnetic pull
    orb.magnetRadius = 220
    orb.pullSpeed = 420

    -- Sonar pulse effect
    orb.pulseTimer = 0
    orb.pulseInterval = 0.5   -- Pulse every 0.5s (was 1.0)
    orb.pulseRadius = 0
    orb.pulseAlpha = 0
    orb.maxPulseRadius = 45   -- Was 20 - much more visible

    -- Slow rotation for visual interest
    orb.rotation = math.random() * math.pi * 2
    orb.rotSpeed = (math.random() < 0.5 and 1 or -1) * (0.8 + math.random() * 0.6)

    -- Set color and size based on value tier
    if value >= 40 then
        -- Large orb: bright magenta
        orb.color     = {1.0, 0.3, 1.0}
        orb.coreSize  = 14   -- was 10
        orb.tier      = "large"
    elseif value >= 20 then
        -- Medium orb: vivid cyan
        orb.color     = {0.0, 1.0, 1.0}
        orb.coreSize  = 11   -- was 8
        orb.tier      = "medium"
    else
        -- Small orb: punchy lime green (was muted 0.4,1,0.6)
        orb.color     = {0.2, 1.0, 0.3}
        orb.coreSize  = 9    -- was 7
        orb.tier      = "small"
    end

    return orb
end

function XPParticleSystem:update(dt, playerX, playerY)
    -- Rotate
    self.rotation = self.rotation + self.rotSpeed * dt

    -- Update sonar pulse
    self.pulseTimer = self.pulseTimer + dt

    if self.pulseTimer >= self.pulseInterval then
        self.pulseTimer = 0
        self.pulseRadius = 0
        self.pulseAlpha = 1.0
    end

    -- Expand pulse
    if self.pulseAlpha > 0 then
        self.pulseRadius = self.pulseRadius + 110 * dt  -- faster expansion (was 80)
        self.pulseAlpha  = math.max(0, self.pulseAlpha - 2.2 * dt)

        if self.pulseRadius >= self.maxPulseRadius then
            self.pulseAlpha = 0
        end
    end

    -- Calculate distance to player
    local dx   = playerX - self.x
    local dy   = playerY - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    -- Magnetic pull when in range
    if dist < self.magnetRadius and dist > 0 then
        local pullStrength = 1.0 - (dist / self.magnetRadius)
        local velocity     = self.pullSpeed * pullStrength

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
    local c = self.color

    -- 1. Outer pulse ring
    if self.pulseAlpha > 0 then
        ShapeLibrary.sonarRing(self.x, self.y, self.pulseRadius, c, self.pulseAlpha, { lineWidth = 2 })
    end

    -- 2. Wide soft glow (2 layers, was 1)
    ShapeLibrary.glow(self.x, self.y, self.coreSize, c, {
        layers    = 2,
        expansion = 5,   -- was 3
        baseAlpha = 0.3  -- was 0.2
    })

    -- 3. Outer outline ring for pop against dark/busy backgrounds
    local outlineSize = self.coreSize + 3
    love.graphics.setColor(c[1], c[2], c[3], 0.55)
    love.graphics.setLineWidth(1.5)
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.rotation)
    local verts = {}
    for i = 0, 11 do
        local angle = (i / 12) * math.pi * 2
        table.insert(verts, math.cos(angle) * outlineSize)
        table.insert(verts, math.sin(angle) * outlineSize)
    end
    love.graphics.polygon("line", verts)
    love.graphics.pop()
    love.graphics.setLineWidth(1)

    -- 4. Filled dodecagon body (rotated)
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.rotation)
    local bodyVerts = {}
    for i = 0, 11 do
        local angle = (i / 12) * math.pi * 2
        table.insert(bodyVerts, math.cos(angle) * self.coreSize)
        table.insert(bodyVerts, math.sin(angle) * self.coreSize)
    end
    love.graphics.setColor(c[1], c[2], c[3], 0.85)
    love.graphics.polygon("fill", bodyVerts)
    love.graphics.pop()

    -- 5. Bright white core
    local coreInner = self.coreSize * 0.45
    love.graphics.setColor(1, 1, 1, 0.92)
    love.graphics.circle("fill", self.x, self.y, coreInner)

    -- 6. Tiny colored inner dot for tier identification
    love.graphics.setColor(c[1], c[2], c[3], 1.0)
    love.graphics.circle("fill", self.x, self.y, coreInner * 0.45)

    -- Debug: show collision/magnet circles
    if debugMode then
        love.graphics.setColor(0, 1, 0, 0.3)
        love.graphics.circle("fill", self.x, self.y, self.collisionRadius)
        love.graphics.setColor(0, 1, 0, 0.1)
        love.graphics.circle("line", self.x, self.y, self.magnetRadius)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return XPParticleSystem
