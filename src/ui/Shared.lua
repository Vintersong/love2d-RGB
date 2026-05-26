-- Shared UI helpers.

local Shared = {}
local Config = require("src.Config")
local GameConfig = require("src.core.GameConfig")

function Shared.getScreenSize()
    local w, h = GameConfig.getScreenSize()
    if not w or not h or w <= 0 or h <= 0 then
        return Config.screen.width, Config.screen.height
    end
    return w, h
end

return Shared
