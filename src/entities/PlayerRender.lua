-- PlayerRender.lua
-- Handles all player and projectile rendering
-- Extracted from Player.lua for better separation of concerns

local PlayerRender = {}
local ShapeLibrary = require("src.render.ShapeLibrary")
local MathUtils = require("src.utils.MathUtils")

local function blendTowardsWhite(color, amount)
    return {
        color[1] + (1 - color[1]) * amount,
        color[2] + (1 - color[2]) * amount,
        color[3] + (1 - color[3]) * amount,
    }
end

local function mixColors(a, b, ratio)
    ratio = ratio or 0.5
    local inv = 1 - ratio
    return {
        a[1] * inv + b[1] * ratio,
        a[2] * inv + b[2] * ratio,
        a[3] * inv + b[3] * ratio,
    }
end

local function drawPrismHexBody(size, color, rotation, gapScale)
    local facetGap = size * (gapScale or 0.08)
    local innerRadius = size * 0.34
    local outerRadius = size * 0.92
    local glowRadius = size * 1.1
    local facetColor = blendTowardsWhite(color, 0.12)
    local coreColor = blendTowardsWhite(color, 0.7)

    love.graphics.setBlendMode("add")
    love.graphics.setColor(color[1], color[2], color[3], 0.18)
    love.graphics.circle("fill", 0, 0, glowRadius)
    love.graphics.setBlendMode("alpha")

    love.graphics.push()
    love.graphics.rotate(rotation or 0)

    for i = 0, 5 do
        local a0 = (i / 6) * math.pi * 2
        local a1 = ((i + 1) / 6) * math.pi * 2
        local amid = (a0 + a1) * 0.5
        local offsetX = math.cos(amid) * facetGap
        local offsetY = math.sin(amid) * facetGap

        local vertices = {
            offsetX, offsetY,
            math.cos(a0) * outerRadius + offsetX, math.sin(a0) * outerRadius + offsetY,
            math.cos(a1) * outerRadius + offsetX, math.sin(a1) * outerRadius + offsetY,
        }

        love.graphics.setColor(facetColor[1], facetColor[2], facetColor[3], 0.26)
        love.graphics.polygon("fill", vertices)
        love.graphics.setColor(color[1], color[2], color[3], 0.92)
        love.graphics.setLineWidth(1.5)
        love.graphics.polygon("line", vertices)
    end

    local ringVerts = {}
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2
        ringVerts[#ringVerts + 1] = math.cos(angle) * outerRadius
        ringVerts[#ringVerts + 1] = math.sin(angle) * outerRadius
    end
    love.graphics.setColor(color[1], color[2], color[3], 0.65)
    love.graphics.setLineWidth(1.2)
    love.graphics.polygon("line", ringVerts)

    love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], 0.95)
    love.graphics.circle("fill", 0, 0, innerRadius)
    love.graphics.setColor(1, 1, 1, 0.98)
    love.graphics.circle("fill", 0, 0, math.max(1.5, size * 0.16))

    love.graphics.pop()
end

local function drawBossStyleTrail(proj, color)
    if not proj.trail or #proj.trail < 2 then
        return
    end

    local len = #proj.trail
    local r, g, b = color[1], color[2], color[3]

    love.graphics.setBlendMode("add")
    for i = 2, len do
        local t = 1 - (i - 1) / len
        love.graphics.setColor(r, g, b, t * 0.18)
        love.graphics.setLineWidth(math.max(1, t * 10))
        love.graphics.line(
            proj.trail[i - 1].x, proj.trail[i - 1].y,
            proj.trail[i].x, proj.trail[i].y
        )
    end
    love.graphics.setBlendMode("alpha")

    for i = 2, len do
        local t = 1 - (i - 1) / len
        love.graphics.setColor(r, g, b, t * 0.85)
        love.graphics.setLineWidth(math.max(1, t * 2.5))
        love.graphics.line(
            proj.trail[i - 1].x, proj.trail[i - 1].y,
            proj.trail[i].x, proj.trail[i].y
        )
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawOrbProjectile(size, color, rotation)
    love.graphics.push()
    love.graphics.rotate(rotation or 0)
    love.graphics.setColor(color[1], color[2], color[3], 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", 0, 0, size * 0.78)
    love.graphics.setColor(color[1], color[2], color[3], 0.6)
    love.graphics.circle("line", 0, 0, size * 0.4)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", 0, 0, math.max(1.5, size * 0.2))
    love.graphics.pop()
end

local function drawBoltProjectile(size, color, angle)
    love.graphics.push()
    love.graphics.rotate(angle)
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line",
        0, -size * 1.2,
        size * 0.34, -size * 0.22,
        size * 0.24, size * 1.08,
        -size * 0.24, size * 1.08,
        -size * 0.34, -size * 0.22
    )
    love.graphics.setBlendMode("add")
    love.graphics.setColor(color[1], color[2], color[3], 0.35)
    love.graphics.ellipse("fill", 0, 0, size * 0.28, size * 0.85)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", 0, 0, math.max(1.3, size * 0.16))
    love.graphics.pop()
