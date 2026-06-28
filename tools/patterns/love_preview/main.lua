-- Standalone LÖVE visual preview for src/patterns/BulletPatternLibrary.lua
--
-- This is a SEPARATE love app from the game and is NOT wired into the game's boot path
-- (the root main.lua / BootLoader never reference it). It loads ONLY the pattern library
-- (which has no love/game dependencies), spawns descriptors from screen center, and
-- animates them so the pattern shapes can be visually confirmed.
--
-- Run from the repo root:   love tools/patterns/love_preview
-- Keys: 1 radial  2 spiral  3 flower  4 aimed  5 wall+gap  6 composite  SPACE re-fire  ESC quit

local BPL

-- The library lives at <repoRoot>/src/patterns; this app lives at
-- <repoRoot>/tools/patterns/love_preview. Derive the repo root from the love source path,
-- mount it, and load the library file directly (it returns a plain table).
local function loadLibrary()
    local source = love.filesystem.getSource()
    local repoRoot = source:gsub("[/\\]tools[/\\]patterns[/\\]love_preview[/\\]?$", "")
    assert(love.filesystem.mount(repoRoot, "repo"),
        "could not mount repo root: " .. tostring(repoRoot))
    local chunk = assert(love.filesystem.load("repo/src/patterns/BulletPatternLibrary.lua"),
        "could not load BulletPatternLibrary.lua under " .. tostring(repoRoot))
    return chunk()
end

local cx, cy = 640, 360
local t = 0
local bullets = {}        -- live simulated bullets {x, y, vx, vy, color_axis, age}
local currentName = "radial"
local respawnTimer = 0
local RESPAWN_EVERY = 1.4 -- seconds between re-fires
local LIFETIME = 2.5

-- Map color_axis placeholders to display tints (preview-only; the library never does this).
local AXIS_TINT = {
    bass = { 1.0, 0.30, 0.40 },
    mids = { 0.40, 1.0, 0.55 },
    treble = { 0.45, 0.65, 1.0 },
}

local patterns = {}

function patterns.radial()
    return BPL.radial({ x = cx, y = cy }, t, { count = 18, speed = 160, color_axis = "bass" })
end
function patterns.spiral()
    return BPL.spiral({ x = cx, y = cy }, t, { count = 28, angularStep = 0.30, speed = 170, color_axis = "mids" })
end
function patterns.flower()
    return BPL.flower({ x = cx, y = cy }, t, { arms = 6, perArm = 4, spread = 0.6, speed = 170, drift = 0.5, color_axis = "mids" })
end
function patterns.aimed()
    local mx, my = love.mouse.getPosition()
    return BPL.aimed({ x = cx, y = cy }, t, { targetX = mx, targetY = my, count = 11, spread = 0.5, speed = 220, color_axis = "treble" })
end
function patterns.wall()
    return BPL.wallWithGap({ x = cx, y = cy }, t, { count = 25, extent = 1100, axisAngle = 0, speed = 140,
        gaps = { { pos = 0.5, width = 0.14 } }, color_axis = "bass" })
end
function patterns.composite()
    local layers = {
        BPL.radial({ x = cx, y = cy }, t, { count = 14, speed = 130, color_axis = "bass" }),
        BPL.spiral({ x = cx, y = cy }, t, { count = 20, angularStep = 0.28, speed = 175, color_axis = "mids" }),
        BPL.aimed({ x = cx, y = cy }, t, { targetX = love.mouse.getX(), targetY = love.mouse.getY(),
            count = 9, spread = 0.4, speed = 220, color_axis = "treble" }),
    }
    local merged = BPL.composite(layers, { softCap = 600 })
    return merged
end

local function fire()
    local descriptors = (patterns[currentName] or patterns.radial)()
    for i = 1, #descriptors do
        local d = descriptors[i]
        bullets[#bullets + 1] = {
            x = d.x, y = d.y, vx = d.vx, vy = d.vy, color_axis = d.color_axis, age = 0,
        }
    end
end

function love.load()
    BPL = loadLibrary()
    local w, h = love.graphics.getDimensions()
    cx, cy = w / 2, h / 2
    fire()
end

function love.resize(w, h)
    cx, cy = w / 2, h / 2
end

function love.update(dt)
    t = t + dt
    respawnTimer = respawnTimer + dt
    if respawnTimer >= RESPAWN_EVERY then
        respawnTimer = respawnTimer - RESPAWN_EVERY
        fire()
    end
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.age = b.age + dt
        if b.age > LIFETIME then
            table.remove(bullets, i)
        end
    end
end

function love.draw()
    love.graphics.clear(0.05, 0.05, 0.07)
    for i = 1, #bullets do
        local b = bullets[i]
        local tint = AXIS_TINT[b.color_axis] or { 1, 1, 1 }
        local fade = 1 - (b.age / LIFETIME)
        love.graphics.setColor(tint[1], tint[2], tint[3], fade)
        love.graphics.circle("fill", b.x, b.y, 4)
    end

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("Pattern: " .. currentName .. "   bullets: " .. #bullets, 16, 12)
    love.graphics.print("1 radial  2 spiral  3 flower  4 aimed  5 wall+gap  6 composite  SPACE re-fire  ESC quit",
        16, 32)
    love.graphics.print("(aimed/composite target = mouse cursor)", 16, 52)

    -- Origin marker.
    love.graphics.setColor(1, 1, 0.4, 0.8)
    love.graphics.circle("line", cx, cy, 6)
end

local keyMap = {
    ["1"] = "radial", ["2"] = "spiral", ["3"] = "flower",
    ["4"] = "aimed", ["5"] = "wall", ["6"] = "composite",
}

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        fire()
    elseif keyMap[key] then
        currentName = keyMap[key]
        bullets = {}
        respawnTimer = 0
        fire()
    end
end
