# VFX Implementation Plan — Trails, Impacts, Shield Hits, Boss Projectiles

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement neon-geometric VFX for projectile trails, impact bursts, shield hit pulses, and 9 distinct boss projectile shapes.

**Architecture:** All changes are confined to 5 existing files — no new files, no new systems, no BootLoader changes. Projectile.lua gains a two-pass trail renderer and 9 boss shape branches. VFXLibrary upgrades spawnImpactBurst to square sparks + ring. ShieldEffect gains a triggerHit API. BossBehaviors wires per-pattern projType strings.

**Tech Stack:** Lua 5.1, LÖVE 11.5 (`love.graphics.*`). No shadowBlur in LÖVE — glow is simulated via `love.graphics.setBlendMode("add")` with semi-transparent wide strokes drawn before the sharp stroke. Boot-check (`lovec.exe`) is the test harness after every task.

---

## File Map

| File | What changes |
|------|-------------|
| `src/entities/Projectile.lua` | Trail two-pass render; `trailLength=18`; `self.rotation=0`, `self.innerRotation=0` init; rotation update per boss type; 9 boss shape branches in `draw()` |
| `src/effects/VFXLibrary.lua` | `spawnImpactBurst`: square sparks + ring particle; `drawImpactBursts`: handle `type="ring"` |
| `src/effects/ShieldEffect.lua` | `hitRings={}` init in `trigger()`; new `triggerHit(color)` function; decay + ring update in `update()`; flash + ring draw in `draw()` |
| `src/data/BossBehaviors.lua` | `patternToProjectiles` gains 5th `projType` param; each of 8 patterns passes correct string; `single_shot` sets `proj.type` directly |
| `src/boss/BossSystem.lua` | `fireCone` uses `"boss_bolt"` |

---

## Task 1: Projectile trail — two-pass neon render

**Files:**
- Modify: `src/entities/Projectile.lua`

Replace `ShapeLibrary.trail(...)` with a two-pass LÖVE renderer. Pass 1 is a wide additive-blend glow. Pass 2 is a thin sharp neon line. Also extend trail length to 18 and add rotation fields for boss shapes (used in Task 4).

- [ ] **Step 1.1 — Add rotation fields to `Projectile:init`**

In `Projectile:init`, after `self.trailLength = 8`, change to:

```lua
self.trailLength = 18
self.rotation = 0
self.innerRotation = 0
```

- [ ] **Step 1.2 — Replace trail render in `Projectile:draw`**

Find the `ShapeLibrary.trail(self.trail, size, color, {fadeAlpha = 0.5})` call (around line 80) and replace it with:

```lua
-- Two-pass neon trail
if #self.trail > 1 then
    local r, g, b = color[1], color[2], color[3]
    local len = #self.trail

    -- Pass 1: wide glow (additive blend)
    love.graphics.setBlendMode("add")
    for i = 2, len do
        local t = 1 - (i - 1) / len
        love.graphics.setColor(r, g, b, t * 0.18)
        love.graphics.setLineWidth(t * 10)
        love.graphics.line(
            self.trail[i-1].x, self.trail[i-1].y,
            self.trail[i].x,   self.trail[i].y
        )
    end
    love.graphics.setBlendMode("alpha")

    -- Pass 2: sharp neon line
    for i = 2, len do
        local t = 1 - (i - 1) / len
        love.graphics.setColor(r, g, b, t * 0.85)
        love.graphics.setLineWidth(t * 2.5)
        love.graphics.line(
            self.trail[i-1].x, self.trail[i-1].y,
            self.trail[i].x,   self.trail[i].y
        )
    end
end
```

- [ ] **Step 1.3 — Replace core dot draw**

Each projectile type block currently draws its own shape. After each type's draw call, ensure the white core dot is drawn. The existing `else` branch already draws `ShapeLibrary.circle` with a core — leave those untouched. Only the trail above is replaced. The core dot for all types will be handled in Task 4 boss shape section. For non-boss types, the existing shape renderers handle the core already.

- [ ] **Step 1.4 — Reset line width after trail**

After Pass 2, reset:

