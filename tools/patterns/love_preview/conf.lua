-- Minimal LÖVE config for the standalone bullet-pattern visual preview.
-- This is a SEPARATE love app from the game; it is never referenced by the game's
-- root main.lua / BootLoader. Run with:  love tools/patterns/love_preview
function love.conf(t)
    t.window.title = "CHROMATIC - Bullet Pattern Preview (standalone)"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.console = false
end
