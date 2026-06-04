-- SimpleGrid.lua
-- Center-aligned backdrop grid used in gameplay while the shader is disabled.

local SimpleGrid = {}
local BackgroundShader = require("src.render.BackgroundShader")

SimpleGrid.cellSize = 48
SimpleGrid.lineAlpha = 0.12
SimpleGrid.centerPulseMaxAlpha = 0.5
SimpleGrid.screenWidth = 0
SimpleGrid.screenHeight = 0
SimpleGrid.cols = 0
SimpleGrid.rows = 0
SimpleGrid.gridWidth = 0
SimpleGrid.gridHeight = 0
SimpleGrid.originX = 0
SimpleGrid.originY = 0
SimpleGrid.time = 0
SimpleGrid.centerCols = {1, 1}
SimpleGrid.bandRows = 2

local function clamp01(value)
    return math.max(0, math.min(1, value or 0))
end

local function pingPong01(value)
    local wrapped = value - math.floor(value)
    return 1 - math.abs(wrapped * 2 - 1)
end

function SimpleGrid.init(screenWidth, screenHeight)
    SimpleGrid.screenWidth = screenWidth
    SimpleGrid.screenHeight = screenHeight
    SimpleGrid.cols = math.ceil(screenWidth / SimpleGrid.cellSize)
    SimpleGrid.rows = math.ceil(screenHeight / SimpleGrid.cellSize)
    SimpleGrid.gridWidth = SimpleGrid.cols * SimpleGrid.cellSize
    SimpleGrid.gridHeight = SimpleGrid.rows * SimpleGrid.cellSize

    -- Center the grid on screen so the highlighted columns stay perfectly
    -- symmetrical, even when the screen size is not a clean multiple of cellSize.
    SimpleGrid.originX = math.floor((screenWidth - SimpleGrid.gridWidth) * 0.5)
    SimpleGrid.originY = math.floor((screenHeight - SimpleGrid.gridHeight) * 0.5)

    local leftCenterCol = math.floor(SimpleGrid.cols * 0.5)
    SimpleGrid.centerCols = {leftCenterCol, leftCenterCol + 1}
    SimpleGrid.time = 0

    print(string.format(
        "[SimpleGrid] Initialized centered %dx%d grid (%d x %d cells), center columns %d-%d",
        screenWidth,
        screenHeight,
        SimpleGrid.cols,
        SimpleGrid.rows,
        SimpleGrid.centerCols[1],
        SimpleGrid.centerCols[2]
    ))

    return true
end

function SimpleGrid.update(dt, musicReactor)
    SimpleGrid.time = SimpleGrid.time + dt
end

function SimpleGrid.draw()
    local ox = SimpleGrid.originX
    local oy = SimpleGrid.originY
    local cellSize = SimpleGrid.cellSize
    local gridW = SimpleGrid.gridWidth
    local gridH = SimpleGrid.gridHeight
    local centerColor = {1.0, 0.4, 0.7}

    love.graphics.push()

    -- Background fill behind the grid so gameplay keeps a stable dark base.
    love.graphics.setColor(0.08, 0.05, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, SimpleGrid.screenWidth, SimpleGrid.screenHeight)

    -- Reintroduce the old shader as a restrained ambient pass inside the board.
    -- The fixed grid remains the structural layer; the shader just adds motion.
    BackgroundShader.drawAmbient(ox, oy, gridW, gridH, 0.2)

    -- Base grid lines.
    love.graphics.setColor(centerColor[1], centerColor[2], centerColor[3], SimpleGrid.lineAlpha)
    for col = 0, SimpleGrid.cols do
        local x = ox + col * cellSize
        love.graphics.line(x, oy, x, oy + gridH)
    end

    for row = 0, SimpleGrid.rows do
        local y = oy + row * cellSize
        love.graphics.line(ox, y, ox + gridW, y)
    end

    local bandHeight = SimpleGrid.bandRows * cellSize
    love.graphics.setColor(centerColor[1], centerColor[2], centerColor[3], 0.04)
    love.graphics.rectangle("fill", ox, oy, gridW, bandHeight)
    love.graphics.rectangle("fill", ox, oy + gridH - bandHeight, gridW, bandHeight)

    -- Sequentially illuminate the two center columns from top to bottom.
    for _, col in ipairs(SimpleGrid.centerCols) do
        local x = ox + (col - 1) * cellSize
        for row = 1, SimpleGrid.rows do
            local y = oy + (row - 1) * cellSize
            local phase = SimpleGrid.time * 0.9 - (row - 1) * 0.12
            local alpha = pingPong01(phase) * SimpleGrid.centerPulseMaxAlpha
            alpha = clamp01(alpha)

            if alpha > 0.001 then
                love.graphics.setColor(centerColor[1], centerColor[2], centerColor[3], alpha)
                love.graphics.rectangle("fill", x, y, cellSize, cellSize)
            end
        end
    end

    -- Re-draw the highlighted center column borders on top for crispness.
    love.graphics.setColor(centerColor[1], centerColor[2], centerColor[3], 0.3)
    for _, col in ipairs(SimpleGrid.centerCols) do
        local x = ox + (col - 1) * cellSize
        love.graphics.rectangle("line", x, oy, cellSize, gridH)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

return SimpleGrid
