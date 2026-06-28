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
local RingBoss = require("src.patterns.RingBoss")

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

-- ---------------------------------------------------------------------------
-- Pillars: a field-space pattern, so it gets a field renderer + a field-aware dump
-- (velocity scatter is meaningless for descending columns).
-- ---------------------------------------------------------------------------

-- Field-aware descriptor dump: shows the telegraph/bullet type and marker fields.
local function dumpPillar(descriptors, maxRows)
    maxRows = maxRows or #descriptors
    print(string.format("  %-3s %-8s %-8s %-5s %-6s %-10s %-8s %-7s %-6s",
        "#", "x", "y", "vx", "vy", "type", "style", "gapH", "axis"))
    for i = 1, math.min(#descriptors, maxRows) do
        local d = descriptors[i]
        print(string.format("  %-3d %-8.1f %-8.1f %-5.0f %-6.0f %-10s %-8s %-7s %-6s",
            i, d.x, d.y, d.vx, d.vy, tostring(d.type), tostring(d.marker_style),
            d.gap_height and string.format("%.0f", d.gap_height) or "-",
            tostring(d.color_axis)))
    end
    if #descriptors > maxRows then
        print(string.format("  ... (%d more)", #descriptors - maxRows))
    end
end

-- Render descriptors onto a downsampled play-field grid: 'o' bullets, 'T' telegraph markers.
-- Blank rows inside a column are the visible safe gap (the refuge).
local function fieldRender(descriptors, bounds, cols, rows)
    cols = cols or 48
    rows = rows or 20
    local grid = {}
    for r = 1, rows do
        grid[r] = {}
        for c = 1, cols do grid[r][c] = " " end
    end
    for i = 1, #descriptors do
        local d = descriptors[i]
        local fx = (d.x - bounds.left) / (bounds.right - bounds.left)
        local fy = (d.y - bounds.top) / (bounds.bottom - bounds.top)
        local c = 1 + math.floor(fx * (cols - 1) + 0.5)
        local r = 1 + math.floor(fy * (rows - 1) + 0.5)
        if r >= 1 and r <= rows and c >= 1 and c <= cols then
            if d.type == "telegraph" then
                grid[r][c] = "T" -- telegraph wins visually
            elseif grid[r][c] == " " then
                grid[r][c] = "o"
            end
        end
    end
    for r = 1, rows do
        print("  |" .. table.concat(grid[r]) .. "|")
    end
end

do
    local bounds = { left = 0, right = 1920, top = 0, bottom = 1080 }
    local pillarField = {
        pillarCount = 4, fieldLeft = 0, fieldRight = 1920, fieldTop = 0, fieldBottom = 1080,
        bulletsPerPillar = 22, gaps = { { pos = 0.45, width = 0.18 } },
        descendSpeed = 220, telegraph_duration = 0.8, color_axis = "bass",
    }

    print("")
    print("=== pillars WARNING stage (t=0 < telegraph_duration) ===")
    local warn = BPL.pillars({ x = 0, y = 0 }, 0, pillarField)
    dumpPillar(warn)
    print("  -- field (T = telegraph marker at the safe gap) --")
    fieldRender(warn, bounds)

    print("")
    print("=== pillars RESOLVE stage (t=1.0 >= telegraph_duration) ===")
    local res = BPL.pillars({ x = 0, y = 0 }, 1.0, pillarField)
    print(string.format("  %d bullets; columns descend (vy=220), gap band ~0.36..0.54 is empty", #res))
    dumpPillar(res, 6)
    print("  -- field (blank band inside each column = the refuge that was telegraphed) --")
    fieldRender(res, bounds)

    print("")
    print("=== pillars per-pillar gaps (staggered refuges), WARNING ===")
    local staggered = BPL.pillars({ x = 0, y = 0 }, 0, {
        pillarCount = 5, fieldLeft = 0, fieldRight = 1920, fieldTop = 0, fieldBottom = 1080,
        gapsPerPillar = {
            { { pos = 0.15, width = 0.12 } },
            { { pos = 0.35, width = 0.12 } },
            { { pos = 0.55, width = 0.12 } },
            { { pos = 0.75, width = 0.12 } },
            { { pos = 0.90, width = 0.12 } },
        },
    })
    fieldRender(staggered, bounds)

    print("")
    print("=== composite: pillar curtain (resolve) + radial ring (Phase 1 will layer these) ===")
    local ring = BPL.radial({ x = 960, y = 540 }, 0, { count = 16, speed = 200, color_axis = "mids" })
    local merged, total = BPL.composite({ res, ring }, { softCap = 600 })
    print(string.format("  total=%d (pillars %d + ring %d)", total, #res, #ring))
    fieldRender(merged, bounds)
end

-- ---------------------------------------------------------------------------
-- Final ring boss: 6/6 pillar choreography + the four ring phase layouts.
-- ---------------------------------------------------------------------------

-- Plot a 12-node ring around a core on a grid: '@' core, digits/letters = node index (0-9,a,b).
local function ringRender(nodes, center, bounds, cols, rows)
    cols = cols or 50
    rows = rows or 24
    local grid = {}
    for r = 1, rows do
        grid[r] = {}
        for c = 1, cols do grid[r][c] = " " end
    end
    local function plot(x, y, ch)
        local fc = (x - bounds.left) / (bounds.right - bounds.left)
        local fr = (y - bounds.top) / (bounds.bottom - bounds.top)
        local c = 1 + math.floor(fc * (cols - 1) + 0.5)
        local r = 1 + math.floor(fr * (rows - 1) + 0.5)
        if r >= 1 and r <= rows and c >= 1 and c <= cols then grid[r][c] = ch end
    end
    plot(center.x, center.y, "@")
    local glyphs = "0123456789ab"
    for i = 1, #nodes do
        plot(nodes[i].x, nodes[i].y, glyphs:sub(nodes[i].index + 1, nodes[i].index + 1))
    end
    for r = 1, rows do print("  " .. table.concat(grid[r])) end
end

do
    local fieldBounds = { left = 0, right = 1920, top = 0, bottom = 1080 }

    print("")
    print("=== RING BOSS P1: 6-top / 6-bottom pillar choreography (offset gaps + telegraph) ===")
    print("  banks fire in an alternating walk; top gaps independent from bottom gaps.")
    local choreoCfg = {
        columns = 6, fieldLeft = 0, fieldRight = 1920, fieldTop = 0, fieldBottom = 1080,
        nodeDelay = 0.18, telegraph_duration = 0.6, descendSpeed = 220, resolveWindow = 0.9,
        topGap = { pos = 0.30, width = 0.12 }, bottomGap = { pos = 0.62, width = 0.12 },
        color_axis = "bass",
    }
    for _, snap in ipairs({ 0.10, 0.55, 1.10 }) do
        local frame = RingBoss.pillarChoreography(snap, choreoCfg)
        print(string.format("  -- t=%.2f  (%d descriptors: T telegraph, o bullet) --", snap, #frame))
        fieldRender(frame, fieldBounds)
    end

    print("")
    print("=== RING BOSS P1: whole-tone gap generator (banks map to the two whole-tone scales) ===")
    local wtFrame = RingBoss.pillarChoreography(0.30, {
        columns = 6, fieldTop = 0, fieldBottom = 1080, nodeDelay = 0.0,
        telegraph_duration = 5, gapGenerator = "wholeTone", gapWidth = 0.10,
    })
    fieldRender(wtFrame, fieldBounds)

    -- The four ring phase layouts (emitter geometry reconfiguring around one core).
    local center = { x = 960, y = 540 }
    local maxR = 220 * 1.4 + 40
    local ringBounds = { left = center.x - maxR, right = center.x + maxR,
        top = center.y - maxR, bottom = center.y + maxR }
    for _, phaseId in ipairs({ 1, 2, 3, 4 }) do
        local nodes, cfg = RingBoss.phaseLayout(phaseId, center, 0.0, { baseRadius = 220 })
        print("")
        print(string.format("=== RING BOSS %s (%s): fireMode=%s  radiusScale=%.2f  coreVulnerable=%s ===",
            cfg.id, cfg.name, cfg.fireMode, cfg.radiusScale, tostring(cfg.coreVulnerable)))
        ringRender(nodes, center, ringBounds)
    end

    print("")
    print("=== RING BOSS P3 interval lasers: node pairs N semitones apart ===")
    for _, iv in ipairs({ { 7, "perfect fifth" }, { 6, "tritone" } }) do
        local pairs = RingBoss.intervalPairs(iv[1], 12)
        local parts = {}
        for i = 1, #pairs do parts[i] = "{" .. pairs[i].a .. "," .. pairs[i].b .. "}" end
        print(string.format("  interval=%d (%s): %d chords  %s", iv[1], iv[2], #pairs, table.concat(parts, " ")))
    end

    print("")
    print("=== RING BOSS win condition routing (flag-gated; default OFF keeps old wincon) ===")
    local function showWin(label, p)
        local won, reason = RingBoss.evaluateWincon(p)
        print(string.format("  %-46s -> won=%s reason=%s", label, tostring(won), tostring(reason)))
    end
    showWin("flag OFF, song ended (ORIGINAL track-completion)", { useRingWincon = false, songEnded = true })
    showWin("flag OFF, P4 core killed (ignored by old path)", { useRingWincon = false, phase = 4, coreDestroyed = true })
    showWin("flag ON, P4 core killed (NEW path)", { useRingWincon = true, phase = 4, coreDestroyed = true })
    showWin("flag ON, P3 core hit (core not yet vulnerable)", { useRingWincon = true, phase = 3, coreDestroyed = true })
    showWin("flag ON, song ended (ignored by new path)", { useRingWincon = true, songEnded = true })
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
