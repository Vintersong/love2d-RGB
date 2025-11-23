-- AbilityLibrary.lua
-- Data-driven ability definitions
-- Each ability is a table with:
--   name: string - Display name
--   cooldown: number - Cooldown time in seconds
--   onActivate: function(entity, state, context) - Called when ability starts
--   onUpdate: function(entity, state, dt, context) -> bool - Called each frame (return false to end)
--   onDeactivate: function(entity, state, context) - Called when ability ends

local AbilityLibrary = {}

-- Get required systems (lazy-loaded to avoid circular dependencies)
local function getVFXLibrary()
    return require("src.systems.VFXLibrary")
end

local function getColorSystem()
    return require("src.systems.ColorSystem")
end

local function getFloatingTextSystem()
    return require("src.systems.FloatingTextSystem")
end

-- ============================================================================
-- DASH ABILITY
-- ============================================================================

AbilityLibrary.DASH = {
    name = "Dash",
    cooldown = 1.5,
    duration = 0.2,
    speed = 800,

    -- Called when dash is activated
    onActivate = function(entity, state, context)
        -- Get movement direction from input
        local dx, dy = 0, 0
        if love.keyboard.isDown("a") or love.keyboard.isDown("left") then dx = dx - 1 end
        if love.keyboard.isDown("d") or love.keyboard.isDown("right") then dx = dx + 1 end
        if love.keyboard.isDown("w") or love.keyboard.isDown("up") then dy = dy - 1 end
        if love.keyboard.isDown("s") or love.keyboard.isDown("down") then dy = dy + 1 end

        -- Default direction if no input
        if dx == 0 and dy == 0 then
            dy = -1  -- Dash up
        end

        -- Normalize direction
        local length = math.sqrt(dx * dx + dy * dy)
        if length > 0 then
            dx = dx / length
            dy = dy / length
        end

        -- Get dominant color for dash effects
        local ColorSystem = getColorSystem()
        local dominantColor = ColorSystem.getDominantColor()

        -- Store dash state
        state.timer = 0
        state.direction = {x = dx, y = dy}
        state.color = dominantColor
        state.piercedEnemies = {}  -- Track enemies hit during dash

        -- Make player invulnerable during dash
        entity.invulnerable = true
        entity.invulnerableTime = AbilityLibrary.DASH.duration

        -- Spawn color-specific dash VFX
        local VFXLibrary = getVFXLibrary()
        local centerX = entity.x + entity.width / 2
        local centerY = entity.y + entity.height / 2

        if dominantColor then
            local colorVFXMap = {
                RED = "SUPERNOVA",
                GREEN = "AURORA",
                BLUE = "LENS",
                YELLOW = "REFRACTION",
                MAGENTA = "PRISM",
                CYAN = "DIFFRACTION"
            }

            local vfxType = colorVFXMap[dominantColor] or "DASH"
            VFXLibrary.spawnArtifactEffect(vfxType, centerX, centerY,
                                           centerX + dx * 50, centerY + dy * 50)
        end

        print(string.format("[Dash] %s Dash activated!", dominantColor or "NEUTRAL"))
        return true
    end,

    -- Called every frame while dash is active
    onUpdate = function(entity, state, dt, context)
        state.timer = state.timer + dt

        -- Spawn continuous dash trail particles
        local VFXLibrary = getVFXLibrary()
        local ColorSystem = getColorSystem()
        local centerX = entity.x + entity.width / 2
        local centerY = entity.y + entity.height / 2

        if state.color then
            local trailColor = ColorSystem.getColorRGB(state.color)
            VFXLibrary.spawnImpactBurst(centerX, centerY, trailColor, 2)
        end

        -- Spawn color-specific trail VFX periodically
        if state.color then
            state.trailTimer = (state.trailTimer or 0) + dt
            if state.trailTimer >= 0.05 then
                state.trailTimer = 0

                local colorVFXMap = {
                    RED = "SUPERNOVA",
                    GREEN = "AURORA",
                    BLUE = "LENS",
                    YELLOW = "REFRACTION",
                    MAGENTA = "PRISM",
                    CYAN = "DIFFRACTION"
                }

                local vfxType = colorVFXMap[state.color]
                if vfxType then
                    VFXLibrary.spawnArtifactEffect(vfxType, centerX, centerY,
                                                   centerX - state.direction.x * 20,
                                                   centerY - state.direction.y * 20)
                end
            end
        end

        -- Move entity during dash
        local moveX = state.direction.x * AbilityLibrary.DASH.speed * dt
        local moveY = state.direction.y * AbilityLibrary.DASH.speed * dt
        entity.x = entity.x + moveX
        entity.y = entity.y + moveY

        -- Keep in bounds
        local SCREEN_WIDTH = 1920
        local SCREEN_HEIGHT = 1080
        entity.x = math.max(0, math.min(SCREEN_WIDTH - entity.width, entity.x))
        entity.y = math.max(0, math.min(SCREEN_HEIGHT - entity.height, entity.y))

        -- Check if dash duration expired
        if state.timer >= AbilityLibrary.DASH.duration then
            return false  -- Deactivate dash
        end

        return true  -- Continue dash
    end,

    -- Called when dash ends
    onDeactivate = function(entity, state, context)
        local FloatingTextSystem = getFloatingTextSystem()

        -- Apply color-based post-dash effects
        if state.color == "RED" then
            -- RED: Speed boost after dash
            entity.speedBoost = 1.5
            entity.speedBoostDuration = 2.0
            print("[Dash] RED: Speed boost applied!")

        elseif state.color == "GREEN" then
            -- GREEN: Heal on dash
            local healAmount = entity.maxHp * 0.1
            entity.hp = math.min(entity.maxHp, entity.hp + healAmount)

            FloatingTextSystem.add(
                string.format("+%d HP", math.floor(healAmount)),
                entity.x + entity.width / 2,
                entity.y,
                "HEAL"
            )
            print(string.format("[Dash] GREEN: Healed %d HP", math.floor(healAmount)))

        elseif state.color == "YELLOW" then
            -- YELLOW: Heal + Speed boost (combination)
            local healAmount = entity.maxHp * 0.05
            entity.hp = math.min(entity.maxHp, entity.hp + healAmount)

            entity.speedBoost = 1.3
            entity.speedBoostDuration = 1.5

            FloatingTextSystem.add(
                string.format("+%d HP +SPEED", math.floor(healAmount)),
                entity.x + entity.width / 2,
                entity.y,
                "HEAL"
            )
            print(string.format("[Dash] YELLOW: Healed %d HP + Speed boost", math.floor(healAmount)))
        end

        -- Count pierced enemies for feedback
        local piercedCount = 0
        for _ in pairs(state.piercedEnemies) do
            piercedCount = piercedCount + 1
        end

        if piercedCount > 0 and (state.color == "BLUE" or state.color == "PURPLE" or state.color == "CYAN") then
            print(string.format("[Dash] %s: Pierced %d enemies", state.color, piercedCount))
        end
    end,

    -- Helper: Check collision with enemies during dash
    checkCollisions = function(entity, state, enemies)
        if not state or not state.color then return end  -- Neutral dash has no pierce

        local FloatingTextSystem = getFloatingTextSystem()
        local VFXLibrary = getVFXLibrary()
        local ColorSystem = getColorSystem()

        for _, enemy in ipairs(enemies) do
            if not enemy.dead and not state.piercedEnemies[enemy] then
                -- Check if entity hitbox overlaps enemy
                if entity.x < enemy.x + enemy.width and
                   entity.x + entity.width > enemy.x and
                   entity.y < enemy.y + enemy.height and
                   entity.y + entity.height > enemy.y then

                    -- Mark as pierced
                    state.piercedEnemies[enemy] = true

                    -- Apply color-based pierce effects
                    if state.color == "BLUE" or state.color == "YELLOW" or
                       state.color == "PURPLE" or state.color == "CYAN" then

                        local damage = 20  -- Base dash damage
                        enemy.hp = enemy.hp - damage

                        -- Visual feedback: Floating text
                        FloatingTextSystem.add(
                            string.format("-%d DASH", damage),
                            enemy.x + enemy.width / 2,
                            enemy.y,
                            "DAMAGE"
                        )

                        -- Visual feedback: Impact VFX
                        local impactColor = ColorSystem.getColorRGB(state.color)
                        VFXLibrary.spawnImpactBurst(
                            enemy.x + enemy.width / 2,
                            enemy.y + enemy.height / 2,
                            impactColor,
                            10
                        )

                        -- PURPLE: Apply DoT
                        if state.color == "PURPLE" then
                            enemy.dotDamage = (enemy.dotDamage or 0) + 5
                            enemy.dotDuration = 3.0
                        end

                        -- CYAN: Life steal
                        if state.color == "CYAN" then
                            local healAmount = damage * 0.5
                            entity.hp = math.min(entity.maxHp, entity.hp + healAmount)
                            FloatingTextSystem.add(
                                string.format("+%d HP", math.floor(healAmount)),
                                entity.x + entity.width / 2,
                                entity.y,
                                "HEAL"
                            )
                        end
                    end
                end
            end
        end
    end
}

