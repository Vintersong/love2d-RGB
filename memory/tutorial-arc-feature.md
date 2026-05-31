---
name: tutorial-arc-feature
description: How the guided color-theory tutorial arc is wired into the game
metadata:
  type: project
---

Guided one-off tutorial arc (built 2026-05-30). Controller is `src/gameplay/TutorialSystem.lua`; it never changes color math, only restricts level-up choices and queues popups at COLOR-level milestones (per user: "level 10/20 etc are the levels of each color", which matches `ColorSystem` `>=10` secondary-unlock gate).

Phases: RED (force red until RED color lvl 10 → RED popup) → COMMIT (offer only the 2 non-red primaries, green recommended) → SECOND (force chosen 2nd primary until lvl 10 → its popup + the secondary-unlock popup) → FREE (no restriction). Arc completes when the secondary (YELLOW for green / MAGENTA for blue) unlocks.

Wiring:
- `LevelUpState` calls `TutorialSystem.filterChoices()` / `getRecommendedCode()` / `onColorAdded()` / popup peek+dismiss. Popups render in LevelUpState (reuses its pause). `selectColor` stays open while a popup is pending.
- `PlayingState` run-init calls `TutorialSystem.beginRun()` after `ColorSystem.init()`.
- Toggle: `Config.gameplay.tutorialEnabled`, exposed in `OptionsState` GAMEPLAY tab.
- Persistence: `src/core/Settings.lua` writes `settings.lua` via love.filesystem; `Settings.load()` runs in `main.lua` love.load. One-off = a completed arc auto-sets tutorialEnabled=false and saves; dying before completion leaves it on to retry.

Deferred (not built): the doc's level-40 capstone mirror-boss (C=defer). Yellow is velocity + inherited spread/bounce, NOT blast wave — see [[yellow-no-blast-wave]].
