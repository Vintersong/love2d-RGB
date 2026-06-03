# GameOverState Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `src/states/GameOverState.lua` in-place as a full dedicated screen matching the CHROMATIC design system — animated neon background, Theme tokens, Michroma/Chakra Petch fonts, and bracket-style navigation buttons.

**Architecture:** Drop all game-world rendering; draw BackgroundShader directly, overlay `bgVoid` at 0.85 alpha, then draw content with a 0.4s fade-in. Bracket buttons copied from MenuState pattern. All color and font values come from `Theme` — no raw floats.

**Tech Stack:** LÖVE 11.5 / LuaJIT — `src/render/BackgroundShader.lua`, `src/render/Theme.lua`, `src/gameplay/ColorSystem.lua`, `src/Config.lua`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `src/states/GameOverState.lua` | **Rewrite in-place** | Full new implementation |

No new files. No other files touched.

---

## Task 1: Scaffold — BackgroundShader, fade-in, title and stats block

**Files:**
- Modify: `src/states/GameOverState.lua`

**What this produces:** Full death screen — neon background, `SIGNAL LOST` title, level, color path, damage stat. Temporary `R / ESC` text hints so the screen is navigable while bracket buttons are absent (Task 2 replaces them).

- [ ] **Step 1: Replace the entire file with the following**

```lua
-- GameOverState.lua
local GameOverState = {}

local Config           = require("src.Config")
local Runtime          = require("src.core.Runtime")
local GameConfig       = require("src.core.GameConfig")
local Theme            = require("src.render.Theme")
local BackgroundShader = require("src.render.BackgroundShader")

GameOverState.player       = nil
GameOverState.musicReactor = nil

local alpha = 0

-- Fonts (lazily initialised after love.graphics exists)
local fontDisplay  = nil
local fontSemiBold = nil
local fontUI       = nil
local fontMono     = nil

function GameOverState:enter(previous, data)
    GameConfig.setActiveRun(false)
    alpha = 0
    if data then
        self.player       = data.player
        self.musicReactor = data.musicReactor
    end
    fontDisplay  = fontDisplay  or Theme.font("display",    75)
    fontSemiBold = fontSemiBold or Theme.font("uiSemiBold", 24)
    fontUI       = fontUI       or Theme.font("ui",         16)
    fontMono     = fontMono     or Theme.font("mono",       12)
end

function GameOverState:update(dt)
    alpha = math.min(1, alpha + dt / 0.4)
    if self.musicReactor then
        self.musicReactor:update(dt)
    end
    BackgroundShader.update(dt, self.musicReactor, nil)
end

function GameOverState:draw()
    local sw, sh = Config.screen.width, Config.screen.height
    BackgroundShader.draw()
    Theme.setColor("bgVoid", 0.85)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    self:drawContent(sw, sh)
end

function GameOverState:drawContent(sw, sh)
    local cx = sw / 2
    local ColorSystem = require("src.gameplay.ColorSystem")

    -- Title
    love.graphics.setFont(fontDisplay)
    local title = "SIGNAL LOST"
    Theme.setColor("danger", alpha)
    love.graphics.print(title, cx - fontDisplay:getWidth(title) / 2, 200)

    -- Accent rule
    local ruleW = sw * 0.4
    Theme.setColor("accent", alpha * 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(cx - ruleW / 2, 305, cx + ruleW / 2, 305)

    -- Level
    love.graphics.setFont(fontSemiBold)
    Theme.setColor("fg1", alpha)
    local levelStr = string.format("Level %d", self.player.level)
    love.graphics.print(levelStr, cx - fontSemiBold:getWidth(levelStr) / 2, 340)

    -- Color path label
    love.graphics.setFont(fontUI)
    Theme.setColor("fg3", alpha)
    local pathLabel = "Color Path:"
    love.graphics.print(pathLabel, cx - fontUI:getWidth(pathLabel) / 2, 390)

    -- Color path segments, each drawn in its Theme color token
    local history = ColorSystem.colorHistory or {}
    if #history > 0 then
        local segments, segWidths = {}, {}
        for _, code in ipairs(history) do
            table.insert(segments, ColorSystem.getColorName(code):upper())
        end
        local arrow  = "  →  "
        local arrowW = fontUI:getWidth(arrow)
        local totalW = 0
        for i, seg in ipairs(segments) do
            segWidths[i] = fontUI:getWidth(seg)
            totalW = totalW + segWidths[i]
            if i < #segments then totalW = totalW + arrowW end
        end
        local px = cx - totalW / 2
        for i, seg in ipairs(segments) do
            local colorName = ColorSystem.getColorName(history[i]):lower()
            local c = Theme.color[colorName] or Theme.color.fg1
            love.graphics.setColor(c[1], c[2], c[3], alpha)
            love.graphics.print(seg, px, 420)
            px = px + segWidths[i]
            if i < #segments then
                Theme.setColor("fg3", alpha * 0.4)
                love.graphics.print(arrow, px, 420)
                px = px + arrowW
            end
        end
    end

    -- Dominant damage stat
    love.graphics.setFont(fontMono)
    Theme.setColor("fg2", alpha)
    local dmg    = self.player.weapon and self.player.weapon.damage or 0
    local dmgStr = string.format("Damage  %.0f", dmg)
    love.graphics.print(dmgStr, cx - fontMono:getWidth(dmgStr) / 2, 480)

    -- Temporary nav hints (replaced by bracket buttons in Task 2)
    love.graphics.setFont(fontUI)
    Theme.setColor("fg3", alpha * 0.7)
    local hint = "R  Restart      ESC  Quit"
    love.graphics.print(hint, cx - fontUI:getWidth(hint) / 2, sh - 100)
end

function GameOverState:keypressed(key)
    local StateManager = require("src.core.StateManager")
    if key == "r" then
        local PlayingState = require("src.states.PlayingState")
        PlayingState.startNewRun()
        StateManager.switch("Playing")
    elseif key == "escape" then
        Runtime.quitOrReturnToTitle()
    end
end

return GameOverState
```

