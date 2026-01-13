-- SpawnController.lua
-- Manages enemy spawning mechanics and wave control
-- Extracted from PlayingState to reduce complexity

local SpawnController = {}
local EnemySpawner = require("src.systems.EnemySpawner")
local CollisionSystem = require("src.systems.CollisionSystem")
local BossSystem = require("src.systems.BossSystem")
local Powerup = require("src.entities.Powerup")
local XPParticleSystem = require("src.systems.XPParticleSystem")
local ColorSystem = require("src.systems.ColorSystem")
local FloatingTextSystem = require("src.systems.FloatingTextSystem")

-- Initialize controller
function SpawnController.init(screenWidth, screenHeight)
    SpawnController.screenWidth = screenWidth
    SpawnController.screenHeight = screenHeight
    SpawnController.gameTime = 0
    SpawnController.enemyKillCount = 0
    print("[SpawnController] Initialized")
end

-- Update spawning logic
function SpawnController.update(dt, playerLevel, musicReactor, enemies)
    SpawnController.gameTime = SpawnController.gameTime + dt
    
    -- Use EnemySpawner system for procedural enemy waves
    local enemyCountBefore = #enemies
    EnemySpawner.update(dt, musicReactor, enemies, playerLevel)

    -- Register newly spawned enemies in collision system
    for i = enemyCountBefore + 1, #enemies do
        local enemy = enemies[i]
        if not CollisionSystem.world:hasItem(enemy) then
            CollisionSystem.add(enemy, "enemy")
        end
    end
end

-- Handle enemy death interactions (spawn drops etc)
function SpawnController.handleEnemyDeath(target, player, xpOrbs, powerups, onKillCallback)
    SpawnController.enemyKillCount = SpawnController.enemyKillCount + 1

    -- Check if boss should spawn (every 100 kills)
    if SpawnController.enemyKillCount % 100 == 0 and not BossSystem.activeBoss then
        local boss = BossSystem.spawnBoss()
        if boss then
            FloatingTextSystem.add("⚠ BOSS WAVE ⚠", SpawnController.screenWidth/2, SpawnController.screenHeight/2, "BOSS")
        end
    end

    -- Spawn XP orbs (delegate calculation to helper)
    local newOrbs = SpawnController.spawnOrbsForEnemy(target, player, SpawnController.gameTime)
    for _, orb in ipairs(newOrbs) do
        table.insert(xpOrbs, orb)
    end

    -- Chance to drop powerup
    if Powerup.shouldDrop() then
        local powerup = SpawnController.spawnPowerup(target)
        if powerup then
            table.insert(powerups, powerup)
        end
    end
    
    -- Run custom callback if any
    if onKillCallback then
        onKillCallback(target)
    end
end

-- Helper: Spawn orbs based on enemy and player state
function SpawnController.spawnOrbsForEnemy(enemy, player, gameTime)
    local orbX = enemy.x + enemy.width / 2
    local orbY = enemy.y + enemy.height / 2
    
    -- Clamp orb spawn to inner 70% of screen
    orbX, orbY = SpawnController.clampToPlayArea(orbX, orbY)

    local orbs = {}

    -- Always spawn basic XP particle orb
    table.insert(orbs, XPParticleSystem.new(orbX, orbY, 10))

    -- Check if player has picked first color
    local colorHistory = ColorSystem.colorHistory or {}
    if #colorHistory > 0 then
        local playerLevel = player.level

        -- Roll for medium XP orb
        local primaryChance = SpawnController.calculateDropChance("primary", playerLevel, gameTime)
        if math.random() < primaryChance then
            local offsetX = orbX + math.random(-20, 20)
            offsetX, _ = SpawnController.clampToPlayArea(offsetX, orbY)
            table.insert(orbs, XPParticleSystem.new(offsetX, orbY, 20))
        end

        -- Roll for large XP orb
        local secondaryChance = SpawnController.calculateDropChance("secondary", playerLevel, gameTime)
        if math.random() < secondaryChance then
            local offsetX = orbX + math.random(-20, 20)
            offsetX, _ = SpawnController.clampToPlayArea(offsetX, orbY)
            table.insert(orbs, XPParticleSystem.new(offsetX, orbY, 40))
        end
    end

    return orbs
end

-- Helper: Spawn powerup logic
function SpawnController.spawnPowerup(target)
    local powerupType = Powerup.getRandomType()
    local powerupX = target.x + target.width/2
    local powerupY = target.y + target.height/2

    powerupX, powerupY = SpawnController.clampToPlayArea(powerupX, powerupY)
    
    return Powerup(powerupX, powerupY, powerupType)
end

-- Helper: Calculate drop chances
function SpawnController.calculateDropChance(orbType, playerLevel, time)
    local base = (orbType == "primary") and 0.05 or 0.08
    local levelBonus = (playerLevel - 1) * 0.005
    local timeBonus = (time / 60) * 0.001
    local total = base + levelBonus + timeBonus

    -- Cap: primary at 0.25, secondary at 0.35
    local cap = (orbType == "primary") and 0.25 or 0.35
    return math.min(total, cap)
end

-- Helper: Clamp coordinates to inner play area
function SpawnController.clampToPlayArea(x, y)
    local playWidth = SpawnController.screenWidth * 0.7
    local playHeight = SpawnController.screenHeight * 0.7
    local leftBound = (SpawnController.screenWidth - playWidth) / 2
    local topBound = (SpawnController.screenHeight - playHeight) / 2

    x = math.max(leftBound, math.min(leftBound + playWidth, x))
    y = math.max(topBound, math.min(topBound + playHeight, y))
    
    return x, y
end

return SpawnController
