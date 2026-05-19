# CHROMATIC — Bullet Heaven

A Vampire Survivors-style bullet heaven built with LÖVE2D (Lua). Auto-aim shooting, a **2-primary color commitment** tree, **music-reactive** formation spawning (`MusicReactor` → `EnemySpawner`), collectible **artifacts** with scripted **synergies** (`SynergySystem` — **18** named combos today).

**Resolution:** fixed **1920×1080**.

On boot, **`SongLibrary`** picks **one of two authored tracks at random**, loads its structure table, and runs BPM detection (`main.lua`). Splash screen: **SPACE** starts a run; **U** jumps into **`UISandboxState`** for HUD experiments.

Canonical runtime entrypoints are the root **`main.lua`**, **`conf.lua`**, and **`src/`** tree. The **`donor/`** folder is reference-only prototype material; its color logic and old entrypoints are not part of the runnable root game.

---

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Space | Dash (1.5s cooldown) |
| E | Blink — teleport to mouse position (5s cooldown) |
| Q | Shield — temporary invulnerability (10s cooldown, 3s duration) |
| Left Shift | SUPERNOVA active artifact ultimate once collected; uses the current dominant color variant and its cooldown. |
| P / Esc | Pause / resume during gameplay. |

Debug hotkeys (**PlayingState**, development prototype; gated by `Config.debug.enabled`):

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

`DebugMenu` adds its **own** overlay/help hotkeys (`src/systems/DebugMenu.lua`) on top of the above when debug mode is enabled.

---

## Color progression

At each level-up the player selects a **color upgrade** overlay (`LevelUpState`). The root **`ColorSystem`** is the source of truth for color progression, commitment, secondary unlocks, dominant color, and projectile stat effects:

- Pick first primary — RED, GREEN, or BLUE.
- Pick second primary — the third locks out for the remainder of the run.
- With both locked and leveled, the matching secondary palette unlocks (`YELLOW`, `MAGENTA`, or `CYAN`).

Full tables live in **`DESIGN_DOC.md` §4** (this README stays succinct).

Dash bonuses change with dominant color combinations (speed buff, heals, piercing dash-chip damage, cyan lifesteal layering).

---

## Artifacts & synergies

Eight artifacts mirror the **ArtifactManager** roster (Prism, Halo, Mirror, Lens, Diffusion, Diffraction, Refraction, Supernova). Duplicate pickups raise each up to **Lv5**.

[`SynergySystem.lua`](src/systems/SynergySystem.lua) houses **18** named triggers (pairs like `LENS + BLUE → Laser Focus`, `SUPERNOVA + MAGENTA → Chain Reaction`). Pickup enums include **`AURORA`** as its own orb type alongside **`HALO`**; synergy keys follow those enums — skim design doc §5 before renaming types or orbs.

---

## Enemy spawning

**Pipeline:** **`SpawnController.update` → `EnemySpawner.update`**. Formations (`square_corners`, `hex_star`, `tri_squares`, `diamond`, `cross`, `vee`, `box`) pulse off music weights for **BASS / MIDS / TREBLE** archetypes via `ProceduralEnemy` & friends. Regular enemies use melee-only AI — projectile shooting was removed from `ProceduralEnemy` to keep the enemy count scalable.

The legacy **`GridAttackSystem`** marching wave layer still exists (`src/systems/GridAttackSystem.lua`) but its **update/draw calls are intentionally commented out** inside `PlayingState` (“DISABLED FOR TESTING” markers).

---

## Boss encounters

Production boss = **`BossSystem.activeBoss`** (spawn banner + cone spread projectiles):

- Spawn cadence — **every 100 kills** counted in `SpawnController` (not unused `BossSystem.checkSpawn`/wave scaffolding).
- **2000 HP** — defeatable (`BossSystem.spawnBoss`).
- Falling exit animation clears `BossSystem.activeBoss` and switches to `VictoryState`.

**⚠ Separate debug entity [`Boss.lua`](src/entities/Boss.lua)** (9999 HP) spawns via **DebugMenu tooling** — not the cinematic boss chase above.

---

## Systems (quick reference)

| System | Responsibility |
|--------|----------------|
| **`BootLoader`** | Startup probes + orderly system `init()` |
| **`GameConfig` / `StateManager`** | Global services + bookkeeping for registered gameplay states |
| **`SongLibrary` + `MusicReactor`** | Random track ingest, BPM-ish estimate, synthesized band ramps feeding spawn weights; master volume initialized from `Config.sound.volume` |
| **`SpawnController`** | Kill counters, orb & power-up drops after deaths, bosses every 100 kills |
| **`EnemySpawner`** | Spatial formations reacting to spectral intensity |
| **`GridAttackSystem`** | Alternate flank waves *(presently disabled hooks)* |
| **`SimpleGrid` + shader bg** | `BackgroundShader` (GLSL + **moonshine glow**) draws the playable backdrop; **`SimpleGrid`** overlays beat ripples (**T** pulses); `splashscreen.glsl` is a separate shader used by the splash/menu/options screens |
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
| **`DebugMenu`** | Config-gated overlay diagnostics |

---

## States

| State | Notes |
|-------|-------|
| `SplashScreenState` | Title + SPACE / sandbox entry; rendered via `splashscreen.glsl` shader backdrop |
| `MenuState` | Animated main menu (shader backdrop, bracket selection UI, micro-animations); routes to Playing or `OptionsState` via SETTINGS |
| `OptionsState` | Tabbed settings screen — **AUDIO** (master volume, mute), **VIDEO** (fullscreen, vsync), **CONTROLS** (key reference diagram); returns to `MenuState` |
| `PlayingState` | Core loop orchestrator (`BackgroundShader` drawn here each frame); delegates update/render/input/enemy-flow to `PlayingUpdateLoop`, `PlayingRenderLayers`, `PlayingInputHandlers`, `PlayingEnemyFlow` |
| `LevelUpState` | Frozen snapshot + color cards (**shader grid not redrawn underneath right now**) |
| `GameOverState` | Death recap path (`PlayingState` -> switch) |
| `VictoryState` | Run completion path after the production BossSystem boss defeat animation finishes |
| `PauseState` | Pushed pause overlay; freezes gameplay, pauses music, supports resume/restart/quit |
| `UISandboxState` | Dev HUD playground registered through `StateManager` |

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
- `donor/` is reference-only prototype code; do not port donor color-system behavior into the canonical root game.
- `src/data/ColorTree.lua` is now an archived legacy data tree; active color progression lives in `src/systems/ColorSystem.lua`.
- `src/data/BossArchetypes.lua` is legacy compatibility only; canonical boss AI comes from `src/data/BossBehaviors.lua`.
- `src/` **+** root `main.lua` / `conf.lua` remain authoritative for behavior.

---

## Web build

The browser build targets **LOVE 11.5** through the 2dengine `love.js` standalone player.

Local package command on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package-web.ps1 -GenerateWebAudio
```

This creates `dist/rgb.love` and `dist/web/`. If `ffmpeg` is available, WAV music is converted to `assets/music_web/*.ogg` for the web package; otherwise the package keeps the WAV files so it still runs. The GitHub Pages workflow installs `ffmpeg`, assembles `dist/web`, downloads love.js, and deploys the static site.

In GitHub, set **Settings -> Pages -> Build and deployment -> Source** to **GitHub Actions**. If it is set to **Deploy from a branch**, GitHub runs Jekyll across the whole repo and will fail on vendored Markdown files such as `donor/libs/moonshine/README.md`; that branch-root mode also does not publish the generated love.js build.

---

## License

MIT — see [LICENSE](LICENSE).
