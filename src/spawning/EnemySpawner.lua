-- EnemySpawner.lua
-- Music-reactive formation spawner.

local Enemy = require("src.entities.Enemy")
local flux = require("libs.flux-master.flux")
local VFXLibrary = require("src.effects.VFXLibrary")
local FormationCatalog = require("src.spawning.FormationCatalog")
local SpawnPolicyMusic = require("src.spawning.SpawnPolicyMusic")
local EnemyPool = require("src.spawning.EnemyPool")

local EnemySpawner = {}

EnemySpawner.formations = FormationCatalog.formations
EnemySpawner.sectionSettings = SpawnPolicyMusic.sectionSettings
EnemySpawner.enemyPool = EnemyPool.pool

EnemySpawner.formationCooldown = 0
EnemySpawner.formationSpawnRate = 8.0

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
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local formationName = EnemySpawner.selectFormationByMusic(musicReactor, complexity)
    local formation = EnemySpawner.formations[formationName]
    if not formation then
        return
    end

    local totalEnemies = formation.count or (formation.rows * formation.columns)
    local spacing = 50
    local spawnDirections = {
        {
            name = "left_side",
            startX = -100,
            startY = screenHeight * 0.3,
            targetX = screenWidth * 0.25,
            targetY = screenHeight * 0.35,
            mirrorX = false
        },
        {
            name = "right_side",
            startX = screenWidth + 100,
            startY = screenHeight * 0.3,
            targetX = screenWidth * 0.75,
            targetY = screenHeight * 0.35,
            mirrorX = true
        }
    }

    local formationEnemyTypes = {}
    for i = 0, totalEnemies - 1 do
        local role = formation.roles and formation.roles[i + 1] or "support"
        formationEnemyTypes[i] = EnemySpawner.assignEnemyType(role, musicReactor)
    end

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

                local targetX = direction.targetX + offsetX
                local targetY = direction.targetY + offsetY

                flux.to(enemy, 2.0, {x = targetX, y = targetY})
                    :ease("quadout")
                    :oncomplete(function()
                        enemy.pattern = "track_player"
                        if i == 0 then
                            local formationColor = {1, 0.3, 0.3}
                            VFXLibrary.spawnFormationFlash(direction.targetX, direction.targetY, formationColor, 1.5)
                        end
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
