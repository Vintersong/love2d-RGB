# UIAnimator — Reusable UI Animation System

**Date:** 2026-06-18
**Status:** Design approved, pending spec review
**Motivating example:** Animating powerup/color card selection in `LevelUpState`.

## Goal

Introduce a reusable, tween-based UI animation layer so menu screens can animate
their elements (cards, panels, buttons) through a clear lifecycle: appear, hover,
select, and exit. First consumer is `LevelUpState`'s color-card selection screen,
which is currently fully static (immediate-mode redraw at fixed coordinates with
no animation state).

This is **UI/widget animation only** — not a particle/VFX system (that already
exists as `VFXLibrary`) and not sprite/frame animation.

## Constraints & context

- LÖVE 11.5, Lua, fixed 1920×1080, no automated test suite (verify by running).
- `flux` (`libs/flux-master/flux.lua`) is the vendored tween library; already used
  in `EnemySpawner` and `PlayingUpdateLoop` (which calls global `flux.update`).
- `VFXLibrary` and `FloatingTextSystem` establish the project's "effects system"
  idiom: a declarative def table + a flat list of instances + `update`/`draw`.
- Systems must boot through `BootLoader` registration in `main.lua` with method-
  name validation, or boot fails hard (per CLAUDE.md architecture rules).
- `LevelUpState` draws cards in immediate mode from `CARD_DEFS` at computed
  positions each frame; there are no persistent per-card objects today.

## Architecture

### Module boundary

New module **`src/effects/UIAnimator.lua`**, placed alongside `VFXLibrary` and
`FloatingTextSystem` to match the effects idiom.

**Instance-based** (constructor style, like `MusicReactor.new()`): one animator per
menu screen. Menu states are independent and transient, so a per-state instance
fits better than a global singleton.

**Separation of concerns:**
- `UIAnimator` owns **motion and timing**. It knows nothing about "cards" — it
  animates generic elements identified by an id and exposes their current
  transform.
- The state owns **layout and drawing**. `LevelUpState` keeps all card-drawing
  code; it reads transforms from the animator instead of using fixed coordinates.

This boundary means the module can later drive `MenuState`, `OptionsState`, etc.
without modification.

### Flux isolation

The animator creates its **own** `flux.group()` and advances it via
`group:update(dt)` inside `animator:update(dt)`. It never touches the global flux
group, so:
- It cannot collide with `PlayingUpdateLoop`'s global `flux.update`.
- It works in menu states that don't run the playing loop.

### Public API

```lua
local a = UIAnimator.new()

a:add(id, opts)            -- register an element + its rest transform
a:enter()                  -- staggered intro for all registered elements
a:setHover(id, isHovered)  -- drive an element toward / away from hover state
a:select(id, onComplete)   -- punch chosen element, dim siblings, call onComplete when done
a:exit(onComplete)         -- animate all elements out, then call onComplete
a:update(dt)               -- advance the owned flux group
a:get(id)  -> transform    -- read current transform in draw code
a:isBusy() -> bool         -- true during select/exit (for input locking)
a:clear()                  -- drop all elements + cancel tweens
```

### Per-element transform model

Each registered element holds one transform table the draw code consumes:

```lua
{ scale = 1, dx = 0, dy = 0, alpha = 1, glow = 0 }
```

- `scale` — uniform scale about the element's own center.
- `dx`, `dy` — pixel offset from the element's layout (rest) position.
- `alpha` — multiplier applied to the element's draw alpha.
- `glow` — 0..1 emphasis factor (hover/select highlight intensity).

The animator stores, per element: the live transform table, its rest values, and
its registration index (for stagger ordering).

### Lifecycle behavior

- **Enter** — each element is seeded offset/faded (`alpha = 0`, `dy = +30`,
  `scale = 0.9`) then `flux.to` toward rest, with a per-index `:delay(i * stagger)`
  for a cascade.
- **Hover** — `flux.to` toward `scale ≈ 1.05`, `glow → 1`; reverse on un-hover.
  Short duration so it tracks pointer/focus responsively. Re-targeting an
  in-flight hover tween is fine (flux replaces the tween on that object).
- **Select** — chosen element punches (`scale` up then settles) and `glow` spikes;
  siblings tween `alpha` down. Sets the internal busy flag; `onComplete` fires via
  flux `:oncomplete()`.
- **Exit** — all elements tween `alpha → 0` and `dy` away; `onComplete` fires after
  the longest tween completes.

### Presets (tunables)

Animation tunables live in a **module-local `UIAnimator.presets` table**, matching
how `VFXLibrary.ArtifactEffects` and `FloatingTextSystem.Types` keep defs local.
These are visual-feel constants (durations, easing names, stagger delay, hover and
select scale factors), not gameplay balance, so they intentionally do **not** go in
`Config.lua`. Keeping them in one table lets the feel be tuned without touching
logic.

## Integration: `LevelUpState`

- `enter()` — create `self.animator = UIAnimator.new()`, register one element per
  valid choice (id = color code), call `animator:enter()`.
- `update(dt)` — add `self.animator:update(dt)` (no global `flux.update` needed
  here).
- `drawCard(...)` — wrap drawing in `love.graphics.push()`, apply `t.dx/t.dy` and
  scale-about-center from `animator:get(code)`, multiply card alpha by `t.alpha`,
  and feed `t.glow` into the existing hover highlight.
- `mousemoved` — call `animator:setHover(code, ...)` for the hovered card.
- `selectColor` — apply the gameplay effect **immediately**
  (`player:levelUp()`, `ColorSystem.addColor`, `applyEffects`,
  `TutorialSystem.onColorAdded`) so game logic stays consistent, but defer the
  `StateManager.pop()` into the `animator:select(code, ...)` → `animator:exit(...)`
  completion callback.
- **Input locking** — `keypressed` and `mousepressed` early-return while
  `animator:isBusy()`, preventing double-select mid-animation.

Note: the tutorial-popup path and the "stay on screen for another level-up" path
(`player:canLevelUp()`) must still work — the deferred pop only replaces the
existing immediate `StateManager.pop()` calls; when the player can still level up
again, no exit animation runs and the screen rebuilds elements for the next choice.

## Boot registration

In `main.lua`:
- `BootLoader.registerSystem("UIAnimator", UIAnimator, {"new"})` — validates the
  constructor exists.
- No `initializeSystem` line needed (no global init state), consistent with
  modules like `ShapeLibrary`.

## Scope (YAGNI)

v1 touches only:
- **New:** `src/effects/UIAnimator.lua`
- **Modified:** `src/states/LevelUpState.lua`, `main.lua`

No other menus are migrated yet. The module is *built* reusable, but proving it on
a second screen is a follow-up.

## Verification

No automated tests exist. Verify by:
1. Capturing the boot log with `lovec.exe` + redirect (flushes on exit) to confirm
   no load/boot error after registration.
2. Running the game, triggering a level-up, and observing: cards cascade in on
   appear, pop on hover, punch + sibling-dim on select, and animate out before the
   screen closes. Confirm input is locked during select/exit.

## Open tuning (not blocking)

Exact durations, easing curves, stagger delay, and scale factors are feel-driven
and will be dialed in live against the running game via the `presets` table.
