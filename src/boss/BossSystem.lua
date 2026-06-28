-- BossSystem.lua
-- Boss encounter every 20 waves

local BossSystem = {}
BossSystem.__index = BossSystem
local BossBehaviors = require("src.data.BossBehaviors")
local BossProgression = require("src.data.BossProgression")
local BehaviorSelector = require("src.combat.BehaviorSelector")
local MathUtils = require("src.utils.MathUtils")
local GameConfig = require("src.core.GameConfig")
local SimpleGrid = require("src.gameplay.SimpleGrid")
local RingBoss = require("src.patterns.RingBoss")
local PatternSpawner = require("src.combat.PatternSpawner")
local LaserBeam = require("src.combat.LaserBeam")

-- Canonical spawn policy is kill-based via SpawnController.
-- Wave-based spawn fields are retired to avoid dual policy drift.
BossSystem.activeBoss = nil
BossSystem.nextEncounterIndex = 1

-- Boss colors (replaced palette dependency)
local BOSS_COLOR = {1, 0.2, 0.8}  -- Neon pink
local WHITE_COLOR = {1, 1, 1}

function BossSystem.init()
    -- Setup boss ship color via GameConfig
    GameConfig.currentShipColor = BOSS_COLOR
end


function BossSystem.clearBossReferences(boss)
    if not boss then return end

    boss._playerRef = nil
    boss._bossProjectiles = nil
    boss._scheduledProjectiles = nil
    boss._scheduler = nil
    boss._ringLasers = nil
    boss._curtainMarkers = nil
    boss._curtainParams = nil
    boss._curtainState = nil
    boss._curtainTimer = nil
    boss._curtainCooldown = nil
    boss.ringPhaseTimer = nil
end

function BossSystem.reset()
    BossSystem.clearBossReferences(BossSystem.activeBoss)
    BossSystem.activeBoss = nil
    BossSystem.nextEncounterIndex = 1
end

function BossSystem.spawnBoss(options)
    options = options or {}
    local boss = setmetatable({}, BossSystem)
    local screenWidth, screenHeight = GameConfig.getScreenSize()
    local cellSize = SimpleGrid.cellSize or 48
    local topBandHeight = cellSize * 2
    local encounterIndex = math.max(1, math.floor(options.encounterIndex or BossSystem.nextEncounterIndex or 1))
    local tier = BossProgression.getForEncounter(encounterIndex)
    
    -- Position (spawn at top center)
    boss.x = screenWidth / 2
    boss.y = -200 -- Start off-screen
    boss.targetY = topBandHeight + math.floor(cellSize * 3.8)
    boss.minY = boss.targetY
    boss.maxY = math.max(boss.targetY + cellSize * 2, math.floor(screenHeight * 0.42))
    
    -- Stats
    boss.health = tier.health
    boss.maxHealth = tier.health
    boss.damage = tier.damage
    boss.speed = tier.speed
    boss.size = tier.size -- Collision radius
    
    -- Combat
    boss.attackCooldown = 0
    boss.attackRate = tier.attackRate
    boss.coneAngle = math.pi / 3 -- 60 degree cone
    boss.projectileCount = 5 -- Projectiles per cone
    
    -- State
    boss.phase = "entering" -- entering, combat, defeated
    boss.alive = true
    boss.invulnerable = true -- Invuln during entrance
    boss.encounterIndex = encounterIndex
    boss.displayName = tier.name
    boss.introText = tier.intro
    boss.bossColor = tier.color
    boss.allowedBehaviorIds = tier.allowedIds

    -- Archetype behavior AI
    boss.archetypeName = tier.archetype or BossBehaviors.randomArchetype()
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
    boss.defeatAlpha = 1
    boss.defeatRotation = 0
    boss.defeatScale = 1
    
    -- Ring-boss extension (opt-in, default OFF): attach dodecagonal ring phase state so this
    -- same entity can reconfigure across P1-P4. Pure logic in src/patterns/RingBoss.lua; when
    -- Config.boss.ringBoss.enabled is false this block is skipped and the boss is unchanged.
    local Config = require("src.Config")
    local rc = Config.boss and Config.boss.ringBoss
    if rc and rc.enabled and (rc.encounterIndex == nil or boss.encounterIndex == rc.encounterIndex) then
        RingBoss.attach(boss, rc)
    end

    BossSystem.activeBoss = boss

    -- Announcement (FloatingTextSystem will be called from main.lua)
    return boss
