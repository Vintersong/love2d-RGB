-- PlayingState.lua
-- Main gameplay state where the player fights enemies and collects XP

local PlayingState = {}
local flux = require("libs.flux-master.flux")

-- Forward declarations for systems
local MusicReactor, ColorSystem, SpawnController, World, HealthSystem
local AttackSystem, UISystem, FloatingTextSystem, VFXLibrary
local XPParticleSystem, CollisionSystem, GridAttackSystem, BackgroundShader, SimpleGrid
local LightningEffect, ShieldEffect, ProjectileCollisionSystem, PickupSystem, BossCoordinator

-- Shared game data (will be set by main.lua)
PlayingState.player = nil
PlayingState.enemies = {}
PlayingState.xpOrbs = {}
PlayingState.powerups = {}
PlayingState.explosions = {}
PlayingState.bossProjectiles = {}
PlayingState.gameTime = 0
-- enemyKillCount moved to SpawnController
PlayingState.musicReactor = nil
PlayingState.screenWidth = 1920
PlayingState.screenHeight = 1080
PlayingState.supernovaEffects = {}

function PlayingState.startNewRun()
    local Player = require("src.entities.Player")
    local Weapon = require("src.Weapon")
    local GameConfig = require("src.systems.GameConfig")
    local ColorSystem = require("src.systems.ColorSystem")
    local SynergySystem = require("src.systems.SynergySystem")
    local ArtifactManager = require("src.systems.ArtifactManager")
    local SpawnController = require("src.systems.SpawnController")
    local BossSystem = require("src.systems.BossSystem")
    local CollisionSystem = require("src.systems.CollisionSystem")
    local VFXLibrary = require("src.systems.VFXLibrary")
    local Config = require("src.Config")

    if PlayingState.player and PlayingState.player.destroy then
        PlayingState.player:destroy()
    end

    ColorSystem.init()
    SynergySystem.reset()
    ArtifactManager.reset()
    CollisionSystem.init(Config.gameplay.cellSize)
    VFXLibrary.clear()

    PlayingState.screenWidth, PlayingState.screenHeight = GameConfig.getScreenSize()
    SpawnController.init(PlayingState.screenWidth, PlayingState.screenHeight)
    BossSystem.reset()

    PlayingState.player = Player(512, 360, Weapon())
    PlayingState.enemies = {}
    PlayingState.xpOrbs = {}
    PlayingState.powerups = {}
    PlayingState.explosions = {}
    PlayingState.bossProjectiles = {}
    PlayingState.supernovaEffects = {}
    PlayingState.gameTime = 0
    PlayingState.enemyKillCount = 0
    PlayingState.musicReactor = GameConfig.getMusicReactor()

    return PlayingState
end

function PlayingState:enter(previous, data)
    -- Load systems on first enter
    if not MusicReactor then
        MusicReactor = require("src.systems.MusicReactor")
        ColorSystem = require("src.systems.ColorSystem")
        SpawnController = require("src.systems.SpawnController") -- Replaced separate EnemySpawner
        World = require("src.systems.World")
        HealthSystem = require("src.systems.HealthSystem")
        AttackSystem = require("src.systems.AttackSystem")
        UISystem = require("src.systems.UISystem")
        FloatingTextSystem = require("src.systems.FloatingTextSystem")
        VFXLibrary = require("src.systems.VFXLibrary")
        XPParticleSystem = require("src.systems.XPParticleSystem")
        CollisionSystem = require("src.systems.CollisionSystem")
        GridAttackSystem = require("src.systems.GridAttackSystem")
        BackgroundShader = require("src.systems.BackgroundShader")
        SimpleGrid = require("src.systems.SimpleGrid")
        LightningEffect = require("src.systems.LightningEffect")
        ShieldEffect = require("src.systems.ShieldEffect")
        ProjectileCollisionSystem = require("src.systems.ProjectileCollisionSystem")
        PickupSystem = require("src.systems.PickupSystem")
        BossCoordinator = require("src.systems.BossCoordinator")

        -- Initialize controller
        SpawnController.init(self.screenWidth, self.screenHeight)
    end

    -- If data provided, restore it (used for returning from levelUp)
    if data then
        self.player = data.player
        self.enemies = data.enemies or {}
        self.xpOrbs = data.xpOrbs or {}
        self.powerups = data.powerups or {}
        self.explosions = data.explosions or {}
        self.bossProjectiles = data.bossProjectiles or {}
        self.supernovaEffects = data.supernovaEffects or {}
        self.gameTime = data.gameTime or 0
        SpawnController.enemyKillCount = data.enemyKillCount or 0 -- Restore kill count to controller
        self.musicReactor = data.musicReactor
    end

    -- Register the active player in the collision world after any restore.
    if self.player and CollisionSystem.world and not CollisionSystem.world:hasItem(self.player) then
        CollisionSystem.add(self.player, "player")
    end

    BossCoordinator.bossProjectiles = self.bossProjectiles
