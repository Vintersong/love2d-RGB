-- shapeLibrary.lua
-- Provides functions to draw custom shapes on a given canvas
local shapeLibrary = {}

-- shapeLibrary.triangle(x, y, w, h, params): Draws isosceles or right triangles with orientation
function shapeLibrary.triangle(x, y, w, h, params)
    -- params.type: "isosceles" (default), "right"
    -- params.orientation: "up" (default), "right", "down", "left"
    -- params.base: base width (optional, only for isosceles)
    local ttype = params and params.type or "isosceles"
    local orientation = params and params.orientation or "up"
    if ttype == "isosceles" then
        local base = params and params.base or w
        if orientation == "up" then
            -- Center the base at the bottom of the cell
            local baseLeft = x + (w - base) / 2
            local baseRight = baseLeft + base
            love.graphics.polygon("fill",
                x + w/2, y,           -- top (center)
                baseRight, y + h,     -- bottom right
                baseLeft, y + h       -- bottom left
            )
        elseif orientation == "down" then
            -- Center the base at the top of the cell
            local baseLeft = x + (w - base) / 2
            local baseRight = baseLeft + base
            love.graphics.polygon("fill",
                baseLeft, y,          -- top left
                baseRight, y,         -- top right
                x + w/2, y + h        -- bottom (center)
            )
        elseif orientation == "right" then
            -- Center the base vertically on the left
            local baseTop = y + (h - base) / 2
            local baseBottom = baseTop + base
            love.graphics.polygon("fill",
                x, baseTop,           -- left top
                x, baseBottom,        -- left bottom
                x + w, y + h/2        -- right (center)
            )
        elseif orientation == "left" then
            -- Center the base vertically on the right
            local baseTop = y + (h - base) / 2
            local baseBottom = baseTop + base
            love.graphics.polygon("fill",
                x + w, baseTop,       -- right top
                x + w, baseBottom,    -- right bottom
                x, y + h/2            -- left (center)
            )
        end
    elseif ttype == "right" then
        if orientation == "up" then
            love.graphics.polygon("fill",
                x, y + h,             -- bottom left (right angle)
                x + w, y + h,         -- bottom right
                x, y                  -- top left
            )
        elseif orientation == "right" then
            love.graphics.polygon("fill",
                x, y,                 -- top left (right angle)
                x + w, y,             -- top right
                x, y + h              -- bottom left
            )
        elseif orientation == "down" then
            love.graphics.polygon("fill",
                x, y,                 -- top left
                x + w, y,             -- top right (right angle)
                x + w, y + h          -- bottom right
            )
        elseif orientation == "left" then
            love.graphics.polygon("fill",
                x + w, y,             -- top right
                x + w, y + h,         -- bottom right (right angle)
                x, y + h              -- bottom left
            )
        end
    end
end

-- shapeLibrary.trapezoid(x, y, w, h, params): Draws a trapezoid with orientation support
function shapeLibrary.trapezoid(x, y, w, h, params)
    -- params.wide: wide side length (default h)
    -- params.narrow: narrow side length (default h*0.6)
    -- params.orientation: "right" (default), "left", "up", "down"
    local wide = params and params.wide or h
    local narrow = params and params.narrow or h * 0.6
    local orientation = params and params.orientation or "right"
    if orientation == "right" or orientation == "left" then
        -- Center the trapezoid vertically in the cell
        local wideTop = y + (h - wide) / 2
        local wideBottom = wideTop + wide
        local narrowTop = y + (h - narrow) / 2
        local narrowBottom = narrowTop + narrow
        if orientation == "right" then
            love.graphics.polygon("fill",
                x, wideTop,                 -- top left (wide)
                x + w, narrowTop,           -- top right (narrow)
                x + w, narrowBottom,        -- bottom right (narrow)
                x, wideBottom               -- bottom left (wide)
            )
        else -- "left"
            love.graphics.polygon("fill",
                x + w, wideTop,             -- top right (wide)
                x, narrowTop,               -- top left (narrow)
                x, narrowBottom,            -- bottom left (narrow)
                x + w, wideBottom           -- bottom right (wide)
            )
        end
    else -- "up" or "down"
        -- Center the trapezoid horizontally in the cell
        local wideLeft = x + (w - wide) / 2
        local wideRight = wideLeft + wide
        local narrowLeft = x + (w - narrow) / 2
        local narrowRight = narrowLeft + narrow
        if orientation == "up" then
            love.graphics.polygon("fill",
                narrowLeft, y + h,          -- bottom left (narrow)
                narrowRight, y + h,         -- bottom right (narrow)
                wideRight, y,               -- top right (wide)
                wideLeft, y                 -- top left (wide)
            )
        else -- "down"
            love.graphics.polygon("fill",
                wideLeft, y + h,            -- bottom left (wide)
                wideRight, y + h,           -- bottom right (wide)
                narrowRight, y,             -- top right (narrow)
                narrowLeft, y               -- top left (narrow)
            )
        end
    end
end

-- shapeLibrary.rectangle(x, y, w, h, params): Draws a rectangle with editable width, height, and orientation
function shapeLibrary.rectangle(x, y, w, h, params)
    -- Center the rectangle in the cell if custom width/height are provided
    local rw = params and params.width or w
    local rh = params and params.height or h
    local orientation = params and params.orientation or "right"
    local offsetX = x + (w - rw) / 2
    local offsetY = y + (h - rh) / 2
    if orientation == "right" then
        love.graphics.rectangle("fill", offsetX, offsetY, rw, rh)
    elseif orientation == "left" then
        love.graphics.push()
        love.graphics.translate(offsetX + rw, offsetY)
        love.graphics.scale(-1, 1)
        love.graphics.rectangle("fill", 0, 0, rw, rh)
        love.graphics.pop()
    elseif orientation == "up" then
        love.graphics.push()
        love.graphics.translate(offsetX, offsetY)
        love.graphics.rotate(-math.pi/2)
        love.graphics.rectangle("fill", 0, 0, rh, rw)
        love.graphics.pop()
    elseif orientation == "down" then
        love.graphics.push()
        love.graphics.translate(offsetX + rw, offsetY + rh)
        love.graphics.rotate(math.pi/2)
        love.graphics.rectangle("fill", 0, 0, rh, rw)
        love.graphics.pop()
    end
end

return shapeLibrary
