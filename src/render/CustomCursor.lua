-- CustomCursor.lua
-- Builds and applies a circular crosshair cursor with a subtle glow.

local CustomCursor = {}
local moonshine = require("libs.moonshine-master")
local Runtime = require("src.core.Runtime")

CustomCursor.enabled = true
CustomCursor.cursor = nil
CustomCursor.canvasSize = 64

local function drawCrosshairShape(cx, cy)
    love.graphics.setLineWidth(2)

    -- Outer ring
    love.graphics.setColor(0.0, 0.85, 1.0, 0.95)
    love.graphics.circle("line", cx, cy, 10)

    -- Cross lines
    love.graphics.line(cx - 16, cy, cx - 5, cy)
    love.graphics.line(cx + 5, cy, cx + 16, cy)
    love.graphics.line(cx, cy - 16, cx, cy - 5)
    love.graphics.line(cx, cy + 5, cx, cy + 16)

    -- Center dot
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", cx, cy, 2)
end

function CustomCursor.init()
    if not love.mouse or not love.graphics then
        return false
    end

    if Runtime.isWeb() then
        local sysOk, systemCursor = pcall(love.mouse.getSystemCursor, "crosshair")
        love.mouse.setVisible(true)
        if sysOk and systemCursor then
            love.mouse.setCursor(systemCursor)
            return true
        end
        love.mouse.setCursor()
        return true
    end

    local baseCanvas = love.graphics.newCanvas(CustomCursor.canvasSize, CustomCursor.canvasSize)
    local glowCanvas = love.graphics.newCanvas(CustomCursor.canvasSize, CustomCursor.canvasSize)
    local half = CustomCursor.canvasSize / 2

    -- Draw base crosshair shape.
    love.graphics.push("all")
    love.graphics.setCanvas(baseCanvas)
    love.graphics.clear(0, 0, 0, 0)
    drawCrosshairShape(half, half)

    -- Build glow using moonshine if available.
    local effect = moonshine(CustomCursor.canvasSize, CustomCursor.canvasSize, moonshine.effects.glow)
    effect.glow.strength = 4.0
    effect.glow.min_luma = 0.08

    love.graphics.setCanvas(glowCanvas)
    love.graphics.clear(0, 0, 0, 0)
    local glowOk = pcall(function()
        effect(function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(baseCanvas, 0, 0)
        end)
    end)
    love.graphics.setCanvas()
    love.graphics.pop()

    local sourceCanvas = glowOk and glowCanvas or baseCanvas
    local imageData = sourceCanvas:newImageData()
    local cursorOk, cursorOrErr = pcall(love.mouse.newCursor, imageData, half, half)

    if cursorOk and cursorOrErr then
        CustomCursor.cursor = cursorOrErr
        love.mouse.setVisible(true)
        love.mouse.setCursor(CustomCursor.cursor)
        return true
    end

    print("[CustomCursor] newCursor failed, falling back to system crosshair: " .. tostring(cursorOrErr))
    local sysOk, systemCursor = pcall(love.mouse.getSystemCursor, "crosshair")
    if sysOk and systemCursor then
        love.mouse.setVisible(true)
        love.mouse.setCursor(systemCursor)
        return true
    end

    love.mouse.setVisible(true)
    return false
end

-- Retained for API compatibility with previous software-drawn cursor flow.
function CustomCursor.draw()
    -- no-op
end

function CustomCursor.resetToDefault()
    if love.mouse and love.mouse.setCursor then
        love.mouse.setCursor()
    end
end

return CustomCursor
