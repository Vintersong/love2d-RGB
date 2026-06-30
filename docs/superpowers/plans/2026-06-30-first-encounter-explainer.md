# First-Encounter Explainer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teach new players what Chroma (the currency) is and what each artifact does, via a persistent per-concept "first encounter" service decoupled from the one-shot color tutorial.

**Architecture:** A pure-logic `FirstEncounter` service reads/writes per-concept "seen" flags in `MetaProgression` and builds card payloads from `AtlasData` (artifact copy extracted from `AtlasState`). One shared `FirstEncounterCard` renderer draws a non-blocking in-combat toast (artifact pickups) and a blocking menu modal (chroma earned / spend). Each concept fires exactly once, persisted, independent of `Config.gameplay.tutorialEnabled`.

**Tech Stack:** Lua 5.1 / LÖVE 11.5. No external deps. Tests run headlessly via `"C:\Program Files\LOVE\lovec.exe" . --selftest`.

## Global Constraints

- Modules return a table; PascalCase module names; `local X = require("...")` grouped at top; `Module.method(...)` call style. (CLAUDE.md conventions.)
- Every tunable goes in `src/Config.lua` — do not hardcode balance/timing numbers elsewhere.
- Behavior must keep both desktop and web paths working; this feature is pure Lua + existing UI, no `Runtime.isWeb()` branch.
- Do not edit `dist/**`, `reference/donor/**`, `src/utils/legacy/**`, `src/data/ColorTree.lua`, or `src/data/BossArchetypes.lua`.
- Boot verification command (whole-game load): `"C:\Program Files\LOVE\lovec.exe" . > boot.log 2>&1` (block-buffered; let it run ~6s, stop the process, read `boot.log`). A clean boot prints `BOOT LOADER REPORT` + `[StateManager] Switched to state: Splash`.
- New copy strings (verbatim):
  - `chroma_earned`: `Chroma is permanent currency. You keep every Chroma you earn when a run ends - win or lose.`
  - `chroma_spend`: `Spend Chroma here to upgrade your artifacts. Upgrades are permanent and carry into every future run.`

---

### Task 1: Extract `AtlasData` from `AtlasState`

**Files:**
- Create: `src/data/AtlasData.lua`
- Modify: `src/states/menu/AtlasState.lua` (remove inline `colorEntries`/`artifactEntries` tables at lines ~33-156; require the new module instead)

**Interfaces:**
- Produces: `AtlasData.colorEntries` (array of `{name, color, principle, effect, tell, light, mixes}`), `AtlasData.artifactEntries` (array of `{name, color, principle, effect, tell, light}`), `AtlasData.artifactByName(name) -> entry|nil` (case-insensitive).

- [ ] **Step 1: Create `src/data/AtlasData.lua` by moving the existing tables verbatim**

Move the current `colorEntries` (AtlasState lines ~33-89) and `artifactEntries` (lines ~90-156) tables into the new module unchanged. Keep the `Theme` require (color tokens are a plain table, safe under lovec).

```lua
-- AtlasData.lua
-- Canonical reference copy for CHROMATIC colors and artifacts. Single source shared
-- by AtlasState (reference screen) and FirstEncounter (first-pickup teaching).
local Theme = require("src.render.Theme")

local AtlasData = {}

AtlasData.colorEntries = {
    -- (paste the exact colorEntries array currently in AtlasState here, unchanged)
}

AtlasData.artifactEntries = {
    -- (paste the exact artifactEntries array currently in AtlasState here, unchanged)
}

function AtlasData.artifactByName(name)
    if type(name) ~= "string" then return nil end
    local upper = name:upper()
    for _, entry in ipairs(AtlasData.artifactEntries) do
        if entry.name:upper() == upper then return entry end
    end
    return nil
end

return AtlasData
```

- [ ] **Step 2: Point `AtlasState` at the extracted data**

In `src/states/menu/AtlasState.lua`, delete the two inline tables and add near the other requires:

```lua
local AtlasData = require("src.data.AtlasData")
local colorEntries = AtlasData.colorEntries
local artifactEntries = AtlasData.artifactEntries
```

Leave the synergy-derivation loop (the `for _, artifact in ipairs(artifactEntries)` block) untouched — it now iterates the shared table.

- [ ] **Step 3: Boot-verify the Atlas still loads**

