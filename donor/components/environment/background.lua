local Background = {}
Background.__index = Background

function Background:new(config)
    local self = setmetatable({}, Background)
    config = config or {}

    self.shader = love.graphics.newShader("shaders/dynamicBackground.glsl")
    self.parallaxShader = love.graphics.newShader("shaders/parallaxLayer.glsl")

    self.time = 0
    self.colorTint = config.colorTint or {0.8, 0.2, 0.6}
    self.parallaxAlpha = config.parallaxAlpha or 0.5

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    self.parallaxCanvas = love.graphics.newCanvas(w, h)
    self.canvasWidth = w
    self.canvasHeight = h

    return self
end

function Background:setColorTint(r, g, b)
    self.colorTint[1], self.colorTint[2], self.colorTint[3] = r, g, b
end

function Background:update(dt)
    self.time = self.time + dt

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    if w ~= self.canvasWidth or h ~= self.canvasHeight then
        self.parallaxCanvas = love.graphics.newCanvas(w, h)
        self.canvasWidth, self.canvasHeight = w, h
    end

    self.shader:send("resolution", {w, h})
    self.shader:send("colorTint", self.colorTint)
    self.shader:send("time", self.time)
    self.parallaxShader:send("time", self.time)

    local prevCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(self.parallaxCanvas)
    love.graphics.clear()
    love.graphics.setShader(self.parallaxShader)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setShader()
    love.graphics.setCanvas(prevCanvas)
end

function Background:draw()
    love.graphics.setShader(self.shader)
    love.graphics.rectangle("fill", 0, 0, self.canvasWidth, self.canvasHeight)
    love.graphics.setShader()

    love.graphics.setColor(1, 1, 1, self.parallaxAlpha)
    love.graphics.draw(self.parallaxCanvas)
    love.graphics.setColor(1, 1, 1, 1)
end

return Background
