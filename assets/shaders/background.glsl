// Top-down grid background shader with music-reactive patterns
// 32-64 pixel cells with vaporwave color progression (pink→purple→cyan→orange)

uniform float time;           // Global time
uniform float bass;           // Bass intensity (0-1)
uniform float mids;           // Mids intensity (0-1)
uniform float treble;         // Treble intensity (0-1)
uniform float intensity;      // Overall music intensity (0-1)
uniform vec2 resolution;      // Screen resolution
uniform float playerLevel;    // Player level for color progression (1-30+)

// Lerp between two colors
vec3 lerpColor(vec3 color1, vec3 color2, float t) {
    return mix(color1, color2, t);
}

// Get grid color based on player level (matches enemy color progression)
vec3 getGridColorByLevel(float level) {
    vec3 pink = vec3(1.0, 0.4, 0.7);      // Level 1-10
    vec3 purple = vec3(0.8, 0.4, 1.0);    // Level 10-20
    vec3 cyan = vec3(0.3, 0.9, 1.0);      // Level 20-30
    vec3 orange = vec3(1.0, 0.6, 0.2);    // Level 30+
    
    if (level < 10.0) {
        // Pink to Purple (levels 1-10)
        float t = (level - 1.0) / 9.0;
        return lerpColor(pink, purple, t);
    } else if (level < 20.0) {
        // Purple to Cyan (levels 10-20)
        float t = (level - 10.0) / 10.0;
        return lerpColor(purple, cyan, t);
    } else if (level < 30.0) {
        // Cyan to Orange (levels 20-30)
        float t = (level - 20.0) / 10.0;
        return lerpColor(cyan, orange, t);
    } else {
        // Stay orange at level 30+
        return orange;
    }
}

// Top-down grid with fixed cell size (32-64 pixels)
float topDownGrid(vec2 screenPos, float cellSize, out vec2 cellPos, out vec2 cellId) {
    // Calculate grid coordinates
    vec2 gridCoord = screenPos / cellSize;
    cellId = floor(gridCoord);
    cellPos = fract(gridCoord);
    
    // Grid lines using modulo - similar to parallaxLayer.glsl approach
    float lineThickness = 2.0;
    
    // Get distance to nearest grid line using mod
    float xDist = mod(screenPos.x, cellSize);
    float yDist = mod(screenPos.y, cellSize);
    
    // Check if we're close to a grid line edge (at 0 or cellSize)
    float xGrid = (xDist < lineThickness) ? 1.0 : 0.0;
    float yGrid = (yDist < lineThickness) ? 1.0 : 0.0;
    
    // Return 1.0 if on any grid line
    return max(xGrid, yGrid);
}

// Dynamic mandala pattern that expands from center with music
float getMandalaPattern(vec2 cellId, float time, vec2 screenCenter, float bass, float mids, float treble) {
    // Distance and angle from center
    vec2 fromCenter = cellId - screenCenter;
    float dist = length(fromCenter);
    float angle = atan(fromCenter.y, fromCenter.x);
    
    // Expansion radius based on time and music
    float expansionSpeed = 2.0 + bass * 3.0;  // Bass drives expansion speed
    float radius = mod(time * expansionSpeed, 30.0);  // Expands out to 30 cells then resets
    
    // Number of symmetry points (petals) - driven by mids
    float symmetry = 8.0 + floor(mids * 8.0);  // 8-16 petals based on mids
    
    // Create rotating mandala pattern
    float rotation = time * 0.5;
    float petalAngle = mod(angle + rotation, 6.28318 / symmetry) * symmetry;
    
    // Petal shape using sine waves
    float petalShape = sin(petalAngle * 2.0) * 0.5 + 0.5;
    petalShape = pow(petalShape, 2.0);  // Sharper petals
    
    // Distance rings - treble creates more detail
    float rings = sin(dist * 0.5 + time * 2.0) * 0.5 + 0.5;
    rings += sin(dist * (1.0 + treble * 2.0) - time * 3.0) * 0.3;
    
    // Combine petal and ring patterns
    float pattern = petalShape * rings;
    
    // Only show pattern near the expanding radius (creates growing mandala effect)
    float distToRadius = abs(dist - radius);
    float fade = 1.0 - smoothstep(0.0, 8.0, distToRadius);  // Fade 8 cells around radius
    
    // Inner glow at center
    float centerGlow = 1.0 - smoothstep(0.0, 5.0, dist);
    
    // Combine everything
    pattern = pattern * fade + centerGlow * 0.5;
    
    return clamp(pattern, 0.0, 1.0);
}

