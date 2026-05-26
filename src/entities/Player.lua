-- Player.lua (REFACTORED)
-- Core player entity with delegated responsibilities
-- Movement -> PlayerInput.lua
-- Combat -> PlayerCombat.lua
-- Rendering -> PlayerRender.lua
-- Abilities -> AbilitySystem.lua + AbilityLibrary.lua
-- Artifacts -> individual artifact modules

local class = require("libs.hump-master.class")
local Entity = require("src.entities.Entity")
local Player = class{__includes = Entity}

-- Load delegated modules
local PlayerInput = require("src.entities.PlayerInput")
local PlayerCombat = require("src.entities.PlayerCombat")
local PlayerRender = require("src.entities.PlayerRender")
local AbilitySystem = require("src.combat.AbilitySystem")
local AbilityLibrary = require("src.data.AbilityLibrary")
local SFXLibrary = require("src.audio.SFXLibrary")

function Player:init(x, y, weapon)
    self.x = x or 400
    self.y = y or 500
    self.width = 32
    self.height = 32
    self.speed = 200
    self.hp = 100
    self.maxHp = 100
    self.weapon = weapon -- Weapon instance
    self.projectiles = {}  -- Compatibility shim for combatState.projectiles
    self.combatState = {
        nearestEnemy = nil,
        projectiles = self.projectiles
    }
    self.level = 1
    self.exp = 0
    self.expToNext = 100  -- XP needed for next level

    -- Link weapon to player for artifact effects
    if self.weapon then
        self.weapon.player = self
    end

    -- Auto-aim targeting (Vampire Survivors style)
    self.nearestEnemy = self.combatState.nearestEnemy  -- Compatibility shim

    -- Damage/invulnerability system
    self.invulnerable = false
    self.invulnerableTime = 0
    self.invulnerableDuration = 1.0  -- 1 second invulnerability after hit
    self.damageFlashTime = 0
    self.blockedHitVfxCooldown = 0.08
    self.blockedHitVfxTimer = 0

    -- Register player abilities with AbilitySystem
    AbilitySystem.register(self, {"DASH", "BLINK", "SHIELD", "LIGHTNING_BOLT"})

    -- Active artifact ability system (for future active artifacts)
    self.abilityState = {
        activeAbility = nil,  -- Current active artifact ability
        cooldown = 0,  -- Current cooldown timer
        maxCooldown = 0,  -- Max cooldown for UI display
        lastEnemies = {}  -- Cache for lightning bolt ability
    }
    self.activeAbility = self.abilityState.activeAbility  -- Compatibility shim
    self.abilityCooldown = self.abilityState.cooldown  -- Compatibility shim
    self.abilityMaxCooldown = self.abilityState.maxCooldown  -- Compatibility shim
    self._lastEnemies = self.abilityState.lastEnemies  -- Compatibility shim
end

