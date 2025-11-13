-- DIFFRACTION Artifact: Spreading/splitting outward from source
-- Theme: Explosive bursts, cones, and radial patterns

local DiffractionArtifact = {}

-- RED DIFFRACTION: Lateral cone spread (left + right)
DiffractionArtifact.RED = {
    name = "Crimson Diffraction",
    effect = "lateral_cone_spread",
    
    getChance = function(level)
        return 0.20 + (level * 0.02)  -- 20-40% chance
    end,
    
    behavior = function(projectiles, level, targetX, targetY, player)
        local chance = DiffractionArtifact.RED.getChance(level)
        
        if math.random() < chance then
            local baseAngle = math.atan(targetY - player.y, targetX - player.x)
            local result = {}
            
            -- Main shot
            table.insert(result, projectiles[1])
            
            -- Projectiles per cone
            local conesPerSide = 1 + math.floor(level / 10)  -- 1-4 per side
            local coneSpread = math.pi / 6  -- 30 degrees
            
            -- Left cone
            for i = 1, conesPerSide do
                local spreadOffset = coneSpread * (i / conesPerSide)
                local angle = baseAngle - math.pi/4 - spreadOffset
                
                table.insert(result, {
                    x = player.x,
                    y = player.y,
                    vx = math.cos(angle) * 350,
                    vy = math.sin(angle) * 350,
                    damage = projectiles[1].damage * 0.7,
                    speed = 350,
                    color = {1, 0.3, 0.3},
                    size = 5,
                    shape = "circle",
                    type = "diffraction_cone"
                })
            end
            
            -- Right cone
            for i = 1, conesPerSide do
                local spreadOffset = coneSpread * (i / conesPerSide)
                local angle = baseAngle + math.pi/4 + spreadOffset
                
                table.insert(result, {
                    x = player.x,
                    y = player.y,
                    vx = math.cos(angle) * 350,
                    vy = math.sin(angle) * 350,
                    damage = projectiles[1].damage * 0.7,
                    speed = 350,
                    color = {1, 0.3, 0.3},
                    size = 5,
                    shape = "circle",
                    type = "diffraction_cone"
                })
            end
            
            return result
        end
        
        return projectiles
    end
}

-- GREEN DIFFRACTION: Orbital explosion (orbits then bursts)
DiffractionArtifact.GREEN = {
    name = "Verdant Diffraction",
    effect = "orbital_explosion",
    
    getChance = function(level)
        return 0.15 + (level * 0.02)  -- 15-35% chance
    end,
    
    behavior = function(projectiles, level, targetX, targetY, player)
        local chance = DiffractionArtifact.GREEN.getChance(level)
        
        if math.random() < chance then
            local proj = {
                x = player.x,
                y = player.y,
                vx = 0,
                vy = 0,
                damage = projectiles[1].damage * 0.8,
                speed = 0,
                color = {0.3, 1, 0.3},
                size = 8,
                shape = "circle",
                type = "orbital_bomb",
                
                -- Orbital data
                orbitAngle = 0,
                orbitRadius = 80,
                orbitSpeed = 2.0,
                lifetime = 3.0,
                explosionProjectiles = 12 + math.floor(level / 5),
                orbiting = true,
                playerX = player.x,
                playerY = player.y
            }
            
            -- Update function
            proj.updateOrbitalBomb = function(self, dt, playerX, playerY)
                if self.orbiting then
                    -- Track player position
                    self.playerX = playerX
                    self.playerY = playerY
                    
                    -- Orbit around player
                    self.orbitAngle = self.orbitAngle + self.orbitSpeed * dt
                    self.x = self.playerX + math.cos(self.orbitAngle) * self.orbitRadius
                    self.y = self.playerY + math.sin(self.orbitAngle) * self.orbitRadius
                    
                    -- Countdown
                    self.lifetime = self.lifetime - dt
                    
                    if self.lifetime <= 0 then
                        self.orbiting = false
                        self.exploding = true
                    end
                end
            end
            
            -- Explosion function (returns new projectiles)
            proj.explode = function(self)
                local explosionProjs = {}
                
                for i = 1, self.explosionProjectiles do
                    local angle = (i / self.explosionProjectiles) * math.pi * 2
                    
                    table.insert(explosionProjs, {
                        x = self.x,
                        y = self.y,
                        vx = math.cos(angle) * 400,
                        vy = math.sin(angle) * 400,
                        damage = self.damage * 0.5,
                        speed = 400,
                        color = {0.3, 1, 0.3},
                        size = 4,
                        shape = "circle",
                        type = "ring_burst"
                    })
                end
                
                return explosionProjs
            end
            
            return {proj}
        end
        
        return projectiles
    end
}

