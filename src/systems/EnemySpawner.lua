-- Enemy Spawner System - Music-Reactive Frequency-Based Spawning with Formations

local ProceduralEnemy = require("src.entities.ProceduralEnemy")
local EnemyAbilities = require("src.components.EnemyAbilities")
local Enemy = require("src.entities.Enemy")
local flux = require("libs.flux-master.flux")
local VFXLibrary = require("src.systems.VFXLibrary")

local EnemySpawner = {}

-- Formation patterns with mixed shapes
EnemySpawner.formations = {
    -- Square with triangles on corners
    square_corners = {
        pattern = function(index, total, spacing)
            local positions = {
                {0, 0},           -- Center square
                {-1, -1}, {1, -1}, -- Top corners (triangles)
                {-1, 1}, {1, 1}    -- Bottom corners (triangles)
            }
            local pos = positions[index + 1] or {0, 0}
            return pos[1] * spacing, pos[2] * spacing
        end,
        count = 5,
        roles = {"center", "corner", "corner", "corner", "corner"},  -- Position roles
        shapeOverride = {"square", "triangle", "triangle", "triangle", "triangle"}
    },
    
    -- Hexagon center with 6 triangles around
    hex_star = {
        pattern = function(index, total, spacing)
            if index == 0 then
                return 0, 0  -- Center hexagon
            else
                local angle = ((index - 1) / 6) * math.pi * 2
                local radius = spacing * 1.5
                return math.cos(angle) * radius, math.sin(angle) * radius
            end
        end,
        count = 7,
        roles = {"center", "outer", "outer", "outer", "outer", "outer", "outer"},
        shapeOverride = {"hexagon", "triangle", "triangle", "triangle", "triangle", "triangle", "triangle"}
    },
    
    -- Triangle formation of squares
    tri_squares = {
        pattern = function(index, total, spacing)
            local positions = {
                {0, -1},          -- Top
                {-0.5, 0}, {0.5, 0},  -- Middle row
                {-1, 1}, {0, 1}, {1, 1}  -- Bottom row
            }
            local pos = positions[index + 1] or {0, 0}
            return pos[1] * spacing, pos[2] * spacing
        end,
        count = 6,
        roles = {"leader", "support", "support", "heavy", "heavy", "heavy"},
        shapeOverride = {"square", "square", "square", "square", "square", "square"}
    },
    
    -- Diamond pattern (1 center, 4 around, 4 outer)
    diamond = {
        pattern = function(index, total, spacing)
            local positions = {
                {0, 0},  -- Center
                {0, -1}, {1, 0}, {0, 1}, {-1, 0},  -- Inner ring
                {0, -2}, {2, 0}, {0, 2}, {-2, 0}   -- Outer ring
            }
            local pos = positions[index + 1] or {0, 0}
            return pos[1] * spacing * 0.7, pos[2] * spacing * 0.7
        end,
        count = 9,
        roles = {"center", "inner", "inner", "inner", "inner", "outer", "outer", "outer", "outer"},
        shapeOverride = {"hexagon", "square", "square", "square", "square", "triangle", "triangle", "triangle", "triangle"}
    },
    
    -- Cross formation (5 enemies in + shape)
    cross = {
        pattern = function(index, total, spacing)
            local positions = {
                {0, 0},           -- Center
                {0, -1}, {1, 0}, {0, 1}, {-1, 0}  -- Arms
            }
            local pos = positions[index + 1] or {0, 0}
            return pos[1] * spacing, pos[2] * spacing
        end,
        count = 5,
        roles = {"center", "arm", "arm", "arm", "arm"},
        shapeOverride = {"hexagon", "triangle", "triangle", "triangle", "triangle"}
    },
    
    -- V formation (classic)
    vee = {
        pattern = function(index, total, spacing)
            local positions = {
                {0, 0},                    -- Leader
                {-0.7, 0.7}, {0.7, 0.7},  -- Second row
                {-1.4, 1.4}, {1.4, 1.4},  -- Third row
                {-2.1, 2.1}, {2.1, 2.1}   -- Fourth row
            }
            local pos = positions[index + 1] or {0, 0}
            return pos[1] * spacing * 0.6, pos[2] * spacing * 0.6
        end,
        count = 7,
        roles = {"leader", "follower", "follower", "scout", "scout", "scout", "scout"},
        shapeOverride = {"hexagon", "square", "square", "triangle", "triangle", "triangle", "triangle"}
    },
    
    -- Box formation (square outline)
    box = {
        pattern = function(index, total, spacing)
            local positions = {
                {-1, -1}, {0, -1}, {1, -1},  -- Top
                {-1, 0}, {1, 0},              -- Sides (no center)
                {-1, 1}, {0, 1}, {1, 1}       -- Bottom
            }
            local pos = positions[index + 1] or {0, 0}
            return pos[1] * spacing, pos[2] * spacing
        end,
        count = 8,
        roles = {"corner", "edge", "corner", "edge", "edge", "corner", "edge", "corner"},
        shapeOverride = {"triangle", "square", "triangle", "square", "square", "triangle", "square", "triangle"}
    }
}

