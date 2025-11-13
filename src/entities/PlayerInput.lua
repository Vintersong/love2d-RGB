-- PlayerInput.lua
-- Handles all player input and movement logic
-- Extracted from Player.lua for better separation of concerns

local PlayerInput = {}

-- Constants
local SCREEN_WIDTH = 1920
local SCREEN_HEIGHT = 1080

-- Process keyboard input and update player position
function PlayerInput.update(player, dt)
    local moveX, moveY

    -- Check if dashing
    if player.isDashing then
        -- Use dash movement (overrides normal input)
        moveX, moveY = player:getDashMovement(dt)
    else
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
    end

    -- Apply movement
    player.x = player.x + moveX
    player.y = player.y + moveY

    -- Keep player in bounds
    player.x = math.max(0, math.min(SCREEN_WIDTH - player.width, player.x))
    player.y = math.max(0, math.min(SCREEN_HEIGHT - player.height, player.y))
end

-- Get player center position (useful for targeting/collision)
function PlayerInput.getCenter(player)
    return player.x + player.width / 2, player.y + player.height / 2
end

return PlayerInput
