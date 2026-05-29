# CHROMATIC — LÖVE2D Bullet Heaven

Vampire-Survivors-style bullet heaven in Lua / LÖVE **11.5**, fixed **1920×1080**, developed on Windows.

## Read first
- `README.md` — authoritative map of systems, states, controls (kept in sync with `src/`).
- `DESIGN_DOC.md` — mechanics depth (color tree §4, artifact synergies §5).
- `PITCH_DECK.md` — stakeholder framing.

Prefer these over re-deriving behavior from code.

## Run & verify
- **Desktop:** `love .` from the repo root. There is no build step for desktop.
  `love` may not be on PATH — invoke the installed `love.exe` directly if `love .` fails.
- **Console output:** gated by `Config.debug.enabled` (currently `true`). F-key debug hotkeys are listed in `README.md`.
- **Web build:** `powershell -ExecutionPolicy Bypass -File .\scripts\package-web.ps1 -GenerateWebAudio` → outputs `dist/rgb.love` and `dist/web/`.
- After editing Lua, sanity-check it loads (run `love .`); there is no automated test suite for game code.

## Architecture rules
- **Config:** every tunable lives in `src/Config.lua` (required as `"src.Config"`). Don't hardcode balance numbers — add/edit a field there.
- **Boot gate:** systems initialize through `src/core/BootLoader.lua`, registered and method-validated in `main.lua`. Adding a system, or changing a system's public method names, requires updating the `registerSystem` / `initializeSystem` block in `main.lua` — otherwise boot fails hard.
- **States:** registered in `main.lua` via `StateManager` + `hump.gamestate`.
- **Web vs desktop:** behavior branches on `Runtime.isWeb()` (web skips BPM analysis, uses `static` sources and `assets/music_web/*.ogg` instead of WAV). Keep both paths working.

## Do NOT touch or wire in (legacy / non-runtime)
- `reference/donor/**` and `src/utils/legacy/**` — idea reference only; never `require` them into the live game.
- `src/data/ColorTree.lua` — archived; live color logic is `src/gameplay/ColorSystem.lua`.
- `src/data/BossArchetypes.lua` — legacy compat; canonical boss AI is `src/data/BossBehaviors.lua`.
- `GridAttackSystem` is intentionally disabled in `PlayingState` (leave the hooks commented out unless asked).
- Two boss entities exist: `BossSystem.activeBoss` is the production cinematic boss; `src/entities/Boss.lua` (9999 HP) is debug-only.
- `dist/**` is a gitignored build artifact containing **stale duplicate copies** of `src/` and `libs/` (old paths like `src/systems/`). Ignore it in searches and never edit it.

## Conventions
- Modules return a table; PascalCase module names; `Module.method(...)` call style; `local X = require("...")` grouped at the top of the file.
- Vendored libraries live in `libs/*-master/` (hump, flux, bump, moonshine, ripple). Treat as third-party — don't edit.
- `Config.debug.enabled` toggles the console window and the F-key debug hotkeys; production / web builds set it to `false`.

## Git
- Day-to-day work happens on `devBranch`; PRs target `main`.
- Pushing to `main` or `devBranch` triggers the GitHub Pages deploy workflow (`.github/workflows/pages.yml`).
