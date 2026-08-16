extends Control

# Ambient life is intentionally procedural and lightweight. The still artwork is
# the hero; this layer only adds room-specific motion, state feedback and the
# 2–3 second completion beat that makes each room feel authored rather than
# wallpaper-like.
var style: String = "uncertainty"
var accent: Color = Color("71dcff")
var secondary: Color = Color("e73535")
var progress: float = 0.0
var pointer: Vector2 = Vector2(0.5, 0.5)
var reduced_motion: bool = false
var cinematic: float = 0.0
var interaction_energy: float = 0.0
var living_strength: float = 0.0
var target_fps: float = 24.0
var runtime_scale: float = 1.0
var _time: float = 0.0
var _accum: float = 0.0
var _behavior
const WorldMicroFXDrawHelpers := preload("res://scripts/render/world_micro_fx_draw_helpers.gd")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visibility_changed.connect(_sync_processing)
    _sync_processing()

func configure(room_style: String, accent_color: Color, secondary_color: Color, behavior) -> void:
    style = room_style
    accent = accent_color
    secondary = secondary_color
    _behavior = behavior
    _time = 0.0
    interaction_energy = 0.0
    queue_redraw()

func set_progress(value: float) -> void:
    var next := clampf(value, 0.0, 1.0)
    if not is_equal_approx(next, progress): progress = next
func set_pointer(value: Vector2) -> void:
    if pointer.distance_squared_to(value) > 0.00000025: pointer = value
func set_reduced_motion(value: bool) -> void:
    if reduced_motion == value: return
    reduced_motion = value; _sync_processing(); queue_redraw()
func set_cinematic(value: float) -> void:
    var next := clampf(value, 0.0, 1.0)
    if is_equal_approx(next, cinematic): return
    cinematic = next; _sync_processing()
func set_interaction_energy(value: float) -> void:
    var next := maxf(interaction_energy, clampf(value, 0.0, 1.0))
    if is_equal_approx(next, interaction_energy): return
    interaction_energy = next; _sync_processing()
func set_living_strength(value: float) -> void:
    var next := clampf(value, 0.0, 1.0)
    if not is_equal_approx(next, living_strength): living_strength = next; _sync_processing()
func set_target_fps(value: float) -> void: target_fps = clampf(value, 12.0, 30.0)
func set_runtime_scale(value: float) -> void: runtime_scale = clampf(value, 0.55, 1.0)

func _sync_processing() -> void:
    var active: bool = is_visible_in_tree() and (not reduced_motion or interaction_energy > 0.01 or cinematic > 0.01)
    set_process(active)

func _process(delta: float) -> void:
    interaction_energy = move_toward(interaction_energy, 0.0, delta * 1.7)
    if reduced_motion:
        if interaction_energy > 0.01 or cinematic > 0.01:
            queue_redraw()
        if interaction_energy <= 0.01 and cinematic <= 0.01:
            set_process(false)
        return
    _time = fmod(_time + delta, 10000.0)
    _accum += delta
    var effective_fps: float = maxf(12.0, target_fps * runtime_scale)
    if _accum >= 1.0 / effective_fps:
        _accum = 0.0
        queue_redraw()

func _draw() -> void:
    if size.x <= 2.0 or size.y <= 2.0:
        return
    var base_alpha := 0.048 + progress * 0.032 + interaction_energy * 0.040 + living_strength * 0.060
    match style:
        "technophobia": _draw_tech(base_alpha)
        "unmasked": _draw_mask(base_alpha)
        "invaluable": _draw_glass(base_alpha)
        "seed": _draw_seed(base_alpha)
        "party": _draw_party(base_alpha)
        "ashes": _draw_ashes(base_alpha)
        "calling": _draw_calling(base_alpha)
        "waves": _draw_waves(base_alpha)
        "hybrid": _draw_hybrid(base_alpha)
        "rise": _draw_rise(base_alpha)
        _: _draw_uncertainty(base_alpha)
    _draw_pointer_response(base_alpha)
    if living_strength > 0.01:
        WorldMicroFXDrawHelpers.draw_living_state(self, style, accent, secondary, base_alpha, living_strength, _time)
        _draw_gameplay_living_accents(base_alpha)
        _draw_post_reveal_touch_signature(base_alpha)
    if cinematic > 0.001:
        WorldMicroFXDrawHelpers.draw_hero_beat(self, style, accent, secondary, cinematic)

