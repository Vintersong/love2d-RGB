-- RunSummary.lua
-- Builds an immutable snapshot for the run-summary screen and meta progression.

local RunSummary = {}

local function copyList(list)
    local out = {}
    for i, value in ipairs(list or {}) do
        out[i] = value
    end
    return out
end

local function buildArtifactList()
    local ArtifactManager = require("src.gameplay.ArtifactManager")
    local artifacts = ArtifactManager.getCollectedArtifacts()
    local out = {}
    for _, artifact in ipairs(artifacts) do
        out[#out + 1] = {
            type = artifact.type,
            name = artifact.name,
            level = artifact.level,
            maxLevel = artifact.maxLevel,
        }
    end
    table.sort(out, function(a, b)
        return tostring(a.type) < tostring(b.type)
    end)
    return out
end

function RunSummary.build(outcome, data)
    data = data or {}

    local player = data.player
    local weapon = player and player.weapon or nil
    local ColorSystem = require("src.gameplay.ColorSystem")
    local BossSystem = require("src.boss.BossSystem")

    local summary = {
        outcome = outcome or "defeat",
        gameTime = data.gameTime or 0,
        enemyKillCount = data.enemyKillCount or 0,
        level = player and player.level or 0,
        hp = player and player.hp or 0,
        maxHp = player and player.maxHp or 0,
        damage = weapon and weapon.damage or 0,
        fireRate = weapon and weapon.fireRate or 0,
        bulletCount = weapon and (weapon.bulletCount or 1) or 1,
        pierceCount = weapon and (weapon.pierceCount or weapon.pierce or 0) or 0,
        weaponName = weapon and weapon.name or "Base Weapon",
        currentPath = ColorSystem.getCurrentPath(),
        dominantColor = ColorSystem.getDominantColor(),
        colorHistory = copyList(ColorSystem.colorHistory),
        artifacts = buildArtifactList(),
        musicReactor = data.musicReactor,
        bossDamage = BossSystem.totalDamageDealt or 0,
    }

    return summary
end

return RunSummary
