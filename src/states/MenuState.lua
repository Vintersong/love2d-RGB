-- MenuState.lua
-- Main Menu screen that displays game title with RGB animation and centered interactive Segmented Bracket buttons

local MenuState = {}
local Config = require("src.Config")
local Runtime = require("src.systems.Runtime")
local GameConfig = require("src.systems.GameConfig")

-- State variables
local alpha = 0
local fadeInDuration = 0.3
local fadeOutDuration = 0.8
local timer = 0
local phase = "fadeIn" -- fadeIn -> active -> fadeOut

local menuOptions = {
    {label = "START GAME", action = "startGame", style = "bracket"},
    {label = "UI SANDBOX", action = "uiSandbox", style = "bracket"},
    {label = "SETTINGS", action = "settings", style = "bracket"},
    {label = "CREDITS", action = "credits", style = "bracket"},
    {label = "QUIT", action = "quit", style = "bracket"}
}
local selectedMenuOption = 1

-- Animation transition trackers for each menu option
local animProgress = {}

-- Interactive Overlay states
local showSettings = false
local showCredits = false

-- Text settings
local titleText = "CHROMATIC"
local titleSize = 75
local subtitleSize = 24

-- Fonts
local titleFont = nil
local subtitleFont = nil
local smallFont = nil

-- Background Shader
local bgShader = nil

-- Glowing visualizer Y-tracker for selection highlighting
local glowY = nil

function MenuState:enter(previous, data)
    alpha = 0
    timer = 0
    phase = "fadeIn"
    selectedMenuOption = 1
    showSettings = false
    showCredits = false
    glowY = nil

    if not titleFont then
        titleFont = love.graphics.newFont(titleSize)
    end
    if not subtitleFont then
        subtitleFont = love.graphics.newFont(subtitleSize)
    end
    if not smallFont then
        smallFont = love.graphics.newFont(16)
    end

    -- Reset animation track table
    for i = 1, #menuOptions do
        animProgress[i] = 0
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
    elseif phase == "fadeOut" then
        alpha = math.max(0, 1 - (timer / fadeOutDuration))
        if timer >= fadeOutDuration then
            -- Reset font to default before switching
            love.graphics.setFont(love.graphics.newFont(12))
            timer = 0
            
            -- Initialize PlayingState before switching
            local PlayingState = require("src.states.PlayingState")
            PlayingState.startNewRun()

            -- Switch to PlayingState
            local StateManager = require("src.systems.StateManager")
            StateManager.switch("Playing")
        end
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
    
    -- 2. Clear to deep space black
    love.graphics.clear(0.015, 0.012, 0.02, 1)

    -- 3. Draw Background Shader if loaded (Full Screen)
    local musicReactor = GameConfig.getMusicReactor()
    local intensity = musicReactor and musicReactor:getOverallIntensity() or 0
    
    if bgShader then
        local previousShader = love.graphics.getShader()
        pcall(function()
            bgShader:send("resolution", {screenWidth, screenHeight})
            bgShader:send("time", love.timer.getTime())
            bgShader:send("intensity", intensity)
        end)
        
        love.graphics.setShader(bgShader)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
        love.graphics.setShader(previousShader)
    end

    -- 4. Draw Equalizer Bars Grid (LED columns - static unlit matrix at 4% opacity - Full Screen Width)
    local numBars = 32
    local segmentHeight = 12
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
            
            local finalAlpha = alpha * 0.04
            -- Highlight ONLY if it is vertically on the selected row AND horizontally behind the buttons!
            if isSelectedRow and isBehindButtonColumn then
                -- Active glowing highlight: pulses and dances brilliantly to the column's audio frequency!
                finalAlpha = alpha * (0.16 + 0.36 * barIntensity)
            end
            
            love.graphics.setColor(r, g, b, finalAlpha)
            love.graphics.rectangle("fill", barX, segmentY, barWidth, segmentHeight, 2, 2)
        end
    end
    
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
    
    for i, option in ipairs(menuOptions) do
        local progress = animProgress[i] or 0
        local ease = 1 - math.pow(2, -10 * progress)
        
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
            love.graphics.setColor(0, 0.85, 1, alpha)
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

    -- 6. Draw Settings Overlay if open
    if showSettings then
        love.graphics.setColor(0.01, 0.01, 0.015, alpha * 0.95)
        love.graphics.rectangle("fill", menuCenter - 250, 320, 500, 320, 10, 10)
        
        love.graphics.setColor(0, 0.85, 1, alpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", menuCenter - 250, 320, 500, 320, 10, 10)
        
        love.graphics.setFont(subtitleFont)
        love.graphics.print("SYSTEM SETTINGS", menuCenter - 230, 340)
        
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.7, 0.7, 0.7, alpha)
        love.graphics.print("MASTER VOLUME:  80%  (Reactive stream)", menuCenter - 230, 410)
        love.graphics.print("INPUT METHOD:   KEYBOARD / MOUSE", menuCenter - 230, 450)
        love.graphics.print("SYSTEM COMM:    CONNECTIVITY STABLE", menuCenter - 230, 490)
        
        love.graphics.setColor(0.5, 0.5, 0.5, alpha)
        love.graphics.print("PRESS [SPACE / ENTER] TO EXIT OVERLAY", menuCenter - 230, 570)
    end

    -- 7. Draw Credits Overlay if open
    if showCredits then
        love.graphics.setColor(0.01, 0.01, 0.015, alpha * 0.95)
        love.graphics.rectangle("fill", menuCenter - 250, 320, 500, 320, 10, 10)
        
        love.graphics.setColor(0.9, 0, 0.6, alpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", menuCenter - 250, 320, 500, 320, 10, 10)
        
        love.graphics.setFont(subtitleFont)
        love.graphics.print("CREDITS", menuCenter - 230, 340)
        
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.7, 0.7, 0.7, alpha)
        love.graphics.print("DESIGN & ART:   VINTERSONG", menuCenter - 230, 410)
        
        love.graphics.setColor(0.5, 0.5, 0.5, alpha)
        love.graphics.print("PRESS [SPACE / ENTER] TO EXIT OVERLAY", menuCenter - 230, 570)
    end

    -- Reset default color
    love.graphics.setColor(1, 1, 1, 1)
