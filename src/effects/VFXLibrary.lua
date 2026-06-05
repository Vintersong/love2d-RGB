-- VFX Library - Centralized visual effects for artifact abilities
-- Easy to tweak particle effects, colors, and behavior

local ShapeLibrary = require("src.render.ShapeLibrary")
local MathUtils = require("src.utils.MathUtils")

local VFXLibrary = {}

local function blendTowardsWhite(color, amount)
    return {
        color[1] + (1 - color[1]) * amount,
        color[2] + (1 - color[2]) * amount,
        color[3] + (1 - color[3]) * amount,
    }
end

local function buildPolygonVerts(sides, radius, rotation)
    local verts = {}
    rotation = rotation or 0
    for i = 0, sides - 1 do
        local angle = rotation + (i / sides) * math.pi * 2
        verts[#verts + 1] = math.cos(angle) * radius
        verts[#verts + 1] = math.sin(angle) * radius
    end
    return verts
end

local function drawVFXCore(color, alpha, size)
    local core = blendTowardsWhite(color, 0.65)
    love.graphics.setColor(core[1], core[2], core[3], alpha)
    love.graphics.circle("fill", 0, 0, size)
    love.graphics.setColor(1, 1, 1, alpha * 0.95)
    love.graphics.circle("fill", 0, 0, math.max(0.8, size * 0.45))
end

local function drawVFXOrb(particle)
    local color = particle.color
    local alpha = particle.alpha
    local size = particle.size

    love.graphics.setBlendMode("add")
    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.18)
    love.graphics.circle("fill", 0, 0, size * 1.9)
    love.graphics.setBlendMode("alpha")

    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.95)
    love.graphics.setLineWidth(1.4)
    love.graphics.circle("line", 0, 0, size)
    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.55)
    love.graphics.circle("line", 0, 0, size * 0.55)
    drawVFXCore(color, alpha * 0.95, math.max(1.1, size * 0.32))
end

local function drawVFXShard(particle)
    local color = particle.color
    local alpha = particle.alpha
    local size = particle.size
    local verts = buildPolygonVerts(8, size, math.pi / 8)
    local innerVerts = buildPolygonVerts(8, size * 0.45, math.pi / 8)

    love.graphics.setBlendMode("add")
    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.15)
    love.graphics.polygon("fill", verts)
    love.graphics.setBlendMode("alpha")

    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.95)
    love.graphics.setLineWidth(1.4)
    love.graphics.polygon("line", verts)
    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.5)
    love.graphics.polygon("line", innerVerts)
    drawVFXCore(color, alpha * 0.9, math.max(1.0, size * 0.22))
end

local function drawVFXBeam(particle)
    local color = particle.color
    local alpha = particle.alpha
    local size = particle.size

    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line",
        0, -size * 2,
        size * 0.45, -size * 0.35,
        size * 0.3, size * 2,
        -size * 0.3, size * 2,
        -size * 0.45, -size * 0.35
    )
    love.graphics.setBlendMode("add")
    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.25)
    love.graphics.ellipse("fill", 0, 0, size * 0.35, size * 1.6)
    love.graphics.setBlendMode("alpha")
    drawVFXCore(color, alpha * 0.9, math.max(0.9, size * 0.2))
end

local function drawDashTrailParticle(particle)
    local color = particle.color
    local alpha = particle.alpha
    local size = particle.size
    local length = particle.length or (size * 3.5)

    love.graphics.setBlendMode("add")
    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.18)
    love.graphics.rectangle("fill", -size * 0.8, -length * 0.5, size * 1.6, length)
    love.graphics.setBlendMode("alpha")

    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.9)
    love.graphics.setLineWidth(1.2)
    love.graphics.rectangle("line", -size * 0.55, -length * 0.5, size * 1.1, length)
    love.graphics.setColor(1, 1, 1, alpha * 0.85)
    love.graphics.line(0, -length * 0.5, 0, length * 0.5)
end

-- Active particle systems
VFXLibrary.activeEffects = {}

-- Impact burst particles (from VFXManager)
VFXLibrary.impactParticles = {}

-- Persistent battlefield effects created by artifact synergies.
VFXLibrary.groundEffects = {}

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

