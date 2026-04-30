# RGB — Game Design Document

**Engine:** LÖVE2D (Lua) | **Resolution:** 1920×1080 | **Genre:** Bullet-hell roguelite

---

## 1. Concept

RGB is an auto-shooting bullet-hell roguelite built around a single design question: **what if your weapon's color was the build?**

Every level-up is a color choice. Color shapes your projectiles, your dash behavior, your artifact synergies, and your identity. The player commits to a two-primary color path early, locking out the third primary permanently. That constraint is the game.

---

## 2. Core Game Loop

```
Survive → Kill enemies → Collect XP orbs → Level up → Choose a color upgrade
         ↑                                                         ↓
         ←←←←←←←←←←← stronger projectiles ←←←←←←←←←←←←←←←←←←←←
```

- The player auto-fires at the nearest enemy (Vampire Survivors–style targeting).
- Enemies approach from off-screen; contact with enemies deals damage over time.
- XP orbs drop on kills and are picked up automatically on proximity.
- Every boss kill (every 100 enemy kills) is a major milestone.
- A run ends on player death or after clearing a victory condition.

---

## 3. Controls

| Input | Action | Cooldown |
|-------|--------|----------|
| WASD | Move | — |
| Space | Dash — color-reactive burst | 1.5s |
| E | Blink — teleport to mouse cursor | 5s |
| Q | Shield — 3s invulnerability | 10s |
| Left Shift | Active artifact ability | *(not yet implemented)* |

---

## 4. Color Progression System

This is the game's core identity mechanic.

### 4.1 Structure

At each level-up the player chooses from a small card selection of color upgrades. The system enforces a **2-primary commitment** constraint:

1. First upgrade: choose RED, GREEN, or BLUE (any, all available).
2. Second upgrade: choose any of the other two — the third is **locked out for the rest of the run**.
3. Once both primaries are active, one secondary color unlocks automatically.

This forces meaningful long-term identity from early decisions.

### 4.2 Primary Colors

| Color | Path | Projectile Effects |
|-------|------|--------------------|
| RED | Damage | +5 damage per rank; Crimson (RR) → +15; Blood Red (RRR) → +30 + 20% crit @ 2× |
| GREEN | Speed | −0.02s fire rate, +1 bullet count; Emerald (GG) → −0.06s, +3 bullets; Forest Green (GGG) → −0.1s, +7 bullets |
| BLUE | Utility | +1 pierce; Sapphire (BB) → +3 pierce, +2 ricochet; Deep Blue (BBB) → +5 pierce, +5 ricochet |

### 4.3 Secondary Colors (auto-unlock when both required primaries are active)

| Color | Requires | Path | Effects |
|-------|----------|------|---------|
| YELLOW | RED + GREEN | Explosive | +8 dmg, 40-radius AoE burst, +2 bullet count |
| MAGENTA | RED + BLUE | Homing | +10 dmg, projectiles home at strength 2.0 |
| CYAN | GREEN + BLUE | Control | +2 bullets, +1 pierce, slow enemies 50% for 2s |

### 4.4 Ultimate Path

| Color | Requires | Path | Effects |
|-------|----------|------|---------|
| WHITE LIGHT | R + G + B | Transcendence | +20 dmg, −0.05s fire rate, +5 bullets, +2 pierce, 50-radius AoE, homing |

### 4.5 Color-Reactive Dash

The player's Dash ability behaves differently based on the dominant active color:

| Color | Post-Dash Effect |
|-------|-----------------|
| RED | +50% speed for 2s |
| GREEN | Heal 10% max HP |
| YELLOW | Heal 5% max HP + 30% speed for 1.5s |
| CYAN | Life-steal 50% of dash damage dealt |
| BLUE / CYAN / MAGENTA | Dash through enemies, dealing 20 damage per hit |

---

## 5. Artifact System

Artifacts are passive collectibles dropped during play. There are 8 distinct artifacts, each leveling up to max 5. All artifacts have per-color behavior variants tuned to synergize with the player's active color path.

### 5.1 Artifact Roster

| Artifact | Theme | Core Behavior |
|----------|-------|---------------|
| Prism | Splitting | Projectiles split into multiple beams on hit |
| Halo | Aura | Color-tinted passive aura that damages nearby enemies |
| Mirror | Reflection | Reflects incoming damage back at attackers |
| Lens | Focus | Optical focus increases projectile damage output |
| Diffusion | Spreading | Projectiles scatter in AoE patterns |
| Diffraction | Deflection | Angular deflection; pulls XP and enemies |
| Refraction | Bending | Projectiles bend and curve mid-flight |
| Supernova | Explosion | Explosive orbital bombs / screen-clearing bursts |

