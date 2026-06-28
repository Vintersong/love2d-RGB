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
-- pillars (vertical curtain with telegraphed safe gaps)
-- ---------------------------------------------------------------------------
do
    -- Shared field: 3 pillars at known x, height 0..1000, 11 bullets/pillar (u = j/10),
    -- one centered gap pos=0.5 width=0.2 -> band 0.4..0.6 removes u in {0.4, 0.5, 0.6}.
    local field = {
        pillarCount = 3, xs = { 200, 600, 1000 },
        fieldTop = 0, fieldBottom = 1000,
        bulletsPerPillar = 11,
        gaps = { { pos = 0.5, width = 0.2 } },
        descendSpeed = 300, telegraph_duration = 0.8,
    }
    local extent = 1000

    -- --- resolve stage: counts ---
    local res = BPL.pillars({ x = 0, y = 0 }, 1.0, field) -- t >= telegraph_duration
    assertEqual(#res, 3 * (11 - 3), "pillars: total resolve count (3 pillars x 8)")

    -- group bullets by pillar x; assert 8 each and gather their u positions.
    local byX = { [200] = {}, [600] = {}, [1000] = {} }
    for i = 1, #res do
        local b = res[i]
        assertEqual(b.type, "bullet", "pillars: resolve descriptor is a bullet")
        assertEqual(b.vx, 0, "pillars: bullet vx == 0")
        assertEqual(b.vy, 300, "pillars: bullet vy == descendSpeed")
        local list = byX[b.x]
        ok(list ~= nil, "pillars: bullet x matches a pillar")
        if list then list[#list + 1] = (b.y - field.fieldTop) / extent end
    end
    for _, x in ipairs({ 200, 600, 1000 }) do
        assertEqual(#byX[x], 8, "pillars: 8 bullets in pillar x=" .. x)
    end

    -- --- gap is actually empty + resolve fills everything except the gap ---
    -- Expected surviving u's for every pillar (gap removed 0.4/0.5/0.6).
    local expected = { 0, 0.1, 0.2, 0.3, 0.7, 0.8, 0.9, 1.0 }
    local got = byX[200]
    table.sort(got)
    assertEqual(#got, #expected, "pillars: surviving u count matches")
    for i = 1, #expected do
        assertNear(got[i], expected[i], "pillars: surviving u " .. i)
        ok(math.abs(got[i] - 0.5) > 0.1, "pillars: no bullet inside gap band " .. i)
    end
    -- (#present 8) + (#sampled-in-gap 3) == 11 sampled total.
    assertEqual(#got + 3, 11, "pillars: present + in-gap == sampled total")

    -- --- warning stage: telegraph markers align with gap centers ---
    local warn = BPL.pillars({ x = 0, y = 0 }, 0, field) -- t < telegraph_duration
    assertEqual(#warn, 3, "pillars: one telegraph marker per pillar")
    local seenX = { [200] = false, [600] = false, [1000] = false }
    for i = 1, #warn do
        local m = warn[i]
        assertEqual(m.type, "telegraph", "pillars: warning descriptor is a telegraph")
        assertEqual(m.vx, 0, "pillars: marker vx == 0")
        assertEqual(m.vy, 0, "pillars: marker vy == 0")
        assertEqual(m.marker_style, "outline", "pillars: default marker_style")
        assertNear(m.y, field.fieldTop + 0.5 * extent, "pillars: marker at gap center y")
        assertNear(m.gap_height, 0.2 * extent, "pillars: marker gap_height == width*extent")
        ok(seenX[m.x] == false, "pillars: marker x is a distinct pillar")
        seenX[m.x] = true
    end

    -- --- stage selection driven purely by t ---
    local early = BPL.pillars({ x = 0, y = 0 }, 0.79, field)
    local late = BPL.pillars({ x = 0, y = 0 }, 0.80, field)
    assertEqual(early[1].type, "telegraph", "pillars: t<dur -> telegraph")
    assertEqual(late[1].type, "bullet", "pillars: t>=dur -> bullet")
    -- explicit stage override wins over t.
    local forced = BPL.pillars({ x = 0, y = 0 }, 0, { pillarCount = 1, xs = { 5 }, stage = "resolve",
        fieldBottom = 1000, bulletsPerPillar = 5, gaps = {} })
    assertEqual(forced[1].type, "bullet", "pillars: stage override forces resolve")

    -- --- per-pillar gaps land at their own centers ---
    local pp = BPL.pillars({ x = 0, y = 0 }, 0, {
        pillarCount = 3, xs = { 200, 600, 1000 }, fieldTop = 0, fieldBottom = 1000,
        gapsPerPillar = {
            { { pos = 0.25, width = 0.1 } },
            { { pos = 0.50, width = 0.1 } },
            { { pos = 0.75, width = 0.1 } },
        },
    })
    assertEqual(#pp, 3, "pillars: per-pillar gaps -> one marker each")
    assertNear(pp[1].y, 250, "pillars: pillar 1 gap center")
    assertNear(pp[2].y, 500, "pillars: pillar 2 gap center")
    assertNear(pp[3].y, 750, "pillars: pillar 3 gap center")
    assertEqual(pp[1].x, 200, "pillars: pillar 1 x")
    assertEqual(pp[3].x, 1000, "pillars: pillar 3 x")

    -- --- spacing-based density (no gap) fills every sampled step ---
    local sp = BPL.pillars({ x = 0, y = 0 }, 1.0, {
        pillarCount = 1, xs = { 50 }, fieldTop = 0, fieldBottom = 1000,
        spacing = 100, gaps = {}, stage = "resolve",
    })
    -- steps = floor(1000/100) = 10 -> j = 0..10 -> 11 bullets.
    assertEqual(#sp, 11, "pillars: spacing density count (no gap)")

    -- --- auto even x placement (cell centers) ---
    local auto = BPL.pillars({ x = 0, y = 0 }, 0, {
        pillarCount = 4, fieldLeft = 0, fieldRight = 800, fieldTop = 0, fieldBottom = 1000,
    })
    -- markers in pillar order; x_i = (i-0.5)/4 * 800 -> 100, 300, 500, 700.
    local expX = { 100, 300, 500, 700 }
    for i = 1, 4 do assertNear(auto[i].x, expX[i], "pillars: auto cell-center x " .. i) end

    -- --- xGen function placement ---
    local gen = BPL.pillars({ x = 0, y = 0 }, 0, {
        pillarCount = 3, xGen = function(i) return i * 111 end, fieldBottom = 1000,
    })
    assertNear(gen[1].x, 111, "pillars: xGen x1")
    assertNear(gen[3].x, 333, "pillars: xGen x3")

    -- --- color_axis passthrough on both stages ---
    local cw = BPL.pillars({ x = 0, y = 0 }, 0, { pillarCount = 1, xs = { 5 }, color_axis = "bass" })
    assertEqual(cw[1].color_axis, "bass", "pillars: warning color_axis passthrough")
    local cr = BPL.pillars({ x = 0, y = 0 }, 1.0, { pillarCount = 1, xs = { 5 }, color_axis = "bass",
        fieldBottom = 1000, bulletsPerPillar = 3, gaps = {} })
    assertEqual(cr[1].color_axis, "bass", "pillars: resolve color_axis passthrough")
    assertEqual(cr[1].color_axis, "bass", "pillars: resolve color_axis passthrough 2")

    -- --- composites cleanly with the ring emitters (Phase 1 will run both at once) ---
    local ring = BPL.radial({ x = 500, y = 500 }, 0, { count = 8 })
    local merged, total = BPL.composite({ res, ring })
    assertEqual(total, #res + 8, "pillars: composite total == sum")
    assertEqual(#res, 24, "pillars: composite leaves pillar input untouched")
    -- types survive the merge (bullets from pillars, nil-type from radial).
    local telMerge = BPL.composite({ warn, ring })
    local tel = 0
    for i = 1, #telMerge do if telMerge[i].type == "telegraph" then tel = tel + 1 end end
    assertEqual(tel, 3, "pillars: telegraph type preserved through composite")
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
