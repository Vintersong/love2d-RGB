local BossPanel = {}

local Shared = require("src.ui.Shared")
local Theme = require("src.render.Theme")
local Icons = require("src.render.Icons")
local SimpleGrid = require("src.gameplay.SimpleGrid")

local function clamp01(value)
    return math.max(0, math.min(1, value or 0))
end

local function prettifyBossName(boss)
    local raw = boss and (boss.displayName or boss.archetypeName or boss.name or boss.type) or "boss"
    raw = tostring(raw):gsub("_", " ")
    return (raw:gsub("(%a)([%w']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end))
end

local function ellipsize(text, maxWidth, font)
    text = tostring(text or "")
    font = font or love.graphics.getFont()
    if font:getWidth(text) <= maxWidth then
        return text
    end

    local suffix = "..."
    while #text > 0 and font:getWidth(text .. suffix) > maxWidth do
        text = text:sub(1, -2)
    end
    return text .. suffix
end

local function getHealthField(boss)
    if not boss then
        return 0, 1
    end

    local health = boss.health or boss.hp or 0
    local maxHealth = boss.maxHealth or boss.maxHp or 1
    return health, maxHealth
end

local function drawHealthBar(boss)
    local screenWidth = select(1, Shared.getScreenSize())
    local cellSize = SimpleGrid.cellSize or 48
    local topBandHeight = cellSize * 2
    local panelW = 760
    local panelH = math.floor(cellSize * 0.64)
    local panelX = screenWidth / 2 - panelW / 2
    local panelY = topBandHeight + math.floor(cellSize * 0.35)

    local health, maxHealth = getHealthField(boss)
    local percent = clamp01(health / maxHealth)
    local title = prettifyBossName(boss)

    Shared.drawGlassPanel(panelX, panelY, panelW, panelH, {fillAlpha = 0.6, edgeAlpha = 0.18, lineWidth = 1})

    if Icons.has("boss") then
        love.graphics.setColor(1, 1, 1, 1)
        Icons.draw("boss", panelX + 14, panelY + 6, 22)
    end

    love.graphics.setFont(Theme.font("mono", 10))
    love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], 1)
    local levelText = string.format("BOSS %02d", (boss and boss.encounterIndex) or 1)
    love.graphics.print(levelText, panelX + 42, panelY + 4)

    love.graphics.setFont(Theme.font("uiBold", 18))
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.print(ellipsize(title, 132, love.graphics.getFont()), panelX + 42, panelY + 15)

    local barX = panelX + 182
    local barY = panelY + 10
    local barW = panelW - 250
    local barH = 12

    love.graphics.setColor(Theme.color.bgRaised[1], Theme.color.bgRaised[2], Theme.color.bgRaised[3], 1)
    love.graphics.rectangle("fill", barX, barY, barW, barH)

    local fill = {
        Theme.color.ok[1] * (0.4 + 0.6 * percent) + Theme.color.danger[1] * (1 - percent),
        Theme.color.ok[2] * (0.4 + 0.6 * percent) + Theme.color.danger[2] * (1 - percent),
        Theme.color.ok[3] * (0.4 + 0.6 * percent) + Theme.color.danger[3] * (1 - percent),
    }
    love.graphics.setColor(fill[1], fill[2], fill[3], 0.95)
    love.graphics.rectangle("fill", barX, barY, barW * percent, barH)

    love.graphics.setColor(Theme.color.accent[1], Theme.color.accent[2], Theme.color.accent[3], 0.65)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX, barY, barW, barH)

    -- Ring boss: split the bar into the four phase segments (each = a quarter of HP) and
    -- outline the active phase. HP empties right->left, so segments L->R are P4|P3|P2|P1.
    if boss and boss.ringPhase then
        for s = 1, 3 do
            local dx = barX + barW * (s * 0.25)
            love.graphics.setColor(0, 0, 0, 0.65)
            love.graphics.setLineWidth(2)
            love.graphics.line(dx, barY, dx, barY + barH)
        end

        local phase = math.max(1, math.min(4, boss.ringPhase))
        local segX = barX + barW * ((4 - phase) * 0.25)
        local segW = barW * 0.25
        love.graphics.setColor(Theme.color.accent[1], Theme.color.accent[2], Theme.color.accent[3], 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", segX, barY - 2, segW, barH + 4)

        love.graphics.setFont(Theme.font("mono", 10))
        love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
        love.graphics.print(string.format("PHASE %d/4", phase), barX, barY - 14)
    end

    local hpText = string.format("%d / %d", math.floor(health), math.floor(maxHealth))
    love.graphics.setFont(Theme.font("mono", 11))
    local hpTextWidth = love.graphics.getFont():getWidth(hpText)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(hpText, panelX + panelW - hpTextWidth - 14, panelY + 11)
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.print(hpText, panelX + panelW - hpTextWidth - 15, panelY + 10)
end

function BossPanel.drawEnemyInfo(enemy)
    local x = enemy.x + enemy.width / 2
    local y = enemy.y - 15

    if enemy.dotStacks and #enemy.dotStacks > 0 then
        love.graphics.setColor(Theme.color.cyan)
        love.graphics.print("dot", x + 15, y - 5, 0, 0.6, 0.6)
    end

    if enemy.rooted then
        love.graphics.setColor(Theme.color.yellow)
        love.graphics.print("root", x + 25, y - 5, 0, 0.6, 0.6)
    end
end

function BossPanel.drawBossInfo(boss)
    drawHealthBar(boss)
end

return BossPanel
