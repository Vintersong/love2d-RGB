local ArtifactPanel = {}

local Shared = require("src.ui.Shared")
local Theme = require("src.render.Theme")
local Icons = require("src.render.Icons")
local SimpleGrid = require("src.gameplay.SimpleGrid")
local AbilitySystem = require("src.combat.AbilitySystem")
local AbilityLibrary = require("src.data.AbilityLibrary")
local ColorSystem = require("src.gameplay.ColorSystem")
local MetaProgression = require("src.core.MetaProgression")

local ARTIFACT_ORDER = {
    "LENS",
    "MIRROR",
    "PRISM",
    "HALO",
    "AURORA",
    "DIFFRACTION",
    "REFRACTION",
    "SUPERNOVA",
}

local ARTIFACT_COLORS = {
    PRISM = Theme.color.magenta,
    HALO = Theme.color.yellow,
    MIRROR = Theme.color.cyan,
    LENS = Theme.color.blue,
    AURORA = Theme.color.green,
    DIFFRACTION = Theme.color.red,
    REFRACTION = Theme.color.accent,
    SUPERNOVA = Theme.color.warn,
}

local function clamp01(value)
    return math.max(0, math.min(1, value or 0))
end

local function buildArtifactLookup(artifacts)
    local lookup = {}
    for _, artifact in ipairs(artifacts or {}) do
        lookup[artifact.type] = artifact
    end
    return lookup
end

local function drawBand(y, width, height)
    love.graphics.setColor(0.01, 0.01, 0.015, 0.72)
    love.graphics.rectangle("fill", 0, y, width, height)

    local accent = Theme.color.accent
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.12)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, y, width, y)
    love.graphics.line(0, y + height, width, y + height)
end

local function drawExperienceBandBar(player, topY, bandHeight)
    local cellSize = SimpleGrid.cellSize or 48
    local gridX = SimpleGrid.originX or 0
    local gridW = SimpleGrid.gridWidth or 0
    local barX = gridX + cellSize
    local chromaPanelW = math.floor(cellSize * 3.8)
    local chromaGap = math.floor(cellSize * 0.35)
    local barW = math.max(cellSize * 2, gridW - cellSize * 2 - chromaPanelW - chromaGap)
    local barH = math.floor(cellSize * 0.5)
    local barY = topY + math.floor(cellSize * 0.35)
    local current = math.floor((player and player.exp) or 0)
    local maxValue = math.max(1, (player and player.expToNext) or 1)
    local percent = clamp01(current / maxValue)
    local fill = Theme.color.accent
    local label = "XP"
    local valueText = string.format("%d / %d", current, maxValue)
    local chromaX = barX + barW + chromaGap
    local chromaValue = MetaProgression.getChroma()
    local chromaText = tostring(chromaValue)

    love.graphics.setColor(0, 0, 0, 0.48)
    love.graphics.rectangle("fill", barX, barY, barW, barH)

    love.graphics.setColor(Theme.color.bgRaised[1], Theme.color.bgRaised[2], Theme.color.bgRaised[3], 0.95)
    love.graphics.rectangle("fill", barX + 1, barY + 1, barW - 2, barH - 2)

    love.graphics.setColor(fill[1], fill[2], fill[3], 0.92)
    love.graphics.rectangle("fill", barX + 1, barY + 1, (barW - 2) * percent, barH - 2)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(fill[1], fill[2], fill[3], 0.5)
    love.graphics.rectangle("line", barX, barY, barW, barH)

    love.graphics.setFont(Theme.font("mono", 13))
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.print(label, barX + 12, barY + 5)

    local valueWidth = love.graphics.getFont():getWidth(valueText)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(valueText, barX + barW - valueWidth - 11, barY + 6)
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.print(valueText, barX + barW - valueWidth - 12, barY + 5)

    Shared.drawGlassPanel(chromaX, barY, chromaPanelW, barH, {fillAlpha = 0.5, edgeAlpha = 0.16, lineWidth = 1})
    love.graphics.setColor(Theme.color.bgRaised[1], Theme.color.bgRaised[2], Theme.color.bgRaised[3], 0.96)
    love.graphics.rectangle("fill", chromaX + 1, barY + 1, chromaPanelW - 2, barH - 2)
    love.graphics.setColor(Theme.color.warn[1], Theme.color.warn[2], Theme.color.warn[3], 0.14)
    love.graphics.rectangle("fill", chromaX + 1, barY + 1, chromaPanelW - 2, barH - 2)
    love.graphics.setColor(Theme.color.warn[1], Theme.color.warn[2], Theme.color.warn[3], 0.55)
    love.graphics.rectangle("line", chromaX, barY, chromaPanelW, barH)

    love.graphics.setFont(Theme.font("mono", 12))
    love.graphics.setColor(Theme.color.warn[1], Theme.color.warn[2], Theme.color.warn[3], 1)
    love.graphics.print("CHR", chromaX + 10, barY + 6)
    local chromaWidth = love.graphics.getFont():getWidth(chromaText)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(chromaText, chromaX + chromaPanelW - chromaWidth - 11, barY + 6)
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.print(chromaText, chromaX + chromaPanelW - chromaWidth - 12, barY + 5)
end

