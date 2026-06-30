-- ProgressionState.lua
-- Persistent profile / unlock screen for long-term collection tracking.

local ProgressionState = {}
local Config = require("src.Config")
local Theme = require("src.render.Theme")
local MetaProgression = require("src.core.MetaProgression")
local Icons = require("src.render.Icons")
local ArtifactManager = require("src.gameplay.ArtifactManager")
local ShellStyle = require("src.ui.ShellStyle")
local StateManager = require("src.core.StateManager")
local FirstEncounter = require("src.gameplay.FirstEncounter")
local FirstEncounterCard = require("src.ui.FirstEncounterCard")

local buttons = {
    {label = "REPLAY TUTORIAL", action = "tutorial"},
    {label = "RESET PROFILE", action = "reset"},
    {label = "BACK", action = "back"},
}

local selectedButton = 1
local buttonRects = {}
local artifactRects = {}
local selectedArtifact = 1
local focusArea = "artifacts"
local bgShader = nil
local RESET_PENALTY_RATE = 0.25

local SHOP_ARTIFACTS = {
    {type = "PRISM", baseCost = 50},
    {type = "HALO", baseCost = 60},
    {type = "LENS", baseCost = 65},
    {type = "MIRROR", baseCost = 80},
    {type = "AURORA", baseCost = 90},
    {type = "DIFFRACTION", baseCost = 105},
    {type = "REFRACTION", baseCost = 120},
    {type = "SUPERNOVA", baseCost = 150},
}

local ARTIFACT_COLOR_KEYS = {
    PRISM = "magenta",
    HALO = "yellow",
    LENS = "blue",
    MIRROR = "cyan",
    AURORA = "green",
    DIFFRACTION = "red",
    REFRACTION = "accent",
    SUPERNOVA = "warn",
}

local function getArtifactCostMap()
    local costs = {}
    for _, item in ipairs(SHOP_ARTIFACTS) do
        costs[item.type] = {baseCost = item.baseCost}
    end
    return costs
end

local function drawColorTheoryStrip(x, y, w, h, alpha)
    local accent = Theme.color.accent

    love.graphics.setColor(0, 0, 0, 0.34 * alpha)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.2 * alpha)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)

    love.graphics.setFont(Theme.font("ui", 14))
    love.graphics.setColor(Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], 0.9 * alpha)
    love.graphics.print("Pick two primaries. Their additive mix unlocks one secondary.", x + 18, y + 10)
    love.graphics.print("Dominant color changes projectiles, dash, artifacts, and VFX.", x + 18, y + 30)

    local chipX = x + w - 372
    local chipY = y + 16
    local chips = {
        {"R+G", "Y", Theme.color.yellow},
        {"R+B", "M", Theme.color.magenta},
        {"G+B", "C", Theme.color.cyan},
    }

    love.graphics.setFont(Theme.font("mono", 12))
    for i, chip in ipairs(chips) do
        local cx = chipX + (i - 1) * 120
        local color = chip[3]
        love.graphics.setColor(color[1], color[2], color[3], 0.08 * alpha)
        love.graphics.rectangle("fill", cx, chipY, 96, 24, 6, 6)
        love.graphics.setColor(color[1], color[2], color[3], 0.45 * alpha)
        love.graphics.rectangle("line", cx, chipY, 96, 24, 6, 6)
        love.graphics.setColor(color[1], color[2], color[3], 0.92 * alpha)
        love.graphics.printf(chip[1] .. " = " .. chip[2], cx, chipY + 5, 96, "center")
    end
end

