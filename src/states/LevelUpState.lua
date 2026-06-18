-- LevelUpState.lua
-- Level up screen where player chooses color upgrades

local LevelUpState = {}
local Config = require("src.Config")
local ColorSystem = require("src.gameplay.ColorSystem")
local ArtifactManager = require("src.gameplay.ArtifactManager")
local TutorialSystem = require("src.gameplay.TutorialSystem")
local Theme = require("src.render.Theme")
local Icons = require("src.render.Icons")

-- Per-card design tokens: neon edge (brand color) + deep fill (committed tint).
local CARD_COLORS = {
    r = {edge = "red",     fill = "redDeep"},
    g = {edge = "green",   fill = "greenDeep"},
    b = {edge = "blue",    fill = "blueDeep"},
    y = {edge = "yellow",  fill = "yellowDeep"},
    m = {edge = "magenta", fill = "magentaDeep"},
    c = {edge = "cyan",    fill = "cyanDeep"},
}

local ARTIFACT_ICON_COLORS = {
    PRISM = "magenta",
    HALO = "yellow",
    MIRROR = "cyan",
    LENS = "blue",
    AURORA = "green",
    DIFFRACTION = "red",
    REFRACTION = "accent",
    SUPERNOVA = "warn",
}

-- Notched-rectangle polygon (clipped top-left + bottom-right corners) matching
-- the kit's clip-path. Returns a flat {x1,y1,...} list for love.graphics.polygon.
local function notchedPoly(x, y, w, h, n)
    return {
        x + n,     y,
        x + w,     y,
        x + w,     y + h - n,
        x + w - n, y + h,
        x,         y + h,
        x,         y + n,
    }
end

-- Blend a color toward white by amt (0-1).
local function lighten(c, amt)
    return {
        c[1] + (1 - c[1]) * amt,
        c[2] + (1 - c[2]) * amt,
        c[3] + (1 - c[3]) * amt,
    }
end

local function drawCollectedArtifactIcons(artifacts, centerX, y, width)
    if not artifacts or #artifacts == 0 then
        return
    end

    local count = #artifacts
    local iconSize = 52
    local slotWidth = width / count
    local startX = centerX - width / 2

    love.graphics.setFont(Theme.font("mono", 11))

    for i, artifact in ipairs(artifacts) do
        local slotCenterX = startX + (i - 0.5) * slotWidth
        local iconX = slotCenterX - iconSize / 2
        local iconY = y
        local iconName = artifact.type and string.lower(artifact.type) or nil
        local colorName = ARTIFACT_ICON_COLORS[artifact.type] or "fg3"
        local color = Theme.color[colorName] or Theme.color.fg3
        local levelText = string.format("Lv%d/%d", artifact.level or 0, artifact.maxLevel or 0)
        local textW = love.graphics.getFont():getWidth(levelText)

        love.graphics.setColor(0, 0, 0, 0.42)
        love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize)

        love.graphics.setColor(color[1], color[2], color[3], 0.14)
        love.graphics.rectangle("fill", iconX + 1, iconY + 1, iconSize - 2, iconSize - 2)

        love.graphics.setColor(color[1], color[2], color[3], 0.55)
        love.graphics.rectangle("line", iconX, iconY, iconSize, iconSize)

        if iconName and Icons.has(iconName) then
            Icons.draw(iconName, iconX + 8, iconY + 8, iconSize - 16, {
                width = 1.8,
                color = {color[1], color[2], color[3], 0.95}
            })
        end

        love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], 0.95)
        love.graphics.print(levelText, slotCenterX - textW / 2, iconY + iconSize + 8)
    end
end

-- Valid color choices, narrowed to the tutorial's forced phase when active.
local function getChoices(playerLevel)
    return TutorialSystem.filterChoices(ColorSystem.getValidChoices(playerLevel))
end

-- Clickable card bounds + hovered card code, refreshed every draw.
local cardRects = {}
local hoveredCard = nil