Run: `"C:\Program Files\LOVE\lovec.exe" . > boot.log 2>&1` (stop after ~6s), then inspect `boot.log`.
Expected: `BOOT LOADER REPORT` present, no `error`/`traceback`/`nil value`. Then manually open the Atlas screen and confirm COLORS/ARTIFACTS/SYNERGIES tabs render as before.

- [ ] **Step 4: Commit**

```bash
git add src/data/AtlasData.lua src/states/menu/AtlasState.lua
git commit -m "Refactor: extract AtlasData from AtlasState for reuse"
```

---

### Task 2: `seenExplainers` persistence + headless self-test harness

**Files:**
- Modify: `src/core/MetaProgression.lua` (`DEFAULT_PROFILE` ~line 10, `ensureProfileShape` ~line 43, add helpers after `markTutorialSeen` ~line 254)
- Create: `tests/selftest.lua`
- Modify: `main.lua` (`love.load` at line 116)

**Interfaces:**
- Produces: `MetaProgression.hasSeenExplainer(id) -> bool`, `MetaProgression.markExplainerSeen(id)` (sets flag + saves), and a persisted `profile.seenExplainers` string→`true` map.
- Produces: a self-test runner invoked by `lovec . --selftest` that requires `tests/selftest.lua`, runs assertions, prints `SELFTEST: PASS`/`FAIL ...`, and quits.

- [ ] **Step 1: Write the failing self-test harness + first test**

Create `tests/selftest.lua`:

```lua
-- Headless assertion suite. Run via: lovec . --selftest
local results = { passed = 0, failed = 0 }

local function check(name, cond)
    if cond then
        results.passed = results.passed + 1
        print("  ok   - " .. name)
    else
        results.failed = results.failed + 1
        print("  FAIL - " .. name)
    end
end

-- MetaProgression explainer flags
local Meta = require("src.core.MetaProgression")
Meta.load()  -- fresh/loaded profile
check("explainer unseen by default", Meta.hasSeenExplainer("chroma_earned") == false)
Meta.markExplainerSeen("chroma_earned")
check("explainer seen after mark", Meta.hasSeenExplainer("chroma_earned") == true)
check("unrelated id still unseen", Meta.hasSeenExplainer("artifact:PRISM") == false)

print(string.format("SELFTEST: %s (%d passed, %d failed)",
    results.failed == 0 and "PASS" or "FAIL", results.passed, results.failed))
return results
```

Add the runner hook in `main.lua` immediately after `Runtime.init(args)` (line 117):

```lua
    for _, a in ipairs(args or {}) do
        if a == "--selftest" then
            require("tests.selftest")
            love.event.quit()
            return
        end
    end
```

- [ ] **Step 2: Run the self-test to verify it fails**

Run: `"C:\Program Files\LOVE\lovec.exe" . --selftest > test.log 2>&1` then read `test.log`.
Expected: FAIL — `hasSeenExplainer`/`markExplainerSeen` are not yet defined (runtime error or `SELFTEST: FAIL`).

- [ ] **Step 3: Implement persistence + helpers in `MetaProgression`**

In `DEFAULT_PROFILE` (line ~10) add the field:

```lua
    seenExplainers = {},
```

In `ensureProfileShape` (after the `artifactPurchases` block, ~line 101) add:

```lua
    if type(data.seenExplainers) == "table" then
        result.seenExplainers = {}
        for key, value in pairs(data.seenExplainers) do
            if type(key) == "string" and value == true then
                result.seenExplainers[key] = true
            end
        end
    end
```

After `markTutorialSeen` (~line 258) add:

```lua
function MetaProgression.hasSeenExplainer(id)
    return type(id) == "string" and profile.seenExplainers[id] == true
end

function MetaProgression.markExplainerSeen(id)
    if type(id) ~= "string" then return end
    if not profile.seenExplainers[id] then
        profile.seenExplainers[id] = true
        MetaProgression.save()
    end
end
```

(The generic `serialize` already persists the new table; no save change needed.)

- [ ] **Step 4: Run the self-test to verify it passes**

Run: `"C:\Program Files\LOVE\lovec.exe" . --selftest > test.log 2>&1` then read `test.log`.
Expected: `SELFTEST: PASS (3 passed, 0 failed)`.

- [ ] **Step 5: Commit**

