-- AtlasState.lua
-- In-game reference for CHROMATIC colors, artifacts, and light interactions.

local AtlasState = {}

local Config = require("src.Config")
local GameConfig = require("src.core.GameConfig")
local Theme = require("src.render.Theme")
local SynergySystem = require("src.gameplay.SynergySystem")
local ShellStyle = require("src.ui.ShellStyle")
local AtlasData = require("src.data.AtlasData")
local colorEntries = AtlasData.colorEntries
local artifactEntries = AtlasData.artifactEntries

local tabs = {
    {label = "COLORS", key = "colors"},
    {label = "ARTIFACTS", key = "artifacts"},
    {label = "SYNERGIES", key = "synergies"},
}

local selectedTab = 1
local selectedEntry = 1
local alpha = 0
local entryRects = {}
local tabRects = {}
local backRect = nil
local backHovered = false
local navRects = {}

local fontDisplay = nil
local fontTitle = nil
local fontUI = nil
local fontMono = nil
local bgShader = nil

local colorOrder = {"RED", "GREEN", "BLUE", "YELLOW", "MAGENTA", "CYAN"}
local synergyEntries = {}
for _, artifact in ipairs(artifactEntries) do
    local definitions = SynergySystem.definitions[artifact.name] or {}
    local recipes = {}
    for _, colorName in ipairs(colorOrder) do
        local synergy = definitions[colorName]
        if synergy then
            recipes[#recipes + 1] = {
                colorName = colorName,
                color = Theme.color[string.lower(colorName)] or Theme.color.fg2,
                name = synergy.name,
                description = synergy.description,
            }
        end
    end

    synergyEntries[#synergyEntries + 1] = {
        name = artifact.name,
        color = artifact.color,
        principle = "Targeted recipes",
        effect = "Collect or level this artifact while a listed color is active to discover that synergy.",
        recipes = recipes,
    }
end

local function initFonts()
    fontDisplay = fontDisplay or Theme.font("display", 72)
    fontTitle = fontTitle or Theme.font("uiSemiBold", 24)
    fontUI = fontUI or Theme.font("ui", 17)
    fontMono = fontMono or Theme.font("mono", 13)
end

local function activeEntries()
    local key = tabs[selectedTab].key
    if key == "colors" then
        return colorEntries
    elseif key == "synergies" then
        return synergyEntries
    end
    return artifactEntries
end

local function drawWrapped(text, x, y, w, lineH, color, font)
    love.graphics.setFont(font or fontUI)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or alpha)

    local line = ""
    local usedY = y
    for word in tostring(text or ""):gmatch("%S+") do
        local candidate = line == "" and word or (line .. " " .. word)
        if love.graphics.getFont():getWidth(candidate) > w and line ~= "" then
            love.graphics.print(line, x, usedY)
            usedY = usedY + lineH
            line = word
        else
            line = candidate
        end
    end
    if line ~= "" then
        love.graphics.print(line, x, usedY)
        usedY = usedY + lineH
    end
    return usedY
end

local function drawSynergyRecipe(recipe, x, y, w, h)
    local c = recipe.color
    h = h or 82

    love.graphics.setColor(0, 0, 0, alpha * 0.34)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(c[1], c[2], c[3], alpha * 0.12)
    love.graphics.rectangle("fill", x + 1, y + 1, w - 2, h - 2)
    love.graphics.setColor(c[1], c[2], c[3], alpha * 0.58)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setColor(c[1], c[2], c[3], alpha * 0.72)
    love.graphics.rectangle("fill", x, y, 4, h)

    love.graphics.setFont(fontMono)
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    love.graphics.print(recipe.colorName, x + 14, y + 12)

    love.graphics.setFont(fontUI)
    Theme.setColor("fg1", alpha)
    love.graphics.print(recipe.name, x + 14, y + 32)

    drawWrapped(
        recipe.description or "",
        x + 14,
        y + 56,
        w - 28,
        18,
        {Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], alpha * 0.84},
        fontMono
    )
end

function AtlasState:enter()
    initFonts()
    alpha = 0
    selectedTab = 1
    selectedEntry = 1
    entryRects = {}
    tabRects = {}
    backRect = nil
    backHovered = false
    navRects = {}
    bgShader = bgShader or ShellStyle.loadShader("AtlasState")
end

function AtlasState:update(dt)
    alpha = math.min(1, alpha + dt / 0.25)
    ShellStyle.updateMusic(dt)
