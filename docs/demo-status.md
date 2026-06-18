# CHROMATIC — Demo Status

Production tracker for screen/state design completion ahead of the **demo/beta**.
This is the source of truth for "is this screen done?" — a project-management fact,
not a runtime one. The engine does **not** read this file.

_Last updated: 2026-06-18_

## Legend

| Status | Meaning |
|--------|---------|
| **Final** | Design locked. Won't change before the demo ships. |
| **WIP** | Exists and functional; actively being polished. |
| **Placeholder** | Stub / minimal / not a real design yet. |
| **Dev tool** | Internal-only; excluded from the demo build. |

> ⚠️ Only **Splash** is confirmed Final by the team. Every other status below is a
> best-guess starting point from the state's description/tags and **needs review**.
> Adjust the Status column as you audit each screen.

## States

States as registered in `main.lua` (`StateManager.register`).

| State | Description | Status | In demo? | What's left / notes |
|-------|-------------|--------|----------|---------------------|
| **Splash** | Initial splash screen | **Final** | ✅ Critical | Confirmed complete. |
| **Menu** | Main menu screen | WIP | ✅ Critical | Entry hub — needs final layout/copy pass. |
| **Loading** | Run loading & preparation | WIP | ✅ Critical | Transition into Playing; confirm visuals/timing. |
| **Playing** | Main gameplay state | WIP | ✅ Critical | Core loop. Likely the largest remaining polish surface. |
| **LevelUp** | Color upgrade selection | WIP | ✅ Critical | Cards now animated (UIAnimator) — needs feel tuning + sign-off. |
| **GameOver** | Game over screen | WIP | ✅ Critical | Color build shown as 6-orb row — recently revised, needs sign-off. |
| **RunSummary** | Post-run summary & unlock recap | WIP | ✅ Critical | Closes the demo loop back to Menu. |
| **Victory** | Victory screen | WIP | 🔶 Conditional | Only if the demo is winnable; otherwise defer. |
| **Pause** | Pause overlay | WIP | 🔶 Supporting | Reachable mid-run; should be polished but not on the spine. |
| **Options** | Options & settings menu | WIP | 🔶 Supporting | Reachable from Menu; trim to demo-relevant settings. |
| **Tutorial** | Onboarding & replayable tutorial deck | WIP | 🔶 Supporting | First-run onboarding; strong demo value if polished. |
| **Confirm** | Generic confirmation modal | WIP | 🔶 Utility | Shared modal used by other states; finalize alongside its callers. |
| **Atlas** | Color & artifact reference | Placeholder | ❌ Deferred | Reference content; likely out of demo scope. |
| **Progression** | Persistent profile & unlocks | Placeholder | ❌ Deferred | Meta-progression; demo may ship without it. |
| **UISandbox** | HUD sandbox | Dev tool | ❌ Excluded | Debug-only (`tags = {"menu","debug"}`); never in demo build. |

## Demo critical path

The demo is defined by a **critical path** — the narrow sequence a player actually
traverses — not by "whichever screens happen to be done." Finish these in order;
everything off the path is secondary.

```
Splash ─► Menu ─► Loading ─► Playing ─► GameOver ─► RunSummary ─► Menu
                               │  ▲          ▲
                               ▼  │          │ (Victory, if winnable)
                            LevelUp          │
                          (mid-run loop)     │
                               │             │
                            Pause ───────────┘ (resume / quit)
```

**Spine (must be Final for the demo):**
1. **Splash** → 2. **Menu** → 3. **Loading** → 4. **Playing**
   → 5. **LevelUp** (repeats during the run) → 6. **GameOver** → 7. **RunSummary** → back to **Menu**

**Supporting (reachable from the spine — polish, but lower priority):**
- **Pause** (during Playing)
- **Options** (from Menu)
- **Tutorial** (first-run onboarding before Playing)
- **Confirm** (modal invoked by Menu/Options/quit flows)
- **Victory** (only if the demo can be won)

**Deferred / excluded from the demo:**
- **Atlas**, **Progression** (meta features — can ship post-demo)
- **UISandbox** (dev tool)

## Suggested finishing order

1. **Playing** — biggest surface, gates everything; the demo lives or dies here.
2. **Menu** — first interactive impression after Splash.
3. **LevelUp** + **GameOver** — already revised; do the sign-off passes.
4. **Loading** + **RunSummary** — short transitions that bookend the loop.
5. **Pause**, **Tutorial**, **Options** — supporting polish.
6. Decide **Victory** in/out based on whether the demo is winnable.

## Open questions

- Is the demo **winnable** (→ Victory on the path) or survival-only (GameOver only)?
- Does the demo include **meta-progression** (Progression/unlocks) or is each run standalone?
- Is **Tutorial** forced on first run, optional, or cut from the demo?
