-- PatternSpawner.lua
-- Integration bridge: turns the inert descriptors produced by the standalone pattern library
-- (src/patterns/BulletPatternLibrary.lua + src/patterns/RingBoss.lua) into live Projectile
-- entities. This is the seam those pure modules were designed to plug into -- they stay free
-- of entities / colors / love.*, and colour + entity construction happen HERE.
--
-- Testable without love: both the Projectile constructor (`factory`) and the colour resolver
-- (`resolveColor`) are injectable, so unit tests pass a fake factory and never touch love. In
-- the live game the defaults lazily require the real Projectile and use a static axis->colour
-- map. The module body itself performs no love calls, so it loads under plain Lua.
local PatternSpawner = {}

-- Static color_axis -> RGB resolution. The pattern library deliberately leaves `color_axis`
-- as an unresolved pass-through ("bass"/"mids"/"treble"/nil); colour is resolved in this
-- integration layer. A future audio-reactive resolver can be supplied via opts.resolveColor
-- without changing the library at all.
PatternSpawner.AXIS_COLORS = {
    bass   = { 1.0, 0.30, 0.38 },
    mids   = { 0.35, 1.0, 0.55 },
    treble = { 0.45, 0.65, 1.0 },
}
PatternSpawner.DEFAULT_COLOR = { 1.0, 0.4, 0.8 }

function PatternSpawner.resolveColorAxis(axis, fallback)
    return (axis and PatternSpawner.AXIS_COLORS[axis]) or fallback or PatternSpawner.DEFAULT_COLOR
end

-- Lazily require the real Projectile only when actually spawning in-game (keeps this module
-- love-free at load time so the harness/tests can require it under plain Lua).
local function defaultFactory(x, y, vx, vy, damage, projType, owner)
    return require("src.entities.Projectile")(x, y, vx, vy, damage, projType, owner)
end

-- Convert a descriptor list into live projectiles appended to `sink`.
-- Telegraph markers (type == "telegraph") are SKIPPED -- they are refuge cues for a future
-- renderer, not bullets. Colour precedence: opts.color > descriptor.color > resolved axis.
-- opts: damage, projType, owner, color, fallbackColor, resolveColor(fn), factory(fn)
-- Returns: spawnedCount, skippedTelegraphCount.
function PatternSpawner.spawn(descriptors, sink, opts)
    if not descriptors then return 0, 0 end
    opts = opts or {}
    local factory = opts.factory or defaultFactory
    local resolve = opts.resolveColor or PatternSpawner.resolveColorAxis
    local owner = opts.owner or "boss"
    local projType = opts.projType or "spread"
    local baseDamage = opts.damage or 10

    local spawned, telegraphs = 0, 0
    for i = 1, #descriptors do
        local d = descriptors[i]
        if d.type == "telegraph" then
            telegraphs = telegraphs + 1
        else
            local proj = factory(d.x, d.y, d.vx, d.vy, d.damage or baseDamage, projType, owner)
            proj.color = opts.color or d.color or resolve(d.color_axis, opts.fallbackColor)
            sink[#sink + 1] = proj
            spawned = spawned + 1
        end
    end
    return spawned, telegraphs
end

return PatternSpawner
