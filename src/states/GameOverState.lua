-- GameOverState.lua
-- Game over screen when player dies

local GameOverState = {}

GameOverState.player = nil
GameOverState.enemies = {}
GameOverState.musicReactor = nil

function GameOverState:enter(previous, data)
    if data then
        self.player = data.player
        self.enemies = data.enemies or {}
        self.musicReactor = data.musicReactor
    end
end

function GameOverState:update(dt)
    -- Keep background systems running
    local World = require("src.systems.World")
    if self.musicReactor then
        self.musicReactor:update(dt)
    end
    World.update(dt, self.musicReactor)
end

function GameOverState:draw()
    local World = require("src.systems.World")
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
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, 1920, 1080)

    local centerX = 1920 / 2
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
    love.graphics.print("Press R to Restart | ESC to Exit", centerX - 220, y, 0, 1.5, 1.5)
end

function GameOverState:keypressed(key)
    local Gamestate = require("libs.hump-master.gamestate")

    if key == "escape" then
        love.event.quit()
    elseif key == "c" then
        -- Continue in endless mode (heal player, keep level/upgrades)
        self.player.hp = self.player.maxHp
        self.player.invulnerable = false
        self.player.invulnerableTimer = 0

        -- Clear enemies and powerups
        local PlayingState = require("src.states.PlayingState")
        PlayingState.player = self.player
        PlayingState.enemies = {}
        PlayingState.xpOrbs = {}
        PlayingState.powerups = {}
        PlayingState.explosions = {}
        PlayingState.bossProjectiles = {}
        PlayingState.musicReactor = self.musicReactor

        print("[ENDLESS MODE] Continuing from level " .. self.player.level)
        Gamestate.switch(PlayingState)
    elseif key == "r" then
        -- Restart game
        self:restartGame()
        local PlayingState = require("src.states.PlayingState")
        Gamestate.switch(PlayingState)
    end
end

function GameOverState:restartGame()
    local Player = require("src.entities.Player")
    local Weapon = require("src.Weapon")
    local ColorSystem = require("src.systems.ColorSystem")
    local SynergySystem = require("src.systems.SynergySystem")
    local ArtifactManager = require("src.systems.ArtifactManager")
    local PlayingState = require("src.states.PlayingState")

    -- Reset all systems
    ColorSystem.init()
    SynergySystem.reset()
    ArtifactManager.reset()

    -- Create new player
    PlayingState.player = Player(512, 360, Weapon())
    PlayingState.enemies = {}
    PlayingState.xpOrbs = {}
    PlayingState.powerups = {}
    PlayingState.explosions = {}
    PlayingState.bossProjectiles = {}
    PlayingState.gameTime = 0
    PlayingState.enemyKillCount = 0
end

return GameOverState