func _state(key: String, fallback: Variant = null) -> Variant:
    if _behavior == null:
        return fallback
    var value: Variant = _behavior.get("state")
    if not value is Dictionary:
        return fallback
    return (value as Dictionary).get(key, fallback)

func _draw_pointer_response(alpha: float) -> void:
    if interaction_energy <= 0.015:
        return
    var center := pointer * size
    var radius := 15.0 + interaction_energy * 24.0
    draw_arc(center, radius, -2.55, -0.18, 26, Color(accent, alpha * (1.4 + interaction_energy)), 1.0)
    draw_arc(center, radius + 7.0, 0.34, 2.68, 26, Color(secondary, alpha * interaction_energy), 1.0)

func _draw_tech(alpha: float) -> void:
    var breaker_off := bool(_state("breaker_off", false))
    var locked := bool(_state("signal_locked", false))
    var unplugged_value: Variant = _state("cables_unplugged", [])
    var unplugged: Array = unplugged_value if unplugged_value is Array else []
    var active := int(_state("active_cable", -1))
    for i in range(7):
        var y := size.y * (0.14 + float(i) * 0.075)
        var glitch := sin(_time * (7.0 + i * 0.57) + float(i) * 1.71) * size.x * 0.005
        var live := 0.20 if breaker_off else (0.58 - float(unplugged.size()) * 0.10)
        if not locked and i % 3 == 0:
            live += 0.12 * maxf(0.0, sin(_time * 12.0 + i))
        draw_line(Vector2(size.x * 0.08 + glitch, y), Vector2(size.x * 0.92 + glitch, y), Color(secondary, alpha * live), 1.0)
    # LEDs never blink in perfect sync; after breaker-off they decay to darkness.
    for i in range(9):
        var x := size.x * (0.12 + float(i % 3) * 0.35)
        var y := size.y * (0.20 + float(i / 3) * 0.13)
        var blink := 0.18 + 0.82 * maxf(0.0, sin(_time * (2.2 + i * 0.19) + i))
        draw_circle(Vector2(x, y), 1.3 + float(i % 2), Color(accent, alpha * blink * (0.10 if breaker_off else 0.88)))
    if active >= 0:
        var tension := clampf(float(int(_state("tension_bucket", 0))) / 4.0, 0.0, 1.0)
        var center := pointer * size
        draw_circle(center, 5.0 + tension * 7.0, Color(secondary, alpha * (0.30 + tension * 1.8)))

func _draw_mask(alpha: float) -> void:
    var removed_value: Variant = _state("removed", [])
    var removed: Array = removed_value if removed_value is Array else []
    var centers := [Vector2(0.29, 0.34), Vector2(0.51, 0.28), Vector2(0.72, 0.39)]
    for i in range(centers.size()):
        if removed.has(i):
            continue
        var sway := sin(_time * (0.48 + i * 0.07) + i * 1.9) * (2.0 + i)
        var c: Vector2 = centers[i] * size + Vector2(sway, 0.0)
        var r := 26.0 + float(i) * 4.0
        draw_arc(c, r, -2.7, -0.25, 30, Color(secondary, alpha * 0.78), 1.0)
        draw_arc(c, r + 7.0, 0.42, 2.76, 30, Color(accent, alpha * 0.30), 1.0)
        draw_line(c + Vector2(0, -r), c + Vector2(sway * 0.25, -r - size.y * 0.14), Color(Color.WHITE, alpha * 0.15), 1.0)

