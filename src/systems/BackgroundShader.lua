-- BackgroundShader.lua
-- Manages the music-reactive vaporwave background shader

local BackgroundShader = {}

-- Load moonshine for post-processing effects
local moonshine = require("libs.moonshine-master")

BackgroundShader.shader = nil
BackgroundShader.canvas = nil
BackgroundShader.time = 0
BackgroundShader.effect = nil  -- Moonshine glow effect
BackgroundShader.fallback = false

-- Initialize shader system
function BackgroundShader.init(screenWidth, screenHeight)
    BackgroundShader.fallback = false
    BackgroundShader.screenWidth = screenWidth
    BackgroundShader.screenHeight = screenHeight

    -- Load shader
    local success, result = pcall(function()
        return love.graphics.newShader("assets/shaders/background.glsl")
    end)

    if success then
        BackgroundShader.shader = result
        print("[BackgroundShader] Shader loaded successfully")
    else
        print("[BackgroundShader] Failed to load shader: " .. tostring(result))
        BackgroundShader.fallback = true
        return true
    end

    -- Fixed grid dimensions (number of cells)
    -- Make canvas match screen exactly
    local gridCols = 40
    local gridRows = 23  -- Changed from 22 to 23 to fill 1080 height (23 * 48 = 1104, but we'll scale)
    local cellSize = 48  -- Fixed cell size in pixels

    -- Use screen dimensions directly to avoid offset issues
    local canvasWidth = screenWidth    -- 1920
    local canvasHeight = screenHeight  -- 1080

    -- Store for later use
    BackgroundShader.canvasWidth = canvasWidth
    BackgroundShader.canvasHeight = canvasHeight
    BackgroundShader.screenWidth = screenWidth
    BackgroundShader.screenHeight = screenHeight

    -- Create canvas for rendering with exact cell dimensions
    local canvasOk, canvasOrError = pcall(love.graphics.newCanvas, canvasWidth, canvasHeight)
    if not canvasOk then
        print("[BackgroundShader] Failed to create canvas: " .. tostring(canvasOrError))
        BackgroundShader.fallback = true
        return true
    end
    BackgroundShader.canvas = canvasOrError

    -- Initialize moonshine post-FX chain
    local effectOk, effectOrError = pcall(function()
        return moonshine(canvasWidth, canvasHeight, moonshine.effects.glow)
            .chain(moonshine.effects.chromasep)
            .chain(moonshine.effects.filmgrain)
            .chain(moonshine.effects.vignette)
    end)

    if not effectOk then
        print("[BackgroundShader] Failed to initialize post-FX, using shader without moonshine: " .. tostring(effectOrError))
        BackgroundShader.effect = nil
    else
        BackgroundShader.effect = effectOrError

        -- Configure glow
        BackgroundShader.effect.glow.strength = 5
        BackgroundShader.effect.glow.min_luma = 0.2

        -- Configure chromatic separation
        BackgroundShader.effect.chromasep.angle = 0.15
        BackgroundShader.effect.chromasep.radius = 1.5

        -- Configure film grain
        BackgroundShader.effect.filmgrain.opacity = 0.15
        BackgroundShader.effect.filmgrain.size = 1

        -- Configure vignette
        BackgroundShader.effect.vignette.radius = 0.85
        BackgroundShader.effect.vignette.opacity = 0.5
        BackgroundShader.effect.vignette.softness = 0.5
    end

    -- Set initial uniforms using canvas dimensions
    BackgroundShader.shader:send("resolution", {canvasWidth, canvasHeight})
    BackgroundShader.shader:send("time", 0)
    BackgroundShader.shader:send("bass", 0)
    BackgroundShader.shader:send("mids", 0)
    BackgroundShader.shader:send("treble", 0)
    BackgroundShader.shader:send("intensity", 0)
    BackgroundShader.shader:send("playerLevel", 1)  -- Start at level 1

    print(string.format("[BackgroundShader] Initialized grid canvas %dx%d (%d x %d cells) on screen %dx%d",
        canvasWidth, canvasHeight, gridCols, gridRows, screenWidth, screenHeight))
    return true
end

-- Update shader uniforms with music data and player level
function BackgroundShader.update(dt, musicReactor, player)
    BackgroundShader.time = BackgroundShader.time + dt

    if not BackgroundShader.shader then return end

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
    if BackgroundShader.fallback or not BackgroundShader.shader or not BackgroundShader.canvas then
        BackgroundShader.drawFallback()
        return
    end

    -- Save previous shader
    local previousShader = love.graphics.getShader()

    -- Render shader to our canvas first
    love.graphics.setCanvas(BackgroundShader.canvas)
    love.graphics.clear()
    love.graphics.setShader(BackgroundShader.shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, BackgroundShader.canvasWidth, BackgroundShader.canvasHeight)
    love.graphics.setShader()
    love.graphics.setCanvas()

    if BackgroundShader.effect then
        -- Draw the canvas through moonshine effect at 0,0 (fills entire screen)
        BackgroundShader.effect(function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(BackgroundShader.canvas, 0, 0)
        end)
    else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(BackgroundShader.canvas, 0, 0)
    end

    -- Restore previous shader
    love.graphics.setShader(previousShader)
end

function BackgroundShader.drawFallback()
    local width = BackgroundShader.screenWidth or love.graphics.getWidth()
    local height = BackgroundShader.screenHeight or love.graphics.getHeight()
    local cellSize = 48
    local pulse = 0.5 + 0.5 * math.sin(BackgroundShader.time * 2)

    love.graphics.setColor(0.08, 0.05, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, width, height)

    love.graphics.setColor(0.6 + pulse * 0.25, 0.25, 0.8, 0.45)
    for x = 0, width, cellSize do
        love.graphics.line(x, 0, x, height)
    end
    for y = 0, height, cellSize do
        love.graphics.line(0, y, width, y)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Reset shader time (useful for testing)
function BackgroundShader.reset()
    BackgroundShader.time = 0
end

-- Toggle a post-FX effect on/off
function BackgroundShader.toggleEffect(effectName, enabled)
    if not BackgroundShader.effect then return end
    if enabled then
        BackgroundShader.effect.enable(effectName)
    else
        BackgroundShader.effect.disable(effectName)
    end
end

return BackgroundShader
