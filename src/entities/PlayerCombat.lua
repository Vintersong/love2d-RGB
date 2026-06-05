-- PlayerCombat.lua
-- Handles player combat: auto-fire, projectile management, targeting
-- Extracted from Player.lua for better separation of concerns

local PlayerCombat = {}
local MathUtils = require("src.utils.MathUtils")
local GameConfig = require("src.core.GameConfig")
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
local ARTIFACT_SIGNAL_COOLDOWN = 4.5

local function signalArtifactMutation(player, artifactType, centerX, centerY)
    player.artifactSignalCooldowns = player.artifactSignalCooldowns or {}
    if (player.artifactSignalCooldowns[artifactType] or 0) > 0 then
        return
    end

    player.artifactSignalCooldowns[artifactType] = ARTIFACT_SIGNAL_COOLDOWN

    local VFXLibrary = require("src.effects.VFXLibrary")
    local SFXLibrary = require("src.audio.SFXLibrary")
    VFXLibrary.spawnArtifactActivationBurst(artifactType, centerX, centerY)
    SFXLibrary.playArtifactCue(artifactType)
end

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
    local ArtifactManager = require("src.gameplay.ArtifactManager")
    local ColorSystem = require("src.gameplay.ColorSystem")
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
        signalArtifactMutation(player, "PRISM", centerX, centerY)
    end

    -- Apply MIRROR effects (duplication, echoing, etc.)
    if ArtifactManager.getLevel("MIRROR") > 0 then
        local MirrorArtifact = require("src.artifacts.MirrorArtifact")
        local mirrorLevel = ArtifactManager.getLevel("MIRROR")
        projectiles = MirrorArtifact.apply(projectiles, mirrorLevel, dominantColor, player)
        signalArtifactMutation(player, "MIRROR", centerX, centerY)
    end

    -- Apply LENS effects (merging, enlarging, pull, etc.)
    if ArtifactManager.getLevel("LENS") > 0 then
        local LensArtifact = require("src.artifacts.LensArtifact")
        local lensLevel = ArtifactManager.getLevel("LENS")
        projectiles = LensArtifact.apply(projectiles, lensLevel, dominantColor)
        signalArtifactMutation(player, "LENS", centerX, centerY)
    end

    -- Apply DIFFRACTION effects (bursts, cones, orbital sources, etc.)
    if ArtifactManager.getLevel("DIFFRACTION") > 0 then
        local DiffractionArtifact = require("src.artifacts.DiffractionArtifact")
        local diffractionLevel = ArtifactManager.getLevel("DIFFRACTION")
        projectiles = DiffractionArtifact.apply(projectiles, diffractionLevel, dominantColor, targetX, targetY, player)
        signalArtifactMutation(player, "DIFFRACTION", centerX, centerY)
    end

    -- Apply REFRACTION effects (curving, seeking, satellites, power growth, etc.)
    if ArtifactManager.getLevel("REFRACTION") > 0 then
        local RefractionArtifact = require("src.artifacts.RefractionArtifact")
        local refractionLevel = ArtifactManager.getLevel("REFRACTION")
        projectiles = RefractionArtifact.apply(projectiles, refractionLevel, dominantColor, targetX, targetY, player)
        signalArtifactMutation(player, "REFRACTION", centerX, centerY)
    end

    return projectiles
end

-- Update projectile artifact effects (per-frame)
function PlayerCombat.updateProjectileArtifactEffects(proj, enemies, dt, player)
    local ArtifactManager = require("src.gameplay.ArtifactManager")
    local ColorSystem = require("src.gameplay.ColorSystem")
    local dominantColor = ColorSystem.getDominantColor()

    if not dominantColor then
        return nil
    end

    local spawnedProjectiles = {}

    local function appendProjectiles(list)
        for _, spawned in ipairs(list or {}) do
            table.insert(spawnedProjectiles, spawned)
        end
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

    -- DIFFRACTION artifact: orbital bombs and mobile burst sources
    if ArtifactManager.getLevel("DIFFRACTION") > 0 then
        local DiffractionArtifact = require("src.artifacts.DiffractionArtifact")
        appendProjectiles(DiffractionArtifact.update({proj}, enemies, dt, dominantColor, player))
    end

    -- REFRACTION artifact: seeking cores, rotating arms, and growth behaviors
    if ArtifactManager.getLevel("REFRACTION") > 0 then
        local RefractionArtifact = require("src.artifacts.RefractionArtifact")
        appendProjectiles(RefractionArtifact.update({proj}, enemies, dt, dominantColor, player))
    end

    return spawnedProjectiles
end

-- Update all player projectiles
function PlayerCombat.updateProjectiles(player, dt, enemies)
    local combatState = getCombatState(player)
    local screenWidth, screenHeight = getScreenSize()

    if player.artifactSignalCooldowns then
        for artifactType, cooldown in pairs(player.artifactSignalCooldowns) do
            player.artifactSignalCooldowns[artifactType] = math.max(0, cooldown - dt)
        end
    end

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
        local spawnedProjectiles = PlayerCombat.updateProjectileArtifactEffects(proj, enemies, dt, player)
        for _, spawned in ipairs(spawnedProjectiles or {}) do
            table.insert(combatState.projectiles, spawned)
        end

        if proj.mirrorFireTrail or proj.refractionFireArms or proj.electricTrail then
            proj._synergyTrailTimer = (proj._synergyTrailTimer or 0) - dt
            if proj._synergyTrailTimer <= 0 then
                proj._synergyTrailTimer = 0.14
                local VFXLibrary = require("src.effects.VFXLibrary")
                if proj.mirrorFireTrail or proj.refractionFireArms then
                    VFXLibrary.spawnGroundEffect("fire", proj.x, proj.y, {
                        radius = 28,
                        duration = proj.mirrorTrailDuration or proj.spiralTrailDuration or 1.0,
                        dps = proj.mirrorTrailDamage or proj.spiralTrailDPS or 5,
                    })
                end
                if proj.electricTrail then
                    VFXLibrary.spawnGroundEffect("lightning", proj.x, proj.y, {
                        radius = 34,
                        duration = proj.trailDuration or 1.0,
                        dps = proj.trailDamage or 4,
                    })
                end
            end
        end

        if proj.expired then
            table.remove(combatState.projectiles, i)
        else

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

            local splitTriggered = false

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
                    splitTriggered = true
                end
            end

            if not splitTriggered then
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
            end
        end
    end
