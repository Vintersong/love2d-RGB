-- ShapeLibrary.lua
-- Centralized shape rendering system - eliminates hard-coded love.graphics calls
-- All shapes accept standard parameters: x, y, size, color, options

local ShapeLibrary = {}

-- ============================================================================
-- BASIC SHAPES
-- ============================================================================

-- Circle with optional core
function ShapeLibrary.circle(x, y, size, color, options)
    options = options or {}
    local filled = options.filled ~= false  -- Default true
    local outline = options.outline
    local outlineWidth = options.outlineWidth or 1
    local core = options.core  -- {size, color, alpha}
    
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.circle(filled and "fill" or "line", x, y, size)
    
    if outline then
        love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
        love.graphics.setLineWidth(outlineWidth)
        love.graphics.circle("line", x, y, size)
        love.graphics.setLineWidth(1)
    end
    
    if core then
        love.graphics.setColor(core.color[1], core.color[2], core.color[3], core.alpha or 1)
        love.graphics.circle("fill", x, y, core.size)
    end
end

-- Rectangle
function ShapeLibrary.rectangle(x, y, width, height, color, options)
    options = options or {}
    local filled = options.filled ~= false
    local outline = options.outline
    local outlineWidth = options.outlineWidth or 1
    local centered = options.centered or false
    
    local drawX = centered and (x - width/2) or x
    local drawY = centered and (y - height/2) or y
    
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.rectangle(filled and "fill" or "line", drawX, drawY, width, height)
    
    if outline then
        love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
        love.graphics.setLineWidth(outlineWidth)
        love.graphics.rectangle("line", drawX, drawY, width, height)
        love.graphics.setLineWidth(1)
    end
end

-- Triangle (equilateral or isosceles)
function ShapeLibrary.triangle(x, y, size, color, options)
    options = options or {}
    local filled = options.filled ~= false
    local outline = options.outline
    local outlineWidth = options.outlineWidth or 1
    local pointUp = options.pointUp ~= false  -- Default true
    local rotation = options.rotation or 0
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rotation)
    
    local vertices
    if pointUp then
        vertices = {
            0, -size * 1.2,           -- Top point
            -size, size * 0.8,        -- Bottom left
            size, size * 0.8          -- Bottom right
        }
    else
        vertices = {
            0, size * 1.2,            -- Bottom point
            -size, -size * 0.8,       -- Top left
            size, -size * 0.8         -- Top right
        }
    end
    
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.polygon(filled and "fill" or "line", vertices)
    
    if outline then
        love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
        love.graphics.setLineWidth(outlineWidth)
        love.graphics.polygon("line", vertices)
        love.graphics.setLineWidth(1)
    end
    
    love.graphics.pop()
end

-- Hexagon
function ShapeLibrary.hexagon(x, y, size, color, options)
    options = options or {}
    local filled = options.filled ~= false
    local outline = options.outline
    local outlineWidth = options.outlineWidth or 1
    local rotation = options.rotation or (-math.pi / 2)  -- Point up by default
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rotation)
    
    local vertices = {}
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2
        table.insert(vertices, math.cos(angle) * size)
        table.insert(vertices, math.sin(angle) * size)
    end
    
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.polygon(filled and "fill" or "line", vertices)
    
    if outline then
        love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
        love.graphics.setLineWidth(outlineWidth)
        love.graphics.polygon("line", vertices)
        love.graphics.setLineWidth(1)
    end
    
    love.graphics.pop()
end

-- Octagon (8-sided)
function ShapeLibrary.octagon(x, y, size, color, options)
    options = options or {}
    local filled = options.filled ~= false
    local outline = options.outline
    local outlineWidth = options.outlineWidth or 1
    local innerRing = options.innerRing  -- {size, color}
    
    love.graphics.push()
    love.graphics.translate(x, y)
    
    local vertices = {}
    for i = 0, 7 do
        local angle = (i / 8) * math.pi * 2
        table.insert(vertices, math.cos(angle) * size)
        table.insert(vertices, math.sin(angle) * size)
    end
    
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.polygon(filled and "fill" or "line", vertices)
    
    if outline then
        love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
        love.graphics.setLineWidth(outlineWidth)
        love.graphics.polygon("line", vertices)
        love.graphics.setLineWidth(1)
    end
    
    if innerRing then
        love.graphics.setColor(innerRing.color[1], innerRing.color[2], innerRing.color[3], innerRing.color[4] or 1)
        love.graphics.circle("line", 0, 0, innerRing.size)
    end
    
    love.graphics.pop()