### 5.2 Synergy System

When the player holds an artifact and has matching active colors, the **SynergySystem** triggers a unique named synergy — a bonus effect that stacks on top of the artifact's base behavior.

Each synergy activates exactly once per run (no double-triggers).

**Selected synergies:**

| Artifact | Color | Synergy Name | Effect |
|----------|-------|--------------|--------|
| Prism | RED | Rainbow Cascade | Spread projectiles split again on hit |
| Prism | YELLOW | Crystal Prison | Rooted enemies grow prismatic crystals (+30 root radius) |
| Lens | RED | Focal Burst | +30% focus damage, converging projectiles burst |
| Lens | BLUE | Laser Focus | Pierce damage accumulates per enemy hit |
| Lens | MAGENTA | Focused Detonation | Explosions deal +50% damage in a cone |
| Mirror | GREEN | Kaleidoscope | Bounces create mirror reflections (+1 bounce count) |
| Mirror | CYAN | Reflected Suffering | DoT chains to nearest enemy on death (150 range) |
| Halo | BLUE | Orbital Pierce | Shield fires piercing orbital beams every 2s |
| Diffraction | GREEN | Wave Echo | Bounces pull enemies (force 50, radius 100) |
| Diffraction | YELLOW | Gravity Well | Rooted enemies become black holes (force 80, radius 120) |
| Diffraction | CYAN | Poison Bloom | DoT enemies explode into toxin on death |
| Refraction | BLUE | Light Ray | Bending pierce hits up to +2 additional times |
| Refraction | MAGENTA | Shockwave | Explosions emit expanding energy rings |
| Supernova | RED | Solar Flare | Screen clear spawns 12 fire projectiles |
| Supernova | MAGENTA | Chain Reaction | Explosions have 50% chance to cascade |

---

## 6. Enemy System

### 6.1 Enemy Types

Enemies are procedurally generated using shape archetypes:

| Type | Shape | Behavior |
|------|-------|----------|
| BASS | Hexagon / Square | Slow, tanky, tied to bass frequency band |
| MIDS | Square | Medium speed, medium HP |
| TREBLE | Triangle | Fast, low HP, tied to treble frequency band |

### 6.2 Formation Patterns

Enemies spawn in coordinated geometric formations rather than solo or random clusters:

| Formation | Shape | Count |
|-----------|-------|-------|
| square_corners | Center square + 4 triangle corners | 5 |
| hex_star | Center hexagon + 6 surrounding triangles | 7 |
| tri_squares | Triangle of squares (1-2-3) | 6 |
| diamond | Hexagon center + 4 inner + 4 outer ring | 9 |
| cross | Plus-sign formation | 5 |
| vee | V-shape | 4 |
| box | Hollow rectangle | 8 |

### 6.3 Boss Encounters

- Spawns every 100 enemy kills.
- Descends from off-screen, moves to screen center, then slowly tracks the player.
- Fires a cone projectile attack.
- Extremely high HP — intended as a sustained pressure encounter rather than a burst DPS check.

---

## 7. Music Reactor

The **MusicReactor** system drives gameplay dynamically from the soundtrack.

### 7.1 Analysis

- Loads audio via LÖVE2D's audio API.
- Performs automatic BPM detection on load.
- Simulates frequency band analysis (bass, mid-low, mid-high, treble, presence) using mathematically derived wave functions synced to the detected BPM.
- Maintains smoothed history buffers (10-sample rolling average) for each band.

### 7.2 Gameplay Effects

| Output | Usage |
|--------|-------|
| Bass intensity | Drives BASS-type enemy spawning weight |
| Mid intensity | Drives MIDS-type enemy spawning weight |
| Treble intensity | Drives TREBLE-type enemy spawning weight |
| Overall intensity | Spawn rate multiplier (0.5× to 2.0×) |
| Difficulty multiplier | Scales from 0.7× to 1.5× with energy |
| BPM | Background scroll speed (BPM × 0.8, min 50) |
| Beat phase | Visual beat-pulse effects on player and UI |

### 7.3 Timing Windows

The system tracks "perfect / good / okay / miss" windows relative to the beat. These are **visual feedback only** — no gameplay penalties. The design philosophy is: music choreographs, it does not punish.

---

## 8. Visual Design

### 8.1 Aesthetic

**Vaporwave / synth-punk.** The game's look is defined by:

