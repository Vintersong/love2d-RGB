-- GameOverState.lua
local GameOverState = {}

local Config           = require("src.Config")
local GameConfig       = require("src.core.GameConfig")
local Theme            = require("src.render.Theme")
local SimpleGrid       = require("src.gameplay.SimpleGrid")
local ColorSystem      = require("src.gameplay.ColorSystem")
local RunSummary       = require("src.core.RunSummary")

GameOverState.player       = nil
GameOverState.musicReactor = nil

local alpha = 0

-- Fonts (lazily initialised after love.graphics exists)
local fontDisplay  = nil
local fontSemiBold = nil
local fontUI       = nil
local fontMono     = nil

-- Button navigation
local buttons = {
    { label = "SUMMARY", action = "summary" },
    { label = "MAIN MENU", action = "menu"  },
}
local selectedButton = 1
local animProgress   = {}

local BTN_W = 300
local BTN_H = 44
local BTN_GAP = 16
local buttonRects = {}

function GameOverState:enter(previous, data)
    GameConfig.setActiveRun(false)
    alpha = 0
    selectedButton = 1
    for i = 1, #buttons do animProgress[i] = 0 end
    if data then
        self.player       = data.player
        self.musicReactor = data.musicReactor
        self.summaryData  = data.summary or RunSummary.build("defeat", data)
    else
        self.summaryData = RunSummary.build("defeat", {})
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
    SimpleGrid.update(dt, self.musicReactor)

    for i = 1, #buttons do
        local target = (i == selectedButton) and 1 or 0
        if animProgress[i] < target then
            animProgress[i] = math.min(target, animProgress[i] + dt / 0.15)
        elseif animProgress[i] > target then
            animProgress[i] = math.max(target, animProgress[i] - dt / 0.15)
        end
    end
end

function GameOverState:draw()
    local sw, sh = Config.screen.width, Config.screen.height
    SimpleGrid.draw()
    Theme.setColor("bgVoid", 0.85)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    self:drawContent(sw, sh)
end

function GameOverState:drawContent(sw, sh)
    if not self.player then return end
    local cx = sw / 2

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
        local segments, segWidths, segColors = {}, {}, {}
        for _, code in ipairs(history) do
            local name = ColorSystem.getColorName(code)
            if name ~= "Unknown" then
                table.insert(segments, name:upper())
                table.insert(segColors, name:lower())
            end
        end
        if #segments > 0 then
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
                local c = Theme.color[segColors[i]] or Theme.color.fg1
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
    end

    -- Dominant damage stat
    love.graphics.setFont(fontMono)
    Theme.setColor("fg2", alpha)
    local dmg    = (self.player.weapon and self.player.weapon.damage) or 0
    local dmgStr = string.format("Damage  %.0f", dmg)
    love.graphics.print(dmgStr, cx - fontMono:getWidth(dmgStr) / 2, 480)

    -- Bracket buttons
    local totalBtnH = #buttons * BTN_H + (#buttons - 1) * BTN_GAP
    local btnStartY = sh - 200 - totalBtnH
    local btnX      = cx - BTN_W / 2
    buttonRects = {}

    for i, btn in ipairs(buttons) do
        local progress = animProgress[i] or 0
        local ease     = 1 - math.pow(2, -10 * math.max(progress, 0.001))
        local slide    = ease * 8
        local lx = btnX + slide
        local rx = btnX + BTN_W - slide
        local by = btnStartY + (i - 1) * (BTN_H + BTN_GAP)

        -- Dark fill
        love.graphics.setColor(0, 0, 0, alpha * 0.5)
        love.graphics.rectangle("fill", lx, by, rx - lx, BTN_H)

        -- Corner brackets
        love.graphics.setLineWidth(1.5)
        if i == selectedButton then
            Theme.setColor("accent", alpha)
        else
            love.graphics.setColor(1, 1, 1, alpha * 0.12)
        end
        love.graphics.line(lx + 12, by,          lx, by,         lx, by + 12)
        love.graphics.line(lx + 12, by + BTN_H,  lx, by + BTN_H, lx, by + BTN_H - 12)
        love.graphics.line(rx - 12, by,          rx, by,         rx, by + 12)
        love.graphics.line(rx - 12, by + BTN_H,  rx, by + BTN_H, rx, by + BTN_H - 12)

        -- Label
        love.graphics.setFont(fontUI)
        local lw = fontUI:getWidth(btn.label)
        if i == selectedButton then
            love.graphics.setColor(0, 0, 0, alpha * 0.5)
            love.graphics.print(btn.label, cx - lw / 2 + 1, by + BTN_H / 2 - 8 + 1)
            Theme.setColor("fg1", alpha)
        else
            love.graphics.setColor(0.55, 0.6, 0.7, alpha * 0.6)
        end
        love.graphics.print(btn.label, cx - lw / 2, by + BTN_H / 2 - 8)

        buttonRects[i] = {x = btnX, y = by, w = BTN_W, h = BTN_H, action = btn.action}
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function buttonAt(x, y)
    for i, rect in ipairs(buttonRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            return i
        end
    end
    return nil
end

function GameOverState:keypressed(key)
    if alpha < 1 then return end
    if key == "up" then
        selectedButton = selectedButton - 1
        if selectedButton < 1 then selectedButton = #buttons end
    elseif key == "down" then
        selectedButton = selectedButton + 1
        if selectedButton > #buttons then selectedButton = 1 end
    elseif key == "return" or key == "space" then
        self:activateButton(buttons[selectedButton].action)
    elseif key == "r" then
        self:activateButton("summary")
    elseif key == "escape" then
        self:activateButton("menu")
    end
end

function GameOverState:mousemoved(x, y)
    local index = buttonAt(x, y)
    if index then
        selectedButton = index
    end
end

function GameOverState:mousepressed(x, y, button)
    if button ~= 1 or alpha < 1 then return end
    local index = buttonAt(x, y)
    if index then
        self:activateButton(buttons[index].action)
    end
end

function GameOverState:activateButton(action)
    local StateManager = require("src.core.StateManager")
    if action == "summary" then
        StateManager.switch("RunSummary", {
            summary = self.summaryData,
        })
    elseif action == "menu" then
        StateManager.push("Confirm", {
            title = "RETURN TO TITLE",
            message = "Leave to the title screen?",
            yesLabel = "RETURN",
            noLabel = "CANCEL",
            onConfirm = function()
                GameConfig.setActiveRun(false)
                StateManager.switch("Menu")
            end,
        })
    end
end

return GameOverState
