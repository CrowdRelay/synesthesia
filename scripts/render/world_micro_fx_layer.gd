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
var _time: float = 0.0
var _accum: float = 0.0
var _behavior

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func configure(room_style: String, accent_color: Color, secondary_color: Color, behavior) -> void:
    style = room_style
    accent = accent_color
    secondary = secondary_color
    _behavior = behavior
    _time = 0.0
    interaction_energy = 0.0
    queue_redraw()

func set_progress(value: float) -> void: progress = clampf(value, 0.0, 1.0)
func set_pointer(value: Vector2) -> void: pointer = value
func set_reduced_motion(value: bool) -> void: reduced_motion = value
func set_cinematic(value: float) -> void: cinematic = clampf(value, 0.0, 1.0)
func set_interaction_energy(value: float) -> void: interaction_energy = maxf(interaction_energy, clampf(value, 0.0, 1.0))
func set_living_strength(value: float) -> void: living_strength = clampf(value, 0.0, 1.0)

func _process(delta: float) -> void:
    interaction_energy = move_toward(interaction_energy, 0.0, delta * 1.7)
    if reduced_motion:
        if interaction_energy > 0.01 or cinematic > 0.01:
            queue_redraw()
        return
    _time = fmod(_time + delta, 10000.0)
    _accum += delta
    if _accum >= 1.0 / 24.0:
        _accum = 0.0
        queue_redraw()

func _draw() -> void:
    if size.x <= 2.0 or size.y <= 2.0:
        return
    var base_alpha := 0.034 + progress * 0.025 + interaction_energy * 0.030 + living_strength * 0.030
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
        _draw_living_state(base_alpha)
    if cinematic > 0.001:
        _draw_hero_beat()

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
    for i in range(11):
        var phase := float(i) * 0.71
        var a := phase + sin(_time * 0.27 + phase) * 0.035
        var radius := minf(size.x, size.y) * (0.13 + float(i % 4) * 0.028)
        var p := c + Vector2(cos(a), sin(a)) * radius
        var shimmer := 0.20 + 0.80 * maxf(0.0, sin(_time * 0.9 + phase))
        draw_line(p, p + Vector2.from_angle(a + 1.2) * (8.0 + i % 4 * 3.0), Color(accent, alpha * shimmer * (0.42 + shattered.size() * 0.08)), 1.0)

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

