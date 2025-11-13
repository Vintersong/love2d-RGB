-- PRISM Artifact: Splitting/Projection
-- Color-specific behaviors for PRISM artifact

local PrismArtifact = {}

-- RED PRISM: Wall of projectiles forward (shotgun)
PrismArtifact.RED = {
    name = "Crimson Prism",
    effect = "forward_wall",
    
    getChance = function(level)
        return 0.20 + (level * 0.02)  -- 20-30% chance
    end,
    
    behavior = function(projectiles, level, targetX, targetY, player)
        local chance = PrismArtifact.RED.getChance(level)
        
        if math.random() < chance then
            -- Create wall of projectiles in cone
            local wall = {}
            local projectileCount = 5 + level  -- 6-10 projectiles
            local spreadAngle = math.pi / 3  -- 60 degrees
            
            -- Base angle toward target
            local baseAngle = math.atan(targetY - player.y, targetX - player.x)
            
            for i = 1, projectileCount do
                local angleOffset = spreadAngle * ((i - 1) / (projectileCount - 1) - 0.5)
                local angle = baseAngle + angleOffset
                
                local wallProj = {
                    x = player.x,
                    y = player.y,
                    vx = math.cos(angle) * 300,
                    vy = math.sin(angle) * 300,
                    damage = projectiles[1].damage * 0.7,
                    speed = 300,
                    color = {1, 0, 0},  -- Red
                    size = 4,
                    shape = "prism",
                    type = "prism_wall",
                    prismWall = true
                }
                
                table.insert(wall, wallProj)
            end
            
            -- Replace with wall
            return wall
        end
        
        return projectiles
    end,
    
    visual = "red_shotgun_cone"
}

-- GREEN PRISM: Projectile orbits enemy
PrismArtifact.GREEN = {
    name = "Verdant Prism",
    effect = "orbit_enemy",
    
    getChance = function(level)
        return 0.15 + (level * 0.02)  -- 15-25% chance
    end,
    
    behavior = function(projectile, level)
        local chance = PrismArtifact.GREEN.getChance(level)
        
        if math.random() < chance then
            projectile.orbitSeek = true
            projectile.orbitRadius = 30
            projectile.orbitSpeed = 2.0  -- radians/sec
            projectile.orbitAngle = 0
            projectile.orbitTarget = nil
            projectile.orbitDamage = projectile.damage * 0.1  -- DPS while orbiting
        end
    end,
    
    update = function(projectile, enemies, dt)
        if projectile.orbitSeek and not projectile.orbitTarget then
            -- Find nearest enemy to lock onto
            local nearestDist = math.huge
            local nearest = nil
            
            for _, enemy in ipairs(enemies) do
                if not enemy.dead then
                    local dx = enemy.x - projectile.x
                    local dy = enemy.y - projectile.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    
                    if dist < 100 and dist < nearestDist then
                        nearestDist = dist
                        nearest = enemy
                    end
                end
            end
            
            if nearest then
                projectile.orbitTarget = nearest
            end
        elseif projectile.orbitTarget then
            if not projectile.orbitTarget.dead then
                -- Orbit around locked enemy
                projectile.orbitAngle = projectile.orbitAngle + projectile.orbitSpeed * dt
                projectile.x = projectile.orbitTarget.x + math.cos(projectile.orbitAngle) * projectile.orbitRadius
                projectile.y = projectile.orbitTarget.y + math.sin(projectile.orbitAngle) * projectile.orbitRadius
                
                -- Continuous damage (handled by collision system)
                projectile.orbitDamageTick = true
            else
                -- Target died, seek new one
                projectile.orbitTarget = nil
            end
        end
    end,
    
    visual = "green_orbit_tether"
}

-- BLUE PRISM: Projectile grows when piercing
PrismArtifact.BLUE = {
    name = "Azure Prism",
    effect = "grow_on_pierce",
    
    getChance = function(level)
        return 0.18 + (level * 0.02)  -- 18-28% chance
    end,
    
    behavior = function(projectile, level)
        local chance = PrismArtifact.BLUE.getChance(level)
        
        if math.random() < chance then
            projectile.growOnPierce = true
            projectile.growthPerHit = 4  -- +4px per enemy
            projectile.maxSize = 40
            projectile.canPierce = true
            projectile.hitEnemies = projectile.hitEnemies or {}
            projectile.maxPierces = 10
            projectile.pierceCount = 0
        end
    end,
    
    visual = "blue_growing_projectile"
}

