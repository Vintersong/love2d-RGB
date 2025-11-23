-- UISystem: Handles all UI rendering with clean text-based display
local UISystem = {}
local ColorSystem = require("src.systems.ColorSystem")

-- Constant screen dimensions (1920x1080)
local SCREEN_WIDTH = 1920
local SCREEN_HEIGHT = 1080

-- Draw player HUD (top-left corner)
function UISystem.drawPlayerHUD(player)
    local x, y = 20, 20
    local lineHeight = 35
    
    love.graphics.setColor(1, 1, 1)
    
    -- Level
    love.graphics.print(string.format("Level: %d", player.level), x, y, 0, 1.5, 1.5)
    y = y + lineHeight
    
    -- Health
    local hpPercent = player.hp / player.maxHp
    local hpColor = {1, 1, 1}
    if hpPercent > 0.5 then
        hpColor = {0.2, 1, 0.2}  -- Green
    elseif hpPercent > 0.25 then
        hpColor = {1, 1, 0.2}  -- Yellow
    else
        hpColor = {1, 0.2, 0.2}  -- Red
    end
    
    love.graphics.setColor(hpColor)
    love.graphics.print(string.format("Health: %d / %d (%.0f%%)", 
        math.floor(player.hp), player.maxHp, hpPercent * 100), x, y, 0, 1.5, 1.5)
    y = y + lineHeight
    
    -- XP
    love.graphics.setColor(0.2, 1, 0.8)
    local xpPercent = player.exp / player.expToNext
    love.graphics.print(string.format("XP: %d / %d (%.0f%%)", 
        player.exp, player.expToNext, xpPercent * 100), x, y, 0, 1.5, 1.5)
    y = y + lineHeight
    
    -- Color Affinity
    local affinityText = UISystem.getAffinityText()
    love.graphics.setColor(1, 0.8, 0.2)
    love.graphics.print("Color Affinity: " .. affinityText, x, y, 0, 1.5, 1.5)
    y = y + lineHeight
    
    -- Weapon stats
    if player.weapon then
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print(string.format("Damage: %.0f | Fire Rate: %.2fs", 
            player.weapon.damage, player.weapon.fireRate), x, y, 0, 1.2, 1.2)
        y = y + 25
        
        -- Debug: Show projectile calculation
        local projCount = 1  -- Base
        if player.weapon.guaranteedBullets then
            projCount = projCount + player.weapon.guaranteedBullets
        end
        if player.weapon.secondaryGuaranteedBullets then
            projCount = projCount + player.weapon.secondaryGuaranteedBullets
        end
        love.graphics.setColor(0.5, 0.8, 1)
        love.graphics.print(string.format("Projectiles: %d guaranteed", projCount), x, y, 0, 1.1, 1.1)
    end
    y = y + 5
    
    -- Active Synergies and Artifacts
    local SynergySystem = require("src.systems.SynergySystem")
    local ArtifactManager = require("src.systems.ArtifactManager")
    local synergyCount = SynergySystem.getCount()
    local artifactCount = ArtifactManager.getCount()
    
    if artifactCount > 0 then
        love.graphics.setColor(0.5, 1, 1)  -- Cyan for artifacts
        love.graphics.print(string.format("💎 Artifacts: %d", artifactCount), x, y, 0, 1.2, 1.2)
        y = y + 25
    end
    
    if synergyCount > 0 then
        love.graphics.setColor(1, 0.5, 1)  -- Magenta for synergies
        love.graphics.print(string.format("⚡ Synergies: %d", synergyCount), x, y, 0, 1.2, 1.2)
    end
    
    -- Dash Ability (always visible - permanent ability, centered at bottom)
    local dashY = SCREEN_HEIGHT - 100
    local barWidth = 250
    local barHeight = 25
    local dashX = (SCREEN_WIDTH / 2) - (barWidth / 2)  -- Center horizontally

    -- Background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
    love.graphics.rectangle("fill", dashX - 10, dashY - 10, barWidth + 20, 75)

    -- Dash name (centered)
    love.graphics.setColor(0.5, 1, 1)
    local titleText = "DASH [SPACE]"
    local font = love.graphics.getFont()
    local titleWidth = font:getWidth(titleText) * 1.5
    love.graphics.print(titleText, dashX + (barWidth - titleWidth) / 2, dashY - 5, 0, 1.5, 1.5)

    -- Cooldown bar (using AbilitySystem)
    local AbilitySystem = require("src.systems.AbilitySystem")
    local AbilityLibrary = require("src.data.AbilityLibrary")

    local dashCdPercent = AbilitySystem.getCooldownProgress(player, "DASH", AbilityLibrary.DASH)
    local dashState = AbilitySystem.getState(player, "DASH")
    local dashCooldown = dashState and dashState.cooldown or 0

    love.graphics.setColor(0.2, 0.2, 0.3)
    love.graphics.rectangle("fill", dashX, dashY + 30, barWidth, barHeight)

    if dashCdPercent >= 1 then
        -- Ready (green pulse)
        local pulse = math.sin(love.timer.getTime() * 5) * 0.3 + 0.7
        love.graphics.setColor(0.2 * pulse, 1 * pulse, 0.2 * pulse)
        love.graphics.rectangle("fill", dashX, dashY + 30, barWidth, barHeight)
        love.graphics.setColor(0.5, 1, 0.5)
        love.graphics.print("READY", dashX + (barWidth / 2) - 30, dashY + 32, 0, 1.3, 1.3)
    else
        -- Cooling down (cyan fill)
        love.graphics.setColor(0.2, 0.8, 1)
        love.graphics.rectangle("fill", dashX, dashY + 30, barWidth * dashCdPercent, barHeight)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("%.1fs", dashCooldown), dashX + (barWidth / 2) - 20, dashY + 32, 0, 1.3, 1.3)
    end

    -- Border
    love.graphics.setColor(0.5, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", dashX, dashY + 30, barWidth, barHeight)

    -- Active Artifact Ability (if equipped)
    if player.activeAbility then
        local abilityY = SCREEN_HEIGHT - 200

        -- Background
        love.graphics.setColor(0.2, 0.1, 0.2, 0.8)
        love.graphics.rectangle("fill", x - 5, abilityY - 5, 220, 70)

        -- Ability name
        love.graphics.setColor(1, 0.5, 1)
        love.graphics.print(string.format("%s [L-SHIFT]", player.activeAbility), x, abilityY, 0, 1.3, 1.3)

        -- Cooldown bar
        local cdPercent = 1 - (player.abilityCooldown / player.abilityMaxCooldown)

        love.graphics.setColor(0.2, 0.2, 0.3)
        love.graphics.rectangle("fill", x, abilityY + 25, barWidth, barHeight)

        if cdPercent >= 1 then
            -- Ready (magenta pulse)
            local pulse = math.sin(love.timer.getTime() * 5) * 0.3 + 0.7
            love.graphics.setColor(1 * pulse, 0.2 * pulse, 1 * pulse)
            love.graphics.rectangle("fill", x, abilityY + 25, barWidth, barHeight)
            love.graphics.setColor(1, 0.5, 1)
            love.graphics.print("READY", x + 75, abilityY + 27, 0, 1.2, 1.2)
        else
            -- Cooling down (magenta fill)
            love.graphics.setColor(0.8, 0.2, 0.8)
            love.graphics.rectangle("fill", x, abilityY + 25, barWidth * cdPercent, barHeight)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(string.format("%.1fs", player.abilityCooldown), x + 75, abilityY + 27, 0, 1.2, 1.2)
        end

        -- Border
        love.graphics.setColor(1, 0.5, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, abilityY + 25, barWidth, barHeight)
    end

    -- Controls (bottom-left)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("WASD: Move | SPACE: Dash | L-SHIFT: Ability | ESC: Exit", x, SCREEN_HEIGHT - 40, 0, 1.2, 1.2)

    -- Draw artifact panel on right side
    UISystem.drawArtifactPanel(player)
end

-- Draw artifact panel (right side of screen)
function UISystem.drawArtifactPanel(player)
    local ArtifactManager = require("src.systems.ArtifactManager")
    local artifacts = ArtifactManager.getCollectedArtifacts()
    
    if #artifacts == 0 then return end
    
    local panelWidth = 350
    local panelX = SCREEN_WIDTH - panelWidth - 20
    local panelY = 20
    local lineHeight = 28
    
    -- Panel background
    love.graphics.setColor(0, 0, 0, 0.7)
    local panelHeight = math.min(60 + (#artifacts * lineHeight * 3), SCREEN_HEIGHT - 40)
    love.graphics.rectangle("fill", panelX - 10, panelY - 10, panelWidth + 20, panelHeight + 20)
    
    -- Panel border
    love.graphics.setColor(0.5, 1, 1, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX - 10, panelY - 10, panelWidth + 20, panelHeight + 20)
    
    -- Title
    love.graphics.setColor(0.5, 1, 1)
    love.graphics.print("💎 COLLECTED ARTIFACTS 💎", panelX + 30, panelY, 0, 1.4, 1.4)
    panelY = panelY + 40
    
    -- Artifact colors for visual variety
    local artifactColors = {
        PRISM = {1, 0.2, 1},      -- Magenta
        HALO = {1, 1, 0.3},       -- Gold
        MIRROR = {0.7, 0.9, 1},   -- Silver
        LENS = {0.3, 0.8, 1},     -- Blue
        AURORA = {0.4, 1, 0.8},   -- Cyan/Green
        DIFFRACTION = {1, 0.5, 0.2}, -- Orange
        REFRACTION = {0.5, 0.3, 1},  -- Purple
        SUPERNOVA = {1, 0.3, 0.2}    -- Red
    }
    
    -- Draw each artifact
    for i, artifact in ipairs(artifacts) do
        local y = panelY + ((i - 1) * lineHeight * 3)
        local color = artifactColors[artifact.type] or {1, 1, 1}
        
        -- Artifact name with level
        love.graphics.setColor(color)
        local artifactText = string.format("%s [Lv %d/%d]", 
            artifact.name, artifact.level, artifact.maxLevel)
        love.graphics.print(artifactText, panelX, y, 0, 1.3, 1.3)
        
        -- Add [WIP] tag if artifact is work-in-progress
        if artifact.isWIP then
            love.graphics.setColor(1, 1, 0)  -- Yellow
            local textWidth = love.graphics.getFont():getWidth(artifactText) * 1.3
            love.graphics.print("[WIP]", panelX + textWidth + 10, y, 0, 1.3, 1.3)
        end
        
        -- Get current effect description
        local effectDesc = UISystem.getArtifactEffectDescription(artifact.type, artifact.level, player)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print(effectDesc, panelX + 10, y + lineHeight, 0, 1.0, 1.0)
        
        -- Progress bar to next level
        if artifact.level < artifact.maxLevel then
            local barWidth = panelWidth - 20
            local barHeight = 8
            local barY = y + lineHeight * 2 + 5
            
            -- Background
            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
            love.graphics.rectangle("fill", panelX, barY, barWidth, barHeight)
            
            -- Progress (fill based on level)
            local progress = artifact.level / artifact.maxLevel
            love.graphics.setColor(color[1] * 0.8, color[2] * 0.8, color[3] * 0.8)
            love.graphics.rectangle("fill", panelX, barY, barWidth * progress, barHeight)
            
            -- Border
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", panelX, barY, barWidth, barHeight)
        else
            -- MAX label
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("MAX LEVEL", panelX + 120, y + lineHeight * 2 + 3, 0, 1.1, 1.1)
        end
    end
end

-- Get current effect description for an artifact
function UISystem.getArtifactEffectDescription(artifactType, level, player)
    if artifactType == "PRISM" then
        local bonus = player.weapon.prismBonus or 0
        return string.format("Split: +%d projectiles", bonus)
    elseif artifactType == "HALO" then
        local ArtifactManager = require("src.systems.ArtifactManager")
        local ColorSystem = require("src.systems.ColorSystem")
        local dominantColor = ColorSystem.getDominantColor()
        local level = ArtifactManager.getLevel("HALO")
        
        if not dominantColor then
            return string.format("Aura (Lv %d) - needs color", level)
        end
        
        -- Show color-specific effect
        local effectNames = {
            RED = "Fire pulse aura",
            GREEN = "Life drain aura",
            BLUE = "Slow aura",
            YELLOW = "Electric pulse heal",
            MAGENTA = "Time bubble",
            CYAN = "Frost drain"
        }
        local effectName = effectNames[dominantColor] or "Aura"
        return string.format("%s (Lv %d)", effectName, level)
    elseif artifactType == "MIRROR" then
        local reflect = player.mirrorReflection or 0
        return string.format("Reflect: %.0f%% damage", reflect * 100)
    elseif artifactType == "LENS" then
        local bonus = player.weapon.lensBonus or 0
        return string.format("Damage: +%.0f%%", bonus * 100)
    elseif artifactType == "DIFFRACTION" then
        local level = player.diffractionLevel or 0
        if level > 0 then
            return string.format("Burst patterns (Lv %d)", level)
        else
            return "Burst patterns"
        end
    elseif artifactType == "REFRACTION" then
        local level = player.refractionLevel or 0
        if level > 0 then
            return string.format("Path bending (Lv %d)", level)
        else
            return "Path bending"
        end
    elseif artifactType == "SUPERNOVA" then
        local level = player.supernovaLevel or 0
        if level > 0 then
            return string.format("Ultimate (Lv %d)", level)
        else
            return "Ultimate ability"
        end
    end
    
    return "Unknown effect"
end

-- Get color affinity display text
function UISystem.getAffinityText()
    local text = ""
    
    if ColorSystem.primaryColor then
        text = string.upper(ColorSystem.getColorName(ColorSystem.primaryColor))
        
        if ColorSystem.primaryCount > 1 then
            text = text .. " x" .. ColorSystem.primaryCount
        end
    else
        return "None"
    end
    
    if ColorSystem.secondaryColor then
        text = text .. " + " .. string.upper(ColorSystem.getColorName(ColorSystem.secondaryColor))
        
        if ColorSystem.secondaryCount > 1 then
            text = text .. " x" .. ColorSystem.secondaryCount
        end
    end
    
    if ColorSystem.tertiaryColor then
        text = text .. " + " .. string.upper(ColorSystem.getColorName(ColorSystem.tertiaryColor))
        
        if ColorSystem.tertiaryCount > 1 then
            text = text .. " x" .. ColorSystem.tertiaryCount
        end
    end
    
    return text
end

-- Draw enemy info (above enemy)
function UISystem.drawEnemyInfo(enemy)
    local x = enemy.x + enemy.width / 2
    local y = enemy.y - 15
    
    -- HP text
    local hpPercent = enemy.hp / enemy.maxHp
    local color = {1, 1, 1}
    if hpPercent > 0.7 then
        color = {0.2, 1, 0.2}
    elseif hpPercent > 0.3 then
        color = {1, 1, 0.2}
    else
        color = {1, 0.2, 0.2}
    end
    
    love.graphics.setColor(color)
    love.graphics.print(string.format("%d", math.floor(enemy.hp)), x - 10, y, 0, 0.8, 0.8)
    
    -- DoT indicator
    if enemy.dotStacks and #enemy.dotStacks > 0 then
        love.graphics.setColor(0, 1, 1)
        love.graphics.print("💧", x + 15, y - 5, 0, 0.6, 0.6)
    end
    
    -- Root indicator
    if enemy.rooted then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("⚡", x + 25, y - 5, 0, 0.6, 0.6)
    end
end

-- Draw boss info
function UISystem.drawBossInfo(boss)
    local centerX = SCREEN_WIDTH / 2
    local y = 50
    
    -- Boss title
    love.graphics.setColor(1, 0, 0)
    love.graphics.print("⚠️  FINAL BOSS  ⚠️", centerX - 150, y, 0, 2.5, 2.5)
    
    -- HP
    local hpPercent = boss.hp / boss.maxHp
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("HP: %d / %d (%.0f%%)", 
        math.floor(boss.hp), boss.maxHp, hpPercent * 100), centerX - 120, y + 45, 0, 1.8, 1.8)
end

-- Draw music analysis debug overlay (bottom-left corner)
function UISystem.drawMusicDebug(musicReactor)
    if not musicReactor or not musicReactor.isPlaying then return end
    
    local x = 20
    local y = SCREEN_HEIGHT - 180
    local barWidth = 200
    local barHeight = 15
    local lineHeight = 20
    
    -- Background panel
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x - 10, y - 10, barWidth + 120, 170)
    
    -- Title
    love.graphics.setColor(0.5, 1, 1)
    love.graphics.print("🎵 MUSIC ANALYSIS", x, y, 0, 1.2, 1.2)
    y = y + 25
    
    -- BPM and Beat
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("BPM: %.1f", musicReactor:getCurrentBPM()), x, y)
    
    -- Beat indicator
    if musicReactor:checkBeat() then
        love.graphics.setColor(1, 1, 0)
        love.graphics.circle("fill", x + barWidth + 10, y + 6, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("BEAT!", x + 100, y)
    end
    y = y + lineHeight
    
    -- Current section
    love.graphics.setColor(0.8, 0.8, 1)
    love.graphics.print(string.format("Section: %s", musicReactor:getCurrentSection():upper()), x, y)
    y = y + lineHeight
    
    -- Timing window
    local window, mult = musicReactor:getTimingWindow()
    local windowColors = {
        perfect = {1, 1, 0},
        good = {0.5, 1, 1},
        okay = {1, 1, 1},
        miss = {0.5, 0.5, 0.5}
    }
    love.graphics.setColor(windowColors[window] or {1, 1, 1})
    love.graphics.print(string.format("Timing: %s (%.1fx)", window:upper(), mult), x, y)
    y = y + lineHeight + 5
    
    -- Bass bar
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.rectangle("fill", x, y, barWidth * musicReactor:getBass(), barHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("BASS", x + barWidth + 10, y + 2, 0, 0.9, 0.9)
    y = y + barHeight + 3
    
    -- Mid bar
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    love.graphics.setColor(0.2, 1, 0.2)
    love.graphics.rectangle("fill", x, y, barWidth * musicReactor:getMid(), barHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("MID", x + barWidth + 10, y + 2, 0, 0.9, 0.9)
    y = y + barHeight + 3
    
    -- Treble bar
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    love.graphics.setColor(0.2, 0.2, 1)
    love.graphics.rectangle("fill", x, y, barWidth * musicReactor:getTreble(), barHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("TREBLE", x + barWidth + 10, y + 2, 0, 0.9, 0.9)
    y = y + barHeight + 3
    
    -- Intensity bar
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    love.graphics.setColor(1, 0.5, 1)
    love.graphics.rectangle("fill", x, y, barWidth * musicReactor:getIntensity(), barHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("ENERGY", x + barWidth + 10, y + 2, 0, 0.9, 0.9)
end

return UISystem
