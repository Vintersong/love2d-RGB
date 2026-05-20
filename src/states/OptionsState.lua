-- OptionsState.lua
-- High-fidelity Options screen featuring Audio sliders, Video toggles, and Controls guide

local OptionsState = {}
local Config = require("src.Config")
local Runtime = require("src.systems.Runtime")
local GameConfig = require("src.systems.GameConfig")
local StateManager = require("src.systems.StateManager")

-- Transition states
local alpha = 0
local fadeInDuration = 0.3
local fadeOutDuration = 0.4
local timer = 0
local phase = "fadeIn" -- fadeIn -> active -> fadeOut

-- Interactive states
local tabs = {
    {label = "AUDIO", action = "audio"},
    {label = "VIDEO", action = "video"},
    {label = "CONTROLS", action = "controls"},
    {label = "BACK", action = "back"}
}
local activeTab = 1
local focusOnRight = false

-- Right-hand settings lists
local audioSettings = {
    {label = "MUTE ALL", type = "toggle", key = "muteAudio", get = function() return Config.debug.muteAudio end, set = function(val) Config.debug.muteAudio = val end},
    {label = "MASTER VOLUME", type = "slider", key = "volume", get = function() return Config.sound.volume end, set = function(val) Config.sound.volume = val end}
}

local videoSettings = {
    {label = "FULLSCREEN", type = "toggle", key = "fullscreen", get = function() return Config.screen.fullscreen end, set = function(val) Config.screen.fullscreen = val end},
    {label = "VSYNC", type = "toggle", key = "vsync", get = function() return Config.screen.vsync end, set = function(val) Config.screen.vsync = val end},
    {label = "BLOOM EFFECT", type = "toggle", key = "bloomEnabled", get = function() return Config.postFX.bloomEnabled end, set = function(val) Config.postFX.bloomEnabled = val end}
}

local activeRightSelection = 1

-- Animation transition trackers for each tab
local tabAnimProgress = {}
local rightAnimProgress = {}

-- Fonts
local titleFont = nil
local subtitleFont = nil
local smallFont = nil
local boldFont = nil

-- Background Shader
local bgShader = nil

-- Glowing visualizer Y-tracker for selection highlighting
local glowY = nil
local rightGlowY = nil

function OptionsState:enter(previous, data)
    alpha = 0
    timer = 0
    phase = "fadeIn"
    activeTab = 1
    focusOnRight = false
    activeRightSelection = 1
    glowY = nil
    rightGlowY = nil

    if not titleFont then
        titleFont = love.graphics.newFont(75)
    end
    if not subtitleFont then
        subtitleFont = love.graphics.newFont(24)
    end
    if not smallFont then
        smallFont = love.graphics.newFont(16)
    end
    if not boldFont then
        boldFont = love.graphics.newFont("libs/hump-master/docs/_static/default.css" and 18 or 18) -- backup bold font logic
    end

    -- Reset animation track tables
    for i = 1, #tabs do
        tabAnimProgress[i] = 0
    end
    for i = 1, 5 do
        rightAnimProgress[i] = 0
    end

    -- Load shader safely
    if not bgShader then
        local success, result = pcall(love.graphics.newShader, "assets/shaders/splashscreen.glsl")
        if success then
            bgShader = result
            print("[OptionsState] Background shader loaded successfully")
        else
            print("[OptionsState] Failed to load background shader: " .. tostring(result))
        end
    end

    print("[OptionsState] Entered Settings screen")
end

