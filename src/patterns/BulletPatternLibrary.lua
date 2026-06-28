-- BulletPatternLibrary: standalone, self-contained bullet-pattern generators.
--
-- This is a PURE pattern-generation library, intentionally decoupled from the
-- running game. It is NOT the live attack module (that is src/data/BulletPatterns.lua,
-- which resolves colors/damage and is wired into BossBehaviors). This module is meant to
-- be integrated later; for now nothing in the runtime requires it.
--
-- Contract for every generator:
--   fn(origin, t, params) -> { descriptor, descriptor, ... }
--     origin  : table {x = number, y = number} -- spawn point
--     t       : number                         -- a caller-supplied time/phase value
--     params  : table                          -- plain tunables (see each function)
--   descriptor : { x, y, vx, vy, color_axis }  -- inert data only
--
-- Some generators add optional pass-through fields the future renderer can dispatch on:
--   * `type`         : "bullet" | "telegraph" (absent => a normal bullet)
--   * `marker_style` : "outline" | "bright" | "dim" -- shape/luminance INTENT for telegraphs,
--                      never resolved to a color/luminance here (must survive the reactive bg)
--   * `gap_height`   : px size of a telegraphed refuge, so a renderer can size the marker
-- These are inert placeholders only; this module draws nothing and resolves nothing.
--
-- Guarantees:
--   * No live entities are created; descriptors are plain tables.
--   * No global state is mutated; no love.*, Config, or MathUtils dependency.
--   * No rendering, collision, color resolution, or audio/beat logic.
--   * `color_axis` is a pure pass-through placeholder (e.g. "bass"/"mids"/"treble" or nil);
--     it is never resolved to a color here.
--   * Output is fully deterministic. Randomness only occurs when a `seed` is supplied,
--     and it flows through a self-contained RNG so runs are reproducible.
--   * Every value a future audio driver might modulate (count, speed, angular step,
--     density, spread, gap width, ...) is a plain argument now -- no reactive hooks.
local BulletPatternLibrary = {}

local TWO_PI = math.pi * 2

-- Cross-version atan2: LuaJIT/Lua 5.1 expose math.atan2; Lua 5.3+ fold it into math.atan.
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

-- Build one inert spawn descriptor. color_axis defaults to nil (placeholder only).
local function descriptor(x, y, vx, vy, color_axis)
    return { x = x, y = y, vx = vx, vy = vy, color_axis = color_axis }
end

-- A pillar bullet: descends straight down (vx = 0), tagged so a merged list can tell it
-- apart from telegraph markers. type is the only addition over a plain descriptor.
local function pillarBullet(x, y, vy, color_axis)
    return { x = x, y = y, vx = 0, vy = vy, color_axis = color_axis, type = "bullet" }
end

-- A telegraph marker: a static (vx = vy = 0) indicator at a safe-gap location. marker_style
-- and gap_height are inert pass-throughs for the future renderer (shape/luminance intent +
-- refuge size); nothing is resolved here.
local function telegraphMarker(x, y, color_axis, marker_style, gap_height)
    return {
        x = x, y = y, vx = 0, vy = 0, color_axis = color_axis,
        type = "telegraph", marker_style = marker_style, gap_height = gap_height,
    }
end

-- Self-contained deterministic RNG (LCG, Numerical Recipes constants). Returns a closure
-- yielding floats in [0, 1). Does NOT touch math.random / love.math, so it never mutates
-- global RNG state and is reproducible from its seed alone.
local function newRng(seed)
    -- Force an integer state: a float seed would degrade the LCG's integer arithmetic.
    local state = math.floor(seed or 0) % 2147483648
    return function()
        state = (1103515245 * state + 12345) % 2147483648
        return state / 2147483648
    end
end
BulletPatternLibrary.newRng = newRng

-- Optional symmetric jitter in [-amount, amount], gated entirely on a seed being present.
-- Without a seed this is a no-op, keeping patterns deterministic by default.
local function maybeJitter(rng, amount)
    if not rng or not amount or amount == 0 then return 0 end
    return (rng() * 2 - 1) * amount
end

