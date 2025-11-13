-- Drop.lua
-- Base class for collectible items (XP orbs, powerups, etc.)
-- Uses inheritance to reduce code duplication

local entity = require("src.entities.Entity")
local Drop = entity:derive("Drop")

function Drop:new(x, y, value, type)
    self.x = x
    self.y = y
    self.value = value or 1  -- XP amount or powerup type
    self.type = type or "drop"
    self.width = 16
    self.height = 16

    -- Physics
    self.vx = 0
    self.vy = 0
    self.friction = 0.85

    -- Magnet behavior
    self.magnetized = false
    self.magnetSpeed = 300
    self.magnetRange = 150  -- Distance at which drop starts moving toward player

    -- Lifetime
    self.age = 0
    self.maxAge = 30  -- Despawn after 30 seconds
    self.dead = false

    -- Visual
    self.floatOffset = math.random() * math.pi * 2  -- Random phase for bobbing
    self.floatSpeed = 2
    self.floatAmplitude = 4
end

function Drop:update(dt, player)
    self.age = self.age + dt

    -- Despawn if too old
    if self.age > self.maxAge then
        self.dead = true
        return
    end

    -- Check if player is in magnet range
    if player and not player.dead then
        local dx = player.x + player.width / 2 - (self.x + self.width / 2)
        local dy = player.y + player.height / 2 - (self.y + self.height / 2)
        local distance = math.sqrt(dx * dx + dy * dy)

        -- Magnetize if in range
        if distance < self.magnetRange then
            self.magnetized = true
        end

        -- Move toward player if magnetized
        if self.magnetized and distance > 5 then
            local angle = math.atan(dy, dx)
            self.vx = math.cos(angle) * self.magnetSpeed
            self.vy = math.sin(angle) * self.magnetSpeed
        elseif self.magnetized and distance <= 5 then
            -- Close enough - mark for collection
            return true  -- Signal to caller that drop was collected
        end
    end

    -- Apply velocity
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Apply friction if not magnetized
    if not self.magnetized then
        self.vx = self.vx * self.friction
        self.vy = self.vy * self.friction
    end

    -- Keep in bounds (optional - drops can go off-screen)
    -- self.x = math.max(0, math.min(1920 - self.width, self.x))
    -- self.y = math.max(0, math.min(1080 - self.height, self.y))

    return false  -- Not collected yet
end

function Drop:draw()
    -- Base draw method - override in subclasses
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
end

-- Check collision with player
function Drop:collidesWith(player)
    return self.x < player.x + player.width and
           self.x + self.width > player.x and
           self.y < player.y + player.height and
           self.y + self.height > player.y
end

-- Get center position
function Drop:getCenter()
    return self.x + self.width / 2, self.y + self.height / 2
end

-- Apply initial velocity (for spawning)
function Drop:applyVelocity(vx, vy)
    self.vx = vx
    self.vy = vy
end

return Drop