func _draw_glass(alpha: float) -> void:
    var shattered_value: Variant = _state("shattered", [])
    var shattered: Array = shattered_value if shattered_value is Array else []
    var c := Vector2(size.x * 0.5, size.y * 0.50)
    for i in range(14):
        var phase := float(i) * 0.58
        var a := phase + sin(_time * 0.29 + phase) * 0.050
        var radius := minf(size.x, size.y) * (0.11 + float(i % 5) * 0.025)
        var p := c + Vector2(cos(a), sin(a)) * radius + Vector2(sin(_time * 0.25 + i) * 2.0, cos(_time * 0.19 + i * 0.7) * 1.5)
        var shimmer := 0.24 + 0.76 * maxf(0.0, sin(_time * (1.0 + i * 0.03) + phase))
        var seg := Vector2.from_angle(a + 1.2) * (10.0 + i % 4 * 3.6)
        draw_line(p - seg * 0.35, p + seg, Color(accent, alpha * shimmer * (0.52 + shattered.size() * 0.10)), 1.1)
    var sweep := fmod(_time * 0.12, 1.0)
    var sx := lerpf(size.x * 0.22, size.x * 0.78, sweep)
    draw_line(Vector2(sx - 22.0, size.y * 0.26), Vector2(sx + 18.0, size.y * 0.74), Color(Color.WHITE, alpha * 0.16 * (1.0 - abs(sweep - 0.5) * 1.5)), 1.6)

func _draw_seed(alpha: float) -> void:
    var growth := clampf(float(_state("growth", _state("root_growth", progress))), 0.0, 1.0)
    var base := Vector2(size.x * 0.5, size.y * 0.76)
    var heartbeat := 0.5 + 0.5 * sin(_time * 2.4)
    draw_circle(base, 3.5 + heartbeat * 2.2, Color(secondary, alpha * (1.5 + heartbeat)))
    var top := Vector2(size.x * 0.5 + sin(_time * 0.42) * 5.0, size.y * lerpf(0.75, 0.27, growth))
    draw_line(base, top, Color(secondary, alpha * (1.1 + growth)), 1.2)
    for i in range(12):
        var travel := fmod(_time * (0.035 + i * 0.002) + float(i) * 0.081, 1.0)
        var p := base.lerp(top, travel) + Vector2(sin(_time + i) * (3.0 + i % 3), 0.0)
        draw_circle(p, 1.0 + float(i % 2), Color(accent, alpha * (0.25 + growth * 0.65)))

func _draw_party(alpha: float) -> void:
    var popped_value: Variant = _state("popped", [])
    var popped: Array = popped_value if popped_value is Array else []
    # Membranes drift asynchronously; they are intentionally dim and organic.
    for i in range(10):
        if popped.has(i):
            continue
        var x := size.x * (0.09 + float(i % 5) * 0.205)
        var y0 := size.y * (0.27 + float(i / 5) * 0.30)
        var drift := Vector2(sin(_time * (0.33 + i * 0.018) + i) * 5.0, cos(_time * (0.27 + i * 0.014) + i * 0.7) * 7.0)
        var center := Vector2(x, y0) + drift
        var radius := 10.0 + float(i % 3) * 4.0
        draw_arc(center, radius, -2.8, 2.4, 28, Color(secondary if i % 2 == 0 else accent, alpha * 0.38), 1.0)
        draw_line(center + Vector2(0, radius), center + Vector2(sin(_time + i) * 7.0, radius + 42.0), Color(Color.WHITE, alpha * 0.10), 1.0)

func _draw_ashes(alpha: float) -> void:
    var formed := bool(_state("phoenix", _state("formed", false)))
    for i in range(24):
        var phase := float(i) * 0.53
        var rise := fmod(_time * (12.0 + float(i % 5) * 1.8) + float(i) * 37.0, size.y * 0.62)
        var x := size.x * 0.5 + sin(_time * 0.42 + phase) * (22.0 + float(i % 6) * 10.0)
        var y := size.y * 0.82 - rise
        draw_circle(Vector2(x, y), 0.9 + float(i % 3) * 0.6, Color(secondary, alpha * (0.45 + (0.55 if formed else 0.0))))
    if formed:
        var c := Vector2(size.x * 0.5, size.y * 0.43)
        var breath := 0.5 + 0.5 * sin(_time * 0.82)
        draw_arc(c, size.x * (0.14 + breath * 0.008), -2.85, -0.20, 36, Color(secondary, alpha * 0.88), 1.2)
        draw_arc(c, size.x * (0.14 + breath * 0.008), 0.20, 2.85, 36, Color(secondary, alpha * 0.88), 1.2)

