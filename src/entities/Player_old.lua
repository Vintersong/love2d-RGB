local entity = require("src.entities.Entity")
local Player = entity:derive("Player")

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
    
    -- Spawn continuous VFX for active artifacts
    self.vfxTimer = (self.vfxTimer or 0) + dt
    if self.vfxTimer >= 0.3 then  -- Spawn VFX every 0.3 seconds
        self.vfxTimer = 0
        local centerX = self.x + self.width / 2
        local centerY = self.y + self.height / 2
        
        -- HALO: Color-based aura VFX (handled by HaloArtifact.lua)
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
    
    -- Player Movement (WASD)
    local dx, dy = 0, 0
    
    if love.keyboard.isDown("a") then
        dx = dx - 1
    end
    if love.keyboard.isDown("d") then
        dx = dx + 1
    end
    if love.keyboard.isDown("w") then
        dy = dy - 1
    end
    if love.keyboard.isDown("s") then
        dy = dy + 1
    end
    
    -- Normalize diagonal movement
    if dx ~= 0 and dy ~= 0 then
        dx = dx * 0.707
        dy = dy * 0.707
    end
    
    self.x = self.x + dx * self.speed * dt
    self.y = self.y + dy * self.speed * dt
    
    -- Keep player in bounds (using constant resolution)
    local SCREEN_WIDTH = 1920
    local SCREEN_HEIGHT = 1080
    self.x = math.max(0, math.min(SCREEN_WIDTH - self.width, self.x))
    self.y = math.max(0, math.min(SCREEN_HEIGHT - self.height, self.y))
    
    -- Update weapon
    if self.weapon then
        self.weapon:update(dt)
    end
    
    -- Update projectiles
    for i = #self.projectiles, 1, -1 do
        local proj = self.projectiles[i]
        
        -- Initialize properties if they don't exist
        if not proj.trail then
            proj.trail = {}
            proj.trailLength = 8
        end
        if not proj.age then
            proj.age = 0
        end
        if not proj.size then
            proj.size = 4
        end
        if not proj.distanceTraveled then
            proj.distanceTraveled = 0
        end
        
        -- Increment age for animations
        proj.age = proj.age + dt
        
        -- Update artifact effects (LENS gravitational pull, etc.)
        self:updateProjectileArtifactEffects(proj, enemies, dt)
        
        -- Add current position to trail
        table.insert(proj.trail, 1, {x = proj.x, y = proj.y})
        if #proj.trail > proj.trailLength then
            table.remove(proj.trail)
        end
        
        -- Calculate movement distance
        local oldX, oldY = proj.x, proj.y
        
        -- Move projectile
        if proj.vx and proj.vy then
            proj.x = proj.x + proj.vx * dt
            proj.y = proj.y + proj.vy * dt
        else
            proj.y = proj.y - proj.speed * dt
        end
        
        -- Track distance for split mechanic
        if proj.canSplit then
            local dx = proj.x - oldX
            local dy = proj.y - oldY
            proj.distanceTraveled = proj.distanceTraveled + math.sqrt(dx * dx + dy * dy)
            
            -- Check if should split
            if not proj.hasSplit and proj.distanceTraveled >= proj.splitDistance then
                proj.hasSplit = true
                self:splitProjectile(proj, i)
                -- Remove original after splitting
                table.remove(self.projectiles, i)
                goto continue
            end
        end
        
        -- Handle screen edge collisions (using constant resolution)
        local SCREEN_WIDTH = 1920
        local SCREEN_HEIGHT = 1080
        local shouldRemove = false
        
        -- BOUNCE attribute: Bounce off screen edges
        if proj.canBounce and proj.bounces and proj.bounces > 0 then
            local bounced = false
            
            if proj.x < 0 then
                proj.x = 0
                proj.vx = -proj.vx
                bounced = true
            elseif proj.x > SCREEN_WIDTH then
                proj.x = SCREEN_WIDTH
                proj.vx = -proj.vx
                bounced = true
            end
            
            if proj.y < 0 then
                proj.y = 0
                proj.vy = -proj.vy
                bounced = true
            elseif proj.y > SCREEN_HEIGHT then
                proj.y = SCREEN_HEIGHT
                proj.vy = -proj.vy
                bounced = true
            end
            
            if bounced then
                proj.bounces = proj.bounces - 1
                if proj.bounces <= 0 then
                    shouldRemove = true
                end
            end
        else
            -- Non-bouncing projectiles: Remove when off-screen
            if proj.y < -10 or proj.y > SCREEN_HEIGHT + 10 or proj.x < -10 or proj.x > SCREEN_WIDTH + 10 then
                shouldRemove = true
            end
        end
        
        if shouldRemove then
            table.remove(self.projectiles, i)
        end
        
        ::continue::
    end
