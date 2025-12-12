function love.conf(t)
    -- Window
    t.window.width = 1920
    t.window.height = 1080
    t.window.fullscreen = true
    t.window.fullscreentype = "exclusive"  -- Use exclusive fullscreen to prevent scaling issues
    t.window.highdpi = false  -- Disable high DPI scaling
    -- Console (set to false for production builds)
    t.console = true  -- Enable console for debug output
end
