local shapeUtils = {}

function shapeUtils.scaleShape(points, scale)
    local count = #points / 2
    local cx, cy = 0, 0
    for i = 1, #points, 2 do
        cx = cx + points[i]
        cy = cy + points[i + 1]
    end
    cx = cx / count
    cy = cy / count

    local scaled = {}
    for i = 1, #points, 2 do
        scaled[#scaled + 1] = cx + (points[i] - cx) * scale
        scaled[#scaled + 1] = cy + (points[i + 1] - cy) * scale
    end
    return scaled
end

return shapeUtils
