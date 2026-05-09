local patternLibrary = {}

local function now(ctx)
    if ctx and ctx.now then
        return ctx.now()
    end
    return 0
end

local function spawn(ctx, spec)
    if ctx and ctx.spawn then
        ctx.spawn(spec)
    end
end

local function schedule(ctx, event)
    if ctx and ctx.schedule then
        ctx.schedule(event)
    end
end

function patternLibrary.radialBurst(ctx, origin, params)
    params = params or {}
    local count = params.count or 12
    local speed = params.speed or 220
    local arc = params.arc or (math.pi * 2)
    local startAngle = params.startAngle or 0
    local color = params.color or {1, 1, 0.3}
    local ttl = params.ttl
    for i = 0, count - 1 do
        local t = (count <= 1) and 0 or i / (count - 1)
        local angle = startAngle + t * arc
        spawn(ctx, {
            x = origin.x,
            y = origin.y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            pattern = params.pattern or "straight",
            color = color,
            ttl = ttl,
        })
    end
end

function patternLibrary.spiral(ctx, origin, params)
    params = params or {}
    local count = params.count or 24
    local speed = params.speed or 250
    local turnStep = params.turnStep or 0.2
    local delay = params.delay or 0.03
    local baseAngle = params.baseAngle or now(ctx)
    local color = params.color or {1, 0.6, 0.2}
    local ttl = params.ttl
    for i = 0, count - 1 do
        local angle = baseAngle + i * turnStep
        schedule(ctx, {
            delay = i * delay,
            kind = "spawn",
            spec = {
                x = origin.x,
                y = origin.y,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed,
                color = color,
                ttl = ttl,
            },
        })
    end
end

function patternLibrary.doubleSpiral(ctx, origin, params)
    params = params or {}
    patternLibrary.spiral(ctx, origin, {
        count = params.count,
        speed = params.speed,
        turnStep = params.turnStep,
        delay = params.delay,
        baseAngle = params.baseAngle,
        color = params.colorA or {0.3, 0.9, 1.0},
        ttl = params.ttl,
    })
    patternLibrary.spiral(ctx, origin, {
        count = params.count,
        speed = params.speed,
        turnStep = params.turnStep,
        delay = params.delay,
        baseAngle = (params.baseAngle or now(ctx)) + math.pi,
        color = params.colorB or {1.0, 0.7, 0.3},
        ttl = params.ttl,
    })
end

function patternLibrary.cross(ctx, origin, params)
    params = params or {}
    local axes = params.axes or 4
    local bulletsPerAxis = params.bulletsPerAxis or 4
    local speed = params.speed or 260
    local delay = params.delay or 0.04
    local color = params.color or {0.8, 1.0, 0.3}
    local ttl = params.ttl
    local startAngle = params.startAngle or 0
    for axis = 0, axes - 1 do
        local angle = startAngle + axis * ((math.pi * 2) / axes)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        for index = 0, bulletsPerAxis - 1 do
            schedule(ctx, {
                delay = index * delay,
                kind = "spawn",
                spec = {
                    x = origin.x,
                    y = origin.y,
                    vx = vx,
                    vy = vy,
                    color = color,
                    ttl = ttl,
                },
            })
        end
    end
end

function patternLibrary.flower(ctx, origin, params)
    params = params or {}
    local petals = params.petals or 8
    local rotations = params.rotations or 4
    local speed = params.speed or 240
    local color = params.color or {1.0, 0.45, 0.8}
    local ttl = params.ttl
    for r = 1, rotations do
        local offset = (r / rotations) * math.pi
        patternLibrary.radialBurst(ctx, origin, {
            count = petals,
            speed = speed,
            startAngle = offset,
            arc = math.pi * 2,
            color = color,
            ttl = ttl,
        })
    end
end

function patternLibrary.wave(ctx, origin, params)
    params = params or {}
    local count = params.count or 12
    local speed = params.speed or 300
    local amplitude = params.amplitude or 1.2
    local frequency = params.frequency or 4
    local spacing = params.spacing or 20
    local color = params.color or {0.2, 0.8, 1.0}
    local t = now(ctx)
    for i = 1, count do
        local angle = math.sin(t * frequency + i) * amplitude
        spawn(ctx, {
            x = origin.x + (i - count * 0.5) * spacing,
            y = origin.y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            pattern = "wave",
            waveAmplitude = params.waveAmplitude or 40,
            waveFrequency = params.waveFrequency or 2,
            wavePhase = i * (math.pi / math.max(count, 1)),
            color = color,
        })
    end
end

function patternLibrary.curved(ctx, origin, params)
    params = params or {}
    local count = params.count or 24
    local speed = params.speed or 260
    local cycles = params.cycles or 2
    local duration = params.duration or 2
    local elapsed = params.elapsed or now(ctx)
    local phase = (elapsed / duration) * cycles * 2 * math.pi
    local pulse = (math.cos(phase) * -0.5) + 0.5
    local radius = (params.minRadius or 60) + pulse * ((params.maxRadius or 180) - (params.minRadius or 60))
    local color = params.color or {0.3, 1.0, 0.4}
    for i = 1, count do
        local angle = (i / count) * (2 * math.pi)
        local x = origin.x + math.cos(angle) * radius
        local y = origin.y + math.sin(angle) * radius
        spawn(ctx, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            pattern = "sine",
            curve = params.curve or 80,
            color = color,
        })
    end
end

function patternLibrary.spiralOutward(ctx, origin, params)
    params = params or {}
    local count = params.count or 24
    local delay = params.delay or 0.04
    local direction = params.direction or 1
    local angularStep = params.angularStep or 0.2
    local baseAngle = params.baseAngle or 0
    local speed = params.speed or 260
    local color = params.color or {1.0, 0.8, 0.3}
    for i = 0, count - 1 do
        local angle = baseAngle + i * angularStep * direction
        schedule(ctx, {
            delay = i * delay,
            kind = "spawn",
            spec = {
                x = origin.x,
                y = origin.y,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed,
                color = color,
            },
        })
    end
end

function patternLibrary.randomSpread(ctx, origin, params)
    params = params or {}
    local count = params.count or 10
    local arc = params.arc or (math.pi * 0.5)
    local baseAngle = params.baseAngle or (-math.pi * 0.5)
    local minSpeed = params.minSpeed or 320
    local maxSpeed = params.maxSpeed or 400
    local color = params.color or {1.0, 1.0, 0.3}
    for _ = 1, count do
        local angle = baseAngle + (math.random() - 0.5) * arc
        local speed = minSpeed + math.random() * (maxSpeed - minSpeed)
        spawn(ctx, {
            x = origin.x,
            y = origin.y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            color = color,
        })
    end
end

return patternLibrary
