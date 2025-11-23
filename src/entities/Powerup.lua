-- Artifact drops from enemies - Physical/Optical Phenomena
local class = require("libs.hump-master.class")
local Entity = require("src.entities.Entity")
local Powerup = class{__includes = Entity}

-- Artifact types based on physical/optical phenomena
Powerup.Types = {
    PRISM = {
        name = "Prism",
        color = {1, 0.2, 1},  -- Magenta (light refraction)
        description = "Light Refraction",
        effect = function(player)
            -- Splits projectiles (like light through a prism)
            if player.weapon then
                player.weapon.prismBonus = (player.weapon.prismBonus or 0) + 1
                player.weapon.prismDuration = 12  -- 12 seconds
            end
            return "Prism: +1 Projectile Split (12s)"
        end,
        dropChance = 0.20
    },
    HALO = {
        name = "Halo",
        color = {1, 1, 0.3},  -- Golden (atmospheric ring)
        description = "Atmospheric Ring",
        effect = function(player)
            -- Protective ring effect
            player.haloShield = (player.haloShield or 0) + 30
            player.haloActive = true
            return "Halo: +30 Shield"
        end,
        dropChance = 0.20
    },
    MIRROR = {
        name = "Mirror",
        color = {0.7, 0.9, 1},  -- Silver (reflection)
        description = "Perfect Reflection",
        effect = function(player)
            -- Reflects damage back to enemies
            player.mirrorReflection = 0.5  -- Reflect 50% damage
            player.mirrorDuration = 10  -- 10 seconds
            return "Mirror: Reflect 50% Damage (10s)"
        end,
        dropChance = 0.15
    },
    LENS = {
        name = "Lens",
        color = {0.3, 0.8, 1},  -- Blue (focus)
        description = "Focal Point",
        effect = function(player)
            -- Focuses damage (increases projectile damage)
            if player.weapon then
                player.weapon.lensBonus = (player.weapon.lensBonus or 0) + 0.5
                player.weapon.lensDuration = 8  -- 8 seconds
            end
            return "Lens: +50% Damage Focus (8s)"
        end,
        dropChance = 0.15
    },
    AURORA = {
        name = "Aurora",
        color = {0.4, 1, 0.8},  -- Cyan/Green (ionization)
        description = "Ionized Glow",
        effect = function(player)
            -- Energy regeneration
            player.auroraRegen = 3  -- 3 HP per second
            player.auroraDuration = 7  -- 7 seconds
            return "Aurora: +3 HP/s (7s)"
        end,
        dropChance = 0.15
    },
    DIFFRACTION = {
        name = "Diffraction",
        color = {1, 0.5, 0.2},  -- Orange (wave bending)
        description = "Wave Interference",
        effect = function(player)
            -- Bends projectiles around player
            player.magnetRadius = 500  -- Large XP collection
            player.magnetDuration = 10  -- 10 seconds
            return "Diffraction: XP Magnet (10s)"
        end,
        dropChance = 0.10
    },
    REFRACTION = {
        name = "Refraction",
        color = {0.5, 0.3, 1},  -- Purple (light bending)
        description = "Light Bending",
        effect = function(player)
            -- Speed boost (bend time)
            player.speedBoost = (player.speedBoost or 0) + 0.6
            player.speedBoostDuration = 8  -- 8 seconds
            return "Refraction: +60% Speed (8s)"
        end,
        dropChance = 0.10
    },
    SUPERNOVA = {
        name = "Supernova",
        color = {1, 0.3, 0.2},  -- Red (stellar explosion)
        description = "Stellar Explosion",
        effect = function(player)
            -- Screen clear
            return "SCREEN_CLEAR"
        end,
        dropChance = 0.05
    }
}

function Powerup:init(x, y, powerupType)
    self.x = x or 0
    self.y = y or 0
    self.width = 20
    self.height = 20
    self.type = powerupType or "PRISM"
    self.typeData = Powerup.Types[self.type]
    self.collected = false
    
    -- Movement
    self.vx = 0
    self.vy = 0
    self.lifetime = 20  -- Despawn after 20 seconds (artifacts last longer)
    
    -- Visual
    self.pulseTime = 0
    self.rotation = math.random() * math.pi * 2
end

function Powerup:update(dt, playerX, playerY)
    if self.collected then return end
    
    self.lifetime = self.lifetime - dt
    self.pulseTime = self.pulseTime + dt
    self.rotation = self.rotation + dt * 2
    
    -- Move toward player if within magnet range
    local dx = playerX - self.x
    local dy = playerY - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    
    -- Check for magnet effect (will be set by player)
    local magnetRange = 120  -- Slightly larger default range for artifacts
    if dist < magnetRange then
        local speed = 250
        self.vx = (dx / dist) * speed
        self.vy = (dy / dist) * speed
    else
        self.vx = 0
        self.vy = 0
    end
    
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
end

function Powerup:draw()
    if self.collected then return end
    
    -- Pulsing and rotating effect
    local pulse = 1 + math.sin(self.pulseTime * 4) * 0.3
    local size = self.width * pulse
    
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.rotation)
    
    -- Draw artifact as diamond/gem shape
    love.graphics.setColor(self.typeData.color)
    love.graphics.polygon("fill", 
        0, -size/2,      -- Top
        size/3, 0,       -- Right
        0, size/2,       -- Bottom
        -size/3, 0       -- Left
    )
    
    -- Glowing outline
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", 
        0, -size/2,
        size/3, 0,
        0, size/2,
        -size/3, 0
    )
    
    -- Inner glow
    love.graphics.setColor(self.typeData.color[1], self.typeData.color[2], self.typeData.color[3], 0.5)
    local innerSize = size * 0.5
    love.graphics.polygon("fill",
        0, -innerSize/2,
        innerSize/3, 0,
        0, innerSize/2,
        -innerSize/3, 0
    )
    
    love.graphics.pop()
    
    -- Blink when about to expire
    if self.lifetime < 5 and math.floor(self.lifetime * 4) % 2 == 0 then
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.circle("line", self.x, self.y, size * 1.5)
    end
end

function Powerup:checkCollision(player)
    local dx = player.x + player.width/2 - self.x
    local dy = player.y + player.height/2 - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    return dist < (self.width + player.width) / 2
end

function Powerup:collect(player)
    if self.collected then return nil end
    
    self.collected = true
    
    -- Use ArtifactManager to handle leveling
    local ArtifactManager = require("src.systems.ArtifactManager")
    local result = ArtifactManager.collect(self.type, player.weapon, player)
    
    -- Check for synergies with current color build (only on first collection)
    if result and result.success and result.level == 1 then
        local SynergySystem = require("src.systems.SynergySystem")
        local synergyMessage = SynergySystem.checkAndActivate(self.type, player.weapon, player)
        
        if synergyMessage then
            -- Add synergy info to result
            result.synergyMessage = synergyMessage
        end
    end
    
    return result
end

-- Helper function to determine drop
function Powerup.shouldDrop()
    return math.random() < 0.12  -- 12% chance for artifacts (reduced from 20%)
end

function Powerup.getRandomType()
    local totalWeight = 0
    local weights = {}
    
    for typeName, typeData in pairs(Powerup.Types) do
        table.insert(weights, {name = typeName, chance = typeData.dropChance})
        totalWeight = totalWeight + typeData.dropChance
    end
    
    local roll = math.random() * totalWeight
    local current = 0
    
    for _, weight in ipairs(weights) do
        current = current + weight.chance
        if roll <= current then
            return weight.name
        end
    end
    
    return "PRISM"  -- Fallback
end

return Powerup
