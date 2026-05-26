local ArtifactPanel = {}
local Shared = require("src.ui.Shared")

function ArtifactPanel.drawArtifactPanel(player)
    local ArtifactManager = require("src.gameplay.ArtifactManager")
    local artifacts = ArtifactManager.getCollectedArtifacts()
    if #artifacts == 0 then
        return
    end

    local screenWidth, screenHeight = Shared.getScreenSize()
    local panelWidth = 350
    local panelX = screenWidth - panelWidth - 20
    local panelY = 20
    local lineHeight = 28

    love.graphics.setColor(0, 0, 0, 0.7)
    local panelHeight = math.min(60 + (#artifacts * lineHeight * 3), screenHeight - 40)
    love.graphics.rectangle("fill", panelX - 10, panelY - 10, panelWidth + 20, panelHeight + 20)

    love.graphics.setColor(0.5, 1, 1, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX - 10, panelY - 10, panelWidth + 20, panelHeight + 20)

    love.graphics.setColor(0.5, 1, 1)
    love.graphics.print("ðŸ’Ž COLLECTED ARTIFACTS ðŸ’Ž", panelX + 30, panelY, 0, 1.4, 1.4)
    panelY = panelY + 40

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
        local y = panelY + ((i - 1) * lineHeight * 3)
        local color = artifactColors[artifact.type] or {1, 1, 1}

        love.graphics.setColor(color)
        local artifactText = string.format("%s [Lv %d/%d]", artifact.name, artifact.level, artifact.maxLevel)
        love.graphics.print(artifactText, panelX, y, 0, 1.3, 1.3)

        -- TODO(ui): Keep [WIP] badge until all artifact descriptions are finalized.
        if artifact.isWIP then
            love.graphics.setColor(1, 1, 0)
            local textWidth = love.graphics.getFont():getWidth(artifactText) * 1.3
            love.graphics.print("[WIP]", panelX + textWidth + 10, y, 0, 1.3, 1.3)
        end

        local effectDesc = ArtifactPanel.getArtifactEffectDescription(artifact.type, artifact.level, player)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print(effectDesc, panelX + 10, y + lineHeight, 0, 1.0, 1.0)

        if artifact.level < artifact.maxLevel then
            local barWidth = panelWidth - 20
            local barHeight = 8
            local barY = y + lineHeight * 2 + 5

            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
            love.graphics.rectangle("fill", panelX, barY, barWidth, barHeight)

            local progress = artifact.level / artifact.maxLevel
            love.graphics.setColor(color[1] * 0.8, color[2] * 0.8, color[3] * 0.8)
            love.graphics.rectangle("fill", panelX, barY, barWidth * progress, barHeight)

            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", panelX, barY, barWidth, barHeight)
        else
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("MAX LEVEL", panelX + 120, y + lineHeight * 2 + 3, 0, 1.1, 1.1)
        end
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