```lua
love.graphics.setLineWidth(1)
love.graphics.setColor(1, 1, 1, 1)
```

- [ ] **Step 1.5 — Boot check**

```
"C:\Program Files\LOVE\lovec.exe" .
```

Expected: `BOOT LOADER REPORT — ALL SYSTEMS OPERATIONAL`, game reaches Menu state, projectiles fire and show longer glowing trails in-game (press Space to start, observe player shots).

- [ ] **Step 1.6 — Commit**

```
git add src/entities/Projectile.lua
git commit -m "feat: two-pass neon trail with additive glow, trailLength 18"
```

---

## Task 2: Impact burst — square sparks + expanding ring

**Files:**
- Modify: `src/effects/VFXLibrary.lua`

`spawnImpactBurst` currently spawns plain circles. Replace sparks with squares and add one expanding ring particle per burst.

- [ ] **Step 2.1 — Update `spawnImpactBurst`**

Replace the entire `spawnImpactBurst` function body (lines ~448–467):

```lua
function VFXLibrary.spawnImpactBurst(x, y, color, count)
    count = count or 9
    color = color or {1, 1, 1}

    -- Square sparks
    for i = 1, count do
        local angle = ((i - 1) / count) * math.pi * 2 + (math.random() - 0.5) * 0.3
        local speed = 70 + math.random() * 110

        table.insert(VFXLibrary.impactParticles, {
            type  = "spark",
            x     = x,
            y     = y,
            vx    = math.cos(angle) * speed,
            vy    = math.sin(angle) * speed,
            color = {color[1], color[2], color[3]},
            life  = 1,
            maxLife = 0.28 + math.random() * 0.27,
            size  = 2 + math.random() * 2,
        })
    end

    -- Expanding ring
    table.insert(VFXLibrary.impactParticles, {
        type    = "ring",
        x       = x,
        y       = y,
        vx      = 0,
        vy      = 0,
        color   = {color[1], color[2], color[3]},
        life    = 1,
        maxLife = 0.35,
        size    = 0,     -- current radius (updated in updateImpactBursts)
        maxSize = 28,
    })
end
```

- [ ] **Step 2.2 — Update `updateImpactBursts` to handle ring radius**

Replace the update loop body so rings grow their radius:

```lua
function VFXLibrary.updateImpactBursts(dt)
    for i = #VFXLibrary.impactParticles, 1, -1 do
        local p = VFXLibrary.impactParticles[i]

        p.x    = p.x + p.vx * dt
        p.y    = p.y + p.vy * dt
        p.life = p.life - dt / p.maxLife

        if p.life <= 0 then
            table.remove(VFXLibrary.impactParticles, i)
        elseif p.type == "spark" then
            p.vx = p.vx * 0.86
            p.vy = p.vy * 0.86
        elseif p.type == "ring" then
            p.size = p.maxSize * (1 - p.life)
        end
    end
end
```

- [ ] **Step 2.3 — Update `drawImpactBursts` for squares and rings**

Replace the draw loop body:

```lua
function VFXLibrary.drawImpactBursts()
    for _, p in ipairs(VFXLibrary.impactParticles) do
        local c = p.color
        if p.type == "spark" then
            love.graphics.setColor(c[1], c[2], c[3], p.life)
            local sz = p.size * p.life
            love.graphics.rectangle("fill", p.x - sz * 0.5, p.y - sz * 0.5, sz, sz)
        elseif p.type == "ring" then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(c[1], c[2], c[3], p.life * 0.85)
            love.graphics.setLineWidth(1.8 * p.life)
            love.graphics.circle("line", p.x, p.y, math.max(0.1, p.size))
            love.graphics.setBlendMode("alpha")
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end
```

- [ ] **Step 2.4 — Boot check**

```
"C:\Program Files\LOVE\lovec.exe" .
```

Expected: game boots clean. In-game, projectile hits show square sparks + expanding ring instead of plain circles.

- [ ] **Step 2.5 — Commit**

```
git add src/effects/VFXLibrary.lua
git commit -m "feat: impact burst — square sparks + expanding ring, neon geometric"
```

---

## Task 3: Shield hit pulse

