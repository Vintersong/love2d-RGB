-- UISandboxState.lua
-- Dedicated UI design and prototyping sandbox
-- No gameplay, no debug overlay - clean space for UI development

local UISandboxState = {}

-- Mock player data for UI testing
local mockPlayer = {
    hp = 85,
    maxHp = 100,
    level = 5,
    exp = 4250,
    expToNext = 5000,
    speed = 150,
    invincible = false,
    dashCooldown = 0,
    dashMaxCooldown = 1.2,
    blinkCooldown = 0,
    blinkMaxCooldown = 3,
    shieldCooldown = 0,
    shieldMaxCooldown = 8,
    width = 20,
    height = 20
}

-- UI state
local sandbox = {
    selectedPanel = 1,  -- 1: HUD, 2: Inventory, 3: Status, 4: Colors, 5: Custom
    showGrid = true,
    gridSize = 20,
    hueShift = 0,  -- For color testing
    colorSamples = {
        {name = "Primary Red", color = {1, 0.2, 0.2}},
        {name = "Primary Green", color = {0.2, 1, 0.2}},
        {name = "Primary Blue", color = {0.2, 0.2, 1}},
        {name = "Secondary Yellow", color = {1, 1, 0.2}},
        {name = "Secondary Magenta", color = {1, 0.2, 1}},
        {name = "Secondary Cyan", color = {0.2, 1, 1}},
        {name = "UI Accent", color = {0.8, 0.4, 1}},
        {name = "UI Background", color = {0.1, 0.1, 0.15}},
    },
    panelSamples = {
        {name = "Health Bar", x = 100, y = 100, width = 300, height = 30},
        {name = "Level Panel", x = 100, y = 150, width = 300, height = 80},
        {name = "Ability Bar", x = 100, y = 250, width = 300, height = 60},
        {name = "Status Icons", x = 100, y = 330, width = 300, height = 80},
    }
}

function UISandboxState:enter(previous, data)
    print("\n=== ENTERING UI SANDBOX ===")
    print("Press 1-5 to switch panels")
    print("Press G to toggle grid")
    print("Press R to reset")
    print("Press Q to quit to main menu")
    print("Arrow keys to adjust values")
    print("=========================\n")
end

function UISandboxState:update(dt)
    -- Simple idle update
end

function UISandboxState:draw()
    love.graphics.clear(0.08, 0.08, 0.12)  -- Dark background
    
    -- Draw grid if enabled
    if sandbox.showGrid then
        drawGrid(sandbox.gridSize)
    end
    
    -- Draw selected panel
    if sandbox.selectedPanel == 1 then
        drawHUDPanel()
    elseif sandbox.selectedPanel == 2 then
        drawInventoryPanel()
    elseif sandbox.selectedPanel == 3 then
        drawStatusPanel()
    elseif sandbox.selectedPanel == 4 then
        drawColorPanel()
    elseif sandbox.selectedPanel == 5 then
        drawCustomPanel()
    end
    
    -- Draw UI info overlay
    drawUIInfoOverlay()
end

function UISandboxState:keypressed(key)
    if key == "q" then
        local Gamestate = require("libs.hump-master.gamestate")
        local SplashScreen = require("src.states.SplashScreenState")
        Gamestate.switch(SplashScreen)
        return
    end
    
    if key == "1" then
        sandbox.selectedPanel = 1
        print("[UI Sandbox] Switched to HUD Panel")
    elseif key == "2" then
        sandbox.selectedPanel = 2
        print("[UI Sandbox] Switched to Inventory Panel")
    elseif key == "3" then
        sandbox.selectedPanel = 3
        print("[UI Sandbox] Switched to Status Panel")
    elseif key == "4" then
        sandbox.selectedPanel = 4
        print("[UI Sandbox] Switched to Color Panel")
    elseif key == "5" then
        sandbox.selectedPanel = 5
        print("[UI Sandbox] Switched to Custom Panel")
    elseif key == "g" then
        sandbox.showGrid = not sandbox.showGrid
        print("[UI Sandbox] Grid: " .. (sandbox.showGrid and "ON" or "OFF"))
    elseif key == "r" then
        mockPlayer.hp = 85
        mockPlayer.level = 5
        mockPlayer.exp = 4250
        print("[UI Sandbox] Reset values")
    elseif key == "up" then
        mockPlayer.hp = math.min(mockPlayer.hp + 5, mockPlayer.maxHp)
    elseif key == "down" then
        mockPlayer.hp = math.max(mockPlayer.hp - 5, 0)
    elseif key == "right" then
        mockPlayer.level = math.min(mockPlayer.level + 1, 20)
    elseif key == "left" then
        mockPlayer.level = math.max(mockPlayer.level - 1, 1)
    end
