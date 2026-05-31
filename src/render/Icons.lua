-- src/render/Icons.lua
-- CHROMATIC bespoke neon line-icon set, ported from the design system
-- (assets/icons/icons.js). Optics/light glyphs on a 24x24 grid, stroke-only,
-- recoloring to the *current* love.graphics color (the SVG stroke=currentColor
-- contract) so every glyph tints to the run's dominant color.
--
-- The path data below is copied verbatim from icons.js. A tiny SVG-path-subset
-- parser (M/m L/l H/h V/v C/c S/s Z/z + <circle>) flattens each glyph into
-- polylines on first use; cubic beziers are flattened via love.math.
--
-- Usage:
--   love.graphics.setColor(Theme.color.cyan)
--   Icons.draw("prism", x, y, 24)          -- top-left at (x,y), 24px box
--   Icons.draw("halo", x, y, 32, {width = 2, color = {1,1,1,0.8}})

local Icons = {}

-- Glyph definitions. Each entry is a list of elements:
--   {p = "<path d>"}                path string
--   {c = {cx, cy, r}}               circle
-- optional per-element: dash = {on, off}, op = opacity (0-1).
local ICONS = {
    -- Abilities
    dash = {
        {p = "M3 8h5"}, {p = "M3 12h7"}, {p = "M3 16h5"}, {p = "M12 6l7 6-7 6"},
    },
    blink = {
        {c = {6, 16, 3}},
        {c = {18, 8, 3}, dash = {2.2, 2.2}},
        {p = "M8.6 13.6l6.8-3.2", dash = {2, 2.5}},
    },
    shield = {
        {p = "M12 3l7 3v5.5c0 4.2-3 7.4-7 8.5-4-1.1-7-4.3-7-8.5V6z"},
        {p = "M9 12l2 2 4-4.5"},
    },
    supernova = {
        {c = {12, 12, 3.2}},
        {p = "M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.2 5.2l2.1 2.1M16.7 16.7l2.1 2.1M18.8 5.2l-2.1 2.1M7.3 16.7l-2.1 2.1"},
    },

    -- Artifacts (optics)
    prism = {
        {p = "M11 5L4 17h14z"}, {p = "M1 12h5"}, {p = "M16 11l6-2M16 13h6M16 15l6 2"},
    },
    halo = {
        {c = {12, 12, 5.5}},
        {c = {12, 12, 9}, dash = {1.5, 3}, op = 0.7},
    },
    mirror = {
        {p = "M19 4v16"}, {p = "M4 6l12 6-12 6"},
    },
    lens = {
        {p = "M10 4c4.2 3 4.2 13 0 16c-4.2-3-4.2-13 0-16z"},
        {p = "M2 12h6M13 12h9"},
        {c = {20, 12, 1}},
    },
    diffusion = {
        {c = {5, 12, 1.6}},
        {p = "M7 12c6 0 9-5 14-7"},
        {p = "M7 12c6 0 9 5 14 7"},
        {p = "M7 12h13", dash = {2, 3}},
    },
    diffraction = {
        {p = "M9 4v16", dash = {2, 2}},
        {p = "M2 12h7"},
        {p = "M9 12l10-5M9 12h11M9 12l10 5"},
    },
    refraction = {
        {p = "M4 16h16", dash = {3, 2}, op = 0.6},
        {p = "M4 4l8 12"},
        {p = "M12 16l7 4"},
        {p = "M12 6v13", dash = {1, 2}, op = 0.4},
    },
    aurora = {
        {p = "M3 9c3-3 6-3 9 0s6 3 9 0"},
        {p = "M3 13c3-3 6-3 9 0s6 3 9 0"},
        {p = "M3 17c3-3 6-3 9 0s6 3 9 0"},
    },

    -- Color / additive motif
    node = { {c = {12, 12, 6}} },
    additive = {
        {c = {9, 10, 5}}, {c = {15, 10, 5}}, {c = {12, 15.5, 5}},
    },

    -- Misc UI
    synergy = { {p = "M13 2L4 14h6l-1 8 9-12h-6z"} },
    boss = {
        {p = "M12 3l9 5v5c0 5-4 8-9 9-5-1-9-4-9-9V8z"},
        {p = "M9 10l1.5 2L9 14M15 10l-1.5 2L15 14"},
    },
}

