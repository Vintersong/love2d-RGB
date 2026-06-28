-- RunSummaryState.lua
-- Post-run recap screen that sits after GameOver / Victory and bridges to
-- replay, progression, or the main menu.

local RunSummaryState = {}
local Config = require("src.Config")
local Theme = require("src.render.Theme")
local MetaProgression = require("src.core.MetaProgression")
local RunSummary = require("src.core.RunSummary")

local buttons = {
    {label = "PLAY AGAIN", action = "play"},
    {label = "PROGRESSION", action = "progression"},
    {label = "MAIN MENU", action = "menu"},
}

local selectedButton = 1
local buttonRects = {}

local function drawPanel(x, y, w, h)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x, y, w, h, 16, 16)
    love.graphics.setLineWidth(2)
    local accent = Theme.color.accent
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.45)
    love.graphics.rectangle("line", x, y, w, h, 16, 16)
end

local function joinList(values, separator)
    local out = {}
    for i, value in ipairs(values or {}) do
        out[#out + 1] = tostring(value)
    end
    return table.concat(out, separator or ", ")
end

function RunSummaryState:enter(previous, data)
    selectedButton = 1
    buttonRects = {}
    self.alpha = 0
    self.summary = data and data.summary or data or {}
    if not self.summary.outcome then
        self.summary = RunSummary.build("defeat", self.summary)
    end

    self.unlocks = MetaProgression.recordRun(self.summary)
    self.profile = MetaProgression.getProfile()
end

function RunSummaryState:update(dt)
    self.alpha = math.min(1, (self.alpha or 0) + dt * 3)
end

local function formatTime(seconds)
    seconds = seconds or 0
    if seconds <= 0 then
        return "0.0s"
    end
    return string.format("%.1fs", seconds)
end

function RunSummaryState:draw()
    local sw, sh = Config.screen.width, Config.screen.height
    local cx = sw / 2
    local summary = self.summary or {}
    local unlocks = self.unlocks or {}

    love.graphics.clear(Theme.color.bgVoid[1], Theme.color.bgVoid[2], Theme.color.bgVoid[3], 1)
    love.graphics.setColor(Theme.color.bgBase[1], Theme.color.bgBase[2], Theme.color.bgBase[3], 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local panelW, panelH = 1500, 760
    local panelX, panelY = cx - panelW / 2, 140
    drawPanel(panelX, panelY, panelW, panelH)

    local outcomeTitle = summary.outcome == "victory" and "RUN COMPLETE" or "RUN ENDED"
    local outcomeColor = summary.outcome == "victory" and Theme.color.ok or Theme.color.danger
    love.graphics.setFont(Theme.font("display", 72))
    love.graphics.setColor(outcomeColor[1], outcomeColor[2], outcomeColor[3], self.alpha or 1)
    love.graphics.printf(outcomeTitle, 0, 54, sw, "center")

    love.graphics.setFont(Theme.font("uiBold", 24))
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.print(string.format("Level %d", summary.level or 0), panelX + 50, panelY + 40)
    love.graphics.print(string.format("Time Survived: %s", formatTime(summary.gameTime)), panelX + 250, panelY + 40)
    love.graphics.print(string.format("Kills: %d", summary.enemyKillCount or 0), panelX + 520, panelY + 40)
    love.graphics.print(string.format("Build: %s", summary.currentPath or "Unknown"), panelX + 760, panelY + 40)

    love.graphics.setFont(Theme.font("ui", 18))
    love.graphics.setColor(Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], 1)
    love.graphics.print(string.format("Weapon: %s", summary.weaponName or "Base Weapon"), panelX + 50, panelY + 92)
    love.graphics.print(string.format("Damage: %.0f", summary.damage or 0), panelX + 50, panelY + 124)
    love.graphics.print(string.format("Fire Rate: %.2fs", summary.fireRate or 0), panelX + 50, panelY + 154)
    love.graphics.print(string.format("Bullets: %d", summary.bulletCount or 1), panelX + 50, panelY + 184)
    love.graphics.print(string.format("Pierce: %d", summary.pierceCount or 0), panelX + 50, panelY + 214)
    love.graphics.print(string.format("HP: %d / %d", summary.hp or 0, summary.maxHp or 0), panelX + 50, panelY + 244)
    love.graphics.print(string.format("Boss Damage: %d", math.floor(summary.bossDamage or 0)), panelX + 250, panelY + 244)

    love.graphics.setFont(Theme.font("uiSemiBold", 22))
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.print("COLOR PATH", panelX + 50, panelY + 320)
    love.graphics.setFont(Theme.font("ui", 18))
    love.graphics.setColor(Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], 1)
    love.graphics.print(summary.currentPath or "None", panelX + 50, panelY + 356)

    love.graphics.setFont(Theme.font("uiSemiBold", 22))
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.print("UNLOCKS THIS RUN", panelX + 50, panelY + 430)

    local unlockedColors = unlocks.newColors or {}
    local unlockedArtifacts = unlocks.newArtifacts or {}
    love.graphics.setFont(Theme.font("ui", 18))
    love.graphics.setColor(Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], 1)
    love.graphics.print(
        #unlockedColors > 0 and ("Colors: " .. joinList(unlockedColors, ", ")) or "Colors: none",
        panelX + 50,
        panelY + 468
    )
    love.graphics.print(
        #unlockedArtifacts > 0 and ("Artifacts: " .. joinList(unlockedArtifacts, ", ")) or "Artifacts: none",
        panelX + 50,
        panelY + 498
    )
    love.graphics.print(
        string.format("Chroma earned: %d   |   Balance: %d", unlocks.chromaEarned or unlocks.shardsEarned or 0, unlocks.chromaBalance or unlocks.shardBalance or MetaProgression.getChroma()),
        panelX + 50,
        panelY + 528
    )

    love.graphics.setFont(Theme.font("uiSemiBold", 22))
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.print("COLLECTED ARTIFACTS", panelX + 50, panelY + 560)
    love.graphics.setFont(Theme.font("ui", 18))
    love.graphics.setColor(Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], 1)
    local artifactNames = {}
    for _, artifact in ipairs(summary.artifacts or {}) do
        artifactNames[#artifactNames + 1] = string.format("%s Lv%d/%d", artifact.name, artifact.level or 0, artifact.maxLevel or 0)
    end
    if #artifactNames == 0 then
        love.graphics.print("None collected", panelX + 50, panelY + 598)
    else
        for i, line in ipairs(artifactNames) do
            love.graphics.print(line, panelX + 50, panelY + 598 + (i - 1) * 28)
        end
    end

    local buttonW, buttonH, gap = 240, 44, 18
    local totalW = #buttons * buttonW + (#buttons - 1) * gap
    local startX = cx - totalW / 2
    local buttonY = panelY + panelH - 86
    buttonRects = {}

    for i, button in ipairs(buttons) do
        local x = startX + (i - 1) * (buttonW + gap)
        buttonRects[i] = {x = x, y = buttonY, w = buttonW, h = buttonH, action = button.action}

        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle("fill", x, buttonY, buttonW, buttonH, 8, 8)
        if selectedButton == i then
            local accent = Theme.color.accent
            love.graphics.setColor(accent[1], accent[2], accent[3], 1)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(1, 1, 1, 0.14)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", x, buttonY, buttonW, buttonH, 8, 8)

        love.graphics.setFont(Theme.font("uiSemiBold", 18))
        if selectedButton == i then
            love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
        else
            love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], 1)
        end
        love.graphics.printf(button.label, x, buttonY + 10, buttonW, "center")
    end

    love.graphics.setLineWidth(1)
    love.graphics.setFont(Theme.font("ui", 16))
    love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], 1)
    love.graphics.printf("ENTER / SPACE to activate   |   ESC to quit to menu", 0, sh - 72, sw, "center")