end

function Player:splitProjectile(parentProj, index)
    -- Spawn PRISM split VFX
    local VFXLibrary = require("src.systems.VFXLibrary")
    VFXLibrary.spawnArtifactEffect("PRISM", parentProj.x, parentProj.y)
    
    -- Create split projectiles in a spread pattern
    local splitCount = parentProj.splitCount or 2
    local angleStep = (math.pi / 6) / (splitCount - 1)  -- ±15° spread
    local baseAngle = math.atan2(parentProj.vy, parentProj.vx)
    
    for i = 1, splitCount do
        local offset = (i - 1) / (splitCount - 1) - 0.5  -- -0.5 to 0.5
        local angle = baseAngle + offset * (math.pi / 6)  -- ±15°
        
        local speed = math.sqrt(parentProj.vx * parentProj.vx + parentProj.vy * parentProj.vy)
        
        -- Create new projectile inheriting all attributes
        local newProj = {
            x = parentProj.x,
            y = parentProj.y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            damage = parentProj.damage,
            type = parentProj.type,
            size = parentProj.size * 0.8,  -- Slightly smaller
            age = 0,
            trail = {},
            trailLength = parentProj.trailLength,
            
            -- Inherit RGB attributes
            rCount = parentProj.rCount,
            gCount = parentProj.gCount,
            bCount = parentProj.bCount,
            shape = parentProj.shape,
            color = parentProj.color,
            
            -- Inherit BOUNCE
            canBounce = parentProj.canBounce,
            bounces = parentProj.bounces,
            
            -- Inherit PIERCE
            canPierce = parentProj.canPierce,
            pierce = parentProj.pierce,
            hitCount = 0,
            hitEnemies = {},
            
            -- NO more splits (already split)
            canSplit = false,
            splitCount = 0,
            hasSplit = true
        }
        
        table.insert(self.projectiles, newProj)
    end
end

