extends Control

const MAX_EFFECTS: int = 14

var accent: Color = Color("72afff")
var secondary: Color = Color("ff6680")
var reduced_motion: bool = false
var calm_mode: bool = true
var _effects: Array[Dictionary] = []
var _accumulator: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func configure(accent_color: Color, secondary_color: Color) -> void:
    accent = accent_color
    secondary = secondary_color

func set_sensory(calm: bool, reduced: bool) -> void:
    calm_mode = calm
    reduced_motion = reduced

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
    while _effects.size() > MAX_EFFECTS:
        _effects.pop_front()
    queue_redraw()

func clear() -> void:
    _effects.clear()
    queue_redraw()

func _process(delta: float) -> void:
    if _effects.is_empty():
        return
    _accumulator += delta
    var target_hz: float = 18.0 if reduced_motion else 30.0
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
            "phoenix", "seed", "light":
                _draw_rays(center, radius, alpha)
            "wave", "presence", "toast", "mask":
                _draw_ring(center, radius, alpha)
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

func _hash01(a: int, b: int) -> float:
    var value: float = sin(float(a * 127 + b * 311) * 0.0179) * 43758.5453
    return value - floor(value)
