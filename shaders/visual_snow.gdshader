shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 0.18) = 0.045;
uniform float motion : hint_range(0.0, 1.0) = 0.28;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.42;
uniform float roll_strength : hint_range(0.0, 1.0) = 0.22;
uniform float sparkle_density : hint_range(0.0, 1.0) = 0.24;
uniform float horizontal_jitter : hint_range(0.0, 1.0) = 0.12;
uniform vec4 tint_color : source_color = vec4(0.76, 0.86, 1.0, 1.0);

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 pixel = FRAGCOORD.xy;
    float frame = floor(TIME * mix(7.0, 28.0, motion));
    float fine = hash21(floor(pixel * 0.84) + vec2(frame * 1.7, frame * 0.43));
    float coarse = hash21(floor(pixel * 0.19) + vec2(frame * 0.31, frame * 1.13));
    float star_seed = hash21(floor(pixel * 0.075) + vec2(frame * 0.07, frame * 0.11));
    float star = step(1.0 - sparkle_density * 0.022, star_seed);

    float scan = 0.5 + 0.5 * sin(pixel.y * 2.18 + TIME * mix(1.2, 3.6, motion));
    float rolling_center = fract(TIME * mix(0.025, 0.11, motion));
    float rolling_distance = abs(UV.y - rolling_center);
    rolling_distance = min(rolling_distance, 1.0 - rolling_distance);
    float rolling = smoothstep(0.17, 0.0, rolling_distance);

    float tear_seed = hash21(vec2(floor(UV.y * 88.0), floor(TIME * 8.0)));
    float tear = step(0.82, tear_seed) * sin((UV.x + TIME * 0.33) * 85.0);
    float shimmer = 0.74 + fine * 0.52 + coarse * 0.18;
    shimmer *= 1.0 + (scan - 0.5) * scanline_strength * 0.62;
    shimmer += rolling * roll_strength * 0.52;
    shimmer += tear * horizontal_jitter * 0.20;

    vec3 cold = mix(vec3(0.62), tint_color.rgb, 0.42);
    vec3 color = cold * (0.72 + fine * 0.38) + vec3(star * 0.62);
    float alpha = intensity * shimmer + star * intensity * 1.35;
    COLOR = vec4(color, clamp(alpha, 0.0, 0.19));
}