end

-- Split a projectile into multiple smaller projectiles
function PlayerCombat.splitProjectile(player, parentProj, index)
    local combatState = getCombatState(player)

    -- Spawn PRISM split VFX
    local VFXLibrary = require("src.effects.VFXLibrary")
    VFXLibrary.spawnArtifactEffect("PRISM", parentProj.x, parentProj.y)

    -- Create split projectiles in a spread pattern
    -- Clamp to >= 2 so the (splitCount - 1) divisor below can never be zero
    -- (a splitCount of 1 would otherwise produce NaN velocities -> stuck projectiles).
    local splitCount = math.max(2, parentProj.splitCount or 2)
    local vx = parentProj.vx or 0
    local vy = parentProj.vy or -(parentProj.speed or 300)
    local baseAngle = MathUtils.atan2(vy, vx)

    for i = 1, splitCount do
        local offset = (i - 1) / (splitCount - 1) - 0.5  -- -0.5 to 0.5
        local angle = baseAngle + offset * (math.pi / 6)  -- ±15° spread

        local speed = math.sqrt(vx * vx + vy * vy)

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

            speed = speed,

            -- Inherit RGB attributes
            rCount = parentProj.rCount,
            gCount = parentProj.gCount,
            bCount = parentProj.bCount,
            shape = parentProj.shape,
            color = parentProj.color,

            -- Inherit all secondary effects so a fully-built projectile passes its
            -- additive abilities down to its split children. Field names match the
            -- canonical schema set by Weapon.lua:applyAbilities (the live bounce/pierce/
            -- explode/dot/root systems read these exact keys).

            -- BOUNCE (GREEN) — bounce-to-nearest chaining
            canBounceToNearest = parentProj.canBounceToNearest,
            maxBounces = parentProj.maxBounces,
            currentBounces = 0,

            -- PIERCE (BLUE)
            canPierce = parentProj.canPierce,
            maxPierces = parentProj.maxPierces,
            pierceCount = 0,
            hitEnemies = {},

            -- EXPLODE (MAGENTA)
            canExplode = parentProj.canExplode,
            explodeRadius = parentProj.explodeRadius,
            explodeDamage = parentProj.explodeDamage,

            -- DOT (CYAN)
            canDot = parentProj.canDot,
            dotDuration = parentProj.dotDuration,
            dotDamage = parentProj.dotDamage,

            -- ROOT
            canRoot = parentProj.canRoot,
            rootDuration = parentProj.rootDuration,

            -- NO more splits (already split)
            canSplit = false,
            splitCount = 0,
            hasSplit = true,

            -- Inherit artifact-synergy field behavior.
            lensThunderball = parentProj.lensThunderball,
            thunderfieldRadius = parentProj.thunderfieldRadius,
            thunderfieldDPS = parentProj.thunderfieldDPS,
            thunderfieldDuration = parentProj.thunderfieldDuration,
            mirrorFireTrail = parentProj.mirrorFireTrail,
            mirrorTrailDamage = parentProj.mirrorTrailDamage,
            mirrorTrailDuration = parentProj.mirrorTrailDuration,
            electricTrail = parentProj.electricTrail,
            trailDamage = parentProj.trailDamage,
            trailDuration = parentProj.trailDuration,
            diffractionBurnZone = parentProj.diffractionBurnZone,
            burnZoneRadius = parentProj.burnZoneRadius,
            burnZoneDPS = parentProj.burnZoneDPS,
            burnZoneDuration = parentProj.burnZoneDuration,
            waveEcho = parentProj.waveEcho,
            waveRadius = parentProj.waveRadius,
            wavePullForce = parentProj.wavePullForce,
            gravityWell = parentProj.gravityWell,
            wellRadius = parentProj.wellRadius,
            wellPullForce = parentProj.wellPullForce,
            poisonBloom = parentProj.poisonBloom,
            bloomRadius = parentProj.bloomRadius,
            bloomDamageRatio = parentProj.bloomDamageRatio,
            dotCloud = parentProj.dotCloud,
            cloudRadius = parentProj.cloudRadius,
            cloudDamageRatio = parentProj.cloudDamageRatio,
            refractionFrostPatches = parentProj.refractionFrostPatches,
            frostPatchRadius = parentProj.frostPatchRadius,
            frostPatchSlow = parentProj.frostPatchSlow,
            frostPatchDuration = parentProj.frostPatchDuration,
            refractionFireArms = parentProj.refractionFireArms,
            spiralTrailDPS = parentProj.spiralTrailDPS,
            spiralTrailDuration = parentProj.spiralTrailDuration,
            prismRootBonus = parentProj.prismRootBonus,
            rootRadius = parentProj.rootRadius,
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
