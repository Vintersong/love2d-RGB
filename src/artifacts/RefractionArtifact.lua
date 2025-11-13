-- REFRACTION Artifact: Bending/redirecting/splitting projectile paths
-- Theme: Projectiles that curve, orbit, and gain power through unique trajectories

local RefractionArtifact = {}

-- RED REFRACTION: Spiral projectile with rotating arms
RefractionArtifact.RED = {
    name = "Crimson Refraction",
    effect = "spiral_projectile",
    
    getChance = function(level)
        return 0.18 + (level * 0.02)  -- 18-38% chance
    end,
    
    behavior = function(projectiles, level, targetX, targetY, player)
        local chance = RefractionArtifact.RED.getChance(level)
        
        if math.random() < chance then
            local baseAngle = math.atan(targetY - player.y, targetX - player.x)
            local armCount = 2 + math.floor(level / 10)  -- 2-5 arms
            
            -- Center projectile
            local center = {
                x = player.x,
                y = player.y,
                vx = math.cos(baseAngle) * 400,
                vy = math.sin(baseAngle) * 400,
                damage = projectiles[1].damage * 0.8,
                speed = 400,
                color = {1, 0.3, 0.3},
                size = 6,
                shape = "atom",
                type = "spiral_center",
                
                -- Spiral data
                spiralArms = {},
                spiralTime = 0,
                spiralRotationSpeed = 5.0
            }
            
            -- Create rotating arms
            for i = 1, armCount do
                local armAngle = (i / armCount) * math.pi * 2
                table.insert(center.spiralArms, {
                    angle = armAngle,
                    distance = 20,
                    damage = projectiles[1].damage * 0.6,
                    hitEnemies = {}
                })
            end
            
            -- Custom update function
            center.updateSpiral = function(self, dt)
                self.spiralTime = self.spiralTime + dt
                
                -- Rotate arms
                for _, arm in ipairs(self.spiralArms) do
                    arm.angle = arm.angle + self.spiralRotationSpeed * dt
                end
            end
            
            return {center}
        end
        
        return projectiles
    end
}

-- GREEN REFRACTION: Orbital satellites around seeking core
RefractionArtifact.GREEN = {
    name = "Verdant Refraction",
    effect = "orbital_satellites",
    
    getChance = function(level)
        return 0.20 + (level * 0.02)  -- 20-40% chance
    end,
    
    behavior = function(projectiles, level, targetX, targetY, player)
        local chance = RefractionArtifact.GREEN.getChance(level)
        
        if math.random() < chance then
            local baseAngle = math.atan(targetY - player.y, targetX - player.x)
            local satelliteCount = 2 + math.floor(level / 10)  -- 2-5 satellites
            
            -- Core projectile (seeking)
            local core = {
                x = player.x,
                y = player.y,
                vx = math.cos(baseAngle) * 350,
                vy = math.sin(baseAngle) * 350,
                damage = projectiles[1].damage,
                speed = 350,
                color = {0.3, 1, 0.3},
                size = 8,
                shape = "atom",
                type = "orbital_core",
                seeking = true,
                seekingStrength = 200,
                
                -- Orbital data
                satellites = {},
                orbitalTime = 0
            }
            
            -- Create satellites
            for i = 1, satelliteCount do
                local satAngle = (i / satelliteCount) * math.pi * 2
                table.insert(core.satellites, {
                    angle = satAngle,
                    radius = 15,
                    speed = 3.0,
                    damage = projectiles[1].damage * 0.5,
                    hitEnemies = {}
                })
            end
            
            -- Custom update function
            core.updateOrbital = function(self, dt, enemies)
                self.orbitalTime = self.orbitalTime + dt
                
                -- Update satellite positions
                for _, sat in ipairs(self.satellites) do
                    sat.angle = sat.angle + sat.speed * dt
                end
                
                -- Seeking behavior
                if self.seeking and enemies and #enemies > 0 then
                    local nearest = nil
                    local nearestDist = math.huge
                    
                    for _, enemy in ipairs(enemies) do
                        if not enemy.dead then
                            local dx = enemy.x - self.x
                            local dy = enemy.y - self.y
                            local dist = math.sqrt(dx * dx + dy * dy)
                            
                            if dist < nearestDist then
                                nearestDist = dist
                                nearest = enemy
                            end
                        end
                    end
                    
                    if nearest then
                        local dx = nearest.x - self.x
                        local dy = nearest.y - self.y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        
                        if dist > 0 then
                            -- Steer toward nearest enemy
                            local steerX = (dx / dist) * self.seekingStrength * dt
                            local steerY = (dy / dist) * self.seekingStrength * dt
                            
                            self.vx = self.vx + steerX
                            self.vy = self.vy + steerY
                            
                            -- Limit speed
                            local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
                            if speed > self.speed then
                                self.vx = (self.vx / speed) * self.speed
                                self.vy = (self.vy / speed) * self.speed
                            end
                        end
                    end
                end
            end
            
            return {core}
        end
        
        return projectiles
    end
}

