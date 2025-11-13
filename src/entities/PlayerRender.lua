-- PlayerRender.lua
-- Handles all player and projectile rendering
-- Extracted from Player.lua for better separation of concerns

local PlayerRender = {}

-- Draw the player sprite
function PlayerRender.drawPlayer(player)
    local centerX = player.x + player.width / 2
    local centerY = player.y + player.height / 2
    local radius = player.width / 2

    -- Calculate direction to nearest enemy
    local targetX, targetY
    if player.nearestEnemy and not player.nearestEnemy.dead then
        targetX = player.nearestEnemy.x + player.nearestEnemy.width / 2
        targetY = player.nearestEnemy.y + player.nearestEnemy.height / 2
    else
        -- Default direction (up)
        targetX = centerX
        targetY = centerY - 100
    end

    local dx = targetX - centerX
    local dy = targetY - centerY
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Draw player as CIRCLE
    -- Flash white when taking damage, flicker when invulnerable
    if player.invulnerable and math.floor(player.invulnerableTime * 10) % 2 == 0 then
        love.graphics.setColor(0.3, 0.6, 1, 0.5) -- Semi-transparent when invulnerable
    elseif player.damageFlashTime > 0 then
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
    if player.nearestEnemy and not player.nearestEnemy.dead then
        love.graphics.setColor(0.2, 1, 0.2, 0.4)  -- Green, semi-transparent
        love.graphics.setLineWidth(2)
        love.graphics.line(centerX, centerY, targetX, targetY)

        -- Draw target indicator on nearest enemy
        love.graphics.setColor(0.2, 1, 0.2, 0.8)  -- Green
        love.graphics.circle("line", targetX, targetY, 15)
        love.graphics.circle("line", targetX, targetY, 12)
    end
end

-- Draw all projectiles with trails and special shapes
function PlayerRender.drawProjectiles(player)
    local ColorSystem = require("src.systems.ColorSystem")
    local projColor = ColorSystem.getProjectileColor()
    local ArtifactManager = require("src.systems.ArtifactManager")

    for _, proj in ipairs(player.projectiles) do
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
        PlayerRender.drawProjectileShape(proj, projColor, abilityCount)
    end
end

-- Draw a single projectile with its shape
function PlayerRender.drawProjectileShape(proj, projColor, abilityCount)
    love.graphics.push()
    love.graphics.translate(proj.x, proj.y)

    local shape = proj.shape or "circle"

    if shape == "atom" or shape == "atom_crescent" or shape == "atom_triangle" then
        PlayerRender.drawAtomShape(proj, projColor)
    elseif shape == "crescent" or shape == "triangle_crescent" then
        PlayerRender.drawCrescentShape(proj, projColor)
    elseif shape == "triangle" then
        PlayerRender.drawTriangleShape(proj, projColor)
    elseif shape == "prism" then
        PlayerRender.drawPrismShape(proj, projColor)
    else
        PlayerRender.drawCircleShape(proj, projColor, abilityCount)
    end

    love.graphics.pop()
end

-- Atom shape (hydrogen atom with orbiting electron)
function PlayerRender.drawAtomShape(proj, projColor)
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
end

-- Crescent moon shape
function PlayerRender.drawCrescentShape(proj, projColor)
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
end

-- Triangle shape
function PlayerRender.drawTriangleShape(proj, projColor)
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
end

-- Prism shape (hexagon with refraction lines)
function PlayerRender.drawPrismShape(proj, projColor)
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
end

-- Circle shape with ability indicators
function PlayerRender.drawCircleShape(proj, projColor, abilityCount)
    local hasMultipleAbilities = abilityCount > 1

    -- PIERCE (BLUE): Elongated diamond/arrow
    if proj.canPierce and not hasMultipleAbilities then
        PlayerRender.drawPierceShape(proj, projColor)
    -- BOUNCE (GREEN): Circle with rotating orbit ring
    elseif proj.canBounceToNearest and not hasMultipleAbilities then
        PlayerRender.drawBounceShape(proj, projColor)
    -- SPREAD (RED): Standard circle slightly larger
    elseif proj.type == "spread" and not hasMultipleAbilities then
        PlayerRender.drawSpreadShape(proj, projColor)
    -- ROOT (YELLOW): Circle with pulsing corona
    elseif proj.canRoot and not hasMultipleAbilities then
        PlayerRender.drawRootShape(proj, projColor)
    -- EXPLODE (MAGENTA): Circle with magenta glow
    elseif proj.canExplode and not hasMultipleAbilities then
        PlayerRender.drawExplodeShape(proj, projColor)
    -- DOT (CYAN): Circle with cyan spiral
    elseif proj.canDot and not hasMultipleAbilities then
        PlayerRender.drawDotShape(proj, projColor)
    -- MULTIPLE ABILITIES: Combined indicators
    else
        PlayerRender.drawMultiAbilityShape(proj, projColor)
    end
end