end

local function startDefeatSequence(boss)
    boss._defeatStarted = true
    boss.defeatTimer = 0
    boss.defeatDuration = 1.4
    boss.defeatPulseIndex = 1
    boss.defeatAlpha = 1
    boss.defeatRotation = 0
    boss.defeatScale = 1
    boss.defeatBaseX = boss.x
    boss.defeatBaseY = boss.y
    boss.invulnerable = true
    boss.behaviorState = "defeated"
    boss.behaviorTimer = math.huge
    boss.dashVx = 0
    boss.dashVy = 0
    boss.dashTimer = 0
    boss._scheduledProjectiles = {}

    local VFXLibrary = require("src.effects.VFXLibrary")
    VFXLibrary.spawnBossDeathBurst(boss, 1)
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

        -- Ring bosses drive their own movement and attacks from the ring phase (below), so the
        -- archetype movement/attack/phase selection is suppressed while ring state is attached.
        -- This makes the four phases read as ONE entity reconfiguring, not the stock boss plus
        -- extra bullets. No-op unless ring state was attached (default off).
        if not self.ringPhase then
            local movement = self._currentMovementBehavior
            if not movement or (movement.canRun and not movement.canRun(self, context)) then
                movement = BehaviorSelector.select(
                    BossBehaviors.listByKind("movement"),
                    "movement",
                    "boss",
                    self,
                    context,
                    {allowedIds = self.allowedBehaviorIds and self.allowedBehaviorIds.movement}
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
                    {allowedIds = self.allowedBehaviorIds and self.allowedBehaviorIds.phase or BossBehaviors.getAllowedIds(self.archetypeName, "phase")}
                )
                local attackBehavior = BehaviorSelector.select(
                    BossBehaviors.listByKind("attack"),
                    "attack",
                    "boss",
                    self,
                    context,
                    {allowedIds = self.allowedBehaviorIds and self.allowedBehaviorIds.attack or BossBehaviors.getAllowedIds(self.archetypeName, "attack")}
                )

                local behavior = phaseBehavior or attackBehavior
                if behavior then
                    self.behaviorTimer = BehaviorSelector.execute(self, behavior, context) or self.attackRate or 0.8
                else
                    self.behaviorTimer = 0.3
                end
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
                    local proj = Projectile(p.x, p.y, p.vx, p.vy, p.damage or 10, p.projType or "spread", "boss")
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

        -- Ring-boss (opt-in): advance P1->P2->P3 by time (the core is invulnerable until P4,
        -- so an HP-driven progression would deadlock), then fire that phase's ring attack on a
        -- cadence. No-op unless ring state was attached at spawn (default off).
        if self.ringPhase then
            RingBoss.advancePhaseByTime(self, dt, (self.ringConfig and self.ringConfig.phaseDuration) or 12)

            -- Per-phase movement: P2 closes on the player; other phases hold (the ring radius
            -- reconfigures via the phase layout). Clamped to the arena.
            local mvx, mvy = RingBoss.phaseVelocity(self.ringPhase, self.x, self.y, playerX, playerY, {
                chaseSpeed = (self.ringConfig and self.ringConfig.chaseSpeed) or 150,
            })
            if mvx ~= 0 or mvy ~= 0 then
                local sw, sh = GameConfig.getScreenSize()
                self.x = math.max(40, math.min((sw or 1920) - 40, self.x + mvx * dt))
                self.y = math.max(self.minY or 50, math.min((sh or 1080) - 120, self.y + mvy * dt))
            end

            self._ringFireTimer = (self._ringFireTimer or 0) - dt
            if self._ringFireTimer <= 0 then
                self._ringFireTimer = (self.ringConfig and self.ringConfig.fireCadence) or 0.5
                -- Descriptors emit from the 12 ring-node positions.
                local baseRadius = (self.ringConfig and self.ringConfig.baseRadius) or 220
                local descriptors = RingBoss.phaseAttack({x = self.x, y = self.y}, self.ringPhase, self.combatTime or 0, {
                    baseRadius = baseRadius,
                    speed = 230,
                    targetX = playerX, targetY = playerY,
                    color_axis = "mids",
                })
                if self.ringPhase == RingBoss.PHASE.P3 then
                    -- P3 emits laser BEAMS (segments), not bullets: each telegraphs, then fires.
                    -- BossCoordinator checks active beams against the player.
                    self._ringLasers = self._ringLasers or {}
                    local length = baseRadius * 2.4
                    for _, d in ipairs(descriptors) do
                        if d.type == "laser" then
                            local seg = LaserBeam.segmentFromVelocity(d.x, d.y, d.vx, d.vy, length)
                            self._ringLasers[#self._ringLasers + 1] = LaserBeam.new(seg, {
                                damage = math.floor((self.damage or 10) * 0.6),
                                color_axis = d.color_axis,
                            })
                        end
                    end
                else
                    -- P1/P2/P4 emit bullets: realize them through the shared bridge.
                    PatternSpawner.spawn(descriptors, self._bossProjectiles or {}, {
                        damage = math.floor((self.damage or 10) * 0.5),
                        projType = "boss_orb",
                    })
                end
            end

            -- Advance laser beams (telegraph -> active -> done) and retire finished ones.
            if self._ringLasers and #self._ringLasers > 0 then
                for i = #self._ringLasers, 1, -1 do
                    LaserBeam.update(self._ringLasers[i], dt)
                    if LaserBeam.isDone(self._ringLasers[i]) then
                        table.remove(self._ringLasers, i)
                    end
                end
            end

            -- P1 also runs the telegraphed 6/6 pillar curtain on its own cadence; other
            -- phases retire any lingering telegraph markers.
            if self.ringPhase == RingBoss.PHASE.P1 then
                self:updateRingCurtain(dt)
            else
                self._curtainMarkers = nil
                self._curtainState = "idle"
            end
        end

        -- Check death
        if self.health <= 0 then
            self.phase = "defeated"
        end

    elseif self.phase == "defeated" then
        if not self._defeatStarted then
            startDefeatSequence(self)
        end

        self.defeatTimer = self.defeatTimer + dt
        local progress = math.min(1, self.defeatTimer / self.defeatDuration)
        local shake = (1 - progress) * 7
        local shakePhase = self.defeatTimer * 60

        self.x = self.defeatBaseX + math.sin(shakePhase) * shake
        self.y = self.defeatBaseY + math.cos(shakePhase * 0.83) * shake
        self.defeatAlpha = 1 - progress
        self.defeatRotation = progress * math.pi * 2.2 + math.sin(self.defeatTimer * 18) * 0.15
        self.defeatScale = 1 + progress * 0.55 + math.sin(progress * math.pi * 5) * 0.08
        self.glowIntensity = 1 - progress

        local pulseTimes = {0.34, 0.74, 1.12}
        if self.defeatPulseIndex <= #pulseTimes and self.defeatTimer >= pulseTimes[self.defeatPulseIndex] then
            local VFXLibrary = require("src.effects.VFXLibrary")
            VFXLibrary.spawnBossDeathBurst(self, 0.65 + self.defeatPulseIndex * 0.25)
            self.defeatPulseIndex = self.defeatPulseIndex + 1
        end

        if self.defeatTimer >= self.defeatDuration and not self._defeatCompleted then
            self._defeatCompleted = true
            local VFXLibrary = require("src.effects.VFXLibrary")
            VFXLibrary.spawnBossDeathBurst(self, 1.35)
            self:onDefeat()
            self.alive = false
            BossSystem.clearBossReferences(self)
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
        
        local proj = Projectile(self.x, self.y, vx, vy, self.damage or 30, "boss_bolt", "boss")
        proj.color = {1, 0.2, 0.7}  -- Neon pink
        table.insert(projectiles, proj)
    end
    
    return projectiles
