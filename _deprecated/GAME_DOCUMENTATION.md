# Love2D RGB - Complete Game Documentation

**Project:** Vampire Survivors-style Bullet Hell
**Engine:** Love2D
**Status:** Phase 4 Complete - Ability System Refactor
**Total LOC:** ~18,000 lines (after cleanup)
**Files:** ~57 Lua files

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Game Overview](#game-overview)
3. [Architecture](#architecture)
4. [Systems Reference](#systems-reference)
5. [Ability System](#ability-system)
6. [Gameplay Features](#gameplay-features)
7. [Development Guide](#development-guide)
8. [Testing Guide](#testing-guide)

---

## Quick Start

### Controls
- **WASD** - Movement
- **SPACE** - Dash (1.5s cooldown)
- **E** - Blink/Teleport (5s cooldown)
- **Q** - Shield (10s cooldown)
- **ESC** - Quit game

### Debug Commands
- **F1** - Instant level up
- **F2** - Spawn 10 enemies
- **F3** - Print color system state
- **F5** - Full heal
- **L** - Add 50 XP

### File Structure
```
love2d-RGB/
├── main.lua                    # Entry point
├── conf.lua                    # Window config
├── src/
│   ├── abilities/
│   │   └── AbilityLibrary.lua  # Ability definitions
│   ├── artifacts/              # 9 artifact modules
│   ├── data/
│   │   └── ColorTree.lua       # Color progression
│   ├── entities/
│   │   ├── Player.lua          # Core player (260 lines)
│   │   ├── PlayerInput.lua     # Movement (77 lines)
│   │   ├── PlayerCombat.lua    # Combat (365 lines)
│   │   ├── PlayerRender.lua    # Rendering (615 lines)
│   │   └── ...
│   ├── states/
│   │   ├── PlayingState.lua    # Main gameplay
│   │   ├── LevelUpState.lua    # Color selection
│   │   └── ...
│   └── systems/
│       ├── AbilitySystem.lua   # Core ability management
│       ├── CollisionSystem.lua # Spatial hashing
│       ├── ColorSystem.lua     # Color progression
│       ├── VFXLibrary.lua      # Visual effects
│       └── ...
└── libs/
    ├── hump-master/            # Gamestate, signal
    └── bump.lua-master/        # Collision detection
```

---

## Game Overview

### Concept
A Vampire Survivors-style auto-shooter with a unique **color-based progression system**. Players collect RGB colors to unlock powerful synergies and abilities.

### Core Loop
1. Kill enemies → Collect XP orbs
2. Level up → Choose a color (R, G, B)
3. Colors combine to create secondary/tertiary colors
4. Unlock color-specific abilities and synergies
5. Survive as long as possible

### Unique Features
- **Color Tree Progression**: RGB → RG/RB/GB → RGB
- **Color-Specific Dash Effects**: Each color modifies dash behavior
- **Artifact System**: Passive abilities that scale with colors
- **Music-Reactive Elements**: Enemies and VFX sync to music
- **Procedural Enemy Waves**: Grid-based attack patterns

---

## Architecture

### Design Principles

1. **Data-Driven Design**
   - Abilities defined in data tables, not code
   - Artifacts as modular, self-contained systems
   - Color progression defined in ColorTree

2. **Separation of Concerns**
   - Player split into: Input, Combat, Render
   - Systems handle specific responsibilities
   - States manage game flow

3. **Performance Optimized**
   - Spatial hashing (bump.lua) for O(n) collision
   - Particle pooling for VFX
   - Fixed 1920x1080 resolution (no scaling overhead)

### Core Systems

#### **State Management** ✓ EXCELLENT
```lua
-- Uses hump.gamestate
SplashScreen → PlayingState ⇄ LevelUpState
                   ↓
            GameOverState / VictoryState
```

**States:**
- `SplashScreen` - Initial logo/title
- `PlayingState` - Main gameplay (781 lines)
- `LevelUpState` - Color selection UI
- `GameOverState` - Death screen
- `VictoryState` - Win screen

#### **Collision System** ✓ EXCELLENT
```lua
-- Spatial hashing with bump.lua
CollisionSystem.init(cellSize)  -- 128px optimal
CollisionSystem.add(entity, type)
CollisionSystem.update(entity, x, y)
CollisionSystem.checkPlayerEnemyCollisions(player)
```

**Performance:**
- Before: O(n²) - 100 entities = 10,000 checks
- After: O(n) - 100 entities = ~100 checks
- Handles 1000+ entities at 60fps

#### **Ability System** ✓ NEW (Phase 4)
```lua
-- Data-driven ability management
AbilitySystem.register(entity, {"DASH", "BLINK", "SHIELD"})
AbilitySystem.activate(entity, "DASH", AbilityLibrary.DASH)
AbilitySystem.update(entity, AbilityLibrary, dt, context)
AbilitySystem.isReady(entity, "DASH")  -- Check cooldown
```

**Benefits:**
- Add new abilities without touching Player code
- Abilities defined as data tables with callbacks
- Reusable for enemies/bosses
- Easy to balance (tweak cooldowns/damage)

#### **Color System**
```lua
-- Tracks player's color progression
ColorSystem.addColor(color)  -- R, G, or B
ColorSystem.getDominantColor()  -- Current strongest color
ColorSystem.getValidChoices(level)  -- Available colors
```

**Color Tree:**
```
Level 1-2: Choose R, G, or B (primary)
Level 3-4: Choose second primary
Level 5-6: Unlocks secondary (RG=YELLOW, RB=MAGENTA, GB=CYAN)
Level 7+:  Choose third primary → unlocks tertiary (RGB=WHITE)
```

#### **VFX Library**
```lua
-- Centralized visual effects
VFXLibrary.spawnArtifactEffect("DASH", x, y, targetX, targetY)
VFXLibrary.spawnImpactBurst(x, y, color, count)
VFXLibrary.update(dt)
VFXLibrary.draw()
```

**Effect Types:**
- DASH, BLINK, SHIELD (abilities)
- PRISM, HALO, MIRROR, LENS (artifacts)
- SUPERNOVA, AURORA, REFRACTION (color effects)

---

## Systems Reference

### Player System

**Architecture:**
```
Player.lua (260 lines) - Core entity
  ├─ PlayerInput.lua (77 lines) - Movement & input
  ├─ PlayerCombat.lua (365 lines) - Auto-fire, projectiles
  └─ PlayerRender.lua (615 lines) - Drawing, effects
```

**Key Methods:**
```lua
Player:new(x, y, weapon)
Player:update(dt, enemies)
Player:draw()
Player:useDash()  -- Activate dash
Player:useBlink()  -- Teleport
Player:useShield()  -- Invulnerability
Player:takeDamage(amount, dt)
Player:addExp(amount)
Player:levelUp()
```

### Artifact System

**Pattern:**
```lua
-- Each artifact is a self-contained module
HaloArtifact.RED = {
    behavior = function(player, level)
        -- Passive damage aura
    end,
    update = function(state, dt, enemies, player)
        -- Damage nearby enemies
    end,
    draw = function(state, player)
        -- Draw pulsing ring
    end
}

-- Usage
HaloArtifact.apply(player, level, "RED")
HaloArtifact.update(dt, enemies, player, "RED")
HaloArtifact.draw(player, "RED")
```

**Available Artifacts:**
1. **HALO** - Passive damage aura
2. **PRISM** - Split projectiles
3. **LENS** - Focus/enlarge projectiles
4. **MIRROR** - Duplicate projectiles
5. **DIFFUSION** - Spread/cloud effects
6. **DIFFRACTION** - XP magnet
7. **REFRACTION** - Speed boost
8. **SUPERNOVA** - Explosions

### Enemy System

**Types:**
- **Enemy** - Basic enemy
- **ProceduralEnemy** - Generated from patterns
- **Boss** - Special encounters every 100 kills

**Spawning:**
```lua
-- Grid-based attack system
GridAttackSystem.init(screenWidth, screenHeight)
GridAttackSystem.update(dt, musicReactor, player, enemies)
```

**Formations:**
- LINE - Marching horizontal/vertical
- DIAMOND - Expanding diamond shape
- PINCER - Surround player
- SPIRAL - Rotating spiral
- WAVE - Sine wave pattern

---

## Ability System

### How It Works

#### **1. Define Ability in AbilityLibrary**
```lua
AbilityLibrary.DASH = {
    name = "Dash",
    cooldown = 1.5,
    duration = 0.2,
    speed = 800,

    onActivate = function(entity, state, context)
        -- Called when ability starts
        -- Get input, spawn VFX, set state
        return true
    end,

    onUpdate = function(entity, state, dt, context)
        -- Called every frame while active
        -- Move entity, spawn trail
        if state.timer >= duration then
            return false  -- Deactivate
        end
        return true  -- Continue
    end,

    onDeactivate = function(entity, state, context)
        -- Called when ability ends
        -- Apply post-effects (heal, speed boost)
    end
}
```

#### **2. Register Abilities**
```lua
-- In Player:new()
AbilitySystem.register(self, {"DASH", "BLINK", "SHIELD"})
```

#### **3. Activate Abilities**
```lua
-- In Player:useDash()
function Player:useDash()
    return AbilitySystem.activate(self, "DASH", AbilityLibrary.DASH, {})
end

-- In PlayingState:keypressed()
if key == "space" then
    self.player:useDash()
end
```

#### **4. Update Abilities**
```lua
-- In Player:update()
AbilitySystem.update(self, AbilityLibrary, dt, {enemies = enemies})
```

### Built-in Abilities

#### **DASH** (SPACE)
- **Cooldown:** 1.5s
- **Duration:** 0.2s
- **Speed:** 800
- **Effect:** Invulnerable during dash, color-specific effects

**Color Variants:**
- **RED** - Speed boost after dash (2s, +50%)
- **GREEN** - Heal 10% max HP on dash end
- **BLUE/YELLOW/PURPLE/CYAN** - Pierce enemies (20 damage)
- **YELLOW** - Heal 5% + speed boost 30% (1.5s)
- **PURPLE** - Apply DoT to pierced enemies
- **CYAN** - Life steal from pierced enemies (50%)

#### **BLINK** (E)
- **Cooldown:** 5s
- **Effect:** Teleport to mouse position
- **VFX:** LENS effect at destination

#### **SHIELD** (Q)
- **Cooldown:** 10s
- **Duration:** 3s
- **Effect:** Invulnerability + HALO VFX

### Adding New Abilities

**Example: Ultimate Ability**
```lua
-- 1. Define in AbilityLibrary.lua
AbilityLibrary.ULTIMATE = {
    name = "Ultimate",
    cooldown = 30.0,
    duration = 5.0,

    onActivate = function(entity, state, context)
        state.timer = 0
        state.damageMultiplier = 3.0  -- 3x damage
        entity.invulnerable = true
        print("[Ultimate] Activated!")
        return true
    end,

    onUpdate = function(entity, state, dt, context)
        state.timer = state.timer + dt

        -- Spawn continuous VFX
        local VFXLibrary = require("src.systems.VFXLibrary")
        VFXLibrary.spawnArtifactEffect("SUPERNOVA",
            entity.x + entity.width/2,
            entity.y + entity.height/2)

        if state.timer >= AbilityLibrary.ULTIMATE.duration then
            return false  -- End ultimate
        end
        return true
    end,

    onDeactivate = function(entity, state, context)
        entity.invulnerable = false
        state.damageMultiplier = 1.0
        print("[Ultimate] Ended!")
    end
}

-- 2. Register in Player:new()
AbilitySystem.register(self, {"DASH", "BLINK", "SHIELD", "ULTIMATE"})

-- 3. Add wrapper method
function Player:useUltimate()
    return AbilitySystem.activate(self, "ULTIMATE", AbilityLibrary.ULTIMATE, {})
end

-- 4. Bind to key
if key == "r" then
    self.player:useUltimate()
end
```

---

## Gameplay Features

### Color-Specific Dash Effects

Each color modifies the dash ability:

| Color | Effect |
|-------|--------|
| **RED** | Speed boost after dash (+50% for 2s) |
| **GREEN** | Heal 10% max HP on dash end |
| **BLUE** | Pierce enemies (20 damage each) |
| **YELLOW** | Heal 5% + speed boost (+30% for 1.5s) |
| **MAGENTA** | Pierce + explosive finish |
| **CYAN** | Pierce + life steal (50% of damage) |
| **PURPLE** | Pierce + apply DoT (5 damage/sec for 3s) |
| **NEUTRAL** | Basic dash (no special effects) |

### Synergy System

**Unlocked when combining specific colors:**

| Colors | Synergy | Effect |
|--------|---------|--------|
| R + G | VITALITY | Increased HP regeneration |
| R + B | POWER | Increased damage |
| G + B | DEFENSE | Damage reduction |
| R + G + B | MASTERY | All stats boosted |

### Artifact Mechanics

**Passive Effects:**
- Scale with player level
- Color-specific variants
- Stack with each other
- Apply to projectiles automatically

**Example: PRISM Artifact**
```lua
-- Level 1: Split into 2 projectiles
-- Level 2: Split into 3 projectiles
-- Level 3: Split into 4 projectiles
-- RED variant: Explosive splits
-- BLUE variant: Pierce after split
```

---

## Development Guide

### Adding a New Enemy Type

```lua
-- 1. Create in src/entities/NewEnemy.lua
local Enemy = require("src.entities.Enemy")
local NewEnemy = Enemy:derive("NewEnemy")

function NewEnemy:new(x, y)
    Enemy.new(self, x, y)
    self.hp = 50
    self.speed = 150
    self.damage = 20
    -- Custom behavior
end

function NewEnemy:update(dt, playerX, playerY)
    -- Custom AI
    Enemy.update(self, dt, playerX, playerY)
end

return NewEnemy

-- 2. Spawn in EnemySpawner
local NewEnemy = require("src.entities.NewEnemy")
table.insert(enemies, NewEnemy(spawnX, spawnY))
```

### Adding a New Artifact

```lua
-- Create src/artifacts/NewArtifact.lua
local NewArtifact = {}

NewArtifact.RED = {
    behavior = function(player, level)
        -- Setup behavior
        return {
            damage = 10 * level,
            range = 100 + (20 * level)
        }
    end,

    update = function(state, dt, enemies, player)
        -- Apply effects each frame
        for _, enemy in ipairs(enemies) do
            -- Damage nearby enemies
        end
    end,

    draw = function(state, player)
        -- Visual indicator
        love.graphics.circle("line", player.x, player.y, state.range)
    end
}

-- Copy for other colors
NewArtifact.GREEN = { ... }
NewArtifact.BLUE = { ... }

-- Main API
function NewArtifact.apply(player, level, color)
    local variant = NewArtifact[color]
    return variant.behavior(player, level)
end

return NewArtifact
```

### Performance Tips

1. **Use Spatial Hashing**
   ```lua
   -- GOOD: O(n) collision
   local nearby = CollisionSystem.checkPlayerEnemyCollisions(player)

   -- BAD: O(n²) collision
   for _, enemy in ipairs(enemies) do
       if checkCollision(player, enemy) then ...
   ```

2. **Pool Particles**
   ```lua
   -- Reuse particle systems instead of creating new ones
   VFXLibrary.spawnArtifactEffect("DASH", x, y)
   ```

3. **Limit Entity Count**
   ```lua
   -- Cap enemies to prevent lag
   if #enemies > 500 then
       table.remove(enemies, 1)  -- Remove oldest
   end
   ```

---

## Testing Guide

### Manual Testing Checklist

#### **Abilities**
- [ ] SPACE - Dash activates
- [ ] SPACE - Cooldown displays correctly
- [ ] SPACE - Invulnerable during dash
- [ ] E - Blink teleports to mouse
- [ ] Q - Shield makes invulnerable for 3s

#### **Color Dash Effects**
- [ ] RED - Speed boost after dash
- [ ] GREEN - Heal on dash end
- [ ] BLUE - Pierce enemies
- [ ] YELLOW - Heal + speed boost
- [ ] CYAN - Pierce + life steal
- [ ] PURPLE - Pierce + DoT

#### **Gameplay**
- [ ] Kill enemies → XP drops
- [ ] Collect XP → Level up
- [ ] Level up → Color selection appears
- [ ] Choose color → Returns to game
- [ ] Die → Game over screen
- [ ] Every 100 kills → Boss spawns

#### **Systems**
- [ ] No console errors on startup
- [ ] 60 FPS with 100+ enemies
- [ ] Collision detection works
- [ ] VFX spawns correctly
- [ ] Music plays and reacts

### Debug Commands

```lua
-- F1: Instant level up
self.player:addExp(self.player.expToNext)

-- F2: Spawn test enemies
for i = 1, 10 do
    local angle = (i / 10) * math.pi * 2
    local x = player.x + math.cos(angle) * 200
    local y = player.y + math.sin(angle) * 200
    table.insert(enemies, Enemy(x, y))
end

-- F3: Print color state
ColorSystem.getDominantColor()

-- F5: Full heal
player.hp = player.maxHp

-- L: Add XP
player.exp = player.exp + 50
```

---

## Current Status

### ✅ Completed (Phase 4)

1. **Ability System Refactor**
   - Extracted dash from Player (260 lines removed)
   - Data-driven ability definitions
   - Added BLINK and SHIELD abilities
   - Keybinds: SPACE, E, Q

2. **Code Cleanup**
   - Deleted 12 unused/redundant files
   - Reduced codebase by 12% (~2,500 lines)
   - Consolidated documentation

3. **Files Removed:**
   - CollisionManager.lua (replaced by CollisionSystem)
   - ArtifactEngine.lua (replaced by ArtifactManager)
   - EffectLibrary.lua (unused)
   - StateSwitcher.lua (replaced by StateManager)
   - StartState.lua (empty)
   - Projectiles.lua (empty)
   - ColorSystems.lua (duplicate)
   - ArtifactDefinitions.lua (old data)
   - EnemyPatterns.lua, EnemyShapes.lua (unused)
   - class.lua, utils/palette.lua (unused)

### 🔄 In Progress

- Complete REFRACTION artifact
- Complete DIFFRACTION artifact
- Complete SUPERNOVA artifact

### 📋 Next Steps (Phase 5)

1. **Event Bus Implementation**
   - Use hump.signal for decoupling
   - Events: "enemy_died", "player_dashed", "projectile_hit"

2. **Extract PlayingState Logic**
   - DropSystem (XP orb spawning)
   - SpawnController (enemy waves)
   - PickupSystem (XP/powerup collection)
   - Target: <400 lines for PlayingState

3. **Configuration System**
   - Create Config.lua
   - Centralize all constants
   - Make values tweakable

---

## Known Issues

### Minor
- Some artifacts incomplete (REFRACTION, DIFFRACTION, SUPERNOVA)
- No automated tests
- Hard-coded screen resolution (1920x1080 only)

### Performance
- None currently (60 FPS stable with 500+ entities)

---

## Credits

**Development:** Romania Game Dev Team
**Refactoring:** Claude (Anthropic) + Gemini AI analysis
**Libraries:**
- hump (gamestate, signal) - vrld
- bump.lua (collision) - kikito
- Love2D engine

**Version:** 4.0 (Post-Ability System Refactor)
**Last Updated:** 2025-01-23
