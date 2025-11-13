-- MIRROR Artifact: Reflection/Duplication
-- Color-specific behaviors for MIRROR artifact

local MirrorArtifact = {}

-- RED MIRROR: Fire projectiles from both sides
MirrorArtifact.RED = {
    name = "Crimson Mirror",
    effect = "dual_walls",
    
    getChance = function(level)
        return 0.20 + (level * 0.02)  -- 20-30% chance
    end,
    
    behavior = function(projectiles, level, player)
        local chance = MirrorArtifact.RED.getChance(level)
        
        if math.random() < chance then
            -- Create duplicate walls on left and right sides
            local duplicates = {}
            
            for _, proj in ipairs(projectiles) do
                -- Calculate perpendicular angles (left and right)
                local baseAngle = math.atan(proj.vy, proj.vx)
                local leftAngle = baseAngle + math.pi/2
                local rightAngle = baseAngle - math.pi/2
                
                -- Left wall projectile
                local leftProj = {
                    x = proj.x,
                    y = proj.y,
                    vx = math.cos(leftAngle) * proj.speed,
                    vy = math.sin(leftAngle) * proj.speed,
                    damage = proj.damage * 0.8,  -- Slightly reduced
                    speed = proj.speed,
                    color = proj.color,
                    size = proj.size or 4,
                    shape = proj.shape,
                    type = proj.type,
                    mirrored = true
                }
                
                -- Right wall projectile
                local rightProj = {
                    x = proj.x,
                    y = proj.y,
                    vx = math.cos(rightAngle) * proj.speed,
                    vy = math.sin(rightAngle) * proj.speed,
                    damage = proj.damage * 0.8,
                    speed = proj.speed,
                    color = proj.color,
                    size = proj.size or 4,
                    shape = proj.shape,
                    type = proj.type,
                    mirrored = true
                }
                
                table.insert(duplicates, leftProj)
                table.insert(duplicates, rightProj)
            end
            
            -- Add duplicates to projectile array
            for _, dup in ipairs(duplicates) do
                table.insert(projectiles, dup)
            end
        end
        
        return projectiles
    end,
    
    visual = "red_dual_walls"
}

-- GREEN MIRROR: Bounce back to same enemy repeatedly (echo)
MirrorArtifact.GREEN = {
    name = "Verdant Mirror",
    effect = "echo_bounce",
    
    getChance = function(level)
        return 0.25 + (level * 0.02)  -- 25-35% chance
    end,
    
    behavior = function(projectile, level)
        local chance = MirrorArtifact.GREEN.getChance(level)
        
        if math.random() < chance then
            projectile.echoEnabled = true
            projectile.echoCount = 2 + math.floor(level / 2)  -- 2-4 echoes
            projectile.echoTimer = 0
            projectile.echoDelay = 0.3  -- Time between echoes
        end
    end,
    
    update = function(projectile, enemies, dt)
        if projectile.echoEnabled and projectile.echoTarget then
            projectile.echoTimer = projectile.echoTimer + dt
            
            -- Return to target enemy after delay
            if projectile.echoTimer >= projectile.echoDelay and projectile.echoCount > 0 then
                if not projectile.echoTarget.dead then
                    local dx = projectile.echoTarget.x - projectile.x
                    local dy = projectile.echoTarget.y - projectile.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    
                    if distance > 0 then
                        -- Redirect toward echo target
                        projectile.vx = (dx / distance) * projectile.speed
                        projectile.vy = (dy / distance) * projectile.speed
                    end
                end
            end
        end
    end,
    
    visual = "green_echo_trail"
}

-- BLUE MIRROR: Split into multiple projectiles
MirrorArtifact.BLUE = {
    name = "Azure Mirror",
    effect = "split_projectiles",
    
    getChance = function(level)
        return 0.15 + (level * 0.02)  -- 15-25% chance
    end,
    
    behavior = function(projectile, level)
        local chance = MirrorArtifact.BLUE.getChance(level)
        
        if math.random() < chance then
            projectile.willSplit = true
            projectile.splitCount = 2 + math.floor(level / 2)  -- 2-4 splits
            projectile.splitDistance = 100  -- After 100px
            projectile.distanceTraveled = projectile.distanceTraveled or 0
        end
    end,
    
    -- Split happens in Player update loop when distanceTraveled >= splitDistance
    -- This just marks projectiles for splitting
    
    visual = "blue_split_shards"
}

-- YELLOW MIRROR: Fast dual walls that bounce (RED + GREEN)
MirrorArtifact.YELLOW = {
    name = "Electric Mirror",
    effect = "fast_dual_echo",
    
    getChance = function(level)
        return 0.18  -- Fixed 18%
    end,
    
    behavior = function(projectiles, level, player)
        local chance = MirrorArtifact.YELLOW.getChance(level)
        
        if math.random() < chance then
            -- Create dual walls (RED trait)
            local duplicates = {}
            
            for _, proj in ipairs(projectiles) do
                local baseAngle = math.atan(proj.vy, proj.vx)
                local leftAngle = baseAngle + math.pi/2
                local rightAngle = baseAngle - math.pi/2
                
                -- Speed boost (YELLOW trait)
                local boostedSpeed = proj.speed * 1.3
                
                -- Left projectile with echo (GREEN trait)
                local leftProj = {
                    x = proj.x,
                    y = proj.y,
                    vx = math.cos(leftAngle) * boostedSpeed,
                    vy = math.sin(leftAngle) * boostedSpeed,
                    damage = proj.damage * 0.8,
                    speed = boostedSpeed,
                    color = {1, 1, 0},  -- Yellow
                    size = proj.size or 4,
                    shape = proj.shape,
                    type = proj.type,
                    mirrored = true,
                    echoEnabled = true,
                    echoCount = 2,
                    echoTimer = 0,
                    echoDelay = 0.3,
                    electricEffect = true
                }
                
                -- Right projectile
                local rightProj = {
                    x = proj.x,
                    y = proj.y,
                    vx = math.cos(rightAngle) * boostedSpeed,
                    vy = math.sin(rightAngle) * boostedSpeed,
                    damage = proj.damage * 0.8,
                    speed = boostedSpeed,
                    color = {1, 1, 0},
                    size = proj.size or 4,
                    shape = proj.shape,
                    type = proj.type,
                    mirrored = true,
                    echoEnabled = true,
                    echoCount = 2,
                    echoTimer = 0,
                    echoDelay = 0.3,
                    electricEffect = true
                }
                
                table.insert(duplicates, leftProj)
                table.insert(duplicates, rightProj)
            end
            
            for _, dup in ipairs(duplicates) do
                table.insert(projectiles, dup)
            end
        end
        
        return projectiles
    end,
    
    visual = "yellow_electric_walls"
}

