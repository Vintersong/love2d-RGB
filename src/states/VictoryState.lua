-- VictoryState.lua
-- Victory screen when player completes the game

local VictoryState = {}
local Config = require("src.Config")
local Runtime = require("src.core.Runtime")
local GameConfig = require("src.core.GameConfig")
local Theme = require("src.render.Theme")
local RunSummary = require("src.core.RunSummary")

VictoryState.player = nil
VictoryState.enemies = {}
VictoryState.xpOrbs = {}
VictoryState.musicReactor = nil

local buttons = {
    { label = "SUMMARY", action = "summary" },
    { label = "QUIT",    action = "quit"    },
}

local selectedButton = 1
local animProgress = {}
local buttonRects = {}

local BTN_W = 300
local BTN_H = 44
local BTN_GAP = 16

function VictoryState:enter(previous, data)
    GameConfig.setActiveRun(false)
    selectedButton = 1
    for i = 1, #buttons do animProgress[i] = 0 end

    if data then
        self.player = data.player
        self.enemies = data.enemies or {}
        self.xpOrbs = data.xpOrbs or {}
        self.musicReactor = data.musicReactor
        self.summaryData = data.summary or RunSummary.build("victory", data)
    else
        self.summaryData = RunSummary.build("victory", {})
    end
end

function VictoryState:update(dt)
    local World = require("src.gameplay.World")
    if self.musicReactor then
        self.musicReactor:update(dt)
    end
    World.update(dt, self.musicReactor)

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
    local World = require("src.gameplay.World")
    World.draw()

    -- Draw frozen game state
    self.player:draw()

    for _, enemy in ipairs(self.enemies) do
        enemy:draw(self.musicReactor)
    end

    for _, orb in ipairs(self.xpOrbs) do
        orb:draw()
    end

    self:drawVictoryScreen()
end

function VictoryState:drawVictoryScreen()
    local ColorSystem = require("src.gameplay.ColorSystem")
    local screenWidth = Config.screen.width
    local screenHeight = Config.screen.height
    local cx = screenWidth / 2

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local startY = 200
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("VICTORY!", cx - 220, startY, 0, 4, 4)

    local y = startY + 120

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("You reached Level %d!", self.player.level), cx - 180, y, 0, 2, 2)
    y = y + 80

    local pathDesc = ColorSystem.getCurrentPath()
    local dominantColor = ColorSystem.getDominantColor()
    if dominantColor then
        pathDesc = pathDesc .. " / Dominant " .. dominantColor
    end
    love.graphics.setColor(0, 0.94, 1)
    love.graphics.print("Final Build:", cx - 120, y, 0, 1.5, 1.5)
    love.graphics.print(pathDesc, cx - 120, y + 40, 0, 1.5, 1.5)
    y = y + 100

    local history = ColorSystem.colorHistory or {}
    local displayHistory = {}
    for _, colorCode in ipairs(history) do
        table.insert(displayHistory, ColorSystem.getColorName(colorCode))
    end
    history = displayHistory

    if #history > 0 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Color Path:", cx - 120, y, 0, 1.5, 1.5)

        local pathStr = table.concat(history, " -> ")
        love.graphics.print(pathStr:upper(), cx - 120, y + 40, 0, 1.5, 1.5)
        y = y + 90
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Final Stats:", cx - 120, y, 0, 1.5, 1.5)
    y = y + 45

    love.graphics.setColor(1, 0.8, 0.8)
    love.graphics.print(string.format("Damage: %.0f", self.player.weapon.damage), cx - 90, y, 0, 1.3, 1.3)
    y = y + 38

    love.graphics.setColor(0.8, 1, 0.8)
    love.graphics.print(string.format("Fire Rate: %.2fs", self.player.weapon.fireRate), cx - 90, y, 0, 1.3, 1.3)
    y = y + 25

    love.graphics.setColor(0.8, 0.8, 1)
    love.graphics.print(string.format("Bullets: %d", self.player.weapon.bulletCount or 1), cx - 60, y)
    y = y + 25

    local pierce = self.player.weapon.pierce or self.player.weapon.pierceCount or 0
    love.graphics.print(string.format("Pierce: %d", pierce), cx - 60, y)
    y = y + 50

    local totalBtnH = #buttons * BTN_H + (#buttons - 1) * BTN_GAP
    local btnStartY = screenHeight - 200 - totalBtnH
    local btnX = cx - BTN_W / 2
    buttonRects = {}

    for i, btn in ipairs(buttons) do
        local progress = animProgress[i] or 0
        local ease = 1 - math.pow(2, -10 * math.max(progress, 0.001))
        local slide = ease * 8
        local lx = btnX + slide
        local rx = btnX + BTN_W - slide
        local by = btnStartY + (i - 1) * (BTN_H + BTN_GAP)

        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", lx, by, rx - lx, BTN_H)

        love.graphics.setLineWidth(1.5)
        if i == selectedButton then
            Theme.setColor("accent")
        else
            love.graphics.setColor(1, 1, 1, 0.12)
        end
        love.graphics.line(lx + 12, by,          lx, by,         lx, by + 12)
        love.graphics.line(lx + 12, by + BTN_H,  lx, by + BTN_H, lx, by + BTN_H - 12)
        love.graphics.line(rx - 12, by,          rx, by,         rx, by + 12)
        love.graphics.line(rx - 12, by + BTN_H,  rx, by + BTN_H, rx, by + BTN_H - 12)

        local uiFont = Theme.font("ui", 16)
        love.graphics.setFont(uiFont)
        local lw = uiFont:getWidth(btn.label)
        if i == selectedButton then
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.print(btn.label, cx - lw / 2 + 1, by + BTN_H / 2 - 8 + 1)
            Theme.setColor("fg1")
        else
            love.graphics.setColor(0.55, 0.6, 0.7, 0.6)
        end
        love.graphics.print(btn.label, cx - lw / 2, by + BTN_H / 2 - 8)

        buttonRects[i] = {x = btnX, y = by, w = BTN_W, h = BTN_H, action = btn.action}
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], 1)
    love.graphics.setFont(Theme.font("ui", 16))
    love.graphics.printf("[SPACE] Summary    [ESC] Quit", 0, screenHeight - 120, screenWidth, "center")
end

function VictoryState:keypressed(key)
    local StateManager = require("src.core.StateManager")

    if key == "escape" then
        StateManager.push("Confirm", {
            title = "QUIT GAME",
            message = "Leave to the title screen?",
            yesLabel = "QUIT",
            noLabel = "CANCEL",
            onConfirm = function()
                Runtime.quitOrReturnToTitle()
            end,
        })
    elseif key == "space" or key == "return" then
        StateManager.switch("RunSummary", {
            summary = self.summaryData,
        })
    elseif key == "up" then
        selectedButton = selectedButton - 1
        if selectedButton < 1 then selectedButton = #buttons end
    elseif key == "down" then
        selectedButton = selectedButton + 1
        if selectedButton > #buttons then selectedButton = 1 end
    end
end

function VictoryState:mousepressed(x, y, button)
    if button ~= 1 then return end
    for i, rect in ipairs(buttonRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            if buttons[i].action == "summary" then
                require("src.core.StateManager").switch("RunSummary", {
                    summary = self.summaryData,
                })
            elseif buttons[i].action == "quit" then
                require("src.core.StateManager").push("Confirm", {
                    title = "QUIT GAME",
                    message = "Leave to the title screen?",
                    yesLabel = "QUIT",
                    noLabel = "CANCEL",
                    onConfirm = function()
                        Runtime.quitOrReturnToTitle()
                    end,
                })
            end
            return
        end
    end
end

return VictoryState