end

function AtlasState:draw()
    local sw, sh = Config.screen.width, Config.screen.height
    local entries = activeEntries()
    local entry = entries[selectedEntry] or entries[1]

    ShellStyle.drawBackground(alpha, bgShader)

    local margin = sh * 0.1
    ShellStyle.drawRgbTitle("ATLAS", margin, margin, fontDisplay, alpha)

    love.graphics.setFont(fontUI)
    Theme.setColor("fg3", alpha)
    love.graphics.print("Colors, optics, artifacts, and additive light rules", margin, margin + 88)

    -- Nav rail: tab buttons + BACK (same column calculation as OptionsState)
    local railButtons = {}
    for i, tab in ipairs(tabs) do
        railButtons[#railButtons + 1] = {label = tab.label, action = "tab", tabIndex = i}
    end
    railButtons[#railButtons + 1] = {label = "BACK", action = "back"}

    local bracketHeight = 44
    local gap = 16
    local menuBottomLimit = sh - margin
    local totalRailH = #railButtons * bracketHeight + (#railButtons - 1) * gap
    local railY = menuBottomLimit - totalRailH

    local barWidth = 56
    local barGap = 4
    local startX = 2
    local barStep = barWidth + barGap
    local menuTitleWidth = ShellStyle.measureSpacedText("CHROMATIC", fontDisplay, 10)
    local logoCenterX = margin + menuTitleWidth / 2
    local centerCol = math.floor((logoCenterX - startX) / barStep) + 1
    local colStart = centerCol - 2
    if colStart < 1 then colStart = 1 end
    if colStart + 4 > 32 then colStart = 28 end

    local railX = startX + (colStart - 1) * barStep
    local railW = 5 * barWidth + 4 * barGap

    navRects = ShellStyle.layoutVerticalRail(railButtons, railX, railY, {buttonW = railW, buttonH = bracketHeight, gap = gap})
    tabRects = {}
    for i = 1, #tabs do tabRects[i] = navRects[i] end
    backRect = navRects[#railButtons]
    ShellStyle.drawVerticalRail(railButtons, navRects, backHovered and #railButtons or selectedTab, alpha, fontUI)

    -- Right panel (same placement formula as OptionsState)
    local panelX = railX + railW + 120
    local panelY = 320
    local panelW = sw - panelX - margin
    local panelH = sh - panelY - margin

    ShellStyle.drawPanel(panelX, panelY, panelW, panelH, alpha, Theme.color.accent)

    -- Panel header
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(0.85, 0.85, 0.9, alpha)
    love.graphics.print(tabs[selectedTab].label .. " REFERENCE", panelX + 40, panelY + 40)

    local ac = Theme.color.accent
    love.graphics.setColor(ac[1], ac[2], ac[3], alpha * 0.15)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 40, panelY + 90, panelX + panelW - 40, panelY + 90)

    -- Two-column interior: entry list (left) | detail (right)
    local contentY = panelY + 110
    local listPaneW = 260
    local listX = panelX + 20
    local detailX = listX + listPaneW + 32
    local detailW = panelX + panelW - detailX - 40

    -- Vertical separator
    local sepX = listX + listPaneW + 16
    love.graphics.setColor(ac[1], ac[2], ac[3], alpha * 0.12)
    love.graphics.setLineWidth(1)
    love.graphics.line(sepX, panelY + 100, sepX, panelY + panelH - 20)

    -- Entry list rows
    local rowH = 52
    local listGap = 8
    entryRects = {}
    for i, item in ipairs(entries) do
        local y = contentY + (i - 1) * (rowH + listGap)
        local selected = i == selectedEntry
        local c = item.color
        entryRects[i] = {x = listX, y = y, w = listPaneW, h = rowH}

        love.graphics.setColor(0, 0, 0, alpha * 0.42)
        love.graphics.rectangle("fill", listX, y, listPaneW, rowH)
        love.graphics.setColor(c[1], c[2], c[3], selected and alpha * 0.28 or alpha * 0.1)
        love.graphics.rectangle("fill", listX + 1, y + 1, listPaneW - 2, rowH - 2)
        love.graphics.setColor(c[1], c[2], c[3], selected and alpha or alpha * 0.42)
        love.graphics.setLineWidth(selected and 2 or 1)
        love.graphics.rectangle("line", listX, y, listPaneW, rowH)

        love.graphics.setFont(fontTitle)
        love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], alpha)
        love.graphics.print(item.name, listX + 18, y + 14)
    end

    -- Detail section (right column)
    love.graphics.setFont(fontDisplay)
    love.graphics.setColor(entry.color[1], entry.color[2], entry.color[3], alpha)
    love.graphics.print(entry.name, detailX, contentY)

    love.graphics.setFont(fontTitle)
    Theme.setColor("fg1", alpha)
    love.graphics.print(entry.principle, detailX, contentY + 94)

    local y = contentY + 150
    if tabs[selectedTab].key == "synergies" then
        love.graphics.setFont(fontMono)
        Theme.setColor("fg3", alpha)
        love.graphics.print("COLOR RECIPES", detailX, y)
        y = y + 30

        local recipes = entry.recipes or {}
        local recipeGap = 12
        local columns = detailW >= 500 and 2 or 1
        local recipeW = math.floor((detailW - recipeGap * (columns - 1)) / columns)
        local recipeH = columns == 2 and 100 or 80

        for i, recipe in ipairs(recipes) do
            local col = (i - 1) % columns
            local row = math.floor((i - 1) / columns)
            local recipeX = detailX + col * (recipeW + recipeGap)
            local recipeY = y + row * (recipeH + recipeGap)
            drawSynergyRecipe(recipe, recipeX, recipeY, recipeW, recipeH)
        end
    else
        love.graphics.setFont(fontMono)
        Theme.setColor("fg3", alpha)
        love.graphics.print("COMBAT FUNCTION", detailX, y)
        y = drawWrapped(entry.effect, detailX, y + 30, detailW, 26, {Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], alpha}, fontUI) + 22

        if entry.tell then
            love.graphics.setFont(fontMono)
            Theme.setColor("fg3", alpha)
            love.graphics.print("VISIBLE SIGNAL", detailX, y)
            y = drawWrapped(entry.tell, detailX, y + 30, detailW, 26, {Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], alpha}, fontUI) + 22
        end

        love.graphics.setFont(fontMono)
        Theme.setColor("fg3", alpha)
        love.graphics.print("LIGHT INTERACTION", detailX, y)
        y = drawWrapped(entry.light, detailX, y + 30, detailW, 26, {Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], alpha}, fontUI) + 22

        if entry.mixes then
            love.graphics.setFont(fontMono)
            Theme.setColor("fg3", alpha)
            love.graphics.print("ADDITIVE MIXING", detailX, y)
            drawWrapped(entry.mixes, detailX, y + 30, detailW, 26, {Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], alpha}, fontUI)
        end
    end

    ShellStyle.drawFooter("LEFT / RIGHT tabs   UP / DOWN entries   ESC / BACK return", sh - 82, alpha)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function AtlasState:keypressed(key)
    local StateManager = require("src.core.StateManager")
    local entries = activeEntries()

    if key == "escape" then
        StateManager.switch("Menu")
    elseif key == "left" or key == "right" then
        local delta = key == "right" and 1 or -1
        selectedTab = ((selectedTab - 1 + delta) % #tabs) + 1
        selectedEntry = 1
    elseif key == "up" then
        selectedEntry = selectedEntry - 1
        if selectedEntry < 1 then selectedEntry = #entries end
    elseif key == "down" then
        selectedEntry = selectedEntry + 1
        if selectedEntry > #entries then selectedEntry = 1 end
    end
end

function AtlasState:mousemoved(x, y)
    backHovered = backRect and x >= backRect.x and x <= backRect.x + backRect.w and y >= backRect.y and y <= backRect.y + backRect.h
    if backHovered then
        return
    end

    for i, rect in ipairs(tabRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            selectedTab = i
            selectedEntry = 1
            return
        end
    end

    for i, rect in ipairs(entryRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            selectedEntry = i
            return
        end
    end
end

function AtlasState:mousepressed(x, y, button)
    if button ~= 1 then return end

    if backRect and x >= backRect.x and x <= backRect.x + backRect.w and y >= backRect.y and y <= backRect.y + backRect.h then
        require("src.core.StateManager").switch("Menu")
        return
    end

    for i, rect in ipairs(tabRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            selectedTab = i
            selectedEntry = 1
            return
        end
    end

    for i, rect in ipairs(entryRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            selectedEntry = i
            return
        end
    end
end

return AtlasState
