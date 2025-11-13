-- BackgroundShader.lua
-- Manages the music-reactive vaporwave background shader

local BackgroundShader = {}

-- Load moonshine for post-processing effects
local moonshine = require("libs.moonshine-master")

BackgroundShader.shader = nil
BackgroundShader.canvas = nil
BackgroundShader.time = 0
BackgroundShader.effect = nil  -- Moonshine glow effect

-- Initialize shader system
function BackgroundShader.init(screenWidth, screenHeight)
    -- Load shader
    local success, result = pcall(function()
        return love.graphics.newShader("assets/shaders/background.glsl")
    end)

    if success then
        BackgroundShader.shader = result
        print("[BackgroundShader] Shader loaded successfully")
    else
        print("[BackgroundShader] Failed to load shader: " .. tostring(result))
        return false
    end

    -- Create canvas for rendering
    BackgroundShader.canvas = love.graphics.newCanvas(screenWidth, screenHeight)
    
    -- Initialize moonshine glow effect for entire grid
    BackgroundShader.effect = moonshine(screenWidth, screenHeight, moonshine.effects.glow)
    BackgroundShader.effect.glow.strength = 5  -- Strong glow for psychedelic effect
    BackgroundShader.effect.glow.min_luma = 0.2  -- Glow most of the grid (lower threshold)

    -- Set initial uniforms
    BackgroundShader.shader:send("resolution", {screenWidth, screenHeight})
    BackgroundShader.shader:send("time", 0)
    BackgroundShader.shader:send("bass", 0)
    BackgroundShader.shader:send("mids", 0)
    BackgroundShader.shader:send("treble", 0)
    BackgroundShader.shader:send("intensity", 0)
    BackgroundShader.shader:send("playerLevel", 1)  -- Start at level 1

    print(string.format("[BackgroundShader] Initialized %dx%d with glow effect", screenWidth, screenHeight))
    return true
end

-- Update shader uniforms with music data and player level
function BackgroundShader.update(dt, musicReactor, player)
    if not BackgroundShader.shader then return end

    BackgroundShader.time = BackgroundShader.time + dt

    -- Update time uniform
    BackgroundShader.shader:send("time", BackgroundShader.time)

    -- Update music-reactive uniforms
    if musicReactor then
        local bass = musicReactor.bass or 0
        local mids = musicReactor.mids or 0
        local treble = musicReactor.treble or 0
        local intensity = musicReactor.intensity or 0

        BackgroundShader.shader:send("bass", bass)
        BackgroundShader.shader:send("mids", mids)
        BackgroundShader.shader:send("treble", treble)
        BackgroundShader.shader:send("intensity", intensity)
    end
    
    -- Update player level for grid color progression
    if player then
        BackgroundShader.shader:send("playerLevel", player.level or 1)
    end
end

-- Draw the shader background with glow effect
function BackgroundShader.draw()
    if not BackgroundShader.shader or not BackgroundShader.effect then return end

    -- Save previous shader
    local previousShader = love.graphics.getShader()

    -- Draw shader to moonshine effect
    BackgroundShader.effect(function()
        love.graphics.setShader(BackgroundShader.shader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setShader()
    end)

    -- Restore previous shader
    love.graphics.setShader(previousShader)
end

-- Reset shader time (useful for testing)
function BackgroundShader.reset()
    BackgroundShader.time = 0
end

return BackgroundShader