end

-- Dodecagon (12-sided, for XP orbs)
function ShapeLibrary.dodecagon(x, y, size, color, options)
    options = options or {}
    local filled = options.filled ~= false
    local outline = options.outline
    local outlineWidth = options.outlineWidth or 1
    local core = options.core
    
    love.graphics.push()
    love.graphics.translate(x, y)
    
    local vertices = {}
    for i = 0, 11 do
        local angle = (i / 12) * math.pi * 2
        table.insert(vertices, math.cos(angle) * size)
        table.insert(vertices, math.sin(angle) * size)
    end
    
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.polygon(filled and "fill" or "line", vertices)
    
    if outline then
        love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
        love.graphics.setLineWidth(outlineWidth)
        love.graphics.polygon("line", vertices)
        love.graphics.setLineWidth(1)
    end
    
    if core then
        love.graphics.setColor(core.color[1], core.color[2], core.color[3], core.alpha or 1)
        love.graphics.circle("fill", 0, 0, core.size)
    end
    
    love.graphics.pop()
end

-- Diamond
function ShapeLibrary.diamond(x, y, size, color, options)
    options = options or {}
    local filled = options.filled ~= false
    local outline = options.outline
    local outlineWidth = options.outlineWidth or 1
    
    love.graphics.push()
    love.graphics.translate(x, y)
    
    local vertices = {0, -size, size, 0, 0, size, -size, 0}
    
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.polygon(filled and "fill" or "line", vertices)
    
    if outline then
        love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
        love.graphics.setLineWidth(outlineWidth)
        love.graphics.polygon("line", vertices)
        love.graphics.setLineWidth(1)
    end
    
    love.graphics.pop()
end

-- Square (convenience wrapper for rectangle)
function ShapeLibrary.square(x, y, size, color, options)
    options = options or {}
    options.centered = true
    ShapeLibrary.rectangle(x, y, size, size, color, options)
end

-- ============================================================================
-- COMPOSITE SHAPES (Projectiles & Special Entities)
-- ============================================================================

-- Atom shape (hydrogen atom with orbiting electron)
function ShapeLibrary.atom(x, y, size, color, options)
    options = options or {}
    local age = options.age or 0
    local orbitSpeed = options.orbitSpeed or 8
    local uniqueSeed = options.uniqueSeed or 0
    
    love.graphics.push()
    love.graphics.translate(x, y)
    
    -- White outline on outer ring
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, size * 1.5)
    
    -- Colored outer ring
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, size * 1.5)
    
    -- Inner core
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.circle("fill", 0, 0, size * 0.6)
    
    -- Orbiting electron
    local angle = age * orbitSpeed + uniqueSeed * 0.1
    local orbitRadius = size * 1.5
    local electronX = math.cos(angle) * orbitRadius
    local electronY = math.sin(angle) * orbitRadius
    love.graphics.circle("fill", electronX, electronY, size * 0.3)
    
    -- Bright white core
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", 0, 0, size * 0.3)
    
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

-- Crescent moon shape (faces direction of travel)
function ShapeLibrary.crescent(x, y, size, color, options)
    options = options or {}
    local angle = options.angle or 0
    local outlineWidth = options.outlineWidth or 2
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    
    -- Draw crescent as two overlapping circles to create C-shape
    -- Outer arc (full semicircle)
    local outerRadius = size * 1.5
    local innerRadius = size * 1.2
    local innerOffset = size * 0.5  -- Offset to create crescent
    
    -- Draw using stencil for proper crescent shape
    love.graphics.stencil(function()
        -- Cut out the inner circle
        love.graphics.circle("fill", innerOffset, 0, innerRadius)
    end, "replace", 1)
    
    love.graphics.setStencilTest("less", 1)
    
    -- Draw outer semicircle (right side facing direction)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.arc("fill", 0, 0, outerRadius, -math.pi/2, math.pi/2)
    
    love.graphics.setStencilTest()
    
    -- White outline on outer edge
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(outlineWidth)
    love.graphics.arc("line", 0, 0, outerRadius, -math.pi/2, math.pi/2)
    
    -- Inner curve outline
    love.graphics.arc("line", innerOffset, 0, innerRadius, math.pi/2, -math.pi/2)
    
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

