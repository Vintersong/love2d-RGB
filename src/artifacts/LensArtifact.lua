-- LENS Artifact: Focus/Amplification
-- Color-specific behaviors for LENS artifact

local LensArtifact = {}

local SYNERGY_FIELDS = {
    "canBounceToNearest", "maxBounces", "canPierce", "maxPierces",
    "canRoot", "rootDuration", "canExplode", "explodeRadius", "explodeDamage",
    "canDot", "dotDuration", "dotDamage", "colorName", "shape",
    "lensThunderball", "thunderfieldRadius", "thunderfieldDPS", "thunderfieldDuration",
    "mirrorFireTrail", "mirrorTrailDamage", "mirrorTrailDuration",
    "electricTrail", "trailDamage", "trailDuration",
    "diffractionBurnZone", "burnZoneRadius", "burnZoneDPS", "burnZoneDuration",
    "waveEcho", "waveRadius", "wavePullForce",
    "gravityWell", "wellRadius", "wellPullForce",
    "poisonBloom", "bloomRadius", "bloomDamageRatio",
    "dotCloud", "cloudRadius", "cloudDamageRatio",
    "refractionFrostPatches", "frostPatchRadius", "frostPatchSlow", "frostPatchDuration",
    "refractionFireArms", "spiralTrailDPS", "spiralTrailDuration",
    "prismRootBonus", "rootRadius",
}

local function inheritSynergyFields(source, target)
    for _, field in ipairs(SYNERGY_FIELDS) do
        target[field] = source[field]
    end
    target.currentBounces = source.currentBounces or 0
    target.pierceCount = source.pierceCount or 0
    target.hitEnemies = {}
end

local function getMergedVelocity(projectiles, speedMultiplier)
    local vx, vy = 0, 0

    for _, projectile in ipairs(projectiles) do
        vx = vx + (projectile.vx or 0)
        vy = vy + (projectile.vy or 0)
    end

    local speed = (projectiles[1].speed or math.sqrt((projectiles[1].vx or 0)^2 + (projectiles[1].vy or 0)^2)) * (speedMultiplier or 1)
    local length = math.sqrt(vx * vx + vy * vy)

    if length <= 0 then
        return (projectiles[1].vx or 0) * (speedMultiplier or 1), (projectiles[1].vy or 0) * (speedMultiplier or 1)
    end

    return (vx / length) * speed, (vy / length) * speed
end