local fontDisplay = nil
local fontSemiBold = nil
local fontUI = nil
local fontMono = nil

local CARD_START_Y = 200

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
        normal    = {"+10% bounce chance", "+3 damage", "Every 10: +1 bounce"},
        intensity = {"INTENSITY!", "+1 bounce", "Chain master!"},
    },
    {
        code = "b", label = "BLUE",
        bg = {0, 0, 0.3}, border = {0, 0.3, 1},
        isSecondary = false,
        isIntensityFn = function(CS) return CS.primary.BLUE and CS.primary.BLUE.level >= 9 end,
        initial   = {"Pierce Shot", "2-5 pierces", "per projectile"},
        normal    = {"+10% pierce chance", "+3 damage", "Every 10: +1 pierce"},
        intensity = {"INTENSITY!", "+2 pierce", "Ultra punch!"},
    },
    {
        code = "y", label = "YELLOW",
        bg = {0.3, 0.3, 0}, border = {1, 1, 0},
        isSecondary = true,
        isIntensityFn = function(CS) return CS.secondary.YELLOW and CS.secondary.YELLOW.level >= 9 end,
        locked    = {"LOCKED!", "Level 10 req."},
        normal    = {"Red + Green", "Faster fire", "Spread + bounce"},
        intensity = {"INTENSITY!", "+spread volley", "+bounce chains"},
    },
    {
        code = "m", label = "MAGENTA",
        bg = {0.3, 0, 0.3}, border = {1, 0, 1},
        isSecondary = true,
        isIntensityFn = function(CS) return CS.secondary.MAGENTA and CS.secondary.MAGENTA.level >= 9 end,
        locked    = {"LOCKED!", "Level 10 req."},
        normal    = {"Red + Blue", "Burst pressure", "Spread + pierce"},
        intensity = {"INTENSITY!", "+1 split", "More chaos!"},
    },
    {
        code = "c", label = "CYAN",
        bg = {0, 0.3, 0.3}, border = {0, 1, 1},
        isSecondary = true,
        isIntensityFn = function(CS) return CS.secondary.CYAN and CS.secondary.CYAN.level >= 9 end,
        locked    = {"LOCKED!", "Level 10 req."},
        normal    = {"Green + Blue", "Frost control", "Bounce + pierce"},
        intensity = {"INTENSITY!", "More frost", "Hard control!"},
    },
}

-- Map number keys (1..n) to the currently-valid choices. Keys are assigned in a
-- stable color-identity order (committed primaries first, then their secondary,
-- then the rest) but only to choices that are actually selectable.
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

