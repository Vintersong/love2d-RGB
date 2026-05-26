-- audioAnalyzer.lua
-- Combined audio analysis library merging lovebpm, luafft, and complex functionality
-- Provides BPM detection, FFT analysis, complex math, and comprehensive audio processing

local audioAnalyzer = { _version = "1.0.0" }

-- Complex number implementation (integrated from complex.lua)
local complex = {}
local complex_meta = {}

-- Helper functions for complex number parsing
local _retone = function() return 1 end
local _retminusone = function() return -1 end

function complex.to(num)
    -- check for table type
    if type(num) == "table" then
        -- check for a complex number
        if getmetatable(num) == complex_meta then
            return num
        end
        local real, imag = tonumber(num[1]), tonumber(num[2])
        if real and imag then
            return setmetatable({real, imag}, complex_meta)
        end
        return
    end
    -- check for number
    if type(num) == "number" then
        return setmetatable({num, 0}, complex_meta)
    end
    if type(num) == "string" then
        -- check for real and complex
        local real, sign, imag = string.match(num, "^([%-%+%*%^%d%./Ee]*%d)([%+%-])([%-%+%*%^%d%./Ee]*)i$")
        if real then
            if string.lower(string.sub(real, 1, 1)) == "e"
            or string.lower(string.sub(imag, 1, 1)) == "e" then
                return
            end
            if imag == "" then
                if sign == "+" then
                    imag = _retone
                else
                    imag = _retminusone
                end
            elseif sign == "+" then
                imag = tonumber(imag)
            else
                imag = tonumber(sign .. imag)
            end
            real = tonumber(real)
            if real and imag then
                return setmetatable({real, imag}, complex_meta)
            end
            return
        end
        -- check for complex
        local imag = string.match(num, "^([%-%+%*%^%d%./Ee]*)i$")
        if imag then
            if imag == "" then
                return setmetatable({0, 1}, complex_meta)
            elseif imag == "-" then
                return setmetatable({0, -1}, complex_meta)
            end
            if string.lower(string.sub(imag, 1, 1)) ~= "e" then
                imag = tonumber(imag)
                if imag then
                    return setmetatable({0, imag}, complex_meta)
                end
            end
            return
        end
        -- should be real
        local real = string.match(num, "^(%-*[%d%.][%-%+%*%^%d%./Ee]*)$")
        if real then
            real = tonumber(real)
            if real then
                return setmetatable({real, 0}, complex_meta)
            end
        end
    end
end

-- Set __call behaviour of complex
setmetatable(complex, {__call = function(_, num) return complex.to(num) end})

-- Fast function to get a complex number, not invoking any checks
function complex.new(...)
    return setmetatable({...}, complex_meta)
end

-- Check if argument is of type complex
function complex.type(arg)
    if getmetatable(arg) == complex_meta then
        return "complex"
    end
end

-- Convert polar coordinates to cartesian complex number
function complex.convpolar(radius, phi)
    return setmetatable({radius * math.cos(phi), radius * math.sin(phi)}, complex_meta)
end

-- Complex number functions
function complex.tostring(cx, formatstr)
    local real, imag = cx[1], cx[2]
    if formatstr then
        if imag == 0 then
            return string.format(formatstr, real)
        elseif real == 0 then
            return string.format(formatstr, imag).."i"
        elseif imag > 0 then
            return string.format(formatstr, real).."+"..string.format(formatstr, imag).."i"
        end
        return string.format(formatstr, real)..string.format(formatstr, imag).."i"
    end
    if imag == 0 then
        return real
    elseif real == 0 then
        return ((imag == 1 and "") or (imag == -1 and "-") or imag).."i"
    elseif imag > 0 then
        return real.."+"..(imag == 1 and "" or imag).."i"
    end
    return real..(imag == -1 and "-" or imag).."i"
end

function complex.polar(cx)
    return math.sqrt(cx[1]^2 + cx[2]^2), math.atan(cx[2]/cx[1])
end

function complex.abs(cx)
    return math.sqrt(cx[1]^2 + cx[2]^2)
end

function complex.get(cx)
    return cx[1], cx[2]
end

function complex.set(cx, real, imag)
    cx[1], cx[2] = real, imag
end

function complex.copy(cx)
    return setmetatable({cx[1], cx[2]}, complex_meta)
end

function complex.add(cx1, cx2)
    return setmetatable({cx1[1] + cx2[1], cx1[2] + cx2[2]}, complex_meta)
end

function complex.sub(cx1, cx2)
    return setmetatable({cx1[1] - cx2[1], cx1[2] - cx2[2]}, complex_meta)
end

function complex.mul(cx1, cx2)
    return setmetatable({cx1[1] * cx2[1] - cx1[2] * cx2[2], cx1[1] * cx2[2] + cx1[2] * cx2[1]}, complex_meta)
end

