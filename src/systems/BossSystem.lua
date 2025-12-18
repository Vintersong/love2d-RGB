-- BossSystem.lua
-- Boss encounter every 20 waves

local BossSystem = {}
BossSystem.__index = BossSystem

-- Boss spawns every 20 waves
BossSystem.SPAWN_INTERVAL = 20
BossSystem.currentWave = 0
BossSystem.activeBoss = nil

-- Boss colors (replaced palette dependency)
local BOSS_COLOR = {1, 0.2, 0.8}  -- Neon pink
local WHITE_COLOR = {1, 1, 1}

function BossSystem.init()
    -- Setup boss ship color via GameConfig
    local GameConfig = require("src.systems.GameConfig")
    GameConfig.currentShipColor = BOSS_COLOR
end

function BossSystem.checkSpawn(waveNumber)
    BossSystem.currentWave = waveNumber
    
    if waveNumber % BossSystem.SPAWN_INTERVAL == 0 and not BossSystem.activeBoss then
        return BossSystem.spawnBoss()
    end
    return nil
end

function BossSystem.spawnBoss()
    local boss = setmetatable({}, BossSystem)
    
    -- Position (spawn at top center)
    boss.x = love.graphics.getWidth() / 2
    boss.y = -200 -- Start off-screen
    boss.targetY = 150 -- Move to this Y position
    
    -- Stats
    boss.health = 2000
    boss.maxHealth = 2000
    boss.damage = 30
    boss.speed = 80 -- Slow movement
    boss.size = 150 -- Collision radius
    
    -- Combat
    boss.attackCooldown = 0
    boss.attackRate = 0.8 -- Attack every 0.8 seconds
    boss.coneAngle = math.pi / 3 -- 60 degree cone
    boss.projectileCount = 5 -- Projectiles per cone
    
    -- State
    boss.phase = "entering" -- entering, combat, defeated
    boss.alive = true
    boss.invulnerable = true -- Invuln during entrance
    
    -- Appearance
    boss.scale = 0.4 -- Scale of ship sprite
    boss.glowIntensity = 0
    
    BossSystem.activeBoss = boss
    
    -- Announcement (FloatingTextSystem will be called from main.lua)
    return boss
end

function BossSystem:update(dt, playerX, playerY)
    if self.phase == "entering" then
        -- Move to combat position
        self.y = self.y + self.speed * dt
        
        if self.y >= self.targetY then
            self.y = self.targetY
            self.phase = "combat"
            self.invulnerable = false
            -- FloatingText announcement will be handled by main.lua
        end
        
    elseif self.phase == "combat" then
        -- Follow player horizontally (slowly)
        local dx = playerX - self.x
        if math.abs(dx) > 50 then
            self.x = self.x + math.sign(dx) * self.speed * dt
        end
        
        -- Stay in bounds
        local margin = 100
        if self.x < margin then self.x = margin end
        if self.x > love.graphics.getWidth() - margin then 
            self.x = love.graphics.getWidth() - margin 
        end
        
        -- Attack pattern: Cone shots toward player
        self.attackCooldown = self.attackCooldown - dt
        if self.attackCooldown <= 0 then
            local newProjectiles = self:fireCone(playerX, playerY)
            self.attackCooldown = self.attackRate
            return newProjectiles  -- Return projectiles to be added to game
        end
        
        -- Pulse glow
        self.glowIntensity = (math.sin(love.timer.getTime() * 3) + 1) / 2
        
        -- Check death
        if self.health <= 0 then
            self.phase = "defeated"
        end
        
    elseif self.phase == "defeated" then
        -- Death animation: fall off screen
        self.y = self.y + 200 * dt
        
        if self.y > love.graphics.getHeight() + 200 then
            self:onDefeat()
            self.alive = false
            BossSystem.activeBoss = nil
        end
    end
end