end

function BossSystem:takeDamage(amount, colorName)
    if self.invulnerable then return end

    -- Ring-boss (opt-in): the central core is only vulnerable in Phase 4 (closing circle /
    -- core exposed). In P1-P3 the ring shields the core, so damage is ignored. No-op unless
    -- ring state was attached at spawn (default off).
    if self.ringPhase then
        if not RingBoss.isCoreVulnerable(self.ringPhase) then
            return
        end
    end

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
    if self.health <= 0 then
        self.health = 0
        self.phase = "defeated"
        -- Ring-boss (opt-in): the exposed core was destroyed (damage only lands in P4 per the
        -- vulnerability guard above). This flag drives the flag-gated P4 core-kill win path.
        if self.ringPhase then
            self.coreDestroyed = true
        end
    end

    -- Visual feedback - simplified (no VFX system integration yet)
    -- VFX:spawnHitEffect(self.x, self.y, WHITE_COLOR)
    
    -- Screen shake on hit - commented out (no Camera system)
    -- Camera:shake(0.1, 5)
    
    -- Health bar flash
    self.hitFlash = 0.2
end

function BossSystem:onDefeat()
    BossSystem.nextEncounterIndex = math.max(BossSystem.nextEncounterIndex or 1, (self.encounterIndex or 1) + 1)

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
    local screenWidth, screenHeight = GameConfig.getScreenSize()
    FloatingTextSystem.add("BOSS DEFEATED", screenWidth / 2, screenHeight / 2, "BOSS")
