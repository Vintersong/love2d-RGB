local LightningEffect = {}

LightningEffect.bolts = {}
LightningEffect.DURATION = 0.22
LightningEffect.COLOR = {0.8, 0.9, 1.0}
LightningEffect.MAX_DISPLACEMENT = 96
LightningEffect.NUM_SEGMENTS = 15
LightningEffect.CHAIN_RANGE = 150
LightningEffect.MAX_CHAINS = 3

local function generateSegments(startX, startY, endX, endY, maxDisplacement, numSegments)
    local segments = {}
    local points = {{x = startX, y = startY}}
    for i = 1, numSegments do
        local progress = i / numSegments
        local cx = startX + (endX - startX) * progress
        local cy = startY + (endY - startY) * progress
        if i < numSegments then
            local scale = 1 - (progress * 0.75)
            cx = cx + (math.random() * 2 - 1) * maxDisplacement * scale
            cy = cy + (math.random() * 2 - 1) * maxDisplacement * scale
        end
        table.insert(points, {x = cx, y = cy})
    end
    points[#points] = {x = endX, y = endY}

    for i = 1, #points - 1 do
        table.insert(segments, {
            x1 = points[i].x, y1 = points[i].y,
            x2 = points[i + 1].x, y2 = points[i + 1].y,
            thickness = math.random(1, 4),
        })
    end
    return segments
end

function LightningEffect.trigger(startX, startY, endX, endY, opts)
    opts = opts or {}
    local bolt = {
        segments = generateSegments(
            startX, startY, endX, endY,
            opts.maxDisplacement or LightningEffect.MAX_DISPLACEMENT,
            opts.numSegments or LightningEffect.NUM_SEGMENTS
        ),
        timer = 0,
        duration = opts.duration or LightningEffect.DURATION,
        color = opts.color or LightningEffect.COLOR,
    }
    table.insert(LightningEffect.bolts, bolt)
end

-- Fire lightning with chaining: damages enemies along path, chains to nearby ones
-- Returns array of {enemy, damage} pairs that were hit
function LightningEffect.fireChain(startX, startY, targetX, targetY, damage, enemies, chainRange, maxChains)
    chainRange = chainRange or LightningEffect.CHAIN_RANGE
    maxChains = maxChains or LightningEffect.MAX_CHAINS

    local hits = {}
    local hitSet = {}
    local cx, cy = startX, startY
    local tx, ty = targetX, targetY

    for chain = 0, maxChains do
        -- Trigger visual bolt
        LightningEffect.trigger(cx, cy, tx, ty)

        -- Find enemies along or near the bolt path and damage them
        local bestEnemy = nil
        local bestDist = math.huge
        if enemies then
            for _, enemy in ipairs(enemies) do
                if not enemy.dead and not hitSet[enemy] then
                    local ex = enemy.x + (enemy.width or 0) / 2
                    local ey = enemy.y + (enemy.height or 0) / 2
                    local dist = math.sqrt((ex - tx) * (ex - tx) + (ey - ty) * (ey - ty))
                    if dist < 60 then
                        table.insert(hits, {enemy = enemy, damage = damage})
                        hitSet[enemy] = true
                    end
                end
            end
        end

        -- Find next chain target
        if chain < maxChains and enemies then
            for _, enemy in ipairs(enemies) do
                if not enemy.dead and not hitSet[enemy] then
                    local ex = enemy.x + (enemy.width or 0) / 2
                    local ey = enemy.y + (enemy.height or 0) / 2
                    local dist = math.sqrt((ex - tx) * (ex - tx) + (ey - ty) * (ey - ty))
                    if dist < chainRange and dist < bestDist then
                        bestDist = dist
                        bestEnemy = enemy
                    end
                end
            end
        end

        if not bestEnemy then break end

        cx, cy = tx, ty
        tx = bestEnemy.x + (bestEnemy.width or 0) / 2
        ty = bestEnemy.y + (bestEnemy.height or 0) / 2
    end

    return hits
end

function LightningEffect.update(dt)
    for i = #LightningEffect.bolts, 1, -1 do
        local bolt = LightningEffect.bolts[i]
        bolt.timer = bolt.timer + dt
        if bolt.timer >= bolt.duration then
            table.remove(LightningEffect.bolts, i)
        end
    end
end

function LightningEffect.draw()
    for _, bolt in ipairs(LightningEffect.bolts) do
        local alpha = math.max(0, 1 - (bolt.timer / bolt.duration))
        if alpha <= 0 then goto continue end

        love.graphics.setColor(bolt.color[1], bolt.color[2], bolt.color[3], alpha)
        for _, seg in ipairs(bolt.segments) do
            love.graphics.setLineWidth(seg.thickness * alpha)
            love.graphics.line(seg.x1, seg.y1, seg.x2, seg.y2)
        end

        ::continue::
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function LightningEffect.isActive()
    return #LightningEffect.bolts > 0
end

return LightningEffect
