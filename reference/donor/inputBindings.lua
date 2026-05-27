local InputBindings = {}
InputBindings.__index = InputBindings

InputBindings.abilityNames = {
    "Parallel Lasers",
    "Spread Shot",
    "Sine Wave",
    "Split Shot",
    "Wave Shot",
    "Cluster Shot",
    "Random Spread",
    "Reflecting Shot",
    "Radial Burst",
    "Spiral",
    "Double Spiral",
    "Cross",
}

local abilityKeyToIndex = {
    ["1"] = 1,
    ["2"] = 2,
    ["3"] = 3,
    ["4"] = 4,
    ["5"] = 5,
    ["6"] = 6,
    ["7"] = 7,
    ["8"] = 8,
    ["9"] = 9,
    ["0"] = 10,
    ["-"] = 11,
    ["="] = 12,
}

function InputBindings:new(config)
    local self = setmetatable({}, InputBindings)
    self.config = config or {}
    self.currentAbility = 1
    self.numLasers = 2
    self.numSplits = 2
    self.waveBullets = 7
    self.clusterCount = 8
    self.randomSpreadBullets = 10
    self.reflectBounces = 3
    self.debugDrawColliders = false
    return self
end

function InputBindings:getAbilityName()
    return InputBindings.abilityNames[self.currentAbility] or "Unknown"
end

function InputBindings:getFireParams()
    return {
        numLasers = self.numLasers,
        numSplits = self.numSplits,
        waveBullets = self.waveBullets,
        clusterCount = self.clusterCount,
        randomSpreadBullets = self.randomSpreadBullets,
        reflectBounces = self.reflectBounces,
    }
end

function InputBindings:keypressed(key)
    local selected = abilityKeyToIndex[key]
    if selected then
        self.currentAbility = selected
        return
    end

    if key == "]" then
        self.numLasers = math.min(self.numLasers + 1, 10)
    elseif key == "[" then
        self.numLasers = math.max(self.numLasers - 1, 1)
    elseif key == "'" then
        self.numSplits = math.min(self.numSplits + 1, 8)
    elseif key == ";" then
        self.numSplits = math.max(self.numSplits - 1, 2)
    elseif key == "." then
        self.waveBullets = math.min(self.waveBullets + 1, 24)
    elseif key == "," then
        self.waveBullets = math.max(self.waveBullets - 1, 2)
    elseif key == "x" then
        self.clusterCount = math.min(self.clusterCount + 1, 20)
    elseif key == "z" then
        self.clusterCount = math.max(self.clusterCount - 1, 2)
    elseif key == "v" then
        self.randomSpreadBullets = math.min(self.randomSpreadBullets + 1, 30)
    elseif key == "c" then
        self.randomSpreadBullets = math.max(self.randomSpreadBullets - 1, 2)
    elseif key == "n" then
        self.reflectBounces = math.min(self.reflectBounces + 1, 10)
    elseif key == "b" then
        self.reflectBounces = math.max(self.reflectBounces - 1, 1)
    elseif key == "f3" then
        self.debugDrawColliders = not self.debugDrawColliders
    elseif key == "q" and self.config.onWeaponCycle then
        self.config.onWeaponCycle(-1)
    elseif key == "e" and self.config.onWeaponCycle then
        self.config.onWeaponCycle(1)
    elseif key == "tab" and self.config.onToggleCards then
        self.config.onToggleCards()
    elseif key == "space" and self.config.onSpace then
        self.config.onSpace()
    end
end

function InputBindings:mousepressed(x, y, button, player)
    if button == 1 and self.config.onFire then
        self.config.onFire(
            self.currentAbility,
            player,
            {x = x, y = y},
            self:getFireParams()
        )
    elseif button == 2 and self.config.onAltFire then
        self.config.onAltFire(player, {x = x, y = y})
    end
end

return InputBindings
