function love.conf(t)
    -- Window
    local Config = require("src.Config")
    
    -- Window
    t.window.width = Config.screen.width
    t.window.height = Config.screen.height
    t.window.fullscreen = Config.screen.fullscreen
    t.window.fullscreentype = "exclusive"  -- Use exclusive fullscreen to prevent scaling issues
    t.window.highdpi = Config.screen.highDpi
    
    -- Console (set to false for production builds)
    t.console = Config.debug.enabled
end
