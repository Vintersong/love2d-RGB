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
local RingBoss = require("src.patterns.RingBoss")

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

-- ---------------------------------------------------------------------------
-- RingBoss: phase configs + core vulnerability + phase transitions
-- ---------------------------------------------------------------------------
do
    assertEqual(RingBoss.isCoreVulnerable(RingBoss.PHASE.P1), false, "ring: P1 core invulnerable")
    assertEqual(RingBoss.isCoreVulnerable(RingBoss.PHASE.P2), false, "ring: P2 core invulnerable")
    assertEqual(RingBoss.isCoreVulnerable(RingBoss.PHASE.P3), false, "ring: P3 core invulnerable")
    assertEqual(RingBoss.isCoreVulnerable(RingBoss.PHASE.P4), true, "ring: P4 core vulnerable")

    -- HP-threshold transitions (default {0.75,0.5,0.25}).
    assertEqual(RingBoss.phaseForHealth(0.90), 1, "ring: 90% HP -> P1")
    assertEqual(RingBoss.phaseForHealth(0.60), 2, "ring: 60% HP -> P2")
    assertEqual(RingBoss.phaseForHealth(0.40), 3, "ring: 40% HP -> P3")
    assertEqual(RingBoss.phaseForHealth(0.10), 4, "ring: 10% HP -> P4")
    -- Custom thresholds are honored (parameterized, not hardcoded).
    assertEqual(RingBoss.phaseForHealth(0.55, { 0.6, 0.3, 0.1 }), 2, "ring: custom thresholds")
    -- External-trigger transitions clamp at P4.
    assertEqual(RingBoss.nextPhase(1), 2, "ring: nextPhase 1->2")
    assertEqual(RingBoss.nextPhase(4), 4, "ring: nextPhase clamps at P4")
end

