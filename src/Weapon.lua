local class = require("libs.hump-master.class")
local MathUtils = require("src.utils.MathUtils")
local Weapon = class{}

function Weapon:init(weaponType)
    self.weaponType = weaponType or "basic"
    self.name = weaponType or "Basic Weapon"
    self.colors = {r = 0, g = 0, b = 0}
    self.fireRate = 0.25
    self.fireTimer = 0
    self.damage = 10                                        -- Base weapon damage - Meta progression influence - 10% increments
    self.bulletCount = 1
    self.projectileSpeed = 300                              -- Base projectile speed - Meta progression influence - 5% increments
    self.spread = 0
    
    -- Primary color chance attributes
    self.bounceChance = 0
    self.pierceChance = 0
    self.spreadChance = 0
    self.spreadAngle = 0
    
    -- Tertiary color chance attributes (level 20+)
    self.rootChance = 0        -- YELLOW: Root/slow
    self.rootDuration = 0
    self.explodeChance = 0     -- MAGENTA: Explode
    self.explodeRadius = 0
    self.explodeDamage = 0
    self.dotChance = 0         -- CYAN: Damage over time
    self.dotDuration = 0
    self.dotDamage = 0
    
end

function Weapon:update(dt)
    self.fireTimer = self.fireTimer + dt
end

function Weapon:canFire()
    return self.fireTimer >= self.fireRate
end

-- Get effective damage with LENS artifact bonus
function Weapon:getEffectiveDamage()
    local damage = self.damage
    if self.lensBonus and self.lensBonus > 0 then
        damage = damage * (1 + self.lensBonus)
    end
    return damage
end

function Weapon:fire(x, y, targetX, targetY)
    -- Store target for artifact calculations
    self.targetX = targetX
    self.targetY = targetY
    
    if self:canFire() then
        self.fireTimer = 0
        return self:createProjectiles(x, y, targetX, targetY)
    end
    return nil
end

