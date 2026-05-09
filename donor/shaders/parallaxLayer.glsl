extern float time;  // Uniform time

float gridGlow(float coord, float spacing, float thickness, float glowStrength) {
    float dist = mod(coord, spacing);
    float edgeDist = min(dist, spacing - dist);
    float glow = exp(-pow(edgeDist / thickness, 4.0) * glowStrength);
    return glow;
}

vec4 effect(vec4 color, Image texture, vec2 texCoord, vec2 screenCoord)
{
    float lineSpacing = 64.0;
    float lineThickness = 1.0;
    float glowStrength = 8.0;

    // Apply movement only on the X axis (horizontal)
    float xGlow = gridGlow(screenCoord.x + time * 300.0, lineSpacing, lineThickness, glowStrength); // Move horizontally
    float yGlow = gridGlow(screenCoord.y, lineSpacing, lineThickness, glowStrength);  // Keep Y fixed

    float combinedGlow = max(xGlow, yGlow);  // Combine the X and Y glow values

    vec3 gridColor = vec3(0.0, 1.0, 1.0); // Neon cyan color

    return vec4(gridColor * combinedGlow, combinedGlow); // Alpha = glow intensity
}
