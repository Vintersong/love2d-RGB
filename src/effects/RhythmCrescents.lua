-- RhythmCrescents.lua
-- Pure visual: two crescent arcs flanking the player that act as a glow-gate beat
-- telegraph. Their brightness tracks MusicReactor.timingWindow (dark off-beat ->
-- bright in the perfect window), so the indicator and the reward tier are the same
-- signal. triggerBurst() plays a short outward flash on a successful on-beat dash.
-- Burst timing is self-contained (love.timer.getTime), so no per-frame update hook
-- is needed.

local Config = require("src.Config")

local RhythmCrescents = {}

local burstStart = -1
local burstTier = nil

-- Called from the dash activation when an on-beat bonus is earned.
function RhythmCrescents.triggerBurst(tier)
    burstStart = love.timer.getTime()
    burstTier = tier
end

local function resolveColor()
    local ColorSystem = require("src.gameplay.ColorSystem")
    local dom = ColorSystem.getDominantColor()
    local rgb = dom and ColorSystem.getColorRGB(dom)
    if rgb then
        return rgb
    end
    local Theme = require("src.render.Theme")
    return Theme.color.accent or {0, 0.85, 1}
end

-- Draw one crescent: an open arc centered at (cx, cy) facing `faceAngle`.
local function drawCrescent(cx, cy, radius, faceAngle, span, thickness, color, alpha)
    -- Soft glow pass, then bright core.
    love.graphics.setLineWidth(thickness * 2.6)
    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.35)
    love.graphics.arc("line", "open", cx, cy, radius, faceAngle - span, faceAngle + span, 20)

    love.graphics.setLineWidth(thickness)
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.arc("line", "open", cx, cy, radius, faceAngle - span, faceAngle + span, 20)
end

function RhythmCrescents.draw(player, musicReactor)
    local cfg = Config.rhythm
    if not (player and cfg and cfg.dashEnabled) then return end

    local c = cfg.crescent

    -- Anticipatory cue from the continuous beat phase: peaks ON the beat (phase
    -- ~0 / ~1), troughs between beats (phase ~0.5). Driving the visual off this
    -- smooth curve -- not the discrete timing window -- gives a readable ramp the
    -- player can anticipate, instead of a hard strobe. The discrete window still
    -- drives the actual dash bonus; the burst below is the on-dash confirmation.
    local phase = (musicReactor and musicReactor.beatPhase) or 0
    local closeness = (math.cos(phase * 2 * math.pi) + 1) * 0.5  -- 1 on beat, 0 between
    closeness = closeness ^ (c.sharpness or 2.0)

    local color = resolveColor()
    local cx = player.x + player.width / 2
    local cy = player.y + player.height / 2

    local minA, maxA = c.minAlpha or 0.1, c.maxAlpha or 0.95
    local radius = c.radius
    local offset = c.offset - (c.pullIn or 0) * closeness   -- converge inward toward the beat
    local alpha = minA + (maxA - minA) * closeness

    -- Success burst: snap inward + expand the arcs + flash brighter, fading over
    -- burstDuration. Perfect bursts punch harder than good.
    if burstStart >= 0 then
        local elapsed = love.timer.getTime() - burstStart
        local dur = c.burstDuration or 0.35
        if elapsed < dur then
            local p = elapsed / dur            -- 0 -> 1
            local punch = (burstTier == "perfect") and 1.0 or 0.6
            radius = radius + (1 - p) * 26 * punch
            alpha = math.min(1, alpha + (1 - p) * punch)
        else
            burstStart = -1
            burstTier = nil
        end
    end

    local prevWidth = love.graphics.getLineWidth()

    -- Left crescent "(" bulges left (faces angle pi); right ")" bulges right (angle 0).
    drawCrescent(cx - offset, cy, radius, math.pi, c.arcSpan, c.thickness, color, alpha)
    drawCrescent(cx + offset, cy, radius, 0, c.arcSpan, c.thickness, color, alpha)

    love.graphics.setLineWidth(prevWidth)
    love.graphics.setColor(1, 1, 1, 1)
end

return RhythmCrescents
