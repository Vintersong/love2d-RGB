-- Text + ASCII preview harness for src/patterns/BulletPatternLibrary.lua
--
-- Standalone: plain Lua (LuaJIT / Lua 5.1+ / 5.3+), no LÖVE, no game runtime. It dumps the
-- spawn descriptors for each pattern and draws a small ASCII scatter of velocity directions
-- so the shape can be eyeballed in a terminal without launching the game.
--
-- Run from the repo root:
--     luajit tools/patterns/preview.lua     (or)   lua tools/patterns/preview.lua

local here = arg and arg[0] or "tools/patterns/preview.lua"
local root = here:gsub("[/\\]tools[/\\]patterns[/\\]preview%.lua$", "")
if root == here then root = "." end
package.path = root .. "/?.lua;" .. package.path

local BPL = require("src.patterns.BulletPatternLibrary")

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function deg(rad)
    return rad * 180 / math.pi
end

-- Print a numbered descriptor table.
local function dump(descriptors)
    print(string.format("  %-3s %-9s %-9s %-9s %-9s %-7s %-7s %-8s",
        "#", "x", "y", "vx", "vy", "ang", "spd", "axis"))
    for i = 1, #descriptors do
        local d = descriptors[i]
        local ang = deg(atan2(d.vy, d.vx)) % 360
        local spd = math.sqrt(d.vx * d.vx + d.vy * d.vy)
        print(string.format("  %-3d %-9.1f %-9.1f %-9.1f %-9.1f %-7.1f %-7.1f %-8s",
            i, d.x, d.y, d.vx, d.vy, ang, spd, tostring(d.color_axis)))
    end
end

-- Draw an ASCII scatter of unit velocity directions on a square grid (origin at center).
-- Useful for seeing radial evenness, spiral winding, flower arms, aimed fans, walls/gaps.
local function scatter(descriptors, size)
    size = size or 21
    local half = math.floor(size / 2)
    local grid = {}
    for r = 1, size do
        grid[r] = {}
        for c = 1, size do grid[r][c] = " " end
    end
    grid[half + 1][half + 1] = "+" -- origin marker

    for i = 1, #descriptors do
        local d = descriptors[i]
        local mag = math.sqrt(d.vx * d.vx + d.vy * d.vy)
        if mag > 0 then
            local ux, uy = d.vx / mag, d.vy / mag
            local c = half + 1 + math.floor(ux * half + 0.5)
            local r = half + 1 + math.floor(uy * half + 0.5)
            if r >= 1 and r <= size and c >= 1 and c <= size then
                grid[r][c] = (grid[r][c] == " " or grid[r][c] == "+") and "o" or "*"
            end
        end
    end

    for r = 1, size do
        print("  " .. table.concat(grid[r]))
    end
end

local origin = { x = 960, y = 540 } -- screen center at 1920x1080

local function section(title, descriptors)
    print("")
    print("=== " .. title .. "  (" .. #descriptors .. " bullets) ===")
    dump(descriptors)
    print("  -- direction scatter --")
    scatter(descriptors)
end

section("radial  count=12 speed=220 axis=bass",
    BPL.radial(origin, 0, { count = 12, speed = 220, color_axis = "bass" }))

section("spiral  count=16 step=0.30 t=0",
    BPL.spiral(origin, 0, { count = 16, angularStep = 0.30, speed = 250 }))

section("spiral  count=16 step=0.30 t=0.8 (swept)",
    BPL.spiral(origin, 0.8, { count = 16, angularStep = 0.30, speed = 250 }))

section("flower  arms=5 perArm=3 spread=0.5 axis=mids",
    BPL.flower(origin, 0, { arms = 5, perArm = 3, spread = 0.5, color_axis = "mids" }))

section("aimed  target=(1500,300) count=7 spread=0.5",
    BPL.aimed(origin, 0, { targetX = 1500, targetY = 300, count = 7, spread = 0.5 }))

section("wallWithGap  count=21 gap@0.5 w=0.12",
    BPL.wallWithGap(origin, 0, { count = 21, extent = 1600,
        gaps = { { pos = 0.5, width = 0.12 } } }))

-- Composite example: a radial ring layered with an aimed fan and a spiral.
do
    local layers = {
        BPL.radial(origin, 0, { count = 18, speed = 180, color_axis = "bass" }),
        BPL.aimed(origin, 0, { targetX = 200, targetY = 900, count = 9, spread = 0.6, color_axis = "treble" }),
        BPL.spiral(origin, 0.4, { count = 24, angularStep = 0.26, color_axis = "mids" }),
    }
    local merged, total, overCap = BPL.composite(layers, { softCap = 600 })
    section(string.format("composite  3 layers  total=%d overCap=%s", total, tostring(overCap)), merged)
end

-- Demonstrate the soft-cap warning path (writes to stderr, returns overCap=true).
do
    print("")
    print("=== soft-cap demo (expect a stderr warning below) ===")
    local huge = BPL.radial(origin, 0, { count = 700, speed = 100 })
    local _, total, overCap = BPL.composite({ huge }, { softCap = 600 })
    print(string.format("  composite total=%d overCap=%s", total, tostring(overCap)))
end

print("")
print("preview complete")
