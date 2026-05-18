function love.conf(t)
    t.version = "11.5"

    -- Window
    local Config = require("src.Config")
    
    -- Window
    t.window.width = Config.screen.width
    t.window.height = Config.screen.height
    t.window.title = Config.screen.title
    t.window.fullscreen = Config.screen.fullscreen
    t.window.fullscreentype = "exclusive"  -- Use exclusive fullscreen to prevent scaling issues
    t.window.highdpi = Config.screen.highDpi
    t.window.vsync = Config.screen.vsync and 1 or 0
    
    -- Console (set to false for production builds)
    t.console = Config.debug.enabled
end