```bash
git add src/core/MetaProgression.lua tests/selftest.lua main.lua
git commit -m "Add seenExplainers persistence + headless selftest harness"
```

---

### Task 3: `FirstEncounter` service

**Files:**
- Create: `src/gameplay/FirstEncounter.lua`
- Modify: `tests/selftest.lua` (append service tests)
- Modify: `src/Config.lua` (add `Config.teaching = { toastSeconds = 6 }`)

**Interfaces:**
- Consumes: `MetaProgression.hasSeenExplainer/markExplainerSeen`, `AtlasData.artifactByName`, `Config.teaching.toastSeconds`.
- Produces:
  - `FirstEncounter.cardFor(id) -> {title, color, lines={...}, atlasTab}|nil`
  - `FirstEncounter.shouldTeach(id) -> bool`, `FirstEncounter.markTaught(id)`
  - `FirstEncounter.onArtifact(artifactType)` — if unseen, enqueue toast + mark taught
  - Toast queue: `FirstEncounter.update(dt)`, `peekToast() -> card|nil`, `hasToast() -> bool`, `dismissToast()`
  - `FirstEncounter.resetAll()` — clears the in-memory queue + timer (used by debug hotkey; flag clearing lives in MetaProgression)

- [ ] **Step 1: Append failing service tests to `tests/selftest.lua`**

Insert before the final summary `print`:

```lua
-- FirstEncounter service
local FE = require("src.gameplay.FirstEncounter")
check("cardFor known artifact", (FE.cardFor("artifact:PRISM") or {}).title ~= nil)
check("cardFor unknown artifact is nil", FE.cardFor("artifact:NOPE") == nil)
check("cardFor chroma_earned", (FE.cardFor("chroma_earned") or {}).title ~= nil)

Meta.load()  -- reset profile view
check("toast empty initially", FE.hasToast() == false)
FE.onArtifact("halo")        -- lowercase on purpose
check("toast queued after first pickup", FE.hasToast() == true)
FE.onArtifact("halo")        -- second time: already seen
FE.dismissToast()
check("toast empties after dismiss", FE.hasToast() == false)
FE.onArtifact("halo")
check("repeat pickup does not re-teach", FE.hasToast() == false)
```

- [ ] **Step 2: Run self-test to verify the new checks fail**

Run: `"C:\Program Files\LOVE\lovec.exe" . --selftest > test.log 2>&1` then read `test.log`.
Expected: FAIL — `FirstEncounter` not found.

- [ ] **Step 3: Add the config tunable**

In `src/Config.lua` add (next to other gameplay/teaching config):

```lua
    teaching = {
        toastSeconds = 6,   -- how long an in-combat first-encounter toast stays up
    },
```

- [ ] **Step 4: Implement `src/gameplay/FirstEncounter.lua`**

```lua
-- FirstEncounter.lua
-- Persistent, per-concept "first encounter" teaching. Decoupled from TutorialSystem:
-- each concept (an artifact, the chroma currency, spending chroma) teaches once, ever,
-- gated by MetaProgression.seenExplainers regardless of Config.gameplay.tutorialEnabled.
local Config = require("src.Config")
local MetaProgression = require("src.core.MetaProgression")
local AtlasData = require("src.data.AtlasData")

local FirstEncounter = {}

local toastQueue = {}
local toastTimer = 0

local CHROMA_CARDS = {
    chroma_earned = {
        title = "CHROMA",
        color = nil,  -- resolved to Theme accent by the renderer when nil
        lines = {
            "Chroma is permanent currency. You keep every Chroma you earn",
            "when a run ends - win or lose.",
        },
        atlasTab = nil,
    },
    chroma_spend = {
        title = "SPEND CHROMA",
        color = nil,
        lines = {
            "Spend Chroma here to upgrade your artifacts.",
            "Upgrades are permanent and carry into every future run.",
        },
        atlasTab = "artifacts",
    },
}

function FirstEncounter.shouldTeach(id)
    return MetaProgression.hasSeenExplainer(id) == false
end

function FirstEncounter.markTaught(id)
    MetaProgression.markExplainerSeen(id)
end

function FirstEncounter.cardFor(id)
    if type(id) ~= "string" then return nil end
    if CHROMA_CARDS[id] then
        local c = CHROMA_CARDS[id]
        return { title = c.title, color = c.color, lines = c.lines, atlasTab = c.atlasTab }
    end
    local name = id:match("^artifact:(.+)$")
    if name then
        local entry = AtlasData.artifactByName(name)
        if not entry then return nil end
        return {
            title = entry.name,
            color = entry.color,
            lines = { entry.principle, entry.effect, entry.tell },
            atlasTab = "artifacts",
        }
    end
    return nil
end

function FirstEncounter.onArtifact(artifactType)
    if type(artifactType) ~= "string" then return end
    local id = "artifact:" .. artifactType:upper()
    if not FirstEncounter.shouldTeach(id) then return end
    local card = FirstEncounter.cardFor(id)
    if not card then return end           -- unknown artifact: skip, no crash
    toastQueue[#toastQueue + 1] = card
    if #toastQueue == 1 then toastTimer = Config.teaching.toastSeconds end
    FirstEncounter.markTaught(id)          -- toast marks on enqueue (auto-times-out)
end

function FirstEncounter.hasToast() return #toastQueue > 0 end
function FirstEncounter.peekToast() return toastQueue[1] end

function FirstEncounter.dismissToast()
    if #toastQueue == 0 then return end
    table.remove(toastQueue, 1)
    toastTimer = (#toastQueue > 0) and Config.teaching.toastSeconds or 0
end

function FirstEncounter.update(dt)
    if #toastQueue == 0 then return end
    toastTimer = toastTimer - dt
    if toastTimer <= 0 then FirstEncounter.dismissToast() end
end

function FirstEncounter.resetAll()
    toastQueue = {}
    toastTimer = 0
end

return FirstEncounter
```

