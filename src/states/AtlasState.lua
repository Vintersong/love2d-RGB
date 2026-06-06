-- AtlasState.lua
-- In-game reference for CHROMATIC colors, artifacts, and light interactions.

local AtlasState = {}

local Config = require("src.Config")
local GameConfig = require("src.core.GameConfig")
local Theme = require("src.render.Theme")
local SynergySystem = require("src.gameplay.SynergySystem")
local ShellStyle = require("src.ui.ShellStyle")

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

local colorEntries = {
    {
        name = "RED",
        color = Theme.color.red,
        principle = "Emission / pressure",
        effect = "Adds spread and extra projectiles. Red turns one beam into a field of threat.",
        tell = "Look for wider firing cones, extra red-shot lanes, and denser impact bursts.",
        light = "Red is the longest primary wavelength here: broad, forceful, and space-filling.",
        mixes = "RED + GREEN -> YELLOW. RED + BLUE -> MAGENTA.",
    },
    {
        name = "GREEN",
        color = Theme.color.green,
        principle = "Reflection / adaptation",
        effect = "Adds bounce and seeking behavior. Green redirects energy instead of wasting it.",
        tell = "Look for projectiles changing direction after hits or edges instead of simply vanishing.",
        light = "Green represents adaptive routing: light finding another surface, then another target.",
        mixes = "GREEN + RED -> YELLOW. GREEN + BLUE -> CYAN.",
    },
    {
        name = "BLUE",
        color = Theme.color.blue,
        principle = "Focus / control",
        effect = "Adds pierce and precision. Blue keeps a beam coherent through multiple targets.",
        tell = "Look for shots passing through enemies and continuing along the same clean path.",
        light = "Blue is short-wavelength control: narrow, clean, and hard to stop.",
        mixes = "BLUE + RED -> MAGENTA. BLUE + GREEN -> CYAN.",
    },
    {
        name = "YELLOW",
        color = Theme.color.yellow,
        principle = "Constructive mixing",
        effect = "RED + GREEN. Keeps spread and bounce while accelerating the weapon rhythm.",
        tell = "Look for faster firing rhythm with both spread pressure and redirected shots.",
        light = "Yellow is additive light overlap: pressure plus routing becomes velocity.",
        mixes = "Secondary commitment from RED and GREEN.",
    },
    {
        name = "MAGENTA",
        color = Theme.color.magenta,
        principle = "Unstable interference",
        effect = "RED + BLUE. Keeps spread and pierce while adding detonation/time pressure.",
        tell = "Look for magenta explosions, burst damage, and projectile paths that still pierce.",
        light = "Magenta is non-spectral synthesis: a constructed color, volatile and artificial.",
        mixes = "Secondary commitment from RED and BLUE.",
    },
    {
        name = "CYAN",
        color = Theme.color.cyan,
        principle = "Cooling diffraction",
        effect = "GREEN + BLUE. Keeps bounce and pierce while adding frost, slow, and damage over time.",
        tell = "Look for cyan trails, slowed enemies, and damage continuing after the first hit.",
        light = "Cyan bends adaptive energy into control: reflected light becomes a slowing field.",
        mixes = "Secondary commitment from GREEN and BLUE.",
    },
}

