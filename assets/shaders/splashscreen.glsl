extern vec2 resolution;
extern float time;
extern float intensity;
extern float bloomEnabled;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Normalize coordinates
    vec2 uv = screen_coords / resolution;
    
    // Dynamic background colors (vaporwave cyberpunk palette)
    vec3 bgColor = vec3(0.03, 0.02, 0.05); // Deep space black-purple
    vec3 glowCyan = vec3(0.0, 0.4, 0.5);  // Electric cyan glow
    vec3 glowPink = vec3(0.5, 0.0, 0.35);  // Hot pink glow
    
    // Create a smooth, animated flowing colored gradient
    float flow = sin(time * 0.5 + uv.x * 2.0 + uv.y * 1.5) * 0.5 + 0.5;
    vec3 activeColor = mix(glowPink, glowCyan, flow);
    
    // Add pulsing light bursts matching music intensity
    float beatPulse = intensity * 0.5;
    
    // Smooth radial/spherical gradient from the center
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(uv, center);
    float radialGlow = smoothstep(1.2, 0.1, dist);
    
    // Final composite color
    vec3 finalColor;
    if (bloomEnabled > 0.5) {
        finalColor = mix(bgColor, activeColor, radialGlow * (0.3 + beatPulse));
    } else {
        // Muted, non-distracting version: very subtle dark purple/black gradient without bright glowing vaporwave colors or pulsing intensity
        finalColor = mix(bgColor, activeColor * 0.15, radialGlow * 0.15);
    }
    
    // Add a dark vignette around screen edges to frame the text
    float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = clamp(pow(16.0 * vignette, 0.45), 0.0, 1.0);
    finalColor *= vignette;
    
    return vec4(finalColor, 1.0);
}
