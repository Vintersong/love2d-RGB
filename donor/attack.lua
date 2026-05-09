local patternLibrary = require("bulletPatterns")
local mathUtils = require("systems.core.mathUtils")

local atan2 = math.atan2 or function(y, x)
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi * 0.5
    elseif x == 0 and y < 0 then
        return -math.pi * 0.5
    end
    return 0
end

local AttackSystem = {}
AttackSystem.__index = AttackSystem

local clamp = mathUtils.clamp
local normalize = mathUtils.normalize

local function rotate(vx, vy, angle)
    local ca = math.cos(angle)
    local sa = math.sin(angle)
    return vx * ca - vy * sa, vx * sa + vy * ca
end

local function makeTemplate(image, color)
    local ps = love.graphics.newParticleSystem(image, 96)
    ps:setParticleLifetime(0.25, 0.6)
    ps:setEmissionRate(0)
    ps:setSizes(0.8, 0.2)
    ps:setLinearAcceleration(-18, -18, 18, 18)
    ps:setColors(
        color[1], color[2], color[3], 0.9,
        color[1], color[2], color[3], 0.3,
        color[1], color[2], color[3], 0.0
    )
    return ps
end

function AttackSystem:new(config)
    local self = setmetatable({}, AttackSystem)
    self.config = config or {}
    self.projectiles = {}
    self.projectilePool = {}
    self.scheduled = {}
    self.particleTemplates = {}
    self.debugDrawColliders = self.config.debugDrawColliders == true
    self.margin = self.config.offscreenMargin or 64
    self.nextId = 1
    return self
end

function AttackSystem:load()
    local imgData = love.image.newImageData(1, 1)
    imgData:setPixel(0, 0, 1, 1, 1, 1)
    local img = love.graphics.newImage(imgData)
    img:setFilter("nearest", "nearest")
    self.particleTemplates.straight = makeTemplate(img, {1.0, 0.95, 0.2})
    self.particleTemplates.sine = makeTemplate(img, {0.2, 1.0, 0.4})
    self.particleTemplates.wave = makeTemplate(img, {0.2, 0.8, 1.0})
    self.particleTemplates.cluster = makeTemplate(img, {1.0, 0.35, 0.75})
    self.particleTemplates.reflecting = makeTemplate(img, {0.9, 1.0, 0.3})
    self.particleTemplates.split = makeTemplate(img, {1.0, 0.7, 0.2})
end

function AttackSystem:getViewport()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    return 0, 0, w, h
end

function AttackSystem:createPatternContext(now)
    local attack = self
    return {
        now = function()
            return now
        end,
        spawn = function(spec)
            attack:spawn(spec)
        end,
        schedule = function(event)
            attack:schedule(event)
        end,
    }
end

function AttackSystem:spawn(spec)
    local projectile = table.remove(self.projectilePool)
    if not projectile then
        projectile = {hitEnemyIds = {}}
    end

    projectile.id = self.nextId
    projectile.x = spec.x or 0
    projectile.y = spec.y or 0
    projectile.vx = spec.vx or 0
    projectile.vy = spec.vy or -300
    projectile.radius = spec.radius or 6
    projectile.width = spec.width or 12
    projectile.height = spec.height or 12
    projectile.color = spec.color or {1.0, 0.95, 0.2}
    projectile.pattern = spec.pattern or "straight"
    projectile.age = 0
    projectile.ttl = spec.ttl or 6
    projectile.curve = spec.curve
    projectile.waveAmplitude = spec.waveAmplitude
    projectile.waveFrequency = spec.waveFrequency
    projectile.wavePhase = spec.wavePhase or 0
    projectile.splitTime = spec.splitTime
    projectile.splitAngle = spec.splitAngle
    projectile.splitSpeed = spec.splitSpeed
    projectile.numSplits = spec.numSplits
    projectile.clusterDelay = spec.clusterDelay
    projectile.clusterCount = spec.clusterCount
    projectile.exploded = false
    projectile.split = false
    projectile.bounces = spec.bounces or 0
    projectile.maxBounces = spec.maxBounces or 3
    projectile.damage = spec.damage or 1
    projectile.pierce = spec.pierce or 0
    projectile.aoeRadius = spec.aoeRadius or 0
    projectile.slowFactor = spec.slowFactor or 1
    projectile.slowDuration = spec.slowDuration or 0
    projectile.homing = spec.homing == true
    projectile.homingStrength = spec.homingStrength or 0
    projectile.homingTarget = spec.homingTarget
    projectile.dead = false

    for k in pairs(projectile.hitEnemyIds) do
        projectile.hitEnemyIds[k] = nil
    end

    self.nextId = self.nextId + 1

    local template = self.particleTemplates[projectile.pattern] or self.particleTemplates.straight
    if template then
        if not projectile.particle then
            projectile.particle = template:clone()
        end
        projectile.particle:setEmissionRate(0)
        projectile.particle:start()
        projectile.particle:setPosition(projectile.x, projectile.y)
        projectile.particle:emit(5)
    else
        projectile.particle = nil
    end

    table.insert(self.projectiles, projectile)
