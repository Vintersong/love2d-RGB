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
        -- hit pulse state
        hitRings   = {},
        flashAlpha = 0,
        hitColor   = {1, 1, 1},
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

function ShieldEffect.triggerHit(color)
    if not active then return end
    if #active.hitRings >= 4 then return end
    active.flashAlpha = 1.0
    active.hitColor   = color or {0.8, 0.8, 0.8}
    local r = active.maxRadius
    table.insert(active.hitRings, {
        life    = 1,
        maxLife = 0.5,
        startR  = r,
        maxR    = r + 30,
        delay   = 0,
    })
    table.insert(active.hitRings, {
        life    = 1,
        maxLife = 0.7,
        startR  = r,
        maxR    = r + 50,
        delay   = 0.1,
    })
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

    -- Flash decay
    if active.flashAlpha > 0 then
        active.flashAlpha = math.max(0, active.flashAlpha - dt * 5)
    end

    -- Hit rings
    for i = #active.hitRings, 1, -1 do
        local ring = active.hitRings[i]
        if ring.delay > 0 then
            ring.delay = ring.delay - dt
        else
            ring.life = ring.life - dt / ring.maxLife
            if ring.life <= 0 then
                table.remove(active.hitRings, i)
            end
        end
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

    -- Flash overlay
    if active.flashAlpha > 0 then
        local fc = active.hitColor
        love.graphics.setBlendMode("add")
        love.graphics.setColor(fc[1], fc[2], fc[3], active.flashAlpha * 0.25)
        love.graphics.circle("fill", cx, cy, radius)
        love.graphics.setColor(fc[1], fc[2], fc[3], active.flashAlpha * 0.7)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", cx, cy, radius)
        love.graphics.setBlendMode("alpha")
    end

    -- Expanding hit rings
    if #active.hitRings > 0 then
        local hc = active.hitColor
        love.graphics.setBlendMode("add")
        for _, ring in ipairs(active.hitRings) do
            if ring.delay <= 0 and ring.life > 0 then
                local progress = 1 - ring.life
                local r2 = ring.startR + (ring.maxR - ring.startR) * progress
                love.graphics.setColor(hc[1], hc[2], hc[3], ring.life * 0.85)
                love.graphics.setLineWidth(2.5 * ring.life)
                love.graphics.circle("line", cx, cy, math.max(0.1, r2))
            end
        end
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return ShieldEffect