-- Radial: even 360 degree spread.
-- params: count (12), baseAngle (0), speed (220), color_axis (nil),
--         seed (nil), angleJitter (0, radians; requires seed to take effect)
function BulletPatternLibrary.radial(origin, t, params)
    params = params or {}
    local count = params.count or 12
    local baseAngle = params.baseAngle or 0
    local speed = params.speed or 220
    local color_axis = params.color_axis
    local rng = params.seed and newRng(params.seed) or nil
    local jitter = params.angleJitter or 0

    local out = {}
    for i = 0, count - 1 do
        -- Full-circle step (2pi/count) tiles evenly with no duplicate bullet at the seam.
        local angle = baseAngle + i * (TWO_PI / count) + maybeJitter(rng, jitter)
        out[#out + 1] = descriptor(
            origin.x, origin.y,
            math.cos(angle) * speed, math.sin(angle) * speed,
            color_axis
        )
    end
    return out
end

-- Spiral: radial with a per-shot angular increment, swept by t.
-- params: count (16), baseAngle (0), angularStep (0.30), speed (250),
--         direction (+1 cw / -1 ccw), timeRate (1.0), color_axis (nil),
--         seed (nil), angleJitter (0)
function BulletPatternLibrary.spiral(origin, t, params)
    params = params or {}
    local count = params.count or 16
    local baseAngle = params.baseAngle or 0
    local angularStep = params.angularStep or 0.30
    local speed = params.speed or 250
    local direction = params.direction or 1
    local timeRate = params.timeRate or 1.0
    local color_axis = params.color_axis
    local rng = params.seed and newRng(params.seed) or nil
    local jitter = params.angleJitter or 0
    t = t or 0

    local out = {}
    for i = 0, count - 1 do
        -- t advances the whole fan over time without any internal clock.
        local angle = baseAngle + direction * (i * angularStep + t * timeRate)
            + maybeJitter(rng, jitter)
        out[#out + 1] = descriptor(
            origin.x, origin.y,
            math.cos(angle) * speed, math.sin(angle) * speed,
            color_axis
        )
    end
    return out
end

-- Flower / petal: symmetric multi-arm burst.
-- arms are evenly spaced (2pi/arms); within each arm, perArm bullets fan symmetrically
-- about the arm axis across `spread`; the whole flower is rotated by t * drift.
-- params: arms (5), perArm (3), baseAngle (0), spread (0.5), speed (240),
--         drift (0), color_axis (nil), seed (nil), angleJitter (0)
function BulletPatternLibrary.flower(origin, t, params)
    params = params or {}
    local arms = params.arms or 5
    local perArm = params.perArm or 3
    local baseAngle = params.baseAngle or 0
    local spread = params.spread or 0.5
    local speed = params.speed or 240
    local drift = params.drift or 0
    local color_axis = params.color_axis
    local rng = params.seed and newRng(params.seed) or nil
    local jitter = params.angleJitter or 0
    t = t or 0

    local rotation = baseAngle + t * drift
    local out = {}
    for arm = 0, arms - 1 do
        local armAxis = rotation + arm * (TWO_PI / arms)
        for j = 0, perArm - 1 do
            -- Symmetric fan about the arm axis: offset spans [-spread/2, +spread/2].
            local offset = (perArm == 1) and 0
                or (j / (perArm - 1) - 0.5) * spread
            local angle = armAxis + offset + maybeJitter(rng, jitter)
            out[#out + 1] = descriptor(
                origin.x, origin.y,
                math.cos(angle) * speed, math.sin(angle) * speed,
                color_axis
            )
        end
    end
    return out
end

-- Aimed: a fan fired toward a supplied target point.
-- params: targetX (required), targetY (required), count (5), spread (0.4),
--         speed (300), color_axis (nil), seed (nil), angleJitter (0)
function BulletPatternLibrary.aimed(origin, t, params)
    params = params or {}
    local targetX = params.targetX or origin.x
    local targetY = params.targetY or origin.y
    local count = params.count or 5
    local spread = params.spread or 0.4
    local speed = params.speed or 300
    local color_axis = params.color_axis
    local rng = params.seed and newRng(params.seed) or nil
    local jitter = params.angleJitter or 0

    local aim = atan2(targetY - origin.y, targetX - origin.x)
    local out = {}
    for i = 0, count - 1 do
        -- Single bullet fires exactly on the aim line; otherwise spread symmetrically.
        local offset = (count == 1) and 0
            or (i / (count - 1) - 0.5) * spread
        local angle = aim + offset + maybeJitter(rng, jitter)
        out[#out + 1] = descriptor(
            origin.x, origin.y,
            math.cos(angle) * speed, math.sin(angle) * speed,
            color_axis
        )
    end
    return out
