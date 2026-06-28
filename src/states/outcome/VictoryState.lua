-- VictoryState.lua
-- CHROMATIC-styled completion screen after a boss defeat.

local VictoryState = {}

local Config = require("src.Config")
local Runtime = require("src.core.Runtime")
local GameConfig = require("src.core.GameConfig")
local Theme = require("src.render.Theme")
local SimpleGrid = require("src.gameplay.SimpleGrid")
local RunSummary = require("src.core.RunSummary")

VictoryState.player = nil
VictoryState.musicReactor = nil

local buttons = {
    { label = "SUMMARY", action = "summary" },
    { label = "QUIT",    action = "quit"    },
}

local selectedButton = 1
local animProgress = {}
local buttonRects = {}
local alpha = 0

local BTN_W = 300
local BTN_H = 44
local BTN_GAP = 16

local fontDisplay = nil
local fontSemiBold = nil
local fontUI = nil
local fontMono = nil

local function initFonts()
    fontDisplay = fontDisplay or Theme.font("display", 75)
    fontSemiBold = fontSemiBold or Theme.font("uiSemiBold", 24)
    fontUI = fontUI or Theme.font("ui", 16)
    fontMono = fontMono or Theme.font("mono", 13)
end

local function drawStat(label, value, x, y, w, accent)
    love.graphics.setColor(0, 0, 0, 0.36)
    love.graphics.rectangle("fill", x, y, w, 44)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.14)
    love.graphics.rectangle("fill", x + 1, y + 1, w - 2, 42)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, 44)

    love.graphics.setFont(fontMono)
    love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], alpha)
    love.graphics.print(label, x + 12, y + 6)
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], alpha)
    love.graphics.print(value, x + 12, y + 24)
end

local function drawButton(i, btn, cx, y)
    local progress = animProgress[i] or 0
    local ease = 1 - math.pow(2, -10 * math.max(progress, 0.001))
    local slide = ease * 8
    local btnX = cx - BTN_W / 2
    local lx = btnX + slide
    local rx = btnX + BTN_W - slide

    love.graphics.setColor(0, 0, 0, alpha * 0.5)
    love.graphics.rectangle("fill", lx, y, rx - lx, BTN_H)

    love.graphics.setLineWidth(1.5)
    if i == selectedButton then
        Theme.setColor("accent", alpha)
    else
        love.graphics.setColor(1, 1, 1, alpha * 0.12)
    end
    love.graphics.line(lx + 12, y,          lx, y,         lx, y + 12)
    love.graphics.line(lx + 12, y + BTN_H,  lx, y + BTN_H, lx, y + BTN_H - 12)
    love.graphics.line(rx - 12, y,          rx, y,         rx, y + 12)
    love.graphics.line(rx - 12, y + BTN_H,  rx, y + BTN_H, rx, y + BTN_H - 12)

    love.graphics.setFont(fontUI)
    local labelW = fontUI:getWidth(btn.label)
    if i == selectedButton then
        love.graphics.setColor(0, 0, 0, alpha * 0.5)
        love.graphics.print(btn.label, cx - labelW / 2 + 1, y + BTN_H / 2 - 8 + 1)
        Theme.setColor("fg1", alpha)
    else
        love.graphics.setColor(0.55, 0.6, 0.7, alpha * 0.6)
    end
    love.graphics.print(btn.label, cx - labelW / 2, y + BTN_H / 2 - 8)

    buttonRects[i] = {x = btnX, y = y, w = BTN_W, h = BTN_H, action = btn.action}
end