-- BLUE DIFFRACTION: Impact ring explosion
DiffractionArtifact.BLUE = {
    name = "Azure Diffraction",
    effect = "impact_ring_explosion",
    
    getChance = function(level)
        return 0.18 + (level * 0.02)  -- 18-38% chance
    end,
    
    behavior = function(projectiles, level, targetX, targetY, player)
        local chance = DiffractionArtifact.BLUE.getChance(level)
        
        if math.random() < chance then
            local baseAngle = math.atan(targetY - player.y, targetX - player.x)
            
            local proj = {
                x = player.x,
                y = player.y,
                vx = math.cos(baseAngle) * 400,
                vy = math.sin(baseAngle) * 400,
                damage = projectiles[1].damage,
                speed = 400,
                color = {0.3, 0.3, 1},
                size = 6,
                shape = "circle",
                type = "impact_bomb",
                
                ringProjectiles = 12 + math.floor(level / 5),
                hasExploded = false
            }
            
            -- On hit function (returns explosion projectiles)
            proj.onImpactExplode = function(self, impactX, impactY)
                if self.hasExploded then return {} end
                
                self.hasExploded = true
                local explosionProjs = {}
                
                for i = 1, self.ringProjectiles do
                    local angle = (i / self.ringProjectiles) * math.pi * 2
                    
                    table.insert(explosionProjs, {
                        x = impactX,
                        y = impactY,
                        vx = math.cos(angle) * 350,
                        vy = math.sin(angle) * 350,
                        damage = self.damage * 0.6,
                        speed = 350,
                        color = {0.3, 0.3, 1},
                        size = 4,
                        shape = "circle",
                        type = "ring_burst"
                    })
                end
                
                return explosionProjs
            end
            
            return {proj}
        end
        
        return projectiles
    end
}

-- YELLOW DIFFRACTION: Mobile cone sources (RED + GREEN)
DiffractionArtifact.YELLOW = {
    name = "Golden Diffraction",
    effect = "mobile_cone_sources",
    
    getChance = function(level)
        return 0.12 + (level * 0.02)  -- 12-32% chance
    end,
    
    behavior = function(projectiles, level, targetX, targetY, player)
        local chance = DiffractionArtifact.YELLOW.getChance(level)
        
        if math.random() < chance then
            local orbitalCount = 2 + math.floor(level / 15)
            local result = {}
            
            for i = 1, orbitalCount do
                local orbitAngle = (i / orbitalCount) * math.pi * 2
                
                local orbital = {
                    x = player.x,
                    y = player.y,
                    vx = 0,
                    vy = 0,
                    damage = projectiles[1].damage * 0.6,
                    speed = 0,
                    color = {1, 1, 0.2},
                    size = 7,
                    shape = "circle",
                    type = "cone_orbital",
                    
                    orbitAngle = orbitAngle,
                    orbitRadius = 100,
                    orbitSpeed = 3.0,  -- Fast orbit
                    orbiting = true,
                    
                    coneCooldown = 0,
                    coneRate = 0.5,  -- Fire every 0.5s
                    coneProjectiles = 3,
                    
                    playerX = player.x,
                    playerY = player.y
                }
                
                -- Update function
                orbital.updateConeOrbital = function(self, dt, playerX, playerY)
                    if self.orbiting then
                        self.playerX = playerX
                        self.playerY = playerY
                        
                        self.orbitAngle = self.orbitAngle + self.orbitSpeed * dt
                        self.x = self.playerX + math.cos(self.orbitAngle) * self.orbitRadius
                        self.y = self.playerY + math.sin(self.orbitAngle) * self.orbitRadius
                        
                        self.coneCooldown = self.coneCooldown - dt
                    end
                end
                
                -- Fire cone function
                orbital.fireCone = function(self)
                    if self.coneCooldown > 0 then return {} end
                    
                    self.coneCooldown = self.coneRate
                    local coneProjs = {}
                    
                    local baseAngle = self.orbitAngle + math.pi/2
                    local coneSpread = math.pi / 4
                    
                    for j = 1, self.coneProjectiles do
                        local angleOffset = coneSpread * ((j - 1) / (self.coneProjectiles - 1) - 0.5)
                        local angle = baseAngle + angleOffset
                        
                        table.insert(coneProjs, {
                            x = self.x,
                            y = self.y,
                            vx = math.cos(angle) * 380,
                            vy = math.sin(angle) * 380,
                            damage = self.damage * 0.5,
                            speed = 380,
                            color = {1, 1, 0.2},
                            size = 4,
                            shape = "circle",
                            type = "cone_burst"
                        })
                    end
                    
                    return coneProjs
                end
                
                table.insert(result, orbital)
            end
            
            return result
        end
        
        return projectiles
    end
}