end

function PlayingState:update(dt)
    -- Update music reactor
    if self.musicReactor then
        self.musicReactor:update(dt)
    end

    -- Update background shader with music data and player level
    BackgroundShader.update(dt, self.musicReactor, self.player)

    -- Update simple grid with music data
    SimpleGrid.update(dt, self.musicReactor)

    -- Update world background
    World.update(dt, self.musicReactor)

    -- Update flux tweening library for smooth animations
    flux.update(dt)

    -- Update floating text system
    FloatingTextSystem.update(dt)

    -- Update VFX particles
    VFXLibrary.update(dt)
    
    -- Update impact burst particles
    VFXLibrary.updateImpactBursts(dt)

    -- Update grid attack system (spawns marching enemies from edges)
    -- DISABLED FOR TESTING
    -- GridAttackSystem.update(dt, self.musicReactor, self.player, self.enemies)

    -- Track game time
    self.gameTime = self.gameTime + dt

    local centerX = self.player.x + self.player.width / 2
    local centerY = self.player.y + self.player.height / 2

    self.player:update(dt, self.enemies)

    -- Check dash collisions with enemies
    self.player:checkDashCollisions(self.enemies)

    -- Auto-fire at nearest enemy (Vampire Survivors style)
    -- Pass boss from BossCoordinator if active
    self.player:autoFire(self.enemies, BossCoordinator.getActiveBoss())

    -- Update lightning bolt visual effect
    LightningEffect.update(dt)

    -- Update shield visual effect (handles expand + fade-out)
    ShieldEffect.update(dt)

    -- Use SpawnController for procedural enemy waves
    SpawnController.update(dt, self.player.level, self.musicReactor, self.enemies)

    -- Update enemies
    self:updateEnemies(dt, centerX, centerY)

    -- Check enemy projectile-player collisions
    self:updateEnemyProjectileCollisions(centerX, centerY)

    -- Update DoT effects on all enemies
    local dotKillCallback = function(target)
        SpawnController.handleEnemyDeath(target, self.player, self.xpOrbs, self.powerups)
    end
    AttackSystem.updateDoTs(self.enemies, dt, dotKillCallback)

    -- Check projectile-enemy collisions
    ProjectileCollisionSystem.update(self.player, self.enemies, self.xpOrbs, self.powerups, self.explosions)

    -- Update explosions (MAGENTA tertiary effect)
    self:updateExplosions(dt)

    -- Update persistent active-artifact effects
    self:updateSupernovaEffects(dt)

    -- Update and collect XP orbs
    PickupSystem.updateXPOrbs(dt, self.player, self.xpOrbs, centerX, centerY)

    -- Update and collect powerups
    PickupSystem.updatePowerups(dt, self.player, self.enemies, self.powerups, centerX, centerY)

    -- Check for level up
    if self.player:canLevelUp() then
        local StateManager = require("src.systems.StateManager")
        StateManager.push("LevelUp", {
            player = self.player,
            enemies = self.enemies,
            xpOrbs = self.xpOrbs,
            powerups = self.powerups,
            explosions = self.explosions,
            bossProjectiles = self.bossProjectiles,
            supernovaEffects = self.supernovaEffects,
            gameTime = self.gameTime,
            enemyKillCount = SpawnController.enemyKillCount, -- Persist via controller
            musicReactor = self.musicReactor
        })
        return
    end

    -- Update boss if active
    local activeBossBefore = BossCoordinator.getActiveBoss()
    BossCoordinator.update(dt, self.player, self.player.projectiles, self.bossProjectiles, self.musicReactor, self.enemies)
    if activeBossBefore and not activeBossBefore.alive and not BossCoordinator.getActiveBoss() then
        local StateManager = require("src.systems.StateManager")
        StateManager.switch("Victory", {
            player = self.player,
            enemies = self.enemies,
            xpOrbs = self.xpOrbs,
            musicReactor = self.musicReactor,
            gameTime = self.gameTime,
            enemyKillCount = SpawnController.enemyKillCount,
        })
        return
    end
