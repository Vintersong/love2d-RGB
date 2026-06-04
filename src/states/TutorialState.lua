-- TutorialState.lua
-- Dedicated onboarding / replayable tutorial deck for the game shell.

local TutorialState = {}
local Config = require("src.Config")
local Theme = require("src.render.Theme")
local MetaProgression = require("src.core.MetaProgression")

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
    {label = "PREV", action = "prev"},
    {label = "NEXT", action = "next"},
    {label = "EXIT", action = "exit"},
}

local buttonRects = {}
local selectedButton = 1

local function drawPanel(x, y, w, h)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x, y, w, h, 16, 16)
    love.graphics.setLineWidth(2)
    local accent = Theme.color.accent
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.45)
    love.graphics.rectangle("line", x, y, w, h, 16, 16)
end

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
    selectedButton = 2
    buttonRects = {}
end

function TutorialState:update(dt)
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

    love.graphics.clear(Theme.color.bgVoid[1], Theme.color.bgVoid[2], Theme.color.bgVoid[3], 1)
    love.graphics.setColor(Theme.color.bgBase[1], Theme.color.bgBase[2], Theme.color.bgBase[3], 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local panelW, panelH = 1180, 620
    local panelX, panelY = cx - panelW / 2, 170
    drawPanel(panelX, panelY, panelW, panelH)

    love.graphics.setFont(Theme.font("display", 72))
    love.graphics.setColor(Theme.color.accent[1], Theme.color.accent[2], Theme.color.accent[3], self.alpha)
    love.graphics.printf(self.title or "TUTORIAL", 0, 68, sw, "center")

    local page = self.pages[self.page] or self.pages[1] or {title = "", body = {}}
    love.graphics.setFont(Theme.font("uiBold", 28))
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], self.alpha)
    love.graphics.printf(page.title or "", panelX + 50, panelY + 40, panelW - 100, "center")

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
        love.graphics.printf(line, panelX + 90, bodyY + (i - 1) * bodyLineHeight, panelW - 180, "center")
    end

    local indicator = string.format("%d / %d", self.page, #self.pages)
    love.graphics.setFont(Theme.font("mono", 18))
    love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], self.alpha)
    love.graphics.printf(indicator, panelX, panelY + panelH - 54, panelW, "center")

    local buttonW, buttonH, gap = 160, 42, 18
    local navLeftX = cx - gap / 2 - buttonW
    local navRightX = cx + gap / 2
    local buttonY = panelY + panelH - 104
    local exitY = panelY + panelH + 18
    buttonRects = {}

    for i, button in ipairs(buttons) do
        local x
        local y
        if button.action == "exit" then
            x = cx - buttonW / 2
            y = exitY
        else
            x = (button.action == "prev") and navLeftX or navRightX
            y = buttonY
        end

        buttonRects[i] = {x = x, y = y, w = buttonW, h = buttonH, action = button.action}

        local active = i == selectedButton
        love.graphics.setColor(0, 0, 0, 0.5 * self.alpha)
        love.graphics.rectangle("fill", x, y, buttonW, buttonH, 8, 8)
        if active then
            local c = Theme.color.accent
            love.graphics.setColor(c[1], c[2], c[3], self.alpha)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(1, 1, 1, 0.15 * self.alpha)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", x, y, buttonW, buttonH, 8, 8)

        love.graphics.setFont(Theme.font("uiSemiBold", 18))
        if active then
            love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], self.alpha)
        else
            love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], self.alpha)
        end
        love.graphics.printf(button.label, x, y + 10, buttonW, "center")
    end

    local footer
    if self.mode == "onboarding" then
        footer = "LEFT / RIGHT  Navigate   |   ENTER / SPACE  Begin Run   |   ESC  Skip"
    else
        footer = "LEFT / RIGHT  Navigate   |   ENTER / SPACE  Return   |   ESC  Exit"
    end
    love.graphics.setFont(Theme.font("ui", 16))
    love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], self.alpha)
    love.graphics.printf(footer, 0, sh - 84, sw, "center")
end

function TutorialState:keypressed(key)
    if key == "left" then
        if self.page > 1 then
            self.page = self.page - 1
        else
            self.page = #self.pages
        end
        selectedButton = 1
    elseif key == "right" then
        if self.page < #self.pages then
            self.page = self.page + 1
        else
            self.page = 1
        end
        selectedButton = 2
    elseif key == "escape" then
        self:exitTutorial()
    elseif key == "return" or key == "space" then
        if selectedButton == 1 then
            self:keypressed("left")
        elseif selectedButton == 2 then
            self:keypressed("right")
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
        self:keypressed("left")
    elseif index == 2 then
        self:keypressed("right")
    elseif index == 3 then
        self:exitTutorial()
    end
end

return TutorialState