-- MAGENTA DIFFRACTION: Compound explosions (RED + BLUE)
DiffractionArtifact.MAGENTA = {
    name = "Magenta Diffraction",
    effect = "compound_explosions",
    
    getChance = function(level)
        return 0.10 + (level * 0.02)  -- 10-30% chance
    end,
    
    behavior = function(projectiles, level, targetX, targetY, player)
        local chance = DiffractionArtifact.MAGENTA.getChance(level)
        
        if math.random() < chance then
            local baseAngle = math.atan(targetY - player.y, targetX - player.x)
            local result = {}
            
            local coneCount = 3 + math.floor(level / 10)
            local coneSpread = math.pi / 3
            
            for i = 1, coneCount do
                local angleOffset = coneSpread * ((i - 1) / (coneCount - 1) - 0.5)
                local angle = baseAngle + angleOffset
                
                local coneProj = {
                    x = player.x,
                    y = player.y,
                    vx = math.cos(angle) * 380,
                    vy = math.sin(angle) * 380,
                    damage = projectiles[1].damage * 0.8,
                    speed = 380,
                    color = {1, 0.2, 0.8},
                    size = 6,
                    shape = "circle",
                    type = "compound_bomb",
                    
                    ringProjectiles = 8 + math.floor(level / 5),
                    hasExploded = false
                }
                
                -- Each cone proj explodes into ring
                coneProj.onCompoundExplode = function(self, impactX, impactY)
                    if self.hasExploded then return {} end
                    
                    self.hasExploded = true
                    local explosionProjs = {}
                    
                    for j = 1, self.ringProjectiles do
                        local ringAngle = (j / self.ringProjectiles) * math.pi * 2
                        
                        table.insert(explosionProjs, {
                            x = impactX,
                            y = impactY,
                            vx = math.cos(ringAngle) * 320,
                            vy = math.sin(ringAngle) * 320,
                            damage = self.damage * 0.5,
                            speed = 320,
                            color = {1, 0.2, 0.8},
                            size = 4,
                            shape = "circle",
                            type = "compound_ring"
                        })
                    end
                    
                    return explosionProjs
                end
                
                table.insert(result, coneProj)
            end
            
            return result
        end
        
        return projectiles
    end
}

-- CYAN DIFFRACTION: Freeze burst (GREEN + BLUE)
DiffractionArtifact.CYAN = {
    name = "Cyan Diffraction",
    effect = "freeze_burst",
    
    getChance = function(level)
        return 0.14 + (level * 0.02)  -- 14-34% chance
    end,
    
    behavior = function(projectiles, level, targetX, targetY, player)
        local chance = DiffractionArtifact.CYAN.getChance(level)
        
        if math.random() < chance then
            local proj = {
                x = player.x,
                y = player.y,
                vx = 0,
                vy = 0,
                damage = projectiles[1].damage * 0.7,
                speed = 0,
                color = {0.2, 0.9, 0.9},
                size = 8,
                shape = "circle",
                type = "freeze_orbital",
                
                orbitAngle = 0,
                orbitRadius = 90,
                orbitSpeed = 2.5,
                lifetime = 3.0,
                explosionProjectiles = 24,  -- Large ring
                orbiting = true,
                
                freezeRadius = 50,
                
                playerX = player.x,
                playerY = player.y
            }
            
            -- Update function
            proj.updateFreezeOrbital = function(self, dt, playerX, playerY, enemies)
                if self.orbiting then
                    self.playerX = playerX
                    self.playerY = playerY
                    
                    self.orbitAngle = self.orbitAngle + self.orbitSpeed * dt
                    self.x = self.playerX + math.cos(self.orbitAngle) * self.orbitRadius
                    self.y = self.playerY + math.sin(self.orbitAngle) * self.orbitRadius
                    
                    -- Freeze nearby enemies
                    if enemies then
                        for _, enemy in ipairs(enemies) do
                            if not enemy.dead then
                                local dx = enemy.x - self.x
                                local dy = enemy.y - self.y
                                local dist = math.sqrt(dx * dx + dy * dy)
                                
                                if dist < self.freezeRadius and enemy.applySlow then
                                    enemy:applySlow(0.5, 0.5)  -- 50% slow
                                end
                            end
                        end
                    end
                    
                    self.lifetime = self.lifetime - dt
                    
                    if self.lifetime <= 0 then
                        self.orbiting = false
                        self.exploding = true
                    end
                end
            end
            
            -- Frozen ring explosion
            proj.explodeFrozen = function(self)
                local explosionProjs = {}
                
                for i = 1, self.explosionProjectiles do
                    local angle = (i / self.explosionProjectiles) * math.pi * 2
                    
                    table.insert(explosionProjs, {
                        x = self.x,
                        y = self.y,
                        vx = math.cos(angle) * 360,
                        vy = math.sin(angle) * 360,
                        damage = self.damage * 0.5,
                        speed = 360,
                        color = {0.2, 0.9, 0.9},
                        size = 4,
                        shape = "circle",
                        type = "frozen_burst",
                        freezing = true  -- These projectiles slow enemies
                    })
                end
                
                return explosionProjs
            end
            
            return {proj}
        end
        
        return projectiles
    end
}

return DiffractionArtifact
