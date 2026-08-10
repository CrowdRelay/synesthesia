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
uniform float living_strength : hint_range(0.0, 1.0) = 0.0;
uniform float living_time = 0.0;

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
    float living = living_strength * motion_scale;
    float lt = living_time;
    vec2 back_loop = vec2(0.0);
    vec2 scene_loop = vec2(0.0);
    vec2 subject_loop = vec2(0.0);
    vec2 foreground_loop = vec2(0.0);
    float unlock_zoom = 0.0;
    float profile_light = 0.0;

    if (unlock_profile == 0) { // Wave of Uncertainty — alternating left/right hits.
        scene_loop = vec2(sin(t * 1.65) * 0.0080, cos(t * 0.58) * 0.0026);
        foreground_loop = vec2(-sin(t * 1.65) * 0.0100, sin(t * 0.74) * 0.0014);
        unlock_zoom = (0.5 + 0.5 * sin(t * 0.72)) * 0.0036;
    } else if (unlock_profile == 1) { // Party Time — balloons and room light lift.
        float rise = min(t * 0.012, 0.055);
        unlock_zoom = (0.5 + 0.5 * sin(t * 1.55)) * 0.0050;
        subject_loop = vec2(sin(t * 1.1) * 0.0022, rise + cos(t * 1.35) * 0.0012);
        profile_light = 0.045 + 0.025 * (0.5 + 0.5 * sin(t * 2.0));
    } else if (unlock_profile == 2) { // Unmasked — masks breathe while eyes animate in overlay.
        subject_loop = vec2(sin(t * 0.72) * 0.0032, cos(t * 0.57) * 0.0014);
        profile_light = 0.018 * (0.5 + 0.5 * sin(t * 3.2));
    } else if (unlock_profile == 3) { // The Calling — table and raised toast drift.
        scene_loop = vec2(sin(t * 0.44) * 0.0018, cos(t * 0.39) * 0.0012);
        foreground_loop = vec2(-sin(t * 0.51) * 0.0022, 0.0);
    } else if (unlock_profile == 4) { // Seed — tree twists and grows under tension.
        subject_loop = vec2(sin(t * 1.15) * 0.0055 + sin(t * 0.31) * 0.0020, min(t * 0.004, 0.020));
        unlock_zoom = (0.5 + 0.5 * sin(t * 0.58)) * 0.0032;
    } else if (unlock_profile == 5) { // Hybrid — heat haze / post-shot recoil.
        scene_loop = vec2(sin(t * 0.92) * 0.0026, sin(t * 1.41) * 0.0009);
        subject_loop = vec2(-sin(t * 0.68) * 0.0022, 0.0);
    } else if (unlock_profile == 6) { // Technophobia — explicit bzz/glitch instability.
        float tech = hash21(vec2(floor(t * 11.0), 13.0)) - 0.5;
        subject_loop = vec2(tech * 0.0100, -tech * 0.0022);
        foreground_loop = vec2(-tech * 0.0060, 0.0);
        scene_loop = vec2(tech * 0.0040, 0.0);
    } else if (unlock_profile == 7) { // Invaluable — impact shake before shards fly.
        float impact = max(0.0, 1.0 - t / 1.25);
        subject_loop = vec2(sin(t * 34.0) * 0.0070 * impact, cos(t * 28.0) * 0.0040 * impact);
        foreground_loop = vec2(-sin(t * 31.0) * 0.0090 * impact, 0.0);
    } else if (unlock_profile == 8) { // From the Ashes — phoenix visibly leaves the ashes.
        float flight = min(t / 4.2, 1.0);
        subject_loop = vec2(sin(t * 1.05) * 0.0040 * flight, flight * 0.075 + sin(t * 4.8) * 0.0028);
        foreground_loop = vec2(0.0, flight * 0.018);
        unlock_zoom = flight * 0.012;
        profile_light = 0.025 * (1.0 - flight * 0.45);
    } else if (unlock_profile == 9) { // Waves — mostly still room; lamp flicker is localized by behavior.
        scene_loop = vec2(sin(t * 0.25) * 0.0005, cos(t * 0.22) * 0.0005);
        foreground_loop = vec2(-sin(t * 0.31) * 0.0008, 0.0);
        profile_light = 0.012 * max(0.0, sin(t * 7.0) * sin(t * 2.3));
    } else if (unlock_profile == 10) { // Rise — person floats toward the window/light.
        float ascent = min(t / 3.4, 1.0);
        scene_loop = vec2(sin(t * 0.38) * 0.0010, ascent * 0.010);
        subject_loop = vec2(0.0, ascent * 0.070);
        unlock_zoom = ascent * 0.014;
        profile_light = 0.035 + ascent * 0.085;
    }

    back_loop *= unlock;
    scene_loop *= unlock;
    subject_loop *= unlock;
    foreground_loop *= unlock;
    unlock_zoom *= unlock;

    // Permanent post-reveal life. These amplitudes are deliberately tiny: the
    // artwork stays cinematic while surfaces, curtains, masks and light never
    // settle into a dead still frame.
    if (living > 0.001) {
        if (unlock_profile == 0) {
            scene_loop += vec2(sin(lt * 0.34) * 0.0012, cos(lt * 0.22) * 0.0005) * living;
            foreground_loop += vec2(-sin(lt * 0.29) * 0.0018, 0.0) * living;
        } else if (unlock_profile == 1) {
            subject_loop += vec2(sin(lt * 0.31) * 0.0036, cos(lt * 0.27) * 0.0052) * living;
            foreground_loop += vec2(-sin(lt * 0.24) * 0.0042, cos(lt * 0.19) * 0.0022) * living;
        } else if (unlock_profile == 2) {
            subject_loop += vec2(sin(lt * 0.27) * 0.0044, cos(lt * 0.21) * 0.0016) * living;
            foreground_loop += vec2(-sin(lt * 0.20) * 0.0012, 0.0) * living;
        } else if (unlock_profile == 3) {
            scene_loop += vec2(sin(lt * 0.15) * 0.0014, cos(lt * 0.13) * 0.0011) * living;
            foreground_loop += vec2(sin(lt * 0.18) * 0.0023, 0.0) * living;
        } else if (unlock_profile == 4) {
            subject_loop += vec2(sin(lt * 0.42) * 0.0016, sin(lt * 0.20) * 0.0007) * living;
        } else if (unlock_profile == 5) {
            scene_loop += vec2(sin(lt * 0.19) * 0.0008, cos(lt * 0.17) * 0.0005) * living;
        } else if (unlock_profile == 6) {
            float residual = hash21(vec2(floor(lt * 3.0), 29.0)) - 0.5;
            scene_loop += vec2(residual * 0.0017, 0.0) * living;
        } else if (unlock_profile == 7) {
            foreground_loop += vec2(sin(lt * 0.16) * 0.0013, cos(lt * 0.14) * 0.0008) * living;
        } else if (unlock_profile == 8) {
            subject_loop += vec2(sin(lt * 0.30) * 0.0012, sin(lt * 0.21) * 0.0010) * living;
        } else if (unlock_profile == 9) {
            foreground_loop += vec2(sin(lt * 0.24) * 0.0042, cos(lt * 0.17) * 0.0011) * living;
            scene_loop += vec2(-sin(lt * 0.18) * 0.0014, 0.0) * living;
        } else if (unlock_profile == 10) {
            scene_loop += vec2(0.0, sin(lt * 0.18) * 0.0016) * living;
            foreground_loop += vec2(sin(lt * 0.16) * 0.0014, -cos(lt * 0.14) * 0.0020) * living;
        }
    }

    vec2 scene_uv = cover_uv(UV, 1.018 + unlock_zoom, parallax * scene_parallax * motion_scale + scene_loop);
    vec2 back_uv = cover_uv(UV, 1.095 + unlock_zoom * 0.45, parallax * background_parallax * motion_scale + back_loop);
    vec2 subject_uv = cover_uv(UV, 1.026 + unlock_zoom * 0.72, parallax * subject_parallax * motion_scale + subject_loop);
    vec2 foreground_uv = cover_uv(UV, 1.042 + unlock_zoom * 1.10, parallax * foreground_parallax * motion_scale + foreground_loop);
    if (living > 0.001) {
        if (unlock_profile == 3) { // Calling: liquid bowl ripple slightly distorts the altar area.
            vec2 altar = UV - vec2(0.5, 0.63);
            float ad = length(altar);
            float ripple = sin(ad * 120.0 - lt * 2.3) * (1.0 - smoothstep(0.05, 0.24, ad));
            subject_uv += normalize(altar + vec2(0.0001)) * ripple * 0.0024 * living;
            scene_uv += vec2(sin(lt * 0.8 + UV.y * 9.0), cos(lt * 0.7 + UV.x * 8.0)) * 0.0005 * living;
        } else if (unlock_profile == 1) { // Party: membrane breath creates small surface drag.
            float membrane = sin(UV.y * 18.0 + lt * 0.9 + sin(UV.x * 7.0)) * 0.0018 * living;
            subject_uv.y += membrane;
            foreground_uv.x += membrane * 0.65;
        } else if (unlock_profile == 2) { // Unmasked: the reliquary breath subtly warps the face area.
            vec2 reliquary = UV - vec2(0.5, 0.43);
            float rd = length(reliquary);
            float halo = (1.0 - smoothstep(0.08, 0.26, rd)) * sin(lt * 1.1 + rd * 18.0);
            subject_uv += normalize(reliquary + vec2(0.0001)) * halo * 0.0016 * living;
        } else if (unlock_profile == 9) { // Waves: curtains and air move the image softly.
            float curtain = sin(UV.x * 21.0 + lt * 0.42) * cos(UV.y * 8.0 + lt * 0.18);
            foreground_uv.x += curtain * 0.0028 * living;
            scene_uv.x -= curtain * 0.0010 * living;
        } else if (unlock_profile == 6) { // Technophobia: residual horizontal sync errors.
            float band = step(0.91, hash21(vec2(floor(UV.y * 22.0), floor(lt * 2.4))));
            float offset = (hash21(vec2(floor(lt * 4.0), floor(UV.y * 22.0))) - 0.5) * 0.006 * band * living;
            scene_uv.x += offset;
            foreground_uv.x -= offset * 0.55;
        } else if (unlock_profile == 7) { // Invaluable: tiny glass refraction around moving glints.
            float shard = sin((UV.x + UV.y) * 36.0 + lt * 0.55) * sin((UV.x - UV.y) * 27.0 - lt * 0.42);
            foreground_uv += vec2(shard, -shard) * 0.0009 * living;
        } else if (unlock_profile == 4) { // Seed: sap current gently bends the trunk area.
            float trunk = 1.0 - smoothstep(0.03, 0.19, abs(UV.x - 0.5));
            subject_uv.x += sin(UV.y * 22.0 + lt * 1.25) * 0.0017 * trunk * living;
        } else if (unlock_profile == 8) { // Ashes: heat haze around phoenix.
            float heat = 1.0 - smoothstep(0.16, 0.43, distance(UV, vec2(0.5, 0.43)));
            subject_uv.x += sin(UV.y * 34.0 + lt * 2.1) * 0.0018 * heat * living;
            foreground_uv.y += cos(UV.x * 19.0 - lt * 1.4) * 0.0007 * heat * living;
        } else if (unlock_profile == 5) { // Hybrid: radial motor vibration.
            vec2 core = UV - vec2(0.5, 0.52);
            float cd = length(core);
            float motor = sin(cd * 95.0 - lt * 1.15) * (1.0 - smoothstep(0.08, 0.34, cd));
            scene_uv += normalize(core + vec2(0.0001)) * motor * 0.0013 * living;
        } else if (unlock_profile == 10) { // Rise: vertical atmospheric current.
            float shaft = 1.0 - smoothstep(0.12, 0.34, abs(UV.x - 0.5));
            scene_uv.y += sin(UV.y * 17.0 + lt * 0.62) * 0.0011 * shaft * living;
            foreground_uv.y -= 0.00055 * living;
        } else if (unlock_profile == 0) { // Uncertainty: opposing wave drag.
            scene_uv.x += sin(UV.y * 19.0 + lt * 0.72) * 0.0011 * living;
            foreground_uv.x -= sin(UV.y * 15.0 - lt * 0.63) * 0.0013 * living;
        }
    }
    if (unlock_profile == 4) {
        subject_uv.x += sin(UV.y * 10.0 + t * 2.2) * 0.0038 * unlock;
    } else if (unlock_profile == 6) {
        float glitch_band = step(0.76, hash21(vec2(floor(UV.y * 18.0), floor(t * 9.0))));
        float glitch_offset = (hash21(vec2(floor(t * 13.0), floor(UV.y * 18.0))) - 0.5) * 0.030 * glitch_band * unlock;
        scene_uv.x += glitch_offset;
        subject_uv.x -= glitch_offset * 0.72;
    }
    vec4 scene = texture(TEXTURE, clamp(scene_uv, vec2(0.001), vec2(0.999)));
    vec4 back = texture(background_texture, clamp(back_uv, vec2(0.001), vec2(0.999)));
    vec4 subject = texture(subject_texture, clamp(subject_uv, vec2(0.001), vec2(0.999)));
    vec4 foreground = texture(foreground_texture, clamp(foreground_uv, vec2(0.001), vec2(0.999)));

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
    // V2 hidden state: dark signal loss instead of the old comic-negative wash.
    vec3 obscured = mix(photographed * 0.12, monochrome * 0.34, 0.72);
    obscured = mix(obscured, negative * 0.18, 0.055 + horizontal_jitter * 0.035);

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

    vec3 static_color = mix(vec3(0.18, 0.21, 0.24), noise_tint.rgb * 0.58, 0.54) * (0.70 + pink * 0.48);
    vec3 color = mix(obscured, photographed, reveal);
    color += accent_color.rgb * profile_light * unlock * reveal;
    color = mix(color, static_color, clamp(static_alpha, 0.0, 0.42));

    // Localized post-process details after reveal: candle flicker/liquid ripple,
    // membrane gloss, glass sweeps, curtain light and other room signatures.
    float living_fx = 0.0;
    if (living > 0.001 && reveal > 0.92) {
        if (unlock_profile == 1) { // Party: slow specular sweeps across membranes.
            float sweep = 0.5 + 0.5 * sin(UV.y * 22.0 - lt * 0.75 + sin(UV.x * 9.0));
            living_fx = pow(sweep, 5.0) * 0.072 * living;
        } else if (unlock_profile == 2) { // Unmasked: breathing halo around reliquary.
            float d = distance(UV, vec2(0.5, 0.43));
            living_fx = (1.0 - smoothstep(0.10, 0.34, d)) * (0.040 + 0.034 * (0.5 + 0.5 * sin(lt * 0.82))) * living;
        } else if (unlock_profile == 3) { // Calling: candles + living liquid surface.
            float candles = 0.0;
            candles += 1.0 - smoothstep(0.015, 0.055, distance(UV, vec2(0.23, 0.58)));
            candles += 1.0 - smoothstep(0.015, 0.055, distance(UV, vec2(0.34, 0.67)));
            candles += 1.0 - smoothstep(0.015, 0.055, distance(UV, vec2(0.66, 0.67)));
            candles += 1.0 - smoothstep(0.015, 0.055, distance(UV, vec2(0.77, 0.58)));
            float flicker = 0.55 + 0.45 * sin(lt * 6.1) * sin(lt * 1.73 + UV.x * 13.0);
            float altar_d = distance(UV, vec2(0.5, 0.63));
            float liquid = (0.5 + 0.5 * sin(altar_d * 165.0 - lt * 2.1)) * (1.0 - smoothstep(0.06, 0.24, altar_d));
            living_fx = (candles * (0.054 + flicker * 0.052) + liquid * 0.050) * living;
        } else if (unlock_profile == 4) { // Seed: energy moves upward through the trunk.
            float trunk = 1.0 - smoothstep(0.015, 0.13, abs(UV.x - 0.5));
            float sap = 0.5 + 0.5 * sin(UV.y * 37.0 + lt * 2.0);
            living_fx = trunk * pow(sap, 5.5) * 0.060 * living;
        } else if (unlock_profile == 6) { // Tech: residual scan / LED glow.
            float grid = step(0.93, hash21(floor(UV * vec2(8.0, 13.0)) + floor(lt * 1.8)));
            living_fx = grid * (0.5 + 0.5 * sin(lt * 8.0 + UV.y * 17.0)) * 0.048 * living;
        } else if (unlock_profile == 7) { // Invaluable: moving glass glint.
            float diagonal = 1.0 - smoothstep(0.0, 0.055, abs(fract(UV.x + UV.y * 0.72 - lt * 0.045) - 0.5));
            living_fx = diagonal * 0.046 * living;
        } else if (unlock_profile == 8) { // Ashes: warm breathing heat around phoenix.
            float d = distance(UV, vec2(0.5, 0.43));
            living_fx = (1.0 - smoothstep(0.10, 0.42, d)) * (0.034 + 0.024 * (0.5 + 0.5 * sin(lt * 0.66))) * living;
        } else if (unlock_profile == 9) { // Waves: rain/window light travels through curtains.
            float curtain = pow(0.5 + 0.5 * sin(UV.x * 31.0 + lt * 0.34), 9.0);
            float window = (1.0 - smoothstep(0.18, 0.42, distance(UV, vec2(0.5, 0.45))));
            living_fx = (curtain * 0.038 + window * (0.028 + 0.022 * sin(lt * 0.47))) * living;
        } else if (unlock_profile == 5) { // Hybrid: core pulse.
            float d = distance(UV, vec2(0.5, 0.52));
            float ring = 1.0 - smoothstep(0.0, 0.018, abs(d - (0.12 + 0.018 * sin(lt * 0.35))));
            living_fx = ring * 0.052 * living;
        } else if (unlock_profile == 10) { // Rise: slow vertical light current.
            float column = 1.0 - smoothstep(0.08, 0.30, abs(UV.x - 0.5));
            float current = 0.5 + 0.5 * sin(UV.y * 15.0 + lt * 0.62);
            living_fx = column * (0.026 + pow(current, 6.5) * 0.050) * living;
        } else {
            living_fx = (0.5 + 0.5 * sin(UV.y * 16.0 + lt * 0.4)) * 0.022 * living;
        }
        color += accent_color.rgb * living_fx;
        if (unlock_profile == 3) {
            color += vec3(0.20, 0.08, 0.04) * living_fx * 0.85;
        } else if (unlock_profile == 1) {
            color += vec3(0.05, 0.02, 0.08) * living_fx * 0.55;
        } else if (unlock_profile == 2) {
            color += vec3(0.10, 0.03, 0.03) * living_fx * 0.70;
        } else if (unlock_profile == 9) {
            color += vec3(0.03, 0.05, 0.08) * living_fx * 0.55;
        }
        // Room materials keep breathing after completion. It is intentionally
        // small but visible on OLED/mobile: a gentle luminance wave + signal sweep.
        float material_breath = 0.5 + 0.5 * sin(lt * (0.31 + float(unlock_profile) * 0.013));
        color *= 1.0 + living * (material_breath - 0.5) * 0.022;
        float signal_scan = pow(0.5 + 0.5 * sin((UV.y + UV.x * 0.12) * 42.0 - lt * 0.52), 12.0);
        color += accent_color.rgb * signal_scan * living * 0.010;
    }

    if (quality_level > 0) {
        float dots = sin(pixel.x * 0.19) * sin(pixel.y * 0.19);
        float halftone = smoothstep(0.60, 0.98, dots * 0.5 + 0.5);
        color *= 1.0 - hidden * halftone * halftone_strength * 0.065;
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
    color *= mix(0.72, 1.0, vignette);

    // Accepted Signal board grade: cool steel in shadows, selective accent in
    // highlights, high black floor and no broad comic-poster quantisation.
    float final_luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float shadow = 1.0 - smoothstep(0.08, 0.52, final_luma);
    float highlight = smoothstep(0.56, 0.94, final_luma);
    color = mix(color, color * vec3(0.90, 1.015, 1.055), shadow * 0.095);
    color += accent_color.rgb * highlight * (0.018 + completion_reveal * 0.022);
    color = mix(color, color * color * (3.0 - 2.0 * color), ink_strength * 0.055);

    COLOR = vec4(color, 1.0);
}
