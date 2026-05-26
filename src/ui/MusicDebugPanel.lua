local MusicDebugPanel = {}
local Shared = require("src.ui.Shared")

function MusicDebugPanel.drawMusicDebug(musicReactor)
    if not musicReactor or not musicReactor.isPlaying then
        return
    end

    local _, screenHeight = Shared.getScreenSize()
    local x = 20
    local y = screenHeight - 180
    local barWidth = 200
    local barHeight = 15
    local lineHeight = 20

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x - 10, y - 10, barWidth + 120, 170)

    love.graphics.setColor(0.5, 1, 1)
    love.graphics.print("ðŸŽµ MUSIC ANALYSIS", x, y, 0, 1.2, 1.2)
    y = y + 25

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("BPM: %.1f", musicReactor:getCurrentBPM()), x, y)

    if musicReactor:checkBeat() then
        love.graphics.setColor(1, 1, 0)
        love.graphics.circle("fill", x + barWidth + 10, y + 6, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("BEAT!", x + 100, y)
    end
    y = y + lineHeight

    love.graphics.setColor(0.8, 0.8, 1)
    love.graphics.print(string.format("Section: %s", musicReactor:getCurrentSection():upper()), x, y)
    y = y + lineHeight

    local window, mult = musicReactor:getTimingWindow()
    local windowColors = {
        perfect = {1, 1, 0},
        good = {0.5, 1, 1},
        okay = {1, 1, 1},
        miss = {0.5, 0.5, 0.5}
    }
    love.graphics.setColor(windowColors[window] or {1, 1, 1})
    love.graphics.print(string.format("Timing: %s (%.1fx)", window:upper(), mult), x, y)
    y = y + lineHeight + 5

    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.rectangle("fill", x, y, barWidth * musicReactor:getBass(), barHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("BASS", x + barWidth + 10, y + 2, 0, 0.9, 0.9)
    y = y + barHeight + 3

    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    love.graphics.setColor(0.2, 1, 0.2)
    love.graphics.rectangle("fill", x, y, barWidth * musicReactor:getMid(), barHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("MID", x + barWidth + 10, y + 2, 0, 0.9, 0.9)
    y = y + barHeight + 3

    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    love.graphics.setColor(0.2, 0.2, 1)
    love.graphics.rectangle("fill", x, y, barWidth * musicReactor:getTreble(), barHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("TREBLE", x + barWidth + 10, y + 2, 0, 0.9, 0.9)
    y = y + barHeight + 3

    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    love.graphics.setColor(1, 0.5, 1)
    love.graphics.rectangle("fill", x, y, barWidth * musicReactor:getIntensity(), barHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("ENERGY", x + barWidth + 10, y + 2, 0, 0.9, 0.9)
end

return MusicDebugPanel
