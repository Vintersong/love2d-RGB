-- GameOverState.lua
local GameOverState = {}

local Config           = require("src.Config")
local Runtime          = require("src.core.Runtime")
local GameConfig       = require("src.core.GameConfig")
local Theme            = require("src.render.Theme")
local BackgroundShader = require("src.render.BackgroundShader")

GameOverState.player       = nil
GameOverState.musicReactor = nil

local alpha = 0

-- Fonts (lazily initialised after love.graphics exists)
local fontDisplay  = nil
local fontSemiBold = nil
local fontUI       = nil
local fontMono     = nil

function GameOverState:enter(previous, data)
    GameConfig.setActiveRun(false)
    alpha = 0
    if data then
        self.player       = data.player
        self.musicReactor = data.musicReactor
    end
    fontDisplay  = fontDisplay  or Theme.font("display",    75)
    fontSemiBold = fontSemiBold or Theme.font("uiSemiBold", 24)
    fontUI       = fontUI       or Theme.font("ui",         16)
    fontMono     = fontMono     or Theme.font("mono",       12)
end

function GameOverState:update(dt)
    alpha = math.min(1, alpha + dt / 0.4)
    if self.musicReactor then
        self.musicReactor:update(dt)
    end
    BackgroundShader.update(dt, self.musicReactor, nil)
end

function GameOverState:draw()
    local sw, sh = Config.screen.width, Config.screen.height
    BackgroundShader.draw()
    Theme.setColor("bgVoid", 0.85)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    self:drawContent(sw, sh)
end

function GameOverState:drawContent(sw, sh)
    local cx = sw / 2
    local ColorSystem = require("src.gameplay.ColorSystem")

    -- Title
    love.graphics.setFont(fontDisplay)
    local title = "SIGNAL LOST"
    Theme.setColor("danger", alpha)
    love.graphics.print(title, cx - fontDisplay:getWidth(title) / 2, 200)

    -- Accent rule
    local ruleW = sw * 0.4
    Theme.setColor("accent", alpha * 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(cx - ruleW / 2, 305, cx + ruleW / 2, 305)

    -- Level
    love.graphics.setFont(fontSemiBold)
    Theme.setColor("fg1", alpha)
    local levelStr = string.format("Level %d", self.player.level)
    love.graphics.print(levelStr, cx - fontSemiBold:getWidth(levelStr) / 2, 340)

    -- Color path label
    love.graphics.setFont(fontUI)
    Theme.setColor("fg3", alpha)
    local pathLabel = "Color Path:"
    love.graphics.print(pathLabel, cx - fontUI:getWidth(pathLabel) / 2, 390)

    -- Color path segments, each drawn in its Theme color token
    local history = ColorSystem.colorHistory or {}
    if #history > 0 then
        local segments, segWidths = {}, {}
        for _, code in ipairs(history) do
            table.insert(segments, ColorSystem.getColorName(code):upper())
        end
        local arrow  = "  →  "
        local arrowW = fontUI:getWidth(arrow)
        local totalW = 0
        for i, seg in ipairs(segments) do
            segWidths[i] = fontUI:getWidth(seg)
            totalW = totalW + segWidths[i]
            if i < #segments then totalW = totalW + arrowW end
        end
        local px = cx - totalW / 2
        for i, seg in ipairs(segments) do
            local colorName = ColorSystem.getColorName(history[i]):lower()
            local c = Theme.color[colorName] or Theme.color.fg1
            love.graphics.setColor(c[1], c[2], c[3], alpha)
            love.graphics.print(seg, px, 420)
            px = px + segWidths[i]
            if i < #segments then
                Theme.setColor("fg3", alpha * 0.4)
                love.graphics.print(arrow, px, 420)
                px = px + arrowW
            end
        end
    end

    -- Dominant damage stat
    love.graphics.setFont(fontMono)
    Theme.setColor("fg2", alpha)
    local dmg    = self.player.weapon and self.player.weapon.damage or 0
    local dmgStr = string.format("Damage  %.0f", dmg)
    love.graphics.print(dmgStr, cx - fontMono:getWidth(dmgStr) / 2, 480)

    -- Temporary nav hints (replaced by bracket buttons in Task 2)
    love.graphics.setFont(fontUI)
    Theme.setColor("fg3", alpha * 0.7)
    local hint = "R  Restart      ESC  Quit"
    love.graphics.print(hint, cx - fontUI:getWidth(hint) / 2, sh - 100)
end

function GameOverState:keypressed(key)
    local StateManager = require("src.core.StateManager")
    if key == "r" then
        local PlayingState = require("src.states.PlayingState")
        PlayingState.startNewRun()
        StateManager.switch("Playing")
    elseif key == "escape" then
        Runtime.quitOrReturnToTitle()
    end
end

return GameOverState