function Player:draw()
    local centerX = self.x + self.width / 2
    local centerY = self.y + self.height / 2
    
    -- Calculate direction to nearest enemy
    local targetX, targetY
    if self.nearestEnemy and not self.nearestEnemy.dead then
        targetX = self.nearestEnemy.x + self.nearestEnemy.width / 2
        targetY = self.nearestEnemy.y + self.nearestEnemy.height / 2
    else
        -- Default direction (up)
        targetX = centerX
        targetY = centerY - 100
    end
    
    local dx = targetX - centerX
    local dy = targetY - centerY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Calculate player radius (circle)
    local radius = self.width / 2
    
    -- Draw HALO aura ring if artifact is active
    local ArtifactManager = require("src.systems.ArtifactManager")
    if ArtifactManager.getLevel("HALO") > 0 then
        local ColorSystem = require("src.systems.ColorSystem")
        local dominantColor = ColorSystem.getDominantColor()
        
        if dominantColor then
            -- Get color-specific aura radius and color
            local auraRadius = radius + 20
            local auraColor = {1, 1, 0.3}  -- Default gold
            
            if dominantColor == "RED" and self.redHalo then
                auraRadius = self.redHalo.currentRadius or (radius + 20)
                auraColor = {1, 0.2, 0.2}  -- Red fire
            elseif dominantColor == "GREEN" and self.greenHalo then
                auraRadius = self.greenHalo.radius or (radius + 30)
                auraColor = {0.2, 1, 0.2}  -- Green drain
            elseif dominantColor == "BLUE" and self.blueHalo then
                auraRadius = self.blueHalo.radius or (radius + 30)
                auraColor = {0.2, 0.4, 1}  -- Blue slow
            elseif dominantColor == "YELLOW" and self.yellowHalo then
                auraRadius = self.yellowHalo.radius or (radius + 25)
                auraColor = {1, 1, 0.2}  -- Yellow electric
            elseif dominantColor == "MAGENTA" and self.magentaHalo then
                auraRadius = self.magentaHalo.radius or (radius + 30)
                auraColor = {1, 0.2, 1}  -- Magenta time
            elseif dominantColor == "CYAN" and self.cyanHalo then
                auraRadius = self.cyanHalo.radius or (radius + 30)
                auraColor = {0.2, 1, 1}  -- Cyan frost
            end
            
            -- Draw aura ring
            love.graphics.setColor(auraColor[1], auraColor[2], auraColor[3], 0.4)
            love.graphics.setLineWidth(4)
            love.graphics.circle("line", centerX, centerY, auraRadius)
            
            -- Outer glow
            love.graphics.setColor(auraColor[1], auraColor[2], auraColor[3], 0.2)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", centerX, centerY, auraRadius + 8)
        end
    end
    
    -- Draw player as CIRCLE
    -- Flash white when taking damage, flicker when invulnerable
    if self.invulnerable and math.floor(self.invulnerableTime * 10) % 2 == 0 then
        love.graphics.setColor(0.3, 0.6, 1, 0.5) -- Semi-transparent when invulnerable
    elseif self.damageFlashTime > 0 then
        love.graphics.setColor(1, 0.3, 0.3) -- Red flash when hit
    else
        love.graphics.setColor(0.3, 0.6, 1) -- Blue-ish player
    end
    love.graphics.circle("fill", centerX, centerY, radius)
    
    -- Draw outline
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", centerX, centerY, radius)
    
    -- Draw direction indicator circle in front of player
    if distance > 0 then
        local dirX = dx / distance
        local dirY = dy / distance
        local indicatorDistance = 20 -- Distance from player center
        local indicatorX = centerX + dirX * indicatorDistance
        local indicatorY = centerY + dirY * indicatorDistance
        
        love.graphics.setColor(1, 1, 0, 0.8) -- Yellow indicator
        love.graphics.circle("fill", indicatorX, indicatorY, 5)
    end
    
    -- Draw player center dot for reference
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", centerX, centerY, 2)
    
    -- Draw line to nearest enemy (if exists) - GREEN for player targeting
    if self.nearestEnemy and not self.nearestEnemy.dead then
        love.graphics.setColor(0.2, 1, 0.2, 0.4)  -- Green, semi-transparent
        love.graphics.setLineWidth(2)
        love.graphics.line(centerX, centerY, targetX, targetY)
        
        -- Draw target indicator on nearest enemy
        love.graphics.setColor(0.2, 1, 0.2, 0.8)  -- Green
        love.graphics.circle("line", targetX, targetY, 15)
        love.graphics.circle("line", targetX, targetY, 12)
    end
    
    -- Draw projectiles with trails
    local ColorSystem = require("src.systems.ColorSystem")
    local projColor = ColorSystem.getProjectileColor()
    local ArtifactManager = require("src.systems.ArtifactManager")
    
    for _, proj in ipairs(self.projectiles) do
        -- Ensure projectile has necessary properties
        proj.color = projColor
        
        -- Enhanced size calculation (20-30% larger base + LENS scaling)
        local baseSize = 8  -- Increased from 4 to 8 (100% larger)
        local lensLevel = ArtifactManager.getLevel("LENS")
        local lensScale = 1 + (lensLevel * 0.1)  -- +10% per LENS level
        
        -- Additional size for multiple abilities (5-10% per ability)
        local abilityCount = 0
        if proj.canPierce then abilityCount = abilityCount + 1 end
        if proj.canBounceToNearest then abilityCount = abilityCount + 1 end
        if proj.canRoot then abilityCount = abilityCount + 1 end
        if proj.canExplode then abilityCount = abilityCount + 1 end
        if proj.canDot then abilityCount = abilityCount + 1 end
        local abilityScale = 1 + (abilityCount * 0.075)  -- 7.5% per ability
        
        proj.size = baseSize * lensScale * abilityScale
        proj.age = proj.age or 0
        
        -- Draw trail
        if proj.trail then
            for i, pos in ipairs(proj.trail) do
                local alpha = (1 - i / #proj.trail) * 0.4
                love.graphics.setColor(projColor[1], projColor[2], projColor[3], alpha)
                local size = proj.size * (1 - i / #proj.trail)
                love.graphics.circle("fill", pos.x, pos.y, size)
            end
        end
        
        -- Draw projectile based on shape
        love.graphics.push()
        love.graphics.translate(proj.x, proj.y)
        
        local shape = proj.shape or "circle"
        
        if shape == "atom" or shape == "atom_crescent" or shape == "atom_triangle" then
            -- HYDROGEN ATOM: Outer ring + core + orbiting electron
            
            -- White outline
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", 0, 0, proj.size * 1.5)
            
            -- Outer ring with color
            love.graphics.setColor(projColor)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", 0, 0, proj.size * 1.5)
            
            -- Inner core
            love.graphics.setColor(projColor)
            love.graphics.circle("fill", 0, 0, proj.size * 0.6)
            
            -- Orbiting electron
            local angle = proj.age * 8 + (proj.x + proj.y) * 0.1
            local orbitRadius = proj.size * 1.5
            local electronX = math.cos(angle) * orbitRadius
            local electronY = math.sin(angle) * orbitRadius
            love.graphics.circle("fill", electronX, electronY, proj.size * 0.3)
            
            -- Bright white core
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.circle("fill", 0, 0, proj.size * 0.3)
            
        elseif shape == "crescent" or shape == "triangle_crescent" then
            -- CRESCENT MOON: 180° arc facing direction of travel
            local angle = math.atan2(proj.vy, proj.vx)
            love.graphics.rotate(angle)
            
            -- White outline
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.setLineWidth(3)
            love.graphics.arc("line", 0, 0, proj.size, -math.pi/2, math.pi/2)
            
            -- Core color fill
            love.graphics.setColor(projColor)
            love.graphics.arc("fill", 0, 0, proj.size, -math.pi/2, math.pi/2)
            
            -- Additional colored outline
            love.graphics.setColor(projColor[1], projColor[2], projColor[3], 0.8)
            love.graphics.setLineWidth(1)
            love.graphics.arc("line", 0, 0, proj.size, -math.pi/2, math.pi/2)
            
        elseif shape == "triangle" then
            -- ISOSCELES TRIANGLE: Points in direction of travel
            local angle = math.atan2(proj.vy, proj.vx) + math.pi/2
            love.graphics.rotate(angle)
            
            -- Triangle vertices (top points forward)
            local vertices = {
                0, -proj.size * 1.5,           -- Top
                -proj.size, proj.size * 1.5,   -- Bottom-left
                proj.size, proj.size * 1.5     -- Bottom-right
            }
            
            -- White outline
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.setLineWidth(3)
            love.graphics.polygon("line", vertices)
            
            -- Core color fill
            love.graphics.setColor(projColor)
            love.graphics.polygon("fill", vertices)
            
            -- Additional colored outline
            love.graphics.setColor(projColor[1], projColor[2], projColor[3], 0.9)
            love.graphics.setLineWidth(1)
            love.graphics.polygon("line", vertices)
            
        elseif shape == "prism" then
            -- PRISM (RGB): Hexagon with refraction lines
            
            -- Hexagon vertices
            local vertices = {}
            for i = 0, 5 do
                local angle = (i / 6) * math.pi * 2
                table.insert(vertices, math.cos(angle) * proj.size)
                table.insert(vertices, math.sin(angle) * proj.size)
            end
            
            -- White outline
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.setLineWidth(3)
            love.graphics.polygon("line", vertices)
            
            -- Core color fill
            love.graphics.setColor(projColor)
            love.graphics.polygon("fill", vertices)
            
            -- Bright core
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.circle("fill", 0, 0, proj.size * 0.4)
            
            -- Refraction lines
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.setLineWidth(1)
            for i = 0, 5 do
                local angle = (i / 6) * math.pi * 2
                local x = math.cos(angle) * proj.size
                local y = math.sin(angle) * proj.size
                love.graphics.line(0, 0, x, y)
            end
            
        else
            -- DEFAULT: Circle with shape variations based on abilities
            
            -- Determine shape based on primary ability
            local hasMultipleAbilities = abilityCount > 1
            
            -- PIERCE (BLUE): Elongated diamond/arrow pointing forward
            if proj.canPierce and not hasMultipleAbilities then
                local angle = math.atan2(proj.vy, proj.vx)
                love.graphics.push()
                love.graphics.rotate(angle)
                
                -- Draw arrow/diamond shape
                local vertices = {
                    proj.size * 1.8, 0,              -- Front point (arrow tip)
                    proj.size * 0.3, proj.size * 0.6, -- Top-right
                    -proj.size * 0.5, 0,             -- Back point
                    proj.size * 0.3, -proj.size * 0.6 -- Bottom-right
                }
                
                -- White outline (3px thick)
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.setLineWidth(3)
                love.graphics.polygon("line", vertices)
                
                -- Core color
                love.graphics.setColor(projColor)
                love.graphics.polygon("fill", vertices)
                
                -- Bright white center streak
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.line(proj.size * 1.5, 0, -proj.size * 0.3, 0)
                
                love.graphics.pop()
                
            -- BOUNCE (GREEN): Circle with rotating orbit ring
            elseif proj.canBounceToNearest and not hasMultipleAbilities then
                -- White outline
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", 0, 0, proj.size)
                
                -- Core color
                love.graphics.setColor(projColor)
                love.graphics.circle("fill", 0, 0, proj.size)
                
                -- Rotating orbit ring (green)
                local orbitAngle = love.timer.getTime() * 4
                love.graphics.setColor(0.3, 1, 0.3, 0.9)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", 0, 0, proj.size * 1.4)
                
                -- Orbit particle
                local orbitX = math.cos(orbitAngle) * proj.size * 1.4
                local orbitY = math.sin(orbitAngle) * proj.size * 1.4
                love.graphics.circle("fill", orbitX, orbitY, proj.size * 0.2)
                
                -- Bright white core
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.circle("fill", 0, 0, proj.size * 0.5)
                
            -- SPREAD (RED): Standard circle but slightly larger
            elseif proj.type == "spread" and not hasMultipleAbilities then
                local spreadScale = 1.15
                local spreadSize = proj.size * spreadScale
                
                -- White outline
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", 0, 0, spreadSize)
                
                -- Core color
                love.graphics.setColor(projColor)
                love.graphics.circle("fill", 0, 0, spreadSize)
                
                -- Bright white core
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.circle("fill", 0, 0, spreadSize * 0.5)
                
            -- ROOT (YELLOW): Circle with pulsing yellow corona
            elseif proj.canRoot and not hasMultipleAbilities then
                -- Pulsing corona
                local pulse = 0.8 + math.sin(love.timer.getTime() * 6) * 0.2
                love.graphics.setColor(1, 1, 0, 0.4 * pulse)
                love.graphics.circle("fill", 0, 0, proj.size * 1.8 * pulse)
                
                -- White outline
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", 0, 0, proj.size)
                
                -- Core color
                love.graphics.setColor(projColor)
                love.graphics.circle("fill", 0, 0, proj.size)
                
                -- Yellow ring
                love.graphics.setColor(1, 1, 0, 0.8)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", 0, 0, proj.size * 1.3)
                
                -- Bright white core
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.circle("fill", 0, 0, proj.size * 0.5)
                
            -- EXPLODE (MAGENTA): Circle with magenta charge glow
            elseif proj.canExplode and not hasMultipleAbilities then
                -- Outer magenta glow
                love.graphics.setColor(1, 0.2, 1, 0.3)
                love.graphics.circle("fill", 0, 0, proj.size * 1.8)
                
                -- White outline
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", 0, 0, proj.size)
                
                -- Core color
                love.graphics.setColor(projColor)
                love.graphics.circle("fill", 0, 0, proj.size)
                
                -- Magenta charge rings
                love.graphics.setColor(1, 0.2, 1, 0.7)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", 0, 0, proj.size * 1.4)
                love.graphics.circle("line", 0, 0, proj.size * 1.6)
                
                -- Bright white core
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.circle("fill", 0, 0, proj.size * 0.5)
                
            -- DOT (CYAN): Circle with cyan spiral trail
            elseif proj.canDot and not hasMultipleAbilities then
                -- White outline
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", 0, 0, proj.size)
                
                -- Core color
                love.graphics.setColor(projColor)
                love.graphics.circle("fill", 0, 0, proj.size)
                
                -- Cyan spiral particles
                love.graphics.setColor(0.4, 1, 1, 0.8)
                for i = 0, 3 do
                    local angle = (i / 4) * math.pi * 2 + love.timer.getTime() * 3
                    local spiralRadius = proj.size * 1.4
                    local x = math.cos(angle) * spiralRadius
                    local y = math.sin(angle) * spiralRadius
                    love.graphics.circle("fill", x, y, proj.size * 0.25)
                end
                
                -- Bright white core
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.circle("fill", 0, 0, proj.size * 0.5)
                
            -- MULTIPLE ABILITIES: Combine indicators on standard circle
            else
                -- White outline (always visible)
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", 0, 0, proj.size)
                
                -- Core color
                love.graphics.setColor(projColor)
                love.graphics.circle("fill", 0, 0, proj.size)
                
                -- Draw indicators for each ability (stacked)
                if proj.canPierce then
                    -- Pierce: elongated shape or cross indicator
                    local angle = math.atan2(proj.vy, proj.vx)
                    love.graphics.push()
                    love.graphics.rotate(angle)
                    
                    love.graphics.setColor(0.3, 0.8, 1, 0.9)
                    love.graphics.setLineWidth(2)
                    -- Arrow shape indicator
                    love.graphics.line(-proj.size * 0.7, 0, proj.size * 0.7, 0)
                    love.graphics.line(proj.size * 0.5, -proj.size * 0.3, proj.size * 0.7, 0)
                    love.graphics.line(proj.size * 0.5, proj.size * 0.3, proj.size * 0.7, 0)
                    
                    love.graphics.pop()
                end
                
                if proj.canBounceToNearest then
                    -- Bounce: green orbital ring
                    love.graphics.setColor(0.3, 1, 0.3, 0.8)
                    love.graphics.setLineWidth(2)
                    love.graphics.circle("line", 0, 0, proj.size * 1.4)
                end
                
                if proj.canRoot then
                    -- Root: yellow pulse ring
                    local pulse = 0.8 + math.sin(love.timer.getTime() * 6) * 0.2
                    love.graphics.setColor(1, 1, 0, 0.6 * pulse)
                    love.graphics.circle("line", 0, 0, proj.size * 1.6)
                end
                
                if proj.canExplode then
                    -- Explode: magenta glow
                    love.graphics.setColor(1, 0.2, 1, 0.5)
                    love.graphics.circle("line", 0, 0, proj.size * 1.8)
                end
                
                if proj.canDot then
                    -- DoT: cyan spiral
                    love.graphics.setColor(0.4, 1, 1, 0.8)
                    for i = 0, 2 do
                        local angle = (i / 3) * math.pi * 2 + love.timer.getTime() * 3
                        local x = math.cos(angle) * proj.size * 1.3
                        local y = math.sin(angle) * proj.size * 1.3
                        love.graphics.circle("fill", x, y, proj.size * 0.2)
                    end
                end
                
                -- Bright white core
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.circle("fill", 0, 0, proj.size * 0.5)
            end
        end
        
        love.graphics.pop()
    end
    
    -- UI is now drawn by UISystem in main.lua, not here
    -- This keeps the draw function clean and focused on the player sprite
end

function Player:addExp(amount)
    self.exp = self.exp + amount
end

function Player:updateProjectileArtifactEffects(proj, enemies, dt)
    -- Apply per-frame artifact effects to a projectile
    local ArtifactManager = require("src.systems.ArtifactManager")
    local ColorSystem = require("src.systems.ColorSystem")
    local dominantColor = ColorSystem.getDominantColor()
    
    if not dominantColor then
        return
    end
    
    -- LENS artifact: gravitational pull, time delays, etc.
    if ArtifactManager.getLevel("LENS") > 0 then
        local LensArtifact = require("src.artifacts.LensArtifact")
        LensArtifact.update({proj}, enemies, dt, dominantColor)
    end
    
    -- MIRROR artifact: echo bounces
    if ArtifactManager.getLevel("MIRROR") > 0 then
        local MirrorArtifact = require("src.artifacts.MirrorArtifact")
        MirrorArtifact.update({proj}, enemies, dt, dominantColor)
    end
    
    -- PRISM artifact: orbiting projectiles, lasers
    if ArtifactManager.getLevel("PRISM") > 0 then
        local PrismArtifact = require("src.artifacts.PrismArtifact")
        PrismArtifact.update({proj}, enemies, dt, dominantColor, self)
    end
    
    -- DIFFUSION artifact: drain clouds
    if ArtifactManager.getLevel("DIFFUSION") > 0 then
        local DiffusionArtifact = require("src.artifacts.DiffusionArtifact")
        DiffusionArtifact.update({proj}, enemies, dt, dominantColor)
    end
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

-- Auto-fire at nearest enemy (Vampire Survivors style)
function Player:autoFire(enemies)
    if not self.weapon then
        return
    end
    
    -- Find nearest enemy
    local centerX = self.x + self.width / 2
    local centerY = self.y + self.height / 2
    
    local nearestEnemy = nil
    local nearestDistance = math.huge
    
    -- Check enemies
    if enemies then
        for _, enemy in ipairs(enemies) do
            if not enemy.dead then
                local dx = enemy.x + enemy.width / 2 - centerX
                local dy = enemy.y + enemy.height / 2 - centerY
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestEnemy = enemy
                end
            end
        end
    end
    
    -- Store for visual indicator
    self.nearestEnemy = nearestEnemy
    
    -- Auto-fire at nearest enemy
    if nearestEnemy then
        local targetX = nearestEnemy.x + nearestEnemy.width / 2
        local targetY = nearestEnemy.y + nearestEnemy.height / 2
        
        local projectiles = self.weapon:fire(centerX, centerY, targetX, targetY)
        if projectiles then
            -- Apply artifact transformations to projectiles
            projectiles = self:applyArtifactEffects(projectiles, targetX, targetY, enemies)
            
            for _, proj in ipairs(projectiles) do
                table.insert(self.projectiles, proj)
            end
        end
    end
end

function Player:getAimAngle()
    if self.nearestEnemy then
        local centerX = self.x + self.width / 2
        local centerY = self.y + self.height / 2
        local targetX = self.nearestEnemy.x + self.nearestEnemy.width / 2
        local targetY = self.nearestEnemy.y + self.nearestEnemy.height / 2
        return math.atan(targetY - centerY, targetX - centerX)
    end
    return 0
end

-- Apply artifact effects to projectiles when they're created
function Player:applyArtifactEffects(projectiles, targetX, targetY, enemies)
    local ArtifactManager = require("src.systems.ArtifactManager")
    local ColorSystem = require("src.systems.ColorSystem")
    local dominantColor = ColorSystem.getDominantColor()
    
    if not dominantColor then
        return projectiles
    end
    
    local centerX = self.x + self.width / 2
    local centerY = self.y + self.height / 2
    
    -- Apply PRISM effects (splitting, orbiting, etc.)
    if ArtifactManager.getLevel("PRISM") > 0 then
        local PrismArtifact = require("src.artifacts.PrismArtifact")
        local prismLevel = ArtifactManager.getLevel("PRISM")
        projectiles = PrismArtifact.apply(projectiles, prismLevel, dominantColor, targetX, targetY, self)
    end
    
    -- Apply MIRROR effects (duplication, echoing, etc.)
    if ArtifactManager.getLevel("MIRROR") > 0 then
        local MirrorArtifact = require("src.artifacts.MirrorArtifact")
        local mirrorLevel = ArtifactManager.getLevel("MIRROR")
        projectiles = MirrorArtifact.apply(projectiles, mirrorLevel, dominantColor, self)
    end
    
    -- Apply LENS effects (merging, enlarging, pull, etc.)
    if ArtifactManager.getLevel("LENS") > 0 then
        local LensArtifact = require("src.artifacts.LensArtifact")
        local lensLevel = ArtifactManager.getLevel("LENS")
        projectiles = LensArtifact.apply(projectiles, lensLevel, dominantColor)
    end
    
    -- Apply DIFFUSION effects (clouds, links, etc.)
    if ArtifactManager.getLevel("DIFFUSION") > 0 then
        local DiffusionArtifact = require("src.artifacts.DiffusionArtifact")
        local diffusionLevel = ArtifactManager.getLevel("DIFFUSION")
        projectiles = DiffusionArtifact.apply(projectiles, diffusionLevel, dominantColor)
    end
    
    return projectiles
end

return Player