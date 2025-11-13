-- HALO Artifact: Shield/Aura
-- Color-specific behaviors for HALO artifact

local HaloArtifact = {}

-- RED HALO: Pulsing fire ring aura
HaloArtifact.RED = {
    name = "Crimson Halo",
    effect = "fire_pulse_aura",
    
    behavior = function(player, level)
        if not player.redHalo then
            player.redHalo = {
                active = true,
                minRadius = 30,
                maxRadius = 60 + (level * 10),
                pulseSpeed = 1.5,  -- Seconds per cycle
                pulsePhase = 0,
                damage = 10 * level,
                expanding = false
            }
        else
            -- Update existing halo
            player.redHalo.maxRadius = 60 + (level * 10)
            player.redHalo.damage = 10 * level
        end
    end,
    
    update = function(halo, dt, enemies, player)
        if not halo or not halo.active then
            return
        end
        
        -- Breathing animation
        halo.pulsePhase = halo.pulsePhase + dt
        local t = (math.sin(halo.pulsePhase * halo.pulseSpeed) + 1) / 2  -- 0 to 1
        local currentRadius = halo.minRadius + (halo.maxRadius - halo.minRadius) * t
        halo.currentRadius = currentRadius
        
        -- Damage enemies when expanding (t > 0.5)
        if t > 0.5 then
            halo.expanding = true
            for _, enemy in ipairs(enemies) do
                if not enemy.dead then
                    local dx = player.x - enemy.x
                    local dy = player.y - enemy.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    
                    if distance <= currentRadius then
                        -- Damage handled by collision system
                        enemy.inFireAura = true
                    end
                end
            end
        else
            halo.expanding = false
        end
    end,
    
    visual = "red_pulsing_ring"
}

-- GREEN HALO: Life drain aura
HaloArtifact.GREEN = {
    name = "Verdant Halo",
    effect = "life_drain_aura",
    
    behavior = function(player, level)
        if not player.greenHalo then
            player.greenHalo = {
                active = true,
                radius = 80 + (level * 10),
                drainRate = 5 * level,
                healPercent = 0.5
            }
        else
            player.greenHalo.radius = 80 + (level * 10)
            player.greenHalo.drainRate = 5 * level
        end
    end,
    
    update = function(halo, dt, enemies, player)
        if not halo or not halo.active then
            return
        end
        
        for _, enemy in ipairs(enemies) do
            if not enemy.dead then
                local dx = player.x - enemy.x
                local dy = player.y - enemy.y
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance <= halo.radius then
                    -- Drain damage (handled externally)
                    enemy.inDrainAura = true
                    enemy.drainAmount = halo.drainRate * dt
                end
            end
        end
    end,
    
    visual = "green_drain_tendrils"
}

-- BLUE HALO: Slow aura
HaloArtifact.BLUE = {
    name = "Azure Halo",
    effect = "slow_aura",
    
    behavior = function(player, level)
        if not player.blueHalo then
            player.blueHalo = {
                active = true,
                radius = 90 + (level * 10),
                slowPercent = 0.3 + (level * 0.05)
            }
        else
            player.blueHalo.radius = 90 + (level * 10)
            player.blueHalo.slowPercent = 0.3 + (level * 0.05)
        end
    end,
    
    update = function(halo, dt, enemies, player)
        if not halo or not halo.active then
            return
        end
        
        for _, enemy in ipairs(enemies) do
            if not enemy.dead then
                local dx = player.x - enemy.x
                local dy = player.y - enemy.y
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance <= halo.radius then
                    enemy.slowMultiplier = 1.0 - halo.slowPercent
                    enemy.inSlowField = true
                else
                    if enemy.inSlowField then
                        enemy.slowMultiplier = 1.0
                        enemy.inSlowField = false
                    end
                end
            end
        end
    end,
    
    visual = "blue_frost_mist"
}

-- YELLOW HALO: Rapid electric pulse (RED pulse + GREEN heal + speed)
HaloArtifact.YELLOW = {
    name = "Electric Halo",
    effect = "electric_pulse_heal",
    
    behavior = function(player, level)
        if not player.yellowHalo then
            player.yellowHalo = {
                active = true,
                radius = 70 + (level * 8),
                pulseRate = 0.3,  -- 3+ pulses per second
                pulseTimer = 0,
                damage = 15 * level,
                healPercent = 0.3
            }
        else
            player.yellowHalo.radius = 70 + (level * 8)
            player.yellowHalo.damage = 15 * level
        end
    end,
    
    update = function(halo, dt, enemies, player)
        if not halo or not halo.active then
            return
        end
        
        halo.pulseTimer = halo.pulseTimer - dt
        if halo.pulseTimer <= 0 then
            halo.pulseTimer = halo.pulseRate
            halo.justPulsed = true
            
            -- Pulse damages all enemies in range
            local totalDamage = 0
            for _, enemy in ipairs(enemies) do
                if not enemy.dead then
                    local dx = player.x - enemy.x
                    local dy = player.y - enemy.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    
                    if distance <= halo.radius then
                        enemy.electricPulse = true
                        enemy.pulseDamage = halo.damage
                        totalDamage = totalDamage + halo.damage
                    end
                end
            end
            
            -- Heal based on damage dealt
            halo.healAmount = totalDamage * halo.healPercent
        else
            halo.justPulsed = false
        end
    end,
    
    visual = "yellow_electric_ring"
}