-- BLUE REFRACTION: Accumulating damage projectile
RefractionArtifact.BLUE = {
    name = "Azure Refraction",
    effect = "accumulating_damage",
    
    getChance = function(level)
        return 0.15 + (level * 0.02)  -- 15-35% chance
    end,
    
    behavior = function(projectiles, level, targetX, targetY, player)
        local chance = RefractionArtifact.BLUE.getChance(level)
        
        if math.random() < chance then
            local baseAngle = math.atan(targetY - player.y, targetX - player.x)
            
            local proj = {
                x = player.x,
                y = player.y,
                vx = math.cos(baseAngle) * 400,
                vy = math.sin(baseAngle) * 400,
                damage = projectiles[1].damage,
                baseDamage = projectiles[1].damage,
                speed = 400,
                color = {0.3, 0.3, 1},
                size = 5,
                shape = "triangle",
                type = "accumulating",
                piercing = true,
                
                -- Accumulation data
                damageMultiplier = 1.0,
                damagePerHit = 0.10,  -- +10% per hit
                hitCount = 0,
                hitEnemies = {}
            }
            
            -- Custom hit function
            proj.onAccumulateHit = function(self, enemy)
                if not self.hitEnemies[enemy] then
                    self.hitCount = self.hitCount + 1
                    self.damageMultiplier = self.damageMultiplier + self.damagePerHit
                    self.damage = self.baseDamage * self.damageMultiplier
                    
                    -- Grow size
                    self.size = 5 + (self.hitCount * 0.5)
                    
                    -- Mark enemy as hit
                    self.hitEnemies[enemy] = true
                end
            end
            
            return {proj}
        end
        
        return projectiles
    end
}

