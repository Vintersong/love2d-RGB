-- Unit tests for src/patterns/BulletPatternLibrary.lua
--
-- Standalone: depends only on plain Lua (LuaJIT / Lua 5.1+ / 5.3+), never on LÖVE or the
-- game runtime. Run from the repo root:
--     luajit tools/patterns/tests.lua      (or)   lua tools/patterns/tests.lua
-- Prints "OK (n passed)" and exits 0 on success; prints the failure and exits 1 otherwise.

-- Resolve the repo root from this file's path so `require("src...")` works from anywhere.
local here = arg and arg[0] or "tools/patterns/tests.lua"
local root = here:gsub("[/\\]tools[/\\]patterns[/\\]tests%.lua$", "")
if root == here then root = "." end
package.path = root .. "/?.lua;" .. package.path

local BPL = require("src.patterns.BulletPatternLibrary")

local EPS = 1e-9
local passed = 0

local function fail(msg)
    io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    os.exit(1)
end

local function ok(cond, msg)
    if cond then
        passed = passed + 1
    else
        fail(msg)
    end
end

local function assertEqual(a, b, msg)
    ok(a == b, string.format("%s (expected %s, got %s)", msg, tostring(b), tostring(a)))
end

local function assertNear(a, b, msg, eps)
    eps = eps or 1e-6
    ok(math.abs(a - b) <= eps, string.format("%s (expected ~%s, got %s)", msg, tostring(b), tostring(a)))
end

local TWO_PI = math.pi * 2
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

-- Angle of a descriptor's velocity, normalized to [0, 2pi).
local function velAngle(d)
    local a = atan2(d.vy, d.vx) % TWO_PI
    return a
end

local function speedOf(d)
    return math.sqrt(d.vx * d.vx + d.vy * d.vy)
end

local origin = { x = 100, y = 200 }

