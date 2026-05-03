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
- A boss encounter triggers every **100 enemy kills**.
- Runs **currently end only on player death**. `VictoryState` UI exists but **no gameplay path switches to victory** yet (win condition wiring is a gap).

---

## 3. Controls

| Input | Action | Cooldown |
|-------|--------|----------|
| WASD | Move | — |
| Space | Dash — color-reactive burst | 1.5s |
| E | Blink — teleport to mouse cursor | 5s |
| Q | Shield — 3s invulnerability | 10s |
| Left Shift | Active artifact ability | *(wired to keydown; [`Player:useActiveAbility`](src/entities/Player.lua) is a stub — no effect; [`setActiveAbility`](src/entities/Player.lua) is never called, so HUD block for `[L-SHIFT]` stays hidden)* |

**Developer debug (PlayingState)**

| Input | Action |
|-------|--------|
| F1 | Instant level up |
| F2 | Spawn 10 enemies in a ring |
| F3 | Print `ColorSystem` state to console |
| F4 | Add XP sufficient to jump toward level 20 |
| F5 | Full heal |
| F8 | Spawn small XP particle orb |
| F9 | Spawn medium XP particle orb |
| F10 | Spawn large XP particle orb |
| F11 | Print drop-chance diagnostics |
| T | Trigger `SimpleGrid` wave pulse (dev) |
| L | Grant +50 EXP |

Separate **Debug menu** overlays and hotkeys remain active via [`DebugMenu`](src/systems/DebugMenu.lua).

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

Each synergy activates exactly once per run (no double-triggers). **Eighteen named synergies** are defined in [`SynergySystem.lua`](src/systems/SynergySystem.lua). Artifact **type strings** passed into `SynergySystem.checkAndActivate` may use internal keys (`AURORA` vs `HALO`) that do not rename the player-facing Halo / Diffusion artifacts in the roster — confirm against pickup types in [`Powerup.lua`](src/entities/Powerup.lua) when auditing balance.

**Full synergy roster (artifact type × color)**

| Artifact type key | Color | Synergy name | Summary |
|-------------------|-------|----------------|----------|
| PRISM | RED | Rainbow Cascade | Extra split on spread projectiles |
| PRISM | YELLOW | Crystal Prison | Rooted enemies widen prismatic crystals |
| LENS | RED | Focal Burst | +Damage, converging then burst |
| LENS | BLUE | Laser Focus | Pierce accumulates damage per hit |
| LENS | MAGENTA | Focused Detonation | Cone explosions (+50%) |
| MIRROR | GREEN | Kaleidoscope | +Reflective bounces |
| MIRROR | CYAN | Reflected Suffering | DoT chains on death |
| HALO | BLUE | Orbital Pierce | Shield orbital beams (~2s cadence) |
| AURORA | GREEN | Chain Lightning | Electric trails on bounces |
| AURORA | YELLOW | Static Field | Rooted enemies pulse electricity |
| AURORA | CYAN | Corrosive Cloud | DoT spreads as fog |
| DIFFRACTION | GREEN | Wave Echo | Bouncing pulls enemies |
| DIFFRACTION | YELLOW | Gravity Well | Rooted enemies pull others |
| DIFFRACTION | CYAN | Poison Bloom | DoT deaths bloom toxin |
| REFRACTION | BLUE | Light Ray | Bending pierce, extra pierce tiers |
| REFRACTION | MAGENTA | Shockwave | Radial explosion rings |
| SUPERNOVA | RED | Solar Flare | Screen clear spawns fire projectiles |
| SUPERNOVA | MAGENTA | Chain Reaction | Chaining explosions (~50%) |

*(No synergy entries currently exist under `DIFFUSION`.)*

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

Gameplay uses **`BossSystem.activeBoss`**, spawned from [`SpawnController`](src/systems/SpawnController.lua) when `enemyKillCount` is divisible by **100** (tracked on enemy deaths — not the dormant `BossSystem.checkSpawn`/wave-interval path).

- **HP:** **2000** (`BossSystem.spawnBoss`): killable sustained fight with cone projectile pressure.
- **Flow:** Drops in from above, phases `entering` → `combat` → falling `defeated`; projectiles originate from BossSystem helpers.
- **Legacy note:** [`Boss.lua`](src/entities/Boss.lua) entity (**9999** HP arc) persists for **debug / tooling** (e.g. [`DebugMenu`](src/systems/DebugMenu.lua)); it is **not** the BossSystem arena boss.

---

## 7. Music Reactor

The **MusicReactor** system drives gameplay dynamically from the soundtrack.

### 7.1 Analysis