-- YELLOW PRISM: Laser beam orbits player (RED wall + GREEN orbit + speed)
PrismArtifact.YELLOW = {
    name = "Electric Prism",
    effect = "orbiting_laser",
    
    -- This is a passive effect, not chance-based
    -- Applied as aura/field effect similar to HALO
    behavior = function(player, level)
        if not player.yellowLaser then
            player.yellowLaser = {
                active = true,
                radius = 100 + (level * 5),
                angle = 0,
                rotationSpeed = 4.0,  -- Fast rotation
                damage = 5 * level,
                width = 3
            }
        end
    end,
    
    update = function(laser, dt, enemies, player)
        if laser and laser.active then
            laser.angle = laser.angle + laser.rotationSpeed * dt
            
            -- Calculate beam endpoint
            local endX = player.x + math.cos(laser.angle) * laser.radius
            local endY = player.y + math.sin(laser.angle) * laser.radius
            
            -- Damage would be handled by line-circle intersection in main system
            laser.endX = endX
            laser.endY = endY
        end
    end,
    
    visual = "yellow_spinning_laser"
}

-- MAGENTA PRISM: Wall of growing projectiles (RED wall + BLUE growth + time)
PrismArtifact.MAGENTA = {
    name = "Temporal Prism",
    effect = "growing_wall",
    
    getChance = function(level)
        return 0.15  -- 15%
    end,
    
    behavior = function(projectiles, level, targetX, targetY, player)
        local chance = PrismArtifact.MAGENTA.getChance(level)
        
        if math.random() < chance then
            -- Create wall (RED trait) where each grows (BLUE trait)
            local wall = {}
            local projectileCount = 6
            local spreadAngle = math.pi / 4
            local baseAngle = math.atan(targetY - player.y, targetX - player.x)
            
            for i = 1, projectileCount do
                local angleOffset = spreadAngle * ((i - 1) / (projectileCount - 1) - 0.5)
                local angle = baseAngle + angleOffset
                
                local wallProj = {
                    x = player.x,
                    y = player.y,
                    vx = math.cos(angle) * 280,
                    vy = math.sin(angle) * 280,
                    damage = projectiles[1].damage * 0.7,
                    speed = 280,
                    color = {1, 0.3, 1},  -- Magenta
                    size = 4,
                    shape = "triangle",
                    type = "prism_wall",
                    growOnPierce = true,  -- BLUE growth
                    growthPerHit = 3,
                    maxSize = 35,
                    canPierce = true,
                    hitEnemies = {},
                    maxPierces = 10,
                    pierceCount = 0,
                    temporalEchoes = true
                }
                
                table.insert(wall, wallProj)
            end
            
            return wall
        end
        
        return projectiles
    end,
    
    visual = "magenta_growing_wall"
}

