shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 0.18) = 0.035;
uniform float motion : hint_range(0.0, 1.0) = 0.18;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 cell = floor(FRAGCOORD.xy * 0.72);
    float t = floor(TIME * (1.0 + motion * 3.0)) * 0.071;
    float grain = hash(cell + vec2(t, t * 0.63));
    float centered = (grain - 0.5) * 2.0;
    float alpha = intensity * (0.22 + abs(centered) * 0.38);
    COLOR = vec4(vec3(0.72 + centered * 0.22), alpha);
}
