-- Player.lua (REFACTORED)
-- Core player entity with delegated responsibilities
-- Movement -> PlayerInput.lua
-- Combat -> PlayerCombat.lua
-- Rendering -> PlayerRender.lua
-- Artifacts -> individual artifact modules

local entity = require("src.entities.Entity")
local Player = entity:derive("Player")

-- Load delegated modules
local PlayerInput = require("src.entities.PlayerInput")
local PlayerCombat = require("src.entities.PlayerCombat")
local PlayerRender = require("src.entities.PlayerRender")

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

    -- Dash ability (permanent, always available)
    self.isDashing = false
    self.dashTimer = 0
    self.dashDuration = 0.2  -- 0.2 second dash
    self.dashSpeed = 800  -- Very fast movement during dash
    self.dashDirection = {x = 0, y = 0}
    self.dashCooldown = 0  -- Current cooldown
    self.dashMaxCooldown = 3.0  -- 3 second cooldown

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

    -- Update dash cooldown
    if self.dashCooldown > 0 then
        self.dashCooldown = self.dashCooldown - dt
        if self.dashCooldown < 0 then
            self.dashCooldown = 0
        end
    end

    -- Update active artifact ability cooldown
    if self.abilityCooldown > 0 then
        self.abilityCooldown = self.abilityCooldown - dt
        if self.abilityCooldown < 0 then
            self.abilityCooldown = 0
        end
    end

    -- Update dash state
    if self.isDashing then
        self.dashTimer = self.dashTimer + dt
        
        -- Spawn continuous dash trail particles
        local VFXManager = require("src.systems.VFXManager")
        local ColorSystem = require("src.systems.ColorSystem")
        local centerX = self.x + self.width / 2
        local centerY = self.y + self.height / 2
        
        if self.dashColor then
            local trailColor = ColorSystem.getColorRGB(self.dashColor)
            -- Spawn 2 trail particles per frame
            VFXManager.spawnImpactBurst(centerX, centerY, trailColor, 2)
        end
        
        -- Spawn continuous dash trail VFX (color-specific)
        if self.dashColor then
            self.dashTrailTimer = (self.dashTrailTimer or 0) + dt
            if self.dashTrailTimer >= 0.05 then  -- Spawn trail every 0.05 seconds
                self.dashTrailTimer = 0
                
                local VFXLibrary = require("src.systems.VFXLibrary")
                
                -- Map colors to VFX with reduced particle count for trail
                local colorVFXMap = {
                    RED = "SUPERNOVA",
                    GREEN = "AURORA",
                    BLUE = "LENS",
                    YELLOW = "REFRACTION",
                    MAGENTA = "PRISM",
                    CYAN = "DIFFRACTION"
                }
                
                local vfxType = colorVFXMap[self.dashColor]
                if vfxType then
                    -- Spawn small trail particles
                    VFXLibrary.spawnArtifactEffect(vfxType, centerX, centerY, 
                                                   centerX - self.dashDirection.x * 20, 
                                                   centerY - self.dashDirection.y * 20)
                end
            end
        end
        
        if self.dashTimer >= self.dashDuration then
            -- Dash ended - apply color-based effects
            self:onDashEnd()
            self.isDashing = false
            self.dashTimer = 0
            self.dashTrailTimer = 0
        end
    end

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
        self.expToNext = math.floor(100 * math.pow(1.05, self.level - 1))
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
    if self.dashCooldown > 0 then return false end
    if self.isDashing then return false end

    return self:activateDash()
end

-- Activate dash ability
function Player:activateDash()
    -- Get current movement direction
    local dx, dy = 0, 0
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then dx = dx - 1 end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then dx = dx + 1 end
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then dy = dy - 1 end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then dy = dy + 1 end

    -- If no direction, dash in last movement direction or forward
    if dx == 0 and dy == 0 then
        dy = -1  -- Default dash up
    end

    -- Normalize direction
    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0 then
        dx = dx / length
        dy = dy / length
    end

    -- Get dominant color for dash effects
    local ColorSystem = require("src.systems.ColorSystem")
    local dominantColor = ColorSystem.getDominantColor()

    -- Set dash state
    self.isDashing = true
    self.dashTimer = 0
    self.dashDirection = {x = dx, y = dy}
    self.dashColor = dominantColor  -- Store color for dash effects
    self.dashPiercedEnemies = {}  -- Track enemies hit during dash
    self.invulnerable = true  -- Invulnerable during dash
    self.invulnerableTime = self.dashDuration

    -- Start dash cooldown
    self.dashCooldown = self.dashMaxCooldown

    -- Spawn color-specific dash VFX
    local VFXLibrary = require("src.systems.VFXLibrary")
    local centerX = self.x + self.width / 2
    local centerY = self.y + self.height / 2
    
    -- Only spawn VFX if we have a color
    if dominantColor then
        -- Map colors to VFX artifact types for color-specific effects
        local colorVFXMap = {
            RED = "SUPERNOVA",      -- Red explosive trail
            GREEN = "AURORA",       -- Green healing waves
            BLUE = "LENS",          -- Blue focused beam
            YELLOW = "REFRACTION",  -- Yellow speed trails
            MAGENTA = "PRISM",      -- Magenta rainbow refraction
            CYAN = "DIFFRACTION"    -- Cyan sparkle/magnet effect
        }
        
        local vfxType = colorVFXMap[dominantColor] or "DASH"
        VFXLibrary.spawnArtifactEffect(vfxType, centerX, centerY, 
                                       centerX + dx * 50, centerY + dy * 50)
    end
    -- No VFX for neutral dash (no color selected)

    print(string.format("[Player] %s Dash activated!", dominantColor or "NEUTRAL"))
    return true