-- MAGENTA MIRROR: Temporal clone fires alongside (RED + BLUE + time)
MirrorArtifact.MAGENTA = {
    name = "Temporal Mirror",
    effect = "time_clone",
    
    getChance = function(level)
        return 0.15  -- 15%
    end,
    
    behavior = function(projectiles, level, player)
        local chance = MirrorArtifact.MAGENTA.getChance(level)
        
        if math.random() < chance then
            -- Add temporal echo effect to projectiles (split + dual wall traits)
            for _, proj in ipairs(projectiles) do
                proj.temporalEcho = true
                proj.echoDelay = 0.2
                proj.willSplit = true
                proj.splitCount = 2
                proj.splitDistance = 80
            end
        end
        
        return projectiles
    end,
    
    visual = "magenta_glitch_clone"
}

-- CYAN MIRROR: Ice walls that bounce, split, and freeze (GREEN + BLUE)
MirrorArtifact.CYAN = {
    name = "Glacial Mirror",
    effect = "frost_walls",
    
    getChance = function(level)
        return 0.20  -- 20%
    end,
    
    behavior = function(projectiles, level, player)
        local chance = MirrorArtifact.CYAN.getChance(level)
        
        if math.random() < chance then
            -- Create ice wall projectiles
            local duplicates = {}
            
            for _, proj in ipairs(projectiles) do
                local baseAngle = math.atan(proj.vy, proj.vx)
                
                -- Create 5 projectiles in a wall formation
                for i = -2, 2 do
                    local angleOffset = (i * math.pi / 12)  -- 15 degrees apart
                    local wallAngle = baseAngle + angleOffset
                    
                    local wallProj = {
                        x = proj.x,
                        y = proj.y,
                        vx = math.cos(wallAngle) * proj.speed,
                        vy = math.sin(wallAngle) * proj.speed,
                        damage = proj.damage * 0.6,
                        speed = proj.speed,
                        color = {0, 1, 1},  -- Cyan
                        size = proj.size or 4,
                        shape = proj.shape,
                        type = proj.type,
                        echoEnabled = true,  -- GREEN bounce
                        echoCount = 2,
                        echoTimer = 0,
                        echoDelay = 0.3,
                        willSplit = true,  -- BLUE split
                        splitCount = 2,
                        splitDistance = 80,
                        freezeOnHit = true,  -- CYAN freeze
                        freezeDuration = 2.0,
                        frostEffect = true
                    }
                    
                    table.insert(duplicates, wallProj)
                end
            end
            
            -- Replace original projectiles with ice wall
            for _, dup in ipairs(duplicates) do
                table.insert(projectiles, dup)
            end
        end
        
        return projectiles
    end,
    
    visual = "cyan_ice_wall"
}

-- Main apply function: Called when projectiles are created
function MirrorArtifact.apply(projectiles, level, dominantColor, player)
    if level <= 0 or not dominantColor then
        return projectiles
    end
    
    -- Route to appropriate color behavior
    if dominantColor == "RED" and MirrorArtifact.RED.behavior then
        return MirrorArtifact.RED.behavior(projectiles, level, player)
    elseif dominantColor == "GREEN" then
        -- GREEN applies per-projectile
        for _, proj in ipairs(projectiles) do
            MirrorArtifact.GREEN.behavior(proj, level)
        end
    elseif dominantColor == "BLUE" then
        -- BLUE applies per-projectile
        for _, proj in ipairs(projectiles) do
            MirrorArtifact.BLUE.behavior(proj, level)
        end
    elseif dominantColor == "YELLOW" and MirrorArtifact.YELLOW.behavior then
        return MirrorArtifact.YELLOW.behavior(projectiles, level, player)
    elseif dominantColor == "MAGENTA" and MirrorArtifact.MAGENTA.behavior then
        return MirrorArtifact.MAGENTA.behavior(projectiles, level, player)
    elseif dominantColor == "CYAN" and MirrorArtifact.CYAN.behavior then
        return MirrorArtifact.CYAN.behavior(projectiles, level, player)
    end
    
    return projectiles
end

-- Main update function: Called per-frame for active effects
function MirrorArtifact.update(projectiles, enemies, dt, dominantColor)
    if not dominantColor then
        return
    end
    
    -- GREEN MIRROR: Echo bounce updates
    if dominantColor == "GREEN" or dominantColor == "YELLOW" or dominantColor == "CYAN" then
        for _, proj in ipairs(projectiles) do
            if proj.echoEnabled and MirrorArtifact.GREEN.update then
                MirrorArtifact.GREEN.update(proj, enemies, dt)
            end
        end
    end
end

return MirrorArtifact