local function drawCooldownBandBars(player, topY, bandHeight)
    local cellSize = SimpleGrid.cellSize or 48
    local gridX = SimpleGrid.originX or 0
    local gridW = SimpleGrid.gridWidth or 0
    local iconSize = math.floor(cellSize * 0.68)
    local iconGap = math.floor(cellSize * 0.16)
    local barH = math.floor(cellSize * 0.5)
    local xpBarX = gridX + cellSize
    local xpBarW = math.max(cellSize * 2, gridW - cellSize * 2)
    local leftIconX = xpBarX
    local rightIconX = xpBarX + xpBarW - iconSize
    local centerGap = math.floor(cellSize * 0.72)
    local leftBarX = leftIconX + iconSize + iconGap
    local rightBarLimit = rightIconX - iconGap
    local usableWidth = rightBarLimit - leftBarX
    local barW = math.floor((usableWidth - centerGap) * 0.5)
    local rightBarX = leftBarX + barW + centerGap
    local barY = topY + bandHeight - barH - math.floor(cellSize * 0.14)

    local function drawBar(barX, abilityName, iconName, accentColor, iconSide)
        local state = AbilitySystem.getState(player, abilityName)
        local abilityDef = AbilityLibrary[abilityName]
        local cooldownRemaining = state and state.cooldown or 0
        local progress = AbilitySystem.getCooldownProgress(player, abilityName, abilityDef)
        local iconX

        Shared.drawGlassPanel(barX, barY, barW, barH, {fillAlpha = 0.5, edgeAlpha = 0.14, lineWidth = 1})
        love.graphics.setColor(Theme.color.bgRaised[1], Theme.color.bgRaised[2], Theme.color.bgRaised[3], 0.96)
        love.graphics.rectangle("fill", barX + 1, barY + 1, barW - 2, barH - 2)

        if progress >= 1 then
            local pulse = math.sin(love.timer.getTime() * 4.5) * 0.18 + 0.82
            love.graphics.setColor(Theme.color.ok[1] * pulse, Theme.color.ok[2] * pulse, Theme.color.ok[3] * pulse, 0.95)
        else
            love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 0.94)
        end
        love.graphics.rectangle("fill", barX + 1, barY + 1, (barW - 2) * progress, barH - 2)

        love.graphics.setLineWidth(1)
        love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 0.7)
        love.graphics.rectangle("line", barX, barY, barW, barH)

        if iconSide == "left" then
            iconX = leftIconX
        else
            iconX = rightIconX
        end

        if Icons.has(iconName) then
            Icons.draw(iconName, iconX, barY + math.floor((barH - iconSize) * 0.5), iconSize, {
                width = 1.9,
                color = {accentColor[1], accentColor[2], accentColor[3], 0.95}
            })
        end

        love.graphics.setFont(Theme.font("mono", 12))
        local statusText = progress >= 1 and "READY" or string.format("%.1fs", cooldownRemaining)
        local statusColor = progress >= 1 and Theme.color.ok or Theme.color.fg1

        if iconSide == "left" then
            love.graphics.setColor(statusColor[1], statusColor[2], statusColor[3], 1)
            love.graphics.print(statusText, barX + barW - love.graphics.getFont():getWidth(statusText) - 10, barY + 4)
        else
            love.graphics.setColor(statusColor[1], statusColor[2], statusColor[3], 1)
            love.graphics.print(statusText, barX + 10, barY + 4)
        end
    end

    drawBar(leftBarX, "DASH", "dash", Theme.color.accent, "left")
    drawBar(rightBarX, "BLINK", "blink", Theme.color.magenta, "right")
end

