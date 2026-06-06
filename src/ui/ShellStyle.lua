-- src/ui/ShellStyle.lua
-- Shared shell styling for menu-adjacent reference screens.

local Config = require("src.Config")
local GameConfig = require("src.core.GameConfig")
local Theme = require("src.render.Theme")

local ShellStyle = {}

local shaderCache = nil
local shaderFailed = false

function ShellStyle.loadShader(label)
    if shaderCache or shaderFailed then
        return shaderCache
    end

    local ok, result = pcall(love.graphics.newShader, "assets/shaders/splashscreen.glsl")
    if ok then
        shaderCache = result
        print(string.format("[%s] Background shader loaded successfully", label or "ShellStyle"))
    else
        shaderFailed = true
        print(string.format("[%s] Failed to load background shader: %s", label or "ShellStyle", tostring(result)))
    end

    return shaderCache
end

function ShellStyle.updateMusic(dt)
    local musicReactor = GameConfig.getMusicReactor()
    if musicReactor then
        musicReactor:update(dt)
    end
end

local function getMusicIntensity()
    local musicReactor = GameConfig.getMusicReactor()
    return musicReactor and musicReactor:getOverallIntensity() or 0
end

function ShellStyle.drawBackground(alpha, shader, opts)
    opts = opts or {}
    alpha = alpha or 1

    local sw, sh = Config.screen.width, Config.screen.height
    local void = Theme.color.bgVoid
    love.graphics.clear(void[1], void[2], void[3], 1)

    if shader then
        local previousShader = love.graphics.getShader()
        pcall(function()
            shader:send("resolution", {sw, sh})
            shader:send("time", love.timer.getTime())
            shader:send("intensity", getMusicIntensity())
            shader:send("bloomEnabled", 0.0)
        end)

        love.graphics.setShader(shader)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
        love.graphics.setShader(previousShader)
    end

    local numBars = opts.numBars or 32
    local barWidth = opts.barWidth or 56
    local barGap = opts.barGap or 4
    local startX = opts.startX or 2
    local segmentHeight = opts.segmentHeight or 12
    local segmentGap = opts.segmentGap or 3
    local numSegments = opts.numSegments or 72
    local time = love.timer.getTime()
    local musicReactor = GameConfig.getMusicReactor()
    local colStart = opts.colStart
    local colEnd = opts.colEnd
    local glowY = opts.glowY
    local glowHeight = opts.glowHeight or 44

    for i = 1, numBars do
        local barX = startX + (i - 1) * (barWidth + barGap)
        local barOffset = (i - 1) * 0.12
        local r = 0.5 + 0.5 * math.sin(time * 2 + barOffset)
        local g = 0.5 + 0.5 * math.sin(time * 2 + 2.09 + barOffset)
        local b = 0.5 + 0.5 * math.sin(time * 2 + 4.18 + barOffset)
        local barIntensity = musicReactor and (musicReactor:getBandIntensity(i) or 0.1) or 0.1
        local columnActive = colStart and colEnd and i >= colStart and i <= colEnd

        for j = 1, numSegments do
            local segmentY = sh - (j * (segmentHeight + segmentGap))
            local rowActive = glowY and segmentY >= glowY - 2 and segmentY + segmentHeight <= glowY + glowHeight + 2
            local finalAlpha = alpha * (opts.idleAlpha or 0.04)
            if columnActive and rowActive then
                finalAlpha = alpha * math.min(opts.activeMaxAlpha or 1, (opts.activeBaseAlpha or 0.12) + (opts.activeAudioAlpha or 0.14) * barIntensity)
            end

            love.graphics.setColor(r, g, b, finalAlpha)
            love.graphics.rectangle("fill", barX, segmentY, barWidth, segmentHeight, 2, 2)
        end
    end

    local bandHeight = (segmentHeight + segmentGap) * 2
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, sw, bandHeight)
    love.graphics.rectangle("fill", 0, sh - bandHeight, sw, bandHeight)
end