**Files:**
- Modify: `src/effects/ShieldEffect.lua`

Add `hitRings` list to the active shield state, a `triggerHit(color)` entry point, and update/draw logic for flash + ring expansion.

- [ ] **Step 3.1 — Initialize `hitRings` in `ShieldEffect.trigger`**

Inside `ShieldEffect.trigger`, after `active = { ... }`, add:

```lua
active.hitRings    = {}
active.flashAlpha  = 0
active.hitColor    = {1, 1, 1}
```

The full `trigger` function block becomes:

```lua
function ShieldEffect.trigger(x, y, config)
    config = config or {}
    active = {
        maxRadius   = config.maxRadius   or 64,
        expandSpeed = config.expandSpeed or 500,
        rotateSpeed = config.rotateSpeed or 1.5,
        fadeSpeed   = config.fadeSpeed   or 3,
        outerColor  = config.outerColor  or {0.1, 0.1, 0.1, 0.0},
        innerColor  = config.innerColor  or {0.8, 0.8, 0.8, 0.7},
        radius      = 0,
        alpha       = config.alpha or 0.5,
        rotation    = 0,
        alive       = true,
        expanding   = true,
        cx          = x,
        cy          = y,
        -- hit pulse state
        hitRings    = {},
        flashAlpha  = 0,
        hitColor    = {1, 1, 1},
    }
end
```

- [ ] **Step 3.2 — Add `ShieldEffect.triggerHit(color)`**

Add this function after `ShieldEffect.despawn`:

```lua
function ShieldEffect.triggerHit(color)
    if not active then return end
    active.flashAlpha = 1.0
    active.hitColor   = color or {0.8, 0.8, 0.8}
    local r = active.maxRadius
    table.insert(active.hitRings, {
        life     = 1,
        maxLife  = 0.5,
        startR   = r,
        maxR     = r + 30,
        delay    = 0,
    })
    table.insert(active.hitRings, {
        life     = 1,
        maxLife  = 0.7,
        startR   = r,
        maxR     = r + 50,
        delay    = 0.1,
    })
end
```

- [ ] **Step 3.3 — Update `ShieldEffect.update` to tick flash + rings**

After the existing rotation update line (`active.rotation = ...`), add:

```lua
    -- Flash decay
    if active.flashAlpha > 0 then
        active.flashAlpha = math.max(0, active.flashAlpha - dt * 5)
    end

    -- Hit rings
    for i = #active.hitRings, 1, -1 do
        local ring = active.hitRings[i]
        if ring.delay > 0 then
            ring.delay = ring.delay - dt
        else
            ring.life = ring.life - dt / ring.maxLife
            if ring.life <= 0 then
                table.remove(active.hitRings, i)
            end
        end
    end
```

- [ ] **Step 3.4 — Update `ShieldEffect.draw` to render flash + rings**

After the existing `love.graphics.setBlendMode("alpha")` / reset line (end of the gradient draw block), add:

```lua
    -- Flash overlay
    if active.flashAlpha > 0 then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, active.flashAlpha * 0.25)
        love.graphics.circle("fill", cx, cy, radius)
        love.graphics.setColor(1, 1, 1, active.flashAlpha * 0.7)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", cx, cy, radius)
        love.graphics.setBlendMode("alpha")
    end

    -- Expanding hit rings
    if #active.hitRings > 0 then
        local hc = active.hitColor
        love.graphics.setBlendMode("add")
        for _, ring in ipairs(active.hitRings) do
            if ring.delay <= 0 and ring.life > 0 then
                local progress = 1 - ring.life
                local r2 = ring.startR + (ring.maxR - ring.startR) * progress
                love.graphics.setColor(hc[1], hc[2], hc[3], ring.life * 0.85)
                love.graphics.setLineWidth(2.5 * ring.life)
                love.graphics.circle("line", cx, cy, math.max(0.1, r2))
            end
        end
        love.graphics.setBlendMode("alpha")
    end
```

- [ ] **Step 3.5 — Wire `triggerHit` in `PlayingEnemyFlow.lua`**

