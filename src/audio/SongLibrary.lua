-- SongLibrary.lua
-- Manages available songs and random selection

local SongLibrary = {}

-- Seed random number generator with current time
math.randomseed(os.time())
-- Call random a few times to "warm up" the generator
math.random(); math.random(); math.random()

-- Song definitions
SongLibrary.songs = {
    {
        name = "Song 1",
        audioPath = "assets/music/song1.wav",
        webAudioPath = "assets/music_web/song1.ogg",
        structurePath = "assets.songs.song1"
    },
    {
        name = "Song 2",
        audioPath = "assets/music/song2.wav",
        webAudioPath = "assets/music_web/song2.ogg",
        structurePath = "assets.songs.song2"
    }
}

local function resolveAudioPath(song)
    local Config = require("src.Config")
    if Config.runtime and Config.runtime.web and song.webAudioPath then
        local info = love.filesystem.getInfo(song.webAudioPath)
        if info then
            return song.webAudioPath
        end
    end

    return song.audioPath
end

local function buildSongData(song, index)
    local structure = require(song.structurePath)

    return {
        index = index,
        name = song.name,
        audioPath = resolveAudioPath(song),
        structure = structure.structure,
        bpm = structure.bpm
    }
end

-- Get a random song from the library
function SongLibrary.getRandomSong()
    local index = math.random(1, #SongLibrary.songs)
    local song = SongLibrary.songs[index]

    print(string.format("[SongLibrary] Selected: %s (%d/%d)", song.name, index, #SongLibrary.songs))
    return buildSongData(song, index)
end

-- Get all available songs
function SongLibrary.getAllSongs()
    return SongLibrary.songs
end

-- Get song count
function SongLibrary.getSongCount()
    return #SongLibrary.songs
end

-- Get specific song by index
function SongLibrary.getSongByIndex(index)
    if index < 1 or index > #SongLibrary.songs then
        print("[SongLibrary] Invalid song index: " .. tostring(index))
        return nil
    end

    local song = SongLibrary.songs[index]
    return buildSongData(song, index)
end

function SongLibrary.getGameplayPlaylist()
    local playlist = {}
    for i, song in ipairs(SongLibrary.songs) do
        playlist[#playlist + 1] = buildSongData(song, i)
    end
    return playlist
end

return SongLibrary
