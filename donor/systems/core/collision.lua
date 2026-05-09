local collision = {}

function collision.pointRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

function collision.rectRect(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2
end

function collision.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function collision.distanceSq(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
end

function collision.circle(x1, y1, r1, x2, y2, r2)
    return collision.distance(x1, y1, x2, y2) < (r1 + r2)
end

function collision.circleSq(x1, y1, r1, x2, y2, r2)
    local r = r1 + r2
    return collision.distanceSq(x1, y1, x2, y2) < (r * r)
end

return collision
