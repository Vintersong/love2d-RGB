-- GridAttackSystem.lua
-- Rhythm-based grid attack system that creates expanding wave patterns
-- Telegraphs danger zones with warning borders, then activates with flame particles

local GridAttackSystem = {}

-- Grid configuration
GridAttackSystem.cellSize = 32  -- Size of each grid cell (smaller for more precision)
GridAttackSystem.rows = 0       -- Calculated based on screen
GridAttackSystem.cols = 0       -- Calculated based on screen
GridAttackSystem.grid = {}      -- 2D array of cells
GridAttackSystem.rowGroupSize = 2  -- Group rows in pairs for thicker bands

-- Wave patterns
GridAttackSystem.activeWaves = {}  -- Currently expanding waves
GridAttackSystem.activeCells = {}  -- Currently active (dangerous) cells

-- Timing configuration
GridAttackSystem.beatCounter = 0          -- Count beats for pattern timing
GridAttackSystem.spawnChance = 0.1        -- 30% chance per beat per row group
GridAttackSystem.pauseTimer = 0           -- Time remaining in current pause
GridAttackSystem.pauseDuration = 4.0      -- Length of pauses (seconds)
GridAttackSystem.pauseInterval = 16        -- Pause every N beats
GridAttackSystem.isPaused = false         -- Whether system is paused
GridAttackSystem.centerCol = 0            -- Center column (calculated on init)
GridAttackSystem.edgeMargin = 2           -- Spawn enemies N columns from edge
GridAttackSystem.enemyTypeIndex = 1       -- Cycle through enemy types (1=BASS, 2=MIDS, 3=TREBLE)

-- Visual configuration
GridAttackSystem.warningColor = {1, 1, 1, 0.8}        -- Bright white warning
GridAttackSystem.activeColor = {1, 0.3, 0, 1}         -- Orange/flame color
GridAttackSystem.particleCount = 20                    -- Particles per cell

-- Damage configuration
GridAttackSystem.damagePerSecond = 10  -- Damage when player stands in active cell

-- Initialize the system
function GridAttackSystem.init(screenWidth, screenHeight)
    -- Calculate grid dimensions
    GridAttackSystem.cols = math.ceil(screenWidth / GridAttackSystem.cellSize)
    GridAttackSystem.rows = math.ceil(screenHeight / GridAttackSystem.cellSize)
    GridAttackSystem.centerCol = math.floor(GridAttackSystem.cols / 2)

    print(string.format("[GridAttackSystem] Initialized %dx%d grid (cell size: %d, center: col %d)",
        GridAttackSystem.cols, GridAttackSystem.rows, GridAttackSystem.cellSize, GridAttackSystem.centerCol))

    -- Initialize grid cells
    GridAttackSystem.grid = {}
    for row = 1, GridAttackSystem.rows do
        GridAttackSystem.grid[row] = {}
        for col = 1, GridAttackSystem.cols do
            GridAttackSystem.grid[row][col] = {
                row = row,
                col = col,
                x = (col - 1) * GridAttackSystem.cellSize,
                y = (row - 1) * GridAttackSystem.cellSize,
                state = "inactive",  -- "inactive", "warning", "active"
                timer = 0,
                particles = {}
            }
        end
    end

    -- Create particle system for flame effects
    GridAttackSystem.createParticleSystem()

    GridAttackSystem.activeWaves = {}
    GridAttackSystem.activeCells = {}
    GridAttackSystem.beatCounter = 0
end

-- Create particle system for flame effects
function GridAttackSystem.createParticleSystem()
    -- Simple particle data structure (no LÖVE particle system, manual particles)
    GridAttackSystem.particleImage = nil  -- We'll draw circles
end

-- Update the grid attack system
function GridAttackSystem.update(dt, musicReactor, player, enemies)
    if not musicReactor then return end

    -- Check for beat to manage pauses and spawn enemies
    if musicReactor.isOnBeat then
        GridAttackSystem.beatCounter = GridAttackSystem.beatCounter + 1

        -- Trigger pause on interval
        if GridAttackSystem.beatCounter % GridAttackSystem.pauseInterval == 0 then
            GridAttackSystem.isPaused = true
            GridAttackSystem.pauseTimer = GridAttackSystem.pauseDuration
            print("[GridAttackSystem] Pause started - reposition time!")
        end

        -- Spawn enemies on beat (when not paused)
        if not GridAttackSystem.isPaused and enemies and player then
            GridAttackSystem.spawnMarchingEnemies(musicReactor.intensity, enemies, player.level)
        end
    end

    -- Update pause timer
    if GridAttackSystem.isPaused then
        GridAttackSystem.pauseTimer = GridAttackSystem.pauseTimer - dt
        if GridAttackSystem.pauseTimer <= 0 then
            GridAttackSystem.isPaused = false
            print("[GridAttackSystem] Pause ended - enemies marching!")
        end
    end
end

