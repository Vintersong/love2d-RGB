local mathUtils = require("systems.core.mathUtils")

local ColorSystem = {}
ColorSystem.__index = ColorSystem

local PRIMARY_ORDER = {"RED", "GREEN", "BLUE"}

local COLORS = {
    RED = {
        name = "Red",
        path = "Damage",
        description = "+damage and red dash speed",
        rgb = {1.0, 0.18, 0.18},
    },
    GREEN = {
        name = "Green",
        path = "Velocity",
        description = "+fire rate and bullet count",
        rgb = {0.2, 1.0, 0.35},
    },
    BLUE = {
        name = "Blue",
        path = "Control",
        description = "+pierce and blue dash strike",
        rgb = {0.25, 0.55, 1.0},
    },
    YELLOW = {
        name = "Yellow",
        path = "Explosive",
        description = "RED + GREEN: AoE bursts",
        rgb = {1.0, 0.9, 0.18},
        requires = {"RED", "GREEN"},
    },
    MAGENTA = {
        name = "Magenta",
        path = "Homing",
        description = "RED + BLUE: tracking shots",
        rgb = {1.0, 0.25, 0.95},
        requires = {"RED", "BLUE"},
    },
    CYAN = {
        name = "Cyan",
        path = "Control",
        description = "GREEN + BLUE: slow fields",
        rgb = {0.2, 1.0, 1.0},
        requires = {"GREEN", "BLUE"},
    },
    WHITE = {
        name = "White Light",
        path = "Prototype",
        description = "Full-spectrum debug power",
        rgb = {1.0, 1.0, 1.0},
    },
}

local SECONDARY_BY_PAIR = {
    BLUE_GREEN = "CYAN",
    BLUE_RED = "MAGENTA",
    GREEN_RED = "YELLOW",
}

local clamp = mathUtils.clamp

local function copyColor(color)
    return {color[1], color[2], color[3]}
end

local function pairKey(a, b)
    if a > b then
        a, b = b, a
    end
    return a .. "_" .. b
end

function ColorSystem:new()
    local self = setmetatable({}, ColorSystem)
    self.ranks = {
        RED = 0,
        GREEN = 0,
        BLUE = 0,
        YELLOW = 0,
        MAGENTA = 0,
        CYAN = 0,
    }
    self.primaryOrder = {}
    self.lockedPrimary = nil
    self.secondary = nil
    return self
end

function ColorSystem:getColorInfo(colorId)
    return COLORS[colorId]
end

function ColorSystem:getActivePrimaryCount()
    local count = 0
    for _, colorId in ipairs(PRIMARY_ORDER) do
        if self.ranks[colorId] > 0 then
            count = count + 1
        end
    end
    return count
end

function ColorSystem:isPrimary(colorId)
    return colorId == "RED" or colorId == "GREEN" or colorId == "BLUE"
end

function ColorSystem:isLocked(colorId)
    return self.lockedPrimary == colorId
end

function ColorSystem:updateCommitment()
    if self:getActivePrimaryCount() < 2 then
        return
    end

    local active = {}
    for _, colorId in ipairs(PRIMARY_ORDER) do
        if self.ranks[colorId] > 0 then
            table.insert(active, colorId)
        end
    end

    if not self.lockedPrimary then
        for _, colorId in ipairs(PRIMARY_ORDER) do
            if self.ranks[colorId] == 0 then
                self.lockedPrimary = colorId
                break
            end
        end
    end

    if #active >= 2 and not self.secondary then
        self.secondary = SECONDARY_BY_PAIR[pairKey(active[1], active[2])]
        if self.secondary then
            self.ranks[self.secondary] = math.max(self.ranks[self.secondary], 1)
        end
    end
end

function ColorSystem:canUpgrade(colorId)
    if not COLORS[colorId] then
        return false
    end

    if self:isPrimary(colorId) then
        if self:isLocked(colorId) then
            return false
        end
        if self:getActivePrimaryCount() < 2 then
            return self.ranks[colorId] == 0 or #self.primaryOrder >= 2
        end
        return self.ranks[colorId] > 0 and self.ranks[colorId] < 3
    end

    return self.secondary == colorId and self.ranks[colorId] < 3
end