function Player:update(dt, enemies)
    enemies = enemies or {}  -- Default to empty table if not provided
    self.abilityState.lastEnemies = enemies  -- Cache for lightning bolt ability
    self._lastEnemies = self.abilityState.lastEnemies  -- Compatibility shim

    -- Update invulnerability timer
    if self.invulnerable then
        self.invulnerableTime = self.invulnerableTime - dt
        if self.invulnerableTime <= 0 then
            self.invulnerable = false
        end
    end

    -- Update damage flash
    if self.damageFlashTime > 0 then
        self.damageFlashTime = self.damageFlashTime - dt
    end

    -- Throttle shield-hit VFX while continuously colliding with enemies.
    if self.blockedHitVfxTimer > 0 then
        self.blockedHitVfxTimer = self.blockedHitVfxTimer - dt
    end

    -- Update active artifact ability cooldown
    if self.abilityState.activeAbility == "SUPERNOVA" then
        local ArtifactManager = require("src.gameplay.ArtifactManager")
        local ColorSystem = require("src.gameplay.ColorSystem")
        local color = ColorSystem.getDominantColor() or "RED"
        ArtifactManager.updateSupernovaCooldowns(dt)
        self.abilityState.maxCooldown = ArtifactManager.getSupernovaCooldown(color, self)
        self.abilityState.cooldown = ArtifactManager.getSupernovaCooldownRemaining(color)
    elseif self.abilityState.cooldown > 0 then
        self.abilityState.cooldown = self.abilityState.cooldown - dt
        if self.abilityState.cooldown < 0 then
            self.abilityState.cooldown = 0
        end
    end
    self.activeAbility = self.abilityState.activeAbility  -- Compatibility shim
    self.abilityCooldown = self.abilityState.cooldown  -- Compatibility shim
    self.abilityMaxCooldown = self.abilityState.maxCooldown  -- Compatibility shim

    -- Update all abilities via AbilitySystem
    AbilitySystem.update(self, AbilityLibrary, dt, {enemies = enemies})

    -- Artifact updates
    local ArtifactManager = require("src.gameplay.ArtifactManager")
    local haloLevel = ArtifactManager.getLevel("HALO")

    -- Spawn continuous VFX for active artifacts
    self.vfxTimer = (self.vfxTimer or 0) + dt
    if self.vfxTimer >= 0.3 then  -- Spawn VFX every 0.3 seconds
        self.vfxTimer = 0
        local centerX, centerY = PlayerInput.getCenter(self)

        -- HALO: Color-based aura VFX
        if haloLevel > 0 then
            local VFXLibrary = require("src.effects.VFXLibrary")
            VFXLibrary.spawnArtifactEffect("HALO", centerX, centerY)
        end
    end

    -- Update HALO artifact aura effects (passive)
    if haloLevel > 0 then
        local ColorSystem = require("src.gameplay.ColorSystem")
        local dominantColor = ColorSystem.getDominantColor()
        if dominantColor then
            local HaloArtifact = require("src.artifacts.HaloArtifact")
            -- Initialize halo if needed
            HaloArtifact.apply(self, haloLevel, dominantColor)
            -- Update halo effects
            HaloArtifact.update(dt, enemies, self, dominantColor)
        end
    end

    -- Player Movement (delegated to PlayerInput)
    PlayerInput.update(self, dt)

    -- Update weapon
    if self.weapon then
        self.weapon:update(dt)
    end

    -- Update projectiles (delegated to PlayerCombat)
    PlayerCombat.updateProjectiles(self, dt, enemies)
end

function Player:drawAura()
    -- Draw HALO aura ring if artifact is active (delegated to HaloArtifact)
    local ArtifactManager = require("src.gameplay.ArtifactManager")
    if ArtifactManager.getLevel("HALO") > 0 then
        local ColorSystem = require("src.gameplay.ColorSystem")
        local dominantColor = ColorSystem.getDominantColor()
        local HaloArtifact = require("src.artifacts.HaloArtifact")
        HaloArtifact.draw(self, dominantColor)
    end
end

function Player:drawBody()
    -- Draw player sprite (delegated to PlayerRender)
    PlayerRender.drawPlayer(self)
end

function Player:drawProjectileTrails()
    -- Draw projectile trails as a background combat VFX layer
    PlayerRender.drawProjectileTrails(self)
end

function Player:drawProjectileCores()
    -- Draw projectile cores as a foreground combat VFX layer
    PlayerRender.drawProjectileCores(self)
end

function Player:drawProjectiles()
    -- Backwards-compatible projectile draw for screens without explicit layering
    PlayerRender.drawProjectiles(self)
end

-- Release subsystem-owned references before discarding this player.
function Player:destroy()
    local AbilitySystem = require("src.combat.AbilitySystem")

    AbilitySystem.unregister(self)

    local CollisionSystem = package.loaded["src.combat.CollisionSystem"]
    if CollisionSystem then
        CollisionSystem.remove(self)
    end

    if self.weapon and self.weapon.player == self then
        self.weapon.player = nil
    end

    self.nearestEnemy = nil
    self._lastEnemies = nil
    self.projectiles = {}
    self.activeAbility = nil
    self.abilityCooldown = 0
    self.abilityMaxCooldown = 0
    self.vfxTimer = nil
    self.weapon = nil
    self.destroyed = true
