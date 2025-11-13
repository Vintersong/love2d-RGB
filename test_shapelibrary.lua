-- Test file for ShapeLibrary
-- Run with: love . (make sure to temporarily modify main.lua to load this)

local ShapeLibrary = require("src.systems.ShapeLibrary")

function love.load()
    print("ShapeLibrary loaded successfully!")
    print("Testing shape function availability:")
    
    -- Test that all shape functions exist
    local shapeFunctions = {
        "circle", "rectangle", "triangle", "hexagon", "octagon", "dodecagon",
        "diamond", "square", "atom", "crescent", "prism", "arrow",
        "trail", "sonarRing", "progressBar", "glow", "multiRing"
    }
    
    for _, funcName in ipairs(shapeFunctions) do
        if ShapeLibrary[funcName] then
            print("  ✓ ShapeLibrary." .. funcName .. " exists")
        else
            print("  ✗ ShapeLibrary." .. funcName .. " MISSING!")
        end
    end
end

function love.draw()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)
    
    local testColor = {0.3, 0.6, 1}
    local y = 100
    
    -- Test basic shapes
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Basic Shapes:", 50, 50)
    
    ShapeLibrary.circle(100, y, 20, testColor, {outline = {1, 1, 1}, outlineWidth = 2})
    love.graphics.print("circle", 80, y + 30)
    
    ShapeLibrary.square(200, y, 40, testColor, {outline = {1, 1, 1}})
    love.graphics.print("square", 180, y + 30)
    
    ShapeLibrary.triangle(300, y, 20, testColor, {outline = {1, 1, 1}})
    love.graphics.print("triangle", 280, y + 30)
    
    ShapeLibrary.hexagon(400, y, 20, testColor, {outline = {1, 1, 1}})
    love.graphics.print("hexagon", 380, y + 30)
    
    ShapeLibrary.octagon(500, y, 20, testColor, {outline = {1, 1, 1}})
    love.graphics.print("octagon", 480, y + 30)
    
    ShapeLibrary.dodecagon(600, y, 20, testColor, {outline = {1, 1, 1}})
    love.graphics.print("dodecagon", 575, y + 30)
    
    ShapeLibrary.diamond(700, y, 20, testColor, {outline = {1, 1, 1}})
    love.graphics.print("diamond", 680, y + 30)
    
    -- Test composite shapes
    y = 250
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Composite Shapes:", 50, y - 50)
    
    local time = love.timer.getTime()
    
    ShapeLibrary.atom(100, y, 15, {1, 0.4, 0.7}, {age = time})
    love.graphics.print("atom", 80, y + 30)
    
    ShapeLibrary.crescent(200, y, 20, {0.8, 0.4, 1}, {angle = time})
    love.graphics.print("crescent", 180, y + 30)
    
    ShapeLibrary.prism(300, y, 20, {0.3, 0.9, 1})
    love.graphics.print("prism", 280, y + 30)
    
    ShapeLibrary.arrow(400, y, 20, {1, 0.6, 0.2}, {angle = time, showWingDetails = true})
    love.graphics.print("arrow", 380, y + 30)
    
    -- Test utility shapes
    y = 400
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Utility Shapes:", 50, y - 50)
    
    ShapeLibrary.progressBar(100, y, 200, 20, 0.7, {
        bgColor = {0.3, 0.3, 0.3},
        fgColor = {0.2, 0.8, 0.2},
        borderColor = {1, 1, 1}
    })
    love.graphics.print("progress bar", 100, y + 30)
    
    ShapeLibrary.glow(450, y + 10, 15, {1, 0.8, 0.2}, {layers = 5})
    love.graphics.print("glow", 430, y + 30)
    
    ShapeLibrary.sonarRing(550, y + 10, 30 + math.sin(time * 2) * 10, {0.3, 1, 0.8}, 0.8)
    love.graphics.print("sonar ring", 520, y + 30)
    
    -- Test multi-ring
    y = 550
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Multi-Ring System:", 50, y - 50)
    
    local ringColors = {
        {1, 0.4, 0.7},
        {0.8, 0.4, 1},
        {0.3, 0.9, 1}
    }
    ShapeLibrary.multiRing(150, y, 20, 3, ringColors, "circle")
    love.graphics.print("circle rings", 120, y + 50)
    
    ShapeLibrary.multiRing(300, y, 20, 3, ringColors, "hexagon")
    love.graphics.print("hexagon rings", 265, y + 50)
    
    ShapeLibrary.multiRing(450, y, 20, 2, ringColors, "square")
    love.graphics.print("square rings", 420, y + 50)
    
    -- Instructions
    love.graphics.setColor(1, 1, 0.5)
    love.graphics.print("ShapeLibrary Test - Press ESC to exit", 50, 700)
    love.graphics.print("All shapes loaded successfully!", 50, 720)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
