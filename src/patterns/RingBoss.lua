-- RingBoss: standalone, pure choreography + configuration for the final boss.
--
-- The final boss is a rotating dodecagonal ring -- twelve nodes (each a semitone) around a
-- central core. The CORE is the hitbox/HP; the RING is the weapon system. The four phases
-- are configurations of this ONE entity reconfiguring, not separate fights:
--   P1 ranged      : full ring rotates, nodes fire radial/spiral + the 6/6 pillar curtain.
--   P2 close follow: ring collapses inward toward the core, short-range chase.
--   P3 lasers      : ring spreads out, node PAIRS fire as interval "chords"
--                    (perfect-fifth = 7 semitones apart, tritone = 6 apart).
--   P4 burn/dodge  : ring closes into a full circle, all 12 nodes fire inward at once,
--                    the core is EXPOSED -- the only phase where it is vulnerable.
--
-- This module is PURE and self-contained, exactly like BulletPatternLibrary:
--   * Generators return inert spawn descriptors ({x,y,vx,vy,color_axis,...}); no entities,
--     no globals, no love.*/Config/MathUtils, no rendering, no color/luminance resolution.
--   * Animation timing is driven by a caller-supplied `t`, never an internal timer.
--   * Deterministic. It reuses BulletPatternLibrary (also pure) for pillar descriptors.
-- The only live-game touchpoint is the win condition, which is flag-gated; this module just
-- provides the pure router (`evaluateWincon`) and the boss-state helpers it needs.
local BulletPatternLibrary = require("src.patterns.BulletPatternLibrary")

local RingBoss = {}

local TWO_PI = math.pi * 2

-- Phase identifiers (configurations of the same entity).
RingBoss.PHASE = { P1 = 1, P2 = 2, P3 = 3, P4 = 4 }

-- Per-phase configuration data. These are the four ring states; transitions are
-- parameterized (HP thresholds or external trigger), never hardcoded into behavior.
--   radiusScale : ring radius relative to baseRadius (collapse < 1 < spread)
--   rotates     : does the ring spin in this phase
--   fireMode    : descriptive tag for the emitter behavior (renderer/AI dispatch later)
--   coreVulnerable : is the central core damageable in this phase (ONLY P4)
RingBoss.PHASE_CONFIG = {
    [1] = { id = "P1", name = "ranged",       fireMode = "radial_spiral", radiusScale = 1.00, rotates = true,  coreVulnerable = false, pillarCurtain = true },
    [2] = { id = "P2", name = "close_follow", fireMode = "follow",        radiusScale = 0.32, rotates = false, coreVulnerable = false, collapse = true },
    [3] = { id = "P3", name = "lasers",       fireMode = "lasers",        radiusScale = 1.40, rotates = false, coreVulnerable = false, laserInterval = 7 },
    [4] = { id = "P4", name = "burn_dodge",   fireMode = "inward_all",    radiusScale = 0.78, rotates = false, coreVulnerable = true,  closed = true },
}

-- The two whole-tone scales: the symmetric 6+6 partition of the 12 semitones.
-- Used as a SELECTABLE, structural gap-position generator (cosmetic ordering, no audio).
RingBoss.WHOLE_TONE = {
    [0] = { 0, 2, 4, 6, 8, 10 }, -- even semitones
    [1] = { 1, 3, 5, 7, 9, 11 }, -- odd semitones
}

-- ---------------------------------------------------------------------------
-- Phase configuration / state machine (parameterized, no hardcoded triggers)
-- ---------------------------------------------------------------------------

function RingBoss.phaseConfig(phaseId)
    return RingBoss.PHASE_CONFIG[phaseId] or RingBoss.PHASE_CONFIG[1]
end

-- The core is vulnerable ONLY in Phase 4 (closing circle / core exposed).
function RingBoss.isCoreVulnerable(phaseId)
    return RingBoss.phaseConfig(phaseId).coreVulnerable == true
end