-- Formation spawn state
EnemySpawner.formationCooldown = 0
EnemySpawner.formationSpawnRate = 8.0  -- Spawn formation every 8 seconds
EnemySpawner.activeFormations = {}  -- Track active formations for synchronized movement

-- Section-based difficulty settings
EnemySpawner.sectionSettings = {
    intro = {
        spawnRateMultiplier = 0.8,  -- 80% spawn rate
        allowedTypes = {"BASS", "MIDS", "TREBLE"},
        formationComplexity = "simple"
    },
    verse = {
        spawnRateMultiplier = 1.0,  -- Normal spawn rate
        allowedTypes = {"BASS", "MIDS", "TREBLE"},
        formationComplexity = "medium"
    },
    chorus = {
        spawnRateMultiplier = 1.3,  -- 130% spawn rate
        allowedTypes = {"BASS", "MIDS", "TREBLE"},
        formationComplexity = "complex"
    },
    bridge = {
        spawnRateMultiplier = 0.8,  -- Slightly reduced spawn rate
        allowedTypes = {"BASS", "MIDS", "TREBLE"},  -- All types allowed
        formationComplexity = "simple"
    },
    outro = {
        spawnRateMultiplier = 1.0,  -- Normal spawn rate
        allowedTypes = {"BASS", "MIDS", "TREBLE"},  -- All types allowed
        formationComplexity = "simple"
    }
}

function EnemySpawner.update(dt, musicReactor, enemies, playerLevel)
    playerLevel = playerLevel or 1
    
    -- Update formation cooldown
    EnemySpawner.formationCooldown = math.max(0, EnemySpawner.formationCooldown - dt)
    
    -- Spawn formations periodically (formations only - no random spawns)
    if EnemySpawner.formationCooldown <= 0 then
        local currentSection = musicReactor and musicReactor.currentSection or "verse"
        local sectionConfig = EnemySpawner.sectionSettings[currentSection] or EnemySpawner.sectionSettings.verse
        
        EnemySpawner.spawnFormation(enemies, playerLevel, sectionConfig.formationComplexity, musicReactor)
        EnemySpawner.formationCooldown = EnemySpawner.formationSpawnRate
    end
end

