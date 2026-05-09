-- BulletPatterns: pattern library for boss and enemy projectile attacks
-- Each pattern returns an array of projectile data tables {x, y, vx, vy, damage, color}
-- Patterns with staggered spawns accept an optional scheduler with a schedule(delay, data) method
local BulletPatterns = {}

function BulletPatterns.radialBurst(origin, baseAngle, params)
    local count = params.count or 8
    local speed = params.speed or 220
    local arc = params.arc or (math.pi * 2)
    local startAngle = params.startAngle or baseAngle
    local damage = params.damage or 10
    local color = params.color

    local projectiles = {}
    for i = 0, count - 1 do
        local t = (count <= 1) and 0 or i / (count - 1)
        local angle = startAngle + t * arc
        table.insert(projectiles, {
            x = origin.x, y = origin.y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            damage = damage, color = color,
        })
    end
    return projectiles
end

function BulletPatterns.spiral(origin, baseAngle, params, scheduler)
    local count = params.count or 16
    local speed = params.speed or 250
    local turnStep = params.turnStep or 0.22
    local delay = params.delay or 0.03
    local startAngle = params.baseAngle or baseAngle
    local damage = params.damage or 10
    local color = params.color

    local projectiles = {}
    for i = 0, count - 1 do
        local angle = startAngle + i * turnStep
        local proj = {
            x = origin.x, y = origin.y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            damage = damage, color = color,
        }
        if i == 0 then
            table.insert(projectiles, proj)
        elseif scheduler then
            scheduler.schedule(i * delay, proj)
        end
    end
    return projectiles
end

function BulletPatterns.doubleSpiral(origin, baseAngle, params, scheduler)
    local count = params.count or 16
    local speed = params.speed or 250
    local turnStep = params.turnStep or 0.2
    local delay = params.delay or 0.03
    local damage = params.damage or 10
    local color = params.color

    local projectiles = {}
    for i = 0, count - 1 do
        local angle1 = baseAngle + i * turnStep
        local angle2 = baseAngle + math.pi + i * turnStep
        local proj1 = {
            x = origin.x, y = origin.y,
            vx = math.cos(angle1) * speed,
            vy = math.sin(angle1) * speed,
            damage = damage, color = color,
        }
        local proj2 = {
            x = origin.x, y = origin.y,
            vx = math.cos(angle2) * speed,
            vy = math.sin(angle2) * speed,
            damage = damage, color = color,
        }
        if i == 0 then
            table.insert(projectiles, proj1)
            table.insert(projectiles, proj2)
        elseif scheduler then
            scheduler.schedule(i * delay, proj1)
            scheduler.schedule(i * delay, proj2)
        end
    end
    return projectiles
end

function BulletPatterns.cross(origin, baseAngle, params, scheduler)
    local axes = params.axes or 4
    local bulletsPerAxis = params.bulletsPerAxis or 4
    local speed = params.speed or 260
    local delay = params.delay or 0.04
    local damage = params.damage or 10
    local color = params.color

    local projectiles = {}
    for axis = 0, axes - 1 do
        local angle = baseAngle + axis * ((math.pi * 2) / axes)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        for index = 0, bulletsPerAxis - 1 do
            local proj = {
                x = origin.x, y = origin.y,
                vx = vx, vy = vy,
                damage = damage, color = color,
            }
            if index == 0 and axis == 0 then
                table.insert(projectiles, proj)
            elseif scheduler then
                scheduler.schedule((axis * bulletsPerAxis + index) * delay, proj)
            else
                table.insert(projectiles, proj)
            end
        end
    end
    return projectiles
end

function BulletPatterns.flower(origin, baseAngle, params)
    local petals = params.petals or 6
    local rotations = params.rotations or 3
    local speed = params.speed or 240
    local damage = params.damage or 10
    local color = params.color

    local projectiles = {}
    for r = 1, rotations do
        local offset = (r / rotations) * math.pi
        for i = 0, petals - 1 do
            local t = (petals <= 1) and 0 or i / (petals - 1)
            local angle = offset + t * (math.pi * 2)
            table.insert(projectiles, {
                x = origin.x, y = origin.y,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed,
                damage = damage, color = color,
            })
        end
    end
    return projectiles
end

function BulletPatterns.wave(origin, baseAngle, params)
    local count = params.count or 7
    local speed = params.speed or 300
    local amplitude = params.amplitude or 1.2
    local frequency = params.frequency or 4
    local spacing = params.spacing or 24
    local damage = params.damage or 10
    local color = params.color
    local t = love.timer.getTime()

    local projectiles = {}
    for i = 1, count do
        local angle = math.sin(t * frequency + i) * amplitude + baseAngle
        local offsetX = (i - count * 0.5) * spacing
        local perpX = -math.sin(baseAngle)
        local perpY = math.cos(baseAngle)
        table.insert(projectiles, {
            x = origin.x + perpX * offsetX,
            y = origin.y + perpY * offsetX,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            damage = damage, color = color,
        })
    end
    return projectiles
end

function BulletPatterns.curved(origin, baseAngle, params)
    local count = params.count or 12
    local speed = params.speed or 260
    local damage = params.damage or 10
    local color = params.color
    local elapsed = love.timer.getTime()
    local cycles = params.cycles or 2
    local duration = params.duration or 2
    local phase = (elapsed / duration) * cycles * 2 * math.pi
    local pulse = (math.cos(phase) * -0.5) + 0.5
    local minRadius = params.minRadius or 40
    local maxRadius = params.maxRadius or 120
    local radius = minRadius + pulse * (maxRadius - minRadius)

    local projectiles = {}
    for i = 1, count do
        local angle = (i / count) * (2 * math.pi)
        table.insert(projectiles, {
            x = origin.x + math.cos(angle) * radius,
            y = origin.y + math.sin(angle) * radius,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            damage = damage, color = color,
        })
    end
    return projectiles
end

function BulletPatterns.spiralOutward(origin, baseAngle, params, scheduler)
    local count = params.count or 16
    local delay = params.delay or 0.04
    local direction = params.direction or 1
    local angularStep = params.angularStep or 0.2
    local speed = params.speed or 260
    local damage = params.damage or 10
    local color = params.color

    local projectiles = {}
    for i = 0, count - 1 do
        local angle = baseAngle + i * angularStep * direction
        local proj = {
            x = origin.x, y = origin.y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            damage = damage, color = color,
        }
        if i == 0 then
            table.insert(projectiles, proj)
        elseif scheduler then
            scheduler.schedule(i * delay, proj)
        end
    end
    return projectiles
end

function BulletPatterns.randomSpread(origin, baseAngle, params)
    local count = params.count or 8
    local arc = params.arc or (math.pi * 0.5)
    local minSpeed = params.minSpeed or 320
    local maxSpeed = params.maxSpeed or 400
    local damage = params.damage or 10
    local color = params.color

    local projectiles = {}
    for _ = 1, count do
        local angle = baseAngle + (math.random() - 0.5) * arc
        local speed = minSpeed + math.random() * (maxSpeed - minSpeed)
        table.insert(projectiles, {
            x = origin.x, y = origin.y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            damage = damage, color = color,
        })
    end
    return projectiles
end

return BulletPatterns
