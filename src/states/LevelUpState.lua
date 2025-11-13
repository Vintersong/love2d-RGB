-- LevelUpState.lua
-- Level up screen where player chooses color upgrades

local LevelUpState = {}

-- Shared data from PlayingState
LevelUpState.player = nil
LevelUpState.enemies = {}
LevelUpState.musicReactor = nil
LevelUpState.returnData = {}

function LevelUpState:enter(previous, data)
    -- Store data to pass back when returning to playing
    if data then
        self.player = data.player
        self.enemies = data.enemies or {}
        self.returnData = data
    end
end

function LevelUpState:update(dt)
    -- Pause gameplay but keep visual updates
    local World = require("src.systems.World")
    local FloatingTextSystem = require("src.systems.FloatingTextSystem")
    local VFXLibrary = require("src.systems.VFXLibrary")

    if self.returnData.musicReactor then
        self.returnData.musicReactor:update(dt)
    end

    World.update(dt, self.returnData.musicReactor)
    FloatingTextSystem.update(dt)
    VFXLibrary.update(dt)
end

function LevelUpState:draw()
    -- Draw frozen game state in background
    local World = require("src.systems.World")
    World.draw()

    self.player:draw()

    -- Draw enemies
    for _, enemy in ipairs(self.enemies) do
        enemy:draw(self.returnData.musicReactor)
    end

    -- Draw level up overlay
    self:drawColorSelect()
end

