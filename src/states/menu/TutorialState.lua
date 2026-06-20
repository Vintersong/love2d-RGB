-- TutorialState.lua
-- Dedicated onboarding / replayable tutorial deck for the game shell.

local TutorialState = {}
local Config = require("src.Config")
local Theme = require("src.render.Theme")
local MetaProgression = require("src.core.MetaProgression")
local ShellStyle = require("src.ui.ShellStyle")

local defaultPages = {
    {
        title = "WELCOME TO CHROMATIC",
        body = {
            "This is a bullet-heaven roguelite where color is your build.",
            "You survive, level up, and tune a light path that changes",
            "shots, dash behavior, artifacts, and the screen around you.",
        },
    },
    {
        title = "PRIMARY WAVELENGTHS",
        body = {
            "Red fractures pressure into multiple lanes.",
            "Green rebounds between targets and keeps damage moving.",
            "Blue pierces clean lines through enemy packs.",
        },
    },
    {
        title = "COLOR COMMITMENT",
        body = {
            "Pick two primaries. The third stays dark for that run.",
            "This keeps builds readable: you are choosing an identity,",
            "not collecting every color at once.",
        },
    },
    {
        title = "ADDITIVE MIXING",
        body = {
            "Two primaries unlock one secondary once both are developed.",
            "Red + Green becomes Yellow velocity.",
            "Red + Blue becomes Magenta burst. Green + Blue becomes Cyan control.",
        },
    },
    {
        title = "ARTIFACTS & SYNERGIES",
        body = {
            "Artifacts are optics: prism, lens, halo, mirror, and more.",
            "They bend the color path you already chose instead of replacing it.",
            "When a named synergy fires, your build found a shared rule.",
        },
    },
}

local buttons = {
    {label = "NEXT", action = "next"},
    {label = "PREV", action = "prev"},
    {label = "BACK", action = "back"},
}

local buttonRects = {}
local selectedButton = 1
local bgShader = nil