local ArtifactActivationCues = {
    PRISM = {
        color = {1, 0.25, 1},
        rings = {24, 42},
        spokes = 6,
        shardCount = 9,
        shape = "triangle",
    },
    LENS = {
        color = {0.25, 0.82, 1},
        rings = {18, 32},
        spokes = 4,
        shardCount = 6,
        shape = "beam",
        forwardBias = true,
    },
    MIRROR = {
        color = {0.72, 0.95, 1},
        rings = {22, 38},
        spokes = 8,
        shardCount = 8,
        shape = "mirror",
    },
    DIFFRACTION = {
        color = {1, 0.42, 0.18},
        rings = {20, 35, 52},
        spokes = 10,
        shardCount = 12,
        shape = "square",
    },
    REFRACTION = {
        color = {0.55, 0.36, 1},
        rings = {26, 46},
        spokes = 7,
        shardCount = 10,
        shape = "spiral",
        swirl = true,
    },
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
        baseAngle = MathUtils.angleBetween(x, y, targetX, targetY)
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

function VFXLibrary.spawnArtifactActivationBurst(artifactType, x, y)
    local cue = ArtifactActivationCues[artifactType]
    if not cue then
        VFXLibrary.spawnArtifactEffect(artifactType, x, y)
        return
    end

    local color = cue.color

    for i, radius in ipairs(cue.rings) do
        table.insert(VFXLibrary.impactParticles, {
            type    = "artifactRing",
            x       = x,
            y       = y,
            vx      = 0,
            vy      = 0,
            color   = {color[1], color[2], color[3]},
            life    = 1,
            maxLife = 0.28 + i * 0.08,
            size    = radius * 0.35,
            maxSize = radius,
            spokes  = cue.spokes,
            rotation = math.random() * math.pi * 2,
            rotationSpeed = cue.swirl and 3.4 or 1.4,
        })
    end

    local count = cue.shardCount or 8
    for i = 1, count do
        local angle = ((i - 1) / count) * math.pi * 2
        if cue.forwardBias then
            angle = angle * 0.42 - math.pi * 0.21
        end
        angle = angle + (math.random() - 0.5) * 0.16
        local speed = 90 + math.random() * 75

        table.insert(VFXLibrary.impactParticles, {
            type  = "artifactShard",
            x     = x + math.cos(angle) * 7,
            y     = y + math.sin(angle) * 7,
            vx    = math.cos(angle) * speed,
            vy    = math.sin(angle) * speed,
            color = {color[1], color[2], color[3]},
            life  = 1,
            maxLife = 0.22 + math.random() * 0.18,
            size  = 5 + math.random() * 3,
            rotation = angle,
            shape = cue.shape,
        })
    end

    VFXLibrary.spawnArtifactEffect(artifactType, x, y)
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
            angle = angle,
            rotation = angle,
            rotationSpeed = effectDef.rotate and ((math.random() - 0.5) * 8) or 0,
            
            rainbow = effectDef.rainbow,
            laser = effectDef.laser,
            geometric = effectDef.geometric,
            
            effectType = "SYNERGY_" .. synergyName
        }
        
        table.insert(VFXLibrary.activeEffects, particle)
    end
end

function VFXLibrary.spawnDashTrail(x, y, color, dirX, dirY)
    color = color or {1, 1, 1}
    dirX = dirX or 0
    dirY = dirY or -1

    local length = math.sqrt(dirX * dirX + dirY * dirY)
    if length <= 0 then
        dirX, dirY = 0, -1
    else
        dirX = dirX / length
        dirY = dirY / length
    end

    local angle = MathUtils.atan2(dirY, dirX) + math.pi * 0.5

    for i = 1, 2 do
        local lateral = (i == 1) and -6 or 6
        local offsetX = -dirX * 10 + (-dirY * lateral)
        local offsetY = -dirY * 10 + (dirX * lateral)
        table.insert(VFXLibrary.activeEffects, {
            x = x + offsetX,
            y = y + offsetY,
            vx = -dirX * (40 + i * 12),
            vy = -dirY * (40 + i * 12),
            lifetime = 0.18,
            maxLifetime = 0.18,
            size = 3.5,
            startSize = 3.5,
            endSize = 1.2,
            alpha = 0.75,
            startAlpha = 0.75,
            endAlpha = 0,
            color = {color[1], color[2], color[3]},
            baseColor = {color[1], color[2], color[3]},
            rotation = angle,
            rotationSpeed = 0,
            dashTrail = true,
            length = 18 + i * 4,
            effectType = "DASH_TRAIL"
        })
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
                local pullAngle = MathUtils.atan2(-particle.y, -particle.x)
                particle.vx = particle.vx + math.cos(pullAngle) * 100 * dt
                particle.vy = particle.vy + math.sin(pullAngle) * 100 * dt
            end
            
            if particle.explosion then
                -- Add gravity to explosion particles
                particle.vy = particle.vy + 200 * dt
            end
            
            -- Update rotation
            particle.rotation = (particle.rotation or 0) + (particle.rotationSpeed or 0) * dt
            
            -- Interpolate size
            particle.size = particle.startSize + (particle.endSize - particle.startSize) * lifeProgress
            
            -- Interpolate alpha
            particle.alpha = particle.startAlpha + (particle.endAlpha - particle.startAlpha) * lifeProgress
            
            -- Rainbow effect
            if particle.rainbow then
                local hue = (lifeProgress + ((particle.angle or 0) / (math.pi * 2))) % 1
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
        
        if particle.dashTrail then
            drawDashTrailParticle(particle)
        elseif particle.laser or particle.focused then
            drawVFXBeam(particle)
        elseif particle.geometric or particle.explosion or particle.trail then
            drawVFXShard(particle)
        else
            drawVFXOrb(particle)
        end
        
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
    VFXLibrary.groundEffects = {}