local function drawHealthBandBar(player, x, y, w, h)
    local current = math.floor((player and player.hp) or 0)
    local maxValue = math.max(1, (player and player.maxHp) or 1)
    local percent = clamp01(current / maxValue)
    local fill = Theme.color.ok
    if percent <= 0.25 then
        fill = Theme.color.danger
    elseif percent <= 0.5 then
        fill = Theme.color.warn
    end
    local valueText = string.format("%d / %d", current, maxValue)

    love.graphics.setColor(0, 0, 0, 0.48)
    love.graphics.rectangle("fill", x, y, w, h)

    love.graphics.setColor(Theme.color.bgRaised[1], Theme.color.bgRaised[2], Theme.color.bgRaised[3], 0.95)
    love.graphics.rectangle("fill", x + 1, y + 1, w - 2, h - 2)

    love.graphics.setColor(fill[1], fill[2], fill[3], 0.92)
    love.graphics.rectangle("fill", x + 1, y + 1, (w - 2) * percent, h - 2)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(fill[1], fill[2], fill[3], 0.5)
    love.graphics.rectangle("line", x, y, w, h)

    love.graphics.setFont(Theme.font("mono", 13))
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.print("HP", x + 12, y + 5)

    local valueWidth = love.graphics.getFont():getWidth(valueText)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(valueText, x + w - valueWidth - 11, y + 6)
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.print(valueText, x + w - valueWidth - 12, y + 5)
end

local function drawShieldReadyIcon(player, x, y, size)
    local state = AbilitySystem.getState(player, "SHIELD")
    local abilityDef = AbilityLibrary.SHIELD
    local progress = AbilitySystem.getCooldownProgress(player, "SHIELD", abilityDef)
    local ready = progress >= 1
    local baseColor = Theme.color.blue
    local color

    if ready then
        local pulse = math.sin(love.timer.getTime() * 4.0) * 0.14 + 0.86
        color = {baseColor[1] * pulse, baseColor[2] * pulse, baseColor[3] * pulse, 0.98}
    else
        local grey = 0.58
        color = {
            baseColor[1] * 0.35 + grey * 0.65,
            baseColor[2] * 0.35 + grey * 0.65,
            baseColor[3] * 0.35 + grey * 0.65,
            0.62
        }
    end

    love.graphics.setColor(0, 0, 0, ready and 0.38 or 0.26)
    love.graphics.rectangle("fill", x, y, size, size)

    love.graphics.setColor(color[1], color[2], color[3], ready and 0.16 or 0.08)
    love.graphics.rectangle("fill", x + 1, y + 1, size - 2, size - 2)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(color[1], color[2], color[3], ready and 0.75 or 0.4)
    love.graphics.rectangle("line", x, y, size, size)

    if Icons.has("shield") then
        local iconInset = math.floor(size * 0.13)
        Icons.draw("shield", x + iconInset, y + iconInset, size - iconInset * 2, {
            width = ready and 2.2 or 1.8,
            color = color
        })
    end
end

local function getPathBarData()
    local bars = {}
    local primary1 = ColorSystem.commitment and ColorSystem.commitment.primary1 or nil
    local primary2 = ColorSystem.commitment and ColorSystem.commitment.primary2 or nil
    local secondaryName = ColorSystem.getCommittedSecondaryName and ColorSystem.getCommittedSecondaryName() or nil

    if primary1 then
        bars[1] = {
            color = ColorSystem.getColorRGB(primary1),
            progress = clamp01((ColorSystem.primary[primary1].level or 0) / 10)
        }
    end

    if primary2 then
        bars[2] = {
            color = ColorSystem.getColorRGB(primary2),
            progress = clamp01((ColorSystem.primary[primary2].level or 0) / 10)
        }
    end

    if secondaryName and ColorSystem.secondary and ColorSystem.secondary[secondaryName] and ColorSystem.secondary[secondaryName].level > 0 then
        bars[3] = {
            color = ColorSystem.getColorRGB(secondaryName),
            progress = clamp01((ColorSystem.secondary[secondaryName].level or 0) / 10)
        }
    end

    return bars
end

