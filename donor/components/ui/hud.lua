local HUD = {}
HUD.__index = HUD

function HUD:new(config)
    local self = setmetatable({}, HUD)
    self.config = config or {}
    self.playerStats = self.config.playerStats
    self.weaponManager = self.config.weaponManager
    self.colorSystem = self.config.colorSystem
    self.abilities = self.config.abilities
    self.enemyManager = self.config.enemyManager
    self.showCards = false
    self.cards = {}
    self.selectedCardIndex = nil
    return self
end

function HUD:spawnCards()
    if self.showCards then
        return
    end
    self.showCards = true
    love.mouse.setVisible(true)

    self.cards = {}
    if self.colorSystem then
        for _, choice in ipairs(self.colorSystem:getUpgradeChoices(3)) do
            local colorId = choice.colorId
            table.insert(self.cards, {
                name = choice.name,
                description = choice.description,
                path = choice.path,
                colorId = colorId,
                color = choice.color,
                apply = function()
                    self.colorSystem:applyUpgrade(colorId)
                end,
            })
        end
    end

    if #self.cards == 0 then
        table.insert(self.cards, {
            name = "Vitality",
            description = "+10 max health",
            path = "Fallback",
            color = {0.8, 0.2, 0.2},
            apply = function()
                self.playerStats.maxHealth = self.playerStats.maxHealth + 10
                self.playerStats.health = self.playerStats.maxHealth
            end,
        })
    end

    local width = 180
    local height = 220
    local spacing = 24
    local total = #self.cards * width + (#self.cards - 1) * spacing
    local startX = (love.graphics.getWidth() - total) * 0.5
    for i, card in ipairs(self.cards) do
        card.x = startX + (i - 1) * (width + spacing)
        card.y = 120
        card.w = width
        card.h = height
    end
end

function HUD:closeCards()
    self.showCards = false
    self.cards = {}
    self.selectedCardIndex = nil
    love.mouse.setVisible(false)
end

function HUD:mousepressed(x, y, button)
    if not self.showCards or button ~= 1 then
        return false
    end

    for i, card in ipairs(self.cards) do
        local inside = x >= card.x and x <= card.x + card.w and y >= card.y and y <= card.y + card.h
        if inside then
            self.selectedCardIndex = i
            card.apply()
            self:closeCards()
            return true
        end
    end
    return false
end

function HUD:drawBars()
    local ps = self.playerStats
    local healthRatio = ps.health / math.max(ps.maxHealth, 1)
    local energyRatio = ps.energy / math.max(ps.maxEnergy, 1)
    local xpRatio = ps.xp / math.max(ps.xpToNextLevel, 1)

    local function drawBar(x, y, w, h, ratio, color, label)
        love.graphics.setColor(0.16, 0.16, 0.2, 0.9)
        love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.rectangle("fill", x, y, w * math.max(0, math.min(1, ratio)), h, 6, 6)
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.rectangle("line", x, y, w, h, 6, 6)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(label, x + 8, y + 3)
    end

    drawBar(18, love.graphics.getHeight() - 72, 230, 20, healthRatio, {0.88, 0.28, 0.28}, "Health")
    drawBar(18, love.graphics.getHeight() - 46, 230, 20, energyRatio, {0.34, 0.88, 0.34}, "Energy")
    drawBar((love.graphics.getWidth() - 320) * 0.5, 18, 320, 20, xpRatio, {0.4, 0.6, 1.0}, "XP")
end

function HUD:drawCooldowns()
    if not self.abilities then
        return
    end

    local labels = {
        {id = "dash", key = "SPACE", name = "Dash"},
        {id = "blink", key = "E", name = "Blink"},
        {id = "shield", key = "Q", name = "Shield"},
    }
    local x = 18
    local y = love.graphics.getHeight() - 112
    for i, item in ipairs(labels) do
        local ratio = self.abilities:getCooldownRatio(item.id)
        local bx = x + (i - 1) * 112
        love.graphics.setColor(0.12, 0.12, 0.18, 0.9)
        love.graphics.rectangle("fill", bx, y, 98, 28, 5, 5)
        love.graphics.setColor(0.2, 0.9, 1.0, 0.85)
        love.graphics.rectangle("fill", bx, y, 98 * (1 - ratio), 28, 5, 5)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.rectangle("line", bx, y, 98, 28, 5, 5)
        love.graphics.printf(item.key, bx, y + 6, 98, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function HUD:drawColorBuild()
    if not self.colorSystem then
        return
    end

    local dominant = self.colorSystem:getDominantColor()
    local stats = self.colorSystem:getProjectileStats()
    local x = love.graphics.getWidth() - 340
    local y = 64
    love.graphics.setColor(0.04, 0.05, 0.09, 0.75)
    love.graphics.rectangle("fill", x, y, 318, 88, 6, 6)
    love.graphics.setColor(dominant.color[1], dominant.color[2], dominant.color[3], 1)
    love.graphics.rectangle("line", x, y, 318, 88, 6, 6)
    love.graphics.circle("fill", x + 22, y + 24, 9)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Dominant: " .. dominant.name, x + 40, y + 15)
    love.graphics.print(self.colorSystem:getSummary(), x + 14, y + 42)
    love.graphics.print(
        "DMG " .. stats.damage .. "  Shots " .. stats.bulletCount .. "  Pierce " .. stats.pierce,
        x + 14,
        y + 64
    )
end

function HUD:drawInfo()
    local ps = self.playerStats
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Level " .. ps.level .. " | Score " .. ps.score, 18, 18)
    if self.enemyManager then
        love.graphics.print("Kills " .. self.enemyManager.killCount .. "/100", 18, 38)
    end
    love.graphics.print("WASD move | Auto-fire nearest enemy", love.graphics.getWidth() - 340, 18)
    love.graphics.print("F1 HUD | F2 XP | F10 boss | TAB cards", love.graphics.getWidth() - 340, 38)
end

function HUD:drawCards()
    if not self.showCards then
        return
    end

    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Choose Color Upgrade", 0, 66, love.graphics.getWidth(), "center")

    for _, card in ipairs(self.cards) do
        love.graphics.setColor(card.color[1], card.color[2], card.color[3], 1)
        love.graphics.rectangle("fill", card.x, card.y, card.w, card.h, 10, 10)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.rectangle("line", card.x, card.y, card.w, card.h, 10, 10)
        love.graphics.printf(card.name, card.x + 10, card.y + 20, card.w - 20, "center")
        love.graphics.printf(card.path or "", card.x + 10, card.y + 58, card.w - 20, "center")
        love.graphics.printf(card.description, card.x + 10, card.y + 105, card.w - 20, "center")
    end
end

function HUD:draw()
    self:drawBars()
    self:drawCooldowns()
    self:drawInfo()
    self:drawColorBuild()
    self:drawCards()
end

return HUD
