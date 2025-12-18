-- PlayingState.lua
-- Main gameplay state where the player fights enemies and collects XP

local PlayingState = {}
local flux = require("libs.flux-master.flux")

-- Forward declarations for systems
local MusicReactor, ColorSystem, EnemySpawner, World, HealthSystem
local AttackSystem, UISystem, FloatingTextSystem, VFXLibrary
local XPParticleSystem, BossSystem, Powerup, CollisionSystem, GridAttackSystem, BackgroundShader, SimpleGrid

-- Shared game data (will be set by main.lua)
PlayingState.player = nil
PlayingState.enemies = {}
PlayingState.xpOrbs = {}
PlayingState.powerups = {}
PlayingState.explosions = {}
PlayingState.bossProjectiles = {}
PlayingState.gameTime = 0
PlayingState.enemyKillCount = 0
PlayingState.musicReactor = nil
PlayingState.screenWidth = 1920
PlayingState.screenHeight = 1080

function PlayingState:enter(previous, data)
    -- Load systems on first enter
    if not MusicReactor then
        MusicReactor = require("src.systems.MusicReactor")
        ColorSystem = require("src.systems.ColorSystem")
        EnemySpawner = require("src.systems.EnemySpawner")
        World = require("src.systems.World")
        HealthSystem = require("src.systems.HealthSystem")
        AttackSystem = require("src.systems.AttackSystem")
        UISystem = require("src.systems.UISystem")
        FloatingTextSystem = require("src.systems.FloatingTextSystem")
        VFXLibrary = require("src.systems.VFXLibrary")
        XPParticleSystem = require("src.systems.XPParticleSystem")
        BossSystem = require("src.systems.BossSystem")
        Powerup = require("src.entities.Powerup")
        CollisionSystem = require("src.systems.CollisionSystem")
        GridAttackSystem = require("src.systems.GridAttackSystem")
        BackgroundShader = require("src.systems.BackgroundShader")
        SimpleGrid = require("src.systems.SimpleGrid")
    end

    -- Register player in collision world
    if self.player and not CollisionSystem.world:hasItem(self.player) then
        CollisionSystem.add(self.player, "player")
    end

    -- If data provided, restore it (used for returning from levelUp)
    if data then
        self.player = data.player
        self.enemies = data.enemies or {}
        self.xpOrbs = data.xpOrbs or {}
        self.powerups = data.powerups or {}
        self.explosions = data.explosions or {}
        self.bossProjectiles = data.bossProjectiles or {}
        self.gameTime = data.gameTime or 0
        self.enemyKillCount = data.enemyKillCount or 0
        self.musicReactor = data.musicReactor
    end
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
    -- Pass boss from BossSystem if active
    self.player:autoFire(self.enemies, BossSystem.activeBoss)

    -- Use EnemySpawner system for procedural enemy waves
    -- DISABLED FOR TESTING
    --[[
    local enemyCountBefore = #self.enemies
    EnemySpawner.update(dt, self.musicReactor, self.enemies, self.player.level)

    -- Register newly spawned enemies in collision system
    for i = enemyCountBefore + 1, #self.enemies do
        local enemy = self.enemies[i]
        if not CollisionSystem.world:hasItem(enemy) then
            CollisionSystem.add(enemy, "enemy")
        end
    end
    --]]

    -- Update enemies
    self:updateEnemies(dt, centerX, centerY)

    -- Check enemy projectile-player collisions
    self:updateEnemyProjectileCollisions(centerX, centerY)

    -- Update DoT effects on all enemies
    AttackSystem.updateDoTs(self.enemies, dt)

    -- Check projectile-enemy collisions
    self:updateProjectileCollisions()

    -- Update explosions (MAGENTA tertiary effect)
    self:updateExplosions(dt)

    -- Update and collect XP orbs
    self:updateXPOrbs(dt, centerX, centerY)

    -- Update and collect powerups
    self:updatePowerups(dt, centerX, centerY)

    -- Check for level up
    if self.player.exp >= self.player.expToNext then
        local Gamestate = require("libs.hump-master.gamestate")
        Gamestate.push(require("src.states.LevelUpState"), {
            player = self.player,
            enemies = self.enemies,
            xpOrbs = self.xpOrbs,
            powerups = self.powerups,
            explosions = self.explosions,
            bossProjectiles = self.bossProjectiles,
            gameTime = self.gameTime,
            enemyKillCount = self.enemyKillCount,
            musicReactor = self.musicReactor
        })
        return
    end

    -- Update boss if active
    self:updateBoss(dt)