local artifactEntries = {
    {
        name = "PRISM",
        color = Theme.color.magenta,
        principle = "Refraction split",
        effect = "Splits, walls, orbiting beams, and prismatic projectile mutations.",
        tell = "Look for prismatic rings and triangular shards near the player; shots split or fan into readable ray patterns.",
        light = "A prism separates white intent into component paths. It makes one shot become many readable rays.",
    },
    {
        name = "LENS",
        color = Theme.color.blue,
        principle = "Focal convergence",
        effect = "Merges, enlarges, pulls, and concentrates projectile power.",
        tell = "Look for narrow blue beam shards near the player; shots become larger, heavier, or pulled into focus.",
        light = "A lens bends paths toward focus. In combat, it turns loose color into a sharper beam.",
    },
    {
        name = "MIRROR",
        color = Theme.color.cyan,
        principle = "Reflection echo",
        effect = "Adds reflected shots, echo bounces, dual walls, and temporal copies.",
        tell = "Look for pale reflective panels near the player; duplicate and echo shots trace mirrored routes.",
        light = "A mirror preserves angle and intent. It doubles a pattern without changing its source color.",
    },
    {
        name = "HALO",
        color = Theme.color.yellow,
        principle = "Atmospheric ring",
        effect = "Creates color-dependent aura fields: fire, drain, slow, electric pulse, time bubble, frost.",
        tell = "Look around the player, not the projectile: HALO draws a persistent dominant-color aura field.",
        light = "A halo is light scattered through atmosphere. It turns your dominant color into local weather.",
    },
    {
        name = "AURORA",
        color = Theme.color.green,
        principle = "Ionized glow",
        effect = "Regeneration and dominant-color aura interactions.",
        tell = "Look for survival pulses and aurora arcs around the player when healing or aura effects update.",
        light = "Aurora is charged light in motion. It makes survival effects pulse outward through color.",
    },
    {
        name = "DIFFRACTION",
        color = Theme.color.red,
        principle = "Wave interference",
        effect = "Creates burst patterns, magnetized pickups, and color-wave interference effects.",
        tell = "Look for orange spoke rings and square sparks near the player; shots form cones, bursts, or wave-like sources.",
        light = "Diffraction bends around edges. It rewards crowded spaces and overlapping wavefronts.",
    },
    {
        name = "REFRACTION",
        color = Theme.color.accent,
        principle = "Path bending",
        effect = "Creates spirals, satellites, synchronized hits, and bending projectile paths.",
        tell = "Look for violet rotating rings near the player; shots curve, spiral, or orbit instead of flying straight.",
        light = "Refraction changes direction when light crosses media. It makes shots curve through combat.",
    },
    {
        name = "SUPERNOVA",
        color = Theme.color.warn,
        principle = "Stellar release",
        effect = "Turns stored pressure into screen-scale color events and ultimate pulses.",
        tell = "Look for a SUPERNOVA burst callout and a large radial blast centered on the player.",
        light = "A supernova is emission without restraint: color collapse becoming a battlefield event.",
    },
}

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

    local margin = 120
    ShellStyle.drawRgbTitle("ATLAS", margin, 86, fontDisplay, alpha)

    love.graphics.setFont(fontUI)
    Theme.setColor("fg3", alpha)
    love.graphics.print("Colors, optics, artifacts, and additive light rules", margin, 170)

    local railButtons = {}
    for i, tab in ipairs(tabs) do
        railButtons[#railButtons + 1] = {label = tab.label, action = "tab", tabIndex = i}
    end
    railButtons[#railButtons + 1] = {label = "BACK", action = "back"}

    local railW = 296
    local menuBottomLimit = sh - (sh * 0.1)
    local bracketHeight = 44
    local gap = 16
    local menuCount = GameConfig.hasActiveRun() and 7 or 6
    local menuStackHeight = menuCount * bracketHeight + (menuCount - 1) * gap
    local menuStackStartY = menuBottomLimit - menuStackHeight
    local quitY = menuStackStartY + (menuCount - 1) * (bracketHeight + gap)
    local railY = quitY - (#railButtons - 1) * (bracketHeight + gap)

    local titleText = "ATLAS"
    local menuTitleText = "CHROMATIC"
    local titleWidth = 0
    local charGap = 10
    for i = 1, #titleText do
        local char = titleText:sub(i, i)
        titleWidth = titleWidth + fontDisplay:getWidth(char)
    end
    titleWidth = titleWidth + (#titleText - 1) * charGap

    local menuTitleWidth = 0
    for i = 1, #menuTitleText do
        local char = menuTitleText:sub(i, i)
        menuTitleWidth = menuTitleWidth + fontDisplay:getWidth(char)
    end
    menuTitleWidth = menuTitleWidth + (#menuTitleText - 1) * charGap

    local logoCenterX = margin + menuTitleWidth / 2
    local menuCenter = logoCenterX
    local barWidth = 56
    local barGap = 4
    local startX = 2
    local barStep = barWidth + barGap
    local centerCol = math.floor((menuCenter - startX) / barStep) + 1
    local colStart = centerCol - 2
    if colStart < 1 then colStart = 1 end
    local colEnd = colStart + 4
    if colEnd > 32 then
        colEnd = 32
        colStart = 32 - 4
    end

    local railX = startX + (colStart - 1) * barStep
    navRects = ShellStyle.layoutVerticalRail(railButtons, railX, railY, {buttonW = railW, buttonH = 44, gap = 16})
    tabRects = {}
    for i = 1, #tabs do
        tabRects[i] = navRects[i]
    end
    backRect = navRects[#railButtons]
    ShellStyle.drawVerticalRail(railButtons, navRects, backHovered and #railButtons or selectedTab, alpha, fontUI)

    local listX = margin
    local listW = 360
    local rowH = 52
    local listGap = 10
    local listHeight = #entries * rowH + math.max(0, #entries - 1) * listGap
    local listY = railY - listHeight - 8
    entryRects = {}

    for i, item in ipairs(entries) do
        local y = listY + (i - 1) * (rowH + listGap)
        local selected = i == selectedEntry
        entryRects[i] = {x = listX, y = y, w = listW, h = rowH}

        love.graphics.setColor(0, 0, 0, alpha * 0.42)
        love.graphics.rectangle("fill", listX, y, listW, rowH)
        local c = item.color
        love.graphics.setColor(c[1], c[2], c[3], selected and alpha * 0.28 or alpha * 0.1)
        love.graphics.rectangle("fill", listX + 1, y + 1, listW - 2, rowH - 2)
        love.graphics.setColor(c[1], c[2], c[3], selected and alpha or alpha * 0.42)
        love.graphics.setLineWidth(selected and 2 or 1)
        love.graphics.rectangle("line", listX, y, listW, rowH)

        love.graphics.setFont(fontTitle)
        love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], alpha)
        love.graphics.print(item.name, listX + 18, y + 12)
    end

    local panelX = listX + listW + 56
    local panelY = 305
    local panelW = sw - panelX - margin
    local panelH = 570

    ShellStyle.drawPanel(panelX, panelY, panelW, panelH, alpha, entry.color)
    love.graphics.setColor(entry.color[1], entry.color[2], entry.color[3], alpha * 0.18)
    love.graphics.rectangle("fill", panelX + 1, panelY + 1, panelW - 2, panelH - 2)

    love.graphics.setFont(fontDisplay)
    love.graphics.setColor(entry.color[1], entry.color[2], entry.color[3], alpha)
    love.graphics.print(entry.name, panelX + 34, panelY + 34)

    love.graphics.setFont(fontTitle)
    Theme.setColor("fg1", alpha)
    love.graphics.print(entry.principle, panelX + 36, panelY + 128)

    local y = panelY + 184
    if tabs[selectedTab].key == "synergies" then
        love.graphics.setFont(fontMono)
        Theme.setColor("fg3", alpha)
        love.graphics.print("HOW TO TARGET", panelX + 36, y)
        y = drawWrapped(entry.effect, panelX + 36, y + 30, panelW - 72, 26, {Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], alpha}, fontUI) + 18

        love.graphics.setFont(fontMono)
        Theme.setColor("fg3", alpha)
        love.graphics.print("COLOR RECIPES", panelX + 36, y)
        y = y + 30

        local recipes = entry.recipes or {}
        local gap = 12
        local columns = panelW >= 760 and 2 or 1
        local recipeW = math.floor((panelW - 72 - gap * (columns - 1)) / columns)
        local recipeH = columns == 2 and 82 or 68

        for i, recipe in ipairs(recipes) do
            local col = (i - 1) % columns
            local row = math.floor((i - 1) / columns)
            local recipeX = panelX + 36 + col * (recipeW + gap)
            local recipeY = y + row * (recipeH + gap)
            drawSynergyRecipe(recipe, recipeX, recipeY, recipeW, recipeH)
        end
    else
        love.graphics.setFont(fontMono)
        Theme.setColor("fg3", alpha)
        love.graphics.print("COMBAT FUNCTION", panelX + 36, y)
        y = drawWrapped(entry.effect, panelX + 36, y + 30, panelW - 72, 26, {Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], alpha}, fontUI) + 22

        if entry.tell then
            love.graphics.setFont(fontMono)
            Theme.setColor("fg3", alpha)
            love.graphics.print("VISIBLE SIGNAL", panelX + 36, y)
            y = drawWrapped(entry.tell, panelX + 36, y + 30, panelW - 72, 26, {Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], alpha}, fontUI) + 22
        end

        love.graphics.setFont(fontMono)
        Theme.setColor("fg3", alpha)
        love.graphics.print("LIGHT INTERACTION", panelX + 36, y)
        y = drawWrapped(entry.light, panelX + 36, y + 30, panelW - 72, 26, {Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], alpha}, fontUI) + 22

        if entry.mixes then
            love.graphics.setFont(fontMono)
            Theme.setColor("fg3", alpha)
            love.graphics.print("ADDITIVE MIXING", panelX + 36, y)
            drawWrapped(entry.mixes, panelX + 36, y + 30, panelW - 72, 26, {Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], alpha}, fontUI)
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
