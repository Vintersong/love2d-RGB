-- BehaviorSelector.lua
-- Shared behavior filtering, context building, and cooldown tracking.

local BehaviorSelector = {}

local function contains(list, value)
    if not list then return false end
    for _, item in ipairs(list) do
        if item == value then return true end
    end
    return false
end

local function validForMatches(validFor, entityKind)
    if validFor == "both" or validFor == entityKind then
        return true
    end
    if type(validFor) == "table" then
        return contains(validFor, entityKind)
    end
    return false
end

function BehaviorSelector.updateCooldowns(entity, dt)
    entity._behaviorCooldowns = entity._behaviorCooldowns or {}
    for id, cooldown in pairs(entity._behaviorCooldowns) do
        local nextCooldown = cooldown - dt
        entity._behaviorCooldowns[id] = nextCooldown > 0 and nextCooldown or nil
    end
end

function BehaviorSelector.isOnCooldown(entity, behavior)
    return entity._behaviorCooldowns and entity._behaviorCooldowns[behavior.id] ~= nil
end

function BehaviorSelector.setCooldown(entity, behavior)
    if not behavior.cooldown or behavior.cooldown <= 0 then
        return
    end
    entity._behaviorCooldowns = entity._behaviorCooldowns or {}
    entity._behaviorCooldowns[behavior.id] = behavior.cooldown
end

function BehaviorSelector.buildContext(entity, base)
    base = base or {}

    local player = base.player
    local playerX = base.playerX
    local playerY = base.playerY
    if player then
        playerX = playerX or (player.x + (player.width or 0) / 2)
        playerY = playerY or (player.y + (player.height or 0) / 2)
    end

    local entityX = entity.x + (entity.width or 0) / 2
    local entityY = entity.y + (entity.height or 0) / 2
    local dx = (playerX or entityX) - entityX
    local dy = (playerY or entityY) - entityY
    local distance = math.sqrt(dx * dx + dy * dy)

    local music = base.musicReactor
    local bass = base.bass or (music and music.bass) or 0
    local mids = base.mids
    if not mids and music then
        mids = ((music.midLow or 0) + (music.midHigh or 0)) / 2
    end
    mids = mids or 0
    local treble = base.treble
    if not treble and music then
        treble = ((music.treble or 0) + (music.presence or 0)) / 2
    end
    treble = treble or 0

    local currentHealth = entity.hp or entity.health
    local maxHealth = entity.maxHp or entity.maxHealth

    return {
        player = player,
        playerX = playerX or entityX,
        playerY = playerY or entityY,
        playerLevel = base.playerLevel or (player and player.level) or entity.playerLevel or 1,
        distanceToPlayer = base.distanceToPlayer or distance,
        healthPercent = base.healthPercent or ((maxHealth and maxHealth > 0 and currentHealth) and (currentHealth / maxHealth) or 1),
        enemyCount = base.enemyCount or 0,
        musicReactor = music,
        musicSection = base.musicSection or (music and music.currentSection) or "verse",
        bass = bass,
        mids = mids,
        treble = treble,
        energy = base.energy or (music and music.energy) or 0,
        beatIntensity = base.beatIntensity or (music and music.beatIntensity) or 0,
        formationRole = base.formationRole or entity.formationRole or (entity.formationData and entity.formationData.role),
        formationName = base.formationName or entity.formationName or (entity.formationData and entity.formationData.formation),
        gameTime = base.gameTime or 0,
        bossPhase = base.bossPhase or entity.phase,
        combatTime = base.combatTime or entity.combatTime or 0,
        enemyProjectiles = base.enemyProjectiles,
        bossProjectiles = base.bossProjectiles,
        scheduler = base.scheduler,
    }
end

function BehaviorSelector.filter(catalog, kind, entityKind, entity, context, options)
    options = options or {}
    local results = {}
    local allowedIds = options.allowedIds

    for _, behavior in ipairs(catalog or {}) do
        local allowedById = not allowedIds or allowedIds[behavior.id]
        if allowedById
            and behavior.kind == kind
            and validForMatches(behavior.validFor, entityKind)
            and not BehaviorSelector.isOnCooldown(entity, behavior)
            and (not behavior.canRun or behavior.canRun(entity, context)) then
            table.insert(results, behavior)
        end
    end

    return results
end

function BehaviorSelector.select(catalog, kind, entityKind, entity, context, options)
    local candidates = BehaviorSelector.filter(catalog, kind, entityKind, entity, context, options)
    local totalWeight = 0
    local weighted = {}

    for _, behavior in ipairs(candidates) do
        local weight = behavior.weight or 1
        if type(weight) == "function" then
            weight = weight(entity, context)
        end
        weight = math.max(0, weight or 0)
        if weight > 0 then
            totalWeight = totalWeight + weight
            table.insert(weighted, {behavior = behavior, weight = weight})
        end
    end

    if totalWeight <= 0 then
        return nil
    end

    local roll = math.random() * totalWeight
    local running = 0
    for _, entry in ipairs(weighted) do
        running = running + entry.weight
        if roll <= running then
            return entry.behavior
        end
    end

    return weighted[#weighted] and weighted[#weighted].behavior or nil
end

function BehaviorSelector.setMovement(entity, behavior, context)
    if not behavior then return end

    if entity._currentMovementBehavior and entity._currentMovementBehavior.id ~= behavior.id then
        local previous = entity._currentMovementBehavior
        if previous.exit then
            previous.exit(entity, context)
        end
        entity._currentMovementBehavior = nil
    end

    if not entity._currentMovementBehavior then
        entity._currentMovementBehavior = behavior
        if behavior.enter then
            behavior.enter(entity, context)
        end
    end
end

function BehaviorSelector.execute(entity, behavior, context)
    if not behavior then return nil end
    local result
    if behavior.execute then
        result = behavior.execute(entity, context)
    end
    BehaviorSelector.setCooldown(entity, behavior)
    return result
end

return BehaviorSelector
