-- LevelUpState.lua
-- Level up screen where player chooses color upgrades

local LevelUpState = {}
local Config = require("src.Config")
local ColorSystem = require("src.gameplay.ColorSystem")
local ArtifactManager = require("src.gameplay.ArtifactManager")
local TutorialSystem = require("src.gameplay.TutorialSystem")

-- Valid color choices, narrowed to the tutorial's forced phase when active.
local function getChoices(playerLevel)
    return TutorialSystem.filterChoices(ColorSystem.getValidChoices(playerLevel))
end

-- Clickable card bounds + hovered card code, refreshed every draw.
local cardRects = {}
local hoveredCard = nil

local CARD_START_Y = 200  -- y offset for the level-up overlay header
local CARD_OFFSET_Y = 250 -- cards sit this many pixels below CARD_START_Y

-- Static per-color card definitions
local CARD_DEFS = {
    {
        code = "r", label = "RED",
        bg = {0.3, 0, 0}, border = {1, 0, 0},
        isSecondary = false,
        isIntensityFn = function(CS) return CS.primary.RED and CS.primary.RED.level >= 9 end,
        initial   = {"Spread Shot", "2-6 projectiles", "in a cone"},
        normal    = {"+1 projectile", "+2 damage", "More spread!"},
        intensity = {"INTENSITY!", "+1 projectile", "Extra power!"},
    },
    {
        code = "g", label = "GREEN",
        bg = {0, 0.3, 0}, border = {0, 1, 0},
        isSecondary = false,
        isIntensityFn = function(CS) return CS.primary.GREEN and CS.primary.GREEN.level >= 9 end,
        initial   = {"Bounce Shot", "60-100% chance", "to chain"},
        normal    = {"+8% bounce", "+3 damage", "More chains!"},
        intensity = {"INTENSITY!", "+1 bounce", "Chain master!"},
    },
    {
        code = "b", label = "BLUE",
        bg = {0, 0, 0.3}, border = {0, 0.3, 1},
        isSecondary = false,
        isIntensityFn = function(CS) return CS.primary.BLUE and CS.primary.BLUE.level >= 9 end,
        initial   = {"Pierce Shot", "2-5 pierces", "per projectile"},
        normal    = {"+1 pierce", "+3 damage", "More punch!"},
        intensity = {"INTENSITY!", "+2 pierce", "Ultra punch!"},
    },
    {
        code = "y", label = "YELLOW",
        bg = {0.3, 0.3, 0}, border = {1, 1, 0},
        isSecondary = true,
        isIntensityFn = function(CS) return CS.secondary.YELLOW and CS.secondary.YELLOW.level >= 9 end,
        locked    = {"LOCKED!", "Level 10 req."},
        normal    = {"Red + Green", "Spread shots", "Bounce chains"},
        intensity = {"INTENSITY!", "+spread volley", "+bounce chains"},
    },
    {
        code = "m", label = "MAGENTA",
        bg = {0.3, 0, 0.3}, border = {1, 0, 1},
        isSecondary = true,
        isIntensityFn = function(CS) return CS.secondary.MAGENTA and CS.secondary.MAGENTA.level >= 9 end,
        locked    = {"LOCKED!", "Level 10 req."},
        normal    = {"+0.4 splits", "+2 damage", "Explode more!"},
        intensity = {"INTENSITY!", "+1 split", "More chaos!"},
    },
    {
        code = "c", label = "CYAN",
        bg = {0, 0.3, 0.3}, border = {0, 1, 1},
        isSecondary = true,
        isIntensityFn = function(CS) return CS.secondary.CYAN and CS.secondary.CYAN.level >= 9 end,
        locked    = {"LOCKED!", "Level 10 req."},
        normal    = {"+3° homing", "+2 damage", "Track better!"},
        intensity = {"INTENSITY!", "+6° homing", "Perfect aim!"},
    },
}

