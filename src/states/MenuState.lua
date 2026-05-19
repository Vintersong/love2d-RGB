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
local titleSize = 130
local subtitleSize = 24

-- Fonts
local titleFont = nil
local subtitleFont = nil
local smallFont = nil

-- Background Shader
local bgShader = nil

function MenuState:enter(previous, data)
    alpha = 0
    timer = 0
    phase = "fadeIn"
    selectedMenuOption = 1
    showSettings = false
    showCredits = false

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
    
    -- 1. Clear to deep space black
    love.graphics.clear(0.015, 0.012, 0.02, 1)

    -- 2. Draw Background Shader if loaded (Full Screen)
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

    -- 3. Draw Equalizer Bars Grid (LED columns - static unlit matrix at 4% opacity - Full Screen Width)
    local numBars = 32
    local barWidth = 56
    local barGap = 4
    local startX = 2
    
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
        
        for j = 1, numSegmentsTotal do
            local segmentY = screenHeight - (j * (segmentHeight + segmentGap))
            love.graphics.setColor(r, g, b, alpha * 0.04)
            love.graphics.rectangle("fill", barX, segmentY, barWidth, segmentHeight, 2, 2)
        end
    end

    -- 4. Draw Title (centered, on top of equalizer background)
    love.graphics.setFont(titleFont)
    local titleY = 240
    
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
    
    local startXText = (screenWidth / 2) - (totalWidth / 2)
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

    -- 5. Draw Centered Segmented Bracket Menu Options Stack
    local menuCenter = screenWidth / 2
    local stackStartY = titleY + 180
    local bracketHeight = 44
    local gap = 16
    local currentY = stackStartY
    
    for i, option in ipairs(menuOptions) do
        local progress = animProgress[i] or 0
        local ease = 1 - math.pow(2, -10 * progress)
        
        -- Segmented Brackets Style (Minimalist Tech)
        local btnW = 420
        local btnX = menuCenter - (btnW / 2)
        
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
        if i == selectedMenuOption then
            love.graphics.setColor(0, 0, 0, alpha * 0.5)
            love.graphics.print(option.label, menuCenter - smallFont:getWidth(option.label)/2 + 1, currentY + bracketHeight/2 - 8 + 1)
            
            love.graphics.setColor(1, 1, 1, alpha)
        else
            love.graphics.setColor(0.55, 0.6, 0.7, alpha * 0.6)
        end
        love.graphics.print(option.label, menuCenter - smallFont:getWidth(option.label)/2, currentY + bracketHeight/2 - 8)
        
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
        love.graphics.print("SYSTEM ENGINE:  ANTIGRAVITY AI", menuCenter - 230, 450)
        love.graphics.print("FRAMEWORK:      LÖVE2D / HUMP GAMESTATE", menuCenter - 230, 490)
        
        love.graphics.setColor(0.5, 0.5, 0.5, alpha)
        love.graphics.print("PRESS [SPACE / ENTER] TO EXIT OVERLAY", menuCenter - 230, 570)
    end

    -- Reset default color
    love.graphics.setColor(1, 1, 1, 1)
end

function MenuState:keypressed(key)
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
