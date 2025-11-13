-- PlayerCombat.lua
-- Handles player combat: auto-fire, projectile management, targeting
-- Extracted from Player.lua for better separation of concerns

local PlayerCombat = {}

-- Constants
local SCREEN_WIDTH = 1920
local SCREEN_HEIGHT = 1080

-- Find nearest enemy to player (for auto-targeting)
function PlayerCombat.findNearestEnemy(player, enemies)
    local centerX = player.x + player.width / 2
    local centerY = player.y + player.height / 2

    local nearestEnemy = nil
    local nearestDistance = math.huge

    if enemies then
        for _, enemy in ipairs(enemies) do
            if not enemy.dead then
                local dx = enemy.x + enemy.width / 2 - centerX
                local dy = enemy.y + enemy.height / 2 - centerY
                local distance = math.sqrt(dx * dx + dy * dy)

                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestEnemy = enemy
                end
            end
        end
    end

    return nearestEnemy
end

-- Auto-fire at nearest enemy (Vampire Survivors style)
function PlayerCombat.autoFire(player, enemies)
    if not player.weapon then
        return
    end

    -- Find nearest enemy
    local nearestEnemy = PlayerCombat.findNearestEnemy(player, enemies)

    -- Store for visual indicator
    player.nearestEnemy = nearestEnemy

    -- Auto-fire at nearest enemy
    if nearestEnemy then
        local centerX = player.x + player.width / 2
        local centerY = player.y + player.height / 2
        local targetX = nearestEnemy.x + nearestEnemy.width / 2
        local targetY = nearestEnemy.y + nearestEnemy.height / 2

        local projectiles = player.weapon:fire(centerX, centerY, targetX, targetY)
        if projectiles then
            -- Apply artifact transformations to projectiles
            projectiles = PlayerCombat.applyArtifactEffects(player, projectiles, targetX, targetY, enemies)

            for _, proj in ipairs(projectiles) do
                table.insert(player.projectiles, proj)
            end
        end
    end
end

-- Apply artifact effects to projectiles when they're created
function PlayerCombat.applyArtifactEffects(player, projectiles, targetX, targetY, enemies)
    local ArtifactManager = require("src.systems.ArtifactManager")
    local ColorSystem = require("src.systems.ColorSystem")
    local dominantColor = ColorSystem.getDominantColor()

    if not dominantColor then
        return projectiles
    end

    local centerX = player.x + player.width / 2
    local centerY = player.y + player.height / 2

    -- Apply PRISM effects (splitting, orbiting, etc.)
    if ArtifactManager.getLevel("PRISM") > 0 then
        local PrismArtifact = require("src.artifacts.PrismArtifact")
        local prismLevel = ArtifactManager.getLevel("PRISM")
        projectiles = PrismArtifact.apply(projectiles, prismLevel, dominantColor, targetX, targetY, player)
    end

    -- Apply MIRROR effects (duplication, echoing, etc.)
    if ArtifactManager.getLevel("MIRROR") > 0 then
        local MirrorArtifact = require("src.artifacts.MirrorArtifact")
        local mirrorLevel = ArtifactManager.getLevel("MIRROR")
        projectiles = MirrorArtifact.apply(projectiles, mirrorLevel, dominantColor, player)
    end

    -- Apply LENS effects (merging, enlarging, pull, etc.)
    if ArtifactManager.getLevel("LENS") > 0 then
        local LensArtifact = require("src.artifacts.LensArtifact")
        local lensLevel = ArtifactManager.getLevel("LENS")
        projectiles = LensArtifact.apply(projectiles, lensLevel, dominantColor)
    end

    -- Apply DIFFUSION effects (clouds, links, etc.)
    if ArtifactManager.getLevel("DIFFUSION") > 0 then
        local DiffusionArtifact = require("src.artifacts.DiffusionArtifact")
        local diffusionLevel = ArtifactManager.getLevel("DIFFUSION")
        projectiles = DiffusionArtifact.apply(projectiles, diffusionLevel, dominantColor)
    end

    return projectiles
end

-- Update projectile artifact effects (per-frame)
function PlayerCombat.updateProjectileArtifactEffects(proj, enemies, dt, player)
    local ArtifactManager = require("src.systems.ArtifactManager")
    local ColorSystem = require("src.systems.ColorSystem")
    local dominantColor = ColorSystem.getDominantColor()

    if not dominantColor then
        return
    end

    -- LENS artifact: gravitational pull, time delays, etc.
    if ArtifactManager.getLevel("LENS") > 0 then
        local LensArtifact = require("src.artifacts.LensArtifact")
        LensArtifact.update({proj}, enemies, dt, dominantColor)
    end

    -- MIRROR artifact: echo bounces
    if ArtifactManager.getLevel("MIRROR") > 0 then
        local MirrorArtifact = require("src.artifacts.MirrorArtifact")
        MirrorArtifact.update({proj}, enemies, dt, dominantColor)
    end

    -- PRISM artifact: orbiting projectiles, lasers
    if ArtifactManager.getLevel("PRISM") > 0 then
        local PrismArtifact = require("src.artifacts.PrismArtifact")
        PrismArtifact.update({proj}, enemies, dt, dominantColor, player)
    end

    -- DIFFUSION artifact: drain clouds
    if ArtifactManager.getLevel("DIFFUSION") > 0 then
        local DiffusionArtifact = require("src.artifacts.DiffusionArtifact")
        DiffusionArtifact.update({proj}, enemies, dt, dominantColor)
    end
