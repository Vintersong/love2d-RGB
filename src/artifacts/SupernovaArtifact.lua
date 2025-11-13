-- SUPERNOVA Artifact: Massive burst/screen-clear ultimate ability
-- Theme: Powerful cooldown-based ultimate attacks

local SupernovaArtifact = {}

-- RED SUPERNOVA: Massive damage explosion
SupernovaArtifact.RED = {
    name = "Crimson Supernova",
    effect = "damage_explosion",
    cooldown = 15.0,
    currentCooldown = 0,
    
    canActivate = function(self)
        return self.currentCooldown <= 0
    end,
    
    activate = function(self, player, enemies, level)
        if not self:canActivate() then return false end
        
        self.currentCooldown = self.cooldown
        
        local radius = 300 + (level * 20)
        local damage = 500 + (level * 50)
        local hitCount = 0
        
        for i = #enemies, 1, -1 do
            local enemy = enemies[i]
            if not enemy.dead then
                local dx = enemy.x - player.x
                local dy = enemy.y - player.y
                local dist = math.sqrt(dx * dx + dy * dy)
                
                if dist < radius then
                    -- Damage falloff
                    local falloff = 1.0 - (dist / radius)
                    local actualDamage = damage * falloff
                    
                    enemy.hp = enemy.hp - actualDamage
                    hitCount = hitCount + 1
                    
                    if enemy.hp <= 0 then
                        enemy.dead = true
                    end
                end
            end
        end
        
        return true, {
            type = "explosion",
            x = player.x,
            y = player.y,
            radius = radius,
            color = {1, 0.2, 0.2},
            duration = 0.5,
            shake = {intensity = 15, duration = 0.5},
            hitCount = hitCount
        }
    end,
    
    update = function(self, dt)
        if self.currentCooldown > 0 then
            self.currentCooldown = self.currentCooldown - dt
        end
    end
}

-- GREEN SUPERNOVA: Vampiric nova (life drain + healing)
SupernovaArtifact.GREEN = {
    name = "Verdant Supernova",
    effect = "vampiric_nova",
    cooldown = 20.0,
    currentCooldown = 0,
    
    canActivate = function(self)
        return self.currentCooldown <= 0
    end,
    
    activate = function(self, player, enemies, level)
        if not self:canActivate() then return false end
        
        self.currentCooldown = self.cooldown
        
        local radius = 250 + (level * 15)
        local damage = 300 + (level * 40)
        local healPercent = 0.5
        local totalDamage = 0
        
        for i = #enemies, 1, -1 do
            local enemy = enemies[i]
            if not enemy.dead then
                local dx = enemy.x - player.x
                local dy = enemy.y - player.y
                local dist = math.sqrt(dx * dx + dy * dy)
                
                if dist < radius then
                    local dealt = math.min(enemy.hp, damage)
                    enemy.hp = enemy.hp - dealt
                    totalDamage = totalDamage + dealt
                    
                    if enemy.hp <= 0 then
                        enemy.dead = true
                    end
                end
            end
        end
        
        -- Heal player
        local healAmount = totalDamage * healPercent
        player.hp = math.min(player.maxHp, player.hp + healAmount)
        
        return true, {
            type = "vampiric_nova",
            x = player.x,
            y = player.y,
            radius = radius,
            color = {0.2, 1, 0.2},
            duration = 0.6,
            heal = healAmount,
            totalDamage = totalDamage
        }
    end,
    
    update = function(self, dt)
        if self.currentCooldown > 0 then
            self.currentCooldown = self.currentCooldown - dt
        end
    end
}

-- BLUE SUPERNOVA: Time freeze
SupernovaArtifact.BLUE = {
    name = "Azure Supernova",
    effect = "time_freeze",
    cooldown = 25.0,
    currentCooldown = 0,
    
    canActivate = function(self)
        return self.currentCooldown <= 0
    end,
    
    activate = function(self, player, enemies, level)
        if not self:canActivate() then return false end
        
        self.currentCooldown = self.cooldown
        
        local radius = 400 + (level * 25)
        local freezeDuration = 3.0 + (level * 0.1)
        local bonusDamage = 1.5
        local frozenCount = 0
        
        for i = #enemies, 1, -1 do
            local enemy = enemies[i]
            if not enemy.dead then
                local dx = enemy.x - player.x
                local dy = enemy.y - player.y
                local dist = math.sqrt(dx * dx + dy * dy)
                
                if dist < radius then
                    -- Freeze enemy
                    enemy.frozen = true
                    enemy.frozenTimer = freezeDuration
                    enemy.frozenDamageMultiplier = bonusDamage
                    enemy.originalSpeed = enemy.speed
                    enemy.speed = 0
                    
                    frozenCount = frozenCount + 1
                end
            end
        end
        
        return true, {
            type = "time_freeze",
            x = player.x,
            y = player.y,
            radius = radius,
            color = {0.2, 0.2, 1},
            duration = 0.8,
            frozenCount = frozenCount,
            freezeDuration = freezeDuration
        }
    end,
    
    update = function(self, dt)
        if self.currentCooldown > 0 then
            self.currentCooldown = self.currentCooldown - dt
        end
    end
}

