-- PlayerInput.lua
-- Handles all player input and movement logic
-- Extracted from Player.lua for better separation of concerns

local PlayerInput = {}

-- Get required systems
local AbilitySystem = require("src.systems.AbilitySystem")
local GameConfig = require("src.systems.GameConfig")
local Config = require("src.Config")

local function getScreenSize()
    local w, h = GameConfig.getScreenSize()
    return w or Config.screen.width, h or Config.screen.height
end

-- Process keyboard input and update player position
function PlayerInput.update(player, dt)
    local moveX, moveY

    -- Check if dashing via AbilitySystem
    local isDashing = AbilitySystem.isActive(player, "DASH")

    if isDashing then
        -- Dash movement is handled by AbilitySystem.update in Player:update
        -- Skip normal movement input
        return
    end

    -- Normal movement from keyboard input
    local dx, dy = 0, 0

    if love.keyboard.isDown("a") then
        dx = dx - 1
    end
    if love.keyboard.isDown("d") then
        dx = dx + 1
    end
    if love.keyboard.isDown("w") then
        dy = dy - 1
    end
    if love.keyboard.isDown("s") then
        dy = dy + 1
    end

    -- Normalize diagonal movement (prevents faster diagonal speed)
    if dx ~= 0 and dy ~= 0 then
        dx = dx * 0.707  -- 1/sqrt(2) ≈ 0.707
        dy = dy * 0.707
    end

    -- Calculate movement with speed boost
    local currentSpeed = player.speed
    if player.speedBoost and player.speedBoostDuration and player.speedBoostDuration > 0 then
        currentSpeed = currentSpeed * player.speedBoost
        player.speedBoostDuration = player.speedBoostDuration - dt
        if player.speedBoostDuration <= 0 then
            player.speedBoost = nil
            player.speedBoostDuration = nil
        end
    end

    moveX = dx * currentSpeed * dt
    moveY = dy * currentSpeed * dt

    -- Apply movement
    player.x = player.x + moveX
    player.y = player.y + moveY

    -- Keep player in bounds
    local screenWidth, screenHeight = getScreenSize()
    player.x = math.max(0, math.min(screenWidth - player.width, player.x))
    player.y = math.max(0, math.min(screenHeight - player.height, player.y))
end

-- Get player center position (useful for targeting/collision)
function PlayerInput.getCenter(player)
    return player.x + player.width / 2, player.y + player.height / 2
end

return PlayerInput
