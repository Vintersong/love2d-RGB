-- OnboardingSequence.lua
-- Phase-0 onboarding: gated, live-gameplay beats teaching movement + abilities
-- before the color-theory TutorialSystem arc takes over at level-ups. Runs only
-- when Config.gameplay.tutorialEnabled is true. It does NOT toggle that flag
-- itself -- TutorialSystem.complete() owns disabling it after the color arc ends.

local Config = require("src.Config")

local OnboardingSequence = {}

local BEATS = {
    { id = "move",     key = "WASD",  name = "MOVE",      line = "Position is your weapon - you never aim manually." },
    { id = "autofire", key = nil,     name = "AUTO-FIRE", line = "You fire automatically at the nearest enemy." },
    { id = "dash",     key = "SPACE", name = "DASH",      line = "Reposition or escape. Its effect changes with your color." },
    { id = "blink",    key = "E",     name = "BLINK",     line = "Instant teleport to your cursor. 5s cooldown." },
    { id = "shield",   key = "Q",     name = "SHIELD",    line = "Negate a hit you can't dodge. 10s cooldown." },
}

local MOVE_DISTANCE = 250    -- px of cumulative movement to clear the MOVE beat
local SKIP_HOLD_TIME = 1.0   -- seconds holding ESC to skip onboarding

local active = false
local index = 1
local movedDistance = 0
local lastX, lastY = nil, nil
local dummies = nil          -- tracked AUTO-FIRE lesson enemies
local skipHold = 0

local function currentBeat()
    return BEATS[index]
end

function OnboardingSequence.beginRun()
    active = (Config.gameplay.tutorialEnabled == true)
    index = 1
    movedDistance = 0
    lastX, lastY = nil, nil
    dummies = nil
    skipHold = 0
    if active then
        print("[Onboarding] Phase 0 started - MOVE beat")
    end
end

function OnboardingSequence.isActive()
    return active
end

local function advance()
    index = index + 1
    dummies = nil
    if index > #BEATS then
        active = false
        print("[Onboarding] Phase 0 complete - handing off to normal run")
    else
        print("[Onboarding] Beat -> " .. BEATS[index].id)
    end
end

-- Spawn the dummy enemies used by the AUTO-FIRE beat. They must be registered with
-- the collision world (like every real enemy) or projectile hits — which resolve via
-- CollisionSystem.checkProjectileEnemyCollisions / world:queryRect — can never land,
-- leaving the beat unable to advance. They deal no contact damage during phase 0
-- because PlayingEnemyFlow.updateEnemies suppresses the contact loop while active.
local function spawnDummies(state)
    local Enemy = require("src.entities.Enemy")
    local CollisionSystem = require("src.combat.CollisionSystem")
    dummies = {}
    local px = state.player.x + state.player.width / 2
    local py = state.player.y + state.player.height / 2
    for i = 1, 2 do
        local angle = -math.pi / 2 + (i - 1.5) * 0.5
        local dx = px + math.cos(angle) * 260
        local dy = py + math.sin(angle) * 260
        local dummy = Enemy(dx, dy)
        table.insert(state.enemies, dummy)
        CollisionSystem.add(dummy, "enemy")
        dummies[#dummies + 1] = dummy
    end
end

function OnboardingSequence.update(dt, player, state)
    if not active then return end

    -- ESC-hold skip.
    if love.keyboard.isDown("escape") then
        skipHold = skipHold + dt
        if skipHold >= SKIP_HOLD_TIME then
            OnboardingSequence.skip()
            return
        end
    else
        skipHold = 0
    end

    local beat = currentBeat()
    if beat.id == "move" then
        if lastX then
            local dx, dy = player.x - lastX, player.y - lastY
            movedDistance = movedDistance + math.sqrt(dx * dx + dy * dy)
        end
        lastX, lastY = player.x, player.y
        if movedDistance >= MOVE_DISTANCE then
            advance()
        end
    elseif beat.id == "autofire" then
        if not dummies then
            spawnDummies(state)
        else
            for _, dummy in ipairs(dummies) do
                if dummy.dead then
                    advance()
                    return
                end
            end
        end
    end
    -- dash/blink/shield beats advance via notifyAbilityUsed.
end

function OnboardingSequence.notifyAbilityUsed(kind)
    if not active then return end
    if currentBeat().id == kind then
        advance()
    end
end

function OnboardingSequence.currentPrompt()
    if not active then return nil end
    local beat = currentBeat()
    return {
        key = beat.key,
        name = beat.name,
        line = beat.line,
        index = index,
        total = #BEATS,
        skipHint = "Hold ESC to skip",
    }
end

function OnboardingSequence.skip()
    if not active then return end
    active = false
    print("[Onboarding] Skipped by player")
end

return OnboardingSequence