local function drawPathBandBars(x, y, w, h)
    if w <= 0 or h <= 0 then
        return
    end

    local barGap = math.floor((SimpleGrid.cellSize or 48) * 0.14)
    local barW = math.floor((w - barGap * 2) / 3)
    local bars = getPathBarData()

    for i = 1, 3 do
        local barX = x + (i - 1) * (barW + barGap)
        local data = bars[i]
        local fill = data and data.color or nil
        local progress = data and data.progress or 0

        love.graphics.setColor(0, 0, 0, 0.48)
        love.graphics.rectangle("fill", barX, y, barW, h)

        love.graphics.setColor(Theme.color.bgRaised[1], Theme.color.bgRaised[2], Theme.color.bgRaised[3], 0.95)
        love.graphics.rectangle("fill", barX + 1, y + 1, barW - 2, h - 2)

        if fill then
            love.graphics.setColor(fill[1], fill[2], fill[3], 0.92)
            love.graphics.rectangle("fill", barX + 1, y + 1, (barW - 2) * progress, h - 2)
            love.graphics.setColor(fill[1], fill[2], fill[3], 0.6)
        else
            love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], 0.25)
        end

        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", barX, y, barW, h)
    end
end

local function drawSlot(x, y, slotSize, artifactType, artifact, slotLabel, persistentLevel)
    local typeName = artifactType or slotLabel
    local color = ARTIFACT_COLORS[typeName] or Theme.color.fg3
    local level = artifact and artifact.level or 0
    local maxLevel = artifact and artifact.maxLevel or 0
    local iconName = typeName and string.lower(typeName) or nil
    local isCollected = artifact ~= nil
    local isUnlocked = (persistentLevel or 0) > 0
    local frameColor = Theme.color.fg3
    local fillAlpha = 0.045
    local borderAlpha = 0.16
    local iconAlpha = 0
    local labelAlpha = 0.95

    if not isUnlocked then
        labelAlpha = 0.28
    elseif not isCollected then
        labelAlpha = 0.46
    else
        frameColor = color
        fillAlpha = 0.18
        borderAlpha = 0.74
        iconAlpha = 1
        labelAlpha = 0.92
    end

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", x, y, slotSize, slotSize)

    love.graphics.setColor(frameColor[1], frameColor[2], frameColor[3], fillAlpha)
    love.graphics.rectangle("fill", x + 1, y + 1, slotSize - 2, slotSize - 2)

    love.graphics.setColor(frameColor[1], frameColor[2], frameColor[3], borderAlpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, slotSize, slotSize)

    if isCollected and iconAlpha > 0 and iconName and Icons.has(iconName) then
        love.graphics.setColor(0, 0, 0, 0.34)
        love.graphics.rectangle("fill", x + 9, y + 9, slotSize - 18, slotSize - 18)

        love.graphics.setColor(color[1], color[2], color[3], 0.16)
        love.graphics.rectangle("fill", x + 10, y + 10, slotSize - 20, slotSize - 20)

        Icons.draw(iconName, x + 8, y + 8, slotSize - 16, {
            width = 3.2,
            color = {color[1], color[2], color[3], 0.24}
        })
        Icons.draw(iconName, x + 10, y + 10, slotSize - 20, {
            width = 2.2,
            color = {frameColor[1], frameColor[2], frameColor[3], iconAlpha}
        })
    end

    love.graphics.setFont(Theme.font("mono", 11))
    love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], labelAlpha)
    love.graphics.print(slotLabel, x + 4, y + 4)

    if isCollected then
        local progress = 0
        if maxLevel > 0 then
            progress = clamp01(level / maxLevel)
        end

        local barX = x + 8
        local barY = y + slotSize - 12
        local barW = slotSize - 16
        local barH = 4

        love.graphics.setColor(Theme.color.bgRaised[1], Theme.color.bgRaised[2], Theme.color.bgRaised[3], 1)
        love.graphics.rectangle("fill", barX, barY, barW, barH)
        love.graphics.setColor(color[1], color[2], color[3], 0.95)
        love.graphics.rectangle("fill", barX, barY, barW * progress, barH)

        local levelText = string.format("Lv%d", level)
        love.graphics.setFont(Theme.font("mono", 12))
        love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
        love.graphics.print(levelText, x + slotSize - Theme.font("mono", 12):getWidth(levelText) - 6, y + 4)
    end
end

