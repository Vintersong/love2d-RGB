local gradient = require("src.render.Gradient")

local ShieldEffect = {}

local active = nil

function ShieldEffect.trigger(x, y, config)
    config = config or {}
    active = {
        maxRadius = config.maxRadius or 64,
        expandSpeed = config.expandSpeed or 500,
        rotateSpeed = config.rotateSpeed or 1.5,
        fadeSpeed = config.fadeSpeed or 3,
        outerColor = config.outerColor or {0.1, 0.1, 0.1, 0.0},
        innerColor = config.innerColor or {0.8, 0.8, 0.8, 0.7},
        radius = 0,
        alpha = config.alpha or 0.5,
        rotation = 0,
        alive = true,
        expanding = true,
        cx = x,
        cy = y,
    }
end

function ShieldEffect.setPosition(x, y)
    if active then
        active.cx = x
        active.cy = y
    end
end

function ShieldEffect.despawn()
    if active then
        active.alive = false
        active.expanding = false
    end
end

function ShieldEffect.update(dt)
    if not active then return end

    if active.expanding and active.alive then
        active.radius = active.radius + active.expandSpeed * dt
        if active.radius >= active.maxRadius then
            active.radius = active.maxRadius
            active.expanding = false
        end
    end

    if active.alpha > 0 then
        active.rotation = active.rotation + active.rotateSpeed * dt
    end

    if not active.alive and active.alpha > 0 then
        active.alpha = active.alpha - active.fadeSpeed * dt
        if active.alpha <= 0 then
            active = nil
        end
    end
end

function ShieldEffect.draw()
    if not active or active.alpha <= 0 or not gradient then
        return
    end

    local cx = active.cx
    local cy = active.cy
    local radius = active.radius
    local function shieldShape()
        love.graphics.circle("fill", cx, cy, radius)
    end

    local inner = {
        active.innerColor[1],
        active.innerColor[2],
        active.innerColor[3],
        active.alpha,
    }

    love.graphics.setBlendMode("add")
    gradient.draw(
        shieldShape,
        "radial",
        cx,
        cy,
        radius,
        radius,
        active.outerColor,
        inner,
        active.rotation
    )
    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 1, 1, 0.8 * math.min(1, active.alpha / 0.5))
    love.graphics.circle("line", cx, cy, radius)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

return ShieldEffect
