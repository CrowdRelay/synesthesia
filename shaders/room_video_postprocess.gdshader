shader_type canvas_item;
render_mode unshaded;

uniform int profile = 0;
uniform float effect_strength : hint_range(0.0, 1.5) = 0.82;
uniform float entry_strength : hint_range(0.0, 1.0) = 0.0;
uniform bool quiet_visuals = false;
uniform bool reduced_motion = false;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 uv = UV;
    // Finale aspect is handled geometrically by RoomVideoLayer. Keeping UV 1:1
    // avoids the old aspect-cover crop that made the portrait skull appear
    // heavily zoomed on wide viewports.
    vec2 px = TEXTURE_PIXEL_SIZE;
    float calm = quiet_visuals ? 0.52 : 1.0;
    float motion = reduced_motion ? 0.28 : 1.0;
    float strength = effect_strength * calm * motion;
    float t = TIME;

    // A short signal tear hides the handoff from the exact source still into AI motion.
    float entry_band = step(0.80, hash21(vec2(floor(uv.y * 31.0), floor(t * 15.0))));
    uv.x += (entry_band - 0.22) * entry_strength * px.x * 3.2 * motion;

    // Theme-specific movement stays sub-pixel except Technophobia: no rubbery image scaling.
    if (profile == 0) {
        uv.x += sin(uv.y * 25.0 + t * 2.2) * px.x * 0.55 * strength;
    } else if (profile == 4) {
        uv.x += sin(uv.y * 13.0 + t * 0.9) * px.x * 0.34 * strength;
    } else if (profile == 6) {
        float tear_row = step(0.72, hash21(vec2(floor(uv.y * 42.0), floor(t * 11.0))));
        float tear_dir = hash21(vec2(floor(t * 17.0), floor(uv.y * 19.0))) - 0.5;
        uv.x += tear_row * tear_dir * px.x * 10.0 * strength;
    } else if (profile == 7) {
        uv.x += sin(uv.y * 74.0 + t * 8.0) * px.x * 0.30 * strength;
    }
    uv = clamp(uv, vec2(0.001), vec2(0.999));

    float chroma_px = 0.45;
    if (profile == 2) chroma_px = 1.20;
    if (profile == 6) chroma_px = 2.70;
    if (profile == 7) chroma_px = 0.95;
    if (profile == 11) chroma_px = 1.35;
    chroma_px *= strength + entry_strength * 0.65;
    vec2 ca = vec2(px.x * chroma_px, 0.0);

    vec4 base = texture(TEXTURE, uv);
    vec3 color = base.rgb;
    color.r = texture(TEXTURE, clamp(uv + ca, vec2(0.0), vec2(1.0))).r;
    color.b = texture(TEXTURE, clamp(uv - ca, vec2(0.0), vec2(1.0))).b;

    // Keep all TEXTURE sampling inside fragment(). Godot 4.7.1 does not expose
    // the CanvasItem TEXTURE builtin inside user helper-function scope.
    vec3 bloom = texture(TEXTURE, uv).rgb * 0.36;
    bloom += texture(TEXTURE, clamp(uv + vec2(px.x * 2.0, 0.0), vec2(0.0), vec2(1.0))).rgb * 0.16;
    bloom += texture(TEXTURE, clamp(uv - vec2(px.x * 2.0, 0.0), vec2(0.0), vec2(1.0))).rgb * 0.16;
    bloom += texture(TEXTURE, clamp(uv + vec2(0.0, px.y * 2.0), vec2(0.0), vec2(1.0))).rgb * 0.16;
    bloom += texture(TEXTURE, clamp(uv - vec2(0.0, px.y * 2.0), vec2(0.0), vec2(1.0))).rgb * 0.16;
    float luma = dot(bloom, vec3(0.2126, 0.7152, 0.0722));
    float bloom_gate = smoothstep(0.48, 0.92, luma);
    float bloom_gain = 0.10;
    if (profile == 1) bloom_gain = 0.22;
    if (profile == 2) bloom_gain = 0.20;
    if (profile == 8) bloom_gain = 0.24;
    if (profile == 10) bloom_gain = 0.34;
    if (profile == 11) bloom_gain = 0.16;
    color += bloom * bloom_gate * bloom_gain * strength;

    // Gentle color direction keeps 12 separately generated clips in one art language.
    if (profile == 0 || profile == 4 || profile == 9) color *= vec3(0.94, 1.02, 1.05);
    if (profile == 1 || profile == 3 || profile == 8) color *= vec3(1.04, 0.99, 0.95);
    if (profile == 2) color *= vec3(1.08, 0.95, 0.92);
    if (profile == 5) color *= vec3(1.03, 0.98, 0.91);
    if (profile == 6) color *= vec3(0.96, 1.03, 1.08);
    if (profile == 7) color *= vec3(0.94, 1.02, 1.07);
    if (profile == 10) color += vec3(0.025, 0.030, 0.035) * strength;

    float scan_strength = 0.018 * strength;
    if (profile == 6) scan_strength = 0.065 * strength;
    if (profile == 11) scan_strength = 0.028 * strength;
    color *= 1.0 - scan_strength * (0.5 + 0.5 * sin(UV.y * 1280.0 * 1.08 + t * 5.0));

    float grain = hash21(FRAGCOORD.xy + vec2(floor(t * 24.0) * 17.0, float(profile) * 31.0)) - 0.5;
    float grain_gain = (profile == 6 ? 0.075 : 0.040) * (quiet_visuals ? 0.55 : 1.0);
    color += grain * grain_gain;

    float edge = smoothstep(0.36, 0.78, length((UV - vec2(0.5)) * vec2(1.0, 0.72)));
    float vignette = profile == 10 ? 0.09 : (profile == 11 ? 0.20 : 0.15);
    color *= 1.0 - edge * vignette;

    // Occasional thin signal scar; strongest on Technophobia and finale, tiny elsewhere.
    float scar_seed = hash21(vec2(floor(t * 8.0), float(profile) * 7.0));
    float scar_y = fract(scar_seed * 5.31);
    float scar = 1.0 - smoothstep(0.0, 0.0035, abs(UV.y - scar_y));
    float scar_gain = profile == 6 ? 0.17 : (profile == 11 ? 0.07 : 0.018);
    color += vec3(0.18, 0.65, 0.92) * scar * scar_gain * strength;

    COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), base.a);
}