function ArtifactPanel.drawArtifactPanel(player)
    local ArtifactManager = require("src.gameplay.ArtifactManager")

    local screenWidth, screenHeight = Shared.getScreenSize()
    local cellSize = SimpleGrid.cellSize or 48
    local bandHeight = cellSize * 2
    local slotSize = bandHeight
    local topY = 0
    local bottomY = screenHeight - bandHeight

    drawBand(topY, screenWidth, bandHeight)
    drawBand(bottomY, screenWidth, bandHeight)
    drawExperienceBandBar(player, topY, bandHeight)
    drawCooldownBandBars(player, topY, bandHeight)

    local lookup = buildArtifactLookup(ArtifactManager.getCollectedArtifacts())
    local centerCols = SimpleGrid.centerCols or {math.floor((screenWidth / cellSize) * 0.5), math.floor((screenWidth / cellSize) * 0.5) + 1}
    local centerStartX = (SimpleGrid.originX or 0) + (centerCols[1] - 1) * cellSize
    local centerWidth = cellSize * 2

    local leftStartX = centerStartX - (slotSize * 4)
    local rightStartX = centerStartX + centerWidth
    local barH = math.floor(cellSize * 0.5)
    local hpBarX = (SimpleGrid.originX or 0) + cellSize
    local hpBarW = math.max(cellSize * 2, leftStartX - hpBarX - math.floor(cellSize * 0.75))
    local hpBarY = bottomY + math.floor((bandHeight - barH) * 0.5)
    local rightLaneLeft = rightStartX + (slotSize * 4) + math.floor(cellSize * 0.35)
    local rightLaneRight = (SimpleGrid.originX or 0) + SimpleGrid.gridWidth - cellSize
    local pathBarsW = math.max(0, rightLaneRight - rightLaneLeft)
    local pathBarsH = barH
    local pathBarsX = rightLaneRight - pathBarsW
    local pathBarsY = hpBarY
    local shieldIconSize = math.floor(cellSize * 1.55)
    local shieldIconX = centerStartX + math.floor((centerWidth - shieldIconSize) * 0.5)
    local shieldIconY = bottomY + math.floor((bandHeight - shieldIconSize) * 0.5)

    if hpBarW > cellSize * 2 then
        drawHealthBandBar(player, hpBarX, hpBarY, hpBarW, barH)
    end
    if pathBarsW > cellSize * 2 then
        drawPathBandBars(pathBarsX, pathBarsY, pathBarsW, pathBarsH)
    end
    drawShieldReadyIcon(player, shieldIconX, shieldIconY, shieldIconSize)

    for i, artifactType in ipairs(ARTIFACT_ORDER) do
        local x
        if i <= 4 then
            x = leftStartX + (i - 1) * slotSize
        else
            x = rightStartX + (i - 5) * slotSize
        end
        local y = bottomY
        local label = string.format("%02d", i)
        drawSlot(x, y, slotSize, artifactType, lookup[artifactType], label, MetaProgression.getArtifactLevel(artifactType))
    end
end

function ArtifactPanel.getArtifactEffectDescription(artifactType, level, player)
    if artifactType == "PRISM" then
        local bonus = player.weapon.prismBonus or 0
        return string.format("Split: +%d projectiles", bonus)
    elseif artifactType == "HALO" then
        local ArtifactManager = require("src.gameplay.ArtifactManager")
        local ColorSystem = require("src.gameplay.ColorSystem")
        local dominantColor = ColorSystem.getDominantColor()
        local haloLevel = ArtifactManager.getLevel("HALO")

        if not dominantColor then
            return string.format("Aura (Lv %d) - needs color", haloLevel)
        end

        local effectNames = {
            RED = "Fire pulse aura",
            GREEN = "Life drain aura",
            BLUE = "Slow aura",
            YELLOW = "Electric pulse heal",
            MAGENTA = "Time bubble",
            CYAN = "Frost drain",
        }
        local effectName = effectNames[dominantColor] or "Aura"
        return string.format("%s (Lv %d)", effectName, haloLevel)
    elseif artifactType == "MIRROR" then
        local reflect = player.mirrorReflection or 0
        return string.format("Reflect: %.0f%% damage", reflect * 100)
    elseif artifactType == "LENS" then
        local bonus = player.weapon.lensBonus or 0
        return string.format("Damage: +%.0f%%", bonus * 100)
    elseif artifactType == "DIFFRACTION" then
        local diffLevel = player.diffractionLevel or 0
        return diffLevel > 0 and string.format("Burst patterns (Lv %d)", diffLevel) or "Burst patterns"
    elseif artifactType == "REFRACTION" then
        local refrLevel = player.refractionLevel or 0
        return refrLevel > 0 and string.format("Path bending (Lv %d)", refrLevel) or "Path bending"
    elseif artifactType == "SUPERNOVA" then
        local novaLevel = player.supernovaLevel or 0
        return novaLevel > 0 and string.format("Ultimate (Lv %d)", novaLevel) or "Ultimate ability"
    end

    return "TODO: effect description pending"
end

return ArtifactPanel
