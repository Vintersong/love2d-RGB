-- LENS Artifact: Focus/Amplification
-- Color-specific behaviors for LENS artifact

local LensArtifact = {}

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
            local merged = {
                x = projectiles[1].x,
                y = projectiles[1].y,
                vx = projectiles[1].vx,
                vy = projectiles[1].vy,
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
            local merged = {
                x = projectiles[1].x,
                y = projectiles[1].y,
                vx = projectiles[1].vx * 1.5,  -- YELLOW speed boost
                vy = projectiles[1].vy * 1.5,
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
            local merged = {
                x = projectiles[1].x,
                y = projectiles[1].y,
                vx = projectiles[1].vx,
                vy = projectiles[1].vy,
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

return LensArtifact
