# RGB — Pitch Deck

---

## Slide 1 — Title

**RGB**
*A bullet-hell roguelite where your color is your build.*

Built in LÖVE2D · Playable in browser · Solo dev prototype

---

## Slide 2 — The Hook

> "Every bullet-hell gives you a loadout. RGB gives you a **commitment**."

At level-up, you don't choose a weapon or a skill — you choose a **color**.

That color changes your projectiles, your dash, your artifacts, and your entire visual identity. And once you've locked in two primary colors, the third is gone forever. You can never go back.

That one constraint is what makes every run feel different.

---

## Slide 3 — Genre & Positioning

| | RGB | Vampire Survivors | Hades |
|--|-----|-------------------|-------|
| Auto-fire | Yes | Yes | No |
| Build depth | Color tree | Weapon + passive stacking | Boon combinations |
| Unique mechanic | Color commitment | Weapon evolution | Dialogue + relationships |
| Music integration | Reactive spawning | Passive soundtrack | Passive soundtrack |
| Platform | Desktop + Web | Desktop + Console | Desktop + Console |

**The gap RGB fills:** A mechanically expressive bullet-hell where the build system has a *concept* — light physics and color theory — not just stat multipliers.

---

## Slide 4 — Core Gameplay Loop

```
Move → Survive → Kill → Collect XP orbs → Level up → Pick a color
  ↑                                                         ↓
  ←←←←← projectiles get stronger, faster, and weirder ←←←←←
```

- WASD movement, auto-aim firing at the nearest target.
- Three active abilities: Dash (Space), Blink/Teleport (E), Shield (Q).
- 1920×1080 arena. Enemies approach from off-screen in formation.
- Boss appears every 100 kills.

**The loop is fast.** A session can be meaningful in under 15 minutes, or push longer as the player explores deeper color paths.

---

## Slide 5 — The Color System

This is the game's core identity.

### Three primaries. Pick two.

| Primary | Path | What it does |
|---------|------|--------------|
| RED | Damage | More damage. Crits. Explosions. |
| GREEN | Speed | More bullets. Faster firing. Overwhelming volume. |
| BLUE | Control | Pierce. Ricochet. Tactical manipulation. |

Once you pick your second primary, the third is **locked out**. Permanently.

### Two primaries unlock one secondary.

| Mix | Secondary | Flavor |
|-----|-----------|--------|
| RED + GREEN | YELLOW | Explosive AoE bursts |
| RED + BLUE | MAGENTA | Homing projectiles |
| GREEN + BLUE | CYAN | Slowing, piercing, life-stealing |

### Go deep or go wide.

Double a primary (RED→RED) for a **pure path** (Crimson, Emerald, Sapphire) — raw power, but no secondary.

Triple a primary (RED→RED→RED) for an **advanced path** (Blood Red, Forest Green, Deep Blue) — devastation, but the narrowest build possible.

Chase all three? **White Light** — the Transcendence path. All effects. Maximum chaos.

### Color even changes your dash.

| Active Color | Dash Bonus |
|-------------|------------|
| RED | +50% move speed for 2s |
| GREEN | Heal 10% HP |
| CYAN | Life-steal from enemies passed through |
| YELLOW | Heal + speed burst |

---

## Slide 6 — Artifacts & Synergies

**8 artifacts.** Each levels up to 5. Each has color-dependent behavior.

| Artifact | What it does |
|----------|-------------|
| Prism | Splits projectiles into beams |
| Halo | Passive aura damage |
| Mirror | Reflects damage back |
| Lens | Focuses and amplifies |
| Diffusion | Spreads projectiles wide |
| Diffraction | Deflects, pulls enemies and XP |
| Refraction | Bends projectile paths |
| Supernova | Explosive orbital bombs |

**The synergy system is what makes this combinatorial.**

When you hold an artifact that matches your active colors, a named synergy triggers:

- **Prism + RED** → *Rainbow Cascade* — spread projectiles split again on hit
- **Lens + BLUE** → *Laser Focus* — pierce damage accumulates per enemy hit
- **Mirror + CYAN** → *Reflected Suffering* — DoT chains to the next enemy on death
- **Diffraction + YELLOW** → *Gravity Well* — rooted enemies pull others toward them
- **Supernova + MAGENTA** → *Chain Reaction* — 50% chance each explosion cascades

