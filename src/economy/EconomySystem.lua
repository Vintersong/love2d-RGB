-- EconomySystem.lua
-- Manages the Prism Shard currency: earning, spending, and persistent totals.
-- This module is PURE DATA - it does not touch the HUD, shop UI, or player stats.
-- Integration points are clearly marked with TODO comments.

local EconomySystem = {}

-- ============================================================================
-- INTERNAL STATE
-- ============================================================================

local _shards       = 0   -- Current spendable shards (session)
local _totalEarned  = 0   -- Lifetime shards earned (for stats/achievements)

-- Earn multiplier - default 1.0, can be raised by upgrades.
-- TODO: when UpgradeSystem is integrated, set this via EconomySystem.setMultiplier()
local _multiplier   = 1.0

-- ============================================================================
-- SHARD EARN RATES (tuning constants)
-- Adjust these without touching any other file.
-- ============================================================================

EconomySystem.RATES = {
    -- Per-kill base rewards (before multiplier)
    KILL_FORMATION  = 1,   -- Basic formation enemy
    KILL_FLANKER    = 2,   -- Faster flanker type
    KILL_MIDS       = 2,   -- MIDS frequency enemy
    KILL_BASS       = 5,   -- BASS tank
    KILL_TREBLE     = 3,   -- TREBLE scout

    -- Boss rewards
    BOSS_CLEAR      = 50,  -- Any boss kill

    -- Milestone bonuses
    LEVEL_UP        = 3,   -- Each player level-up
    SURVIVE_WAVE    = 10,  -- Completing a full survival wave

    -- Wave time bonus: shards per 60s survived (awarded on wave end)
    TIME_BONUS_PER_MINUTE = 5,
}

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Reset for a new run. Call from PlayingState:init() or equivalent.
function EconomySystem.reset()
    _shards      = 0
    _totalEarned = 0
    _multiplier  = 1.0
end

--- Current spendable shard balance.
function EconomySystem.getShards()
    return _shards
end

--- Total shards earned this session (for end-screen stats).
function EconomySystem.getTotalEarned()
    return _totalEarned
end

--- Earn shards from a source. amount is the BASE amount (multiplier applied here).
-- source: string label for debugging ("kill", "boss", "levelup", etc.)
-- Returns the final amount actually awarded.
function EconomySystem.earn(amount, source)
    local finalAmount = math.max(1, math.floor(amount * _multiplier))
    _shards      = _shards + finalAmount
    _totalEarned = _totalEarned + finalAmount
    -- Debug log (remove when HUD shard pop is implemented)
    -- print(string.format("[Economy] +%d shards (%s) | total: %d", finalAmount, source or "?", _shards))
    return finalAmount
end

--- Convenience wrappers called from kill/event sites.
-- TODO: call EconomySystem.onEnemyKill(enemy) inside EnemyManager or PlayingState
-- where enemy.dead transitions to true.
function EconomySystem.onEnemyKill(enemy)
    local rate = EconomySystem.RATES.KILL_FORMATION
    local eType = enemy.enemyType or "formation"
    if     eType == "BASS"    then rate = EconomySystem.RATES.KILL_BASS
    elseif eType == "MIDS"    then rate = EconomySystem.RATES.KILL_MIDS
    elseif eType == "TREBLE"  then rate = EconomySystem.RATES.KILL_TREBLE
    elseif eType == "flanker" then rate = EconomySystem.RATES.KILL_FLANKER
    end
    return EconomySystem.earn(rate, "kill:" .. eType)
end

-- TODO: call EconomySystem.onBossClear() when boss.dead transitions to true.
function EconomySystem.onBossClear()
    return EconomySystem.earn(EconomySystem.RATES.BOSS_CLEAR, "boss")
end

-- TODO: call EconomySystem.onLevelUp() inside Player:levelUp() after level increments.
function EconomySystem.onLevelUp()
    return EconomySystem.earn(EconomySystem.RATES.LEVEL_UP, "levelup")
end

-- TODO: call EconomySystem.onWaveClear(survivalSeconds) at end of each wave.
function EconomySystem.onWaveClear(survivalSeconds)
    EconomySystem.earn(EconomySystem.RATES.SURVIVE_WAVE, "wave_clear")
    local timeBonus = math.floor((survivalSeconds / 60) * EconomySystem.RATES.TIME_BONUS_PER_MINUTE)
    if timeBonus > 0 then
        EconomySystem.earn(timeBonus, "time_bonus")
    end
end

--- Attempt to spend shards. Returns true if successful, false if insufficient.
-- TODO: call EconomySystem.spend(cost) from ShopSystem when player confirms a purchase.
function EconomySystem.spend(amount)
    if _shards < amount then
        return false, "insufficient_shards"
    end
    _shards = _shards - amount
    return true
end

--- Check affordability without spending.
function EconomySystem.canAfford(amount)
    return _shards >= amount
end

--- Override the earn multiplier (called by upgrade that buffs shard income).
function EconomySystem.setMultiplier(value)
    _multiplier = math.max(0.1, value)
end

function EconomySystem.getMultiplier()
    return _multiplier
end

return EconomySystem