-- YELLOW REFRACTION: Fast spinning orbital (RED + GREEN)
RefractionArtifact.YELLOW = {
    name = "Golden Refraction",
    effect = "fast_spinning_orbital",
    
    getChance = function(level)
        return 0.12 + (level * 0.02)  -- 12-32% chance
    end,
    
    behavior = function(projectiles, level, targetX, targetY, player)
        local chance = RefractionArtifact.YELLOW.getChance(level)
        
        if math.random() < chance then
            local baseAngle = math.atan(targetY - player.y, targetX - player.x)
            
            -- Combine spiral (RED) and orbital (GREEN)
            local proj = {
                x = player.x,
                y = player.y,
                vx = math.cos(baseAngle) * 450,
                vy = math.sin(baseAngle) * 450,
                damage = projectiles[1].damage * 0.9,
                speed = 450,
                color = {1, 1, 0.2},
                size = 7,
                shape = "atom",
                type = "yellow_spiral_orbital",
                
                -- Spiral arms (RED trait)
                spiralArms = {},
                spiralTime = 0,
                spiralRotationSpeed = 10.0,  -- 2x faster than RED
                
                -- Satellites (GREEN trait)
                satellites = {},
                orbitalTime = 0,
                seeking = true,
                seekingStrength = 250
            }
            
            -- Create spiral arms
            local armCount = 2 + math.floor(level / 15)
            for i = 1, armCount do
                local armAngle = (i / armCount) * math.pi * 2
                table.insert(proj.spiralArms, {
                    angle = armAngle,
                    distance = 22,
                    damage = projectiles[1].damage * 0.5,
                    hitEnemies = {}
                })
            end
            
            -- Create satellites
            local satCount = 2 + math.floor(level / 15)
            for i = 1, satCount do
                local satAngle = (i / satCount) * math.pi * 2
                table.insert(proj.satellites, {
                    angle = satAngle,
                    radius = 25,
                    speed = 6.0,  -- Faster orbit
                    damage = projectiles[1].damage * 0.4,
                    hitEnemies = {}
                })
            end
            
            -- Hybrid update function
            proj.updateYellowRefraction = function(self, dt, enemies)
                self.spiralTime = self.spiralTime + dt
                self.orbitalTime = self.orbitalTime + dt
                
                -- Rotate spiral arms
                for _, arm in ipairs(self.spiralArms) do
                    arm.angle = arm.angle + self.spiralRotationSpeed * dt
                end
                
                -- Rotate satellites
                for _, sat in ipairs(self.satellites) do
                    sat.angle = sat.angle + sat.speed * dt
                end
                
                -- Seeking (from GREEN)
                if self.seeking and enemies and #enemies > 0 then
                    local nearest = nil
                    local nearestDist = math.huge
                    
                    for _, enemy in ipairs(enemies) do
                        if not enemy.dead then
                            local dx = enemy.x - self.x
                            local dy = enemy.y - self.y
                            local dist = math.sqrt(dx * dx + dy * dy)
                            
                            if dist < nearestDist then
                                nearestDist = dist
                                nearest = enemy
                            end
                        end
                    end
                    
                    if nearest then
                        local dx = nearest.x - self.x
                        local dy = nearest.y - self.y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        
                        if dist > 0 then
                            local steerX = (dx / dist) * self.seekingStrength * dt
                            local steerY = (dy / dist) * self.seekingStrength * dt
                            
                            self.vx = self.vx + steerX
                            self.vy = self.vy + steerY
                            
                            local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
                            if speed > self.speed then
                                self.vx = (self.vx / speed) * self.speed
                                self.vy = (self.vy / speed) * self.speed
                            end
                        end
                    end
                end
            end
            
            return {proj}
        end
        
        return projectiles
    end
}

-- MAGENTA REFRACTION: Accumulating spiral arms (RED + BLUE)
RefractionArtifact.MAGENTA = {
    name = "Magenta Refraction",
    effect = "accumulating_spiral_arms",
    
    getChance = function(level)
        return 0.10 + (level * 0.02)  -- 10-30% chance
    end,
    
    behavior = function(projectiles, level, targetX, targetY, player)
        local chance = RefractionArtifact.MAGENTA.getChance(level)
        
        if math.random() < chance then
            local baseAngle = math.atan(targetY - player.y, targetX - player.x)
            
            -- Spiral where each arm accumulates damage independently
            local proj = {
                x = player.x,
                y = player.y,
                vx = math.cos(baseAngle) * 400,
                vy = math.sin(baseAngle) * 400,
                damage = projectiles[1].damage * 0.7,
                speed = 400,
                color = {1, 0.2, 0.8},
                size = 6,
                shape = "atom",
                type = "magenta_accumulating_spiral",
                
                spiralArms = {},
                spiralTime = 0,
                spiralRotationSpeed = 6.0
            }
            
            -- Create arms with individual damage tracking
            local armCount = 3 + math.floor(level / 10)
            for i = 1, armCount do
                local armAngle = (i / armCount) * math.pi * 2
                table.insert(proj.spiralArms, {
                    angle = armAngle,
                    distance = 20,
                    damage = projectiles[1].damage * 0.5,
                    baseDamage = projectiles[1].damage * 0.5,
                    damageMultiplier = 1.0,
                    hitCount = 0,
                    hitEnemies = {}
                })
            end
            
            -- Custom update
            proj.updateMagentaSpiral = function(self, dt)
                self.spiralTime = self.spiralTime + dt
                
                for _, arm in ipairs(self.spiralArms) do
                    arm.angle = arm.angle + self.spiralRotationSpeed * dt
                end
            end
            
            -- Arm hit function
            proj.onArmHit = function(self, armIndex, enemy)
                local arm = self.spiralArms[armIndex]
                if arm and not arm.hitEnemies[enemy] then
                    arm.hitCount = arm.hitCount + 1
                    arm.damageMultiplier = arm.damageMultiplier + 0.15
                    arm.damage = arm.baseDamage * arm.damageMultiplier
                    arm.hitEnemies[enemy] = true
                end
            end
            
            return {proj}
        end
        
        return projectiles
    end
}