function Weapon:createProjectiles(x, y, targetX, targetY)
    local ColorSystem = require("src.gameplay.ColorSystem")
    -- NEW ColorSystem API: Use getDominantColor() and commitment tracking
    local dominantColor = ColorSystem.getDominantColor()
    local hasRed = ColorSystem.primary.RED.level > 0
    local hasGreen = ColorSystem.primary.GREEN.level > 0
    local hasBlue = ColorSystem.primary.BLUE.level > 0
    
    -- Calculate effective damage with LENS bonus
    local effectiveDamage = self:getEffectiveDamage()
    
    -- Spawn LENS VFX if damage boost is active
    if self.lensBonus and self.lensBonus > 0 then
        local VFXLibrary = require("src.effects.VFXLibrary")
        VFXLibrary.spawnArtifactEffect("LENS", x, y, targetX, targetY)
    end
    
    -- Calculate direction toward target
    local dx = targetX - x
    local dy = targetY - y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 0 then
        dx = dx / distance
        dy = dy / distance
    end
    
    -- Get projectile color
    local color = self:calculateProjectileColor()
    
    -- If no color chosen yet, fire simple white projectile
    if not dominantColor then
        return {{
            x = x, y = y,
            damage = effectiveDamage,
            speed = self.projectileSpeed,
            vx = dx * self.projectileSpeed,
            vy = dy * self.projectileSpeed,
            color = {1, 1, 1},  -- White
            shape = "atom",
            type = "basic"
        }}
    end
    
    -- STEP 1: Determine projectile count from RED
    local projectileCount = 1  -- Base count
    
    -- RED PRIMARY: Guaranteed bullets + chance for one more
    if hasRed then
        -- Add guaranteed bullets (from milestones)
        if self.guaranteedBullets and self.guaranteedBullets > 0 then
            projectileCount = projectileCount + self.guaranteedBullets
        end
        
        -- Roll for bonus bullet based on spreadChance
        if self.spreadChance and self.spreadChance > 0 then
            if math.random() <= self.spreadChance then
                projectileCount = projectileCount + 1
            end
        end
    end
    
    -- Cap at reasonable number for performance
    projectileCount = math.min(projectileCount, 36)  -- Max 36 projectiles (every 10 degrees)
    
    -- STEP 2: Roll for GREEN/BLUE abilities (apply to ALL projectiles)
    local hasBounce = false
    local hasPierce = false
    local bounceCount = self.bounceCount or 0
    local pierceCount = self.pierceCount or 0
    
    -- Primary GREEN
    if hasGreen then
        local guaranteed = self.bounceCount or 0
        local bonus = (self.bounceChance and self.bounceChance > 0 and math.random() <= self.bounceChance) and 1 or 0
        bounceCount = guaranteed + bonus
        hasBounce = bounceCount > 0
    end
    
    -- Primary BLUE
    if hasBlue then
        local guaranteed = self.pierceCount or 0
        local bonus = (self.pierceChance and self.pierceChance > 0 and math.random() <= self.pierceChance) and 1 or 0
        pierceCount = guaranteed + bonus
        hasPierce = pierceCount > 0
    end
    
    -- STEP 2.5: Roll for TERTIARY color abilities (level 20+)
    local hasRoot = false
    local hasExplode = false
    local hasDot = false
    
    if self.rootChance and math.random() <= self.rootChance then
        hasRoot = true
    end
    
    if self.explodeChance and math.random() <= self.explodeChance then
        hasExplode = true
    end
    
    if self.dotChance and math.random() <= self.dotChance then
        hasDot = true
    end
    
    -- STEP 3: Create projectiles with all abilities
    local projectiles = {}
    local baseAngle = MathUtils.atan2(dy, dx)

    local function getProjectileShape()
        if dominantColor == "RED" then
            return "atom"
        elseif dominantColor == "GREEN" then
            return "crescent"
        elseif dominantColor == "BLUE" then
            return "arrow"
        elseif dominantColor == "YELLOW" then
            return "atom_crescent"
        elseif dominantColor == "MAGENTA" then
            return "atom_arrow"
        elseif dominantColor == "CYAN" then
            return "crescent_arrow"
        end

        return "atom"
    end
    
    -- Helper function to apply all abilities to a projectile
    local function applyAbilities(proj)
        -- Tag with the run's dominant color name so boss affinity can read it
        -- cheaply (proj.color is an RGB table, unusable for name matching).
        proj.colorName = dominantColor

        if hasBounce then
            proj.canBounceToNearest = true
            proj.maxBounces = bounceCount  -- Number of redirects after hits
            proj.currentBounces = 0
        end
        
        if hasPierce then
            proj.canPierce = true
            proj.hitEnemies = {}
            proj.maxPierces = pierceCount  -- Number of enemies the shot can pass through
            proj.pierceCount = 0
        end
        
        -- Tertiary abilities
        if hasRoot then
            proj.canRoot = true
            proj.rootDuration = self.rootDuration
        end
        
        if hasExplode then
            proj.canExplode = true
            proj.explodeRadius = self.explodeRadius
            proj.explodeDamage = self.explodeDamage
        end
        
        if hasDot then
            proj.canDot = true
            proj.dotDuration = self.dotDuration
            proj.dotDamage = self.dotDamage
        end

        -- Artifact synergies that need to manifest where the projectile hits
        -- or travels. These are set by SynergySystem on the weapon.
        proj.lensThunderball = self.lensThunderball
        proj.thunderfieldRadius = self.thunderfieldRadius
        proj.thunderfieldDPS = self.thunderfieldDPS
        proj.thunderfieldDuration = self.thunderfieldDuration
        proj.mirrorFireTrail = self.mirrorFireTrail
        proj.mirrorTrailDamage = self.mirrorTrailDamage
        proj.mirrorTrailDuration = self.mirrorTrailDuration
        proj.electricTrail = self.electricTrail
        proj.trailDamage = self.trailDamage
        proj.trailDuration = self.trailDuration
        proj.diffractionBurnZone = self.diffractionBurnZone
        proj.burnZoneRadius = self.burnZoneRadius
        proj.burnZoneDPS = self.burnZoneDPS
        proj.burnZoneDuration = self.burnZoneDuration
        proj.waveEcho = self.waveEcho
        proj.waveRadius = self.waveRadius
        proj.wavePullForce = self.wavePullForce
        proj.gravityWell = self.gravityWell
        proj.wellRadius = self.wellRadius
        proj.wellPullForce = self.wellPullForce
        proj.poisonBloom = self.poisonBloom
        proj.bloomRadius = self.bloomRadius
        proj.bloomDamageRatio = self.bloomDamageRatio
        proj.dotCloud = self.dotCloud
        proj.cloudRadius = self.cloudRadius
        proj.cloudDamageRatio = self.cloudDamageRatio
        proj.refractionFrostPatches = self.refractionFrostPatches
        proj.frostPatchRadius = self.frostPatchRadius
        proj.frostPatchSlow = self.frostPatchSlow
        proj.frostPatchDuration = self.frostPatchDuration
        proj.refractionFireArms = self.refractionFireArms
        proj.spiralTrailDPS = self.spiralTrailDPS
        proj.spiralTrailDuration = self.spiralTrailDuration
        proj.prismRootBonus = self.prismRootBonus
        proj.rootRadius = self.rootRadius
    end
    
    if projectileCount == 1 then
        -- Single projectile (straight forward)
        local proj = {
            x = x, y = y,
            damage = effectiveDamage,
            speed = self.projectileSpeed,
            vx = dx * self.projectileSpeed,
            vy = dy * self.projectileSpeed,
            color = color,
            shape = "atom",
            type = "basic"
        }
        
        applyAbilities(proj)
        
        proj.shape = getProjectileShape()
        
        table.insert(projectiles, proj)
        
    else
        -- Multiple projectiles: spread them based on spreadAngle
        local spreadAngle = (self.spreadAngle and self.spreadAngle > 0) and self.spreadAngle or (math.pi / 6)  -- Default 30 degrees
        local is360 = (spreadAngle >= math.pi * 2)  -- Full circle?
        
        if is360 then
            -- Full 360-degree circle: space evenly around player
            for i = 1, projectileCount do
                local angle = (i - 1) * (math.pi * 2 / projectileCount)
                
                local proj = {
                    x = x, y = y,
                    damage = effectiveDamage,
                    speed = self.projectileSpeed,
                    vx = math.cos(angle) * self.projectileSpeed,
                    vy = math.sin(angle) * self.projectileSpeed,
                    color = color,
                    shape = "atom",
                    type = "spread"
                }
                
                applyAbilities(proj)
                
                proj.shape = getProjectileShape()
                
                table.insert(projectiles, proj)
            end
        else
            -- Cone spread: distribute projectiles across the cone
            local halfSpread = spreadAngle / 2
            
            if projectileCount == 2 then
                -- Two projectiles: left and right
                for i = 1, 2 do
                    local angle = baseAngle + (i == 1 and -halfSpread or halfSpread)
                    local proj = {
                        x = x, y = y,
                        damage = effectiveDamage,
                        speed = self.projectileSpeed,
                        vx = math.cos(angle) * self.projectileSpeed,
                        vy = math.sin(angle) * self.projectileSpeed,
                        color = color,
                        shape = "atom",
                        type = "spread"
                    }
                    
                    applyAbilities(proj)
                    
                    proj.shape = getProjectileShape()
                    
                    table.insert(projectiles, proj)
                end
            else
                -- 3+ projectiles: spread evenly across the cone
                for i = 1, projectileCount do
                    local t = (i - 1) / (projectileCount - 1)  -- 0 to 1
                    local angle = baseAngle - halfSpread + (t * spreadAngle)
                    
                    local proj = {
                        x = x, y = y,
                        damage = effectiveDamage,
                        speed = self.projectileSpeed,
                        vx = math.cos(angle) * self.projectileSpeed,
                        vy = math.sin(angle) * self.projectileSpeed,
                        color = color,
                        shape = "atom",
                        type = "spread"
                    }
                    
                    applyAbilities(proj)
                    
                    proj.shape = getProjectileShape()
                    
                    table.insert(projectiles, proj)
                end
            end
        end
    end
    
    return projectiles
end

function Weapon:calculateProjectileColor()
    -- Get color from ColorSystem (tracks primary color choice)
    local ColorSystem = require("src.gameplay.ColorSystem")
    return ColorSystem.getProjectileColor()
end

return Weapon