-- RED LENS: Merge projectiles into larger shot
LensArtifact.RED = {
    name = "Crimson Lens",
    effect = "merge_projectiles",
    
    getChance = function(level)
        return 0.15 + (level * 0.02)  -- 15-25% chance
    end,
    
    behavior = function(projectiles, level)
        local chance = LensArtifact.RED.getChance(level)
        
        if math.random() < chance and #projectiles >= 2 then
            -- Merge all projectiles into one large projectile
            local baseSize = projectiles[1].size or 4  -- Default size if not set
            local mergedVx, mergedVy = getMergedVelocity(projectiles)
            local merged = {
                x = projectiles[1].x,
                y = projectiles[1].y,
                vx = mergedVx,
                vy = mergedVy,
                size = baseSize * math.sqrt(#projectiles),  -- Size scales with count
                damage = projectiles[1].damage * #projectiles,  -- Combined damage
                color = projectiles[1].color,
                speed = projectiles[1].speed,
                -- Copy all abilities
                pierce = projectiles[1].pierce,
                bounce = projectiles[1].bounce,
                pierceCount = projectiles[1].pierceCount,
                bounceCount = projectiles[1].bounceCount,
                hitEnemies = {},
                merged = true,
                mergeCount = #projectiles
            }
            inheritSynergyFields(projectiles[1], merged)
            
            -- Return only the merged projectile
            return {merged}
        end
        
        return projectiles
    end,
    
    visual = "red_merge_convergence"
}

-- GREEN LENS: Pull enemies toward projectile
LensArtifact.GREEN = {
    name = "Verdant Lens",
    effect = "gravitational_pull",
    
    getChance = function(level)
        return 0.20 + (level * 0.02)  -- 20-30% chance
    end,
    
    behavior = function(projectile, level)
        local chance = LensArtifact.GREEN.getChance(level)
        
        if math.random() < chance then
            projectile.pullRadius = 100 + (level * 10)
            projectile.pullStrength = 200  -- Pixels per second
            projectile.gravitationalPull = true
        end
    end,
    
    update = function(projectile, enemies, dt)
        if projectile.gravitationalPull then
            for _, enemy in ipairs(enemies) do
                if not enemy.dead then
                    local dx = projectile.x - enemy.x
                    local dy = projectile.y - enemy.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    
                    if distance < projectile.pullRadius and distance > 0 then
                        -- Pull enemy toward projectile
                        local pullForce = projectile.pullStrength * (1 - distance / projectile.pullRadius)
                        enemy.x = enemy.x + (dx / distance) * pullForce * dt
                        enemy.y = enemy.y + (dy / distance) * pullForce * dt
                    end
                end
            end
        end
    end,
    
    visual = "green_gravity_field"
}

-- BLUE LENS: Enlarge projectiles
LensArtifact.BLUE = {
    name = "Azure Lens",
    effect = "enlarge_projectiles",
    
    getMultiplier = function(level)
        return 1.0 + (level * 0.15)  -- +15% size per level
    end,
    
    behavior = function(projectile, level)
        local multiplier = LensArtifact.BLUE.getMultiplier(level)
        local baseSize = projectile.size or 4  -- Default size if not set
        projectile.size = baseSize * multiplier
        projectile.damage = projectile.damage * (1.0 + (multiplier - 1.0) * 0.5)  -- Slight damage boost
        projectile.enlarged = true
    end,
    
    visual = "blue_size_pulse"
}

-- YELLOW LENS: Fast merged projectiles with pull (RED + GREEN + speed)
LensArtifact.YELLOW = {
    name = "Electric Lens",
    effect = "fast_merged_pull",
    
    getChance = function(level)
        return 0.20  -- Fixed 20% chance
    end,
    
    behavior = function(projectiles, level)
        local chance = LensArtifact.YELLOW.getChance(level)
        
        if math.random() < chance and #projectiles >= 2 then
            -- Merge projectiles (RED trait)
            local baseSize = projectiles[1].size or 4  -- Default size if not set
            local mergedVx, mergedVy = getMergedVelocity(projectiles, 1.5)
            local merged = {
                x = projectiles[1].x,
                y = projectiles[1].y,
                vx = mergedVx,  -- YELLOW speed boost
                vy = mergedVy,
                size = baseSize * math.sqrt(#projectiles),
                damage = projectiles[1].damage * #projectiles,
                color = {1, 1, 0.3},  -- Yellow/electric
                speed = projectiles[1].speed * 1.5,
                pierce = projectiles[1].pierce,
                bounce = projectiles[1].bounce,
                pierceCount = projectiles[1].pierceCount,
                bounceCount = projectiles[1].bounceCount,
                hitEnemies = {},
                merged = true,
                mergeCount = #projectiles,
                -- GREEN trait: Gravitational pull
                gravitationalPull = true,
                pullRadius = 120,
                pullStrength = 250,
                electricTrail = true
            }
            inheritSynergyFields(projectiles[1], merged)
            merged.electricTrail = true
            
            return {merged}
        end
        
        return projectiles
    end,
    
    visual = "yellow_electric_merge"
}

-- MAGENTA LENS: Merged large projectiles with time delay (RED + BLUE + time)
LensArtifact.MAGENTA = {
    name = "Temporal Lens",
    effect = "time_delayed_merge",
    
    getChance = function(level)
        return 0.18  -- 18% chance
    end,
    
    behavior = function(projectiles, level)
        local chance = LensArtifact.MAGENTA.getChance(level)
        
        if math.random() < chance and #projectiles >= 2 then
            -- Merge (RED) + Enlarge (BLUE)
            local baseSize = projectiles[1].size or 4  -- Default size if not set
            local mergedVx, mergedVy = getMergedVelocity(projectiles)
            local merged = {
                x = projectiles[1].x,
                y = projectiles[1].y,
                vx = mergedVx,
                vy = mergedVy,
                size = baseSize * math.sqrt(#projectiles) * 1.5,  -- Extra large
                damage = projectiles[1].damage * #projectiles,
                color = {1, 0.3, 1},  -- Magenta
                speed = projectiles[1].speed,
                pierce = projectiles[1].pierce,
                bounce = projectiles[1].bounce,
                pierceCount = projectiles[1].pierceCount,
                bounceCount = projectiles[1].bounceCount,
                hitEnemies = {},
                merged = true,
                mergeCount = #projectiles,
                -- MAGENTA trait: Time delay
                timeDelay = 0.5,  -- Hits 0.5s after contact
                temporalEcho = true
            }
            inheritSynergyFields(projectiles[1], merged)
            
            return {merged}
        end
        
        return projectiles
    end,
    
    visual = "magenta_temporal_afterimages"
}

-- CYAN LENS: Large projectiles with pull and slow (GREEN + BLUE + frost)
LensArtifact.CYAN = {
    name = "Glacial Lens",
    effect = "frost_pull_enlarge",
    
    behavior = function(projectile, level)
        -- Enlarge (BLUE trait)
        local baseSize = projectile.size or 4  -- Default size if not set
        projectile.size = baseSize * 1.4
        
        -- Pull (GREEN trait)
        projectile.gravitationalPull = true
        projectile.pullRadius = 100
        projectile.pullStrength = 180
        
        -- CYAN trait: Slow debuff
        projectile.applySlowDebuff = true
        projectile.slowPercent = 0.5  -- 50% slow
        projectile.slowDuration = 2.0
        projectile.frostEffect = true
    end,
    
    update = function(projectile, enemies, dt)
        if projectile.gravitationalPull then
            for _, enemy in ipairs(enemies) do
                if not enemy.dead then
                    local dx = projectile.x - enemy.x
                    local dy = projectile.y - enemy.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    
                    if distance < projectile.pullRadius and distance > 0 then
                        -- Pull enemy
                        local pullForce = projectile.pullStrength * (1 - distance / projectile.pullRadius)
                        enemy.x = enemy.x + (dx / distance) * pullForce * dt
                        enemy.y = enemy.y + (dy / distance) * pullForce * dt
                        
                        -- Apply slow (CYAN)
                        if projectile.applySlowDebuff then
                            enemy.speedMultiplier = 1.0 - projectile.slowPercent
                            enemy.slowedUntil = love.timer.getTime() + projectile.slowDuration
                        end
                    end
                end
            end
        end
    end,
    
    visual = "cyan_frost_gravity"
}

-- Apply LENS effect based on dominant color
function LensArtifact.apply(projectiles, level, dominantColor)
    if not dominantColor then return projectiles end
    
    local colorBehavior = LensArtifact[dominantColor]
    if not colorBehavior then return projectiles end
    
    -- For merge behaviors (RED, YELLOW, MAGENTA), apply to full array
    if dominantColor == "RED" or dominantColor == "YELLOW" or dominantColor == "MAGENTA" then
        return colorBehavior.behavior(projectiles, level)
    else
        -- For per-projectile behaviors (GREEN, BLUE, CYAN), apply to each
        for _, proj in ipairs(projectiles) do
            colorBehavior.behavior(proj, level)
        end
        return projectiles
    end
end

-- Update function for projectiles with LENS effects
function LensArtifact.update(projectiles, enemies, dt, dominantColor)
    local colorBehavior = LensArtifact[dominantColor]
    if not colorBehavior or not colorBehavior.update then return end
    
    for _, proj in ipairs(projectiles) do
        colorBehavior.update(proj, enemies, dt)
    end
end

local LENS_COLORS = {
    RED     = {1,    0.2,  0.2 },
    GREEN   = {0.2,  1,    0.3 },
    BLUE    = {0.3,  0.5,  1   },
    YELLOW  = {1,    1,    0.2 },
    MAGENTA = {1,    0.2,  1   },
    CYAN    = {0.2,  1,    1   },
}

-- Draw: two counterrotating ellipses creating a focusing effect, with cardinal tick marks
function LensArtifact.draw(player, dominantColor)
    if not dominantColor or not player then return end

    local c  = LENS_COLORS[dominantColor] or {1, 1, 1}
    local cx = player.x + player.width  / 2
    local cy = player.y + player.height / 2
    local t  = love.timer.getTime()

    local baseR = player.width / 2 + 18
    local pulse = 1 + math.sin(t * 2.2) * 0.06   -- gentle breathe

    love.graphics.push()
    love.graphics.translate(cx, cy)

    -- Two counterrotating ellipses
    for i = 0, 1 do
        local angle = t * 0.5 * (i == 0 and 1 or -1)
        love.graphics.push()
        love.graphics.rotate(angle)
        love.graphics.setColor(c[1], c[2], c[3], 0.75)
        love.graphics.setLineWidth(1.5)
        love.graphics.ellipse("line", 0, 0, baseR * pulse, baseR * 0.45 * pulse)
        love.graphics.pop()
    end

    -- Cardinal tick marks pointing inward (optical measurement feel)
    love.graphics.setColor(c[1], c[2], c[3], 0.9)
    love.graphics.setLineWidth(1.5)
    for i = 0, 3 do
        local a    = (i / 4) * math.pi * 2
        local near = baseR - 6
        local far  = baseR + 6
        love.graphics.line(
            math.cos(a) * near, math.sin(a) * near,
            math.cos(a) * far,  math.sin(a) * far)
    end

    -- Bright focal centre dot
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", 0, 0, 2.5)

    love.graphics.pop()
end

return LensArtifact