- A retro grid background rendered via a custom GLSL shader with moonshine glow post-processing.
- Neon color palette dominated by the player's current dominant color at any given moment.
- Particle VFX (impact bursts, artifact aura effects, dash trails) that morph based on active color — each color has its own VFX type mapped at the code level.

### 8.2 Color-VFX Mapping

| Color | Dash VFX Type |
|-------|--------------|
| RED | SUPERNOVA |
| GREEN | AURORA |
| BLUE | LENS |
| YELLOW | REFRACTION |
| MAGENTA | PRISM |
| CYAN | DIFFRACTION |

### 8.3 UI

- Health bar and XP bar rendered during play.
- Floating text system for damage numbers and heal feedback.
- Level-up overlay renders over the live game world (game does not pause).
- Ability cooldown indicators.

---

## 9. Technical Architecture

### 9.1 Stack

| Layer | Technology |
|-------|-----------|
| Language | Lua |
| Framework | LÖVE2D 11.x |
| State management | hump.gamestate |
| Entity class system | hump.class |
| Tweening | flux |
| Collision | bump.lua (spatial hash) |
| Post-processing | moonshine |
| Web export | love.js |

### 9.2 Module Structure

```
main.lua                      — Boot entry point
src/
  data/                       — Static data tables
    ColorTree.lua             — Full RGB color upgrade tree
    AbilityLibrary.lua        — Data-driven ability definitions
  entities/                   — Game objects
    Player.lua                — Thin coordinator; delegates to sub-modules
    PlayerInput.lua           — Movement, ability key handling
    PlayerCombat.lua          — Auto-fire, projectile logic
    PlayerRender.lua          — Draw calls
    Enemy.lua / ProceduralEnemy.lua
    Boss.lua
    Projectile.lua / Drop.lua / XPOrb.lua / Powerup.lua
  artifacts/                  — Per-artifact modules (BaseArtifact + 8 concrete types)
  systems/                    — Core game systems
    ColorSystem.lua           — Active color tracking, stat application
    AbilitySystem.lua         — Cooldown/state machine for DASH/BLINK/SHIELD
    ArtifactManager.lua       — Artifact collection and level tracking
    SynergySystem.lua         — Artifact × color bonus definitions
    EnemySpawner.lua          — Music-reactive formation spawning
    MusicReactor.lua          — BPM detection, frequency analysis
    BossSystem.lua            — Boss phase management
    AttackSystem.lua          — Projectile firing, auto-aim
    CollisionSystem.lua       — bump.lua wrapper
    VFXLibrary.lua            — Particle and visual effects
    BackgroundShader.lua      — GLSL grid shader + moonshine glow
    UISystem.lua              — HUD rendering
    FloatingTextSystem.lua    — Damage/heal floating text
  states/
    SplashScreenState.lua
    PlayingState.lua
    LevelUpState.lua
    GameOverState.lua / VictoryState.lua
    UISandboxState.lua        — Developer UI layout tool
```

### 9.3 Platform Support

- Desktop (Windows/macOS/Linux) via LÖVE2D binary.
- Web browser via love.js (uses compatibility mode to avoid SharedArrayBuffer requirement).

---

## 10. Current State

### Implemented

- Full color progression tree: primaries, secondaries, pure paths, advanced paths, white light.
- Color-reactive Dash with post-dash effects per color.
- Blink (teleport) and Shield abilities.
- 8 artifacts with level scaling (active artifact ability unimplemented).
- Full synergy system definitions.
- Music-reactive enemy spawning with 7 formation patterns.
- Boss encounter every 100 kills.
- GLSL vaporwave background shader (loaded; render enabled).
- Particle VFX library with artifact and color variants.
- Floating text damage/heal feedback.
- Web export compatibility.

### Known Gaps / In Progress

- Active artifact ability (Left Shift) — defined but not wired.
- Post-dash delay UX (noted in Feedback.md).
- Dash cooldown visual clarity (noted in Feedback.md).
- Debug overlays are active (F1–F3, T hotkeys).
- Boss HP in code (9999) differs from README (2000); README is outdated.

---

## 11. Design Pillars

1. **Commitment over optimization** — locking out a primary color early creates genuine identity and meaningful trade-offs, not just min-maxing.
2. **Music as DM** — the soundtrack runs the encounter, not a scripted wave timer. Hard sections spawn harder waves.
3. **Color = everything** — the player's color choice affects their projectiles, their dash, their artifact synergies, and their visual presentation simultaneously.
4. **No punishment for rhythm** — timing windows are cosmetic. The game does not penalize players for not hitting beats; it rewards the music by reacting to it.
