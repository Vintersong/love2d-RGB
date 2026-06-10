-- Floating Text System - Visual feedback for artifact collection and game events
local FloatingTextSystem = {}
local GameConfig = require("src.core.GameConfig")
local Config = require("src.Config")
local Theme = require("src.render.Theme")

FloatingTextSystem.texts = {}

-- Cache fonts (created once, not every frame). Numerics use Share Tech Mono
-- (tabular digits) per the CHROMATIC design tokens.
local fonts = {
    small = Theme.font("mono", 14),
    medium = Theme.font("mono", 18),
    large = Theme.font("mono", 24),
    toastLabel = Theme.font("mono", 12),
    toastTitle = Theme.font("uiSemiBold", 22),
    toastMeta = Theme.font("mono", 13)
}

local artifactColors = {
    PRISM = Theme.color.magenta,
    HALO = Theme.color.yellow,
    MIRROR = Theme.color.cyan,
    LENS = Theme.color.blue,
    AURORA = Theme.color.green,
    DIFFRACTION = Theme.color.red,
    REFRACTION = Theme.color.accent,
    SUPERNOVA = Theme.color.warn,
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

-- Add floating text at a position.
-- `colorOverride` (optional {r,g,b}) replaces the type's default color — used by
-- the color economy to pop XP in the matched affinity color (or gray off-color).
-- `scaleMult` (optional) scales the type's base scale, e.g. for streak milestones.
function FloatingTextSystem.add(text, x, y, textType, colorOverride, scaleMult)
    textType = textType or "ARTIFACT"
    local typeData = FloatingTextSystem.Types[textType] or FloatingTextSystem.Types.ARTIFACT

    local floatingText = {
        text = text,
        x = x,
        y = y,
        startY = y,
        color = colorOverride or typeData.color,
        duration = typeData.duration,
        fadeStart = typeData.fadeStart,
        scale = typeData.scale * (scaleMult or 1),
        riseSpeed = typeData.riseSpeed,
        font = typeData.font,
        timer = 0,
        alpha = 1.0
    }

    table.insert(FloatingTextSystem.texts, floatingText)
end

-- Add artifact collection text with multi-line support
function FloatingTextSystem.addArtifact(artifactName, level, x, y, isMaxLevel, artifactType, maxLevel)
    local accent = artifactColors[artifactType] or Theme.color.accent
    local title = string.upper(artifactName or artifactType or "ARTIFACT")
    local levelText = string.format("LV %d", level or 1)
    if maxLevel then
        levelText = string.format("LV %d/%d", level or 1, maxLevel)
    end

    table.insert(FloatingTextSystem.texts, {
        style = "artifactToast",
        text = title,
        subText = isMaxLevel and "RESONANCE MAXED" or "ARTIFACT SYNCED",
        levelText = isMaxLevel and "MAX" or levelText,
        x = x,
        y = y - 56,
        startY = y - 56,
        color = accent,
        duration = isMaxLevel and 2.15 or 1.75,
        fadeStart = isMaxLevel and 1.35 or 1.05,
        riseSpeed = 26,
        timer = 0,
        alpha = 1.0
    })
end

function FloatingTextSystem.addAchievement(title, subtitle, accent)
    local screenWidth = select(1, GameConfig.getScreenSize()) or Config.screen.width
    accent = accent or Theme.color.accent
    local stackIndex = 0
    for _, text in ipairs(FloatingTextSystem.texts) do
        if text.style == "achievementToast" then
            stackIndex = stackIndex + 1
        end
    end
    local y = 164 + stackIndex * 74

    table.insert(FloatingTextSystem.texts, {
        style = "achievementToast",
        text = string.upper(title or "DISCOVERY"),
        subText = subtitle or "",
        x = screenWidth - 330,
        y = y,
        startY = y,
        color = accent,
        duration = 3.2,
        fadeStart = 2.35,
        riseSpeed = 0,
        timer = 0,
        alpha = 1.0
    })
end

-- Add synergy unlock text
function FloatingTextSystem.addSynergy(synergyName, x, y)
    FloatingTextSystem.addAchievement("Synergy Discovered", synergyName, Theme.color.magenta)
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

local function drawCornerBrackets(x, y, w, h, accent, alpha)
    local len = 8
    love.graphics.setColor(accent[1], accent[2], accent[3], alpha)
    love.graphics.setLineWidth(1)
    love.graphics.line(x, y + len, x, y, x + len, y)
    love.graphics.line(x + w - len, y, x + w, y, x + w, y + len)
    love.graphics.line(x, y + h - len, x, y + h, x + len, y + h)
    love.graphics.line(x + w - len, y + h, x + w, y + h, x + w, y + h - len)
end

local function drawArtifactToast(text)
    local previousLineWidth = love.graphics.getLineWidth()
    local labelFont = fonts.toastLabel
    local metaFont = fonts.toastMeta
    local accent = text.color or Theme.color.accent
    local progress = math.min(1, text.timer / 0.12)
    local ease = 1 - math.pow(1 - progress, 3)
    local pulse = 0.9 + math.sin(text.timer * 10) * 0.06

    love.graphics.setFont(metaFont)
    local titleW = metaFont:getWidth(text.text)
    love.graphics.setFont(labelFont)
    local labelW = labelFont:getWidth(text.subText or "")
    local levelW = metaFont:getWidth(text.levelText or "")

    local w = math.max(150, titleW + levelW + 52, labelW + 38)
    local h = 34
    local x = text.x - w * 0.5 - (1 - ease) * 12
    local y = text.y - h * 0.5
    local alpha = (text.alpha or 1) * ease * 0.9

    love.graphics.setColor(0, 0, 0, 0.36 * alpha)
    love.graphics.rectangle("fill", x + 4, y + 5, w, h)

    love.graphics.setColor(Theme.color.bgRaised[1], Theme.color.bgRaised[2], Theme.color.bgRaised[3], 0.54 * alpha)
    love.graphics.rectangle("fill", x, y, w, h)

    love.graphics.setColor(accent[1], accent[2], accent[3], 0.08 * alpha)
    love.graphics.rectangle("fill", x + 1, y + 1, w - 2, h - 2)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.72 * alpha)
    love.graphics.rectangle("fill", x, y, 3, h)
    love.graphics.rectangle("fill", x + 9, y + 4, w - 18, 1)

    drawCornerBrackets(x, y, w, h, accent, 0.45 * alpha * pulse)

    love.graphics.setFont(labelFont)
    love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], 0.78 * alpha)
    love.graphics.print(text.subText or "ARTIFACT SYNCED", x + 12, y + 5)

    love.graphics.setFont(metaFont)
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], alpha)
    love.graphics.print(text.text, x + 12, y + 17)

    local pillW = math.max(38, levelW + 14)
    local pillX = x + w - pillW - 10
    love.graphics.setColor(0, 0, 0, 0.26 * alpha)
    love.graphics.rectangle("fill", pillX, y + 17, pillW, 15)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.20 * alpha)
    love.graphics.rectangle("fill", pillX + 1, y + 18, pillW - 2, 13)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.50 * alpha)
    love.graphics.rectangle("line", pillX, y + 17, pillW, 15)

    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], alpha)
    love.graphics.print(text.levelText or "", pillX + (pillW - levelW) * 0.5, y + 18)
    love.graphics.setLineWidth(previousLineWidth)
