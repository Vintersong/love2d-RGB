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
    return require("src.effects.VFXLibrary")
end

local function getColorSystem()
    return require("src.gameplay.ColorSystem")
end

local function getFloatingTextSystem()
    return require("src.effects.FloatingTextSystem")
end

local function getHealthSystem()
    return require("src.combat.HealthSystem")
end

local function clampPlayerToPlayArea(entity)
    local GameConfig = require("src.core.GameConfig")
    local Config = require("src.Config")
    local SimpleGrid = require("src.gameplay.SimpleGrid")
    local screenWidth, screenHeight = GameConfig.getScreenSize()
    screenWidth = screenWidth or Config.screen.width
    screenHeight = screenHeight or Config.screen.height
    local bandHeight = (SimpleGrid.cellSize or 48) * 2

    entity.x = math.max(0, math.min(screenWidth - entity.width, entity.x))
    entity.y = math.max(bandHeight, math.min(screenHeight - bandHeight - entity.height, entity.y))
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
        state.rhythmBonus = context and context.rhythmBonus or nil  -- on-beat dash bonus (or nil)

        -- Make player invulnerable during dash
        entity.invulnerable = true
        entity.invulnerableTime = AbilityLibrary.DASH.duration

        -- Spawn a dedicated dash streak, distinct from projectile visuals.
        local VFXLibrary = getVFXLibrary()
        local centerX = entity.x + entity.width / 2
        local centerY = entity.y + entity.height / 2
        local dashColor = dominantColor and ColorSystem.getColorRGB(dominantColor) or {1, 1, 1}
        if state.rhythmBonus then
            -- On-beat dash: brighten the trail toward white and flash the crescents.
            local k = (state.rhythmBonus.tier == "perfect") and 0.6 or 0.35
            dashColor = {
                dashColor[1] + (1 - dashColor[1]) * k,
                dashColor[2] + (1 - dashColor[2]) * k,
                dashColor[3] + (1 - dashColor[3]) * k,
            }
            require("src.effects.RhythmCrescents").triggerBurst(state.rhythmBonus.tier)
        end
        VFXLibrary.spawnDashTrail(centerX, centerY, dashColor, dx, dy)

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

        local trailColor = state.color and ColorSystem.getColorRGB(state.color) or {1, 1, 1}
        state.trailTimer = (state.trailTimer or 0) + dt
        if state.trailTimer >= 0.025 then
            state.trailTimer = 0
            VFXLibrary.spawnDashTrail(centerX, centerY, trailColor, state.direction.x, state.direction.y)
        end

        -- Move entity during dash (rhythm bonus lengthens the dash by raising speed)
        local speedMult = (state.rhythmBonus and state.rhythmBonus.speedMult) or 1
        local moveX = state.direction.x * AbilityLibrary.DASH.speed * speedMult * dt
        local moveY = state.direction.y * AbilityLibrary.DASH.speed * speedMult * dt
        entity.x = entity.x + moveX
        entity.y = entity.y + moveY

        -- Keep in bounds
        clampPlayerToPlayArea(entity)

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

        if piercedCount > 0 and (state.color == "BLUE" or state.color == "MAGENTA" or state.color == "CYAN") then
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
                       state.color == "MAGENTA" or state.color == "CYAN" then

                        local damageMult = (state.rhythmBonus and state.rhythmBonus.damageMult) or 1
                        local damage = math.floor(20 * damageMult)  -- Base dash damage x on-beat bonus
                        -- Route through HealthSystem so a dash-only kill marks the
                        -- enemy dead; the PlayingUpdateLoop reward sweep then grants
                        -- XP/drops (a direct `enemy.hp - damage` left kills unrewarded).
                        getHealthSystem().takeDamage(enemy, damage)

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

                        -- MAGENTA: arcane burn — damage over time via the real DoT system
                        if state.color == "MAGENTA" then
                            enemy.dotStacks = enemy.dotStacks or {}
                            table.insert(enemy.dotStacks, {duration = 3.0, damage = 5, tickRate = 0.5})
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
        local Viewport = require("src.render.Viewport")
        local mouseX, mouseY = Viewport.getMousePosition()

        -- Teleport entity to mouse position
        entity.x = mouseX - entity.width / 2
        entity.y = mouseY - entity.height / 2
        clampPlayerToPlayArea(entity)

        -- Spawn VFX at start and end position
        local VFXLibrary = getVFXLibrary()
        VFXLibrary.spawnArtifactEffect("LENS", entity.x, entity.y)

        print("[Blink] Teleported to mouse position")
        return true
    end
}

-- Shield (temporary invulnerability with gradient radial visual)
AbilityLibrary.SHIELD = {
    name = "Shield",
    cooldown = 10.0,
    duration = 3.0,

    onActivate = function(entity, state, context)
        local ShieldEffect = require("src.effects.ShieldEffect")
        local ColorSystem = getColorSystem()

        state.timer = 0
        entity.invulnerable = true

        local centerX = entity.x + entity.width / 2
        local centerY = entity.y + entity.height / 2

        local innerColor = {0.8, 0.8, 0.8, 0.7}
        local outerColor = {0.1, 0.1, 0.1, 0.0}
        local dominant = ColorSystem.getDominantColor()
        if dominant then
            local rgb = ColorSystem.getColorRGB(dominant)
            if rgb then
                innerColor = {rgb[1], rgb[2], rgb[3], 0.7}
                outerColor = {rgb[1] * 0.2, rgb[2] * 0.2, rgb[3] * 0.2, 0.0}
            end
        end

        ShieldEffect.trigger(centerX, centerY, {
            maxRadius = 64,
            expandSpeed = 500,
            rotateSpeed = 1.5,
            fadeSpeed = 3,
            innerColor = innerColor,
            outerColor = outerColor,
        })

        print("[Shield] Shield activated!")
        return true
    end,

    onUpdate = function(entity, state, dt, context)
        state.timer = state.timer + dt

        local ShieldEffect = require("src.effects.ShieldEffect")
        local centerX = entity.x + entity.width / 2
        local centerY = entity.y + entity.height / 2
        ShieldEffect.setPosition(centerX, centerY)

        if state.timer >= AbilityLibrary.SHIELD.duration then
            return false
        end
        return true
    end,

    onDeactivate = function(entity, state, context)
        entity.invulnerable = false
        local ShieldEffect = require("src.effects.ShieldEffect")
        ShieldEffect.despawn()
        print("[Shield] Shield ended")
    end
}

return AbilityLibrary