-- MAGENTA HALO: Time bubble (RED damage + BLUE slow + time)
HaloArtifact.MAGENTA = {
    name = "Temporal Halo",
    effect = "time_bubble",
    
    behavior = function(player, level)
        if not player.magentaHalo then
            player.magentaHalo = {
                active = true,
                radius = 85 + (level * 10),
                damage = 8 * level,
                slowPercent = 0.6
            }
        else
            player.magentaHalo.radius = 85 + (level * 10)
            player.magentaHalo.damage = 8 * level
        end
    end,
    
    update = function(halo, dt, enemies, player)
        if not halo or not halo.active then
            return
        end
        
        for _, enemy in ipairs(enemies) do
            if not enemy.dead then
                local dx = player.x - enemy.x
                local dy = player.y - enemy.y
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance <= halo.radius then
                    -- Damage over time (RED)
                    enemy.inTimeBubble = true
                    enemy.timeBubbleDamage = halo.damage * dt
                    
                    -- Slow (BLUE)
                    enemy.slowMultiplier = 1.0 - halo.slowPercent
                    enemy.temporalDistortion = true
                else
                    enemy.inTimeBubble = false
                    enemy.slowMultiplier = 1.0
                    enemy.temporalDistortion = false
                end
            end
        end
    end,
    
    visual = "magenta_time_bubble"
}

-- CYAN HALO: Frost aura with drain (GREEN drain + BLUE slow + frost)
HaloArtifact.CYAN = {
    name = "Glacial Halo",
    effect = "frost_drain_aura",
    
    behavior = function(player, level)
        if not player.cyanHalo then
            player.cyanHalo = {
                active = true,
                radius = 80 + (level * 10),
                drainRate = 4 * level,
                slowPercent = 0.4,
                healPercent = 0.4
            }
        else
            player.cyanHalo.radius = 80 + (level * 10)
            player.cyanHalo.drainRate = 4 * level
        end
    end,
    
    update = function(halo, dt, enemies, player)
        if not halo or not halo.active then
            return
        end
        
        for _, enemy in ipairs(enemies) do
            if not enemy.dead then
                local dx = player.x - enemy.x
                local dy = player.y - enemy.y
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance <= halo.radius then
                    -- Drain HP (GREEN)
                    enemy.inFrostDrain = true
                    enemy.frostDrainAmount = halo.drainRate * dt
                    
                    -- Slow (BLUE + CYAN)
                    enemy.slowMultiplier = 1.0 - halo.slowPercent
                    enemy.frosted = true
                else
                    enemy.inFrostDrain = false
                    enemy.slowMultiplier = 1.0
                    enemy.frosted = false
                end
            end
        end
    end,
    
    visual = "cyan_frost_drain"
}

-- Main behavior function: Initialize halo
function HaloArtifact.apply(player, level, dominantColor)
    if level <= 0 or not dominantColor then
        return
    end
    
    -- Initialize appropriate halo based on color
    if dominantColor == "RED" then
        HaloArtifact.RED.behavior(player, level)
    elseif dominantColor == "GREEN" then
        HaloArtifact.GREEN.behavior(player, level)
    elseif dominantColor == "BLUE" then
        HaloArtifact.BLUE.behavior(player, level)
    elseif dominantColor == "YELLOW" then
        HaloArtifact.YELLOW.behavior(player, level)
    elseif dominantColor == "MAGENTA" then
        HaloArtifact.MAGENTA.behavior(player, level)
    elseif dominantColor == "CYAN" then
        HaloArtifact.CYAN.behavior(player, level)
    end
end