end

local function buttonAt(x, y)
    for i, rect in ipairs(buttonRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            return i
        end
    end
    return nil
end

function RunSummaryState:activate(action)
    local StateManager = require("src.core.StateManager")
    if action == "play" then
        StateManager.switch("Loading", {
            message = "Preparing a new run...",
            nextState = "Playing",
            onLoad = function()
                local PlayingState = require("src.states.gameplay.PlayingState")
                PlayingState.startNewRun()
            end,
        })
    elseif action == "progression" then
        StateManager.switch("Progression")
    elseif action == "menu" then
        StateManager.switch("Menu")
    end
end

function RunSummaryState:keypressed(key)
    if key == "up" then
        selectedButton = selectedButton - 1
        if selectedButton < 1 then selectedButton = #buttons end
    elseif key == "down" then
        selectedButton = selectedButton + 1
        if selectedButton > #buttons then selectedButton = 1 end
    elseif key == "return" or key == "space" then
        self:activate(buttons[selectedButton].action)
    elseif key == "escape" then
        self:activate("menu")
    end
end

function RunSummaryState:mousemoved(x, y)
    local index = buttonAt(x, y)
    if index then
        selectedButton = index
    end
end

function RunSummaryState:mousepressed(x, y, button)
    if button ~= 1 then return end
    local index = buttonAt(x, y)
    if index then
        self:activate(buttons[index].action)
    end
end

return RunSummaryState