-- ============================================================================
-- FUTURE ABILITIES (Examples)
-- ============================================================================

-- Example: Blink (teleport)
AbilityLibrary.BLINK = {
    name = "Blink",
    cooldown = 5.0,

    onActivate = function(entity, state, context)
        -- Get mouse position or direction
        local mouseX, mouseY = love.mouse.getPosition()

        -- Teleport entity to mouse position
        entity.x = mouseX - entity.width / 2
        entity.y = mouseY - entity.height / 2

        -- Spawn VFX at start and end position
        local VFXLibrary = getVFXLibrary()
        VFXLibrary.spawnArtifactEffect("LENS", entity.x, entity.y)

        print("[Blink] Teleported to mouse position")
        return true
    end
}

-- Example: Shield (temporary invulnerability)
AbilityLibrary.SHIELD = {
    name = "Shield",
    cooldown = 10.0,
    duration = 3.0,

    onActivate = function(entity, state, context)
        state.timer = 0
        entity.invulnerable = true
        print("[Shield] Shield activated!")
        return true
    end,

    onUpdate = function(entity, state, dt, context)
        state.timer = state.timer + dt

        -- Spawn shield VFX
        local VFXLibrary = getVFXLibrary()
        VFXLibrary.spawnArtifactEffect("HALO", entity.x + entity.width/2, entity.y + entity.height/2)

        if state.timer >= AbilityLibrary.SHIELD.duration then
            return false  -- End shield
        end
        return true
    end,

    onDeactivate = function(entity, state, context)
        entity.invulnerable = false
        print("[Shield] Shield ended")
    end
}

return AbilityLibrary