end

-- Get active effect count
function VFXLibrary.getCount()
    return #VFXLibrary.activeEffects
end

-- ============================================================================
-- PERSISTENT GROUND / ENEMY FIELD EFFECTS
-- ============================================================================

local GroundEffectDefs = {
    fire = {
        color = {1, 0.32, 0.08},
        radius = 48,
        duration = 1.6,
        dps = 0,
        shape = "flame",
    },
    frost = {
        color = {0.28, 0.92, 1},
        radius = 56,
        duration = 2.2,
        slow = 0.4,
        shape = "frost",
    },
    lightning = {
        color = {1, 0.92, 0.18},
        radius = 78,
        duration = 1.6,
        dps = 0,
        shape = "lightning",
    },
    poison = {
        color = {0.28, 1, 0.55},
        radius = 64,
        duration = 2.4,
        dps = 0,
        shape = "poison",
    },
    gravity = {
        color = {0.92, 0.45, 1},
        radius = 96,
        duration = 1.5,
        slow = 0.25,
        shape = "gravity",
    },
    temporal = {
        color = {1, 0.26, 1},
        radius = 82,
        duration = 1.2,
        slow = 0.25,
        shape = "temporal",
    },
    harvest = {
        color = {0.26, 1, 0.42},
        radius = 54,
        duration = 0.9,
        shape = "harvest",
    },
}

function VFXLibrary.spawnGroundEffect(kind, x, y, options)
    local def = GroundEffectDefs[kind] or GroundEffectDefs.temporal
    options = options or {}

    if #VFXLibrary.groundEffects > 120 then
        table.remove(VFXLibrary.groundEffects, 1)
    end

    local color = options.color or def.color or {1, 1, 1}
    local duration = options.duration or def.duration or 1.5
    table.insert(VFXLibrary.groundEffects, {
        kind = kind,
        x = x,
        y = y,
        radius = options.radius or def.radius or 60,
        duration = duration,
        maxDuration = duration,
        color = {color[1], color[2], color[3]},
        dps = options.dps or options.damagePerSecond or def.dps or 0,
        slow = options.slow or def.slow or 0,
        pull = options.pull or def.pull or 0,
        pulse = math.random() * math.pi * 2,
        shape = options.shape or def.shape or kind,
    })
end