end

-- Update all player projectiles
function PlayerCombat.updateProjectiles(player, dt, enemies)
    for i = #player.projectiles, 1, -1 do
        local proj = player.projectiles[i]

        -- Initialize properties if they don't exist
        if not proj.trail then
            proj.trail = {}
            proj.trailLength = 8
        end
        if not proj.age then
            proj.age = 0
        end
        if not proj.size then
            proj.size = 4
        end
        if not proj.distanceTraveled then
            proj.distanceTraveled = 0
        end

        -- Increment age for animations
        proj.age = proj.age + dt

        -- Update artifact effects (LENS gravitational pull, etc.)
        PlayerCombat.updateProjectileArtifactEffects(proj, enemies, dt, player)

        -- Add current position to trail
        table.insert(proj.trail, 1, {x = proj.x, y = proj.y})
        if #proj.trail > proj.trailLength then
            table.remove(proj.trail)
        end

        -- Calculate movement distance
        local oldX, oldY = proj.x, proj.y

        -- Move projectile
        if proj.vx and proj.vy then
            proj.x = proj.x + proj.vx * dt
            proj.y = proj.y + proj.vy * dt
        else
            proj.y = proj.y - proj.speed * dt
        end

        -- Track distance for split mechanic
        if proj.canSplit then
            local dx = proj.x - oldX
            local dy = proj.y - oldY
            proj.distanceTraveled = proj.distanceTraveled + math.sqrt(dx * dx + dy * dy)

            -- Check if should split
            if not proj.hasSplit and proj.distanceTraveled >= proj.splitDistance then
                proj.hasSplit = true
                PlayerCombat.splitProjectile(player, proj, i)
                -- Remove original after splitting
                table.remove(player.projectiles, i)
                goto continue
            end
        end

        -- Handle screen edge collisions
        local shouldRemove = false

        -- BOUNCE attribute: Bounce off screen edges
        if proj.canBounce and proj.bounces and proj.bounces > 0 then
            local bounced = false

            if proj.x < 0 then
                proj.x = 0
                proj.vx = -proj.vx
                bounced = true
            elseif proj.x > SCREEN_WIDTH then
                proj.x = SCREEN_WIDTH
                proj.vx = -proj.vx
                bounced = true
            end

            if proj.y < 0 then
                proj.y = 0
                proj.vy = -proj.vy
                bounced = true
            elseif proj.y > SCREEN_HEIGHT then
                proj.y = SCREEN_HEIGHT
                proj.vy = -proj.vy
                bounced = true
            end

            if bounced then
                proj.bounces = proj.bounces - 1
                if proj.bounces <= 0 then
                    shouldRemove = true
                end
            end
        else
            -- Non-bouncing projectiles: Remove when off-screen
            if proj.y < -10 or proj.y > SCREEN_HEIGHT + 10 or proj.x < -10 or proj.x > SCREEN_WIDTH + 10 then
                shouldRemove = true
            end
        end

        if shouldRemove then
            table.remove(player.projectiles, i)
        end

        ::continue::
    end
end

-- Split a projectile into multiple smaller projectiles
function PlayerCombat.splitProjectile(player, parentProj, index)
    -- Spawn PRISM split VFX
    local VFXLibrary = require("src.systems.VFXLibrary")
    VFXLibrary.spawnArtifactEffect("PRISM", parentProj.x, parentProj.y)

    -- Create split projectiles in a spread pattern
    local splitCount = parentProj.splitCount or 2
    local angleStep = (math.pi / 6) / (splitCount - 1)  -- ±15° spread
    local baseAngle = math.atan(parentProj.vy, parentProj.vx)

    for i = 1, splitCount do
        local offset = (i - 1) / (splitCount - 1) - 0.5  -- -0.5 to 0.5
        local angle = baseAngle + offset * (math.pi / 6)  -- ±15°

        local speed = math.sqrt(parentProj.vx * parentProj.vx + parentProj.vy * parentProj.vy)

        -- Create new projectile inheriting all attributes
        local newProj = {
            x = parentProj.x,
            y = parentProj.y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            damage = parentProj.damage,
            type = parentProj.type,
            size = parentProj.size * 0.8,  -- Slightly smaller
            age = 0,
            trail = {},
            trailLength = parentProj.trailLength,

            -- Inherit RGB attributes
            rCount = parentProj.rCount,
            gCount = parentProj.gCount,
            bCount = parentProj.bCount,
            shape = parentProj.shape,
            color = parentProj.color,

            -- Inherit BOUNCE
            canBounce = parentProj.canBounce,
            bounces = parentProj.bounces,

            -- Inherit PIERCE
            canPierce = parentProj.canPierce,
            pierce = parentProj.pierce,
            hitCount = 0,
            hitEnemies = {},

            -- NO more splits (already split)
            canSplit = false,
            splitCount = 0,
            hasSplit = true
        }

        table.insert(player.projectiles, newProj)
    end
end

-- Get aim angle to nearest enemy
function PlayerCombat.getAimAngle(player)
    if player.nearestEnemy then
        local centerX = player.x + player.width / 2
        local centerY = player.y + player.height / 2
        local targetX = player.nearestEnemy.x + player.nearestEnemy.width / 2
        local targetY = player.nearestEnemy.y + player.nearestEnemy.height / 2
        return math.atan(targetY - centerY, targetX - centerX)
    end
    return 0
end

return PlayerCombat
