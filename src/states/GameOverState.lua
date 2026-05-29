-- GameOverState.lua
-- Game over screen when player dies

local GameOverState = {}
local Config = require("src.Config")
local Runtime = require("src.core.Runtime")
local GameConfig = require("src.core.GameConfig")

GameOverState.player = nil
GameOverState.enemies = {}
GameOverState.musicReactor = nil

function GameOverState:enter(previous, data)
    GameConfig.setActiveRun(false)
    if data then
        self.player = data.player
        self.enemies = data.enemies or {}
        self.musicReactor = data.musicReactor
    end
end

function GameOverState:update(dt)
    -- Keep background systems running
    local World = require("src.gameplay.World")
    if self.musicReactor then
        self.musicReactor:update(dt)
    end
    World.update(dt, self.musicReactor)
end

function GameOverState:draw()
    local World = require("src.gameplay.World")
    World.draw()

    -- Draw frozen game state
    self.player:draw()

    for _, enemy in ipairs(self.enemies) do
        enemy:draw(self.musicReactor)
    end

    -- Draw game over overlay
    self:drawGameOverScreen()
end

function GameOverState:drawGameOverScreen()
    local screenWidth = Config.screen.width
    local screenHeight = Config.screen.height

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local centerX = screenWidth / 2
    local startY = 250

    -- Title
    love.graphics.setColor(1, 0, 0)
    love.graphics.print("💀 GAME OVER 💀", centerX - 300, startY, 0, 5, 5)

    local y = startY + 150

    -- Boss message
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("The Final Boss has defeated you!", centerX - 280, y, 0, 2, 2)
    y = y + 80

    -- Level reached
    love.graphics.print(string.format("You reached Level %d", self.player.level), centerX - 180, y, 0, 1.8, 1.8)
    y = y + 80

    -- Congratulations message
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("Congratulations on making it this far!", centerX - 280, y, 0, 1.5, 1.5)
    y = y + 120

    -- Options
    love.graphics.setColor(0.2, 1, 0.2)
    love.graphics.print("Press C to Continue (Endless Mode)", centerX - 280, y, 0, 1.5, 1.5)
    y = y + 60

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Press R to Restart | ESC to " .. Runtime.exitActionText(), centerX - 220, y, 0, 1.5, 1.5)
end

function GameOverState:keypressed(key)
    local StateManager = require("src.core.StateManager")

    if key == "escape" then
        Runtime.quitOrReturnToTitle()
    elseif key == "c" then
        local CollisionSystem = require("src.combat.CollisionSystem")
        local Config = require("src.Config")
        CollisionSystem.init(Config.gameplay.cellSize)

        -- Continue in endless mode (heal player, keep level/upgrades)
        self.player.hp = self.player.maxHp
        self.player.invulnerable = false
        self.player.invulnerableTime = 0

        -- Clear enemies and powerups
        local PlayingState = require("src.states.PlayingState")
        local BossSystem = require("src.boss.BossSystem")
        BossSystem.reset()

        PlayingState.player = self.player
        PlayingState.enemies = {}
        PlayingState.xpOrbs = {}
        PlayingState.powerups = {}
        PlayingState.explosions = {}
        PlayingState.bossProjectiles = {}
        PlayingState.musicReactor = self.musicReactor

        print("[ENDLESS MODE] Continuing from level " .. self.player.level)
        StateManager.switch("Playing")
    elseif key == "r" then
        -- Restart game
        self:restartGame()
        StateManager.switch("Playing")
    end
end

function GameOverState:restartGame()
    local PlayingState = require("src.states.PlayingState")
    PlayingState.startNewRun()
    self.player = PlayingState.player
end

return GameOverState