- [ ] **Step 5: Run self-test to verify it passes**

Run: `"C:\Program Files\LOVE\lovec.exe" . --selftest > test.log 2>&1` then read `test.log`.
Expected: `SELFTEST: PASS` with all checks `ok` (9 passed, 0 failed).

- [ ] **Step 6: Commit**

```bash
git add src/gameplay/FirstEncounter.lua src/Config.lua tests/selftest.lua
git commit -m "Add FirstEncounter teaching service + tests"
```

---

### Task 4: `FirstEncounterCard` renderer (toast + modal)

**Files:**
- Create: `src/ui/FirstEncounterCard.lua`
- Reference (read for patterns, do not edit): `src/ui/ShellStyle.lua` / `Shared.drawGlassPanel`, `src/states/menu/TutorialState.lua` (card draw), `src/render/Theme.lua`

**Interfaces:**
- Consumes: a `card` table `{title, color, lines, atlasTab}` from `FirstEncounter.cardFor`.
- Produces:
  - `FirstEncounterCard.drawToast(card, alphaScale)` — edge-anchored, non-blocking, no input.
  - `FirstEncounterCard.drawModal(card)` — centered, dims background, draws `[SPACE] dismiss` (and `[A] Atlas` when `card.atlasTab`).

- [ ] **Step 1: Implement the renderer**

Follow the existing glass-panel + `Theme.font` pattern used in `TutorialState`. Resolve `card.color` to `Theme.color.accent` when nil. Toast anchors bottom-center within the 1920×1080 logical space; modal centers. Keep all sizes in local constants at the top of the file (not Config — these are layout, not balance).

```lua
-- FirstEncounterCard.lua
-- Shared renderer for first-encounter teaching cards. Two modes:
--   drawToast  - non-blocking in-combat banner (PlayingState)
--   drawModal  - blocking centered card (RunSummary / Progression menus)
local Theme = require("src.render.Theme")
local Shared = require("src.ui.ShellStyle")  -- adjust to the module exposing drawGlassPanel

local FirstEncounterCard = {}

local TOAST_W, TOAST_H = 760, 150
local MODAL_W, MODAL_H = 820, 260

local function accent(card) return card.color or Theme.color.accent end

local function drawCard(card, x, y, w, h, footer)
    Shared.drawGlassPanel(x, y, w, h)              -- translucent dark glass + cyan edge
    local rim = accent(card)
    love.graphics.setColor(rim[1], rim[2], rim[3], 0.9)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)

    love.graphics.setFont(Theme.font("uiSemiBold", 24))
    love.graphics.print(card.title, x + 28, y + 20)

    love.graphics.setFont(Theme.font("ui", 18))
    love.graphics.setColor(1, 1, 1, 0.92)
    for i, line in ipairs(card.lines or {}) do
        love.graphics.print(line, x + 28, y + 60 + (i - 1) * 26)
    end

    if footer then
        love.graphics.setFont(Theme.font("uiMono", 14))
        love.graphics.setColor(1, 1, 1, 0.55)
        love.graphics.print(footer, x + 28, y + h - 30)
    end
end

function FirstEncounterCard.drawToast(card, alphaScale)
    if not card then return end
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, alphaScale or 1)
    local x = (1920 - TOAST_W) / 2
    drawCard(card, x, 1080 - TOAST_H - 60, TOAST_W, TOAST_H, nil)
    love.graphics.pop()
end

function FirstEncounterCard.drawModal(card)
    if not card then return end
    love.graphics.push("all")
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, 1920, 1080)
    local footer = card.atlasTab and "[SPACE] dismiss   [A] Atlas" or "[SPACE] dismiss"
    drawCard(card, (1920 - MODAL_W) / 2, (1080 - MODAL_H) / 2, MODAL_W, MODAL_H, footer)
    love.graphics.pop()
end

return FirstEncounterCard
```

