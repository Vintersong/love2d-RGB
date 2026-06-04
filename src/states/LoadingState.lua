-- LoadingState.lua
-- Lightweight transition state for run setup and other short prep sequences.

local LoadingState = {}
local Config = require("src.Config")
local Theme = require("src.render.Theme")

local defaultTips = {
    "Color choices shape every run.",
    "Artifacts and synergies can swing a build fast.",
    "Bosses arrive every 100 kills.",
}

function LoadingState:enter(previous, data)
    self.message = (data and data.message) or "Preparing run..."
    self.nextState = (data and data.nextState) or "Playing"
    self.nextData = data and data.nextData or nil
    self.onLoad = data and data.onLoad or nil
    self.duration = (data and data.duration) or 0.65
    self.timer = 0
    self.tip = defaultTips[(math.floor(love.timer.getTime() * 10) % #defaultTips) + 1]
    self.started = false

    if self.onLoad then
        local ok, err = pcall(self.onLoad)
        if not ok then
            self.message = "Loading failed"
            self.tip = tostring(err)
            self.nextState = "Menu"
            self.nextData = nil
        end
    end
    self.started = true
end

function LoadingState:update(dt)
    self.timer = self.timer + dt
    if self.timer >= self.duration then
        local StateManager = require("src.core.StateManager")
        StateManager.switch(self.nextState, self.nextData)
    end
end

function LoadingState:draw()
    local sw, sh = Config.screen.width, Config.screen.height
    local cx = sw / 2
    local cy = sh / 2

    love.graphics.clear(Theme.color.bgVoid[1], Theme.color.bgVoid[2], Theme.color.bgVoid[3], 1)
    love.graphics.setColor(Theme.color.bgBase[1], Theme.color.bgBase[2], Theme.color.bgBase[3], 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local panelW, panelH = 680, 180
    local panelX, panelY = cx - panelW / 2, cy - panelH / 2

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 16, 16)
    love.graphics.setLineWidth(2)
    local accent = Theme.color.accent
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.55)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 16, 16)

    love.graphics.setFont(Theme.font("uiBold", 30))
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.printf(self.message, panelX, panelY + 40, panelW, "center")

    local dots = "." .. string.rep(".", math.floor((self.timer * 3) % 3))
    love.graphics.setFont(Theme.font("uiSemiBold", 20))
    love.graphics.setColor(Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], 1)
    love.graphics.printf("Please wait" .. dots, panelX, panelY + 92, panelW, "center")

    love.graphics.setFont(Theme.font("ui", 14))
    love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], 1)
    love.graphics.printf(self.tip or "", panelX + 30, panelY + 128, panelW - 60, "center")
end

function LoadingState:keypressed()
    self.timer = self.duration
end

function LoadingState:mousepressed()
    self.timer = self.duration
end

return LoadingState