Open `src/states/playing/PlayingEnemyFlow.lua`. Find where boss projectile collision with player is handled (search for `proj.damage` near shield/HALO logic). After a boss projectile is blocked by the shield (wherever `ShieldEffect` is currently called or where `player.invulnerable` is set by HALO), add:

```lua
local ShieldEffect = require("src.effects.ShieldEffect")
ShieldEffect.triggerHit(proj.color or {1, 0.4, 0.8})
```

> **Note:** If the exact call site is ambiguous after reading the file, search for `ShieldEffect` or `HALO` references in `PlayingEnemyFlow.lua` and `HaloArtifact.lua` to find where shield blocking happens, then add the call there.

- [ ] **Step 3.6 — Boot check**

```
"C:\Program Files\LOVE\lovec.exe" .
```

Expected: boots clean. With HALO artifact equipped, boss projectile hits cause the shield to flash white + emit two expanding rings.

- [ ] **Step 3.7 — Commit**

```
git add src/effects/ShieldEffect.lua src/states/playing/PlayingEnemyFlow.lua
git commit -m "feat: shield hit pulse — flash + expanding rings on boss projectile block"
```

---

## Task 4: Boss projectile draw shapes

**Files:**
- Modify: `src/entities/Projectile.lua`

Add rotation update per boss type in `update()`, then add 9 draw branches in `draw()`.

- [ ] **Step 4.1 — Add rotation update to `Projectile:update`**

At the end of `Projectile:update`, before the final `end`, add:

```lua
    -- Boss projectile rotation
    local rotSpeeds = {
        boss_diamond = 4.0,
        boss_orb     = 3.0,
        boss_shard   = 2.5,
        boss_cross   = 2.0,
        boss_twinorb = 2.0,
        boss_petal   = 1.0,
    }
    local rs = rotSpeeds[self.type]
    if rs then
        self.rotation = self.rotation + rs * dt
    end
    if self.type == "boss_twinorb" then
        self.innerRotation = self.innerRotation - 3.5 * dt
    end
```

- [ ] **Step 4.2 — Add boss shape draw branches to `Projectile:draw`**

In `Projectile:draw`, after the existing `else` branch (the default circle), add before the closing `end` of the type dispatch:

```lua
    elseif self.type == "boss_diamond" then
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.rotation)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(color[1], color[2], color[3], 0.3)
        love.graphics.polygon("fill", 0,-9, 9,0, 0,9, -9,0)
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.polygon("line", 0,-7, 7,0, 0,7, -7,0)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", 0, 0, 2)
        love.graphics.pop()

    elseif self.type == "boss_bolt" then
        local angle = MathUtils.atan2(self.vy, self.vx) + math.pi * 0.5
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(angle)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.polygon("line", 0,-10, 3,-2, 2,10, -2,10, -3,-2)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(color[1], color[2], color[3], 0.35)
        love.graphics.ellipse("fill", 0, 0, 2.5, 7)
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", 0, 0, 1.5)
        love.graphics.pop()

    elseif self.type == "boss_orb" then
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.rotation)
        love.graphics.setColor(color[1], color[2], color[3], 0.9)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", 0, 0, 6)
        love.graphics.setColor(color[1], color[2], color[3], 0.6)
        love.graphics.circle("line", 0, 0, 3)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.circle("fill", 0, 0, 1.5)
        love.graphics.pop()

    elseif self.type == "boss_shard" then
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.rotation)
        local verts = {}
        for k = 0, 7 do
            local a = (k / 8) * math.pi * 2
            local r2 = (k % 2 == 0) and 8 or 3.5
            table.insert(verts, math.cos(a) * r2)
            table.insert(verts, math.sin(a) * r2)
        end
        love.graphics.setBlendMode("add")
        love.graphics.setColor(color[1], color[2], color[3], 0.2)
        love.graphics.polygon("fill", verts)
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.polygon("line", verts)
        love.graphics.pop()

    elseif self.type == "boss_crescent" then
        local angle = MathUtils.atan2(self.vy, self.vx)
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(angle)
        love.graphics.setColor(color[1], color[2], color[3], 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", 0, 0, 7, 0.5, math.pi - 0.5)
        love.graphics.arc("line", "open", 3, 0, 5, math.pi + 0.35, math.pi * 2 - 0.35)
        love.graphics.pop()

    elseif self.type == "boss_cross" then
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.rotation)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.rectangle("fill", -1.5, -9, 3, 18)
        love.graphics.rectangle("fill", -9, -1.5, 18, 3)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.circle("fill", 0, 0, 2)
        love.graphics.pop()

    elseif self.type == "boss_chevron" then
        local angle = MathUtils.atan2(self.vy, self.vx)
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(angle)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(-6, 5, 0, -8)
        love.graphics.line(0, -8, 6, 5)
        love.graphics.setLineWidth(1.5)
        love.graphics.setColor(color[1], color[2], color[3], 0.6)
        love.graphics.line(-4, 10, 0, 1)
        love.graphics.line(0, 1, 4, 10)
        love.graphics.pop()

    elseif self.type == "boss_twinorb" then
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.rotation)
        love.graphics.setColor(color[1], color[2], color[3], 0.9)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", 0, 0, 7)
        -- Inner counter-rotating dots (innerRotation is in world space, undo outer rotation)
        local ir = (self.innerRotation or 0) - self.rotation
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", math.cos(ir) * 4,           math.sin(ir) * 4,           2)
        love.graphics.circle("fill", math.cos(ir + math.pi) * 4, math.sin(ir + math.pi) * 4, 2)
        love.graphics.pop()

    elseif self.type == "boss_petal" then
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.rotation)
        love.graphics.setColor(color[1], color[2], color[3], 0.85)
        love.graphics.setLineWidth(1.5)
        for k = 0, 5 do
            local a = (k / 6) * math.pi * 2
            love.graphics.push()
            love.graphics.rotate(a)
            love.graphics.ellipse("line", 0, -5, 2.5, 4.5)
            love.graphics.pop()
        end
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("fill", 0, 0, 2)
        love.graphics.pop()
```

