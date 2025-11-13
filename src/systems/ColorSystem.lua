-- Color System - Pure Additive Mixing with 2-Primary Commitment
-- Primary colors: RED (multi-target), GREEN (adaptation), BLUE (control)
-- Secondary colors: YELLOW (R+G electric), MAGENTA (R+B time), CYAN (G+B frost)
-- Commitment: Can only choose TWO primaries total, then one secondary unlocks

local ColorTree = require("src.data.ColorTree")

local ColorSystem = {}

-- Primary color tracking
ColorSystem.primary = {
    RED = {level = 0, locked = false},
    GREEN = {level = 0, locked = false},
    BLUE = {level = 0, locked = false}
}

-- Secondary color tracking
ColorSystem.secondary = {
    YELLOW = {level = 0, unlocked = false, requires = {"RED", "GREEN"}},
    MAGENTA = {level = 0, unlocked = false, requires = {"RED", "BLUE"}},
    CYAN = {level = 0, unlocked = false, requires = {"GREEN", "BLUE"}}
}

-- Commitment system
ColorSystem.commitment = {
    primary1 = nil,  -- First primary chosen
    primary2 = nil,  -- Second primary chosen (locks commitment)
    locked = false   -- True when 2 primaries chosen
}

ColorSystem.colorHistory = {}  -- Legacy tracking

function ColorSystem.init()
    ColorSystem.primary = {
        RED = {level = 0, locked = false},
        GREEN = {level = 0, locked = false},
        BLUE = {level = 0, locked = false}
    }
    ColorSystem.secondary = {
        YELLOW = {level = 0, unlocked = false, requires = {"RED", "GREEN"}},
        MAGENTA = {level = 0, unlocked = false, requires = {"RED", "BLUE"}},
        CYAN = {level = 0, unlocked = false, requires = {"GREEN", "BLUE"}}
    }
    ColorSystem.commitment = {
        primary1 = nil,
        primary2 = nil,
        locked = false
    }
    ColorSystem.colorHistory = {}
end

function ColorSystem.getValidChoices(level)
    local choices = {}
    
    -- Add available primaries (if not locked)
    for colorName, data in pairs(ColorSystem.primary) do
        if not data.locked and data.level < 100 then
            -- Convert to lowercase for compatibility
            table.insert(choices, colorName:lower():sub(1, 1))  -- "RED" -> "r"
        end
    end
    
    -- Add unlocked secondaries
    for colorName, data in pairs(ColorSystem.secondary) do
        if data.unlocked and data.level < 100 then
            -- Convert to lowercase: YELLOW -> "y", MAGENTA -> "m", CYAN -> "c"
            table.insert(choices, colorName:lower():sub(1, 1))
        end
    end
    
    return choices
end

function ColorSystem.getTertiaryColor()
    -- Legacy function for compatibility - now returns secondary color
    if not ColorSystem.commitment.primary1 or not ColorSystem.commitment.primary2 then
        return nil
    end
    
    local p1 = ColorSystem.commitment.primary1
    local p2 = ColorSystem.commitment.primary2
    
    if (p1 == "RED" and p2 == "GREEN") or (p1 == "GREEN" and p2 == "RED") then
        return "y"  -- YELLOW
    elseif (p1 == "RED" and p2 == "BLUE") or (p1 == "BLUE" and p2 == "RED") then
        return "m"  -- MAGENTA
    elseif (p1 == "GREEN" and p2 == "BLUE") or (p1 == "BLUE" and p2 == "GREEN") then
        return "c"  -- CYAN
    end
    
    return nil
end