end

function PlayingState:captureAliveEnemies()
    local alive = {}
    for _, enemy in ipairs(self.enemies) do
        if not enemy.dead then
            alive[enemy] = true
        end
    end
    return alive
end

function PlayingState:rewardNewEnemyDeaths(aliveBefore)
    for _, enemy in ipairs(self.enemies) do
        if aliveBefore[enemy] and enemy.dead and not enemy._deathRewarded then
            SpawnController.handleEnemyDeath(enemy, self.player, self.xpOrbs, self.powerups)
        end
    end
end

function PlayingState:activateSupernova()
    local aliveBefore = self:captureAliveEnemies()
    local success, effectData, color = self.player:useActiveAbility(self.enemies)
    if not success then
        return false
    end

    self:rewardNewEnemyDeaths(aliveBefore)

    local centerX = self.player.x + self.player.width / 2
    local centerY = self.player.y + self.player.height / 2
    VFXLibrary.spawnArtifactEffect("SUPERNOVA", centerX, centerY)
    FloatingTextSystem.add((color or "RED") .. " SUPERNOVA", centerX, centerY - 80, "SYNERGY")

    if effectData and effectData.field then
        table.insert(self.supernovaEffects, {
            type = effectData.type,
            field = effectData.field,
            color = effectData.color or {1, 0.3, 0.2},
            radius = effectData.radius or 120,
        })
    end

    return true
end

function PlayingState:updateSupernovaEffects(dt)
    for i = #self.supernovaEffects, 1, -1 do
        local effect = self.supernovaEffects[i]
        if effect.field and effect.field.update then
            local aliveBefore = self:captureAliveEnemies()
            local stillActive = effect.field:update(dt, self.player, self.enemies)
            self:rewardNewEnemyDeaths(aliveBefore)

            if not stillActive then
                table.remove(self.supernovaEffects, i)
            end
        else
            table.remove(self.supernovaEffects, i)
        end
    end
end

function PlayingState:updateEnemies(dt, centerX, centerY)
    -- Update player position in collision world
    CollisionSystem.update(self.player, self.player.x, self.player.y)

    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        enemy:update(dt, centerX, centerY, {
            player = self.player,
            musicReactor = self.musicReactor,
            enemyCount = #self.enemies,
            gameTime = self.gameTime,
        })

        -- Update enemy position in collision world
        if CollisionSystem.world:hasItem(enemy) then
            CollisionSystem.update(enemy, enemy.x, enemy.y)
        end

        -- Process HALO artifact effects on enemies (skip if inactive)
        if not enemy.dead and not enemy.inactive then
            -- Delegate to HaloArtifact module
            local HaloArtifact = require("src.artifacts.HaloArtifact")
            HaloArtifact.processEffects(enemy, self.player, function(killedEnemy)
                -- Use Controller to handle death rewards
                SpawnController.handleEnemyDeath(killedEnemy, self.player, self.xpOrbs, self.powerups)
            end)
        end

        -- Remove dead enemies (return to pool for recycling)
        if enemy.dead then
            CollisionSystem.remove(enemy)
            table.remove(self.enemies, i)
            local EnemySpawner = require("src.systems.EnemySpawner")
            EnemySpawner.returnToPool(enemy)
        end
    end

    -- Check enemy-player collisions using CollisionSystem (MUCH faster!)
    local collidingEnemies = CollisionSystem.checkPlayerEnemyCollisions(self.player)
    for _, enemy in ipairs(collidingEnemies) do
        -- Enemy touches player - deal damage via AttackSystem
        local died = AttackSystem.enemyContactDamage(enemy, self.player, dt)
        if died then
            local StateManager = require("src.systems.StateManager")
            StateManager.switch("GameOver", {
                player = self.player,
                enemies = self.enemies,
                musicReactor = self.musicReactor
            })
            return
        end
    end