end

function BossSystem:draw()
    local bossColor = self.bossColor or BOSS_COLOR
    local alpha = self.defeatAlpha or 1
    local renderScale = self.scale * (self.defeatScale or 1)
    local rotation = self.defeatRotation or 0

    -- Draw boss ship
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(rotation)
    love.graphics.scale(renderScale, renderScale)
    
    -- Glow effect when damaged
    if self.hitFlash and self.hitFlash > 0 then
        love.graphics.setColor(1, 1, 1, self.hitFlash * 2 * alpha)
    end
    
    -- Draw boss as large diamond/star shape
    love.graphics.setColor(bossColor[1], bossColor[2], bossColor[3], alpha)
    
    -- Draw diamond body
    local points = {
        0, -self.size,        -- Top
        self.size, 0,         -- Right
        0, self.size,         -- Bottom
        -self.size, 0         -- Left
    }
    love.graphics.polygon("fill", points)
    
    -- Draw outline
    love.graphics.setColor(1, 1, 1, 0.8 * alpha)
    love.graphics.setLineWidth(3)
    love.graphics.polygon("line", points)
    
    -- Draw core glow
    love.graphics.setColor(1, 1, 1, 0.6 * alpha)
    love.graphics.circle("fill", 0, 0, self.size * 0.3)
    
    love.graphics.pop()

    -- Ring-boss (opt-in): draw the dodecagonal ring overlay around the core. Additive and
    -- gated by ring state (default off), so the stock boss silhouette is unchanged.
    if self.ringPhase then
        self:drawRing()
    end

    -- Health bar
    if self.phase ~= "defeated" then
        self:drawHealthBar()
    end
    
    -- Debug: Collision circle
    local DEBUG_MODE = false  -- Set to true for debug visualization
    if DEBUG_MODE then
        love.graphics.setColor(1, 0, 0, 0.3)
        love.graphics.circle("line", self.x, self.y, self.size)
    end
end

function BossSystem:drawHealthBar()
    local BossPanel = require("src.ui.BossPanel")
    BossPanel.drawBossInfo(self)
end