function ColorSystem.addColor(weapon, colorChoice)
    -- Convert lowercase choice to uppercase
    local colorMap = {
        r = "RED",
        g = "GREEN",
        b = "BLUE",
        y = "YELLOW",
        m = "MAGENTA",
        c = "CYAN"
    }
    
    local colorName = colorMap[colorChoice:lower()]
    if not colorName then return end
    
    -- Add to history
    table.insert(ColorSystem.colorHistory, colorChoice)
    
    -- Check if this is a primary color
    if ColorSystem.primary[colorName] then
        ColorSystem.primary[colorName].level = ColorSystem.primary[colorName].level + 1
        
        -- Track commitment
        if not ColorSystem.commitment.primary1 then
            -- First primary chosen
            ColorSystem.commitment.primary1 = colorName
        elseif not ColorSystem.commitment.primary2 and colorName ~= ColorSystem.commitment.primary1 then
            -- Second primary chosen - LOCK COMMITMENT
            ColorSystem.commitment.primary2 = colorName
            ColorSystem.commitment.locked = true
            
            -- Lock out the third primary
            for primary, _ in pairs(ColorSystem.primary) do
                if primary ~= ColorSystem.commitment.primary1 and primary ~= ColorSystem.commitment.primary2 then
                    ColorSystem.primary[primary].locked = true
                end
            end
            
            print("[ColorSystem] Commitment locked to " .. ColorSystem.commitment.primary1 .. " + " .. ColorSystem.commitment.primary2)
        end
        
        -- Check secondary unlock
        ColorSystem.checkSecondaryUnlock()
        
    -- Check if this is a secondary color
    elseif ColorSystem.secondary[colorName] then
        ColorSystem.secondary[colorName].level = ColorSystem.secondary[colorName].level + 1
    end
    
    -- Apply effects based on color choice
    ColorSystem.applyEffects(weapon)
end

function ColorSystem.checkSecondaryUnlock()
    if not ColorSystem.commitment.locked then return end
    
    for secColor, data in pairs(ColorSystem.secondary) do
        if not data.unlocked then
            local req1, req2 = data.requires[1], data.requires[2]
            if ColorSystem.primary[req1].level >= 10 and ColorSystem.primary[req2].level >= 10 then
                data.unlocked = true
                print("[ColorSystem] ✦ " .. secColor .. " UNLOCKED! ✦")
                
                -- Show floating text if available
                local FloatingTextSystem = require("src.systems.FloatingTextSystem")
                FloatingTextSystem.add("✦ " .. secColor .. " UNLOCKED! ✦", 960, 400, "SYNERGY")
            end
        end
    end
end

