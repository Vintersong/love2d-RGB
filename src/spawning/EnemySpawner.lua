-- EnemySpawner.lua
-- Music-reactive formation spawner.

local Enemy = require("src.entities.Enemy")
local flux = require("libs.flux-master.flux")
local VFXLibrary = require("src.effects.VFXLibrary")
local FormationCatalog = require("src.spawning.FormationCatalog")
local SpawnPolicyMusic = require("src.spawning.SpawnPolicyMusic")
local EnemyPool = require("src.spawning.EnemyPool")
local GameConfig = require("src.core.GameConfig")

local EnemySpawner = {}

local ENEMY_FOOTPRINTS = {
    BASS = {width = 35, height = 35},
    MIDS = {width = 18, height = 18},
    TREBLE = {width = 18, height = 18},
    BOSS = {width = 60, height = 60},
    formation = {width = 24, height = 24},
    flanker = {width = 24, height = 24},
}

EnemySpawner.formations = FormationCatalog.formations
EnemySpawner.sectionSettings = SpawnPolicyMusic.sectionSettings
EnemySpawner.enemyPool = EnemyPool.pool

EnemySpawner.formationCooldown = 0
EnemySpawner.formationSpawnRate = 8.0

local function getFootprint(enemyType)
    local footprint = ENEMY_FOOTPRINTS[enemyType] or ENEMY_FOOTPRINTS.formation
    return footprint.width, footprint.height
end

local function getFormationSpacing(enemyTypes, baseSpacing)
    local maxFootprint = baseSpacing or 50

    for _, enemyType in pairs(enemyTypes or {}) do
        local width, height = getFootprint(enemyType)
        maxFootprint = math.max(maxFootprint, width, height)
    end

    return maxFootprint + 14
end

local function getActiveLandingBands(playerLevel, complexity, musicReactor)
    local _, screenHeight = GameConfig.getScreenSize()
    local energy = musicReactor and musicReactor.energy or 0
    local useAllBands = playerLevel >= 10 or complexity == "complex" or energy >= 0.8
    local bands = {
        {
            name = "upper",
            startY = screenHeight * 0.3,
            targetY = screenHeight * 0.35,
        },
        {
            name = "lower",
            startY = screenHeight * 0.7,
            targetY = screenHeight * 0.65,
        }
    }

    if useAllBands then
        return bands
    end

    return {bands[love.math.random(1, #bands)]}
end

function EnemySpawner.update(dt, musicReactor, enemies, playerLevel)
    playerLevel = playerLevel or 1
    EnemySpawner.formationCooldown = math.max(0, EnemySpawner.formationCooldown - dt)

    if EnemySpawner.formationCooldown <= 0 then
        local complexity = SpawnPolicyMusic.getFormationComplexity(musicReactor)
        EnemySpawner.spawnFormation(enemies, playerLevel, complexity, musicReactor)
        EnemySpawner.formationCooldown = EnemySpawner.formationSpawnRate
    end
end

function EnemySpawner.assignEnemyType(role, musicReactor)
    return SpawnPolicyMusic.assignEnemyType(role, musicReactor)
end

function EnemySpawner.createBehaviorProfile(enemyType, role, musicReactor, playerLevel, formationName)
    return SpawnPolicyMusic.createBehaviorProfile(enemyType, role, musicReactor, playerLevel, formationName)
end

function EnemySpawner.selectFormationByMusic(musicReactor, complexity)
    return SpawnPolicyMusic.selectFormationByMusic(musicReactor, complexity)
end

function EnemySpawner.spawnFormation(enemies, playerLevel, complexity, musicReactor)
    local screenWidth, screenHeight = GameConfig.getScreenSize()

    local formationName = EnemySpawner.selectFormationByMusic(musicReactor, complexity)
    local formation = EnemySpawner.formations[formationName]
    if not formation then
        return
    end

    local totalEnemies = formation.count or (formation.rows * formation.columns)
    local activeBands = getActiveLandingBands(playerLevel, complexity, musicReactor)
    local spawnDirections = {}

    for _, band in ipairs(activeBands) do
        table.insert(spawnDirections, {
            name = "left_side_" .. band.name,
            startX = -100,
            startY = band.startY,
            targetX = screenWidth * 0.25,
            targetY = band.targetY,
            mirrorX = false
        })
        table.insert(spawnDirections, {
            name = "right_side_" .. band.name,
            startX = screenWidth + 100,
            startY = band.startY,
            targetX = screenWidth * 0.75,
            targetY = band.targetY,
            mirrorX = true
        })
    end

    local formationEnemyTypes = {}
    for i = 0, totalEnemies - 1 do
        local role = formation.roles and formation.roles[i + 1] or "support"
        formationEnemyTypes[i] = EnemySpawner.assignEnemyType(role, musicReactor)
    end

    local spacing = getFormationSpacing(formationEnemyTypes, 50)

    for _, direction in ipairs(spawnDirections) do
        local formationID = love.timer.getTime() + math.random()
        local formationWidth = spacing * (formation.columns or 6)
        local formationHeight = spacing * (formation.rows or 3)

        VFXLibrary.spawnFormationWarning(direction.targetX, direction.targetY, formationWidth, formationHeight, 1.0)

        local formationData = {
            id = formationID,
            centerX = direction.targetX,
            targetY = direction.targetY,
            members = {}
        }

        for i = 0, totalEnemies - 1 do
            local offsetX, offsetY = formation.pattern(i, totalEnemies, spacing)
            if direction.mirrorX then
                offsetX = -offsetX
            end

            local x = direction.startX + offsetX
            local y = direction.startY + offsetY
            local enemyType = formationEnemyTypes[i]
            local role = formation.roles and formation.roles[i + 1] or "support"
            local shapeOverride = formation.shapeOverride and formation.shapeOverride[i + 1] or nil
            local targetX = direction.targetX + offsetX
            local targetY = direction.targetY + offsetY

            local formData = {
                formation = formationName,
                formationID = formationID,
                formationIndex = i,
                role = role,
                offsetX = offsetX,
                offsetY = offsetY,
                centerX = direction.targetX,
                targetY = direction.targetY,
                spawnDirection = direction.name,
                behaviorProfile = EnemySpawner.createBehaviorProfile(enemyType, role, musicReactor, playerLevel, formationName)
            }

            local enemy = EnemyPool.take()
            if enemy then
                enemy:reset(x, y, enemyType, playerLevel, formData)
            else
                enemy = Enemy(x, y, enemyType, playerLevel, formData)
            end

            if enemy then
                if shapeOverride then
                    enemy.shape = shapeOverride
                end

                enemy.pattern = "formation_hold"
                enemy.formationData.group = formationData

                flux.to(enemy, 2.0, {x = targetX, y = targetY})
                    :ease("quadout")
                    :oncomplete(function()
                        enemy.pattern = "track_player"
                    end)

                table.insert(enemies, enemy)
                table.insert(formationData.members, enemy)
            end
        end
    end
end

function EnemySpawner.returnToPool(enemy)
    EnemyPool.release(enemy)
end

return EnemySpawner