local function drawArtifactCard(item, x, y, w, h, isSelected, canAfford)
    local colorKey = ARTIFACT_COLOR_KEYS[item.type] or "fg3"
    local fullColor = Theme.color[colorKey] or Theme.color.fg3
    local color = fullColor
    local iconName = string.lower(item.type)
    local title = item.name or item.type
    local statusText
    local statusColor
    local levelText = string.format("LV %d / %d", item.level or 0, item.maxLevel or 1)

    if item.isMaxLevel then
        statusText = "MAX"
        statusColor = Theme.color.ok
    elseif canAfford then
        statusText = string.format("NEXT %d CHROMA", item.cost)
        statusColor = Theme.color.accent
    else
        statusText = string.format("NEXT %d CHROMA", item.cost)
        statusColor = Theme.color.fg3
    end

    if item.level <= 0 then
        local grey = 0.58
        color = {
            fullColor[1] * 0.35 + grey * 0.65,
            fullColor[2] * 0.35 + grey * 0.65,
            fullColor[3] * 0.35 + grey * 0.65,
        }
    elseif item.isMaxLevel then
        color = fullColor
    elseif canAfford then
        color = fullColor
    end

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(color[1], color[2], color[3], item.level > 0 and 0.16 or 0.08)
    love.graphics.rectangle("fill", x + 1, y + 1, w - 2, h - 2, 6, 6)

    love.graphics.setLineWidth(isSelected and 2 or 1)
    if isSelected then
        love.graphics.setColor(color[1], color[2], color[3], 0.95)
    else
        love.graphics.setColor(color[1], color[2], color[3], 0.4)
    end
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setLineWidth(1)

    if Icons.has(iconName) then
        Icons.draw(iconName, x + 18, y + 18, 58, {
            width = 2.0,
            color = {color[1], color[2], color[3], item.level > 0 and 0.92 or 0.45}
        })
    end

    love.graphics.setFont(Theme.font("uiSemiBold", 18))
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
    love.graphics.print(title, x + 88, y + 18)

    love.graphics.setFont(Theme.font("mono", 12))
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.print(levelText, x + w - love.graphics.getFont():getWidth(levelText) - 18, y + 21)

    love.graphics.setFont(Theme.font("ui", 14))
    love.graphics.setColor(Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], 1)
    love.graphics.printf(item.description or "Artifact unlock", x + 88, y + 48, w - 104)

    love.graphics.setFont(Theme.font("mono", 13))
    love.graphics.setColor(statusColor[1], statusColor[2], statusColor[3], 1)
    love.graphics.print(statusText, x + 18, y + h - 16)
end

function ProgressionState:enter(previous, data)
    self.alpha = 0
    selectedButton = 1
    selectedArtifact = 1
    focusArea = "artifacts"
    buttonRects = {}
    artifactRects = {}
    self.profile = MetaProgression.getProfile()
    self.notice = nil
    self.noticeColor = Theme.color.fg3
    self.noticeTimer = 0
    bgShader = bgShader or ShellStyle.loadShader("ProgressionState")
    self.explainerCard = nil
    if FirstEncounter.shouldTeach("chroma_spend") then
        self.explainerCard = FirstEncounter.cardFor("chroma_spend")
    end
end

function ProgressionState:update(dt)
    ShellStyle.updateMusic(dt)
    self.alpha = math.min(1, self.alpha + dt * 3)
    if self.noticeTimer > 0 then
        self.noticeTimer = math.max(0, self.noticeTimer - dt)
    end
end

