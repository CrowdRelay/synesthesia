extends Control

const MAX_EFFECTS: int = 14

var accent: Color = Color("72afff")
var secondary: Color = Color("ff6680")
var reduced_motion: bool = false
var calm_mode: bool = true
var _effects: Array[Dictionary] = []
var _accumulator: float = 0.0
var _runtime_scale: float = 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(false)

func configure(accent_color: Color, secondary_color: Color) -> void:
    accent = accent_color
    secondary = secondary_color

func set_sensory(calm: bool, reduced: bool) -> void:
    calm_mode = calm
    reduced_motion = reduced

func set_runtime_scale(value: float) -> void:
    _runtime_scale = clampf(value, 0.55, 1.0)
    var max_effects := maxi(8, int(round(float(MAX_EFFECTS) * _runtime_scale)))
    while _effects.size() > max_effects:
        _effects.pop_front()

func spawn(point_norm: Vector2, kind: String) -> void:
    var duration: float = 0.48 if calm_mode else 0.62
    if reduced_motion:
        duration = 0.32
    _effects.append({
        "point": Vector2(clampf(point_norm.x, 0.0, 1.0), clampf(point_norm.y, 0.0, 1.0)),
        "kind": kind,
        "age": 0.0,
        "duration": duration,
        "seed": int(Time.get_ticks_usec() & 0x7fffffff),
    })
    var max_effects := maxi(8, int(round(float(MAX_EFFECTS) * _runtime_scale)))
    while _effects.size() > max_effects:
        _effects.pop_front()
    set_process(true)
    queue_redraw()

func clear() -> void:
    _effects.clear()
    set_process(false)
    queue_redraw()

func _process(delta: float) -> void:
    if _effects.is_empty():
        return
    _accumulator += delta
    var target_hz: float = 18.0 if reduced_motion else maxf(20.0, 30.0 * _runtime_scale)
    if _accumulator < 1.0 / target_hz:
        return
    var elapsed: float = _accumulator
    _accumulator = 0.0
    for effect in _effects:
        effect["age"] = float(effect.get("age", 0.0)) + elapsed
    for index in range(_effects.size() - 1, -1, -1):
        var effect: Dictionary = _effects[index]
        if float(effect.get("age", 0.0)) >= float(effect.get("duration", 0.5)):
            _effects.remove_at(index)
    if _effects.is_empty():
        set_process(false)
    queue_redraw()

func _draw() -> void:
    if size.x <= 1.0 or size.y <= 1.0:
        return
    for effect in _effects:
        var point_value: Variant = effect.get("point", Vector2(0.5, 0.5))
        var point_norm: Vector2 = point_value if point_value is Vector2 else Vector2(0.5, 0.5)
        var center: Vector2 = Vector2(point_norm.x * size.x, point_norm.y * size.y)
        var duration: float = maxf(0.05, float(effect.get("duration", 0.5)))
        var t: float = clampf(float(effect.get("age", 0.0)) / duration, 0.0, 1.0)
        var alpha: float = (1.0 - t) * (0.16 if calm_mode else 0.24)
        var radius: float = lerpf(8.0, 62.0 if reduced_motion else 86.0, t)
        var kind: String = str(effect.get("kind", "interaction"))
        match kind:
            "mirror":
                _draw_shards(center, radius, alpha, int(effect.get("seed", 0)))
            "balloon":
                _draw_confetti(center, radius, alpha, int(effect.get("seed", 0)))
            "screen", "duel":
                _draw_glitch(center, radius, alpha)
            "cable_grab", "cable_tension":
                _draw_cable_tension(center, radius, alpha)
            "cable_snap":
                _draw_cable_snap(center, radius, alpha)
            "cable_unplug":
                _draw_unplug_sparks(center, radius, alpha, int(effect.get("seed", 0)))
            "breaker":
                _draw_breaker_pulse(center, radius, alpha)
            "signal_lock", "semantic_echo":
                _draw_signal_lock(center, radius, alpha)
            "phoenix", "seed", "light":
                _draw_rays(center, radius, alpha)
            "wave", "presence", "toast":
                _draw_ring(center, radius, alpha)
            "mask":
                _draw_peel(center, radius, alpha)
            "root":
                _draw_root_burst(center, radius, alpha)
            "ember":
                _draw_embers(center, radius, alpha, int(effect.get("seed", 0)))
            "pour":
                _draw_droplets(center, radius, alpha, int(effect.get("seed", 0)))
            _:
                _draw_ring(center, radius, alpha)

