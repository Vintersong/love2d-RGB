# VFX Design Spec — Projectile Impact, Trails, Shield Impacts, Boss Projectiles

**Date:** 2026-06-01  
**Status:** Approved

---

## Decisions Summary

| Area | Decision |
|------|----------|
| Aesthetic | Neon Geometric — hard edges, square sparks, sharp line segments |
| Color coding | Color-inherited — all effects match the projectile's `color` attribute |
| Trails | Segmented line — tapered glow-halo + sharp line pass |
| Shield impact | Full shield pulse — whole shield flashes + two expanding rings |
| Boss projectiles | Pattern-specific — all 9 attack patterns get distinct silhouettes |

---

## 1. Aesthetic Language

All new VFX follows a **Neon Geometric** style:
- Sparks are small **squares** (`fillRect`), not circles
- Trails are **connected line segments** with a wide low-alpha glow pass behind a thin sharp pass
- Rings/arcs use `stroke` with `shadowBlur` glow
- No soft gradients, no smoke blobs, no organic falloff
- All effects stay high-contrast against the dark background

---

## 2. Projectile Trails

**Replaces:** `ShapeLibrary.trail()` call in `Projectile:draw()`  
**Owner:** `Projectile:draw()` reads `self.trail`, `self.color`, `self.size`

### Algorithm (two-pass)

**Pass 1 — Glow halo:**
- Iterate trail positions front-to-back
- Per segment: `lineWidth = (1 - i/len) * 10`, `globalAlpha = (1 - i/len) * 0.18`
- Color = `self.color`, `shadowBlur = 0` (halo is width-based, not shadow)

**Pass 2 — Sharp line:**
- Same iteration
- Per segment: `lineWidth = (1 - i/len) * 2.5`, `globalAlpha = (1 - i/len) * 0.85`
- Color = `self.color`, `shadowColor = self.color`, `shadowBlur = 6`

**Trail length:** 18 positions (up from current 8). Update `self.trailLength = 18` in `Projectile:init`.

**Core dot:** white circle radius 3.5, `shadowColor = self.color`, `shadowBlur = 14`.

---

## 3. Projectile Impact Burst

**Replaces:** `VFXLibrary.spawnImpactBurst()` — current implementation is plain circles with no glow.  
**Called from:** `AttackSystem.projectileHit()` and `ProjectileCollisionSystem`

### New `spawnImpactBurst(x, y, color, count)`

**Sparks (count, default 9):**
- Angle: evenly distributed `(i/count)*2π + random(-0.15, 0.15)`
- Speed: `random(70, 180)`
- Shape: square (`fillRect`), size `random(2, 4)`
- Lifetime: `random(0.28, 0.55)s`
- Drag: `vx *= 0.86, vy *= 0.86` per frame
- Draw: `globalAlpha = life`, `fillStyle = color`, `shadowBlur = 5`

**Expanding ring (1):**
- Radius: `0 → 28` over `0.35s`
- Draw: `stroke`, `lineWidth = 1.8 * life`, `shadowBlur = 8`

No changes to `updateImpactBursts` / `drawImpactBursts` structure — just update the spawn function and add ring handling to the draw loop.

---

## 4. Shield Impact (Boss Projectile Hits)

**Trigger:** When a boss projectile hits the player's active shield (HALO artifact), call `ShieldEffect.triggerHit(color)`.  
**Owner:** `ShieldEffect.lua` gets a new `triggerHit(color)` function alongside the existing `trigger/update/draw`.

### `ShieldEffect.triggerHit(color)`

**Guard:** if `active == nil`, do nothing (shield not currently deployed).

Sets on the `active` shield object:
- `active.flashAlpha = 1.0`
- `active.hitColor = color` (defaults to `{0.8, 0.8, 0.8}` if nil)
- Pushes two ring entries into `active.hitRings` (initialized as `{}` inside `ShieldEffect.trigger()`):
  - Ring 1: `startR = maxRadius`, `maxR = maxRadius + 30`, `lifetime = 0.5s`
  - Ring 2: `startR = maxRadius`, `maxR = maxRadius + 50`, `lifetime = 0.7s`, `delay = 0.1s`

### Updates to `ShieldEffect.update(dt)`

- Decay `active.flashAlpha` by `dt * 5` (clamp to 0)
- Update `active.hitRings` — subtract dt, remove dead rings

### Updates to `ShieldEffect.draw()`