function ProgressionState:draw()
    local sw, sh = Config.screen.width, Config.screen.height
    local margin = sh * 0.1

    ShellStyle.drawBackground(self.alpha, bgShader)
    ShellStyle.drawRgbTitle("PROGRESSION", margin, margin, Theme.font("display", 72), self.alpha)

    -- Nav rail (same bar-column calculation as other states)
    local bracketHeight = 44
    local gap = 16
    local menuBottomLimit = sh - margin
    local totalBtnH = #buttons * bracketHeight + (#buttons - 1) * gap
    local btnStackY = menuBottomLimit - totalBtnH

    local barWidth, barGap, startX = 56, 4, 2
    local barStep = barWidth + barGap
    local titleW = ShellStyle.measureSpacedText("CHROMATIC", Theme.font("display", 72), 10)
    local logoCenterX = margin + titleW / 2
    local centerCol = math.floor((logoCenterX - startX) / barStep) + 1
    local colStart = math.max(1, centerCol - 2)
    if colStart + 4 > 32 then colStart = 28 end
    local btnX = startX + (colStart - 1) * barStep
    local btnW = 5 * barWidth + 4 * barGap

    buttonRects = ShellStyle.layoutVerticalRail(buttons, btnX, btnStackY, {buttonW = btnW, buttonH = bracketHeight, gap = gap})
    ShellStyle.drawVerticalRail(buttons, buttonRects, focusArea == "buttons" and selectedButton or nil, self.alpha, Theme.font("uiSemiBold", 18))

    -- Right panel (same placement formula as OptionsState / AtlasState)
    local panelX = btnX + btnW + 120
    local panelY = 320
    local panelW = sw - panelX - margin
    local panelH = sh - panelY - margin

    ShellStyle.drawPanel(panelX, panelY, panelW, panelH, self.alpha, Theme.color.accent)

    -- Panel header: title + chroma counter
    love.graphics.setFont(Theme.font("uiBold", 24))
    love.graphics.setColor(0.85, 0.85, 0.9, self.alpha)
    love.graphics.print("UPGRADES", panelX + 40, panelY + 40)

    local chromaText = string.format("Chroma: %d", MetaProgression.getChroma())
    local chromaFont = Theme.font("uiSemiBold", 20)
    local chromaW = chromaFont:getWidth(chromaText) + 32
    local chromaX = panelX + panelW - 40 - chromaW
    local chromaY = panelY + 38
    love.graphics.setFont(chromaFont)
    love.graphics.setColor(0, 0, 0, 0.55 * self.alpha)
    love.graphics.rectangle("fill", chromaX, chromaY, chromaW, 36, 6, 6)
    love.graphics.setColor(Theme.color.accent[1], Theme.color.accent[2], Theme.color.accent[3], 0.28 * self.alpha)
    love.graphics.rectangle("line", chromaX, chromaY, chromaW, 36, 6, 6)
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], self.alpha)
    love.graphics.print(chromaText, chromaX + 16, chromaY + 7)

    -- Dividing line
    local ac = Theme.color.accent
    love.graphics.setColor(ac[1], ac[2], ac[3], 0.15 * self.alpha)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 40, panelY + 90, panelX + panelW - 40, panelY + 90)

    -- Color theory strip
    drawColorTheoryStrip(panelX + 40, panelY + 100, panelW - 80, 54, self.alpha)

    -- Artifact grid
    artifactRects = {}
    local cardW, cardH = 420, 95
    local cardGapX, cardGapY = 28, 10
    local cardStartX = panelX + 40 + math.floor((panelW - 80 - (cardW * 2 + cardGapX)) / 2)
    local cardStartY = panelY + 168

    for index, shopItem in ipairs(SHOP_ARTIFACTS) do
        local definition = ArtifactManager.levelDefinitions[shopItem.type] or {}
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local x = cardStartX + column * (cardW + cardGapX)
        local y = cardStartY + row * (cardH + cardGapY)
        local persistentLevel = MetaProgression.getArtifactLevel(shopItem.type)
        local maxLevel = definition.maxLevel or 1
        local nextCost = persistentLevel < maxLevel and MetaProgression.getNextArtifactCost(shopItem.type, shopItem.baseCost) or 0
        local item = {
            type = shopItem.type,
            cost = nextCost,
            name = definition.name or shopItem.type,
            description = definition.description or "Artifact unlock",
            level = persistentLevel,
            maxLevel = maxLevel,
            isMaxLevel = persistentLevel >= maxLevel,
        }
        local canAfford = not item.isMaxLevel and MetaProgression.getChroma() >= nextCost
        local isSelected = focusArea == "artifacts" and selectedArtifact == index
        artifactRects[index] = {x = x, y = y, w = cardW, h = cardH, index = index}
        drawArtifactCard(item, x, y, cardW, cardH, isSelected, canAfford)
    end

    if self.notice and self.noticeTimer > 0 then
        love.graphics.setFont(Theme.font("mono", 15))
        love.graphics.setColor(self.noticeColor[1], self.noticeColor[2], self.noticeColor[3], self.alpha)
        love.graphics.printf(self.notice, panelX + 40, panelY + panelH - 50, panelW - 80, "center")
    end

    love.graphics.setLineWidth(1)
    ShellStyle.drawFooter("ENTER / SPACE to buy or activate   |   TAB / UP / DOWN to switch sections   |   ESC to return", sh - 76, self.alpha)
    if self.explainerCard then
        FirstEncounterCard.drawModal(self.explainerCard)
    end
end