end

function AttackSystem:schedule(event)
    local scheduled = {
        delay = event.delay or 0,
        kind = event.kind or "spawn",
        spec = event.spec,
        patternName = event.patternName,
        origin = event.origin,
        params = event.params,
    }
    table.insert(self.scheduled, scheduled)
end

function AttackSystem:updateScheduled(dt)
    for i = #self.scheduled, 1, -1 do
        local event = self.scheduled[i]
        event.delay = event.delay - dt
        if event.delay <= 0 then
            if event.kind == "spawn" and event.spec then
                self:spawn(event.spec)
            elseif event.kind == "pattern" and event.patternName then
                local pattern = patternLibrary[event.patternName]
                if pattern then
                    pattern(self:createPatternContext(love.timer.getTime()), event.origin or {x = 0, y = 0}, event.params or {})
                end
            end
            table.remove(self.scheduled, i)
        end
    end
end

function AttackSystem:isOffscreen(projectile)
    local x0, y0, w, h = self:getViewport()
    local m = self.margin
    return projectile.x < x0 - m
        or projectile.x > x0 + w + m
        or projectile.y < y0 - m
        or projectile.y > y0 + h + m
end

function AttackSystem:updateProjectile(projectile, dt)
    if projectile.dead then
        return true
    end

    projectile.age = projectile.age + dt

    if projectile.homing and projectile.homingTarget and projectile.homingTarget.hp and projectile.homingTarget.hp > 0 then
        local desiredX = projectile.homingTarget.x - projectile.x
        local desiredY = projectile.homingTarget.y - projectile.y
        local nx, ny = normalize(desiredX, desiredY)
        local speed = math.sqrt(projectile.vx * projectile.vx + projectile.vy * projectile.vy)
        local blend = clamp((projectile.homingStrength or 1) * dt, 0, 1)
        projectile.vx = projectile.vx * (1 - blend) + nx * speed * blend
        projectile.vy = projectile.vy * (1 - blend) + ny * speed * blend
    end

    if projectile.pattern == "sine" then
        local nx, ny = normalize(projectile.vx, projectile.vy)
        local px, py = -ny, nx
        local sway = math.sin(projectile.age * 6) * (projectile.curve or 90)
        projectile.x = projectile.x + (projectile.vx + px * sway) * dt
        projectile.y = projectile.y + (projectile.vy + py * sway) * dt
    elseif projectile.pattern == "wave" then
        local nx, ny = normalize(projectile.vx, projectile.vy)
        local px, py = -ny, nx
        local freq = projectile.waveFrequency or 2.5
        local amp = projectile.waveAmplitude or 50
        local sway = math.sin(projectile.age * freq + projectile.wavePhase) * amp
        projectile.x = projectile.x + (projectile.vx + px * sway) * dt
        projectile.y = projectile.y + (projectile.vy + py * sway) * dt
    else
        projectile.x = projectile.x + projectile.vx * dt
        projectile.y = projectile.y + projectile.vy * dt
    end

    if projectile.pattern == "cluster" and not projectile.exploded and projectile.age >= (projectile.clusterDelay or 0.5) then
        projectile.exploded = true
        patternLibrary.radialBurst(
            self:createPatternContext(love.timer.getTime()),
            {x = projectile.x, y = projectile.y},
            {
                count = projectile.clusterCount or 8,
                speed = 260,
                color = {1.0, 0.7, 0.2},
            }
        )
        return true
    end

    if projectile.pattern == "split" and not projectile.split and projectile.age >= (projectile.splitTime or 0.4) then
        projectile.split = true
        local heading = atan2(projectile.vy, projectile.vx)
        local splitAngle = projectile.splitAngle or math.rad(30)
        local splitSpeed = projectile.splitSpeed or 300
        local splitCount = projectile.numSplits or 2
        local arc = splitAngle * math.max(splitCount - 1, 1)
        local startAngle = heading - arc * 0.5
        for index = 0, splitCount - 1 do
            local angle = startAngle + index * (arc / math.max(splitCount - 1, 1))
            self:spawn({
                x = projectile.x,
                y = projectile.y,
                vx = math.cos(angle) * splitSpeed,
                vy = math.sin(angle) * splitSpeed,
                pattern = "straight",
                color = {1.0, 0.7, 0.2},
                ttl = 3,
            })
        end
        return true
    end

    if projectile.pattern == "reflecting" then
        local x0, y0, w, h = self:getViewport()
        local hit = false
        if projectile.x < x0 then projectile.x = x0; projectile.vx = -projectile.vx; hit = true end
        if projectile.x > x0 + w then projectile.x = x0 + w; projectile.vx = -projectile.vx; hit = true end
        if projectile.y < y0 then projectile.y = y0; projectile.vy = -projectile.vy; hit = true end
        if projectile.y > y0 + h then projectile.y = y0 + h; projectile.vy = -projectile.vy; hit = true end
        if hit then
            projectile.bounces = projectile.bounces + 1
            if projectile.bounces >= projectile.maxBounces then
                return true
            end
        end
    end

    if projectile.particle then
        projectile.particle:setPosition(projectile.x, projectile.y)
        projectile.particle:update(dt)
    end

    if projectile.age >= projectile.ttl then
        return true
    end

    if self:isOffscreen(projectile) then
        return true
    end

    return false
