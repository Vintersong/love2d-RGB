local class = require("class")
local Weapon = class:derive("Weapon")

function Weapon:new(weaponType)
    self.weaponType = weaponType or "basic"
    self.name = weaponType or "Basic Weapon"
    self.colors = {r = 0, g = 0, b = 0}
    self.fireRate = 0.25
    self.fireTimer = 0
    self.damage = 10
    self.bulletCount = 1
    self.projectileSpeed = 300
    self.spread = 0
    
    -- Primary color chance attributes
    self.bounceChance = 0
    self.pierceChance = 0
    self.spreadChance = 0
    self.spreadAngle = 0
    
    -- Secondary color chance attributes (level 10+)
    self.secondaryBounceChance = 0
    self.secondaryPierceChance = 0
    self.secondarySpreadChance = 0
    
    -- Tertiary color chance attributes (level 20+)
    self.rootChance = 0        -- YELLOW: Root/slow
    self.rootDuration = 0
    self.explodeChance = 0     -- MAGENTA: Explode
    self.explodeRadius = 0
    self.explodeDamage = 0
    self.dotChance = 0         -- CYAN: Damage over time
    self.dotDuration = 0
    self.dotDamage = 0
    
    -- Legacy attributes (unused)
    self.maxBounces = 0
    self.maxPierceCount = 0
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
    local ColorSystem = require("src.systems.ColorSystem")
    -- NEW ColorSystem API: Use getDominantColor() and commitment tracking
    local dominantColor = ColorSystem.getDominantColor()
    local hasRed = ColorSystem.primary.RED.level > 0
    local hasGreen = ColorSystem.primary.GREEN.level > 0
    local hasBlue = ColorSystem.primary.BLUE.level > 0
    
    -- Calculate effective damage with LENS bonus
    local effectiveDamage = self:getEffectiveDamage()
    
    -- Spawn LENS VFX if damage boost is active
    if self.lensBonus and self.lensBonus > 0 then
        local VFXLibrary = require("src.systems.VFXLibrary")
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
    
    -- YELLOW SPECIAL: Always fire 2 bouncing projectiles (RED + GREEN combo)
    if ColorSystem.tertiaryColor == "y" then
        local projectiles = {}
        local spreadAngle = math.pi / 8  -- 22.5 degrees spread
        
        -- Left projectile
        local leftAngle = math.atan(dy, dx) - spreadAngle
        table.insert(projectiles, {
            x = x, y = y,
            damage = effectiveDamage,
            speed = self.projectileSpeed,
            vx = math.cos(leftAngle) * self.projectileSpeed,
            vy = math.sin(leftAngle) * self.projectileSpeed,
            color = color,
            shape = "atom_crescent",
            type = "projectile",
            canBounce = true,
            bouncesLeft = 3,
            canRoot = self.rootChance and self.rootChance > 0,
            rootDuration = self.rootDuration
        })
        
        -- Right projectile
        local rightAngle = math.atan(dy, dx) + spreadAngle
        table.insert(projectiles, {
            x = x, y = y,
            damage = effectiveDamage,
            speed = self.projectileSpeed,
            vx = math.cos(rightAngle) * self.projectileSpeed,
            vy = math.sin(rightAngle) * self.projectileSpeed,
            color = color,
            shape = "atom_crescent",
            type = "projectile",
            canBounce = true,
            bouncesLeft = 3,
            canRoot = self.rootChance and self.rootChance > 0,
            rootDuration = self.rootDuration
        })
        
        return projectiles
    end
    
    -- STEP 1: Determine projectile count (affected by RED primary/secondary)
    local projectileCount = 1  -- Base count
    local primaryRedTriggered = false
    local secondaryRedTriggered = false
    
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
                primaryRedTriggered = true
            end
        end
    end
    
    -- RED SECONDARY: Guaranteed bullets + chance for one more
    if dominantColor == "YELLOW" or dominantColor == "MAGENTA" then
        -- Add guaranteed bullets from secondary
        if self.secondaryGuaranteedBullets and self.secondaryGuaranteedBullets > 0 then
            projectileCount = projectileCount + self.secondaryGuaranteedBullets
        end
        
        -- Roll for bonus bullet based on secondarySpreadChance
        if self.secondarySpreadChance and self.secondarySpreadChance > 0 then
            if math.random() <= self.secondarySpreadChance then
                projectileCount = projectileCount + 1
                secondaryRedTriggered = true
            end
        end
    end
    
    -- Cap at reasonable number for performance
    projectileCount = math.min(projectileCount, 36)  -- Max 36 projectiles (every 10 degrees)
    
    -- STEP 2: Roll for GREEN/BLUE abilities (apply to ALL projectiles)
    local hasBounce = false
    local hasPierce = false
    local bounceCount = 1
    local pierceCount = 1
    
    -- Primary GREEN
    if hasGreen and self.bounceChance then
        if math.random() <= self.bounceChance then
            hasBounce = true
            bounceCount = self.bounceCount or 1
        end
    end
    
    -- Secondary GREEN (YELLOW or CYAN)
    if (dominantColor == "YELLOW" or dominantColor == "CYAN") and self.secondaryBounceChance then
        if math.random() <= self.secondaryBounceChance then
            hasBounce = true
            -- Use the higher bounce count if both trigger
            bounceCount = math.max(bounceCount, self.secondaryBounceCount or 1)
        end
    end
    
    -- Primary BLUE
    if hasBlue and self.pierceChance then
        if math.random() <= self.pierceChance then
            hasPierce = true
            pierceCount = self.pierceCount or 1
        end
    end
    
    -- Secondary BLUE (MAGENTA or CYAN)
    if (dominantColor == "MAGENTA" or dominantColor == "CYAN") and self.secondaryPierceChance then
        if math.random() <= self.secondaryPierceChance then
            hasPierce = true
            -- Use the higher pierce count if both trigger
            pierceCount = math.max(pierceCount, self.secondaryPierceCount or 1)
        end
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
    local baseAngle = math.atan(dy, dx)
    
    -- Helper function to apply all abilities to a projectile
    local function applyAbilities(proj)
        if hasBounce then
            proj.canBounceToNearest = true
            proj.maxBounces = bounceCount  -- Track how many bounces are allowed
            proj.currentBounces = 0
        end
        
        if hasPierce then
            proj.canPierce = true
            proj.hitEnemies = {}
            proj.maxPierces = pierceCount  -- Track how many enemies can be pierced
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
        
        -- Assign shape based on dominant color
        if dominantColor == "RED" then
            proj.shape = "atom"
        elseif dominantColor == "GREEN" then
            proj.shape = "crescent"
        elseif dominantColor == "BLUE" then
            proj.shape = "arrow"  -- Arrow/triangle pointing forward
        elseif dominantColor == "YELLOW" then
            proj.shape = "atom_crescent"  -- Crescent with atom inside
        elseif dominantColor == "MAGENTA" then
            proj.shape = "atom_arrow"  -- Atom with arrow attached
        elseif dominantColor == "CYAN" then
            proj.shape = "crescent"
        else
            -- No color chosen yet, default to atom
            proj.shape = "atom"
        end
        
        table.insert(projectiles, proj)
        
    else
        -- Multiple projectiles: spread them based on spreadAngle
        local spreadAngle = self.spreadAngle or (math.pi / 3)  -- Default 60 degrees
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
                
                -- Assign shape based on dominant color
                if dominantColor == "RED" then
                    proj.shape = "atom"
                elseif dominantColor == "GREEN" then
                    proj.shape = "crescent"
                elseif dominantColor == "BLUE" then
                    proj.shape = "arrow"
                elseif dominantColor == "YELLOW" then
                    proj.shape = "atom_crescent"
                elseif dominantColor == "MAGENTA" then
                    proj.shape = "atom_arrow"
                elseif dominantColor == "CYAN" then
                    proj.shape = "crescent"
                else
                    proj.shape = "atom"
                end
                
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
                    
                    -- Assign shape based on dominant color
                    if dominantColor == "RED" then
                        proj.shape = "atom"
                    elseif dominantColor == "GREEN" then
                        proj.shape = "crescent"
                    elseif dominantColor == "BLUE" then
                        proj.shape = "arrow"
                    elseif dominantColor == "YELLOW" then
                        proj.shape = "atom_crescent"
                    elseif dominantColor == "MAGENTA" then
                        proj.shape = "atom_arrow"
                    elseif dominantColor == "CYAN" then
                        proj.shape = "crescent"
                    else
                        proj.shape = "atom"
                    end
                    
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
                    
                    -- Assign shape based on dominant color
                    if dominantColor == "RED" then
                        proj.shape = "atom"
                    elseif dominantColor == "GREEN" then
                        proj.shape = "crescent"
                    elseif dominantColor == "BLUE" then
                        proj.shape = "arrow"
                    elseif dominantColor == "YELLOW" then
                        proj.shape = "atom_crescent"
                    elseif dominantColor == "MAGENTA" then
                        proj.shape = "atom_arrow"
                    elseif dominantColor == "CYAN" then
                        proj.shape = "crescent"
                    else
                        proj.shape = "atom"
                    end
                    
                    table.insert(projectiles, proj)
                end
            end
        end
    end
    
    -- Apply artifact effects AFTER projectile creation
    projectiles = self:applyArtifactEffects(projectiles)
    
    return projectiles