-- ---------------------------------------------------------------------------
-- radial
-- ---------------------------------------------------------------------------
do
    local r = BPL.radial(origin, 0, { count = 12, speed = 220 })
    assertEqual(#r, 12, "radial: count")

    -- Known input: count=4, baseAngle=0 -> velocity angles {0, 90, 180, 270} deg.
    local r4 = BPL.radial(origin, 0, { count = 4, baseAngle = 0, speed = 150 })
    local expected = { 0, math.pi / 2, math.pi, 3 * math.pi / 2 }
    for i = 1, 4 do
        assertNear(velAngle(r4[i]), expected[i], "radial: angle " .. i)
        assertNear(speedOf(r4[i]), 150, "radial: speed " .. i)
        assertEqual(r4[i].x, origin.x, "radial: spawn x " .. i)
        assertEqual(r4[i].y, origin.y, "radial: spawn y " .. i)
    end

    -- Symmetry: consecutive angles are evenly spaced by 2pi/count.
    local n = 9
    local rn = BPL.radial(origin, 0, { count = n, baseAngle = 0.3 })
    for i = 1, n - 1 do
        local diff = (velAngle(rn[i + 1]) - velAngle(rn[i])) % TWO_PI
        assertNear(diff, TWO_PI / n, "radial: even spacing " .. i)
    end

    -- color_axis is a pure pass-through.
    local rc = BPL.radial(origin, 0, { count = 3, color_axis = "bass" })
    for i = 1, 3 do assertEqual(rc[i].color_axis, "bass", "radial: color_axis passthrough") end
    local rnil = BPL.radial(origin, 0, { count = 3 })
    assertEqual(rnil[1].color_axis, nil, "radial: color_axis defaults nil")
end

-- ---------------------------------------------------------------------------
-- spiral
-- ---------------------------------------------------------------------------
do
    local s = BPL.spiral(origin, 0, { count = 16, angularStep = 0.3, baseAngle = 0 })
    assertEqual(#s, 16, "spiral: count")
    -- Per-shot increment equals angularStep at t=0.
    for i = 1, 15 do
        local diff = (velAngle(s[i + 1]) - velAngle(s[i])) % TWO_PI
        assertNear(diff, 0.3, "spiral: angular step " .. i)
    end
    -- t sweeps the whole fan by direction * t * timeRate.
    local s0 = BPL.spiral(origin, 0, { count = 4, angularStep = 0.2, baseAngle = 0, timeRate = 1 })
    local s1 = BPL.spiral(origin, 0.5, { count = 4, angularStep = 0.2, baseAngle = 0, timeRate = 1 })
    for i = 1, 4 do
        local diff = (velAngle(s1[i]) - velAngle(s0[i])) % TWO_PI
        assertNear(diff, 0.5, "spiral: t sweep " .. i)
    end
    -- direction = -1 reverses the increment sign.
    local sccw = BPL.spiral(origin, 0, { count = 3, angularStep = 0.4, baseAngle = 0, direction = -1 })
    local diff = (velAngle(sccw[2]) - velAngle(sccw[1])) % TWO_PI
    assertNear(diff, TWO_PI - 0.4, "spiral: direction reversed")
end

-- ---------------------------------------------------------------------------
-- flower
-- ---------------------------------------------------------------------------
do
    local arms, perArm = 5, 3
    local f = BPL.flower(origin, 0, { arms = arms, perArm = perArm, spread = 0.5 })
    assertEqual(#f, arms * perArm, "flower: count == arms*perArm")

    -- Rotational symmetry: the set of velocity directions is invariant under rotation by
    -- 2pi/arms. Test it directly on direction VECTORS (robust to the 0/2pi angle seam):
    -- rotate each bullet's unit velocity by one arm-spacing and assert a matching direction
    -- exists in the original set.
    local function units(list)
        local u = {}
        for i = 1, #list do
            local d = list[i]
            local m = math.sqrt(d.vx * d.vx + d.vy * d.vy)
            u[i] = { d.vx / m, d.vy / m }
        end
        return u
    end
    local base = units(f)
    local phi = TWO_PI / arms
    local ca, sa = math.cos(phi), math.sin(phi)
    for i = 1, #base do
        local rx = base[i][1] * ca - base[i][2] * sa
        local ry = base[i][1] * sa + base[i][2] * ca
        local found = false
        for j = 1, #base do
            if math.abs(base[j][1] - rx) < 1e-6 and math.abs(base[j][2] - ry) < 1e-6 then
                found = true
                break
            end
        end
        ok(found, "flower: rotational symmetry (rotated dir present) " .. i)
    end

    -- Per-arm fan is symmetric about the arm axis: for perArm=3 the middle bullet sits on
    -- the axis and the outer two are mirror images (+/- spread/2).
    local f3 = BPL.flower(origin, 0, { arms = 1, perArm = 3, spread = 0.6, baseAngle = 0 })
    assertNear(velAngle(f3[2]), 0, "flower: center bullet on axis")
    local left = velAngle(f3[1])
    local right = velAngle(f3[3])
    -- left ~ -0.3 (i.e. 2pi-0.3), right ~ +0.3; their offsets from axis are mirrored.
    assertNear((left - TWO_PI), -0.3, "flower: left offset")
    assertNear(right, 0.3, "flower: right offset")

    -- drift rotates the flower over t.
    local fd0 = BPL.flower(origin, 0, { arms = 4, perArm = 1, drift = 1.0 })
    local fd1 = BPL.flower(origin, 0.25, { arms = 4, perArm = 1, drift = 1.0 })
    local d = (velAngle(fd1[1]) - velAngle(fd0[1])) % TWO_PI
    assertNear(d, 0.25, "flower: drift over t")
end

-- ---------------------------------------------------------------------------
-- aimed
-- ---------------------------------------------------------------------------
do
    -- Target due-east of origin -> center bullet angle ~ 0.
    local a = BPL.aimed(origin, 0, { targetX = origin.x + 500, targetY = origin.y, count = 5, spread = 0.4 })
    assertEqual(#a, 5, "aimed: count")
    -- count=5 is odd, so the middle (index 3) sits exactly on the aim line.
    assertNear(velAngle(a[3]), 0, "aimed: center on aim (east)")
    -- Fan symmetry about aim: outermost offsets mirror to +/- spread/2.
    assertNear(velAngle(a[5]), 0.2, "aimed: +half spread")
    assertNear((velAngle(a[1]) - TWO_PI), -0.2, "aimed: -half spread")

    -- Target due-north (screen y grows downward, so north is -y) -> aim ~ -pi/2.
    local an = BPL.aimed(origin, 0, { targetX = origin.x, targetY = origin.y - 300, count = 1 })
    assertEqual(#an, 1, "aimed: single count")
    assertNear(velAngle(an[1]), (3 * math.pi / 2), "aimed: single fires on aim (north)")
    assertNear(speedOf(an[1]), 300, "aimed: default speed")
end

-- ---------------------------------------------------------------------------
-- wallWithGap
-- ---------------------------------------------------------------------------
do
    -- count=21, single centered gap width 0.12 -> normalized positions within 0.06 of 0.5
    -- are removed. Positions are i/20 for i=0..20; |i/20 - 0.5| <= 0.06 -> i in {9,10,11}.
    local w = BPL.wallWithGap(origin, 0, { count = 21, extent = 2000, axisAngle = 0,
        gaps = { { pos = 0.5, width = 0.12 } } })
    assertEqual(#w, 21 - 3, "wallWithGap: count minus lane (3 removed)")

    -- All bullets travel perpendicular to a horizontal wall: velocity straight down (+y).
    for i = 1, #w do
        assertNear(w[i].vx, 0, "wallWithGap: vx perpendicular " .. i)
        assertNear(w[i].vy, 200, "wallWithGap: vy = speed " .. i)
    end

    -- Spawn positions lie along the x axis, centered on origin; extremes at +/- extent/2.
    assertNear(w[1].x, origin.x - 1000, "wallWithGap: left extreme x")
    assertNear(w[1].y, origin.y, "wallWithGap: y on axis")
    assertNear(w[#w].x, origin.x + 1000, "wallWithGap: right extreme x")

    -- No bullet survives inside the gap band.
    for i = 1, #w do
        local u = (w[i].x - (origin.x - 1000)) / 2000
        ok(math.abs(u - 0.5) > 0.06 - 1e-9, "wallWithGap: none inside gap")
    end

    -- Multiple gaps remove multiple lanes.
    local w2 = BPL.wallWithGap(origin, 0, { count = 21, extent = 2000,
        gaps = { { pos = 0.25, width = 0.08 }, { pos = 0.75, width = 0.08 } } })
    -- |i/20 - 0.25| <= 0.04 -> i in {4,5,6}? 0.20,0.25,0.30 -> dist .05,.0,.05 -> only i=5 within .04. So 1 each side.
    ok(#w2 < 21, "wallWithGap: multiple gaps remove bullets")
end

-- ---------------------------------------------------------------------------
-- determinism & seeding
-- ---------------------------------------------------------------------------
do
    -- No seed -> identical output across calls.
    local p = { count = 10, baseAngle = 0.7, speed = 213 }
    local a = BPL.radial(origin, 0, p)
    local b = BPL.radial(origin, 0, p)
    for i = 1, #a do
        ok(a[i].vx == b[i].vx and a[i].vy == b[i].vy, "determinism: no-seed reproducible " .. i)
    end

    -- Same seed -> identical jittered output; different seed -> differs somewhere.
    local s1a = BPL.radial(origin, 0, { count = 12, angleJitter = 0.2, seed = 42 })
    local s1b = BPL.radial(origin, 0, { count = 12, angleJitter = 0.2, seed = 42 })
    local same = true
    for i = 1, #s1a do
        if s1a[i].vx ~= s1b[i].vx or s1a[i].vy ~= s1b[i].vy then same = false end
    end
    ok(same, "seeding: same seed reproduces jitter")

    local s2 = BPL.radial(origin, 0, { count = 12, angleJitter = 0.2, seed = 99 })
    local differs = false
    for i = 1, #s1a do
        if s1a[i].vx ~= s2[i].vx or s1a[i].vy ~= s2[i].vy then differs = true end
    end
    ok(differs, "seeding: different seed changes jitter")

    -- Jitter without a seed is a no-op (stays deterministic / unjittered).
    local nj1 = BPL.radial(origin, 0, { count = 6, angleJitter = 0.5 })
    local nj2 = BPL.radial(origin, 0, { count = 6 })
    for i = 1, #nj1 do
        assertNear(velAngle(nj1[i]), velAngle(nj2[i]), "seeding: jitter no-op without seed " .. i)
    end
end

-- ---------------------------------------------------------------------------
-- composite
-- ---------------------------------------------------------------------------
do
    local a = BPL.radial(origin, 0, { count = 8 })
    local b = BPL.spiral(origin, 0, { count = 5 })
    local merged, total, overCap = BPL.composite({ a, b })
    assertEqual(total, 13, "composite: total == sum")
    assertEqual(#merged, 13, "composite: merged length")
    ok(not overCap, "composite: under default soft cap")

    -- Inputs are not mutated.
    assertEqual(#a, 8, "composite: input a untouched")
    assertEqual(#b, 5, "composite: input b untouched")

    -- Soft cap overflow sets the flag and triggers the callback (no stderr noise in test).
    local seenTotal, seenCap
    local big = BPL.radial(origin, 0, { count = 50 })
    local _, t2, over2 = BPL.composite({ big }, {
        softCap = 20,
        onOverflow = function(n, cap) seenTotal, seenCap = n, cap end,
    })
    ok(over2, "composite: overCap flag set past soft cap")
    assertEqual(t2, 50, "composite: overflow total")
    assertEqual(seenTotal, 50, "composite: onOverflow total arg")
    assertEqual(seenCap, 20, "composite: onOverflow cap arg")
end

print(string.format("OK (%d passed)", passed))
