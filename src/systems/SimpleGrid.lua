-- SimpleGrid.lua
-- Simple grid system with 32x32 cells that can have opacity modified based on rhythm

local SimpleGrid = {}

-- Grid configuration
SimpleGrid.cellSize = 32
SimpleGrid.cols = 0
SimpleGrid.rows = 0
SimpleGrid.screenWidth = 0
SimpleGrid.screenHeight = 0
SimpleGrid.grid = {}  -- 2D array to store cell data
SimpleGrid.centerCol = 30  -- Center vertical stripe (columns 30-31)
SimpleGrid.centerRow = 17  -- Center horizontal stripe (rows 17-18)
SimpleGrid.waves = {}  -- Active animation waves propagating from center
SimpleGrid.waveSpeed = 5  -- Cells per second

-- Initialize the grid system
function SimpleGrid.init(screenWidth, screenHeight)
    SimpleGrid.screenWidth = screenWidth
    SimpleGrid.screenHeight = screenHeight

    -- Calculate number of cells
    SimpleGrid.cols = math.ceil(screenWidth / SimpleGrid.cellSize)
    SimpleGrid.rows = math.ceil(screenHeight / SimpleGrid.cellSize)

    -- Initialize grid with default values
    SimpleGrid.grid = {}
    for row = 1, SimpleGrid.rows do
        SimpleGrid.grid[row] = {}
        for col = 1, SimpleGrid.cols do
            SimpleGrid.grid[row][col] = {
                opacity = 0.0,  -- 0.0 = transparent, 1.0 = fully visible
                color = {1, 1, 1}  -- RGB color
            }
        end
    end

    print(string.format("[SimpleGrid] Initialized %dx%d grid (%d x %d cells)",
        screenWidth, screenHeight, SimpleGrid.cols, SimpleGrid.rows))

    return true
end

-- Trigger a wave animation from the center
function SimpleGrid.triggerWave(quadrant, color, pattern)
    -- quadrant: 1=top-left, 2=top-right, 3=bottom-left, 4=bottom-right (or "all")
    -- color: RGB table {r, g, b}
    -- pattern: "expand", "line", "diamond", etc. (for future use)

    local wave = {
        quadrant = quadrant or "all",
        color = color or {1, 1, 1},
        pattern = pattern or "expand",
        distance = 0,  -- Current propagation distance from center
        age = 0,       -- Time since wave started
        duration = 2.0 -- How long the wave lasts (seconds)
    }

    table.insert(SimpleGrid.waves, wave)
end

-- Update grid (animations and rhythm-based updates)
function SimpleGrid.update(dt, musicReactor)
    -- Update all active waves
    for i = #SimpleGrid.waves, 1, -1 do
        local wave = SimpleGrid.waves[i]
        wave.age = wave.age + dt
        wave.distance = wave.distance + SimpleGrid.waveSpeed * dt

        -- Remove expired waves
        if wave.age >= wave.duration then
            table.remove(SimpleGrid.waves, i)
        else
            -- Apply wave effect to grid cells
            SimpleGrid.applyWave(wave)
        end
    end

    -- Decay all cell opacities over time (fade out effect)
    for row = 1, SimpleGrid.rows do
        for col = 1, SimpleGrid.cols do
            if SimpleGrid.grid[row][col].opacity > 0 then
                SimpleGrid.grid[row][col].opacity = SimpleGrid.grid[row][col].opacity - dt * 2
                if SimpleGrid.grid[row][col].opacity < 0 then
                    SimpleGrid.grid[row][col].opacity = 0
                end
            end
        end
    end
end

