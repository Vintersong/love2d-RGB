local PlayerStats = {}
PlayerStats.__index = PlayerStats

function PlayerStats:new()
    local self = setmetatable({}, PlayerStats)
    self:reset()
    return self
end

function PlayerStats:reset()
    self.health = 100
    self.maxHealth = 100
    self.energy = 100
    self.maxEnergy = 100
    self.level = 1
    self.xp = 0
    self.xpToNextLevel = 100
    self.score = 0
end

function PlayerStats:calculateXpForLevel(level)
    local baseXP = 100
    local multiplier = 50
    return baseXP + (level * multiplier)
end

function PlayerStats:levelUp()
    self.level = self.level + 1
    self.xp = 0
    self.xpToNextLevel = self:calculateXpForLevel(self.level)
    self.maxHealth = self.maxHealth + 10
    self.health = self.maxHealth
    self.maxEnergy = self.maxEnergy + 5
    self.energy = self.maxEnergy
    return true
end

function PlayerStats:addXP(amount)
    self.xp = self.xp + amount
    if self.xp >= self.xpToNextLevel then
        return self:levelUp()
    end
    return false
end

function PlayerStats:takeDamage(amount)
    self.health = math.max(0, self.health - amount)
end

function PlayerStats:restoreEnergy(amount)
    self.energy = math.min(self.maxEnergy, self.energy + amount)
end

return PlayerStats