function ColorSystem.applyEffects(weapon)
    -- PURE ADDITIVE MIXING SYSTEM
    -- All color traits stack independently
    -- RED 20 + GREEN 20 = BOTH traits active at full strength
    
    -- Reset to base stats
    weapon.damage = 10
    weapon.fireRate = 0.20  -- Base fire rate
    weapon.bulletCount = 1
    weapon.guaranteedBullets = 0
    weapon.spreadChance = 0
    weapon.bounceChance = 0
    weapon.pierceChance = 0
    weapon.bounceCount = 1
    weapon.pierceCount = 1
    
    weapon.secondarySpreadChance = 0
    weapon.secondaryBounceChance = 0
    weapon.secondaryPierceChance = 0
    weapon.secondaryGuaranteedBullets = 0
    
    -- Apply RED traits (Multi-target aggression)
    local redLevel = ColorSystem.primary.RED.level
    if redLevel > 0 then
        -- Every 10 levels = +1 projectile
        weapon.guaranteedBullets = math.floor(redLevel / 10)
        
        -- Progress within tier gives chance for next projectile
        local progressInTier = redLevel % 10
        weapon.spreadChance = progressInTier * 0.1  -- 0% to 90%
        
        weapon.damage = weapon.damage + (redLevel * 2)
        weapon.fireRate = weapon.fireRate - (redLevel * 0.001)  -- Slightly faster
        
        -- Spread angle based on projectile count
        local maxProj = weapon.guaranteedBullets + 2
        if maxProj <= 6 then
            weapon.spreadAngle = (math.pi / 6) * maxProj  -- 30° to 180°
        else
            weapon.spreadAngle = math.pi * 2  -- Full circle
        end
    end
    
    -- Apply GREEN traits (Adaptation/seeking)
    local greenLevel = ColorSystem.primary.GREEN.level
    if greenLevel > 0 then
        -- Every 10 levels = +1 bounce
        weapon.bounceCount = 1 + math.floor(greenLevel / 10)
        
        -- Chance to activate bounce
        if greenLevel <= 10 then
            weapon.bounceChance = greenLevel * 0.1
        else
            weapon.bounceChance = 1.0 + ((greenLevel - 10) * 0.05)  -- Over 100%
        end
        
        weapon.damage = weapon.damage + (greenLevel * 3)
        weapon.fireRate = weapon.fireRate + (greenLevel * 0.002)  -- Slightly slower
    end
    
    -- Apply BLUE traits (Control/precision)
    local blueLevel = ColorSystem.primary.BLUE.level
    if blueLevel > 0 then
        -- Every 10 levels = +1 pierce
        weapon.pierceCount = 1 + math.floor(blueLevel / 10)
        
        -- Chance to activate pierce
        if blueLevel <= 10 then
            weapon.pierceChance = blueLevel * 0.1
        else
            weapon.pierceChance = 1.0 + ((blueLevel - 10) * 0.05)  -- Over 100%
        end
        
        weapon.damage = weapon.damage + (blueLevel * 3)
        weapon.fireRate = weapon.fireRate + (blueLevel * 0.003)  -- Slower but powerful
    end
    
    -- Apply YELLOW traits (RED + GREEN = Electric/velocity)
    local yellowLevel = ColorSystem.secondary.YELLOW.level
    if yellowLevel > 0 and ColorSystem.secondary.YELLOW.unlocked then
        -- YELLOW inherits RED + GREEN traits AND adds special effect
        -- Special: X% chance for electric blast wave
        weapon.yellowSpecialChance = yellowLevel * 0.01  -- 1% per level
        weapon.electricDamage = weapon.damage * 0.5
        weapon.electricRadius = 80
        
        -- Speed boost (YELLOW identity)
        weapon.fireRate = weapon.fireRate * 0.85  -- 15% faster
        weapon.yellowActive = true
    end
    
    -- Apply MAGENTA traits (RED + BLUE = Arcane/time)
    local magentaLevel = ColorSystem.secondary.MAGENTA.level
    if magentaLevel > 0 and ColorSystem.secondary.MAGENTA.unlocked then
        -- MAGENTA inherits RED + BLUE traits AND adds time distortion
        -- Special: X% chance for time distortion burst
        weapon.magentaSpecialChance = magentaLevel * 0.01  -- 1% per level
        weapon.timeDistortionDuration = 2.0
        weapon.timeDistortionSlowPercent = 0.5
        
        -- Temporal effects
        weapon.magentaActive = true
    end
    
    -- Apply CYAN traits (GREEN + BLUE = Frost/slow)
    local cyanLevel = ColorSystem.secondary.CYAN.level
    if cyanLevel > 0 and ColorSystem.secondary.CYAN.unlocked then
        -- CYAN inherits GREEN + BLUE traits AND adds frost nova
        -- Special: X% chance for frost nova explosion
        weapon.cyanSpecialChance = cyanLevel * 0.01  -- 1% per level
        weapon.frostDamage = weapon.damage * 0.6
        weapon.frostRadius = 100
        weapon.frostSlowPercent = 0.4
        
        -- Frost effects
        weapon.cyanActive = true
    end
    
    -- Determine weapon name based on active colors
    weapon.weaponType = ColorSystem.getWeaponTypeName()
    weapon.name = weapon.weaponType
end