end

-- ============================================
-- GRID DRAWING
-- ============================================
function drawGrid(size)
    love.graphics.setColor(0.2, 0.2, 0.25, 0.3)
    love.graphics.setLineWidth(0.5)
    
    local w, h = love.graphics.getDimensions()
    
    for x = 0, w, size do
        love.graphics.line(x, 0, x, h)
    end
    
    for y = 0, h, size do
        love.graphics.line(0, y, w, y)
    end
end

-- ============================================
-- PANEL: HUD LAYOUT
-- ============================================
function drawHUDPanel()
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local padding = 20
    
    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("HUD DESIGN PANEL", 0, padding, screenWidth, "center")
    
    -- Health Bar
    local hpX, hpY = 50, 100
    local hpWidth, hpHeight = 400, 40
    drawHealthBar(mockPlayer, hpX, hpY, hpWidth, hpHeight)
    
    -- Level Info Panel
    local levelX, levelY = 50, 160
    local levelWidth, levelHeight = 400, 100
    drawLevelPanel(mockPlayer, levelX, levelY, levelWidth, levelHeight)
    
    -- Ability Cooldowns
    local abilityX, abilityY = 50, 280
    local abilityWidth, abilityHeight = 400, 80
    drawAbilityBar(mockPlayer, abilityX, abilityY, abilityWidth, abilityHeight)
    
    -- Instructions
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("Arrow Keys: Adjust HP/Level | G: Toggle Grid | R: Reset | 1-5: Switch Panels", 50, screenHeight - 40)
end

-- ============================================
-- PANEL: INVENTORY
-- ============================================
function drawInventoryPanel()
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local padding = 20
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("INVENTORY DESIGN PANEL", 0, padding, screenWidth, "center")
    
    -- Artifact Grid
    local gridStartX = 100
    local gridStartY = 100
    local slotSize = 80
    local spacing = 20
    
    love.graphics.setColor(0.3, 0.3, 0.35, 1)
    love.graphics.print("Artifacts:", gridStartX, gridStartY - 40)
    
    -- Draw artifact slots (placeholder)
    for i = 1, 5 do
        local x = gridStartX + (i - 1) * (slotSize + spacing)
        local y = gridStartY
        
        -- Slot background
        love.graphics.setColor(0.15, 0.15, 0.2, 1)
        love.graphics.rectangle("fill", x, y, slotSize, slotSize)
        
        -- Slot border
        love.graphics.setColor(0.5, 0.4, 0.8, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, slotSize, slotSize)
        
        -- Icon placeholder
        love.graphics.setColor(0.7, 0.5, 1, 0.5)
        love.graphics.circle("fill", x + slotSize/2, y + slotSize/2, slotSize/4)
        
        -- Label
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        local names = {"LENS", "MIRROR", "PRISM", "HALO", "DIFF"}
        love.graphics.printf(names[i], x, y + slotSize + 5, slotSize, "center")
    end
    
    -- Powerups section
    local pwrStartX = 100
    local pwrStartY = 250
    
    love.graphics.setColor(0.3, 0.3, 0.35, 1)
    love.graphics.print("Active Powerups:", pwrStartX, pwrStartY - 40)
    
    -- Powerup list with icons
    local powerups = {
        {name = "Damage Up", color = {1, 0.3, 0.3}, icon = "+"},
        {name = "Speed Boost", color = {0.3, 1, 0.3}, icon = "~"},
        {name = "Shield", color = {0.3, 0.3, 1}, icon = "O"},
    }
    
    for i, pw in ipairs(powerups) do
        local y = pwrStartY + (i - 1) * 50
        
        -- Icon
        love.graphics.setColor(pw.color)
        love.graphics.circle("fill", pwrStartX + 15, y + 15, 10)
        
        -- Name
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(pw.name, pwrStartX + 40, y)
    end
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("Arrow Keys: Adjust | G: Toggle Grid | R: Reset | 1-5: Switch Panels", 50, love.graphics.getHeight() - 40)
end

