local class = require("libs.hump-master.class")
local Entity = require("src.entities.Entity")
local Enemy = class{__includes = Entity}
local ShapeLibrary = require("src.systems.ShapeLibrary")

-- Helper function: Lerp between two colors
local function lerpColor(color1, color2, t)
    return {
        color1[1] + (color2[1] - color1[1]) * t,
        color1[2] + (color2[2] - color1[2]) * t,
        color1[3] + (color2[3] - color1[3]) * t
    }
end

-- Calculate enemy color based on player level
local function getEnemyColorByLevel(playerLevel)
    playerLevel = playerLevel or 1
    
    -- Vaporwave color palette
    local pink = {1, 0.4, 0.7}      -- Level 1-10
    local purple = {0.8, 0.4, 1}    -- Level 10-20
    local cyan = {0.3, 0.9, 1}      -- Level 20-30
    local orange = {1, 0.6, 0.2}    -- Level 30+
    
    -- Normalize level for cycling (50-60 uses same progression as 1-10, etc.)
    local cycleLevel = ((playerLevel - 1) % 40) + 1
    
    if cycleLevel <= 10 then
        -- Pink to Purple
        local t = (cycleLevel - 1) / 9
        return lerpColor(pink, purple, t)
    elseif cycleLevel <= 20 then
        -- Purple to Cyan
        local t = (cycleLevel - 10) / 10
        return lerpColor(purple, cyan, t)
    elseif cycleLevel <= 30 then
        -- Cyan to Orange
        local t = (cycleLevel - 20) / 10
        return lerpColor(cyan, orange, t)
    else
        -- Orange (30-40)
        return orange
    end
end

-- Calculate how many rings enemy should have based on level
-- Rings accumulate as player levels up
-- Level 1-40: 1 ring, Level 41-80: 2 rings, Level 81-120: 3 rings, Level 121+: 4 rings
local function getRingCount(playerLevel)
    playerLevel = playerLevel or 1
    return math.min(math.floor((playerLevel - 1) / 40) + 1, 4)
end

-- Draw outer rings for higher-level enemies using ShapeLibrary
-- Each ring represents the color progression for that prestige tier
-- NOTE: x, y should be 0, 0 when drawing within a transformed coordinate system
local function drawOuterRings(shape, width, ringCount, playerLevel)
    if ringCount < 1 then return end
    
    -- Build ring colors array
    local ringColors = {}
    for ring = ringCount, 1, -1 do
        local tierOffset = (ringCount - ring) * 40
        local ringLevel = playerLevel - tierOffset
        local ringColor = getEnemyColorByLevel(ringLevel)
        -- Add alpha to color
        local alpha = ring == 1 and 1.0 or 0.7
        ringColors[ring] = {ringColor[1], ringColor[2], ringColor[3], alpha}
    end
    
    -- Use ShapeLibrary multiRing function at origin (already transformed)
    ShapeLibrary.multiRing(0, 0, width / 2, ringCount, ringColors, shape, {
        ringThickness = 3,
        ringOffset = 6
    })
end

