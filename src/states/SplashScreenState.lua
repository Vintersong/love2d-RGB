-- SplashScreen.lua
-- Initial splash screen that displays game title and fades to PlayingState

local SplashScreen = {}

-- Animation state
local alpha = 0
local fadeInDuration = 1.0
local displayDuration = 2.0
local fadeOutDuration = 0.8
local timer = 0
local phase = "fadeIn" -- fadeIn -> display -> fadeOut -> switch

-- Menu state
local showMenu = false
local menuOptions = {
    {label = "[SPACE] Start Game", action = "startGame"},
    {label = "[U] UI Sandbox", action = "uiSandbox"},
    {label = "[ESC] Quit", action = "quit"}
}
local selectedMenuOption = 1

-- Text settings
local titleText = "L O V E 2 D - R G B"
local subtitleText = "Press SPACE to Start or U for UI Sandbox"
local titleSize = 72
local subtitleSize = 24

-- Fonts (created once)
local titleFont = nil
local subtitleFont = nil

function SplashScreen:enter(previous, data)
    -- Reset animation state
    alpha = 0
    timer = 0
    phase = "fadeIn"
    showMenu = false
    selectedMenuOption = 1

    -- Create fonts once on enter
    if not titleFont then
        titleFont = love.graphics.newFont(titleSize)
    end
    if not subtitleFont then
        subtitleFont = love.graphics.newFont(subtitleSize)
    end

    print("[SplashScreen] Entered splash screen")
    print("[SplashScreen] Press SPACE to start or U for UI Sandbox")
end

function SplashScreen:update(dt)
    timer = timer + dt

    if phase == "fadeIn" then
        -- Fade in from black
        alpha = math.min(1, timer / fadeInDuration)

        if timer >= fadeInDuration then
            phase = "display"
            timer = 0
            showMenu = true  -- Show menu after fade in
        end
    elseif phase == "display" then
        -- Hold at full opacity
        alpha = 1
    elseif phase == "fadeOut" then
        -- Fade out to black
        alpha = math.max(0, 1 - (timer / fadeOutDuration))

        if timer >= fadeOutDuration then
            -- Reset font to default before switching
            love.graphics.setFont(love.graphics.newFont(12))
            timer = 0
        end
    end
end

function SplashScreen:draw()
    -- Clear to black
    love.graphics.clear(0, 0, 0, 1)

    -- Draw title (centered)
    love.graphics.setFont(titleFont)
    local titleWidth = titleFont:getWidth(titleText)
    local titleX = (1920 - titleWidth) / 2
    local titleY = 350

    -- Draw title with RGB gradient effect
    local time = love.timer.getTime()
    local r = 0.5 + 0.5 * math.sin(time * 2)
    local g = 0.5 + 0.5 * math.sin(time * 2 + 2.09)
    local b = 0.5 + 0.5 * math.sin(time * 2 + 4.18)
    love.graphics.setColor(r, g, b, alpha)
    love.graphics.print(titleText, titleX, titleY)

    -- Draw menu if visible
    if showMenu then
        love.graphics.setFont(subtitleFont)
        
        local menuStartX = 1920 / 2 - 150
        local menuStartY = 550
        local lineHeight = 50
        
        for i, option in ipairs(menuOptions) do
            local y = menuStartY + (i - 1) * lineHeight
            
            -- Highlight selected option
            if i == selectedMenuOption then
                love.graphics.setColor(1, 1, 0, alpha)  -- Yellow
            else
                love.graphics.setColor(0.7, 0.7, 0.7, alpha)  -- Gray
            end
            
            love.graphics.print(option.label, menuStartX, y)
        end
    else
        -- Show subtitle during fade in
        love.graphics.setFont(subtitleFont)
        local subtitleWidth = subtitleFont:getWidth(subtitleText)
        local subtitleX = (1920 - subtitleWidth) / 2
        local subtitleY = titleY + 150

        love.graphics.setColor(1, 1, 1, alpha * 0.5)
        love.graphics.print(subtitleText, subtitleX, subtitleY)
    end

    -- Reset color and font
    love.graphics.setColor(1, 1, 1, 1)
end

function SplashScreen:keypressed(key)
    if phase == "display" and showMenu then
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
            elseif action == "quit" then
                love.event.quit()
            end
            return
        elseif key == "u" then
            self:enterUISandbox()
            return
        elseif key == "escape" then
            love.event.quit()
            return
        end
    else
        -- Skip to game on space during fade
        if key == "space" or key == "return" then
            self:startGame()
        elseif key == "u" then
            self:enterUISandbox()
        elseif key == "escape" then
            love.event.quit()
        end
    end
end

function SplashScreen:startGame()
    phase = "fadeOut"
    timer = 0
    
    -- After fade out, switch to game
    local fadeOutTimer = 0
    local fadeOutDuration = 0.8
    
    -- Use a simple approach: schedule the switch for after fade
    love.timer.sleep(fadeOutDuration)
    
    -- Reset font to default before switching
    love.graphics.setFont(love.graphics.newFont(12))

    -- Initialize PlayingState before switching
    local Player = require("src.entities.Player")
    local Weapon = require("src.Weapon")
    local PlayingState = require("src.states.PlayingState")
    local GameConfig = require("src.systems.GameConfig")

    PlayingState.player = Player(512, 360, Weapon())
    PlayingState.enemies = {}
    PlayingState.xpOrbs = {}
    PlayingState.powerups = {}
    PlayingState.explosions = {}
    PlayingState.bossProjectiles = {}
    PlayingState.gameTime = 0
    PlayingState.enemyKillCount = 0
    PlayingState.musicReactor = GameConfig.getMusicReactor()
    PlayingState.screenWidth, PlayingState.screenHeight = GameConfig.getScreenSize()

    -- Switch to PlayingState
    local Gamestate = require("libs.hump-master.gamestate")
    Gamestate.switch(PlayingState)
end

function SplashScreen:enterUISandbox()
    -- Reset font and switch immediately to UI Sandbox
    love.graphics.setFont(love.graphics.newFont(12))
    
    local Gamestate = require("libs.hump-master.gamestate")
    local UISandboxState = require("src.states.UISandboxState")
    
    Gamestate.switch(UISandboxState)
end

return SplashScreen