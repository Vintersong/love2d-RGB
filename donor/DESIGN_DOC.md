# RGB — Game Design Document

**Engine:** LÖVE2D 11.x (Lua) | **Resolution:** 1920×1080 windowed, vsync | **Genre:** Bullet-hell prototype

> Status: prototype. This document describes what the code actually does. Aspirational features (artifacts, music reactor, multi-state UI, etc.) are not in this build and have been pruned from the doc — see `git log` for prior iterations.

---

## 1. Concept

RGB is an arena bullet-hell prototype built around a single design question: **what if your weapon's color was the build?** Every level-up is a color choice. Color shapes projectile stats and dash behavior. Committing to two primaries early locks out the third for the rest of the run.

---

## 2. Core Loop

```
Survive → Kill enemies → XP fills bar → Level up → Pick a color upgrade
         ↑                                                    ↓
         ←←←←← stronger projectiles + dominant-color dash ←←←
```

- Auto-fire targets the nearest enemy on a fire-rate cooldown (`getProjectileStats().fireRate`).
- Enemies spawn in formations from off-screen; contact damages the player over time.
- Reaching the kill threshold spawns a single boss (`EnemyManager:spawnBoss`).
- Run ends on `playerStats.health <= 0` (game over) or `enemyManager.bossDefeated` (victory). Press **R** to reset.

---

## 3. Controls

| Input | Action |
|-------|--------|
| WASD / arrows | Move |
| Left mouse | Fire current ability pattern (or `WeaponManager:fire` if no numeric ability is selected) |
| Right mouse | Trigger lightning bolt toward cursor |
| Space | Dash (color-reactive, `playerAbilities:dash`) |
| E | Blink to a fixed forward offset |
| Q | Shield (temporary invulnerability) |
| Tab | Open/close level-up cards |
| 1–9, 0, -, = | Select ability pattern 1–12 (see §4) |
| `[` `]` | Decrease / increase laser count |
| `;` `'` | Decrease / increase split count |
| `,` `.` | Decrease / increase wave bullets |
| `z` `x` | Decrease / increase cluster count |
| `c` `v` | Decrease / increase random-spread bullets |
| `b` `n` | Decrease / increase reflect bounces |
| F1 | Toggle debug overlay |
| F2 | Instant level up (adds full XP bar) |
| F3 | Toggle collider debug draw |
| F5 | Full heal |
| F10 | Force-spawn the boss |
| R | Restart (only after game over / victory) |
| Esc | Close level-up cards (when open) |

Note: `space`, `e`, `q` are intercepted in `gameRuntime:keypressed` before reaching `InputBindings`, so the `onSpace` / weapon-cycle (`q`/`e`) callbacks in `inputBindings.lua` are never reached. Either remove them or rebind.

---

## 4. Color Progression

`colorSystem.lua` owns the color tree. Twelve numeric "ability" patterns in `attack.lua` (Parallel Lasers, Spread Shot, Sine Wave, Split Shot, Wave Shot, Cluster Shot, Random Spread, Reflecting Shot, Radial Burst, Spiral, Double Spiral, Cross) are selectable via the number-row keys and dispatched through `AttackSystem:fire(abilityId, ...)`. The auto-fire loop separately calls `AttackSystem:fireColorVolley(player, target, stats)` using `ColorSystem:getProjectileStats()`.

### 4.1 Commitment rule

- Pick any of RED / GREEN / BLUE first.
- Pick one of the remaining two second — the third primary is locked permanently.
- Once both primaries are active, a corresponding secondary unlocks automatically.

### 4.2 Primaries

| Color | Path | Effects (per rank) |
|-------|------|--------------------|
| RED | Damage | Increases projectile damage |
| GREEN | Speed | Reduces fire rate, increases bullet count |
| BLUE | Utility | Adds pierce / ricochet |

### 4.3 Secondaries (auto-unlock)

| Color | Requires | Path |
|-------|----------|------|
| YELLOW | RED + GREEN | Explosive (AoE) |
| MAGENTA | RED + BLUE | Homing |
| CYAN | GREEN + BLUE | Control |

### 4.4 Color-reactive dash

`PlayerAbilities:dash` consults `ColorSystem:getDashSpec()` (driven by the dominant color) for the post-dash effect — bonus speed, heal, life-steal, or pass-through damage depending on the active mix.

Exact per-rank numbers live in `colorSystem.lua` (`updateCommitment`, `getProjectileStats`, `getDashSpec`). They are the source of truth — do not duplicate them here.

---

## 5. Enemies

`components/enemies/enemyManager.lua` (645 LOC) owns spawning, formations, contacts, projectile collisions, and boss flow.

### 5.1 Archetypes

| Type | Speed | HP | Notes |
|------|-------|----|-------|
| BASS | 72 | 8 | Slow, tanky |
| MIDS | 104 | 5 | Medium |
| TREBLE | 145 | 3 | Fast, fragile |
| SHOOTER | 90 | 6 | Fires projectiles |

### 5.2 Formations

`square_corners`, `hex_star`, `tri_squares`, `diamond`, `vee` — each is a list of `{dx, dy, archetype}` offsets spawned around an off-screen anchor.

### 5.3 Boss

`EnemyManager:spawnBoss` is invoked from `update` once kill thresholds trigger it (or via F10). Boss AI lives in `components/enemies/bossBehaviors.lua` and fires through a second `AttackSystem` instance (`enemyAttack`). Killing the boss sets `bossDefeated`, which `gameRuntime:update` reads to flip into the `"victory"` overlay.

