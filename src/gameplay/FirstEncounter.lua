-- FirstEncounter.lua
-- Persistent, per-concept "first encounter" teaching. Decoupled from TutorialSystem:
-- each concept (an artifact, the chroma currency, spending chroma) teaches once, ever,
-- gated by MetaProgression.seenExplainers regardless of Config.gameplay.tutorialEnabled.
local Config = require("src.Config")
local MetaProgression = require("src.core.MetaProgression")
local AtlasData = require("src.data.AtlasData")

local FirstEncounter = {}

local toastQueue = {}
local toastTimer = 0

local CHROMA_CARDS = {
    chroma_earned = {
        title = "CHROMA",
        color = nil,  -- resolved to Theme accent by the renderer when nil
        lines = {
            "Chroma is permanent currency. You keep every Chroma you earn",
            "when a run ends - win or lose.",
        },
        atlasTab = nil,
    },
    chroma_spend = {
        title = "SPEND CHROMA",
        color = nil,
        lines = {
            "Spend Chroma here to upgrade your artifacts.",
            "Upgrades are permanent and carry into every future run.",
        },
        atlasTab = "artifacts",
    },
}

function FirstEncounter.shouldTeach(id)
    return MetaProgression.hasSeenExplainer(id) == false
end

function FirstEncounter.markTaught(id)
    MetaProgression.markExplainerSeen(id)
end

function FirstEncounter.cardFor(id)
    if type(id) ~= "string" then return nil end
    if CHROMA_CARDS[id] then
        local c = CHROMA_CARDS[id]
        return { title = c.title, color = c.color, lines = c.lines, atlasTab = c.atlasTab }
    end
    local name = id:match("^artifact:(.+)$")
    if name then
        local entry = AtlasData.artifactByName(name)
        if not entry then return nil end
        return {
            title = entry.name,
            color = entry.color,
            lines = { entry.principle, entry.effect, entry.tell },
            atlasTab = "artifacts",
        }
    end
    return nil
end

function FirstEncounter.onArtifact(artifactType)
    if type(artifactType) ~= "string" then return end
    local id = "artifact:" .. artifactType:upper()
    if not FirstEncounter.shouldTeach(id) then return end
    local card = FirstEncounter.cardFor(id)
    if not card then return end           -- unknown artifact: skip, no crash
    toastQueue[#toastQueue + 1] = card
    if #toastQueue == 1 then toastTimer = Config.teaching.toastSeconds end
    FirstEncounter.markTaught(id)          -- toast marks on enqueue (auto-times-out)
end

function FirstEncounter.hasToast() return #toastQueue > 0 end
function FirstEncounter.peekToast() return toastQueue[1] end

function FirstEncounter.dismissToast()
    if #toastQueue == 0 then return end
    table.remove(toastQueue, 1)
    toastTimer = (#toastQueue > 0) and Config.teaching.toastSeconds or 0
end

function FirstEncounter.update(dt)
    if #toastQueue == 0 then return end
    toastTimer = toastTimer - dt
    if toastTimer <= 0 then FirstEncounter.dismissToast() end
end

function FirstEncounter.resetAll()
    toastQueue = {}
    toastTimer = 0
end

return FirstEncounter