> Implementer note: confirm the actual module/function name for `drawGlassPanel` and the exact `Theme.font` role keys (`ui`, `uiSemiBold`, `uiMono`) against `TutorialState.lua`; adjust requires/roles to match what that file uses.

- [ ] **Step 2: Boot-verify the module loads (no render path yet)**

Add a temporary require to `tests/selftest.lua` (`require("src.ui.FirstEncounterCard")`) and run the self-test; expected `SELFTEST: PASS` (module loads without error). Remove the temporary require after confirming, or leave a `check("card renderer loads", true)` line.

- [ ] **Step 3: Commit**

```bash
git add src/ui/FirstEncounterCard.lua tests/selftest.lua
git commit -m "Add FirstEncounterCard renderer (toast + modal)"
```

---

### Task 5: Artifact toast integration + retire generic popup

**Files:**
- Modify: `src/gameplay/PickupSystem.lua:38` (add `FirstEncounter.onArtifact`)
- Modify: `src/states/gameplay/playing/PlayingUpdateLoop.lua` (tick `FirstEncounter.update(dt)`)
- Modify: `src/states/gameplay/playing/PlayingRenderLayers.lua` (draw toast last, as overlay)
- Modify: `src/states/gameplay/playing/PlayingInputHandlers.lua` (dismiss toast on key)
- Modify: `src/gameplay/TutorialSystem.lua:224-227` (retire the generic `ARTIFACT` popup)

**Interfaces:**
- Consumes: `FirstEncounter.onArtifact`, `.update`, `.peekToast`, `.hasToast`, `.dismissToast`; `FirstEncounterCard.drawToast`.

- [ ] **Step 1: Fire the toast on pickup**

In `src/gameplay/PickupSystem.lua`, add to the requires block:

```lua
local FirstEncounter = require("src.gameplay.FirstEncounter")
```

At line 38, alongside the existing `TutorialSystem.onArtifactCollected(result.type)`:

```lua
                FirstEncounter.onArtifact(result.type)
```

- [ ] **Step 2: Retire the duplicate generic artifact popup**

In `src/gameplay/TutorialSystem.lua`, change `onArtifactCollected` (lines 224-227) so it no longer queues the generic `ARTIFACT` popup (FirstEncounter now owns artifact teaching). Leave `onSynergyActivated` untouched:

```lua
function TutorialSystem.onArtifactCollected(_artifactType)
    -- Artifact teaching now handled by FirstEncounter (per-artifact, in-combat toast).
    return
end
```

- [ ] **Step 3: Tick the toast timer in the update loop**

In `src/states/gameplay/playing/PlayingUpdateLoop.lua`, require `FirstEncounter` and call `FirstEncounter.update(dt)` once per frame within the main `update` function (only when not paused — match the existing guard used for other live systems).

- [ ] **Step 4: Draw the toast as the top overlay**

In `src/states/gameplay/playing/PlayingRenderLayers.lua`, require `FirstEncounter` and `FirstEncounterCard`, and at the very end of `draw` (after HUD):

```lua
    if FirstEncounter.hasToast() then
        FirstEncounterCard.drawToast(FirstEncounter.peekToast(), 1)
    end
```

- [ ] **Step 5: Dismiss the toast on keypress**

