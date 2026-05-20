local ProjectileScheduler = {}

ProjectileScheduler.queue = {}
ProjectileScheduler.MAX_QUEUE = 256

function ProjectileScheduler.schedule(delay, projectileData)
    if #ProjectileScheduler.queue >= ProjectileScheduler.MAX_QUEUE then
        return
    end
    table.insert(ProjectileScheduler.queue, {
        delay = delay,
        data = projectileData,
    })
end

function ProjectileScheduler.update(dt, player)
    if not player or #ProjectileScheduler.queue == 0 then return end

    for i = #ProjectileScheduler.queue, 1, -1 do
        local entry = ProjectileScheduler.queue[i]
        entry.delay = entry.delay - dt
        if entry.delay <= 0 then
            table.insert(player.projectiles, entry.data)
            
            -- O(1) removal: swap with last element and nil the end
            local lastIndex = #ProjectileScheduler.queue
            ProjectileScheduler.queue[i] = ProjectileScheduler.queue[lastIndex]
            ProjectileScheduler.queue[lastIndex] = nil
        end
    end
end

function ProjectileScheduler.clear()
    ProjectileScheduler.queue = {}
end

return ProjectileScheduler
