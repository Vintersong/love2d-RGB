-- Song structure definition for song1.wav
-- This file defines the BPM and structure sections for music-reactive gameplay

return {
    name = "Song 1",
    bpm = 120,  -- Will be overridden by auto-detection if available
    structure = {
        {name = "intro", start = 0, stop = 15},
        {name = "verse", start = 15, stop = 45},
        {name = "chorus", start = 45, stop = 75},
        {name = "verse", start = 75, stop = 105},
        {name = "chorus", start = 105, stop = 135},
        {name = "bridge", start = 135, stop = 165},
        {name = "outro", start = 165, stop = 195}
    }
}