- [ ] **Step 4.3 — Reset graphics state after draw**

After the entire type dispatch block (after the final `end`), ensure:

```lua
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
```

- [ ] **Step 4.4 — Boot check**

```
"C:\Program Files\LOVE\lovec.exe" .
```

Expected: boots clean. Boss projectiles (when boss spawns) show distinct shapes. Player projectiles unaffected.

- [ ] **Step 4.5 — Commit**

```
git add src/entities/Projectile.lua
git commit -m "feat: 9 distinct boss projectile shapes with per-type rotation"
```

---

## Task 5: Wire projTypes in BossBehaviors + BossSystem

**Files:**
- Modify: `src/data/BossBehaviors.lua`
- Modify: `src/boss/BossSystem.lua`

Each of the 9 attack pattern `execute` functions needs to pass the correct `projType` to `patternToProjectiles`. `single_shot` creates its projectile directly. `BossSystem:fireCone` also needs updating.

- [ ] **Step 5.1 — Add `projType` parameter to `patternToProjectiles`**

Find the local function `patternToProjectiles` at the top of `BossBehaviors.lua` (~line 17):

```lua
local function patternToProjectiles(patternProjectiles, bossProjectiles, damage, color)
    for _, p in ipairs(patternProjectiles) do
        local proj = Projectile(p.x, p.y, p.vx, p.vy, p.damage or damage, "spread", "boss")
```

Replace with:

```lua
local function patternToProjectiles(patternProjectiles, bossProjectiles, damage, color, projType)
    for _, p in ipairs(patternProjectiles) do
        local proj = Projectile(p.x, p.y, p.vx, p.vy, p.damage or damage, projType or "spread", "boss")
```

- [ ] **Step 5.2 — Update `single_shot` execute**

Find the `single_shot` execute block (~line 139). Change:

```lua
local proj = Projectile(boss.x, boss.y, math.cos(angle) * 350, math.sin(angle) * 350, 15, "basic", "boss")
```

to:

```lua
local proj = Projectile(boss.x, boss.y, math.cos(angle) * 350, math.sin(angle) * 350, 15, "boss_diamond", "boss")
```

- [ ] **Step 5.3 — Update the 8 pattern-based execute calls**

