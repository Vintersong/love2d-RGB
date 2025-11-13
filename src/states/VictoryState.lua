-- VictoryState.lua
-- Victory screen when player completes the game

local VictoryState = {}

VictoryState.player = nil
VictoryState.enemies = {}
VictoryState.xpOrbs = {}
VictoryState.musicReactor = nil

function VictoryState:enter(previous, data)
    if data then
        self.player = data.player
        self.enemies = data.enemies or {}
        self.xpOrbs = data.xpOrbs or {}
        self.musicReactor = data.musicReactor
    end
end

function VictoryState:update(dt)
    -- Keep background systems running
    local World = require("src.systems.World")
    if self.musicReactor then
        self.musicReactor:update(dt)
    end
    World.update(dt, self.musicReactor)
end

function VictoryState:draw()
    local World = require("src.systems.World")
    World.draw()

    -- Draw frozen game state
    self.player:draw()

    for _, enemy in ipairs(self.enemies) do
        enemy:draw(self.musicReactor)
    end

    for _, orb in ipairs(self.xpOrbs) do
        orb:draw()
    end

    -- Draw victory overlay
    self:drawVictoryScreen()
end

function VictoryState:drawVictoryScreen()
    local ColorSystem = require("src.systems.ColorSystem")

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, 1920, 1080)

    local centerX = 1920 / 2
    local startY = 200

    -- Title
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("🎉 VICTORY! 🎉", centerX - 220, startY, 0, 4, 4)

    local y = startY + 120

    -- Level reached
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("You reached Level %d!", self.player.level), centerX - 180, y, 0, 2, 2)
    y = y + 80

    -- Final build name
    local ColorTree = require("src.data.ColorTree")
    local pathDesc = ColorTree.getPathDescription(ColorSystem.colorHistory or {})
    love.graphics.setColor(0, 0.94, 1)
    love.graphics.print("Final Build:", centerX - 120, y, 0, 1.5, 1.5)
    love.graphics.print(pathDesc, centerX - 120, y + 40, 0, 1.5, 1.5)
    y = y + 100

    -- Color path
    local history = ColorSystem.colorHistory or {}
    if #history > 0 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Color Path:", centerX - 120, y, 0, 1.5, 1.5)

        local pathStr = table.concat(history, " → ")
        love.graphics.print(pathStr:upper(), centerX - 120, y + 40, 0, 1.5, 1.5)
        y = y + 90
    end

    -- Stats
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Final Stats:", centerX - 120, y, 0, 1.5, 1.5)
    y = y + 45

    love.graphics.setColor(1, 0.8, 0.8)
    love.graphics.print(string.format("Damage: %.0f", self.player.weapon.damage), centerX - 90, y, 0, 1.3, 1.3)
    y = y + 38

    love.graphics.setColor(0.8, 1, 0.8)
    love.graphics.print(string.format("Fire Rate: %.2fs", self.player.weapon.fireRate), centerX - 90, y, 0, 1.3, 1.3)
    y = y + 25

    love.graphics.setColor(0.8, 0.8, 1)
    love.graphics.print(string.format("Bullets: %d", self.player.weapon.bulletCount or 1), centerX - 60, y)
    y = y + 25

    local pierce = self.player.weapon.pierce or 0
    love.graphics.print(string.format("Pierce: %d", pierce), centerX - 60, y)
    y = y + 50

    -- Controls
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("[SPACE] Restart    [ESC] Quit", centerX - 120, y, 0, 1.2, 1.2)
end

function VictoryState:keypressed(key)
    local Gamestate = require("libs.hump-master.gamestate")

    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        -- Restart game
        self:restartGame()
        local PlayingState = require("src.states.PlayingState")
        Gamestate.switch(PlayingState)
    end
end

function VictoryState:restartGame()
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

return VictoryState