function VFXLibrary.updateGroundEffects(dt, enemies, player, onKillCallback)
    local HealthSystem = nil

    for i = #VFXLibrary.groundEffects, 1, -1 do
        local effect = VFXLibrary.groundEffects[i]
        effect.duration = effect.duration - dt
        effect.pulse = (effect.pulse or 0) + dt * 5.5

        if effect.duration <= 0 then
            table.remove(VFXLibrary.groundEffects, i)
        else
            local radiusSq = effect.radius * effect.radius
            for _, enemy in ipairs(enemies or {}) do
                if not enemy.dead and not enemy.inactive then
                    local ex = enemy.x + enemy.width / 2
                    local ey = enemy.y + enemy.height / 2
                    local dx = ex - effect.x
                    local dy = ey - effect.y
                    local distSq = dx * dx + dy * dy

                    if distSq <= radiusSq then
                        if effect.slow and effect.slow > 0 then
                            enemy.speedMultiplier = math.min(enemy.speedMultiplier or 1, math.max(0.12, 1 - effect.slow))
                            enemy.slowedUntil = math.max(enemy.slowedUntil or 0, love.timer.getTime() + 0.18)
                        end

                        if effect.pull and effect.pull > 0 and distSq > 16 then
                            local dist = math.sqrt(distSq)
                            enemy.x = enemy.x - (dx / dist) * effect.pull * dt
                            enemy.y = enemy.y - (dy / dist) * effect.pull * dt
                        end

                        if effect.dps and effect.dps > 0 then
                            HealthSystem = HealthSystem or require("src.combat.HealthSystem")
                            local died = HealthSystem.takeDamage(enemy, effect.dps * dt)
                            if died and onKillCallback then
                                onKillCallback(enemy)
                            end
                        end
                    end
                end
            end
        end
    end
end

function VFXLibrary.drawGroundEffects()
    for _, effect in ipairs(VFXLibrary.groundEffects) do
        local c = effect.color
        local life = math.max(0, effect.duration / effect.maxDuration)
        local pulse = (math.sin(effect.pulse or 0) + 1) * 0.5
        local radius = effect.radius * (0.92 + pulse * 0.08)

        love.graphics.setBlendMode("add")
        love.graphics.setColor(c[1], c[2], c[3], 0.08 + life * 0.08)
        love.graphics.circle("fill", effect.x, effect.y, radius)
        love.graphics.setColor(c[1], c[2], c[3], life * 0.62)
        love.graphics.setLineWidth(1.4)
        love.graphics.circle("line", effect.x, effect.y, radius)
        love.graphics.setColor(c[1], c[2], c[3], life * 0.32)
        love.graphics.circle("line", effect.x, effect.y, radius * 0.62)

        if effect.shape == "frost" then
            love.graphics.setColor(1, 1, 1, life * 0.45)
            for s = 1, 6 do
                local angle = (s / 6) * math.pi * 2 + pulse * 0.5
                love.graphics.line(
                    effect.x + math.cos(angle) * radius * 0.22,
                    effect.y + math.sin(angle) * radius * 0.22,
                    effect.x + math.cos(angle) * radius * 0.88,
                    effect.y + math.sin(angle) * radius * 0.88
                )
            end
        elseif effect.shape == "lightning" then
            love.graphics.setColor(c[1], c[2], c[3], life * 0.72)
            for s = 1, 4 do
                local angle = (s / 4) * math.pi * 2 + pulse
                love.graphics.line(effect.x, effect.y, effect.x + math.cos(angle) * radius * 0.82, effect.y + math.sin(angle) * radius * 0.82)
            end
        elseif effect.shape == "gravity" or effect.shape == "temporal" then
            love.graphics.setColor(c[1], c[2], c[3], life * 0.55)
            love.graphics.arc("line", "open", effect.x, effect.y, radius * 0.72, effect.pulse, effect.pulse + math.pi * 1.35)
            love.graphics.arc("line", "open", effect.x, effect.y, radius * 0.38, -effect.pulse, -effect.pulse + math.pi * 1.2)
        else
            love.graphics.setColor(c[1], c[2], c[3], life * 0.45)
            love.graphics.rectangle("line", effect.x - radius * 0.45, effect.y - radius * 0.45, radius * 0.9, radius * 0.9)
        end

        love.graphics.setBlendMode("alpha")
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- IMPACT BURST EFFECTS (Consolidated from VFXManager)
-- ============================================================================

-- Spawn impact burst particles
function VFXLibrary.spawnImpactBurst(x, y, color, count)
    count = count or 9
    color = color or {1, 1, 1}

    -- Square sparks
    for i = 1, count do
        local angle = ((i - 1) / count) * math.pi * 2 + (math.random() - 0.5) * 0.3
        local speed = 70 + math.random() * 110

        table.insert(VFXLibrary.impactParticles, {
            type  = "spark",
            x     = x,
            y     = y,
            vx    = math.cos(angle) * speed,
            vy    = math.sin(angle) * speed,
            color = {color[1], color[2], color[3]},
            life  = 1,
            maxLife = 0.28 + math.random() * 0.27,
            size  = 2 + math.random() * 2,
            rotation = math.random() * math.pi * 2,
        })
    end

    -- Expanding ring
    table.insert(VFXLibrary.impactParticles, {
        type    = "ring",
        x       = x,
        y       = y,
        vx      = 0,
        vy      = 0,
        color   = {color[1], color[2], color[3]},
        life    = 1,
        maxLife = 0.35,
        size    = 0,
        maxSize = 28,
    })