end

function AttackSystem:update(dt)
    self:updateScheduled(dt)
    for i = #self.projectiles, 1, -1 do
        local projectile = self.projectiles[i]
        if self:updateProjectile(projectile, dt) then
            local deadProj = table.remove(self.projectiles, i)
            if deadProj.particle then
                deadProj.particle:stop()
            end
            table.insert(self.projectilePool, deadProj)
        end
    end
end

function AttackSystem:draw()
    for _, projectile in ipairs(self.projectiles) do
        if projectile.particle then
            love.graphics.draw(projectile.particle, projectile.x, projectile.y)
        end
        love.graphics.setColor(projectile.color[1], projectile.color[2], projectile.color[3], 1)
        love.graphics.circle("fill", projectile.x, projectile.y, projectile.radius)
        if self.debugDrawColliders then
            love.graphics.setColor(1, 1, 1, 0.4)
            love.graphics.circle("line", projectile.x, projectile.y, projectile.radius)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function AttackSystem:fireColorVolley(origin, target, stats)
    stats = stats or {}
    target = target or {x = origin.x, y = origin.y - 100}
    local count = stats.bulletCount or 1
    local speed = stats.bulletSpeed or 620
    local baseAngle = self:_aimAngle(origin, target)
    local spread = math.rad(math.min(42, 8 + count * 5))
    local color = stats.color or {0.2, 1.0, 1.0}

    for i = 1, count do
        local offset = 0
        if count > 1 then
            offset = -spread * 0.5 + ((i - 1) / (count - 1)) * spread
        end
        local vx = math.cos(baseAngle) * speed
        local vy = math.sin(baseAngle) * speed
        vx, vy = rotate(vx, vy, offset)
        self:spawn({
            x = origin.x,
            y = origin.y,
            vx = vx,
            vy = vy,
            radius = 5 + math.min(stats.damage or 1, 6) * 0.7,
            pattern = stats.homing and "sine" or "straight",
            color = color,
            ttl = 2.7,
            damage = stats.damage or 1,
            pierce = stats.pierce or 0,
            aoeRadius = stats.aoeRadius or 0,
            slowFactor = stats.slowFactor or 1,
            slowDuration = stats.slowDuration or 0,
            homing = stats.homing == true,
            homingStrength = stats.homingStrength or 0,
            homingTarget = target,
        })
    end
end

function AttackSystem:_aimAngle(origin, target)
    if not target then
        return -math.pi * 0.5
    end
    return atan2(target.y - origin.y, target.x - origin.x)
end