local function buttonAt(x, y)
    for i, rect in ipairs(buttonRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            return i
        end
    end
    return nil
end

function VictoryState:enter(previous, data)
    GameConfig.setActiveRun(false)
    initFonts()

    alpha = 0
    selectedButton = 1
    buttonRects = {}
    for i = 1, #buttons do
        animProgress[i] = i == selectedButton and 1 or 0
    end

    if data then
        self.player = data.player
        self.musicReactor = data.musicReactor
        self.summaryData = data.summary or RunSummary.build("victory", data)
    else
        self.summaryData = RunSummary.build("victory", {})
    end
end

function VictoryState:update(dt)
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

function VictoryState:draw()
    local sw, sh = Config.screen.width, Config.screen.height
    SimpleGrid.draw()
    love.graphics.setColor(Theme.color.bgVoid[1], Theme.color.bgVoid[2], Theme.color.bgVoid[3], 0.88)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    self:drawContent(sw, sh)
end

function VictoryState:drawContent(sw, sh)
    local summary = self.summaryData or {}
    local player = self.player or {}
    local weapon = player.weapon or {}
    local cx = sw / 2
    local panelW = math.min(980, sw - 240)
    local panelX = cx - panelW / 2
    local topY = 150

    love.graphics.setFont(fontDisplay)
    local title = "SPECTRUM STABLE"
    Theme.setColor("ok", alpha)
    love.graphics.print(title, cx - fontDisplay:getWidth(title) / 2, topY)

    local ruleW = panelW * 0.72
    Theme.setColor("accent", alpha * 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(cx - ruleW / 2, topY + 104, cx + ruleW / 2, topY + 104)

    love.graphics.setFont(fontSemiBold)
    Theme.setColor("fg1", alpha)
    local levelText = string.format("Level %d run complete", player.level or summary.level or 0)
    love.graphics.print(levelText, cx - fontSemiBold:getWidth(levelText) / 2, topY + 132)

    local statY = topY + 208
    local statW = math.floor((panelW - 36) / 4)
    drawStat("DAMAGE", string.format("%.0f", weapon.damage or summary.damage or 0), panelX, statY, statW, Theme.color.red)
    drawStat("FIRE RATE", string.format("%.2fs", weapon.fireRate or summary.fireRate or 0), panelX + (statW + 12), statY, statW, Theme.color.green)
    drawStat("BULLETS", string.format("%d", weapon.bulletCount or summary.bulletCount or 1), panelX + (statW + 12) * 2, statY, statW, Theme.color.blue)
    drawStat("PIERCE", string.format("%d", weapon.pierce or weapon.pierceCount or summary.pierceCount or 0), panelX + (statW + 12) * 3, statY, statW, Theme.color.magenta)

    local detailY = statY + 118
    local leftColW = math.floor((panelW - 28) * 0.55)
    local rightColX = panelX + leftColW + 28

    love.graphics.setFont(fontUI)
    Theme.setColor("fg3", alpha)
    love.graphics.print("RUN SIGNAL", panelX, detailY)
    love.graphics.print("REWARD ROUTE", rightColX, detailY)

    love.graphics.setFont(fontMono)
    Theme.setColor("fg2", alpha)
    love.graphics.print(string.format("TIME      %s", summary.gameTime and string.format("%.1fs", summary.gameTime) or "--"), panelX, detailY + 34)
    love.graphics.print(string.format("KILLS     %d", summary.enemyKillCount or 0), panelX, detailY + 60)
    love.graphics.print(string.format("HP        %d / %d", summary.hp or player.hp or 0, summary.maxHp or player.maxHp or 0), panelX, detailY + 86)
    love.graphics.print(string.format("BOSS DMG  %d", math.floor(summary.bossDamage or 0)), panelX, detailY + 112)

    Theme.setColor("fg2", alpha)
    love.graphics.print("SUMMARY  FULL RECAP", rightColX, detailY + 34)
    love.graphics.print("QUIT     RETURN TO TITLE", rightColX, detailY + 60)

    local totalBtnH = #buttons * BTN_H + (#buttons - 1) * BTN_GAP
    local btnStartY = sh - 188 - totalBtnH
    buttonRects = {}
    for i, btn in ipairs(buttons) do
        drawButton(i, btn, cx, btnStartY + (i - 1) * (BTN_H + BTN_GAP))
    end

    love.graphics.setFont(fontUI)
    Theme.setColor("fg3", alpha * 0.9)
    love.graphics.printf("[SPACE] Summary    [ESC] Quit", 0, sh - 88, sw, "center")
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function VictoryState:activate(action)
    local StateManager = require("src.core.StateManager")
    if action == "summary" then
        StateManager.switch("RunSummary", {
            summary = self.summaryData,
        })
    elseif action == "quit" then
        StateManager.push("Confirm", {
            title = "QUIT GAME",
            message = "Leave to the title screen?",
            yesLabel = "QUIT",
            noLabel = "CANCEL",
            onConfirm = function()
                Runtime.quitOrReturnToTitle()
            end,
        })
    end
end

function VictoryState:keypressed(key)
    if alpha < 1 then return end
    if key == "escape" then
        self:activate("quit")
    elseif key == "space" or key == "return" then
        self:activate(buttons[selectedButton].action)
    elseif key == "up" then
        selectedButton = selectedButton - 1
        if selectedButton < 1 then selectedButton = #buttons end
    elseif key == "down" then
        selectedButton = selectedButton + 1
        if selectedButton > #buttons then selectedButton = 1 end
    end
end

function VictoryState:mousemoved(x, y)
    local index = buttonAt(x, y)
    if index then
        selectedButton = index
    end
end

function VictoryState:mousepressed(x, y, button)
    if button ~= 1 or alpha < 1 then return end
    local index = buttonAt(x, y)
    if index then
        self:activate(buttons[index].action)
    end
end

return VictoryState
