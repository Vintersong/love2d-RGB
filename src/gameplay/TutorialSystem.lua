-- TutorialSystem.lua
-- Guided color-theory tutorial arc. Sits on top of ColorSystem / LevelUpState as a
-- thin controller; it never changes color math, it only (a) restricts which colors
-- the level-up screen offers during the forced phases and (b) queues skippable
-- popups at color-level milestones.
--
-- Milestones are COLOR levels (what ColorSystem already tracks), not character
-- levels. Phase flow:
--   RED    : only RED selectable until RED reaches color level 10 -> RED popup
--   COMMIT : only the two non-red primaries selectable (GREEN recommended)
--   SECOND : only the chosen 2nd primary selectable until it hits color level 10
--            -> 2nd-primary popup + secondary-unlock popup, then arc completes
--   FREE   : no restriction; all unlocked colors selectable
--
-- One-off behaviour: a fully completed arc auto-disables the toggle and persists
-- that to disk, so it plays once for new players. Dying before completion leaves it
-- enabled so the tutorial retries next run. Players can re-enable it in Options.

local Config = require("src.Config")

local TutorialSystem = {}

local active = false
local tipsActive = false
local phase = "RED"      -- RED | COMMIT | SECOND | FREE
local secondCode = nil   -- "g" or "b": the chosen second primary
local popupQueue = {}
local arcComplete = false
local firedPrompts = {}

-- Popup copy. Short enough to read in well under 10s, framed in light/wavelength
-- terms rather than game-tutorial language.
local POPUPS = {
    RED_START = {
        title = "RED  -  PRESSURE ONLINE",
        lines = {
            "Red is your first wavelength: wide pressure, many angles.",
            "Each red level teaches the beam to fracture into more lanes.",
            "Think of it as build identity, not a lesson: red owns space.",
        },
    },
    RED = {
        title = "RED  -  AGGRESSION",
        lines = {
            "Red is the long, slow end of the visible spectrum (~650nm).",
            "Your beam has been fracturing: each level raised the chance to",
            "SPLIT into an extra projectile. At full red the split is guaranteed.",
            "Red is multi-target pressure. Now commit to a second wavelength.",
        },
    },
    COMMIT = {
        title = "SECOND WAVELENGTH",
        lines = {
            "A second primary commits the run. The third primary stays dark.",
            "Two wavelengths define your projectile shape, dash feel,",
            "artifact behavior, and the secondary color waiting downstream.",
        },
    },
    GREEN = {
        title = "GREEN  -  ADAPTATION",
        lines = {
            "Green light reflects. Where red strikes, green REBOUNDS,",
            "chaining from target to target. Each level raised bounce chance;",
            "every 10 levels adds another rebound.",
            "Red splits, green chains. Now watch two wavelengths mix.",
        },
    },
    BLUE = {
        title = "BLUE  -  CONTROL",
        lines = {
            "Blue is the short, high-energy end of the spectrum.",
            "It PIERCES, punching straight through targets. Each level raised",
            "pierce chance; every 10 levels adds another pierce.",
            "Red splits, blue pierces. Now watch two wavelengths mix.",
        },
    },
    YELLOW = {
        title = "YELLOW  -  SYNTHESIS",
        lines = {
            "Red + Green = Yellow. Additive mixing: two wavelengths combine",
            "into a brighter, faster light. Yellow inherits red's spread and",
            "green's bounce, and fires faster - pure velocity.",
            "You now have the full toolkit. Experiment.",
        },
    },
    MAGENTA = {
        title = "MAGENTA  -  SYNTHESIS",
        lines = {
            "Red + Blue = Magenta. Additive mixing combines spread and pierce",
            "into unstable bursts. Magenta inherits red's spread and blue's",
            "pierce, with a chance to detonate on impact.",
            "You now have the full toolkit. Experiment.",
        },
    },
    CYAN = {
        title = "CYAN  -  SYNTHESIS",
        lines = {
            "Green + Blue = Cyan. Additive mixing blends rebound and pierce",
            "into cold control: projectiles carry frost pressure while keeping",
            "the line discipline of blue and the recursion of green.",
            "You now have the full toolkit. Experiment.",
        },
    },
    ARTIFACT = {
        title = "OPTICS ARTIFACT",
        lines = {
            "Artifact synced. Optics do not replace your color path; they bend it.",
            "Prisms, lenses, halos, and mirrors read your dominant wavelength",
            "and turn build choices into visible behavior.",
        },
    },
    SYNERGY = {
        title = "COLOR SYNERGY",
        lines = {
            "A named synergy just fired. That means color plus artifact found",
            "a shared optical rule: split, focus, reflect, refract, or amplify.",
            "When the screen changes, your build is explaining itself.",
        },
    },
}

