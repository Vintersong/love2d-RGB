local Config = require("src.Config")

local Viewport = {}

Viewport.logicalWidth = Config.screen.width
Viewport.logicalHeight = Config.screen.height
Viewport.windowWidth = Config.screen.width
Viewport.windowHeight = Config.screen.height
Viewport.scale = 1
Viewport.offsetX = 0
Viewport.offsetY = 0
Viewport.canvas = nil

local function round(value)
    return math.floor(value + 0.5)
end

local function refreshLayout(windowWidth, windowHeight)
    Viewport.windowWidth = windowWidth or love.graphics.getWidth()
    Viewport.windowHeight = windowHeight or love.graphics.getHeight()

    local scaleX = Viewport.windowWidth / Viewport.logicalWidth
    local scaleY = Viewport.windowHeight / Viewport.logicalHeight
    Viewport.scale = math.min(scaleX, scaleY)
    Viewport.offsetX = round((Viewport.windowWidth - Viewport.logicalWidth * Viewport.scale) * 0.5)
    Viewport.offsetY = round((Viewport.windowHeight - Viewport.logicalHeight * Viewport.scale) * 0.5)
end

function Viewport.init(logicalWidth, logicalHeight)
    Viewport.logicalWidth = logicalWidth or Config.screen.width
    Viewport.logicalHeight = logicalHeight or Config.screen.height

    local ok, canvasOrErr = pcall(
        love.graphics.newCanvas,
        Viewport.logicalWidth,
        Viewport.logicalHeight,
        {stencil = true}
    )
    if ok then
        Viewport.canvas = canvasOrErr
        Viewport.canvas:setFilter("linear", "linear")
    else
        Viewport.canvas = nil
        print("[Viewport] Failed to create canvas, falling back to direct render: " .. tostring(canvasOrErr))
    end

    refreshLayout(love.graphics.getDimensions())

    print(string.format(
        "[Viewport] Logical %dx%d -> window %dx%d (scale %.3f, offset %d,%d)",
        Viewport.logicalWidth,
        Viewport.logicalHeight,
        Viewport.windowWidth,
        Viewport.windowHeight,
        Viewport.scale,
        Viewport.offsetX,
        Viewport.offsetY
    ))
end

function Viewport.resize(windowWidth, windowHeight)
    refreshLayout(windowWidth, windowHeight)
end

function Viewport.beginFrame()
    if not Viewport.canvas then
        return
    end

    local currentWidth, currentHeight = love.graphics.getDimensions()
    if currentWidth ~= Viewport.windowWidth or currentHeight ~= Viewport.windowHeight then
        refreshLayout(currentWidth, currentHeight)
    end

    love.graphics.setCanvas(Viewport.canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 1)
end

function Viewport.endFrame()
    if not Viewport.canvas then
        return
    end

    love.graphics.setCanvas()
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Viewport.canvas, Viewport.offsetX, Viewport.offsetY, 0, Viewport.scale, Viewport.scale)
end

function Viewport.toGameCoords(x, y)
    if not Viewport.canvas then
        return x, y
    end

    return
        (x - Viewport.offsetX) / Viewport.scale,
        (y - Viewport.offsetY) / Viewport.scale
end

function Viewport.toGameDelta(dx, dy)
    if not Viewport.canvas then
        return dx, dy
    end

    return dx / Viewport.scale, dy / Viewport.scale
end

function Viewport.getMousePosition()
    local x, y = love.mouse.getPosition()
    return Viewport.toGameCoords(x, y)
end

return Viewport
