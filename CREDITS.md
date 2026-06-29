# CHROMATIC — Credits, Tools & Third-Party Licenses

This document lists the engine, libraries, tools, and assets used in CHROMATIC and their
licenses, for the Student Games Festival 2026 submission (rules §2.6, §2.7, §3.2).

## Game
- **CHROMATIC** © 2025 Vintersong. Game code licensed **MIT** (see `LICENSE`). Original work.

## Engine / runtime
| Component | Version | License | Source |
|-----------|---------|---------|--------|
| **LÖVE (love2d)** | 11.5 | zlib/libpng | https://love2d.org |

## Vendored libraries (`libs/`)
| Library | Author | License | Notes |
|---------|--------|---------|-------|
| **hump** (`hump-master`) | Matthias Richter | MIT | gamestate, class, vector, timer |
| **flux** (`flux-master`) | rxi | MIT | `libs/flux-master/LICENSE` — tweening |
| **bump.lua** (`bump.lua-master`) | kikito (Enrique García) | MIT | AABB collision |
| **moonshine** (`moonshine-master`) | Matthias Richter / contributors | MIT | post-processing shaders |
| **ripple** (`ripple-master`) | tesselode | MIT | `libs/ripple-master/LICENSE` — audio helper |

> ACTION: confirm each library's upstream `LICENSE` text is included in the shipped build
> (`libs/` is bundled in the `.love`). hump / bump / moonshine ship without a license file in
> this tree — add their upstream MIT license text to `libs/<name>/LICENSE` before submitting.

## Fonts (`assets/fonts/`)
| Font | License |
|------|---------|
| Michroma | SIL Open Font License 1.1 |
| Chakra Petch (Regular/Medium/SemiBold/Bold) | SIL Open Font License 1.1 |
| Share Tech Mono | SIL Open Font License 1.1 |

License text: `assets/fonts/OFL.txt`.

## Audio (`assets/music/`, `assets/songs/`, `assets/sfx/`)
| File | Type | Source / License |
|------|------|------------------|
| `assets/music/song1.wav` | music track | **TODO — confirm source & license** |
| `assets/music/song2.wav` | music track | **TODO — confirm source & license** |
| `assets/sfx/Dash.mp3` | sound effect | **TODO — confirm source & license** |
| `assets/sfx/MenuSelectorMove.wav` | sound effect | **TODO — confirm source & license** |

> ACTION (rules §2.3 originality, §2.7 asset disclosure): every audio file must be an
> original work OR used under a license that permits this use. Fill in the source and license
> for each file above, and ensure proof/links are declared on the submission form. Submissions
> that do not comply with asset licenses are rejected (§3.3).

## Generative AI
AI use must be disclosed on the submission form (rules §3.2). See the submission form / your
AI-use statement for details of how AI tools were used in development.
