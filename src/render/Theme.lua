-- src/render/Theme.lua
-- Runtime consumer of the CHROMATIC design tokens declared in src/Config.lua
-- (the Lua embodiment of the design system's colors_and_type.css).
--
-- Provides:
--   Theme.color.<name>          -- {r,g,b} float triples (see Config.theme.colors)
--   Theme.font(role, size)      -- lazily-loaded + cached LÖVE Font for a type role
--   Theme.setColor(name, [a])   -- love.graphics.setColor() from a token name
--
-- Fonts are created on first use (after love.graphics exists) and cached per
-- (role, size). If a .ttf is missing or fails to load, we transparently fall
-- back to LÖVE's default font so the game still boots.

local Config = require("src.Config")

local Theme = {}

-- Direct access to the token palette: Theme.color.accent, Theme.color.red, ...
Theme.color = Config.theme.colors

-- Convenience aliases for the type roles + scale (so callers can stay terse).
Theme.role = Config.theme.fonts
Theme.scale = Config.theme.typeScale

-- font cache: _fonts[role][size] = Font
local _fonts = {}
-- Remember roles whose .ttf failed to load so we only warn once.
local _missing = {}

-- Internal: build a font for a role at a pixel size, with default-font fallback.
local function createFont(role, size)
    local path = Config.theme.fonts[role]
    if path and not _missing[role] then
        local ok, fontOrErr = pcall(love.graphics.newFont, path, size)
        if ok then
            return fontOrErr
        end
        _missing[role] = true
        print(string.format("[Theme] Font '%s' (%s) failed to load; using default. (%s)",
            tostring(role), tostring(path), tostring(fontOrErr)))
    end
    -- Fallback: LÖVE default font at the requested size.
    return love.graphics.newFont(size)
end

--- Return a cached LÖVE Font for a type role at a given pixel size.
-- @param role  one of the keys in Config.theme.fonts (default "ui")
-- @param size  pixel size (default Config.theme.typeScale.ui)
function Theme.font(role, size)
    role = role or "ui"
    size = size or Theme.scale.ui
    local byRole = _fonts[role]
    if not byRole then
        byRole = {}
        _fonts[role] = byRole
    end
    local font = byRole[size]
    if not font then
        font = createFont(role, size)
        byRole[size] = font
    end
    return font
end

--- love.graphics.setColor() from a token name, with optional alpha override.
-- @param name   key in Config.theme.colors (e.g. "accent", "fg1", "danger")
-- @param alpha  optional alpha 0-1 (defaults to 1)
function Theme.setColor(name, alpha)
    local c = Theme.color[name]
    if not c then
        love.graphics.setColor(1, 1, 1, alpha or 1)
        return
    end
    love.graphics.setColor(c[1], c[2], c[3], alpha or 1)
end

return Theme