function OptionsState:update(dt)
    timer = timer + dt
    
    -- Update music reactor if present so equalizer continues dancing
    local musicReactor = GameConfig.getMusicReactor()
    if musicReactor then
        musicReactor:update(dt)
    end

    -- Animate tab selection progress
    for i = 1, #tabs do
        local target = (i == activeTab and not focusOnRight) and 1 or 0
        if tabAnimProgress[i] < target then
            tabAnimProgress[i] = math.min(target, tabAnimProgress[i] + dt / 0.15)
        elseif tabAnimProgress[i] > target then
            tabAnimProgress[i] = math.max(target, tabAnimProgress[i] - dt / 0.15)
        end
    end

    -- Animate active settings list items selection progress
    local maxItems = 2
    if tabs[activeTab].action == "video" then maxItems = 3 end
    if tabs[activeTab].action == "controls" then maxItems = 0 end
    
    for i = 1, maxItems do
        local target = (focusOnRight and i == activeRightSelection) and 1 or 0
        if rightAnimProgress[i] < target then
            rightAnimProgress[i] = math.min(target, rightAnimProgress[i] + dt / 0.15)
        elseif rightAnimProgress[i] > target then
            rightAnimProgress[i] = math.max(target, rightAnimProgress[i] - dt / 0.15)
        end
    end
    
    -- Easing for tab glow tracker
    local screenHeight = Config.screen.height
    local menuBottomLimit = screenHeight - (screenHeight * 0.1)
    local bracketHeight = 44
    local gap = 16
    local numItems = #tabs
    local totalMenuHeight = numItems * bracketHeight + (numItems - 1) * gap
    local stackStartY = menuBottomLimit - totalMenuHeight
    local selectedY = stackStartY + (activeTab - 1) * (bracketHeight + gap)
    
    if not glowY then
        glowY = selectedY
    else
        glowY = glowY + (selectedY - glowY) * dt * 16
    end

    -- Easing for right settings item glow tracker
    if focusOnRight then
        local rightStartY = rightY or (320 + 130) -- fallback
        local itemHeight = 60
        local rightSelectedY = 320 + 130 + (activeRightSelection - 1) * itemHeight
        if not rightGlowY then
            rightGlowY = rightSelectedY
        else
            rightGlowY = rightGlowY + (rightSelectedY - rightGlowY) * dt * 16
        end
    else
        rightGlowY = nil
    end

    if phase == "fadeIn" then
        alpha = math.min(1, timer / fadeInDuration)
        if timer >= fadeInDuration then
            phase = "active"
            timer = 0
        end
    elseif phase == "fadeOut" then
        alpha = math.max(0, 1 - (timer / fadeOutDuration))
        if timer >= fadeOutDuration then
            love.graphics.setFont(love.graphics.newFont(12))
            timer = 0
            StateManager.switch("Menu")
        end
    end
end

