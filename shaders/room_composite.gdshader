shader_type canvas_item;
render_mode unshaded;

uniform sampler2D background_texture : source_color, filter_linear;
uniform sampler2D reveal_mask : filter_linear;
uniform sampler2D subject_texture : source_color, filter_linear;
uniform sampler2D foreground_texture : source_color, filter_linear;
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
uniform float completion_reveal : hint_range(0.0, 1.0) = 0.0;
uniform vec2 completion_origin = vec2(0.5, 0.5);
uniform vec2 brush_point = vec2(0.5, 0.5);
uniform float brush_energy : hint_range(0.0, 1.0) = 0.0;
uniform float film_grain_strength : hint_range(0.0, 1.0) = 0.32;
uniform float subject_lift : hint_range(0.0, 1.0) = 0.0;
uniform float runtime_scale : hint_range(0.5, 1.0) = 1.0;
uniform float cinematic_time = 0.0;
uniform float unlock_motion : hint_range(0.0, 1.0) = 0.0;
uniform int unlock_profile = 0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec2 cover_uv(vec2 uv, float zoom, vec2 shift) {
    return (uv - vec2(0.5)) / zoom + vec2(0.5) + shift;
}

void fragment() {
    float motion_scale = reduced_motion ? 0.20 : runtime_scale;
    float unlock = completion_reveal * unlock_motion * motion_scale;
    float t = cinematic_time;
    vec2 back_loop = vec2(0.0);
    vec2 scene_loop = vec2(0.0);
    vec2 subject_loop = vec2(0.0);
    vec2 foreground_loop = vec2(0.0);
    float unlock_zoom = 0.0;

    if (unlock_profile == 0) { // Wave of Uncertainty — tidal breathing.
        scene_loop = vec2(sin(t * 0.43) * 0.0014, cos(t * 0.37) * 0.0018);
        foreground_loop = vec2(sin(t * 0.61) * 0.0020, -0.0010);
    } else if (unlock_profile == 1) { // Party Time — restrained pulse.
        unlock_zoom = (0.5 + 0.5 * sin(t * 1.55)) * 0.0032;
        subject_loop = vec2(sin(t * 1.1) * 0.0012, cos(t * 1.35) * 0.0010);
    } else if (unlock_profile == 2) { // Unmasked — masks breathe apart.
        subject_loop = vec2(sin(t * 0.52) * 0.0018, cos(t * 0.47) * 0.0008);
    } else if (unlock_profile == 3) { // The Calling — slow table/wine drift.
        scene_loop = vec2(sin(t * 0.34) * 0.0010, cos(t * 0.29) * 0.0007);
        foreground_loop = vec2(-sin(t * 0.41) * 0.0012, 0.0);
    } else if (unlock_profile == 4) { // Seed — organic upward growth.
        subject_loop = vec2(sin(t * 0.31) * 0.0008, -0.0015 - 0.0007 * sin(t * 0.47));
        unlock_zoom = (0.5 + 0.5 * sin(t * 0.38)) * 0.0018;
    } else if (unlock_profile == 5) { // Hybrid — heat haze / duel tension.
        scene_loop = vec2(sin(t * 0.72) * 0.0015, sin(t * 1.21) * 0.0005);
        subject_loop = vec2(-sin(t * 0.48) * 0.0010, 0.0);
    } else if (unlock_profile == 6) { // Technophobia — tiny digital instability.
        float tech = hash21(vec2(floor(t * 7.0), 13.0)) - 0.5;
        subject_loop = vec2(tech * 0.0024, -tech * 0.0008);
        foreground_loop = vec2(-tech * 0.0013, 0.0);
    } else if (unlock_profile == 7) { // Invaluable — mirror shimmer.
        subject_loop = vec2(sin(t * 0.39) * 0.0011, cos(t * 0.51) * 0.0007);
        foreground_loop = vec2(cos(t * 0.33) * 0.0017, 0.0);
    } else if (unlock_profile == 8) { // From the Ashes — phoenix rises.
        subject_loop = vec2(sin(t * 0.44) * 0.0009, -0.0018 - 0.0008 * sin(t * 0.66));
        foreground_loop = vec2(0.0, -0.0010);
    } else if (unlock_profile == 9) { // Waves — slow intimate breathing.
        scene_loop = vec2(sin(t * 0.25) * 0.0008, cos(t * 0.22) * 0.0007);
        foreground_loop = vec2(-sin(t * 0.31) * 0.0012, 0.0);
        unlock_zoom = (0.5 + 0.5 * sin(t * 0.24)) * 0.0014;
    } else if (unlock_profile == 10) { // Rise — gentle upward light.
        scene_loop = vec2(sin(t * 0.28) * 0.0007, -0.0010 - 0.0005 * sin(t * 0.35));
        subject_loop = vec2(0.0, -0.0012);
        unlock_zoom = (0.5 + 0.5 * sin(t * 0.30)) * 0.0016;
    }

    back_loop *= unlock;
    scene_loop *= unlock;
    subject_loop *= unlock;
    foreground_loop *= unlock;
    unlock_zoom *= unlock;

    vec2 scene_uv = cover_uv(UV, 1.018 + unlock_zoom, parallax * scene_parallax * motion_scale + scene_loop);
    vec2 back_uv = cover_uv(UV, 1.095 + unlock_zoom * 0.45, parallax * background_parallax * motion_scale + back_loop);
    vec2 subject_uv = cover_uv(UV, 1.026 + unlock_zoom * 0.72, parallax * subject_parallax * motion_scale + subject_loop);
    vec2 foreground_uv = cover_uv(UV, 1.042 + unlock_zoom * 1.10, parallax * foreground_parallax * motion_scale + foreground_loop);
    vec4 scene = texture(TEXTURE, scene_uv);
    vec4 back = texture(background_texture, back_uv);
    vec4 subject = texture(subject_texture, subject_uv);
    vec4 foreground = texture(foreground_texture, foreground_uv);

    float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    float edge_blend = smoothstep(0.0, 0.19, edge_distance);
    vec3 photographed = mix(back.rgb, scene.rgb, edge_blend);
    vec3 lifted_subject = subject.rgb * (1.0 + subject_lift * 0.075);
    photographed = mix(photographed, lifted_subject, subject.a * (0.88 + subject_lift * 0.10));
    photographed = mix(photographed, foreground.rgb, foreground.a * 0.96);

    float mask = texture(reveal_mask, UV).r;
    float reveal_radius = completion_reveal * 1.45;
    float reveal_distance = distance(UV, completion_origin);
    float cinematic = 1.0 - smoothstep(reveal_radius - 0.075, reveal_radius + 0.055, reveal_distance);
    cinematic *= step(0.001, completion_reveal);
    float reveal = max(mask, cinematic);
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
    float rolling = 1.0 - smoothstep(0.0, 0.16, rolling_distance);
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

    float mask_edge = 1.0 - smoothstep(0.002, 0.015, abs(mask - 0.52));
    float brush_distance = distance(UV, brush_point);
    float brush_glow = (1.0 - smoothstep(0.018, 0.105, brush_distance)) * brush_energy;
    color += accent_color.rgb * mask_edge * hidden * 0.30;
    color += accent_color.rgb * brush_glow * (0.035 + hidden * 0.075);

    float cinematic_edge = 1.0 - smoothstep(0.018, 0.055, abs(reveal_distance - reveal_radius));
    cinematic_edge *= step(0.001, completion_reveal) * (1.0 - step(0.995, completion_reveal));
    color += accent_color.rgb * cinematic_edge * 0.16;

    float revealed_grain = hash21(floor(pixel * 0.34) + vec2(19.0, 73.0));
    float grain_strength = film_grain_strength * runtime_scale * (quiet_visuals ? 0.20 : 1.0);
    color *= 1.0 + (revealed_grain - 0.5) * 0.042 * grain_strength * reveal;

    float vignette = 1.0 - smoothstep(0.22, 0.78, distance(UV, vec2(0.5)));
    color *= mix(0.76, 1.0, vignette);
    color = mix(color, color * color * (3.0 - 2.0 * color), ink_strength * 0.16);

    COLOR = vec4(color, 1.0);
}