function ColorSystem:getUpgradeChoices(count)
    count = count or 3
    local choices = {}
    local activePrimaryCount = self:getActivePrimaryCount()

    if activePrimaryCount < 2 then
        for _, colorId in ipairs(PRIMARY_ORDER) do
            if not self:isLocked(colorId) and self.ranks[colorId] == 0 then
                table.insert(choices, self:makeUpgradeCard(colorId))
            end
        end
    else
        for _, colorId in ipairs(PRIMARY_ORDER) do
            if self.ranks[colorId] > 0 and self.ranks[colorId] < 3 then
                table.insert(choices, self:makeUpgradeCard(colorId))
            end
        end
        if self.secondary and self.ranks[self.secondary] < 3 then
            table.insert(choices, self:makeUpgradeCard(self.secondary))
        end
    end

    while #choices > count do
        table.remove(choices, #choices)
    end

    return choices
end

function ColorSystem:makeUpgradeCard(colorId)
    local info = COLORS[colorId]
    local rank = self.ranks[colorId] + 1
    return {
        colorId = colorId,
        name = info.name .. " " .. rank,
        description = info.description,
        path = info.path,
        color = copyColor(info.rgb),
    }
end

function ColorSystem:applyUpgrade(colorId)
    if not self:canUpgrade(colorId) then
        return false
    end

    if self:isPrimary(colorId) and self.ranks[colorId] == 0 then
        table.insert(self.primaryOrder, colorId)
    end

    self.ranks[colorId] = clamp(self.ranks[colorId] + 1, 0, 3)
    self:updateCommitment()
    return true
end

function ColorSystem:getDominantColor()
    if self.secondary and self.ranks[self.secondary] > 0 then
        return {
            id = self.secondary,
            name = COLORS[self.secondary].name,
            color = copyColor(COLORS[self.secondary].rgb),
        }
    end

    local dominant = "WHITE"
    local bestRank = 0
    for _, colorId in ipairs(PRIMARY_ORDER) do
        if self.ranks[colorId] > bestRank then
            dominant = colorId
            bestRank = self.ranks[colorId]
        end
    end

    return {
        id = dominant,
        name = COLORS[dominant].name,
        color = copyColor(COLORS[dominant].rgb),
    }
end

function ColorSystem:getProjectileStats()
    local red = self.ranks.RED
    local green = self.ranks.GREEN
    local blue = self.ranks.BLUE
    local yellow = self.ranks.YELLOW
    local magenta = self.ranks.MAGENTA
    local cyan = self.ranks.CYAN
    local dominant = self:getDominantColor()

    return {
        damage = 1 + red + yellow,
        fireRate = clamp(0.42 - green * 0.055 - cyan * 0.025, 0.13, 0.5),
        bulletCount = 1 + green + yellow + cyan,
        bulletSpeed = 620 + green * 45,
        pierce = blue + cyan,
        aoeRadius = yellow > 0 and (34 + yellow * 12) or 0,
        homing = magenta > 0,
        homingStrength = 2.0 + magenta * 0.45,
        slowFactor = cyan > 0 and 0.55 or 1.0,
        slowDuration = cyan > 0 and (1.2 + cyan * 0.35) or 0,
        color = dominant.color,
        colorId = dominant.id,
    }
end

function ColorSystem:getDashSpec()
    local dominant = self:getDominantColor()
    local spec = {
        colorId = dominant.id,
        color = dominant.color,
        distance = 230,
        cooldown = 1.5,
        duration = 0.14,
        damage = 0,
        healRatio = 0,
        speedBoost = 0,
        speedDuration = 0,
    }

    if dominant.id == "RED" then
        spec.speedBoost = 0.5
        spec.speedDuration = 2.0
    elseif dominant.id == "GREEN" then
        spec.healRatio = 0.1
    elseif dominant.id == "YELLOW" then
        spec.healRatio = 0.05
        spec.speedBoost = 0.3
        spec.speedDuration = 1.5
    elseif dominant.id == "BLUE" or dominant.id == "MAGENTA" or dominant.id == "CYAN" then
        spec.damage = 20
    end

    return spec
end

function ColorSystem:getSummary()
    local parts = {}
    for _, colorId in ipairs({"RED", "GREEN", "BLUE", "YELLOW", "MAGENTA", "CYAN"}) do
        if self.ranks[colorId] > 0 then
            table.insert(parts, colorId .. ":" .. tostring(self.ranks[colorId]))
        end
    end
    if #parts == 0 then
        return "No color"
    end
    return table.concat(parts, " ")
end

return ColorSystem
