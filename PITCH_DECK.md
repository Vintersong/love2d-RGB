---


**CHROMATIC**
*A bullet-hell roguelite where your color is your build.*

Built in LÖVE2D - Solo dev prototype

---


> "Every bullet-hell gives you a loadout. CHROMATIC gives you a **commitment**."

At level-up, you don't choose a weapon or a skill — you choose a **color**.

That color changes your projectiles, your dash, your artifacts, and your entire visual identity. And once you've locked in two primary colors, the third is gone forever. You can never go back.

That one constraint is what makes every run feel different.

---


| | RGB | Vampire Survivors | Hades |
|--|-----|-------------------|-------|
| Auto-fire | Yes | Yes | No |
| Build depth | Color tree | Weapon + passive stacking | Boon combinations |
| Unique mechanic | Color commitment | Weapon evolution | Dialogue + relationships |
| Music integration | Reactive spawning | Passive soundtrack | Passive soundtrack |
| Platform | Desktop + Web | Desktop + Console | Desktop + Console |

**The gap RGB fills:** A bullet-hell where the build system has a *concept* — light physics and color theory — not just stat multipliers.

---

```
Move → Survive → Kill → Collect XP orbs → Level up → Pick a color
  ↑                                                         ↓
  ←←←←← projectiles get stronger, faster, and weirder ←←←←←
```

- WASD movement, auto-aim firing at the nearest target.
- Three active abilities: Dash (Space), Blink/Teleport (E), Shield (Q).
- 1920×1080 arena. Enemies approach from off-screen in formation.
- Boss appears every 100 kills.

---



This is the game's core identity.

### Three primaries. Pick two.

| Primary | Path | What it does |
|---------|------|--------------|
| RED | Damage | Crits and split projectiles.|
| GREEN | Bounce | Bounces to enemies. |
| BLUE | Control | Pierce through enemies.|

Once you pick your second primary, the third is **locked out**. Permanently.

### Two primaries unlock one secondary.

| Mix | Secondary |
|-----|-----------|
| RED + GREEN | YELLOW |
| RED + BLUE | MAGENTA |
| GREEN + BLUE | CYAN |


### Color even changes your dash.

| Active Color | Dash Bonus |
|-------------|------------|
| RED | +50% move speed for 2s |
| GREEN | Heal 10% max HP |
| YELLOW | Heal + speed burst combo |
| CYAN | Life-steal off dash-contact damage |
| BLUE | Dash through foes for chip damage |
| MAGENTA | Dash through foes for chip damage |

*(BLUE / MAGENTA / CYAN path damage shares one dash-hit rule in code — CYAN layering also applies lifesteal.)*

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

---
The game's enemy spawning is **driven by the soundtrack**.

- **Two soundtrack candidates** rotate in via `SongLibrary` — whichever loads at boot informs that run unless you swap sources.
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

**Vaporwave / synth-punk.**

- Custom GLSL shader renders the perspective grid canvas; moonshine bloom runs as part of **`BackgroundShader`**, while supplemental **`SimpleGrid`** accents can pulse with the beat (**`T`** hotkey demos the wave ripple in-engine).
- The player's dominant color saturates particles, trails, aura, and much of HUD chrome.
- Each color has its own particle VFX type for dash trails, impacts, and ability effects.
- Floating damage numbers and heal text keep tactical information legible against the neon background.

The aesthetic goal: a game that **looks like the music it reacts to**.

---

### What's working today

- Full color tree: primaries, secondaries
- 3 active abilities (Dash, Blink, Shield) with color-reactive behavior
- 8 artifacts with level scaling and **18** scripted synergies (`SynergySystem`)
- 7 procedural formation patterns for enemy spawning
- Music-reactive spawning with BPM detection
- Boss encounter every 100 kills
- GLSL vaporwave background shader
- Full particle VFX system
- Floating text damage/heal feedback

This is a working prototype.

It has a functional game loop, a deep build system and music reactivity. The core design is validated and the architecture is clean-ish.

