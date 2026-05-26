-- PlayerRender.lua
-- Handles all player and projectile rendering
-- Extracted from Player.lua for better separation of concerns

local PlayerRender = {}
local ShapeLibrary = require("src.render.ShapeLibrary")
local MathUtils = require("src.utils.MathUtils")

local function getProjectileList(player)
    local combatState = player.combatState or {projectiles = player.projectiles or {}}
    return combatState.projectiles or player.projectiles or {}
end

local function getTargetInfo(player)
    local centerX = player.x + player.width / 2
    local centerY = player.y + player.height / 2
    local combatState = player.combatState or {projectiles = player.projectiles or {}}
    local nearestEnemy = combatState.nearestEnemy or player.nearestEnemy
    local hasTarget = nearestEnemy and (not nearestEnemy.dead or nearestEnemy.alive)
    local targetX, targetY

    if hasTarget then
        -- BossSystem bosses use center x,y; regular enemies use x,y + width/height
        if nearestEnemy.width and nearestEnemy.height then
            targetX = nearestEnemy.x + nearestEnemy.width / 2
            targetY = nearestEnemy.y + nearestEnemy.height / 2
        else
            targetX = nearestEnemy.x
            targetY = nearestEnemy.y
        end
    else
        -- Default direction (up)
        targetX = centerX
        targetY = centerY - 100
    end

    local dx = targetX - centerX
    local dy = targetY - centerY
    local distance = math.sqrt(dx * dx + dy * dy)
    local isBoss = hasTarget and (nearestEnemy.enemyType == "boss" or nearestEnemy.phase ~= nil)

    return {
        centerX = centerX,
        centerY = centerY,
        targetX = targetX,
        targetY = targetY,
        dx = dx,
        dy = dy,
        distance = distance,
        hasTarget = hasTarget,
        isBoss = isBoss,
    }
end

local function prepareProjectileVisuals(player)
    local ColorSystem = require("src.gameplay.ColorSystem")
    local ArtifactManager = require("src.gameplay.ArtifactManager")
    local projColor = ColorSystem.getProjectileColor()

    for _, proj in ipairs(getProjectileList(player)) do
        proj.color = projColor

        local baseSize = 8
        local lensLevel = ArtifactManager.getLevel("LENS")
        local lensScale = 1 + (lensLevel * 0.1)

        local abilityCount = 0
        if proj.canPierce then abilityCount = abilityCount + 1 end
        if proj.canBounceToNearest then abilityCount = abilityCount + 1 end
        if proj.canRoot then abilityCount = abilityCount + 1 end
        if proj.canExplode then abilityCount = abilityCount + 1 end
        if proj.canDot then abilityCount = abilityCount + 1 end

        local abilityScale = 1 + (abilityCount * 0.075)
        proj.size = baseSize * lensScale * abilityScale
        proj.age = proj.age or 0
        proj._renderAbilityCount = abilityCount
    end

    return projColor
end

-- Draw the player sprite without above-entity targeting overlays
function PlayerRender.drawPlayer(player)
    local targetInfo = getTargetInfo(player)
    local centerX = targetInfo.centerX
    local centerY = targetInfo.centerY
    local radius = player.width / 2

    -- Draw player as CIRCLE
    if player.invulnerable and math.floor(player.invulnerableTime * 10) % 2 == 0 then
        love.graphics.setColor(0.3, 0.6, 1, 0.5)
    elseif player.damageFlashTime > 0 then
        love.graphics.setColor(1, 0.3, 0.3)
    else
        love.graphics.setColor(0.3, 0.6, 1)
    end
    love.graphics.circle("fill", centerX, centerY, radius)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", centerX, centerY, radius)

    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", centerX, centerY, 2)
end

-- Draw the direction indicator, target line, and target reticle above combatants
function PlayerRender.drawTargetingOverlay(player)
    local targetInfo = getTargetInfo(player)
    local centerX = targetInfo.centerX
    local centerY = targetInfo.centerY
    local targetX = targetInfo.targetX
    local targetY = targetInfo.targetY

    if targetInfo.distance > 0 then
        local dirX = targetInfo.dx / targetInfo.distance
        local dirY = targetInfo.dy / targetInfo.distance
        local indicatorDistance = 20
        local indicatorX = centerX + dirX * indicatorDistance
        local indicatorY = centerY + dirY * indicatorDistance

        love.graphics.setColor(1, 1, 0, 0.8)
        love.graphics.circle("fill", indicatorX, indicatorY, 5)
    end

    if targetInfo.hasTarget then
        if targetInfo.isBoss then
            love.graphics.setColor(0.3, 0.6, 1, 0.7)
        else
            love.graphics.setColor(0.2, 1, 0.2, 0.4)
        end

        love.graphics.setLineWidth(3)
        love.graphics.line(centerX, centerY, targetX, targetY)

        if targetInfo.isBoss then
            love.graphics.setColor(0.3, 0.6, 1, 0.9)
            love.graphics.circle("line", targetX, targetY, 20)
            love.graphics.circle("line", targetX, targetY, 16)
            love.graphics.circle("line", targetX, targetY, 12)
        else
            love.graphics.setColor(0.2, 1, 0.2, 0.8)
            love.graphics.circle("line", targetX, targetY, 15)
            love.graphics.circle("line", targetX, targetY, 12)
        end
    end
