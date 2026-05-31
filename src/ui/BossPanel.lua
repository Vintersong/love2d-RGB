local BossPanel = {}
local Shared = require("src.ui.Shared")
local Theme = require("src.render.Theme")

function BossPanel.drawEnemyInfo(enemy)
    local x = enemy.x + enemy.width / 2
    local y = enemy.y - 15

    local hpPercent = enemy.hp / enemy.maxHp
    local color = Theme.color.fg1
    if hpPercent > 0.7 then
        color = Theme.color.ok
    elseif hpPercent > 0.3 then
        color = Theme.color.warn
    else
        color = Theme.color.danger
    end

    love.graphics.setColor(color)
    love.graphics.print(string.format("%d", math.floor(enemy.hp)), x - 10, y, 0, 0.8, 0.8)

    if enemy.dotStacks and #enemy.dotStacks > 0 then
        love.graphics.setColor(Theme.color.cyan)
        love.graphics.print("ðŸ’§", x + 15, y - 5, 0, 0.6, 0.6)
    end

    if enemy.rooted then
        love.graphics.setColor(Theme.color.yellow)
        love.graphics.print("âš¡", x + 25, y - 5, 0, 0.6, 0.6)
    end
end

function BossPanel.drawBossInfo(boss)
    local screenWidth = select(1, Shared.getScreenSize())
    local centerX = screenWidth / 2
    local y = 50

    love.graphics.setColor(Theme.color.red)
    love.graphics.print("âš ï¸  FINAL BOSS  âš ï¸", centerX - 150, y, 0, 2.5, 2.5)

    local hpPercent = boss.hp / boss.maxHp
    Theme.setColor("fg1")
    love.graphics.print(string.format("HP: %d / %d (%.0f%%)", math.floor(boss.hp), boss.maxHp, hpPercent * 100), centerX - 120, y + 45, 0, 1.8, 1.8)
end

return BossPanel