function OptionsState:draw()
    local screenWidth = Config.screen.width
    local screenHeight = Config.screen.height
    
    -- Clear to deep space black
    love.graphics.clear(0.015, 0.012, 0.02, 1)

    -- Draw background shader
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

    -- Draw Equalizer Grid in background
    local numBars = 32
    local barWidth = 56
    local barGap = 4
    local startX = 2
    local barStep = barWidth + barGap
    local segmentHeight = 12
    local segmentGap = 3
    local numSegmentsTotal = 72
    local time = love.timer.getTime()
    
    -- Determine highlighted columns based on left side UI
    local margin = screenHeight * 0.1
    local titleX = margin
    local titleY = margin
    
    local widths = {}
    local totalWidth = 0
    local charGap = 10
    local titleText = "SETTINGS"
    
    for i = 1, #titleText do
        local char = titleText:sub(i, i)
        widths[i] = titleFont:getWidth(char)
        totalWidth = totalWidth + widths[i]
    end
    totalWidth = totalWidth + (#titleText - 1) * charGap
    local menuCenter = titleX + totalWidth / 2
    local centerCol = math.floor((menuCenter - startX) / barStep) + 1
    local colStart = centerCol - 2
    if colStart < 1 then colStart = 1 end
    local colEnd = colStart + 4
    
    local btnX = startX + (colStart - 1) * barStep
    local btnW = 5 * barWidth + 4 * barGap
    local bracketHeight = 44
    local gap = 16
    local stackStartY = screenHeight - (screenHeight * 0.1) - (#tabs * bracketHeight + (#tabs - 1) * gap)

    for i = 1, numBars do
        local barX = startX + (i - 1) * (barWidth + barGap)
        local barOffset = (i - 1) * 0.12
        local r = 0.5 + 0.5 * math.sin(time * 2 + barOffset)
        local g = 0.5 + 0.5 * math.sin(time * 2 + 2.09 + barOffset)
        local b = 0.5 + 0.5 * math.sin(time * 2 + 4.18 + barOffset)
        
        local barIntensity = 0.1
        if musicReactor then
            barIntensity = musicReactor:getBandIntensity(i) or 0.1
        end
        
        local isBehindButtonColumn = (i >= colStart and i <= colEnd)
        
        for j = 1, numSegmentsTotal do
            local segmentY = screenHeight - (j * (segmentHeight + segmentGap))
            local isSelectedRow = false
            
            if glowY and not focusOnRight then
                isSelectedRow = (segmentY >= glowY - 2) and (segmentY + segmentHeight <= glowY + bracketHeight + 2)
            end
            
            local finalAlpha = alpha * 0.04
            if isSelectedRow and isBehindButtonColumn then
                finalAlpha = alpha * (0.08 + 0.1 * barIntensity)
            end
            
            love.graphics.setColor(r, g, b, finalAlpha)
            love.graphics.rectangle("fill", barX, segmentY, barWidth, segmentHeight, 2, 2)
        end
    end
    
    -- Draw title text with dynamic RGB color cycling
    love.graphics.setFont(titleFont)
    local currentX = titleX
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

    -- Draw Left Sidebar Categories stack
    local currentY = stackStartY
    for i, tab in ipairs(tabs) do
        local progress = tabAnimProgress[i] or 0
        local ease = 1 - math.pow(2, -10 * progress)
        local slideOffset = ease * 8
        local lx = btnX + slideOffset
        local rx = btnX + btnW - slideOffset
        
        -- Tab background
        love.graphics.setColor(0, 0, 0, alpha * 0.5)
        love.graphics.rectangle("fill", lx, currentY, rx - lx, bracketHeight)
        
        -- Brackets outline
        love.graphics.setLineWidth(1.5)
        if i == activeTab then
            if focusOnRight then
                love.graphics.setColor(0, 0.45, 0.6, alpha * 0.7) -- darker color if focus shifted
            else
                love.graphics.setColor(0, 0.85, 1, alpha) -- bright cyan highlight
            end
        else
            love.graphics.setColor(1, 1, 1, alpha * 0.12)
        end
        
        -- Draw segmented brackets
        love.graphics.line(lx + 12, currentY, lx, currentY, lx, currentY + 12)
        love.graphics.line(lx + 12, currentY + bracketHeight, lx, currentY + bracketHeight, lx, currentY + bracketHeight - 12)
        love.graphics.line(rx - 12, currentY, rx, currentY, rx, currentY + 12)
        love.graphics.line(rx - 12, currentY + bracketHeight, rx, currentY + bracketHeight, rx, currentY + bracketHeight - 12)
        
        -- Label Text
        love.graphics.setFont(smallFont)
        local btnCenterX = btnX + btnW / 2
        if i == activeTab and not focusOnRight then
            love.graphics.setColor(0, 0, 0, alpha * 0.5)
            love.graphics.print(tab.label, btnCenterX - smallFont:getWidth(tab.label)/2 + 1, currentY + bracketHeight/2 - 8 + 1)
            love.graphics.setColor(1, 1, 1, alpha)
        else
            love.graphics.setColor(0.55, 0.6, 0.7, alpha * 0.6)
        end
        love.graphics.print(tab.label, btnCenterX - smallFont:getWidth(tab.label)/2, currentY + bracketHeight/2 - 8)
        
        currentY = currentY + bracketHeight + gap
    end

    -- Draw Right Panel Details
    local rightX = btnX + btnW + 120
    local rightW = screenWidth - rightX - margin
    local rightY = 320
    local rightH = screenHeight - rightY - margin
    
    -- Tech panel backing
    love.graphics.setColor(0.01, 0.01, 0.015, alpha * 0.8)
    love.graphics.rectangle("fill", rightX, rightY, rightW, rightH, 12, 12)
    
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0, 0.85, 1, alpha * 0.25)
    love.graphics.rectangle("line", rightX, rightY, rightW, rightH, 12, 12)
    
    -- Sub-title inside right panel
    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(0.85, 0.85, 0.9, alpha)
    love.graphics.print(tabs[activeTab].label .. " PARAMETERS", rightX + 40, rightY + 40)
    
    -- Draw horizontal dividing line
    love.graphics.setColor(0, 0.85, 1, alpha * 0.15)
    love.graphics.line(rightX + 40, rightY + 90, rightX + rightW - 40, rightY + 90)

    -- Dynamic Rendering based on active tab
    local action = tabs[activeTab].action
    
    if action == "audio" or action == "video" then
        local currentList = (action == "audio") and audioSettings or videoSettings
        local rightStartY = rightY + 130
        local itemHeight = 60
        
        for i, item in ipairs(currentList) do
            local itemY = rightStartY + (i - 1) * itemHeight
            local isSelected = (focusOnRight and i == activeRightSelection)
            
            -- Selection row highlight
            if isSelected then
                love.graphics.setColor(0, 0.85, 1, alpha * 0.08)
                love.graphics.rectangle("fill", rightX + 30, itemY - 10, rightW - 60, 44, 6, 6)
                
                love.graphics.setColor(0, 0.85, 1, alpha * 0.4)
                love.graphics.rectangle("line", rightX + 30, itemY - 10, rightW - 60, 44, 6, 6)
            end
            
            -- Label
            love.graphics.setFont(smallFont)
            if isSelected then
                love.graphics.setColor(1, 1, 1, alpha)
            else
                love.graphics.setColor(0.65, 0.7, 0.8, alpha * 0.7)
            end
            love.graphics.print(item.label, rightX + 60, itemY + 2)
            
            -- Control Value Rendering
            local valX = rightX + 360
            local val = item.get()
            
            if item.type == "toggle" then
                -- Render beautiful LED toggle switch
                local toggleText = val and "ENABLED" or "DISABLED"
                love.graphics.setFont(smallFont)
                
                -- Toggle backing bracket
                love.graphics.setColor(0, 0, 0, alpha * 0.5)
                love.graphics.rectangle("fill", valX, itemY - 4, 120, 26, 4, 4)
                
                love.graphics.setLineWidth(1)
                if val then
                    love.graphics.setColor(0, 1, 0.5, alpha * 0.6)
                else
                    love.graphics.setColor(1, 0.1, 0.4, alpha * 0.6)
                end
                love.graphics.rectangle("line", valX, itemY - 4, 120, 26, 4, 4)
                
                -- Dynamic LED status pip
                if val then
                    love.graphics.setColor(0, 1, 0.5, alpha)
                    love.graphics.circle("fill", valX + 20, itemY + 9, 5)
                else
                    love.graphics.setColor(1, 0.1, 0.4, alpha)
                    love.graphics.circle("fill", valX + 20, itemY + 9, 5)
                end
                
                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.print(toggleText, valX + 38, itemY)
                
            elseif item.type == "slider" then
                -- Render interactive slider bar
                local percent = val * 100
                
                -- Outer track
                love.graphics.setColor(0.1, 0.1, 0.15, alpha)
                love.graphics.rectangle("fill", valX, itemY + 6, 200, 10, 5, 5)
                
                -- Filled progress with color sweep
                local r = 0.5 + 0.5 * math.sin(time * 3)
                local g = 0.5 + 0.5 * math.sin(time * 3 + 2.09)
                local b = 0.5 + 0.5 * math.sin(time * 3 + 4.18)
                love.graphics.setColor(r, g, b, alpha)
                love.graphics.rectangle("fill", valX, itemY + 6, 200 * val, 10, 5, 5)
                
                -- End tick handle
                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.circle("fill", valX + 200 * val, itemY + 11, 8)
                
                -- Value string
                love.graphics.print(string.format("%.0f%%", percent), valX + 220, itemY)
            end
        end
        
        -- Help navigation footer text
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.5, 0.5, 0.6, alpha * 0.6)
        if focusOnRight then
            love.graphics.print("Press [UP / DOWN] to select items | [LEFT / RIGHT / ENTER] to adjust | [ESC] to return to categories", rightX + 60, rightY + rightH - 50)
        else
            love.graphics.print("Press [RIGHT / ENTER] to edit these settings", rightX + 60, rightY + rightH - 50)
        end
        
    elseif action == "controls" then
        -- Render visual bindings list in stylish dashboard structure
        local bindY = rightY + 130
        local bindH = 50
        
        local bindings = {
            {action = "MOVE UP / LEFT / DOWN / RIGHT", keys = {"W", "A", "S", "D"}, extra = "Or ARROW keys"},
            {action = "AIM SHIP / SHOOT PROJECTILES", keys = {"MOUSE CURSOR"}, extra = "Shoots automatically"},
            {action = "TRIGGER SPEED BOOST (DASH)", keys = {"SPACE", "L-SHIFT"}, extra = "1.0s Cooldown"},
            {action = "ACTIVATE SUPERNOVA ULTIMATE", keys = {"L-SHIFT"}, extra = "When hyper-charged"},
            {action = "PAUSE / RETRIEVE MENUS", keys = {"P", "ESC"}, extra = "Freezes state"}
        }
        
        for i, bind in ipairs(bindings) do
            local itemY = bindY + (i - 1) * bindH
            
            -- Action description
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0.7, 0.75, 0.85, alpha * 0.85)
            love.graphics.print(bind.action, rightX + 60, itemY)
            
            -- Draw dynamic key blocks
            local keyXStart = rightX + 380
            for k, keyName in ipairs(bind.keys) do
                local textW = smallFont:getWidth(keyName)
                local pad = 10
                local blockW = math.max(34, textW + pad * 2)
                local blockH = 26
                
                -- Key boundary block
                love.graphics.setColor(0.08, 0.08, 0.12, alpha)
                love.graphics.rectangle("fill", keyXStart, itemY - 4, blockW, blockH, 5, 5)
                
                love.graphics.setLineWidth(1)
                love.graphics.setColor(0, 0.85, 1, alpha * 0.4)
                love.graphics.rectangle("line", keyXStart, itemY - 4, blockW, blockH, 5, 5)
                
                -- Key string
                love.graphics.setFont(smallFont)
                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.print(keyName, keyXStart + (blockW/2 - textW/2), itemY - 2)
                
                keyXStart = keyXStart + blockW + 10
            end
            
            -- Extra description details
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0.45, 0.5, 0.65, alpha * 0.6)
            love.graphics.print(bind.extra, keyXStart + 10, itemY)
        end
        
        -- Help navigation footer text
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.5, 0.5, 0.6, alpha * 0.6)
        love.graphics.print("Keyboard & Mouse controls are active automatically", rightX + 60, rightY + rightH - 50)
    end

    -- Reset color parameters
    love.graphics.setColor(1, 1, 1, 1)
