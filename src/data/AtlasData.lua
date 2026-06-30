-- AtlasData.lua
-- Canonical reference copy for CHROMATIC colors and artifacts. Single source shared
-- by AtlasState (reference screen) and FirstEncounter (first-pickup teaching).
local Theme = require("src.render.Theme")

local AtlasData = {}

AtlasData.colorEntries = {
    {
        name = "RED",
        color = Theme.color.red,
        principle = "Emission / pressure",
        effect = "Adds spread and extra projectiles. Red turns one beam into a field of threat.",
        tell = "Look for wider firing cones, extra red-shot lanes, and denser impact bursts.",
        light = "Red is the longest primary wavelength here: broad, forceful, and space-filling.",
        mixes = "RED + GREEN -> YELLOW. RED + BLUE -> MAGENTA.",
    },
    {
        name = "GREEN",
        color = Theme.color.green,
        principle = "Reflection / adaptation",
        effect = "Adds bounce and seeking behavior. Green redirects energy instead of wasting it.",
        tell = "Look for projectiles changing direction after hits or edges instead of simply vanishing.",
        light = "Green represents adaptive routing: light finding another surface, then another target.",
        mixes = "GREEN + RED -> YELLOW. GREEN + BLUE -> CYAN.",
    },
    {
        name = "BLUE",
        color = Theme.color.blue,
        principle = "Focus / control",
        effect = "Adds pierce and precision. Blue keeps a beam coherent through multiple targets.",
        tell = "Look for shots passing through enemies and continuing along the same clean path.",
        light = "Blue is short-wavelength control: narrow, clean, and hard to stop.",
        mixes = "BLUE + RED -> MAGENTA. BLUE + GREEN -> CYAN.",
    },
    {
        name = "YELLOW",
        color = Theme.color.yellow,
        principle = "Constructive mixing",
        effect = "RED + GREEN. Keeps spread and bounce while accelerating the weapon rhythm.",
        tell = "Look for faster firing rhythm with both spread pressure and redirected shots.",
        light = "Yellow is additive light overlap: pressure plus routing becomes velocity.",
        mixes = "Secondary commitment from RED and GREEN.",
    },
    {
        name = "MAGENTA",
        color = Theme.color.magenta,
        principle = "Unstable interference",
        effect = "RED + BLUE. Keeps spread and pierce while adding detonation/time pressure.",
        tell = "Look for magenta explosions, burst damage, and projectile paths that still pierce.",
        light = "Magenta is non-spectral synthesis: a constructed color, volatile and artificial.",
        mixes = "Secondary commitment from RED and BLUE.",
    },
    {
        name = "CYAN",
        color = Theme.color.cyan,
        principle = "Cooling diffraction",
        effect = "GREEN + BLUE. Keeps bounce and pierce while adding frost, slow, and damage over time.",
        tell = "Look for cyan trails, slowed enemies, and damage continuing after the first hit.",
        light = "Cyan bends adaptive energy into control: reflected light becomes a slowing field.",
        mixes = "Secondary commitment from GREEN and BLUE.",
    },
}

AtlasData.artifactEntries = {
    {
        name = "PRISM",
        color = Theme.color.magenta,
        principle = "Refraction split",
        effect = "Splits, walls, orbiting beams, and prismatic projectile mutations.",
        tell = "Look for prismatic rings and triangular shards near the player; shots split or fan into readable ray patterns.",
        light = "A prism separates white intent into component paths. It makes one shot become many readable rays.",
    },
    {
        name = "LENS",
        color = Theme.color.blue,
        principle = "Focal convergence",
        effect = "Merges, enlarges, pulls, and concentrates projectile power.",
        tell = "Look for narrow blue beam shards near the player; shots become larger, heavier, or pulled into focus.",
        light = "A lens bends paths toward focus. In combat, it turns loose color into a sharper beam.",
    },
    {
        name = "MIRROR",
        color = Theme.color.cyan,
        principle = "Reflection echo",
        effect = "Adds reflected shots, echo bounces, dual walls, and temporal copies.",
        tell = "Look for pale reflective panels near the player; duplicate and echo shots trace mirrored routes.",
        light = "A mirror preserves angle and intent. It doubles a pattern without changing its source color.",
    },
    {
        name = "HALO",
        color = Theme.color.yellow,
        principle = "Atmospheric ring",
        effect = "Creates color-dependent aura fields: fire, drain, slow, electric pulse, time bubble, frost.",
        tell = "Look around the player, not the projectile: HALO draws a persistent dominant-color aura field.",
        light = "A halo is light scattered through atmosphere. It turns your dominant color into local weather.",
    },
    {
        name = "AURORA",
        color = Theme.color.green,
        principle = "Ionized glow",
        effect = "Regeneration and dominant-color aura interactions.",
        tell = "Look for survival pulses and aurora arcs around the player when healing or aura effects update.",
        light = "Aurora is charged light in motion. It makes survival effects pulse outward through color.",
    },
    {
        name = "DIFFRACTION",
        color = Theme.color.red,
        principle = "Wave interference",
        effect = "Creates burst patterns, magnetized pickups, and color-wave interference effects.",
        tell = "Look for orange spoke rings and square sparks near the player; shots form cones, bursts, or wave-like sources.",
        light = "Diffraction bends around edges. It rewards crowded spaces and overlapping wavefronts.",
    },
    {
        name = "REFRACTION",
        color = Theme.color.accent,
        principle = "Path bending",
        effect = "Creates spirals, satellites, synchronized hits, and bending projectile paths.",
        tell = "Look for violet rotating rings near the player; shots curve, spiral, or orbit instead of flying straight.",
        light = "Refraction changes direction when light crosses media. It makes shots curve through combat.",
    },
    {
        name = "SUPERNOVA",
        color = Theme.color.warn,
        principle = "Stellar release",
        effect = "Turns stored pressure into screen-scale color events and ultimate pulses.",
        tell = "Look for a SUPERNOVA burst callout and a large radial blast centered on the player.",
        light = "A supernova is emission without restraint: color collapse becoming a battlefield event.",
    },
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
