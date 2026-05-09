local shapeUtils = require("systems.core.shapeUtils")

local drawUtils = {}

function drawUtils.neonPolygon(color, points, time)
    time = time or love.timer.getTime()

    for i = 1, 4 do
        love.graphics.setColor(color[1], color[2], color[3], 0.3)
        love.graphics.setLineWidth(2 + i)
        love.graphics.polygon("line", points)
    end

    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", points)

    local inner = shapeUtils.scaleShape(points, 0.98)
    local pulse = math.abs(math.sin(time * 2))
    local r = color[1] * pulse + (1 - pulse)
    local g = color[2] * pulse + (1 - pulse)
    local b = color[3] * pulse + (1 - pulse)

    for i = 1, 2 do
        love.graphics.setColor(r, g, b, 0.3)
        love.graphics.setLineWidth(1 + i * 0.5)
        love.graphics.polygon("line", inner)
    end

    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", inner)

    love.graphics.setLineWidth(1)
end

return drawUtils
