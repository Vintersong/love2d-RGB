-- DIFFUSION Artifact: Spread/Softening
-- Color-specific behaviors for DIFFUSION artifact

local DiffusionArtifact = {}

-- RED DIFFUSION: Energy links between projectiles
DiffusionArtifact.RED = {
    name = "Crimson Diffusion",
    effect = "energy_web",
    
    getChance = function(level)
        return 0.20 + (level * 0.02)  -- 20-30% chance
    end,
    
    behavior = function(projectiles, level)
        local chance = DiffusionArtifact.RED.getChance(level)
        
        if math.random() < chance and #projectiles >= 2 then
            -- Create links between all projectiles
            for i = 1, #projectiles do
                projectiles[i].hasLinks = true
                projectiles[i].linkDamage = projectiles[i].damage * 0.5
                projectiles[i].maxLinkDistance = 150
            end
        end
        
        return projectiles
    end,
    
    -- Link damage handled in update loop
    visual = "red_energy_web"
}

-- GREEN DIFFUSION: Drain cloud that crystallizes
DiffusionArtifact.GREEN = {
    name = "Verdant Diffusion",
    effect = "drain_cloud",
    
    getChance = function(level)
        return 0.15 + (level * 0.02)  -- 15-25% chance
    end,
    
    behavior = function(projectiles, level)
        local chance = DiffusionArtifact.GREEN.getChance(level)
        
        if math.random() < chance and #projectiles >= 1 then
            -- Mark projectiles as creating drain cloud
            for _, proj in ipairs(projectiles) do
                proj.drainCloud = true
                proj.cloudRadius = 80
                proj.drainRate = 10 * level
                proj.drainedHP = 0
                proj.crystalThreshold = 50
            end
        end
        
        return projectiles
    end,
    
    update = function(projectile, enemies, dt)
        if projectile.drainCloud then
            -- Drain enemies in cloud radius
            for _, enemy in ipairs(enemies) do
                if not enemy.dead then
                    local dx = projectile.x - enemy.x
                    local dy = projectile.y - enemy.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    
                    if distance <= projectile.cloudRadius then
                        enemy.inDrainCloud = true
                        enemy.cloudDrain = projectile.drainRate * dt
                        projectile.drainedHP = (projectile.drainedHP or 0) + enemy.cloudDrain
                    end
                end
            end
            
            -- Check for crystal spawn threshold
            if projectile.drainedHP >= projectile.crystalThreshold then
                projectile.spawnCrystal = true
                projectile.crystalX = projectile.x
                projectile.crystalY = projectile.y
                projectile.drainedHP = 0
            end
        end
    end,
    
    visual = "green_drain_mist"
}

-- BLUE DIFFUSION: Split into smaller piercing projectiles
DiffusionArtifact.BLUE = {
    name = "Azure Diffusion",
    effect = "split_pierce",
    
    getChance = function(level)
        return 0.18 + (level * 0.02)  -- 18-28% chance
    end,
    
    behavior = function(projectile, level)
        local chance = DiffusionArtifact.BLUE.getChance(level)
        
        if math.random() < chance then
            projectile.willSplit = true
            projectile.splitCount = 3
            projectile.splitDistance = 150
            projectile.pierceChance = 0.3 + (level * 0.05)
            projectile.distanceTraveled = projectile.distanceTraveled or 0
        end
    end,
    
    -- Split creates child projectiles with pierce chance
    visual = "blue_split_pierce"
}

-- YELLOW DIFFUSION: Electric web that drains (RED links + GREEN drain + speed)
DiffusionArtifact.YELLOW = {
    name = "Electric Diffusion",
    effect = "electric_drain_web",
    
    getChance = function(level)
        return 0.15  -- 15%
    end,
    
    behavior = function(projectiles, level)
        local chance = DiffusionArtifact.YELLOW.getChance(level)
        
        if math.random() < chance and #projectiles >= 2 then
            -- Create energy links (RED) with drain effect (GREEN)
            for i = 1, #projectiles do
                projectiles[i].hasLinks = true
                projectiles[i].linkDamage = projectiles[i].damage * 0.5
                projectiles[i].maxLinkDistance = 180  -- Longer links
                projectiles[i].linkDrain = true
                projectiles[i].drainRate = 5 * level
                projectiles[i].speed = projectiles[i].speed * 1.2  -- YELLOW speed
            end
        end
        
        return projectiles
    end,
    
    visual = "yellow_electric_web"
}

