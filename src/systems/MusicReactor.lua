local audioAnalyzer = require("libs.audioAnalyzer")

local MusicReactor = {}
MusicReactor.__index = MusicReactor

function MusicReactor:new()
    local reactor = setmetatable({}, self)
    
    reactor.analyzer = audioAnalyzer
    reactor.currentSong = nil
    reactor.soundData = nil
    reactor.isPlaying = false
    reactor.bpm = 120
    reactor.beatInterval = 60 / 120
    reactor.timeSinceLastBeat = 0
    reactor.beatThreshold = 0.7
    
    -- Frequency band intensities (0-1)
    reactor.bass = 0
    reactor.midLow = 0
    reactor.midHigh = 0
    reactor.treble = 0
    reactor.presence = 0
    
    -- Normalized values (scaled for gameplay)
    reactor.bassNorm = 0
    reactor.midNorm = 0
    reactor.trebleNorm = 0
    
    -- Overall energy
    reactor.energy = 0
    reactor.intensity = 0
    reactor.beatIntensity = 0  -- Decaying value that spikes on beats
    
    -- Beat detection
    reactor.isOnBeat = false
    reactor.beatCooldown = 0
    reactor.beatPhase = 0  -- 0.0 to 1.0, progress through current beat
    
    -- Song structure (manual tagging)
    reactor.songStructure = {}
    reactor.currentSection = "intro"
    reactor.songTime = 0
    
    -- Timing windows (visual feedback ONLY - no penalties)
    reactor.timingWindow = "miss"  -- "perfect", "good", "okay", "miss"
    reactor.timingMultiplier = 1.0  -- Always 1.0, no timing-based penalties
    
    -- History for smoothing
    reactor.bassHistory = {}
    reactor.midHistory = {}
    reactor.trebleHistory = {}
    reactor.historySize = 10
    
    return reactor
end