In `src/states/gameplay/playing/PlayingInputHandlers.lua`, near the top of `keypressed`, require `FirstEncounter` and add:

```lua
    if FirstEncounter.hasToast() and (key == "space" or key == "return") then
        FirstEncounter.dismissToast()
        return
    end
```

- [ ] **Step 6: Manual verification**

Run `"C:\Program Files\LOVE\lovec.exe" .`, start a run with a fresh profile (delete the save, or use the Task 8 debug hotkey once it exists), pick up an artifact. Expected: a bottom-center toast naming the artifact + its effect appears, auto-dismisses after ~6s (or on Space), and does NOT pause combat. Pick the same artifact again → no toast.

- [ ] **Step 7: Commit**

```bash
git add src/gameplay/PickupSystem.lua src/gameplay/TutorialSystem.lua src/states/gameplay/playing/PlayingUpdateLoop.lua src/states/gameplay/playing/PlayingRenderLayers.lua src/states/gameplay/playing/PlayingInputHandlers.lua
git commit -m "Wire artifact first-pickup toast; retire generic tutorial artifact popup"
```

---

### Task 6: Chroma-earned modal in `RunSummaryState`

**Files:**
- Modify: `src/states/outcome/RunSummaryState.lua` (`enter` line 37, `update` 50, `draw` 62, `keypressed` 211)