function complex.mulnum(cx, num)
    return setmetatable({cx[1] * num, cx[2] * num}, complex_meta)
end

function complex.div(cx1, cx2)
    local val = cx2[1]^2 + cx2[2]^2
    return setmetatable({(cx1[1] * cx2[1] + cx1[2] * cx2[2]) / val, (cx1[2] * cx2[1] - cx1[1] * cx2[2]) / val}, complex_meta)
end

function complex.divnum(cx, num)
    return setmetatable({cx[1] / num, cx[2] / num}, complex_meta)
end

function complex.conjugate(cx)
    return setmetatable({cx[1], -cx[2]}, complex_meta)
end

function complex.exp(cx)
    local expreal = math.exp(cx[1])
    return setmetatable({expreal * math.cos(cx[2]), expreal * math.sin(cx[2])}, complex_meta)
end

function complex.ln(cx)
    return setmetatable({math.log(math.sqrt(cx[1]^2 + cx[2]^2)), math.atan(cx[2]/cx[1])}, complex_meta)
end

function complex.sqrt(cx)
    local len = math.sqrt(cx[1]^2 + cx[2]^2)
    local sign = (cx[2] < 0 and -1) or 1
    return setmetatable({math.sqrt((cx[1] + len) / 2), sign * math.sqrt((len - cx[1]) / 2)}, complex_meta)
end

function complex.pow(cx, num)
    if num % 1 == 0 then
        if num < 0 then
            local val = cx[1]^2 + cx[2]^2
            cx = {cx[1] / val, -cx[2] / val}
            num = -num
        end
        local real, imag = cx[1], cx[2]
        for i = 2, num do
            real, imag = real * cx[1] - imag * cx[2], real * cx[2] + imag * cx[1]
        end
        return setmetatable({real, imag}, complex_meta)
    end
    local length, phi = math.sqrt(cx[1]^2 + cx[2]^2)^num, math.atan(cx[2]/cx[1]) * num
    return setmetatable({length * math.cos(phi), length * math.sin(phi)}, complex_meta)
end

function complex.round(cx, idp)
    local mult = 10^(idp or 0)
    return setmetatable({math.floor(cx[1] * mult + 0.5) / mult, math.floor(cx[2] * mult + 0.5) / mult}, complex_meta)
end

-- Metatable functions
complex_meta.__add = function(cx1, cx2)
    local cx1, cx2 = complex.to(cx1), complex.to(cx2)
    return complex.add(cx1, cx2)
end
complex_meta.__sub = function(cx1, cx2)
    local cx1, cx2 = complex.to(cx1), complex.to(cx2)
    return complex.sub(cx1, cx2)
end
complex_meta.__mul = function(cx1, cx2)
    local cx1, cx2 = complex.to(cx1), complex.to(cx2)
    return complex.mul(cx1, cx2)
end
complex_meta.__div = function(cx1, cx2)
    local cx1, cx2 = complex.to(cx1), complex.to(cx2)
    return complex.div(cx1, cx2)
end
complex_meta.__pow = function(cx, num)
    if num == "*" then
        return complex.conjugate(cx)
    end
    return complex.pow(cx, num)
end
complex_meta.__unm = function(cx)
    return setmetatable({-cx[1], -cx[2]}, complex_meta)
end
complex_meta.__eq = function(cx1, cx2)
    return cx1[1] == cx2[1] and cx1[2] == cx2[2]
end
complex_meta.__tostring = function(cx)
    return tostring(complex.tostring(cx))
end
complex_meta.__concat = function(cx, cx2)
    return tostring(cx)..tostring(cx2)
end
complex_meta.__call = function(...)
    print(complex.tostring(...))
end
complex_meta.__index = {}
for k, v in pairs(complex) do
    complex_meta.__index[k] = v
end

-- Add complex to audioAnalyzer for external access
audioAnalyzer.complex = complex

-- Include FFT functionality from luafft
local cos, sin = math.cos, math.sin
local debugging = false

local function msg(...)
    if debugging then
        print(...)
    end
end

-- Returns the next possible size for FFT input
local function next_possible_size(n)
    local m = n
    while true do
        m = n
        while m % 2 == 0 do m = m / 2 end
        while m % 3 == 0 do m = m / 3 end
        while m % 5 == 0 do m = m / 5 end
        if m <= 1 then break end
        n = n + 1
    end
    return n
end

