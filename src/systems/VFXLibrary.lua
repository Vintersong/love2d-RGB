-- VFX Library - Centralized visual effects for artifact abilities
-- Easy to tweak particle effects, colors, and behavior

local ShapeLibrary = require("src.systems.ShapeLibrary")

local VFXLibrary = {}

-- Active particle systems
VFXLibrary.activeEffects = {}

-- Impact burst particles (from VFXManager)
VFXLibrary.impactParticles = {}

-- Formation spawn effects
VFXLibrary.formationFlashes = {}  -- Flash effects when formations spawn
VFXLibrary.formationWarnings = {}  -- Warning indicators before spawn

-- ============================================================================
-- ARTIFACT EFFECT DEFINITIONS
-- ============================================================================

VFXLibrary.ArtifactEffects = {
    -- PRISM: Rainbow light refraction
    PRISM = {
        color = {1, 0.2, 1},  -- Magenta base
        particleCount = 3,
        lifetime = 0.8,
        speed = 150,
        spread = math.pi * 2,  -- Full circle
        size = {start = 6, finish = 2},
        alpha = {start = 1, finish = 0},
        rainbow = true,  -- Cycle through colors
        trail = true
    },
    
    -- HALO: Golden protective shield aura
    HALO = {
        color = {1, 1, 0.3},  -- Gold
        particleCount = 5,
        lifetime = 1.2,
        speed = 80,
        spread = math.pi * 2,
        size = {start = 8, finish = 12},
        alpha = {start = 0.8, finish = 0},
        pulse = true,  -- Pulsing effect
        orbital = true  -- Orbit around player
    },
    
    -- MIRROR: Silver reflective shimmer
    MIRROR = {
        color = {0.7, 0.9, 1},  -- Silver
        particleCount = 4,
        lifetime = 0.6,
        speed = 120,
        spread = math.pi / 2,  -- 90 degrees
        size = {start = 5, finish = 1},
        alpha = {start = 1, finish = 0},
        reflect = true,  -- Mirror bounce effect
        shimmer = true
    },
    
    -- LENS: Focused blue beam particles
    LENS = {
        color = {0.3, 0.8, 1},  -- Bright blue
        particleCount = 2,
        lifetime = 0.5,
        speed = 200,
        spread = math.pi / 12,  -- Narrow beam
        size = {start = 4, finish = 8},
        alpha = {start = 1, finish = 0},
        focused = true,  -- Converging beam
        glow = true
    },
    
    -- AURORA: Cyan healing waves
    AURORA = {
        color = {0.4, 1, 0.8},  -- Cyan
        particleCount = 6,
        lifetime = 1.5,
        speed = 50,
        spread = math.pi * 2,
        size = {start = 10, finish = 3},
        alpha = {start = 0.7, finish = 0},
        wave = true,  -- Wavy motion
        heal = true,  -- Green tint
        drift = true  -- Slow upward drift
    },
    
    -- DIFFRACTION: Orange XP magnet rays
    DIFFRACTION = {
        color = {1, 0.5, 0.2},  -- Orange
        particleCount = 8,
        lifetime = 0.4,
        speed = 300,
        spread = math.pi * 2,
        size = {start = 3, finish = 1},
        alpha = {start = 1, finish = 0},
        magnet = true,  -- Pull toward center
        sparkle = true
    },
    
    -- REFRACTION: Purple speed boost trails
    REFRACTION = {
        color = {0.5, 0.3, 1},  -- Purple
        particleCount = 4,
        lifetime = 0.8,
        speed = 250,
        spread = math.pi / 3,
        size = {start = 7, finish = 2},
        alpha = {start = 1, finish = 0},
        trail = true,
        speed_lines = true
    },
    
    -- SUPERNOVA: Red explosive burst
    SUPERNOVA = {
        color = {1, 0.3, 0.2},  -- Red
        particleCount = 20,
        lifetime = 1.0,
        speed = 400,
        spread = math.pi * 2,
        size = {start = 12, finish = 4},
        alpha = {start = 1, finish = 0},
        explosion = true,
        shockwave = true,
        screen_shake = true
    },
    
    -- DASH: Neutral dash effect (no color-specific VFX)
    DASH = {
        color = {0.8, 0.8, 0.8},  -- Gray/white (neutral)
        particleCount = 5,
        lifetime = 0.3,
        speed = 100,
        spread = math.pi / 4,  -- 45 degree cone
        size = {start = 4, finish = 1},
        alpha = {start = 0.6, finish = 0},
        trail = true
    }
}