-- ============================================
-- PANEL: STATUS
-- ============================================
function drawStatusPanel()
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("STATUS DESIGN PANEL", 0, 20, screenWidth, "center")
    
    local startX = 100
    local startY = 100
    local lineHeight = 35
    
    -- Status items
    local statusItems = {
        {label = "Level:", value = mockPlayer.level, color = {0.8, 0.8, 0.3}},
        {label = "HP:", value = math.floor(mockPlayer.hp) .. "/" .. mockPlayer.maxHp, color = {1, 0.3, 0.3}},
        {label = "XP:", value = math.floor(mockPlayer.exp) .. "/" .. mockPlayer.expToNext, color = {0.3, 1, 0.8}},
        {label = "Speed:", value = mockPlayer.speed, color = {0.3, 0.8, 1}},
    }
    
    for i, item in ipairs(statusItems) do
        local y = startY + (i - 1) * lineHeight
        
        -- Background panel
        love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
        love.graphics.rectangle("fill", startX, y, 400, 30)
        
        -- Border
        love.graphics.setColor(item.color[1], item.color[2], item.color[3], 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", startX, y, 400, 30)
        
        -- Text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(item.label, startX + 15, y + 5)
        love.graphics.setColor(item.color[1], item.color[2], item.color[3], 1)
        love.graphics.printf(tostring(item.value), startX + 150, y + 5, 250, "left")
    end
    
    -- Ability cooldowns as horizontal bars
    local cdY = startY + 4 * lineHeight + 20
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.print("Ability Cooldowns:", startX, cdY)
    
    local abilityData = {
        {key = "Q", name = "Shield", cooldown = mockPlayer.shieldCooldown, maxCD = mockPlayer.shieldMaxCooldown},
        {key = "E", name = "Blink", cooldown = mockPlayer.blinkCooldown, maxCD = mockPlayer.blinkMaxCooldown},
        {key = "Space", name = "Dash", cooldown = mockPlayer.dashCooldown, maxCD = mockPlayer.dashMaxCooldown},
    }
    
    for i, ab in ipairs(abilityData) do
        local y = cdY + 30 + (i - 1) * 40
        drawCooldownBar(ab.key, ab.name, ab.cooldown, ab.maxCD, startX, y, 300, 25)
    end
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("Arrow Keys: Adjust | G: Toggle Grid | R: Reset | 1-5: Switch Panels", 50, screenHeight - 40)
end

-- ============================================
-- PANEL: COLORS
-- ============================================
function drawColorPanel()
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("COLOR PALETTE PANEL", 0, 20, screenWidth, "center")
    
    local startX = 100
    local startY = 80
    local swatchSize = 80
    local spacing = 20
    
    -- Draw color swatches
    for i, color in ipairs(sandbox.colorSamples) do
        local row = math.floor((i - 1) / 4)
        local col = (i - 1) % 4
        
        local x = startX + col * (swatchSize + spacing)
        local y = startY + row * (swatchSize + spacing)
        
        -- Swatch
        love.graphics.setColor(color.color[1], color.color[2], color.color[3], 1)
        love.graphics.rectangle("fill", x, y, swatchSize, swatchSize)
        
        -- Border
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, swatchSize, swatchSize)
        
        -- Label
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        love.graphics.printf(color.name, x, y + swatchSize + 5, swatchSize, "center")
    end
    
    -- Color theory info
    local infoY = startY + 3 * (swatchSize + spacing) + 40
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("Color System Notes:", startX, infoY)
    
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    local notes = {
        "• Primary colors (RGB) unlock at level 1, 3, 5",
        "• Secondary colors (YMC) unlock at specific levels",
        "• Use colors to shape gameplay and visuals",
        "• Test color combinations for readability",
    }
    
    for i, note in ipairs(notes) do
        love.graphics.print(note, startX, infoY + 20 + (i - 1) * 20)
    end
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("Arrow Keys: Adjust | G: Toggle Grid | R: Reset | 1-5: Switch Panels", 50, screenHeight - 40)
end

