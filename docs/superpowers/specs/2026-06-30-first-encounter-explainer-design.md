# First-Encounter Explainer — Design Spec

**Date:** 2026-06-30
**Status:** Approved design, pending implementation plan
**Scope:** Sub-project 1 of 3 (Teaching). Difficulty and Endgame are separate specs.

## Problem

New players do not understand three things, despite content existing for some of them:

1. **Chroma (the currency)** — `RunSummaryState` shows `"Chroma earned: N | Balance: M"` and
   `ProgressionState` shows a `Chroma:` counter and `"NEXT N CHROMA"` costs, but nothing ever
   *defines* chroma or says it is permanent currency spent to upgrade artifacts between runs.
2. **Delivery** — every in-moment tip routes through `TutorialSystem`, gated on
   `Config.gameplay.tutorialEnabled`. `TutorialSystem.complete()` permanently disables and persists
   that flag after one finished color arc, so all in-moment teaching silently stops thereafter.
3. **In-moment artifacts** — `TutorialSystem.onArtifactCollected` fires a single generic
   `"OPTICS ARTIFACT"` popup, once ever, identical for all 8 artifacts, and only renders on the
   next `LevelUpState` screen (never at the moment of pickup during live combat).

Root pattern: teaching is welded to the color-tutorial's one-shot lifecycle, which is built to play
once and turn itself off. Currency and per-artifact teaching were hung on a hook designed to vanish.

## Approach (chosen: A)

A small **persistent first-encounter service**, fully decoupled from `TutorialSystem`. Any surface
asks "should I teach concept X right now?"; the service answers from persistent per-concept seen
flags, builds a card payload, and marks the concept seen on dismiss. Reuses existing card UI and the
artifact copy already authored in the Atlas.

Rejected: (B) patching `TutorialSystem` — it is in-run only and cannot reach RunSummary/Progression,
so it cannot teach currency. (C) discoverability-only — passive; players already do not seek the
Atlas. C's "→ Atlas" link is folded into A's menu cards.

## Architecture

```
 pickup / run-end / progression ──▶ FirstEncounter (new) ──▶ MetaProgression (persistent flags)
                                          │ pulls copy from
                                          ▼
                                     AtlasData (new, extracted from AtlasState)
```

### New modules

- **`src/data/AtlasData.lua`** — the `colorEntries` and `artifactEntries` tables lifted out of
  `AtlasState`. Pure data, no love calls, no `Theme` *render* dependency for the fields the explainer
  needs (name, principle, effect, tell, light, plus a color token reference). `AtlasState` requires
  this module instead of owning the tables. Rationale: data must not live inside a render-state, or
  `FirstEncounter` would drag love-graphics deps in and risk a circular require.
  - Note: `artifactEntries` currently references `Theme.color.*` inline. Keep the color reference in
    `AtlasData` (Theme.color is a plain token table, safe to require headlessly); confirm during
    implementation that requiring `Theme` for color tokens alone does not pull `love.graphics`. If it
    does, store color tokens by name string and resolve in the renderer instead.

- **`src/gameplay/FirstEncounter.lua`** — pure logic service. API:
  - `FirstEncounter.shouldTeach(id) -> bool` — true if concept `id` is unseen.
  - `FirstEncounter.markTaught(id)` — mark seen + persist immediately.
  - `FirstEncounter.cardFor(id) -> table|nil` — `{ title, color, lines = {...}, atlasTab }`,
    or nil if `id` is unknown (e.g. artifact with no `AtlasData` entry).
  - `FirstEncounter.onArtifact(artifactType)` — convenience: normalize name to UPPER, if
    `shouldTeach("artifact:"..NAME)` enqueue the toast card and mark seen.
  - In-run toast queue: `pushToast(card)`, `update(dt)`, `peekToast()`, `dismissToast()`,
    `hasToast()`. Queue shows one card at a time; auto-timeout ~6s or manual dismiss.
  - No `love.graphics` calls. May call `love.timer`/`love.filesystem` indirectly via
    `MetaProgression`; acceptable for headless love test runner.

### Reused, not rebuilt

- Card visuals: `Shared.drawGlassPanel()` + `Theme` fonts (as `TutorialState` does).
- `PickupSystem:38` artifact hook (add one call alongside the existing one).
- `RunSummaryState` and `ProgressionState` as host surfaces for the two chroma cards.

### New UI module

- **`src/ui/FirstEncounterCard.lua`** — one renderer, two modes from the same draw code:
  - **toast**: edge-anchored, fade in/out, auto-timeout, non-blocking. Used in `PlayingState`.
  - **modal**: centered, dims background, blocks input until dismissed, shows
    `[SPACE] dismiss · [A] Atlas` footer. Used by the menu states.
  - Accent rim uses the concept color (artifact color from `AtlasData`).

## Data model

`MetaProgression` `DEFAULT_PROFILE` gains:

