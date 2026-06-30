-- MetaProgression.lua
-- Persistent profile data for the shell around runs: tutorials, discovered colors,
-- discovered artifacts, and simple run statistics.

local MetaProgression = {}
local Config = require("src.Config")

local FILE = "progression.lua"

local DEFAULT_PROFILE = {
    runs = 0,
    victories = 0,
    defeats = 0,
    bestLevel = 0,
    bestTime = 0,
    tutorialSeen = false,
    chroma = 0,
    unlocks = {
        colors = {},
        artifacts = {},
    },
    ownedArtifacts = {},
    artifactInvestment = {},
    artifactPurchases = 0,
    seenExplainers = {},
}

local profile = nil

local function deepcopy(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}
    for k, v in pairs(value) do
        out[deepcopy(k)] = deepcopy(v)
    end
    return out
end

profile = deepcopy(DEFAULT_PROFILE)

local function ensureProfileShape(data)
    local result = deepcopy(DEFAULT_PROFILE)
    if type(data) ~= "table" then
        return result
    end

    if type(data.runs) == "number" then result.runs = data.runs end
    if type(data.victories) == "number" then result.victories = data.victories end
    if type(data.defeats) == "number" then result.defeats = data.defeats end
    if type(data.bestLevel) == "number" then result.bestLevel = data.bestLevel end
    if type(data.bestTime) == "number" then result.bestTime = data.bestTime end
    if type(data.tutorialSeen) == "boolean" then result.tutorialSeen = data.tutorialSeen end
    if type(data.chroma) == "number" then
        result.chroma = math.max(0, math.floor(data.chroma))
    elseif type(data.shards) == "number" then
        -- Backwards compatibility for pre-Chroma saves.
        result.chroma = math.max(0, math.floor(data.shards))
    end

    if type(data.unlocks) == "table" then
        if type(data.unlocks.colors) == "table" then
            result.unlocks.colors = deepcopy(data.unlocks.colors)
        end
        if type(data.unlocks.artifacts) == "table" then
            result.unlocks.artifacts = deepcopy(data.unlocks.artifacts)
        end
    end

    if type(data.ownedArtifacts) == "table" then
        result.ownedArtifacts = {}
        for key, value in pairs(data.ownedArtifacts) do
            local artifactKey = type(key) == "string" and key:upper() or key
            if value == true then
                result.ownedArtifacts[artifactKey] = 1
            elseif type(value) == "number" then
                result.ownedArtifacts[artifactKey] = math.max(0, math.floor(value))
            end
        end
    end

    if type(data.artifactInvestment) == "table" then
        result.artifactInvestment = {}
        for key, value in pairs(data.artifactInvestment) do
            if type(value) == "number" then
                local artifactKey = type(key) == "string" and key:upper() or key
                result.artifactInvestment[artifactKey] = math.max(0, math.floor(value))
            end
        end
    end

    if type(data.artifactPurchases) == "number" then
        result.artifactPurchases = math.max(0, math.floor(data.artifactPurchases))
    else
        local inferredPurchases = 0
        for _, level in pairs(result.ownedArtifacts or {}) do
            inferredPurchases = inferredPurchases + math.max(0, math.floor(level or 0))
        end
        result.artifactPurchases = inferredPurchases
    end

    if type(data.seenExplainers) == "table" then
        result.seenExplainers = {}
        for key, value in pairs(data.seenExplainers) do
            if type(key) == "string" and value == true then
                result.seenExplainers[key] = true
            end
        end
    end

    return result
end

local function sortedKeys(map)
    local keys = {}
    for key, enabled in pairs(map or {}) do
        if enabled and enabled ~= 0 then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    return keys
end