-- ---------------------------------------------------------------------------
-- RingBoss: ring geometry
-- ---------------------------------------------------------------------------
do
    local nodes = RingBoss.ringNodes({ x = 0, y = 0 }, 100, 12, 0)
    assertEqual(#nodes, 12, "ring: 12 nodes")
    for i = 1, 12 do
        assertNear(math.sqrt(nodes[i].x ^ 2 + nodes[i].y ^ 2), 100, "ring: node on radius " .. i)
        assertEqual(nodes[i].semitone, i - 1, "ring: node semitone index " .. i)
    end
    -- Even angular spacing of 2pi/12.
    for i = 1, 11 do
        assertNear(nodes[i + 1].angle - nodes[i].angle, TWO_PI / 12, "ring: node spacing " .. i)
    end
end

-- ---------------------------------------------------------------------------
-- RingBoss: P3 interval-laser node pairing (fifth=7, tritone=6)
-- ---------------------------------------------------------------------------
do
    local function hasPair(pairs, a, b)
        local lo, hi = math.min(a, b), math.max(a, b)
        for i = 1, #pairs do
            if pairs[i].a == lo and pairs[i].b == hi then return true end
        end
        return false
    end

    -- Tritone (6 semitones apart): the maximally-dissonant axis -> 6 distinct dyads.
    local tri = RingBoss.intervalPairs(6, 12)
    assertEqual(#tri, 6, "ring: tritone -> 6 pairs")
    for i = 1, #tri do
        assertEqual(tri[i].b - tri[i].a, 6, "ring: tritone pair is 6 apart " .. i)
    end
    ok(hasPair(tri, 0, 6), "ring: tritone contains {0,6}")
    ok(hasPair(tri, 5, 11), "ring: tritone contains {5,11}")

    -- Perfect fifth (7 semitones apart) -> 12 distinct dyads (interval class 5).
    local fifth = RingBoss.intervalPairs(7, 12)
    assertEqual(#fifth, 12, "ring: fifth -> 12 pairs")
    for i = 1, #fifth do
        local d = fifth[i].b - fifth[i].a
        ok(d == 7 or d == (12 - 7), "ring: fifth pair spans 7 (or 5 wrapped) " .. i)
    end
    ok(hasPair(fifth, 0, 7), "ring: fifth contains {0,7}")
    ok(hasPair(fifth, 0, 5), "ring: fifth contains {0,5} (wrap of 7)")

    -- laserChords resolves pairs to node positions.
    local chords, pairs = RingBoss.laserChords(6, { x = 0, y = 0 }, { baseRadius = 100 })
    assertEqual(#chords, 6, "ring: tritone chords resolved to 6 node pairs")
    assertEqual(#pairs, 6, "ring: laserChords returns the pair index list too")
end

-- ---------------------------------------------------------------------------
-- RingBoss: 6/6 firing sequence order (data-driven)
-- ---------------------------------------------------------------------------
do
    local seq = RingBoss.firingSequence({ columns = 6, nodeDelay = 0.2 })
    assertEqual(#seq, 12, "ring: 6 columns x 2 banks = 12 firings")
    -- Default alternating walk (1-indexed columns): top c1, bottom c1, top c2, bottom c2, ...
    assertEqual(seq[1].bank, "top", "ring: seq[1] is top bank")
    assertEqual(seq[1].col, 1, "ring: seq[1] is column 1")
    assertEqual(seq[2].bank, "bottom", "ring: seq[2] is bottom bank")
    assertEqual(seq[2].col, 1, "ring: seq[2] is column 1")
    assertEqual(seq[3].bank, "top", "ring: seq[3] is top bank")
    assertEqual(seq[3].col, 2, "ring: seq[3] walks to column 2")
    -- fire times are monotonically increasing by nodeDelay.
    for i = 1, #seq do
        assertNear(seq[i].fireTime, (i - 1) * 0.2, "ring: fireTime step " .. i)
    end
    -- Sequence is reorderable via params.order.
    local custom = RingBoss.firingSequence({ nodeDelay = 0.1,
        order = { { bank = "bottom", col = 3 }, { bank = "top", col = 1 } } })
    assertEqual(#custom, 2, "ring: custom order length")
    assertEqual(custom[1].bank, "bottom", "ring: custom order respected (bank)")
    assertEqual(custom[1].col, 3, "ring: custom order respected (col)")
end

-- ---------------------------------------------------------------------------
-- RingBoss: top/bottom gap independence + telegraph alignment
-- ---------------------------------------------------------------------------
do
    -- Whole-tone generator maps banks to the two whole-tone scales (offset by construction).
    local topG = RingBoss.wholeToneGaps("top", 6)
    local botG = RingBoss.wholeToneGaps("bottom", 6)
    for c = 1, 6 do
        ok(math.abs(topG[c].pos - botG[c].pos) > 1e-6, "ring: whole-tone banks differ at col " .. c)
    end

    -- Drive the choreography so column-0's top and bottom pillars are BOTH in the warning
    -- window at once; their telegraph markers must sit at different y (independent gaps).
    local cfg = {
        columns = 1, fieldLeft = 0, fieldRight = 100, fieldTop = 0, fieldBottom = 1000,
        nodeDelay = 0.18, telegraph_duration = 0.7,
        topGap = { pos = 0.35, width = 0.14 }, bottomGap = { pos = 0.65, width = 0.14 },
    }
    local warn = RingBoss.pillarChoreography(0.25, cfg) -- top rel=0.25, bottom rel=0.07: both warning
    assertEqual(#warn, 2, "ring: both banks telegraph at col 0")
    local topMarker, botMarker
    for i = 1, #warn do
        assertEqual(warn[i].type, "telegraph", "ring: choreography warning is a telegraph " .. i)
        if warn[i].bank == "top" then topMarker = warn[i] else botMarker = warn[i] end
    end
    ok(topMarker and botMarker, "ring: one marker per bank")
    -- Telegraph alignment: marker y == fieldTop + gap.pos * extent (extent = 1000).
    assertNear(topMarker.y, 0.35 * 1000, "ring: top telegraph aligns to top gap center")
    assertNear(botMarker.y, 0.65 * 1000, "ring: bottom telegraph aligns to bottom gap center")
    ok(math.abs(topMarker.y - botMarker.y) > 1, "ring: top and bottom gaps are independent")
    assertEqual(topMarker.x, botMarker.x, "ring: same column -> same x (convergence axis)")

    -- Changing the top gap must not move the bottom gap (independence, not mirrored).
    local cfg2 = {
        columns = 1, fieldTop = 0, fieldBottom = 1000, nodeDelay = 0.18, telegraph_duration = 0.7,
        topGap = { pos = 0.10, width = 0.14 }, bottomGap = { pos = 0.65, width = 0.14 },
    }
    local warn2 = RingBoss.pillarChoreography(0.25, cfg2)
    local bot2
    for i = 1, #warn2 do if warn2[i].bank == "bottom" then bot2 = warn2[i] end end
    assertNear(bot2.y, 0.65 * 1000, "ring: bottom gap unchanged when top gap moves")
end

-- ---------------------------------------------------------------------------
-- RingBoss: choreography stage timing (driven by caller t)
-- ---------------------------------------------------------------------------
do
    local cfg = {
        columns = 1, fieldTop = 0, fieldBottom = 1000, nodeDelay = 0.18, telegraph_duration = 0.7,
        spacing = 100, topGap = { pos = 0.5, width = 0.2 }, bottomGap = { pos = 0.5, width = 0.2 },
        descendSpeed = 240,
    }
    -- Before anything fires: empty.
    assertEqual(#RingBoss.pillarChoreography(-1, cfg), 0, "ring: nothing before t=0")

    -- After both resolve (t large): bullets only, top descends (+vy), bottom rises (-vy).
    local res = RingBoss.pillarChoreography(5, cfg)
    ok(#res > 0, "ring: resolve emits bullets")
    local sawDown, sawUp = false, false
    for i = 1, #res do
        assertEqual(res[i].type, "bullet", "ring: resolved descriptor is a bullet " .. i)
        if res[i].bank == "top" then
            assertEqual(res[i].vy, 240, "ring: top bank descends")
            sawDown = true
        else
            assertEqual(res[i].vy, -240, "ring: bottom bank rises")
            sawUp = true
        end
        -- gap (pos 0.5, width 0.2 -> band 0.4..0.6) must be empty in both banks.
        local u = res[i].y / 1000
        ok(math.abs(u - 0.5) > 0.1, "ring: resolve leaves the safe gap empty " .. i)
    end
    ok(sawDown and sawUp, "ring: both banks resolve (down + up)")

    -- resolveWindow makes a node go inactive again after its bullets have flown.
    local windowed = RingBoss.pillarChoreography(5, {
        columns = 1, fieldTop = 0, fieldBottom = 1000, nodeDelay = 0.18,
        telegraph_duration = 0.7, resolveWindow = 0.2,
    })
    assertEqual(#windowed, 0, "ring: finite resolveWindow deactivates old nodes")
end

-- ---------------------------------------------------------------------------
-- RingBoss: win-condition flag routing (old vs new path)
-- ---------------------------------------------------------------------------
do
    -- flag OFF -> ORIGINAL path (track-completion): song end wins; core kill is ignored.
    local won, reason = RingBoss.evaluateWincon({ useRingWincon = false, songEnded = true })
    ok(won and reason == "song_end", "wincon: flag off + song end -> old path victory")
    won = RingBoss.evaluateWincon({ useRingWincon = false, songEnded = false,
        phase = 4, coreDestroyed = true })
    ok(not won, "wincon: flag off ignores P4 core kill")

    -- flag ON -> NEW path (P4 core kill): song end is ignored; core kill in P4 wins.
    won, reason = RingBoss.evaluateWincon({ useRingWincon = true, phase = 4, coreDestroyed = true })
    ok(won and reason == "ring_core_kill", "wincon: flag on + P4 core kill -> new path victory")
    won = RingBoss.evaluateWincon({ useRingWincon = true, phase = 4, coreDestroyed = false })
    ok(not won, "wincon: flag on but core not destroyed -> no win")
    won = RingBoss.evaluateWincon({ useRingWincon = true, phase = 3, coreDestroyed = true })
    ok(not won, "wincon: flag on but pre-P4 core not vulnerable -> no win")
    won = RingBoss.evaluateWincon({ useRingWincon = true, songEnded = true })
    ok(not won, "wincon: flag on ignores the old song-end signal")
end

-- ---------------------------------------------------------------------------
-- RingBoss: per-phase attack generation (emitters fire from the ring nodes)
-- ---------------------------------------------------------------------------
do
    local center = { x = 1000, y = 500 }
    local params = { baseRadius = 200, speed = 240 }

    -- P4: all 12 nodes fire inward simultaneously; each velocity points at the core.
    local p4 = RingBoss.phaseAttack(center, RingBoss.PHASE.P4, 0, params)
    assertEqual(#p4, 12, "phaseAttack: P4 fires all 12 nodes")
    for i = 1, #p4 do
        local b = p4[i]
        assertEqual(b.type, "bullet", "phaseAttack: P4 emits bullets " .. i)
        -- velocity points toward the core: dot((center - pos), v) > 0.
        local dot = (center.x - b.x) * b.vx + (center.y - b.y) * b.vy
        ok(dot > 0, "phaseAttack: P4 bullet aims inward " .. i)
        assertNear(math.sqrt(b.vx ^ 2 + b.vy ^ 2), 240, "phaseAttack: P4 speed " .. i)
    end

    -- P1: the firing origin walks the ring as t advances.
    local p1a = RingBoss.phaseAttack(center, RingBoss.PHASE.P1, 0.00, { baseRadius = 200, count = 6, nodeFireInterval = 0.1, rotateSpeed = 0 })
    local p1b = RingBoss.phaseAttack(center, RingBoss.PHASE.P1, 0.15, { baseRadius = 200, count = 6, nodeFireInterval = 0.1, rotateSpeed = 0 })
    assertEqual(#p1a, 6, "phaseAttack: P1 radial burst count")
    -- t=0 -> node 1 (angle 0) at (center.x + radius, center.y); all bullets share that origin.
    assertNear(p1a[1].x, center.x + 200, "phaseAttack: P1 origin on node 1 at t=0")
    assertNear(p1a[1].y, center.y, "phaseAttack: P1 origin y on node 1")
    -- t=0.15 with interval 0.1 -> node 2; origin moves off node 1.
    ok(math.abs(p1b[1].x - p1a[1].x) > 1e-6 or math.abs(p1b[1].y - p1a[1].y) > 1e-6,
        "phaseAttack: P1 origin walks the ring over t")

    -- P3: interval lasers -> a laser descriptor per paired node (both ends fire inward).
    local p3 = RingBoss.phaseAttack(center, RingBoss.PHASE.P3, 0, { baseRadius = 200, speed = 240, laserInterval = 7 })
    -- fifth = 12 pairs, each pair fires from both nodes -> 24 laser descriptors.
    assertEqual(#p3, 24, "phaseAttack: P3 fifth -> 24 laser ends")
    for i = 1, #p3 do
        assertEqual(p3[i].type, "laser", "phaseAttack: P3 emits lasers " .. i)
        assertEqual(p3[i].interval, 7, "phaseAttack: P3 carries interval " .. i)
    end
    local p3tri = RingBoss.phaseAttack(center, RingBoss.PHASE.P3, 0, { laserInterval = 6 })
    assertEqual(#p3tri, 12, "phaseAttack: P3 tritone -> 12 laser ends")

    -- The bridge realizes P4 bullets but skips P3 lasers (no Projectile for a beam).
    local PatternSpawner = require("src.combat.PatternSpawner")
    local function fakeFactory(x, y, vx, vy, d, pt, o) return { x = x, y = y, vx = vx, vy = vy, color = nil } end
    local sinkP4 = {}
    local spawnedP4 = PatternSpawner.spawn(p4, sinkP4, { factory = fakeFactory })
    assertEqual(spawnedP4, 12, "phaseAttack: bridge spawns all P4 bullets")
    local sinkP3 = {}
    local spawnedP3, skippedP3 = PatternSpawner.spawn(p3, sinkP3, { factory = fakeFactory })
    assertEqual(spawnedP3, 0, "phaseAttack: bridge spawns no laser bullets")
    assertEqual(skippedP3, 24, "phaseAttack: bridge skips all laser descriptors")
end

-- ---------------------------------------------------------------------------
-- RingBoss: synchronized 6/6 curtain volley (warning markers / resolve bullets)
-- ---------------------------------------------------------------------------
do
    local extent = 1000
    local params = {
        columns = 6, fieldLeft = 0, fieldRight = 1920, fieldTop = 0, fieldBottom = extent,
        bulletsPerColumn = 8,
        topGap = { pos = 0.30, width = 0.12 }, bottomGap = { pos = 0.64, width = 0.12 },
        descendSpeed = 200,
    }

    -- warning: one telegraph marker per column per bank -> 6 top + 6 bottom = 12.
    local warn = RingBoss.curtainVolley("warning", params)
    assertEqual(#warn, 12, "curtain: warning -> 12 telegraph markers")
    local topMarkers, botMarkers = 0, 0
    for i = 1, #warn do
        assertEqual(warn[i].type, "telegraph", "curtain: warning descriptor is telegraph " .. i)
        if warn[i].bank == "top" then
            topMarkers = topMarkers + 1
            assertNear(warn[i].y, 0.30 * extent, "curtain: top marker at top gap center " .. i)
        else
            botMarkers = botMarkers + 1
            assertNear(warn[i].y, 0.64 * extent, "curtain: bottom marker at bottom gap center " .. i)
        end
    end
    assertEqual(topMarkers, 6, "curtain: 6 top markers")
    assertEqual(botMarkers, 6, "curtain: 6 bottom markers")

    -- resolve: bullets; top bank descends (vy>0), bottom rises (vy<0); gap bands stay empty.
    local res = RingBoss.curtainVolley("resolve", params)
    ok(#res > 0, "curtain: resolve emits bullets")
    local sawTop, sawBottom = false, false
    for i = 1, #res do
        local b = res[i]
        local u = (b.y - params.fieldTop) / extent
        if b.bank == "top" then
            sawTop = true
            assertEqual(b.vy, 200, "curtain: top bullet descends")
            ok(math.abs(u - 0.30) > 0.06, "curtain: top gap band empty " .. i)
        else
            sawBottom = true
            assertEqual(b.vy, -200, "curtain: bottom bullet rises")
            ok(math.abs(u - 0.64) > 0.06, "curtain: bottom gap band empty " .. i)
        end
    end
    ok(sawTop and sawBottom, "curtain: both banks resolve to bullets")
end

-- ---------------------------------------------------------------------------
-- RingBoss: per-phase boss movement (P2 chases, others hold)
-- ---------------------------------------------------------------------------
do
    -- P2 (close_follow) chases the player: velocity points at the target at ~chaseSpeed.
    local vx, vy = RingBoss.phaseVelocity(RingBoss.PHASE.P2, 0, 0, 300, 0, { chaseSpeed = 150 })
    ok(vx > 0, "phaseVelocity: P2 moves toward target x")
    assertNear(vy, 0, "phaseVelocity: P2 stays on the target axis")
    assertNear(math.sqrt(vx ^ 2 + vy ^ 2), 150, "phaseVelocity: P2 uses chaseSpeed")

    -- Within the follow-stop band, the chaser holds.
    local sx, sy = RingBoss.phaseVelocity(RingBoss.PHASE.P2, 0, 0, 50, 0, { followStop = 80 })
    assertEqual(sx, 0, "phaseVelocity: P2 holds inside follow-stop (x)")
    assertEqual(sy, 0, "phaseVelocity: P2 holds inside follow-stop (y)")

    -- Non-follow phases hold position (the ring radius reconfigures, the body does not chase).
    for _, ph in ipairs({ RingBoss.PHASE.P1, RingBoss.PHASE.P3, RingBoss.PHASE.P4 }) do
        local hx, hy = RingBoss.phaseVelocity(ph, 0, 0, 500, 500)
        assertEqual(hx, 0, "phaseVelocity: phase " .. ph .. " holds x")
        assertEqual(hy, 0, "phaseVelocity: phase " .. ph .. " holds y")
    end
end

-- ---------------------------------------------------------------------------
-- RingBoss: boss-state attach / updatePhase (the entity reconfigures)
-- ---------------------------------------------------------------------------
do
    local boss = { health = 100, maxHealth = 100 }
    RingBoss.attach(boss, { phaseThresholds = { 0.75, 0.5, 0.25 } })
    assertEqual(boss.ringPhase, 1, "ring: attach starts at P1")
    assertEqual(boss.coreDestroyed, false, "ring: attach core intact")

    boss.health = 60
    RingBoss.updatePhase(boss)
    assertEqual(boss.ringPhase, 2, "ring: updatePhase -> P2 at 60% HP")

    boss.health = 10
    RingBoss.updatePhase(boss)
    assertEqual(boss.ringPhase, 4, "ring: updatePhase -> P4 at 10% HP")
    assertEqual(RingBoss.isCoreVulnerable(boss.ringPhase), true, "ring: core now vulnerable in P4")
end

-- ---------------------------------------------------------------------------
-- RingBoss: clamped phase progression (HP-gated, one step at a time, never skips)
-- ---------------------------------------------------------------------------
do
    local boss = { health = 100, maxHealth = 100 }
    RingBoss.attach(boss, {})
    assertEqual(boss.ringPhase, 1, "clampPhase: starts at P1")
    assertEqual(boss.ringPhaseTimer, 0, "clampPhase: attach zeroes the phase timer")

    -- Normal play: HP into the P2 band advances one phase (dwell satisfied).
    boss.health = 60
    RingBoss.advancePhaseClamped(boss, 2.0, 1.5) -- dwell met
    assertEqual(boss.ringPhase, 2, "clampPhase: 60% HP -> P2")

    -- BURST: drop straight to the P4 band. It must NOT jump to P4 -- one step per call.
    boss.health = 5
    RingBoss.advancePhaseClamped(boss, 2.0, 1.5)
    assertEqual(boss.ringPhase, 3, "clampPhase: burst steps P2 -> P3 (no skip)")
    RingBoss.advancePhaseClamped(boss, 2.0, 1.5)
    assertEqual(boss.ringPhase, 4, "clampPhase: next step -> P4")
    assertEqual(RingBoss.isCoreVulnerable(boss.ringPhase), true, "clampPhase: core vulnerable at P4")

    -- minDwell holds a phase until enough time has elapsed, even if HP says advance.
    local b2 = { health = 100, maxHealth = 100 }
    RingBoss.attach(b2, {})
    b2.health = 5 -- target P4
    RingBoss.advancePhaseClamped(b2, 0.5, 1.5) -- not enough dwell yet
    assertEqual(b2.ringPhase, 1, "clampPhase: holds P1 until minDwell elapses")
    RingBoss.advancePhaseClamped(b2, 1.0, 1.5) -- cumulative 1.5 -> advance one
    assertEqual(b2.ringPhase, 2, "clampPhase: advances one step once dwell met")

    -- Forward-only: phase never decreases if HP somehow rises (e.g. heal).
    local b3 = { health = 40, maxHealth = 100 }
    RingBoss.attach(b3, {})
    b3.ringPhase = 3
    b3.health = 90 -- would map to P1
    RingBoss.advancePhaseClamped(b3, 5, 0)
    assertEqual(b3.ringPhase, 3, "clampPhase: never steps backward")
end

-- ---------------------------------------------------------------------------
-- PatternSpawner bridge: descriptors -> live projectiles (love-free via fake factory)
-- ---------------------------------------------------------------------------
do
    local PatternSpawner = require("src.combat.PatternSpawner")
    -- Fake Projectile constructor: captures args, returns a mutable projectile-like table.
    local function fakeFactory(x, y, vx, vy, damage, projType, owner)
        return { x = x, y = y, vx = vx, vy = vy, damage = damage, projType = projType, owner = owner }
    end

    -- Pillar resolve stage -> bullets; prepend a telegraph marker to prove it is skipped.
    local descriptors = BPL.pillars({ x = 0, y = 0 }, 1.0, {
        pillarCount = 2, xs = { 100, 200 }, fieldTop = 0, fieldBottom = 1000,
        bulletsPerPillar = 5, gaps = { { pos = 0.5, width = 0.2 } }, descendSpeed = 300,
        color_axis = "mids",
    })
    local bulletCount = #descriptors
    table.insert(descriptors, 1, { x = 1, y = 2, vx = 0, vy = 0, type = "telegraph", marker_style = "outline" })

    local sink = {}
    local spawned, skipped = PatternSpawner.spawn(descriptors, sink, {
        factory = fakeFactory, damage = 12, projType = "boss_orb",
    })
    assertEqual(skipped, 1, "bridge: telegraph markers skipped")
    assertEqual(spawned, bulletCount, "bridge: every non-telegraph descriptor spawned")
    assertEqual(#sink, bulletCount, "bridge: sink length == spawned")

    local midsColor = PatternSpawner.AXIS_COLORS.mids
    for i = 1, #sink do
        assertEqual(sink[i].owner, "boss", "bridge: owner set")
        assertEqual(sink[i].projType, "boss_orb", "bridge: projType set")
        assertEqual(sink[i].damage, 12, "bridge: base damage applied")
        assertEqual(sink[i].vy, 300, "bridge: velocity carried through")
        assertEqual(sink[i].color, midsColor, "bridge: color_axis=mids resolved to mids color")
    end

    -- Colour precedence: explicit opts.color overrides the axis.
    local sink2 = {}
    PatternSpawner.spawn({ { x = 0, y = 0, vx = 0, vy = 1, color_axis = "bass" } }, sink2,
        { factory = fakeFactory, color = { 0.1, 0.2, 0.3 } })
    assertNear(sink2[1].color[1], 0.1, "bridge: explicit color overrides axis")

    -- A descriptor's own color (if present) beats axis resolution.
    local sink3 = {}
    PatternSpawner.spawn({ { x = 0, y = 0, vx = 0, vy = 1, color_axis = "bass", color = { 0.9, 0.9, 0.9 } } },
        sink3, { factory = fakeFactory })
    assertNear(sink3[1].color[1], 0.9, "bridge: descriptor color beats axis")

    -- nil axis -> default colour.
    local sink4 = {}
    PatternSpawner.spawn({ { x = 0, y = 0, vx = 0, vy = 1 } }, sink4, { factory = fakeFactory })
    assertEqual(sink4[1].color, PatternSpawner.DEFAULT_COLOR, "bridge: nil axis -> default color")

    -- Composability: a RingBoss choreography frame flows through the same bridge; warning-stage
    -- telegraph markers are skipped, leaving only the would-be bullets.
    local frame = RingBoss.pillarChoreography(0.05, { columns = 2, fieldTop = 0, fieldBottom = 1000,
        nodeDelay = 0.0, telegraph_duration = 5 }) -- all in warning stage -> all telegraphs
    local sink5 = {}
    local s5, t5 = PatternSpawner.spawn(frame, sink5, { factory = fakeFactory })
    assertEqual(s5, 0, "bridge: an all-warning choreography frame spawns no bullets")
    assertEqual(t5, #frame, "bridge: all warning descriptors counted as telegraphs")
end

-- ---------------------------------------------------------------------------
-- LaserBeam: P3 beam geometry, lifecycle, and point/segment collision (pure)
-- ---------------------------------------------------------------------------
do
    local LaserBeam = require("src.combat.LaserBeam")

    -- segment: from->to extended to a length.
    local seg = LaserBeam.segment({ x = 0, y = 0 }, { x = 10, y = 0 }, 20)
    assertNear(seg.x1, 0, "laser: seg start x")
    assertNear(seg.x2, 20, "laser: seg extended to length")
    assertNear(seg.y2, 0, "laser: seg stays on axis")

    -- segmentFromVelocity: direction normalized then scaled to length.
    local segv = LaserBeam.segmentFromVelocity(5, 5, 0, 3, 10) -- straight down
    assertNear(segv.x2, 5, "laser: velocity seg x unchanged")
    assertNear(segv.y2, 15, "laser: velocity seg extends by length")

    -- pointDistance: perpendicular, before-start, past-end, and on-line cases.
    local s = { x1 = 0, y1 = 0, x2 = 10, y2 = 0 }
    assertNear(LaserBeam.pointDistance(s, 5, 5), 5, "laser: perpendicular distance")
    assertNear(LaserBeam.pointDistance(s, -3, 0), 3, "laser: clamps to start point")
    assertNear(LaserBeam.pointDistance(s, 15, 0), 5, "laser: clamps to end point")
    assertNear(LaserBeam.pointDistance(s, 4, 0), 0, "laser: point on the segment")

    -- hitsPoint respects the half-width band.
    ok(LaserBeam.hitsPoint(s, 5, 6, 8), "laser: within band -> hit")
    ok(not LaserBeam.hitsPoint(s, 5, 6, 4), "laser: outside band -> miss")

    -- lifecycle: telegraph (warn) -> active -> done.
    assertEqual(LaserBeam.lifecycle(0.3, 0.6, 0.5), "warning", "laser: warning window")
    assertEqual(LaserBeam.lifecycle(0.8, 0.6, 0.5), "active", "laser: active window")
    assertEqual(LaserBeam.lifecycle(1.2, 0.6, 0.5), "done", "laser: done window")

    -- a live beam advances through the stages and only damages while active.
    local beam = LaserBeam.new(s, { telegraphTime = 0.6, activeTime = 0.5, halfWidth = 10, damage = 7 })
    assertEqual(beam.phase, "warning", "laser: new beam starts warning")
    LaserBeam.update(beam, 0.3)
    ok(not LaserBeam.isActive(beam), "laser: still warning at 0.3s (no damage)")
    LaserBeam.update(beam, 0.4) -- elapsed 0.7 -> active
    ok(LaserBeam.isActive(beam), "laser: active at 0.7s")
    LaserBeam.update(beam, 0.5) -- elapsed 1.2 -> done
    ok(LaserBeam.isDone(beam), "laser: done at 1.2s")
end

-- ---------------------------------------------------------------------------
-- Defensive guards (from PR review): malformed/nil inputs must not crash
-- ---------------------------------------------------------------------------
do
    local LaserBeam = require("src.combat.LaserBeam")

    -- composite tolerates nil / non-table.
    local m, n, over = BPL.composite(nil)
    assertEqual(#m, 0, "guard: composite(nil) -> empty")
    assertEqual(n, 0, "guard: composite(nil) total 0")
    assertEqual(over, false, "guard: composite(nil) not over cap")
    local m2 = BPL.composite("not a table")
    assertEqual(#m2, 0, "guard: composite(non-table) -> empty")

    -- LaserBeam helpers tolerate nil.
    assertEqual(LaserBeam.pointDistance(nil, 1, 2), 0, "guard: pointDistance(nil) -> 0")
    local zseg = LaserBeam.segment(nil, nil)
    assertEqual(zseg.x1, 0, "guard: segment(nil,nil) -> zero seg x1")
    assertEqual(zseg.x2, 0, "guard: segment(nil,nil) -> zero seg x2")
    local vseg = LaserBeam.segmentFromVelocity(nil, nil, nil, nil, nil)
    assertEqual(vseg.x1, 0, "guard: segmentFromVelocity(nil...) -> zero seg")

    -- RingBoss helpers tolerate nil / partial args.
    assertEqual(#RingBoss.defaultFiringOrder(), 12, "guard: defaultFiringOrder() defaults 6 columns")
    local pv1, pv2 = RingBoss.phaseVelocity(RingBoss.PHASE.P2, nil, nil, nil, nil)
    assertEqual(pv1, 0, "guard: phaseVelocity(nil coords) holds x")
    assertEqual(pv2, 0, "guard: phaseVelocity(nil coords) holds y")
    local pa = RingBoss.phaseAttack({}, RingBoss.PHASE.P4, 0, {})
    assertEqual(#pa, 12, "guard: phaseAttack(empty center) still fires 12")
    ok(pa[1].x == pa[1].x, "guard: phaseAttack(empty center) produces finite coords") -- not NaN
end

print(string.format("OK (%d passed)", passed))