-- Map number keys (1..n) to the currently-valid choices. Keys are assigned in a
-- stable color-identity order (committed primaries first, then their secondary,
-- then the rest) but only to choices that are actually selectable, so the key
-- shown on a card always selects that card — including during tutorial phases
-- where only a subset is offered.
local function buildKeyMap(validChoices)
    local valid = {}
    for _, c in ipairs(validChoices) do valid[c] = true end

    local order = {}
    local seen = {}
    local function add(code)
        if code and valid[code] and not seen[code] then
            order[#order + 1] = code
            seen[code] = true
        end
    end

    if ColorSystem.commitment.primary1 then
        add(ColorSystem.commitment.primary1:lower():sub(1, 1))
    end
    if ColorSystem.commitment.primary2 then
        add(ColorSystem.commitment.primary2:lower():sub(1, 1))
        add(ColorSystem.getCommittedSecondaryCode())
    end
    for _, c in ipairs({"r", "g", "b", "y", "m", "c"}) do add(c) end

    local keyMap = {}
    for i, code in ipairs(order) do keyMap[i] = code end
    return keyMap
end

local function drawCard(def, cardX, cardY, cardWidth, cardHeight, keyNum, isIntensity, colorHistory)
    love.graphics.setColor(def.bg[1], def.bg[2], def.bg[3], 0.7)
    love.graphics.rectangle("fill", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
    love.graphics.setColor(def.border[1], def.border[2], def.border[3])
    love.graphics.rectangle("line", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
    love.graphics.print(def.label, cardX - cardWidth/2 + 10, cardY + 15, 0, 1.5, 1.5)
    love.graphics.setColor(1, 1, 1, 0.9)

    local lines
    if def.isSecondary and #colorHistory < 10 then
        lines = def.locked
    elseif #colorHistory == 0 then
        lines = def.initial or def.normal
    elseif isIntensity then
        lines = def.intensity
    else
        lines = def.normal
    end

    for i, line in ipairs(lines) do
        love.graphics.print(line, cardX - cardWidth/2 + 10, cardY + 35 + (i * 25), 0, 1.0, 1.0)
    end

    if keyNum then
        love.graphics.print("[Press " .. keyNum .. "]", cardX - cardWidth/2 + 10, cardY + cardHeight - 35, 0, 1.0, 1.0)
    end
end

function LevelUpState:enter(previous, data)
    self.previousState = previous
    if data then
        self.player = data.player
        self.enemies = data.enemies or {}
        self.returnData = data
    else
        self.returnData = {}
    end
end

function LevelUpState:update(dt)
    local World = require("src.gameplay.World")
    local FloatingTextSystem = require("src.effects.FloatingTextSystem")
    local VFXLibrary = require("src.effects.VFXLibrary")

    if self.returnData.musicReactor then
        self.returnData.musicReactor:update(dt)
    end

    World.update(dt, self.returnData.musicReactor)
    FloatingTextSystem.update(dt)
    VFXLibrary.update(dt)
end

function LevelUpState:draw()
    if self.previousState and self.previousState.draw then
        self.previousState:draw()
    end
    local popup = TutorialSystem.peekPopup()
    if popup then
        self:drawTutorialPopup(popup)
    else
        self:drawColorSelect()
    end
end

function LevelUpState:drawTutorialPopup(def)
    local screenWidth = Config.screen.width
    local screenHeight = Config.screen.height

    love.graphics.setColor(0, 0, 0, 0.88)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local panelW = 1000
    local panelH = 360
    local panelX = (screenWidth - panelW) / 2
    local panelY = (screenHeight - panelH) / 2

    love.graphics.setColor(0.02, 0.02, 0.03, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 14, 14)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0, 0.85, 1, 0.5)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 14, 14)

    -- Title
    love.graphics.setColor(1, 1, 0.85)
    love.graphics.print(def.title, panelX + 50, panelY + 45, 0, 2.2, 2.2)

    love.graphics.setColor(0, 0.85, 1, 0.3)
    love.graphics.line(panelX + 50, panelY + 105, panelX + panelW - 50, panelY + 105)

    -- Body
    love.graphics.setColor(0.85, 0.9, 0.95, 1)
    for i, line in ipairs(def.lines) do
        love.graphics.print(line, panelX + 50, panelY + 130 + (i - 1) * 38, 0, 1.4, 1.4)
    end

    -- Footer
    love.graphics.setColor(0.5, 0.55, 0.65, 0.9)
    love.graphics.print("[Press SPACE / ENTER to continue]", panelX + 50, panelY + panelH - 50, 0, 1.2, 1.2)
end

function LevelUpState:drawColorSelect()
    local screenWidth = Config.screen.width
    local screenHeight = Config.screen.height

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local centerX = screenWidth / 2
    local startY = CARD_START_Y

    love.graphics.setColor(1, 1, 0)
    love.graphics.print("🎉 LEVEL UP! 🎉", centerX - 180, startY, 0, 3.5, 3.5)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Level " .. self.player.level, centerX - 60, startY + 90, 0, 2, 2)

    if ColorSystem.commitment.primary1 then
        local pathName = ColorSystem.getCurrentPath()
        love.graphics.setColor(0, 0.94, 1)
        love.graphics.print("Current Path: " .. pathName, centerX - 180, startY + 130, 0, 1.5, 1.5)

        local secondaryName = ColorSystem.getCommittedSecondaryName()
        local secondary = secondaryName and ColorSystem.secondary[secondaryName] or nil
        if secondary and not secondary.unlocked then
            local req1, req2 = secondary.requires[1], secondary.requires[2]
            local pCount = ColorSystem.primary[req1].level
            local sCount = ColorSystem.primary[req2].level
            if pCount >= 10 and sCount >= 10 then
                love.graphics.setColor(1, 1, 0)
                love.graphics.print(secondaryName .. " UNLOCKED!", centerX - 180, startY + 165, 0, 1.5, 1.5)
            elseif pCount >= 10 or sCount >= 10 then
                love.graphics.setColor(1, 0.7, 0)
                local needed = pCount < 10 and ((10 - pCount) .. " more " .. req1)
                                           or  ((10 - sCount) .. " more " .. req2)
                love.graphics.print(secondaryName .. " unlock in: " .. needed, centerX - 220, startY + 165, 0, 1.5, 1.5)
            end
        end
    end

    local validChoices = getChoices(self.player.level)
    local recommendedCode = TutorialSystem.getRecommendedCode()

    local function isValid(color)
        for _, c in ipairs(validChoices) do
            if c == color then return true end
        end
        return false
    end

    love.graphics.setColor(1, 1, 1)
    local instructionText
    if recommendedCode then
        instructionText = "Green light reflects — choose your second wavelength:"
    elseif #ColorSystem.colorHistory == 0 then
        instructionText = "Choose your weapon type:"
    elseif self.player.level == 10 and #validChoices > 1 then
        instructionText = "Upgrade your path OR choose a new color to branch:"
    else
        instructionText = "Continue upgrading:"
    end
    love.graphics.print(instructionText, centerX - 250, startY + 200, 0, 1.5, 1.5)

    local artifacts = ArtifactManager.getCollectedArtifacts()
    if #artifacts > 0 then
        local artifactX = screenWidth - 350
        local artifactY = startY + 250
        love.graphics.setColor(0.5, 1, 1)
        love.graphics.print("💎 Collected Artifacts:", artifactX, artifactY, 0, 1.3, 1.3)
        artifactY = artifactY + 35
        for _, artifact in ipairs(artifacts) do
            love.graphics.setColor(0.7, 0.9, 1)
            local levelText = string.format("Lv%d/%d", artifact.level, artifact.maxLevel)
            love.graphics.print(string.format("%s %s", artifact.name, levelText), artifactX, artifactY, 0, 1.1, 1.1)
            artifactY = artifactY + 28
        end
    end

    local cardY = startY + 250
    local cardWidth = 220
    local cardHeight = 180
    local cardSpacing = 250

    local keyMap = buildKeyMap(validChoices)

    local function getKeyForColor(color)
        for key, mappedColor in pairs(keyMap) do
            if mappedColor == color then return key end
        end
        return nil
    end

    cardRects = {}
    local cardIndex = 0
    for _, def in ipairs(CARD_DEFS) do
        if isValid(def.code) then
            local keyNum = getKeyForColor(def.code)
            local cardX = centerX - ((#validChoices - 1) * cardSpacing / 2) + (cardIndex * cardSpacing)
            local isIntensity = def.isIntensityFn(ColorSystem)
            drawCard(def, cardX, cardY, cardWidth, cardHeight, keyNum, isIntensity, ColorSystem.colorHistory)

            cardRects[#cardRects + 1] = {x = cardX - cardWidth/2, y = cardY, w = cardWidth, h = cardHeight, code = def.code}

            -- Brighten the border of the hovered card for click affordance.
            if hoveredCard == def.code then
                love.graphics.setLineWidth(3)
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.rectangle("line", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
                love.graphics.setLineWidth(1)
            end

            if recommendedCode and def.code == recommendedCode then
                love.graphics.setColor(1, 1, 0.4)
                love.graphics.print("RECOMMENDED", cardX - cardWidth/2 + 10, cardY - 28, 0, 1.1, 1.1)
            end
            cardIndex = cardIndex + 1
        end
    end
end

function LevelUpState:selectColor(colorCode)
    local validChoices = getChoices(self.player.level)
    for _, valid in ipairs(validChoices) do
        if valid == colorCode then
            self.player:levelUp()
            ColorSystem.addColor(self.player.weapon, colorCode)
            ColorSystem.applyEffects(self.player.weapon)
            TutorialSystem.onColorAdded(colorCode)

            -- Stay open if a tutorial popup was just queued (it must be shown even
            -- when the player has no further level-ups banked).
            if not self.player:canLevelUp() and not TutorialSystem.hasPopup() then
                local StateManager = require("src.core.StateManager")
                StateManager.pop()
            end
            return
        end
    end
end

function LevelUpState:keypressed(key)
    -- A pending tutorial popup eats input until dismissed.
    if TutorialSystem.hasPopup() then
        if key == "space" or key == "return" or key == "escape" then
            self:dismissTutorialPopup()
        end
        return
    end

    if key == "escape" then return end

    local validChoices = getChoices(self.player.level)
    local keyMap = buildKeyMap(validChoices)

    if key == "1" and keyMap[1] then
        self:selectColor(keyMap[1])
    elseif key == "2" and keyMap[2] then
        self:selectColor(keyMap[2])
    elseif key == "3" and keyMap[3] then
        self:selectColor(keyMap[3])
    end
end

-- Dismiss the current tutorial popup; when the queue empties and the player has
-- no level-up left to spend, return to gameplay.
function LevelUpState:dismissTutorialPopup()
    TutorialSystem.dismissPopup()
    if not TutorialSystem.hasPopup() and not self.player:canLevelUp() then
        require("src.core.StateManager").pop()
    end
end

-- Code of the card under a point, or nil. Uses the bounds recorded during draw.
local function cardAt(x, y)
    for _, rect in ipairs(cardRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            return rect.code
        end
    end
    return nil
end

function LevelUpState:mousepressed(x, y, button)
    if button ~= 1 then return end

    if TutorialSystem.hasPopup() then
        self:dismissTutorialPopup()
        return
    end

    local code = cardAt(x, y)
    if code then
        self:selectColor(code)
    end
end

function LevelUpState:mousemoved(x, y)
    if TutorialSystem.hasPopup() then
        hoveredCard = nil
        return
    end
    hoveredCard = cardAt(x, y)
end

return LevelUpState
