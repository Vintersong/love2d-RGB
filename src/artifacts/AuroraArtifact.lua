-- AuroraArtifact.lua
-- Visual representation of the AURORA (health regen) artifact

local AuroraArtifact = {}

local AURORA_COLORS = {
    RED     = {1,    0.2,  0.2 },
    GREEN   = {0.2,  1,    0.3 },
    BLUE    = {0.3,  0.5,  1   },
    YELLOW  = {1,    1,    0.2 },
    MAGENTA = {1,    0.2,  1   },
    CYAN    = {0.2,  1,    1   },
}

-- Draw: three arcing wisp segments rotating at different speeds, sine-wave undulating
function AuroraArtifact.draw(player, dominantColor)
    if not dominantColor or not player then return end

    local c  = AURORA_COLORS[dominantColor] or {1, 1, 1}
    local cx = player.x + player.width  / 2
    local cy = player.y + player.height / 2
    local t  = love.timer.getTime()

    local baseR       = player.width / 2 + 20
    local waveAmp     = 6
    local dotsPerWisp = 14
    local arcSpan     = math.pi * 0.8   -- each wisp covers ~144 degrees

    love.graphics.push()
    love.graphics.translate(cx, cy)

    for w = 1, 3 do
        local wispPhase = (w - 1) / 3 * math.pi * 2
        local rotSpeed  = 0.35 + (w - 1) * 0.08

        for i = 0, dotsPerWisp - 1 do
            local frac  = i / (dotsPerWisp - 1)
            local angle = wispPhase + t * rotSpeed + frac * arcSpan
            local wave  = math.sin(frac * math.pi * 3 + t * 2.5 + w) * waveAmp
            local r     = baseR + wave
            local x     = math.cos(angle) * r
            local y     = math.sin(angle) * r

            -- Fade at arc edges, brighter in the middle; gentle flicker
            local edgeFade = math.sin(frac * math.pi)
            local flicker  = (math.sin(t * 3 + w + frac * 5) + 1) * 0.15
            local alpha    = edgeFade * 0.7 + flicker

            love.graphics.setColor(c[1], c[2], c[3], alpha)
            love.graphics.circle("fill", x, y, 1.5 + edgeFade * 1.5)
        end
    end

    love.graphics.pop()
end

return AuroraArtifact
