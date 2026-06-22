-- RhythmDash.lua
-- Pure logic: given the music reactor's current timing window, returns the dash
-- bonus the player earns for dashing on the beat. No rendering, no side effects.
-- Tiers come from MusicReactor.timingWindow; multipliers from Config.rhythm.

local Config = require("src.Config")

local RhythmDash = {}

-- Returns { tier = "good"|"perfect", damageMult, speedMult } when the dash lands
-- inside a rewarding window, or nil for okay/miss/disabled/no-reactor.
function RhythmDash.getDashBonus(musicReactor)
    local cfg = Config.rhythm
    if not (cfg and cfg.dashEnabled) then return nil end
    if not musicReactor then return nil end

    local window = musicReactor.timingWindow
    if window ~= "good" and window ~= "perfect" then return nil end

    return {
        tier = window,
        damageMult = (cfg.damageMult and cfg.damageMult[window]) or 1,
        speedMult = (cfg.speedMult and cfg.speedMult[window]) or 1,
    }
end

return RhythmDash
