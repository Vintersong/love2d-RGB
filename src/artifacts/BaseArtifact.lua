-- BaseArtifact.lua
-- Interface/Pattern documentation for all artifact modules
-- This is NOT a class to inherit from, but a pattern to follow

--[[
    ARTIFACT MODULE PATTERN
    =======================

    Each artifact module exports:

    1. Color-specific variants (e.g., RED, GREEN, BLUE, YELLOW, MAGENTA, CYAN):
       - name: string - Display name
       - effect: string - Effect description
       - behavior: function(player, level) - Initialize artifact on player
       - update: function(state, dt, enemies, player) - Update per frame (optional)
       - draw: function(state, player) - Custom rendering (optional)
       - visual: string - VFX identifier

    2. Main functions:
       - apply(player, level, dominantColor): Initialize artifact for given color
       - update(dt, enemies, player, dominantColor): Update artifact effects
       - draw(player, dominantColor): Render artifact visuals (optional)

    EXAMPLE STRUCTURE:
    ==================

    local MyArtifact = {}

    -- Color-specific behaviors
    MyArtifact.RED = {
        name = "Fire Effect",
        effect = "burn_damage",

        behavior = function(player, level)
            -- Initialize player state for this artifact
            player.myArtifactRed = {
                active = true,
                damage = 10 * level,
                radius = 50
            }
        end,

        update = function(state, dt, enemies, player)
            -- Per-frame logic (damage, collision, etc.)
            for _, enemy in ipairs(enemies) do
                -- Apply effects...
            end
        end,

        draw = function(state, player)
            -- Custom rendering (rings, auras, etc.)
            love.graphics.circle("line", player.x, player.y, state.radius)
        end,

        visual = "fire_ring"
    }

    -- Main entry points
    function MyArtifact.apply(player, level, dominantColor)
        if level <= 0 or not dominantColor then return end

        if dominantColor == "RED" then
            MyArtifact.RED.behavior(player, level)
        elseif dominantColor == "GREEN" then
            MyArtifact.GREEN.behavior(player, level)
        -- ... etc
        end
    end

    function MyArtifact.update(dt, enemies, player, dominantColor)
        if not dominantColor or not player then return end

        if dominantColor == "RED" and player.myArtifactRed then
            MyArtifact.RED.update(player.myArtifactRed, dt, enemies, player)
        elseif dominantColor == "GREEN" and player.myArtifactGreen then
            MyArtifact.GREEN.update(player.myArtifactGreen, dt, enemies, player)
        -- ... etc
        end
    end

    function MyArtifact.draw(player, dominantColor)
        if not dominantColor or not player then return end

        if dominantColor == "RED" and player.myArtifactRed then
            MyArtifact.RED.draw(player.myArtifactRed, player)
        -- ... etc
        end
    end

    return MyArtifact

    RESPONSIBILITIES:
    =================

    - Artifacts manage their own state (stored on player object)
    - Artifacts handle their own update logic (damage, collision, etc.)
    - Artifacts can have custom rendering (rings, auras, projectiles)
    - Artifacts are fully self-contained and decoupled
    - ArtifactManager coordinates activation and levels

    INTEGRATION:
    ============

    In Player:update():
        if ArtifactManager.getLevel("MYARTIFACT") > 0 then
            MyArtifact.apply(self, level, dominantColor)
            MyArtifact.update(dt, enemies, self, dominantColor)
        end

    In Player:draw():
        if ArtifactManager.getLevel("MYARTIFACT") > 0 then
            MyArtifact.draw(self, dominantColor)
        end
]]

local BaseArtifact = {}

-- This module exports no functions - it exists only as documentation
-- All actual artifact implementations follow this pattern independently

return BaseArtifact