-- ============================================================================
-- SYNERGY EFFECT DEFINITIONS
-- ============================================================================

VFXLibrary.SynergyEffects = {
    -- Example synergies with distinct visual styles
    RAINBOW_CASCADE = {
        color = {1, 0, 0},  -- Will cycle through rainbow
        particleCount = 10,
        lifetime = 1.5,
        speed = 180,
        spread = math.pi * 2,
        size = {start = 5, finish = 2},
        alpha = {start = 1, finish = 0},
        rainbow = true,
        cascade = true
    },
    
    LASER_FOCUS = {
        color = {0, 0.5, 1},
        particleCount = 15,
        lifetime = 0.3,
        speed = 500,
        spread = math.pi / 24,  -- Very narrow
        size = {start = 2, finish = 6},
        alpha = {start = 1, finish = 0},
        laser = true
    },
    
    KALEIDOSCOPE = {
        color = {0.8, 0.8, 1},
        particleCount = 12,
        lifetime = 1.0,
        speed = 150,
        spread = math.pi * 2,
        size = {start = 8, finish = 3},
        alpha = {start = 0.9, finish = 0},
        geometric = true,
        rotate = true
    }
}

-- ============================================================================
-- PARTICLE SYSTEM
-- ============================================================================

-- Spawn artifact effect
function VFXLibrary.spawnArtifactEffect(artifactType, x, y, targetX, targetY)
    local effectDef = VFXLibrary.ArtifactEffects[artifactType]
    if not effectDef then return end
    
    local baseAngle = 0
    if targetX and targetY then
        baseAngle = math.atan(targetY - y, targetX - x)
    end
    
    for i = 1, effectDef.particleCount do
        local angle = baseAngle + (math.random() - 0.5) * effectDef.spread
        
        local particle = {
            x = x,
            y = y,
            vx = math.cos(angle) * effectDef.speed,
            vy = math.sin(angle) * effectDef.speed,
            lifetime = effectDef.lifetime,
            maxLifetime = effectDef.lifetime,
            size = effectDef.size.start,
            startSize = effectDef.size.start,
            endSize = effectDef.size.finish,
            alpha = effectDef.alpha.start,
            startAlpha = effectDef.alpha.start,
            endAlpha = effectDef.alpha.finish,
            color = {effectDef.color[1], effectDef.color[2], effectDef.color[3]},
            baseColor = {effectDef.color[1], effectDef.color[2], effectDef.color[3]},
            angle = angle,
            rotation = math.random() * math.pi * 2,
            rotationSpeed = (math.random() - 0.5) * 10,
            
            -- Special properties
            rainbow = effectDef.rainbow,
            pulse = effectDef.pulse,
            orbital = effectDef.orbital,
            wave = effectDef.wave,
            trail = effectDef.trail,
            focused = effectDef.focused,
            magnet = effectDef.magnet,
            explosion = effectDef.explosion,
            drift = effectDef.drift,
            
            orbitalAngle = (i / effectDef.particleCount) * math.pi * 2,
            orbitalRadius = 40,
            waveOffset = math.random() * math.pi * 2,
            
            effectType = artifactType
        }
        
        table.insert(VFXLibrary.activeEffects, particle)
    end
end

