local class = require("libs.hump-master.class")
local Entity = require("src.entities.Entity")
local Boss = class{__includes = Entity}

function Boss:init(x, y)
    local SCREEN_WIDTH = 1920
    local SCREEN_HEIGHT = 1080
    self.x = x or SCREEN_WIDTH / 2 - 50
    self.y = y or -100
    self.width = 100
    self.height = 100
    self.enemyType = "boss"
    self.dead = false
    self.age = 0
    
    -- Boss properties
    self.speed = 30  -- Slow movement speed
    self.hp = 9999  -- Invincible
    self.maxHp = 9999
    self.damage = 25  -- Lower damage (not instant kill)
    self.expReward = 0
    self.color = {1, 0, 0}  -- Bright red
    self.shape = "boss"
    
    -- Boss behavior
    self.hasReachedCenter = false
    self.targetY = SCREEN_HEIGHT / 2 - 50
end

function Boss:update(dt, playerX, playerY)
    if self.dead then return end
    
    self.age = self.age + dt
    
    -- Descend to center of screen
    if not self.hasReachedCenter then
        if self.y < self.targetY then
            self.y = self.y + self.speed * dt
        else
            self.hasReachedCenter = true
        end
    else
        -- Track the player slowly
        local dx = playerX - (self.x + self.width / 2)
        local dy = playerY - (self.y + self.height / 2)
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance > 10 then  -- Don't jitter when very close
            dx = dx / distance
            dy = dy / distance
            
            self.x = self.x + dx * self.speed * dt
            self.y = self.y + dy * self.speed * dt
        end
    end
end

function Boss:draw()
    if self.dead then return end
    
    love.graphics.push()
    love.graphics.translate(self.x + self.width/2, self.y + self.height/2)
    
    -- Rotate slowly
    love.graphics.rotate(self.age * 0.5)
    
    -- Draw massive skull-like boss
    love.graphics.setColor(self.color)
    
    -- Main body (large square)
    love.graphics.rectangle("fill", -self.width/2, -self.height/2, self.width, self.height)
    
    -- Eyes (menacing)
    love.graphics.setColor(1, 1, 0)  -- Yellow eyes
    love.graphics.circle("fill", -20, -15, 8)
    love.graphics.circle("fill", 20, -15, 8)
    
    -- Pupils (following player would be cool but keeping simple)
    love.graphics.setColor(0, 0, 0)
    love.graphics.circle("fill", -20, -15, 4)
    love.graphics.circle("fill", 20, -15, 4)
    
    -- Mouth (ominous grin)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", -30, 10, 60, 8)
    love.graphics.rectangle("fill", -30, 10, 8, 20)
    love.graphics.rectangle("fill", -10, 10, 8, 20)
    love.graphics.rectangle("fill", 10, 10, 8, 20)
    love.graphics.rectangle("fill", 22, 10, 8, 20)
    
    -- Horns
    love.graphics.setColor(self.color[1] * 0.7, 0, 0)
    love.graphics.polygon("fill", 
        -self.width/2, -self.height/2,
        -self.width/2 - 20, -self.height/2 - 30,
        -self.width/2 + 10, -self.height/2
    )
    love.graphics.polygon("fill", 
        self.width/2, -self.height/2,
        self.width/2 + 20, -self.height/2 - 30,
        self.width/2 - 10, -self.height/2
    )
    
    love.graphics.pop()
    
    -- Debug collision circle
    love.graphics.setColor(1, 0, 0, 0.5)
    love.graphics.circle("line", self.x + self.width/2, self.y + self.height/2, self.width/2)
    
    -- Boss name and HP bar
    love.graphics.setColor(1, 0, 0)
    love.graphics.print("FINAL BOSS", self.x - 10, self.y - 30)
    
    -- Draw boss HP bar
    local barWidth = self.width
    local barHeight = 8
    local hpPercent = self.hp / self.maxHp
    
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", self.x, self.y - 20, barWidth, barHeight)
    
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", self.x, self.y - 20, barWidth * hpPercent, barHeight)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", self.x, self.y - 20, barWidth, barHeight)
    love.graphics.print(string.format("%d/%d", math.floor(self.hp), self.maxHp), self.x + 5, self.y - 18, 0, 0.6, 0.6)
end

function Boss:takeDamage(amount)
    if self.dead then return 0 end
    
    self.hp = self.hp - amount
    if self.hp <= 0 then
        self.hp = 0
        self.dead = true
        return 1000  -- Huge XP reward for killing boss
    end
    return 0
end

function Boss:checkCollision(projectile)
    if self.dead then return false end
    
    -- Simple AABB collision
    return projectile.x > self.x and
           projectile.x < self.x + self.width and
           projectile.y > self.y and
           projectile.y < self.y + self.height
end

-- Check if boss touches player (instant kill)
function Boss:checkPlayerCollision(player)
    if self.dead or not self.hasReachedCenter then return false end
    
    local centerX = self.x + self.width / 2
    local centerY = self.y + self.height / 2
    local playerCenterX = player.x + player.width / 2
    local playerCenterY = player.y + player.height / 2
    
    local dx = centerX - playerCenterX
    local dy = centerY - playerCenterY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Boss has large collision radius
    return distance < (self.width / 2 + player.width / 2)
end

return Boss