-- CYAN REFRACTION: Synchronized power growth (GREEN + BLUE)
RefractionArtifact.CYAN = {
    name = "Cyan Refraction",
    effect = "synchronized_power_growth",
    
    getChance = function(level)
        return 0.14 + (level * 0.02)  -- 14-34% chance
    end,
    
    behavior = function(projectiles, level, targetX, targetY, player)
        local chance = RefractionArtifact.CYAN.getChance(level)
        
        if math.random() < chance then
            local baseAngle = math.atan(targetY - player.y, targetX - player.x)
            
            -- Orbital with shared damage multiplier
            local proj = {
                x = player.x,
                y = player.y,
                vx = math.cos(baseAngle) * 350,
                vy = math.sin(baseAngle) * 350,
                damage = projectiles[1].damage,
                baseDamage = projectiles[1].damage,
                speed = 350,
                color = {0.2, 0.9, 0.9},
                size = 7,
                shape = "atom",
                type = "cyan_synchronized",
                seeking = true,
                seekingStrength = 180,
                
                -- Shared power system
                sharedMultiplier = 1.0,
                totalHits = 0,
                
                satellites = {},
                orbitalTime = 0,
                hitEnemies = {}
            }
            
            -- Create satellites
            local satCount = 3 + math.floor(level / 10)
            for i = 1, satCount do
                local satAngle = (i / satCount) * math.pi * 2
                table.insert(proj.satellites, {
                    angle = satAngle,
                    radius = 18,
                    speed = 4.0,
                    baseDamage = projectiles[1].damage * 0.5,
                    hitEnemies = {}
                })
            end
            
            -- Update function
            proj.updateCyanOrbital = function(self, dt, enemies)
                self.orbitalTime = self.orbitalTime + dt
                
                -- Rotate satellites
                for _, sat in ipairs(self.satellites) do
                    sat.angle = sat.angle + sat.speed * dt
                    -- Apply shared multiplier
                    sat.damage = sat.baseDamage * self.sharedMultiplier
                end
                
                -- Apply shared multiplier to core
                self.damage = self.baseDamage * self.sharedMultiplier
                
                -- Seeking behavior
                if self.seeking and enemies and #enemies > 0 then
                    local nearest = nil
                    local nearestDist = math.huge
                    
                    for _, enemy in ipairs(enemies) do
                        if not enemy.dead then
                            local dx = enemy.x - self.x
                            local dy = enemy.y - self.y
                            local dist = math.sqrt(dx * dx + dy * dy)
                            
                            if dist < nearestDist then
                                nearestDist = dist
                                nearest = enemy
                            end
                        end
                    end
                    
                    if nearest then
                        local dx = nearest.x - self.x
                        local dy = nearest.y - self.y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        
                        if dist > 0 then
                            local steerX = (dx / dist) * self.seekingStrength * dt
                            local steerY = (dy / dist) * self.seekingStrength * dt
                            
                            self.vx = self.vx + steerX
                            self.vy = self.vy + steerY
                            
                            local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
                            if speed > self.speed then
                                self.vx = (self.vx / speed) * self.speed
                                self.vy = (self.vy / speed) * self.speed
                            end
                        end
                    end
                end
            end
            
            -- Shared hit function
            proj.onSynchronizedHit = function(self, enemy)
                if not self.hitEnemies[enemy] then
                    self.totalHits = self.totalHits + 1
                    self.sharedMultiplier = self.sharedMultiplier + 0.08
                    self.hitEnemies[enemy] = true
                end
            end
            
            -- Satellite hit applies slow (CYAN control)
            proj.onSatelliteHit = function(self, satIndex, enemy)
                if enemy.applySlow then
                    enemy:applySlow(0.3, 1.0)  -- 30% slow for 1s
                end
                
                -- Also triggers shared power growth
                self:onSynchronizedHit(enemy)
            end
            
            return {proj}
        end
        
        return projectiles
    end
}

return RefractionArtifact
