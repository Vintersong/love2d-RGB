# LÖVE2D RGB — Bullet Hell

A Vampire Survivors-style bullet hell game built with LÖVE2D (Lua). Auto-aim shooting, a color-commitment progression system, music-reactive enemy spawning, and 8 collectible artifacts.

Resolution: 1920×1080.

---

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Space | Dash (1.5s cooldown) |
| E | Blink — teleport to mouse position (5s cooldown) |
| Q | Shield — temporary invulnerability (10s cooldown, 3s duration) |
| Left Shift | Active artifact ability | ( currently not implemented )

Debug hotkeys (development only):

| Key | Action |
|-----|--------|
| F1 | Instant level up |
| F2 | Spawn 10 enemies around player |
| F3 | Print color system state to console |
| T | Trigger grid wave animation (all quadrants) |

---

## Color Progression System

At each level-up the player picks a color upgrade. The system uses a **2-primary commitment** model:

- Choose your first primary — RED, GREEN, or BLUE.
- Choose your second primary — the third is permanently locked out.
- Once both primaries are active, one secondary color unlocks automatically.

**Primaries**

| Color | Path | Effect |
|-------|------|--------|
| RED | Damage | Increased damage, multi-target |
| GREEN | Speed | Rapid fire, extra bullet count |
| BLUE | Control | Pierce, ricochet |

**Secondaries (unlock when both required primaries are chosen)**

| Color | Requires | Path | Effect |
|-------|----------|------|--------|
| YELLOW | RED + GREEN | Explosive | AoE burst, extra projectiles |
| MAGENTA | RED + BLUE | Homing | Seeking projectiles |
| CYAN | GREEN + BLUE | Frost/Control | Slowing shots, pierce |

**Pure paths** — doubling down on the same primary unlocks Crimson (RR), Emerald (GG), or Sapphire (BB) with stronger single-color bonuses.

Dash effects are also color-reactive (e.g. RED dash → speed boost, GREEN dash → heal, CYAN dash → life steal).

---

## Artifacts

Artifacts are collectible items that level up to max level 5. All 8 are implemented with per-color behavior variants.

| Artifact | Behavior |
|----------|----------|
| Prism | Splits projectiles into multiple beams |
| Halo | Color-based aura damage |
| Mirror | Reflects incoming damage back to attackers |
| Lens | Optical focusing effects |
| Diffusion | Spreading/area projectile behavior |
| Diffraction | Angular deflection effects |
| Refraction | Temporal/bending projectile patterns |
| Supernova | Explosive orbital bombs |

The `SynergySystem` defines bonus interactions between artifact type and active colors.

---

## Enemy Spawning

Enemies are spawned in **procedural formations**, music-reactive via `MusicReactor`:

- **Enemy types:** BASS, MIDS, TREBLE — mapped to low/mid/high frequency bands.
- **Formation patterns:** square_corners, hex_star, tri_squares, diamond, cross, vee, box.
- **Boss encounter:** spawns every 100 enemy kills. 2000 HP, cone projectile attack.

---

## Systems

| System | Role |
|--------|------|
| `ColorSystem` | 2-primary commitment tracking and color stat application |
| `AbilitySystem` | Data-driven cooldown/state system for DASH, BLINK, SHIELD |
| `EnemySpawner` | Music-reactive formation spawning |
| `MusicReactor` | BPM detection and frequency band analysis |
| `BossSystem` | Boss encounter spawning and phase management |
| `SynergySystem` | Artifact × color synergy bonus definitions |
| `AttackSystem` | Projectile firing, auto-aim targeting |
| `CollisionSystem` | Spatial hash collision via bump.lua |
| `VFXLibrary` | Particle and artifact visual effects |
| `BackgroundShader` | Vaporwave grid shader (initialized; render currently disabled) |

---

## States

- `SplashScreenState` — intro screen
- `PlayingState` — main gameplay loop
- `LevelUpState` — color upgrade selection (game world stays visible behind overlay)
- `GameOverState` / `VictoryState`
- `UISandboxState` — dev tool for UI layout testing

---

## Libraries

| Library | Use |
|---------|-----|
| hump (class, gamestate, timer) | Entity class system, state management |
| flux | Tweening / smooth animations |
| bump.lua | Spatial hash collision detection |
| moonshine | Post-process shader effects (loaded, render step disabled) |

---

## Notes

- Debug overlays and print logging are currently active.
- `_deprecated/` contains older design documents from earlier phases — not relevant to the current implementation.
- `src/` and `main.lua` are the authoritative source of truth.

---

## License

MIT — see [LICENSE](LICENSE).
