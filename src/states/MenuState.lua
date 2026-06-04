-- MenuState.lua
-- Main Menu screen that displays game title with RGB animation and centered interactive Segmented Bracket buttons

local MenuState = {}
local Config = require("src.Config")
local Runtime = require("src.core.Runtime")
local GameConfig = require("src.core.GameConfig")
local MetaProgression = require("src.core.MetaProgression")
local SFXLibrary = require("src.audio.SFXLibrary")
local ShipRenderer = require("src.render.ShipRenderer")
local Theme = require("src.render.Theme")

-- State variables
local alpha = 0
local fadeInDuration = 0.3
local timer = 0
local phase = "fadeIn" -- fadeIn -> active

local menuOptions = {}
local selectedMenuOption = 1

-- Clickable bounds for each menu option, refreshed every draw {x, y, w, h}.
local optionRects = {}

-- Animation transition trackers for each menu option
local animProgress = {}

-- Text settings
local titleText = "CHROMATIC"
local titleSize = 75
local subtitleSize = 24

-- Fonts
local titleFont = nil
local subtitleFont = nil
local smallFont = nil
local defaultFont = nil

-- Background Shader
local bgShader = nil

-- Ship display
local shipRenderer = nil

-- Glowing visualizer Y-tracker for selection highlighting
local glowY = nil

-- Equalizer highlight tuning for selected menu rows
local MENU_GRID_IDLE_ALPHA = 0.04
local MENU_GRID_ACTIVE_BASE_ALPHA = 0.14
local MENU_GRID_ACTIVE_AUDIO_ALPHA = 0.18
local MENU_GRID_ACTIVE_MAX_ALPHA = 1.0
local MENU_GRID_CELL_HEIGHT = 12

local function buildMenuOptions()
    menuOptions = {}
    if GameConfig.hasActiveRun() then
        table.insert(menuOptions, {label = "CONTINUE", action = "continue", style = "bracket"})
    end
    table.insert(menuOptions, {label = "START GAME", action = "startGame", style = "bracket"})
    table.insert(menuOptions, {label = "TUTORIAL", action = "tutorial", style = "bracket"})
    table.insert(menuOptions, {label = "PROGRESSION", action = "progression", style = "bracket"})
    table.insert(menuOptions, {label = "SETTINGS", action = "settings", style = "bracket"})
    table.insert(menuOptions, {label = "QUIT", action = "quit", style = "bracket"})
end

local function buildLoadingData()
    local PlayingState = require("src.states.PlayingState")
    return {
        message = "Preparing run...",
        nextState = "Playing",
        nextData = nil,
        onLoad = function()
            PlayingState.startNewRun()
        end,
    }
end

local function openConfirm(title, message, onConfirm, yesLabel, noLabel)
    local StateManager = require("src.core.StateManager")
    StateManager.push("Confirm", {
        title = title,
        message = message,
        yesLabel = yesLabel or "YES",
        noLabel = noLabel or "NO",
        onConfirm = onConfirm,
    })
end

function MenuState:enter(previous, data)
    alpha = 0
    timer = 0
    phase = "fadeIn"
    selectedMenuOption = 1
    glowY = nil

    buildMenuOptions()

    -- Branded type system (CHROMATIC design tokens): Michroma wordmark,
    -- Chakra Petch UI, Share Tech Mono numerics.
    titleFont = titleFont or Theme.font("display", titleSize)
    subtitleFont = subtitleFont or Theme.font("uiMedium", subtitleSize)
    smallFont = smallFont or Theme.font("ui", Theme.scale.ui)
    defaultFont = defaultFont or Theme.font("mono", Theme.scale.micro)

    -- Reset animation track table
    for i = 1, #menuOptions do
        animProgress[i] = 0
    end

    if not shipRenderer then
        shipRenderer = ShipRenderer:new({color = {1.0, 0.35, 0.75, 1.0}})
    end

    -- Load shader safely
    if not bgShader then
        local success, result = pcall(love.graphics.newShader, "assets/shaders/splashscreen.glsl")
        if success then
            bgShader = result
            print("[MenuState] Background shader loaded successfully")
        else
            print("[MenuState] Failed to load background shader: " .. tostring(result))
        end
    end

    print("[MenuState] Entered Main Menu screen")
