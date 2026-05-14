-- EnemyPool.lua
-- Recycled enemy object pool helpers.

local EnemyPool = {
    pool = {}
}

function EnemyPool.take()
    return table.remove(EnemyPool.pool)
end

function EnemyPool.release(enemy)
    table.insert(EnemyPool.pool, enemy)
end

function EnemyPool.size()
    return #EnemyPool.pool
end

function EnemyPool.clear()
    EnemyPool.pool = {}
end

return EnemyPool