end

function OptionsState:keypressed(key)
    if Runtime.isWeb() then
        Runtime.startMusicAfterGesture()
    end

    if phase ~= "active" then return end

    if not focusOnRight then
        -- CATEGORY NAVIGATION MODE
        if key == "up" then
            activeTab = activeTab - 1
            if activeTab < 1 then activeTab = #tabs end
        elseif key == "down" then
            activeTab = activeTab + 1
            if activeTab > #tabs then activeTab = 1 end
        elseif key == "return" or key == "space" or key == "right" then
            local action = tabs[activeTab].action
            if action == "back" then
                self:goBack()
            elseif action == "controls" then
                -- View tab only, no selectable inputs
            else
                -- Focus details on the right panel
                focusOnRight = true
                activeRightSelection = 1
            end
        elseif key == "escape" then
            self:goBack()
        end
    else
        -- SETTINGS PANEL FOCUS MODE
        local currentAction = tabs[activeTab].action
        local currentList = (currentAction == "audio") and audioSettings or videoSettings
        
        if key == "escape" or key == "left" then
            focusOnRight = false
        elseif key == "up" then
            activeRightSelection = activeRightSelection - 1
            if activeRightSelection < 1 then activeRightSelection = #currentList end
        elseif key == "down" then
            activeRightSelection = activeRightSelection + 1
            if activeRightSelection > #currentList then activeRightSelection = 1 end
        elseif key == "return" or key == "space" then
            local item = currentList[activeRightSelection]
            if item.type == "toggle" then
                local currentVal = item.get()
                item.set(not currentVal)
                self:applySetting(item.key, not currentVal)
            end
        elseif key == "left" or key == "right" then
            local item = currentList[activeRightSelection]
            if item.type == "slider" then
                local currentVal = item.get()
                local delta = (key == "left") and -0.05 or 0.05
                local newVal = math.max(0, math.min(1, currentVal + delta))
                item.set(newVal)
                self:applySetting(item.key, newVal)
            end
        end
    end