end

function MenuState:update(dt)
    timer = timer + dt
    
    -- Update music reactor if present so that background and audio keep playing/reacting
    local musicReactor = GameConfig.getMusicReactor()
    if musicReactor then
        musicReactor:update(dt)
    end

    -- Animate selection progress for each button
    for i = 1, #menuOptions do
        local target = (i == selectedMenuOption) and 1 or 0
        if animProgress[i] < target then
            animProgress[i] = math.min(target, animProgress[i] + dt / 0.15) -- 150ms slide
        elseif animProgress[i] > target then
            animProgress[i] = math.max(target, animProgress[i] - dt / 0.15)
        end
    end
    
    -- Smoothly interpolate glowing visualizer Y-position for active button
    local screenHeight = Config.screen.height
    local menuBottomLimit = screenHeight - (screenHeight * 0.1)
    local bracketHeight = 44
    local gap = 16
    local numItems = #menuOptions
    local totalMenuHeight = numItems * bracketHeight + (numItems - 1) * gap
    local stackStartY = menuBottomLimit - totalMenuHeight
    local selectedY = stackStartY + (selectedMenuOption - 1) * (bracketHeight + gap)
    
    if not glowY then
        glowY = selectedY
    else
        glowY = glowY + (selectedY - glowY) * dt * 16 -- fast, highly responsive slide
    end

    if phase == "fadeIn" then
        alpha = math.min(1, timer / fadeInDuration)
        if timer >= fadeInDuration then
            phase = "active"
            timer = 0
        end
    elseif phase == "active" then
        alpha = 1
    end
end