local function queue(id)
    if POPUPS[id] then
        popupQueue[#popupQueue + 1] = POPUPS[id]
    end
end

local function queueOnce(id)
    if firedPrompts[id] then return end
    firedPrompts[id] = true
    queue(id)
end

-- Begin (or skip) the tutorial for a fresh run. Called from PlayingState run init,
-- after ColorSystem.init() so color state is already clean.
function TutorialSystem.beginRun()
    active = (Config.gameplay.tutorialEnabled == true)
    tipsActive = active
    phase = "RED"
    secondCode = nil
    popupQueue = {}
    arcComplete = false
    firedPrompts = {}
    if active then
        print("[Tutorial] Guided run started - forced RED phase")
    end
end

function TutorialSystem.isActive()
    return active
end

function TutorialSystem.areTipsActive()
    return active or tipsActive
end

-- Restrict the level-up choices for the current forced phase. Returns the input
-- list unchanged when inactive or in FREE. Falls back to the input list if the
-- filter would leave nothing selectable (safety).
function TutorialSystem.filterChoices(choices)
    if not active then return choices end

    local allowed
    if phase == "RED" then
        allowed = { r = true }
    elseif phase == "COMMIT" then
        allowed = { g = true, b = true }
    elseif phase == "SECOND" and secondCode then
        allowed = { [secondCode] = true }
    else
        return choices -- FREE
    end

    local out = {}
    for _, c in ipairs(choices) do
        if allowed[c] then out[#out + 1] = c end
    end
    if #out == 0 then return choices end
    return out
end

-- The color the commitment screen nudges toward (green), per the Poland build.
function TutorialSystem.getRecommendedCode()
    if active and phase == "COMMIT" then return "g" end
    return nil
end

-- Called right after ColorSystem.addColor() in LevelUpState. Inspects color state,
-- advances the phase, and queues popups at milestones.
function TutorialSystem.onColorAdded(_code)
    if not active then return end

    local ColorSystem = require("src.gameplay.ColorSystem")

    if phase == "RED" then
        if _code == "r" and ColorSystem.primary.RED.level == 1 then
            queueOnce("RED_START")
        end
        if ColorSystem.primary.RED.level >= 10 then
            queueOnce("RED")
            phase = "COMMIT"
        end
    elseif phase == "COMMIT" then
        -- Picking a second distinct primary locks the commitment in ColorSystem.
        if ColorSystem.commitment.primary2 then
            secondCode = ColorSystem.commitment.primary2:lower():sub(1, 1)
            queueOnce("COMMIT")
            phase = "SECOND"
        end
    elseif phase == "SECOND" then
        local secondName = ColorSystem.commitment.primary2
        local secondLevel = secondName and ColorSystem.primary[secondName].level or 0
        if secondLevel >= 10 then
            -- 2nd-primary lesson, then the secondary that just unlocked.
            queueOnce(secondCode == "b" and "BLUE" or "GREEN")
            local secondaryName = ColorSystem.getCommittedSecondaryName()
            if secondaryName then queueOnce(secondaryName) end
            phase = "FREE"
            arcComplete = true
        end
    end
end

function TutorialSystem.onArtifactCollected(_artifactType)
    -- Artifact teaching now handled by FirstEncounter (per-artifact, in-combat toast).
    return
end

function TutorialSystem.onSynergyActivated(_synergyName)
    if not TutorialSystem.areTipsActive() then return end
    queueOnce("SYNERGY")
end

function TutorialSystem.hasPopup()
    return #popupQueue > 0
end

function TutorialSystem.peekPopup()
    return popupQueue[1]
end

-- Dismiss the current popup. When the last popup of a completed arc is dismissed,
-- the tutorial finalizes (one-off: disable + persist).
function TutorialSystem.dismissPopup()
    if #popupQueue == 0 then return end
    table.remove(popupQueue, 1)
    if #popupQueue == 0 and arcComplete then
        TutorialSystem.complete()
    end
end

function TutorialSystem.complete()
    active = false
    arcComplete = false
    Config.gameplay.tutorialEnabled = false
    require("src.core.Settings").save()
    print("[Tutorial] Arc complete - auto-disabled (toggle in Options to replay)")
end

return TutorialSystem