For each pattern, add the `projType` string as the 5th argument to `patternToProjectiles`. Make these changes:

| Pattern id | Current call | Add 5th arg |
|-----------|-------------|------------|
| `spread_cone` | `patternToProjectiles(projs, context.bossProjectiles, 10, {1.0, 0.6, 0.2})` | `"boss_bolt"` |
| `spiral` | `patternToProjectiles(projs, context.bossProjectiles, 8, {1.0, 0.6, 0.2})` | `"boss_orb"` |
| `circle_burst` | `patternToProjectiles(projs, context.bossProjectiles, 12, {0.8, 0.2, 1.0})` | `"boss_shard"` |
| `wave` | `patternToProjectiles(projs, context.bossProjectiles, 10, {0.2, 0.8, 1.0})` | `"boss_crescent"` |
| `cross` | `patternToProjectiles(projs, context.bossProjectiles, 12, {0.8, 1.0, 0.3})` | `"boss_cross"` |
| `slam` | `patternToProjectiles(projs, context.bossProjectiles, 20, {1.0, 0.2, 0.2})` | `"boss_chevron"` |
| `double_spiral` | `patternToProjectiles(projs, context.bossProjectiles, 15, {0.3, 0.9, 1.0})` | `"boss_twinorb"` |
| `flower` | `patternToProjectiles(projs, context.bossProjectiles, 12, {1.0, 0.45, 0.8})` | `"boss_petal"` |

Example for `spread_cone` (same pattern for all 8):

```lua
patternToProjectiles(projs, context.bossProjectiles, 10, {1.0, 0.6, 0.2}, "boss_bolt")
```

- [ ] **Step 5.4 — Update `BossSystem:fireCone`**

In `src/boss/BossSystem.lua`, find `BossSystem:fireCone` (~line 203). Change the `Projectile(...)` call:

```lua
local proj = Projectile(self.x, self.y, vx, vy, 30, "spread", "boss")
```

to:

```lua
local proj = Projectile(self.x, self.y, vx, vy, 30, "boss_bolt", "boss")
```

- [ ] **Step 5.5 — Boot check**

```
"C:\Program Files\LOVE\lovec.exe" .
```

Expected: boots clean. Kill 100 enemies to trigger the boss. Each attack pattern fires projectiles with its distinct shape.

- [ ] **Step 5.6 — Commit**

```
git add src/data/BossBehaviors.lua src/boss/BossSystem.lua
git commit -m "feat: wire per-pattern boss projTypes — 9 distinct shapes in combat"
```

---

## Self-Review

**Spec coverage check:**

| Spec section | Task covering it |
|-------------|-----------------|
| §2 Trails — two-pass, trailLength 18 | Task 1 |
| §3 Impact burst — square sparks + ring | Task 2 |
| §4 Shield hit — flash + two rings, triggerHit API | Task 3 |
| §4 Guard: triggerHit when active==nil | Task 3.2 (guard is first line of triggerHit) |
| §5 Boss shapes — all 9 projTypes | Task 4 |
| §5 Rotation speeds per type | Task 4.1 |
| §5 Velocity-aligned types | Task 4.2 (bolt/crescent/chevron use atan2) |
| §5 boss_twinorb innerRotation | Task 4.1 + 4.2 |
| §5 BossBehaviors projType wiring | Task 5 |
| §5 BossSystem:fireCone | Task 5.4 |
| §6 self.rotation init | Task 1.1 |
| §6 hitRings init in trigger() | Task 3.1 |

**Placeholder scan:** No TBDs. All code blocks are complete Lua. All file paths are exact.

**Type consistency:**
- `active.hitRings` — initialized in Task 3.1, written in Task 3.2, read in Task 3.3 and 3.4. ✓
- `active.flashAlpha` — initialized Task 3.1, set Task 3.2, decayed Task 3.3, drawn Task 3.4. ✓
- `self.rotation` / `self.innerRotation` — initialized Task 1.1, updated Task 4.1, read Task 4.2. ✓
- `projType` param — added Task 5.1, passed in Tasks 5.2–5.4, consumed in Projectile:draw Task 4.2. ✓