func _draw_ring(center: Vector2, radius: float, alpha: float) -> void:
    draw_arc(center, radius, 0.0, TAU, 36, Color(accent, alpha), 1.6)
    draw_arc(center, radius * 0.68, 0.0, TAU, 28, Color(secondary, alpha * 0.48), 1.0)

func _draw_shards(center: Vector2, radius: float, alpha: float, seed: int) -> void:
    for index in range(9):
        var angle: float = float(index) * TAU / 9.0 + _hash01(index, seed) * 0.34
        var inner: Vector2 = center + Vector2.from_angle(angle) * radius * 0.12
        var outer: Vector2 = center + Vector2.from_angle(angle) * radius * lerpf(0.56, 1.0, _hash01(index + 19, seed))
        draw_line(inner, outer, Color(Color.WHITE, alpha * 1.25), 1.1)

func _draw_confetti(center: Vector2, radius: float, alpha: float, seed: int) -> void:
    for index in range(10):
        var angle: float = float(index) * TAU / 10.0 + _hash01(index, seed) * 0.5
        var distance: float = radius * lerpf(0.34, 1.0, _hash01(index + 31, seed))
        var point: Vector2 = center + Vector2.from_angle(angle) * distance
        var color: Color = accent if index % 2 == 0 else secondary
        draw_rect(Rect2(point - Vector2(2.5, 1.0), Vector2(5.0, 2.0)), Color(color, alpha * 1.35), true)

func _draw_glitch(center: Vector2, radius: float, alpha: float) -> void:
    for index in range(6):
        var offset: float = (float(index) - 2.5) * radius * 0.13
        var width: float = radius * (0.34 + float(index % 3) * 0.11)
        draw_line(center + Vector2(-width, offset), center + Vector2(width, offset), Color(accent, alpha * (1.0 - float(index) * 0.08)), 1.6)

func _draw_rays(center: Vector2, radius: float, alpha: float) -> void:
    for index in range(8):
        var angle: float = float(index) * TAU / 8.0
        draw_line(center + Vector2.from_angle(angle) * radius * 0.16, center + Vector2.from_angle(angle) * radius, Color(accent, alpha), 1.2)

func _draw_cable_tension(center: Vector2, radius: float, alpha: float) -> void:
    draw_arc(center, radius * 0.72, -PI * 0.20, PI * 1.18, 22, Color(accent, alpha * 0.78), 1.2)
    draw_line(center - Vector2(radius * 0.42, 0.0), center + Vector2(radius * 0.42, 0.0), Color(secondary, alpha * 0.42), 1.0)

func _draw_cable_snap(center: Vector2, radius: float, alpha: float) -> void:
    var points := PackedVector2Array()
    for index in range(7):
        var x := lerpf(-radius * 0.72, radius * 0.72, float(index) / 6.0)
        var y := sin(float(index) * PI) * radius * 0.12
        points.append(center + Vector2(x, y))
    draw_polyline(points, Color(accent, alpha * 0.72), 1.4, true)

