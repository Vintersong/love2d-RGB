-- CollisionSystem.lua
-- Centralized collision detection using bump.lua spatial hash
-- Replaces manual distance checks with efficient spatial queries

-- Load bump.lua directly (directory name has dots which confuses require)
local bumpPath = "libs/bump.lua-master/bump.lua"
local bump = love.filesystem.load(bumpPath)()

local CollisionSystem = {}

-- Bump world instance
CollisionSystem.world = nil

-- Collision filters
local function playerFilter(item, other)
    -- Player collides with enemies and powerups
    if other.type == "enemy" or other.type == "powerup" or other.type == "xpOrb" then
        return "cross" -- Allow overlap, we handle it manually
    end
    return nil -- No collision response
end

local function projectileFilter(item, other)
    -- Projectiles collide with enemies and bosses
    if other.type == "enemy" or other.type == "boss" then
        return "cross"
    end
    return nil
end

local function enemyProjectileFilter(item, other)
    -- Enemy projectiles collide with player
    if other.type == "player" then
        return "cross"
    end
    return nil
end

local function pickupFilter(item, other)
    -- Pickups (powerups, xpOrbs) collide with player
    if other.type == "player" then
        return "cross"
    end
    return nil
end

-- Initialize the collision world
function CollisionSystem.init(cellSize)
    cellSize = cellSize or 128 -- Larger cells for performance with many entities
    CollisionSystem.world = bump.newWorld(cellSize)
    print("[CollisionSystem] Initialized with cell size: " .. cellSize)
end

-- Register an entity in the collision world
function CollisionSystem.add(entity, type)
    if not CollisionSystem.world then
        error("[CollisionSystem] World not initialized! Call CollisionSystem.init() first.")
    end

    entity.type = type -- Tag entity with type

    -- Add to world with AABB (Axis-Aligned Bounding Box)
    CollisionSystem.world:add(entity, entity.x, entity.y, entity.width, entity.height)
end

-- Remove an entity from the collision world
function CollisionSystem.remove(entity)
    if not CollisionSystem.world then return end

    if CollisionSystem.world:hasItem(entity) then
        CollisionSystem.world:remove(entity)
    end
end

-- Update entity position in the collision world
function CollisionSystem.update(entity, newX, newY)
    if not CollisionSystem.world then return end

    if CollisionSystem.world:hasItem(entity) then
        -- Update position (width/height stay the same)
        CollisionSystem.world:update(entity, newX, newY)
    end
end

-- Check collisions between player and enemies (returns list of colliding enemies)
function CollisionSystem.checkPlayerEnemyCollisions(player)
    if not CollisionSystem.world or not CollisionSystem.world:hasItem(player) then
        return {}
    end

    local items, len = CollisionSystem.world:queryRect(
        player.x,
        player.y,
        player.width,
        player.height,
        function(item)
            return item.type == "enemy" and not item.dead and not item.inactive
        end
    )

    return items
end

-- Check collisions between player and powerups
function CollisionSystem.checkPlayerPowerupCollisions(player, powerups)
    if not CollisionSystem.world or not CollisionSystem.world:hasItem(player) then
        return {}
    end

    local collectedPowerups = {}

    local items, len = CollisionSystem.world:queryRect(
        player.x,
        player.y,
        player.width,
        player.height,
        function(item)
            return item.type == "powerup"
        end
    )

    return items
end

-- Check collisions between player and XP orbs
function CollisionSystem.checkPlayerXPCollisions(player)
    if not CollisionSystem.world or not CollisionSystem.world:hasItem(player) then
        return {}
    end

    local items, len = CollisionSystem.world:queryRect(
        player.x,
        player.y,
        player.width,
        player.height,
        function(item)
            return item.type == "xpOrb"
        end
    )

    return items
end

-- Check collisions between projectile and enemies
function CollisionSystem.checkProjectileEnemyCollisions(projectile, enemies)
    if not CollisionSystem.world then
        return {}
    end

    -- Query area around projectile (projectiles are circles, approximate with square)
    local radius = projectile.radius or 5
    local items, len = CollisionSystem.world:queryRect(
        projectile.x - radius,
        projectile.y - radius,
        radius * 2,
        radius * 2,
        function(item)
            return item.type == "enemy" and not item.dead and not item.inactive
        end
    )

    -- Filter by actual circle collision
    local hits = {}
    for _, enemy in ipairs(items) do
        -- Circle-to-AABB collision check
        local dx = projectile.x - math.max(enemy.x, math.min(projectile.x, enemy.x + enemy.width))
        local dy = projectile.y - math.max(enemy.y, math.min(projectile.y, enemy.y + enemy.height))
        local distSq = dx * dx + dy * dy

        if distSq < (radius * radius) then
            table.insert(hits, enemy)
        end
    end

    return hits
end

-- Check collision between projectile and boss
function CollisionSystem.checkProjectileBossCollision(projectile, boss)
    if not boss or boss.invulnerable then
        return false
    end

    -- Circle-to-circle collision (boss is circular)
    local dx = projectile.x - boss.x
    local dy = projectile.y - boss.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local radius = projectile.radius or 5

    return distance < (boss.size + radius)
end

-- Check collision between enemy projectile and player (circle-to-AABB)
function CollisionSystem.checkEnemyProjectilePlayerCollision(enemyProj, player)
    -- Circle-to-AABB collision
    local dx = enemyProj.x - math.max(player.x, math.min(enemyProj.x, player.x + player.width))
    local dy = enemyProj.y - math.max(player.y, math.min(enemyProj.y, player.y + player.height))
    local distSq = dx * dx + dy * dy
    local radius = enemyProj.radius or 8

    return distSq < (radius * radius)
end

-- Check collision between boss projectile and player
function CollisionSystem.checkBossProjectilePlayerCollision(bossProj, player)
    -- Circle-to-circle collision (approximate player as circle)
    local dx = bossProj.x - (player.x + player.width / 2)
    local dy = bossProj.y - (player.y + player.height / 2)
    local distance = math.sqrt(dx * dx + dy * dy)
    local playerRadius = player.width / 2
    local projRadius = 8 -- Boss projectile radius

    return distance < (playerRadius + projRadius)
end

-- Get all items in the world (for debug visualization)
function CollisionSystem.getAllItems()
    if not CollisionSystem.world then return {} end
    return CollisionSystem.world:getItems()
end

-- Get number of items in the world
function CollisionSystem.getItemCount()
    if not CollisionSystem.world then return 0 end
    return CollisionSystem.world:countItems()
end

-- Clear the world (useful for resets)
function CollisionSystem.clear()
    if CollisionSystem.world then
        -- Remove all items
        for _, item in ipairs(CollisionSystem.world:getItems()) do
            CollisionSystem.world:remove(item)
        end
    end
end

-- Debug: Draw collision boxes
function CollisionSystem.drawDebug()
    if not CollisionSystem.world then return end

    love.graphics.setColor(0, 1, 0, 0.3) -- Green transparent
    for _, item in ipairs(CollisionSystem.world:getItems()) do
        local x, y, w, h = CollisionSystem.world:getRect(item)
        love.graphics.rectangle("line", x, y, w, h)

        -- Draw type label
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(item.type or "?", x, y - 12, 0, 0.5, 0.5)
    end
end

return CollisionSystem