end

-- Wall-with-gap: a line of bullets with one or more safe lanes.
-- Bullets are placed evenly along a line of length `extent` centered on origin, oriented
-- by `axisAngle`, all moving perpendicular to the line at `speed`. Any bullet whose
-- normalized position (0..1 across the line) falls inside a gap is omitted (a safe lane).
-- params: count (21), extent (1600), axisAngle (0), speed (200),
--         gaps (list of {pos=0..1, width=0..1}, default one centered gap), color_axis (nil)
function BulletPatternLibrary.wallWithGap(origin, t, params)
    params = params or {}
    local count = params.count or 21
    local extent = params.extent or 1600
    local axisAngle = params.axisAngle or 0
    local speed = params.speed or 200
    local gaps = params.gaps or { { pos = 0.5, width = 0.12 } }
    local color_axis = params.color_axis

    -- Direction along the wall, and the perpendicular (travel) direction.
    local ax, ay = math.cos(axisAngle), math.sin(axisAngle)
    local px, py = -ay, ax
    local vx, vy = px * speed, py * speed

    local function inGap(u)
        for g = 1, #gaps do
            local gap = gaps[g]
            if math.abs(u - gap.pos) <= (gap.width * 0.5) then
                return true
            end
        end
        return false
    end

    local out = {}
    for i = 0, count - 1 do
        local u = (count == 1) and 0.5 or i / (count - 1) -- normalized position 0..1
        if not inGap(u) then
            local offset = (u - 0.5) * extent -- signed distance from center
            out[#out + 1] = descriptor(
                origin.x + ax * offset, origin.y + ay * offset,
                vx, vy,
                color_axis
            )
        end
    end
    return out
end

