-- Runtime.lua
-- Small platform/build-mode helpers used by browser packaging and desktop runs.

local Runtime = {}
local Config = require("src.Config")

Runtime.args = {}

local function hasArg(args, expected)
    if type(args) ~= "table" then
        return false
    end

    for _, value in ipairs(args) do
        if value == expected then
            return true
        end
    end

    return false
end

function Runtime.init(args)
    Runtime.args = args or {}

    local isWeb = hasArg(Runtime.args, "--web")

    if love.system and love.system.getOS then
        local ok, osName = pcall(love.system.getOS)
        if ok and osName == "Web" then
            isWeb = true
        end
    end

    Config.runtime.web = isWeb
    Config.runtime.musicStarted = false

    print(string.format("[Runtime] Mode: %s", isWeb and "web" or "desktop"))
end

function Runtime.isWeb()
    return Config.runtime and Config.runtime.web == true
end

function Runtime.startMusicAfterGesture()
    local GameConfig = require("src.systems.GameConfig")
    local musicReactor = GameConfig.getMusicReactor()

    if musicReactor and musicReactor.play and not musicReactor.isPlaying then
        musicReactor:play()
        Config.runtime.musicStarted = true
        print("[Runtime] Music started after user input")
        return true
    end

    return false
end

function Runtime.quitOrReturnToTitle()
    if Runtime.isWeb() then
        local StateManager = require("src.systems.StateManager")

        if StateManager.currentState == "Splash" then
            love.event.push("quit", "reload")
            return
        end

        StateManager.switch("Splash")
        return
    end

    love.event.quit()
end

function Runtime.quitActionText()
    return Runtime.isWeb() and "Return to Title" or "Quit Game"
end

function Runtime.exitActionText()
    return Runtime.isWeb() and "Return to Title" or "Exit"
end

return Runtime