function Enemy:init(x, y, enemyType, playerLevel, formationData)
    self.x = x or 0
    self.y = y or 0
    self.width = 24
    self.height = 24
    self.enemyType = enemyType or "formation"  -- "formation", "flanker", "BASS", "MIDS", "TREBLE", "BOSS"
    self.pattern = "descend_straight"  -- Default pattern
    self.formationData = formationData or {}
    self.dead = false
    self.age = 0
    
    -- Follow player after delay
    self.followDelay = 3.0  -- Start following after 3 seconds
    self.isFollowing = false
    
    -- Calculate color based on player level
    local levelColor = getEnemyColorByLevel(playerLevel)
    self.ringCount = getRingCount(playerLevel)
    self.playerLevel = playerLevel or 1  -- Store for ring color calculation
    
    -- Frequency type (for music-reactive enemies)
    self.frequencyType = nil
    self.baseColor = {1, 1, 1}  -- White base for all enemies
    self.overlayColor = levelColor  -- Level-based vaporwave color
    self.overlayAlpha = 0.5
    
    -- Type-specific properties
    if self.enemyType == "BASS" then
        -- Bass enemies: Large, slow, tanky
        self.width = 35
        self.height = 35
        self.speed = 60
        self.hp = 180
        self.maxHp = 180
        self.damage = 40
        self.expReward = 50
        self.shape = "square"
        self.frequencyType = "bass"
        self.overlayColor = levelColor
        
    elseif self.enemyType == "MIDS" then
        -- Mids enemies: Standard balanced
        self.width = 18
        self.height = 18
        self.speed = 120
        self.hp = 60
        self.maxHp = 60
        self.damage = 25
        self.expReward = 30
        self.shape = "hexagon"  -- Changed from circle to hexagon
        self.frequencyType = "mids"
        self.overlayColor = levelColor
        
    elseif self.enemyType == "TREBLE" then
        -- Treble enemies: Small, fast, fragile (IMPROVED VISIBILITY)
        self.width = 18  -- Increased from 10
        self.height = 18  -- Increased from 10
        self.speed = 200  -- Slowed from 100
        self.hp = 10  -- Increased from 25
        self.maxHp = 40
        self.damage = 15
        self.expReward = 20
        self.shape = "triangle"  -- Changed from diamond to triangle
        self.frequencyType = "treble"
        self.overlayColor = levelColor
        
    elseif self.enemyType == "BOSS" then
        -- Boss enemies: Large, powerful, rainbow overlay
        self.width = 60
        self.height = 60
        self.speed = 80
        self.hp = 500
        self.maxHp = 500
        self.damage = 50
        self.expReward = 200
        self.shape = "complex"
        self.frequencyType = "full"
        self.overlayColor = {1, 1, 1}  -- Will cycle through rainbow
        
    elseif self.enemyType == "formation" then
        -- Legacy formation enemies: blocky, slower, tankier
        self.speed = 40
        self.hp = 70
        self.maxHp = 70
        self.damage = 30
        self.expReward = 30
        self.baseColor = {1, 1, 1}  -- White base
        self.overlayColor = levelColor  -- Use level-based color
        self.overlayAlpha = 0.5
        self.shape = "square"
        
    elseif self.enemyType == "flanker" then
        -- Legacy flanking enemies: arrow, faster, weaker
        self.speed = 80
        self.hp = 25
        self.maxHp = 25
        self.damage = 20
        self.expReward = 20
        self.baseColor = {1, 1, 1}  -- White base
        self.overlayColor = levelColor  -- Use level-based color
        self.overlayAlpha = 0.5
        self.shape = "triangle"
        self.angle = 0  -- Rotation angle
    end
    
    -- Apply prestige scaling (each 40 levels = one prestige tier)
    -- Prestige 0 (level 1-40): 1.0x stats
    -- Prestige 1 (level 41-80): 1.15x stats
    -- Prestige 2 (level 81-120): 1.30x stats, etc.
    local prestigeTier = math.floor((playerLevel - 1) / 40)
    if prestigeTier > 0 then
        local statMultiplier = 1 + (prestigeTier * 0.15)
        self.hp = math.floor(self.hp * statMultiplier)
        self.maxHp = math.floor(self.maxHp * statMultiplier)
        self.damage = math.floor(self.damage * statMultiplier)
        self.expReward = math.floor(self.expReward * statMultiplier)
    end
    
    -- Initial velocity based on spawn side (for flankers)
    self.vx = self.formationData.vx or 0
    self.vy = self.formationData.vy or 0
end

function Enemy:update(dt, playerX, playerY)
    if self.dead then return end
    
    self.age = self.age + dt
    
    -- Handle activation: enemies spawn above screen and become active after moving down
    if self.inactive then
        -- Move down slowly until reaching activation threshold
        self.y = self.y + self.speed * dt
        
        -- Check if enemy has entered the activation zone (10% of screen height)
        if self.activationY and self.y >= self.activationY then
            self.inactive = false
        end
        
        -- Don't update other behavior while inactive
        return
    end
    
    -- Check if should start following player
    if not self.isFollowing and self.age >= self.followDelay then
        self.isFollowing = true
    end
    
    -- Handle marching enemies (from GridAttackSystem)
    if self.isMarchingEnemy and self.marchTarget then
        self:marchTowardTarget(dt)
    -- If following, move toward player
    elseif self.isFollowing then
        self:followPlayer(dt, playerX, playerY)
    else
        -- Use original pattern-based movement
        if self.enemyType == "formation" then
            self:updateFormationMovement(dt, playerX, playerY)
        elseif self.enemyType == "flanker" then
            self:updateFlankerMovement(dt, playerX, playerY)
        end
    end