function BossSystem:fireCone(targetX, targetY)
    -- Calculate angle to player
    local baseAngle = math.atan(targetY - self.y, targetX - self.x)
    
    -- Fire 5 projectiles in a cone
    local Projectile = require("src.entities.Projectile")
    local projectiles = {}
    
    for i = -2, 2 do
        local angle = baseAngle + (i * 0.15)  -- 0.15 radian spread
        local speed = 300
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        
        local proj = Projectile(self.x, self.y, vx, vy, 30, "spread", "boss")
        proj.color = {1, 0.2, 0.7}  -- Neon pink
        table.insert(projectiles, proj)
    end
    
    return projectiles
end

function BossSystem:takeDamage(amount)
    if self.invulnerable then return end
    
    self.health = self.health - amount
    
    -- Visual feedback - simplified (no VFX system integration yet)
    -- VFX:spawnHitEffect(self.x, self.y, WHITE_COLOR)
    
    -- Screen shake on hit - commented out (no Camera system)
    -- Camera:shake(0.1, 5)
    
    -- Health bar flash
    self.hitFlash = 0.2
end

function BossSystem:onDefeat()
    -- Drop special powerups instead of Color Matrix
    -- Spawn multiple powerups at boss location
    for i = 1, 3 do
        local angle = (i / 3) * math.pi * 2
        local dist = 50
        local px = self.x + math.cos(angle) * dist
        local py = self.y + math.sin(angle) * dist
        -- Note: Powerups will be spawned by the game's powerup system
    end
    
    -- Explosion effects
    for i = 1, 12 do
        local angle = (i / 12) * math.pi * 2
        local dist = math.random(30, 80)
        -- VFX:spawnExplosion would need to be integrated
        -- For now, just visual feedback
    end
    
    -- Announcement
    FloatingTextSystem = require("src.systems.FloatingTextSystem")
    FloatingTextSystem.add("⚡ BOSS DEFEATED ⚡", love.graphics.getWidth()/2, love.graphics.getHeight()/2, "BOSS")
end

function BossSystem:draw()
    -- Draw boss ship
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.scale(self.scale, self.scale)
    
    -- Glow effect when damaged
    if self.hitFlash and self.hitFlash > 0 then
        love.graphics.setColor(1, 1, 1, self.hitFlash * 2)
        self.hitFlash = self.hitFlash - love.timer.getDelta()
    end
    
    -- Draw boss as large diamond/star shape
    love.graphics.setColor(BOSS_COLOR)
    
    -- Draw diamond body
    local points = {
        0, -self.size,        -- Top
        self.size, 0,         -- Right
        0, self.size,         -- Bottom
        -self.size, 0         -- Left
    }
    love.graphics.polygon("fill", points)
    
    -- Draw outline
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setLineWidth(3)
    love.graphics.polygon("line", points)
    
    -- Draw core glow
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.circle("fill", 0, 0, self.size * 0.3)
    
    love.graphics.pop()
    
    -- Health bar
    self:drawHealthBar()
    
    -- Debug: Collision circle
    local DEBUG_MODE = false  -- Set to true for debug visualization
    if DEBUG_MODE then
        love.graphics.setColor(1, 0, 0, 0.3)
        love.graphics.circle("line", self.x, self.y, self.size)
    end
end

function BossSystem:drawHealthBar()
    local barWidth = 400
    local barHeight = 20
    local barX = love.graphics.getWidth()/2 - barWidth/2
    local barY = 30
    
    local healthPercent = self.health / self.maxHealth
    
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX - 2, barY - 2, barWidth + 4, barHeight + 4)
    
    -- Health bar (gradient from green to red)
    local r = 1.0 - healthPercent
    local g = healthPercent
    love.graphics.setColor(r, g, 0.2, 0.9)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)
    
    -- Border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
    
    -- Text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        "BOSS: " .. math.floor(self.health) .. " / " .. self.maxHealth,
        barX, barY + 2, barWidth, "center"
    )
end

-- Helper
function math.sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end

return BossSystem