func _draw_unplug_sparks(center: Vector2, radius: float, alpha: float, seed: int) -> void:
    draw_arc(center, radius * 0.56, 0.0, TAU, 24, Color(accent, alpha * 0.38), 1.0)
    for index in range(11):
        var angle := float(index) * TAU / 11.0 + _hash01(index + 41, seed) * 0.42
        var inner := center + Vector2.from_angle(angle) * radius * 0.14
        var outer := center + Vector2.from_angle(angle) * radius * lerpf(0.45, 1.0, _hash01(index + 61, seed))
        var spark_color := secondary if index % 3 == 0 else accent
        draw_line(inner, outer, Color(spark_color, alpha * 1.45), 1.25)

func _draw_breaker_pulse(center: Vector2, radius: float, alpha: float) -> void:
    var rect := Rect2(center - Vector2(radius * 0.36, radius * 0.48), Vector2(radius * 0.72, radius * 0.96))
    draw_rect(rect, Color(accent, alpha * 0.54), false, 1.3)
    draw_line(center - Vector2(radius * 0.10, radius * 0.24), center + Vector2(radius * 0.10, radius * 0.24), Color(secondary, alpha * 0.92), 2.0)
    draw_arc(center, radius, 0.0, TAU, 30, Color(accent, alpha * 0.26), 1.0)

func _draw_signal_lock(center: Vector2, radius: float, alpha: float) -> void:
    for ring in range(3):
        var r := radius * (0.45 + float(ring) * 0.28)
        draw_arc(center, r, -PI * 0.78, PI * 0.78, 34, Color(accent, alpha * (1.25 - float(ring) * 0.24)), 1.4)
    var waveform := PackedVector2Array()
    for index in range(19):
        var t := float(index) / 18.0
        waveform.append(center + Vector2((t - 0.5) * radius * 1.35, sin(t * TAU * 3.0) * radius * 0.16 * (1.0 - absf(t - 0.5))))
    draw_polyline(waveform, Color(Color.WHITE, alpha * 1.18), 1.4, true)

func _draw_peel(center: Vector2, radius: float, alpha: float) -> void:
    draw_arc(center + Vector2(radius * 0.12, 0.0), radius * 0.70, -2.55, 1.10, 28, Color(accent, alpha * 0.95), 1.3)
    draw_line(center - Vector2(radius * 0.46, radius * 0.18), center + Vector2(radius * 0.62, radius * 0.24), Color(Color.WHITE, alpha * 0.72), 1.0)

func _draw_root_burst(center: Vector2, radius: float, alpha: float) -> void:
    for index in range(7):
        var angle := lerpf(-PI * 0.88, -PI * 0.12, float(index) / 6.0)
        var bend := Vector2.from_angle(angle) * radius * (0.42 + float(index % 3) * 0.14)
        draw_line(center, center + bend, Color(accent, alpha * (0.62 + float(index % 2) * 0.28)), 1.1)

func _draw_embers(center: Vector2, radius: float, alpha: float, seed: int) -> void:
    for index in range(10):
        var x := lerpf(-radius * 0.65, radius * 0.65, _hash01(index + 7, seed))
        var y := -radius * lerpf(0.20, 1.0, _hash01(index + 17, seed))
        draw_circle(center + Vector2(x, y), 1.0 + float(index % 3) * 0.6, Color(secondary if index % 3 == 0 else accent, alpha * 1.25))

func _draw_droplets(center: Vector2, radius: float, alpha: float, seed: int) -> void:
    draw_arc(center, radius * 0.58, 0.1, PI - 0.1, 24, Color(accent, alpha * 0.62), 1.2)
    for index in range(7):
        var angle := lerpf(PI * 0.12, PI * 0.88, _hash01(index + 29, seed))
        var p := center + Vector2.from_angle(angle) * radius * lerpf(0.35, 0.88, _hash01(index + 39, seed))
        draw_circle(p, 1.2 + float(index % 2), Color(Color.WHITE, alpha * 0.82))

func _hash01(a: int, b: int) -> float:
    var value: float = sin(float(a * 127 + b * 311) * 0.0179) * 43758.5453
    return value - floor(value)