end

function Weapon:applyArtifactEffects(projectiles)
    local ArtifactManager = require("src.systems.ArtifactManager")
    local ColorSystem = require("src.systems.ColorSystem")
    
    -- Get dominant color for artifact behavior selection
    local dominantColor = ColorSystem.getDominantColor()
    if not dominantColor then return projectiles end
    
    -- Apply LENS artifact effect
    if ArtifactManager.getLevel("LENS") > 0 then
        local LensArtifact = require("src.artifacts.LensArtifact")
        local lensLevel = ArtifactManager.getLevel("LENS")
        projectiles = LensArtifact.apply(projectiles, lensLevel, dominantColor)
    end
    
    -- Apply MIRROR artifact effect
    if ArtifactManager.getLevel("MIRROR") > 0 then
        local MirrorArtifact = require("src.artifacts.MirrorArtifact")
        local mirrorLevel = ArtifactManager.getLevel("MIRROR")
        projectiles = MirrorArtifact.apply(projectiles, mirrorLevel, dominantColor, self.player)
    end
    
    -- Apply PRISM artifact effect
    if ArtifactManager.getLevel("PRISM") > 0 then
        local PrismArtifact = require("src.artifacts.PrismArtifact")
        local prismLevel = ArtifactManager.getLevel("PRISM")
        -- PRISM needs target position for wall calculations
        projectiles = PrismArtifact.apply(projectiles, prismLevel, dominantColor, 
                                         self.targetX or 0, self.targetY or 0, self.player)
    end
    
    -- Apply DIFFUSION artifact effect
    if ArtifactManager.getLevel("DIFFUSION") > 0 then
        local DiffusionArtifact = require("src.artifacts.DiffusionArtifact")
        local diffusionLevel = ArtifactManager.getLevel("DIFFUSION")
        projectiles = DiffusionArtifact.apply(projectiles, diffusionLevel, dominantColor)
    end
    
    return projectiles
end

function Weapon:getColorString()
    return string.format("R:%d G:%d B:%d", self.colors.r, self.colors.g, self.colors.b)
end

function Weapon:calculateProjectileColor()
    -- Get color from ColorSystem (tracks primary color choice)
    local ColorSystem = require("src.systems.ColorSystem")
    return ColorSystem.getProjectileColor()
end

return Weapon