func _draw_living_state(alpha: float) -> void:
    var live := living_strength
    var c := Vector2(size.x * 0.5, size.y * 0.52)
    match style:
        "technophobia":
            var sweep := fmod(_time * 0.11, 1.0)
            var y := size.y * lerpf(0.18, 0.72, sweep)
            draw_line(Vector2(size.x * 0.12, y), Vector2(size.x * 0.88, y), Color(accent, alpha * live * 0.28), 1.0)
            for i in range(3):
                var spark_phase := fmod(_time * (0.19 + i * 0.04) + i * 0.37, 1.0)
                if spark_phase < 0.055:
                    var p := Vector2(size.x * (0.23 + i * 0.27), size.y * (0.31 + i * 0.09))
                    draw_line(p, p + Vector2(5.0 + i * 2.0, -7.0), Color(secondary, live * 0.32), 1.2)
        "unmasked":
            var pulse := 0.5 + 0.5 * sin(_time * 0.82)
            draw_arc(Vector2(size.x * 0.5, size.y * 0.43), size.x * (0.10 + pulse * 0.006), -2.8, 2.8, 56, Color(secondary, alpha * live * 0.78), 1.2)
            for i in range(13):
                var p := Vector2(fmod(float(i) * 71.0 + _time * (5.0 + i % 3), size.x), fmod(float(i) * 113.0 - _time * (7.0 + i % 4) + size.y, size.y))
                draw_circle(p, 0.7 + i % 2, Color(Color.WHITE, alpha * live * 0.20))
        "invaluable":
            for i in range(8):
                var a := float(i) * 0.83 + _time * 0.08
                var p := c + Vector2.from_angle(a) * size.x * (0.12 + i % 3 * 0.05)
                var glint := 0.35 + 0.65 * maxf(0.0, sin(_time * 1.2 + i))
                draw_line(p - Vector2(5, 0), p + Vector2(5, 0), Color(accent, alpha * live * glint), 1.0)
        "seed":
            for i in range(16):
                var travel := fmod(_time * (0.055 + i * 0.002) + i * 0.067, 1.0)
                var p := Vector2(size.x * 0.5 + sin(_time * 0.7 + i) * (9.0 + i % 4 * 5.0), size.y * lerpf(0.76, 0.18, travel))
                draw_circle(p, 1.0 + i % 2, Color(secondary if i % 3 == 0 else accent, alpha * live * (1.0 - travel * 0.45)))
        "party":
            for i in range(7):
                var center := Vector2(size.x * (0.14 + (i % 4) * 0.24), size.y * (0.25 + (i / 4) * 0.34))
                center += Vector2(sin(_time * (0.27 + i * 0.015) + i) * 5.0, cos(_time * 0.23 + i) * 7.0)
                var shine := 0.5 + 0.5 * sin(_time * 0.73 + i * 1.7)
                draw_arc(center, 18.0 + i % 3 * 4.0, -2.55, -1.35, 18, Color(Color.WHITE, alpha * live * shine * 0.28), 1.0)
                draw_line(center + Vector2(0, 18), center + Vector2(sin(_time * 0.45 + i) * 12.0, 62.0), Color(secondary, alpha * live * 0.18), 1.0)
        "calling":
            var altar := Vector2(size.x * 0.5, size.y * 0.63)
            var ripple := fmod(_time * 0.19, 1.0)
            draw_arc(altar, size.x * (0.07 + ripple * 0.22), 0.0, TAU, 64, Color(accent, alpha * live * (1.0 - ripple) * 0.46), 1.0)
            for uv in [Vector2(0.23,0.58), Vector2(0.34,0.67), Vector2(0.66,0.67), Vector2(0.77,0.58)]:
                var p: Vector2 = uv * size
                var flicker := 0.55 + 0.45 * sin(_time * 6.2 + p.x * 0.017) * sin(_time * 1.7 + p.y * 0.013)
                var flame := PackedVector2Array([p + Vector2(-2.2, 2.0), p + Vector2(0, -8.0 - flicker * 3.0), p + Vector2(2.2, 2.0)])
                draw_colored_polygon(flame, Color(secondary, alpha * live * (0.42 + flicker * 0.46)))
        "ashes":
            for i in range(22):
                var y := fmod(_time * (17.0 + i % 4 * 2.0) + i * 61.0, size.y * 0.72)
                var p := Vector2(size.x * 0.5 + sin(_time * 0.35 + i) * (25.0 + i % 5 * 14.0), size.y * 0.86 - y)
                draw_circle(p, 0.8 + i % 3 * 0.45, Color(secondary, alpha * live * (0.35 + (i % 4) * 0.10)))
        "waves":
            for i in range(11):
                var x := size.x * (0.13 + i / 10.0 * 0.74) + sin(_time * 0.21 + i) * 5.0
                draw_line(Vector2(x, size.y * 0.16), Vector2(x + sin(_time * 0.29 + i) * 6.0, size.y * 0.82), Color(accent if i % 2 else secondary, alpha * live * 0.10), 1.0)
            var window_pulse := 0.5 + 0.5 * sin(_time * 0.48)
            draw_rect(Rect2(Vector2(size.x * 0.34, size.y * 0.18), Vector2(size.x * 0.32, size.y * 0.48)), Color(accent, alpha * live * window_pulse * 0.035), true)
        "hybrid":
            for ring in range(6):
                var r := 28.0 + ring * 23.0
                var dir := -1.0 if ring % 2 else 1.0
                var phase := _time * (0.12 + ring * 0.015) * dir
                draw_arc(c, r, phase, phase + 4.9, 52, Color(accent if ring % 2 else secondary, alpha * live * 0.50), 1.0)
        "rise":
            for i in range(18):
                var y := fmod(_time * (12.0 + i % 4 * 1.5) + i * 53.0, size.y * 0.76)
                var x := size.x * (0.30 + float(i % 7) / 6.0 * 0.40) + sin(_time * 0.24 + i) * 4.0
                draw_circle(Vector2(x, size.y * 0.88 - y), 0.8 + i % 2, Color(Color.WHITE, alpha * live * 0.35))
        _:
            for i in range(5):
                var y := size.y * (0.28 + i * 0.10) + sin(_time * 0.31 + i) * 4.0
                draw_line(Vector2(size.x * 0.12, y), Vector2(size.x * 0.88, y), Color(accent if i % 2 == 0 else secondary, alpha * live * 0.24), 1.0)

