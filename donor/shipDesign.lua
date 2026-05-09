local shapeLibrary = require("shapeLibrary")

local palette = {
    vaporwavePink = {1.0, 0.35, 0.75, 1.0},
}

local ShipRenderer = {}
ShipRenderer.__index = ShipRenderer

function ShipRenderer:new(config)
    local self = setmetatable({}, ShipRenderer)
    self.config = config or {}
    self.color = self.config.color or palette.vaporwavePink or {1, 1, 1, 1}
    self.scale = self.config.scale or 1
    self.shipMainCanvas = nil
    self.grid = {}
    self:build()
    return self
end

function ShipRenderer:build()
    local gap = 2
    self.cellSizes = {
        { {64,64}, {64,64}, {64,64}, {128,64}, {64,64}, {64,64}, {128,64} },
        { {64,64}, {64,64}, {64,64}, {128,64}, {64,64}, {64,64}, {128,64} },
        { {64,64}, {64,64}, {64,64}, {128,64}, {64,64}, {64,64}, {128,64} },
        { {64,128}, {64,128}, {64,128}, {128,128}, {64,128}, {64,128}, {128,128} },
        { {64,64}, {64,64}, {64,64}, {128,64}, {64,64}, {64,64}, {128,64} },
        { {64,64}, {64,64}, {64,64}, {128,64}, {64,64}, {64,64}, {128,64} },
        { {64,64}, {64,64}, {64,64}, {128,64}, {64,64}, {64,64}, {128,64} },
    }

    local rows = #self.cellSizes
    local cols = #self.cellSizes[1]
    self.grid = {}

    local colWidths = {}
    for col = 1, cols do
        local maxW = 0
        for row = 1, rows do
            if self.cellSizes[row][col][1] > maxW then
                maxW = self.cellSizes[row][col][1]
            end
        end
        colWidths[col] = maxW
    end

    local rowHeights = {}
    for row = 1, rows do
        local maxH = 0
        for col = 1, cols do
            if self.cellSizes[row][col][2] > maxH then
                maxH = self.cellSizes[row][col][2]
            end
        end
        rowHeights[row] = maxH
    end

    for row = 1, rows do
        self.grid[row] = {}
        for col = 1, cols do
            local size = self.cellSizes[row][col]
            self.grid[row][col] = love.graphics.newCanvas(size[1], size[2], {format = "normal"})
        end
    end

    local shapeGrid = {
        { nil, nil, {shape="triangle", type="isosceles", orientation="left", base=64}, {shape="rectangle", width=128, height=64, orientation="right"}, {shape="trapezoid", wide=64, narrow=48, orientation="right"}, {shape="trapezoid", wide=48, narrow=32, orientation="right"}, {shape="triangle", type="isosceles", orientation="right", base=32} },
        { nil, nil, nil, {shape="trapezoid", wide=64, narrow=128, orientation="down"}, nil, nil, nil },
        { nil, nil, nil, {shape="trapezoid", wide=128, narrow=64, orientation="down"}, nil, nil, nil },
        { {shape="trapezoid", wide=128, narrow=64, orientation="right"}, {shape="trapezoid", wide=64, narrow=80, orientation="right"}, {shape="trapezoid", wide=128, narrow=80, orientation="left"}, {shape="rectangle", width=128, height=128, orientation="right"}, {shape="rectangle", width=64, height=128, orientation="right"}, {shape="trapezoid", wide=128, narrow=64, orientation="right"}, {shape="triangle", type="isosceles", orientation="right", base=64} },
        { nil, nil, nil, {shape="trapezoid", wide=64, narrow=128, orientation="down"}, nil, nil, nil },
        { nil, nil, nil, {shape="trapezoid", wide=128, narrow=64, orientation="down"}, nil, nil, nil },
        { nil, nil, {shape="triangle", type="isosceles", orientation="left", base=64}, {shape="rectangle", width=128, height=64, orientation="right"}, {shape="trapezoid", wide=64, narrow=48, orientation="right"}, {shape="trapezoid", wide=48, narrow=32, orientation="right"}, {shape="triangle", type="isosceles", orientation="right", base=32} },
    }

    for row = 1, rows do
        for col = 1, cols do
            local size = self.cellSizes[row][col]
            love.graphics.setCanvas(self.grid[row][col])
            love.graphics.setBlendMode("alpha")
            love.graphics.clear(0, 0, 0, 0)

            local cell = shapeGrid[row] and shapeGrid[row][col]
            if cell then
                local shapeName = cell.shape
                local params = {}
                for key, value in pairs(cell) do
                    if key ~= "shape" then
                        params[key] = value
                    end
                end
                love.graphics.setColor(self.color)
                shapeLibrary[shapeName](0, 0, size[1], size[2], params)
            end

            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", 1, 1, size[1] - 2, size[2] - 2)
            love.graphics.setCanvas()
        end
    end

    local gridWidth = 0
    for col = 1, cols do
        gridWidth = gridWidth + colWidths[col]
    end
    gridWidth = gridWidth + gap * (cols - 1)

    local gridHeight = 0
    for row = 1, rows do
        gridHeight = gridHeight + rowHeights[row]
    end
    gridHeight = gridHeight + gap * (rows - 1)

    self.shipMainCanvas = love.graphics.newCanvas(gridWidth, gridHeight, {format = "normal"})
    love.graphics.setCanvas(self.shipMainCanvas)
    love.graphics.setBlendMode("alpha")
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)

    for row = 1, rows do
        local y = 0
        for r = 1, row - 1 do
            y = y + rowHeights[r] + gap
        end
        for col = 1, cols do
            local x = 0
            for c = 1, col - 1 do
                x = x + colWidths[c] + gap
            end
            local cellW = self.cellSizes[row][col][1]
            local cellH = self.cellSizes[row][col][2]
            local offsetX = (colWidths[col] - cellW) * 0.5
            local offsetY = (rowHeights[row] - cellH) * 0.5
            love.graphics.draw(self.grid[row][col], x + offsetX, y + offsetY)
        end
    end
    love.graphics.setCanvas()
end

function ShipRenderer:draw(x, y, scale)
    if not self.shipMainCanvas then
        return
    end
    local drawScale = scale or self.scale
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local cw = self.shipMainCanvas:getWidth()
    local ch = self.shipMainCanvas:getHeight()
    local dx = x or ((sw / drawScale - cw) * 0.5)
    local dy = y or ((sh / drawScale - ch) * 0.5)
    love.graphics.push()
    love.graphics.scale(drawScale, drawScale)
    love.graphics.draw(self.shipMainCanvas, dx, dy)
    love.graphics.pop()
end

return ShipRenderer
