local ArtifactPanel = {}
local Shared = require("src.ui.Shared")
local Theme = require("src.render.Theme")
local Icons = require("src.render.Icons")

function ArtifactPanel.drawArtifactPanel(player)
    local ArtifactManager = require("src.gameplay.ArtifactManager")
    local artifacts = ArtifactManager.getCollectedArtifacts()
    if #artifacts == 0 then
        return
    end

    local screenWidth, screenHeight = Shared.getScreenSize()
    local tileSize = 64
    local tileGap = 6
    local iconDrawSize = 34
    local panelWidth = 350
    local panelX = screenWidth - panelWidth - 20
    local panelY = 20
    local headerHeight = 40
    local columns = math.max(1, math.floor((panelWidth + tileGap) / (tileSize + tileGap)))
    local rows = math.ceil(#artifacts / columns)
    local gridHeight = rows * tileSize + math.max(0, rows - 1) * tileGap
    local panelHeight = math.min(headerHeight + gridHeight + 12, screenHeight - 40)
    local mouseX, mouseY = love.mouse.getPosition()
    local hoveredArtifact = nil

    Shared.drawGlassPanel(panelX - 10, panelY - 10, panelWidth + 20, panelHeight + 20)

    Theme.setColor("accent")
    love.graphics.print("ðŸ’Ž COLLECTED ARTIFACTS ðŸ’Ž", panelX + 30, panelY, 0, 1.4, 1.4)
    panelY = panelY + headerHeight

    local artifactColors = {
        PRISM = {1, 0.2, 1},
        HALO = {1, 1, 0.3},
        MIRROR = {0.7, 0.9, 1},
        LENS = {0.3, 0.8, 1},
        AURORA = {0.4, 1, 0.8},
        DIFFRACTION = {1, 0.5, 0.2},
        REFRACTION = {0.5, 0.3, 1},
        SUPERNOVA = {1, 0.3, 0.2}
    }

    for i, artifact in ipairs(artifacts) do
        local column = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        local x = panelX + column * (tileSize + tileGap)
        local y = panelY + row * (tileSize + tileGap)
        local color = artifactColors[artifact.type] or {1, 1, 1}
        local artifactIconName = string.lower(artifact.type)
        local isHovered = mouseX >= x and mouseX <= x + tileSize and mouseY >= y and mouseY <= y + tileSize

        if isHovered then
            hoveredArtifact = artifact
        end

        love.graphics.setColor(color[1] * 0.18, color[2] * 0.18, color[3] * 0.18, isHovered and 0.9 or 0.72)
        love.graphics.rectangle("fill", x, y, tileSize, tileSize, 8, 8)

        love.graphics.setColor(color[1], color[2], color[3], isHovered and 1 or 0.82)
        love.graphics.setLineWidth(isHovered and 3 or 2)
        love.graphics.rectangle("line", x, y, tileSize, tileSize, 8, 8)
        love.graphics.setLineWidth(1)

        if artifact.level < artifact.maxLevel then
            local progress = artifact.level / artifact.maxLevel
            love.graphics.setColor(color[1], color[2], color[3], 0.95)
            love.graphics.rectangle("fill", x + 2, y + tileSize - 5, (tileSize - 4) * progress, 3, 2, 2)
        else
            Theme.setColor("warn")
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x + 3, y + 3, tileSize - 6, tileSize - 6, 7, 7)
            love.graphics.setLineWidth(1)
        end

        if Icons.has(artifactIconName) then
            local iconX = x + (tileSize - iconDrawSize) / 2
            local iconY = y + (tileSize - iconDrawSize) / 2
            love.graphics.setColor(color)
            Icons.draw(artifactIconName, iconX, iconY, iconDrawSize)
        end

        love.graphics.setColor(1, 1, 1, 0.92)
        local levelText = string.format("Lv %d", artifact.level)
        local levelWidth = love.graphics.getFont():getWidth(levelText)
        love.graphics.print(levelText, x + tileSize - levelWidth - 6, y + tileSize - 18)

        if artifact.isWIP then
            Theme.setColor("warn")
            love.graphics.print("WIP", x + 6, y + tileSize - 18)
        end
    end

    if hoveredArtifact then
        local tooltipPadding = 10
        local tooltipWidth = 260
        local tooltipX = math.min(mouseX + 14, screenWidth - tooltipWidth - 12)
        local tooltipY = math.min(mouseY + 14, screenHeight - 96)
        local color = artifactColors[hoveredArtifact.type] or {1, 1, 1}
        local effectDesc = ArtifactPanel.getArtifactEffectDescription(hoveredArtifact.type, hoveredArtifact.level, player)
        local detailText = string.format("Lv %d/%d", hoveredArtifact.level, hoveredArtifact.maxLevel)

        Shared.drawGlassPanel(tooltipX, tooltipY, tooltipWidth, 84, { fillAlpha = 0.88, edgeAlpha = 0.45 })
        love.graphics.setColor(color)
        love.graphics.print(hoveredArtifact.name, tooltipX + tooltipPadding, tooltipY + tooltipPadding, 0, 1.15, 1.15)
        Theme.setColor("fg2")
        love.graphics.print(detailText, tooltipX + tooltipPadding, tooltipY + 34)
        Theme.setColor("fg")
        love.graphics.printf(effectDesc, tooltipX + tooltipPadding, tooltipY + 56, tooltipWidth - tooltipPadding * 2)
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
            CYAN = "Frost drain"
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
