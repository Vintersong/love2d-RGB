-- LaserBeam.lua
-- P3 "interval laser" beams for the ring boss. A beam is a line segment with a two-stage
-- lifecycle driven by elapsed time (telegraph -> active -> done), mirroring the pattern
-- library's telegraph philosophy: warn where the danger is, THEN deal damage.
--
-- The geometry, lifecycle, and collision math are pure (no love, no globals) and unit-tested;
-- only :draw touches love and is called at runtime, so the module loads under plain Lua.
local LaserBeam = {}

-- Segment from `from` toward `to`, extended to `length` px (defaults to the from->to distance).
function LaserBeam.segment(from, to, length)
    local dx, dy = to.x - from.x, to.y - from.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d == 0 then
        return { x1 = from.x, y1 = from.y, x2 = from.x, y2 = from.y }
    end
    local len = length or d
    return { x1 = from.x, y1 = from.y, x2 = from.x + dx / d * len, y2 = from.y + dy / d * len }
end

-- Segment from (x,y) along a velocity/direction (vx,vy), extended to `length` px.
function LaserBeam.segmentFromVelocity(x, y, vx, vy, length)
    local d = math.sqrt(vx * vx + vy * vy)
    if d == 0 then
        return { x1 = x, y1 = y, x2 = x, y2 = y }
    end
    return { x1 = x, y1 = y, x2 = x + vx / d * length, y2 = y + vy / d * length }
end

-- Shortest distance from point (px,py) to the segment (clamped to the endpoints).
function LaserBeam.pointDistance(seg, px, py)
    local vx, vy = seg.x2 - seg.x1, seg.y2 - seg.y1
    local wx, wy = px - seg.x1, py - seg.y1
    local c1 = vx * wx + vy * wy
    if c1 <= 0 then
        return math.sqrt(wx * wx + wy * wy)
    end
    local c2 = vx * vx + vy * vy
    if c2 <= c1 then
        local dx, dy = px - seg.x2, py - seg.y2
        return math.sqrt(dx * dx + dy * dy)
    end
    local b = c1 / c2
    local bx, by = seg.x1 + b * vx, seg.y1 + b * vy
    local dx, dy = px - bx, py - by
    return math.sqrt(dx * dx + dy * dy)
end

-- Does the beam's hit band (halfWidth) cover the point?
function LaserBeam.hitsPoint(seg, px, py, halfWidth)
    return LaserBeam.pointDistance(seg, px, py) <= (halfWidth or 0)
end

-- Lifecycle stage from elapsed time: telegraph window (no damage) -> active (damage) -> done.
function LaserBeam.lifecycle(elapsed, telegraphTime, activeTime)
    if elapsed < telegraphTime then return "warning" end
    if elapsed < telegraphTime + activeTime then return "active" end
    return "done"
end

-- A live beam (plain data; no love). The caller advances it with LaserBeam.update.
function LaserBeam.new(seg, opts)
    opts = opts or {}
    return {
        seg = seg,
        elapsed = 0,
        phase = "warning",
        telegraphTime = opts.telegraphTime or 0.6,
        activeTime = opts.activeTime or 0.5,
        halfWidth = opts.halfWidth or 14,
        damage = opts.damage or 10,
        color_axis = opts.color_axis,
    }
end

function LaserBeam.update(beam, dt)
    beam.elapsed = beam.elapsed + dt
    beam.phase = LaserBeam.lifecycle(beam.elapsed, beam.telegraphTime, beam.activeTime)
    return beam.phase
end

function LaserBeam.isActive(beam) return beam.phase == "active" end
function LaserBeam.isDone(beam) return beam.phase == "done" end

-- Render (love): a thin dim line while telegraphing, a bright wide beam while active.
function LaserBeam.draw(beam, color)
    color = color or { 1, 0.3, 0.4 }
    local active = beam.phase == "active"
    love.graphics.setColor(color[1], color[2], color[3], active and 0.95 or 0.28)
    love.graphics.setLineWidth(active and beam.halfWidth * 1.4 or 2)
    love.graphics.line(beam.seg.x1, beam.seg.y1, beam.seg.x2, beam.seg.y2)
end

return LaserBeam