end

local function drawChevronProjectile(size, color, angle)
    love.graphics.push()
    love.graphics.rotate(angle)
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(-size * 0.7, size * 0.55, 0, -size)
    love.graphics.line(0, -size, size * 0.7, size * 0.55)
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(color[1], color[2], color[3], 0.6)
    love.graphics.line(-size * 0.45, size * 1.0, 0, -size * 0.1)
    love.graphics.line(0, -size * 0.1, size * 0.45, size * 1.0)
    love.graphics.pop()
end

local function drawCrescentProjectile(size, color, angle)
    love.graphics.push()
    love.graphics.rotate(angle)
    love.graphics.setColor(color[1], color[2], color[3], 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", "open", 0, 0, size * 0.88, 0.5, math.pi - 0.5)
    love.graphics.arc("line", "open", size * 0.38, 0, size * 0.62, math.pi + 0.35, math.pi * 2 - 0.35)
    love.graphics.pop()
end

local function drawShardProjectile(size, color, rotation)
    love.graphics.push()
    love.graphics.rotate(rotation or 0)
    local verts = {}
    for k = 0, 7 do
        local a = (k / 8) * math.pi * 2
        local r2 = (k % 2 == 0) and (size * 0.95) or (size * 0.42)
        verts[#verts + 1] = math.cos(a) * r2
        verts[#verts + 1] = math.sin(a) * r2
    end
    love.graphics.setBlendMode("add")
    love.graphics.setColor(color[1], color[2], color[3], 0.2)
    love.graphics.polygon("fill", verts)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", verts)
    love.graphics.pop()
end

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
    local ColorSystem = require("src.gameplay.ColorSystem")
    local centerX = player.x + player.width / 2
    local centerY = player.y + player.height / 2
    local radius = player.width / 2
    local baseWhite = {1, 1, 1}
    local dominantColor = ColorSystem.getDominantColor()
    local chosenColor = dominantColor and ColorSystem.getColorRGB(dominantColor) or baseWhite
    local playerColor = mixColors(baseWhite, chosenColor, dominantColor and 0.72 or 0)

    local bodyColor
    if player.invulnerable and math.floor(player.invulnerableTime * 10) % 2 == 0 then
        bodyColor = {playerColor[1], playerColor[2], playerColor[3], 0.55}
    elseif player.damageFlashTime > 0 then
        bodyColor = {1, 0.3, 0.3, 1}
    else
        bodyColor = {playerColor[1], playerColor[2], playerColor[3], 1}
    end

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    drawPrismHexBody(radius * 1.25, bodyColor, love.timer.getTime() * 0.7, 0.08)
    love.graphics.pop()
end

-- Draw the direction indicator, target line, and target reticle above combatants
function PlayerRender.drawTargetingOverlay(player)
    return
end

-- Draw only projectile trails for the behind-entity combat VFX layer
function PlayerRender.drawProjectileTrails(player)
    local projColor = prepareProjectileVisuals(player)

    for _, proj in ipairs(getProjectileList(player)) do
        drawBossStyleTrail(proj, proj.color or projColor)
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
    local angle = MathUtils.atan2(proj.vy, proj.vx)
    local spin = renderAge * 3.5

    if shape == "atom" then
        love.graphics.push()
        love.graphics.translate(proj.x, proj.y)
        drawOrbProjectile(renderSize, renderColor, spin)
        love.graphics.pop()
    elseif shape == "atom_crescent" then
        love.graphics.push()
        love.graphics.translate(proj.x, proj.y)
        drawCrescentProjectile(renderSize, renderColor, angle)
        drawOrbProjectile(renderSize * 0.68, renderColor, -spin)
        love.graphics.pop()
    elseif shape == "atom_arrow" then
        love.graphics.push()
        love.graphics.translate(proj.x, proj.y)
        drawOrbProjectile(renderSize * 0.72, renderColor, spin)
        drawBoltProjectile(renderSize * 0.9, renderColor, angle + math.pi * 0.5)
        love.graphics.pop()
    elseif shape == "crescent_arrow" then
        love.graphics.push()
        love.graphics.translate(proj.x, proj.y)
        drawCrescentProjectile(renderSize, renderColor, angle)
        drawChevronProjectile(renderSize * 0.78, renderColor, angle + math.pi * 0.5)
        love.graphics.pop()
    elseif shape == "crescent" then
        love.graphics.push()
        love.graphics.translate(proj.x, proj.y)
        drawCrescentProjectile(renderSize, renderColor, angle)
        love.graphics.pop()
    elseif shape == "triangle" or shape == "arrow" then
        love.graphics.push()
        love.graphics.translate(proj.x, proj.y)
        drawBoltProjectile(renderSize, renderColor, angle + math.pi * 0.5)
        love.graphics.pop()
    elseif shape == "prism" then
        love.graphics.push()
        love.graphics.translate(proj.x, proj.y)
        drawShardProjectile(renderSize, renderColor, spin)
        love.graphics.pop()
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
    drawBoltProjectile(renderSize * 0.95, renderColor, angle + math.pi * 0.5)
end

-- Bounce projectile shape
function PlayerRender.drawBounceShape(proj, renderSize, renderColor)
    drawOrbProjectile(renderSize, renderColor, love.timer.getTime() * 4)
    love.graphics.setColor(0.3, 1, 0.3, 0.75)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", 0, 0, renderSize * 1.2)
end

-- Spread projectile shape
function PlayerRender.drawSpreadShape(proj, renderSize, renderColor)
    drawOrbProjectile(renderSize * 1.05, renderColor, love.timer.getTime() * 3.2)
end

-- Root projectile shape
function PlayerRender.drawRootShape(proj, renderSize, renderColor)
    local pulse = 0.8 + math.sin(love.timer.getTime() * 6) * 0.2
    drawOrbProjectile(renderSize, renderColor, love.timer.getTime() * 3)
    love.graphics.setColor(1, 1, 0, 0.8)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", 0, 0, renderSize * (1.2 + 0.18 * pulse))
end

-- Explode projectile shape
function PlayerRender.drawExplodeShape(proj, renderSize, renderColor)
    drawShardProjectile(renderSize * 0.95, renderColor, love.timer.getTime() * 3)
    love.graphics.setColor(1, 0.2, 1, 0.7)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", 0, 0, renderSize * 1.24)
    love.graphics.circle("line", 0, 0, renderSize * 1.48)
end

-- DoT projectile shape
function PlayerRender.drawDotShape(proj, renderSize, renderColor)
    drawOrbProjectile(renderSize, renderColor, love.timer.getTime() * 2.8)
    love.graphics.setColor(0.4, 1, 1, 0.8)
    for i = 0, 3 do
        local angle = (i / 4) * math.pi * 2 + love.timer.getTime() * 3
        local spiralRadius = renderSize * 1.4
        local x = math.cos(angle) * spiralRadius
        local y = math.sin(angle) * spiralRadius
        love.graphics.circle("line", x, y, renderSize * 0.22)
    end
end

-- Multi-ability projectile shape
function PlayerRender.drawMultiAbilityShape(proj, renderSize, renderColor)
    drawOrbProjectile(renderSize, renderColor, love.timer.getTime() * 3.1)

    if proj.canPierce then
        local angle = MathUtils.atan2(proj.vy, proj.vx)
        love.graphics.push()
        love.graphics.rotate(angle)

        love.graphics.setColor(0.3, 0.8, 1, 0.9)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(-renderSize * 0.7, 0, renderSize * 0.7, 0)
        love.graphics.line(renderSize * 0.5, -renderSize * 0.3, renderSize * 0.7, 0)
        love.graphics.line(renderSize * 0.5, renderSize * 0.3, renderSize * 0.7, 0)

        love.graphics.pop()
    end

    if proj.canBounceToNearest then
        love.graphics.setColor(0.3, 1, 0.3, 0.8)
        love.graphics.setLineWidth(1.5)
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
            love.graphics.circle("line", x, y, renderSize * 0.2)
        end
    end
end

return PlayerRender
