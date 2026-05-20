-- SplashScreen.lua
-- Initial splash screen that displays game title and fades to MenuState upon keypress

local SplashScreen = {}
local Config = require("src.Config")
local Runtime = require("src.systems.Runtime")
local GameConfig = require("src.systems.GameConfig")

-- Animation state
local alpha = 0
local fadeInDuration = 1.0
local fadeOutDuration = 0.8
local timer = 0
local phase = "fadeIn" -- fadeIn -> display -> fadeOut

-- Text settings
local titleText = "CHROMATIC"
local subtitleText = "Press ANY KEY to continue."
local titleSize = 150
local subtitleSize = 24

-- Fonts (created once)
local titleFont = nil
local subtitleFont = nil

-- Background Shader
local bgShader = nil

-- Equalizer visualization state
local equalizerHeights = {}
for i = 1, 32 do
    equalizerHeights[i] = 0
end

function SplashScreen:enter(previous, data)
    -- Reset animation state
    alpha = 0
    timer = 0
    phase = "fadeIn"

    -- Create fonts once on enter
    if not titleFont then
        titleFont = love.graphics.newFont(titleSize)
    end
    if not subtitleFont then
        subtitleFont = love.graphics.newFont(subtitleSize)
    end

    -- Load shader safely
    if not bgShader then
        local success, result = pcall(love.graphics.newShader, "assets/shaders/splashscreen.glsl")
        if success then
            bgShader = result
            print("[SplashScreen] Background shader loaded successfully")
        else
            print("[SplashScreen] Failed to load background shader: " .. tostring(result))
        end
    end

    print("[SplashScreen] Entered splash screen")
end

function SplashScreen:update(dt)
    timer = timer + dt

    -- Update music reactor for real-time visualization frequencies
    local musicReactor = GameConfig.getMusicReactor()
    if musicReactor then
        musicReactor:update(dt)
        
        -- Extract current frequency bands
        local bands = {
            musicReactor:getBass(),
            musicReactor:getMid(),
            (musicReactor:getMid() + musicReactor:getTreble()) / 2,
            musicReactor:getTreble(),
            musicReactor:getPresenceIntensity()
        }
        
        -- Interpolate and calculate target heights for our 32-bar display
        for i = 1, 32 do
            local t = (i - 1) / 31 * 4 + 1 -- Map 1..32 bars to 1..5 bands
            local idx1 = math.floor(t)
            local idx2 = math.min(5, idx1 + 1)
            local frac = t - idx1
            
            local val1 = bands[idx1] or 0
            local val2 = bands[idx2] or 0
            local targetVal = val1 * (1 - frac) + val2 * frac
            
            -- Add clean high-frequency organic variation to bars
            local noise = 0.08 * math.sin(love.timer.getTime() * 15 + i * 0.7)
            targetVal = math.max(0, math.min(1, targetVal + noise * targetVal))
            
            -- Smooth physical bounce: rise instantly, fall smoothly under "gravity"
            if targetVal > equalizerHeights[i] then
                equalizerHeights[i] = targetVal
            else
                equalizerHeights[i] = equalizerHeights[i] - dt * 1.5
                equalizerHeights[i] = math.max(0, equalizerHeights[i])
            end
        end
    end

    if phase == "fadeIn" then
        -- Fade in from black
        alpha = math.min(1, timer / fadeInDuration)

        if timer >= fadeInDuration then
            phase = "display"
            timer = 0
        end
    elseif phase == "display" then
        -- Stay at full opacity indefinitely until keypress
        alpha = 1
    elseif phase == "fadeOut" then
        -- Fade out to black
        alpha = math.max(0, 1 - (timer / fadeOutDuration))

        if timer >= fadeOutDuration then
            timer = 0
            -- Switch to MenuState
            local StateManager = require("src.systems.StateManager")
            StateManager.switch("Menu")
        end
    end
end

