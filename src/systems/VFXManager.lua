-- VFXManager: Manages visual effects and particles
local VFXManager = {}

-- Particle storage
VFXManager.particles = {}

-- Spawn impact burst particles
function VFXManager.spawnImpactBurst(x, y, color, count)
    count = count or 8
    color = color or {1, 1, 1}
    
    for i = 1, count do
        local angle = (i / count) * math.pi * 2
        local speed = 100 + math.random() * 100
        
        table.insert(VFXManager.particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            color = color,
            life = 0.3 + math.random() * 0.2,
            maxLife = 0.5,
            size = 2 + math.random() * 2
        })
    end
end

-- Update all particles
function VFXManager.update(dt)
    for i = #VFXManager.particles, 1, -1 do
        local p = VFXManager.particles[i]
        
        -- Update position
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        
        -- Apply drag
        p.vx = p.vx * 0.95
        p.vy = p.vy * 0.95
        
        -- Update lifetime
        p.life = p.life - dt
        
        -- Remove dead particles
        if p.life <= 0 then
            table.remove(VFXManager.particles, i)
        end
    end
end

-- Draw all particles
function VFXManager.draw()
    for _, p in ipairs(VFXManager.particles) do
        local alpha = p.life / p.maxLife
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Clear all particles
function VFXManager.clear()
    VFXManager.particles = {}
end

return VFXManager