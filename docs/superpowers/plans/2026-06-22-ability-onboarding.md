# Ability Onboarding ("Phase 0") Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a live, gated in-game onboarding segment that teaches Move → auto-fire → Dash → Blink → Shield before the existing color-theory tutorial arc, then hands off into a normal run.

**Architecture:** A new self-contained `OnboardingSequence` module owns a beat state-machine driven from the existing `PlayingState` update loop. It gates normal enemy spawning and contact damage while active (player can't die), renders an in-game prompt card, and advances each beat only when the player performs the action. It deliberately does **not** touch the color-arc `TutorialSystem`; the two share only the `Config.gameplay.tutorialEnabled` flag.

**Tech Stack:** Lua, LÖVE 11.5, `hump.gamestate`. No automated test suite (per CLAUDE.md) — every task is verified by running `love .` (boots clean, no Lua errors) plus a specific observed-behavior check. Console prints (`Config.debug.enabled = true`) are the primary behavioral signal.

## Global Constraints

- LÖVE **11.5**, fixed **1920×1080**. Developed on Windows; `love .` from repo root, or invoke `love.exe`/`lovec.exe` directly if `love` is not on PATH.
- Every tunable belongs in `src/Config.lua` (required as `"src.Config"`). Don't hardcode balance numbers elsewhere.
- Modules return a table; PascalCase module names; `Module.method(...)` call style; `local X = require("...")` grouped at the top of the file.
- Do NOT require or wire in anything under `reference/donor/**`, `src/utils/legacy/**`, or `dist/**`.
- No automated tests exist for game code. "Verify it fails / passes" means: run the game and observe the stated console output / on-screen behavior.
- To capture a boot log on Windows (flushes on exit): `lovec.exe . > boot.log 2>&1` then read `boot.log`. (Plain `love .` opens a window; close it to end.)
- Supernova is a **passive** artifact effect — there is no Left-Shift binding. Do not reintroduce one.

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `src/gameplay/OnboardingSequence.lua` | Phase-0 beat state machine: beats data, gating, prompt copy, skip, completion | Create |
| `src/ui/OnboardingPrompt.lua` | Draws the in-game prompt card from a prompt table | Create |
| `src/states/gameplay/PlayingState.lua` | Run init — call `OnboardingSequence.beginRun()` | Modify (`:79`) |
| `src/states/gameplay/playing/PlayingUpdateLoop.lua` | Tick onboarding; suppress normal spawns while active | Modify |
| `src/states/gameplay/playing/PlayingEnemyFlow.lua` | Suppress contact-damage death while onboarding active | Modify (`updateEnemies`) |
| `src/states/gameplay/playing/PlayingInputHandlers.lua` | Report dash/blink/shield; swallow ESC/P while active | Modify (`keypressed`) |
| `src/states/gameplay/playing/PlayingRenderLayers.lua` | Draw the onboarding prompt | Modify (`draw`) |
| `README.md`, `DESIGN_DOC.md` | Remove stale Left-Shift Supernova references | Modify |

---

## Task 1: OnboardingSequence module + run wiring + spawn/death suppression

Creates the full beat state machine and wires it so a fresh run starts in phase 0: normal spawns are suppressed, the player can't take contact damage, and the **Move** and **Auto-fire** beats advance on their own (dash/blink/shield wiring comes in Task 3; prompt rendering in Task 2). Verified via console.

**Files:**
- Create: `src/gameplay/OnboardingSequence.lua`
- Modify: `src/states/gameplay/PlayingState.lua:79`
- Modify: `src/states/gameplay/playing/PlayingUpdateLoop.lua`
- Modify: `src/states/gameplay/playing/PlayingEnemyFlow.lua`

**Interfaces:**
- Consumes: `Config.gameplay.tutorialEnabled` (bool); `src.entities.Enemy` constructor `Enemy(x, y)`; `state.player` with `.x`, `.y`, `.width`, `.height`; `state.enemies` (array).
- Produces (used by later tasks):
  - `OnboardingSequence.beginRun()` → nil
  - `OnboardingSequence.isActive()` → bool
  - `OnboardingSequence.update(dt, player, state)` → nil
  - `OnboardingSequence.notifyAbilityUsed(kind)` → nil  (`kind` ∈ `"dash"|"blink"|"shield"`)
  - `OnboardingSequence.currentPrompt()` → `{ key, name, line, index, total, skipHint }` or nil
  - `OnboardingSequence.skip()` → nil

- [ ] **Step 1: Create the OnboardingSequence module**

Create `src/gameplay/OnboardingSequence.lua`:

```lua
-- OnboardingSequence.lua
-- Phase-0 onboarding: gated, live-gameplay beats teaching movement + abilities
-- before the color-theory TutorialSystem arc takes over at level-ups. Runs only
-- when Config.gameplay.tutorialEnabled is true. It does NOT toggle that flag
-- itself -- TutorialSystem.complete() owns disabling it after the color arc ends.

local Config = require("src.Config")

local OnboardingSequence = {}

local BEATS = {
    { id = "move",     key = "WASD",  name = "MOVE",      line = "Position is your weapon - you never aim manually." },
    { id = "autofire", key = nil,     name = "AUTO-FIRE", line = "You fire automatically at the nearest enemy." },
    { id = "dash",     key = "SPACE", name = "DASH",      line = "Reposition or escape. Its effect changes with your color." },
    { id = "blink",    key = "E",     name = "BLINK",     line = "Instant teleport to your cursor. 5s cooldown." },
    { id = "shield",   key = "Q",     name = "SHIELD",    line = "Negate a hit you can't dodge. 10s cooldown." },
}

local MOVE_DISTANCE = 250    -- px of cumulative movement to clear the MOVE beat
local SKIP_HOLD_TIME = 1.0   -- seconds holding ESC to skip onboarding

local active = false
local index = 1
local movedDistance = 0
local lastX, lastY = nil, nil
local dummies = nil          -- tracked AUTO-FIRE lesson enemies
local skipHold = 0

local function currentBeat()
    return BEATS[index]
end

function OnboardingSequence.beginRun()
    active = (Config.gameplay.tutorialEnabled == true)
    index = 1
    movedDistance = 0
    lastX, lastY = nil, nil
    dummies = nil
    skipHold = 0
    if active then
        print("[Onboarding] Phase 0 started - MOVE beat")
    end
end

function OnboardingSequence.isActive()
    return active
end

local function advance()
    index = index + 1
    dummies = nil
    if index > #BEATS then
        active = false
        print("[Onboarding] Phase 0 complete - handing off to normal run")
    else
        print("[Onboarding] Beat -> " .. BEATS[index].id)
    end
end

-- Spawn the harmless dummy enemies used by the AUTO-FIRE beat. They are NOT added
-- to the collision world, so they never deal contact damage; auto-fire still
-- targets them via the enemies list.
local function spawnDummies(state)
    local Enemy = require("src.entities.Enemy")
    dummies = {}
    local px = state.player.x + state.player.width / 2
    local py = state.player.y + state.player.height / 2
    for i = 1, 2 do
        local angle = -math.pi / 2 + (i - 1.5) * 0.5
        local dx = px + math.cos(angle) * 260
        local dy = py + math.sin(angle) * 260
        local dummy = Enemy(dx, dy)
        table.insert(state.enemies, dummy)
        dummies[#dummies + 1] = dummy
    end
end

function OnboardingSequence.update(dt, player, state)
    if not active then return end

    -- ESC-hold skip.
    if love.keyboard.isDown("escape") then
        skipHold = skipHold + dt
        if skipHold >= SKIP_HOLD_TIME then
            OnboardingSequence.skip()
            return
        end
    else
        skipHold = 0
    end

    local beat = currentBeat()
    if beat.id == "move" then
        if lastX then
            local dx, dy = player.x - lastX, player.y - lastY
            movedDistance = movedDistance + math.sqrt(dx * dx + dy * dy)
        end
        lastX, lastY = player.x, player.y
        if movedDistance >= MOVE_DISTANCE then
            advance()
        end
    elseif beat.id == "autofire" then
        if not dummies then
            spawnDummies(state)
        else
            for _, dummy in ipairs(dummies) do
                if dummy.dead then
                    advance()
                    return
                end
            end
        end
    end
    -- dash/blink/shield beats advance via notifyAbilityUsed.
end

function OnboardingSequence.notifyAbilityUsed(kind)
    if not active then return end
    if currentBeat().id == kind then
        advance()
    end
end

function OnboardingSequence.currentPrompt()
    if not active then return nil end
    local beat = currentBeat()
    return {
        key = beat.key,
        name = beat.name,
        line = beat.line,
        index = index,
        total = #BEATS,
        skipHint = "Hold ESC to skip",
    }
end

function OnboardingSequence.skip()
    if not active then return end
    active = false
    print("[Onboarding] Skipped by player")
end

return OnboardingSequence
```

- [ ] **Step 2: Wire `beginRun()` into run start**

In `src/states/gameplay/PlayingState.lua`, find line 79:

```lua
    require("src.gameplay.TutorialSystem").beginRun()
```

Add immediately after it:

```lua
    require("src.gameplay.OnboardingSequence").beginRun()
```

- [ ] **Step 3: Tick onboarding + suppress normal spawns in the update loop**

In `src/states/gameplay/playing/PlayingUpdateLoop.lua`, add the require at the top of the file (after line 2, the `RunSummary` require):

```lua
local OnboardingSequence = require("src.gameplay.OnboardingSequence")
```

Then find this block (currently lines 57–61):

```lua
    state.player:autoFire(state.enemies, BossCoordinator.getActiveBoss())

    ShieldEffect.update(dt)
    SpawnController.update(dt, state.player.level, state.musicReactor, state.enemies)
    state.enemyKillCount = SpawnController.enemyKillCount
```

Replace it with:

```lua
    state.player:autoFire(state.enemies, BossCoordinator.getActiveBoss())

    OnboardingSequence.update(dt, state.player, state)

    ShieldEffect.update(dt)
    if not OnboardingSequence.isActive() then
        SpawnController.update(dt, state.player.level, state.musicReactor, state.enemies)
    end
    state.enemyKillCount = SpawnController.enemyKillCount
```

- [ ] **Step 4: Suppress contact-damage death while onboarding is active**

In `src/states/gameplay/playing/PlayingEnemyFlow.lua`, add the require at the top (after line 2, the `RunSummary` require):

```lua
local OnboardingSequence = require("src.gameplay.OnboardingSequence")
```

Then in `PlayingEnemyFlow.updateEnemies`, find the colliding-enemies contact loop (currently lines 75–100):

```lua
    local collidingEnemies = CollisionSystem.checkPlayerEnemyCollisions(state.player)
    for _, enemy in ipairs(collidingEnemies) do
```

Wrap the whole `for` loop in an onboarding guard so no contact damage is applied during phase 0:

```lua
    local collidingEnemies = CollisionSystem.checkPlayerEnemyCollisions(state.player)
    if not OnboardingSequence.isActive() then
    for _, enemy in ipairs(collidingEnemies) do
```

…and add the matching closing `end` after that loop's existing closing `end` (the loop currently ends at line 100, just before `end` of the function at line 101). The structure becomes:

```lua
        if died then
            local StateManager = require("src.core.StateManager")
            StateManager.switch("GameOver", {
                ...
            })
            return
        end
    end
    end   -- <-- new: closes the `if not OnboardingSequence.isActive()` guard
end
```

- [ ] **Step 5: Verify it boots and phase 0 is active**

Run: `lovec.exe . > boot.log 2>&1` (close the window after ~10s of play: move with WASD, then let auto-fire kill the two dummies). Then read `boot.log`.
Expected console lines, in order:
```
[Onboarding] Phase 0 started - MOVE beat
[Onboarding] Beat -> autofire
[Onboarding] Beat -> dash
```
(It stalls at `dash` because the ability hooks land in Task 3 — that's expected here.) Also expected: **no waves of formation enemies spawn** at run start (only the 2 dummies appear once you've moved). No Lua error traceback in the log.

- [ ] **Step 6: Commit**

```bash
git add src/gameplay/OnboardingSequence.lua src/states/gameplay/PlayingState.lua src/states/gameplay/playing/PlayingUpdateLoop.lua src/states/gameplay/playing/PlayingEnemyFlow.lua
git commit -m "feat(tutorial): phase-0 onboarding state machine + spawn/death suppression"
```

---

## Task 2: In-game prompt card renderer

Draws the current beat's prompt (keycap + name + tactical line + step indicator) at the bottom of the playfield during phase 0.

**Files:**
- Create: `src/ui/OnboardingPrompt.lua`
- Modify: `src/states/gameplay/playing/PlayingRenderLayers.lua`

**Interfaces:**
- Consumes: `OnboardingSequence.currentPrompt()` → `{ key, name, line, index, total, skipHint }`; `src.render.Theme` (`Theme.font(role, size)`, `Theme.color.{accent,fg1,fg2,fg3}`); `Config.screen.{width,height}`.
- Produces: `OnboardingPrompt.draw(prompt)` → nil.

- [ ] **Step 1: Create the prompt renderer**

Create `src/ui/OnboardingPrompt.lua`:

```lua
-- OnboardingPrompt.lua
-- Renders a single phase-0 onboarding prompt card (keycap + ability + why line)
-- near the bottom of the playfield. Pure draw; reads no global state.

local Config = require("src.Config")
local Theme = require("src.render.Theme")

local OnboardingPrompt = {}

function OnboardingPrompt.draw(prompt)
    if not prompt then return end

    local sw, sh = Config.screen.width, Config.screen.height
    local panelW, panelH = 760, 150
    local x = (sw - panelW) / 2
    local y = sh - panelH - 90
    local ac = Theme.color.accent

    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", x, y, panelW, panelH, 10, 10)
    love.graphics.setColor(ac[1], ac[2], ac[3], 0.55)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, panelW, panelH, 10, 10)

    local textX = x + 40

    -- Keycap box (omitted for the passive AUTO-FIRE beat, which has no key).
    if prompt.key then
        local capFont = Theme.font("mono", 30)
        local capW = math.max(72, capFont:getWidth(prompt.key) + 28)
        local capH = 58
        local capX, capY = x + 30, y + (panelH - capH) / 2
        love.graphics.setColor(ac[1], ac[2], ac[3], 0.18)
        love.graphics.rectangle("fill", capX, capY, capW, capH, 8, 8)
        love.graphics.setColor(ac[1], ac[2], ac[3], 0.9)
        love.graphics.rectangle("line", capX, capY, capW, capH, 8, 8)
        love.graphics.setFont(capFont)
        love.graphics.setColor(Theme.color.fg1[1], Theme.color.fg1[2], Theme.color.fg1[3], 1)
        love.graphics.printf(prompt.key, capX, capY + (capH - capFont:getHeight()) / 2, capW, "center")
        textX = capX + capW + 30
    end

    love.graphics.setFont(Theme.font("uiBold", 26))
    love.graphics.setColor(ac[1], ac[2], ac[3], 1)
    love.graphics.print(prompt.name, textX, y + 28)

    love.graphics.setFont(Theme.font("ui", 18))
    love.graphics.setColor(Theme.color.fg2[1], Theme.color.fg2[2], Theme.color.fg2[3], 1)
    love.graphics.printf(prompt.line, textX, y + 66, x + panelW - textX - 30, "left")

    love.graphics.setFont(Theme.font("mono", 14))
    love.graphics.setColor(Theme.color.fg3[1], Theme.color.fg3[2], Theme.color.fg3[3], 1)
    love.graphics.print(prompt.skipHint, x + 20, y + panelH - 26)
    love.graphics.printf(string.format("STEP %d / %d", prompt.index, prompt.total), x, y + panelH - 26, panelW - 20, "right")

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return OnboardingPrompt
```

- [ ] **Step 2: Draw the prompt from the render layer**

In `src/states/gameplay/playing/PlayingRenderLayers.lua`, find `FloatingTextSystem.draw()` (currently line 73), and immediately after it add:

```lua
    local prompt = require("src.gameplay.OnboardingSequence").currentPrompt()
    if prompt then
        require("src.ui.OnboardingPrompt").draw(prompt)
    end
```

- [ ] **Step 3: Verify the prompt renders and tracks beats**

Run: `love .`. On a fresh run you should see a prompt card at the bottom reading **MOVE / WASD / "Position is your weapon…"** with `STEP 1 / 5`. Move ~250px → it switches to **AUTO-FIRE** (no keycap box, `STEP 2 / 5`); kill the two dummies → it switches to **DASH / SPACE** (`STEP 3 / 5`) and stalls there (abilities wired in Task 3).

- [ ] **Step 4: Commit**

```bash
git add src/ui/OnboardingPrompt.lua src/states/gameplay/playing/PlayingRenderLayers.lua
git commit -m "feat(tutorial): in-game onboarding prompt card renderer"
```

---

## Task 3: Ability beat hooks (dash / blink / shield)

Reports successful ability use so the Dash, Blink, and Shield beats advance, completing the sequence and handing off to a normal run.

**Files:**
- Modify: `src/states/gameplay/playing/PlayingInputHandlers.lua`

**Interfaces:**
- Consumes: `OnboardingSequence.notifyAbilityUsed(kind)`; `Player:useDash()/useBlink()/useShield()` (each returns truthy on success).
- Produces: nothing new.

- [ ] **Step 1: Notify on successful ability use**

In `src/states/gameplay/playing/PlayingInputHandlers.lua`, add the require at the top of the file (above `local PlayingInputHandlers = {}` on line 1, or just under it):

```lua
local OnboardingSequence = require("src.gameplay.OnboardingSequence")
```

Update the dash handler (currently lines 18–23):

```lua
    if key == "space" then
        if state.player:useDash() then
            print("[Input] Dash activated!")
            OnboardingSequence.notifyAbilityUsed("dash")
        end
        return
    end
```

Update the blink handler (currently lines 33–38):

```lua
    if key == "e" then
        if state.player:useBlink() then
            print("[Input] Blink activated!")
            OnboardingSequence.notifyAbilityUsed("blink")
        end
        return
    end
```

Update the shield handler (currently lines 40–45):

```lua
    if key == "q" then
        if state.player:useShield() then
            print("[Input] Shield activated!")
            OnboardingSequence.notifyAbilityUsed("shield")
        end
        return
    end
```

- [ ] **Step 2: Verify full sequence completion + hand-off**

Run: `lovec.exe . > boot.log 2>&1`. Play through: move, kill dummies, press SPACE, press E, press Q. Close window, read `boot.log`. Expected, in order:
```
[Onboarding] Phase 0 started - MOVE beat
[Onboarding] Beat -> autofire
[Onboarding] Beat -> dash
[Onboarding] Beat -> blink
[Onboarding] Beat -> shield
[Onboarding] Phase 0 complete - handing off to normal run
```
After the last line, normal formation enemies should begin spawning (the prompt card disappears).

- [ ] **Step 3: Commit**

```bash
git add src/states/gameplay/playing/PlayingInputHandlers.lua
git commit -m "feat(tutorial): advance dash/blink/shield onboarding beats on ability use"
```

---

## Task 4: ESC/P swallow while onboarding is active

Prevents ESC/P from opening the Pause overlay during phase 0 (ESC is reserved for the hold-to-skip gesture handled in `OnboardingSequence.update`).

**Files:**
- Modify: `src/states/gameplay/playing/PlayingInputHandlers.lua`

**Interfaces:**
- Consumes: `OnboardingSequence.isActive()`.
- Produces: nothing new.

- [ ] **Step 1: Swallow ESC/P during phase 0**

In `src/states/gameplay/playing/PlayingInputHandlers.lua`, find the pause handler at the top of `keypressed` (currently lines 9–16):

```lua
    if key == "escape" or key == "p" then
        local StateManager = require("src.core.StateManager")
        StateManager.push("Pause", {
            player = state.player,
            musicReactor = state.musicReactor
        })
        return
    end
```

Replace with (ESC/P do nothing here while onboarding is active; ESC-hold-to-skip is handled in the update loop):

```lua
    if key == "escape" or key == "p" then
        if OnboardingSequence.isActive() then
            return
        end
        local StateManager = require("src.core.StateManager")
        StateManager.push("Pause", {
            player = state.player,
            musicReactor = state.musicReactor
        })
        return
    end
```

- [ ] **Step 2: Verify skip + no pause during phase 0**

Run: `lovec.exe . > boot.log 2>&1`. On a fresh run, tap ESC once — the Pause overlay must NOT appear. Then hold ESC ~1s. Close window, read `boot.log`. Expected:
```
[Onboarding] Phase 0 started - MOVE beat
[Onboarding] Skipped by player
```
After skipping, normal spawns begin and (separately) tapping ESC now opens Pause as usual.

- [ ] **Step 3: Commit**

```bash
git add src/states/gameplay/playing/PlayingInputHandlers.lua
git commit -m "feat(tutorial): reserve ESC for skip during onboarding, suppress pause"
```

---

## Task 5: Docs cleanup — remove stale Left-Shift Supernova

Aligns the docs with the code (Supernova is passive; no Left-Shift binding) so docs and the new tutorial agree.

**Files:**
- Modify: `README.md`
- Modify: `DESIGN_DOC.md`

**Interfaces:** none (documentation only).

- [ ] **Step 1: Fix README controls table**

In `README.md`, find this row (currently line 21):

```
| Left Shift | SUPERNOVA active artifact ultimate once collected; uses the current dominant color variant and its cooldown. |
```

Replace with:

```
| _(passive)_ | SUPERNOVA — once the artifact is collected it triggers automatically (reactive); there is no key binding. |
```

- [ ] **Step 2: Fix DESIGN_DOC controls table**

In `DESIGN_DOC.md`, find this row in the §3 Controls table (currently line 41):

```
| Left Shift | SUPERNOVA active artifact ultimate | SUPERNOVA pickup required; cooldown and behavior use the current dominant color variant |
```

Replace with:

```
| _(passive)_ | SUPERNOVA — triggers automatically once the artifact is owned | Reactive passive (`Player.supernovaPassive` → `ArtifactManager.triggerReactiveSupernova`); behavior uses the current dominant color variant. No key binding. |
```

- [ ] **Step 3: Fix DESIGN_DOC §8.3 UI note**

In `DESIGN_DOC.md`, find this line in §8.3 (currently line 254):

```
- SUPERNOVA pickup equips the Left Shift active slot; the HUD renders its cooldown once `player.activeAbility` becomes non-nil.
```

Replace with:

```
- SUPERNOVA is a passive artifact effect (no active slot / key); once owned it triggers reactively and the HUD renders its cooldown glyph.
```

- [ ] **Step 4: Verify no remaining stale references**

Run a search for leftover bindings:

```bash
grep -rni "left shift" README.md DESIGN_DOC.md
```

Expected: no matches (exit status 1, no output). If any remain, repeat the pattern above for them.

- [ ] **Step 5: Commit**

```bash
git add README.md DESIGN_DOC.md
git commit -m "docs: Supernova is passive, remove stale Left-Shift binding references"
```

---

## Self-Review

**Spec coverage:**
- §3 beats (Move/Auto-fire/Dash/Blink/Shield + hand-off) → Tasks 1 (move/autofire), 3 (dash/blink/shield), prompt copy in Task 1 BEATS table. ✓
- §4 safety (suppress spawns; harmless dummies; can't die) → Task 1 Steps 3–4 (spawn guard + contact-damage guard; dummies not in collision world). ✓
- §5 architecture (`OnboardingSequence` separate module; new prompt renderer; hook points) → Tasks 1, 2, 3, 4. ✓
- §5 hook list (PlayingState init, update loop, input handlers, enemy flow, render layers) → all covered. ✓
- §6 persistence/replay (reuse `tutorialEnabled`; phase-0 completion does NOT disable the flag) → Task 1 module comment + `beginRun` reads the flag; no `Settings.save`/flag-disable added, matching spec. ✓
- §3 per-beat skip = none; global hold-ESC skip → Task 1 (`update` ESC-hold) + Task 4 (swallow ESC/P). ✓
- §7 docs cleanup → Task 5. ✓

**Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to" — every code step shows complete code. ✓

**Type consistency:** `isActive()`, `currentPrompt()` (returns `{key,name,line,index,total,skipHint}`), `notifyAbilityUsed("dash"|"blink"|"shield")`, `update(dt, player, state)`, `beginRun()`, `skip()` — names/shapes match between the module (Task 1), the renderer consumer (Task 2), and the input hooks (Tasks 3–4). ✓

**Note for implementer:** Task 1 leaves the game intentionally stuck at the Dash beat (no console error, just no further advance) until Task 3 lands. Don't treat that as a bug during Task 1 verification.