function MenuState:draw()
    local screenWidth = Config.screen.width
    local screenHeight = Config.screen.height
    
    -- 1. Calculate menu layout metrics early
    local menuBottomLimit = screenHeight - (screenHeight * 0.1)
    local bracketHeight = 44
    local gap = 16
    local numItems = #menuOptions
    local totalMenuHeight = numItems * bracketHeight + (numItems - 1) * gap
    local stackStartY = menuBottomLimit - totalMenuHeight
    
    local margin = screenHeight * 0.1
    local titleX = margin
    local titleY = margin
    
    -- Calculate individual character widths and total width with a symmetrical gap
    local widths = {}
    local totalWidth = 0
    local charGap = 10
    
    for i = 1, #titleText do
        local char = titleText:sub(i, i)
        widths[i] = titleFont:getWidth(char)
        totalWidth = totalWidth + widths[i]
    end
    totalWidth = totalWidth + (#titleText - 1) * charGap
    
    local logoCenterX = titleX + totalWidth / 2
    local menuCenter = logoCenterX
    
    -- Align button exactly to 5 visualizer cells/columns
    local barWidth = 56
    local barGap = 4
    local startX = 2
    local barStep = barWidth + barGap -- 60
    
    -- Find the column index closest to the logo center
    local centerCol = math.floor((menuCenter - startX) / barStep) + 1
    
    -- Center a 5-cell wide button (2 columns left, 2 columns right, 1 middle)
    local colStart = centerCol - 2
    if colStart < 1 then colStart = 1 end
    local colEnd = colStart + 4
    if colEnd > 32 then
        colEnd = 32
        colStart = 32 - 4
    end
    
    local btnX = startX + (colStart - 1) * barStep
    local btnW = 5 * barWidth + 4 * barGap -- exactly 5 cells wide (296 pixels)
    
    -- 2. Clear to deep space black (design token: bg-void)
    local void = Theme.color.bgVoid
    love.graphics.clear(void[1], void[2], void[3], 1)

    -- 3. Draw Background Shader if loaded (Full Screen)
    local musicReactor = GameConfig.getMusicReactor()
    local intensity = musicReactor and musicReactor:getOverallIntensity() or 0
    
    if bgShader then
        local previousShader = love.graphics.getShader()
        pcall(function()
            bgShader:send("resolution", {screenWidth, screenHeight})
            bgShader:send("time", love.timer.getTime())
            bgShader:send("intensity", intensity)
            bgShader:send("bloomEnabled", 0.0)
        end)
        
        love.graphics.setShader(bgShader)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
        love.graphics.setShader(previousShader)
    end

    -- 3.5 Draw Ship (centered on screen, facing up)
    if shipRenderer then
        shipRenderer:draw(screenWidth / 2, screenHeight / 2, 1.0, alpha, -math.pi / 2)
    end

    -- 4. Draw Equalizer Bars Grid (LED columns - static unlit matrix at 4% opacity - Full Screen Width)
    local numBars = 32
    local segmentHeight = MENU_GRID_CELL_HEIGHT
    local segmentGap = 3
    local numSegmentsTotal = 72
    local time = love.timer.getTime()
    
    for i = 1, numBars do
        local barX = startX + (i - 1) * (barWidth + barGap)
        local barOffset = (i - 1) * 0.12
        local r = 0.5 + 0.5 * math.sin(time * 2 + barOffset)
        local g = 0.5 + 0.5 * math.sin(time * 2 + 2.09 + barOffset)
        local b = 0.5 + 0.5 * math.sin(time * 2 + 4.18 + barOffset)
        
        -- Get real-time reactive audio intensity for this specific column
        local barIntensity = 0.1
        if musicReactor then
            barIntensity = musicReactor:getBandIntensity(i) or 0.1
        end
        
        -- Check if this specific column is horizontally behind the buttons (columns colStart to colEnd)
        local isBehindButtonColumn = (i >= colStart and i <= colEnd)
        
        for j = 1, numSegmentsTotal do
            local segmentY = screenHeight - (j * (segmentHeight + segmentGap))
            
            -- Check if this segment lies vertically inside the smoothly sliding selection range (glowY)
            local isSelectedRow = false
            if glowY then
                isSelectedRow = (segmentY >= glowY - 2) and (segmentY + segmentHeight <= glowY + bracketHeight + 2)
            end
            
            local finalAlpha = alpha * MENU_GRID_IDLE_ALPHA
            -- Highlight ONLY if it is vertically on the selected row AND horizontally behind the buttons!
            if isSelectedRow and isBehindButtonColumn then
                -- Brighter active glow that still preserves legibility and avoids clipping.
                local selectedAlpha = MENU_GRID_ACTIVE_BASE_ALPHA + MENU_GRID_ACTIVE_AUDIO_ALPHA * math.max(0, barIntensity)
                finalAlpha = alpha * math.min(MENU_GRID_ACTIVE_MAX_ALPHA, selectedAlpha)
            end
            
            love.graphics.setColor(r, g, b, finalAlpha)
            love.graphics.rectangle("fill", barX, segmentY, barWidth, segmentHeight, 2, 2)
        end
    end

    local bandHeight = (segmentHeight + segmentGap) * 2
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, screenWidth, bandHeight)
    love.graphics.rectangle("fill", 0, screenHeight - bandHeight, screenWidth, bandHeight)
    
    -- 4.6 Draw Title (on the left side, distanced equally from top and left)
    love.graphics.setFont(titleFont)
    local startXText = titleX
    local currentX = startXText
    
    for i = 1, #titleText do
        local char = titleText:sub(i, i)
        local charOffset = (i - 1) * 0.4
        
        local r = 0.5 + 0.5 * math.sin(time * 2 + charOffset)
        local g = 0.5 + 0.5 * math.sin(time * 2 + 2.09 + charOffset)
        local b = 0.5 + 0.5 * math.sin(time * 2 + 4.18 + charOffset)
        
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.print(char, currentX, titleY)
        currentX = currentX + widths[i] + charGap
    end

    -- 5. Draw Segmented Bracket Menu Options Stack
    -- Centered to the logo but 10% left, and 10% bottom margin starting with the last item at the bottom limit
    local currentY = stackStartY
    optionRects = {}

    for i, option in ipairs(menuOptions) do
        local progress = animProgress[i] or 0
        local ease = 1 - math.pow(2, -10 * progress)

        -- Record the full clickable bounds (brackets animate inward, hit area does not)
        optionRects[i] = {x = btnX, y = currentY, w = btnW, h = bracketHeight}

        -- Segmented Brackets Style (Minimalist Tech)
        local slideOffset = ease * 8
        local lx = btnX + slideOffset
        local rx = btnX + btnW - slideOffset
        
        -- 1. Draw a slight background behind the text: black 0.5 alpha
        love.graphics.setColor(0, 0, 0, alpha * 0.5)
        love.graphics.rectangle("fill", lx, currentY, rx - lx, bracketHeight)
        
        -- 2. Draw bracket outlines
        love.graphics.setLineWidth(1.5)
        if i == selectedMenuOption then
            local a = Theme.color.accent
            love.graphics.setColor(a[1], a[2], a[3], alpha)
        else
            love.graphics.setColor(1, 1, 1, alpha * 0.12)
        end
        
        -- Top-Left Corner
        love.graphics.line(lx + 12, currentY, lx, currentY, lx, currentY + 12)
        -- Bottom-Left Corner
        love.graphics.line(lx + 12, currentY + bracketHeight, lx, currentY + bracketHeight, lx, currentY + bracketHeight - 12)
        
        -- Top-Right Corner
        love.graphics.line(rx - 12, currentY, rx, currentY, rx, currentY + 12)
        -- Bottom-Right Corner
        love.graphics.line(rx - 12, currentY + bracketHeight, rx, currentY + bracketHeight, rx, currentY + bracketHeight - 12)
        
        -- Option Text
        love.graphics.setFont(smallFont)
        local btnCenterX = btnX + btnW / 2
        if i == selectedMenuOption then
            love.graphics.setColor(0, 0, 0, alpha * 0.5)
            love.graphics.print(option.label, btnCenterX - smallFont:getWidth(option.label)/2 + 1, currentY + bracketHeight/2 - 8 + 1)
            
            love.graphics.setColor(1, 1, 1, alpha)
        else
            love.graphics.setColor(0.55, 0.6, 0.7, alpha * 0.6)
        end
        love.graphics.print(option.label, btnCenterX - smallFont:getWidth(option.label)/2, currentY + bracketHeight/2 - 8)
        
        currentY = currentY + bracketHeight + gap
    end

    -- 5.5 Draw controls map panel on main menu
    local mapW = 520
    local mapH = 250
    local mapX = screenWidth - mapW - margin
    local mapY = screenHeight - mapH - margin

    love.graphics.setColor(0.01, 0.01, 0.015, alpha * 0.85)
    love.graphics.rectangle("fill", mapX, mapY, mapW, mapH, 10, 10)

    love.graphics.setLineWidth(2)
    local mapEdge = Theme.color.accent
    love.graphics.setColor(mapEdge[1], mapEdge[2], mapEdge[3], alpha * 0.28)
    love.graphics.rectangle("line", mapX, mapY, mapW, mapH, 10, 10)

    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(0.85, 0.9, 0.95, alpha)
    love.graphics.print("CONTROL MAP", mapX + 24, mapY + 18)

    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.6, 0.8, 1, alpha * 0.85)
    love.graphics.print("Gameplay", mapX + 24, mapY + 56)
    love.graphics.setColor(0.75, 0.8, 0.9, alpha * 0.85)
    love.graphics.print("MOVE  W A S D", mapX + 24, mapY + 80)
    love.graphics.print("DASH  SPACE   |  BLINK  E   |  SHIELD  Q", mapX + 24, mapY + 102)
    love.graphics.print("PAUSE  P / ESC   |   SUPERNOVA  reactive artifact", mapX + 24, mapY + 124)
    love.graphics.print("AIM  MOUSE CURSOR   (AUTO-FIRE)", mapX + 24, mapY + 146)

    love.graphics.setColor(0.6, 0.8, 1, alpha * 0.85)
    love.graphics.print("Menu", mapX + 24, mapY + 176)
    love.graphics.setColor(0.75, 0.8, 0.9, alpha * 0.85)
    love.graphics.print("NAVIGATE  UP / DOWN   |   SELECT  ENTER / SPACE", mapX + 24, mapY + 200)

    -- Reset default color
    love.graphics.setColor(1, 1, 1, 1)
