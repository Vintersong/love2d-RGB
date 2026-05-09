local AttackSystem = require("attack")
local ShieldEffect = require("shield")
local LightningEffect = require("lightningEffect")
local ShipRenderer = require("shipDesign")
local InputBindings = require("inputBindings")
local DebugHUD = require("debugHud")
local Timer = require("systems.core.timer")
local PlayerStats = require("components.player.playerStats")
local WeaponManager = require("components.player.weaponManager")
local EnemyManager = require("components.enemies.enemyManager")
local GameHUD = require("components.ui.hud")
local XPManager = require("systems.combat.xpManager")
local ColorSystem = require("colorSystem")
local PlayerAbilities = require("playerAbilities")
local Resolution = require("systems.core.resolution")
local Starfield = require("components.environment.starfield")
local Background = require("components.environment.background")
local moonshine = require("libs.moonshine")
local unpackTable = table.unpack or unpack

local function buildPostFx()
    local fx = moonshine(moonshine.effects.glow)
        .chain(moonshine.effects.chromasep)
    fx.glow.strength = 6
    fx.glow.min_luma = 0.35
    fx.chromasep.radius = 1.5
    return fx
end

local GameRuntime = {}
GameRuntime.__index = GameRuntime

function GameRuntime:new()
    local self = setmetatable({}, GameRuntime)
    self.attack = AttackSystem:new()
    self.shield = ShieldEffect:new()
    self.lightning = LightningEffect:new({duration = 0.22})
    self.ship = ShipRenderer:new({scale = 0.45})
    self.debugHud = DebugHUD:new()
    self.playerStats = PlayerStats:new()
    self.weaponManager = WeaponManager:new()
    self.colorSystem = ColorSystem:new()
    self.abilities = PlayerAbilities:new()
    self.enemyManager = EnemyManager:new()
    self.xpManager = XPManager:new({maxXP = self.playerStats.xpToNextLevel})
    self.enemyAttack = AttackSystem:new()
    self.resolution = Resolution
    self.starfield = Starfield:new()
    self.background = Background:new()
    self.postFx = buildPostFx()
    self.hud = GameHUD:new({
        playerStats = self.playerStats,
        weaponManager = self.weaponManager,
        colorSystem = self.colorSystem,
        abilities = self.abilities,
        enemyManager = self.enemyManager,
    })
    self.player = {x = 0, y = 0, radius = 18, moveX = 0, moveY = -1}
    self.backgroundColor = {0.04, 0.05, 0.09, 1.0}
    self.showDebugOverlay = true
    self.state = "playing"
    self.autoFireCooldown = 0
    self.baseMoveSpeed = 290

    self.xpManager:setLevelUpCallback(function(level)
        self.playerStats.level = level
        self.playerStats.xpToNextLevel = self.playerStats:calculateXpForLevel(level)
        self.playerStats.maxHealth = self.playerStats.maxHealth + 10
        self.playerStats.health = self.playerStats.maxHealth
        self.playerStats.maxEnergy = self.playerStats.maxEnergy + 5
        self.playerStats.energy = self.playerStats.maxEnergy
        self.xpManager.maxXP = self.playerStats.xpToNextLevel
        self.hud:spawnCards()
    end)

    self.input = InputBindings:new({
        onFire = function(abilityId, player, target, params)
            local didFire = false
            if type(abilityId) == "number" and abilityId >= 1 and abilityId <= 12 then
                self.attack:fire(abilityId, player, target, params or {})
                didFire = true
            else
                didFire = self.weaponManager:fire(player, target, self.attack)
            end
            if didFire then
                self.shield:trigger(player.x, player.y)
            end
        end,
        onAltFire = function(player, target)
            self.lightning:trigger(player.x, player.y, target.x, target.y)
        end,
        onWeaponCycle = function(direction)
            self.weaponManager:cycle(direction)
        end,
        onToggleCards = function()
            if self.hud.showCards then
                self.hud:closeCards()
            else
                self.hud:spawnCards()
            end
        end,
        onSpace = function()
            local w = love.graphics.getWidth()
            local h = love.graphics.getHeight()
            local startX = math.random(math.floor(w * 0.2), math.floor(w * 0.8))
            local endX = math.random(math.floor(w * 0.2), math.floor(w * 0.8))
            self.lightning:trigger(startX, 0, endX, h)
        end,
    })
    return self
