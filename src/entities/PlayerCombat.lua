-- PlayerCombat.lua
-- Handles player combat: auto-fire, projectile management, targeting
-- Extracted from Player.lua for better separation of concerns

local PlayerCombat = {}
local MathUtils = require("src.systems.MathUtils")
local GameConfig = require("src.systems.GameConfig")
local Config = require("src.Config")

local function getCombatState(player)
    player.combatState = player.combatState or {
        nearestEnemy = player.nearestEnemy,
        projectiles = player.projectiles or {}
    }
    player.combatState.projectiles = player.combatState.projectiles or player.projectiles or {}
    player.projectiles = player.combatState.projectiles  -- Compatibility shim
    return player.combatState
end

local BOSS_PRIORITY_RANGE = 1000  -- Auto-target boss if within this range (covers most of screen)

local function getScreenSize()
    local w, h = GameConfig.getScreenSize()
    return w or Config.screen.width, h or Config.screen.height
end

-- Find nearest enemy to player (for auto-targeting)
-- Prioritizes boss enemies if player is within BOSS_PRIORITY_RANGE
-- bosses: optional, can be a single boss entity or nil
function PlayerCombat.findNearestEnemy(player, enemies, boss)
    local centerX = player.x + player.width / 2
    local centerY = player.y + player.height / 2

    local nearestEnemy = nil
    local nearestDistance = math.huge
    local bossEnemy = nil
    local bossDistance = math.huge

    -- Check standalone boss (from BossSystem.activeBoss)
    -- BossSystem boss has: alive, x, y, size (radius), no width/height/dead
    if boss and boss.alive then
        local dx = boss.x - centerX
        local dy = boss.y - centerY
        bossDistance = math.sqrt(dx * dx + dy * dy)
        bossEnemy = boss
    end

    -- Check enemies array
    if enemies then
        for _, enemy in ipairs(enemies) do
            if not enemy.dead then
                local dx = enemy.x + enemy.width / 2 - centerX
                local dy = enemy.y + enemy.height / 2 - centerY
                local distance = math.sqrt(dx * dx + dy * dy)

                -- Check if this is a boss in the enemies array
                if enemy.enemyType == "boss" then
                    if distance < bossDistance then
                        bossDistance = distance
                        bossEnemy = enemy
                    end
                end

                -- Track nearest regular enemy
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestEnemy = enemy
                end
            end
        end
    end

    -- Prioritize boss if within range
    if bossEnemy and bossDistance <= BOSS_PRIORITY_RANGE then
        return bossEnemy
    end

    -- Otherwise return nearest enemy
    return nearestEnemy
end

-- Auto-fire at nearest enemy (Vampire Survivors style)
-- boss: optional, single boss entity from BossSystem.activeBoss
function PlayerCombat.autoFire(player, enemies, boss)
    if not player.weapon then
        return
    end

    local combatState = getCombatState(player)

    -- Find nearest enemy (including boss if provided)
    local nearestEnemy = PlayerCombat.findNearestEnemy(player, enemies, boss)

    -- Store for visual indicator
    combatState.nearestEnemy = nearestEnemy
    player.nearestEnemy = combatState.nearestEnemy  -- Compatibility shim

    -- Auto-fire at nearest enemy
    if nearestEnemy then
        local centerX = player.x + player.width / 2
        local centerY = player.y + player.height / 2

        -- BossSystem bosses use center x,y; regular enemies use x,y + width/height
        local targetX, targetY
        if nearestEnemy.width and nearestEnemy.height then
            -- Regular enemy or Boss entity
            targetX = nearestEnemy.x + nearestEnemy.width / 2
            targetY = nearestEnemy.y + nearestEnemy.height / 2
        else
            -- BossSystem boss (x,y is center)
            targetX = nearestEnemy.x
            targetY = nearestEnemy.y
        end

        local projectiles = player.weapon:fire(centerX, centerY, targetX, targetY)
        if projectiles then
            -- Apply artifact transformations to projectiles
            projectiles = PlayerCombat.applyArtifactEffects(player, projectiles, targetX, targetY, enemies)

            for _, proj in ipairs(projectiles) do
                table.insert(combatState.projectiles, proj)
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
    local combatState = getCombatState(player)
    local screenWidth, screenHeight = getScreenSize()

    for i = #combatState.projectiles, 1, -1 do
        local proj = combatState.projectiles[i]

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
                table.remove(combatState.projectiles, i)
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
            elseif proj.x > screenWidth then
                proj.x = screenWidth
                proj.vx = -proj.vx
                bounced = true
            end

            if proj.y < 0 then
                proj.y = 0
                proj.vy = -proj.vy
                bounced = true
            elseif proj.y > screenHeight then
                proj.y = screenHeight
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
            if proj.y < -10 or proj.y > screenHeight + 10 or proj.x < -10 or proj.x > screenWidth + 10 then
                shouldRemove = true
            end
        end

        if shouldRemove then
            table.remove(combatState.projectiles, i)
        end

        ::continue::
    end
end

-- Split a projectile into multiple smaller projectiles
function PlayerCombat.splitProjectile(player, parentProj, index)
    local combatState = getCombatState(player)

    -- Spawn PRISM split VFX
    local VFXLibrary = require("src.systems.VFXLibrary")
    VFXLibrary.spawnArtifactEffect("PRISM", parentProj.x, parentProj.y)

    -- Create split projectiles in a spread pattern
    local splitCount = parentProj.splitCount or 2
    local angleStep = (math.pi / 6) / (splitCount - 1)  -- ±15° spread
    local baseAngle = MathUtils.atan2(parentProj.vy, parentProj.vx)

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

        table.insert(combatState.projectiles, newProj)
    end
end

-- Get aim angle to nearest enemy
function PlayerCombat.getAimAngle(player)
    local combatState = getCombatState(player)
    local nearestEnemy = combatState.nearestEnemy or player.nearestEnemy
    if nearestEnemy then
        local centerX = player.x + player.width / 2
        local centerY = player.y + player.height / 2
        local targetX, targetY
        if nearestEnemy.width and nearestEnemy.height then
            targetX = nearestEnemy.x + nearestEnemy.width / 2
            targetY = nearestEnemy.y + nearestEnemy.height / 2
        else
            targetX = nearestEnemy.x
            targetY = nearestEnemy.y
        end
        return MathUtils.angleBetween(centerX, centerY, targetX, targetY)
    end
    return 0
end

return PlayerCombat
