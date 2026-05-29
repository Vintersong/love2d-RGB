-- ShipRenderer.lua
-- Renders the player ship design onto a cached canvas using inline polygon shapes.
-- Adapted from reference/donor/shipDesign.lua — no external shape library needed.

local ShipRenderer = {}
ShipRenderer.__index = ShipRenderer

local GAP = 2

local CELL_SIZES = {
    { {64,64}, {64,64}, {64,64}, {128,64},  {64,64}, {64,64}, {128,64} },
    { {64,64}, {64,64}, {64,64}, {128,64},  {64,64}, {64,64}, {128,64} },
    { {64,64}, {64,64}, {64,64}, {128,64},  {64,64}, {64,64}, {128,64} },
    { {64,128},{64,128},{64,128},{128,128},{64,128},{64,128},{128,128} },
    { {64,64}, {64,64}, {64,64}, {128,64},  {64,64}, {64,64}, {128,64} },
    { {64,64}, {64,64}, {64,64}, {128,64},  {64,64}, {64,64}, {128,64} },
    { {64,64}, {64,64}, {64,64}, {128,64},  {64,64}, {64,64}, {128,64} },
}

local SHAPE_GRID = {
    { nil, nil, {s="tri",  ori="left",  base=64}, {s="rect"}, {s="trap", wide=64,  narrow=48, ori="right"}, {s="trap", wide=48, narrow=32, ori="right"}, {s="tri", ori="right", base=32} },
    { nil, nil, nil,                              {s="trap", wide=64,  narrow=128, ori="down"}, nil, nil, nil },
    { nil, nil, nil,                              {s="trap", wide=128, narrow=64,  ori="down"}, nil, nil, nil },
    { {s="trap", wide=128, narrow=64, ori="right"}, {s="trap", wide=64, narrow=80, ori="right"}, {s="trap", wide=128, narrow=80, ori="left"}, {s="rect"}, {s="rect"}, {s="trap", wide=128, narrow=64, ori="right"}, {s="tri", ori="right", base=64} },
    { nil, nil, nil,                              {s="trap", wide=64,  narrow=128, ori="down"}, nil, nil, nil },
    { nil, nil, nil,                              {s="trap", wide=128, narrow=64,  ori="down"}, nil, nil, nil },
    { nil, nil, {s="tri",  ori="left",  base=64}, {s="rect"}, {s="trap", wide=64,  narrow=48, ori="right"}, {s="trap", wide=48, narrow=32, ori="right"}, {s="tri", ori="right", base=32} },
}

local function drawShape(w, h, cell, color)
    love.graphics.setColor(color)
    if cell.s == "rect" then
        love.graphics.rectangle("fill", 0, 0, w, h)
    elseif cell.s == "tri" then
        local base = cell.base or h
        local verts
        if cell.ori == "left" then
            verts = {0, h/2,  w, (h-base)/2,  w, (h+base)/2}
        else
            verts = {w, h/2,  0, (h-base)/2,  0, (h+base)/2}
        end
        love.graphics.polygon("fill", verts)
    elseif cell.s == "trap" then
        local wide, narrow = cell.wide, cell.narrow
        local verts
        if cell.ori == "right" then
            verts = {0,(h-wide)/2,  0,(h+wide)/2,  w,(h+narrow)/2,  w,(h-narrow)/2}
        elseif cell.ori == "left" then
            verts = {0,(h-narrow)/2,  0,(h+narrow)/2,  w,(h+wide)/2,  w,(h-wide)/2}
        elseif cell.ori == "down" then
            verts = {(w-wide)/2,0,  (w+wide)/2,0,  (w+narrow)/2,h,  (w-narrow)/2,h}
        end
        if verts then love.graphics.polygon("fill", verts) end
    end
end

local function computeLayout()
    local rows, cols = #CELL_SIZES, #CELL_SIZES[1]
    local colW, rowH = {}, {}
    for c = 1, cols do
        local m = 0
        for r = 1, rows do if CELL_SIZES[r][c][1] > m then m = CELL_SIZES[r][c][1] end end
        colW[c] = m
    end
    for r = 1, rows do
        local m = 0
        for c = 1, cols do if CELL_SIZES[r][c][2] > m then m = CELL_SIZES[r][c][2] end end
        rowH[r] = m
    end
    return colW, rowH
end

function ShipRenderer:new(config)
    local o = setmetatable({}, ShipRenderer)
    o.color = (config and config.color) or {1.0, 0.35, 0.75, 1.0}
    o.scale = (config and config.scale) or 1
    o.canvas = nil
    o:build()
    return o
end

function ShipRenderer:build()
    local colW, rowH = computeLayout()
    local rows, cols = #CELL_SIZES, #CELL_SIZES[1]

    local totalW, totalH = -GAP, -GAP
    for _, w in ipairs(colW) do totalW = totalW + w + GAP end
    for _, h in ipairs(rowH) do totalH = totalH + h + GAP end

    local colX, rowY = {}, {}
    local x = 0
    for c = 1, cols do colX[c] = x; x = x + colW[c] + GAP end
    local y = 0
    for r = 1, rows do rowY[r] = y; y = y + rowH[r] + GAP end

    self.canvas = love.graphics.newCanvas(totalW, totalH, {format = "normal"})
    love.graphics.setCanvas(self.canvas)
    love.graphics.setBlendMode("alpha")
    love.graphics.clear(0, 0, 0, 0)

    for row = 1, rows do
        for col = 1, cols do
            local cell = SHAPE_GRID[row] and SHAPE_GRID[row][col]
            if cell then
                local cw = CELL_SIZES[row][col][1]
                local ch = CELL_SIZES[row][col][2]
                local cx = colX[col] + (colW[col] - cw) * 0.5
                local cy = rowY[row] + (rowH[row] - ch) * 0.5

                love.graphics.push()
                love.graphics.translate(cx, cy)
                drawShape(cw, ch, cell, self.color)
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", 1, 1, cw - 2, ch - 2)
                love.graphics.setLineWidth(1)
                love.graphics.pop()
            end
        end
    end

    love.graphics.setCanvas()
    love.graphics.setBlendMode("alpha")
end

function ShipRenderer:getSize()
    if not self.canvas then return 0, 0 end
    return self.canvas:getWidth() * self.scale, self.canvas:getHeight() * self.scale
end

-- screenX/screenY is where the CENTER of the ship appears on screen.
-- rotation is in radians (default 0 = facing right, -math.pi/2 = facing up).
function ShipRenderer:draw(screenX, screenY, scale, alpha, rotation)
    if not self.canvas then return end
    local s = scale or self.scale
    local cw = self.canvas:getWidth()
    local ch = self.canvas:getHeight()
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(self.canvas, screenX, screenY, rotation or 0, s, s, cw / 2, ch / 2)
end

return ShipRenderer
