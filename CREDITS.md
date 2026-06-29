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
| `assets/music/song1.wav` | music track | **Suno** (generative AI) — commercial-use rights held by the author. **AI-generated: must be disclosed (see below).** |
| `assets/music/song2.wav` | music track | **Suno** (generative AI) — commercial-use rights held by the author. **AI-generated: must be disclosed (see below).** |
| `assets/sfx/Dash.mp3` | sound effect | **OpenGameArt.com** — **TODO: record the exact license (e.g. CC0 / CC-BY / CC-BY-SA) + author, and add attribution if required.** |
| `assets/sfx/MenuSelectorMove.wav` | sound effect | **TODO — confirm source & license** |

> ACTION (rules §2.3 originality, §2.7 asset disclosure): every audio file must be an
> original work OR used under a license that permits this use, and disclosed on the submission
> form. For the Suno tracks, keep proof of your commercial-rights tier. For the OpenGameArt
> effect, note the exact license — if it is CC-BY / CC-BY-SA you must credit the author by name
> here and in-game. `MenuSelectorMove.wav` still needs its source confirmed. Submissions that do
> not comply with asset licenses are rejected (§3.3).

## Generative AI (disclosure — rules §3.2)
Generative AI was used in this project and is disclosed as required:
- **Music** — both in-game tracks were generated with **Suno** (a generative-AI music tool);
  the author holds commercial-use rights to the generated audio.
- **Code** — an AI coding assistant was used to help write/refactor game-system code under
  author direction; all design, integration, and final review were done by the team.

No AI-generated visual art or narrative assets are used. The exact wording above should also be
entered in the submission form's AI-disclosure field.
