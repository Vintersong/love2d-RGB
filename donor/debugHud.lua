local DebugHUD = {}
DebugHUD.__index = DebugHUD

function DebugHUD:new()
    return setmetatable({}, DebugHUD)
end

function DebugHUD:draw(runtime)
    local input = runtime.input
    local attack = runtime.attack
    local weapon = runtime.weaponManager:getCurrent()
    local ps = runtime.playerStats
    local lines = {
        "State: " .. runtime.state,
        "Debug Ability: " .. input:getAbilityName(),
        "Debug Weapon: " .. weapon.name,
        "Color: " .. runtime.colorSystem:getSummary(),
        "Dominant: " .. runtime.colorSystem:getDominantColor().name,
        "Select Ability: 1-9, 0, -, =",
        "LMB debug fire, RMB lightning",
        "WASD move | SPACE dash | E blink | Q shield",
        "F2 level | F5 heal | F10 boss | TAB cards",
        "HP " .. ps.health .. "/" .. ps.maxHealth .. " | EN " .. ps.energy .. "/" .. ps.maxEnergy,
        "Level " .. ps.level .. " | XP " .. ps.xp .. "/" .. ps.xpToNextLevel .. " | Score " .. ps.score,
        "Enemies: " .. tostring(#runtime.enemyManager.enemies) .. " | Kills: " .. tostring(runtime.enemyManager.killCount),
        "Projectiles: " .. tostring(#attack.projectiles) .. " | Scheduled: " .. tostring(#attack.scheduled),
        "F3 collider debug: " .. (input.debugDrawColliders and "ON" or "OFF"),
    }

    love.graphics.setColor(1, 1, 1, 1)
    for i, text in ipairs(lines) do
        love.graphics.print(text, 20, 20 + (i - 1) * 18)
    end
end

return DebugHUD
