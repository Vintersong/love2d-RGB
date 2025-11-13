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
        structurePath = "assets.songs.song1"
    },
    {
        name = "Song 2",
        audioPath = "assets/music/song2.wav",
        structurePath = "assets.songs.song2"
    }
}

-- Get a random song from the library
function SongLibrary.getRandomSong()
    local index = math.random(1, #SongLibrary.songs)
    local song = SongLibrary.songs[index]

    -- Load structure file
    local structure = require(song.structurePath)

    print(string.format("[SongLibrary] Selected: %s (%d/%d)", song.name, index, #SongLibrary.songs))

    return {
        name = song.name,
        audioPath = song.audioPath,
        structure = structure.structure,
        bpm = structure.bpm
    }
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
    local structure = require(song.structurePath)

    return {
        name = song.name,
        audioPath = song.audioPath,
        structure = structure.structure,
        bpm = structure.bpm
    }
end

return SongLibrary