function MusicReactor:loadSong(filepath, structure)
    self.currentSong = love.audio.newSource(filepath, "stream")
    self.currentSong:setLooping(true)
    
    -- Load sound data for BPM detection
    local success, soundData = pcall(love.sound.newSoundData, filepath)
    if success then
        self.soundData = soundData
        -- Detect BPM automatically
        local detectedBPM = audioAnalyzer.detectBPM(soundData, {minbpm = 80, maxbpm = 180})
        self:setBPM(detectedBPM)
        print(string.format("[MusicReactor] Detected BPM: %.1f", detectedBPM))
    else
        print("[MusicReactor] Could not load sound data for analysis, using default BPM")
    end
    
    -- Set song structure if provided
    if structure then
        self.songStructure = structure
        print("[MusicReactor] Loaded song structure with " .. #structure .. " sections")
    end
    
    return self.currentSong
end

function MusicReactor:play()
    if self.currentSong then
        self.currentSong:play()
        self.isPlaying = true
    end
end

function MusicReactor:pause()
    if self.currentSong then
        self.currentSong:pause()
        self.isPlaying = false
    end
end

function MusicReactor:stop()
    if self.currentSong then
        self.currentSong:stop()
        self.isPlaying = false
    end
end

function MusicReactor:update(dt)
    if not self.isPlaying then return end
    
    -- Update song time
    if self.currentSong then
        self.songTime = self.currentSong:tell()
    else
        self.songTime = self.songTime + dt
    end
    
    -- Update beat timing
    self.timeSinceLastBeat = self.timeSinceLastBeat + dt
    self.beatCooldown = math.max(0, self.beatCooldown - dt)
    
    -- Calculate beat phase (0.0 to 1.0)
    self.beatPhase = (self.timeSinceLastBeat % self.beatInterval) / self.beatInterval
    
    -- Decay beat intensity
    self.beatIntensity = math.max(0, self.beatIntensity - dt * 4)
    
    -- Analyze audio frequencies
    self:analyzeAudio()
    
    -- Detect beats
    self:detectBeat()
    
    -- Update timing window based on beat phase
    self:updateTimingWindow()
    
    -- Update current song section
    self:updateCurrentSection()
end

function MusicReactor:analyzeAudio()
    -- Simple time-based simulation for frequency bands
    -- This creates reactive values that feel musical even without real FFT analysis
    local time = love.timer.getTime()
    
    -- Bass: slow, heavy oscillation (mimics kick drum patterns)
    local bassWave = math.abs(math.sin(time * self.bpm / 60 * 2 * math.pi))
    bassWave = math.pow(bassWave, 2)  -- Square it for sharper peaks
    self.bass = bassWave * 0.8 + 0.2  -- Keep some baseline
    
    -- Mid: medium frequency content
    local midWave = (math.sin(time * self.bpm / 30 * math.pi) + 1) / 2
    self.midLow = midWave * 0.6 + 0.2
    self.midHigh = (1 - midWave) * 0.6 + 0.2
    
    -- Treble: high frequency, more chaotic
    local trebleWave = (math.sin(time * self.bpm / 15 * math.pi * 1.618) + 1) / 2
    self.treble = trebleWave * 0.7 + 0.3
    
    -- Presence: very high frequencies
    local presenceWave = (math.sin(time * self.bpm / 10 * math.pi * 2.414) + 1) / 2
    self.presence = presenceWave * 0.5 + 0.3
    
    -- Add smoothing through history
    self:addToHistory(self.bassHistory, self.bass)
    self:addToHistory(self.midHistory, (self.midLow + self.midHigh) / 2)
    self:addToHistory(self.trebleHistory, self.treble)
    
    -- Get smoothed values
    self.bassNorm = self:getHistoryAverage(self.bassHistory)
    self.midNorm = self:getHistoryAverage(self.midHistory)
    self.trebleNorm = self:getHistoryAverage(self.trebleHistory)
    
    -- Calculate overall energy (weighted toward bass for better beat detection)
    self.energy = (self.bass * 0.4 + self.midLow * 0.2 + self.midHigh * 0.2 + self.treble * 0.2)
    
    -- Calculate intensity (how "loud" or energetic the music is)
    self.intensity = self.bass * 0.4 + self.midLow * 0.2 + self.midHigh * 0.2 + self.treble * 0.1 + self.presence * 0.1
end

function MusicReactor:addToHistory(history, value)
    table.insert(history, value)
    if #history > self.historySize then
        table.remove(history, 1)
    end
end

function MusicReactor:getHistoryAverage(history)
    if #history == 0 then return 0 end
    local sum = 0
    for _, v in ipairs(history) do
        sum = sum + v
    end
    return sum / #history
end

function MusicReactor:detectBeat()
    self.isOnBeat = false
    
    -- Beat detection: bass spike + timing alignment
    local beatExpected = self.timeSinceLastBeat >= self.beatInterval * 0.85
    local bassSpike = self.bass > self.beatThreshold
    
    if bassSpike and beatExpected and self.beatCooldown <= 0 then
        self.isOnBeat = true
        self.timeSinceLastBeat = 0
        self.beatCooldown = 0.1  -- 100ms cooldown to prevent double triggers
        self.beatIntensity = 1.0  -- Spike the visual intensity
        
        -- Debug output
        -- print(string.format("[Beat] %.2fs - Bass: %.2f", self.songTime, self.bass))
    end
end

-- Update timing window (NO PENALTIES - music choreographs, doesn't punish)
function MusicReactor:updateTimingWindow()
    local timeFromBeat = self.timeSinceLastBeat % self.beatInterval
    local timeUntilNextBeat = self.beatInterval - timeFromBeat
    local closestBeatTime = math.min(timeFromBeat, timeUntilNextBeat)
    
    -- All timing windows provide 1.0x multiplier (no penalty)
    -- This is for visual feedback ONLY, not for punishing players
    self.timingMultiplier = 1.0
    
    if closestBeatTime <= 0.05 then
        -- Perfect: ±50ms from beat (visual indicator only)
        self.timingWindow = "perfect"
    elseif closestBeatTime <= 0.1 then
        -- Good: ±100ms from beat (visual indicator only)
        self.timingWindow = "good"
    elseif closestBeatTime <= 0.2 then
        -- Okay: ±200ms from beat (visual indicator only)
        self.timingWindow = "okay"
    else
        -- Outside window (visual indicator only)
        self.timingWindow = "miss"
    end
end

-- Update current song section based on time
function MusicReactor:updateCurrentSection()
    if #self.songStructure == 0 then
        self.currentSection = "default"
        return
    end
    
    for _, section in ipairs(self.songStructure) do
        if self.songTime >= section.start and self.songTime < section.stop then
            self.currentSection = section.name
            return
        end
    end
    
    -- Default to last section if past all defined sections
    self.currentSection = self.songStructure[#self.songStructure].name
end

-- Getter functions for game systems

function MusicReactor:getBassIntensity()
    return self.bassNorm or self.bass
end

function MusicReactor:getMidIntensity()
    return self.midNorm or ((self.midLow + self.midHigh) / 2)
end

function MusicReactor:getTrebleIntensity()
    return self.trebleNorm or self.treble
end

function MusicReactor:getPresenceIntensity()
    return self.presence
end

function MusicReactor:getOverallIntensity()
    return self.intensity
end

-- Short aliases for convenience
function MusicReactor:getBass()
    return self.bassNorm or self.bass
end

function MusicReactor:getMid()
    return self.midNorm or ((self.midLow + self.midHigh) / 2)
end

function MusicReactor:getTreble()
    return self.trebleNorm or self.treble
end

function MusicReactor:getIntensity()
    return self.intensity
end

function MusicReactor:getEnergy()
    return self.energy
end

function MusicReactor:getBeatIntensity()
    return self.beatIntensity
end

function MusicReactor:getBeatPhase()
    return self.beatPhase
end

function MusicReactor:getCurrentBPM()
    return self.bpm
end

function MusicReactor:setBPM(bpm)
    self.bpm = bpm
    self.beatInterval = 60 / bpm
end

function MusicReactor:checkBeat()
    return self.isOnBeat
end

-- New functions for rhythm gameplay

function MusicReactor:getTimingWindow()
    return self.timingWindow, self.timingMultiplier
end

function MusicReactor:getCurrentSection()
    return self.currentSection
end

function MusicReactor:getSongTime()
    return self.songTime
end

function MusicReactor:setSongStructure(structure)
    self.songStructure = structure
end

-- Get frequency bands for enemy spawning
function MusicReactor:getFrequencyBands()
    return {
        bass = self.bassNorm or self.bass,
        mids = self.midNorm or ((self.midLow + self.midHigh) / 2),
        treble = self.trebleNorm or self.treble
    }
end

-- Check if a specific frequency band is dominant
function MusicReactor:isFrequencyDominant(band, threshold)
    threshold = threshold or 0.6
    local bands = self:getFrequencyBands()
    return bands[band] and bands[band] > threshold
end

-- Get dominant frequency (for visual effects)
function MusicReactor:getDominantFrequency()
    local bands = self:getFrequencyBands()
    local maxBand = "mids"
    local maxValue = bands.mids
    
    if bands.bass > maxValue then
        maxBand = "bass"
        maxValue = bands.bass
    end
    
    if bands.treble > maxValue then
        maxBand = "treble"
        maxValue = bands.treble
    end
    
    return maxBand, maxValue
end

-- Game-specific helper functions

function MusicReactor:getSpawnMultiplier()
    -- Returns spawn rate multiplier based on intensity (0.5 to 2.0)
    return 0.5 + self.intensity * 1.5
end

function MusicReactor:getScrollSpeed()
    -- Returns background scroll speed based on BPM
    return math.max(50, self.bpm * 0.8)
end

function MusicReactor:getDifficultyMultiplier()
    -- Returns difficulty multiplier based on energy (0.7 to 1.5)
    return 0.7 + self.energy * 0.8
end

function MusicReactor:getColorIntensities()
    -- Returns RGB mapping for visual effects
    return {
        r = self.bass,
        g = self.midHigh,
        b = self.treble
    }
end

return MusicReactor
