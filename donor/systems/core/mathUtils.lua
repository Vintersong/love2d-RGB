local mathUtils = {}

function mathUtils.clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function mathUtils.normalize(x, y)
    local length = math.sqrt(x * x + y * y)
    if length == 0 then
        return 0, -1
    end
    return x / length, y / length
end

return mathUtils
