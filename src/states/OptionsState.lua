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
local ShellStyle = require("src.ui.ShellStyle")

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

-- Fonts
local titleFont = nil
local subtitleFont = nil
local smallFont = nil
local boldFont = nil
local defaultFont = nil

-- Background Shader
local bgShader = nil

function OptionsState:enter(previous, data)
    alpha = 0
    timer = 0
    phase = "fadeIn"
    activeTab = 1
    focusOnRight = false
    activeRightSelection = 1

    titleFont = titleFont or Theme.font("display", Theme.scale.title)
    subtitleFont = subtitleFont or Theme.font("uiMedium", Theme.scale.subtitle)
    smallFont = smallFont or Theme.font("ui", Theme.scale.ui)
    boldFont = boldFont or Theme.font("uiSemiBold", Theme.scale.body)
    defaultFont = defaultFont or Theme.font("mono", Theme.scale.micro)

    bgShader = bgShader or ShellStyle.loadShader("OptionsState")

    print("[OptionsState] Entered Settings screen")
end

function OptionsState:update(dt)
    timer = timer + dt
    ShellStyle.updateMusic(dt)

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
    local margin = screenHeight * 0.1

    tabRects = {}
    settingRects = {}

    ShellStyle.drawBackground(alpha, bgShader)
    ShellStyle.drawRgbTitle("SETTINGS", margin, margin, titleFont, alpha)

    -- Nav rail (same bar-column formula as all other shell states)
    local barWidth = 56
    local barGap = 4
    local startX = 2
    local barStep = barWidth + barGap
    local bracketHeight = 44
    local gap = 16
    local totalMenuHeight = #tabs * bracketHeight + (#tabs - 1) * gap
    local stackStartY = screenHeight - margin - totalMenuHeight

    local chromaticW = ShellStyle.measureSpacedText("CHROMATIC", titleFont, 10)
    local logoCenterX = margin + chromaticW / 2
    local centerCol = math.floor((logoCenterX - startX) / barStep) + 1
    local colStart = centerCol - 2
    if colStart < 1 then colStart = 1 end
    if colStart + 4 > 32 then colStart = 28 end

    local btnX = startX + (colStart - 1) * barStep
    local btnW = 5 * barWidth + 4 * barGap

    tabRects = ShellStyle.layoutVerticalRail(tabs, btnX, stackStartY, {buttonW = btnW, buttonH = bracketHeight, gap = gap})
    ShellStyle.drawVerticalRail(tabs, tabRects, activeTab, alpha, smallFont)

    -- Right panel
    local rightX = btnX + btnW + 120
    local rightW = screenWidth - rightX - margin
    local rightY = 320
    local rightH = screenHeight - rightY - margin

    ShellStyle.drawPanel(rightX, rightY, rightW, rightH, alpha, Theme.color.accent)

    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(0.85, 0.85, 0.9, alpha)
    love.graphics.print(tabs[activeTab].label .. " PARAMETERS", rightX + 40, rightY + 40)

    love.graphics.setColor(0, 0.85, 1, alpha * 0.15)
    love.graphics.setLineWidth(2)
    love.graphics.line(rightX + 40, rightY + 90, rightX + rightW - 40, rightY + 90)

    -- Panel content
    local action = tabs[activeTab].action
    local currentList = getCurrentSettingsList()
    local time = love.timer.getTime()

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

            if isSelected then
                love.graphics.setColor(0, 0.85, 1, alpha * 0.08)
                love.graphics.rectangle("fill", rightX + 30, itemY - 10, rightW - 60, 44, 6, 6)
                love.graphics.setColor(0, 0.85, 1, alpha * 0.4)
                love.graphics.rectangle("line", rightX + 30, itemY - 10, rightW - 60, 44, 6, 6)
            end

            love.graphics.setFont(smallFont)
            love.graphics.setColor(isSelected and {1, 1, 1, alpha} or {0.65, 0.7, 0.8, alpha * 0.7})
            love.graphics.print(item.label, rightX + 60, itemY + 2)

            local valX = rightX + 360
            local val = item.get()

            if item.type == "toggle" then
                local toggleText = val and "ENABLED" or "DISABLED"
                love.graphics.setFont(smallFont)
                love.graphics.setColor(0, 0, 0, alpha * 0.5)
                love.graphics.rectangle("fill", valX, itemY - 4, 120, 26, 4, 4)
                love.graphics.setLineWidth(1)
                local ledColor = val and {0, 1, 0.5} or {1, 0.1, 0.4}
                love.graphics.setColor(ledColor[1], ledColor[2], ledColor[3], alpha * 0.6)
                love.graphics.rectangle("line", valX, itemY - 4, 120, 26, 4, 4)
                love.graphics.setColor(ledColor[1], ledColor[2], ledColor[3], alpha)
                love.graphics.circle("fill", valX + 20, itemY + 9, 5)
                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.print(toggleText, valX + 38, itemY)

            elseif item.type == "slider" then
                local r = 0.5 + 0.5 * math.sin(time * 3)
                local g = 0.5 + 0.5 * math.sin(time * 3 + 2.09)
                local b = 0.5 + 0.5 * math.sin(time * 3 + 4.18)
                love.graphics.setColor(0.1, 0.1, 0.15, alpha)
                love.graphics.rectangle("fill", valX, itemY + 6, 200, 10, 5, 5)
                love.graphics.setColor(r, g, b, alpha)
                love.graphics.rectangle("fill", valX, itemY + 6, 200 * val, 10, 5, 5)
                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.circle("fill", valX + 200 * val, itemY + 11, 8)
                love.graphics.print(string.format("%.0f%%", val * 100), valX + 220, itemY)
            end
        end

        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.5, 0.5, 0.6, alpha * 0.6)
        if focusOnRight then
            love.graphics.print("UP / DOWN select   |   LEFT / RIGHT / ENTER adjust   |   ESC categories", rightX + 60, rightY + rightH - 50)
        else
            love.graphics.print("RIGHT / ENTER to edit these settings", rightX + 60, rightY + rightH - 50)
        end

    elseif action == "controls" then
        local bindY = rightY + 130
        local bindH = 50
        local bindings = {
            {action = "MOVE",                      keys = {"W", "A", "S", "D"},   extra = "Directional movement"},
            {action = "AIM SHIP / SHOOT",           keys = {"MOUSE CURSOR"},        extra = "Shoots automatically"},
            {action = "DASH BOOST",                 keys = {"SPACE"},               extra = "1.5s cooldown"},
            {action = "BLINK TELEPORT / SHIELD",    keys = {"E", "Q"},              extra = "Blink 5.0s | Shield 10.0s"},
            {action = "SUPERNOVA ARTIFACT",         keys = {"PASSIVE"},             extra = "Reactive nova chance when hit"},
            {action = "PAUSE MENU",                 keys = {"P", "ESC"},            extra = "Freezes gameplay"},
        }

        for i, bind in ipairs(bindings) do
            local itemY = bindY + (i - 1) * bindH
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0.7, 0.75, 0.85, alpha * 0.85)
            love.graphics.print(bind.action, rightX + 60, itemY)

            local keyXStart = rightX + 380
            for _, keyName in ipairs(bind.keys) do
                local textW = smallFont:getWidth(keyName)
                local blockW = math.max(34, textW + 20)
                love.graphics.setColor(0.08, 0.08, 0.12, alpha)
                love.graphics.rectangle("fill", keyXStart, itemY - 4, blockW, 26, 5, 5)
                love.graphics.setLineWidth(1)
                love.graphics.setColor(0, 0.85, 1, alpha * 0.4)
                love.graphics.rectangle("line", keyXStart, itemY - 4, blockW, 26, 5, 5)
                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.print(keyName, keyXStart + (blockW / 2 - textW / 2), itemY - 2)
                keyXStart = keyXStart + blockW + 10
            end

            love.graphics.setColor(0.45, 0.5, 0.65, alpha * 0.6)
            love.graphics.print(bind.extra, keyXStart + 10, itemY)
        end

        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.5, 0.5, 0.6, alpha * 0.6)
        love.graphics.print("Keyboard & Mouse controls are active automatically", rightX + 60, rightY + rightH - 50)

    elseif action == "general" then
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.4, 0.45, 0.55, alpha * 0.7)
        love.graphics.print("GENERAL SETTINGS - COMING SOON", rightX + 60, rightY + 130)
        love.graphics.setColor(0.5, 0.5, 0.6, alpha * 0.4)
        love.graphics.print("This section will be available in a future update.", rightX + 60, rightY + 165)
    end

    ShellStyle.drawFooter("UP / DOWN select   |   ENTER / RIGHT adjust   |   ESC back", screenHeight - 82, alpha)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
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