end

function VFXLibrary.spawnEnemyDeathBurst(enemy)
    if not enemy then return end

    local x = enemy.x + (enemy.width or 0) / 2
    local y = enemy.y + (enemy.height or 0) / 2
    local color = enemy.overlayColor or enemy.projectileColor or enemy.baseColor or {1, 1, 1}
    local size = math.max(enemy.width or 18, enemy.height or 18)
    local count = math.random(8, 14)

    VFXLibrary.spawnImpactBurst(x, y, color, count)

    table.insert(VFXLibrary.impactParticles, {
        type    = "ring",
        x       = x,
        y       = y,
        vx      = 0,
        vy      = 0,
        color   = {color[1], color[2], color[3]},
        life    = 1,
        maxLife = 0.26,
        size    = 0,
        maxSize = size * 1.7,
    })
end

function VFXLibrary.spawnBossDeathBurst(boss, intensity)
    if not boss then return end

    intensity = intensity or 1
    local x = boss.x
    local y = boss.y
    local color = boss.bossColor or {1, 0.2, 0.8}
    local radius = (boss.size or 80) * intensity
    local sparkCount = math.floor(22 + intensity * 14)

    for i = 1, sparkCount do
        local angle = ((i - 1) / sparkCount) * math.pi * 2 + (math.random() - 0.5) * 0.16
        local speed = 120 + math.random() * 220 * intensity
        local shardSize = 3 + math.random() * 5 * intensity

        table.insert(VFXLibrary.impactParticles, {
            type  = "spark",
            x     = x + math.cos(angle) * radius * 0.12,
            y     = y + math.sin(angle) * radius * 0.12,
            vx    = math.cos(angle) * speed,
            vy    = math.sin(angle) * speed,
            color = {color[1], color[2], color[3]},
            life  = 1,
            maxLife = 0.42 + math.random() * 0.32,
            size  = shardSize,
            rotation = angle,
        })
    end

    for i = 1, 3 do
        table.insert(VFXLibrary.impactParticles, {
            type    = "ring",
            x       = x,
            y       = y,
            vx      = 0,
            vy      = 0,
            color   = {color[1], color[2], color[3]},
            life    = 1,
            maxLife = 0.36 + i * 0.08,
            size    = radius * 0.15 * i,
            maxSize = radius * (0.8 + i * 0.42),
        })
    end

    table.insert(VFXLibrary.impactParticles, {
        type    = "core",
        x       = x,
        y       = y,
        vx      = 0,
        vy      = 0,
        color   = {color[1], color[2], color[3]},
        life    = 1,
        maxLife = 0.28,
        size    = radius * 0.5,
        maxSize = radius * 1.3,
    })
end

-- Update impact burst particles
function VFXLibrary.updateImpactBursts(dt)
    for i = #VFXLibrary.impactParticles, 1, -1 do
        local p = VFXLibrary.impactParticles[i]

        p.x    = p.x + p.vx * dt
        p.y    = p.y + p.vy * dt
        p.life = p.life - dt / p.maxLife

        if p.life <= 0 then
            table.remove(VFXLibrary.impactParticles, i)
        elseif p.type == "spark" then
            p.vx = p.vx * 0.86
            p.vy = p.vy * 0.86
        elseif p.type == "ring" then
            p.size = p.maxSize * (1 - p.life)
        elseif p.type == "core" then
            p.size = p.maxSize * (1 - p.life)
        elseif p.type == "artifactRing" then
            p.size = p.maxSize * (1 - p.life)
            p.rotation = (p.rotation or 0) + (p.rotationSpeed or 0) * dt
        elseif p.type == "artifactShard" then
            p.vx = p.vx * 0.84
            p.vy = p.vy * 0.84
            p.rotation = (p.rotation or 0) + 7 * dt
        end
    end
end

