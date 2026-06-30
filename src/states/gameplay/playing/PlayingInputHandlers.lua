local FirstEncounter = require("src.gameplay.FirstEncounter")
local MetaProgression = require("src.core.MetaProgression")
local OnboardingSequence = require("src.gameplay.OnboardingSequence")
local RhythmDash = require("src.gameplay.RhythmDash")

local PlayingInputHandlers = {}

function PlayingInputHandlers.keypressed(state, key, deps)
    local SimpleGrid = deps.SimpleGrid
    local ColorSystem = deps.ColorSystem
    local XPParticleSystem = deps.XPParticleSystem
    local enemyFlow = deps.enemyFlow

    if FirstEncounter.hasToast() and (key == "space" or key == "return") then
        FirstEncounter.dismissToast()
        return
    end

    if key == "escape" or key == "p" then
        if OnboardingSequence.isActive() then
            return
        end
        local StateManager = require("src.core.StateManager")
        StateManager.push("Pause", {
            player = state.player,
            musicReactor = state.musicReactor
        })
        return
    end

    if key == "space" then
        local rhythmBonus = RhythmDash.getDashBonus(state.musicReactor)
        if state.player:useDash(rhythmBonus) then
            print("[Input] Dash activated!")
            OnboardingSequence.notifyAbilityUsed("dash")
        end
        return
    end

    local GameConfig = require("src.core.GameConfig")
    local debugEnabled = GameConfig.isDebugMode()

    if debugEnabled and key == "t" then
        SimpleGrid.triggerWave("all", {1, 1, 1}, "expand")
        print("[Test] Triggered white wave in all quadrants")
    end

    if key == "e" then
        if state.player:useBlink() then
            print("[Input] Blink activated!")
            OnboardingSequence.notifyAbilityUsed("blink")
        end
        return
    end

    if key == "q" then
        if state.player:useShield() then
            print("[Input] Shield activated!")
            OnboardingSequence.notifyAbilityUsed("shield")
        end
        return
    end

    if debugEnabled and key == "f1" then
        state.player:addExp(state.player.expToNext)
        print("[DEBUG] Instant level up to level " .. state.player.level)
    elseif debugEnabled and key == "f2" then
        local Enemy = require("src.entities.Enemy")
        for i = 1, 10 do
            local angle = (i / 10) * math.pi * 2
            local distance = 200
            local spawnX = state.player.x + math.cos(angle) * distance
            local spawnY = state.player.y + math.sin(angle) * distance
            table.insert(state.enemies, Enemy(spawnX, spawnY))
        end
        print("[DEBUG] Spawned 10 enemies")
    elseif debugEnabled and key == "f3" then
        local counts = ColorSystem.getColorCounts()
        print("[DEBUG] Color System State:")
        print("  Commitment: " .. ColorSystem.getCurrentPath())
        print(string.format("  Primaries: RED=%d GREEN=%d BLUE=%d", counts.RED, counts.GREEN, counts.BLUE))
        print(string.format("  Secondaries: YELLOW=%d MAGENTA=%d CYAN=%d", counts.YELLOW, counts.MAGENTA, counts.CYAN))
        print("  Dominant: " .. tostring(ColorSystem.getDominantColor()))
        print("  Level: " .. state.player.level)
        local choices = ColorSystem.getValidChoices(state.player.level)
        print("  Valid choices: " .. table.concat(choices, ", "))
    elseif debugEnabled and key == "f4" then
        local xpNeeded = 0
        local tempLevel = state.player.level
        local tempExpToNext = state.player.expToNext
        local baseXP = 100
        local scaleFactor = 1.1

        while tempLevel < 20 do
            xpNeeded = xpNeeded + tempExpToNext
            tempLevel = tempLevel + 1
            tempExpToNext = math.floor(baseXP * (scaleFactor ^ (tempLevel - 1)))
        end

        state.player:addExp(xpNeeded)
        print("[DEBUG] Added " .. xpNeeded .. " XP")
    elseif debugEnabled and key == "f5" then
        state.player.hp = state.player.maxHp
        print("[DEBUG] Full heal")
    elseif debugEnabled and key == "f8" then
        local playerCenterX = state.player.x + state.player.width / 2
        local playerCenterY = state.player.y + state.player.height / 2
        table.insert(state.xpOrbs, XPParticleSystem.new(playerCenterX, playerCenterY, 10))
        print("[DEBUG] Spawned basic XP particle orb (10 XP)")
    elseif debugEnabled and key == "f9" then
        local playerCenterX = state.player.x + state.player.width / 2
        local playerCenterY = state.player.y + state.player.height / 2
        table.insert(state.xpOrbs, XPParticleSystem.new(playerCenterX, playerCenterY, 20))
        print("[DEBUG] Spawned medium XP particle orb (20 XP)")
    elseif debugEnabled and key == "f10" then
        local playerCenterX = state.player.x + state.player.width / 2
        local playerCenterY = state.player.y + state.player.height / 2
        table.insert(state.xpOrbs, XPParticleSystem.new(playerCenterX, playerCenterY, 40))
        print("[DEBUG] Spawned large XP particle orb (40 XP)")
    elseif debugEnabled and key == "f6" then
        -- Cycle the first live enemy's color-economy affinity (RED->GREEN->BLUE).
        local cycle = {RED = "GREEN", GREEN = "BLUE", BLUE = "RED"}
        for _, enemy in ipairs(state.enemies) do
            if not enemy.dead then
                enemy.affinity = cycle[enemy.affinity] or "RED"
                print("[DEBUG] Enemy affinity -> " .. enemy.affinity)
                break
            end
        end
    elseif debugEnabled and key == "f7" then
        local s = require("src.gameplay.ColorEconomy").getState()
        print("[DEBUG] Color Economy State:")
        print(string.format("  active=%s  dominantPrimary=%s  secondaryUnlocked=%s",
            tostring(s.active), tostring(s.dominantPrimary), tostring(s.secondaryUnlocked)))
        print(string.format("  streak=%d (+%.1fx)  mults: dominant=%.1f committed=%.1f off=%.1f",
            s.streak, s.streakBonus, s.dominantMult, s.committedMult, s.offMult))
    elseif debugEnabled and key == "f11" then
        local primaryChance = state:calculateDropChance("primary", state.player.level, state.gameTime)
        local secondaryChance = state:calculateDropChance("secondary", state.player.level, state.gameTime)
        print(string.format("[DEBUG] Drop Chances - Primary: %.1f%%, Secondary: %.1f%%", primaryChance * 100, secondaryChance * 100))
        print(string.format("[DEBUG] Game Time: %.1fs, Level: %d", state.gameTime, state.player.level))
    elseif debugEnabled and key == "f12" then
        MetaProgression.clearExplainers()
        require("src.gameplay.FirstEncounter").resetAll()
        print("[Debug] Cleared first-encounter explainer flags")
    elseif debugEnabled and key == "l" then
        state.player.exp = state.player.exp + 50
    end

    if debugEnabled then
        local DebugMenu = require("src.debug.DebugMenu")
        DebugMenu.keypressed(key, state.player, state.enemies, state.musicReactor)
    end
end

return PlayingInputHandlers
