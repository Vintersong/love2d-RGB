-- Floating Text System - Visual feedback for artifact collection and game events
local FloatingTextSystem = {}

FloatingTextSystem.texts = {}

-- Cache fonts (created once, not every frame)
local fonts = {
    small = love.graphics.newFont(14),
    medium = love.graphics.newFont(18),
    large = love.graphics.newFont(24)
}

-- Text types with different colors and behaviors
FloatingTextSystem.Types = {
    ARTIFACT = {
        color = {1, 0.84, 0},  -- Gold
        duration = 2.5,
        fadeStart = 1.5,
        scale = 1.8,
        riseSpeed = 50,
        font = "large"
    },
    ARTIFACT_LEVELUP = {
        color = {0.4, 1, 1},  -- Cyan
        duration = 2.0,
        fadeStart = 1.0,
        scale = 1.5,
        riseSpeed = 60,
        font = "medium"
    },
    SYNERGY = {
        color = {1, 0.4, 1},  -- Magenta
        duration = 3.0,
        fadeStart = 2.0,
        scale = 2.0,
        riseSpeed = 40,
        font = "large"
    },
    DAMAGE = {
        color = {1, 0.3, 0.3},  -- Red
        duration = 1.0,
        fadeStart = 0.5,
        scale = 1.2,
        riseSpeed = 80,
        font = "small"
    },
    HEAL = {
        color = {0.3, 1, 0.3},  -- Green
        duration = 1.5,
        fadeStart = 0.8,
        scale = 1.3,
        riseSpeed = 70,
        font = "small"
    },
    MAX_LEVEL = {
        color = {1, 1, 0},  -- Yellow
        duration = 2.5,
        fadeStart = 1.5,
        scale = 2.2,
        riseSpeed = 45,
        font = "large"
    }
}

function FloatingTextSystem.init()
    FloatingTextSystem.texts = {}
end

-- Add floating text at a position
function FloatingTextSystem.add(text, x, y, textType)
    textType = textType or "ARTIFACT"
    local typeData = FloatingTextSystem.Types[textType] or FloatingTextSystem.Types.ARTIFACT
    
    local floatingText = {
        text = text,
        x = x,
        y = y,
        startY = y,
        color = typeData.color,
        duration = typeData.duration,
        fadeStart = typeData.fadeStart,
        scale = typeData.scale,
        riseSpeed = typeData.riseSpeed,
        font = typeData.font,
        timer = 0,
        alpha = 1.0
    }
    
    table.insert(FloatingTextSystem.texts, floatingText)
end

-- Add artifact collection text with multi-line support
function FloatingTextSystem.addArtifact(artifactName, level, x, y, isMaxLevel)
    local mainText = "⭐ " .. artifactName .. " ⭐"
    local levelText = "Level " .. level
    
    if isMaxLevel then
        FloatingTextSystem.add(mainText, x, y - 20, "MAX_LEVEL")
        FloatingTextSystem.add("MAX LEVEL!", x, y + 20, "MAX_LEVEL")
    else
        FloatingTextSystem.add(mainText, x, y - 15, "ARTIFACT")
        FloatingTextSystem.add(levelText, x, y + 15, "ARTIFACT_LEVELUP")
    end
end

-- Add synergy unlock text
function FloatingTextSystem.addSynergy(synergyName, x, y)
    FloatingTextSystem.add("✦ SYNERGY ✦", x, y - 20, "SYNERGY")
    FloatingTextSystem.add(synergyName, x, y + 20, "SYNERGY")
end

function FloatingTextSystem.update(dt)
    for i = #FloatingTextSystem.texts, 1, -1 do
        local text = FloatingTextSystem.texts[i]
        text.timer = text.timer + dt
        
        -- Move text upward
        text.y = text.y - text.riseSpeed * dt
        
        -- Calculate alpha (fade out near end of duration)
        if text.timer >= text.fadeStart then
            local fadeProgress = (text.timer - text.fadeStart) / (text.duration - text.fadeStart)
            text.alpha = 1.0 - fadeProgress
        end
        
        -- Remove expired texts
        if text.timer >= text.duration then
            table.remove(FloatingTextSystem.texts, i)
        end
    end
end

function FloatingTextSystem.draw()
    local SCREEN_WIDTH = 1920
    local SCREEN_HEIGHT = 1080
    
    -- Save the current font to restore later
    local currentFont = love.graphics.getFont()
    
    for _, text in ipairs(FloatingTextSystem.texts) do
        -- Only draw if on screen
        if text.y > -50 and text.y < SCREEN_HEIGHT + 50 then
            -- Set font (using cached fonts)
            local font = fonts[text.font] or fonts.medium
            love.graphics.setFont(font)
            
            -- Calculate text dimensions for centering
            local textWidth = font:getWidth(text.text)
            local textHeight = font:getHeight()
            
            -- Calculate scaled position (no push/pop/translate)
            local drawX = text.x - (textWidth * text.scale) / 2
            local drawY = text.y - (textHeight * text.scale) / 2
            
            -- Draw shadow for better visibility
            love.graphics.setColor(0, 0, 0, text.alpha * 0.7)
            love.graphics.print(text.text, drawX + 2, drawY + 2, 0, text.scale, text.scale)
            
            -- Draw main text
            love.graphics.setColor(text.color[1], text.color[2], text.color[3], text.alpha)
            love.graphics.print(text.text, drawX, drawY, 0, text.scale, text.scale)
        end
    end
    
    -- Reset color and font
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(currentFont)
end

function FloatingTextSystem.clear()
    FloatingTextSystem.texts = {}
end

return FloatingTextSystem
