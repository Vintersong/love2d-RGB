-- PauseState.lua
-- Frozen gameplay overlay pushed on top of PlayingState

local PauseState = {}
local Config = require("src.Config")
local Runtime = require("src.systems.Runtime")

PauseState.previousState = nil
PauseState.musicReactor = nil

function PauseState:enter(previous, data)
    self.previousState = previous
    self.musicReactor = data and data.musicReactor or nil

    if self.musicReactor and self.musicReactor.pause then
        self.musicReactor:pause()
    end
end

function PauseState:leave()
    if self.musicReactor and self.musicReactor.play then
        self.musicReactor:play()
    end
end

function PauseState:update(dt)
    -- Intentionally empty: gameplay remains frozen while paused.
end

function PauseState:draw()
    if self.previousState and self.previousState.draw then
        self.previousState:draw()
    end

    local screenWidth = Config.screen.width
    local screenHeight = Config.screen.height

    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local centerX = screenWidth / 2
    local y = 350

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("PAUSED", centerX - 300, y, 600, "center", 0, 4, 4)

    y = y + 140
    love.graphics.setColor(0.7, 0.9, 1)
    love.graphics.printf("P / ESC  Resume", centerX - 250, y, 500, "center", 0, 1.8, 1.8)
    y = y + 55
    love.graphics.printf("R  Restart Run", centerX - 250, y, 500, "center", 0, 1.8, 1.8)
    y = y + 55
    love.graphics.printf("Q  " .. Runtime.quitActionText(), centerX - 250, y, 500, "center", 0, 1.8, 1.8)

    love.graphics.setColor(1, 1, 1, 1)
end

function PauseState:keypressed(key)
    local StateManager = require("src.systems.StateManager")

    if key == "p" or key == "escape" then
        StateManager.pop()
    elseif key == "r" then
        local PlayingState = require("src.states.PlayingState")
        PlayingState.startNewRun()
        StateManager.switch("Playing")
    elseif key == "q" then
        Runtime.quitOrReturnToTitle()
    end
end

return PauseState