-- Prism/Hexagon with refraction lines
function ShapeLibrary.prism(x, y, size, color, options)
    options = options or {}
    local showRefraction = options.showRefraction ~= false
    
    love.graphics.push()
    love.graphics.translate(x, y)
    
    -- Hexagon vertices
    local vertices = {}
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2
        table.insert(vertices, math.cos(angle) * size)
        table.insert(vertices, math.sin(angle) * size)
    end
    
    -- White outline
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.polygon("line", vertices)
    
    -- Core color fill
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.polygon("fill", vertices)
    
    -- Bright core
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", 0, 0, size * 0.4)
    
    -- Refraction lines
    if showRefraction then
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.setLineWidth(1)
        for i = 0, 5 do
            local angle = (i / 6) * math.pi * 2
            local lineX = math.cos(angle) * size
            local lineY = math.sin(angle) * size
            love.graphics.line(0, 0, lineX, lineY)
        end
    end
    
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

-- Arrow/Wing shape (for flanker enemies)
function ShapeLibrary.arrow(x, y, size, color, options)
    options = options or {}
    local angle = options.angle or 0
    local showWingDetails = options.showWingDetails ~= false
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    
    local vertices = {
        size * 1.2, 0,           -- Front point
        -size * 0.6, -size * 0.8, -- Top wing
        -size * 0.3, 0,          -- Body middle
        -size * 0.6, size * 0.8   -- Bottom wing
    }
    
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.polygon("fill", vertices)
    
    -- Wing details
    if showWingDetails then
        love.graphics.setColor(color[1] * 0.6, color[2] * 0.6, color[3] * 0.6)
        love.graphics.line(-size * 0.6, -size * 0.8, -size * 0.8, -size)
        love.graphics.line(-size * 0.6, size * 0.8, -size * 0.8, size)
    end
    
    love.graphics.pop()
end

-- Atom with crescent (YELLOW projectile - atom inside crescent)
function ShapeLibrary.atom_crescent(x, y, size, color, options)
    options = options or {}
    local angle = options.angle or 0
    local age = options.age or 0
    local orbitSpeed = options.orbitSpeed or 8
    local uniqueSeed = options.uniqueSeed or 0
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    
    -- Outer crescent (arc facing direction of travel)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.arc("line", 0, 0, size * 1.8, -math.pi/2, math.pi/2)
    
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.arc("fill", 0, 0, size * 1.8, -math.pi/2, math.pi/2)
    
    -- Reset rotation for atom
    love.graphics.rotate(-angle)
    
    -- Inner atom (smaller, centered)
    local atomSize = size * 0.7
    
    -- White outline on atom ring
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, atomSize * 1.2)
    
    -- Colored atom ring
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", 0, 0, atomSize * 1.2)
    
    -- Atom core
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.circle("fill", 0, 0, atomSize * 0.5)
    
    -- Orbiting electron
    local electronAngle = age * orbitSpeed + uniqueSeed * 0.1
    local orbitRadius = atomSize * 1.2
    local electronX = math.cos(electronAngle) * orbitRadius
    local electronY = math.sin(electronAngle) * orbitRadius
    love.graphics.circle("fill", electronX, electronY, atomSize * 0.25)
    
    -- Bright white core
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", 0, 0, atomSize * 0.25)
    
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

-- Atom with arrow (MAGENTA projectile - arrow pointing from atom edge)
function ShapeLibrary.atom_arrow(x, y, size, color, options)
    options = options or {}
    local angle = options.angle or 0
    local age = options.age or 0
    local orbitSpeed = options.orbitSpeed or 8
    local uniqueSeed = options.uniqueSeed or 0
    
    love.graphics.push()
    love.graphics.translate(x, y)
    
    -- Atom core (centered)
    local atomSize = size * 0.8
    
    -- White outline on atom ring
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, atomSize * 1.2)
    
    -- Colored atom ring
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", 0, 0, atomSize * 1.2)
    
    -- Atom core
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.circle("fill", 0, 0, atomSize * 0.5)
    
    -- Orbiting electron
    local electronAngle = age * orbitSpeed + uniqueSeed * 0.1
    local orbitRadius = atomSize * 1.2
    local electronX = math.cos(electronAngle) * orbitRadius
    local electronY = math.sin(electronAngle) * orbitRadius
    love.graphics.circle("fill", electronX, electronY, atomSize * 0.25)
    
    -- Bright white core
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", 0, 0, atomSize * 0.25)
    
    -- Arrow pointing in direction of travel (attached to edge)
    love.graphics.rotate(angle)
    local arrowBaseX = atomSize * 1.5
    
    -- Arrow head vertices
    local arrowVertices = {
        arrowBaseX + size * 1.0, 0,           -- Tip
        arrowBaseX, -size * 0.4,              -- Top base
        arrowBaseX + size * 0.3, 0,           -- Middle notch
        arrowBaseX, size * 0.4                -- Bottom base
    }
    
    -- White outline on arrow
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", arrowVertices)
    
    -- Colored arrow fill
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.polygon("fill", arrowVertices)
    
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