-- Spawn marching enemies (triggered on each beat)
function GridAttackSystem.spawnMarchingEnemies(intensity, enemies, playerLevel)
    intensity = intensity or 0.5
    playerLevel = playerLevel or 1
    local Enemy = require("src.entities.Enemy")
    local CollisionSystem = require("src.systems.CollisionSystem")

    -- Randomly select which row groups might spawn (more intense = more chances)
    local maxGroups = math.floor(GridAttackSystem.rows / GridAttackSystem.rowGroupSize)

    for groupIndex = 1, maxGroups do
        -- Random chance to spawn in this row group
        if math.random() < GridAttackSystem.spawnChance * intensity then
            local startRow = (groupIndex - 1) * GridAttackSystem.rowGroupSize + 1

            -- Pick middle row of the group
            local spawnRow = startRow + math.floor(GridAttackSystem.rowGroupSize / 2)
            if spawnRow > GridAttackSystem.rows then spawnRow = GridAttackSystem.rows end

            -- Calculate spawn positions (from both edges)
            local spawnY = (spawnRow - 0.5) * GridAttackSystem.cellSize

            -- Always spawn on BOTH sides (mirrored marching enemies)
            local targetX = (GridAttackSystem.centerCol - 0.5) * GridAttackSystem.cellSize

            -- Cycle through enemy types in order (BASS -> MIDS -> TREBLE -> BASS...)
            local enemyTypes = {"BASS", "MIDS", "TREBLE"}
            local enemyType = enemyTypes[GridAttackSystem.enemyTypeIndex]
            GridAttackSystem.enemyTypeIndex = (GridAttackSystem.enemyTypeIndex % 3) + 1  -- Cycle 1->2->3->1

            -- Spawn LEFT enemy
            local leftX = GridAttackSystem.edgeMargin * GridAttackSystem.cellSize
            local leftEnemy = Enemy(leftX, spawnY, enemyType, playerLevel)
            leftEnemy.marchTarget = {x = targetX, y = spawnY}
            leftEnemy.isMarchingEnemy = true
            leftEnemy.followDelay = 999
            leftEnemy.isFollowing = false
            table.insert(enemies, leftEnemy)
            if not CollisionSystem.world:hasItem(leftEnemy) then
                CollisionSystem.add(leftEnemy, "enemy")
            end

            -- Spawn RIGHT enemy (same type, mirrored position)
            local rightX = (GridAttackSystem.cols - GridAttackSystem.edgeMargin) * GridAttackSystem.cellSize
            local rightEnemy = Enemy(rightX, spawnY, enemyType, playerLevel)
            rightEnemy.marchTarget = {x = targetX, y = spawnY}
            rightEnemy.isMarchingEnemy = true
            rightEnemy.followDelay = 999
            rightEnemy.isFollowing = false
            table.insert(enemies, rightEnemy)
            if not CollisionSystem.world:hasItem(rightEnemy) then
                CollisionSystem.add(rightEnemy, "enemy")
            end
        end
    end
end

-- Activate a cell (set to warning state)
function GridAttackSystem.activateCell(row, col)
    if row < 1 or row > GridAttackSystem.rows then return end
    if col < 1 or col > GridAttackSystem.cols then return end

    local cell = GridAttackSystem.grid[row][col]

    -- Only activate if currently inactive
    if cell.state == "inactive" then
        cell.state = "warning"
        cell.timer = 0
    end
end

-- Update all cell states
function GridAttackSystem.updateCells(dt)
    -- Clear active cells list
    GridAttackSystem.activeCells = {}

    for row = 1, GridAttackSystem.rows do
        for col = 1, GridAttackSystem.cols do
            local cell = GridAttackSystem.grid[row][col]

            if cell.state == "warning" then
                cell.timer = cell.timer + dt

                -- Transition to active state
                if cell.timer >= GridAttackSystem.warningDuration then
                    cell.state = "active"
                    cell.timer = 0

                    -- Spawn particles
                    GridAttackSystem.spawnParticles(cell)

                    -- Add to active cells list
                    table.insert(GridAttackSystem.activeCells, cell)
                end

            elseif cell.state == "active" then
                cell.timer = cell.timer + dt

                -- Add to active cells list
                table.insert(GridAttackSystem.activeCells, cell)

                -- Transition to inactive
                if cell.timer >= GridAttackSystem.activeDuration then
                    cell.state = "inactive"
                    cell.timer = 0
                    cell.particles = {}  -- Clear particles
                end
            end
        end
    end
end

-- Spawn flame particles for a cell
function GridAttackSystem.spawnParticles(cell)
    cell.particles = {}

    for i = 1, GridAttackSystem.particleCount do
        local particle = {
            x = cell.x + math.random() * GridAttackSystem.cellSize,
            y = cell.y + math.random() * GridAttackSystem.cellSize,
            vx = (math.random() - 0.5) * 50,
            vy = -math.random() * 100 - 50,  -- Rise upward
            life = math.random() * 0.3 + 0.2,  -- 0.2 to 0.5 seconds
            maxLife = 0.5,
            size = math.random() * 4 + 2
        }

        table.insert(cell.particles, particle)
    end