end

function MenuState:keypressed(key)
    if Runtime.isWeb() then
        Runtime.startMusicAfterGesture()
    end

    if phase ~= "active" then return end

    if key == "up" then
        selectedMenuOption = selectedMenuOption - 1
        if selectedMenuOption < 1 then selectedMenuOption = #menuOptions end
        SFXLibrary.play("menuMove")
    elseif key == "down" then
        selectedMenuOption = selectedMenuOption + 1
        if selectedMenuOption > #menuOptions then selectedMenuOption = 1 end
        SFXLibrary.play("menuMove")
    elseif key == "return" or key == "space" then
        self:activateOption(menuOptions[selectedMenuOption].action)
        return
    elseif key == "escape" then
        self:activateOption("quit")
        return
    end
end

function MenuState:activateOption(action)
    if action == "continue" then
        self:continueGame()
    elseif action == "startGame" then
        self:startGame()
    elseif action == "tutorial" then
        local StateManager = require("src.core.StateManager")
        StateManager.switch("Tutorial", {
            mode = "review",
            nextState = "Menu",
        })
    elseif action == "progression" then
        local StateManager = require("src.core.StateManager")
        StateManager.switch("Progression")
    elseif action == "settings" then
        local StateManager = require("src.core.StateManager")
        love.graphics.setFont(defaultFont)
        StateManager.switch("Options")
    elseif action == "quit" then
        openConfirm(
            "QUIT GAME",
            "Leave the game now?",
            function()
                Runtime.quitOrReturnToTitle()
            end,
            "QUIT",
            "CANCEL"
        )
    end
