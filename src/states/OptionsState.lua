-- OptionsState.lua
-- High-fidelity Options screen featuring Audio sliders, Video toggles, and Controls guide

local OptionsState = {}
local Config = require("src.Config")
local Runtime = require("src.core.Runtime")
local GameConfig = require("src.core.GameConfig")
local StateManager = require("src.core.StateManager")
local SFXLibrary = require("src.audio.SFXLibrary")
local Settings = require("src.core.Settings")
local Theme = require("src.render.Theme")

local OPTIONS_GRID_CELL_HEIGHT = 12

-- Transition states
local alpha = 0
local fadeInDuration = 0.3
local fadeOutDuration = 0.4
local timer = 0
local phase = "fadeIn" -- fadeIn -> active -> fadeOut

-- Interactive states
local tabs = {
    {label = "AUDIO",    action = "audio"},
    {label = "VIDEO",    action = "video"},
    {label = "CONTROLS", action = "controls"},
    {label = "GAMEPLAY", action = "gameplay"},
    {label = "GENERAL",  action = "general"},
    {label = "BACK",     action = "back"}
}
local activeTab = 1
local focusOnRight = false

-- Clickable bounds, refreshed every draw. Left category tabs and right setting rows.
local tabRects = {}
local settingRects = {}

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

local gameplaySettings = {
    {label = "TUTORIAL", type = "toggle", key = "tutorialEnabled", get = function() return Config.gameplay.tutorialEnabled end, set = function(val) Config.gameplay.tutorialEnabled = val end}
}

local generalSettings = {}

local settingsMap = {
    audio    = audioSettings,
    video    = videoSettings,
    gameplay = gameplaySettings,
    general  = generalSettings,
}

local function getCurrentSettingsList()
    return settingsMap[tabs[activeTab].action]
end

local activeRightSelection = 1

-- Animation transition trackers for each tab
local tabAnimProgress = {}
local rightAnimProgress = {}

-- Fonts
local titleFont = nil
local subtitleFont = nil
local smallFont = nil
local boldFont = nil
local defaultFont = nil

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

    -- Branded CHROMATIC type system.
    titleFont = titleFont or Theme.font("display", Theme.scale.title)
    subtitleFont = subtitleFont or Theme.font("uiMedium", Theme.scale.subtitle)
    smallFont = smallFont or Theme.font("ui", Theme.scale.ui)
    boldFont = boldFont or Theme.font("uiSemiBold", Theme.scale.body)
    defaultFont = defaultFont or Theme.font("mono", Theme.scale.micro)

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
    local currentList = getCurrentSettingsList()
    local maxItems = currentList and #currentList or 0

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
            love.graphics.setFont(defaultFont)
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

    -- Reset clickable bounds; the draw passes below repopulate them.
    tabRects = {}
    settingRects = {}

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
    local segmentHeight = OPTIONS_GRID_CELL_HEIGHT
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

    local bandHeight = (segmentHeight + segmentGap) * 2
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, screenWidth, bandHeight)
    love.graphics.rectangle("fill", 0, screenHeight - bandHeight, screenWidth, bandHeight)
    
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

        tabRects[i] = {x = btnX, y = currentY, w = btnW, h = bracketHeight}
        
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
    local currentList = getCurrentSettingsList()

    if currentList and #currentList > 0 then
        local rightStartY = rightY + 130
        local itemHeight = 60
        
        for i, item in ipairs(currentList) do
            local itemY = rightStartY + (i - 1) * itemHeight
            local isSelected = (focusOnRight and i == activeRightSelection)

            settingRects[i] = {
                x = rightX + 30, y = itemY - 10, w = rightW - 60, h = 44,
                index = i, item = item, type = item.type,
                valX = rightX + 360, sliderW = 200,
            }

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
            {action = "MOVE", keys = {"W", "A", "S", "D"}, extra = "Directional movement"},
            {action = "AIM SHIP / SHOOT PROJECTILES", keys = {"MOUSE CURSOR"}, extra = "Shoots automatically"},
            {action = "DASH BOOST", keys = {"SPACE"}, extra = "1.5s cooldown"},
            {action = "BLINK TELEPORT / SHIELD", keys = {"E", "Q"}, extra = "Blink 5.0s | Shield 10.0s"},
            {action = "SUPERNOVA ARTIFACT", keys = {"PASSIVE"}, extra = "Reactive nova chance when hit"},
            {action = "PAUSE MENU", keys = {"P", "ESC"}, extra = "Freezes gameplay"}
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

    elseif action == "general" then
        -- Placeholder panel
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.4, 0.45, 0.55, alpha * 0.7)
        love.graphics.print("GENERAL SETTINGS - COMING SOON", rightX + 60, rightY + 130)

        love.graphics.setColor(0.5, 0.5, 0.6, alpha * 0.4)
        love.graphics.print("This section will be available in a future update.", rightX + 60, rightY + 165)
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
            SFXLibrary.play("menuMove")
        elseif key == "down" then
            activeTab = activeTab + 1
            if activeTab > #tabs then activeTab = 1 end
            SFXLibrary.play("menuMove")
        elseif key == "return" or key == "space" or key == "right" then
            local action = tabs[activeTab].action
            if action == "back" then
                self:goBack()
            else
                local list = getCurrentSettingsList()
                if list and #list > 0 then
                    focusOnRight = true
                    activeRightSelection = 1
                    SFXLibrary.play("menuMove")
                end
                -- tabs with no selectable items (controls, gameplay, general) stay in left focus
            end
        elseif key == "escape" then
            self:goBack()
        end
    else
        -- SETTINGS PANEL FOCUS MODE
        local currentList = getCurrentSettingsList()
        local item = currentList and currentList[activeRightSelection]

        if key == "escape" then
            focusOnRight = false
            SFXLibrary.play("menuMove")
        elseif key == "up" then
            if currentList and #currentList > 0 then
                activeRightSelection = activeRightSelection - 1
                if activeRightSelection < 1 then activeRightSelection = #currentList end
                SFXLibrary.play("menuMove")
            end
        elseif key == "down" then
            if currentList and #currentList > 0 then
                activeRightSelection = activeRightSelection + 1
                if activeRightSelection > #currentList then activeRightSelection = 1 end
                SFXLibrary.play("menuMove")
            end
        elseif key == "return" or key == "space" then
            if item and item.type == "toggle" then
                local currentVal = item.get()
                item.set(not currentVal)
                self:applySetting(item.key, not currentVal)
            end
        elseif key == "left" then
            if item and item.type == "slider" then
                local newVal = math.max(0, item.get() - 0.05)
                item.set(newVal)
                self:applySetting(item.key, newVal)
            else
                focusOnRight = false
                SFXLibrary.play("menuMove")
            end
        elseif key == "right" then
            if item and item.type == "slider" then
                local newVal = math.min(1, item.get() + 0.05)
                item.set(newVal)
                self:applySetting(item.key, newVal)
            end
        end
    end
