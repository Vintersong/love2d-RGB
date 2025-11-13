-- EffectLibrary.lua
-- Reusable effect behaviors that artifacts can compose
-- Data-driven design: artifacts reference effects by name

local EffectLibrary = {}

-- ============================================================================
-- DAMAGE EFFECTS
-- ============================================================================

-- Pulse damage in radius
EffectLibrary.pulseDamage = {
    update = function(state, dt, enemies, player)
        local centerX = player.x + player.width / 2
        local centerY = player.y + player.height / 2

        for _, enemy in ipairs(enemies) do
            if not enemy.dead then
                local dx = centerX - (enemy.x + enemy.width / 2)
                local dy = centerY - (enemy.y + enemy.height / 2)
                local distance = math.sqrt(dx * dx + dy * dy)

                if distance <= state.radius then
                    enemy.inPulseAura = true
                    enemy.pulseDamage = state.damage * dt
                end
            end
        end
    end
}

-- Drain damage + heal player
EffectLibrary.drainDamage = {
    update = function(state, dt, enemies, player)
        local centerX = player.x + player.width / 2
        local centerY = player.y + player.height / 2

        for _, enemy in ipairs(enemies) do
            if not enemy.dead then
                local dx = centerX - (enemy.x + enemy.width / 2)
                local dy = centerY - (enemy.y + enemy.height / 2)
                local distance = math.sqrt(dx * dx + dy * dy)

                if distance <= state.radius then
                    enemy.inDrainAura = true
                    enemy.drainAmount = state.drainRate * dt
                    -- Healing happens in HaloArtifact.processEffects
                end
            end
        end
    end
}

-- Slow enemies in radius
EffectLibrary.slowEffect = {
    update = function(state, dt, enemies, player)
        local centerX = player.x + player.width / 2
        local centerY = player.y + player.height / 2

        for _, enemy in ipairs(enemies) do
            if not enemy.dead then
                local dx = centerX - (enemy.x + enemy.width / 2)
                local dy = centerY - (enemy.y + enemy.height / 2)
                local distance = math.sqrt(dx * dx + dy * dy)

                if distance <= state.radius then
                    enemy.slowMultiplier = 1.0 - state.slowPercent
                    enemy.inSlowField = true
                else
                    if enemy.inSlowField then
                        enemy.slowMultiplier = 1.0
                        enemy.inSlowField = false
                    end
                end
            end
        end
    end
}

-- ============================================================================
-- VISUAL EFFECTS
-- ============================================================================

-- Pulsing ring aura
EffectLibrary.pulsingRing = {
    update = function(state, dt)
        state.pulsePhase = (state.pulsePhase or 0) + dt * state.pulseSpeed
        local t = (math.sin(state.pulsePhase) + 1) / 2
        state.currentRadius = state.minRadius + (state.maxRadius - state.minRadius) * t
    end,

    draw = function(state, player, color)
        local centerX = player.x + player.width / 2
        local centerY = player.y + player.height / 2

        love.graphics.setColor(color[1], color[2], color[3], 0.4)
        love.graphics.setLineWidth(4)
        love.graphics.circle("line", centerX, centerY, state.currentRadius or state.radius)

        -- Outer glow
        love.graphics.setColor(color[1], color[2], color[3], 0.2)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", centerX, centerY, (state.currentRadius or state.radius) + 8)
    end
}

-- Static ring aura
EffectLibrary.staticRing = {
    draw = function(state, player, color)
        local centerX = player.x + player.width / 2
        local centerY = player.y + player.height / 2

        love.graphics.setColor(color[1], color[2], color[3], 0.4)
        love.graphics.setLineWidth(4)
        love.graphics.circle("line", centerX, centerY, state.radius)

        -- Outer glow
        love.graphics.setColor(color[1], color[2], color[3], 0.2)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", centerX, centerY, state.radius + 8)
    end
}

-- ============================================================================
-- PROJECTILE EFFECTS
-- ============================================================================

-- Split projectile into multiple
EffectLibrary.splitProjectile = {
    apply = function(projectiles, level, params)
        local newProjectiles = {}

        for _, proj in ipairs(projectiles) do
            proj.canSplit = true
            proj.splitCount = params.splitCount or (1 + level)
            proj.splitDistance = params.splitDistance or 200
            proj.hasSplit = false
            table.insert(newProjectiles, proj)
        end

        return newProjectiles
    end
}

-- Duplicate projectiles
EffectLibrary.duplicateProjectile = {
    apply = function(projectiles, level, params)
        local newProjectiles = {}

        for _, proj in ipairs(projectiles) do
            table.insert(newProjectiles, proj)

            -- Create duplicates
            local duplicates = params.duplicateCount or level
            for i = 1, duplicates do
                local dupe = {}
                for k, v in pairs(proj) do
                    dupe[k] = v
                end
                -- Slight angle offset
                local angleOffset = (i / duplicates) * 0.2 - 0.1
                local angle = math.atan2(dupe.vy, dupe.vx) + angleOffset
                local speed = math.sqrt(dupe.vx * dupe.vx + dupe.vy * dupe.vy)
                dupe.vx = math.cos(angle) * speed
                dupe.vy = math.sin(angle) * speed
                table.insert(newProjectiles, dupe)
            end
        end

        return newProjectiles
    end
}

-- Add homing behavior
EffectLibrary.homingProjectile = {
    update = function(projectiles, enemies, dt, params)
        for _, proj in ipairs(projectiles) do
            if proj.canHome then
                -- Find nearest enemy
                local nearestDist = math.huge
                local nearest = nil

                for _, enemy in ipairs(enemies) do
                    if not enemy.dead then
                        local dx = enemy.x - proj.x
                        local dy = enemy.y - proj.y
                        local dist = math.sqrt(dx * dx + dy * dy)

                        if dist < nearestDist then
                            nearestDist = dist
                            nearest = enemy
                        end
                    end
                end

                -- Adjust trajectory toward nearest
                if nearest then
                    local angle = math.atan2(nearest.y - proj.y, nearest.x - proj.x)
                    local speed = math.sqrt(proj.vx * proj.vx + proj.vy * proj.vy)
                    local turnRate = params.turnRate or 2.0

                    proj.vx = proj.vx + math.cos(angle) * turnRate * dt
                    proj.vy = proj.vy + math.sin(angle) * turnRate * dt

                    -- Normalize to maintain speed
                    local currentSpeed = math.sqrt(proj.vx * proj.vx + proj.vy * proj.vy)
                    if currentSpeed > 0 then
                        proj.vx = (proj.vx / currentSpeed) * speed
                        proj.vy = (proj.vy / currentSpeed) * speed
                    end
                end
            end
        end
    end
}

-- ============================================================================
-- UTILITY
-- ============================================================================

-- Get effect by name
function EffectLibrary.get(effectName)
    return EffectLibrary[effectName]
end

-- Check if effect exists
function EffectLibrary.has(effectName)
    return EffectLibrary[effectName] ~= nil
end

return EffectLibrary