func _draw_calling(alpha: float) -> void:
    var awakened := bool(_state("poured", false))
    var synced := bool(_state("toast", false))
    var c := Vector2(size.x * 0.5, size.y * 0.62)
    for ring in range(5):
        var phase := _time * (0.13 + ring * 0.017) * (-1.0 if ring % 2 else 1.0)
        var radius := size.x * (0.075 + ring * 0.035)
        var strength := (0.22 if awakened else 0.08) + (0.30 if synced else 0.0)
        draw_arc(c, radius, phase, phase + 4.6, 48, Color(secondary if ring % 2 == 0 else accent, alpha * strength), 1.0)
    if awakened:
        var ripple := fmod(_time * 0.34, 1.0)
        draw_arc(c, size.x * (0.10 + ripple * 0.24), 0.0, TAU, 64, Color(accent, alpha * (1.0 - ripple) * 0.30), 1.0)

func _draw_waves(alpha: float) -> void:
    var closeness := clampf(float(_state("closeness", 0.0)), 0.0, 1.0)
    # Curtain/rain field: vertical traces move at different speeds and never sync.
    for i in range(18):
        var x := size.x * (0.04 + float(i) / 18.0 * 0.92)
        var drift := sin(_time * 0.23 + i * 0.54) * 4.0
        var y := fmod(_time * (18.0 + i % 4 * 3.0) + float(i) * 47.0, size.y)
        draw_line(Vector2(x + drift, y - 18.0), Vector2(x + drift, y + 8.0), Color(accent, alpha * 0.17), 1.0)
    var mid := size.y * 0.58
    for channel in range(2):
        var points := PackedVector2Array()
        for i in range(40):
            var x := size.x * float(i) / 39.0
            var amp := lerpf(12.0, 3.5, closeness)
            var phase := _time * (0.72 + channel * 0.05) + channel * lerpf(2.2, 0.15, closeness)
            var y := mid + (channel * 18.0 - 9.0) * (1.0 - closeness) + sin(float(i) * 0.61 + phase) * amp
            points.append(Vector2(x, y))
        draw_polyline(points, Color(accent if channel == 0 else secondary, alpha * (0.38 + closeness * 0.55)), 1.0)

func _draw_hybrid(alpha: float) -> void:
    var c := Vector2(size.x * 0.5, size.y * 0.52)
    var solve := clampf(float(_state("alignment", _state("aim", progress))), 0.0, 1.0)
    for ring in range(5):
        var dir := -1.0 if ring % 2 else 1.0
        var phase := _time * (0.17 + ring * 0.027) * dir
        var radius := 35.0 + ring * 24.0
        draw_arc(c, radius, phase, phase + 4.7 - solve * 0.7, 48, Color(secondary if ring % 2 == 0 else accent, alpha * (0.28 + solve * 0.48)), 1.0)
    var lock := 0.5 + 0.5 * sin(_time * 1.6)
    draw_line(c - Vector2(12 + solve * 16, 0), c + Vector2(12 + solve * 16, 0), Color(accent, alpha * (0.35 + lock * 0.35)), 1.0)

func _draw_rise(alpha: float) -> void:
    var done := (float(bool(_state("light_tap", false))) + float(bool(_state("center_hold", false))) + float(bool(_state("rise_swipe", false)))) / 3.0
    for i in range(26):
        var lane := float(i % 7) / 6.0
        var x := lerpf(size.x * 0.18, size.x * 0.82, lane)
        var travel := fmod(_time * (24.0 + float(i % 5) * 3.0) + float(i) * 41.0, size.y * 0.68)
        var y := size.y * 0.88 - travel
        draw_line(Vector2(x, y), Vector2(x + sin(_time + i) * 2.0, y - 9.0 - done * 12.0), Color(accent, alpha * (0.18 + done * 0.55)), 1.0)
    var top := Vector2(size.x * 0.5, size.y * 0.19)
    draw_circle(top, 2.5 + (0.5 + 0.5 * sin(_time * 1.25)) * 4.0, Color(Color.WHITE, alpha * (0.35 + done * 0.55)))