**Interfaces:**
- Consumes: `FirstEncounter.shouldTeach`, `.cardFor`, `.markTaught`; `FirstEncounterCard.drawModal`; the run-summary data exposing `chromaEarned` (same source as line 125's `unlocks.chromaEarned or unlocks.shardsEarned`).

- [ ] **Step 1: Decide-and-store the card on enter**

Add requires for `FirstEncounter` and `FirstEncounterCard`. In `RunSummaryState:enter`, after the unlocks/summary data is resolved:

```lua
    self.explainerCard = nil
    local earned = (self.unlocks and (self.unlocks.chromaEarned or self.unlocks.shardsEarned)) or 0
    if earned > 0 and FirstEncounter.shouldTeach("chroma_earned") then
        self.explainerCard = FirstEncounter.cardFor("chroma_earned")
    end
```

(Use whatever field name `enter` already stores the unlocks under; line 125 reads `unlocks.chromaEarned` — mirror that exact access.)

- [ ] **Step 2: Draw the modal on top when present**

At the end of `RunSummaryState:draw`:

```lua
    if self.explainerCard then
        FirstEncounterCard.drawModal(self.explainerCard)
    end
```

- [ ] **Step 3: Capture input while the modal is up**

At the very top of `RunSummaryState:keypressed`, before existing handling (the `chroma_earned` card has no `atlasTab`, so there is no Atlas branch here — just dismiss):

```lua
    if self.explainerCard then
        if key == "space" or key == "return" or key == "escape" then
            FirstEncounter.markTaught("chroma_earned")
            self.explainerCard = nil
        end
        return
    end
```

- [ ] **Step 4: Manual verification**

Fresh profile, finish a run that awards chroma. Expected: a centered modal explaining chroma appears over the summary; Space dismisses it; finishing another run does NOT show it again.

- [ ] **Step 5: Commit**

```bash
git add src/states/outcome/RunSummaryState.lua
git commit -m "Teach what Chroma is on first run-summary that awards it"
```

---

### Task 7: Chroma-spend modal + Atlas jump in `ProgressionState`

**Files:**
- Modify: `src/states/menu/ProgressionState.lua` (`enter` line 162, `draw` 184, `keypressed` 403)

**Interfaces:**
- Consumes: `FirstEncounter.shouldTeach`, `.cardFor`, `.markTaught`; `FirstEncounterCard.drawModal`; the existing Gamestate switch used elsewhere in this file to open the Atlas.

- [ ] **Step 1: Decide-and-store on enter**

Add requires for `FirstEncounter` and `FirstEncounterCard`. In `ProgressionState:enter`:

```lua
    self.explainerCard = nil
    if FirstEncounter.shouldTeach("chroma_spend") then
        self.explainerCard = FirstEncounter.cardFor("chroma_spend")
    end
```

- [ ] **Step 2: Draw the modal last**

At the end of `ProgressionState:draw`:

```lua
    if self.explainerCard then
        FirstEncounterCard.drawModal(self.explainerCard)
    end
```

- [ ] **Step 3: Capture input + wire the Atlas jump**

At the top of `ProgressionState:keypressed`. This file already uses `StateManager.switch(...)` (lines 383/390), and `MenuState:459` opens the Atlas with `StateManager.switch("Atlas")` — reuse that exact call. `AtlasState:enter()` takes no args, so the Atlas opens on its default (COLORS) tab; the `atlasTab` field is only a flag that shows the `[A] Atlas` hint:

```lua
    if self.explainerCard then
        if key == "a" then
            FirstEncounter.markTaught("chroma_spend")
            self.explainerCard = nil
            StateManager.switch("Atlas")
        elseif key == "space" or key == "return" or key == "escape" then
            FirstEncounter.markTaught("chroma_spend")
            self.explainerCard = nil
        end
        return
    end
```

(Confirm `StateManager` is already required at the top of this file — it is used at lines 358/383. If the local is named differently, match it.)

- [ ] **Step 4: Manual verification**

Fresh profile, open the Progression screen. Expected: modal explaining how to spend Chroma; `A` opens the Atlas (artifacts), `Space` dismisses; re-entering Progression does NOT show it again.

- [ ] **Step 5: Commit**

```bash
git add src/states/menu/ProgressionState.lua
git commit -m "Teach how to spend Chroma on first Progression visit"
```

---

### Task 8: Debug reset hotkey

**Files:**
- Modify: `src/core/MetaProgression.lua` (add `clearExplainers`)
- Modify: the debug-hotkey handler (find via `grep -n "Config.debug" src` — likely `DebugMenu` or a global `love.keypressed` F-key block in `main.lua`)
- Modify: `tests/selftest.lua` (add a `clearExplainers` round-trip check)
- Modify: `README.md` (add the new F-key to the debug hotkey list)

**Interfaces:**
- Produces: `MetaProgression.clearExplainers()` (empties `seenExplainers` + saves) and a debug key that calls it plus `FirstEncounter.resetAll()`.

- [ ] **Step 1: Add the failing test**

In `tests/selftest.lua` before the summary:

```lua
Meta.markExplainerSeen("chroma_spend")
Meta.clearExplainers()
check("clearExplainers wipes flags", Meta.hasSeenExplainer("chroma_spend") == false)
```

- [ ] **Step 2: Run self-test — expect FAIL**

Run: `"C:\Program Files\LOVE\lovec.exe" . --selftest > test.log 2>&1`.
Expected: FAIL — `clearExplainers` undefined.

- [ ] **Step 3: Implement `clearExplainers`**

In `MetaProgression`:

```lua
function MetaProgression.clearExplainers()
    profile.seenExplainers = {}
    MetaProgression.save()
end
```

- [ ] **Step 4: Run self-test — expect PASS**

Run: `"C:\Program Files\LOVE\lovec.exe" . --selftest > test.log 2>&1`.
Expected: `SELFTEST: PASS`.

- [ ] **Step 5: Bind the debug hotkey**

In the existing `Config.debug.enabled`-gated F-key handler, add a free F-key (confirm which are unused against `README.md`'s list) that runs:

```lua
        MetaProgression.clearExplainers()
        require("src.gameplay.FirstEncounter").resetAll()
        print("[Debug] Cleared first-encounter explainer flags")
```

- [ ] **Step 6: Document the hotkey**

Add the new F-key + "reset first-encounter explainers" to the debug hotkey table in `README.md`.

- [ ] **Step 7: Manual verification + commit**

Run the game with `Config.debug.enabled = true`, press the new key, confirm the console prints the reset line, then re-trigger an artifact toast to prove flags cleared.

```bash
git add src/core/MetaProgression.lua tests/selftest.lua README.md main.lua
git commit -m "Add debug hotkey to reset first-encounter explainer flags"
```

---

## Notes for the implementer

- Run the boot-verify command after every task that touches a `require`d module — a missing `require` or typo fails the whole game hard at the BootLoader gate.
- The `tests/selftest.lua` suite is cumulative; each task appends to it and every task's "run self-test" step should still end in `SELFTEST: PASS`.
- Keep `Config.debug.enabled` at its committed value; do not flip it as part of this work.
- After Task 8, the full feature is shippable but the `dist/` build is stale — repackaging (`scripts/package-web.ps1`) is a separate step the user runs when ready.
