-- PickupSystem.lua
-- Handles XP orb and powerup collection/drop helper behavior.

local PickupSystem = {}

local ColorSystem = require("src.gameplay.ColorSystem")
local FloatingTextSystem = require("src.effects.FloatingTextSystem")
local VFXLibrary = require("src.effects.VFXLibrary")
local XPParticleSystem = require("src.effects.XPParticleSystem")

function PickupSystem.updateXPOrbs(dt, player, xpOrbs, centerX, centerY)
    for i = #xpOrbs, 1, -1 do
        local orb = xpOrbs[i]
        local collectedXP = orb:update(dt, centerX, centerY)

        -- Check if collected
        if collectedXP then
            player:addExp(collectedXP)
            table.remove(xpOrbs, i)
        elseif not orb.alive then
            table.remove(xpOrbs, i)
        end
    end
end

function PickupSystem.updatePowerups(dt, player, enemies, powerups, centerX, centerY)
    for i = #powerups, 1, -1 do
        local powerup = powerups[i]
        powerup:update(dt, centerX, centerY)

        -- Check if collected
        if powerup:checkCollision(player) then
            local result = powerup:collect(player)

            -- Show floating text for artifact collection
            if result and result.success then
                FloatingTextSystem.addArtifact(
                    result.artifactName,
                    result.level,
                    powerup.x,
                    powerup.y,
                    result.isMaxLevel
                )

                -- Spawn VFX for artifact
                VFXLibrary.spawnArtifactEffect(
                    result.type,
                    powerup.x,
                    powerup.y,
                    centerX,
                    centerY
                )

                -- Show synergy unlock if exists
                if result.synergyMessage then
                    FloatingTextSystem.addSynergy(
                        result.synergyMessage,
                        powerup.x,
                        powerup.y + 60
                    )

                    -- Spawn synergy VFX
                    local synergyKey = result.synergyMessage:match("^%S+")
                    if synergyKey then
                        synergyKey = synergyKey:upper():gsub("[^%w]", "_")
                        VFXLibrary.spawnSynergyEffect(synergyKey, powerup.x, powerup.y + 60)
                    end
                end
            end

            -- Handle special effects
            if result and result.message == "SCREEN_CLEAR" then
                for _, enemy in ipairs(enemies) do
                    enemy.dead = true
                end
                print("SCREEN CLEARED!")
            end

            table.remove(powerups, i)
        elseif powerup.lifetime <= 0 then
            table.remove(powerups, i)
        end
    end
end

function PickupSystem.calculateDropChance(orbType, playerLevel, time)
    local base = (orbType == "primary") and 0.05 or 0.08
    local levelBonus = (playerLevel - 1) * 0.005
    local timeBonus = (time / 60) * 0.001
    local total = base + levelBonus + timeBonus

    -- Cap: primary at 0.25, secondary at 0.35
    local cap = (orbType == "primary") and 0.25 or 0.35
    return math.min(total, cap)
end

function PickupSystem.spawnOrbsForEnemy(enemy, player, gameTime, screenWidth, screenHeight)
    local orbX = enemy.x + enemy.width / 2
    local orbY = enemy.y + enemy.height / 2

    -- Clamp orb spawn to inner 70% of screen
    local playWidth = screenWidth * 0.7
    local playHeight = screenHeight * 0.7
    local leftBound = (screenWidth - playWidth) / 2
    local topBound = (screenHeight - playHeight) / 2

    orbX = math.max(leftBound, math.min(leftBound + playWidth, orbX))
    orbY = math.max(topBound, math.min(topBound + playHeight, orbY))

    local orbs = {}

    -- Always spawn basic XP particle orb
    table.insert(orbs, XPParticleSystem.new(orbX, orbY, 10))

    -- Check if player has picked first color
    local colorHistory = ColorSystem.colorHistory or {}
    if #colorHistory > 0 then
        local playerLevel = player.level

        -- Roll for medium XP orb
        local primaryChance = PickupSystem.calculateDropChance("primary", playerLevel, gameTime)
        if math.random() < primaryChance then
            local offsetX = orbX + math.random(-20, 20)
            offsetX = math.max(leftBound, math.min(leftBound + playWidth, offsetX))
            table.insert(orbs, XPParticleSystem.new(offsetX, orbY, 20))
        end

        -- Roll for large XP orb
        local secondaryChance = PickupSystem.calculateDropChance("secondary", playerLevel, gameTime)
        if math.random() < secondaryChance then
            local offsetX = orbX + math.random(-20, 20)
            offsetX = math.max(leftBound, math.min(leftBound + playWidth, offsetX))
            table.insert(orbs, XPParticleSystem.new(offsetX, orbY, 40))
        end
    end

    return orbs
end

return PickupSystem