func _draw_uncertainty(alpha: float) -> void:
    for channel in range(5):
        var y := size.y * (0.22 + 0.13 * channel)
        var points := PackedVector2Array()
        for i in range(26):
            var x := size.x * float(i) / 25.0
            var wobble := sin(float(i) * 0.72 + _time * (0.46 + channel * 0.045) + channel) * (3.0 + channel)
            points.append(Vector2(x, y + wobble))
        draw_polyline(points, Color(accent if channel % 2 == 0 else secondary, alpha * (0.20 + channel * 0.04)), 1.0)


func _draw_post_reveal_touch_signature(alpha: float) -> void:
    if living_strength <= 0.01 or interaction_energy <= 0.02:
        return
    var center: Vector2 = pointer * size
    var energy: float = clampf(interaction_energy, 0.0, 1.0)
    var pulse: float = 0.5 + 0.5 * sin(_time * 5.2)
    match style:
        "technophobia":
            var jitter: float = 3.0 + energy * 8.0
            draw_polyline(PackedVector2Array([
                center + Vector2(-22, 0),
                center + Vector2(-10, -jitter),
                center + Vector2(0, jitter * 0.55),
                center + Vector2(11, -jitter * 0.75),
                center + Vector2(24, 1),
            ]), Color(secondary, alpha * energy * 2.4), 1.5)
        "invaluable":
            for i in range(4):
                var angle: float = float(i) * PI * 0.5 + _time * 0.12
                var ray: Vector2 = Vector2.from_angle(angle) * (15.0 + energy * 18.0)
                draw_line(center - ray * 0.25, center + ray, Color(Color.WHITE, alpha * energy * (1.3 + pulse)), 1.2)
        "party":
            for i in range(6):
                var angle: float = float(i) / 6.0 * TAU + _time * 0.26
                var point: Vector2 = center + Vector2.from_angle(angle) * (12.0 + pulse * 14.0)
                draw_circle(point, 1.4 + energy * 1.8, Color(secondary if i % 2 == 0 else accent, alpha * energy * 1.8))
        "calling", "waves", "hybrid":
            for i in range(3):
                var radius: float = 10.0 + float(i) * 11.0 + pulse * 6.0
                draw_arc(center, radius, -2.7, 2.7, 28, Color(accent if i % 2 == 0 else secondary, alpha * energy * (1.6 - i * 0.25)), 1.1)
        "ashes", "seed", "rise":
            for i in range(7):
                var travel: float = fmod(_time * (0.42 + i * 0.025) + i * 0.14, 1.0)
                var point: Vector2 = center + Vector2(sin(i * 2.1) * (8.0 + i * 2.0), -travel * (22.0 + energy * 24.0))
                draw_circle(point, 1.0 + energy, Color(secondary if i % 2 == 0 else accent, alpha * energy * (1.0 - travel) * 1.8))
        "unmasked":
            draw_arc(center, 15.0 + pulse * 9.0, -2.6, 2.6, 30, Color(Color.WHITE, alpha * energy * 1.7), 1.2)
            draw_line(center + Vector2(-18, 13), center + Vector2(20, -15), Color(secondary, alpha * energy * 1.5), 1.0)
        _:
            draw_arc(center, 14.0 + pulse * 13.0, 0.0, TAU, 34, Color(accent, alpha * energy * 1.7), 1.1)