local function buttonAt(x, y)
    for i, rect in ipairs(buttonRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            return i
        end
    end
    return nil
end

local function artifactAt(x, y)
    for _, rect in ipairs(artifactRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            return rect.index
        end
    end
    return nil
end

function ProgressionState:flashNotice(text, color)
    self.notice = text
    self.noticeColor = color or Theme.color.fg3
    self.noticeTimer = 2.2
end

function ProgressionState:purchaseSelectedArtifact()
    local entry = SHOP_ARTIFACTS[selectedArtifact]
    if not entry then
        return
    end

    local definition = ArtifactManager.levelDefinitions[entry.type] or {}
    local maxLevel = definition.maxLevel or 1
    local ok, reason, newLevel = MetaProgression.purchaseArtifactLevel(entry.type, entry.baseCost, maxLevel)
    self.profile = MetaProgression.getProfile()

    if ok then
        local artifactName = definition.name or entry.type
        local message
        if newLevel == 1 then
            message = string.format("%s unlocked at Lv1 for future runs.", artifactName)
        else
            message = string.format("%s upgraded to Lv%d for future runs.", artifactName, newLevel)
        end
        self:flashNotice(message, Theme.color.ok)
        return
    end

    if reason == "max_level" then
        self:flashNotice("Artifact already at max level.", Theme.color.warn)
    elseif reason == "insufficient_chroma" or reason == "insufficient_shards" then
        self:flashNotice("Not enough Chroma.", Theme.color.danger)
    else
        self:flashNotice("Purchase failed.", Theme.color.danger)
    end
end

function ProgressionState:openConfirm()
    local StateManager = require("src.core.StateManager")
    local refundPreview = MetaProgression.getArtifactRefundPreview(getArtifactCostMap(), RESET_PENALTY_RATE)
    local message
    if refundPreview.invested > 0 then
        message = string.format(
            "Reset profile and disable all artifact upgrades? Artifact Chroma spent: %d. Refund: %d after %d reset penalty.",
            refundPreview.invested,
            refundPreview.refund,
            refundPreview.penalty
        )
    else
        message = "Reset profile and disable all artifact upgrades? No artifact Chroma is available to refund."
    end

    StateManager.push("Confirm", {
        title = "RESET PROFILE",
        message = message,
        yesLabel = "RESET",
        noLabel = "CANCEL",
        onConfirm = function()
            local result = MetaProgression.reset({
                refundArtifacts = true,
                artifactCosts = getArtifactCostMap(),
                penaltyRate = RESET_PENALTY_RATE,
            })
            ArtifactManager.reset()
            self.profile = MetaProgression.getProfile()
            selectedArtifact = 1
            focusArea = "artifacts"
            self:flashNotice(
                string.format("Profile reset. Artifacts disabled. Refunded %d Chroma, penalty %d.", result.refund, result.penalty),
                Theme.color.warn
            )
        end,
    })
end

function ProgressionState:openTutorial()
    local StateManager = require("src.core.StateManager")
    StateManager.switch("Tutorial", {
        mode = "review",
        nextState = "Menu",
    })
end

function ProgressionState:back()
    require("src.core.StateManager").switch("Menu")
end

function ProgressionState:activate(action)
    if action == "tutorial" then
        self:openTutorial()
    elseif action == "reset" then
        self:openConfirm()
    elseif action == "back" then
        self:back()
    end
end

function ProgressionState:keypressed(key)
    if self.explainerCard then
        if key == "a" then
            FirstEncounter.markTaught("chroma_spend")
            self.explainerCard = nil
            StateManager.switch("Atlas")
        elseif key == "space" or key == "return" or key == "escape" then
            FirstEncounter.markTaught("chroma_spend")
            self.explainerCard = nil
        end
        return
    end
    if key == "tab" then
        focusArea = focusArea == "artifacts" and "buttons" or "artifacts"
    elseif key == "up" then
        if focusArea == "buttons" then
            focusArea = "artifacts"
        else
            selectedArtifact = selectedArtifact - 2
            if selectedArtifact < 1 then
                selectedArtifact = selectedArtifact + 2
            end
        end
    elseif key == "down" then
        if focusArea == "artifacts" then
            local candidate = selectedArtifact + 2
            if candidate <= #SHOP_ARTIFACTS then
                selectedArtifact = candidate
            else
                focusArea = "buttons"
            end
        else
            focusArea = "artifacts"
        end
    elseif key == "left" then
        if focusArea == "artifacts" then
            selectedArtifact = math.max(1, selectedArtifact - 1)
        else
            selectedButton = selectedButton - 1
            if selectedButton < 1 then selectedButton = #buttons end
        end
    elseif key == "right" then
        if focusArea == "artifacts" then
            selectedArtifact = math.min(#SHOP_ARTIFACTS, selectedArtifact + 1)
        else
            selectedButton = selectedButton + 1
            if selectedButton > #buttons then selectedButton = 1 end
        end
    elseif key == "return" or key == "space" then
        if focusArea == "artifacts" then
            self:purchaseSelectedArtifact()
        else
            self:activate(buttons[selectedButton].action)
        end
    elseif key == "escape" then
        self:back()
    end
end

function ProgressionState:mousemoved(x, y)
    local artifactIndex = artifactAt(x, y)
    if artifactIndex then
        focusArea = "artifacts"
        selectedArtifact = artifactIndex
        return
    end

    local index = buttonAt(x, y)
    if index then
        focusArea = "buttons"
        selectedButton = index
    end
end

function ProgressionState:mousepressed(x, y, button)
    if button ~= 1 then return end
    local artifactIndex = artifactAt(x, y)
    if artifactIndex then
        focusArea = "artifacts"
        selectedArtifact = artifactIndex
        self:purchaseSelectedArtifact()
        return
    end

    local index = buttonAt(x, y)
    if index then
        focusArea = "buttons"
        self:activate(buttons[index].action)
    end
end

return ProgressionState
