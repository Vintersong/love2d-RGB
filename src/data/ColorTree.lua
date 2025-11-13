-- Complete RGB Color Upgrade Tree
-- Each color choice unlocks new paths and combinations

local ColorTree = {
    -- PRIMARY COLORS (First choice - always available)
    primary = {
        r = {
            name = "Red",
            path = "damage",
            description = "Commit to raw power",
            baseEffect = { damage = 5 },
            color = {1, 0, 0},
            nextChoices = {"r", "rg", "rb"}  -- Can continue red or mix
        },
        g = {
            name = "Green",
            path = "speed",
            description = "Commit to rapid fire",
            baseEffect = { fireRate = -0.02, bulletCount = 1 },
            color = {0, 1, 0},
            nextChoices = {"g", "rg", "gb"}
        },
        b = {
            name = "Blue",
            path = "utility",
            description = "Commit to tactical options",
            baseEffect = { pierce = 1 },
            color = {0, 0, 1},
            nextChoices = {"b", "rb", "gb"}
        }
    },
    
    -- PURE PATHS (Double down on same color)
    pure = {
        rr = {
            name = "Crimson",
            requires = {"r", "r"},
            path = "pure_damage",
            description = "Pure destruction",
            baseEffect = { damage = 15 },
            color = {1, 0.2, 0.2},
            nextChoices = {"r", "rg", "rb"}  -- Can still mix after double
        },
        gg = {
            name = "Emerald",
            requires = {"g", "g"},
            path = "pure_speed",
            description = "Overwhelming firepower",
            baseEffect = { fireRate = -0.06, bulletCount = 3 },
            color = {0.2, 1, 0.2},
            nextChoices = {"g", "rg", "gb"}
        },
        bb = {
            name = "Sapphire",
            requires = {"b", "b"},
            path = "pure_utility",
            description = "Complete control",
            baseEffect = { pierce = 3, ricochet = 2 },
            color = {0.2, 0.2, 1},
            nextChoices = {"b", "rb", "gb"}
        }
    },
    
    -- MIXED COLORS (Combine two different colors)
    mixed = {
        rg = {
            name = "Yellow",
            requires = {"r", "g"},
            requiresOrder = false,  -- rg or gr both work
            path = "explosive",
            description = "Explosive damage",
            baseEffect = {
                damage = 8,
                explosionRadius = 40,
                bulletCount = 2
            },
            color = {1, 1, 0},
            nextChoices = {"r", "g", "b"}  -- Can go any direction
        },
        rb = {
            name = "Magenta",
            requires = {"r", "b"},
            requiresOrder = false,
            path = "homing",
            description = "Seeking destruction",
            baseEffect = {
                damage = 10,
                homing = true,
                homingStrength = 2.0
            },
            color = {1, 0, 1},
            nextChoices = {"r", "g", "b"}
        },
        gb = {
            name = "Cyan",
            requires = {"g", "b"},
            requiresOrder = false,
            path = "control",
            description = "Tactical superiority",
            baseEffect = {
                bulletCount = 2,
                pierce = 1,
                slowEffect = 0.5,
                slowDuration = 2.0
            },
            color = {0, 1, 1},
            nextChoices = {"r", "g", "b"}
        }
    },
    
    -- ADVANCED PATHS (Triple colors or reinforced doubles)
    advanced = {
        rrr = {
            name = "Blood Red",
            requires = {"r", "r", "r"},
            path = "devastation",
            description = "Ultimate destruction",
            baseEffect = { damage = 30, critChance = 0.2, critMultiplier = 2.0 },
            color = {0.8, 0, 0},
            unlocks = "terrain_red",  -- Unlocks red optical elements
            nextChoices = {"r", "rgb"}  -- Can aim for white
        },
        ggg = {
            name = "Forest Green",
            requires = {"g", "g", "g"},
            path = "suppression",
            description = "Overwhelming barrage",
            baseEffect = { fireRate = -0.1, bulletCount = 7, spreadAngle = 0.05 },
            color = {0, 0.8, 0},
            unlocks = "terrain_green",
            nextChoices = {"g", "rgb"}
        },
        bbb = {
            name = "Deep Blue",
            requires = {"b", "b", "b"},
            path = "mastery",
            description = "Perfect control",
            baseEffect = { pierce = 5, ricochet = 5, homingStrength = 3.0 },
            color = {0, 0, 0.8},
            unlocks = "terrain_blue",
            nextChoices = {"b", "rgb"}
        },
        
        -- WHITE (Ultimate - requires one of each)
        rgb = {
            name = "White Light",
            requires = {"r", "g", "b"},
            requiresOrder = false,
            path = "transcendence",
            description = "Mastery of all elements",
            baseEffect = {
                damage = 20,
                fireRate = -0.05,
                bulletCount = 5,
                pierce = 2,
                explosionRadius = 50,
                homing = true,
                homingStrength = 1.5
            },
            color = {1, 1, 1},
            unlocks = "terrain_all",  -- Can place any optical element
            nextChoices = {"r", "g", "b"}  -- Keep upgrading
        }
    }
}

-- Helper function to check if a color combination is valid
function ColorTree.isValidCombination(history)
    if #history == 0 then
        return true, {"r", "g", "b"}
    end
    
    -- Count each color
    local counts = {r = 0, g = 0, b = 0}
    for _, color in ipairs(history) do
        counts[color] = counts[color] + 1
    end
    
    -- Always allow any color (no restrictions)
    return true, {"r", "g", "b"}
end

-- Helper function to get current path description
function ColorTree.getPathDescription(history)
    local counts = {r = 0, g = 0, b = 0}
    for _, color in ipairs(history) do
        counts[color] = counts[color] + 1
    end
    
    if counts.r > 0 and counts.g == 0 and counts.b == 0 then
        return "Pure Damage Path"
    elseif counts.g > 0 and counts.r == 0 and counts.b == 0 then
        return "Pure Speed Path"
    elseif counts.b > 0 and counts.r == 0 and counts.g == 0 then
        return "Pure Utility Path"
    elseif counts.r > 0 and counts.g > 0 and counts.b == 0 then
        return "Explosive Path (Yellow)"
    elseif counts.r > 0 and counts.b > 0 and counts.g == 0 then
        return "Homing Path (Magenta)"
    elseif counts.g > 0 and counts.b > 0 and counts.r == 0 then
        return "Control Path (Cyan)"
    elseif counts.r > 0 and counts.g > 0 and counts.b > 0 then
        return "Transcendence Path (White)"
    end
    
    return "Hybrid Path"
end

return ColorTree
