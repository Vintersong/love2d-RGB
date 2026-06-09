-- BossMeterPanel.lua
-- Thin HUD meter surfacing SpawnController.enemyKillCount as progress toward the
-- next boss wave. Glass-panel style with the cyan accent token; pulses on beat
-- when the wave is imminent. Uses the default font per the README HUD note.

local BossMeterPanel = {}

local Config = require("src.Config")
local Shared = require("src.ui.Shared")
local Theme = require("src.render.Theme")

-- Default LÖVE font (HUD typography is intentionally left unstyled).
local labelFont = love.graphics.newFont(13)

-- killCount: SpawnController.enemyKillCount. musicReactor: optional, for the
-- on-beat pulse as the boss approaches.
function BossMeterPanel.draw(killCount, musicReactor)
    killCount = killCount or 0
    local cfg = Config.bossMeter
    local interval = cfg.bossInterval

    local into = killCount % interval
    local progress = into / interval
    local toNext = interval - into

    local screenW = Shared.getScreenSize()
    local w, h = cfg.width, cfg.height
    local x = (screenW - w) / 2
    local y = 28

    -- Beat pulse only when the wave is imminent (anticipation, not alarm).
    local pulse = 0
    if into >= cfg.pulseThreshold and musicReactor and musicReactor.beatIntensity then
        pulse = musicReactor.beatIntensity * cfg.pulseScale
    end

    Shared.drawGlassPanel(x, y, w, h, {edgeAlpha = 0.25 + pulse})

    -- Fill toward the next boss.
    local a = Theme.color.accent
    local pad = 2
    love.graphics.setColor(a[1], a[2], a[3], 0.55 + pulse)
    love.graphics.rectangle("fill", x + pad, y + pad, math.max(0, (w - pad * 2) * progress), h - pad * 2)

    -- Label: current kill count + countdown to the next boss.
    local prev = love.graphics.getFont()
    love.graphics.setFont(labelFont)
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 0.95)
    love.graphics.printf(
        string.format("KILLS %d   ·   NEXT BOSS IN %d", killCount, toNext),
        x, y - 18, w, "center")
    if prev then love.graphics.setFont(prev) end

    love.graphics.setColor(1, 1, 1, 1)
end

return BossMeterPanel