function AttackSystem:fire(abilityId, origin, target, params)
    params = params or {}
    local ctx = self:createPatternContext(love.timer.getTime())
    local x = origin.x
    local y = origin.y
    local ability = clamp(abilityId or 1, 1, 12)

    if ability == 1 then
        local count = params.numLasers or 2
        local spacing = params.spacing or 40
        local speed = params.speed or 420
        local totalWidth = (count - 1) * spacing
        for i = 0, count - 1 do
            local offset = -totalWidth * 0.5 + i * spacing
            self:spawn({x = x + offset, y = y, vx = 0, vy = -speed, pattern = "straight", color = {0.0, 1.0, 1.0}})
        end
    elseif ability == 2 then
        local spreadAngle = params.arc or math.pi
        local count = params.count or 20
        local speed = params.speed or 350
        local center = self:_aimAngle(origin, target)
        patternLibrary.radialBurst(ctx, origin, {
            count = count,
            speed = speed,
            startAngle = center - spreadAngle * 0.5,
            arc = spreadAngle,
            color = {1.0, 0.5, 0.0},
        })
    elseif ability == 3 then
        self:spawn({x = x, y = y, vx = 0, vy = -250, pattern = "sine", curve = params.curve or 120, color = {0.0, 1.0, 0.4}})
    elseif ability == 4 then
        self:spawn({
            x = x,
            y = y,
            vx = 0,
            vy = -350,
            pattern = "split",
            splitTime = params.splitTime or 0.4,
            splitAngle = params.splitAngle or math.rad(30),
            splitSpeed = params.splitSpeed or 300,
            numSplits = params.numSplits or 2,
            color = {1.0, 1.0, 0.2},
        })
    elseif ability == 5 then
        local count = params.waveBullets or 7
        local spacing = params.spacing or 24
        local totalWidth = (count - 1) * spacing
        for i = 0, count - 1 do
            local offset = -totalWidth * 0.5 + i * spacing
            self:spawn({
                x = x + offset,
                y = y,
                vx = 0,
                vy = -300,
                pattern = "wave",
                waveAmplitude = params.waveAmplitude or 40,
                waveFrequency = params.waveFrequency or 2,
                wavePhase = i * (math.pi / math.max(count, 1)),
                color = {0.2, 0.8, 1.0},
            })
        end
    elseif ability == 6 then
        self:spawn({
            x = x,
            y = y,
            vx = 0,
            vy = -180,
            pattern = "cluster",
            clusterCount = params.clusterCount or 8,
            clusterDelay = params.clusterDelay or 0.5,
            color = {1.0, 0.2, 0.6},
        })
    elseif ability == 7 then
        patternLibrary.randomSpread(ctx, origin, {
            baseAngle = -math.pi * 0.5,
            arc = params.arc or math.pi * 0.5,
            count = params.randomSpreadBullets or 10,
            minSpeed = params.minSpeed or 320,
            maxSpeed = params.maxSpeed or 400,
            color = {1.0, 1.0, 0.3},
        })
    elseif ability == 8 then
        local angle = self:_aimAngle(origin, target)
        local speed = params.speed or 350
        self:spawn({
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            pattern = "reflecting",
            bounces = 0,
            maxBounces = params.reflectBounces or 3,
            color = {0.8, 1.0, 0.2},
        })
    elseif ability == 9 then
        patternLibrary.radialBurst(ctx, origin, {count = 36, speed = params.speed or 320, color = {1.0, 0.4, 0.8}})
    elseif ability == 10 then
        patternLibrary.spiral(ctx, origin, {
            count = params.count or 24,
            speed = params.speed or 280,
            turnStep = 0.22,
            delay = 0.03,
            color = {1.0, 0.6, 0.2},
        })
    elseif ability == 11 then
        patternLibrary.doubleSpiral(ctx, origin, {
            count = params.count or 24,
            speed = params.speed or 260,
            turnStep = 0.2,
            delay = 0.03,
            colorA = {0.3, 0.9, 1.0},
            colorB = {1.0, 0.7, 0.3},
        })
    elseif ability == 12 then
        patternLibrary.cross(ctx, origin, {
            axes = 4,
            bulletsPerAxis = 6,
            speed = params.speed or 300,
            delay = 0.04,
            color = {0.8, 1.0, 0.3},
        })
    end
end

return AttackSystem