-- ============================================
-- PANEL: CUSTOM PROTOTYPES
-- ============================================
function drawCustomPanel()
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("CUSTOM UI PROTOTYPES", 0, 20, screenWidth, "center")
    
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("Add experimental UI elements here:", 100, 80)
    
    -- Example: Character portrait placeholder
    local portraitX, portraitY = 100, 130
    local portraitSize = 120
    
    love.graphics.setColor(0.2, 0.2, 0.25, 1)
    love.graphics.rectangle("fill", portraitX, portraitY, portraitSize, portraitSize)
    
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", portraitX, portraitY, portraitSize, portraitSize)
    
    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.print("[Portrait]", portraitX + 20, portraitY + portraitSize / 2 - 8)
    
    -- Example: Mini stat panel
    local miniPanelX = portraitX + portraitSize + 40
    local miniPanelY = portraitY
    
    love.graphics.setColor(0.15, 0.15, 0.2, 1)
    love.graphics.rectangle("fill", miniPanelX, miniPanelY, 250, portraitSize)
    
    love.graphics.setColor(0.5, 0.7, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", miniPanelX, miniPanelY, 250, portraitSize)
    
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("Character Name", miniPanelX + 15, miniPanelY + 10)
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("Lv. " .. mockPlayer.level, miniPanelX + 15, miniPanelY + 35)
    love.graphics.print("HP: " .. math.floor(mockPlayer.hp) .. "/" .. mockPlayer.maxHp, miniPanelX + 15, miniPanelY + 55)
    love.graphics.print("EXP: " .. math.floor(mockPlayer.exp) .. "/" .. mockPlayer.expToNext, miniPanelX + 15, miniPanelY + 75)
    
    -- Large message display area
    local msgX, msgY = 100, 300
    local msgWidth, msgHeight = 500, 150
    
    love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
    love.graphics.rectangle("fill", msgX, msgY, msgWidth, msgHeight)
    
    love.graphics.setColor(1, 0.8, 0.3, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", msgX, msgY, msgWidth, msgHeight)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("LEVEL UP!\nYou unlocked Yellow color!", msgX, msgY + 30, msgWidth, "center")
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("Arrow Keys: Adjust | G: Toggle Grid | R: Reset | 1-5: Switch Panels", 50, screenHeight - 40)
end

-- ============================================
-- UI COMPONENT DRAWING
-- ============================================

function drawHealthBar(player, x, y, width, height)
    local hpPercent = player.hp / player.maxHp
    
    -- Background
    love.graphics.setColor(0.15, 0.15, 0.2, 1)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- HP bar (gradient red to orange)
    if hpPercent > 0.5 then
        love.graphics.setColor(0.3, 1, 0.3, 1)  -- Green
    elseif hpPercent > 0.2 then
        love.graphics.setColor(1, 0.7, 0.2, 1)  -- Orange
    else
        love.graphics.setColor(1, 0.2, 0.2, 1)  -- Red
    end
    love.graphics.rectangle("fill", x, y, width * hpPercent, height)
    
    -- Border
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(math.floor(player.hp) .. " / " .. player.maxHp .. " HP", x, y + height/4, width, "center")
end

function drawLevelPanel(player, x, y, width, height)
    -- Panel background
    love.graphics.setColor(0.15, 0.15, 0.2, 1)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Panel border
    love.graphics.setColor(0.8, 0.6, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Level display
    love.graphics.setColor(1, 1, 0.3, 1)
    love.graphics.printf("LEVEL " .. player.level, x, y + 10, width, "center")
    
    -- XP bar
    local expPercent = player.exp / player.expToNext
    local barX = x + 20
    local barY = y + 40
    local barWidth = width - 40
    local barHeight = 20
    
    love.graphics.setColor(0.2, 0.2, 0.25, 1)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
    
    love.graphics.setColor(0.3, 0.8, 1, 1)
    love.graphics.rectangle("fill", barX, barY, barWidth * expPercent, barHeight)
    
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
    
    -- XP text
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.printf(math.floor(player.exp) .. " / " .. player.expToNext, x, barY + barHeight + 5, width, "center")
end

function drawAbilityBar(player, x, y, width, height)
    local abilities = {
        {key = "Q", name = "Shield", cooldown = player.shieldCooldown, maxCD = player.shieldMaxCooldown, color = {0.3, 0.5, 1}},
        {key = "E", name = "Blink", cooldown = player.blinkCooldown, maxCD = player.blinkMaxCooldown, color = {1, 0.5, 0.8}},
        {key = "Space", name = "Dash", cooldown = player.dashCooldown, maxCD = player.dashMaxCooldown, color = {1, 1, 0.3}},
    }
    
    -- Panel background
    love.graphics.setColor(0.15, 0.15, 0.2, 1)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Panel border
    love.graphics.setColor(0.8, 0.8, 0.3, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Ability buttons
    local buttonSize = 60
    local spacing = 10
    
    for i, ab in ipairs(abilities) do
        local btnX = x + 20 + (i - 1) * (buttonSize + spacing)
        local btnY = y + 10
        
        -- Button background
        local ready = ab.cooldown <= 0
        if ready then
            love.graphics.setColor(ab.color[1], ab.color[2], ab.color[3], 0.8)
        else
            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        end
        love.graphics.rectangle("fill", btnX, btnY, buttonSize, buttonSize)
        
        -- Button border
        love.graphics.setColor(ab.color[1], ab.color[2], ab.color[3], 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", btnX, btnY, buttonSize, buttonSize)
        
        -- Key label
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(ab.key, btnX, btnY + 5, buttonSize, "center")
        
        -- If on cooldown, show remaining time
        if not ready then
            love.graphics.setColor(1, 0.3, 0.3, 1)
            love.graphics.printf(string.format("%.1f", ab.cooldown), btnX, btnY + 25, buttonSize, "center")
        end
    end
end

function drawCooldownBar(key, name, cooldown, maxCD, x, y, width, height)
    local ready = cooldown <= 0
    local cdPercent = 1 - (cooldown / maxCD)
    if cdPercent < 0 then cdPercent = 0 end
    if cdPercent > 1 then cdPercent = 1 end
    
    -- Background
    love.graphics.setColor(0.15, 0.15, 0.2, 1)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Cooldown bar
    if ready then
        love.graphics.setColor(0.3, 1, 0.3, 1)
    else
        love.graphics.setColor(1, 0.5, 0.3, 1)
    end
    love.graphics.rectangle("fill", x, y, width * cdPercent, height)
    
    -- Border
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("[" .. key .. "] " .. name, x + 5, y + 2)
    
    if not ready then
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf(string.format("%.1fs", cooldown), x + width - 30, y + 2, 25, "right")
    end
end

-- ============================================
-- INFO OVERLAY
-- ============================================

function drawUIInfoOverlay()
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Panel selector at top
    love.graphics.setColor(0.2, 0.2, 0.25, 0.9)
    love.graphics.rectangle("fill", 0, 0, screenWidth, 50)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("UI SANDBOX - Select Panel:", 10, 15)
    
    local panelNames = {"[1] HUD", "[2] Inventory", "[3] Status", "[4] Colors", "[5] Custom"}
    for i, name in ipairs(panelNames) do
        local color = sandbox.selectedPanel == i and {1, 1, 0.3, 1} or {0.6, 0.6, 0.6, 1}
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        love.graphics.print(name, 250 + (i - 1) * 100, 15)
    end
    
    -- Controls at bottom
    love.graphics.setColor(0.2, 0.2, 0.25, 0.9)
    love.graphics.rectangle("fill", 0, screenHeight - 50, screenWidth, 50)
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("CONTROLS: ↑↓←→ Adjust  |  G: Grid  |  R: Reset  |  Q: Main Menu", 10, screenHeight - 35)
end

return UISandboxState