-- ---- Path parsing ---------------------------------------------------------

-- Tokenize a path "d" string into command letters and numbers (in order).
local function tokenize(d)
    local toks, i, n = {}, 1, #d
    while i <= n do
        local ch = d:sub(i, i)
        if ch:match("[MmLlHhVvCcSsZzQqTt]") then
            toks[#toks + 1] = ch
            i = i + 1
        elseif ch:match("[%s,]") then
            i = i + 1
        else
            local num = d:match("^[%+%-]?%d*%.?%d+", i)
            if not num then
                i = i + 1 -- skip anything unexpected
            else
                toks[#toks + 1] = tonumber(num)
                i = i + #num
            end
        end
    end
    return toks
end

-- Flatten a cubic bezier into the polyline `into` (skipping the start point).
local function flattenCubic(into, x0, y0, x1, y1, x2, y2, x3, y3)
    local curve = love.math.newBezierCurve(x0, y0, x1, y1, x2, y2, x3, y3)
    local pts = curve:render(4)
    for k = 3, #pts, 2 do
        into[#into + 1] = pts[k]
        into[#into + 1] = pts[k + 1]
    end
end

-- Parse a path string into a list of subpaths: { {points={...}, closed=bool}, ... }
local function parsePath(d)
    local t = tokenize(d)
    local subs, cur = {}, nil
    local px, py, sx, sy = 0, 0, 0, 0
    local cx2, cy2 = nil, nil -- last cubic control point (absolute), for S
    local cmd, prevCmd = nil, nil
    local ti = 1
    local function num() local v = t[ti]; ti = ti + 1; return v end
    local function newSub()
        cur = {}
        subs[#subs + 1] = { points = cur, closed = false }
    end
    local function add(x, y) cur[#cur + 1] = x; cur[#cur + 1] = y end

    while ti <= #t do
        if type(t[ti]) == "string" then
            cmd = t[ti]; ti = ti + 1
        end
        if cmd == "M" or cmd == "m" then
            local x, y = num(), num()
            if cmd == "m" then x, y = px + x, py + y end
            px, py, sx, sy = x, y, x, y
            newSub(); add(px, py)
            cmd = (cmd == "M") and "L" or "l" -- subsequent pairs are lineto
        elseif cmd == "L" or cmd == "l" then
            local x, y = num(), num()
            if cmd == "l" then x, y = px + x, py + y end
            px, py = x, y; add(px, py)
        elseif cmd == "H" or cmd == "h" then
            local x = num(); if cmd == "h" then x = px + x end
            px = x; add(px, py)
        elseif cmd == "V" or cmd == "v" then
            local y = num(); if cmd == "v" then y = py + y end
            py = y; add(px, py)
        elseif cmd == "C" or cmd == "c" then
            local x1, y1, x2, y2, x, y = num(), num(), num(), num(), num(), num()
            if cmd == "c" then
                x1, y1, x2, y2, x, y = px + x1, py + y1, px + x2, py + y2, px + x, py + y
            end
            flattenCubic(cur, px, py, x1, y1, x2, y2, x, y)
            cx2, cy2 = x2, y2; px, py = x, y
        elseif cmd == "S" or cmd == "s" then
            local x2, y2, x, y = num(), num(), num(), num()
            if cmd == "s" then x2, y2, x, y = px + x2, py + y2, px + x, py + y end
            local x1, y1
            if prevCmd == "C" or prevCmd == "c" or prevCmd == "S" or prevCmd == "s" then
                x1, y1 = 2 * px - cx2, 2 * py - cy2
            else
                x1, y1 = px, py
            end
            flattenCubic(cur, px, py, x1, y1, x2, y2, x, y)
            cx2, cy2 = x2, y2; px, py = x, y
        elseif cmd == "Z" or cmd == "z" then
            if cur then subs[#subs].closed = true end
            px, py = sx, sy
        else
            break -- unsupported command; stop to avoid an infinite loop
        end
        prevCmd = cmd
    end
    return subs
end

-- ---- Build cache ----------------------------------------------------------

local _cache = {}

local function build(name)
    local def = ICONS[name]
    if not def then return nil end
    local strokes = {}
    for _, el in ipairs(def) do
        if el.c then
            strokes[#strokes + 1] = { circle = el.c, dash = el.dash, op = el.op }
        elseif el.p then
            for _, sub in ipairs(parsePath(el.p)) do
                strokes[#strokes + 1] = {
                    points = sub.points, closed = sub.closed, dash = el.dash, op = el.op,
                }
            end
        end
    end
    _cache[name] = strokes
    return strokes
end

local function getStrokes(name)
    return _cache[name] or build(name)
end

-- ---- Drawing --------------------------------------------------------------

local function circleToPoly(c)
    local cx, cy, r = c[1], c[2], c[3]
    local pts, N = {}, 48
    for i = 0, N do
        local a = (i / N) * math.pi * 2
        pts[#pts + 1] = cx + math.cos(a) * r
        pts[#pts + 1] = cy + math.sin(a) * r
    end
    return pts
end

-- Draw a polyline as a dashed stroke (pattern in glyph units).
local function dashedLine(pts, dash, closed)
    if closed then
        pts = { unpack(pts) }
        pts[#pts + 1] = pts[1]; pts[#pts + 1] = pts[2]
    end
    local on, off = dash[1], dash[2]
    local drawing, dist = true, 0
    for i = 1, #pts - 2, 2 do
        local x1, y1, x2, y2 = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
        local segLen = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        if segLen > 0 then
            local pos = 0
            while pos < segLen do
                local span = (drawing and on or off) - dist
                local step = math.min(span, segLen - pos)
                if drawing then
                    local t0, t1 = pos / segLen, (pos + step) / segLen
                    love.graphics.line(
                        x1 + (x2 - x1) * t0, y1 + (y2 - y1) * t0,
                        x1 + (x2 - x1) * t1, y1 + (y2 - y1) * t1)
                end
                pos = pos + step; dist = dist + step
                if dist >= (drawing and on or off) - 1e-6 then
                    drawing = not drawing; dist = 0
                end
            end
        end
    end
end

--- Draw an icon with its top-left at (x, y), scaled to `size` px (default 24).
-- Recolors to the current love.graphics color unless opts.color is given.
-- opts = { width = strokeWidth(glyph units, default 1.8), color = {r,g,b,a} }
function Icons.draw(name, x, y, size, opts)
    local strokes = getStrokes(name)
    if not strokes then return false end
    opts = opts or {}
    local s = (size or 24) / 24
    local r, g, b, a = love.graphics.getColor()
    if opts.color then
        r, g, b = opts.color[1], opts.color[2], opts.color[3]
        a = opts.color[4] or a
    end

    local prevW = love.graphics.getLineWidth()
    local prevJoin = love.graphics.getLineJoin()
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(s, s)
    love.graphics.setLineWidth(opts.width or 1.8)
    love.graphics.setLineJoin("bevel")

    for _, st in ipairs(strokes) do
        love.graphics.setColor(r, g, b, a * (st.op or 1))
        if st.circle then
            if st.dash then
                dashedLine(circleToPoly(st.circle), st.dash, false)
            else
                love.graphics.circle("line", st.circle[1], st.circle[2], st.circle[3], 48)
            end
        elseif st.dash then
            dashedLine(st.points, st.dash, st.closed)
        else
            local pts = st.points
            if st.closed then
                pts = { unpack(pts) }
                pts[#pts + 1] = pts[1]; pts[#pts + 1] = pts[2]
            end
            if #pts >= 4 then love.graphics.line(pts) end
        end
    end

    love.graphics.pop()
    love.graphics.setLineWidth(prevW)
    love.graphics.setLineJoin(prevJoin)
    love.graphics.setColor(r, g, b, a)
    return true
end

--- Is there a glyph by this name?
function Icons.has(name)
    return ICONS[name] ~= nil
end

return Icons