```lua
seenExplainers = {},   -- { ["artifact:PRISM"]=true, ["chroma_earned"]=true, ["chroma_spend"]=true }
```

- `ensureProfileShape`: whitelist `data.seenExplainers` as a table, copying only string keys whose
  value is `true`. Old saves without the field default to an empty table (every card teaches once for
  existing players too — intended).
- `save()`: include `seenExplainers` in the serialized profile.
- New helpers: `MetaProgression.hasSeenExplainer(id)`, `MetaProgression.markExplainerSeen(id)`
  (the latter sets the flag and calls the existing save path so it survives a crash/quit).

### Concept ids

| id                  | Trigger surface                                  | Copy source                                   | Card mode |
|---------------------|--------------------------------------------------|-----------------------------------------------|-----------|
| `artifact:<NAME>` ×8| first pickup of that artifact (`PickupSystem`)    | `AtlasData` entry: principle + effect + tell  | toast     |
| `chroma_earned`     | first RunSummary with `chromaEarned > 0`          | new 2-line string (below)                     | modal     |
| `chroma_spend`      | first `ProgressionState:enter`                    | new 2-line string (below)                     | modal     |

Two new strings only (artifact cards are generated from Atlas data):

- `chroma_earned`: "Chroma is permanent currency. You keep every Chroma you earn when a run ends —
  win or lose."
- `chroma_spend`: "Spend Chroma here to upgrade your artifacts. Upgrades are permanent and carry into
  every future run."

## Flow

**Artifact pickup (in-run, toast):**
1. `PickupSystem` collects an artifact → calls `FirstEncounter.onArtifact(type)` (alongside the
   existing `TutorialSystem.onArtifactCollected`, which is retired — see below).
2. If `shouldTeach("artifact:"..NAME)`: enqueue `cardFor(id)` as a toast, `markTaught(id)`.
3. `PlayingState:update(dt)` ticks `FirstEncounter.update(dt)`; `PlayingState:draw` renders
   `peekToast()` via the toast renderer. Combat never pauses. Multiple new artifacts in one frame
   queue and show sequentially.

**Chroma earned (run end, modal):** `RunSummaryState:enter` — if `chromaEarned > 0` and
`shouldTeach("chroma_earned")`, show the modal card over the summary; `markTaught` on dismiss.

**Chroma spend (Progression, modal):** `ProgressionState:enter` — if `shouldTeach("chroma_spend")`,
show the modal card; `markTaught` on dismiss. The "carry into every future run" line also seeds the
endgame mental model addressed by sub-project 3.

**Mark-seen timing (deliberate, per surface):** toast cards mark seen *on enqueue/show* because they
auto-time-out and have no guaranteed explicit dismiss; modal cards mark seen *on dismiss* because the
player explicitly closes them. Both persist immediately via `MetaProgression.markExplainerSeen`.

**Single-source rule:** retire `TutorialSystem.onArtifactCollected`'s generic `ARTIFACT` popup so
artifact teaching has exactly one owner. Leave the color and synergy popups untouched (out of scope).

## Edge cases

- Unknown artifact type (no `AtlasData` entry) → `cardFor` returns nil → no card, no crash.
- Artifact name casing normalized to UPPER for both `AtlasData` lookup and flag id.
- Multiple unseen artifacts same frame → queue, show one at a time, never overlap.
- Old profiles lacking `seenExplainers` → empty default → each card fires once.
- Independent of `tutorialEnabled`: cards fire whether the color tutorial is on, off, or completed.
- Web build → pure Lua + existing UI; no `Runtime.isWeb()` branch needed.

## Testing

LÖVE is installed at `C:\Program Files\LOVE` (`lovec.exe` flushes stdout on exit).

1. **Headless logic test** — a minimal love harness (its own `main.lua` under a throwaway test dir,
   or a debug entry) that requires `FirstEncounter` + `AtlasData`, stubs/uses `MetaProgression`, and
   asserts: `shouldTeach` true on first call, false after `markTaught`; `cardFor("artifact:PRISM")`
   returns the expected title/lines; `cardFor` for an unknown id returns nil. Run with
   `"C:\Program Files\LOVE\lovec.exe" <testdir> > out.txt 2>&1` and read `out.txt`.
2. **Debug reset hotkey** — gated by `Config.debug.enabled`: clears `seenExplainers` so every card is
   repeatably re-triggerable in one session.
3. **Manual pass** — fresh profile: grab an artifact (toast appears once, never again) → finish a run
   (earned card) → open Progression (spend card). Confirm each fires exactly once and survives a
   restart.

## Out of scope (separate specs)

- Difficulty tuning ("too easy") — sub-project 2.
- Endgame loop beyond boss + artifact upgrades — sub-project 3.
- Reworking the color-theory `TutorialSystem` arc or the `OnboardingSequence` movement beats.
