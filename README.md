# LÖVE2D RGB — Bullet Hell

A Vampire Survivors-style bullet hell built with LÖVE2D (Lua). Auto-aim shooting, a **2-primary color commitment** tree, **music-reactive** formation spawning (`MusicReactor` → `EnemySpawner`), collectible **artifacts** with scripted **synergies** (`SynergySystem` — **18** named combos today).

**Resolution:** fixed **1920×1080**.

On boot, **`SongLibrary`** picks **one of two authored tracks at random**, loads its structure table, and runs BPM detection (`main.lua`). Splash screen: **SPACE** starts a run; **U** jumps into **`UISandboxState`** for HUD experiments.

---

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Space | Dash (1.5s cooldown) |
| E | Blink — teleport to mouse position (5s cooldown) |
| Q | Shield — temporary invulnerability (10s cooldown, 3s duration) |
| Left Shift | Artifact “active” slot *(keydown wired; **[`Player:useActiveAbility`](src/entities/Player.lua) is still a stub** — no effect yet. HUD block for **`[L-SHIFT]`** only appears once `setActiveAbility` is wired; footer text may still mention the bind.) |

Debug hotkeys (**PlayingState**, development prototype):

| Key | Action |
|-----|--------|
| F1 | Instant level up |
| F2 | Spawn 10 enemies around the player |
| F3 | Print `ColorSystem` state to console |
| F4 | Add enough XP to push toward player level ~20 |
| F5 | Full heal |
| F8 | Spawn small XP particle orb at player |
| F9 | Spawn medium XP particle orb |
| F10 | Spawn large XP particle orb |
| F11 | Print loot / drop-rate diagnostics |
| T | Pulse **SimpleGrid** wave animation (visual dev test) |
| L | Grant +50 player EXP |

`DebugMenu` adds its **own** overlay/help hotkeys (`src/systems/DebugMenu.lua`) on top of the above.

---

## Color progression

At each level-up the player selects a **color upgrade** overlay (`LevelUpState`). Mechanics match the **`ColorTree` + `ColorSystem`** pairing:

- Pick first primary — RED, GREEN, or BLUE.
- Pick second primary — the third locks out for the remainder of the run.
- With both locked, tertiary / secondary palettes unlock (`YELLOW`, `MAGENTA`, `CYAN`, etc.)

Full tables live in **`DESIGN_DOC.md` §4** (this README stays succinct).

Dash bonuses change with dominant color combinations (speed buff, heals, piercing dash-chip damage, cyan lifesteal layering).

---

## Artifacts & synergies

Eight artifacts mirror the **ArtifactManager** roster (Prism, Halo, Mirror, Lens, Diffusion, Diffraction, Refraction, Supernova). Duplicate pickups raise each up to **Lv5**.

[`SynergySystem.lua`](src/systems/SynergySystem.lua) houses **18** named triggers (pairs like `LENS + BLUE → Laser Focus`, `SUPERNOVA + MAGENTA → Chain Reaction`). Pickup enums include **`AURORA`** as its own orb type alongside **`HALO`**; synergy keys follow those enums — skim design doc §5 before renaming types or orbs.

---

## Enemy spawning

**Pipeline:** **`SpawnController.update` → `EnemySpawner.update`**. Formations (`square_corners`, `hex_star`, `tri_squares`, `diamond`, `cross`, `vee`, `box`) pulse off music weights for **BASS / MIDS / TREBLE** archetypes via `ProceduralEnemy` & friends.

The legacy **`GridAttackSystem`** marching wave layer still exists (`src/systems/GridAttackSystem.lua`) but its **update/draw calls are intentionally commented out** inside `PlayingState` (“DISABLED FOR TESTING” markers).

---

## Boss encounters

Production boss = **`BossSystem.activeBoss`** (spawn banner + cone spread projectiles):

- Spawn cadence — **every 100 kills** counted in `SpawnController` (not unused `BossSystem.checkSpawn`/wave scaffolding).
- **2000 HP** — defeatable (`BossSystem.spawnBoss`).
- Falling exit animation clears `BossSystem.activeBoss`.

**⚠ Separate debug entity [`Boss.lua`](src/entities/Boss.lua)** (9999 HP) spawns via **DebugMenu tooling** — not the cinematic boss chase above.

---

## Systems (quick reference)

| System | Responsibility |
|--------|----------------|
| **`BootLoader`** | Startup probes + orderly system `init()` |
| **`GameConfig` / `StateManager`** | Global services + bookkeeping for registered gameplay states |
| **`SongLibrary` + `MusicReactor`** | Random track ingest, BPM-ish estimate, synthesized band ramps feeding spawn weights |
| **`SpawnController`** | Kill counters, orb & power-up drops after deaths, bosses every 100 kills |
| **`EnemySpawner`** | Spatial formations reacting to spectral intensity |
| **`GridAttackSystem`** | Alternate flank waves *(presently disabled hooks)* |
| **`SimpleGrid` + shader bg** | `BackgroundShader` (GLSL + **moonshine glow**) draws the playable backdrop; **`SimpleGrid`** overlays beat ripples (**T** pulses) |
| **`World`** | Scroll metadata / frozen perspective grid scaffolding (mostly bypassed visually) |
| **`ColorSystem`** | Locks primaries / applies projectile stats |
| **`AbilitySystem` + `AbilityLibrary`** | Cooldown choreography for Dash / Blink / Shield |
| **`ArtifactManager`** + `src/artifacts/*` | Collectible scaling per artifact archetype |
| **`SynergySystem`** | Scripted combo unlocks keyed by pickup type strings |
| **`AttackSystem`** + `Weapon`/`PlayerCombat` | Auto-fire, DoTs, split shots |
| **`BossSystem`** | Arena Boss HP + projectile fan |
| **`CollisionSystem`** | bump.lua hashing |
| **`VFXLibrary` / XP particle helpers / `FloatingTextSystem`** | Juice & feedback |
| **`UISystem`** + optional **`UISandboxState`** | HUD + layout lab |
| **`DebugMenu`** | Overlay diagnostics |

---

## States

| State | Notes |
|-------|-------|
| `SplashScreenState` | Title + SPACE / sandbox entry |
| `PlayingState` | Core loop orchestrator (`BackgroundShader` drawn here each frame) |
| `LevelUpState` | Frozen snapshot + color cards (**shader grid not redrawn underneath right now**) |
| `GameOverState` | Death recap path (`PlayingState` -> switch) |
| `VictoryState` | Exists + renders summary overlays, yet **Gameplay never pushes/switches victory** currently |
| `UISandboxState` | Dev HUD playground (direct `gamestate.switch` from splash) |

---

## Libraries

| Library | Role |
|---------|------|
| hump (**class**, **gamestate**, **timer**, **camera**) | OO patterns + stacked states |
| **flux** | Motion smoothing |
| **bump.lua** | Spatial hash collisions |
| **moonshine** | Bloom pass owned by **`BackgroundShader`** |

---

## Notes

- Prefer **`DESIGN_DOC.md`** for mechanical depth; **`PITCH_DECK.md`** for stakeholder framing — both documents were refreshed to match **`src/`** at the time this README synced.
- `Feedback.md` still tracks experiential papercuts (**post-upgrade delay**, **dash clarity**).
- `_deprecated/` is historical baggage only.
- `src/` **+** `main.lua` remain authoritative for behavior.

---

## License

MIT — see [LICENSE](LICENSE).