-- Spawn synergy effect
function VFXLibrary.spawnSynergyEffect(synergyName, x, y)
    local effectDef = VFXLibrary.SynergyEffects[synergyName]
    if not effectDef then return end
    
    for i = 1, effectDef.particleCount do
        local angle = (i / effectDef.particleCount) * math.pi * 2
        
        local particle = {
            x = x,
            y = y,
            vx = math.cos(angle) * effectDef.speed,
            vy = math.sin(angle) * effectDef.speed,
            lifetime = effectDef.lifetime,
            maxLifetime = effectDef.lifetime,
            size = effectDef.size.start,
            startSize = effectDef.size.start,
            endSize = effectDef.size.finish,
            alpha = effectDef.alpha.start,
            startAlpha = effectDef.alpha.start,
            endAlpha = effectDef.alpha.finish,
            color = {effectDef.color[1], effectDef.color[2], effectDef.color[3]},
            rotation = angle,
            
            rainbow = effectDef.rainbow,
            laser = effectDef.laser,
            geometric = effectDef.geometric,
            
            effectType = "SYNERGY_" .. synergyName
        }
        
        table.insert(VFXLibrary.activeEffects, particle)
    end
end

-- Update all particles
function VFXLibrary.update(dt)
    -- Update formation effects
    VFXLibrary.updateFormationEffects(dt)
    
    for i = #VFXLibrary.activeEffects, 1, -1 do
        local particle = VFXLibrary.activeEffects[i]
        
        particle.lifetime = particle.lifetime - dt
        
        if particle.lifetime <= 0 then
            table.remove(VFXLibrary.activeEffects, i)
        else
            -- Calculate life progress (0 = just spawned, 1 = about to die)
            local lifeProgress = 1 - (particle.lifetime / particle.maxLifetime)
            
            -- Update position
            particle.x = particle.x + particle.vx * dt
            particle.y = particle.y + particle.vy * dt
            
            -- Apply special behaviors
            if particle.drift then
                particle.y = particle.y - 30 * dt  -- Slow upward drift
            end
            
            if particle.wave then
                particle.vx = particle.vx + math.sin(particle.waveOffset + lifeProgress * math.pi * 4) * 50 * dt
            end
            
            if particle.orbital then
                particle.orbitalAngle = particle.orbitalAngle + dt * 2
                particle.x = particle.x + math.cos(particle.orbitalAngle) * 2
                particle.y = particle.y + math.sin(particle.orbitalAngle) * 2
            end
            
            if particle.focused then
                -- Particles converge slightly
                local centerPull = 20 * dt
                particle.vx = particle.vx * 0.98
                particle.vy = particle.vy * 0.98
            end
            
            if particle.magnet then
                -- Particles curve inward
                local pullAngle = math.atan(-particle.y, -particle.x)
                particle.vx = particle.vx + math.cos(pullAngle) * 100 * dt
                particle.vy = particle.vy + math.sin(pullAngle) * 100 * dt
            end
            
            if particle.explosion then
                -- Add gravity to explosion particles
                particle.vy = particle.vy + 200 * dt
            end
            
            -- Update rotation
            particle.rotation = particle.rotation + particle.rotationSpeed * dt
            
            -- Interpolate size
            particle.size = particle.startSize + (particle.endSize - particle.startSize) * lifeProgress
            
            -- Interpolate alpha
            particle.alpha = particle.startAlpha + (particle.endAlpha - particle.startAlpha) * lifeProgress
            
            -- Rainbow effect
            if particle.rainbow then
                local hue = (lifeProgress + (particle.angle / (math.pi * 2))) % 1
                particle.color = VFXLibrary.hsvToRgb(hue, 1, 1)
            end
            
            -- Pulse effect
            if particle.pulse then
                local pulseScale = 1 + math.sin(lifeProgress * math.pi * 6) * 0.3
                particle.size = particle.size * pulseScale
            end
        end
    end