---

## 6. Visuals

- Solid dark backdrop (`backgroundColor` in `gameRuntime`) with a parallax `Starfield`.
- Player ship rendered to a canvas via `shipDesign.lua` + `shapeLibrary.lua` (triangle / rectangle / trapezoid primitives).
- Projectile, dash, shield, and lightning effects use Love particle systems and direct draws — no post-processing pipeline.
- The only third-party library is `libs/gradient.lua` (used by `shield.lua` for radial gradients, with a `pcall` fallback).

---

## 7. Architecture

### 7.1 Stack

| Layer | Choice |
|-------|--------|
| Language | Lua (LuaJIT via LÖVE 11.x) |
| Framework | LÖVE2D 11.x |
| State management | None — single `GameRuntime` with a string `state` field (`"playing" / "gameover" / "victory"`) |
| Collision | Hand-rolled circle / line-segment in `systems/core/collision.lua` |
| Tweening | None — manual timers via `systems/core/timer.lua` |
| Third-party libs | `libs/gradient.lua` only |

### 7.2 Module layout

```
main.lua                            — love.* callbacks delegate to GameRuntime
conf.lua                            — Window config (1920×1080, vsync)
gameRuntime.lua                     — Owns every subsystem; runs the playing/gameover/victory loop

attack.lua                          — Projectile pool, 12 ability patterns, fireColorVolley
bulletPatterns.lua                  — Pattern shape generators (arc, ring, spiral, ...)
colorSystem.lua                     — Color tree, commitment rule, projectile/dash stats
playerAbilities.lua                 — Dash, blink, shield logic + cooldowns
shield.lua / lightningEffect.lua    — VFX + hit detection
shipDesign.lua / shapeLibrary.lua   — Ship sprite assembled from primitive shapes
inputBindings.lua                   — Keyboard/mouse → callbacks
debugHud.lua                        — Debug overlay (toggled with F1)

components/
  enemies/
    enemyManager.lua                — Archetypes, formations, spawn, collisions, boss orchestration
    bossBehaviors.lua               — Boss attack patterns
  environment/starfield.lua         — Parallax stars
  player/
    playerStats.lua                 — Health/energy/level/XP scaling
    weaponManager.lua               — Cycles between weapon types
    weaponTypes.lua                 — Static weapon definitions
  ui/hud.lua                        — Bars, cooldowns, color build, level-up cards

systems/
  combat/xpManager.lua              — XP bar fill + level-up callback
  core/
    collision.lua                   — Circle / line-segment helpers
    mathUtils.lua                   — clamp, normalize (shared)
    resolution.lua                  — Window sizing helpers
    timer.lua                       — Deferred / repeating callbacks

libs/gradient.lua                   — Radial gradient texture helper
```

### 7.3 Wiring

`GameRuntime:new()` instantiates every subsystem and wires them with closures:

- `xpManager:setLevelUpCallback` bumps `playerStats` and tells `hud:spawnCards()`.
- `InputBindings` is constructed with `onFire / onAltFire / onWeaponCycle / onToggleCards / onSpace` callbacks pointing back at runtime systems.
- `EnemyManager:update` is passed the player projectiles, stats, XP manager, abilities, and the `enemyAttack` system in a single call.

There is no service container, dependency-injection layer, or scene/state stack. Reset is a wholesale re-instantiation of every subsystem in `GameRuntime:reset()` — kept in sync by hand with `:new()`.

---

## 8. Current State

### Implemented

- Color commitment data + projectile stat derivation (`colorSystem.lua`).
- 12 selectable bullet patterns + auto-fire color volley (`attack.lua`).
- Dash / blink / shield with cooldowns (`playerAbilities.lua`).
- Enemy spawning by formation, archetype-weighted (`enemyManager.lua`).
- Boss spawn + defeat → victory overlay (`enemyManager.lua` + `gameRuntime.lua`).
- HUD bars, cooldown rings, color build readout, level-up cards (`components/ui/hud.lua`).
- XP bar + level-up callback chain (`systems/combat/xpManager.lua`).
- Lightning, shield, and starfield VFX.
- Reset-on-R from terminal states.

### Known gaps / smells

- **`gameRuntime:reset` duplicates `:new`** — any new subsystem must be added in two places.
- **Three intercepted bindings** in `inputBindings.lua` (`space`, `e`, `q` callbacks, weapon-cycle on `q`/`e`) are dead code because `gameRuntime:keypressed` returns first.
- **`attack.lua` is 497 LOC**, with `updateProjectile` and the 12-way `fire` dispatch as the worst offenders.
- **`enemyManager.lua` is 645 LOC** and owns spawn, AI, contact, projectile collision, and rendering.
- **Magic numbers** for tuning are scattered across `colorSystem.lua`, `playerAbilities.lua`, `shield.lua`, `lightningEffect.lua`. A central `constants.lua` would help iteration.
- **`atan2` polyfill** in `attack.lua` coexists with direct `math.atan2` calls in `bossBehaviors.lua` — pick one.
- **Mouse cursor** stays hidden during play and is re-shown only in terminal states; no explicit `setVisible(false)` call exists, so this depends on engine defaults.

### Suggested next refactors

1. Split `attack.lua` into a projectile entity + a pattern dispatcher.
2. Slim `enemyManager.lua` by extracting collision and rendering.
3. Move tuning numbers to a single constants module.
4. Replace `gameRuntime:reset`'s copy-paste with a single `:initSystems()` helper called from both `:new` and `:reset`.