-- HP-threshold transition. thresholds are descending HP fractions {t1,t2,t3}:
--   frac > t1 -> P1, frac > t2 -> P2, frac > t3 -> P3, else P4.
function RingBoss.phaseForHealth(frac, thresholds)
    -- Per-index fallbacks so a short/partial custom thresholds table can't crash the compare.
    local t1 = (thresholds and thresholds[1]) or 0.75
    local t2 = (thresholds and thresholds[2]) or 0.5
    local t3 = (thresholds and thresholds[3]) or 0.25
    if frac > t1 then
        return RingBoss.PHASE.P1
    elseif frac > t2 then
        return RingBoss.PHASE.P2
    elseif frac > t3 then
        return RingBoss.PHASE.P3
    end
    return RingBoss.PHASE.P4
end

-- External-trigger transition (e.g. scripted): advance to the next phase, clamped at P4.
function RingBoss.nextPhase(current)
    return math.min((current or RingBoss.PHASE.P1) + 1, RingBoss.PHASE.P4)
end

-- ---------------------------------------------------------------------------
-- Ring geometry (used for emitter layouts / preview; pure)
-- ---------------------------------------------------------------------------

-- Twelve nodes evenly placed on a circle. Each node carries its index/semitone (0..11).
function RingBoss.ringNodes(center, radius, count, rotation)
    count = count or 12
    rotation = rotation or 0
    center = center or { x = 0, y = 0 }
    local nodes = {}
    for i = 0, count - 1 do
        local ang = rotation + i * (TWO_PI / count)
        nodes[#nodes + 1] = {
            index = i, semitone = i, angle = ang,
            x = center.x + math.cos(ang) * radius,
            y = center.y + math.sin(ang) * radius,
        }
    end
    return nodes
end

-- The 12-node emitter layout for a given phase: radius scaled per phase config, rotated by t
-- when the phase rotates. Returns nodes, config.
function RingBoss.phaseLayout(phaseId, center, t, params)
    params = params or {}
    t = t or 0
    local cfg = RingBoss.phaseConfig(phaseId)
    local radius = (params.baseRadius or 220) * (cfg.radiusScale or 1)
    local rotation = cfg.rotates and (t * (params.rotateSpeed or 0.6)) or 0
    return RingBoss.ringNodes(center, radius, 12, rotation), cfg
end

-- ---------------------------------------------------------------------------
-- P3 interval lasers: pair nodes N semitones apart (chords)
-- ---------------------------------------------------------------------------