- [ ] **Step 2: Run `love .` from the repo root — verify it loads without error**

Expected console output: no Lua errors, `[BackgroundShader]` lines appear normally.  
If `love` is not on PATH, run the installed `love.exe` directly (see CLAUDE.md).

- [ ] **Step 3: Die in-game and verify the death screen**

Check:
- Neon animated background visible (not the game world)
- `SIGNAL LOST` in red, centered near the top
- Thin cyan rule below the title
- Level, color path in segment colors, and Damage stat visible
- `R` restarts, `ESC` quits

- [ ] **Step 4: Commit**

```
git add src/states/GameOverState.lua
git commit -m "feat: rewrite GameOverState — BackgroundShader background, Theme fonts, stats block"
```

---

## Task 2: Bracket buttons and full keyboard navigation

**Files:**
- Modify: `src/states/GameOverState.lua`

**What this produces:** Replaces the temporary text hints with animated bracket buttons matching MenuState style. Up/Down moves selection, Return/Space confirms, `r` = restart, `escape` = quit.

- [ ] **Step 1: Add button state locals after the font locals block**

Find the line:
```lua
local fontMono     = nil
```
Add immediately after it:
```lua
-- Button navigation
local buttons = {
    { label = "RESTART", action = "restart" },
    { label = "QUIT",    action = "quit"    },
}
local selectedButton = 1
local animProgress   = {}

local BTN_W = 300
local BTN_H = 44
local BTN_GAP = 16
```

- [ ] **Step 2: Reset button state in `enter()`**

Find the line:
```lua
    alpha = 0
```
Add immediately after it:
```lua
    selectedButton = 1
    for i = 1, #buttons do animProgress[i] = 0 end
```

- [ ] **Step 3: Animate button selection in `update()`**

Find the end of `GameOverState:update(dt)` — after the `BackgroundShader.update` call, before the closing `end`. Add:
```lua
    for i = 1, #buttons do
        local target = (i == selectedButton) and 1 or 0
        if animProgress[i] < target then
            animProgress[i] = math.min(target, animProgress[i] + dt / 0.15)
        elseif animProgress[i] > target then
            animProgress[i] = math.max(target, animProgress[i] - dt / 0.15)
        end
    end
```

- [ ] **Step 4: Replace the temporary nav hints section in `drawContent()` with bracket buttons**

Find and remove these lines in `drawContent`:
```lua
    -- Temporary nav hints (replaced by bracket buttons in Task 2)
    love.graphics.setFont(fontUI)
    Theme.setColor("fg3", alpha * 0.7)
    local hint = "R  Restart      ESC  Quit"
    love.graphics.print(hint, cx - fontUI:getWidth(hint) / 2, sh - 100)
```