-- Draw impact burst particles
function VFXLibrary.drawImpactBursts()
    for _, p in ipairs(VFXLibrary.impactParticles) do
        local c = p.color
        if p.type == "spark" then
            local sz = p.size * p.life
            love.graphics.push()
            love.graphics.translate(p.x, p.y)
            love.graphics.rotate((p.rotation or 0) + (1 - p.life) * 4)
            love.graphics.setBlendMode("add")
            love.graphics.setColor(c[1], c[2], c[3], p.life * 0.18)
            love.graphics.polygon("fill", buildPolygonVerts(4, sz * 1.4, math.pi / 4))
            love.graphics.setBlendMode("alpha")
            love.graphics.setColor(c[1], c[2], c[3], p.life)
            love.graphics.setLineWidth(1.3)
            love.graphics.polygon("line", buildPolygonVerts(4, sz, math.pi / 4))
            love.graphics.setColor(1, 1, 1, p.life * 0.9)
            love.graphics.circle("fill", 0, 0, math.max(0.7, sz * 0.3))
            love.graphics.pop()
        elseif p.type == "ring" then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(c[1], c[2], c[3], p.life * 0.85)
            love.graphics.setLineWidth(1.8 * p.life)
            love.graphics.circle("line", p.x, p.y, math.max(0.1, p.size))
            love.graphics.setBlendMode("alpha")
        elseif p.type == "core" then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(c[1], c[2], c[3], p.life * 0.28)
            love.graphics.circle("fill", p.x, p.y, math.max(0.1, p.size))
            love.graphics.setColor(1, 1, 1, p.life * 0.72)
            love.graphics.circle("fill", p.x, p.y, math.max(0.1, p.size * 0.24))
            love.graphics.setBlendMode("alpha")
        elseif p.type == "artifactRing" then
            local spokes = p.spokes or 6
            love.graphics.push()
            love.graphics.translate(p.x, p.y)
            love.graphics.rotate(p.rotation or 0)
            love.graphics.setBlendMode("add")
            love.graphics.setColor(c[1], c[2], c[3], p.life * 0.48)
            love.graphics.setLineWidth(1.4 * p.life)
            love.graphics.circle("line", 0, 0, math.max(0.1, p.size))
            for i = 1, spokes do
                local angle = (i / spokes) * math.pi * 2
                local inner = p.size * 0.48
                local outer = p.size * 0.94
                love.graphics.line(
                    math.cos(angle) * inner,
                    math.sin(angle) * inner,
                    math.cos(angle) * outer,
                    math.sin(angle) * outer
                )
            end
            love.graphics.setBlendMode("alpha")
            love.graphics.pop()
        elseif p.type == "artifactShard" then
            local sz = p.size * p.life
            love.graphics.push()
            love.graphics.translate(p.x, p.y)
            love.graphics.rotate(p.rotation or 0)
            love.graphics.setBlendMode("add")
            love.graphics.setColor(c[1], c[2], c[3], p.life * 0.18)
            if p.shape == "beam" then
                love.graphics.rectangle("fill", -sz * 0.28, -sz * 1.9, sz * 0.56, sz * 3.8)
            elseif p.shape == "triangle" then
                love.graphics.polygon("fill", 0, -sz * 1.7, sz * 1.1, sz * 0.8, -sz * 1.1, sz * 0.8)
            elseif p.shape == "mirror" then
                love.graphics.rectangle("fill", -sz * 0.9, -sz * 1.2, sz * 1.8, sz * 2.4)
            else
                love.graphics.polygon("fill", buildPolygonVerts(4, sz * 1.4, math.pi / 4))
            end
            love.graphics.setBlendMode("alpha")
            love.graphics.setColor(c[1], c[2], c[3], p.life)
            love.graphics.setLineWidth(1.2)
            if p.shape == "beam" then
                love.graphics.rectangle("line", -sz * 0.22, -sz * 1.55, sz * 0.44, sz * 3.1)
            elseif p.shape == "triangle" then
                love.graphics.polygon("line", 0, -sz * 1.4, sz * 0.9, sz * 0.65, -sz * 0.9, sz * 0.65)
            elseif p.shape == "mirror" then
                love.graphics.rectangle("line", -sz * 0.75, -sz, sz * 1.5, sz * 2)
                love.graphics.line(-sz * 0.55, sz * 0.75, sz * 0.55, -sz * 0.75)
            else
                love.graphics.polygon("line", buildPolygonVerts(4, sz, math.pi / 4))
            end
            love.graphics.pop()
        end
    end
    love.graphics.setLineWidth(1)
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