local function serialize(value, indent)
    indent = indent or 0
    local kind = type(value)

    if kind == "number" or kind == "boolean" then
        return tostring(value)
    elseif kind == "string" then
        return string.format("%q", value)
    elseif kind ~= "table" then
        return "nil"
    end

    local pad = string.rep("    ", indent)
    local childPad = string.rep("    ", indent + 1)
    local parts = {"{\n"}

    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    for _, key in ipairs(keys) do
        local entry = value[key]
        local keyExpr
        if type(key) == "string" and key:match("^[%a_][%w_]*$") then
            keyExpr = key
        else
            keyExpr = "[" .. serialize(key, indent + 1) .. "]"
        end
        parts[#parts + 1] = childPad .. keyExpr .. " = " .. serialize(entry, indent + 1) .. ",\n"
    end

    parts[#parts + 1] = pad .. "}"
    return table.concat(parts)
end

function MetaProgression.load()
    if not (love and love.filesystem and love.filesystem.getInfo(FILE)) then
        profile = ensureProfileShape(nil)
        return profile
    end

    local chunk = love.filesystem.load(FILE)
    if not chunk then
        profile = ensureProfileShape(nil)
        return profile
    end

    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then
        print("[MetaProgression] Ignoring corrupt profile file")
        profile = ensureProfileShape(nil)
        return profile
    end

    profile = ensureProfileShape(data)
    print(string.format(
        "[MetaProgression] Loaded profile (runs=%d, victories=%d, tutorialSeen=%s)",
        profile.runs,
        profile.victories,
        tostring(profile.tutorialSeen)
    ))
    return profile
end

function MetaProgression.save()
    if not (love and love.filesystem) then return end

    local serialized = "-- Auto-generated by MetaProgression.save(); profile and collection data.\nreturn "
        .. serialize(profile, 0)
        .. "\n"

    local ok, err = pcall(love.filesystem.write, FILE, serialized)
    if not ok then
        print("[MetaProgression] Failed to save: " .. tostring(err))
    end
end

local function getArtifactInvestment(artifactCosts)
    local total = 0
    local investedByArtifact = profile.artifactInvestment or {}

    for artifactType in pairs(profile.ownedArtifacts or {}) do
        local ledgerValue = math.max(0, math.floor(investedByArtifact[artifactType] or 0))
        total = total + ledgerValue
    end
    return math.floor(total)
end

function MetaProgression.getArtifactRefundPreview(artifactCosts, penaltyRate)
    penaltyRate = math.max(0, math.min(1, tonumber(penaltyRate) or 0))
    local invested = getArtifactInvestment(artifactCosts)
    local penalty = math.floor(invested * penaltyRate)
    return {
        invested = invested,
        penalty = penalty,
        refund = math.max(0, invested - penalty),
        currentChroma = MetaProgression.getChroma(),
    }
end

function MetaProgression.reset(options)
    options = options or {}
    local preview = MetaProgression.getArtifactRefundPreview(options.artifactCosts, options.penaltyRate)
    local carryChroma = options.refundArtifacts and (preview.currentChroma + preview.refund) or 0

    local nextProfile = ensureProfileShape(nil)
    for key in pairs(profile) do
        profile[key] = nil
    end
    for key, value in pairs(nextProfile) do
        profile[key] = value
    end
    profile.chroma = carryChroma
    MetaProgression.save()
    preview.newBalance = MetaProgression.getChroma()
    print(string.format(
        "[MetaProgression] Reset profile: invested=%d refund=%d penalty=%d balance=%d",
        preview.invested,
        preview.refund,
        preview.penalty,
        preview.newBalance
    ))
    return preview
end

function MetaProgression.getProfile()
    return profile
end

function MetaProgression.hasSeenTutorial()
    return profile.tutorialSeen == true
end

function MetaProgression.markTutorialSeen()
    if not profile.tutorialSeen then
        profile.tutorialSeen = true
        MetaProgression.save()
    end
end

function MetaProgression.hasSeenExplainer(id)
    return type(id) == "string" and profile.seenExplainers[id] == true
end

function MetaProgression.markExplainerSeen(id)
    if type(id) ~= "string" then return end
    if not profile.seenExplainers[id] then
        profile.seenExplainers[id] = true
        MetaProgression.save()
    end
end

function MetaProgression.clearExplainers()
    profile.seenExplainers = {}
    MetaProgression.save()
end

function MetaProgression.getUnlockedColors()
    return sortedKeys(profile.unlocks.colors)
end

function MetaProgression.getUnlockedArtifacts()
    return sortedKeys(profile.unlocks.artifacts)
end

function MetaProgression.getOwnedArtifacts()
    return sortedKeys(profile.ownedArtifacts)
end

function MetaProgression.getArtifactLevel(artifactType)
    artifactType = type(artifactType) == "string" and artifactType:upper() or artifactType
    return math.max(0, math.floor(profile.ownedArtifacts[artifactType] or 0))
end

function MetaProgression.isArtifactOwned(artifactType)
    return MetaProgression.getArtifactLevel(artifactType) > 0
end

function MetaProgression.isArtifactUnlocked(artifactType)
    return MetaProgression.getArtifactLevel(artifactType) > 0
end

function MetaProgression.getChroma()
    return math.max(0, math.floor(profile.chroma or 0))
end

function MetaProgression.getArtifactPurchaseCount()
    return math.max(0, math.floor(profile.artifactPurchases or 0))
end

function MetaProgression.awardChroma(amount)
    amount = math.max(0, math.floor(amount or 0))
    if amount <= 0 then
        return 0
    end

    profile.chroma = MetaProgression.getChroma() + amount
    MetaProgression.save()
    return amount
end

function MetaProgression.spendChroma(amount)
    amount = math.max(0, math.floor(amount or 0))
    if amount <= 0 then
        return true
    end

    if MetaProgression.getChroma() < amount then
        return false, "insufficient_chroma"
    end

    profile.chroma = MetaProgression.getChroma() - amount
    MetaProgression.save()
    return true
end

function MetaProgression.getNextArtifactCost(artifactType, baseCost)
    local level = MetaProgression.getArtifactLevel(artifactType)
    baseCost = math.max(0, math.floor(baseCost or 0))
    local purchases = MetaProgression.getArtifactPurchaseCount()
    local globalMultiplier = 1 + purchases * 0.25 + purchases * purchases * 0.03
    return math.max(1, math.floor(baseCost * (level + 1) * globalMultiplier + 0.5))
end

function MetaProgression.purchaseArtifactLevel(artifactType, baseCost, maxLevel)
    artifactType = type(artifactType) == "string" and artifactType:upper() or nil
    if not artifactType then
        return false, "invalid_artifact"
    end

    local currentLevel = MetaProgression.getArtifactLevel(artifactType)
    maxLevel = math.max(1, math.floor(maxLevel or 1))
    if currentLevel >= maxLevel then
        return false, "max_level"
    end

    local cost = MetaProgression.getNextArtifactCost(artifactType, baseCost)
    local ok, reason = MetaProgression.spendChroma(cost)
    if not ok then
        return false, reason
    end

    local newLevel = currentLevel + 1
    profile.ownedArtifacts[artifactType] = newLevel
    profile.artifactPurchases = MetaProgression.getArtifactPurchaseCount() + 1
    profile.artifactInvestment = profile.artifactInvestment or {}
    profile.artifactInvestment[artifactType] = math.max(0, math.floor(profile.artifactInvestment[artifactType] or 0)) + cost
    MetaProgression.save()
    return true, nil, newLevel, cost
end

function MetaProgression.purchaseArtifact(artifactType, cost)
    return MetaProgression.purchaseArtifactLevel(artifactType, cost, 1)
end

function MetaProgression.getCollectionCounts()
    return {
        colors = #MetaProgression.getUnlockedColors(),
        artifacts = #MetaProgression.getUnlockedArtifacts(),
        ownedArtifacts = #MetaProgression.getOwnedArtifacts(),
    }
end

local function addUnlock(map, value)
    if not value or value == "" then return false end
    if map[value] then
        return false
    end
    map[value] = true
    return true
end

local function calculateRunShardReward(summary)
    local enemyKills = math.max(0, math.floor(summary.enemyKillCount or 0))
    local level = math.max(0, math.floor(summary.level or 0))
    local gameTime = math.max(0, tonumber(summary.gameTime or summary.time or 0) or 0)
    local outcome = summary.outcome or "defeat"

    local reward = 12
    reward = reward + math.floor(enemyKills * 0.65)
    reward = reward + math.max(0, level - 1) * 4
    reward = reward + math.floor(gameTime / 30) * 3

    if outcome == "victory" then
        reward = reward + 35
    end

    return math.max(0, reward)
end

function MetaProgression.recordRun(summary)
    summary = summary or {}

    profile.runs = profile.runs + 1

    local outcome = summary.outcome or "defeat"
    if outcome == "victory" then
        profile.victories = profile.victories + 1
    else
        profile.defeats = profile.defeats + 1
    end

    if type(summary.level) == "number" and summary.level > profile.bestLevel then
        profile.bestLevel = summary.level
    end

    local runTime = summary.gameTime or summary.time
    if type(runTime) == "number" and runTime > 0 then
        if profile.bestTime <= 0 or runTime > profile.bestTime then
            profile.bestTime = runTime
        end
    end

    local newColors = {}
    local newArtifacts = {}
    local chromaEarned = math.max(0, math.floor(summary.chromaEarned or summary.shardsEarned or calculateRunShardReward(summary)))

    local colorHistory = summary.colorHistory or {}
    for _, colorCode in ipairs(colorHistory) do
        local colorName = colorCode
        if type(colorName) == "string" and #colorName == 1 then
            local ColorSystem = require("src.gameplay.ColorSystem")
            colorName = ColorSystem.getColorName(colorName)
            if colorName ~= "Unknown" then
                colorName = colorName:upper()
            else
                colorName = nil
            end
        elseif type(colorName) == "string" then
            colorName = colorName:upper()
        end

        if addUnlock(profile.unlocks.colors, colorName) then
            newColors[#newColors + 1] = colorName
        end
    end

    local artifacts = summary.artifacts or {}
    for _, artifact in ipairs(artifacts) do
        local artifactType = artifact
        if type(artifact) == "table" then
            artifactType = artifact.type or artifact.name
        end
        if type(artifactType) == "string" then
            artifactType = artifactType:upper()
            if addUnlock(profile.unlocks.artifacts, artifactType) then
                newArtifacts[#newArtifacts + 1] = artifactType
            end
        end
    end

    MetaProgression.save()
    if chromaEarned > 0 then
        profile.chroma = MetaProgression.getChroma() + chromaEarned
        MetaProgression.save()
    end

    return {
        newColors = newColors,
        newArtifacts = newArtifacts,
        chromaEarned = chromaEarned,
        chromaBalance = MetaProgression.getChroma(),
        -- Legacy keys kept for older UI callers.
        shardsEarned = chromaEarned,
        shardBalance = MetaProgression.getChroma(),
    }
end

-- Legacy aliases kept so older call sites continue to work while the UI moves to Chroma naming.
MetaProgression.getShards = MetaProgression.getChroma
MetaProgression.awardShards = MetaProgression.awardChroma
MetaProgression.spendShards = MetaProgression.spendChroma

return MetaProgression
