-- Debug Menu System
-- Hierarchical menu system (like phone menus)

local DebugMenu = {}

DebugMenu.enabled = true
DebugMenu.musicPaused = false
DebugMenu.currentMenu = nil  -- nil = main menu, "color", "artifact", "enemy", "player"
DebugMenu.helpVisible = false

-- Initialize debug system
function DebugMenu.init()
    print("=== DEBUG MENU ENABLED ===")
    print("Press H to toggle help | Press 1-9 for menus")
end

-- Show debug help overlay
function DebugMenu.showHelp()
    DebugMenu.helpVisible = not DebugMenu.helpVisible
    if DebugMenu.helpVisible then
        print("\n========== DEBUG MENU ==========")
        print("MAIN MENU (when no submenu active):")
        print("  H - Toggle this help on screen")
        print("  1 - Color Menu")
        print("  2 - Artifact Menu")
        print("  3 - Enemy Menu")
        print("  4 - Player Menu")
        print("  5 - Music Menu")
        print("  ESC - Exit submenu / Quit game")
        print("")
        print("COLOR MENU (Press 1):")
        print("  1 - Add RED +1")
        print("  2 - Add GREEN +1")
        print("  3 - Add BLUE +1")
        print("  4 - Add YELLOW +1")
        print("  5 - Add MAGENTA +1")
        print("  6 - Add CYAN +1")
        print("  0 - Add +10 to last selected color")
        print("")
        print("ARTIFACT MENU (Press 2):")
        print("  1 - Add LENS +1")
        print("  2 - Add MIRROR +1")
        print("  3 - Add PRISM +1")
        print("  4 - Add HALO +1")
        print("  5 - Add DIFFUSION +1")
        print("  0 - Add +3 to last selected artifact")
        print("")
        print("ENEMY MENU (Press 3):")
        print("  1 - Spawn basic enemy")
        print("  2 - Spawn fast enemy")
        print("  3 - Spawn tank enemy")
        print("  4 - Spawn boss")
        print("  9 - Kill all enemies")
        print("")
        print("PLAYER MENU (Press 4):")
        print("  1 - Add 100 XP")
        print("  2 - Add 1000 XP")
        print("  3 - Full heal")
        print("  4 - Decrease speed")
        print("  5 - Increase speed")
        print("  6 - Toggle invincibility")
        print("")
        print("MUSIC MENU (Press 5):")
        print("  1 - Pause/Resume")
        print("  2 - Restart song")
        print("================================\n")
    else
        print("[DEBUG] Help hidden")
    end
end

-- Show current menu state
function DebugMenu.showMenuState()
    if DebugMenu.currentMenu == "color" then
        print("[DEBUG MENU] COLOR - Pick: 1=RED 2=GREEN 3=BLUE 4=YELLOW 5=MAGENTA 6=CYAN 0=+10")
    elseif DebugMenu.currentMenu == "artifact" then
        print("[DEBUG MENU] ARTIFACT - Pick: 1=LENS 2=MIRROR 3=PRISM 4=HALO 5=DIFFUSION 0=+3")
    elseif DebugMenu.currentMenu == "enemy" then
        print("[DEBUG MENU] ENEMY - Pick: 1=Basic 2=Fast 3=Tank 4=Boss 9=Kill All")
    elseif DebugMenu.currentMenu == "player" then
        print("[DEBUG MENU] PLAYER - Pick: 1=+100XP 2=+1000XP 3=Heal 4=SlowDown 5=SpeedUp 6=Invincible")
    elseif DebugMenu.currentMenu == "music" then
        print("[DEBUG MENU] MUSIC - Pick: 1=Pause/Resume 2=Restart")
    end
end