end

-- processHaloEffects has been removed - now delegated to HaloArtifact.processEffects()

function PlayingState:updateEnemyProjectileCollisions(centerX, centerY)
    for _, enemy in ipairs(self.enemies) do
        if not enemy.dead and enemy.projectiles then
            for i = #enemy.projectiles, 1, -1 do
                local proj = enemy.projectiles[i]

                -- Use CollisionSystem for circle-to-AABB collision
                if CollisionSystem.checkEnemyProjectilePlayerCollision(proj, self.player) then
                    -- Player hit by enemy projectile
                    local died = HealthSystem.takeDamage(self.player, proj.damage)
                    table.remove(enemy.projectiles, i)

                    if died then
                        local StateManager = require("src.systems.StateManager")
                        StateManager.switch("GameOver", {
                            player = self.player,
                            enemies = self.enemies,
                            musicReactor = self.musicReactor
                        })
                        return
                    end
                end
            end
        end
    end
end

function PlayingState:updateExplosions(dt)
    for i = #self.explosions, 1, -1 do
        local explosion = self.explosions[i]
        explosion.lifetime = explosion.lifetime - dt

        -- Process explosion damage
        if not explosion.processed then
            local explosionKillCallback = function(target)
                SpawnController.handleEnemyDeath(target, self.player, self.xpOrbs, self.powerups)
            end

            AttackSystem.processExplosion(explosion, self.enemies, explosionKillCallback)
            explosion.processed = true
        end

        -- Remove expired explosions
        if explosion.lifetime <= 0 then
            table.remove(self.explosions, i)
        end
    end
end

function PlayingState:calculateDropChance(orbType, playerLevel, time)
    return PickupSystem.calculateDropChance(orbType, playerLevel, time)
end

function PlayingState:spawnOrbsForEnemy(enemy)
    return PickupSystem.spawnOrbsForEnemy(enemy, self.player, self.gameTime, self.screenWidth, self.screenHeight)
end

