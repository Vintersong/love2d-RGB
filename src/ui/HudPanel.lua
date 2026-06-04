local HudPanel = {}

local ColorSystem = require("src.gameplay.ColorSystem")
local Shared = require("src.ui.Shared")
local ArtifactPanel = require("src.ui.ArtifactPanel")
local Theme = require("src.render.Theme")
local SimpleGrid = require("src.gameplay.SimpleGrid")

local function drawPanelLabel(x, y, label, value, width, accent)
    local panelHeight = 54
    Shared.drawGlassPanel(x, y, width, panelHeight, {fillAlpha = 0.52, edgeAlpha = 0.14, lineWidth = 1})

    if accent then
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.95)
        love.graphics.rectangle("fill", x + 4, y + 4, 4, panelHeight - 8)
    end

    love.graphics.setFont(Theme.font("mono", 14))
    love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], 1)
    love.graphics.print(label, x + 14, y + 8)

    love.graphics.setFont(Theme.font("uiSemiBold", 20))
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.print(value, x + 14, y + 24)
end

local function drawStatPill(x, y, w, h, label, value, accent)
    Shared.drawGlassPanel(x, y, w, h, {fillAlpha = 0.5, edgeAlpha = 0.1, lineWidth = 1})

    if accent then
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.95)
        love.graphics.rectangle("fill", x + 4, y + 4, 4, h - 8)
    end

    love.graphics.setFont(Theme.font("mono", 12))
    love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], 1)
    love.graphics.print(label, x + 14, y + 6)

    love.graphics.setFont(Theme.font("uiSemiBold", 16))
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.print(value, x + 14, y + 21)
end

function HudPanel.drawPlayerHUD(player)
    local bandHeight = (SimpleGrid.cellSize or 48) * 2

    local leftX = 20
    local leftY = bandHeight + 20
    local leftW = 500
    local panelH = 150

    Shared.drawGlassPanel(leftX, leftY, leftW, panelH, {fillAlpha = 0.62, edgeAlpha = 0.18, lineWidth = 1})

    drawPanelLabel(leftX + 14, leftY + 14, "LEVEL", tostring(player.level or 0), 108, Theme.color.accent)

    local weapon = player.weapon
    local statY = leftY + 82
    local statW = math.floor(((leftW - 28) - 16) / 3)
    if weapon then
        drawStatPill(
            leftX + 14,
            statY,
            statW,
            48,
            "DMG",
            string.format("%.0f", weapon.damage or 0),
            Theme.color.red
        )
        drawStatPill(
            leftX + 14 + statW + 8,
            statY,
            statW,
            48,
            "FIRE",
            string.format("%.2fs", weapon.fireRate or 0),
            Theme.color.cyan
        )
        drawStatPill(
            leftX + 14 + (statW + 8) * 2,
            statY,
            statW,
            48,
            "SHOTS",
            tostring(weapon.bulletCount or 1),
            Theme.color.yellow
        )
    end

    ArtifactPanel.drawArtifactPanel(player)
end

return HudPanel
