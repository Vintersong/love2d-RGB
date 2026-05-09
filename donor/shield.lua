local gradient = require("libs.gradient")

if type(gradient) == "boolean" then
    gradient = love.gradient
end

local ShieldEffect = {}
ShieldEffect.__index = ShieldEffect

function ShieldEffect:new(config)
    local self = setmetatable({}, ShieldEffect)
    self.config = config or {}
    self.maxRadius = self.config.maxRadius or 64
    self.expandSpeed = self.config.expandSpeed or 500
    self.rotateSpeed = self.config.rotateSpeed or 1.5
    self.fadeSpeed = self.config.fadeSpeed or 3
    self.outerColor = self.config.outerColor or {0.1, 0.1, 0.1, 0.0}
    self.innerColor = self.config.innerColor or {0.8, 0.8, 0.8, 0.7}
    self.radius = 0
    self.alpha = 0
    self.rotation = 0
    self.alive = false
    self.expanding = false
    self.cx = 0
    self.cy = 0
    return self
end

function ShieldEffect:trigger(x, y, opts)
    opts = opts or {}
    self.cx = x or self.cx
    self.cy = y or self.cy
    self.radius = opts.startRadius or 0
    self.alpha = opts.alpha or 0.5
    self.alive = true
    self.expanding = true
end

function ShieldEffect:despawn()
    self.alive = false
    self.expanding = false
end

function ShieldEffect:update(dt)
    if self.expanding and self.alive then
        self.radius = self.radius + self.expandSpeed * dt
        if self.radius >= self.maxRadius then
            self.radius = self.maxRadius
            self.expanding = false
        end
    end

    if self.alpha > 0 then
        self.rotation = self.rotation + self.rotateSpeed * dt
    end

    if not self.alive and self.alpha > 0 then
        self.alpha = self.alpha - self.fadeSpeed * dt
        if self.alpha < 0 then
            self.alpha = 0
        end
    end
end

function ShieldEffect:draw()
    if self.alpha <= 0 or not gradient then
        return
    end

    local cx = self.cx
    local cy = self.cy
    local radius = self.radius
    local function shieldShape()
        love.graphics.circle("fill", cx, cy, radius)
    end

    local inner = {
        self.innerColor[1],
        self.innerColor[2],
        self.innerColor[3],
        self.alpha,
    }

    love.graphics.setBlendMode("add")
    gradient.draw(
        shieldShape,
        "radial",
        cx,
        cy,
        radius,
        radius,
        self.outerColor,
        inner,
        self.rotation
    )
    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("line", cx, cy, radius)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

return ShieldEffect
