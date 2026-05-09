local weaponTypes = require("components.player.weaponTypes")

local WeaponManager = {}
WeaponManager.__index = WeaponManager

function WeaponManager:new()
    local self = setmetatable({}, WeaponManager)
    self.currentType = "single"
    self.lastShot = 0
    return self
end

function WeaponManager:update(dt)
    self.lastShot = math.max(0, self.lastShot - dt)
end

function WeaponManager:getCurrent()
    return weaponTypes[self.currentType]
end

function WeaponManager:setType(typeName)
    if weaponTypes[typeName] then
        self.currentType = typeName
    end
end

function WeaponManager:cycle(direction)
    local order = weaponTypes.order
    local currentIndex = 1
    for i, name in ipairs(order) do
        if name == self.currentType then
            currentIndex = i
            break
        end
    end
    local nextIndex = currentIndex + direction
    if nextIndex < 1 then
        nextIndex = #order
    elseif nextIndex > #order then
        nextIndex = 1
    end
    self.currentType = order[nextIndex]
end

function WeaponManager:fire(player, target, attackSystem)
    local weapon = self:getCurrent()
    if not weapon then
        return false
    end

    if self.lastShot > 0 then
        return false
    end

    self.lastShot = weapon.fireRate
    attackSystem:fire(weapon.abilityId, player, target, weapon.params)
    return true
end

return WeaponManager
