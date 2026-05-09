local collision = require("systems.core.collision")
local mathUtils = require("systems.core.mathUtils")

local PlayerAbilities = {}
PlayerAbilities.__index = PlayerAbilities

local normalize = mathUtils.normalize
local clamp = mathUtils.clamp

function PlayerAbilities:new(config)
    local self = setmetatable({}, PlayerAbilities)
    self.config = config or {}
    self.cooldowns = {
        dash = 0,
        blink = 0,
        shield = 0,
    }
    self.maxCooldowns = {
        dash = 1.5,
        blink = 5.0,
        shield = 10.0,
    }
    self.shieldTimer = 0
    self.speedBoostTimer = 0
    self.speedBoostMultiplier = 1
    self.dashTrail = {}
    return self
end

function PlayerAbilities:update(dt)
    for key, value in pairs(self.cooldowns) do
        self.cooldowns[key] = math.max(0, value - dt)
    end

    self.shieldTimer = math.max(0, self.shieldTimer - dt)
    self.speedBoostTimer = math.max(0, self.speedBoostTimer - dt)
    if self.speedBoostTimer <= 0 then
        self.speedBoostMultiplier = 1
    end

    for i = #self.dashTrail, 1, -1 do
        local node = self.dashTrail[i]
        node.life = node.life - dt
        if node.life <= 0 then
            table.remove(self.dashTrail, i)
        end
    end
end

function PlayerAbilities:getMoveMultiplier()
    return self.speedBoostMultiplier
end

function PlayerAbilities:isShielded()
    return self.shieldTimer > 0
end

function PlayerAbilities:getCooldownRatio(id)
    return self.cooldowns[id] / math.max(self.maxCooldowns[id] or 1, 0.001)
end

function PlayerAbilities:dash(player, colorSystem, enemyManager, playerStats)
    if self.cooldowns.dash > 0 then
        return false
    end

    local spec = colorSystem:getDashSpec()
    self.maxCooldowns.dash = spec.cooldown
    self.cooldowns.dash = spec.cooldown

    local dx = player.moveX or 0
    local dy = player.moveY or -1
    dx, dy = normalize(dx, dy)

    local startX = player.x
    local startY = player.y
    local endX = clamp(player.x + dx * spec.distance, 32, love.graphics.getWidth() - 32)
    local endY = clamp(player.y + dy * spec.distance, 32, love.graphics.getHeight() - 32)
    player.x = endX
    player.y = endY

    table.insert(self.dashTrail, {
        x1 = startX,
        y1 = startY,
        x2 = endX,
        y2 = endY,
        life = 0.22,
        maxLife = 0.22,
        color = spec.color,
    })

    if spec.healRatio > 0 and playerStats then
        playerStats.health = math.min(playerStats.maxHealth, playerStats.health + playerStats.maxHealth * spec.healRatio)
    end

    if spec.speedBoost > 0 then
        self.speedBoostMultiplier = 1 + spec.speedBoost
        self.speedBoostTimer = spec.speedDuration
    end

    if spec.damage > 0 and enemyManager then
        enemyManager:damageEnemiesAlongLine(startX, startY, endX, endY, 34, spec.damage)
    end

    return true
end

function PlayerAbilities:blink(player)
    if self.cooldowns.blink > 0 then
        return false
    end

    self.cooldowns.blink = self.maxCooldowns.blink
    local mx, my = love.mouse.getPosition()
    player.x = clamp(mx, 32, love.graphics.getWidth() - 32)
    player.y = clamp(my, 32, love.graphics.getHeight() - 32)
    return true
end

function PlayerAbilities:shield(shieldEffect, player)
    if self.cooldowns.shield > 0 then
        return false
    end

    self.cooldowns.shield = self.maxCooldowns.shield
    self.shieldTimer = 3.0
    if shieldEffect then
        shieldEffect:trigger(player.x, player.y, {startRadius = 18, alpha = 0.65})
    end
    return true
end

function PlayerAbilities:draw()
    love.graphics.setLineWidth(5)
    love.graphics.setBlendMode("add")
    for _, node in ipairs(self.dashTrail) do
        local alpha = node.life / node.maxLife
        love.graphics.setColor(node.color[1], node.color[2], node.color[3], alpha)
        love.graphics.line(node.x1, node.y1, node.x2, node.y2)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function PlayerAbilities:intersectsPlayer(player, enemy)
    return collision.circle(player.x, player.y, player.radius or 18, enemy.x, enemy.y, enemy.r or 16)
end

return PlayerAbilities
