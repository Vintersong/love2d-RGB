local XPManager = {}
XPManager.__index = XPManager

function XPManager:new(config)
    local self = setmetatable({}, XPManager)
    self.currentXP = 0
    self.maxXP = (config and config.maxXP) or 100
    self.currentLevel = 1
    self.levelUpCallback = nil
    return self
end

function XPManager:setLevelUpCallback(callback)
    if type(callback) == "function" then
        self.levelUpCallback = callback
    end
end

function XPManager:addXP(amount)
    if type(amount) ~= "number" then
        return false
    end

    self.currentXP = self.currentXP + amount
    local leveled = false

    while self.currentXP >= self.maxXP do
        self.currentXP = self.currentXP - self.maxXP
        self.currentLevel = self.currentLevel + 1
        leveled = true
        if self.levelUpCallback then
            self.levelUpCallback(self.currentLevel)
        end
    end

    return leveled
end

return XPManager