-- Pillars: vertical columns (a "curtain") with telegraphed safe gaps.
--
-- Each pillar is a column at a fixed x with bullets sampled down the play-field height; a
-- safe gap is a normalized vertical band (pos, width in 0..1 of the column) left empty -- a
-- horizontal lane the player slides into. The vertical analog of wallWithGap, plus descent.
--
-- Two-stage output driven by the caller-supplied `t` (NOT an internal timer):
--   warning stage (t < telegraph_duration): emits one telegraph marker per gap per pillar at
--     the gap CENTER, so the refuge location is shown before bullets appear.
--   resolve stage (t >= telegraph_duration): emits the descending bullets, skipping gap bands.
-- The stage may also be forced via params.stage ("warning"/"resolve").
--
-- params:
--   pillarCount (4)
--   x placement (first match wins): xs (list) | xGen(i, count) (function) |
--       auto even cell-centers across [fieldLeft, fieldRight]
--   fieldLeft (0), fieldRight (1920), fieldTop (0), fieldBottom (1080)
--   density (first match wins): bulletsPerPillar (N) | spacing (px, default 48)
--   descendSpeed (200) -> bullet vy
--   gaps (first match wins): gapsFor(p, x) (function->list) | gapsPerPillar (table by p) |
--       gaps (one list for all) | default {{pos=0.5, width=0.16}}; gap = {pos 0..1, width 0..1}
--   telegraph_duration (0.8) -- plain numeric warning lead time; not beat-synced
--   marker_style ("outline"), color_axis (nil), stage (optional override)
-- `origin` is accepted for signature/contract uniformity; pillar geometry uses field params.
function BulletPatternLibrary.pillars(origin, t, params)
    params = params or {}
    t = t or 0
    -- Default the count to the supplied xs length so explicit positions are never truncated.
    local pillarCount = params.pillarCount or (type(params.xs) == "table" and #params.xs) or 4
    local fieldLeft = params.fieldLeft or 0
    local fieldRight = params.fieldRight or 1920
    local fieldTop = params.fieldTop or 0
    local fieldBottom = params.fieldBottom or 1080
    local descendSpeed = params.descendSpeed or 200
    local telegraphDuration = params.telegraph_duration or 0.8
    local markerStyle = params.marker_style or "outline"
    local color_axis = params.color_axis
    local extent = fieldBottom - fieldTop

    -- Resolve pillar x positions.
    local xs = {}
    if type(params.xs) == "table" then
        for i = 1, pillarCount do xs[i] = params.xs[i] end
    elseif type(params.xGen) == "function" then
        for i = 1, pillarCount do xs[i] = params.xGen(i, pillarCount) end
    else
        -- Even cell-centers: the i-th of pillarCount columns sits at the middle of its slice.
        local width = fieldRight - fieldLeft
        for i = 1, pillarCount do
            xs[i] = fieldLeft + (i - 0.5) / pillarCount * width
        end
    end

    -- Resolve the gap list for a given pillar.
    local function gapsForPillar(p, x)
        if type(params.gapsFor) == "function" then
            return params.gapsFor(p, x) or {}
        elseif type(params.gapsPerPillar) == "table" then
            return params.gapsPerPillar[p] or {}
        elseif type(params.gaps) == "table" then
            return params.gaps
        end
        return { { pos = 0.5, width = 0.16 } }
    end

    local function inGap(u, gaps)
        for g = 1, #gaps do
            if math.abs(u - gaps[g].pos) <= (gaps[g].width * 0.5) then
                return true
            end
        end
        return false
    end

    local stage = params.stage
    if not stage then
        stage = (t < telegraphDuration) and "warning" or "resolve"
    end

    local out = {}

    if stage == "warning" then
        for p = 1, pillarCount do
            local x = xs[p]
            local gaps = gapsForPillar(p, x)
            for g = 1, #gaps do
                local gy = fieldTop + gaps[g].pos * extent
                local gh = gaps[g].width * extent
                out[#out + 1] = telegraphMarker(x, gy, color_axis, markerStyle, gh)
            end
        end
        return out
    end

    -- resolve stage: build the column sampling (normalized u positions top->bottom).
    local us = {}
    if params.bulletsPerPillar then
        local n = params.bulletsPerPillar
        for j = 0, n - 1 do
            us[#us + 1] = (n == 1) and 0.5 or j / (n - 1)
        end
    else
        local spacing = params.spacing or 48
        local steps = math.max(1, math.floor(extent / spacing)) -- inclusive of both ends
        for j = 0, steps do
            us[#us + 1] = j * spacing / extent
        end
    end

    for p = 1, pillarCount do
        local x = xs[p]
        local gaps = gapsForPillar(p, x)
        for j = 1, #us do
            local u = us[j]
            if not inGap(u, gaps) then
                out[#out + 1] = pillarBullet(x, fieldTop + u * extent, descendSpeed, color_axis)
            end
        end
    end
    return out
end

-- Composite: merge N already-generated descriptor lists into one new flat list.
-- Pure: input lists are never mutated. Patterns compose by calling each generator and
-- passing the results here, so layered boss attacks can be assembled later.
-- opts.softCap (600): soft readability ceiling. On overflow, opts.onOverflow(total, cap)
-- is called if provided, else a warning is written to io.stderr. Never throws.
-- Returns: merged, total, overCap
function BulletPatternLibrary.composite(lists, opts)
    if type(lists) ~= "table" then return {}, 0, false end
    opts = opts or {}
    local softCap = opts.softCap or 600

    local merged = {}
    for l = 1, #lists do
        local list = lists[l]
        for d = 1, #list do
            merged[#merged + 1] = list[d]
        end
    end

    local total = #merged
    local overCap = total > softCap
    if overCap then
        if opts.onOverflow then
            opts.onOverflow(total, softCap)
        else
            io.stderr:write(string.format(
                "[BulletPatternLibrary] composite bullet count %d exceeds soft cap %d (readability)\n",
                total, softCap))
        end
    end
    return merged, total, overCap
end

return BulletPatternLibrary