end

-- Draw only projectile trails for the behind-entity combat VFX layer
function PlayerRender.drawProjectileTrails(player)
    local projColor = prepareProjectileVisuals(player)

    for _, proj in ipairs(getProjectileList(player)) do
        if proj.trail then
            ShapeLibrary.trail(proj.trail, proj.size, projColor, {fadeAlpha = 0.4})
        end
    end
end

-- Draw only projectile cores for the foreground combat VFX layer
function PlayerRender.drawProjectileCores(player)
    local projColor = prepareProjectileVisuals(player)

    for _, proj in ipairs(getProjectileList(player)) do
        PlayerRender.drawProjectileShape(proj, proj.size, projColor, proj.age or 0, proj._renderAbilityCount or 0)
    end
end

-- Draw all projectiles with trails and special shapes
function PlayerRender.drawProjectiles(player)
    PlayerRender.drawProjectileTrails(player)
    PlayerRender.drawProjectileCores(player)
end

-- Draw a single projectile with its shape
function PlayerRender.drawProjectileShape(proj, renderSize, renderColor, renderAge, abilityCount)
    local shape = proj.shape or "circle"

    if shape == "atom" then
        ShapeLibrary.atom(proj.x, proj.y, renderSize, renderColor, {
            age = renderAge,
            orbitSpeed = 8,
            uniqueSeed = proj.x + proj.y
        })
    elseif shape == "atom_crescent" then
        local angle = MathUtils.atan2(proj.vy, proj.vx)
        ShapeLibrary.atom_crescent(proj.x, proj.y, renderSize, renderColor, {
            angle = angle,
            age = renderAge,
            orbitSpeed = 8,
            uniqueSeed = proj.x + proj.y
        })
    elseif shape == "atom_arrow" then
        local angle = MathUtils.atan2(proj.vy, proj.vx)
        ShapeLibrary.atom_arrow(proj.x, proj.y, renderSize, renderColor, {
            angle = angle,
            age = renderAge,
            orbitSpeed = 8,
            uniqueSeed = proj.x + proj.y
        })
    elseif shape == "crescent_arrow" then
        local angle = MathUtils.atan2(proj.vy, proj.vx)
        ShapeLibrary.crescent(proj.x, proj.y, renderSize, renderColor, {
            angle = angle
        })
        ShapeLibrary.triangle(proj.x, proj.y, renderSize * 0.7, renderColor, {
            rotation = angle + math.pi / 2,
            outline = {1, 1, 1, 0.9},
            outlineWidth = 2
        })
    elseif shape == "crescent" then
        local angle = MathUtils.atan2(proj.vy, proj.vx)
        ShapeLibrary.crescent(proj.x, proj.y, renderSize, renderColor, {
            angle = angle
        })
    elseif shape == "triangle" or shape == "arrow" then
        local angle = MathUtils.atan2(proj.vy, proj.vx) + math.pi / 2
        ShapeLibrary.triangle(proj.x, proj.y, renderSize, renderColor, {
            rotation = angle,
            outline = {1, 1, 1, 0.95},
            outlineWidth = 3
        })
    elseif shape == "prism" then
        ShapeLibrary.prism(proj.x, proj.y, renderSize, renderColor, {
            showRefraction = true
        })
    else
        love.graphics.push()
        love.graphics.translate(proj.x, proj.y)
        PlayerRender.drawCircleShape(proj, renderSize, renderColor, abilityCount)
        love.graphics.pop()
    end
end

-- Circle shape with ability indicators
function PlayerRender.drawCircleShape(proj, renderSize, renderColor, abilityCount)
    local hasMultipleAbilities = abilityCount > 1

    if proj.canPierce and not hasMultipleAbilities then
        PlayerRender.drawPierceShape(proj, renderSize, renderColor)
    elseif proj.canBounceToNearest and not hasMultipleAbilities then
        PlayerRender.drawBounceShape(proj, renderSize, renderColor)
    elseif proj.type == "spread" and not hasMultipleAbilities then
        PlayerRender.drawSpreadShape(proj, renderSize, renderColor)
    elseif proj.canRoot and not hasMultipleAbilities then
        PlayerRender.drawRootShape(proj, renderSize, renderColor)
    elseif proj.canExplode and not hasMultipleAbilities then
        PlayerRender.drawExplodeShape(proj, renderSize, renderColor)
    elseif proj.canDot and not hasMultipleAbilities then
        PlayerRender.drawDotShape(proj, renderSize, renderColor)
    else
        PlayerRender.drawMultiAbilityShape(proj, renderSize, renderColor)
    end
end