end

-- Update particles
function GridAttackSystem.updateParticles(dt)
    for row = 1, GridAttackSystem.rows do
        for col = 1, GridAttackSystem.cols do
            local cell = GridAttackSystem.grid[row][col]

            -- Update particles in this cell
            for i = #cell.particles, 1, -1 do
                local p = cell.particles[i]

                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                p.life = p.life - dt

                -- Remove dead particles
                if p.life <= 0 then
                    table.remove(cell.particles, i)
                end
            end
        end
    end
end

-- Check if player is standing in an active cell
function GridAttackSystem.checkPlayerCollision(player, dt)
    if player.dead or player.invulnerable then return end

    -- Calculate player's grid position
    local playerCenterX = player.x + player.width / 2
    local playerCenterY = player.y + player.height / 2

    local playerCol = math.floor(playerCenterX / GridAttackSystem.cellSize) + 1
    local playerRow = math.floor(playerCenterY / GridAttackSystem.cellSize) + 1

    -- Check if player's cell is active
    if playerRow >= 1 and playerRow <= GridAttackSystem.rows and
       playerCol >= 1 and playerCol <= GridAttackSystem.cols then

        local cell = GridAttackSystem.grid[playerRow][playerCol]

        if cell.state == "active" then
            -- Deal continuous damage (doesn't trigger invulnerability)
            player:takeContinuousDamage(GridAttackSystem.damagePerSecond, dt)

            -- Visual feedback (optional)
            -- Could spawn damage numbers or screen shake here
        end
    end
end

-- Draw the grid (warning borders and particles)
function GridAttackSystem.draw(debugMode)
    -- Draw warning cells (bright white borders)
    for row = 1, GridAttackSystem.rows do
        for col = 1, GridAttackSystem.cols do
            local cell = GridAttackSystem.grid[row][col]

            if cell.state == "warning" then
                -- Pulsing white border
                local alpha = 0.5 + math.sin(cell.timer * 20) * 0.3
                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", cell.x, cell.y,
                    GridAttackSystem.cellSize, GridAttackSystem.cellSize)
            elseif cell.state == "active" then
                -- Filled orange/red cell
                local alpha = 1 - (cell.timer / GridAttackSystem.activeDuration)
                love.graphics.setColor(1, 0.3, 0, alpha * 0.4)
                love.graphics.rectangle("fill", cell.x, cell.y,
                    GridAttackSystem.cellSize, GridAttackSystem.cellSize)

                -- Border
                love.graphics.setColor(1, 0.5, 0, alpha)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", cell.x, cell.y,
                    GridAttackSystem.cellSize, GridAttackSystem.cellSize)

                -- Draw particles
                GridAttackSystem.drawParticles(cell)
            end
        end
    end

    -- Debug: Draw grid lines
    if debugMode then
        love.graphics.setColor(0.3, 0.3, 0.3, 0.3)
        love.graphics.setLineWidth(1)

        -- Vertical lines
        for col = 0, GridAttackSystem.cols do
            local x = col * GridAttackSystem.cellSize
            love.graphics.line(x, 0, x, GridAttackSystem.rows * GridAttackSystem.cellSize)
        end

        -- Horizontal lines
        for row = 0, GridAttackSystem.rows do
            local y = row * GridAttackSystem.cellSize
            love.graphics.line(0, y, GridAttackSystem.cols * GridAttackSystem.cellSize, y)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

-- Draw flame particles for a cell
function GridAttackSystem.drawParticles(cell)
    for _, p in ipairs(cell.particles) do
        local lifePercent = p.life / p.maxLife
        local alpha = lifePercent

        -- Flame colors (yellow to orange to red)
        local r = 1
        local g = 0.3 + lifePercent * 0.5  -- Yellower when young
        local b = 0

        love.graphics.setColor(r, g, b, alpha)
        love.graphics.circle("fill", p.x, p.y, p.size * lifePercent)
    end
end

-- Clear all active waves and cells (useful for testing)
function GridAttackSystem.clear()
    GridAttackSystem.activeWaves = {}
    GridAttackSystem.activeCells = {}
    GridAttackSystem.beatCounter = 0

    for row = 1, GridAttackSystem.rows do
        for col = 1, GridAttackSystem.cols do
            local cell = GridAttackSystem.grid[row][col]
            cell.state = "inactive"
            cell.timer = 0
            cell.particles = {}
        end
    end

    print("[GridAttackSystem] Cleared all waves and cells")
end

-- Get active cell count (for debugging)
function GridAttackSystem.getActiveCellCount()
    local count = 0
    for row = 1, GridAttackSystem.rows do
        for col = 1, GridAttackSystem.cols do
            if GridAttackSystem.grid[row][col].state ~= "inactive" then
                count = count + 1
            end
        end
    end
    return count
end

-- Manual trigger for testing
function GridAttackSystem.triggerTestWave()
    GridAttackSystem.triggerWave(0.8)
end

return GridAttackSystem