function ShellStyle.measureSpacedText(text, font, charGap)
    local total = 0
    local widths = {}
    for i = 1, #text do
        local char = text:sub(i, i)
        widths[i] = font:getWidth(char)
        total = total + widths[i]
    end
    total = total + math.max(0, #text - 1) * (charGap or 10)
    return total, widths
end

function ShellStyle.drawRgbTitle(text, x, y, font, alpha, charGap)
    charGap = charGap or 10
    local _, widths = ShellStyle.measureSpacedText(text, font, charGap)
    local time = love.timer.getTime()
    local currentX = x

    love.graphics.setFont(font)
    for i = 1, #text do
        local char = text:sub(i, i)
        local charOffset = (i - 1) * 0.4
        local r = 0.5 + 0.5 * math.sin(time * 2 + charOffset)
        local g = 0.5 + 0.5 * math.sin(time * 2 + 2.09 + charOffset)
        local b = 0.5 + 0.5 * math.sin(time * 2 + 4.18 + charOffset)
        love.graphics.setColor(r, g, b, alpha or 1)
        love.graphics.print(char, currentX, y)
        currentX = currentX + widths[i] + charGap
    end
end

function ShellStyle.drawPanel(x, y, w, h, alpha, accentColor)
    accentColor = accentColor or Theme.color.accent
    love.graphics.setColor(0.01, 0.01, 0.015, (alpha or 1) * 0.82)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], (alpha or 1) * 0.28)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)
end

function ShellStyle.drawBracketButton(label, x, y, w, h, selected, alpha, font, muted)
    alpha = alpha or 1
    font = font or Theme.font("ui", Theme.scale.ui)

    love.graphics.setColor(0, 0, 0, alpha * 0.5)
    love.graphics.rectangle("fill", x, y, w, h)

    love.graphics.setLineWidth(1.5)
    if selected then
        local c = muted and Theme.color.fg3 or Theme.color.accent
        love.graphics.setColor(c[1], c[2], c[3], alpha)
    else
        love.graphics.setColor(1, 1, 1, alpha * 0.12)
    end

    love.graphics.line(x + 12, y, x, y, x, y + 12)
    love.graphics.line(x + 12, y + h, x, y + h, x, y + h - 12)
    love.graphics.line(x + w - 12, y, x + w, y, x + w, y + 12)
    love.graphics.line(x + w - 12, y + h, x + w, y + h, x + w, y + h - 12)

    love.graphics.setFont(font)
    local color = selected and Theme.color.fg1 or Theme.color.fg3
    love.graphics.setColor(color[1], color[2], color[3], selected and alpha or alpha * 0.72)
    love.graphics.print(label, x + w / 2 - font:getWidth(label) / 2, y + h / 2 - font:getHeight() / 2)
end

function ShellStyle.layoutActionRow(buttons, centerX, y, opts)
    opts = opts or {}
    local buttonW = opts.buttonW or 296
    local buttonH = opts.buttonH or 44
    local gap = opts.gap or 18
    local count = #buttons
    local totalW = count * buttonW + math.max(0, count - 1) * gap
    local startX = centerX - totalW / 2
    local rects = {}

    for i, button in ipairs(buttons) do
        rects[i] = {
            x = startX + (i - 1) * (buttonW + gap),
            y = y,
            w = buttonW,
            h = buttonH,
            action = button.action,
        }
    end

    return rects
end

function ShellStyle.layoutVerticalRail(buttons, x, y, opts)
    opts = opts or {}
    local buttonW = opts.buttonW or 296
    local buttonH = opts.buttonH or 44
    local gap = opts.gap or 16
    local rects = {}

    for i, button in ipairs(buttons) do
        rects[i] = {
            x = x,
            y = y + (i - 1) * (buttonH + gap),
            w = buttonW,
            h = buttonH,
            action = button.action,
            tabIndex = button.tabIndex,
        }
    end

    return rects
end

function ShellStyle.drawActionRow(buttons, rects, selectedIndex, alpha, font)
    font = font or Theme.font("uiSemiBold", 18)
    for i, button in ipairs(buttons) do
        local rect = rects[i]
        if rect then
            ShellStyle.drawBracketButton(button.label, rect.x, rect.y, rect.w, rect.h, selectedIndex == i, alpha, font)
        end
    end
end

function ShellStyle.drawVerticalRail(buttons, rects, selectedIndex, alpha, font)
    font = font or Theme.font("uiSemiBold", 18)
    for i, button in ipairs(buttons) do
        local rect = rects[i]
        if rect then
            ShellStyle.drawBracketButton(button.label, rect.x, rect.y, rect.w, rect.h, selectedIndex == i, alpha, font)
        end
    end
end

function ShellStyle.drawFooter(text, y, alpha)
    local sw, sh = Config.screen.width, Config.screen.height
    love.graphics.setFont(Theme.font("ui", 16))
    Theme.setColor("fg3", (alpha or 1) * 0.9)
    love.graphics.printf(text, 0, y or sh - 82, sw, "center")
end

return ShellStyle
