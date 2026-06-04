-- SpawnController.lua
-- Manages enemy spawning mechanics and wave control
-- Extracted from PlayingState to reduce complexity

local SpawnController = {}
local EnemySpawner = require("src.spawning.EnemySpawner")
local CollisionSystem = require("src.combat.CollisionSystem")
local BossSystem = require("src.boss.BossSystem")
local Powerup = require("src.entities.Powerup")
local FloatingTextSystem = require("src.effects.FloatingTextSystem")
local PickupSystem = require("src.gameplay.PickupSystem")

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

    if BossSystem.activeBoss then
        return
    end
    
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
    if target._deathRewarded then
        return
    end
    target._deathRewarded = true

    SpawnController.enemyKillCount = SpawnController.enemyKillCount + 1

    -- Check if boss should spawn (every 100 kills)
    if SpawnController.enemyKillCount % 100 == 0 and not BossSystem.activeBoss then
        local encounterIndex = math.floor(SpawnController.enemyKillCount / 100)
        local boss = BossSystem.spawnBoss({encounterIndex = encounterIndex})
        if boss then
            FloatingTextSystem.add(boss.introText or "BOSS WAVE", SpawnController.screenWidth/2, SpawnController.screenHeight/2, "BOSS")
        end
    end

    -- Spawn XP orbs (delegate calculation to helper)
    local newOrbs = PickupSystem.spawnOrbsForEnemy(target, player, SpawnController.gameTime, SpawnController.screenWidth, SpawnController.screenHeight)
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

-- Helper: Spawn powerup logic
function SpawnController.spawnPowerup(target)
    local powerupType = Powerup.getRandomType()
    if not powerupType then
        return nil
    end
    local powerupX = target.x + target.width/2
    local powerupY = target.y + target.height/2

    powerupX, powerupY = SpawnController.clampToPlayArea(powerupX, powerupY)
    
    return Powerup(powerupX, powerupY, powerupType)
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