function LevelUpState:drawColorSelect()
    local ColorSystem = require("src.systems.ColorSystem")
    local ArtifactManager = require("src.systems.ArtifactManager")

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, 1920, 1080)

    local centerX = 1920 / 2
    local startY = 200

    -- Title
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("🎉 LEVEL UP! 🎉", centerX - 180, startY, 0, 3.5, 3.5)

    -- Current level
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Level " .. self.player.level, centerX - 60, startY + 90, 0, 2, 2)

    -- Current path (if any)
    if ColorSystem.primaryColor then
        local pathName = ColorSystem.getCurrentPath()
        love.graphics.setColor(0, 0.94, 1)
        love.graphics.print("Current Path: " .. pathName, centerX - 180, startY + 130, 0, 1.5, 1.5)

        -- Show tertiary unlock progress
        if ColorSystem.secondaryColor and not ColorSystem.tertiaryColor then
            local pCount = ColorSystem.primaryCount
            local sCount = ColorSystem.secondaryCount
            if pCount >= 10 and sCount >= 10 then
                love.graphics.setColor(1, 1, 0)
                love.graphics.print("⚡ TERTIARY COLOR UNLOCKED! ⚡", centerX - 250, startY + 165, 0, 1.5, 1.5)
            elseif pCount >= 10 or sCount >= 10 then
                love.graphics.setColor(1, 0.7, 0)
                local needed = ""
                if pCount < 10 then
                    needed = (10 - pCount) .. " more " .. string.upper(ColorSystem.primaryColor)
                else
                    needed = (10 - sCount) .. " more " .. string.upper(ColorSystem.secondaryColor)
                end
                love.graphics.print("Tertiary unlock in: " .. needed, centerX - 200, startY + 165, 0, 1.5, 1.5)
            end
        end
    end

    -- Get valid choices for this level
    local validChoices = ColorSystem.getValidChoices(self.player.level)

    -- Helper function to check if a color is valid
    local function isValid(color)
        for _, c in ipairs(validChoices) do
            if c == color then return true end
        end
        return false
    end

    -- Instructions
    love.graphics.setColor(1, 1, 1)
    local instructionText = ""
    if #ColorSystem.colorHistory == 0 then
        instructionText = "Choose your weapon type:"
    elseif self.player.level == 10 and #validChoices > 1 then
        instructionText = "Upgrade your path OR choose a new color to branch:"
    else
        instructionText = "Continue upgrading:"
    end
    love.graphics.print(instructionText, centerX - 250, startY + 200, 0, 1.5, 1.5)

    -- Display collected artifacts (on right side)
    local artifacts = ArtifactManager.getCollectedArtifacts()
    if #artifacts > 0 then
        local artifactX = 1920 - 350
        local artifactY = startY + 250

        love.graphics.setColor(0.5, 1, 1)
        love.graphics.print("💎 Collected Artifacts:", artifactX, artifactY, 0, 1.3, 1.3)
        artifactY = artifactY + 35

        for _, artifact in ipairs(artifacts) do
            love.graphics.setColor(0.7, 0.9, 1)
            local levelText = string.format("Lv%d/%d", artifact.level, artifact.maxLevel)
            love.graphics.print(string.format("%s %s", artifact.name, levelText),
                artifactX, artifactY, 0, 1.1, 1.1)
            artifactY = artifactY + 28
        end
    end

    -- Card layout
    local cardY = startY + 250
    local cardWidth = 220
    local cardHeight = 180
    local cardSpacing = 250

    -- Build key mapping based on progression (same logic as keypressed)
    local keyMap = {}
    if ColorSystem.commitment.primary1 then
        if ColorSystem.commitment.primary2 then
            -- Both primaries committed - map to 1 and 2
            keyMap[1] = ColorSystem.commitment.primary1:lower():sub(1,1)
            keyMap[2] = ColorSystem.commitment.primary2:lower():sub(1,1)
            -- Position 3 = tertiary (secondary color)
            local tertiaryColor = ColorSystem.getTertiaryColor()
            if tertiaryColor then
                keyMap[3] = tertiaryColor
            end
        else
            -- Only first primary chosen
            keyMap[1] = ColorSystem.commitment.primary1:lower():sub(1,1)
            local remainingSlot = 2
            for _, choice in ipairs({"r", "g", "b"}) do
                if choice ~= keyMap[1] and isValid(choice) then
                    keyMap[remainingSlot] = choice
                    remainingSlot = remainingSlot + 1
                end
            end
        end
    else
        keyMap[1] = "r"
        keyMap[2] = "g"
        keyMap[3] = "b"
    end
    
    -- Helper to get key number for a color
    local function getKeyForColor(color)
        for key, mappedColor in pairs(keyMap) do
            if mappedColor == color then
                return key
            end
        end
        return nil
    end
    
    -- Helper to get card position index (0-based for centering)
    local cardIndex = 0

    -- Red option card
    if isValid("r") then
        local keyNum = getKeyForColor("r")
        local cardX = centerX - ((#validChoices - 1) * cardSpacing / 2) + (cardIndex * cardSpacing)
        local isIntensity = ColorSystem.primary.RED and ColorSystem.primary.RED.level >= 9

        love.graphics.setColor(0.3, 0, 0, 0.7)
        love.graphics.rectangle("fill", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("line", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
        love.graphics.print("🔴 RED", cardX - 50, cardY + 15, 0, 1.5, 1.5)
        love.graphics.setColor(1, 1, 1, 0.9)

        if #ColorSystem.colorHistory == 0 then
            love.graphics.print("Spread Shot", cardX - 60, cardY + 55, 0, 1.1, 1.1)
            love.graphics.print("2-6 projectiles", cardX - 75, cardY + 85, 0, 0.9, 0.9)
            love.graphics.print("in a cone", cardX - 50, cardY + 105, 0, 0.9, 0.9)
        elseif isIntensity then
            love.graphics.print("INTENSITY!", cardX - 60, cardY + 55, 0, 1.1, 1.1)
            love.graphics.print("+1 projectile", cardX - 70, cardY + 85, 0, 1.0, 1.0)
            love.graphics.print("Extra power!", cardX - 65, cardY + 105, 0, 0.9, 0.9)
        else
            love.graphics.print("+1 projectile", cardX - 70, cardY + 55, 0, 1.0, 1.0)
            love.graphics.print("+2 damage", cardX - 60, cardY + 80, 0, 1.0, 1.0)
            love.graphics.print("More spread!", cardX - 65, cardY + 105, 0, 0.9, 0.9)
        end
        if keyNum then
            love.graphics.print("[Press " .. keyNum .. "]", cardX - 55, cardY + 145, 0, 1.0, 1.0)
        end
        cardIndex = cardIndex + 1
    end

    -- Green option card
    if isValid("g") then
        local keyNum = getKeyForColor("g")
        local cardX = centerX - ((#validChoices - 1) * cardSpacing / 2) + (cardIndex * cardSpacing)
        local isIntensity = ColorSystem.primary.GREEN and ColorSystem.primary.GREEN.level >= 9

        love.graphics.setColor(0, 0.3, 0, 0.7)
        love.graphics.rectangle("fill", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
        love.graphics.setColor(0, 1, 0)
        love.graphics.rectangle("line", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
        love.graphics.print("🟢 GREEN", cardX - 60, cardY + 15, 0, 1.5, 1.5)
        love.graphics.setColor(1, 1, 1, 0.9)

        if #ColorSystem.colorHistory == 0 then
            love.graphics.print("Bounce Shot", cardX - 60, cardY + 55, 0, 1.1, 1.1)
            love.graphics.print("60-100% chance", cardX - 75, cardY + 85, 0, 0.9, 0.9)
            love.graphics.print("to chain", cardX - 45, cardY + 105, 0, 0.9, 0.9)
        elseif isIntensity then
            love.graphics.print("INTENSITY!", cardX - 60, cardY + 55, 0, 1.1, 1.1)
            love.graphics.print("+1 bounce", cardX - 60, cardY + 85, 0, 1.0, 1.0)
            love.graphics.print("Chain master!", cardX - 70, cardY + 105, 0, 0.9, 0.9)
        else
            love.graphics.print("+8% bounce", cardX - 65, cardY + 55, 0, 1.0, 1.0)
            love.graphics.print("+3 damage", cardX - 60, cardY + 80, 0, 1.0, 1.0)
            love.graphics.print("More chains!", cardX - 70, cardY + 105, 0, 0.9, 0.9)
        end
        if keyNum then
            love.graphics.print("[Press " .. keyNum .. "]", cardX - 55, cardY + 145, 0, 1.0, 1.0)
        end
        cardIndex = cardIndex + 1
    end

    -- Blue option card
    if isValid("b") then
        local keyNum = getKeyForColor("b")
        local cardX = centerX - ((#validChoices - 1) * cardSpacing / 2) + (cardIndex * cardSpacing)
        local isIntensity = ColorSystem.primary.BLUE and ColorSystem.primary.BLUE.level >= 9

        love.graphics.setColor(0, 0, 0.3, 0.7)
        love.graphics.rectangle("fill", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
        love.graphics.setColor(0, 0.3, 1)
        love.graphics.rectangle("line", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
        love.graphics.print("🔵 BLUE", cardX - 55, cardY + 15, 0, 1.5, 1.5)
        love.graphics.setColor(1, 1, 1, 0.9)

        if #ColorSystem.colorHistory == 0 then
            love.graphics.print("Pierce Shot", cardX - 60, cardY + 55, 0, 1.1, 1.1)
            love.graphics.print("2-5 pierces", cardX - 60, cardY + 85, 0, 0.9, 0.9)
            love.graphics.print("per projectile", cardX - 70, cardY + 105, 0, 0.9, 0.9)
        elseif isIntensity then
            love.graphics.print("INTENSITY!", cardX - 60, cardY + 55, 0, 1.1, 1.1)
            love.graphics.print("+2 pierce", cardX - 55, cardY + 85, 0, 1.0, 1.0)
            love.graphics.print("Ultra punch!", cardX - 70, cardY + 105, 0, 0.9, 0.9)
        else
            love.graphics.print("+1 pierce", cardX - 55, cardY + 55, 0, 1.0, 1.0)
            love.graphics.print("+3 damage", cardX - 60, cardY + 80, 0, 1.0, 1.0)
            love.graphics.print("More punch!", cardX - 65, cardY + 105, 0, 0.9, 0.9)
        end
        if keyNum then
            love.graphics.print("[Press " .. keyNum .. "]", cardX - 55, cardY + 145, 0, 1.0, 1.0)
        end
        cardIndex = cardIndex + 1
    end

    -- Yellow option card (tertiary)
    if isValid("y") then
        local keyNum = getKeyForColor("y")
        local cardX = centerX - ((#validChoices - 1) * cardSpacing / 2) + (cardIndex * cardSpacing)
        local isIntensity = ColorSystem.secondary.YELLOW and ColorSystem.secondary.YELLOW.level >= 9

        love.graphics.setColor(0.3, 0.3, 0, 0.7)
        love.graphics.rectangle("fill", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
        love.graphics.setColor(1, 1, 0)
        love.graphics.rectangle("line", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
        love.graphics.print("� YELLOW", cardX - 65, cardY + 15, 0, 1.5, 1.5)
        love.graphics.setColor(1, 1, 1, 0.9)

        if #ColorSystem.colorHistory < 10 then
            love.graphics.print("LOCKED!", cardX - 45, cardY + 55, 0, 1.2, 1.2)
            love.graphics.print("Level 10 req.", cardX - 75, cardY + 85, 0, 0.8, 0.8)
        elseif isIntensity then
            love.graphics.print("INTENSITY!", cardX - 60, cardY + 55, 0, 1.1, 1.1)
            love.graphics.print("+1 explosion", cardX - 75, cardY + 85, 0, 1.0, 1.0)
            love.graphics.print("Boom chain!", cardX - 70, cardY + 105, 0, 0.9, 0.9)
        else
            love.graphics.print("Area Explosion", cardX - 85, cardY + 55, 0, 1.0, 1.0)
            love.graphics.print("+5 damage", cardX - 60, cardY + 80, 0, 1.0, 1.0)
            love.graphics.print("More boom!", cardX - 65, cardY + 105, 0, 0.9, 0.9)
        end
        if keyNum then
            love.graphics.print("[Press " .. keyNum .. "]", cardX - 55, cardY + 145, 0, 1.0, 1.0)
        end
        cardIndex = cardIndex + 1
    end

    -- Magenta option card
    if isValid("m") then
        local keyNum = getKeyForColor("m")
        local cardX = centerX - ((#validChoices - 1) * cardSpacing / 2) + (cardIndex * cardSpacing)
        local isIntensity = ColorSystem.secondary.MAGENTA and ColorSystem.secondary.MAGENTA.level >= 9

        love.graphics.setColor(0.3, 0, 0.3, 0.7)
        love.graphics.rectangle("fill", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
        love.graphics.setColor(1, 0, 1)
        love.graphics.rectangle("line", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
        love.graphics.print("� MAGENTA", cardX - 70, cardY + 15, 0, 1.5, 1.5)
        love.graphics.setColor(1, 1, 1, 0.9)

        if #ColorSystem.colorHistory < 10 then
            love.graphics.print("LOCKED!", cardX - 45, cardY + 55, 0, 1.2, 1.2)
            love.graphics.print("Level 10 req.", cardX - 75, cardY + 85, 0, 0.8, 0.8)
        elseif isIntensity then
            love.graphics.print("INTENSITY!", cardX - 60, cardY + 55, 0, 1.1, 1.1)
            love.graphics.print("+1 split", cardX - 50, cardY + 85, 0, 1.0, 1.0)
            love.graphics.print("More chaos!", cardX - 70, cardY + 105, 0, 0.9, 0.9)
        else
            love.graphics.print("+0.4 splits", cardX - 65, cardY + 55, 0, 1.0, 1.0)
            love.graphics.print("+2 damage", cardX - 60, cardY + 80, 0, 1.0, 1.0)
            love.graphics.print("Explode more!", cardX - 75, cardY + 105, 0, 0.9, 0.9)
        end
        if keyNum then
            love.graphics.print("[Press " .. keyNum .. "]", cardX - 55, cardY + 145, 0, 1.0, 1.0)
        end
        cardIndex = cardIndex + 1
    end

    -- Cyan option card
    if isValid("c") then
        local keyNum = getKeyForColor("c")
        local cardX = centerX - ((#validChoices - 1) * cardSpacing / 2) + (cardIndex * cardSpacing)
        local isIntensity = ColorSystem.secondary.CYAN and ColorSystem.secondary.CYAN.level >= 9

        love.graphics.setColor(0, 0.3, 0.3, 0.7)
        love.graphics.rectangle("fill", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
        love.graphics.setColor(0, 1, 1)
        love.graphics.rectangle("line", cardX - cardWidth/2, cardY, cardWidth, cardHeight)
        love.graphics.print("🔵 CYAN", cardX - 55, cardY + 15, 0, 1.5, 1.5)
        love.graphics.setColor(1, 1, 1, 0.9)

        if #ColorSystem.colorHistory < 10 then
            love.graphics.print("LOCKED!", cardX - 45, cardY + 55, 0, 1.2, 1.2)
            love.graphics.print("Level 10 req.", cardX - 75, cardY + 85, 0, 0.8, 0.8)
        elseif isIntensity then
            love.graphics.print("INTENSITY!", cardX - 60, cardY + 55, 0, 1.1, 1.1)
            love.graphics.print("+6° homing", cardX - 65, cardY + 85, 0, 1.0, 1.0)
            love.graphics.print("Perfect aim!", cardX - 70, cardY + 105, 0, 0.9, 0.9)
        else
            love.graphics.print("+3° homing", cardX - 65, cardY + 55, 0, 1.0, 1.0)
            love.graphics.print("+2 damage", cardX - 60, cardY + 80, 0, 1.0, 1.0)
            love.graphics.print("Track better!", cardX - 75, cardY + 105, 0, 0.9, 0.9)
        end
        if keyNum then
            love.graphics.print("[Press " .. keyNum .. "]", cardX - 55, cardY + 145, 0, 1.0, 1.0)
        end
        cardIndex = cardIndex + 1
    end
end

function LevelUpState:keypressed(key)
    local ColorSystem = require("src.systems.ColorSystem")
    local Gamestate = require("libs.hump-master.gamestate")

    -- ESC exits game
    if key == "escape" then
        love.event.quit()
        return
    end

    -- Get valid choices based on current level and color history
    local validChoices = ColorSystem.getValidChoices(self.player.level)
    local function isValidChoice(choice)
        for _, valid in ipairs(validChoices) do
            if valid == choice then
                return true
            end
        end
        return false
    end

    local colorChosen = nil
    
    -- Build ordered choice map based on progression
    -- Initially: 1=RED, 2=GREEN, 3=BLUE
    -- After primary chosen: 1=Primary, 2/3=Remaining initial colors
    -- After secondary unlocked: 1=Primary, 2=Secondary, 3=Tertiary
    local keyMap = {}
    
    if ColorSystem.commitment.primary1 then
        -- After first choice
        if ColorSystem.commitment.primary2 then
            -- After commitment
            keyMap[1] = ColorSystem.commitment.primary1:lower():sub(1,1)
            keyMap[2] = ColorSystem.commitment.primary2:lower():sub(1,1)
            -- Position 3 = tertiary color if available
            local tertiaryColor = ColorSystem.getTertiaryColor()
            if tertiaryColor then
                keyMap[3] = tertiaryColor
            end
        else
            -- Only primary chosen, before commitment
            keyMap[1] = ColorSystem.commitment.primary1:lower():sub(1,1)
            -- Positions 2 and 3 = other initial colors (remaining r/g/b)
            local remainingSlot = 2
            for _, choice in ipairs({"r", "g", "b"}) do
                if choice ~= keyMap[1] and isValidChoice(choice) then
                    keyMap[remainingSlot] = choice
                    remainingSlot = remainingSlot + 1
                end
            end
        end
    else
        -- First choice: always R=1, G=2, B=3
        keyMap[1] = "r"
        keyMap[2] = "g"
        keyMap[3] = "b"
    end
    
    -- Map number keys to colors based on keyMap
    if key == "1" and keyMap[1] and isValidChoice(keyMap[1]) then
        colorChosen = keyMap[1]
    elseif key == "2" and keyMap[2] and isValidChoice(keyMap[2]) then
        colorChosen = keyMap[2]
    elseif key == "3" and keyMap[3] and isValidChoice(keyMap[3]) then
        colorChosen = keyMap[3]
    end

    if colorChosen then
        self.player:levelUp()  -- Increment level and reset XP
        ColorSystem.addColor(self.player.weapon, colorChosen)
        ColorSystem.applyEffects(self.player.weapon)

        -- Return to playing state
        Gamestate.pop()
    end
end

return LevelUpState