end

-- Alias for callers that prefer dispose terminology.
function Player:dispose()
    self:destroy()
end

function Player:drawTargetingOverlay()
    -- Draw targeting lines/indicators above combatants
    PlayerRender.drawTargetingOverlay(self)
end

function Player:draw()
    -- Backwards-compatible full player draw for screens without explicit layering
    self:drawAura()
    self:drawBody()
    self:drawProjectiles()
    self:drawTargetingOverlay()
end

function Player:addExp(amount)
    self.exp = self.exp + amount
end

function Player:takeDamage(amount, dt)
    if self.invulnerable then
        return false  -- No damage taken
    end

    self.hp = self.hp - (amount * dt)  -- Damage per second when touching enemy
    self.damageFlashTime = 0.1  -- Flash for 0.1 seconds

    if self.hp <= 0 then
        self.hp = 0
        return true  -- Player died
    end

    -- Set invulnerability period
    self.invulnerable = true
    self.invulnerableTime = self.invulnerableDuration

    return false
end

-- Continuous damage (for environmental hazards like fire)
-- Does not trigger invulnerability frames
function Player:takeContinuousDamage(amount, dt)
    if self.dead then
        return false
    end

    self.hp = self.hp - (amount * dt)  -- Damage per second
    self.damageFlashTime = 0.1  -- Flash for 0.1 seconds

    if self.hp <= 0 then
        self.hp = 0
        self.dead = true
        return true  -- Player died
    end

    return false
end

function Player:canLevelUp()
    return self.exp >= self.expToNext
end

function Player:levelUp()
    if self:canLevelUp() then
        local oldExpToNext = self.expToNext

        self.level = self.level + 1
        self.exp = self.exp - oldExpToNext
        -- XP requirement increases by 5% per level
        self.expToNext = math.floor(100 * (1.05^(self.level - 1)))
        -- Trigger color choice UI
        return true -- Signals that player should choose a color
    end
    return false
end

function Player:addColorToWeapon(color)
    if self.weapon then
        self.weapon:addColor(color)
    end
end

-- Auto-fire at nearest enemy (delegated to PlayerCombat)
function Player:autoFire(enemies, boss)
    PlayerCombat.autoFire(self, enemies, boss)
end

-- Get aim angle to nearest enemy (delegated to PlayerCombat)
function Player:getAimAngle()
    return PlayerCombat.getAimAngle(self)
end

-- Split projectile (delegated to PlayerCombat)
function Player:splitProjectile(proj, index)
    PlayerCombat.splitProjectile(self, proj, index)
end

-- Apply artifact effects to projectiles (delegated to PlayerCombat)
function Player:applyArtifactEffects(projectiles, targetX, targetY, enemies)
    return PlayerCombat.applyArtifactEffects(self, projectiles, targetX, targetY, enemies)
end

-- Update projectile artifact effects (delegated to PlayerCombat)
function Player:updateProjectileArtifactEffects(proj, enemies, dt)
    PlayerCombat.updateProjectileArtifactEffects(proj, enemies, dt, self)
end

-- Set active ability (called when picking up an active artifact)
function Player:setActiveAbility(abilityName, cooldown)
    self.abilityState.activeAbility = abilityName
    self.abilityState.maxCooldown = cooldown
    self.abilityState.cooldown = 0  -- Ready immediately
    self.activeAbility = self.abilityState.activeAbility  -- Compatibility shim
    self.abilityMaxCooldown = self.abilityState.maxCooldown  -- Compatibility shim
    self.abilityCooldown = self.abilityState.cooldown  -- Compatibility shim
    print(string.format("[Player] Active ability set: %s (cooldown: %.1fs)", abilityName, cooldown))
end

