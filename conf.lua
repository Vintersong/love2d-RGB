function love.conf(t)
    -- Window
    t.window.width = 1920
    t.window.height = 1080
    t.window.fullscreen = true
    t.window.fullscreentype = "exclusive"  -- Use exclusive fullscreen to prevent scaling issues
    t.window.highdpi = false  -- Disable high DPI scaling
    -- Console
    t.window.resizable = false  -- Disabled to maintain constant UI scale
    t.console = true
end