end

function GameRuntime:load()
    math.randomseed(os.time())
    Timer.clear()
    self.player.x = love.graphics.getWidth() * 0.5
    self.player.y = love.graphics.getHeight() * 0.82
    self.attack:load()
    self.enemyAttack:load()
    self.hud:spawnCards()
    local function scheduleAmbientLightning()
        Timer.after(6, function()
            local w = love.graphics.getWidth()
            local h = love.graphics.getHeight()
            local sx = math.random(math.floor(w * 0.15), math.floor(w * 0.85))
            local ex = math.random(math.floor(w * 0.15), math.floor(w * 0.85))
            self.lightning:trigger(sx, 0, ex, h, {numSegments = 18, maxDisplacement = w / 16})
            scheduleAmbientLightning()
        end)
    end
    scheduleAmbientLightning()
end

function GameRuntime:reset()
    self.attack = AttackSystem:new()
    self.shield = ShieldEffect:new()
    self.lightning = LightningEffect:new({duration = 0.22})
    self.debugHud = DebugHUD:new()
    self.playerStats = PlayerStats:new()
    self.weaponManager = WeaponManager:new()
    self.colorSystem = ColorSystem:new()
    self.abilities = PlayerAbilities:new()
    self.enemyManager = EnemyManager:new()
    self.xpManager = XPManager:new({maxXP = self.playerStats.xpToNextLevel})
    self.enemyAttack = AttackSystem:new()
    self.resolution = Resolution
    self.starfield = Starfield:new()
    self.background = Background:new()
    self.postFx = self.postFx or buildPostFx()
    self.hud = GameHUD:new({
        playerStats = self.playerStats,
        weaponManager = self.weaponManager,
        colorSystem = self.colorSystem,
        abilities = self.abilities,
        enemyManager = self.enemyManager,
    })
    self.player = {
        x = love.graphics.getWidth() * 0.5,
        y = love.graphics.getHeight() * 0.82,
        radius = 18,
        moveX = 0,
        moveY = -1,
    }
    self.state = "playing"
    self.autoFireCooldown = 0
    self:load()
end

function GameRuntime:updatePlayer(dt)
    local dx = 0
    local dy = 0
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
        dx = dx - 1
    end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
        dx = dx + 1
    end
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
        dy = dy - 1
    end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
        dy = dy + 1
    end

    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0 then
        dx = dx / length
        dy = dy / length
        self.player.moveX = dx
        self.player.moveY = dy
    end

    local speed = self.baseMoveSpeed * self.abilities:getMoveMultiplier()
    self.player.x = math.max(28, math.min(love.graphics.getWidth() - 28, self.player.x + dx * speed * dt))
    self.player.y = math.max(28, math.min(love.graphics.getHeight() - 28, self.player.y + dy * speed * dt))
end

function GameRuntime:updateAutoFire(dt)
    self.autoFireCooldown = math.max(0, self.autoFireCooldown - dt)
    if self.autoFireCooldown > 0 then
        return
    end

    local target = self.enemyManager:getNearestEnemy(self.player.x, self.player.y)
    if not target then
        return
    end

    local stats = self.colorSystem:getProjectileStats()
    self.attack:fireColorVolley(self.player, target, stats)
    self.autoFireCooldown = stats.fireRate
end