-- ============================================================================
-- UTILITY SHAPES
-- ============================================================================

-- Trail (series of diminishing circles)
function ShapeLibrary.trail(positions, size, color, options)
    options = options or {}
    local fadeAlpha = options.fadeAlpha or 0.5
    
    for i, pos in ipairs(positions) do
        local alpha = (1 - i / #positions) * fadeAlpha
        local trailSize = size * (1 - i / #positions)
        love.graphics.setColor(color[1], color[2], color[3], alpha)
        love.graphics.circle("fill", pos.x, pos.y, trailSize)
    end
end

-- Sonar pulse ring (expanding ring with fade)
function ShapeLibrary.sonarRing(x, y, radius, color, alpha, options)
    options = options or {}
    local lineWidth = options.lineWidth or 2
    
    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.4)
    love.graphics.setLineWidth(lineWidth)
    love.graphics.circle("line", x, y, radius)
    love.graphics.setLineWidth(1)
end

-- Progress bar
function ShapeLibrary.progressBar(x, y, width, height, progress, options)
    options = options or {}
    local bgColor = options.bgColor or {0.3, 0.3, 0.3}
    local fgColor = options.fgColor or {0.2, 0.8, 0.2}
    local borderColor = options.borderColor
    local borderWidth = options.borderWidth or 2
    
    -- Background
    love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Foreground (progress)
    love.graphics.setColor(fgColor[1], fgColor[2], fgColor[3], fgColor[4] or 1)
    love.graphics.rectangle("fill", x, y, width * progress, height)
    
    -- Border
    if borderColor then
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
        love.graphics.setLineWidth(borderWidth)
        love.graphics.rectangle("line", x, y, width, height)
        love.graphics.setLineWidth(1)
    end
end

-- Glow effect (concentric circles with diminishing alpha)
function ShapeLibrary.glow(x, y, size, color, options)
    options = options or {}
    local layers = options.layers or 3
    local expansion = options.expansion or 3
    local baseAlpha = options.baseAlpha or 0.2
    
    for i = layers, 1, -1 do
        local alpha = baseAlpha * (1 - (i - 1) / layers)
        local glowSize = size + (i * expansion)
        love.graphics.setColor(color[1], color[2], color[3], alpha)
        love.graphics.circle("fill", x, y, glowSize)
    end
end

-- Multi-ring system (for high-level enemies)
function ShapeLibrary.multiRing(x, y, baseSize, ringCount, ringColors, shapeType, options)
    options = options or {}
    local ringThickness = options.ringThickness or 3
    local ringOffset = options.ringOffset or 6
    
    love.graphics.push()
    love.graphics.translate(x, y)
    
    -- Draw rings from outermost to innermost
    for ring = ringCount, 1, -1 do
        local ringColor = ringColors[ring] or {1, 1, 1}
        local alpha = ring == 1 and 1.0 or 0.7
        local offset = (ringCount - ring) * ringOffset
        local size = baseSize + offset
        
        love.graphics.setColor(ringColor[1], ringColor[2], ringColor[3], alpha)
        love.graphics.setLineWidth(ringThickness)
        
        if shapeType == "square" then
            local outerSize = (baseSize * 2) + (offset * 2)
            love.graphics.rectangle("line", -(outerSize/2), -(outerSize/2), outerSize, outerSize)
        elseif shapeType == "hexagon" then
            local vertices = {}
            for i = 0, 5 do
                local angle = (i / 6) * math.pi * 2 - math.pi / 2
                table.insert(vertices, math.cos(angle) * size)
                table.insert(vertices, math.sin(angle) * size)
            end
            love.graphics.polygon("line", vertices)
        elseif shapeType == "triangle" then
            local vertices = {
                0, -size * 1.2,
                -size, size * 0.8,
                size, size * 0.8
            }
            love.graphics.polygon("line", vertices)
        elseif shapeType == "circle" then
            love.graphics.circle("line", 0, 0, size)
        elseif shapeType == "octagon" then
            local vertices = {}
            for i = 0, 7 do
                local angle = (i / 8) * math.pi * 2
                table.insert(vertices, math.cos(angle) * size)
                table.insert(vertices, math.sin(angle) * size)
            end
            love.graphics.polygon("line", vertices)
        end
    end
    
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

return ShapeLibrary
