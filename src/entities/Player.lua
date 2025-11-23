-- Player.lua (REFACTORED)
-- Core player entity with delegated responsibilities
-- Movement -> PlayerInput.lua
-- Combat -> PlayerCombat.lua
-- Rendering -> PlayerRender.lua
-- Abilities -> AbilitySystem.lua + AbilityLibrary.lua
-- Artifacts -> individual artifact modules

local entity = require("src.entities.Entity")
local Player = entity:derive("Player")

-- Load delegated modules
local PlayerInput = require("src.entities.PlayerInput")
local PlayerCombat = require("src.entities.PlayerCombat")
local PlayerRender = require("src.entities.PlayerRender")
local AbilitySystem = require("src.systems.AbilitySystem")
local AbilityLibrary = require("src.data.AbilityLibrary")

function Player:new(x, y, weapon)
    self.x = x or 400
    self.y = y or 500
    self.width = 32
    self.height = 32
    self.speed = 200
    self.hp = 100
    self.maxHp = 100
    self.weapon = weapon -- Weapon instance
    self.projectiles = {}
    self.level = 1
    self.exp = 0
    self.expToNext = 100  -- XP needed for next level

    -- Link weapon to player for artifact effects
    if self.weapon then
        self.weapon.player = self
    end

    -- Auto-aim targeting (Vampire Survivors style)
    self.nearestEnemy = nil

    -- Damage/invulnerability system
    self.invulnerable = false
    self.invulnerableTime = 0
    self.invulnerableDuration = 1.0  -- 1 second invulnerability after hit
    self.damageFlashTime = 0

    -- Register player abilities with AbilitySystem
    AbilitySystem.register(self, {"DASH"})

    -- Active artifact ability system (for future active artifacts)
    self.activeAbility = nil  -- Current active artifact ability
    self.abilityCooldown = 0  -- Current cooldown timer
    self.abilityMaxCooldown = 0  -- Max cooldown for UI display
end

function Player:update(dt, enemies)
    enemies = enemies or {}  -- Default to empty table if not provided

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

    -- Update active artifact ability cooldown
    if self.abilityCooldown > 0 then
        self.abilityCooldown = self.abilityCooldown - dt
        if self.abilityCooldown < 0 then
            self.abilityCooldown = 0
        end
    end

    -- Update all abilities via AbilitySystem
    AbilitySystem.update(self, AbilityLibrary, dt, {enemies = enemies})

    -- Spawn continuous VFX for active artifacts
    self.vfxTimer = (self.vfxTimer or 0) + dt
    if self.vfxTimer >= 0.3 then  -- Spawn VFX every 0.3 seconds
        self.vfxTimer = 0
        local centerX, centerY = PlayerInput.getCenter(self)

        -- HALO: Color-based aura VFX
        local ArtifactManager = require("src.systems.ArtifactManager")
        if ArtifactManager.getLevel("HALO") > 0 then
            local VFXLibrary = require("src.systems.VFXLibrary")
            VFXLibrary.spawnArtifactEffect("HALO", centerX, centerY)
        end
    end

    -- Update HALO artifact aura effects (passive)
    local ArtifactManager = require("src.systems.ArtifactManager")
    if ArtifactManager.getLevel("HALO") > 0 then
        local ColorSystem = require("src.systems.ColorSystem")
        local dominantColor = ColorSystem.getDominantColor()
        if dominantColor then
            local HaloArtifact = require("src.artifacts.HaloArtifact")
            local haloLevel = ArtifactManager.getLevel("HALO")
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

function Player:draw()
    -- Draw HALO aura ring if artifact is active (delegated to HaloArtifact)
    local ArtifactManager = require("src.systems.ArtifactManager")
    if ArtifactManager.getLevel("HALO") > 0 then
        local ColorSystem = require("src.systems.ColorSystem")
        local dominantColor = ColorSystem.getDominantColor()
        local HaloArtifact = require("src.artifacts.HaloArtifact")
        HaloArtifact.draw(self, dominantColor)
    end

    -- Draw player sprite (delegated to PlayerRender)
    PlayerRender.drawPlayer(self)

    -- Draw projectiles with trails (delegated to PlayerRender)
    PlayerRender.drawProjectiles(self)
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

function Player:levelUp()
    if self.exp >= self.expToNext then
        self.level = self.level + 1
        self.exp = 0
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
function Player:autoFire(enemies)
    PlayerCombat.autoFire(self, enemies)
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
    self.activeAbility = abilityName
    self.abilityMaxCooldown = cooldown
    self.abilityCooldown = 0  -- Ready immediately
    print(string.format("[Player] Active ability set: %s (cooldown: %.1fs)", abilityName, cooldown))
end

-- Use active ability (called on spacebar press)
function Player:useActiveAbility()
    if not self.activeAbility then return false end
    if self.abilityCooldown > 0 then return false end

    if self.activeAbility == "DASH" then
        return self:activateDash()
    end

    return false
end

-- Use dash (SPACE key - permanent ability)
function Player:useDash()
    local success = AbilitySystem.activate(self, "DASH", AbilityLibrary.DASH, {})
    return success
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