-- FFT calculation function
function audioAnalyzer.fft(input, inverse)
    local num_points = #input
    assert(#input == next_possible_size(#input), 
           string.format("The size of your input is not correct. For your size=%i, use a table of size=%i with zeros at the end.", 
                        #input, next_possible_size(#input)))

    local twiddles = {}
    for i = 0, num_points - 1 do
        local phase = -2 * math.pi * i / num_points
        if inverse then phase = phase * -1 end
        twiddles[1 + i] = complex.new(cos(phase), sin(phase))
    end
    
    local factors = calculate_factors(num_points)
    local output = {}
    work(input, output, 1, 1, factors, 1, twiddles, 1, 1, inverse)
    return output
end

-- BPM detection with enhanced FFT-based analysis
function audioAnalyzer.detectBPM(filename, opts)
    -- Handle legacy calling convention: detectBPM(data, sampleRate)
    if type(opts) == "number" then
        -- Old style: detectBPM(amplitudeData, sampleRate)
        local amplitudeData = filename
        local sampleRate = opts
        return audioAnalyzer.detectBPMFromAmplitudeArray(amplitudeData, sampleRate)
    end
    
    -- New style: detectBPM(filename, options)
    opts = opts or {}
    local t = { minbpm = 75, maxbpm = 300, useFFT = false, fftWindowSize = 1024 }
    for k, v in pairs(t) do
        t[k] = opts[k] or v
    end
    opts = t

    -- Load data
    local data = filename
    if type(data) == "string" then
        data = love.sound.newSoundData(data)
    else
        data = filename
    end
    
    if opts.useFFT then
        return audioAnalyzer.detectBPMWithFFT(data, opts)
    else
        return audioAnalyzer.detectBPMAmplitude(data, opts)
    end
end

-- Simple BPM detection from amplitude array (for demo purposes)
function audioAnalyzer.detectBPMFromAmplitudeArray(amplitudeData, sampleRate)
    if not amplitudeData or #amplitudeData == 0 then
        return 120 -- Default BPM
    end
    
    sampleRate = sampleRate or 44100
    
    -- Ensure sampleRate is valid
    if not sampleRate or sampleRate <= 0 then
        sampleRate = 44100
    end
    
    local minBPM = 60
    local maxBPM = 200
    local minInterval = math.floor(sampleRate * 60 / maxBPM)
    local maxInterval = math.floor(sampleRate * 60 / minBPM)
    
    -- Ensure intervals are valid
    if minInterval <= 0 then minInterval = 1 end
    if maxInterval <= minInterval then maxInterval = minInterval + 1 end
    if maxInterval > #amplitudeData then maxInterval = #amplitudeData - 1 end
    
    -- Simple autocorrelation-based BPM detection
    local bestBPM = 120
    local bestScore = 0
    
    -- Test different intervals
    local stepSize = math.max(1, math.floor((maxInterval - minInterval) / 50)) -- Limit iterations
    
    for interval = minInterval, maxInterval, stepSize do
        if interval > 0 and interval < #amplitudeData then
            local score = 0
            local count = 0
            
            for i = 1, #amplitudeData - interval do
                local val1 = amplitudeData[i] or 0
                local val2 = amplitudeData[i + interval] or 0
                score = score + val1 * val2
                count = count + 1
            end
            
            if count > 0 then
                score = score / count
                if score > bestScore then
                    bestScore = score
                    bestBPM = 60 * sampleRate / interval
                end
            end
        end
    end
    
    -- Clamp BPM to reasonable range
    bestBPM = math.max(minBPM, math.min(maxBPM, bestBPM))
    
    return bestBPM
end

-- Original amplitude-based BPM detection
function audioAnalyzer.detectBPMAmplitude(data, opts)
    -- Fix: Use getChannelCount() instead of getChannels()
    local channels = data:getChannelCount() and data:getChannelCount() or data:getChannels()
    local samplerate = data:getSampleRate()

    -- Gets max amplitude over a number of samples at `n` seconds
    local function getAmplitude(n)
        local count = samplerate * channels / 200
        local at = n * channels * samplerate
        if at + count > data:getSampleCount() then
            return 0
        end
        local a = 0
        for i = 0, count - 1 do
            a = math.max(a, math.abs(data:getSample(at + i)))
        end
        return a
    end

    -- Get track duration and init results table
    local dur = data:getDuration("seconds")
    local results = {}

    -- Get maximum allowed BPM
    local step = 8
    local n = (dur * opts.maxbpm / 60)
    n = math.floor(n / step) * step

    -- Fill table with BPMs and their average on-the-beat amplitude
    while true do
        local bpm = n / dur * 60
        if bpm < opts.minbpm then
            break
        end
        local acc = 0
        for i = 0, n - 1 do
            acc = acc + getAmplitude(dur / n * i)
        end
        -- Round BPM to 3 decimal places
        bpm = math.floor(bpm * 1000 + .5) / 1000
        table.insert(results, { bpm = bpm, avg = acc / n })
        n = n - step
    end

    table.sort(results, function(a, b) return a.avg > b.avg end)
    return results[1].bpm
end

-- Enhanced FFT-based BPM detection
function audioAnalyzer.detectBPMWithFFT(data, opts)
    -- Fix: Use getChannelCount() instead of getChannels()
    local channels = data:getChannelCount() and data:getChannelCount() or data:getChannels()
    local samplerate = data:getSampleRate()
    local windowSize = opts.fftWindowSize or 1024
    
    -- Extract mono signal for analysis
    local signal = {}
    local sampleCount = data:getSampleCount()
    
    for i = 0, sampleCount - 1, channels do
        local sample = 0
        for ch = 0, channels - 1 do
            sample = sample + data:getSample(i + ch)
        end
        table.insert(signal, sample / channels)
    end
    
    -- Perform windowed FFT analysis
    local beatStrengths = {}
    local hopSize = windowSize / 2
    
    for start = 1, #signal - windowSize, hopSize do
        local window = {}
        -- Apply Hanning window and prepare for FFT
        for i = 1, windowSize do
            local windowed = signal[start + i - 1] * (0.5 - 0.5 * cos(2 * math.pi * (i - 1) / (windowSize - 1)))
            window[i] = complex.new(windowed, 0)
        end
        
        -- Pad to next power of 2 for efficient FFT
        local fftSize = next_possible_size(windowSize)
        for i = windowSize + 1, fftSize do
            window[i] = complex.new(0, 0)
        end
        
        local spectrum = audioAnalyzer.fft(window, false)
        
        -- Calculate spectral flux (change in magnitude spectrum)
        local flux = 0
        for i = 1, math.floor(fftSize / 2) do
            local magnitude = complex.abs(spectrum[i])
            if beatStrengths[i] then
                flux = flux + math.max(0, magnitude - beatStrengths[i])
            end
            beatStrengths[i] = magnitude
        end
        
        -- Store beat strength for this frame
        table.insert(beatStrengths, flux)
    end
    
    -- Analyze beat periodicity to determine BPM
    return audioAnalyzer.analyzeBeatPeriodicity(beatStrengths, samplerate / hopSize, opts)
end

-- Analyze beat periodicity from spectral flux
function audioAnalyzer.analyzeBeatPeriodicity(beatStrengths, frameRate, opts)
    local autocorr = {}
    local maxLag = math.floor(frameRate * 60 / opts.minbpm) -- Maximum lag for minimum BPM
    
    -- Calculate autocorrelation
    for lag = 1, maxLag do
        local correlation = 0
        local count = 0
        for i = 1, #beatStrengths - lag do
            correlation = correlation + beatStrengths[i] * beatStrengths[i + lag]
            count = count + 1
        end
        autocorr[lag] = count > 0 and correlation / count or 0
    end
    
    -- Find peaks in autocorrelation corresponding to beat periods
    local peaks = {}
    for i = 2, #autocorr - 1 do
        if autocorr[i] > autocorr[i-1] and autocorr[i] > autocorr[i+1] then
            local bpm = 60 * frameRate / i
            if bpm >= opts.minbpm and bpm <= opts.maxbpm then
                table.insert(peaks, { bpm = bpm, strength = autocorr[i], lag = i })
            end
        end
    end
    
    -- Sort by strength and return the strongest peak
    table.sort(peaks, function(a, b) return a.strength > b.strength end)
    return peaks[1] and peaks[1].bpm or 120 -- Default to 120 BPM if no peaks found
end

-- Spectral analysis functions
function audioAnalyzer.analyzeSpectrum(data, windowSize, hopSize)
    windowSize = windowSize or 1024
    hopSize = hopSize or windowSize / 2
    
    -- Fix: Use getChannelCount() instead of getChannels()
    local channels = data:getChannelCount() and data:getChannelCount() or data:getChannels()
    local signal = {}
    local sampleCount = data:getSampleCount()
    
    -- Convert to mono
    for i = 0, sampleCount - 1, channels do
        local sample = 0
        for ch = 0, channels - 1 do
            sample = sample + data:getSample(i + ch)
        end
        table.insert(signal, sample / channels)
    end
    
    local spectrogram = {}

    local fftSize = next_possible_size(windowSize)
    
    for start = 1, #signal - windowSize, hopSize do
        local window = {}
        for i = 1, windowSize do
            local windowed = signal[start + i - 1] * (0.5 - 0.5 * cos(2 * math.pi * (i - 1) / (windowSize - 1)))
            window[i] = complex.new(windowed, 0)
        end
        
        -- Zero pad
        for i = windowSize + 1, fftSize do
            window[i] = complex.new(0, 0)
        end
        
        local spectrum = audioAnalyzer.fft(window, false)
        local magnitudes = {}
        
        for i = 1, math.floor(fftSize / 2) do
            magnitudes[i] = complex.abs(spectrum[i])
        end
        
        table.insert(spectrogram, magnitudes)
    end
    
    return spectrogram
end

-- FFT Spectrum Analysis Functions
function audioAnalyzer.analyzeFFTSpectrum(fftResult, sampleRate)
    sampleRate = sampleRate or 44100
    local spectrum = {
        dominantFreq = 0,
        spectralCentroid = 0,
        spectralSpread = 0,
        totalEnergy = 0,
        magnitudes = {},
        frequencies = {}
    }
    
    local maxMagnitude = 0
    local maxIndex = 1
    local totalMagnitude = 0
    local weightedSum = 0
    
    -- Calculate magnitudes and frequencies
    for i = 1, #fftResult do
        local magnitude = audioAnalyzer.complex.abs(fftResult[i])
        local frequency = (i - 1) * sampleRate / (#fftResult * 2)
        
        spectrum.magnitudes[i] = magnitude
        spectrum.frequencies[i] = frequency
        totalMagnitude = totalMagnitude + magnitude
        
        if magnitude > maxMagnitude then
            maxMagnitude = magnitude
            maxIndex = i
        end
        
        weightedSum = weightedSum + frequency * magnitude
    end
    
    spectrum.totalEnergy = totalMagnitude
    spectrum.dominantFreq = spectrum.frequencies[maxIndex]
    spectrum.spectralCentroid = totalMagnitude > 0 and weightedSum / totalMagnitude or 0
    
    -- Calculate spectral spread
    local spreadSum = 0
    for i = 1, #fftResult do
        local frequency = spectrum.frequencies[i]
        local magnitude = spectrum.magnitudes[i]
        spreadSum = spreadSum + magnitude * (frequency - spectrum.spectralCentroid)^2
    end
    spectrum.spectralSpread = totalMagnitude > 0 and math.sqrt(spreadSum / totalMagnitude) or 0
    
    return spectrum
end

function audioAnalyzer.getFrequencyBins(fftSize, sampleRate)
    local bins = {}
    sampleRate = sampleRate or 44100
    
    -- Calculate frequency for each FFT bin
    -- Only return the first half (positive frequencies)
    for i = 1, math.floor(fftSize / 2) do
        bins[i] = (i - 1) * sampleRate / fftSize
    end
    
    return bins
end

-- Remove the duplicate getFrequencyBands function and keep only this one

-- Track class from lovebpm with added spectral analysis capabilities
local Track = {}
Track.__index = Track

function audioAnalyzer.newTrack()
    local self = setmetatable({}, Track)
    self.source = nil
    self.offset = 0
    self.volume = 1
    self.pitch = 1
    self.looping = false
    self.listeners = {}
    self.period = 60 / 120
    self.lastBeat = nil
    self.lastUpdateTime = nil
    self.lastSourceTime = 0
    self.time = 0
    self.totalTime = 0
    self.dtMultiplier = 1
    self.spectrum = nil
    self.spectralAnalysisEnabled = false
    return self
end

function Track:load(filename)
    self:stop()
    self.source = love.audio.newSource(filename, "static")
    self:setLooping(self.looping)
    self:setVolume(self.volume)
    self:setPitch(self.pitch)
    self.totalTime = self.source:getDuration("seconds")
    self:stop()
    return self
end

function Track:enableSpectralAnalysis(enabled)
    self.spectralAnalysisEnabled = enabled
    return self
end

function Track:setBPM(n)
    self.period = 60 / n
    return self
end

function Track:setOffset(n)
    self.offset = n or 0
    return self
end

function Track:setVolume(volume)
    self.volume = volume or 1
    if self.source then
        self.source:setVolume(self.volume)
    end
    return self
end

function Track:setPitch(pitch)
    self.pitch = pitch or 1
    if self.source then
        self.source:setPitch(self.pitch)
    end
    return self
end

function Track:setLooping(loop)
    self.looping = loop
    if self.source then
        self.source:setLooping(self.looping)
    end
    return self
end

function Track:on(name, fn)
    self.listeners[name] = self.listeners[name] or {}
    table.insert(self.listeners[name], fn)
    return self
end

function Track:emit(name, ...)
    if self.listeners[name] then
        for i, fn in ipairs(self.listeners[name]) do
            fn(...)
        end
    end
    return self
end

function Track:play(restart)
    if not self.source then return self end
    if restart then
        self:stop()
    end
    self.source:play()
    return self
end

function Track:pause()
    if not self.source then return self end
    self.source:pause()
    return self
end

function Track:stop()
    self.lastBeat = nil
    self.time = 0
    self.lastUpdateTime = nil
    self.lastSourceTime = 0
    if self.source then
        self.source:stop()
    end
    return self
end

function Track:setTime(n)
    if not self.source then return end
    self.source:seek(n)
    self.time = n
    self.lastSourceTime = n
    self.lastBeat = self:getBeat() - 1
    return self
end

function Track:setBeat(n)
    return self:setTime(n * self.period)
end

function Track:getTotalTime()
    return self.totalTime
end

function Track:getTotalBeats()
    if not self.source then
        return 0
    end
    return math.floor(self:getTotalTime() / self.period + 0.5)
end

function Track:getTime()
    return self.time
end

function Track:getBeat(multiplier)
    multiplier = multiplier or 1
    local period = self.period * multiplier
    return math.floor(self.time / period), (self.time % period) / period
end

function Track:getCurrentSpectrum()
    return self.spectrum
end

function Track:update()
    if not self.source then return self end

    -- Original timing code from lovebpm
    local t = love.timer.getTime()
    local dt = self.lastUpdateTime and (t - self.lastUpdateTime) or 0
    self.lastUpdateTime = t

    local time
    if self.source:isPlaying() then
        time = self.time + dt * self.dtMultiplier * self.pitch
    else
        time = self.time
    end

    local sourceTime = self.source:tell("seconds")
    sourceTime = sourceTime + self.offset

    if sourceTime ~= self.lastSourceTime then
        local diff = time - sourceTime
        if math.abs(diff) > 0.01 and math.abs(diff) < self.totalTime / 2 then
            self.dtMultiplier = math.max(0, 1 - diff * 2)
        else
            self.dtMultiplier = 1
        end
        self.lastSourceTime = sourceTime
    end

    time = time % self.totalTime

    if self.lastBeat then
        local t = time
        if t < self.time then
            t = t + self.totalTime
        end
        self:emit("update", t - self.time)
    else
        self:emit("update", 0)
    end
    self.time = time

    -- Beat detection and events
    local beat = self:getBeat()
    local last = self.lastBeat
    if beat ~= last then
        self.lastBeat = beat
        local total = self:getTotalBeats()
        local b = beat
        local x = 0
        if last then
            x = last + 1
            if x > b then
                if self.looping then
                    self:emit("loop")
                    b = b + total
                else
                    self:emit("end")
                    self:stop()
                end
            end
        end
        while x <= b do
            self:emit("beat", x % total)
            x = x + 1
        end
    end

    -- Real-time spectral analysis (if enabled)
    if self.spectralAnalysisEnabled and self.source:isPlaying() then
        -- This would require access to the current audio buffer
        -- In practice, you'd need to implement real-time audio capture
        -- or use a different approach for live spectral analysis
        self:emit("spectrum", self.spectrum)
    end

    return self
end

-- Track Management Class
audioAnalyzer.Track = {}
audioAnalyzer.Track.__index = audioAnalyzer.Track

function audioAnalyzer.Track:getAverageIntensity()
    if #self.beatHistory == 0 then
        return 0
    end
    local sum = 0
    for _, beat in ipairs(self.beatHistory) do
        sum = sum + beat.intensity
    end
    return sum / #self.beatHistory
end

function audioAnalyzer.Track:getBeatCount()
    return #self.beatHistory
end

function audioAnalyzer.Track:getLastBeatTime()
    return self.lastBeatTime
end

function audioAnalyzer.Track:getBeatAtTime(time)
    for i, beat in ipairs(self.beatHistory) do
        if math.abs(beat.time - time) < 0.1 then  -- Within 100ms tolerance
            return beat
        end
    end
    return nil
end

function audioAnalyzer.Track:getBeatsInRange(startTime, endTime)
    local beats = {}
    for _, beat in ipairs(self.beatHistory) do
        if beat.time >= startTime and beat.time <= endTime then
            table.insert(beats, beat)
        end
    end
    return beats
end

function audioAnalyzer.Track:getInfo()
    return {
        name = self.name,
        bpm = self.bpm,
        isPlaying = self.isPlaying,
        currentTime = self.currentTime,
        beatCount = #self.beatHistory,
        averageIntensity = self:getAverageIntensity(),
        lastBeatTime = self.lastBeatTime
    }
end

-- FFT Helper functions (from luafft)
function calculate_factors(num_points)
    local buf = {}
    local p = 4
    local floor_sqrt = math.floor(math.sqrt(num_points))
    local n = num_points
    repeat
        while n % p > 0 do
            if p == 4 then p = 2
            elseif p == 2 then p = 3
            else p = p + 2 end
            if p > floor_sqrt then p = n end
        end
        n = n / p
        table.insert(buf, p)
        table.insert(buf, n)
    until n <= 1
    return buf
end

function work(input, output, out_index, f, factors, factors_index, twiddles, fstride, in_stride, inverse)
    local p = factors[factors_index]
    local m = factors[factors_index + 1]
    factors_index = factors_index + 2
    local last = out_index + p * m
    local beg = out_index

    if m == 1 then
        repeat
            if type(input[f]) == "number" then 
                output[out_index] = complex.new(input[f], 0)
            else 
                output[out_index] = input[f] 
            end
            f = f + fstride * in_stride
            out_index = out_index + 1
        until out_index == last
    else
        repeat
            work(input, output, out_index, f, factors, factors_index, twiddles, fstride * p, in_stride, inverse)
            f = f + fstride * in_stride
            out_index = out_index + m
        until out_index == last
    end

    out_index = beg

    if p == 2 then 
        butterfly2(output, out_index, fstride, twiddles, m, inverse)
    elseif p == 3 then 
        butterfly3(output, out_index, fstride, twiddles, m, inverse)
    elseif p == 4 then 
        butterfly4(output, out_index, fstride, twiddles, m, inverse)
    elseif p == 5 then 
        butterfly5(output, out_index, fstride, twiddles, m, inverse)
    else 
        butterfly_generic(output, out_index, fstride, twiddles, m, p, inverse) 
    end
end

function butterfly2(input, out_index, fstride, twiddles, m, inverse)
    local i1 = out_index
    local i2 = out_index + m
    local ti = 1
    repeat
        local t = input[i2] * twiddles[ti]
        ti = ti + fstride
        input[i2] = input[i1] - t
        input[i1] = input[i1] + t
        i1 = i1 + 1
        i2 = i2 + 1
        m = m - 1
    until m == 0
end

function butterfly3(input, out_index, fstride, twiddles, m, inverse)
    local k = m
    local m2 = m * 2
    local tw1, tw2 = 1, 1
    local scratch = {}
    local epi3 = twiddles[fstride * m]
    local i = out_index

    repeat
        scratch[1] = input[i + m] * twiddles[tw1]
        scratch[2] = input[i + m2] * twiddles[tw2]
        scratch[3] = scratch[1] + scratch[2]
        scratch[0] = scratch[1] - scratch[2]
        tw1 = tw1 + fstride
        tw2 = tw2 + fstride * 2

        input[i + m][1] = input[i][1] - scratch[3][1] * 0.5
        input[i + m][2] = input[i][2] - scratch[3][2] * 0.5

        scratch[0] = scratch[0]:mulnum(epi3[2])
        input[i] = input[i] + scratch[3]

        input[i + m2][1] = input[i + m][1] + scratch[0][2]
        input[i + m2][2] = input[i + m][2] - scratch[0][1]

        input[i + m][1] = input[i + m][1] - scratch[0][2]
        input[i + m][2] = input[i + m][2] + scratch[0][1]

        i = i + 1
        k = k - 1
    until k == 0
end

function butterfly4(input, out_index, fstride, twiddles, m, inverse)
    local ti1, ti2, ti3 = 1, 1, 1
    local scratch = {}
    local k = m
    local m2 = 2 * m
    local m3 = 3 * m
    local i = out_index

    repeat
        scratch[0] = input[i + m] * twiddles[ti1]
        scratch[1] = input[i + m2] * twiddles[ti2]
        scratch[2] = input[i + m3] * twiddles[ti3]

        scratch[5] = input[i] - scratch[1]
        input[i] = input[i] + scratch[1]

        scratch[3] = scratch[0] + scratch[2]
        scratch[4] = scratch[0] - scratch[2]

        input[i + m2] = input[i] - scratch[3]
        ti1 = ti1 + fstride
        ti2 = ti2 + fstride * 2
        ti3 = ti3 + fstride * 3
        input[i] = input[i] + scratch[3]

        if inverse then
            input[i + m][1] = scratch[5][1] - scratch[4][2]
            input[i + m][2] = scratch[5][2] + scratch[4][1]

            input[i + m3][1] = scratch[5][1] + scratch[4][2]
            input[i + m3][2] = scratch[5][2] - scratch[4][1]
        else
            input[i + m][1] = scratch[5][1] + scratch[4][2]
            input[i + m][2] = scratch[5][2] - scratch[4][1]

            input[i + m3][1] = scratch[5][1] - scratch[4][2]
            input[i + m3][2] = scratch[5][2] + scratch[4][1]
        end
        i = i + 1
        k = k - 1
    until k == 0
end

function butterfly5(input, out_index, fstride, twiddles, m, inverse)
    local i0, i1, i2, i3, i4 = out_index, out_index + m, out_index + 2 * m, out_index + 3 * m, out_index + 4 * m
    local scratch = {}
    local tw = twiddles
    local ya, yb = tw[1 + fstride * m], tw[1 + fstride * 2 * m]
    
    for u = 0, m - 1 do
        scratch[0] = input[i0]
        scratch[1] = input[i1] * tw[1 + u * fstride]
        scratch[2] = input[i2] * tw[1 + 2 * u * fstride]
        scratch[3] = input[i3] * tw[1 + 3 * u * fstride]
        scratch[4] = input[i4] * tw[1 + 4 * u * fstride]

        scratch[7] = scratch[1] + scratch[4]
        scratch[8] = scratch[2] + scratch[3]
        scratch[9] = scratch[2] - scratch[3]
        scratch[10] = scratch[1] - scratch[4]

        input[i0][1] = input[i0][1] + scratch[7][1] + scratch[8][1]
        input[i0][2] = input[i0][2] + scratch[7][2] + scratch[8][2]

        scratch[5] = complex.new(scratch[0][1] + scratch[7][1] * ya[1] + scratch[8][1] * yb[1],
                                scratch[0][2] + scratch[7][2] * ya[1] + scratch[8][2] * yb[1])

        scratch[6] = complex.new(scratch[10][2] * ya[2] + scratch[9][2] * yb[2],
                                -1 * scratch[10][1] * ya[2] + scratch[9][1] * yb[2])

        input[i1] = scratch[5] - scratch[6]
        input[i4] = scratch[5] + scratch[6]

        scratch[11] = complex.new(scratch[0][1] + scratch[7][1] * yb[1] + scratch[8][1] * ya[1],
                                 scratch[0][2] + scratch[7][2] * yb[1] + scratch[8][2] * ya[1])

        scratch[12] = complex.new(-1 * scratch[10][2] * yb[2] + scratch[9][2] * ya[2],
                                 scratch[10][1] * yb[2] - scratch[9][1] * ya[2])

        input[i2] = scratch[11] + scratch[12]
        input[i3] = scratch[11] - scratch[12]

        i0 = i0 + 1
        i1 = i1 + 1
        i2 = i2 + 1
        i3 = i3 + 1
        i4 = i4 + 1
    end
end

function butterfly_generic(input, out_index, fstride, twiddles, m, p, inverse)
    local norig = #input
    local scratchbuf = {}

    for u = 0, m - 1 do
        local k = u
        for q1 = 0, p - 1 do
            scratchbuf[q1] = input[out_index + k]
            k = k + m
        end

        k = u
        for q1 = 0, p - 1 do
            local twidx = 0
            input[out_index + k] = scratchbuf[0]
            for q = 1, p - 1 do
                twidx = twidx + fstride * k
                if twidx >= norig then twidx = twidx - norig end
                local t = scratchbuf[q] * twiddles[1 + twidx]
                input[out_index + k] = input[out_index + k] + t
            end
            k = k + m
        end
    end
end

-- Get frequency bands (bass, mid, treble)
function audioAnalyzer.getFrequencyBands(spectrum)
    local bands = {
        bass = {energy = 0, peak = 0, range = "20-250 Hz"},
        midLow = {energy = 0, peak = 0, range = "250-500 Hz"},
        midHigh = {energy = 0, peak = 0, range = "500-2000 Hz"},
        treble = {energy = 0, peak = 0, range = "2000-8000 Hz"},
        presence = {energy = 0, peak = 0, range = "8000+ Hz"}
    }
    
    for i = 1, #spectrum.frequencies do
        local freq = spectrum.frequencies[i]
        local mag = spectrum.magnitudes[i]
        local energy = mag * mag
        
        if freq >= 20 and freq < 250 then
            bands.bass.energy = bands.bass.energy + energy
            if mag > bands.bass.peak then bands.bass.peak = mag end
        elseif freq >= 250 and freq < 500 then
            bands.midLow.energy = bands.midLow.energy + energy
            if mag > bands.midLow.peak then bands.midLow.peak = mag end
        elseif freq >= 500 and freq < 2000 then
            bands.midHigh.energy = bands.midHigh.energy + energy
            if mag > bands.midHigh.peak then bands.midHigh.peak = mag end
        elseif freq >= 2000 and freq < 8000 then
            bands.treble.energy = bands.treble.energy + energy
            if mag > bands.treble.peak then bands.treble.peak = mag end
        elseif freq >= 8000 then
            bands.presence.energy = bands.presence.energy + energy
            if mag > bands.presence.peak then bands.presence.peak = mag end
        end
    end
    
    return bands
end

-- Find spectral peaks
function audioAnalyzer.findSpectralPeaks(spectrum, threshold, minDistance)
    threshold = threshold or 0.1
    minDistance = minDistance or 5 -- minimum distance between peaks in frequency bins
    
    local peaks = {}
    local magnitudes = spectrum.magnitudes
    
    for i = 2, #magnitudes - 1 do
        local current = magnitudes[i]
        local prev = magnitudes[i-1]
        local next = magnitudes[i+1]
        
        -- Check if it's a local maximum above threshold
        if current > prev and current > next and current > threshold then
            -- Check minimum distance from other peaks
            local tooClose = false
            for _, peak in ipairs(peaks) do
                if math.abs(i - peak.bin) < minDistance then
                    tooClose = true
                    -- Keep the higher peak
                    if current > peak.magnitude then
                        peak.bin = i
                        peak.frequency = spectrum.frequencies[i]
                        peak.magnitude = current
                    end
                    break
                end
            end
            
            if not tooClose then
                table.insert(peaks, {
                    bin = i,
                    frequency = spectrum.frequencies[i],
                    magnitude = current
                })
            end
        end
    end
    
    -- Sort by magnitude (highest first)
    table.sort(peaks, function(a, b) return a.magnitude > b.magnitude end)
    
    return peaks
end

return audioAnalyzer