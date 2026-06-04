-- PauseState.lua
-- Frozen gameplay overlay pushed on top of PlayingState

local PauseState = {}
local Config = require("src.Config")
local Theme = require("src.render.Theme")
local Shared = require("src.ui.Shared")

-- Clickable bounds for the pause options, refreshed every draw.
local optionRects = {}
local hovered = nil
local selectedOption = 1

local fontDisplay = nil
local fontSemiBold = nil
local fontUI = nil
local fontMono = nil

local options = {
    {action = "resume", label = "RESUME", key = "P / ESC"},
    {action = "quit", label = "RETURN TO TITLE", key = "Q"},
}

function PauseState:enter(previous, data)
    self.previousState = previous
    self.musicReactor = data and data.musicReactor or nil
    hovered = nil
    selectedOption = 1
    fontDisplay = fontDisplay or Theme.font("display", 72)
    fontSemiBold = fontSemiBold or Theme.font("uiSemiBold", 24)
    fontUI = fontUI or Theme.font("ui", 16)
    fontMono = fontMono or Theme.font("mono", 12)

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

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local centerX = screenWidth / 2
    local titleY = 210
    local panelW = 560
    local panelH = 220
    local panelX = centerX - panelW / 2
    local panelY = 315

    love.graphics.setFont(fontDisplay)
    Theme.setColor("yellow")
    local title = "PAUSED"
    love.graphics.print(title, centerX - fontDisplay:getWidth(title) / 2, titleY)

    local ruleW = screenWidth * 0.24
    Theme.setColor("accent", 0.45)
    love.graphics.setLineWidth(1)
    love.graphics.line(centerX - ruleW / 2, titleY + 102, centerX + ruleW / 2, titleY + 102)

    Shared.drawGlassPanel(panelX, panelY, panelW, panelH, {
        fillAlpha = 0.68,
        edgeAlpha = 0.2,
        lineWidth = 1
    })

    love.graphics.setFont(fontSemiBold)
    Theme.setColor("fg1")
    local subtitle = "Run suspended"
    love.graphics.print(subtitle, centerX - fontSemiBold:getWidth(subtitle) / 2, panelY + 26)

    love.graphics.setFont(fontUI)
    Theme.setColor("fg3")
    local helper = "Resume instantly or abandon this run and return to the title screen"
    love.graphics.print(helper, centerX - fontUI:getWidth(helper) / 2, panelY + 60)

    optionRects = {}
    local y = panelY + 104
    for i, option in ipairs(options) do
        local isActive = hovered == i or selectedOption == i
        local btnX = centerX - 190
        local btnW = 380
        local btnH = 44

        love.graphics.setColor(0, 0, 0, isActive and 0.54 or 0.32)
        love.graphics.rectangle("fill", btnX, y, btnW, btnH)

        love.graphics.setLineWidth(1.5)
        if isActive then
            Theme.setColor("accent", 0.95)
        else
            love.graphics.setColor(1, 1, 1, 0.12)
        end
        love.graphics.line(btnX + 12, y, btnX, y, btnX, y + 12)
        love.graphics.line(btnX + 12, y + btnH, btnX, y + btnH, btnX, y + btnH - 12)
        love.graphics.line(btnX + btnW - 12, y, btnX + btnW, y, btnX + btnW, y + 12)
        love.graphics.line(btnX + btnW - 12, y + btnH, btnX + btnW, y + btnH, btnX + btnW, y + btnH - 12)

        love.graphics.setFont(fontMono)
        Theme.setColor(isActive and "accent" or "fg3")
        love.graphics.print(option.key, btnX + 18, y + 14)

        love.graphics.setFont(fontUI)
        if isActive then
            Theme.setColor("fg1")
        else
            love.graphics.setColor(0.58, 0.64, 0.74, 0.9)
        end
        love.graphics.print(option.label, btnX + 128, y + 13)

        optionRects[i] = {x = btnX, y = y, w = btnW, h = btnH, action = option.action}
        y = y + 58
    end

    love.graphics.setFont(fontMono)
    Theme.setColor("fg3", 0.72)
    local footer = "Combat remains frozen while this overlay is open"
    love.graphics.print(footer, centerX - fontMono:getWidth(footer) / 2, panelY + panelH - 28)

    love.graphics.setLineWidth(1)
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
    elseif action == "quit" then
        StateManager.push("Confirm", {
            title = "RETURN TO TITLE",
            message = "Return to the title screen and abandon the current run?",
            yesLabel = "RETURN",
            noLabel = "CANCEL",
            onConfirm = function()
                local GameConfig = require("src.core.GameConfig")
                GameConfig.setActiveRun(false)
                StateManager.switch("Menu")
            end,
        })
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
    if hovered then
        selectedOption = hovered
    end
end

function PauseState:keypressed(key)
    if key == "p" or key == "escape" then
        self:activate("resume")
    elseif key == "up" then
        selectedOption = selectedOption - 1
        if selectedOption < 1 then
            selectedOption = #options
        end
    elseif key == "down" then
        selectedOption = selectedOption + 1
        if selectedOption > #options then
            selectedOption = 1
        end
    elseif key == "return" or key == "space" then
        self:activate(options[selectedOption].action)
    elseif key == "q" then
        self:activate("quit")
    end
end

return PauseState