-- CYAN PRISM: Orbiting projectile expands and freezes (GREEN orbit + BLUE growth + freeze)
PrismArtifact.CYAN = {
    name = "Glacial Prism",
    effect = "expanding_orbit_freeze",
    
    getChance = function(level)
        return 0.15  -- 15%
    end,
    
    behavior = function(projectile, level)
        local chance = PrismArtifact.CYAN.getChance(level)
        
        if math.random() < chance then
            projectile.orbitSeek = true
            projectile.orbitRadius = 30
            projectile.orbitSpeed = 2.0
            projectile.orbitAngle = 0
            projectile.orbitTarget = nil
            projectile.orbitDamage = projectile.damage * 0.1
            projectile.expandPerRevolution = 5  -- BLUE growth
            projectile.revolutionCount = 0
            projectile.maxRevolutions = 5
            projectile.freezeOnComplete = true  -- CYAN freeze
            projectile.freezeDuration = 3.0
        end
    end,
    
    update = function(projectile, enemies, dt)
        -- Same as GREEN PRISM orbit logic
        if projectile.orbitSeek and not projectile.orbitTarget then
            local nearestDist = math.huge
            local nearest = nil
            
            for _, enemy in ipairs(enemies) do
                if not enemy.dead then
                    local dx = enemy.x - projectile.x
                    local dy = enemy.y - projectile.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    
                    if dist < 100 and dist < nearestDist then
                        nearestDist = dist
                        nearest = enemy
                    end
                end
            end
            
            if nearest then
                projectile.orbitTarget = nearest
                projectile.lastAngle = projectile.orbitAngle
            end
        elseif projectile.orbitTarget then
            if not projectile.orbitTarget.dead then
                -- Orbit and track revolutions
                local oldAngle = projectile.orbitAngle
                projectile.orbitAngle = projectile.orbitAngle + projectile.orbitSpeed * dt
                
                -- Check for full revolution (crossed 0) - CYAN only
                if projectile.revolutionCount and projectile.maxRevolutions then
                    if oldAngle > math.pi * 1.5 and projectile.orbitAngle < math.pi * 0.5 then
                        projectile.revolutionCount = projectile.revolutionCount + 1
                        projectile.orbitRadius = projectile.orbitRadius + (projectile.expandPerRevolution or 0)
                    end
                end
                
                projectile.x = projectile.orbitTarget.x + math.cos(projectile.orbitAngle) * projectile.orbitRadius
                projectile.y = projectile.orbitTarget.y + math.sin(projectile.orbitAngle) * projectile.orbitRadius
                
                -- Freeze after max revolutions (CYAN only)
                if projectile.revolutionCount and projectile.maxRevolutions and projectile.revolutionCount >= projectile.maxRevolutions and projectile.freezeOnComplete then
                    projectile.orbitTarget.frozen = true
                    projectile.orbitTarget.frozenTime = projectile.freezeDuration
                    projectile.alive = false
                end
            else
                projectile.orbitTarget = nil
            end
        end
    end,
    
    visual = "cyan_expanding_orbit"
}

-- Main apply function
function PrismArtifact.apply(projectiles, level, dominantColor, targetX, targetY, player)
    if level <= 0 or not dominantColor then
        return projectiles
    end
    
    -- RED and MAGENTA create entire walls
    if dominantColor == "RED" and PrismArtifact.RED.behavior then
        return PrismArtifact.RED.behavior(projectiles, level, targetX, targetY, player)
    elseif dominantColor == "MAGENTA" and PrismArtifact.MAGENTA.behavior then
        return PrismArtifact.MAGENTA.behavior(projectiles, level, targetX, targetY, player)
    end
    
    -- Other colors apply per-projectile
    for _, proj in ipairs(projectiles) do
        if dominantColor == "GREEN" then
            PrismArtifact.GREEN.behavior(proj, level)
        elseif dominantColor == "BLUE" then
            PrismArtifact.BLUE.behavior(proj, level)
        elseif dominantColor == "CYAN" then
            PrismArtifact.CYAN.behavior(proj, level)
        end
    end
    
    -- YELLOW is passive (laser beam)
    if dominantColor == "YELLOW" and player then
        PrismArtifact.YELLOW.behavior(player, level)
    end
    
    return projectiles
end

-- Main update function
function PrismArtifact.update(projectiles, enemies, dt, dominantColor, player)
    if not dominantColor then
        return
    end
    
    -- Update orbiting projectiles (GREEN, CYAN)
    if dominantColor == "GREEN" then
        for _, proj in ipairs(projectiles) do
            if proj.orbitSeek then
                PrismArtifact.GREEN.update(proj, enemies, dt)
            end
        end
    elseif dominantColor == "CYAN" then
        for _, proj in ipairs(projectiles) do
            if proj.orbitSeek then
                PrismArtifact.CYAN.update(proj, enemies, dt)
            end
        end
    end
    
    -- Update YELLOW laser
    if dominantColor == "YELLOW" and player and player.yellowLaser then
        PrismArtifact.YELLOW.update(player.yellowLaser, dt, enemies, player)
    end
end

return PrismArtifact