end

function MenuState:keypressed(key)
    if Runtime.isWeb() then
        Runtime.startMusicAfterGesture()
    end

    if phase ~= "active" then return end

    -- If overlays are open, dismiss them on return/space/escape
    if showSettings then
        if key == "return" or key == "space" or key == "escape" then
            showSettings = false
        end
        return
    end

    if showCredits then
        if key == "return" or key == "space" or key == "escape" then
            showCredits = false
        end
        return
    end

    -- Menu controls
    if key == "up" then
        selectedMenuOption = selectedMenuOption - 1
        if selectedMenuOption < 1 then selectedMenuOption = #menuOptions end
    elseif key == "down" then
        selectedMenuOption = selectedMenuOption + 1
        if selectedMenuOption > #menuOptions then selectedMenuOption = 1 end
    elseif key == "return" or key == "space" then
        local action = menuOptions[selectedMenuOption].action
        if action == "startGame" then
            self:startGame()
        elseif action == "uiSandbox" then
            self:enterUISandbox()
        elseif action == "settings" then
            showSettings = true
        elseif action == "credits" then
            showCredits = true
        elseif action == "quit" then
            Runtime.quitOrReturnToTitle()
        end
        return
    elseif key == "u" then
        self:enterUISandbox()
        return
    elseif key == "escape" then
        Runtime.quitOrReturnToTitle()
        return
    end
end

function MenuState:mousepressed(x, y, button)
    if Runtime.isWeb() then
        Runtime.startMusicAfterGesture()
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

    phase = "fadeOut"
    timer = 0
end

function MenuState:enterUISandbox()
    if Runtime.isWeb() then
        Runtime.startMusicAfterGesture()
    end

    -- Reset font and switch immediately to UI Sandbox
    love.graphics.setFont(love.graphics.newFont(12))
    
    local StateManager = require("src.systems.StateManager")
    StateManager.switch("UISandbox")
end

return MenuState