end

local function pointIn(rect, x, y)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

function OptionsState:mousepressed(x, y, button)
    if Runtime.isWeb() then
        Runtime.startMusicAfterGesture()
    end
    if phase ~= "active" or button ~= 1 then return end

    -- Left category tabs
    for i, rect in ipairs(tabRects) do
        if pointIn(rect, x, y) then
            activeTab = i
            focusOnRight = false
            SFXLibrary.play("menuMove")
            if tabs[i].action == "back" then
                self:goBack()
            end
            return
        end
    end

    -- Right setting rows
    for _, rect in ipairs(settingRects) do
        if pointIn(rect, x, y) then
            focusOnRight = true
            activeRightSelection = rect.index
            local item = rect.item
            if item.type == "toggle" then
                local newVal = not item.get()
                item.set(newVal)
                self:applySetting(item.key, newVal)
                SFXLibrary.play("menuMove")
            elseif item.type == "slider" then
                -- Only adjust when clicking on/after the track start; clicking the
                -- label area just focuses the row (so it can't zero the value).
                if x >= rect.valX then
                    local t = math.max(0, math.min(1, (x - rect.valX) / rect.sliderW))
                    local newVal = math.floor(t * 20 + 0.5) / 20 -- snap to 5% steps
                    item.set(newVal)
                    self:applySetting(item.key, newVal)
                end
                SFXLibrary.play("menuMove")
            end
            return
        end
    end
end

function OptionsState:mousemoved(x, y)
    if phase ~= "active" then return end

    if not focusOnRight then
        for i, rect in ipairs(tabRects) do
            if pointIn(rect, x, y) and activeTab ~= i then
                activeTab = i
                SFXLibrary.play("menuMove")
                return
            end
        end
    else
        for _, rect in ipairs(settingRects) do
            if pointIn(rect, x, y) and activeRightSelection ~= rect.index then
                activeRightSelection = rect.index
                SFXLibrary.play("menuMove")
                return
            end
        end
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
        local BackgroundShader = require("src.render.BackgroundShader")
        BackgroundShader.toggleEffect("glow", val)

    elseif key == "tutorialEnabled" then
        Config.gameplay.tutorialEnabled = val
        Settings.save() -- persist so the choice survives between sessions
    end
end

function OptionsState:goBack()
    phase = "fadeOut"
    timer = 0
end

return OptionsState