-- Pierce projectile shape
function PlayerRender.drawPierceShape(proj, projColor)
    local angle = math.atan2(proj.vy, proj.vx)
    love.graphics.push()
    love.graphics.rotate(angle)

    local vertices = {
        proj.size * 1.8, 0,
        proj.size * 0.3, proj.size * 0.6,
        -proj.size * 0.5, 0,
        proj.size * 0.3, -proj.size * 0.6
    }

    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.polygon("line", vertices)

    love.graphics.setColor(projColor)
    love.graphics.polygon("fill", vertices)

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.line(proj.size * 1.5, 0, -proj.size * 0.3, 0)

    love.graphics.pop()
end

-- Bounce projectile shape
function PlayerRender.drawBounceShape(proj, projColor)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, proj.size)

    love.graphics.setColor(projColor)
    love.graphics.circle("fill", 0, 0, proj.size)

    local orbitAngle = love.timer.getTime() * 4
    love.graphics.setColor(0.3, 1, 0.3, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, proj.size * 1.4)

    local orbitX = math.cos(orbitAngle) * proj.size * 1.4
    local orbitY = math.sin(orbitAngle) * proj.size * 1.4
    love.graphics.circle("fill", orbitX, orbitY, proj.size * 0.2)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 0, 0, proj.size * 0.5)
end

-- Spread projectile shape
function PlayerRender.drawSpreadShape(proj, projColor)
    local spreadScale = 1.15
    local spreadSize = proj.size * spreadScale

    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, spreadSize)

    love.graphics.setColor(projColor)
    love.graphics.circle("fill", 0, 0, spreadSize)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 0, 0, spreadSize * 0.5)
end

-- Root projectile shape
function PlayerRender.drawRootShape(proj, projColor)
    local pulse = 0.8 + math.sin(love.timer.getTime() * 6) * 0.2
    love.graphics.setColor(1, 1, 0, 0.4 * pulse)
    love.graphics.circle("fill", 0, 0, proj.size * 1.8 * pulse)

    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, proj.size)

    love.graphics.setColor(projColor)
    love.graphics.circle("fill", 0, 0, proj.size)

    love.graphics.setColor(1, 1, 0, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, proj.size * 1.3)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 0, 0, proj.size * 0.5)
end

-- Explode projectile shape
function PlayerRender.drawExplodeShape(proj, projColor)
    love.graphics.setColor(1, 0.2, 1, 0.3)
    love.graphics.circle("fill", 0, 0, proj.size * 1.8)

    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, proj.size)

    love.graphics.setColor(projColor)
    love.graphics.circle("fill", 0, 0, proj.size)

    love.graphics.setColor(1, 0.2, 1, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, proj.size * 1.4)
    love.graphics.circle("line", 0, 0, proj.size * 1.6)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 0, 0, proj.size * 0.5)
end

-- DoT projectile shape
function PlayerRender.drawDotShape(proj, projColor)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, proj.size)

    love.graphics.setColor(projColor)
    love.graphics.circle("fill", 0, 0, proj.size)

    love.graphics.setColor(0.4, 1, 1, 0.8)
    for i = 0, 3 do
        local angle = (i / 4) * math.pi * 2 + love.timer.getTime() * 3
        local spiralRadius = proj.size * 1.4
        local x = math.cos(angle) * spiralRadius
        local y = math.sin(angle) * spiralRadius
        love.graphics.circle("fill", x, y, proj.size * 0.25)
    end

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 0, 0, proj.size * 0.5)
end

-- Multi-ability projectile shape
function PlayerRender.drawMultiAbilityShape(proj, projColor)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, proj.size)

    love.graphics.setColor(projColor)
    love.graphics.circle("fill", 0, 0, proj.size)

    -- Draw indicators for each ability (stacked)
    if proj.canPierce then
        local angle = math.atan2(proj.vy, proj.vx)
        love.graphics.push()
        love.graphics.rotate(angle)

        love.graphics.setColor(0.3, 0.8, 1, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.line(-proj.size * 0.7, 0, proj.size * 0.7, 0)
        love.graphics.line(proj.size * 0.5, -proj.size * 0.3, proj.size * 0.7, 0)
        love.graphics.line(proj.size * 0.5, proj.size * 0.3, proj.size * 0.7, 0)

        love.graphics.pop()
    end

    if proj.canBounceToNearest then
        love.graphics.setColor(0.3, 1, 0.3, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, proj.size * 1.4)
    end

    if proj.canRoot then
        local pulse = 0.8 + math.sin(love.timer.getTime() * 6) * 0.2
        love.graphics.setColor(1, 1, 0, 0.6 * pulse)
        love.graphics.circle("line", 0, 0, proj.size * 1.6)
    end

    if proj.canExplode then
        love.graphics.setColor(1, 0.2, 1, 0.5)
        love.graphics.circle("line", 0, 0, proj.size * 1.8)
    end

    if proj.canDot then
        love.graphics.setColor(0.4, 1, 1, 0.8)
        for i = 0, 2 do
            local angle = (i / 3) * math.pi * 2 + love.timer.getTime() * 3
            local x = math.cos(angle) * proj.size * 1.3
            local y = math.sin(angle) * proj.size * 1.3
            love.graphics.circle("fill", x, y, proj.size * 0.2)
        end
    end

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 0, 0, proj.size * 0.5)
end

return PlayerRender
