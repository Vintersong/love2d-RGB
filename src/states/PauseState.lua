-- PauseState.lua
-- Frozen gameplay overlay pushed on top of PlayingState

local PauseState = {}
local Config = require("src.Config")
local Runtime = require("src.core.Runtime")

-- Clickable bounds for the pause options, refreshed every draw.
local optionRects = {}
local hovered = nil

function PauseState:enter(previous, data)
    self.previousState = previous
    self.musicReactor = data and data.musicReactor or nil
    hovered = nil

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

    local options = {
        {action = "resume",  label = "P / ESC  Resume"},
        {action = "restart", label = "R  Restart Run"},
        {action = "quit",    label = "Q  " .. Runtime.quitActionText()},
    }

    optionRects = {}
    y = y + 140
    for i, option in ipairs(options) do
        if hovered == i then
            love.graphics.setColor(1, 1, 0.6)
        else
            love.graphics.setColor(0.7, 0.9, 1)
        end
        love.graphics.printf(option.label, centerX - 250, y, 500, "center", 0, 1.8, 1.8)
        optionRects[i] = {x = centerX - 250, y = y - 4, w = 500, h = 40, action = option.action}
        y = y + 55
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function optionAt(x, y)
    for i, rect in ipairs(optionRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            return i
        end
    end
    return nil
end

function PauseState:activate(action)
    local StateManager = require("src.core.StateManager")
    if action == "resume" then
        StateManager.pop()
    elseif action == "restart" then
        local PlayingState = require("src.states.PlayingState")
        PlayingState.startNewRun()
        StateManager.switch("Playing")
    elseif action == "quit" then
        Runtime.quitOrReturnToTitle()
    end
end

function PauseState:mousepressed(x, y, button)
    if button ~= 1 then return end
    local i = optionAt(x, y)
    if i then
        self:activate(optionRects[i].action)
    end
end

function PauseState:mousemoved(x, y)
    hovered = optionAt(x, y)
end

function PauseState:keypressed(key)
    if key == "p" or key == "escape" then
        self:activate("resume")
    elseif key == "r" then
        self:activate("restart")
    elseif key == "q" then
        self:activate("quit")
    end
end

return PauseState