function GameRuntime:update(dt)
    Timer.update(dt)
    self.background:update(dt)
    if self.state ~= "playing" then
        self.lightning:update(dt)
        return
    end

    self.abilities:update(dt)
    if self.abilities:isShielded() then
        self.shield.cx = self.player.x
        self.shield.cy = self.player.y
    else
        self.shield:despawn()
    end
    self.shield:update(dt)
    self.lightning:update(dt)

    if self.hud.showCards then
        return
    end

    self:updatePlayer(dt)
    self:updateAutoFire(dt)
    self.attack.debugDrawColliders = self.input.debugDrawColliders
    self.weaponManager:update(dt)
    self.attack:update(dt)
    self.enemyManager:update(dt, self.attack.projectiles, self.playerStats, self.xpManager, self.player, self.abilities, self.enemyAttack)
    self.enemyAttack:update(dt)
    
    -- Player collision with enemy projectiles
    for _, projectile in ipairs(self.enemyAttack.projectiles) do
        if not projectile.dead then
            local dx = self.player.x - projectile.x
            local dy = self.player.y - projectile.y
            local distSq = dx * dx + dy * dy
            local minDist = self.player.radius + projectile.radius
            if distSq < minDist * minDist then
                if not (self.abilities and self.abilities:isShielded()) then
                    self.playerStats:takeDamage(projectile.damage or 10)
                end
                projectile.dead = true
            end
        end
    end

    self.playerStats.xp = math.floor(self.xpManager.currentXP)
    self.playerStats.level = self.xpManager.currentLevel

    if self.playerStats.health <= 0 then
        self.state = "gameover"
        love.mouse.setVisible(true)
    elseif self.enemyManager.bossDefeated then
        self.state = "victory"
        love.mouse.setVisible(true)
    end
end

function GameRuntime:drawPlayer()
    if self.ship.shipMainCanvas then
        local scale = self.ship.scale
        local cw = self.ship.shipMainCanvas:getWidth()
        local ch = self.ship.shipMainCanvas:getHeight()
        local shipX = (self.player.x / scale) - (cw * 0.5)
        local shipY = (self.player.y / scale) - (ch * 0.5)
        self.ship:draw(shipX, shipY, scale)
    end

    local dominant = self.colorSystem:getDominantColor()
    love.graphics.setColor(dominant.color[1], dominant.color[2], dominant.color[3], 0.95)
    love.graphics.circle("line", self.player.x, self.player.y, self.player.radius + 5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self.player.x, self.player.y, 3)
end

function GameRuntime:drawEndOverlay()
    if self.state == "playing" then
        return
    end

    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)
    local title = self.state == "victory" and "VICTORY" or "GAME OVER"
    local subtitle = self.state == "victory" and "First boss defeated" or "The spectrum collapsed"
    love.graphics.printf(title, 0, love.graphics.getHeight() * 0.38, love.graphics.getWidth(), "center")
    love.graphics.printf(subtitle, 0, love.graphics.getHeight() * 0.45, love.graphics.getWidth(), "center")
    love.graphics.printf("Press R to restart", 0, love.graphics.getHeight() * 0.52, love.graphics.getWidth(), "center")
end

function GameRuntime:draw()
    love.graphics.clear(unpackTable(self.backgroundColor))
    self.background:draw()

    self.postFx(function()
        self:drawPlayer()
        self.attack:draw()
        self.enemyManager:draw()
        self.abilities:draw()
        self.shield:draw()
        self.lightning:draw()
        self.enemyAttack:draw()
    end)

    self.hud:draw()
    if self.showDebugOverlay then
        self.debugHud:draw(self)
    end
    self:drawEndOverlay()
end

function GameRuntime:keypressed(key)
    if self.state ~= "playing" then
        if key == "r" then
            self:reset()
        end
        return
    end

    if key == "f1" then
        self.showDebugOverlay = not self.showDebugOverlay
        return
    end
    if key == "f2" then
        self.xpManager:addXP(self.xpManager.maxXP)
        return
    end
    if key == "f5" then
        self.playerStats.health = self.playerStats.maxHealth
        return
    end
    if key == "f10" then
        self.enemyManager:spawnBoss()
        return
    end
    if key == "escape" and self.hud.showCards then
        self.hud:closeCards()
        return
    end
    if key == "space" and not self.hud.showCards then
        self.abilities:dash(self.player, self.colorSystem, self.enemyManager, self.playerStats)
        return
    end
    if key == "e" and not self.hud.showCards then
        self.abilities:blink(self.player)
        return
    end
    if key == "q" and not self.hud.showCards then
        self.abilities:shield(self.shield, self.player)
        return
    end
    self.input:keypressed(key)
end

function GameRuntime:mousepressed(x, y, button)
    if self.state ~= "playing" then
        return
    end
    if self.hud:mousepressed(x, y, button) then
        return
    end
    self.input:mousepressed(x, y, button, self.player)
end

return GameRuntime