-- Use active ability (called on left shift)
function Player:useActiveAbility(enemies)
    local activeAbility = self.abilityState.activeAbility or self.activeAbility
    if not activeAbility then return false end
    if (self.abilityState.cooldown or self.abilityCooldown or 0) > 0 then return false end

    if activeAbility == "SUPERNOVA" then
        local ArtifactManager = require("src.gameplay.ArtifactManager")
        local ColorSystem = require("src.gameplay.ColorSystem")
        local color = ColorSystem.getDominantColor() or "RED"
        local level = ArtifactManager.getLevel("SUPERNOVA")
        if level <= 0 then
            return false
        end

        local success, effectData = ArtifactManager.tryActivateSupernova(color, self, enemies or {}, level)
        if success then
            self.abilityState.maxCooldown = ArtifactManager.getSupernovaCooldown(color, self)
            self.abilityState.cooldown = ArtifactManager.getSupernovaCooldownRemaining(color)
            self.abilityMaxCooldown = self.abilityState.maxCooldown
            self.abilityCooldown = self.abilityState.cooldown
        end
        return success, effectData, color
    end

    local abilityDef = AbilityLibrary[activeAbility]
    if not abilityDef then return false end

    local context = {}
    if activeAbility == "LIGHTNING_BOLT" then
        context = {enemies = self.abilityState.lastEnemies or self._lastEnemies or {}}
    end

    local success = AbilitySystem.activate(self, activeAbility, abilityDef, context)
    if success then
        self.abilityState.cooldown = abilityDef.cooldown or self.abilityState.maxCooldown or 0
        self.abilityCooldown = self.abilityState.cooldown
    end

    return success
end

-- Use lightning bolt (L-Shift key)
function Player:useLightningBolt()
    local enemies = self.abilityState.lastEnemies or {}
    local success = AbilitySystem.activate(self, "LIGHTNING_BOLT", AbilityLibrary.LIGHTNING_BOLT, {enemies = enemies})
    return success
end

-- Use dash (SPACE key - permanent ability)
function Player:useDash()
    if not AbilitySystem.isReady(self, "DASH") then
        return false
    end

    SFXLibrary.play("playerDash")
    local success = AbilitySystem.activate(self, "DASH", AbilityLibrary.DASH, {})
    return success
end

-- Use blink (E key - teleport ability)
function Player:useBlink()
    local success = AbilitySystem.activate(self, "BLINK", AbilityLibrary.BLINK, {})
    return success
end

-- Use shield (Q key - invulnerability ability)
function Player:useShield()
    local success = AbilitySystem.activate(self, "SHIELD", AbilityLibrary.SHIELD, {})
    return success
end

-- Called when an incoming hit is absorbed by invulnerability.
function Player:onInvulnerableHit(amount, source)
    -- Show hit sparks only for active shield, not for dash i-frames.
    if not AbilitySystem.isActive(self, "SHIELD") then
        return
    end

    if self.blockedHitVfxTimer > 0 then
        return
    end
    self.blockedHitVfxTimer = self.blockedHitVfxCooldown

    local ColorSystem = require("src.gameplay.ColorSystem")
    local VFXLibrary = require("src.effects.VFXLibrary")
    local dominant = ColorSystem.getDominantColor()
    local color = {0.25, 0.95, 1.0}
    if dominant then
        local rgb = ColorSystem.getColorRGB(dominant)
        if rgb then
            color = {rgb[1], rgb[2], rgb[3]}
        end
    end

    VFXLibrary.spawnImpactBurst(self.x + self.width / 2, self.y + self.height / 2, color, 8)
end

-- Check collision with enemies during dash (called from PlayingState)
function Player:checkDashCollisions(enemies)
    -- Delegate to ability library's dash collision checker
    local dashState = AbilitySystem.getState(self, "DASH")
    if dashState and dashState.isActive then
        AbilityLibrary.DASH.checkCollisions(self, dashState.state, enemies)
    end
end

return Player