local function wrapText(lines)
    local out = {}
    for _, line in ipairs(lines or {}) do
        if type(line) == "table" then
            for _, nested in ipairs(line) do
                out[#out + 1] = tostring(nested)
            end
        else
            out[#out + 1] = tostring(line)
        end
    end
    return out
end

local function normalizePages(inputPages)
    local source = inputPages or defaultPages
    local normalized = {}

    for _, page in ipairs(source) do
        if type(page) == "table" then
            local body = page.body or page.lines or page.text or {}
            if type(body) == "string" then
                body = {body}
            end
            normalized[#normalized + 1] = {
                title = page.title or page.heading or "SLIDE",
                body = wrapText(body),
            }
        else
            normalized[#normalized + 1] = {
                title = "SLIDE",
                body = {tostring(page)},
            }
        end
    end

    if #normalized == 0 then
        normalized = normalizePages(defaultPages)
    end

    return normalized
end

local function buttonAt(x, y)
    for i, rect in ipairs(buttonRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            return i
        end
    end
    return nil
end

function TutorialState:enter(previous, data)
    self.mode = (data and data.mode) or "review" -- review | onboarding
    self.nextState = (data and data.nextState) or "Menu"
    self.nextData = data and data.nextData or nil
    self.title = (data and data.title) or "TUTORIAL"
    self.pages = normalizePages(data and data.pages)
    self.page = 1
    self.alpha = 0
    self.autoMarked = false
    selectedButton = 1
    buttonRects = {}
    bgShader = bgShader or ShellStyle.loadShader("TutorialState")
end

function TutorialState:update(dt)
    ShellStyle.updateMusic(dt)
    self.alpha = math.min(1, self.alpha + dt * 3)
end

function TutorialState:finish()
    local StateManager = require("src.core.StateManager")

    if self.mode == "onboarding" and not self.autoMarked then
        MetaProgression.markTutorialSeen()
        self.autoMarked = true
    end

    StateManager.switch(self.nextState, self.nextData)
end

function TutorialState:skipToMenu()
    local StateManager = require("src.core.StateManager")
    MetaProgression.markTutorialSeen()
    self.autoMarked = true
    StateManager.switch("Menu")
end

function TutorialState:draw()
    local sw, sh = Config.screen.width, Config.screen.height
    local cx = sw / 2
    local margin = sh * 0.1

    ShellStyle.drawBackground(self.alpha, bgShader)

    local titleFont = Theme.font("display", 72)
    ShellStyle.drawRgbTitle(self.title or "TUTORIAL", margin, margin, titleFont, self.alpha)

    local panelW, panelH = 1180, 572
    local panelX, panelY = cx - panelW / 2, 218
    ShellStyle.drawPanel(panelX, panelY, panelW, panelH, self.alpha)

    local page = self.pages[self.page] or self.pages[1] or {title = "", body = {}}
    love.graphics.setFont(Theme.font("uiBold", 28))
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], self.alpha)
    love.graphics.print(page.title or "", panelX + 50, panelY + 42)

    love.graphics.setLineWidth(2)
    local accent = Theme.color.accent
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.35 * self.alpha)
    love.graphics.line(panelX + 50, panelY + 102, panelX + panelW - 50, panelY + 102)

    love.graphics.setFont(Theme.font("ui", 22))
    love.graphics.setColor(Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], self.alpha)
    local body = wrapText(page.body)
    local bodyY = panelY + 150
    local bodyLineHeight = 40
    for i, line in ipairs(body) do
        love.graphics.printf(line, panelX + 90, bodyY + (i - 1) * bodyLineHeight, panelW - 180, "left")
    end

    local indicator = string.format("%d / %d", self.page, #self.pages)
    love.graphics.setFont(Theme.font("mono", 18))
    love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], self.alpha)
    love.graphics.printf(indicator, panelX, panelY + panelH - 54, panelW, "center")

    local bracketHeight = 44
    local gap = 16
    local menuBottomLimit = sh - (sh * 0.1)
    local totalBtnH = #buttons * bracketHeight + (#buttons - 1) * gap
    local btnStackY = menuBottomLimit - totalBtnH

    local barWidth, barGap, startXBar = 56, 4, 2
    local barStep = barWidth + barGap
    local titleW = ShellStyle.measureSpacedText("CHROMATIC", Theme.font("display", 75), 10)
    local logoCenterX = sh * 0.1 + titleW / 2
    local centerCol = math.floor((logoCenterX - startXBar) / barStep) + 1
    local colStart = math.max(1, centerCol - 2)
    if colStart + 4 > 32 then colStart = 28 end
    local btnX = startXBar + (colStart - 1) * barStep
    local btnW = 5 * barWidth + 4 * barGap

    buttonRects = ShellStyle.layoutVerticalRail(buttons, btnX, btnStackY, {buttonW = btnW, buttonH = bracketHeight, gap = gap})

    for i, button in ipairs(buttons) do
        local rect = buttonRects[i]
        ShellStyle.drawBracketButton(button.label, rect.x, rect.y, rect.w, rect.h, i == selectedButton, self.alpha, Theme.font("uiSemiBold", 18))
    end

    local footer
    if self.mode == "onboarding" then
        footer = "LEFT / RIGHT  Navigate   |   ENTER / SPACE  Select   |   ESC  Back"
    else
        footer = "LEFT / RIGHT  Navigate   |   ENTER / SPACE  Select   |   ESC  Back"
    end
    ShellStyle.drawFooter(footer, sh - 84, self.alpha)
end

function TutorialState:keypressed(key)
    if key == "left" then
        if self.page > 1 then
            self.page = self.page - 1
        else
            self.page = #self.pages
        end
        selectedButton = 2
    elseif key == "right" then
        if self.page < #self.pages then
            self.page = self.page + 1
        else
            self.page = 1
        end
        selectedButton = 1
    elseif key == "escape" then
        self:exitTutorial()
    elseif key == "return" or key == "space" then
        if selectedButton == 1 then
            self:keypressed("right")
        elseif selectedButton == 2 then
            self:keypressed("left")
        elseif selectedButton == 3 then
            self:exitTutorial()
        end
    end
end

function TutorialState:exitTutorial()
    if self.mode == "onboarding" then
        self:skipToMenu()
    else
        self:finish()
    end
end

function TutorialState:mousemoved(x, y)
    local index = buttonAt(x, y)
    if index then
        selectedButton = index
    end
end

function TutorialState:mousepressed(x, y, button)
    if button ~= 1 then return end
    local index = buttonAt(x, y)
    if index == 1 then
        self:keypressed("right")
    elseif index == 2 then
        self:keypressed("left")
    elseif index == 3 then
        self:exitTutorial()
    end
end

return TutorialState
