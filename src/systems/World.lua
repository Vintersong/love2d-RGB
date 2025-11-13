-- Vaporwave grid background that scrolls with music
local World = {}

function World.init()
    World.gridSize = 50
    World.gridColor = {0.3, 0.15, 0.45, 0.5}  -- Purple grid lines
    World.backgroundColor = {0.1, 0.05, 0.2}   -- Deep purple background
    World.neonCyan = {0, 0.94, 1, 0.6}         -- Neon cyan accent lines
    World.scrollSpeed = 100  -- Base scroll speed (pixels/second)
    World.scrollOffset = 0
    World.horizonY = 200  -- Y position of horizon line
    
    -- Perspective effect values
    World.perspectiveScale = 0.3  -- How much grid shrinks toward horizon
end

function World.update(dt, musicReactor)
    -- Update scroll speed based on music if available
    if musicReactor then
        World.scrollSpeed = musicReactor:getScrollSpeed() or 100
    end
    
    -- Scroll the grid
    World.scrollOffset = World.scrollOffset + World.scrollSpeed * dt
    
    -- Wrap offset to prevent infinite growth
    if World.scrollOffset >= World.gridSize then
        World.scrollOffset = World.scrollOffset - World.gridSize
    end
end

function World.draw()
    -- Background now handled by BackgroundShader system
    -- World system disabled to prevent covering the shader
    -- The isometric grid shader provides the vaporwave background

    -- local SCREEN_WIDTH = 1920
    -- local SCREEN_HEIGHT = 1080
    --
    -- -- Draw background
    -- love.graphics.setColor(World.backgroundColor)
    -- love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    --
    -- -- Draw horizon glow
    -- love.graphics.setColor(World.neonCyan[1], World.neonCyan[2], World.neonCyan[3], 0.2)
    -- for i = 0, 20 do
    --     local alpha = (20 - i) / 20 * 0.1
    --     love.graphics.setColor(World.neonCyan[1], World.neonCyan[2], World.neonCyan[3], alpha)
    --     love.graphics.rectangle("fill", 0, World.horizonY - i * 2, SCREEN_WIDTH, 2)
    -- end
    --
    -- -- Draw perspective grid
    -- World.drawPerspectiveGrid(SCREEN_WIDTH, SCREEN_HEIGHT)
    --
    -- -- Draw horizon line (bright cyan)
    -- love.graphics.setColor(World.neonCyan)
    -- love.graphics.setLineWidth(2)
    -- love.graphics.line(0, World.horizonY, SCREEN_WIDTH, World.horizonY)
    -- love.graphics.setLineWidth(1)
end

function World.drawPerspectiveGrid(width, height)
    local gridSize = World.gridSize
    local offset = World.scrollOffset
    
    -- Draw horizontal lines (receding into distance)
    love.graphics.setColor(World.gridColor)
    local y = World.horizonY
    local step = gridSize
    local index = 0
    
    while y < height do
        -- Calculate perspective scale (lines get further apart as they approach)
        local distanceFromHorizon = y - World.horizonY
        local scale = 1 + distanceFromHorizon / height * World.perspectiveScale
        
        -- Apply scroll offset with perspective
        local lineY = y + (offset * scale)
        if lineY < height then
            -- Fade lines near the horizon
            local alpha = math.min(1, distanceFromHorizon / 200)
            love.graphics.setColor(World.gridColor[1], World.gridColor[2], World.gridColor[3], World.gridColor[4] * alpha)
            
            -- Make every 4th line brighter (accent lines)
            if index % 4 == 0 then
                love.graphics.setColor(World.neonCyan[1], World.neonCyan[2], World.neonCyan[3], World.neonCyan[4] * alpha * 0.5)
            end
            
            love.graphics.line(0, lineY, width, lineY)
        end
        
        y = y + step * scale
        index = index + 1
    end
    
    -- Draw vertical lines (perspective converging to center)
    local centerX = width / 2
    local numLines = 20
    
    for i = -numLines, numLines do
        if i == 0 then
            -- Center line is brighter
            love.graphics.setColor(World.neonCyan)
        else
            love.graphics.setColor(World.gridColor)
        end
        
        -- Calculate line position with perspective
        local xTop = centerX + i * (gridSize * 0.2)
        local xBottom = centerX + i * (gridSize * 2)
        
        -- Don't draw if off-screen
        if xBottom >= 0 and xBottom <= width then
            love.graphics.line(xTop, World.horizonY, xBottom, height)
        end
    end
end

return World