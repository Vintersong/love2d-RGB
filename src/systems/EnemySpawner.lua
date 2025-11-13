-- Enemy Spawner System - Music-Reactive Frequency-Based Spawning

local ProceduralEnemy = require("src.entities.ProceduralEnemy")
local EnemyAbilities = require("src.components.EnemyAbilities")
local Enemy = require("src.entities.Enemy")

local EnemySpawner = {}

-- NEW: Frequency-based spawn cooldowns
EnemySpawner.bassSpawnCooldown = 0
EnemySpawner.midsSpawnCooldown = 0
EnemySpawner.trebleSpawnCooldown = 0
EnemySpawner.bassSpawnRate = 3.0  -- BASS enemies every 1.5 seconds max (slower)
EnemySpawner.midsSpawnRate = 1.6  -- MIDS enemies every 0.8 seconds max (slower)
EnemySpawner.trebleSpawnRate = 1.0  -- TREBLE enemies every 0.5 seconds max (slower)

-- Section-based difficulty settings
EnemySpawner.sectionSettings = {
    intro = {
        spawnRateMultiplier = 0.8,  -- 80% spawn rate
        allowedTypes = {"BASS", "MIDS", "TREBLE"},
        formationComplexity = "simple"
    },
    verse = {
        spawnRateMultiplier = 1.0,  -- Normal spawn rate
        allowedTypes = {"BASS", "MIDS", "TREBLE"},
        formationComplexity = "medium"
    },
    chorus = {
        spawnRateMultiplier = 1.3,  -- 130% spawn rate
        allowedTypes = {"BASS", "MIDS", "TREBLE"},
        formationComplexity = "complex"
    },
    bridge = {
        spawnRateMultiplier = 0.8,  -- Slightly reduced spawn rate
        allowedTypes = {"BASS", "MIDS", "TREBLE"},  -- All types allowed
        formationComplexity = "simple"
    },
    outro = {
        spawnRateMultiplier = 1.0,  -- Normal spawn rate
        allowedTypes = {"BASS", "MIDS", "TREBLE"},  -- All types allowed
        formationComplexity = "simple"
    }
}

function EnemySpawner.update(dt, musicReactor, enemies, playerLevel)
    playerLevel = playerLevel or 1
    
    -- Frequency-based spawning (music-reactive)
    if musicReactor then
        local freqBands = musicReactor:getFrequencyBands()
        local currentSection = musicReactor.currentSection or "verse"
        local sectionConfig = EnemySpawner.sectionSettings[currentSection] or EnemySpawner.sectionSettings.verse
        
        -- Update cooldowns
        EnemySpawner.bassSpawnCooldown = math.max(0, EnemySpawner.bassSpawnCooldown - dt)
        EnemySpawner.midsSpawnCooldown = math.max(0, EnemySpawner.midsSpawnCooldown - dt)
        EnemySpawner.trebleSpawnCooldown = math.max(0, EnemySpawner.trebleSpawnCooldown - dt)
        
        -- BASS enemies spawn on strong bass hits
        if freqBands.bass > 0.7 and EnemySpawner.bassSpawnCooldown <= 0 then
            if EnemySpawner.isTypeAllowed("BASS", sectionConfig.allowedTypes) then
                EnemySpawner.spawnFrequencyEnemy(enemies, "BASS", playerLevel)
                EnemySpawner.bassSpawnCooldown = EnemySpawner.bassSpawnRate / sectionConfig.spawnRateMultiplier
            end
        end
        
        -- MIDS enemies spawn on mid-range activity
        if freqBands.mids > 0.5 and EnemySpawner.midsSpawnCooldown <= 0 then
            if EnemySpawner.isTypeAllowed("MIDS", sectionConfig.allowedTypes) then
                EnemySpawner.spawnFrequencyEnemy(enemies, "MIDS", playerLevel)
                EnemySpawner.midsSpawnCooldown = EnemySpawner.midsSpawnRate / sectionConfig.spawnRateMultiplier
            end
        end
        
        -- TREBLE enemies spawn on high-frequency peaks
        if freqBands.treble > 0.7 and EnemySpawner.trebleSpawnCooldown <= 0 then
            if EnemySpawner.isTypeAllowed("TREBLE", sectionConfig.allowedTypes) then
                EnemySpawner.spawnFrequencyEnemy(enemies, "TREBLE", playerLevel)
                EnemySpawner.trebleSpawnCooldown = EnemySpawner.trebleSpawnRate / sectionConfig.spawnRateMultiplier
            end
        end
    end
end

-- Spawn frequency-based enemy (BASS/MIDS/TREBLE)
function EnemySpawner.spawnFrequencyEnemy(enemies, enemyType, playerLevel)
    local SCREEN_WIDTH = love.graphics.getWidth()
    local SCREEN_HEIGHT = love.graphics.getHeight()
    playerLevel = playerLevel or 1
    
    -- Calculate 70% play area
    local playWidth = SCREEN_WIDTH * 0.7
    local leftBound = (SCREEN_WIDTH - playWidth) / 2
    
    -- Spawn enemies above the screen (never visible at spawn)
    -- They move down and become active after entering 10% of screen height
    local x, y
    
    -- All enemies spawn from top, spread across 70% play width
    x = leftBound + math.random() * playWidth
    y = -50  -- Spawn above screen
    
    -- Create frequency-based enemy
    local enemy = Enemy(x, y, enemyType, playerLevel)
    if enemy and enemies then
        -- Mark enemy as inactive until it enters the screen
        enemy.inactive = true
        enemy.activationY = SCREEN_HEIGHT * 0.1  -- Becomes active at 10% screen height
        table.insert(enemies, enemy)
    end
end

-- Helper: Check if enemy type is allowed in current section
function EnemySpawner.isTypeAllowed(enemyType, allowedTypes)
    for _, allowedType in ipairs(allowedTypes) do
        if enemyType == allowedType then
            return true
        end
    end
    return false
end

return EnemySpawner
