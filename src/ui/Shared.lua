-- Shared UI helpers.

local Shared = {}
local Config = require("src.Config")
local GameConfig = require("src.core.GameConfig")
local Theme = require("src.render.Theme")

function Shared.getScreenSize()
    local w, h = GameConfig.getScreenSize()
    if not w or not h or w <= 0 or h <= 0 then
        return Config.screen.width, Config.screen.height
    end
    return w, h
end

-- Translucent dark-glass panel with a thin cyan accent edge (CHROMATIC design
-- token: panel rgba(10,14,22,0.7) + panel-edge rgba(0,217,255,0.25)).
-- opts = { fillAlpha, edgeAlpha, lineWidth } — all optional.
function Shared.drawGlassPanel(x, y, w, h, opts)
    opts = opts or {}
    local fillAlpha = opts.fillAlpha or 0.7
    local edgeAlpha = opts.edgeAlpha or 0.25
    local lineWidth = opts.lineWidth or 2

    love.graphics.setColor(0.039, 0.055, 0.086, fillAlpha)
    love.graphics.rectangle("fill", x, y, w, h)

    local a = Theme.color.accent
    love.graphics.setColor(a[1], a[2], a[3], edgeAlpha)
    love.graphics.setLineWidth(lineWidth)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineWidth(1)
end

return Shared