-- YELLOW SUPERNOVA: Shield burst (RED + GREEN)
SupernovaArtifact.YELLOW = {
    name = "Golden Supernova",
    effect = "shield_burst",
    cooldown = 18.0,
    currentCooldown = 0,
    
    canActivate = function(self)
        return self.currentCooldown <= 0
    end,
    
    activate = function(self, player, enemies, level)
        if not self:canActivate() then return false end
        
        self.currentCooldown = self.cooldown
        
        local radius = 300 + (level * 18)
        local damage = 400 + (level * 45)
        local totalDamage = 0
        
        for i = #enemies, 1, -1 do
            local enemy = enemies[i]
            if not enemy.dead then
                local dx = enemy.x - player.x
                local dy = enemy.y - player.y
                local dist = math.sqrt(dx * dx + dy * dy)
                
                if dist < radius then
                    local dealt = math.min(enemy.hp, damage)
                    enemy.hp = enemy.hp - dealt
                    totalDamage = totalDamage + dealt
                    
                    if enemy.hp <= 0 then
                        enemy.dead = true
                    end
                end
            end
        end
        
        -- Grant shield (50% of damage dealt)
        local shieldAmount = totalDamage * 0.5
        player.shield = (player.shield or 0) + shieldAmount
        player.shieldTimer = 10.0  -- Lasts 10 seconds
        
        return true, {
            type = "shield_burst",
            x = player.x,
            y = player.y,
            radius = radius,
            color = {1, 1, 0.2},
            duration = 0.5,
            shake = {intensity = 12, duration = 0.4},
            shield = shieldAmount,
            totalDamage = totalDamage
        }
    end,
    
    update = function(self, dt)
        if self.currentCooldown > 0 then
            self.currentCooldown = self.currentCooldown - dt
        end
    end
}

-- MAGENTA SUPERNOVA: Temporal rewind (RED + BLUE)
SupernovaArtifact.MAGENTA = {
    name = "Magenta Supernova",
    effect = "temporal_rewind",
    cooldown = 30.0,
    currentCooldown = 0,
    
    canActivate = function(self)
        return self.currentCooldown <= 0
    end,
    
    activate = function(self, player, enemies, level)
        if not self:canActivate() then return false end
        
        self.currentCooldown = self.cooldown
        
        local radius = 350 + (level * 20)
        local damage = 600 + (level * 60)
        local rewindTime = 2.0  -- 2 seconds
        local affectedCount = 0
        
        for i = #enemies, 1, -1 do
            local enemy = enemies[i]
            if not enemy.dead then
                local dx = enemy.x - player.x
                local dy = enemy.y - player.y
                local dist = math.sqrt(dx * dx + dy * dy)
                
                if dist < radius then
                    -- Rewind position (if history exists)
                    if enemy.positionHistory and #enemy.positionHistory > 0 then
                        local rewindIndex = math.max(1, #enemy.positionHistory - math.floor(rewindTime * 60))
                        local rewindPos = enemy.positionHistory[rewindIndex]
                        
                        if rewindPos then
                            enemy.x = rewindPos.x
                            enemy.y = rewindPos.y
                        end
                    end
                    
                    -- Deal damage
                    enemy.hp = enemy.hp - damage
                    affectedCount = affectedCount + 1
                    
                    if enemy.hp <= 0 then
                        enemy.dead = true
                    end
                end
            end
        end
        
        return true, {
            type = "temporal_rewind",
            x = player.x,
            y = player.y,
            radius = radius,
            color = {1, 0.2, 0.8},
            duration = 0.7,
            shake = {intensity = 10, duration = 0.3},
            affectedCount = affectedCount
        }
    end,
    
    update = function(self, dt)
        if self.currentCooldown > 0 then
            self.currentCooldown = self.currentCooldown - dt
        end
    end
}

-- CYAN SUPERNOVA: Glacial field (GREEN + BLUE)
SupernovaArtifact.CYAN = {
    name = "Cyan Supernova",
    effect = "glacial_field",
    cooldown = 22.0,
    currentCooldown = 0,
    
    canActivate = function(self)
        return self.currentCooldown <= 0
    end,
    
    activate = function(self, player, enemies, level)
        if not self:canActivate() then return false end
        
        self.currentCooldown = self.cooldown
        
        local radius = 280 + (level * 18)
        local fieldDuration = 5.0 + (level * 0.2)
        local drainRate = 50 + (level * 5)
        
        -- Create persistent ice field
        local field = {
            x = player.x,
            y = player.y,
            radius = radius,
            lifetime = fieldDuration,
            drainRate = drainRate,
            active = true
        }
        
        -- Field update function (to be called from main loop)
        field.update = function(self, dt, player, enemies)
            if not self.active then return false end
            
            self.lifetime = self.lifetime - dt
            
            if self.lifetime <= 0 then
                self.active = false
                return false
            end
            
            for i = #enemies, 1, -1 do
                local enemy = enemies[i]
                if not enemy.dead then
                    local dx = enemy.x - self.x
                    local dy = enemy.y - self.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    
                    if dist < self.radius then
                        -- Freeze enemy
                        enemy.frozen = true
                        enemy.frozenTimer = dt * 2
                        if enemy.originalSpeed then
                            enemy.speed = 0
                        end
                        
                        -- Drain HP
                        local drained = math.min(enemy.hp, self.drainRate * dt)
                        enemy.hp = enemy.hp - drained
                        
                        -- Heal player (40% of drained)
                        player.hp = math.min(player.maxHp, player.hp + drained * 0.4)
                        
                        if enemy.hp <= 0 then
                            enemy.dead = true
                        end
                    end
                end
            end
            
            return true  -- Field still active
        end
        
        return true, {
            type = "glacial_field",
            field = field,
            x = player.x,
            y = player.y,
            radius = radius,
            color = {0.2, 0.9, 0.9},
            duration = fieldDuration
        }
    end,
    
    update = function(self, dt)
        if self.currentCooldown > 0 then
            self.currentCooldown = self.currentCooldown - dt
        end
    end
}

return SupernovaArtifact