function SplashScreen:draw()
    local screenWidth = Config.screen.width
    local screenHeight = Config.screen.height
    
    -- Clear to black
    love.graphics.clear(0, 0, 0, 1)

    -- 1. Draw Background Shader if loaded
    local musicReactor = GameConfig.getMusicReactor()
    local intensity = musicReactor and musicReactor:getOverallIntensity() or 0
    
    if bgShader then
        local previousShader = love.graphics.getShader()
        pcall(function()
            bgShader:send("resolution", {screenWidth, screenHeight})
            bgShader:send("time", love.timer.getTime())
            bgShader:send("intensity", intensity)
            bgShader:send("bloomEnabled", Config.postFX.bloomEnabled and 1.0 or 0.0)
        end)
        
        love.graphics.setShader(bgShader)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
        love.graphics.setShader(previousShader)
    end

    -- 2. Draw Equalizer Bars (LED Segment Style with Chromatic Rainbow Cycle - Full Screen Height)
    local numBars = 32
    local barWidth = 56
    local barGap = 4
    local startX = 2
    
    local segmentHeight = 12
    local segmentGap = 3
    local numSegmentsTotal = 72 -- Covers full height: 72 * 15 = 1080 pixels (top of the screen)
    local numSegmentsActiveMax = 36 -- Active reactive segments only fill up to the middle maximum: 36 * 15 = 540 pixels
    local time = love.timer.getTime()
    
    for i = 1, numBars do
        local barX = startX + (i - 1) * (barWidth + barGap)
        local val = equalizerHeights[i] or 0
        local numActive = math.ceil(val * numSegmentsActiveMax)
        
        -- Calculate base color for this bar to match the horizontal chromatic wave of the text
        local barOffset = (i - 1) * 0.12
        local r = 0.5 + 0.5 * math.sin(time * 2 + barOffset)
        local g = 0.5 + 0.5 * math.sin(time * 2 + 2.09 + barOffset)
        local b = 0.5 + 0.5 * math.sin(time * 2 + 4.18 + barOffset)
        
        for j = 1, numSegmentsTotal do
            local segmentY = screenHeight - (j * (segmentHeight + segmentGap))
            
            -- Segment state opacity (Lit vs Unlit background placeholder)
            local segmentAlpha
            if j <= numActive then
                if Config.postFX.bloomEnabled then
                    segmentAlpha = alpha * 0.75 -- Lit segment glow
                else
                    segmentAlpha = alpha * 0.25 -- Much more muted, non-distracting
                end
            else
                segmentAlpha = alpha * 0.05 -- Unlit grid cell backing extending all the way to the top
            end
            
            love.graphics.setColor(r, g, b, segmentAlpha)
            love.graphics.rectangle("fill", barX, segmentY, barWidth, segmentHeight, 2, 2)
        end
    end

    -- 3. Draw Title (centered, on top of equalizer background)
    love.graphics.setFont(titleFont)
    local titleY = 350
    
    -- Calculate individual character widths and total width with a symmetrical gap
    local widths = {}
    local totalWidth = 0
    local charGap = 10 -- Symmetrical extra spacing between characters
    
    for i = 1, #titleText do
        local char = titleText:sub(i, i)
        widths[i] = titleFont:getWidth(char)
        totalWidth = totalWidth + widths[i]
    end
    totalWidth = totalWidth + (#titleText - 1) * charGap
    
    -- Center the entire string on the screen
    local startXText = (screenWidth - totalWidth) / 2
    local currentX = startXText
    
    for i = 1, #titleText do
        local char = titleText:sub(i, i)
        local charOffset = (i - 1) * 0.4 -- Smooth color shift across characters
        
        local r = 0.5 + 0.5 * math.sin(time * 2 + charOffset)
        local g = 0.5 + 0.5 * math.sin(time * 2 + 2.09 + charOffset)
        local b = 0.5 + 0.5 * math.sin(time * 2 + 4.18 + charOffset)
        
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.print(char, currentX, titleY)
        
        -- Move to the next character position using its natural width plus the gap
        currentX = currentX + widths[i] + charGap
    end

    -- 4. Draw Subtitle
    love.graphics.setFont(subtitleFont)
    local subtitleWidth = subtitleFont:getWidth(subtitleText)
    local subtitleX = (screenWidth - subtitleWidth) / 2
    local subtitleY = titleY + 200

    love.graphics.setColor(1, 1, 1, alpha * 0.5)
    love.graphics.print(subtitleText, subtitleX, subtitleY)

    -- Reset color and font
    love.graphics.setColor(1, 1, 1, 1)
end

function SplashScreen:keypressed(key)
    if Runtime.isWeb() then
        Runtime.startMusicAfterGesture()
    end

    -- Trigger fade out to MenuState when a key is pressed during fadeIn or display
    if phase == "fadeIn" or phase == "display" then
        phase = "fadeOut"
        timer = 0
    end
end

function SplashScreen:mousepressed(x, y, button)
    if Runtime.isWeb() then
        Runtime.startMusicAfterGesture()
    end

    if phase == "fadeIn" or phase == "display" then
        phase = "fadeOut"
        timer = 0
    end
end

function SplashScreen:touchpressed(id, x, y, dx, dy, pressure)
    if Runtime.isWeb() then
        Runtime.startMusicAfterGesture()
    end

    if phase == "fadeIn" or phase == "display" then
        phase = "fadeOut"
        timer = 0
    end
end

return SplashScreen
