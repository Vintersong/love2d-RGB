-- BossSystem.lua
-- Boss encounter every 20 waves

local BossSystem = {}
BossSystem.__index = BossSystem
local BossBehaviors = require("src.data.BossBehaviors")
local BehaviorSelector = require("src.combat.BehaviorSelector")
local MathUtils = require("src.utils.MathUtils")

-- Canonical spawn policy is kill-based via SpawnController.
-- Wave-based spawn fields are retired to avoid dual policy drift.
BossSystem.activeBoss = nil

-- Boss colors (replaced palette dependency)
local BOSS_COLOR = {1, 0.2, 0.8}  -- Neon pink
local WHITE_COLOR = {1, 1, 1}

function BossSystem.init()
    -- Setup boss ship color via GameConfig
    local GameConfig = require("src.core.GameConfig")
    GameConfig.currentShipColor = BOSS_COLOR
end


function BossSystem.clearBossReferences(boss)
    if not boss then return end

    boss._playerRef = nil
    boss._bossProjectiles = nil
    boss._scheduledProjectiles = nil
    boss._scheduler = nil
end

function BossSystem.reset()
    BossSystem.clearBossReferences(BossSystem.activeBoss)
    BossSystem.activeBoss = nil
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

    -- Archetype behavior AI
    boss.archetypeName = BossBehaviors.randomArchetype()
    boss.behaviorState = "idle" -- idle, attacking
    boss.behaviorTimer = 0
    boss._behaviorCooldowns = {}
    boss.dashVx = 0
    boss.dashVy = 0
    boss.dashTimer = 0
    boss.combatTime = 0

    -- Delayed projectile scheduler for boss patterns (spiral, cross, etc.)
    boss._scheduledProjectiles = {}
    boss._scheduler = {
        schedule = function(delay, projData)
            table.insert(boss._scheduledProjectiles, {
                delay = delay,
                data = projData,
            })
        end,
    }

    -- Appearance
    boss.scale = 0.4 -- Scale of ship sprite
    boss.glowIntensity = 0
    
    BossSystem.activeBoss = boss
    
    -- Announcement (FloatingTextSystem will be called from main.lua)
    return boss
end

function BossSystem:update(dt, playerX, playerY)
    if self.phase == "entering" then
        local behavior = BossBehaviors.getById("enter_from_top")
        if behavior and behavior.update then
            behavior.update(self, dt, BehaviorSelector.buildContext(self, {playerX = playerX, playerY = playerY}))
        end
        
    elseif self.phase == "combat" then
        self.combatTime = (self.combatTime or 0) + dt
        BehaviorSelector.updateCooldowns(self, dt)

        local context = BehaviorSelector.buildContext(self, {
            player = self._playerRef,
            playerX = playerX,
            playerY = playerY,
            bossProjectiles = self._bossProjectiles or {},
            scheduler = self._scheduler,
            bossPhase = self.phase,
            combatTime = self.combatTime,
            musicReactor = self._musicReactor,
        })

        local movement = self._currentMovementBehavior
        if not movement or (movement.canRun and not movement.canRun(self, context)) then
            movement = BehaviorSelector.select(
                BossBehaviors.listByKind("movement"),
                "movement",
                "boss",
                self,
                context
            ) or BossBehaviors.getById("horizontal_oscillate")
        end
        BehaviorSelector.setMovement(self, movement, context)
        if self._currentMovementBehavior and self._currentMovementBehavior.update then
            self._currentMovementBehavior.update(self, dt, context)
        end

        local lowHealthPhase = BossBehaviors.getById("phase_low_health")
        if lowHealthPhase and lowHealthPhase.canRun and lowHealthPhase.canRun(self, context) then
            BehaviorSelector.execute(self, lowHealthPhase, context)
        end

        self.behaviorTimer = self.behaviorTimer - dt
        if self.behaviorTimer <= 0 then
            local phaseBehavior = BehaviorSelector.select(
                BossBehaviors.listByKind("phase"),
                "phase",
                "boss",
                self,
                context,
                {allowedIds = BossBehaviors.getAllowedIds(self.archetypeName, "phase")}
            )
            local attackBehavior = BehaviorSelector.select(
                BossBehaviors.listByKind("attack"),
                "attack",
                "boss",
                self,
                context,
                {allowedIds = BossBehaviors.getAllowedIds(self.archetypeName, "attack")}
            )

            local behavior = phaseBehavior or attackBehavior
            if behavior then
                self.behaviorTimer = BehaviorSelector.execute(self, behavior, context) or self.attackRate or 0.8
            else
                self.behaviorTimer = 0.3
            end
        end

        -- Process delayed pattern projectiles (spiral/cross staggered spawns)
        if self._scheduledProjectiles and #self._scheduledProjectiles > 0 then
            local Projectile = require("src.entities.Projectile")
            local projectiles = self._bossProjectiles or {}
            for i = #self._scheduledProjectiles, 1, -1 do
                local entry = self._scheduledProjectiles[i]
                entry.delay = entry.delay - dt
                if entry.delay <= 0 then
                    local p = entry.data
                    local proj = Projectile(p.x, p.y, p.vx, p.vy, p.damage or 10, "spread", "boss")
                    proj.color = p.color or {1.0, 0.4, 0.8}
                    table.insert(projectiles, proj)
                    table.remove(self._scheduledProjectiles, i)
                end
            end
        end

        -- Pulse glow
        self.glowIntensity = (math.sin(love.timer.getTime() * 3) + 1) / 2

        if self.hitFlash and self.hitFlash > 0 then
            self.hitFlash = self.hitFlash - dt
        end

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
            BossSystem.clearBossReferences(self)
            BossSystem.activeBoss = nil
        end
    end
end

function BossSystem:fireCone(targetX, targetY)
    -- Calculate angle to player
    local baseAngle = MathUtils.angleBetween(self.x, self.y, targetX, targetY)
    
    -- Fire 5 projectiles in a cone
    local Projectile = require("src.entities.Projectile")
    local projectiles = {}
    
    for i = -2, 2 do
        local angle = baseAngle + (i * 0.15)  -- 0.15 radian spread
        local speed = 300
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        
        local proj = Projectile(self.x, self.y, vx, vy, 30, "boss_bolt", "boss")
        proj.color = {1, 0.2, 0.7}  -- Neon pink
        table.insert(projectiles, proj)
    end
    
    return projectiles
end

function BossSystem:takeDamage(amount, colorName)
    if self.invulnerable then return end

    -- Color affinity (bonus-only): a projectile matching this archetype's weak
    -- color deals bonus damage. Regular enemies never reach this path, so they
    -- stay affinity-free by design. See Config.boss.affinity.
    if colorName then
        local Config = require("src.Config")
        local affinity = Config.boss and Config.boss.affinity
        if affinity and affinity.weak and affinity.weak[self.archetypeName] == colorName then
            amount = amount * (affinity.bonus or 1)
        end
    end

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
    local FloatingTextSystem = require("src.effects.FloatingTextSystem")
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
    
    local healthPercent = math.max(0, self.health / self.maxHealth)
    
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