func _draw_hero_beat() -> void:
    # Completion is deliberately short and room-specific. Cinematic is a 0..1
    # eased mix driven by RoomStage; this layer supplies the authored visual beat.
    var c := Vector2(size.x * 0.5, size.y * 0.46)
    var t := cinematic
    match style:
        "technophobia":
            for row in range(6):
                var on := 1.0 if t >= float(row) / 6.0 else 0.0
                var y := size.y * (0.18 + row * 0.08)
                draw_rect(Rect2(Vector2(size.x * 0.10, y), Vector2(size.x * 0.80, 2.0)), Color(accent, 0.10 * (1.0 - on)), true)
            draw_arc(c, size.x * (0.05 + t * 0.18), -2.7, 2.7, 64, Color(accent, 0.34 * t), 1.5)
        "unmasked":
            for i in range(12):
                var a := float(i) / 12.0 * TAU
                var p := c + Vector2.from_angle(a) * size.x * (0.04 + t * 0.30)
                draw_line(c.lerp(p, 0.72), p, Color(secondary, 0.22 * (1.0 - t * 0.55)), 1.2)
        "invaluable":
            for i in range(18):
                var a := float(i) * 2.1
                var p := c + Vector2.from_angle(a) * size.x * t * (0.08 + float(i % 5) * 0.025) + Vector2(0, size.y * t * t * 0.05)
                draw_line(p, p + Vector2.from_angle(a + 0.8) * 14.0, Color(accent, 0.30 * (1.0 - t * 0.65)), 1.0)
        "seed":
            var top := Vector2(size.x * 0.5, size.y * 0.20)
            draw_line(Vector2(size.x * 0.5, size.y * 0.78), top, Color(secondary, 0.20 + t * 0.48), 2.0)
            draw_circle(top, size.x * t * 0.18, Color(accent, 0.028 * t))
        "party":
            for i in range(22):
                var a := float(i) * 1.7
                var p := c + Vector2.from_angle(a) * size.x * t * (0.05 + i % 6 * 0.018)
                draw_circle(p, 1.0 + i % 3, Color(secondary if i % 2 == 0 else accent, 0.24 * (1.0 - t * 0.6)))
        "calling":
            for ring in range(7):
                draw_arc(c, size.x * (0.06 + ring * 0.035 + t * 0.05), -2.8 + t * ring * 0.07, 2.8 - t * ring * 0.05, 64, Color(accent if ring % 2 else secondary, 0.08 + t * 0.12), 1.0)
        "ashes":
            var wing := size.x * (0.08 + t * 0.22)
            draw_arc(c, wing, -2.95, -0.18, 48, Color(secondary, 0.12 + t * 0.30), 1.6)
            draw_arc(c, wing, 0.18, 2.95, 48, Color(secondary, 0.12 + t * 0.30), 1.6)
        "waves":
            draw_line(Vector2(size.x * 0.18, c.y), Vector2(size.x * 0.82, c.y), Color(accent, 0.10 + t * 0.30), 1.2)
            draw_circle(c, size.x * (0.03 + t * 0.17), Color(accent, 0.018 + t * 0.018))
        "hybrid":
            for ring in range(6):
                var r := 32.0 + ring * 21.0
                draw_arc(c, r, _time * (0.18 + ring * 0.02), _time * (0.18 + ring * 0.02) + lerpf(4.0, TAU, t), 60, Color(accent if ring % 2 else secondary, 0.10 + t * 0.12), 1.2)
        "rise":
            draw_rect(Rect2(Vector2.ZERO, size), Color(Color.WHITE, t * t * 0.075), true)
            for i in range(9):
                var x := size.x * (0.18 + float(i) / 8.0 * 0.64)
                draw_line(Vector2(x, size.y * 0.84), Vector2(size.x * 0.5, size.y * lerpf(0.38, 0.13, t)), Color(accent, 0.04 + t * 0.11), 1.0)
        _:
            for i in range(5):
                var y := size.y * (0.28 + i * 0.10)
                draw_line(Vector2(size.x * 0.08, y), Vector2(size.x * lerpf(0.30, 0.92, t), y), Color(accent, 0.08 + t * 0.12), 1.0)
