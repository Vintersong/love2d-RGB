local SFXLibrary = {}

local function loadSource(path)
    local ok, source = pcall(love.audio.newSource, path, "static")
    if ok then
        return source
    end
    print(string.format("[SFXLibrary] Failed to load sound: %s", path))
    return nil
end

SFXLibrary.sources = {
    playerDash = loadSource("assets/sfx/Dash.mp3")
}

function SFXLibrary.play(name)
    local source = SFXLibrary.sources[name]
    if not source then
        return false
    end

    source:stop()
    source:play()
    return true
end

return SFXLibrary
