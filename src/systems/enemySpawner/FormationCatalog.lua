-- FormationCatalog.lua
-- Static formation definitions for EnemySpawner.

local FormationCatalog = {}

FormationCatalog.formations = {
    square_corners = {
        pattern = function(index, total, spacing)
            local positions = {
                {0, 0},
                {-1, -1}, {1, -1},
                {-1, 1}, {1, 1}
            }
            local pos = positions[index + 1] or {0, 0}
            return pos[1] * spacing, pos[2] * spacing
        end,
        count = 5,
        roles = {"center", "corner", "corner", "corner", "corner"},
        shapeOverride = {"square", "triangle", "triangle", "triangle", "triangle"}
    },
    hex_star = {
        pattern = function(index, total, spacing)
            if index == 0 then
                return 0, 0
            end
            local angle = ((index - 1) / 6) * math.pi * 2
            local radius = spacing * 1.5
            return math.cos(angle) * radius, math.sin(angle) * radius
        end,
        count = 7,
        roles = {"center", "outer", "outer", "outer", "outer", "outer", "outer"},
        shapeOverride = {"hexagon", "triangle", "triangle", "triangle", "triangle", "triangle", "triangle"}
    },
    tri_squares = {
        pattern = function(index, total, spacing)
            local positions = {
                {0, -1},
                {-0.5, 0}, {0.5, 0},
                {-1, 1}, {0, 1}, {1, 1}
            }
            local pos = positions[index + 1] or {0, 0}
            return pos[1] * spacing, pos[2] * spacing
        end,
        count = 6,
        roles = {"leader", "support", "support", "heavy", "heavy", "heavy"},
        shapeOverride = {"square", "square", "square", "square", "square", "square"}
    },
    diamond = {
        pattern = function(index, total, spacing)
            local positions = {
                {0, 0},
                {0, -1}, {1, 0}, {0, 1}, {-1, 0},
                {0, -2}, {2, 0}, {0, 2}, {-2, 0}
            }
            local pos = positions[index + 1] or {0, 0}
            return pos[1] * spacing * 0.7, pos[2] * spacing * 0.7
        end,
        count = 9,
        roles = {"center", "inner", "inner", "inner", "inner", "outer", "outer", "outer", "outer"},
        shapeOverride = {"hexagon", "square", "square", "square", "square", "triangle", "triangle", "triangle", "triangle"}
    },
    cross = {
        pattern = function(index, total, spacing)
            local positions = {
                {0, 0},
                {0, -1}, {1, 0}, {0, 1}, {-1, 0}
            }
            local pos = positions[index + 1] or {0, 0}
            return pos[1] * spacing, pos[2] * spacing
        end,
        count = 5,
        roles = {"center", "arm", "arm", "arm", "arm"},
        shapeOverride = {"hexagon", "triangle", "triangle", "triangle", "triangle"}
    },
    vee = {
        pattern = function(index, total, spacing)
            local positions = {
                {0, 0},
                {-0.7, 0.7}, {0.7, 0.7},
                {-1.4, 1.4}, {1.4, 1.4},
                {-2.1, 2.1}, {2.1, 2.1}
            }
            local pos = positions[index + 1] or {0, 0}
            return pos[1] * spacing * 0.6, pos[2] * spacing * 0.6
        end,
        count = 7,
        roles = {"leader", "follower", "follower", "scout", "scout", "scout", "scout"},
        shapeOverride = {"hexagon", "square", "square", "triangle", "triangle", "triangle", "triangle"}
    },
    box = {
        pattern = function(index, total, spacing)
            local positions = {
                {-1, -1}, {0, -1}, {1, -1},
                {-1, 0}, {1, 0},
                {-1, 1}, {0, 1}, {1, 1}
            }
            local pos = positions[index + 1] or {0, 0}
            return pos[1] * spacing, pos[2] * spacing
        end,
        count = 8,
        roles = {"corner", "edge", "corner", "edge", "edge", "corner", "edge", "corner"},
        shapeOverride = {"triangle", "square", "triangle", "square", "square", "triangle", "square", "triangle"}
    }
}

return FormationCatalog