end

function OptionsState:mousepressed(x, y, button)
    if Runtime.isWeb() then
        Runtime.startMusicAfterGesture()
    end
end

function OptionsState:applySetting(key, val)
    print(string.format("[OptionsState] Applying settings change: %s = %s", key, tostring(val)))
    
    if key == "muteAudio" then
        if val then
            love.audio.setVolume(0)
            -- Direct muting on music reactor
            local musicReactor = GameConfig.getMusicReactor()
            if musicReactor and musicReactor.currentSong then
                musicReactor.currentSong:setVolume(0)
            end
        else
            love.audio.setVolume(Config.sound.volume or 0.8)
            local musicReactor = GameConfig.getMusicReactor()
            if musicReactor and musicReactor.currentSong then
                musicReactor.currentSong:setVolume(1)
            end
        end
        
    elseif key == "volume" then
        Config.sound.volume = val
        if not Config.debug.muteAudio then
            love.audio.setVolume(val)
        end
        
    elseif key == "fullscreen" then
        Config.screen.fullscreen = val
        pcall(function()
            love.window.setFullscreen(val)
        end)
        
    elseif key == "vsync" then
        Config.screen.vsync = val
        pcall(function()
            love.window.setVSync(val and 1 or 0)
        end)
        
    elseif key == "bloomEnabled" then
        Config.postFX.bloomEnabled = val
        local BackgroundShader = require("src.systems.BackgroundShader")
        BackgroundShader.toggleEffect("glow", val)
    end
end

function OptionsState:goBack()
    phase = "fadeOut"
    timer = 0
end

return OptionsState