end

-- Index of the menu option under a point, or nil.
local function optionAt(x, y)
    for i, rect in ipairs(optionRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            return i
        end
    end
    return nil
end

function MenuState:mousepressed(x, y, button)
    if Runtime.isWeb() then
        Runtime.startMusicAfterGesture()
    end
    if phase ~= "active" or button ~= 1 then return end

    local i = optionAt(x, y)
    if i then
        selectedMenuOption = i
        SFXLibrary.play("menuMove")
        self:activateOption(menuOptions[i].action)
    end
end

function MenuState:mousemoved(x, y)
    if phase ~= "active" then return end
    local i = optionAt(x, y)
    if i and i ~= selectedMenuOption then
        selectedMenuOption = i
        SFXLibrary.play("menuMove")
    end
end

function MenuState:touchpressed(id, x, y, dx, dy, pressure)
    if Runtime.isWeb() then
        Runtime.startMusicAfterGesture()
    end
end

function MenuState:startGame()
    if Runtime.isWeb() then
        Runtime.startMusicAfterGesture()
    end

    local StateManager = require("src.core.StateManager")
    if MetaProgression.hasSeenTutorial() then
        StateManager.switch("Loading", buildLoadingData())
    else
        StateManager.switch("Tutorial", {
            mode = "onboarding",
            nextState = "Loading",
            nextData = buildLoadingData(),
        })
    end
end

function MenuState:continueGame()
    if Runtime.isWeb() then
        Runtime.startMusicAfterGesture()
    end
    local StateManager = require("src.core.StateManager")
    StateManager.switch("Loading", buildLoadingData())
end

return MenuState
