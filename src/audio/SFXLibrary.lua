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
    playerDash = loadSource("assets/sfx/Dash.mp3"),
    menuMove = loadSource("assets/sfx/MenuSelectorMove.wav")
}

local artifactCueNames = {
    PRISM = "artifactPrism",
    LENS = "artifactLens",
    MIRROR = "artifactMirror",
    DIFFRACTION = "artifactDiffraction",
    REFRACTION = "artifactRefraction",
    HALO = "artifactHalo",
    AURORA = "artifactAurora",
    SUPERNOVA = "artifactSupernova",
}

-- Individual volume audjustments for specific sounds

if SFXLibrary.sources.menuMove then
    SFXLibrary.sources.menuMove:setVolume(0.35)
end

function SFXLibrary.play(name)
    local source = SFXLibrary.sources[name]
    if not source then
        return false
    end

    source:stop()
    source:play()
    return true
end

function SFXLibrary.playArtifactCue(artifactType)
    local cueName = artifactCueNames[artifactType]
    if not cueName then
        return false
    end
    return SFXLibrary.play(cueName)
end

return SFXLibrary
