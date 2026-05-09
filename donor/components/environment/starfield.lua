local Starfield = {}
Starfield.__index = Starfield

function Starfield:new(config)
    local self = setmetatable({}, Starfield)
    self.layers = {
        { speed = 40,  color = {0.4, 0.4, 0.6}, size = 1, density = 0.05 }, -- Distant
        { speed = 120, color = {0.6, 0.6, 0.8}, size = 2, density = 0.02 }, -- Mid
        { speed = 300, color = {0.8, 0.8, 1.0}, size = 3, density = 0.01 }  -- Near
    }
    
    self.objects = {}
    self.cameraX = 0
    self.spawnX = 0
    self.cullDistance = 400
    self.screenWidth = love.graphics.getWidth()
    
    return self
end

function Starfield:spawnObject(x, layerIndex)
    local layer = self.layers[layerIndex]
    local obj = {
        x = x,
        y = math.random(0, 1080), -- Assuming base height
        layer = layerIndex,
        speed = layer.speed,
        color = layer.color,
        size = layer.size
    }
    table.insert(self.objects, obj)
end

function Starfield:update(dt, scrollSpeed)
    self.cameraX = self.cameraX + (scrollSpeed or 100) * dt
    
    -- Spawn/Cull logic (to be fully implemented later)
    -- This is where the Environment_Buildings logic would go
end

function Starfield:draw()
    for _, obj in ipairs(self.objects) do
        love.graphics.setColor(obj.color[1], obj.color[2], obj.color[3], 0.8)
        love.graphics.circle("fill", obj.x - self.cameraX * (obj.speed/100), obj.y, obj.size)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Starfield