end

function PlayingState:updateEnemies(dt, centerX, centerY)
    -- Update player position in collision world
    CollisionSystem.update(self.player, self.player.x, self.player.y)

    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        enemy:update(dt, centerX, centerY)

        -- Update enemy position in collision world
        if CollisionSystem.world:hasItem(enemy) then
            CollisionSystem.update(enemy, enemy.x, enemy.y)
        end

        -- Process HALO artifact effects on enemies (skip if inactive)
        if not enemy.dead and not enemy.inactive then
            -- Delegate to HaloArtifact module
            local HaloArtifact = require("src.artifacts.HaloArtifact")
            HaloArtifact.processEffects(enemy, self.player, function(killedEnemy)
                local newOrbs = self:spawnOrbsForEnemy(killedEnemy)
                for _, orb in ipairs(newOrbs) do
                    table.insert(self.xpOrbs, orb)
                end
            end)
        end

        -- Remove dead enemies
        if enemy.dead then
            CollisionSystem.remove(enemy)
            table.remove(self.enemies, i)
        end
    end

    -- Check enemy-player collisions using CollisionSystem (MUCH faster!)
    local collidingEnemies = CollisionSystem.checkPlayerEnemyCollisions(self.player)
    for _, enemy in ipairs(collidingEnemies) do
        -- Enemy touches player - deal damage via AttackSystem
        local died = AttackSystem.enemyContactDamage(enemy, self.player, dt)
        if died then
            local Gamestate = require("libs.hump-master.gamestate")
            Gamestate.switch(require("src.states.GameOverState"), {
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
                        local Gamestate = require("libs.hump-master.gamestate")
                        Gamestate.switch(require("src.states.GameOverState"), {
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

function PlayingState:updateProjectileCollisions()
    for i = #self.player.projectiles, 1, -1 do
        local proj = self.player.projectiles[i]

        -- Initialize pierce tracking if not exists
        if not proj.hitEnemies then
            proj.hitEnemies = {}
        end

        local shouldRemove = false

        -- Callback for spawning XP orbs and powerups when enemy dies
        local onKillCallback = function(target)
            -- Increment kill counter for boss spawning
            self.enemyKillCount = self.enemyKillCount + 1

            -- Check if boss should spawn (every 100 kills)
            if self.enemyKillCount % 100 == 0 and not BossSystem.activeBoss then
                local boss = BossSystem.spawnBoss()
                if boss then
                    FloatingTextSystem.add("⚠ BOSS WAVE ⚠", self.screenWidth/2, self.screenHeight/2, "BOSS")
                end
            end

            local newOrbs = self:spawnOrbsForEnemy(target)
            for _, orb in ipairs(newOrbs) do
                table.insert(self.xpOrbs, orb)
            end

            -- Chance to drop powerup
            if Powerup.shouldDrop() then
                local powerupType = Powerup.getRandomType()
                local powerupX = target.x + target.width/2
                local powerupY = target.y + target.height/2

                -- Clamp powerup spawn to inner 70% of screen
                local playWidth = self.screenWidth * 0.7
                local playHeight = self.screenHeight * 0.7
                local leftBound = (self.screenWidth - playWidth) / 2
                local topBound = (self.screenHeight - playHeight) / 2

                powerupX = math.max(leftBound, math.min(leftBound + playWidth, powerupX))
                powerupY = math.max(topBound, math.min(topBound + playHeight, powerupY))

                local powerup = Powerup(powerupX, powerupY, powerupType)
                table.insert(self.powerups, powerup)
            end
        end

        -- Use CollisionSystem for spatial query (much faster than checking all enemies)
        local nearbyEnemies = CollisionSystem.checkProjectileEnemyCollisions(proj, self.enemies)

        for _, enemy in ipairs(nearbyEnemies) do
            -- Check if enemy hasn't been hit by this projectile already
            if not proj.hitEnemies[enemy] and not enemy.inactive then
                -- Use AttackSystem to handle damage and effects
                local explosion = AttackSystem.projectileHit(proj, enemy, onKillCallback)

                -- Mark enemy as hit
                proj.hitEnemies[enemy] = true

                -- Handle explosion if MAGENTA created one
                if explosion then
                    table.insert(self.explosions, explosion)
                    VFXLibrary.spawnArtifactEffect("SUPERNOVA", explosion.x, explosion.y)
                end

                -- GREEN: Bounce to nearest enemy
                if proj.canBounceToNearest then
                    shouldRemove = self:handleBounce(proj)
                -- BLUE: Pierce through enemies
                elseif proj.canPierce then
                    shouldRemove = self:handlePierce(proj)
                else
                    -- Normal projectile: dies on hit
                    shouldRemove = true
                end

                if shouldRemove then
                    break
                end
            end
        end

        if shouldRemove then
            table.remove(self.player.projectiles, i)
        end
    end
end

function PlayingState:handleBounce(proj)
    proj.currentBounces = (proj.currentBounces or 0) + 1

    if proj.currentBounces >= (proj.maxBounces or 1) then
        return true -- Remove projectile
    end

    -- Find nearest enemy that hasn't been hit yet
    local nearestEnemy = nil
    local nearestDist = math.huge

    for _, otherEnemy in ipairs(self.enemies) do
        if not proj.hitEnemies[otherEnemy] and not otherEnemy.dead and not otherEnemy.inactive then
            local dx = otherEnemy.x - proj.x
            local dy = otherEnemy.y - proj.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < nearestDist then
                nearestDist = dist
                nearestEnemy = otherEnemy
            end
        end
    end

    if nearestEnemy then
        -- Redirect projectile toward nearest enemy
        local dx = (nearestEnemy.x + nearestEnemy.width/2) - proj.x
        local dy = (nearestEnemy.y + nearestEnemy.height/2) - proj.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist > 0 then
            proj.vx = (dx / dist) * proj.speed
            proj.vy = (dy / dist) * proj.speed
        end
        return false -- Keep projectile
    end

    return true -- No more enemies, remove projectile
end

function PlayingState:handlePierce(proj)
    proj.pierceCount = (proj.pierceCount or 0) + 1

    if proj.pierceCount >= (proj.maxPierces or 1) then
        return true -- Max pierces reached, remove
    end

    return false -- Continue piercing
end

function PlayingState:updateExplosions(dt)
    for i = #self.explosions, 1, -1 do
        local explosion = self.explosions[i]
        explosion.lifetime = explosion.lifetime - dt

        -- Process explosion damage
        if not explosion.processed then
            local explosionKillCallback = function(target)
                local newOrbs = self:spawnOrbsForEnemy(target)
                for _, orb in ipairs(newOrbs) do
                    table.insert(self.xpOrbs, orb)
                end

                -- Chance to drop powerup
                if Powerup.shouldDrop() then
                    local powerupType = Powerup.getRandomType()
                    local powerupX = target.x + target.width/2
                    local powerupY = target.y + target.height/2

                    local playWidth = self.screenWidth * 0.7
                    local playHeight = self.screenHeight * 0.7
                    local leftBound = (self.screenWidth - playWidth) / 2
                    local topBound = (self.screenHeight - playHeight) / 2

                    powerupX = math.max(leftBound, math.min(leftBound + playWidth, powerupX))
                    powerupY = math.max(topBound, math.min(topBound + playHeight, powerupY))

                    local powerup = Powerup(powerupX, powerupY, powerupType)
                    table.insert(self.powerups, powerup)
                end
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

function PlayingState:updateXPOrbs(dt, centerX, centerY)
    for i = #self.xpOrbs, 1, -1 do
        local orb = self.xpOrbs[i]
        local collectedXP = orb:update(dt, centerX, centerY)

        -- Check if collected
        if collectedXP then
            self.player:addExp(collectedXP)
            table.remove(self.xpOrbs, i)
        elseif not orb.alive then
            table.remove(self.xpOrbs, i)
        end
    end
end

function PlayingState:updatePowerups(dt, centerX, centerY)
    for i = #self.powerups, 1, -1 do
        local powerup = self.powerups[i]
        powerup:update(dt, centerX, centerY)

        -- Check if collected
        if powerup:checkCollision(self.player) then
            local result = powerup:collect(self.player)

            -- Show floating text for artifact collection
            if result and result.success then
                FloatingTextSystem.addArtifact(
                    result.artifactName,
                    result.level,
                    powerup.x,
                    powerup.y,
                    result.isMaxLevel
                )

                -- Spawn VFX for artifact
                VFXLibrary.spawnArtifactEffect(
                    result.type,
                    powerup.x,
                    powerup.y,
                    centerX,
                    centerY
                )

                -- Show synergy unlock if exists
                if result.synergyMessage then
                    FloatingTextSystem.addSynergy(
                        result.synergyMessage,
                        powerup.x,
                        powerup.y + 60
                    )

                    -- Spawn synergy VFX
                    local synergyKey = result.synergyMessage:match("^%S+")
                    if synergyKey then
                        synergyKey = synergyKey:upper():gsub("[^%w]", "_")
                        VFXLibrary.spawnSynergyEffect(synergyKey, powerup.x, powerup.y + 60)
                    end
                end
            end

            -- Handle special effects
            if result and result.message == "SCREEN_CLEAR" then
                for _, enemy in ipairs(self.enemies) do
                    enemy.dead = true
                end
                print("SCREEN CLEARED!")
            end

            table.remove(self.powerups, i)
        elseif powerup.lifetime <= 0 then
            table.remove(self.powerups, i)
        end
    end
end

function PlayingState:updateBoss(dt)
    if BossSystem.activeBoss then
        local newProjectiles = BossSystem.activeBoss:update(dt, self.player.x, self.player.y)

        -- Add boss projectiles if any were fired
        if newProjectiles then
            for _, proj in ipairs(newProjectiles) do
                table.insert(self.bossProjectiles, proj)
            end
        end

        -- Check player projectile collisions with boss
        for i = #self.player.projectiles, 1, -1 do
            local proj = self.player.projectiles[i]
            if BossSystem.activeBoss and not BossSystem.activeBoss.invulnerable then
                -- Use CollisionSystem for circle-to-circle collision
                if CollisionSystem.checkProjectileBossCollision(proj, BossSystem.activeBoss) then
                    BossSystem.activeBoss:takeDamage(proj.damage or 10)
                    table.remove(self.player.projectiles, i)
                end
            end
        end

        -- Check if boss is defeated
        if BossSystem.activeBoss and not BossSystem.activeBoss.alive then
            BossSystem.activeBoss = nil
        end
    end

    -- Update boss projectiles
    for i = #self.bossProjectiles, 1, -1 do
        local proj = self.bossProjectiles[i]
        proj:update(dt)

        -- Remove if dead or off screen
        if proj.dead or proj.y > 1080 or proj.y < -50 or proj.x < -50 or proj.x > 1970 then
            table.remove(self.bossProjectiles, i)
        else
            -- Check collision with player using CollisionSystem
            if CollisionSystem.checkBossProjectilePlayerCollision(proj, self.player) then
                if not self.player.invulnerable then
                    self.player.hp = self.player.hp - proj.damage
                    self.player.invulnerable = true
                    self.player.invulnerableTimer = 0.5
                    self.player.damageFlashTime = 0.1

                    if self.player.hp <= 0 then
                        self.player.hp = 0
                        local Gamestate = require("libs.hump-master.gamestate")
                        Gamestate.switch(require("src.states.GameOverState"), {
                            player = self.player,
                            enemies = self.enemies,
                            musicReactor = self.musicReactor
                        })
                        return
                    end
                end
                table.remove(self.bossProjectiles, i)
            end
        end
    end
end

function PlayingState:calculateDropChance(orbType, playerLevel, time)
    local base = (orbType == "primary") and 0.05 or 0.08
    local levelBonus = (playerLevel - 1) * 0.005
    local timeBonus = (time / 60) * 0.001
    local total = base + levelBonus + timeBonus

    -- Cap: primary at 0.25, secondary at 0.35
    local cap = (orbType == "primary") and 0.25 or 0.35
    return math.min(total, cap)
end

function PlayingState:spawnOrbsForEnemy(enemy)
    local orbX = enemy.x + enemy.width / 2
    local orbY = enemy.y + enemy.height / 2

    -- Clamp orb spawn to inner 70% of screen
    local playWidth = self.screenWidth * 0.7
    local playHeight = self.screenHeight * 0.7
    local leftBound = (self.screenWidth - playWidth) / 2
    local topBound = (self.screenHeight - playHeight) / 2

    orbX = math.max(leftBound, math.min(leftBound + playWidth, orbX))
    orbY = math.max(topBound, math.min(topBound + playHeight, orbY))

    local orbs = {}

    -- Always spawn basic XP particle orb
    table.insert(orbs, XPParticleSystem.new(orbX, orbY, 10))

    -- Check if player has picked first color
    local colorHistory = ColorSystem.colorHistory or {}
    if #colorHistory > 0 then
        local primaryColor = colorHistory[1]
        local playerLevel = self.player.level

        -- Roll for medium XP orb
        local primaryChance = self:calculateDropChance("primary", playerLevel, self.gameTime)
        if math.random() < primaryChance then
            local offsetX = orbX + math.random(-20, 20)
            offsetX = math.max(leftBound, math.min(leftBound + playWidth, offsetX))
            table.insert(orbs, XPParticleSystem.new(offsetX, orbY, 20))
        end

        -- Roll for large XP orb
        local secondaryChance = self:calculateDropChance("secondary", playerLevel, self.gameTime)
        if math.random() < secondaryChance then
            local offsetX = orbX + math.random(-20, 20)
            offsetX = math.max(leftBound, math.min(leftBound + playWidth, offsetX))
            table.insert(orbs, XPParticleSystem.new(offsetX, orbY, 40))
        end
    end

    return orbs
end

function PlayingState:draw()
    -- Draw music-reactive shader background
    BackgroundShader.draw()

    -- Draw simple grid (replaces shader for testing)
    SimpleGrid.draw()

    -- Draw vaporwave background (stars/particles on top of shader)
    -- DISABLED FOR TESTING
    -- World.draw()

    -- Draw grid attack system (under entities)
    -- DISABLED FOR TESTING
    -- GridAttackSystem.draw(false)  -- Set to true for debug grid

    self.player:draw()

    -- Draw enemies
    for _, enemy in ipairs(self.enemies) do
        enemy:draw(self.musicReactor)

        -- Draw enemy info (HP, DoT, Root indicators)
        UISystem.drawEnemyInfo(enemy)

        -- Debug trace line from enemy to player
        local enemyCenterX = enemy.x + enemy.width / 2
        local enemyCenterY = enemy.y + enemy.height / 2
        local playerCenterX = self.player.x + self.player.width / 2
        local playerCenterY = self.player.y + self.player.height / 2

        love.graphics.setColor(1, 0, 0, 0.3)
        love.graphics.setLineWidth(1)
        love.graphics.line(enemyCenterX, enemyCenterY, playerCenterX, playerCenterY)
    end

    -- Draw boss if active
    if BossSystem.activeBoss then
        BossSystem.activeBoss:draw()
    end

    -- Draw boss projectiles
    for _, proj in ipairs(self.bossProjectiles) do
        proj:draw()
    end

    -- Draw XP orbs
    for _, orb in ipairs(self.xpOrbs) do
        orb:draw(false)
    end

    -- Draw powerups
    for _, powerup in ipairs(self.powerups) do
        powerup:draw()
    end

    -- Draw explosions (MAGENTA AoE)
    for _, explosion in ipairs(self.explosions) do
        love.graphics.setColor(1, 0.2, 1, 0.6 * (explosion.lifetime / 0.5))
        love.graphics.circle("fill", explosion.x, explosion.y, explosion.radius * (explosion.lifetime / 0.5))
        love.graphics.setColor(1, 0.2, 1, 0.9)
        love.graphics.circle("line", explosion.x, explosion.y, explosion.radius)
    end

    -- Draw player HUD using UISystem
    UISystem.drawPlayerHUD(self.player)

    -- Draw VFX particles
    VFXLibrary.draw()
    
    -- Draw impact burst particles
    VFXLibrary.drawImpactBursts()

    -- Draw floating text (on top of everything)
    FloatingTextSystem.draw()

    -- Draw debug menu overlay
    local DebugMenu = require("src.systems.DebugMenu")
    DebugMenu.draw(self.player)
end

function PlayingState:keypressed(key)
    -- ESC exits game
    if key == "escape" then
        love.event.quit()
        return
    end

    -- Spacebar: Dash (permanent ability)
    if key == "space" then
        if self.player:useDash() then
            print("[Input] Dash activated!")
        end
        return
    end

    -- TEST: Trigger grid wave animations (for development)
    if key == "t" then
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

    -- Left Shift: Use active artifact ability (for future)
    if key == "lshift" then
        if self.player:useActiveAbility() then
            print("[Input] Active artifact ability used!")
        end
        return
    end

    -- Debug helpers (F1-F5)
    if key == "f1" then
        self.player:addExp(self.player.expToNext)
        print("[DEBUG] Instant level up to level " .. self.player.level)
    elseif key == "f2" then
        local Enemy = require("src.entities.Enemy")
        for i = 1, 10 do
            local angle = (i / 10) * math.pi * 2
            local distance = 200
            local spawnX = self.player.x + math.cos(angle) * distance
            local spawnY = self.player.y + math.sin(angle) * distance
            table.insert(self.enemies, Enemy(spawnX, spawnY))
        end
        print("[DEBUG] Spawned 10 enemies")
    elseif key == "f3" then
        print("[DEBUG] Color System State:")
        print("  Primary: " .. tostring(ColorSystem.primaryColor) .. " (count: " .. ColorSystem.primaryCount .. ")")
        print("  Secondary: " .. tostring(ColorSystem.secondaryColor) .. " (count: " .. ColorSystem.secondaryCount .. ")")
        print("  Tertiary: " .. tostring(ColorSystem.tertiaryColor) .. " (count: " .. ColorSystem.tertiaryCount .. ")")
        print("  Level: " .. self.player.level)
        local choices = ColorSystem.getValidChoices(self.player.level)
        print("  Valid choices: " .. table.concat(choices, ", "))
    elseif key == "f4" then
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
    elseif key == "f5" then
        self.player.hp = self.player.maxHp
        print("[DEBUG] Full heal")
    elseif key == "f8" then
        local playerCenterX = self.player.x + self.player.width / 2
        local playerCenterY = self.player.y + self.player.height / 2
        table.insert(self.xpOrbs, XPParticleSystem.new(playerCenterX, playerCenterY, 10))
        print("[DEBUG] Spawned basic XP particle orb (10 XP)")
    elseif key == "f9" then
        local playerCenterX = self.player.x + self.player.width / 2
        local playerCenterY = self.player.y + self.player.height / 2
        table.insert(self.xpOrbs, XPParticleSystem.new(playerCenterX, playerCenterY, 20))
        print("[DEBUG] Spawned medium XP particle orb (20 XP)")
    elseif key == "f10" then
        local playerCenterX = self.player.x + self.player.width / 2
        local playerCenterY = self.player.y + self.player.height / 2
        table.insert(self.xpOrbs, XPParticleSystem.new(playerCenterX, playerCenterY, 40))
        print("[DEBUG] Spawned large XP particle orb (40 XP)")
    elseif key == "f11" then
        local primaryChance = self:calculateDropChance("primary", self.player.level, self.gameTime)
        local secondaryChance = self:calculateDropChance("secondary", self.player.level, self.gameTime)
        print(string.format("[DEBUG] Drop Chances - Primary: %.1f%%, Secondary: %.1f%%",
            primaryChance * 100, secondaryChance * 100))
        print(string.format("[DEBUG] Game Time: %.1fs, Level: %d", self.gameTime, self.player.level))
    elseif key == "l" then
        self.player.exp = self.player.exp + 50
    end

    -- DebugMenu system
    local DebugMenu = require("src.systems.DebugMenu")
    DebugMenu.keypressed(key, self.player, self.enemies, self.musicReactor)
end

return PlayingState