-- Angular cyberpunk color card: notched corners, neon rim, additive orb,
-- centered content (CHROMATIC design system).
local function drawCard(def, cardX, cardY, cardWidth, cardHeight, keyNum, isIntensity, colorHistory, isHover, alphaMul, glow)
    alphaMul = alphaMul or 1
    glow = glow or (isHover and 1 or 0)

    -- All card primitives route through sc() so the animator's per-card alpha
    -- (enter fade-in, exit fade-out, sibling dim) multiplies every layer.
    local function sc(r, g, b, a)
        love.graphics.setColor(r, g, b, (a or 1) * alphaMul)
    end

    local tok = CARD_COLORS[def.code] or {edge = "fg1", fill = "bgRaised"}
    local edge = Theme.color[tok.edge]
    local fill = Theme.color[tok.fill]
    local left = cardX - cardWidth / 2
    local notch = 22
    local inset = 2

    sc(edge[1], edge[2], edge[3], 1)
    love.graphics.polygon("fill", notchedPoly(left, cardY, cardWidth, cardHeight, notch))

    sc(fill[1], fill[2], fill[3], 0.94)
    love.graphics.polygon("fill", notchedPoly(left + inset, cardY + inset, cardWidth - inset * 2, cardHeight - inset * 2, notch - inset))

    if glow > 0.01 then
        local hl = lighten(edge, 0.5)
        love.graphics.setLineWidth(2)
        sc(hl[1], hl[2], hl[3], 0.95 * glow)
        love.graphics.polygon("line", notchedPoly(left, cardY, cardWidth, cardHeight, notch))
        love.graphics.setLineWidth(1)
    end

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

    local orbY = cardY + 46
    local prevBlend = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add")
    sc(edge[1], edge[2], edge[3], 0.30 + 0.4 * glow)
    love.graphics.circle("fill", cardX, orbY, 20)
    sc(edge[1], edge[2], edge[3], 0.85)
    love.graphics.circle("fill", cardX, orbY, 10)
    local core = lighten(edge, 0.6)
    sc(core[1], core[2], core[3], 1)
    love.graphics.circle("fill", cardX, orbY, 4)
    love.graphics.setBlendMode(prevBlend)

    local textHeights = {}
    local totalTextHeight = 0

    textHeights[1] = Theme.font("uiSemiBold", 24):getHeight()
    totalTextHeight = totalTextHeight + textHeights[1]

    for i = 1, #lines do
        if i == 1 then
            textHeights[i + 1] = Theme.font("uiMedium", 15):getHeight()
        else
            textHeights[i + 1] = Theme.font("ui", 13):getHeight()
        end
        totalTextHeight = totalTextHeight + textHeights[i + 1]
    end

    local internalBottom = cardY + cardHeight - 24
    local contentTop = orbY - 18
    local contentHeight = internalBottom - contentTop
    local gaps = 20 + (#lines * 10)
    local blockHeight = totalTextHeight + gaps
    local ty = contentTop + math.max(0, (contentHeight - blockHeight) * 0.5) + 52

    love.graphics.setFont(Theme.font("uiSemiBold", 24))
    local nm = lighten(edge, 0.35)
    sc(nm[1], nm[2], nm[3], 1)
    love.graphics.printf(def.label, left, ty, cardWidth, "center")
    ty = ty + textHeights[1] + 20

    for i, line in ipairs(lines) do
        if i == 1 then
            love.graphics.setFont(Theme.font("uiMedium", 15))
            sc(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
            love.graphics.printf(line, left, ty, cardWidth, "center")
            ty = ty + textHeights[i + 1] + 10
        else
            love.graphics.setFont(Theme.font("ui", 13))
            sc(Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], 1)
            love.graphics.printf(line, left, ty, cardWidth, "center")
            ty = ty + textHeights[i + 1] + 10
        end
    end
end

function LevelUpState:enter(previous, data)
    self.previousState = previous
    fontDisplay = fontDisplay or Theme.font("display", 75)
    fontSemiBold = fontSemiBold or Theme.font("uiSemiBold", 24)
    fontUI = fontUI or Theme.font("ui", 16)
    fontMono = fontMono or Theme.font("mono", 12)

    if data then
        self.player = data.player
        self.enemies = data.enemies or {}
        self.returnData = data
    else
        self.returnData = {}
    end

    self:buildCards()
end

-- (Re)create the animator and register one animatable element per valid choice,
-- then kick off the staggered intro. Called on enter and again after a selection
-- that keeps the screen open (multi-level / tutorial).
function LevelUpState:buildCards()
    if not self.player then return end
    local UIAnimator = require("src.effects.UIAnimator")
    self.animator = UIAnimator.new()

    local validChoices = getChoices(self.player.level)
    local valid = {}
    for _, c in ipairs(validChoices) do valid[c] = true end

    for _, def in ipairs(CARD_DEFS) do
        if valid[def.code] then
            self.animator:add(def.code)
        end
    end
    self.animator:enter()
    hoveredCard = nil
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

    if self.animator then
        self.animator:update(dt)
    end
end

function LevelUpState:draw()
    if self.previousState and self.previousState.draw then
        self.previousState:draw()
    end

    local entryFont = love.graphics.getFont()
    local popup = TutorialSystem.peekPopup()
    if popup then
        self:drawTutorialPopup(popup)
    else
        self:drawColorSelect()
    end
    love.graphics.setFont(entryFont)
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

    love.graphics.setFont(fontSemiBold)
    love.graphics.setColor(1, 1, 0.85)
    love.graphics.print(def.title, panelX + 50, panelY + 45)

    love.graphics.setColor(0, 0.85, 1, 0.3)
    love.graphics.line(panelX + 50, panelY + 105, panelX + panelW - 50, panelY + 105)

    love.graphics.setFont(fontUI)
    love.graphics.setColor(0.85, 0.9, 0.95, 1)
    for i, line in ipairs(def.lines) do
        love.graphics.print(line, panelX + 50, panelY + 130 + (i - 1) * 38)
    end

    love.graphics.setColor(0.5, 0.55, 0.65, 0.9)
    love.graphics.print("[Press SPACE / ENTER to continue]", panelX + 50, panelY + panelH - 50)
end

function LevelUpState:drawColorSelect()
    local screenWidth = Config.screen.width
    local screenHeight = Config.screen.height

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local centerX = screenWidth / 2
    local startY = CARD_START_Y

    love.graphics.setFont(fontDisplay)
    local title = "LEVEL UP"
    Theme.setColor("yellow")
    love.graphics.print(title, centerX - fontDisplay:getWidth(title) / 2, startY)

    local ruleW = screenWidth * 0.28
    Theme.setColor("accent", 0.45)
    love.graphics.setLineWidth(1)
    love.graphics.line(centerX - ruleW / 2, startY + 106, centerX + ruleW / 2, startY + 106)

    love.graphics.setFont(fontSemiBold)
    Theme.setColor("fg1")
    local levelText = "Level " .. self.player.level
    love.graphics.print(levelText, centerX - fontSemiBold:getWidth(levelText) / 2, startY + 132)

    if ColorSystem.commitment.primary1 then
        local pathName = ColorSystem.getCurrentPath()
        love.graphics.setFont(fontUI)
        Theme.setColor("fg3")
        local pathLabel = "Current Path"
        love.graphics.print(pathLabel, centerX - fontUI:getWidth(pathLabel) / 2, startY + 172)

        love.graphics.setFont(fontSemiBold)
        Theme.setColor("accent")
        love.graphics.print(pathName, centerX - fontSemiBold:getWidth(pathName) / 2, startY + 194)

        local secondaryName = ColorSystem.getCommittedSecondaryName()
        local secondary = secondaryName and ColorSystem.secondary[secondaryName] or nil
        if secondary and not secondary.unlocked then
            local req1, req2 = secondary.requires[1], secondary.requires[2]
            local pCount = ColorSystem.primary[req1].level
            local sCount = ColorSystem.primary[req2].level
            love.graphics.setFont(fontUI)
            if pCount >= 10 and sCount >= 10 then
                Theme.setColor("yellow")
                local unlockText = secondaryName .. " UNLOCKED!"
                love.graphics.print(unlockText, centerX - fontUI:getWidth(unlockText) / 2, startY + 226)
            elseif pCount >= 10 or sCount >= 10 then
                Theme.setColor("warn")
                local needed = pCount < 10 and ((10 - pCount) .. " more " .. req1)
                                           or  ((10 - sCount) .. " more " .. req2)
                local unlockText = secondaryName .. " unlock in: " .. needed
                love.graphics.print(unlockText, centerX - fontUI:getWidth(unlockText) / 2, startY + 226)
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

    love.graphics.setFont(fontSemiBold)
    Theme.setColor("fg1")
    local instructionText
    if recommendedCode then
        instructionText = "Green light reflects - choose your second wavelength:"
    elseif #ColorSystem.colorHistory == 0 then
        instructionText = "Choose your weapon type:"
    elseif self.player.level == 10 and #validChoices > 1 then
        instructionText = "Upgrade your path OR choose a new color to branch:"
    else
        instructionText = "Continue upgrading:"
    end
    love.graphics.print(instructionText, centerX - fontSemiBold:getWidth(instructionText) / 2, startY + 266)

    local cardY = startY + 320
    local cardWidth = 200
    local cardHeight = 244
    local cardSpacing = 250
    local artifacts = ArtifactManager.getCollectedArtifacts()

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

            local tf = self.animator and self.animator:get(def.code)
            local scale   = tf and tf.scale or 1
            local dx      = tf and tf.dx or 0
            local dy      = tf and tf.dy or 0
            local alphaMul = tf and tf.alpha or 1
            local glow    = tf and tf.glow or (hoveredCard == def.code and 1 or 0)
            local centerYc = cardY + cardHeight / 2

            -- Scale about the card's own center and apply the animated offset.
            love.graphics.push()
            love.graphics.translate(cardX + dx, centerYc + dy)
            love.graphics.scale(scale, scale)
            love.graphics.translate(-cardX, -centerYc)
            drawCard(def, cardX, cardY, cardWidth, cardHeight, keyNum, isIntensity, ColorSystem.colorHistory, hoveredCard == def.code, alphaMul, glow)
            love.graphics.pop()

            cardRects[#cardRects + 1] = {
                x = cardX - cardWidth / 2,
                y = cardY,
                w = cardWidth,
                h = cardHeight,
                code = def.code
            }

            if recommendedCode and def.code == recommendedCode then
                love.graphics.setFont(Theme.font("uiMedium", 14))
                love.graphics.setColor(Theme.color.yellow)
                love.graphics.printf("RECOMMENDED", cardX - cardWidth / 2, cardY - 26, cardWidth, "center")
            end
            cardIndex = cardIndex + 1
        end
    end

    if #artifacts > 0 then
        local cardGroupWidth = math.max(cardWidth * #validChoices, cardSpacing * math.max(0, #validChoices - 1) + cardWidth)
        local artifactStripWidth = math.min(screenWidth * 0.68, math.max(cardGroupWidth + 140, #artifacts * 88))
        local artifactY = cardY + cardHeight + 58
        drawCollectedArtifactIcons(artifacts, centerX, artifactY, artifactStripWidth)
    end
end

function LevelUpState:selectColor(colorCode)
    if self.animator and self.animator:isBusy() then return end

    local validChoices = getChoices(self.player.level)
    for _, valid in ipairs(validChoices) do
        if valid == colorCode then
            -- Apply the gameplay effect immediately so logic stays consistent;
            -- only the visual exit (and the state pop) is deferred.
            self.player:levelUp()
            ColorSystem.addColor(self.player.weapon, colorCode)
            ColorSystem.applyEffects(self.player.weapon)
            TutorialSystem.onColorAdded(colorCode)

            local function finish()
                if not self.player:canLevelUp() and not TutorialSystem.hasPopup() then
                    require("src.core.StateManager").pop()
                else
                    -- More choices to make (multi-level / tutorial popup): rebuild.
                    self:buildCards()
                end
            end

            if self.animator then
                self.animator:select(colorCode, function()
                    self.animator:exit(finish)
                end)
            else
                finish()
            end
            return
        end
    end
end

function LevelUpState:keypressed(key)
    if TutorialSystem.hasPopup() then
        if key == "space" or key == "return" or key == "escape" then
            self:dismissTutorialPopup()
        end
        return
    end

    if self.animator and self.animator:isBusy() then return end
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

function LevelUpState:dismissTutorialPopup()
    TutorialSystem.dismissPopup()
    if not TutorialSystem.hasPopup() and not self.player:canLevelUp() then
        require("src.core.StateManager").pop()
    end
end

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

    if self.animator and self.animator:isBusy() then return end

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

    local code = cardAt(x, y)
    if code ~= hoveredCard then
        if self.animator then
            if hoveredCard then self.animator:setHover(hoveredCard, false) end
            if code then self.animator:setHover(code, true) end
        end
        hoveredCard = code
    end
end

return LevelUpState