-- Assign enemy types based on music frequencies and role
function EnemySpawner.assignEnemyType(role, musicReactor)
    if not musicReactor then
        -- Fallback to random type
        local types = {"BASS", "MIDS", "TREBLE"}
        return types[math.random(#types)]
    end
    
    local bass = musicReactor.bass or 0.5
    local mids = ((musicReactor.midLow or 0.5) + (musicReactor.midHigh or 0.5)) / 2
    local treble = ((musicReactor.treble or 0.5) + (musicReactor.presence or 0.5)) / 2
    
    -- Role-based type assignment influenced by current frequencies
    if role == "center" or role == "leader" or role == "heavy" then
        -- Heavy/center roles favor bass when bass is strong
        if bass > 0.6 then
            return "BASS"
        elseif mids > 0.5 then
            return "MIDS"
        else
            return math.random() > 0.5 and "BASS" or "MIDS"
        end
    elseif role == "outer" or role == "scout" or role == "corner" then
        -- Outer/fast roles favor treble when treble is strong
        if treble > 0.6 then
            return "TREBLE"
        elseif mids > 0.5 then
            return "MIDS"
        else
            return math.random() > 0.5 and "TREBLE" or "MIDS"
        end
    else
        -- Support/balanced roles use frequency distribution
        local total = bass + mids + treble
        local rand = math.random() * total
        
        if rand < bass then
            return "BASS"
        elseif rand < bass + mids then
            return "MIDS"
        else
            return "TREBLE"
        end
    end
end

-- Select formation based on music frequency analysis
function EnemySpawner.selectFormationByMusic(musicReactor, complexity)
    if not musicReactor then
        -- Fallback to random selection
        local allFormations = {"square_corners", "hex_star", "tri_squares", "diamond", "cross", "vee", "box"}
        return allFormations[math.random(#allFormations)]
    end
    
    local bass = musicReactor.bass or 0.5
    local mids = ((musicReactor.midLow or 0.5) + (musicReactor.midHigh or 0.5)) / 2
    local treble = ((musicReactor.treble or 0.5) + (musicReactor.presence or 0.5)) / 2
    local energy = musicReactor.energy or 0.5
    
    -- Get frequency bands for more detailed analysis
    local freqBands = musicReactor:getFrequencyBands()
    local subBass = freqBands.bass or bass  -- Very low frequencies
    local midLow = musicReactor.midLow or 0.5
    local midHigh = musicReactor.midHigh or 0.5
    local highTreble = freqBands.treble or treble
    local presence = musicReactor.presence or 0.5
    
    -- Formation selection based on specific frequency characteristics
    local formationPool = {}
    
    -- SUB-BASS heavy (0-100 Hz) → Dense, compact formations
    if subBass > 0.7 then
        table.insert(formationPool, "square_corners")  -- Tight square
        table.insert(formationPool, "cross")           -- Compact +
        if complexity ~= "simple" then
            table.insert(formationPool, "diamond")     -- Layered density
        end
    end
    
    -- MID-BASS (100-250 Hz) → Geometric, structured formations
    if bass > 0.6 and bass < 0.75 then
        table.insert(formationPool, "box")            -- Hollow square
        table.insert(formationPool, "tri_squares")    -- Triangle grid
        if complexity == "complex" then
            table.insert(formationPool, "diamond")    -- Multi-layer
        end
    end
    
    -- LOW-MIDS (250-500 Hz) → Balanced formations
    if midLow > 0.6 then
        table.insert(formationPool, "cross")          -- Balanced cross
        table.insert(formationPool, "square_corners") -- Mixed types
        if energy > 0.6 then
            table.insert(formationPool, "diamond")    -- Energetic multi-ring
        end
    end
    
    -- HIGH-MIDS (500-2kHz) → Spread formations
    if midHigh > 0.6 then
        table.insert(formationPool, "hex_star")       -- Star pattern
        table.insert(formationPool, "vee")            -- V spread
        if complexity == "complex" then
            table.insert(formationPool, "box")        -- Perimeter spread
        end
    end
    
    -- TREBLE (2k-8kHz) → Fast, angular formations
    if highTreble > 0.65 then
        table.insert(formationPool, "vee")            -- Sharp V
        table.insert(formationPool, "tri_squares")    -- Triangular
        if energy > 0.7 then
            table.insert(formationPool, "hex_star")   -- Fast star burst
        end
    end
    
    -- PRESENCE (8kHz+) → Light, scattered formations
    if presence > 0.7 then
        table.insert(formationPool, "hex_star")       -- Dispersed star
        table.insert(formationPool, "box")            -- Hollow perimeter
        if complexity ~= "simple" then
            table.insert(formationPool, "vee")        -- Extended V
        end
    end
    
    -- MIXED FREQUENCIES (balanced) → Versatile formations
    local freqRange = math.max(bass, mids, treble) - math.min(bass, mids, treble)
    if freqRange < 0.3 then  -- Balanced mix
        table.insert(formationPool, "diamond")        -- All-around
        table.insert(formationPool, "cross")          -- Balanced
        table.insert(formationPool, "square_corners") -- Mixed
    end
    
    -- HIGH ENERGY (any frequency) → Complex formations
    if energy > 0.8 then
        table.insert(formationPool, "diamond")        -- Multi-layer
        table.insert(formationPool, "hex_star")       -- Star burst
        if complexity == "complex" then
            table.insert(formationPool, "box")        -- Full perimeter
        end
    end
    
    -- LOW ENERGY → Simple formations
    if energy < 0.4 then
        table.insert(formationPool, "square_corners") -- Simple 5
        table.insert(formationPool, "cross")          -- Simple 5
        table.insert(formationPool, "vee")            -- Simple 7
    end
    
    -- Select from pool or fallback
    if #formationPool > 0 then
        return formationPool[math.random(#formationPool)]
    else
        -- Fallback based on dominant frequency
        if bass > mids and bass > treble then
            return "square_corners"
        elseif treble > bass and treble > mids then
            return "vee"
        else
            return "cross"
        end
    end
end

-- Spawn a formation of enemies (now with mirrored spawning)
function EnemySpawner.spawnFormation(enemies, playerLevel, complexity, musicReactor)
    local SCREEN_WIDTH = love.graphics.getWidth()
    local SCREEN_HEIGHT = love.graphics.getHeight()
    
    -- Select formation based on music analysis
    local formationName = EnemySpawner.selectFormationByMusic(musicReactor, complexity)
    local formation = EnemySpawner.formations[formationName]
    if not formation then return end
    
    -- Calculate total enemies in formation
    local totalEnemies = formation.count or (formation.rows * formation.columns)
    local spacing = 50  -- Space between enemies
    
    -- Always spawn mirrored formations from left and right sides
    local spawnDirections = {
        {
            name = "left_side",
            startX = -100,
            startY = SCREEN_HEIGHT * 0.3,
            targetX = SCREEN_WIDTH * 0.25,
            targetY = SCREEN_HEIGHT * 0.35,
            mirrorX = false  -- Normal orientation
        },
        {
            name = "right_side",
            startX = SCREEN_WIDTH + 100,
            startY = SCREEN_HEIGHT * 0.3,
            targetX = SCREEN_WIDTH * 0.75,
            targetY = SCREEN_HEIGHT * 0.35,
            mirrorX = true  -- Mirror the formation horizontally
        }
    }
    
    -- Pre-generate enemy types for this formation (so both left and right sides match)
    local formationEnemyTypes = {}
    for i = 0, totalEnemies - 1 do
        local role = formation.roles and formation.roles[i + 1] or "support"
        formationEnemyTypes[i] = EnemySpawner.assignEnemyType(role, musicReactor)
    end
    
    -- Spawn formation for each direction
    for _, direction in ipairs(spawnDirections) do
        local formationID = love.timer.getTime() + math.random()  -- Unique ID
        
        -- Calculate formation bounds for VFX
        local formationWidth = spacing * (formation.columns or 6)
        local formationHeight = spacing * (formation.rows or 3)
        
        -- Spawn warning VFX before formation appears
        VFXLibrary.spawnFormationWarning(direction.targetX, direction.targetY, formationWidth, formationHeight, 1.0)
        
        -- Create formation data for synchronized movement
        local formationData = {
            id = formationID,
            centerX = direction.targetX,
            targetY = direction.targetY,
            members = {}
        }
        
        -- Spawn enemies in formation pattern
        for i = 0, totalEnemies - 1 do
            local offsetX, offsetY = formation.pattern(i, totalEnemies, spacing)
            
            -- Mirror X offset for right-side formation
            if direction.mirrorX then
                offsetX = -offsetX
            end
            
            local x = direction.startX + offsetX
            local y = direction.startY + offsetY
        
            -- Use pre-generated enemy type (same for both left and right)
            local enemyType = formationEnemyTypes[i]
            
            -- Determine shape (override if specified, otherwise use type default)
            local shapeOverride = formation.shapeOverride and formation.shapeOverride[i + 1] or nil
            
            -- Create enemy
            local enemy = Enemy(x, y, enemyType, playerLevel, {
                formation = formationName,
                formationID = formationID,
                formationIndex = i,
                offsetX = offsetX,
                offsetY = offsetY,
                centerX = direction.targetX,
                spawnDirection = direction.name
            })
            
            if enemy then
                -- Apply shape override if specified
                if shapeOverride then
                    enemy.shape = shapeOverride
                end
                
                enemy.pattern = "formation_hold"
                enemy.formationData = formationData
                
                -- Tween to target position (both X and Y for side spawns)
                local targetX = direction.targetX + offsetX
                local targetY = direction.targetY + offsetY
                
                flux.to(enemy, 2.0, {x = targetX, y = targetY})
                    :ease("quadout")
                    :oncomplete(function()
                        -- After arriving, add gentle sway movement
                        enemy.pattern = "formation_sway"
                        
                        -- Spawn flash VFX on first enemy arrival
                        if i == 0 then
                            local formationColor = {1, 0.3, 0.3}  -- Red for formations
                            VFXLibrary.spawnFormationFlash(direction.targetX, direction.targetY, formationColor, 1.5)
                        end
                    end)
                
                table.insert(enemies, enemy)
                table.insert(formationData.members, enemy)
            end
        end
    end
    
    -- Store formation reference
    table.insert(EnemySpawner.activeFormations, formationData)
end

return EnemySpawner