-- Main update function: Update active halos
function HaloArtifact.update(dt, enemies, player, dominantColor)
    if not dominantColor or not player then
        return
    end

    -- Update active halo
    if dominantColor == "RED" and player.redHalo then
        HaloArtifact.RED.update(player.redHalo, dt, enemies, player)
    elseif dominantColor == "GREEN" and player.greenHalo then
        HaloArtifact.GREEN.update(player.greenHalo, dt, enemies, player)
    elseif dominantColor == "BLUE" and player.blueHalo then
        HaloArtifact.BLUE.update(player.blueHalo, dt, enemies, player)
    elseif dominantColor == "YELLOW" and player.yellowHalo then
        HaloArtifact.YELLOW.update(player.yellowHalo, dt, enemies, player)
    elseif dominantColor == "MAGENTA" and player.magentaHalo then
        HaloArtifact.MAGENTA.update(player.magentaHalo, dt, enemies, player)
    elseif dominantColor == "CYAN" and player.cyanHalo then
        HaloArtifact.CYAN.update(player.cyanHalo, dt, enemies, player)
    end
end

-- Main draw function: Render halo aura rings
function HaloArtifact.draw(player, dominantColor)
    if not dominantColor or not player then
        return
    end

    local centerX = player.x + player.width / 2
    local centerY = player.y + player.height / 2
    local radius = player.width / 2

    -- Get color-specific aura radius and color
    local auraRadius = radius + 20
    local auraColor = {1, 1, 0.3}  -- Default gold

    if dominantColor == "RED" and player.redHalo then
        auraRadius = player.redHalo.currentRadius or (radius + 20)
        auraColor = {1, 0.2, 0.2}  -- Red fire
    elseif dominantColor == "GREEN" and player.greenHalo then
        auraRadius = player.greenHalo.radius or (radius + 30)
        auraColor = {0.2, 1, 0.2}  -- Green drain
    elseif dominantColor == "BLUE" and player.blueHalo then
        auraRadius = player.blueHalo.radius or (radius + 30)
        auraColor = {0.2, 0.4, 1}  -- Blue slow
    elseif dominantColor == "YELLOW" and player.yellowHalo then
        auraRadius = player.yellowHalo.radius or (radius + 25)
        auraColor = {1, 1, 0.2}  -- Yellow electric
    elseif dominantColor == "MAGENTA" and player.magentaHalo then
        auraRadius = player.magentaHalo.radius or (radius + 30)
        auraColor = {1, 0.2, 1}  -- Magenta time
    elseif dominantColor == "CYAN" and player.cyanHalo then
        auraRadius = player.cyanHalo.radius or (radius + 30)
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

-- Process halo damage/healing effects on enemies (called from game state)
function HaloArtifact.processEffects(enemy, player, onKillCallback)
    local HealthSystem = require("src.systems.HealthSystem")

    -- RED HALO: Fire pulse damage
    if enemy.inFireAura and player.redHalo then
        local died = HealthSystem.takeDamage(enemy, player.redHalo.damage * 0.016) -- Approximate dt
        if died and onKillCallback then
            onKillCallback(enemy)
        end
        enemy.inFireAura = false
    end

    -- GREEN HALO: Life drain (heal player)
    if enemy.inDrainAura and enemy.drainAmount and player.greenHalo then
        local died = HealthSystem.takeDamage(enemy, enemy.drainAmount)
        HealthSystem.heal(player, enemy.drainAmount * (player.greenHalo.healPercent or 0.5))
        if died and onKillCallback then
            onKillCallback(enemy)
        end
        enemy.inDrainAura = false
        enemy.drainAmount = nil
    end

    -- YELLOW HALO: Electric pulse damage + heal
    if enemy.electricPulse and enemy.pulseDamage then
        local died = HealthSystem.takeDamage(enemy, enemy.pulseDamage)
        if died and onKillCallback then
            onKillCallback(enemy)
        end
        enemy.electricPulse = false
        enemy.pulseDamage = nil
    end

    -- Heal player from yellow halo pulse
    if player.yellowHalo and player.yellowHalo.healAmount then
        HealthSystem.heal(player, player.yellowHalo.healAmount)
        player.yellowHalo.healAmount = nil
    end

    -- MAGENTA HALO: Time bubble damage
    if enemy.inTimeBubble and enemy.timeBubbleDamage then
        local died = HealthSystem.takeDamage(enemy, enemy.timeBubbleDamage)
        if died and onKillCallback then
            onKillCallback(enemy)
        end
    end

    -- CYAN HALO: Frost drain (heal player)
    if enemy.inFrostDrain and enemy.frostDrainAmount and player.cyanHalo then
        local died = HealthSystem.takeDamage(enemy, enemy.frostDrainAmount)
        HealthSystem.heal(player, enemy.frostDrainAmount * (player.cyanHalo.healPercent or 0.4))
        if died and onKillCallback then
            onKillCallback(enemy)
        end
        enemy.inFrostDrain = false
        enemy.frostDrainAmount = nil
    end
end

return HaloArtifact
