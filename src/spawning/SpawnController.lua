-- SpawnController.lua
-- Manages enemy spawning mechanics and wave control
-- Extracted from PlayingState to reduce complexity

local SpawnController = {}
local Config = require("src.Config")
local ColorEconomy = require("src.gameplay.ColorEconomy")
local EnemySpawner = require("src.spawning.EnemySpawner")
local CollisionSystem = require("src.combat.CollisionSystem")
local BossSystem = require("src.boss.BossSystem")
local Powerup = require("src.entities.Powerup")
local FloatingTextSystem = require("src.effects.FloatingTextSystem")
local PickupSystem = require("src.gameplay.PickupSystem")
local VFXLibrary = require("src.effects.VFXLibrary")

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

    VFXLibrary.spawnEnemyDeathBurst(target)

    SpawnController.enemyKillCount = SpawnController.enemyKillCount + 1

    -- Check if boss should spawn (every bossInterval kills)
    local bossInterval = Config.bossMeter.bossInterval
    if SpawnController.enemyKillCount % bossInterval == 0 and not BossSystem.activeBoss then
        local encounterIndex = math.floor(SpawnController.enemyKillCount / bossInterval)
        local boss = BossSystem.spawnBoss({encounterIndex = encounterIndex})
        if boss then
            FloatingTextSystem.add(boss.introText or "BOSS WAVE", SpawnController.screenWidth/2, SpawnController.screenHeight/2, "BOSS")
        end
    end

    -- Color economy: classify the kill against the player's committed colors and
    -- scale XP accordingly. Drops below are unaffected — only XP is routed.
    local economy = ColorEconomy.registerKill(target)

    -- Spawn XP orbs (delegate calculation to helper)
    local newOrbs = PickupSystem.spawnOrbsForEnemy(target, player, SpawnController.gameTime, SpawnController.screenWidth, SpawnController.screenHeight, economy.multiplier)
    for _, orb in ipairs(newOrbs) do
        table.insert(xpOrbs, orb)
    end

    -- Feedback pop (only once the economy is active — pre-commitment stays quiet;
    -- the absence of color is itself the signal). Matched kills pop in the matched
    -- color, off-color in gray, with a larger streak-milestone callout.
    if economy.killType ~= "precommit" then
        local cx = target.x + (target.width or 0) / 2
        local cy = target.y + (target.height or 0) / 2
        if economy.milestone then
            FloatingTextSystem.add(
                string.format("STREAK %d  %.1fx", economy.milestone, economy.multiplier),
                cx, cy, "HEAL", economy.color, 1.6)
        else
            local shownXP = math.max(1, math.ceil(10 * economy.multiplier))
            FloatingTextSystem.add("+" .. shownXP, cx, cy, "DAMAGE", economy.color)
        end
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
