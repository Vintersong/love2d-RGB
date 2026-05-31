---
name: yellow-no-blast-wave
description: Yellow secondary color has no "blast wave"; that doc idea is stale
metadata:
  type: project
---

`TUTORIAL.MD` and some older design notes describe YELLOW (RED+GREEN secondary) as a "blast wave" mechanic. That is stale / abandoned. The live behavior in `src/gameplay/ColorSystem.lua` `applyEffects` is: yellow = velocity/electric (`fireRate * 0.85`) and it inherits RED spread + GREEN bounce through the primary traits. No unique projectile effect, no blast wave.

**Why:** A prior Claude instance wrote the blast-wave framing into TUTORIAL.MD; the user confirmed it's based on old ideas and that current projectile behavior is canonical.

**How to apply:** When building tutorial popups or docs, frame yellow as velocity + inherited spread/bounce, not blast wave. Trust `ColorSystem.lua` over the design doc on color mechanics. See [[tutorial-arc-feature]].
