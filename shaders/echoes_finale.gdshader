shader_type canvas_item;
render_mode unshaded;

uniform vec4 cold_tint : source_color = vec4(0.36, 0.78, 1.0, 1.0);
uniform vec4 hot_tint : source_color = vec4(1.0, 0.25, 0.46, 1.0);
uniform float motion : hint_range(0.0, 1.0) = 1.0;
uniform float quiet_visuals : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 uv = UV;
    float speed = mix(0.10, 0.52, motion);
    float breath = sin(TIME * speed) * 0.0022 * motion;
    uv = (uv - vec2(0.5)) / (1.018 + breath) + vec2(0.5);

    float skull_zone = 1.0 - smoothstep(0.22, 0.96, distance(UV, vec2(0.49, 0.56)));
    float left_decay = (1.0 - smoothstep(0.06, 0.68, UV.x)) * skull_zone;
    float grain = hash21(floor(FRAGCOORD.xy * 0.31) + vec2(floor(TIME * 5.0 * motion), 17.0));
    float drift = (grain - 0.5) * 0.0120 * left_decay * motion;
    float peel = step(0.80, grain) * left_decay * motion;
    vec2 displaced_uv = clamp(uv + vec2(-abs(drift) - peel * 0.010, drift * 0.55), vec2(0.001), vec2(0.999));

    vec4 base = texture(TEXTURE, displaced_uv);
    float cold = left_decay * (0.08 + grain * 0.07) * motion;
    float hot = smoothstep(0.48, 0.96, UV.x) * skull_zone * 0.05 * motion;
    vec3 color = base.rgb + cold_tint.rgb * cold + hot_tint.rgb * hot;

    float dust = step(0.905, grain) * left_decay * motion * (1.0 - quiet_visuals * 0.75);
    color += cold_tint.rgb * dust * 0.34;
    color *= 1.0 - peel * 0.055;
    float vignette = 1.0 - smoothstep(0.32, 0.82, distance(UV, vec2(0.5, 0.54)));
    color *= mix(0.58, 1.0, vignette);
    COLOR = vec4(color, 1.0);
}