function PlayingState:draw()
    -- LAYER: background
    -- Draw music-reactive shader background
    BackgroundShader.draw()

    -- Draw vaporwave background (stars/particles on top of shader)
    -- DISABLED FOR TESTING
    -- World.draw()

    -- LAYER: ground/grid effects
    -- Draw grid attack system and low-lying world effects under entities
    -- DISABLED FOR TESTING
    -- GridAttackSystem.draw(false)  -- Set to true for debug grid
    self.player:drawAura()
    VFXLibrary.draw()

    -- LAYER: projectile trails
    -- Player projectile trails render under combatants so motion reads without covering sprites
    self.player:drawProjectileTrails()

    -- LAYER: entities/player/enemies/boss/collectibles
    self.player:drawBody()

    -- Draw enemies
    for _, enemy in ipairs(self.enemies) do
        enemy:draw(self.musicReactor)

        -- Draw enemy info (HP, DoT, Root indicators)
        UISystem.drawEnemyInfo(enemy)
    end

    -- Draw boss if active
    local activeBoss = BossCoordinator.getActiveBoss()
    if activeBoss then
        activeBoss:draw()
    end

    -- Draw XP orbs
    for _, orb in ipairs(self.xpOrbs) do
        orb:draw(false)
    end

    -- Draw powerups
    for _, powerup in ipairs(self.powerups) do
        powerup:draw()
    end

    -- Draw persistent active-artifact fields
    for _, effect in ipairs(self.supernovaEffects) do
        if effect.field then
            local alpha = 0.18
            if effect.field.lifetime and effect.field.lifetime < 1 then
                alpha = alpha * math.max(0, effect.field.lifetime)
            end
            local color = effect.color or {1, 0.3, 0.2}
            love.graphics.setColor(color[1], color[2], color[3], alpha)
            love.graphics.circle("fill", effect.field.x, effect.field.y, effect.field.radius or effect.radius or 120)
            love.graphics.setColor(color[1], color[2], color[3], 0.7)
            love.graphics.circle("line", effect.field.x, effect.field.y, effect.field.radius or effect.radius or 120)
        end
    end

    -- LAYER: foreground projectile cores and combat VFX overlays
    -- Draw player projectile cores above entities after their trails were rendered below entities
    self.player:drawProjectileCores()

    -- Draw boss projectiles
    for _, proj in ipairs(self.bossProjectiles) do
        proj:draw()
    end

    -- Draw explosions (MAGENTA AoE)
    for _, explosion in ipairs(self.explosions) do
        love.graphics.setColor(1, 0.2, 1, 0.6 * (explosion.lifetime / 0.5))
        love.graphics.circle("fill", explosion.x, explosion.y, explosion.radius * (explosion.lifetime / 0.5))
        love.graphics.setColor(1, 0.2, 1, 0.9)
        love.graphics.circle("line", explosion.x, explosion.y, explosion.radius)
    end

    -- Shield is a foreground combat overlay around the player.
    ShieldEffect.draw()

    -- Lightning is a foreground combat overlay so bolts remain readable above enemies/projectiles.
    LightningEffect.draw()

    -- Draw impact burst particles with foreground combat VFX
    VFXLibrary.drawImpactBursts()

    -- LAYER: targeting overlays
    -- Target line/indicator intentionally draws above enemies and foreground VFX
    self.player:drawTargetingOverlay()

    -- LAYER: HUD and debug overlays
    -- Draw player HUD using UISystem
    UISystem.drawPlayerHUD(self.player)

    -- Draw floating text (on top of everything)
    FloatingTextSystem.draw()

    -- Draw debug menu overlay
    local GameConfig = require("src.systems.GameConfig")
    if GameConfig.isDebugMode() then
        local DebugMenu = require("src.systems.DebugMenu")
        DebugMenu.draw(self.player)
    end
end