end

-- Draw all particles
function VFXLibrary.draw()
    -- Draw formation warning indicators first (behind everything)
    VFXLibrary.drawFormationEffects()
    
    for _, particle in ipairs(VFXLibrary.activeEffects) do
        love.graphics.push()
        love.graphics.translate(particle.x, particle.y)
        love.graphics.rotate(particle.rotation)
        
        -- Glow effect (outer ring)
        if particle.trail or particle.explosion then
            love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], particle.alpha * 0.3)
            love.graphics.circle("fill", 0, 0, particle.size * 1.8)
        end
        
        -- Main particle
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], particle.alpha)
        
        if particle.geometric then
            -- Draw hexagon
            local verts = {}
            for i = 0, 5 do
                local a = (i / 6) * math.pi * 2
                table.insert(verts, math.cos(a) * particle.size)
                table.insert(verts, math.sin(a) * particle.size)
            end
            love.graphics.polygon("fill", verts)
        elseif particle.laser then
            -- Draw elongated laser
            love.graphics.rectangle("fill", -particle.size * 0.5, -particle.size * 2, particle.size, particle.size * 4)
        else
            -- Default circle
            love.graphics.circle("fill", 0, 0, particle.size)
        end
        
        -- Bright core
        love.graphics.setColor(1, 1, 1, particle.alpha * 0.8)
        love.graphics.circle("fill", 0, 0, particle.size * 0.4)
        
        love.graphics.pop()
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Convert HSV to RGB
function VFXLibrary.hsvToRgb(h, s, v)
    local r, g, b
    
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    
    i = i % 6
    
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    
    return {r, g, b}
end

-- Clear all effects
function VFXLibrary.clear()
    VFXLibrary.activeEffects = {}
    VFXLibrary.impactParticles = {}
end

-- Get active effect count
function VFXLibrary.getCount()
    return #VFXLibrary.activeEffects
end

-- ============================================================================
-- IMPACT BURST EFFECTS (Consolidated from VFXManager)
-- ============================================================================

-- Spawn impact burst particles
function VFXLibrary.spawnImpactBurst(x, y, color, count)
    count = count or 8
    color = color or {1, 1, 1}
    
    for i = 1, count do
        local angle = (i / count) * math.pi * 2
        local speed = 100 + math.random() * 100
        
        table.insert(VFXLibrary.impactParticles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            color = color,
            life = 0.3 + math.random() * 0.2,
            maxLife = 0.5,
            size = 2 + math.random() * 2
        })
    end
end

-- Update impact burst particles
function VFXLibrary.updateImpactBursts(dt)
    for i = #VFXLibrary.impactParticles, 1, -1 do
        local p = VFXLibrary.impactParticles[i]
        
        -- Update position
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        
        -- Apply drag
        p.vx = p.vx * 0.95
        p.vy = p.vy * 0.95
        
        -- Update lifetime
        p.life = p.life - dt
        
        -- Remove dead particles
        if p.life <= 0 then
            table.remove(VFXLibrary.impactParticles, i)
        end
    end
end

-- Draw impact burst particles
function VFXLibrary.drawImpactBursts()
    for _, p in ipairs(VFXLibrary.impactParticles) do
        local alpha = p.life / p.maxLife
        local color = {p.color[1], p.color[2], p.color[3], alpha}
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        love.graphics.circle("fill", p.x, p.y, p.size)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- FORMATION SPAWN EFFECTS
-- ============================================================================

-- Spawn formation warning effect
function VFXLibrary.spawnFormationWarning(centerX, centerY, formationWidth, formationHeight, duration)
    duration = duration or 1.0
    
    table.insert(VFXLibrary.formationWarnings, {
        x = centerX,
        y = centerY,
        width = formationWidth,
        height = formationHeight,
        life = duration,
        maxLife = duration,
        pulsePhase = 0,
        flashIntensity = 0
    })