-- Pierce projectile shape
function PlayerRender.drawPierceShape(proj, renderSize, renderColor)
    local angle = MathUtils.atan2(proj.vy, proj.vx)
    love.graphics.push()
    love.graphics.rotate(angle)

    local vertices = {
        renderSize * 1.8, 0,
        renderSize * 0.3, renderSize * 0.6,
        -renderSize * 0.5, 0,
        renderSize * 0.3, -renderSize * 0.6
    }

    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.polygon("line", vertices)

    love.graphics.setColor(renderColor)
    love.graphics.polygon("fill", vertices)

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.line(renderSize * 1.5, 0, -renderSize * 0.3, 0)

    love.graphics.pop()
end

-- Bounce projectile shape
function PlayerRender.drawBounceShape(proj, renderSize, renderColor)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, renderSize)

    love.graphics.setColor(renderColor)
    love.graphics.circle("fill", 0, 0, renderSize)

    local orbitAngle = love.timer.getTime() * 4
    love.graphics.setColor(0.3, 1, 0.3, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, renderSize * 1.4)

    local orbitX = math.cos(orbitAngle) * renderSize * 1.4
    local orbitY = math.sin(orbitAngle) * renderSize * 1.4
    love.graphics.circle("fill", orbitX, orbitY, renderSize * 0.2)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 0, 0, renderSize * 0.5)
end

-- Spread projectile shape
function PlayerRender.drawSpreadShape(proj, renderSize, renderColor)
    local spreadSize = renderSize * 1.15

    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, spreadSize)

    love.graphics.setColor(renderColor)
    love.graphics.circle("fill", 0, 0, spreadSize)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 0, 0, spreadSize * 0.5)
end

-- Root projectile shape
function PlayerRender.drawRootShape(proj, renderSize, renderColor)
    local pulse = 0.8 + math.sin(love.timer.getTime() * 6) * 0.2
    love.graphics.setColor(1, 1, 0, 0.4 * pulse)
    love.graphics.circle("fill", 0, 0, renderSize * 1.8 * pulse)

    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, renderSize)

    love.graphics.setColor(renderColor)
    love.graphics.circle("fill", 0, 0, renderSize)

    love.graphics.setColor(1, 1, 0, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, renderSize * 1.3)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 0, 0, renderSize * 0.5)
end

-- Explode projectile shape
function PlayerRender.drawExplodeShape(proj, renderSize, renderColor)
    love.graphics.setColor(1, 0.2, 1, 0.3)
    love.graphics.circle("fill", 0, 0, renderSize * 1.8)

    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, renderSize)

    love.graphics.setColor(renderColor)
    love.graphics.circle("fill", 0, 0, renderSize)

    love.graphics.setColor(1, 0.2, 1, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, renderSize * 1.4)
    love.graphics.circle("line", 0, 0, renderSize * 1.6)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 0, 0, renderSize * 0.5)
end

-- DoT projectile shape
function PlayerRender.drawDotShape(proj, renderSize, renderColor)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, renderSize)

    love.graphics.setColor(renderColor)
    love.graphics.circle("fill", 0, 0, renderSize)

    love.graphics.setColor(0.4, 1, 1, 0.8)
    for i = 0, 3 do
        local angle = (i / 4) * math.pi * 2 + love.timer.getTime() * 3
        local spiralRadius = renderSize * 1.4
        local x = math.cos(angle) * spiralRadius
        local y = math.sin(angle) * spiralRadius
        love.graphics.circle("fill", x, y, renderSize * 0.25)
    end

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 0, 0, renderSize * 0.5)
end

-- Multi-ability projectile shape
function PlayerRender.drawMultiAbilityShape(proj, renderSize, renderColor)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, renderSize)

    love.graphics.setColor(renderColor)
    love.graphics.circle("fill", 0, 0, renderSize)

    if proj.canPierce then
        local angle = MathUtils.atan2(proj.vy, proj.vx)
        love.graphics.push()
        love.graphics.rotate(angle)

        love.graphics.setColor(0.3, 0.8, 1, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.line(-renderSize * 0.7, 0, renderSize * 0.7, 0)
        love.graphics.line(renderSize * 0.5, -renderSize * 0.3, renderSize * 0.7, 0)
        love.graphics.line(renderSize * 0.5, renderSize * 0.3, renderSize * 0.7, 0)

        love.graphics.pop()
    end

    if proj.canBounceToNearest then
        love.graphics.setColor(0.3, 1, 0.3, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, renderSize * 1.4)
    end

    if proj.canRoot then
        local pulse = 0.8 + math.sin(love.timer.getTime() * 6) * 0.2
        love.graphics.setColor(1, 1, 0, 0.6 * pulse)
        love.graphics.circle("line", 0, 0, renderSize * 1.6)
    end

    if proj.canExplode then
        love.graphics.setColor(1, 0.2, 1, 0.5)
        love.graphics.circle("line", 0, 0, renderSize * 1.8)
    end

    if proj.canDot then
        love.graphics.setColor(0.4, 1, 1, 0.8)
        for i = 0, 2 do
            local angle = (i / 3) * math.pi * 2 + love.timer.getTime() * 3
            local x = math.cos(angle) * renderSize * 1.3
            local y = math.sin(angle) * renderSize * 1.3
            love.graphics.circle("fill", x, y, renderSize * 0.2)
        end
    end

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 0, 0, renderSize * 0.5)
end

return PlayerRender
