local MathUtils = {}

function MathUtils.atan2(y, x)
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 then
        if y >= 0 then
            return math.atan(y / x) + math.pi
        end
        return math.atan(y / x) - math.pi
    elseif y > 0 then
        return math.pi / 2
    elseif y < 0 then
        return -math.pi / 2
    end
    return 0
end

function MathUtils.angleBetween(fromX, fromY, toX, toY)
    return MathUtils.atan2(toY - fromY, toX - fromX)
end

return MathUtils