-- Apply wave effect to grid cells based on distance from center
function SimpleGrid.applyWave(wave)
    local centerCols = {SimpleGrid.centerCol, SimpleGrid.centerCol + 1}  -- 30, 31
    local centerRows = {SimpleGrid.centerRow, SimpleGrid.centerRow + 1}  -- 17, 18

    -- Iterate through all cells
    for row = 2, SimpleGrid.rows - 1 do  -- Skip border cells
        for col = 2, SimpleGrid.cols - 1 do
            -- Determine which quadrant this cell is in
            local cellQuadrant = SimpleGrid.getCellQuadrant(col, row)

            -- Skip if wave is for a specific quadrant and this cell isn't in it
            if wave.quadrant ~= "all" and wave.quadrant ~= cellQuadrant then
                goto continue
            end

            -- Calculate distance from nearest center cell
            local minDist = math.huge
            for _, centerCol in ipairs(centerCols) do
                for _, centerRow in ipairs(centerRows) do
                    local dist = math.abs(col - centerCol) + math.abs(row - centerRow)  -- Manhattan distance
                    minDist = math.min(minDist, dist)
                end
            end

            -- Check if wave front has reached this cell (with small tolerance band)
            local distDiff = math.abs(minDist - wave.distance)
            if distDiff < 1.5 then  -- Wave "thickness"
                -- Set cell color and opacity based on wave
                local opacity = 1.0 - (wave.age / wave.duration)  -- Fade over time
                opacity = opacity * (1.0 - distDiff / 1.5)  -- Smooth edges

                SimpleGrid.grid[row][col].color = wave.color
                SimpleGrid.grid[row][col].opacity = math.max(SimpleGrid.grid[row][col].opacity, opacity)
            end

            ::continue::
        end
    end
end

-- Get which quadrant a cell is in (1=TL, 2=TR, 3=BL, 4=BR)
function SimpleGrid.getCellQuadrant(col, row)
    local isLeft = col < SimpleGrid.centerCol
    local isTop = row < SimpleGrid.centerRow

    if isTop and isLeft then return 1 end      -- Top-left
    if isTop and not isLeft then return 2 end  -- Top-right
    if not isTop and isLeft then return 3 end  -- Bottom-left
    return 4                                    -- Bottom-right
end

-- Draw the grid
function SimpleGrid.draw()
    love.graphics.push()

    -- Draw each cell
    for row = 1, SimpleGrid.rows do
        for col = 1, SimpleGrid.cols do
            local x = (col - 1) * SimpleGrid.cellSize
            local y = (row - 1) * SimpleGrid.cellSize

            -- Check if this is a center intersection cell (where red lines cross)
            local isCenterIntersection = (col == 30 or col == 31) and (row == 17 or row == 18)

            -- Draw first and last row/column in red, plus columns 30 and 31, plus center rows 17 and 18
            if row == 1 or row == SimpleGrid.rows or col == 1 or col == SimpleGrid.cols or col == 30 or col == 31 or row == 17 or row == 18 then
                -- Center intersection is green, everything else is red
                if isCenterIntersection then
                    love.graphics.setColor(0, 1, 0, 0.5)  -- Green with 50% opacity
                else
                    love.graphics.setColor(1, 0, 0, 0.5)  -- Red with 50% opacity
                end
                love.graphics.rectangle("fill", x, y, SimpleGrid.cellSize, SimpleGrid.cellSize)

                -- Draw coordinates in the cell
                love.graphics.setColor(1, 1, 1, 1)  -- White text
                local coordText = string.format("(%d,%d)", col, row)
                love.graphics.print(coordText, x + 2, y + SimpleGrid.cellSize / 2 - 6, 0, 0.5, 0.5)
            else
                -- Draw interior cells normally
                local cell = SimpleGrid.grid[row][col]

                -- Only draw cells with opacity > 0
                if cell.opacity > 0 then
                    love.graphics.setColor(cell.color[1], cell.color[2], cell.color[3], cell.opacity)
                    love.graphics.rectangle("fill", x, y, SimpleGrid.cellSize, SimpleGrid.cellSize)
                end
            end
        end
    end

    -- Draw grid lines for reference
    love.graphics.setColor(1, 1, 1, 0.1)  -- Very faint white lines

    -- Vertical lines
    for col = 0, SimpleGrid.cols do
        local x = col * SimpleGrid.cellSize
        love.graphics.line(x, 0, x, SimpleGrid.screenHeight)
    end

    -- Horizontal lines
    for row = 0, SimpleGrid.rows do
        local y = row * SimpleGrid.cellSize
        love.graphics.line(0, y, SimpleGrid.screenWidth, y)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

-- Set opacity for a specific cell
function SimpleGrid.setCell(row, col, opacity, color)
    if row >= 1 and row <= SimpleGrid.rows and col >= 1 and col <= SimpleGrid.cols then
        SimpleGrid.grid[row][col].opacity = opacity or 0
        if color then
            SimpleGrid.grid[row][col].color = color
        end
    end
end

-- Clear all cells
function SimpleGrid.clear()
    for row = 1, SimpleGrid.rows do
        for col = 1, SimpleGrid.cols do
            SimpleGrid.grid[row][col].opacity = 0
        end
    end
end

return SimpleGrid