// Hash function for pseudo-random cell selection
float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

// Check if a cell should be filled based on symmetrical pattern
float getSymmetricalFill(vec2 cellId, vec2 screenCenter) {
    // Get distance from center (in cell coordinates)
    vec2 fromCenter = cellId - screenCenter;

    // Create 4-way symmetry by taking absolute values
    vec2 symmetricPos = abs(fromCenter);

    // Use hash function on the symmetric position
    // This ensures that all 4 quadrants have the same pattern
    float randomValue = hash21(symmetricPos);

    // Only fill ~15% of cells (adjust 0.15 to change density)
    return (randomValue < 0.15) ? 1.0 : 0.0;
}

// Get mandala color for this cell
vec3 getMandalaColor(vec2 cellId, float time, vec2 screenCenter, float level, float bass, float mids, float treble) {
    // Get mandala pattern intensity
    float pattern = getMandalaPattern(cellId, time, screenCenter, bass, mids, treble);

    if (pattern > 0.1) {
        // Get vaporwave color based on player level
        vec3 color = getGridColorByLevel(level);

        // Apply pattern intensity at very low alpha for subtlety
        return color * pattern * 0.15;  // Reduced from 0.5 to 0.15
    }

    return vec3(0.0);  // No pattern
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Fixed grid dimensions - canvas matches screen resolution
    float cellSize = 48.0;
    float gridWidth = resolution.x / cellSize;   // 1920 / 48 = 40.0
    float gridHeight = resolution.y / cellSize;  // 1080 / 48 = 22.5
    
    // Screen center in grid coordinates
    vec2 screenCenter = vec2(gridWidth * 0.5, gridHeight * 0.5);
    
    // Get grid info using raw screen coordinates
    vec2 cellPos;
    vec2 cellId;
    float grid = topDownGrid(screen_coords, cellSize, cellPos, cellId);
    
    // Base dark background
    vec3 bgColor = vec3(0.08, 0.05, 0.12);  // Dark purple
    
    // Get grid color based on player level
    float level = max(1.0, playerLevel);
    vec3 gridColor = getGridColorByLevel(level);
    
    // Start with background color
    vec3 finalColor = bgColor;

    // Check if this cell should be filled with symmetrical pattern
    float fillCell = getSymmetricalFill(cellId, screenCenter);

    // Get mandala pattern color for this cell
    vec3 patternColor = getMandalaColor(cellId, time, screenCenter, level, bass, mids, treble);

    // Apply patterns - filled cells take priority over mandala
    if (fillCell > 0.5) {
        // Fill the cell with a dimmed version of the grid color
        finalColor = gridColor * 0.3;  // Increased from 0.25 for better visibility
    } else if (length(patternColor) > 0.0) {
        // Apply subtle mandala pattern only if cell is not filled
        finalColor = bgColor + patternColor * 0.3;  // Very subtle addition
    }

    // Add grid lines with full opacity - this should make pink lines visible
    finalColor = mix(finalColor, gridColor, grid);
    
    // Add music reactivity using all frequency bands
    float reactivity = (bass * 0.4 + mids * 0.3 + treble * 0.3) * intensity * 0.15;
    finalColor += gridColor * reactivity;
    
    // Pulse grid brightness with overall intensity
    finalColor *= (1.0 + intensity * 0.2);
    
    // Subtle vignette
    vec2 uv = screen_coords / resolution;
    uv -= 0.5;
    float vignette = 1.0 - length(uv) * 0.3;
    finalColor *= vignette;
    
    return vec4(finalColor, 0.5);
}
