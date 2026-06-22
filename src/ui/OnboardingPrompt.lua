-- OnboardingPrompt.lua
-- Renders a single phase-0 onboarding prompt card (keycap + ability + why line)
-- near the bottom of the playfield. Pure draw; reads no global state.

local Config = require("src.Config")
local Theme = require("src.render.Theme")

local OnboardingPrompt = {}

function OnboardingPrompt.draw(prompt)
    if not prompt then return end

    local sw, sh = Config.screen.width, Config.screen.height
    local panelW, panelH = 760, 150
    local x = (sw - panelW) / 2
    local y = sh - panelH - 90
    local ac = Theme.color.accent

    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", x, y, panelW, panelH, 10, 10)
    love.graphics.setColor(ac[1], ac[2], ac[3], 0.55)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, panelW, panelH, 10, 10)

    local textX = x + 40

    -- Keycap box (omitted for the passive AUTO-FIRE beat, which has no key).
    if prompt.key then
        local capFont = Theme.font("mono", 30)
        local capW = math.max(72, capFont:getWidth(prompt.key) + 28)
        local capH = 58
        local capX, capY = x + 30, y + (panelH - capH) / 2
        love.graphics.setColor(ac[1], ac[2], ac[3], 0.18)
        love.graphics.rectangle("fill", capX, capY, capW, capH, 8, 8)
        love.graphics.setColor(ac[1], ac[2], ac[3], 0.9)
        love.graphics.rectangle("line", capX, capY, capW, capH, 8, 8)
        love.graphics.setFont(capFont)
        love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
        love.graphics.printf(prompt.key, capX, capY + (capH - capFont:getHeight()) / 2, capW, "center")
        textX = capX + capW + 30
    end

    love.graphics.setFont(Theme.font("uiBold", 26))
    love.graphics.setColor(ac[1], ac[2], ac[3], 1)
    love.graphics.print(prompt.name, textX, y + 28)

    love.graphics.setFont(Theme.font("ui", 18))
    love.graphics.setColor(Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], 1)
    love.graphics.printf(prompt.line, textX, y + 66, x + panelW - textX - 30, "left")

    love.graphics.setFont(Theme.font("mono", 14))
    love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], 1)
    love.graphics.print(prompt.skipHint, x + 20, y + panelH - 26)
    love.graphics.printf(string.format("STEP %d / %d", prompt.index, prompt.total), x, y + panelH - 26, panelW - 20, "right")

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return OnboardingPrompt
