extern number time;
extern vec2 resolution;
extern vec3 colorTint; // 👈 Add this line!

vec4 effect(vec4 color, Image texture, vec2 texCoord, vec2 screenCoord)
{
    float x = screenCoord.x / resolution.x;
    float y = screenCoord.y / resolution.y;

    float wave = sin(x * 10.0 + time * 6.0) * 0.1;
    float brightness = 0.3 + wave;

    // Apply brightness to tint
    return vec4(colorTint * brightness, 1.0);
}
