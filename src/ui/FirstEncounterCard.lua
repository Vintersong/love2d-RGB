-- src/ui/FirstEncounterCard.lua
-- Shared renderer for first-encounter teaching cards. Two modes:
--   drawToast  - non-blocking in-combat banner (PlayingState)
--   drawModal  - blocking centered card (RunSummary / Progression menus)
local Theme      = require("src.render.Theme")
local ShellStyle = require("src.ui.ShellStyle")

local FirstEncounterCard = {}

-- Layout constants (1920×1080 logical space; not balance, so kept here, not Config)
local TOAST_W, TOAST_H = 760, 150
local MODAL_W, MODAL_H = 820, 260

local function accent(card)
    return card.color or Theme.color.accent
end

local function drawCard(card, x, y, w, h, footer)
    -- Background fill + dim border via the shared panel utility.
    -- ShellStyle.drawPanel(x, y, w, h, alpha, accentColor)
    ShellStyle.drawPanel(x, y, w, h)

    -- Bright accent rim tinted to the card's own color (or the default accent).
    local rim = accent(card)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(rim[1], rim[2], rim[3], 0.9)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)

    -- Title  (uiSemiBold = ChakraPetch-SemiBold.ttf)
    love.graphics.setFont(Theme.font("uiSemiBold", 24))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(card.title, x + 28, y + 20)

    -- Body lines — read-only; do NOT mutate card.lines (may alias FE internal table)
    love.graphics.setFont(Theme.font("ui", 18))
    love.graphics.setColor(1, 1, 1, 0.92)
    for i, line in ipairs(card.lines or {}) do
        love.graphics.print(line, x + 28, y + 60 + (i - 1) * 26)
    end

    -- Footer keybind hint
    if footer then
        love.graphics.setFont(Theme.font("mono", 14))
        love.graphics.setColor(1, 1, 1, 0.55)
        love.graphics.print(footer, x + 28, y + h - 30)
    end
end

--- Non-blocking in-combat banner. Anchored bottom-center in 1920×1080.
-- @param card        {title, color, lines, atlasTab} from FirstEncounter.cardFor
-- @param alphaScale  optional 0-1 fade multiplier (default 1)
function FirstEncounterCard.drawToast(card, alphaScale)
    if not card then return end
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, alphaScale or 1)
    local x = (1920 - TOAST_W) / 2
    drawCard(card, x, 1080 - TOAST_H - 60, TOAST_W, TOAST_H, nil)
    love.graphics.pop()
end

--- Blocking centered card. Dims the background; shows dismiss / atlas hints.
-- @param card  {title, color, lines, atlasTab} from FirstEncounter.cardFor
function FirstEncounterCard.drawModal(card)
    if not card then return end
    love.graphics.push("all")
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, 1920, 1080)
    local footer = card.atlasTab and "[SPACE] dismiss   [A] Atlas" or "[SPACE] dismiss"
    drawCard(card, (1920 - MODAL_W) / 2, (1080 - MODAL_H) / 2, MODAL_W, MODAL_H, footer)
    love.graphics.pop()
end

return FirstEncounterCard
