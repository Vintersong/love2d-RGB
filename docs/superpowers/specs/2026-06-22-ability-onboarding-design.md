# Ability Onboarding Segment ("Phase 0") — Design

**Date:** 2026-06-22
**Status:** Approved (design), pending implementation plan
**Scope:** Teach new players the moment-to-moment controls (movement + abilities) through a live, gated in-game segment that runs *before* the existing color-theory tutorial arc.

---

## 1. Problem

New players get no proper onboarding for **which key is which ability, what it does, or how it feeds into gameplay**. Today:

- `src/states/menu/TutorialState.lua` is a passive 5-slide *menu* deck about color theory. It never mentions Dash, Blink, Shield, or even auto-fire.
- `src/gameplay/TutorialSystem.lua` is a live **color arc** layered on level-ups: it forces RED → COMMIT to a 2nd primary → SECOND → FREE and queues skippable popups. It teaches color identity only — nothing about movement or abilities.

So a player learns the *philosophy* of color but not a single control.

### Stale-docs note (real bug surfaced during design)

`README.md` and `DESIGN_DOC.md` (§3, §8.3) still describe a **Left-Shift "SUPERNOVA ultimate"**. This binding does **not exist** in code. `PlayingInputHandlers.keypressed` binds only Space (Dash), E (Blink), Q (Shield), P/Esc (Pause), plus WASD movement. Supernova is now a **passive artifact effect** (`Player.supernovaPassive` → `ArtifactManager.triggerReactiveSupernova`). Teaching a dead binding would be worse than nothing, so doc cleanup is folded into this feature.

---

## 2. Goal

A **live-gameplay onboarding segment** ("phase 0") that runs at the very start of a guided run, before the color arc. The player physically performs each control, gated step by step, then is handed off seamlessly into a real run where the existing color arc takes over at the first level-up.

Full tutorial flow becomes:

```
Movement → Abilities   (NEW — phase 0, live play)
        ↓
Colors                 (EXISTING TutorialSystem: RED → COMMIT → SECOND → FREE, at level-ups)
```

---

## 3. The Beats

Each beat shows an in-game prompt card (keycap glyph + ability name + a one-line tactical "why") and is **gated** — it does not advance until the player performs the action.

| # | Beat | Key | Gate (advances when…) | Tactical "why" line |
|---|------|-----|----------------------|---------------------|
| 1 | **Move** | WASD | player moves a short minimum distance | "Position is your weapon — you'll never aim manually." |
| 2 | **Auto-fire** | — (passive) | a dummy enemy dies to the auto-beam | "You fire automatically at the nearest enemy." |
| 3 | **Dash** | Space | dash used once (`Player:useDash()` returns true) | "Reposition / escape. Its effect changes with your color." |
| 4 | **Blink** | E | blink used once (`Player:useBlink()` returns true) | "Instant teleport out of danger. 5s cooldown." |
| 5 | **Shield** | Q | shield used once (`Player:useShield()` returns true) | "Negate a hit you can't dodge. 10s cooldown." |
| — | **Hand-off** | — | automatic after beat 5 | "You're ready. Survive." → normal spawning + color arc begin |

**Per-beat skip:** none — the player must perform each beat so the binding is actually learned. The whole segment still respects the Options `tutorialEnabled` toggle (so returning players never see it). A single global "hold ESC to skip onboarding" escape hatch is in scope as a safety valve.

---

## 4. Safety & Pacing

During phase 0 the player **cannot die**:

- Normal `SpawnController` spawning is suppressed while `OnboardingSequence.isActive()` is true (gated in `PlayingEnemyFlow`).
- Beat 2 spawns 1–2 slow, harmless dummy enemies purely for the auto-fire lesson.
- After the hand-off, normal spawning resumes and the run is real (full stakes, XP, level-ups).

---

## 5. Architecture