Boot picks a **`SongLibrary` entry at random** (currently **two** WAV + structure modules: `song1` / `song2`) and passes it to `MusicReactor:loadSong`.

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
- Level-up is a **pushed Gamestate** ([`Gamestate.push`](libs/hump-master/gamestate.lua)): **enemy simulation freezes** while HUD cards show, but **`LevelUpState` still ticks music / lightweight effects**. Backdrop differs from gameplay: **`World.draw`** is largely disabled and **`BackgroundShader` is not drawn** there (Shader background only in [`PlayingState:draw`](src/states/PlayingState.lua)).
- Ability cooldown indicators.
- Artifact ability hint text may cite **Left Shift**, but HUD block renders only once `player.activeAbility` becomes non-nil (**stub today** — see Controls).

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
main.lua                      — Boot: SongLibrary RNG, BootLoader sanity checks, registers core states via StateManager
src/
  data/                       — Static data tables
    ColorTree.lua             — Full RGB color upgrade tree
    AbilityLibrary.lua        — Data-driven ability definitions
  Weapon.lua                  — Projectile / weapon facade used by Player
  entities/                   — Game objects
    Player.lua + PlayerInput.lua / PlayerCombat.lua / PlayerRender.lua
    Enemy.lua / ProceduralEnemy.lua
    Boss.lua                  — Legacy debug boss entity (not BossSystem arena boss)
    Projectile.lua / Drop.lua / XPOrb.lua / Powerup.lua
  artifacts/                  — Per-artifact modules (BaseArtifact + 8 concrete types)
  systems/
    BootLoader.lua            — Validates & initializes singleton systems printed at startup
    GameConfig.lua / StateManager.lua / SongLibrary.lua
    ColorSystem.lua           — Primary commitment tracking + projectile stats
    AbilitySystem.lua         — Cooldown/state for DASH / BLINK / SHIELD (+ future actives)
    ArtifactManager.lua / SynergySystem.lua
    SpawnController.lua       — Kill counts, orb drops — wraps EnemySpawner.update
    EnemySpawner.lua          — Music formations + procedural waves (called by SpawnController)
    GridAttackSystem.lua      — Alternate grid wave attackers (currently disabled in PlayingState)
    SimpleGrid.lua            — Quadrant visuals & dev wave pulses synced to MusicReactor
    MusicReactor.lua          — BPM estimation + synthesized band envelopes
    BossSystem.lua            — Active arena boss singleton + projectile cone
    AttackSystem.lua          — DoTs + combat helpers layered with PlayerCombat
    CollisionSystem.lua       — bump.lua wrapper
    VFXLibrary.lua / FloatingTextSystem.lua / XPParticleSystem.lua
    BackgroundShader.lua      — Canvas + moonshine glow (primary playfield backdrop)
    World.lua                 — Perspective grid scaffolding (drawing disabled — shader replaces it)
    UISystem.lua / DebugMenu.lua / ShapeLibrary.lua / HealthSystem.lua
  states/
    SplashScreenState.lua     — Menu: SPACE start, optional U → UISandbox
    PlayingState.lua          — Primary loop orchestrator
    LevelUpState.lua          — Card stack atop frozen playfield snapshot
    GameOverState.lua / VictoryState.lua (Victory presently unwired from play)
    UISandboxState.lua        — HUD layout prototyping
```

### 9.3 Platform Support

- Desktop (Windows/macOS/Linux) via LÖVE2D binary.
- Web browser via love.js (uses compatibility mode to avoid SharedArrayBuffer requirement).

---

## 10. Current State

### Implemented

- Full color progression data in [`ColorTree`](src/data/ColorTree.lua): primaries, secondaries, triple primaries (“White Light” path expressed in tree data).
- Color-reactive Dash, Blink (`E`), Shield (`Q`) via [`AbilityLibrary`](src/data/AbilityLibrary.lua).
- Eight artifacts leveling to 5 (`ArtifactManager`); passive behaviors across modules (`src/artifacts/*`).
- **18** scripted synergies triggered through [`SynergySystem.checkAndActivate`](src/systems/SynergySystem.lua) on artifact pickups (`Powerup` types aligned with synergy keys — see HUD note for `HALO` vs `AURORA`).
- Spawn pipeline: **`SpawnController` → `EnemySpawner`**, formations listed in §6.2, BPM / band multipliers hooked to music.
- **BossSystem** bosses every **100** kills at **2000 HP** until defeated animation completes.
- **BackgroundShader**: GLSL fill pass + moonshine bloom drawn every [`PlayingState:draw`](src/states/PlayingState.lua).
- Auxiliary **SimpleGrid** animations (music keyed + **`T`** dev pulse).
- **SongLibrary**: two authored tracks randomized at startup.
- **BootLoader** startup validation banner + deterministic init sequencing.
- Particle / impact VFX stacks, FloatingText, HUD via `UISystem`.
- Splash flow can jump to **UI Sandbox (`U`)** without registering that state inside `StateManager` (pure `gamestate.switch` shortcut).

### Known Gaps / In Progress

- **Active artifact ability** — Left Shift calls [`useActiveAbility`](src/entities/Player.lua) stub (`setActiveAbility` unused).
- **`GridAttackSystem.update/draw`** remain commented (**disabled**) inside [`PlayingState`](src/states/PlayingState.lua) “for testing”.
- **Victory flow** — `VictoryState` assets exist yet **Gameplay never calls `switch(VictoryState)`**.
- UX polish backlog: **post-upgrade input delay**, **dash cooldown clarity** (`Feedback.md`).
- **Contributor trap:** Legacy [`Boss.lua`](src/entities/Boss.lua) (9999 HP) vs production **BossSystem** boss — differentiate when editing AI.
- **Level-up layering:** Missing shader/grid backdrop parity while overlay is modal.
- Debug surfaces (`DebugMenu`, extended F-keys) still compiled in prototype builds (`Config.debug`/console flags per [`conf.lua`](conf.lua)).

---

## 11. Design Pillars

1. **Commitment over optimization** — locking out a primary color early creates genuine identity and meaningful trade-offs, not just min-maxing.
2. **Music as DM** — the soundtrack runs the encounter, not a scripted wave timer. Hard sections spawn harder waves.
3. **Color = everything** — the player's color choice affects their projectiles, their dash, their artifact synergies, and their visual presentation simultaneously.
4. **No punishment for rhythm** — timing windows are cosmetic. The game does not penalize players for not hitting beats; it rewards the music by reacting to it.
