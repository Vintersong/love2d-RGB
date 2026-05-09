local GameRuntime = require("gameRuntime")

local runtime

function love.load()
    runtime = GameRuntime:new()
    runtime:load()
end

function love.update(dt)
    runtime:update(dt)
end

function love.draw()
    runtime:draw()
end

function love.keypressed(key)
    runtime:keypressed(key)
end

function love.mousepressed(x, y, button)
    runtime:mousepressed(x, y, button)
end
