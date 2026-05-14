-- SpawnPolicyMusic.lua
-- Music-reactive type/profile/formation selection policy.

local SpawnPolicyMusic = {}

SpawnPolicyMusic.sectionSettings = {
    intro = {
        spawnRateMultiplier = 0.8,
        allowedTypes = {"BASS", "MIDS", "TREBLE"},
        formationComplexity = "simple"
    },
    verse = {
        spawnRateMultiplier = 1.0,
        allowedTypes = {"BASS", "MIDS", "TREBLE"},
        formationComplexity = "medium"
    },
    chorus = {
        spawnRateMultiplier = 1.3,
        allowedTypes = {"BASS", "MIDS", "TREBLE"},
        formationComplexity = "complex"
    },
    bridge = {
        spawnRateMultiplier = 0.8,
        allowedTypes = {"BASS", "MIDS", "TREBLE"},
        formationComplexity = "simple"
    },
    outro = {
        spawnRateMultiplier = 1.0,
        allowedTypes = {"BASS", "MIDS", "TREBLE"},
        formationComplexity = "simple"
    }
}

function SpawnPolicyMusic.getFormationComplexity(musicReactor)
    local currentSection = musicReactor and musicReactor.currentSection or "verse"
    local sectionConfig = SpawnPolicyMusic.sectionSettings[currentSection] or SpawnPolicyMusic.sectionSettings.verse
    return sectionConfig.formationComplexity
end

function SpawnPolicyMusic.assignEnemyType(role, musicReactor)
    if not musicReactor then
        local types = {"BASS", "MIDS", "TREBLE"}
        return types[math.random(#types)]
    end

    local bass = musicReactor.bass or 0.5
    local mids = ((musicReactor.midLow or 0.5) + (musicReactor.midHigh or 0.5)) / 2
    local treble = ((musicReactor.treble or 0.5) + (musicReactor.presence or 0.5)) / 2

    if role == "center" or role == "leader" or role == "heavy" then
        if bass > 0.6 then
            return "BASS"
        elseif mids > 0.5 then
            return "MIDS"
        else
            return math.random() > 0.5 and "BASS" or "MIDS"
        end
    elseif role == "outer" or role == "scout" or role == "corner" then
        if treble > 0.6 then
            return "TREBLE"
        elseif mids > 0.5 then
            return "MIDS"
        else
            return math.random() > 0.5 and "TREBLE" or "MIDS"
        end
    else
        local total = bass + mids + treble
        local rand = math.random() * total
        if rand < bass then
            return "BASS"
        elseif rand < bass + mids then
            return "MIDS"
        end
        return "TREBLE"
    end
end

function SpawnPolicyMusic.createBehaviorProfile(enemyType, role, musicReactor, playerLevel, formationName)
    playerLevel = playerLevel or 1
    local bass = musicReactor and musicReactor.bass or 0.5
    local mids = musicReactor and ((musicReactor.midLow or 0.5) + (musicReactor.midHigh or 0.5)) / 2 or 0.5
    local treble = musicReactor and ((musicReactor.treble or 0.5) + (musicReactor.presence or 0.5)) / 2 or 0.5
    local energy = musicReactor and musicReactor.energy or 0.5

    local profile = {
        modifiers = {"prestige_rings"},
    }

    if role == "center" or role == "leader" or role == "heavy" or enemyType == "BASS" then
        table.insert(profile.modifiers, "tank_scaling")
    elseif role == "outer" or role == "scout" or role == "corner" or enemyType == "TREBLE" then
        table.insert(profile.modifiers, "scout_scaling")
    end

    if playerLevel >= 10 then
        if bass >= mids and bass >= treble then
            table.insert(profile.modifiers, "affinity_red")
        elseif treble >= bass and treble >= mids then
            table.insert(profile.modifiers, "affinity_blue")
        else
            table.insert(profile.modifiers, "affinity_green")
        end
    end
    if playerLevel >= 20 then
        if formationName == "vee" or treble > 0.7 then
            table.insert(profile.modifiers, "affinity_cyan")
        elseif formationName == "diamond" or bass > 0.7 then
            table.insert(profile.modifiers, "affinity_yellow")
        elseif energy > 0.75 then
            table.insert(profile.modifiers, "affinity_magenta")
        end
    end

    return profile
end

function SpawnPolicyMusic.selectFormationByMusic(musicReactor, complexity)
    if not musicReactor then
        local allFormations = {"square_corners", "hex_star", "tri_squares", "diamond", "cross", "vee", "box"}
        return allFormations[math.random(#allFormations)]
    end

    local bass = musicReactor.bass or 0.5
    local mids = ((musicReactor.midLow or 0.5) + (musicReactor.midHigh or 0.5)) / 2
    local treble = ((musicReactor.treble or 0.5) + (musicReactor.presence or 0.5)) / 2
    local energy = musicReactor.energy or 0.5

    local freqBands = musicReactor:getFrequencyBands()
    local subBass = freqBands.bass or bass
    local midLow = musicReactor.midLow or 0.5
    local midHigh = musicReactor.midHigh or 0.5
    local highTreble = freqBands.treble or treble
    local presence = musicReactor.presence or 0.5

    local formationPool = {}

    if subBass > 0.7 then
        table.insert(formationPool, "square_corners")
        table.insert(formationPool, "cross")
        if complexity ~= "simple" then
            table.insert(formationPool, "diamond")
        end
    end

    if bass > 0.6 and bass < 0.75 then
        table.insert(formationPool, "box")
        table.insert(formationPool, "tri_squares")
        if complexity == "complex" then
            table.insert(formationPool, "diamond")
        end
    end

    if midLow > 0.6 then
        table.insert(formationPool, "cross")
        table.insert(formationPool, "square_corners")
        if energy > 0.6 then
            table.insert(formationPool, "diamond")
        end
    end

    if midHigh > 0.6 then
        table.insert(formationPool, "hex_star")
        table.insert(formationPool, "vee")
        if complexity == "complex" then
            table.insert(formationPool, "box")
        end
    end

    if highTreble > 0.65 then
        table.insert(formationPool, "vee")
        table.insert(formationPool, "tri_squares")
        if energy > 0.7 then
            table.insert(formationPool, "hex_star")
        end
    end

    if presence > 0.7 then
        table.insert(formationPool, "hex_star")
        table.insert(formationPool, "box")
        if complexity ~= "simple" then
            table.insert(formationPool, "vee")
        end
    end

    local freqRange = math.max(bass, mids, treble) - math.min(bass, mids, treble)
    if freqRange < 0.3 then
        table.insert(formationPool, "diamond")
        table.insert(formationPool, "cross")
        table.insert(formationPool, "square_corners")
    end

    if energy > 0.8 then
        table.insert(formationPool, "diamond")
        table.insert(formationPool, "hex_star")
        if complexity == "complex" then
            table.insert(formationPool, "box")
        end
    end

    if energy < 0.4 then
        table.insert(formationPool, "square_corners")
        table.insert(formationPool, "cross")
        table.insert(formationPool, "vee")
    end

    if #formationPool > 0 then
        return formationPool[math.random(#formationPool)]
    end

    if bass > mids and bass > treble then
        return "square_corners"
    elseif treble > bass and treble > mids then
        return "vee"
    end
    return "cross"
end

return SpawnPolicyMusic