### New module: `src/gameplay/OnboardingSequence.lua`
Owns phase-0 beat state, gating logic, current-prompt copy, and completion. Mirrors `TutorialSystem`'s shape (module-table, `beginRun()` / `isActive()` / tick / completion). Deliberately **separate** from `TutorialSystem` so the color arc stays single-purpose; the two share only the on/off flag and the "play once" persistence.

Public surface (sketch):
- `OnboardingSequence.beginRun()` — reset to beat 1 if `tutorialEnabled`, else inert.
- `OnboardingSequence.isActive()` — true while beats remain (used to gate spawns).
- `OnboardingSequence.update(dt, ctx)` — advances movement / auto-fire-kill detection.
- `OnboardingSequence.notifyAbilityUsed(kind)` — called on successful dash/blink/shield.
- `OnboardingSequence.currentPrompt()` — `{ key, icon, name, line }` or nil for the renderer.
- `OnboardingSequence.skip()` — global escape hatch.
- `OnboardingSequence.complete()` — finalize phase 0 (does **not** disable the toggle by itself; see §6).

### New in-game prompt renderer
A small prompt card drawn in `PlayingRenderLayers` (centered/bottom), keycap via `src/render/Icons.lua`, body via `Theme` fonts. Required because `LevelUpState`'s existing popup path only renders inside the frozen level-up overlay and cannot draw during live play.

### Hook points (all already clean)
- `PlayingState` init: call `OnboardingSequence.beginRun()` alongside `TutorialSystem.beginRun()` (PlayingState.lua:79).
- `PlayingUpdateLoop`: tick `OnboardingSequence.update(dt, ...)`; detect movement and auto-fire kills.
- `PlayingInputHandlers`: on successful `useDash` / `useBlink` / `useShield`, call `OnboardingSequence.notifyAbilityUsed(...)`; route "hold ESC to skip" while active.
- `PlayingEnemyFlow` / `SpawnController`: suppress normal spawns while `OnboardingSequence.isActive()`.
- `PlayingRenderLayers`: draw `OnboardingSequence.currentPrompt()`.

---

## 6. Persistence & Replay

Reuses the existing `Config.gameplay.tutorialEnabled` flag + `src/core/Settings.lua` save path — the same one-off behavior the color arc already uses:

- New players: phase 0 plays, then the color arc plays.
- The toggle auto-disables only after the **whole** guided experience completes. Today `TutorialSystem.complete()` disables the flag when the color arc finishes; that remains the single point that turns the toggle off, so phase 0 completing does **not** prematurely disable anything. (If a player dies mid-onboarding, the flag stays on and the tutorial retries next run, matching current behavior.)
- Re-enabled via the existing Options toggle.

The menu deck (`TutorialState`) and its "REPLAY TUTORIAL" entry in `ProgressionState` are left unchanged (out of scope).

---

## 7. Docs Cleanup (folded in)

Update `README.md` and `DESIGN_DOC.md` (§3 controls table, §8.3 UI) to remove the Left-Shift Supernova "ultimate" binding and describe Supernova as a passive artifact effect, so the docs and the new tutorial agree.

---

## 8. Out of Scope (YAGNI)

- No changes to the color arc beats/popups themselves.
- No changes to the menu `TutorialState` slide deck.
- No new artifacts, abilities, or progression/meta changes (the meta-progression brainstorm is a separate, later spec).
- No animated mini-sim preview boxes — teaching happens in the real playfield, not a preview canvas.

---

## 9. Success Criteria

- A brand-new profile, on first run, is walked through Move → Auto-fire → Dash → Blink → Shield with gated in-game prompts, cannot die during the segment, then transitions into a normal run whose first level-up begins the forced-RED color arc.
- Each beat will not advance until its action is performed; "hold ESC" skips the whole segment.
- Returning players (toggle off) never see phase 0.
- `love .` boots clean; README/DESIGN_DOC no longer reference a Left-Shift Supernova binding.