function PlayingState:keypressed(key)
    -- Pause overlay
    if key == "escape" or key == "p" then
        local StateManager = require("src.systems.StateManager")
        StateManager.push("Pause", {
            player = self.player,
            musicReactor = self.musicReactor
        })
        return
    end

    -- Spacebar: Dash (permanent ability)
    if key == "space" then
        if self.player:useDash() then
            print("[Input] Dash activated!")
        end
        return
    end

    local GameConfig = require("src.systems.GameConfig")
    local debugEnabled = GameConfig.isDebugMode()

    -- TEST: Trigger grid wave animations (for development)
    if debugEnabled and key == "t" then
        SimpleGrid.triggerWave("all", {1, 1, 1}, "expand")  -- White wave in all quadrants
        print("[Test] Triggered white wave in all quadrants")
    end

    -- E key: Blink (teleport ability)
    if key == "e" then
        if self.player:useBlink() then
            print("[Input] Blink activated!")
        end
        return
    end

    -- Q key: Shield (invulnerability ability)
    if key == "q" then
        if self.player:useShield() then
            print("[Input] Shield activated!")
        end
        return
    end

    -- Left Shift: Use active artifact ability
    if key == "lshift" then
        if self:activateSupernova() then
            print("[Input] Active artifact ability used!")
        end
        return
    end

    -- Debug helpers
    if debugEnabled and key == "f1" then
        self.player:addExp(self.player.expToNext)
        print("[DEBUG] Instant level up to level " .. self.player.level)
    elseif debugEnabled and key == "f2" then
        local Enemy = require("src.entities.Enemy")
        for i = 1, 10 do
            local angle = (i / 10) * math.pi * 2
            local distance = 200
            local spawnX = self.player.x + math.cos(angle) * distance
            local spawnY = self.player.y + math.sin(angle) * distance
            table.insert(self.enemies, Enemy(spawnX, spawnY))
        end
        print("[DEBUG] Spawned 10 enemies")
    elseif debugEnabled and key == "f3" then
        local counts = ColorSystem.getColorCounts()
        print("[DEBUG] Color System State:")
        print("  Commitment: " .. ColorSystem.getCurrentPath())
        print(string.format("  Primaries: RED=%d GREEN=%d BLUE=%d", counts.RED, counts.GREEN, counts.BLUE))
        print(string.format("  Secondaries: YELLOW=%d MAGENTA=%d CYAN=%d", counts.YELLOW, counts.MAGENTA, counts.CYAN))
        print("  Dominant: " .. tostring(ColorSystem.getDominantColor()))
        print("  Level: " .. self.player.level)
        local choices = ColorSystem.getValidChoices(self.player.level)
        print("  Valid choices: " .. table.concat(choices, ", "))
    elseif debugEnabled and key == "f4" then
        local xpNeeded = 0
        local tempLevel = self.player.level
        local tempExpToNext = self.player.expToNext
        local baseXP = 100
        local scaleFactor = 1.1

        while tempLevel < 20 do
            xpNeeded = xpNeeded + tempExpToNext
            tempLevel = tempLevel + 1
            tempExpToNext = math.floor(baseXP * (scaleFactor ^ (tempLevel - 1)))
        end

        self.player:addExp(xpNeeded)
        print("[DEBUG] Added " .. xpNeeded .. " XP")
    elseif debugEnabled and key == "f5" then
        self.player.hp = self.player.maxHp
        print("[DEBUG] Full heal")
    elseif debugEnabled and key == "f8" then
        local playerCenterX = self.player.x + self.player.width / 2
        local playerCenterY = self.player.y + self.player.height / 2
        table.insert(self.xpOrbs, XPParticleSystem.new(playerCenterX, playerCenterY, 10))
        print("[DEBUG] Spawned basic XP particle orb (10 XP)")
    elseif debugEnabled and key == "f9" then
        local playerCenterX = self.player.x + self.player.width / 2
        local playerCenterY = self.player.y + self.player.height / 2
        table.insert(self.xpOrbs, XPParticleSystem.new(playerCenterX, playerCenterY, 20))
        print("[DEBUG] Spawned medium XP particle orb (20 XP)")
    elseif debugEnabled and key == "f10" then
        local playerCenterX = self.player.x + self.player.width / 2
        local playerCenterY = self.player.y + self.player.height / 2
        table.insert(self.xpOrbs, XPParticleSystem.new(playerCenterX, playerCenterY, 40))
        print("[DEBUG] Spawned large XP particle orb (40 XP)")
    elseif debugEnabled and key == "f11" then
        local primaryChance = self:calculateDropChance("primary", self.player.level, self.gameTime)
        local secondaryChance = self:calculateDropChance("secondary", self.player.level, self.gameTime)
        print(string.format("[DEBUG] Drop Chances - Primary: %.1f%%, Secondary: %.1f%%",
            primaryChance * 100, secondaryChance * 100))
        print(string.format("[DEBUG] Game Time: %.1fs, Level: %d", self.gameTime, self.player.level))
    elseif debugEnabled and key == "l" then
        self.player.exp = self.player.exp + 50
    end

    -- DebugMenu system
    if debugEnabled then
        local DebugMenu = require("src.systems.DebugMenu")
        DebugMenu.keypressed(key, self.player, self.enemies, self.musicReactor)
    end
end

return PlayingState
