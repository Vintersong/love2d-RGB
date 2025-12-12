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

-- Text settings
local titleText = "L O V E 2 D - R G B"
local subtitleText = "Press SPACE to Start"
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

    -- Create fonts once on enter
    if not titleFont then
        titleFont = love.graphics.newFont(titleSize)
    end
    if not subtitleFont then
        subtitleFont = love.graphics.newFont(subtitleSize)
    end

    print("[SplashScreen] Entered splash screen")
end

function SplashScreen:update(dt)
    timer = timer + dt

    if phase == "fadeIn" then
        -- Fade in from black
        alpha = math.min(1, timer / fadeInDuration)

        if timer >= fadeInDuration then
            phase = "display"
            timer = 0
        end
    elseif phase == "display" then
        -- Hold at full opacity
        alpha = 1

        -- Auto-advance after displayDuration or on spacebar
        if timer >= displayDuration or love.keyboard.isDown("space") then
            phase = "fadeOut"
            timer = 0
        end
    elseif phase == "fadeOut" then
        -- Fade out to black
        alpha = math.max(0, 1 - (timer / fadeOutDuration))

        if timer >= fadeOutDuration then
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
    end
end

function SplashScreen:draw()
    -- Clear to black
    love.graphics.clear(0, 0, 0, 1)

    -- Draw title (centered)
    love.graphics.setFont(titleFont)
    local titleWidth = titleFont:getWidth(titleText)
    local titleX = (1920 - titleWidth) / 2
    local titleY = 400

    -- Draw title with RGB gradient effect
    local time = love.timer.getTime()
    local r = 0.5 + 0.5 * math.sin(time * 2)
    local g = 0.5 + 0.5 * math.sin(time * 2 + 2.09)
    local b = 0.5 + 0.5 * math.sin(time * 2 + 4.18)
    love.graphics.setColor(r, g, b, alpha)
    love.graphics.print(titleText, titleX, titleY)

    -- Draw subtitle (centered, below title)
    if phase == "display" and math.floor(time * 2) % 2 == 0 then
        love.graphics.setFont(subtitleFont)
        local subtitleWidth = subtitleFont:getWidth(subtitleText)
        local subtitleX = (1920 - subtitleWidth) / 2
        local subtitleY = titleY + 100

        love.graphics.setColor(1, 1, 1, alpha * 0.7)
        love.graphics.print(subtitleText, subtitleX, subtitleY)
    end

    -- Reset color and font
    love.graphics.setColor(1, 1, 1, 1)
end

function SplashScreen:keypressed(key)
    -- Skip to game on any key
    if key == "space" or key == "return" or key == "escape" then
        phase = "fadeOut"
        timer = 0
    end
end

return SplashScreen