-- MAGENTA DIFFUSION: Temporal split web (RED links + BLUE split + time)
DiffusionArtifact.MAGENTA = {
    name = "Temporal Diffusion",
    effect = "temporal_split_web",
    
    getChance = function(level)
        return 0.15  -- 15%
    end,
    
    behavior = function(projectiles, level)
        local chance = DiffusionArtifact.MAGENTA.getChance(level)
        
        if math.random() < chance and #projectiles >= 2 then
            -- Energy links (RED) + split behavior (BLUE)
            for i = 1, #projectiles do
                projectiles[i].hasLinks = true
                projectiles[i].linkDamage = projectiles[i].damage * 0.6
                projectiles[i].maxLinkDistance = 150
                projectiles[i].willSplit = true
                projectiles[i].splitCount = 2
                projectiles[i].splitDistance = 100
                projectiles[i].temporalEchoes = true
            end
        end
        
        return projectiles
    end,
    
    visual = "magenta_time_web"
}

-- CYAN DIFFUSION: Frost web with drain (GREEN drain + BLUE split + freeze)
DiffusionArtifact.CYAN = {
    name = "Glacial Diffusion",
    effect = "frost_drain_split",
    
    getChance = function(level)
        return 0.15  -- 15%
    end,
    
    behavior = function(projectiles, level)
        local chance = DiffusionArtifact.CYAN.getChance(level)
        
        if math.random() < chance and #projectiles >= 1 then
            -- Drain cloud (GREEN) + split (BLUE) + freeze
            for _, proj in ipairs(projectiles) do
                proj.drainCloud = true
                proj.cloudRadius = 70
                proj.drainRate = 8 * level
                proj.willSplit = true
                proj.splitCount = 2
                proj.splitDistance = 120
                proj.freezeOnHit = true
                proj.freezeDuration = 2.0
                proj.frostEffect = true
            end
        end
        
        return projectiles
    end,
    
    update = function(projectile, enemies, dt)
        if projectile.drainCloud then
            -- Drain with frost effect
            for _, enemy in ipairs(enemies) do
                if not enemy.dead then
                    local dx = projectile.x - enemy.x
                    local dy = projectile.y - enemy.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    
                    if distance <= projectile.cloudRadius then
                        enemy.inFrostCloud = true
                        enemy.frostDrain = projectile.drainRate * dt
                        enemy.slowMultiplier = 0.7  -- 30% slow
                    end
                end
            end
        end
    end,
    
    visual = "cyan_frost_cloud"
}

-- Main apply function
function DiffusionArtifact.apply(projectiles, level, dominantColor)
    if level <= 0 or not dominantColor then
        return projectiles
    end
    
    -- RED and YELLOW create links between projectiles
    if dominantColor == "RED" and DiffusionArtifact.RED.behavior then
        return DiffusionArtifact.RED.behavior(projectiles, level)
    elseif dominantColor == "YELLOW" and DiffusionArtifact.YELLOW.behavior then
        return DiffusionArtifact.YELLOW.behavior(projectiles, level)
    elseif dominantColor == "MAGENTA" and DiffusionArtifact.MAGENTA.behavior then
        return DiffusionArtifact.MAGENTA.behavior(projectiles, level)
    end
    
    -- GREEN and CYAN apply drain clouds
    if dominantColor == "GREEN" and DiffusionArtifact.GREEN.behavior then
        return DiffusionArtifact.GREEN.behavior(projectiles, level)
    elseif dominantColor == "CYAN" and DiffusionArtifact.CYAN.behavior then
        return DiffusionArtifact.CYAN.behavior(projectiles, level)
    end
    
    -- BLUE applies per-projectile
    if dominantColor == "BLUE" then
        for _, proj in ipairs(projectiles) do
            DiffusionArtifact.BLUE.behavior(proj, level)
        end
    end
    
    return projectiles
end

-- Main update function
function DiffusionArtifact.update(projectiles, enemies, dt, dominantColor)
    if not dominantColor then
        return
    end
    
    -- Update drain clouds (GREEN, CYAN)
    if dominantColor == "GREEN" or dominantColor == "CYAN" then
        for _, proj in ipairs(projectiles) do
            if proj.drainCloud then
                if dominantColor == "GREEN" then
                    DiffusionArtifact.GREEN.update(proj, enemies, dt)
                elseif dominantColor == "CYAN" then
                    DiffusionArtifact.CYAN.update(proj, enemies, dt)
                end
            end
        end
    end
end

return DiffusionArtifact
