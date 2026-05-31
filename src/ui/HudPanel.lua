local HudPanel = {}
local ColorSystem = require("src.gameplay.ColorSystem")
local Shared = require("src.ui.Shared")
local ArtifactPanel = require("src.ui.ArtifactPanel")
local Theme = require("src.render.Theme")
local Icons = require("src.render.Icons")

function HudPanel.getAffinityText()
    local parts = {}

    for _, color in ipairs({"RED", "GREEN", "BLUE"}) do
        local level = ColorSystem.primary[color].level
        if level > 0 then
            local text = color
            if level > 1 then
                text = text .. " x" .. level
            end
            table.insert(parts, text)
        end
    end

    for _, color in ipairs({"YELLOW", "MAGENTA", "CYAN"}) do
        local data = ColorSystem.secondary[color]
        if data.unlocked and data.level > 0 then
            local text = color
            if data.level > 1 then
                text = text .. " x" .. data.level
            end
            table.insert(parts, text)
        end
    end

    if #parts == 0 then
        return "None"
    end

    return table.concat(parts, " + ")
end

function HudPanel.drawPlayerHUD(player)
    local screenWidth, screenHeight = Shared.getScreenSize()
    local x, y = 20, 20
    local lineHeight = 35

    Theme.setColor("fg1")
    love.graphics.print(string.format("Level: %d", player.level), x, y, 0, 1.5, 1.5)
    y = y + lineHeight

    local hpPercent = player.hp / player.maxHp
    local hpColor = Theme.color.fg1
    if hpPercent > 0.5 then
        hpColor = Theme.color.ok
    elseif hpPercent > 0.25 then
        hpColor = Theme.color.warn
    else
        hpColor = Theme.color.danger
    end

    love.graphics.setColor(hpColor)
    love.graphics.print(string.format("Health: %d / %d (%.0f%%)", math.floor(player.hp), player.maxHp, hpPercent * 100), x, y, 0, 1.5, 1.5)
    y = y + lineHeight

    Theme.setColor("accent")
    local xpPercent = player.exp / player.expToNext
    love.graphics.print(string.format("XP: %d / %d (%.0f%%)", player.exp, player.expToNext, xpPercent * 100), x, y, 0, 1.5, 1.5)
    y = y + lineHeight

    love.graphics.setColor(1, 0.8, 0.2)
    love.graphics.print("Color Affinity: " .. HudPanel.getAffinityText(), x, y, 0, 1.5, 1.5)
    y = y + lineHeight

    if player.weapon then
        Theme.setColor("fg2")
        love.graphics.print(string.format("Damage: %.0f | Fire Rate: %.2fs", player.weapon.damage, player.weapon.fireRate), x, y, 0, 1.2, 1.2)
        y = y + 25

        local projCount = 1
        if player.weapon.guaranteedBullets then
            projCount = projCount + player.weapon.guaranteedBullets
        end
        Theme.setColor("fg2")
        love.graphics.print(string.format("Projectiles: %d guaranteed", projCount), x, y, 0, 1.1, 1.1)
    end
    y = y + 5

    local SynergySystem = require("src.gameplay.SynergySystem")
    local ArtifactManager = require("src.gameplay.ArtifactManager")
    local synergyCount = SynergySystem.getCount()
    local artifactCount = ArtifactManager.getCount()

    if artifactCount > 0 then
        Theme.setColor("accent")
        love.graphics.print(string.format("ðŸ’Ž Artifacts: %d", artifactCount), x, y, 0, 1.2, 1.2)
        y = y + 25
    end

    if synergyCount > 0 then
        love.graphics.setColor(Theme.color.magenta)
        love.graphics.print(string.format("âš¡ Synergies: %d", synergyCount), x, y, 0, 1.2, 1.2)
    end

    local dashY = screenHeight - 100
    local barWidth = 250
    local barHeight = 25
    local dashX = (screenWidth / 2) - (barWidth / 2)

    Shared.drawGlassPanel(dashX - 10, dashY - 10, barWidth + 20, 75)

    Theme.setColor("accent")
    local titleText = "DASH [SPACE]"
    local font = love.graphics.getFont()
    local titleWidth = font:getWidth(titleText) * 1.5
    local titleX = dashX + (barWidth - titleWidth) / 2
    Icons.draw("dash", titleX - 30, dashY - 6, 24)
    love.graphics.print(titleText, titleX, dashY - 5, 0, 1.5, 1.5)

    local AbilitySystem = require("src.combat.AbilitySystem")
    local AbilityLibrary = require("src.data.AbilityLibrary")
    local dashCdPercent = AbilitySystem.getCooldownProgress(player, "DASH", AbilityLibrary.DASH)
    local dashState = AbilitySystem.getState(player, "DASH")
    local dashCooldown = dashState and dashState.cooldown or 0

    Theme.setColor("bgRaised")
    love.graphics.rectangle("fill", dashX, dashY + 30, barWidth, barHeight)

    if dashCdPercent >= 1 then
        local pulse = math.sin(love.timer.getTime() * 5) * 0.3 + 0.7
        local c = Theme.color.ok
        love.graphics.setColor(c[1] * pulse, c[2] * pulse, c[3] * pulse)
        love.graphics.rectangle("fill", dashX, dashY + 30, barWidth, barHeight)
        Theme.setColor("ok")
        love.graphics.print("READY", dashX + (barWidth / 2) - 30, dashY + 32, 0, 1.3, 1.3)
    else
        Theme.setColor("accent")
        love.graphics.rectangle("fill", dashX, dashY + 30, barWidth * dashCdPercent, barHeight)
        Theme.setColor("fg1")
        love.graphics.print(string.format("%.1fs", dashCooldown), dashX + (barWidth / 2) - 20, dashY + 32, 0, 1.3, 1.3)
    end

    Theme.setColor("accent")
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", dashX, dashY + 30, barWidth, barHeight)

    local abilityState = player.abilityState or {
        activeAbility = player.activeAbility,
        cooldown = player.abilityCooldown or 0,
        maxCooldown = player.abilityMaxCooldown or 1
    }

    if abilityState.activeAbility then
        local abilityY = screenHeight - 200
        Shared.drawGlassPanel(x - 5, abilityY - 5, 220, 70)

        love.graphics.setColor(Theme.color.magenta)
        Icons.draw("supernova", x, abilityY - 1, 22)
        love.graphics.print(string.format("%s [L-SHIFT]", abilityState.activeAbility), x + 28, abilityY, 0, 1.3, 1.3)

        local cdPercent = 1
        if abilityState.maxCooldown and abilityState.maxCooldown > 0 then
            cdPercent = 1 - (abilityState.cooldown / abilityState.maxCooldown)
        end

        Theme.setColor("bgRaised")
        love.graphics.rectangle("fill", x, abilityY + 25, barWidth, barHeight)

        if cdPercent >= 1 then
            local pulse = math.sin(love.timer.getTime() * 5) * 0.3 + 0.7
            local c = Theme.color.magenta
            love.graphics.setColor(c[1] * pulse, c[2] * pulse, c[3] * pulse)
            love.graphics.rectangle("fill", x, abilityY + 25, barWidth, barHeight)
            love.graphics.setColor(Theme.color.magenta)
            love.graphics.print("READY", x + 75, abilityY + 27, 0, 1.2, 1.2)
        else
            love.graphics.setColor(Theme.color.magenta)
            love.graphics.rectangle("fill", x, abilityY + 25, barWidth * cdPercent, barHeight)
            Theme.setColor("fg1")
            love.graphics.print(string.format("%.1fs", abilityState.cooldown), x + 75, abilityY + 27, 0, 1.2, 1.2)
        end

        love.graphics.setColor(Theme.color.magenta)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, abilityY + 25, barWidth, barHeight)
    end

    Theme.setColor("fg3")
    local activeText = player.activeAbility and " | L-SHIFT: Supernova" or ""
    love.graphics.print("WASD: Move | SPACE: Dash | P/ESC: Pause" .. activeText, x, screenHeight - 40, 0, 1.2, 1.2)

    ArtifactPanel.drawArtifactPanel(player)
end

return HudPanel