-- Handle key presses
function DebugMenu.keypressed(key, player, enemies, musicReactor)
    if not DebugMenu.enabled then return end
    
    local ColorSystem = require("src.systems.ColorSystem")
    local ArtifactManager = require("src.systems.ArtifactManager")
    
    -- === HELP TOGGLE (ALWAYS ACTIVE) ===
    if key == "h" then
        DebugMenu.showHelp()
        return
    end
    
    -- === MAIN MENU (when no submenu active) ===
    if not DebugMenu.currentMenu then
        if key == "1" then
            DebugMenu.currentMenu = "color"
            DebugMenu.showMenuState()
        elseif key == "2" then
            DebugMenu.currentMenu = "artifact"
            DebugMenu.showMenuState()
        elseif key == "3" then
            DebugMenu.currentMenu = "enemy"
            DebugMenu.showMenuState()
        elseif key == "4" then
            DebugMenu.currentMenu = "player"
            DebugMenu.showMenuState()
        elseif key == "5" then
            DebugMenu.currentMenu = "music"
            DebugMenu.showMenuState()
        end
        return
    end
    
    -- === ESCAPE TO EXIT SUBMENU ===
    if key == "escape" then
        if DebugMenu.currentMenu then
            print("[DEBUG MENU] Exited " .. DebugMenu.currentMenu .. " menu")
            DebugMenu.currentMenu = nil
            return
        end
    end
    
    -- === COLOR MENU ===
    if DebugMenu.currentMenu == "color" then
        DebugMenu.lastColorChoice = DebugMenu.lastColorChoice or "r"
        
        if key == "1" then
            ColorSystem.addColor(player.weapon, "r")
            DebugMenu.lastColorChoice = "r"
            print("[COLOR] Added RED (Level: " .. ColorSystem.primary.RED.level .. ")")
        elseif key == "2" then
            ColorSystem.addColor(player.weapon, "g")
            DebugMenu.lastColorChoice = "g"
            print("[COLOR] Added GREEN (Level: " .. ColorSystem.primary.GREEN.level .. ")")
        elseif key == "3" then
            ColorSystem.addColor(player.weapon, "b")
            DebugMenu.lastColorChoice = "b"
            print("[COLOR] Added BLUE (Level: " .. ColorSystem.primary.BLUE.level .. ")")
        elseif key == "4" then
            if ColorSystem.secondary.YELLOW.unlocked then
                ColorSystem.addColor(player.weapon, "y")
                DebugMenu.lastColorChoice = "y"
                print("[COLOR] Added YELLOW (Level: " .. ColorSystem.secondary.YELLOW.level .. ")")
            else
                print("[COLOR] YELLOW locked (need RED+GREEN L10)")
            end
        elseif key == "5" then
            if ColorSystem.secondary.MAGENTA.unlocked then
                ColorSystem.addColor(player.weapon, "m")
                DebugMenu.lastColorChoice = "m"
                print("[COLOR] Added MAGENTA (Level: " .. ColorSystem.secondary.MAGENTA.level .. ")")
            else
                print("[COLOR] MAGENTA locked (need RED+BLUE L10)")
            end
        elseif key == "6" then
            if ColorSystem.secondary.CYAN.unlocked then
                ColorSystem.addColor(player.weapon, "c")
                DebugMenu.lastColorChoice = "c"
                print("[COLOR] Added CYAN (Level: " .. ColorSystem.secondary.CYAN.level .. ")")
            else
                print("[COLOR] CYAN locked (need GREEN+BLUE L10)")
            end
        elseif key == "0" then
            -- Add +10 to last selected
            for i = 1, 10 do
                ColorSystem.addColor(player.weapon, DebugMenu.lastColorChoice)
            end
            print("[COLOR] Added +" .. 10 .. " to last selected")
        end
        
        -- Update weapon stats
        if player and player.weapon then
            ColorSystem.applyEffects(player.weapon)
        end
        
        DebugMenu.currentMenu = nil  -- Exit menu after selection
        
    -- === ARTIFACT MENU ===
    elseif DebugMenu.currentMenu == "artifact" then
        DebugMenu.lastArtifactChoice = DebugMenu.lastArtifactChoice or "LENS"
        
        if key == "1" then
            ArtifactManager.collect("LENS", player.weapon, player)
            DebugMenu.lastArtifactChoice = "LENS"
            print("[ARTIFACT] LENS Level: " .. ArtifactManager.getLevel("LENS"))
        elseif key == "2" then
            ArtifactManager.collect("MIRROR", player.weapon, player)
            DebugMenu.lastArtifactChoice = "MIRROR"
            print("[ARTIFACT] MIRROR Level: " .. ArtifactManager.getLevel("MIRROR"))
        elseif key == "3" then
            ArtifactManager.collect("PRISM", player.weapon, player)
            DebugMenu.lastArtifactChoice = "PRISM"
            print("[ARTIFACT] PRISM Level: " .. ArtifactManager.getLevel("PRISM"))
        elseif key == "4" then
            ArtifactManager.collect("HALO", player.weapon, player)
            DebugMenu.lastArtifactChoice = "HALO"
            print("[ARTIFACT] HALO Level: " .. ArtifactManager.getLevel("HALO"))
        elseif key == "5" then
            ArtifactManager.collect("DIFFUSION", player.weapon, player)
            DebugMenu.lastArtifactChoice = "DIFFUSION"
            print("[ARTIFACT] DIFFUSION Level: " .. ArtifactManager.getLevel("DIFFUSION"))
        elseif key == "0" then
            -- Add +3 to last selected
            for i = 1, 3 do
                ArtifactManager.collect(DebugMenu.lastArtifactChoice, player.weapon, player)
            end
            print("[ARTIFACT] Added +3 to " .. DebugMenu.lastArtifactChoice)
        end
        
        DebugMenu.currentMenu = nil  -- Exit menu after selection
        
    -- === ENEMY MENU ===
    elseif DebugMenu.currentMenu == "enemy" then
        if key == "1" then
            DebugMenu.spawnEnemy(enemies, player, "basic")
        elseif key == "2" then
            DebugMenu.spawnEnemy(enemies, player, "fast")
        elseif key == "3" then
            DebugMenu.spawnEnemy(enemies, player, "tank")
        elseif key == "4" then
            DebugMenu.spawnEnemy(enemies, player, "boss")
        elseif key == "9" then
            if enemies then
                for _, enemy in ipairs(enemies) do
                    enemy.dead = true
                end
                print("[ENEMY] Killed all enemies")
            end
        end
        
        DebugMenu.currentMenu = nil
        
    -- === PLAYER MENU ===
    elseif DebugMenu.currentMenu == "player" then
        if key == "1" then
            if player then
                player:addExp(100)
                print("[PLAYER] Added 100 XP")
            end
        elseif key == "2" then
            if player then
                player:addExp(1000)
                print("[PLAYER] Added 1000 XP")
            end
        elseif key == "3" then
            if player then
                player.hp = player.maxHp
                print("[PLAYER] Full heal")
            end
        elseif key == "4" then
            if player then
                player.speed = math.max(50, player.speed - 50)
                print("[PLAYER] Speed: " .. player.speed)
            end
        elseif key == "5" then
            if player then
                player.speed = player.speed + 50
                print("[PLAYER] Speed: " .. player.speed)
            end
        elseif key == "6" then
            if player then
                player.godMode = not player.godMode
                if player.godMode then
                    print("[PLAYER] INVINCIBILITY ON")
                else
                    print("[PLAYER] INVINCIBILITY OFF")
                end
            end
        end
        
        DebugMenu.currentMenu = nil
        
    -- === MUSIC MENU ===
    elseif DebugMenu.currentMenu == "music" then
        if key == "1" then
            if musicReactor and musicReactor.music then
                if DebugMenu.musicPaused then
                    musicReactor.music:play()
                    print("[MUSIC] Resumed")
                else
                    musicReactor.music:pause()
                    print("[MUSIC] Paused")
                end
                DebugMenu.musicPaused = not DebugMenu.musicPaused
            end
        elseif key == "2" then
            if musicReactor and musicReactor.music then
                musicReactor.music:seek(0)
                print("[MUSIC] Restarted song")
            end
        end
        
        DebugMenu.currentMenu = nil
    end