end

function Enemy:marchTowardTarget(dt)
    -- March toward target position (horizontal only, stay in same Y row)
    local dx = self.marchTarget.x - (self.x + self.width / 2)
    local distance = math.abs(dx)

    if distance > 5 then  -- Still marching
        -- Move horizontally toward target
        local direction = dx > 0 and 1 or -1
        self.vx = direction * self.speed
        self.vy = 0  -- Stay in same row

        self.x = self.x + self.vx * dt
    else
        -- Reached center, stop marching and start following player
        self.isMarchingEnemy = false
        self.isFollowing = true
    end
end

function Enemy:followPlayer(dt, playerX, playerY)
    -- Calculate direction to player
    local dx = playerX - (self.x + self.width / 2)
    local dy = playerY - (self.y + self.height / 2)
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 0 then
        -- Normalize and apply speed
        local followSpeed = self.speed * 1.5  -- Slightly faster when following
        self.vx = (dx / distance) * followSpeed
        self.vy = (dy / distance) * followSpeed
        
        -- Move toward player
        self.x = self.x + self.vx * dt
        self.y = self.y + self.vy * dt
        
        -- Update angle for visual rotation (flankers)
        if self.enemyType == "flanker" then
            self.angle = math.atan(self.vy, self.vx)
        end
    end
end

function Enemy:updateFormationMovement(dt, playerX, playerY)
    if self.pattern == "formation_hold" then
        -- Hold position during formation tween (flux handles movement)
        -- Do nothing, flux is moving the enemy
        
    elseif self.pattern == "formation_sway" then
        -- Gentle swaying movement after formation arrives
        if self.formationData then
            local swaySpeed = 0.5
            local swayAmount = 15
            local targetX = self.formationData.centerX + self.formationData.offsetX + math.sin(self.age * swaySpeed) * swayAmount
            self.x = self.x + (targetX - self.x) * 2 * dt
        end
        
    elseif self.pattern == "descend_straight" then
        -- Straight downward
        self.y = self.y + self.speed * dt
        
    elseif self.pattern == "descend_wave" then
        -- Sway side to side while descending
        self.x = self.x + math.sin(self.age * 2) * 30 * dt
        self.y = self.y + self.speed * dt
        
    elseif self.pattern == "sine_descend" then
        -- Wave pattern while descending
        local phase = self.formationData.phase or 0
        self.x = self.x + math.sin(self.age * 3 + phase) * 50 * dt
        self.y = self.y + self.speed * dt
        
    elseif self.pattern == "hold_formation" then
        -- Maintain formation position, slow descent
        if self.formationData.offsetX then
            local targetX = (self.formationData.centerX or playerX) + self.formationData.offsetX
            self.x = self.x + (targetX - self.x) * 2 * dt
        end
        self.y = self.y + self.speed * 0.5 * dt
    end
end

function Enemy:updateFlankerMovement(dt, playerX, playerY)
    if self.pattern == "straight" then
        -- Straight horizontal movement
        self.x = self.x + self.vx * dt
        self.y = self.y + self.vy * dt
        
    elseif self.pattern == "zigzag" then
        -- Horizontal + vertical oscillation
        self.x = self.x + self.vx * dt
        self.y = self.y + math.sin(self.age * 5 + self.x * 0.02) * 150 * dt
        
    elseif self.pattern == "dive" then
        -- Start horizontal, dive toward player when close
        local dx = playerX - self.x
        local distX = math.abs(dx)
        
        if distX < 150 then
            -- Dive toward player
            local dy = playerY - self.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance > 0 then
                self.vx = (dx / distance) * self.speed
                self.vy = (dy / distance) * self.speed
            end
        end
        
        self.x = self.x + self.vx * dt
        self.y = self.y + self.vy * dt
    end
    
    -- Update rotation angle for visual direction
    self.angle = math.atan(self.vy, self.vx)
