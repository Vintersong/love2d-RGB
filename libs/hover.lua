local hover = {}

-- Point-in-polygon check
function hover.pointInPolygon(px, py, polygon)
    local inside = false
    local j = #polygon - 1

    for i = 1, #polygon - 1, 2 do
        local xi, yi = polygon[i], polygon[i + 1]
        local xj, yj = polygon[j], polygon[j + 1]

        local intersect = ((yi > py) ~= (yj > py)) and
                          (px < (xj - xi) * (py - yi) / ((yj - yi) + 0.00001) + xi)
        if intersect then
            inside = not inside
        end
        j = i
    end

    return inside
end

-- Point-in-circle check
function hover.pointInCircle(px, py, cx, cy, radius)
    local dx = px - cx
    local dy = py - cy
    return dx * dx + dy * dy <= radius * radius
end

return hover

    
    --The hover module contains a single function,  pointInPolygon , which checks if a point is inside a polygon. The function takes three arguments: the x and y coordinates of the point, and a table containing the polygon's vertices. The function returns a boolean value indicating whether the point is inside the polygon. 
    --The function works by iterating over each pair of vertices in the polygon, and checking if the point lies on the left side of the line segment connecting the two vertices. If the point lies on the left side of an odd number of line segments, it is considered inside the polygon. 
    --The function uses a simple ray-casting algorithm to determine if the point is inside the polygon. The algorithm works by casting a ray from the point in a horizontal direction, and counting the number of times the ray intersects with the polygon's edges. If the number of intersections is odd, the point is inside the polygon; if it is even, the point is outside the polygon. 
    --The function uses a small epsilon value (0.00001) to handle floating point precision issues when calculating the intersection point. This ensures that the function works correctly even when the point is very close to an edge of the polygon. 
    --The function is used in the main.lua file to detect when the mouse cursor is hovering over the letter "V" drawn on the screen. When the mouse cursor is over the letter, the letter is drawn with a different color to indicate that it is being hovered over. 
    --The hover module provides a simple and efficient way to check if a point is inside a polygon, which can be useful in a variety of applications, such as collision detection, hit testing, and user interface design. 
    