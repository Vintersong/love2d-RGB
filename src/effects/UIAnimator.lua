-- UIAnimator - Reusable tween-based UI animation layer (flux-backed).
--
-- One instance per menu screen. The animator owns motion and timing; the state
-- owns layout and drawing. The animator knows nothing about "cards" - it animates
-- generic elements identified by an id and exposes their current transform via
-- :get(id). Read those transform values in your draw code.
--
-- Each element exposes a transform table:
--   { scale = 1, dx = 0, dy = 0, alpha = 1, glow = 0 }
--     scale - uniform scale about the element's own center
--     dx,dy - pixel offset from the element's layout (rest) position
--     alpha - multiplier applied to the element's draw alpha
--     glow  - 0..1 emphasis factor (hover / select highlight intensity)
--
-- The animator owns its OWN flux group, so it never collides with the gameplay
-- loop's global flux.update and works in menu states that don't run that loop.

local flux = require("libs.flux-master.flux")

local UIAnimator = {}
UIAnimator.__index = UIAnimator

-- Visual-feel constants. Kept module-local (matching VFXLibrary.ArtifactEffects /
-- FloatingTextSystem.Types) since these are animation feel, not gameplay balance.
UIAnimator.presets = {
    enter = {
        duration  = 0.42,
        ease      = "quartout",
        stagger   = 0.06,   -- per-element intro delay
        fromDy    = 30,     -- starts this far below rest
        fromScale = 0.9,
    },
    hover = { duration = 0.16, ease = "quadout", scale = 1.06, glow = 1 },
    rest  = { duration = 0.18, ease = "quadout", scale = 1.0,  glow = 0 },
    select = {
        punchDuration  = 0.12,
        settleDuration = 0.22,
        ease           = "backout",
        scale          = 1.16,
        glow           = 1,
        siblingAlpha   = 0.25,
        siblingDuration = 0.20,
    },
    exit = { duration = 0.28, ease = "quadin", dy = -24 },
}

function UIAnimator.new()
    local self = setmetatable({}, UIAnimator)
    self.tweens = flux.group()
    self.elements = {}   -- id -> { t = transform, rest = {...}, index = n, hovered = bool }
    self.order = {}      -- registration order of ids (for stagger + iteration)
    self.busy = false
    return self
end

-- Register an element. opts may override rest transform values (scale/dx/dy/alpha/glow).
function UIAnimator:add(id, opts)
    opts = opts or {}
    local rest = {
        scale = opts.scale or 1,
        dx    = opts.dx or 0,
        dy    = opts.dy or 0,
        alpha = opts.alpha or 1,
        glow  = opts.glow or 0,
    }
    local t = { scale = rest.scale, dx = rest.dx, dy = rest.dy, alpha = rest.alpha, glow = rest.glow }
    self.order[#self.order + 1] = id
    self.elements[id] = { t = t, rest = rest, index = #self.order, hovered = false }
    return self
end

-- Staggered intro: seed every element offset/faded, then tween toward rest.
function UIAnimator:enter()
    local p = UIAnimator.presets.enter
    for _, id in ipairs(self.order) do
        local el = self.elements[id]
        local t = el.t
        t.alpha = 0
        t.dy    = el.rest.dy + p.fromDy
        t.scale = p.fromScale
        self.tweens:to(t, p.duration, {
            alpha = el.rest.alpha,
            dy    = el.rest.dy,
            scale = el.rest.scale,
        }):ease(p.ease):delay((el.index - 1) * p.stagger)
    end
    return self
end

-- Drive an element toward / away from its hover state. Ignored while busy.
function UIAnimator:setHover(id, hovered)
    local el = self.elements[id]
    if not el or self.busy or el.hovered == hovered then return end
    el.hovered = hovered
    local cfg = hovered and UIAnimator.presets.hover or UIAnimator.presets.rest
    self.tweens:to(el.t, cfg.duration, {
        scale = el.rest.scale * cfg.scale,
        glow  = cfg.glow,
    }):ease(cfg.ease)
    return self
end

-- Punch the chosen element, dim the siblings, then fire onComplete. Sets busy.
function UIAnimator:select(id, onComplete)
    if self.busy then return self end
    self.busy = true
    local p = UIAnimator.presets.select

    for _, oid in ipairs(self.order) do
        if oid ~= id then
            local el = self.elements[oid]
            self.tweens:to(el.t, p.siblingDuration, {
                alpha = el.rest.alpha * p.siblingAlpha,
                glow  = 0,
            }):ease("quadout")
        end
    end

    local chosen = self.elements[id]
    if chosen then
        self.tweens:to(chosen.t, p.punchDuration, {
            scale = chosen.rest.scale * p.scale,
            glow  = p.glow,
        }):ease("quadout")
            :after(chosen.t, p.settleDuration, { scale = chosen.rest.scale })
            :ease(p.ease)
            :oncomplete(function()
                if onComplete then onComplete() end
            end)
    elseif onComplete then
        onComplete()
    end
    return self
end

-- Animate all elements out, then fire onComplete once the last tween finishes.
function UIAnimator:exit(onComplete)
    self.busy = true
    local p = UIAnimator.presets.exit
    local remaining = #self.order
    if remaining == 0 then
        if onComplete then onComplete() end
        return self
    end

    local fired = false
    for _, id in ipairs(self.order) do
        local el = self.elements[id]
        self.tweens:to(el.t, p.duration, {
            alpha = 0,
            dy    = el.rest.dy + p.dy,
        }):ease(p.ease):oncomplete(function()
            remaining = remaining - 1
            if remaining <= 0 and not fired then
                fired = true
                if onComplete then onComplete() end
            end
        end)
    end
    return self
end

function UIAnimator:update(dt)
    self.tweens:update(dt)
    return self
end

-- Current transform for an element, or nil if unknown. Read this in draw code.
function UIAnimator:get(id)
    local el = self.elements[id]
    return el and el.t or nil
end

-- True while a select/exit sequence is playing (use to lock input).
function UIAnimator:isBusy()
    return self.busy
end

-- Drop all elements and cancel in-flight tweens.
function UIAnimator:clear()
    self.tweens = flux.group()
    self.elements = {}
    self.order = {}
    self.busy = false
    return self
end

return UIAnimator
