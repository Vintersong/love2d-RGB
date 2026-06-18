-- ConfirmState.lua
-- Lightweight modal confirmation dialog for destructive or ambiguous actions.

local ConfirmState = {}
local Config = require("src.Config")
local Theme = require("src.render.Theme")
local ShellStyle = require("src.ui.ShellStyle")

local hovered = nil
local optionRects = {}
local alpha = 0

function ConfirmState:enter(previous, data)
    self.previousState = previous
    self.title = (data and data.title) or "CONFIRM"
    self.message = (data and data.message) or "Are you sure?"
    self.yesLabel = (data and data.yesLabel) or "YES"
    self.noLabel = (data and data.noLabel) or "NO"
    self.onConfirm = data and data.onConfirm or nil
    self.onCancel = data and data.onCancel or nil
    self.selected = 1
    hovered = nil
    alpha = 0
    optionRects = {}
end

function ConfirmState:update(dt)
    alpha = math.min(1, alpha + dt * 4)
end

function ConfirmState:draw()
    if self.previousState and self.previousState.draw then
        self.previousState:draw()
    end

    local sw, sh = Config.screen.width, Config.screen.height
    local cx = sw / 2
    local cy = sh / 2
    local panelW = 760
    local panelH = 260
    local panelX = cx - panelW / 2
    local panelY = cy - panelH / 2

    love.graphics.setColor(0, 0, 0, 0.66 * alpha)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setColor(Theme.color.bgRaised[1], Theme.color.bgRaised[2], Theme.color.bgRaised[3], 0.96 * alpha)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 14, 14)

    love.graphics.setLineWidth(2)
    local accent = Theme.color.accent
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.8 * alpha)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 14, 14)

    love.graphics.setFont(Theme.font("uiBold", 28))
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], alpha)
    love.graphics.printf(self.title, panelX, panelY + 26, panelW, "center")

    love.graphics.setFont(Theme.font("ui", 18))
    love.graphics.setColor(Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], alpha)
    love.graphics.printf(self.message, panelX + 40, panelY + 90, panelW - 80, "center")

    local btnY = panelY + panelH - 72
    local buttons = {
        {label = self.yesLabel, action = "confirm"},
        {label = self.noLabel, action = "cancel"},
    }

    optionRects = ShellStyle.layoutActionRow(buttons, cx, btnY)
    for i, button in ipairs(buttons) do
        local rect = optionRects[i]
        local isSelected = self.selected == i or hovered == i
        ShellStyle.drawBracketButton(button.label, rect.x, rect.y, rect.w, rect.h, isSelected, alpha, Theme.font("uiSemiBold", 18))
    end

    love.graphics.setLineWidth(1)
end

local function buttonAt(x, y)
    for i, rect in ipairs(optionRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            return i
        end
    end
    return nil
end

function ConfirmState:confirm()
    local StateManager = require("src.core.StateManager")
    local callback = self.onConfirm
    if callback then
        callback()
    end
    StateManager.pop()
end

function ConfirmState:cancel()
    local StateManager = require("src.core.StateManager")
    local callback = self.onCancel
    StateManager.pop()
    if callback then
        callback()
    end
end

function ConfirmState:keypressed(key)
    if key == "left" or key == "up" then
        self.selected = 1
    elseif key == "right" or key == "down" then
        self.selected = 2
    elseif key == "return" or key == "space" then
        if self.selected == 1 then
            self:confirm()
        else
            self:cancel()
        end
    elseif key == "escape" then
        self:cancel()
    end
end

function ConfirmState:mousemoved(x, y)
    hovered = buttonAt(x, y)
end

function ConfirmState:mousepressed(x, y, button)
    if button ~= 1 then return end
    local index = buttonAt(x, y)
    if index == 1 then
        self:confirm()
    elseif index == 2 then
        self:cancel()
    end
end

return ConfirmState