function ColorSystem.getWeaponTypeName()
    local activePrimaries = {}
    local activeSecondary = nil
    
    if ColorSystem.primary.RED.level > 0 then table.insert(activePrimaries, "RED") end
    if ColorSystem.primary.GREEN.level > 0 then table.insert(activePrimaries, "GREEN") end
    if ColorSystem.primary.BLUE.level > 0 then table.insert(activePrimaries, "BLUE") end
    
    if ColorSystem.secondary.YELLOW.level > 0 then activeSecondary = "YELLOW" end
    if ColorSystem.secondary.MAGENTA.level > 0 then activeSecondary = "MAGENTA" end
    if ColorSystem.secondary.CYAN.level > 0 then activeSecondary = "CYAN" end
    
    if activeSecondary then
        return activeSecondary .. " Hybrid"
    elseif #activePrimaries == 2 then
        return activePrimaries[1] .. "+" .. activePrimaries[2]
    elseif #activePrimaries == 1 then
        return activePrimaries[1] .. " Weapon"
    else
        return "Base Weapon"
    end
end

-- Helper: Get dominant color for artifact behavior selection
function ColorSystem.getDominantColor()
    local maxLevel = 0
    local dominant = nil
    
    -- Check primaries
    for color, data in pairs(ColorSystem.primary) do
        if data.level > maxLevel then
            maxLevel = data.level
            dominant = color
        end
    end
    
    -- Check secondaries (they override if active)
    for color, data in pairs(ColorSystem.secondary) do
        if data.unlocked and data.level > 0 then
            return color  -- Secondary always takes priority
        end
    end
    
    return dominant
end

-- Helper: Get color counts for visualization
function ColorSystem.getColorCounts()
    return {
        RED = ColorSystem.primary.RED.level,
        GREEN = ColorSystem.primary.GREEN.level,
        BLUE = ColorSystem.primary.BLUE.level,
        YELLOW = ColorSystem.secondary.YELLOW.level,
        MAGENTA = ColorSystem.secondary.MAGENTA.level,
        CYAN = ColorSystem.secondary.CYAN.level
    }
end

-- Legacy compatibility functions
function ColorSystem.getCurrentPath()
    local p1 = ColorSystem.commitment.primary1
    local p2 = ColorSystem.commitment.primary2
    
    if not p1 then return "No color chosen" end
    if not p2 then return p1 .. " (uncommitted)" end
    return p1 .. " + " .. p2 .. " (committed)"
end

-- Helper: Get color name for display
function ColorSystem.getColorName(colorCode)
    local names = {
        r = "Red",
        g = "Green", 
        b = "Blue",
        y = "Yellow",
        m = "Magenta",
        c = "Cyan"
    }
    return names[colorCode] or "Unknown"
end

-- Helper: Get projectile color for rendering
function ColorSystem.getProjectileColor()
    local dominant = ColorSystem.getDominantColor()
    
    -- If no color chosen, return white
    if not dominant then
        return {1, 1, 1}
    end
    
    -- Return pure color based on dominant color
    local colorMap = {
        RED = {1, 0.2, 0.2},       -- Bright red
        GREEN = {0.2, 1, 0.2},     -- Bright green
        BLUE = {0.2, 0.5, 1},      -- Bright blue
        YELLOW = {1, 1, 0.2},      -- Bright yellow
        MAGENTA = {1, 0.2, 1},     -- Bright magenta
        CYAN = {0.2, 1, 1}         -- Bright cyan
    }
    
    return colorMap[dominant] or {1, 1, 1}
end

-- Get RGB color for a specific color name
function ColorSystem.getColorRGB(colorName)
    local colorMap = {
        RED = {1, 0, 0},
        GREEN = {0, 1, 0},
        BLUE = {0, 0, 1},
        YELLOW = {1, 1, 0},
        MAGENTA = {1, 0, 1},
        CYAN = {0, 1, 1},
        PURPLE = {0.8, 0, 1}  -- Alias for MAGENTA
    }
    return colorMap[colorName] or {1, 1, 1}
end

return ColorSystem