end

local function drawAchievementToast(text)
    local previousLineWidth = love.graphics.getLineWidth()
    local accent = text.color or Theme.color.accent
    local progress = math.min(1, text.timer / 0.2)
    local ease = 1 - math.pow(1 - progress, 3)
    local alpha = (text.alpha or 1) * ease
    local w = 300
    local h = 64
    local x = text.x + (1 - ease) * 28
    local y = text.y

    love.graphics.setColor(0, 0, 0, 0.42 * alpha)
    love.graphics.rectangle("fill", x + 5, y + 6, w, h)
    love.graphics.setColor(Theme.color.bgRaised[1], Theme.color.bgRaised[2], Theme.color.bgRaised[3], 0.82 * alpha)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.12 * alpha)
    love.graphics.rectangle("fill", x + 1, y + 1, w - 2, h - 2)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.9 * alpha)
    love.graphics.rectangle("fill", x, y, 4, h)
    love.graphics.rectangle("fill", x + 14, y + 11, w - 28, 1)
    drawCornerBrackets(x, y, w, h, accent, 0.6 * alpha)

    love.graphics.setFont(fonts.toastLabel)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.95 * alpha)
    love.graphics.print("DISCOVERY", x + 16, y + 10)

    love.graphics.setFont(fonts.toastTitle)
    love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], alpha)
    love.graphics.print(text.text or "SYNERGY DISCOVERED", x + 16, y + 26)

    love.graphics.setFont(fonts.toastMeta)
    love.graphics.setColor(Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], 0.9 * alpha)
    local subtitle = tostring(text.subText or "")
    local maxW = w - 32
    if fonts.toastMeta:getWidth(subtitle) > maxW then
        while #subtitle > 0 and fonts.toastMeta:getWidth(subtitle .. "...") > maxW do
            subtitle = subtitle:sub(1, -2)
        end
        subtitle = subtitle .. "..."
    end
    love.graphics.print(subtitle, x + 16, y + 49)
    love.graphics.setLineWidth(previousLineWidth)
end

function FloatingTextSystem.draw()
    local _, screenHeight = GameConfig.getScreenSize()
    screenHeight = screenHeight or Config.screen.height
    
    -- Save the current font to restore later
    local currentFont = love.graphics.getFont()
    
    for _, text in ipairs(FloatingTextSystem.texts) do
        -- Only draw if on screen
        if text.y > -50 and text.y < screenHeight + 50 then
            if text.style == "artifactToast" then
                drawArtifactToast(text)
            elseif text.style == "achievementToast" then
                drawAchievementToast(text)
            else
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
    end
    
    -- Reset color and font
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(currentFont)
end

function FloatingTextSystem.clear()
    FloatingTextSystem.texts = {}
end

return FloatingTextSystem