func _draw_gameplay_living_accents(alpha: float) -> void:
    if living_strength <= 0.01:
        return
    var live := living_strength
    var c := Vector2(size.x * 0.5, size.y * 0.52)
    match style:
        "technophobia":
            for i in range(4):
                var phase := fmod(_time * (0.18 + i * 0.025) + i * 0.23, 1.0)
                var center := Vector2(size.x * (0.18 + i * 0.21), size.y * (0.24 + (i % 2) * 0.20))
                draw_arc(center, 10.0 + phase * 30.0, -2.8, 2.8, 32, Color(accent, alpha * live * (1.0 - phase) * 0.55), 1.0)
            var arc_phase := fmod(_time * 0.31, 1.0)
            if arc_phase < 0.08:
                var p := Vector2(size.x * 0.68, size.y * 0.39)
                draw_polyline(PackedVector2Array([p, p + Vector2(4,-9), p + Vector2(10,-4), p + Vector2(16,-14)]), Color(secondary, 0.42 * live), 1.4)
        "unmasked":
            for i in range(7):
                var a := float(i) / 7.0 * TAU + _time * (0.10 + i * 0.004)
                var p := c + Vector2.from_angle(a) * (42.0 + i * 7.0)
                var gl := 0.5 + 0.5 * sin(_time * 1.4 + i * 1.9)
                draw_line(p - Vector2(4,4), p + Vector2(4,4), Color(Color.WHITE, alpha * live * gl * 0.40), 1.0)
            var blink := pow(maxf(0.0, sin(_time * 0.72)), 14.0)
            draw_circle(Vector2(size.x * 0.5, size.y * 0.43), 3.0 + blink * 5.0, Color(secondary, alpha * live * (0.20 + blink * 0.82)))
        "invaluable":
            for i in range(14):
                var a := float(i) * 0.66 + sin(_time * 0.17 + i) * 0.06
                var r := 34.0 + float(i % 5) * 24.0
                var p := c + Vector2.from_angle(a) * r
                var glint := pow(maxf(0.0, sin(_time * (0.72 + i * 0.025) + i)), 7.0)
                draw_line(p - Vector2(8,0), p + Vector2(8,0), Color(accent, alpha * live * glint * 0.78), 1.3)
                draw_line(p - Vector2(0,5), p + Vector2(0,5), Color(Color.WHITE, alpha * live * glint * 0.50), 1.0)
            var sweep := fmod(_time * 0.11, 1.0)
            var x0 := lerpf(size.x * 0.18, size.x * 0.82, sweep)
            draw_line(Vector2(x0 - 20.0, size.y * 0.27), Vector2(x0 + 24.0, size.y * 0.77), Color(Color.WHITE, alpha * live * (1.0 - abs(sweep - 0.5) * 1.4) * 0.28), 1.8)
        "seed":
            var pulse := fmod(_time * 0.22, 1.0)
            var y := size.y * lerpf(0.76, 0.18, pulse)
            var radius := 5.0 + 20.0 * sin(pulse * PI)
            draw_arc(Vector2(size.x * 0.5, y), radius, 0.0, TAU, 34, Color(secondary, alpha * live * (1.0 - pulse) * 0.72), 1.2)
            for i in range(10):
                var x := size.x * 0.5 + sin(_time * 0.55 + i) * (16.0 + i * 7.0)
                draw_circle(Vector2(x, y + i * 4.0), 1.0 + i % 2, Color(accent, alpha * live * 0.28))
        "party":
            var beat := pow(maxf(0.0, sin(_time * 0.92)), 10.0)
            draw_circle(c, 28.0 + beat * 18.0, Color(secondary, alpha * live * beat * 0.10))
            draw_arc(c, 48.0 + beat * 22.0, -2.7, 2.7, 42, Color(accent, alpha * live * beat * 0.42), 1.2)
            for i in range(12):
                var p := Vector2(size.x * (0.10 + float(i % 6) * 0.16), size.y * (0.26 + float(i / 6) * 0.32))
                p += Vector2(sin(_time * 0.31 + i) * 8.0, cos(_time * 0.25 + i) * 10.0)
                draw_circle(p, 1.0 + beat * 2.0, Color(Color.WHITE, alpha * live * (0.10 + beat * 0.24)))
        "calling":
            for ring in range(4):
                var r := 28.0 + ring * 20.0
                var dir := -1.0 if ring % 2 else 1.0
                var phase := _time * (0.16 + ring * 0.025) * dir
                draw_arc(Vector2(size.x * 0.5, size.y * 0.63), r, phase, phase + 1.45 + ring * 0.25, 28, Color(secondary if ring % 2 == 0 else accent, alpha * live * 0.46), 1.3)
            for i in range(8):
                var x := size.x * (0.33 + i * 0.045)
                var y := size.y * 0.62 + sin(_time * 0.9 + i) * 4.0
                draw_line(Vector2(x, y), Vector2(x + 12.0, y + sin(_time * 1.2 + i) * 4.0), Color(Color.WHITE, alpha * live * 0.16), 1.0)
        "ashes":
            var pulse := pow(maxf(0.0, sin(_time * 0.58)), 7.0)
            draw_circle(Vector2(size.x * 0.5, size.y * 0.43), 8.0 + pulse * 16.0, Color(secondary, alpha * live * pulse * 0.18))
            for i in range(14):
                var travel := fmod(_time * (0.08 + i * 0.004) + i * 0.11, 1.0)
                var p := Vector2(size.x * 0.5 + sin(i * 2.1 + _time) * (18.0 + i * 4.0), size.y * lerpf(0.72, 0.24, travel))
                draw_circle(p, 0.8 + i % 3 * 0.4, Color(secondary, alpha * live * (1.0 - travel) * 0.46))
        "waves":
            var sync := 0.5 + 0.5 * sin(_time * 0.38)
            var left := Vector2(size.x * lerpf(0.31, 0.46, sync), size.y * 0.59)
            var right := Vector2(size.x * lerpf(0.69, 0.54, sync), size.y * 0.59)
            draw_arc(left, 17.0 + sync * 8.0, -2.5, 2.5, 30, Color(secondary, alpha * live * 0.36), 1.0)
            draw_arc(right, 17.0 + sync * 8.0, -2.5, 2.5, 30, Color(accent, alpha * live * 0.36), 1.0)
            if sync > 0.86:
                draw_line(left, right, Color(Color.WHITE, alpha * live * (sync - 0.86) * 3.0), 1.2)
        "hybrid":
            var pulse := fmod(_time * 0.17, 1.0)
            draw_arc(c, 30.0 + pulse * 86.0, -2.8, 2.8, 58, Color(accent, alpha * live * (1.0 - pulse) * 0.56), 1.1)
            if pulse < 0.12:
                draw_line(c - Vector2(34,0), c + Vector2(34,0), Color(secondary, alpha * live * 0.52), 1.3)
            draw_circle(c, 4.0 + sin(_time * 1.3) * 1.5, Color(Color.WHITE, alpha * live * 0.14))
        "rise":
            var shaft := 0.5 + 0.5 * sin(_time * 0.31)
            draw_rect(Rect2(Vector2(size.x * 0.47, size.y * 0.13), Vector2(size.x * 0.06, size.y * 0.68)), Color(Color.WHITE, alpha * live * (0.024 + shaft * 0.030)), true)
            for i in range(14):
                var travel := fmod(_time * (0.07 + i * 0.003) + i * 0.09, 1.0)
                var p := Vector2(size.x * (0.37 + float(i % 6) * 0.05), size.y * lerpf(0.82, 0.18, travel))
                draw_line(p, p - Vector2(0, 5.0 + i % 3 * 2.0), Color(accent, alpha * live * (1.0 - travel) * 0.34), 1.0)
        _:
            var sweep := fmod(_time * 0.13, 1.0)
            var x := size.x * lerpf(0.12, 0.88, sweep)
            draw_line(Vector2(x, size.y * 0.22), Vector2(x, size.y * 0.75), Color(accent, alpha * live * (1.0 - abs(sweep - 0.5)) * 0.18), 1.0)
            for i in range(4):
                var y := size.y * (0.28 + i * 0.11) + sin(_time * 0.31 + i) * 6.0
                draw_line(Vector2(size.x * 0.16, y), Vector2(size.x * 0.84, y), Color(secondary if i % 2 == 0 else accent, alpha * live * 0.18), 1.0)


func _draw_living_state(alpha: float) -> void:
    WorldMicroFXDrawHelpers.draw_living_state(self, style, accent, secondary, alpha, living_strength, _time)

func _draw_hero_beat() -> void:
    WorldMicroFXDrawHelpers.draw_hero_beat(self, style, accent, secondary, cinematic)