-- Ring-boss (opt-in) overlay: the 12-node dodecagonal ring reconfiguring around the core.
-- Radius/rotation come from the pure RingBoss phase layout, so the silhouette reads as one
-- entity changing shape across phases. The core is highlighted red when exposed (P4).
function BossSystem:drawRing()
    local baseRadius = (self.ringConfig and self.ringConfig.baseRadius) or 220
    local nodes, cfg = RingBoss.phaseLayout(self.ringPhase, {x = self.x, y = self.y}, self.combatTime or 0, {
        baseRadius = baseRadius,
    })
    local radius = baseRadius * (cfg.radiusScale or 1)
    local bossColor = self.bossColor or BOSS_COLOR

    love.graphics.setColor(bossColor[1], bossColor[2], bossColor[3], 0.30)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, radius)

    for i = 1, #nodes do
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.circle("fill", nodes[i].x, nodes[i].y, 6)
    end

    if cfg.coreVulnerable then
        love.graphics.setColor(1, 0.3, 0.3, 0.9)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", self.x, self.y, (self.size or 30) * 0.6)
    end

    -- P3 laser beams: dim while telegraphing, bright while firing.
    if self._ringLasers and #self._ringLasers > 0 then
        for i = 1, #self._ringLasers do
            LaserBeam.draw(self._ringLasers[i], bossColor)
        end
    end

    -- P1 pillar-curtain telegraphs: outline the safe lanes before the curtain resolves.
    self:drawCurtainTelegraphs()
end

-- P1 6/6 pillar curtain on a cadence: warn (telegraph markers) then resolve (live bullets).
-- Reuses the pure RingBoss.curtainVolley + the PatternSpawner bridge. No-op outside P1.
function BossSystem:updateRingCurtain(dt)
    local cfg = self.ringConfig or {}
    local sw, sh = GameConfig.getScreenSize()
    local params = {
        columns = 6,
        fieldLeft = 0, fieldRight = sw or 1920,
        fieldTop = 0, fieldBottom = sh or 1080,
        bulletsPerColumn = 8,
        descendSpeed = 200,
        topGap = { pos = 0.30, width = 0.13 },
        bottomGap = { pos = 0.64, width = 0.13 },
        color_axis = "bass",
    }

    self._curtainState = self._curtainState or "idle"
    if self._curtainState == "idle" then
        self._curtainCooldown = (self._curtainCooldown or (cfg.curtainInterval or 5.0)) - dt
        if self._curtainCooldown <= 0 then
            self._curtainMarkers = RingBoss.curtainVolley("warning", params)
            self._curtainParams = params
            self._curtainState = "warning"
            self._curtainTimer = cfg.telegraphDuration or 0.7
        end
    elseif self._curtainState == "warning" then
        self._curtainTimer = (self._curtainTimer or 0) - dt
        if self._curtainTimer <= 0 then
            local bullets = RingBoss.curtainVolley("resolve", self._curtainParams or params)
            PatternSpawner.spawn(bullets, self._bossProjectiles or {}, {
                damage = math.floor((self.damage or 10) * 0.4),
                projType = "boss_orb",
            })
            self._curtainMarkers = nil
            self._curtainState = "idle"
            self._curtainCooldown = cfg.curtainInterval or 5.0
        end
    end
end

-- Draw the curtain telegraph markers as hollow "safe lane" rectangles. The inert
-- marker_style / gap_height pass-throughs from the pattern library finally drive a visual:
-- gap_height sizes the refuge band; marker_style picks luminance intent (outline/bright/dim).
function BossSystem:drawCurtainTelegraphs()
    if not self._curtainMarkers or #self._curtainMarkers == 0 then return end
    local p = self._curtainParams or {}
    local colWidth = ((p.fieldRight or 1920) - (p.fieldLeft or 0)) / (p.columns or 6)
    local w = colWidth * 0.7
    for i = 1, #self._curtainMarkers do
        local m = self._curtainMarkers[i]
        local h = m.gap_height or 60
        local alpha = (m.marker_style == "bright") and 0.7 or (m.marker_style == "dim") and 0.22 or 0.45
        love.graphics.setColor(1, 1, 0.4, alpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", m.x - w / 2, m.y - h / 2, w, h)
    end
end

-- Helper
function math.sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end

return BossSystem