end

-- Spawn enemy helper
function DebugMenu.spawnEnemy(enemies, player, enemyType)
    local Enemy = require("src.entities.Enemy")
    
    -- Spawn near player but offscreen
    local angle = math.random() * math.pi * 2
    local distance = 400
    local x = player.x + math.cos(angle) * distance
    local y = player.y + math.sin(angle) * distance
    
    local enemy
    if enemyType == "basic" then
        enemy = Enemy:new(x, y, "formation")
        enemy.speed = 80
        enemy.hp = 50
        enemy.maxHp = 50
        enemy.damage = 10
        print("[ENEMY] Spawned basic enemy")
        
    elseif enemyType == "fast" then
        enemy = Enemy:new(x, y, "flanker")
        enemy.speed = 150
        enemy.hp = 30
        enemy.maxHp = 30
        enemy.damage = 5
        enemy.color = {1, 1, 0}  -- Yellow
        print("[ENEMY] Spawned fast enemy")
        
    elseif enemyType == "tank" then
        enemy = Enemy:new(x, y, "BASS")
        enemy.speed = 40
        enemy.hp = 200
        enemy.maxHp = 200
        enemy.damage = 20
        enemy.width = 48
        enemy.height = 48
        enemy.color = {0.5, 0.5, 0.5}  -- Gray
        print("[ENEMY] Spawned tank enemy")
        
    elseif enemyType == "boss" then
        local Boss = require("src.entities.Boss")
        enemy = Boss:new(x, y, 1)
        print("[ENEMY] Spawned boss")
    end
    
    if enemy then
        table.insert(enemies, enemy)
    end