-- All distinct unordered node pairs `interval` semitones apart around the ring.
-- interval = 7 (perfect fifth) -> 12 pairs; interval = 6 (tritone) -> 6 pairs.
function RingBoss.intervalPairs(interval, nodeCount)
    nodeCount = nodeCount or 12
    local seen, out = {}, {}
    for a = 0, nodeCount - 1 do
        local b = (a + interval) % nodeCount
        if a ~= b then
            local lo, hi = math.min(a, b), math.max(a, b)
            local key = lo .. "," .. hi
            if not seen[key] then
                seen[key] = true
                out[#out + 1] = { a = lo, b = hi }
            end
        end
    end
    return out
end

-- Interval pairs resolved to actual node positions (for the P3 laser layout / preview).
function RingBoss.laserChords(interval, center, params)
    params = params or {}
    local radius = (params.baseRadius or 220) * (RingBoss.phaseConfig(RingBoss.PHASE.P3).radiusScale)
    local nodes = RingBoss.ringNodes(center, radius, 12, params.rotation or 0)
    local pairs = RingBoss.intervalPairs(interval, 12)
    local chords = {}
    for i = 1, #pairs do
        chords[i] = { a = nodes[pairs[i].a + 1], b = nodes[pairs[i].b + 1], interval = interval }
    end
    return chords, pairs
end

-- ---------------------------------------------------------------------------
-- P1 6-top / 6-bottom pillar choreography (telegraphed, animated by t)
-- ---------------------------------------------------------------------------

-- Default firing order: alternating banks walking across the columns
-- (top c1, bottom c1, top c2, bottom c2, ...). Columns are 1-indexed to match Lua tables, so
-- caller-supplied xs / topGapsPerColumn / bottomGapsPerColumn line up. Pass params.order to reorder.
function RingBoss.defaultFiringOrder(columns)
    local order = {}
    for c = 1, columns do
        order[#order + 1] = { bank = "top", col = c }
        order[#order + 1] = { bank = "bottom", col = c }
    end
    return order
end

-- The firing sequence with cumulative fire times (fireTime = position * nodeDelay).
function RingBoss.firingSequence(params)
    params = params or {}
    local columns = params.columns or 6
    local nodeDelay = params.nodeDelay or 0.18
    local order = params.order or RingBoss.defaultFiringOrder(columns)
    local seq = {}
    for i = 1, #order do
        seq[i] = { bank = order[i].bank, col = order[i].col, fireTime = (i - 1) * nodeDelay, index = i }
    end
    return seq
end

-- Whole-tone gap generator: maps a bank to one whole-tone scale and derives a safe-gap
-- position per column from the semitone, centered in its 1/12 slot. Pure structural ordering.
function RingBoss.wholeToneGaps(bank, columns, width)
    columns = columns or 6
    width = width or 0.14
    local scale = (bank == "top") and 0 or 1
    local pitches = RingBoss.WHOLE_TONE[scale]
    local gaps = {}
    for c = 1, columns do
        local pitch = pitches[((c - 1) % #pitches) + 1]
        gaps[c] = { pos = (pitch + 0.5) / 12, width = width }
    end
    return gaps
end

-- Column x positions (cell-centers across the field) unless explicit xs are supplied.
local function columnXs(columns, fieldLeft, fieldRight, xs)
    if xs then return xs end
    local out = {}
    local w = fieldRight - fieldLeft
    for c = 1, columns do
        out[c] = fieldLeft + (c - 0.5) / columns * w
    end
    return out
end

-- Resolve a single {pos,width} gap for a bank+column. Top and bottom banks have
-- INDEPENDENT gaps; they are never forced to match (the dodge is finding where they align).
local function gapFor(bank, col, params)
    if params.gapGenerator == "wholeTone" then
        local gaps = RingBoss.wholeToneGaps(bank, params.columns or 6, params.gapWidth)
        return gaps[col]
    end
    local perCol = (bank == "top") and params.topGapsPerColumn or params.bottomGapsPerColumn
    if perCol and perCol[col] then return perCol[col] end
    local single = (bank == "top") and params.topGap or params.bottomGap
    if single then return single end
    -- Defaults: offset top vs bottom so the banks do NOT align by default.
    if bank == "top" then
        return { pos = 0.35, width = 0.14 }
    end
    return { pos = 0.65, width = 0.14 }
end

-- The animated 6/6 curtain at caller time `t`. For each sequenced node:
--   rel = t - node.fireTime
--   rel < 0                     -> not started (nothing emitted)
--   rel < telegraph_duration    -> WARNING: a telegraph marker at the node's safe gap
--   < telegraph + resolveWindow -> RESOLVE: the descending pillar, skipping the gap
-- Top bank fires downward (vy > 0), bottom bank fires upward (vy < 0). Reuses
-- BulletPatternLibrary.pillars for the per-column telegraph/resolve + gap logic.
-- Descriptors are tagged with bank/col/node for downstream dispatch.
function RingBoss.pillarChoreography(t, params)
    params = params or {}
    t = t or 0
    local columns = params.columns or 6
    local fieldLeft = params.fieldLeft or 0
    local fieldRight = params.fieldRight or 1920
    local fieldTop = params.fieldTop or 0
    local fieldBottom = params.fieldBottom or 1080
    local nodeDelay = params.nodeDelay or 0.18
    local telegraphDuration = params.telegraph_duration or 0.7
    local resolveWindow = params.resolveWindow or math.huge
    local speed = params.descendSpeed or 240
    local markerStyle = params.marker_style or "outline"
    local color_axis = params.color_axis

    local xs = columnXs(columns, fieldLeft, fieldRight, params.xs)
    local seq = RingBoss.firingSequence({ columns = columns, nodeDelay = nodeDelay, order = params.order })

    local out = {}
    for s = 1, #seq do
        local node = seq[s]
        local rel = t - node.fireTime
        local stage
        if rel < 0 then
            stage = nil
        elseif rel < telegraphDuration then
            stage = "warning"
        elseif rel < telegraphDuration + resolveWindow then
            stage = "resolve"
        end
        if stage then
            local x = xs[node.col]
            local gap = gapFor(node.bank, node.col, { columns = columns,
                gapGenerator = params.gapGenerator, gapWidth = params.gapWidth,
                topGap = params.topGap, bottomGap = params.bottomGap,
                topGapsPerColumn = params.topGapsPerColumn,
                bottomGapsPerColumn = params.bottomGapsPerColumn })
            local signedSpeed = (node.bank == "top") and speed or -speed
            local part = BulletPatternLibrary.pillars({ x = 0, y = 0 }, 0, {
                pillarCount = 1, xs = { x },
                fieldTop = fieldTop, fieldBottom = fieldBottom,
                bulletsPerPillar = params.bulletsPerColumn,
                spacing = params.spacing or 56,
                gaps = { gap },
                descendSpeed = signedSpeed,
                telegraph_duration = telegraphDuration,
                marker_style = markerStyle,
                color_axis = color_axis,
                stage = stage,
            })
            for d = 1, #part do
                part[d].bank = node.bank
                part[d].col = node.col
                part[d].node = node.index
                out[#out + 1] = part[d]
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Win condition (pure router; the flag-gated live hook calls this)
-- ---------------------------------------------------------------------------

-- Routes between the ORIGINAL and the NEW win condition. Pure -- no globals, no side effects.
--   params.useRingWincon (bool): the Config.boss.ringBoss.use_ring_boss_wincon flag.
--   params.songEnded     (bool): ORIGINAL win signal (track-completion).
--   params.phase         (1..4): current ring phase, if a ring boss is active.
--   params.coreDestroyed (bool): has the exposed core been killed.
-- Returns: won(bool), reason(string|nil).
--
-- flag OFF -> ORIGINAL path only: win when the song finishes (track-completion).
-- flag ON  -> NEW path only: win iff the core is destroyed during Phase 4 (core exposed).
function RingBoss.evaluateWincon(params)
    params = params or {}
    if params.useRingWincon then
        local phase = params.phase
        if phase == RingBoss.PHASE.P4 and params.coreDestroyed and RingBoss.isCoreVulnerable(phase) then
            return true, "ring_core_kill"
        end
        return false, nil
    end
    if params.songEnded then
        return true, "song_end"
    end
    return false, nil
end

-- ---------------------------------------------------------------------------
-- Boss-state helpers (extend the existing boss with ring phase state; opt-in)
-- ---------------------------------------------------------------------------

-- Attach ring phase state to an existing boss entity so the SAME entity reconfigures across
-- P1-P4. Pure table mutation on the passed-in boss; no globals. Called only when
-- Config.boss.ringBoss.enabled is true (default off), so the stock boss is untouched.
function RingBoss.attach(boss, cfg)
    cfg = cfg or {}
    boss.ringPhase = RingBoss.PHASE.P1
    boss.coreDestroyed = false
    boss.ringThresholds = cfg.phaseThresholds or { 0.75, 0.5, 0.25 }
    boss.ringConfig = cfg
    return boss
end

-- Recompute the ring phase from the boss's current HP fraction (no-op if not a ring boss).
function RingBoss.updatePhase(boss)
    if not boss or not boss.ringPhase then return end
    local frac = (boss.maxHealth and boss.maxHealth > 0) and (boss.health / boss.maxHealth) or 1
    boss.ringPhase = RingBoss.phaseForHealth(frac, boss.ringThresholds)
    return boss.ringPhase
end

return RingBoss