The build space is: 6 active colors × 8 artifacts × 5 levels = **240 distinct artifact states**, with 15+ named synergies layered on top.

---

## Slide 7 — Music Reactivity

The game's enemy spawning is **driven by the soundtrack**.

- BPM is detected automatically on song load.
- Frequency bands (bass, mids, treble) are analyzed in real time.
- Enemy type weights shift to match the dominant frequency:
  - **Bass spike** → heavy tanky enemies flood in
  - **High treble** → fast swarming triangle enemies
- Overall music intensity sets the **spawn rate multiplier** (0.5× to 2.0×).
- Background scroll speed syncs to BPM.
- Beat phase drives visual pulse effects on the player and UI.

The design philosophy: **the music is the game master**. It choreographs encounters. It doesn't punish players for not hitting beats — timing windows are cosmetic feedback only.

This means every song produces a different encounter rhythm. Swapping the soundtrack changes the game.

---

## Slide 8 — Visual Identity

**Vaporwave / synth-punk.**

- Custom GLSL shader renders a retro perspective grid background with glow post-processing.
- The player's dominant color saturates the entire visual layer — particles, trails, aura, and UI all shift hue together.
- Each color has its own particle VFX type for dash trails, impacts, and ability effects.
- Floating damage numbers and heal text keep tactical information legible against the neon background.

The aesthetic goal: a game that **looks like the music it reacts to**.

---

## Slide 9 — Current State

### What's working today

- Full color tree: primaries, secondaries, pure paths, advanced paths, White Light
- 3 active abilities (Dash, Blink, Shield) with color-reactive behavior
- 8 artifacts with level scaling and 15+ defined synergies
- 7 procedural formation patterns for enemy spawning
- Music-reactive spawning with BPM detection
- Boss encounter every 100 kills
- GLSL vaporwave background shader
- Full particle VFX system
- Floating text damage/heal feedback
- Playable in browser via love.js

### What's next

- Wire the active artifact ability (Left Shift) to the artifact system
- Post-level-up input delay (UX)
- Visual clarity improvements for Dash cooldown state
- Tune boss HP (currently effectively invincible — needs a kill condition)
- Expand synergy coverage across all 8 artifacts × 6 colors
- Victory condition / run-end flow

---

## Slide 10 — Roadmap

**Near term (prototype → vertical slice)**
- Active artifact ability fully implemented
- 2–3 hand-crafted songs with authored song structure (tagged sections to escalate difficulty)
- Synergy coverage: all 8 artifacts × all 6 colors
- Victory state with run summary screen
- Polish pass: post-dash delay, dash cooldown clarity, level-up transition

**Medium term (vertical slice → beta)**
- Persistent meta-progression (unlocking artifact types across runs)
- Additional color paths or artifact slots
- Controller support
- Sound effects tied to synergy activations
- Steam / itch.io release candidate

**Long term**
- Console port (Switch is a natural fit for the visual style)
- Modding support via song + structure authoring tools
- Leaderboards by color path

---

## Slide 11 — Why This Works

**The core loop is proven.** Auto-fire roguelites are a validated genre. RGB doesn't reinvent the loop — it installs a genuinely novel identity layer on top.

**The constraint is the fun.** Locking out a primary color is the same design instinct as deck-building restrictions in deckbuilders or spec trees in ARPGs — commitment creates meaningful choices, and meaningful choices create runs worth talking about.

**The music integration is underexplored.** Most roguelites have good soundtracks. RGB has a soundtrack that *plays the game for you* — wave difficulty is never scripted, it's composed.

**The aesthetic is consistent.** Color-as-identity works visually. A RED player looks different from a CYAN player. Players can read their own build at a glance.

---

## Slide 12 — Ask

This is a working prototype.

It has a functional game loop, a deep build system, music reactivity, and browser playability. The core design is validated and the architecture is clean.

**What it needs:**
- Playtesting feedback on color commitment balance
- A second song to prove the music-reactivity generalizes
- A path to a public demo release

**What makes RGB worth betting on:**
The color system is a genuinely original mechanic sitting inside a genre players already understand and love. The ceiling is high. The scope is controlled.

*The game runs today. The question is how far it goes.*