end

-- Get dash movement (called from PlayerInput during dash)
function Player:getDashMovement(dt)
    if not self.isDashing then return 0, 0 end

    local moveX = self.dashDirection.x * self.dashSpeed * dt
    local moveY = self.dashDirection.y * self.dashSpeed * dt

    return moveX, moveY
end

-- Check collision with enemies during dash (called from PlayingState)
function Player:checkDashCollisions(enemies)
    if not self.isDashing then return end
    if not self.dashColor then return end  -- Neutral dash has no pierce

    for _, enemy in ipairs(enemies) do
        if not enemy.dead and not self.dashPiercedEnemies[enemy] then
            -- Check if player hitbox overlaps enemy
            if self.x < enemy.x + enemy.width and
               self.x + self.width > enemy.x and
               self.y < enemy.y + enemy.height and
               self.y + self.height > enemy.y then

                -- Mark as pierced
                self.dashPiercedEnemies[enemy] = true

                -- Apply color-based pierce effects
                self:applyDashPierceEffect(enemy)
            end
        end
    end
end

-- Apply effect when dashing through an enemy
function Player:applyDashPierceEffect(enemy)
    local damage = 20  -- Base dash damage

    if self.dashColor == "BLUE" or self.dashColor == "YELLOW" or
       self.dashColor == "PURPLE" or self.dashColor == "CYAN" then

        -- Deal damage to pierced enemy
        enemy.hp = enemy.hp - damage

        -- Visual feedback: Floating text
        local FloatingTextSystem = require("src.systems.FloatingTextSystem")
        FloatingTextSystem.add(
            string.format("-%d DASH", damage),
            enemy.x + enemy.width / 2,
            enemy.y,
            "DAMAGE"
        )
        
        -- Visual feedback: Impact VFX at enemy position
        local VFXManager = require("src.systems.VFXManager")
        local ColorSystem = require("src.systems.ColorSystem")
        local impactColor = ColorSystem.getColorRGB(self.dashColor)
        VFXManager.spawnImpactBurst(
            enemy.x + enemy.width / 2,
            enemy.y + enemy.height / 2,
            impactColor,
            10  -- particle count
        )

        -- PURPLE: Apply DoT
        if self.dashColor == "PURPLE" then
            enemy.dotDamage = (enemy.dotDamage or 0) + 5
            enemy.dotDuration = 3.0
        end

        -- CYAN: Life steal
        if self.dashColor == "CYAN" then
            local healAmount = damage * 0.5  -- 50% life steal
            self.hp = math.min(self.maxHp, self.hp + healAmount)
            FloatingTextSystem.add(
                string.format("+%d HP", math.floor(healAmount)),
                self.x + self.width / 2,
                self.y,
                "HEAL"
            )
        end
    end
end

-- Called when dash ends - apply post-dash effects
function Player:onDashEnd()
    if not self.dashColor then return end

    -- RED: Speed boost after dash
    if self.dashColor == "RED" then
        self.speedBoost = 1.5  -- 50% speed boost
        self.speedBoostDuration = 2.0  -- 2 seconds
        print("[Player] RED dash: Speed boost applied!")
    end

    -- GREEN: Heal on dash
    if self.dashColor == "GREEN" then
        local healAmount = self.maxHp * 0.1  -- 10% max HP
        self.hp = math.min(self.maxHp, self.hp + healAmount)

        local FloatingTextSystem = require("src.systems.FloatingTextSystem")
        FloatingTextSystem.add(
            string.format("+%d HP", math.floor(healAmount)),
            self.x + self.width / 2,
            self.y,
            "HEAL"
        )
        print(string.format("[Player] GREEN dash: Healed %d HP", math.floor(healAmount)))
    end

    -- YELLOW: Heal + Speed boost (combination)
    if self.dashColor == "YELLOW" then
        -- Heal (smaller than green)
        local healAmount = self.maxHp * 0.05  -- 5% max HP
        self.hp = math.min(self.maxHp, self.hp + healAmount)

        -- Speed boost (smaller than red)
        self.speedBoost = 1.3  -- 30% speed boost
        self.speedBoostDuration = 1.5  -- 1.5 seconds

        local FloatingTextSystem = require("src.systems.FloatingTextSystem")
        FloatingTextSystem.add(
            string.format("+%d HP +SPEED", math.floor(healAmount)),
            self.x + self.width / 2,
            self.y,
            "HEAL"
        )
        print(string.format("[Player] YELLOW dash: Healed %d HP + Speed boost", math.floor(healAmount)))
    end

    -- Count pierced enemies for feedback
    local piercedCount = 0
    for _ in pairs(self.dashPiercedEnemies) do
        piercedCount = piercedCount + 1
    end

    if piercedCount > 0 and (self.dashColor == "BLUE" or self.dashColor == "PURPLE" or self.dashColor == "CYAN") then
        print(string.format("[Player] %s dash: Pierced %d enemies", self.dashColor, piercedCount))
    end
end

return Player
