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

    local AbilitySystem = require("src.combat.AbilitySystem")
    local AbilityLibrary = require("src.data.AbilityLibrary")
    local abilityState = player.abilityState or {
        activeAbility = player.activeAbility,
        cooldown = player.abilityCooldown or 0,
        maxCooldown = player.abilityMaxCooldown or 1
    }

    local iconSize = 64
    local iconGap = 4
    local abilityRowWidth = iconSize * 2 + iconGap
    local rowX = (screenWidth - abilityRowWidth) / 2
    local rowY = screenHeight - iconSize - 24
    local iconGlyphSize = 40

    local function drawAbilitySlot(slotX, slotY, iconName, keyLabel, color, cooldownProgress, cooldownRemaining, isAvailable)
        cooldownProgress = math.max(0, math.min(cooldownProgress or 1, 1))
        cooldownRemaining = cooldownRemaining or 0
        isAvailable = isAvailable ~= false

        Theme.setColor("bgRaised")
        love.graphics.rectangle("fill", slotX, slotY, iconSize, iconSize)

        love.graphics.setColor(1, 1, 1, 0.08)
        love.graphics.rectangle("fill", slotX + 2, slotY + 2, iconSize - 4, iconSize - 4)

        local iconAlpha = (isAvailable and cooldownProgress >= 1) and 1 or 0.38
        love.graphics.setColor(color[1], color[2], color[3], iconAlpha)
        Icons.draw(
            iconName,
            slotX + (iconSize - iconGlyphSize) / 2,
            slotY + (iconSize - iconGlyphSize) / 2,
            iconGlyphSize,
            { width = 2.2 }
        )

        if cooldownProgress < 1 then
            local maskHeight = iconSize * (1 - cooldownProgress)
            love.graphics.setColor(0, 0, 0, 0.55)
            love.graphics.rectangle("fill", slotX, slotY, iconSize, maskHeight)

            Theme.setColor("fg1")
            local cooldownText = string.format("%.1fs", cooldownRemaining)
            local font = love.graphics.getFont()
            love.graphics.print(
                cooldownText,
                slotX + (iconSize - font:getWidth(cooldownText)) / 2,
                slotY + 22
            )
        elseif isAvailable then
            local pulse = math.sin(love.timer.getTime() * 5) * 0.25 + 0.55
            love.graphics.setColor(color[1], color[2], color[3], pulse)
            love.graphics.rectangle("line", slotX + 2, slotY + 2, iconSize - 4, iconSize - 4)
        else
            love.graphics.setColor(0, 0, 0, 0.62)
            love.graphics.rectangle("fill", slotX, slotY, iconSize, iconSize)
        end

        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", slotX, slotY + iconSize - 16, iconSize, 16)

        Theme.setColor("fg1")
        local font = love.graphics.getFont()
        love.graphics.print(keyLabel, slotX + (iconSize - font:getWidth(keyLabel)) / 2, slotY + iconSize - 14)

        love.graphics.setColor(color[1], color[2], color[3], isAvailable and 0.95 or 0.35)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", slotX, slotY, iconSize, iconSize)
    end

    local dashCdPercent = AbilitySystem.getCooldownProgress(player, "DASH", AbilityLibrary.DASH)
    local dashState = AbilitySystem.getState(player, "DASH")
    local dashCooldown = dashState and dashState.cooldown or 0

    drawAbilitySlot(rowX, rowY, "dash", "SPACE", Theme.color.accent, dashCdPercent, dashCooldown, true)

    local supernovaProgress = 1
    if abilityState.maxCooldown and abilityState.maxCooldown > 0 then
        supernovaProgress = 1 - ((abilityState.cooldown or 0) / abilityState.maxCooldown)
    end

    drawAbilitySlot(
        rowX + iconSize + iconGap,
        rowY,
        "supernova",
        "SHIFT",
        Theme.color.magenta,
        supernovaProgress,
        abilityState.cooldown or 0,
        abilityState.activeAbility ~= nil
    )

    Theme.setColor("fg3")
    local activeText = player.activeAbility and " | L-SHIFT: Supernova" or ""
    love.graphics.print("WASD: Move | SPACE: Dash | P/ESC: Pause" .. activeText, x, screenHeight - 40, 0, 1.2, 1.2)

    ArtifactPanel.drawArtifactPanel(player)
end

return HudPanel