After drawing the base shield circle, if `active.flashAlpha > 0`:
- Draw filled shield circle: `fillStyle = white`, `alpha = flashAlpha * 0.25`
- Draw stroke rim: `lineWidth = 3`, `alpha = flashAlpha * 0.7`, `shadowBlur = 20`

For each hit ring:
- `radius = startR + (maxR - startR) * (1 - life/maxLifetime)`
- `stroke`, `lineWidth = 2.5 * life`, color = `hitColor`, `shadowBlur = 10`

---

## 5. Boss Projectile Shapes

**Replaces:** `"spread"` type (atom shape) used for all boss projectiles in `BossBehaviors.patternToProjectiles`.

Each boss attack pattern sets a distinct `projType` on projectiles. `Projectile:draw()` routes to the new shape.  
All boss projectiles share color `#ff2288` (neon pink/magenta) with a white core dot.

| Attack Pattern | `projType` | Shape Description |
|---------------|-----------|-------------------|
| `single_shot` | `"boss_diamond"` | Rotating diamond outline, 7px half-size |
| `spread_cone` | `"boss_bolt"` | Elongated vertical bolt (narrow ellipse 2×7), aligned to velocity |
| `spiral` | `"boss_orb"` | Two concentric circles (r=6, r=3) + white core dot |
| `circle_burst` | `"boss_shard"` | 8-pointed star polygon (alt radii 8 and 3.5) |
| `wave` | `"boss_crescent"` | Two arcs offset to form a crescent, aligned to velocity |
| `cross` | `"boss_cross"` | Plus sign — two rectangles 2×10 and 10×2 |
| `slam` | `"boss_chevron"` | Forward-pointing chevron (3 lines), aligned to velocity |
| `double_spiral` | `"boss_twinorb"` | Outer ring r=7 + two small offset dots at ±45°, counter-rotating |
| `flower` | `"boss_petal"` | 6 ellipse-shaped petals radiating from center, slowly rotating |

### Rendering notes

- All boss shapes draw at `shadowColor = self.color`, `shadowBlur = 10`
- All rotate: `self.rotation` incremented in `Projectile:update` at a per-type rate (see below)
- Velocity-aligned types (`bolt`, `crescent`, `chevron`) use `atan2(vy, vx)` as base rotation

| `projType` | Rotation speed (rad/s) |
|-----------|----------------------|
| `boss_diamond` | 4.0 |
| `boss_bolt` | velocity-aligned |
| `boss_orb` | 3.0 |
| `boss_shard` | 2.5 |
| `boss_crescent` | velocity-aligned |
| `boss_cross` | 2.0 |
| `boss_chevron` | velocity-aligned |
| `boss_twinorb` | outer +2.0 / inner −3.5 (stored as `self.innerRotation`) |
| `boss_petal` | 1.0 |

### Changes to `BossBehaviors.lua`

`patternToProjectiles` currently passes `"spread"` as projType for all patterns. Update each attack block to pass the correct `projType` string.

`BossSystem:fireCone` also hardcodes `"spread"` — update to `"boss_bolt"`.

---

## 6. Files Changed

| File | Change |
|------|--------|
| `src/entities/Projectile.lua` | Trail two-pass render; `trailLength = 18`; boss shape routing in `draw()`; add `self.rotation = 0` and `self.innerRotation = 0` in `init()`; update rotation in `update()` based on `self.type` |
| `src/effects/VFXLibrary.lua` | `spawnImpactBurst` — square sparks + expanding ring; `drawImpactBursts` handles ring type |
| `src/effects/ShieldEffect.lua` | `triggerHit(color)`; `hitRings` list; flash alpha; updated `update`/`draw` |
| `src/data/BossBehaviors.lua` | Per-pattern `projType` on each `Projectile(...)` call |
| `src/boss/BossSystem.lua` | `fireCone` uses `"boss_bolt"` |

No new files. No new systems. No changes to `Config.lua`, `BootLoader.lua`, or `main.lua`.

---

## 7. Out of Scope

- Enemy (non-boss) projectile shapes — enemies currently don't fire; excluded
- Synergy-specific impact effects (Corrosive Cloud, Poison Bloom) — deferred until synergy consumption code lands
- Screen shake on boss impacts — already handled by `SUPERNOVA` artifact, not in scope here
- AudioAnalyzer FFT debt noted in bug review — separate task
