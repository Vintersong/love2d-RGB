local Resolution = {
    baseWidth = 1920,
    baseHeight = 1080,
    
    canvasWidth = 1920,
    canvasHeight = 1080,
    visibleWidth = 1920,
    visibleHeight = 1080,
    
    offsetX = 0,
    offsetY = 0,
    canvasOffsetX = 0,
    canvasOffsetY = 0,
    scale = 1,
    
    mainCanvas = nil,
    useAdaptiveWidth = true
}

function Resolution:init()
    self:update()
    self.mainCanvas = love.graphics.newCanvas(self.canvasWidth, self.canvasHeight)
    self.mainCanvas:setFilter("linear", "linear")
end

function Resolution:update()
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    if self.useAdaptiveWidth then
        -- Height-locked scaling for ultrawide support
        self.scale = screenHeight / self.baseHeight
        self.visibleHeight = self.baseHeight
        self.visibleWidth = math.floor(screenWidth / self.scale)
        
        -- Add 10% safety margin for offscreen spawning
        local extraWidth = self.visibleWidth * 0.10
        self.canvasWidth = self.visibleWidth + extraWidth
        self.canvasHeight = self.baseHeight
        self.canvasOffsetX = extraWidth / 2
        self.canvasOffsetY = 0
    else
        -- Fixed aspect ratio with black bars
        local scaleX = screenWidth / self.baseWidth
        local scaleY = screenHeight / self.baseHeight
        self.scale = math.min(scaleX, scaleY)
        self.visibleWidth = self.baseWidth
        self.visibleHeight = self.baseHeight
        self.canvasWidth = self.baseWidth
        self.canvasHeight = self.baseHeight
        self.canvasOffsetX = 0
        self.canvasOffsetY = 0
    end
    
    -- Center the visible area on screen
    self.offsetX = (screenWidth - self.visibleWidth * self.scale) / 2
    self.offsetY = (screenHeight - self.visibleHeight * self.scale) / 2
    
    -- Recreate canvas if dimensions changed significantly
    if self.mainCanvas then
        local cw, ch = self.mainCanvas:getDimensions()
        if cw ~= self.canvasWidth or ch ~= self.canvasHeight then
            self.mainCanvas = love.graphics.newCanvas(self.canvasWidth, self.canvasHeight)
        end
    end
end

function Resolution:toCanvas(sx, sy)
    local cx = (sx - self.offsetX) / self.scale + self.canvasOffsetX
    local cy = (sy - self.offsetY) / self.scale + self.canvasOffsetY
    return cx, cy
end

function Resolution:toScreen(cx, cy)
    local sx = (cx - self.canvasOffsetX) * self.scale + self.offsetX
    local sy = (cy - self.canvasOffsetY) * self.scale + self.offsetY
    return sx, sy
end

function Resolution:getVisibleArea()
    return self.canvasOffsetX, self.canvasOffsetY, self.visibleWidth, self.visibleHeight
end

return Resolution
