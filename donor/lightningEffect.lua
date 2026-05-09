local LightningEffect = {}
LightningEffect.__index = LightningEffect

function LightningEffect:new(config)
    local self = setmetatable({}, LightningEffect)
    self.config = config or {}
    self.duration = self.config.duration or 0.2
    self.color = self.config.color or {0.8, 0.9, 1.0}
    self.segments = {}
    self.active = false
    self.timer = 0
    return self
end

function LightningEffect:generate(startX, startY, endX, endY, maxDisplacement, numSegments)
    self.segments = {}
    local points = {{x = startX, y = startY}}
    for i = 1, numSegments do
        local progress = i / numSegments
        local currentX = startX + (endX - startX) * progress
        local currentY = startY + (endY - startY) * progress
        if i < numSegments then
            local displacementScale = 1 - (progress * 0.75)
            currentX = currentX + (math.random() * 2 - 1) * maxDisplacement * displacementScale
            currentY = currentY + (math.random() * 2 - 1) * maxDisplacement * displacementScale
        end
        table.insert(points, {x = currentX, y = currentY})
    end

    points[#points] = {x = endX, y = endY}
    for i = 1, #points - 1 do
        table.insert(self.segments, {
            x1 = points[i].x,
            y1 = points[i].y,
            x2 = points[i + 1].x,
            y2 = points[i + 1].y,
            thickness = math.random(1, 4),
        })
    end
end

function LightningEffect:trigger(startX, startY, endX, endY, opts)
    opts = opts or {}
    local width = love.graphics.getWidth()
    self:generate(
        startX,
        startY,
        endX,
        endY,
        opts.maxDisplacement or width / 20,
        opts.numSegments or 15
    )
    self.active = true
    self.timer = 0
end

function LightningEffect:update(dt)
    if not self.active then
        return
    end
    self.timer = self.timer + dt
    if self.timer >= self.duration then
        self.active = false
    end
end

function LightningEffect:draw()
    if not self.active then
        return
    end

    local alpha = math.max(0, 1 - (self.timer / self.duration))
    if alpha <= 0 then
        return
    end

    love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha)
    for _, segment in ipairs(self.segments) do
        love.graphics.setLineWidth(segment.thickness * alpha)
        love.graphics.line(segment.x1, segment.y1, segment.x2, segment.y2)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return LightningEffect
