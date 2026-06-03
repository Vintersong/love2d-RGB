# GameOverState Redesign — Design Spec
**Date:** 2026-06-03  
**Scope:** `src/states/GameOverState.lua` rewrite in-place  
**Branch:** devBranch

---

## Goal

Replace the raw-print fail screen with a full dedicated screen that matches the CHROMATIC design system — background shader, Theme tokens, bracket buttons, Michroma/Chakra Petch typefaces.

---

## Architecture

- `GameOverState` becomes a self-contained full-screen state, same shape as `MenuState`.
- **World rendering removed:** `World.draw()`, `player:draw()`, and the enemy loop are dropped entirely. No game world visible behind the screen.
- **BackgroundShader** drives the animated neon environment (already used by MenuState).
- **Fade-in only:** a single `alpha` value lerps 0→1 over 0.4s on enter. No fadeOut state machine — keypresses switch state immediately.
- **Data received via `enter(previous, data)`:** same as current — `data.player`, `data.musicReactor`. `musicReactor` kept for `update()` only (audio continuity), not used for visual reactivity.
- **No new files.** `GameOverState.lua` is rewritten in-place.

---

## Layout & Content

Vertically centered column, three zones at 1920×1080:

```
SIGNAL LOST          Michroma "display" font, 75px, Theme.color.danger

── thin rule ──       1px line, 40% screen width, Theme.color.accent

Level 12             ChakraPetch uiSemiBold 24px, fg1
Color Path:          ChakraPetch ui 16px, fg3 (label)
RED → MAGENTA        each segment in its own Theme.color token

Damage  140          ShareTechMono micro 12px, fg2

[ RESTART ]          bracket button, accent when focused
[ QUIT    ]          bracket button, fg3 unfocused / fg1 focused
```

**Content decisions:**
- Title is `SIGNAL LOST` (fits CHROMATIC identity). One-word swap to `GAME OVER` if preferred.
- Color path segments each render in their own `Theme.color` value so the line reads as colored text.
- `Continue (Endless Mode)` option removed — was a debug escape hatch, not a designed player choice.
- Keyboard hints (`R`, `ESC` text labels) removed; bracket buttons are the affordance.

---

## Visual Language

**Colors:** All via `Theme.setColor()` — no raw hardcoded floats.
| Element | Token |
|---|---|
| Title | `danger` |
| Rule + focused button | `accent` |
| Stats label | `fg3` |
| Stats value | `fg1` |
| Unfocused button | `fg3` |
| Dark overlay (over shader) | `bgVoid` at 0.85 alpha |

**Typefaces** (all via `Theme.font()`):
| Role | Font | Size |
|---|---|---|
| Title | `display` (Michroma) | 75px |
| Level / path | `uiSemiBold` (Chakra Petch) | 24px |
| Labels | `ui` (Chakra Petch) | 16px |
| Stat values | `mono` (Share Tech Mono) | 12px |

**Bracket buttons:** Copy draw pattern from `MenuState` — side brackets `[` `]` expand outward on focus. `accent` when selected, `fg3` when not.

**Keyboard:** `up`/`down` move selection; `return`/`space` confirm; `r` directly triggers RESTART; `escape` directly triggers QUIT.

**Fade-in:**
```lua
alpha = math.min(1, alpha + dt / 0.4)
-- entire draw pass wrapped in love.graphics.setColor(1,1,1,alpha)
```

**Not included (can be added later without restructuring):** particles, ship renderer, music-reactive glow.

---

## What Changes vs. Current

| Current | After |
|---|---|
| `World.draw()` + frozen enemies behind overlay | Background shader only |
| Raw `love.graphics.print` with hardcoded colors | `Theme.font()` + `Theme.setColor()` throughout |
| Emoji strings ("💀 GAME OVER 💀") | Clean Michroma title |
| Plain text keyboard hints | Bracket buttons with keyboard nav |
| "Continue Endless Mode" option | Removed |
| No fade | 0.4s fade-in |