end

function Enemy:draw(musicReactor)
    if self.dead then return end
    
    local centerX = self.x + self.width/2
    local centerY = self.y + self.height/2
    local size = self.width / 2
    
    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    
    -- NEW: Solid vaporwave colored enemies
    if self.frequencyType then
        -- Draw outer rings using ShapeLibrary (at origin, already transformed)
        if self.ringCount then
            drawOuterRings(self.shape, self.width, self.ringCount, self.playerLevel)
        end
        
        -- Get color
        local color = self.overlayColor or {1, 1, 1}
        
        -- Draw solid colored shape using ShapeLibrary
        if self.shape == "square" then
            ShapeLibrary.square(0, 0, self.width, color)
        elseif self.shape == "circle" then
            ShapeLibrary.circle(0, 0, size, color)
        elseif self.shape == "hexagon" then
            ShapeLibrary.hexagon(0, 0, size, color, {rotation = -math.pi/2})
        elseif self.shape == "triangle" then
            ShapeLibrary.triangle(0, 0, size, color, {pointUp = true})
        elseif self.shape == "diamond" then
            ShapeLibrary.diamond(0, 0, size, color)
        elseif self.shape == "complex" then
            -- Boss: Rainbow octagon with inner ring
            local hueShift = (love.timer.getTime() * 0.5) % 1
            local r = 0.5 + 0.5 * math.sin(hueShift * math.pi * 2)
            local g = 0.5 + 0.5 * math.sin((hueShift + 0.33) * math.pi * 2)
            local b = 0.5 + 0.5 * math.sin((hueShift + 0.66) * math.pi * 2)
            ShapeLibrary.octagon(0, 0, size, {r, g, b}, {
                innerRing = {size = size * 0.6, color = {r, g, b}}
            })
        end
        
    -- LEGACY: Old formation/flanker enemy types (now using level colors)
    elseif self.enemyType == "formation" then
        -- Draw outer rings
        if self.ringCount then
            drawOuterRings(self.shape, self.width, self.ringCount, self.playerLevel)
        end
        
        -- Use overlay color (level-based)
        local color = self.overlayColor or {0.8, 0.2, 0.2}
        
        if self.shape == "square" then
            -- Blocky square with antenna using ShapeLibrary
            ShapeLibrary.square(0, 0, self.width, color)
            
            -- Antenna detail
            love.graphics.setColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7)
            love.graphics.rectangle("fill", -2, -self.height/2 - 4, 4, 4)
            
        elseif self.shape == "hexagon" then
            ShapeLibrary.hexagon(0, 0, size, color)
        end
        
    elseif self.enemyType == "flanker" then
        -- Use overlay color (level-based)
        local color = self.overlayColor or {0.3, 0.3, 0.8}
        
        -- Rotate to face direction of travel
        if self.vx ~= 0 or self.vy ~= 0 then
            love.graphics.rotate(self.angle)
        end
        
        -- Draw outer rings (at origin, already transformed)
        if self.ringCount then
            drawOuterRings(self.shape, self.width, self.ringCount, self.playerLevel)
        end
        
        -- Draw arrow shape using ShapeLibrary
        ShapeLibrary.arrow(0, 0, size, color, {
            angle = 0,  -- Already rotated by love.graphics.rotate
            showWingDetails = true
        })
    end
    
    love.graphics.pop()
    
    -- Draw HP bar using ShapeLibrary
    ShapeLibrary.progressBar(self.x, self.y - 8, self.width, 4, self.hp / self.maxHp, {
        bgColor = {0.3, 0.3, 0.3},
        fgColor = {0.2, 0.8, 0.2}
    })
end

function Enemy:takeDamage(amount)
    self.hp = self.hp - amount
    if self.hp <= 0 then
        self.dead = true
        return self.expReward
    end
    return 0
end

function Enemy:checkCollision(projectile)
    if self.dead then return false end
    
    -- Simple AABB collision
    return projectile.x > self.x and
           projectile.x < self.x + self.width and
           projectile.y > self.y and
           projectile.y < self.y + self.height
end

return Enemy
