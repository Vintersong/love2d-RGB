local class = require("libs.hump-master.class")

-- Create base Entity class
local Entity = class{}

function Entity:init()
    -- Initialize entity properties here
    -- This will be called by child classes
end

function Entity:update(dt)
    -- Entity update logic
    -- Override in child classes
end

return Entity