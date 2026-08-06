shader_type canvas_item;
render_mode unshaded;

uniform sampler2D background_texture : source_color, filter_linear_mipmap;
uniform sampler2D reveal_mask : filter_linear;
uniform sampler2D subject_texture : source_color, filter_linear_mipmap;
uniform sampler2D foreground_texture : source_color, filter_linear_mipmap;
uniform vec4 accent_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform vec4 noise_tint : source_color = vec4(0.9, 0.75, 0.9, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float noise_intensity : hint_range(0.0, 0.35) = 0.16;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.35;
uniform float roll_strength : hint_range(0.0, 1.0) = 0.22;
uniform float horizontal_jitter : hint_range(0.0, 1.0) = 0.12;
uniform float halftone_strength : hint_range(0.0, 1.0) = 0.22;
uniform float ink_strength : hint_range(0.0, 1.0) = 0.72;
uniform float motion : hint_range(0.0, 1.0) = 0.28;
uniform vec2 parallax = vec2(0.0);
uniform float scene_parallax : hint_range(0.0, 0.06) = 0.018;
uniform float background_parallax : hint_range(0.0, 0.04) = 0.008;
uniform float subject_parallax : hint_range(0.0, 0.08) = 0.026;
uniform float foreground_parallax : hint_range(0.0, 0.10) = 0.042;
uniform int quality_level = 1;
uniform bool reduced_motion = false;
uniform bool quiet_visuals = false;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec2 cover_uv(vec2 uv, float zoom, vec2 shift) {
    return (uv - vec2(0.5)) / zoom + vec2(0.5) + shift;
}

void fragment() {
    float motion_scale = reduced_motion ? 0.20 : 1.0;
    vec2 scene_uv = cover_uv(UV, 1.018, parallax * scene_parallax * motion_scale);
    vec2 back_uv = cover_uv(UV, 1.095, parallax * background_parallax * motion_scale);
    vec2 subject_uv = cover_uv(UV, 1.026, parallax * subject_parallax * motion_scale);
    vec2 foreground_uv = cover_uv(UV, 1.042, parallax * foreground_parallax * motion_scale);
    vec4 scene = texture(TEXTURE, scene_uv);
    vec4 back = texture(background_texture, back_uv);
    vec4 subject = texture(subject_texture, subject_uv);
    vec4 foreground = texture(foreground_texture, foreground_uv);

    float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    float edge_blend = smoothstep(0.0, 0.19, edge_distance);
    vec3 photographed = mix(back.rgb, scene.rgb, edge_blend);
    photographed = mix(photographed, subject.rgb, subject.a * 0.92);
    photographed = mix(photographed, foreground.rgb, foreground.a * 0.96);

    float mask = texture(reveal_mask, UV).r;
    float fully_revealed = step(0.989, progress);
    float reveal = max(mask, fully_revealed);
    float hidden = 1.0 - reveal;

    float luminance = dot(photographed, vec3(0.2126, 0.7152, 0.0722));
    vec3 monochrome = vec3(luminance);
    vec3 negative = vec3(1.0) - photographed;
    vec3 obscured = mix(monochrome * 0.48, negative * 0.36, 0.22 + horizontal_jitter * 0.25);

    float time_speed = mix(5.0, 24.0, motion) * motion_scale;
    float frame = floor(TIME * time_speed);
    vec2 pixel = FRAGCOORD.xy;
    float fine = hash21(floor(pixel * 0.72) + vec2(frame * 1.71, frame * 0.43));
    float coarse = hash21(floor(pixel * 0.18) + vec2(frame * 0.31, frame * 1.13));
    float scan = 0.5 + 0.5 * sin(pixel.y * 2.06 + TIME * 2.4 * motion_scale);
    float rolling_center = fract(TIME * mix(0.024, 0.09, motion) * motion_scale);
    float rolling_distance = abs(UV.y - rolling_center);
    rolling_distance = min(rolling_distance, 1.0 - rolling_distance);
    float rolling = smoothstep(0.16, 0.0, rolling_distance);
    float tear_seed = hash21(vec2(floor(UV.y * 86.0), floor(TIME * 7.0 * motion_scale)));
    float tear = step(0.88, tear_seed) * sin((UV.x + TIME * 0.28) * 92.0);

    float pink = fine * 0.72 + coarse * 0.28;
    float static_alpha = hidden * noise_intensity * (0.56 + pink * 0.92);
    static_alpha *= 1.0 + (scan - 0.5) * scanline_strength;
    static_alpha += hidden * rolling * roll_strength * noise_intensity * 0.65;
    static_alpha += hidden * tear * horizontal_jitter * noise_intensity * 0.18;
    if (quiet_visuals) {
        static_alpha *= 0.22;
    }

    vec3 static_color = mix(vec3(0.72), noise_tint.rgb, 0.64) * (0.72 + pink * 0.52);
    vec3 color = mix(obscured, photographed, reveal);
    color = mix(color, static_color, clamp(static_alpha, 0.0, 0.42));

    if (quality_level > 0) {
        float dots = sin(pixel.x * 0.19) * sin(pixel.y * 0.19);
        float halftone = smoothstep(0.60, 0.98, dots * 0.5 + 0.5);
        color *= 1.0 - hidden * halftone * halftone_strength * 0.20;
    }

    float edge = 1.0 - smoothstep(0.002, 0.015, abs(mask - 0.52));
    color += accent_color.rgb * edge * hidden * 0.34;
    float vignette = 1.0 - smoothstep(0.22, 0.78, distance(UV, vec2(0.5)));
    color *= mix(0.76, 1.0, vignette);
    color = mix(color, color * color * (3.0 - 2.0 * color), ink_strength * 0.16);

    COLOR = vec4(color, 1.0);
}