end

-- Spawn formation flash effect
function VFXLibrary.spawnFormationFlash(centerX, centerY, color, intensity)
    intensity = intensity or 1.0
    color = color or {1, 1, 1}
    
    table.insert(VFXLibrary.formationFlashes, {
        x = centerX,
        y = centerY,
        color = color,
        intensity = intensity,
        life = 0.3,
        maxLife = 0.3,
        radius = 20,
        maxRadius = 200
    })
end

-- Update formation effects
function VFXLibrary.updateFormationEffects(dt)
    -- Update warning indicators
    for i = #VFXLibrary.formationWarnings, 1, -1 do
        local w = VFXLibrary.formationWarnings[i]
        w.life = w.life - dt
        w.pulsePhase = w.pulsePhase + dt * 8  -- Pulse speed
        w.flashIntensity = math.sin(w.pulsePhase) * 0.5 + 0.5
        
        if w.life <= 0 then
            table.remove(VFXLibrary.formationWarnings, i)
        end
    end
    
    -- Update flash effects
    for i = #VFXLibrary.formationFlashes, 1, -1 do
        local f = VFXLibrary.formationFlashes[i]
        f.life = f.life - dt
        
        -- Expand radius
        local progress = 1 - (f.life / f.maxLife)
        f.radius = f.maxRadius * progress
        
        if f.life <= 0 then
            table.remove(VFXLibrary.formationFlashes, i)
        end
    end
end

-- Draw formation effects
function VFXLibrary.drawFormationEffects()
    -- Draw warning indicators (behind enemies)
    for _, w in ipairs(VFXLibrary.formationWarnings) do
        local alpha = w.life / w.maxLife
        local pulseAlpha = w.flashIntensity * alpha * 0.3
        
        -- Draw warning rectangle
        local x = w.x - w.width/2
        local y = w.y - w.height/2
        local color = {1, 0.3, 0.3, pulseAlpha}
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x, y, w.width, w.height)
        love.graphics.setLineWidth(1)
        
        -- Draw corner markers
        local cornerSize = 15
        love.graphics.setColor(1, 0.5, 0.3, alpha * 0.7)
        -- Top-left
        love.graphics.line(w.x - w.width/2, w.y - w.height/2, w.x - w.width/2 + cornerSize, w.y - w.height/2)
        love.graphics.line(w.x - w.width/2, w.y - w.height/2, w.x - w.width/2, w.y - w.height/2 + cornerSize)
        -- Top-right
        love.graphics.line(w.x + w.width/2, w.y - w.height/2, w.x + w.width/2 - cornerSize, w.y - w.height/2)
        love.graphics.line(w.x + w.width/2, w.y - w.height/2, w.x + w.width/2, w.y - w.height/2 + cornerSize)
        -- Bottom-left
        love.graphics.line(w.x - w.width/2, w.y + w.height/2, w.x - w.width/2 + cornerSize, w.y + w.height/2)
        love.graphics.line(w.x - w.width/2, w.y + w.height/2, w.x - w.width/2, w.y + w.height/2 - cornerSize)
        -- Bottom-right
        love.graphics.line(w.x + w.width/2, w.y + w.height/2, w.x + w.width/2 - cornerSize, w.y + w.height/2)
        love.graphics.line(w.x + w.width/2, w.y + w.height/2, w.x + w.width/2, w.y + w.height/2 - cornerSize)
    end
    
    -- Draw flash effects (in front of enemies)
    for _, f in ipairs(VFXLibrary.formationFlashes) do
        local alpha = f.life / f.maxLife
        
        -- Expanding ring
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], alpha * f.intensity)
        love.graphics.circle("line", f.x, f.y, f.radius, 32)
        
        -- Inner glow
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], alpha * f.intensity * 0.3)
        love.graphics.circle("fill", f.x, f.y, f.radius * 0.5)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return VFXLibrary