Replace them with:
```lua
    -- Bracket buttons
    local totalBtnH = #buttons * BTN_H + (#buttons - 1) * BTN_GAP
    local btnStartY = sh - 200 - totalBtnH
    local btnX      = cx - BTN_W / 2

    for i, btn in ipairs(buttons) do
        local progress = animProgress[i] or 0
        local ease     = 1 - math.pow(2, -10 * math.max(progress, 0.001))
        local slide    = ease * 8
        local lx = btnX + slide
        local rx = btnX + BTN_W - slide
        local by = btnStartY + (i - 1) * (BTN_H + BTN_GAP)

        -- Dark fill
        love.graphics.setColor(0, 0, 0, alpha * 0.5)
        love.graphics.rectangle("fill", lx, by, rx - lx, BTN_H)

        -- Corner brackets
        love.graphics.setLineWidth(1.5)
        if i == selectedButton then
            Theme.setColor("accent", alpha)
        else
            love.graphics.setColor(1, 1, 1, alpha * 0.12)
        end
        love.graphics.line(lx + 12, by,          lx, by,         lx, by + 12)
        love.graphics.line(lx + 12, by + BTN_H,  lx, by + BTN_H, lx, by + BTN_H - 12)
        love.graphics.line(rx - 12, by,          rx, by,         rx, by + 12)
        love.graphics.line(rx - 12, by + BTN_H,  rx, by + BTN_H, rx, by + BTN_H - 12)

        -- Label
        love.graphics.setFont(fontUI)
        local lw = fontUI:getWidth(btn.label)
        if i == selectedButton then
            love.graphics.setColor(0, 0, 0, alpha * 0.5)
            love.graphics.print(btn.label, cx - lw / 2 + 1, by + BTN_H / 2 - 8 + 1)
            Theme.setColor("fg1", alpha)
        else
            love.graphics.setColor(0.55, 0.6, 0.7, alpha * 0.6)
        end
        love.graphics.print(btn.label, cx - lw / 2, by + BTN_H / 2 - 8)
    end
```

- [ ] **Step 5: Replace `keypressed()` with full navigation**

Replace the entire `GameOverState:keypressed` function with:
```lua
function GameOverState:keypressed(key)
    if key == "up" then
        selectedButton = selectedButton - 1
        if selectedButton < 1 then selectedButton = #buttons end
    elseif key == "down" then
        selectedButton = selectedButton + 1
        if selectedButton > #buttons then selectedButton = 1 end
    elseif key == "return" or key == "space" then
        self:activateButton(buttons[selectedButton].action)
    elseif key == "r" then
        self:activateButton("restart")
    elseif key == "escape" then
        self:activateButton("quit")
    end
end

function GameOverState:activateButton(action)
    local StateManager = require("src.core.StateManager")
    if action == "restart" then
        local PlayingState = require("src.states.PlayingState")
        PlayingState.startNewRun()
        StateManager.switch("Playing")
    elseif action == "quit" then
        Runtime.quitOrReturnToTitle()
    end
end
```

- [ ] **Step 6: Run `love .` — verify no load errors**

- [ ] **Step 7: Die in-game and verify bracket buttons**

Check:
- Two bracket buttons visible in the lower portion of the screen
- `[ RESTART ]` highlighted in cyan by default (selectedButton = 1)
- Up/Down arrows move selection between the two buttons; brackets animate (slide inward) on focus
- `Return` or `Space` on RESTART starts a new run
- `Return` or `Space` on QUIT exits / returns to title
- `R` directly restarts regardless of selection
- `ESC` directly quits regardless of selection
- No text hints visible (old `R Restart ESC Quit` line is gone)

- [ ] **Step 8: Commit**

```
git add src/states/GameOverState.lua
git commit -m "feat: bracket buttons and keyboard nav on GameOverState"
```

---

## Spec Coverage Check

| Spec requirement | Covered by |
|---|---|
| Full dedicated screen, no game world | Task 1 — World/enemy render removed |
| BackgroundShader animated neon bg | Task 1 — `BackgroundShader.draw()` |
| Fade-in 0.4s | Task 1 — `alpha = math.min(1, alpha + dt / 0.4)` |
| bgVoid 0.85 overlay | Task 1 — `Theme.setColor("bgVoid", 0.85)` |
| musicReactor update only, no visual | Task 1 — `musicReactor:update(dt)` in update(), not used in draw |
| Title "SIGNAL LOST" Michroma 75px danger | Task 1 — `fontDisplay`, `Theme.setColor("danger", alpha)` |
| Accent rule 40% width | Task 1 — `sw * 0.4` line |
| Level uiSemiBold 24px fg1 | Task 1 |
| Color path segments in own Theme.color | Task 1 — `Theme.color[colorName]` per segment |
| Damage mono 12px fg2 | Task 1 |
| Bracket buttons accent/fg3 | Task 2 |
| Up/down selection, return/space confirm | Task 2 |
| r = restart, escape = quit | Task 2 — `activateButton()` |
| No raw hardcoded color floats | Task 1 + 2 — all via `Theme.setColor()` or `Theme.color[name]` |
| Emoji strings removed | Task 1 — not present in new file |
| Endless Mode option removed | Task 1 — not present in new file |