end

-- Draw debug overlay
function DebugMenu.draw(player)
    if not DebugMenu.enabled then return end
    
    local ColorSystem = require("src.systems.ColorSystem")
    local ArtifactManager = require("src.systems.ArtifactManager")
    
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local panelWidth = 310
    local panelHeight = 280
    local panelX = 10
    local panelY = screenHeight - panelHeight - 10
    
    -- Draw background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight)
    
    -- Draw border
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight)
    
    local textX = panelX + 10
    local textY = panelY + 10
    local lineHeight = 18
    
    -- === HEADER ===
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("DEBUG MENU (H for help)", textX, textY)
    textY = textY + lineHeight + 5
    
    -- Show current menu state
    if DebugMenu.currentMenu then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.print("MENU: " .. string.upper(DebugMenu.currentMenu), textX, textY)
        textY = textY + lineHeight + 5
    else
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.print("Press 1-5 for menu", textX, textY)
        textY = textY + lineHeight + 5
    end
    
    -- === PLAYER STATS ===
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("HP: " .. math.floor(player.hp) .. "/" .. player.maxHp, textX, textY)
    textY = textY + lineHeight
    
    love.graphics.print("Level: " .. player.level .. " | XP: " .. math.floor(player.exp), textX, textY)
    textY = textY + lineHeight
    
    love.graphics.print("Speed: " .. math.floor(player.speed), textX, textY)
    textY = textY + lineHeight + 3
    
    -- === COLORS ===
    love.graphics.setColor(1, 0.5, 0.5, 1)
    love.graphics.print("R:" .. ColorSystem.primary.RED.level, textX, textY)
    love.graphics.setColor(0.5, 1, 0.5, 1)
    love.graphics.print(" G:" .. ColorSystem.primary.GREEN.level, textX + 50, textY)
    love.graphics.setColor(0.5, 0.5, 1, 1)
    love.graphics.print(" B:" .. ColorSystem.primary.BLUE.level, textX + 100, textY)
    textY = textY + lineHeight
    
    if ColorSystem.secondary.YELLOW.unlocked then
        love.graphics.setColor(1, 1, 0.5, 1)
        love.graphics.print("Y:" .. ColorSystem.secondary.YELLOW.level, textX, textY)
    end
    if ColorSystem.secondary.MAGENTA.unlocked then
        love.graphics.setColor(1, 0.5, 1, 1)
        love.graphics.print(" M:" .. ColorSystem.secondary.MAGENTA.level, textX + 50, textY)
    end
    if ColorSystem.secondary.CYAN.unlocked then
        love.graphics.setColor(0.5, 1, 1, 1)
        love.graphics.print(" C:" .. ColorSystem.secondary.CYAN.level, textX + 100, textY)
    end
    textY = textY + lineHeight + 3
    
    -- === ARTIFACTS ===
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.print("LENS:" .. ArtifactManager.getLevel("LENS"), textX, textY)
    love.graphics.print(" MIR:" .. ArtifactManager.getLevel("MIRROR"), textX + 80, textY)
    textY = textY + lineHeight
    
    love.graphics.print("PRISM:" .. ArtifactManager.getLevel("PRISM"), textX, textY)
    love.graphics.print(" HALO:" .. ArtifactManager.getLevel("HALO"), textX + 80, textY)
    textY = textY + lineHeight
    
    love.graphics.print("DIFF:" .. ArtifactManager.getLevel("DIFFUSION"), textX, textY)
    textY = textY + lineHeight + 3
    
    -- === MUSIC STATUS ===
    if DebugMenu.musicPaused then
        love.graphics.setColor(1, 0.5, 0.5, 1)
        love.graphics.print("MUSIC: PAUSED", textX, textY)
    else
        love.graphics.setColor(0.5, 1, 0.5, 1)
        love.graphics.print("MUSIC: PLAYING", textX, textY)
    end
    
    -- === HELP DISPLAY ===
    if DebugMenu.helpVisible then
        local helpX = screenWidth / 2 - 250
        local helpY = 50
        local helpWidth = 500
        local helpHeight = 550
        
        -- Background
        love.graphics.setColor(0, 0, 0, 0.95)
        love.graphics.rectangle("fill", helpX, helpY, helpWidth, helpHeight)
        
        -- Border
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", helpX, helpY, helpWidth, helpHeight)
        
        -- Help text
        local helpTextY = helpY + 15
        local helpTextX = helpX + 15
        
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.print("=== DEBUG MENU HELP ===", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight + 5
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("MAIN MENU (no submenu):", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print("  1 - Color Menu", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.print("  2 - Artifact Menu", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.print("  3 - Enemy Menu", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.print("  4 - Player Menu", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.print("  5 - Music Menu", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.print("  H - Toggle help | ESC - Exit", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight + 5
        
        love.graphics.setColor(1, 0.5, 0.5, 1)
        love.graphics.print("COLOR MENU:", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print("  1-6: Add R/G/B/Y/M/C +1", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.print("  0: Add +10 to last", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight + 3
        
        love.graphics.setColor(0.5, 1, 1, 1)
        love.graphics.print("ARTIFACT MENU:", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print("  1: LENS | 2: MIRROR", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.print("  3: PRISM | 4: HALO", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.print("  5: DIFFUSION | 0: +3 last", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight + 3
        
        love.graphics.setColor(1, 0.5, 0.5, 1)
        love.graphics.print("ENEMY MENU:", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print("  1: Basic | 2: Fast", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.print("  3: Tank | 4: Boss", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.print("  9: Kill all", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight + 3
        
        love.graphics.setColor(0.5, 1, 0.5, 1)
        love.graphics.print("PLAYER MENU:", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print("  1: +100 XP | 2: +1000 XP", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.print("  3: Heal | 4: Slow | 5: Fast", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.print("  6: Toggle Invincibility", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight + 3
        
        love.graphics.setColor(1, 1, 0.5, 1)
        love.graphics.print("MUSIC MENU:", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print("  1: Pause/Resume", helpTextX, helpTextY)
        helpTextY = helpTextY + lineHeight
        love.graphics.print("  2: Restart song", helpTextX, helpTextY)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return DebugMenu
