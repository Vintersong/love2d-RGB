---
name: audit-findings-2026-05
description: Deep-audit findings (2026-05-31) — bugs, dead code, doc drift; not yet fixed
metadata:
  type: project
---

Deep audit done 2026-05-31. Nothing crashing; mostly dead code, latent bugs, and doc drift. Not yet fixed (user digesting). Priority order:

**Bugs — FIXED 2026-05-31:**
- ✅ `ArtifactManager.lua:209` — SUPERNOVA artifact L1 now binds L-Shift to `SUPERNOVA` (was mis-wired to `LIGHTNING_BOLT`). This also removes lightning from gameplay (it was *only* reachable via this line) AND fixes the never-working Supernova ultimate.
- ✅ `PlayerCombat.lua` `splitProjectile` — splitCount clamped `math.max(2, ...)`; dead `angleStep` removed.
- ✅ README — fixed ProceduralEnemy spawning claim (now `Enemy.lua`) and "Eight"→"Nine" artifacts.
- ✅ `AttackSystem.lua` applyEffects — root now guards `if not target.rooted` before capturing originalSpeed/applying slow, so re-rooting can't bake in a permanent slow. (Still latent overall: `ColorSystem` never sets `rootChance`>0, so root is disconnected.)
- ✅ Deleted dead methods `Weapon:getColorString` and `Enemy:checkCollision` (zero callers).
- ✅ DEAD-CODE SWEEP done: deleted files `LightningEffect.lua`, `ProceduralEnemy.lua`, `EnemyAbilities.lua`, `XPOrb.lua`, `Drop.lua`, `BaseArtifact.lua`; removed all lightning wiring (main.lua require+registerSystem, AbilityLibrary.LIGHTNING_BOLT, Config.lightning, Player register/useLightningBolt/useActiveAbility branch/lastEnemies caching, PlayingState+PlayingUpdateLoop+PlayingRenderLayers deps); removed dead `BossSystem.checkSpawn`. Boots clean.

- ✅ MAGENTA dash fixed (`AbilityLibrary.lua`): renamed dead `"PURPLE"` → `"MAGENTA"` in the dash damage gates, so magenta dash now deals the 20 instant + impact VFX like BLUE/YELLOW, and its DoT now uses the real `dotStacks` system (3s @ 5/tick) processed by `AttackSystem.updateDoTs`.

**Bugs — FIXED 2026-05-31 (session 2):**
- ✅ Split children now inherit ALL secondary effects (`PlayerCombat.splitProjectile`): bounce/pierce/explode/dot/root, using the canonical Weapon.lua field names (`canBounceToNearest`/`maxBounces`, `canPierce`/`maxPierces`, `canExplode`/`explodeRadius`/`explodeDamage`, `canDot`/`dotDuration`/`dotDamage`, `canRoot`/`rootDuration`) + `speed`. The old code used dead field names (`canBounce`/`bounces`/`pierce`) the live systems never read.
- ✅ Dash *instant* damage now routes through `HealthSystem.takeDamage` (`AbilityLibrary.lua` checkCollisions). Added `getHealthSystem` lazy loader. `PlayingUpdateLoop` now wraps `checkDashCollisions` in a `captureAliveEnemies`→`rewardNewEnemyDeaths` sweep so dash-only kills grant XP/drops.
- `Weapon:getColorString` — already deleted in session 1; remove this line if seen again.

**Boss affinity — IMPLEMENTED 2026-05-31 (session 2):** bonus-only, 1.25x, no resist (user call). `Config.boss.affinity` = `{bonus=1.25, weak={berserker="BLUE", mage="RED", warrior="GREEN"}}` (weak colors are starting values, tunable). `Weapon.applyAbilities` tags each projectile with `proj.colorName = dominantColor`. `BossCoordinator:53` passes `proj.colorName` into `BossSystem:takeDamage(amount, colorName)`, which multiplies by `bonus` when the projectile color matches the archetype's weak color. Regular enemies never hit this path → stay affinity-free by design.

**Dead code (see [[orphaned-and-dead-code]] decision):** ProceduralEnemy+EnemyAbilities (user retired — enemy projectiles caused clutter), XPOrb, Drop, BaseArtifact. Dead methods: `Enemy:checkCollision`, `BossSystem.checkSpawn`. LIGHTNING_BOLT ability + LightningEffect + Config.lightning (being removed).

**Doc drift:** README:68 says ProceduralEnemy drives spawning (false — it's `Enemy.lua`); README "Eight artifacts" but 9 exist (incl. Aurora).

**Verified clean:** reverse-iteration removal loops, enemy pool reset, collision-world sync, `_deathRewarded` guard, no ability-system cross-run leak (unregister on destroy).

**Boss affinity:** DONE (see "Boss affinity — IMPLEMENTED" above). `BossSystem:takeDamage(amount, colorName)` now applies the bonus.

Lightning removal touches: AbilityLibrary.LIGHTNING_BOLT, LightningEffect.lua, Config.lightning, Player (register/useLightningBolt/useActiveAbility branch/lastEnemies), ArtifactManager:212, PlayingUpdateLoop/RenderLayers update+draw. NOTE: SynergySystem "lightning"-themed entries are separate flavor, not the bolt ability — leave them.
