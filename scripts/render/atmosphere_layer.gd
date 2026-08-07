extends Control

var style: String = "uncertainty"
var accent: Color = Color("72afff")
var secondary: Color = Color("ff6680")
var progress: float = 0.0
var calm_mode: bool = true
var reduced_motion: bool = false
var particle_count: int = 42
var redraw_hz: float = 24.0
var _particles: Array[Dictionary] = []
var _accumulator: float = 0.0
var _time: float = 0.0
var _runtime_scale: float = 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func configure(room_style: String, accent_color: Color, secondary_color: Color, quality: Dictionary) -> void:
    style = room_style
    accent = accent_color
    secondary = secondary_color
    particle_count = clampi(int(quality.get("particle_count", 42)), 12, 96)
    redraw_hz = clampf(float(quality.get("atmosphere_hz", 24.0)), 8.0, 36.0)
    _particles.clear()
    for index in range(particle_count):
        _particles.append({
            "x": _hash01(index, 11),
            "y": _hash01(index, 23),
            "speed": lerpf(0.015, 0.085, _hash01(index, 37)),
            "size": lerpf(0.8, 3.6, _hash01(index, 41)),
            "phase": _hash01(index, 53) * TAU,
        })
    queue_redraw()

func set_progress(value: float) -> void:
    progress = clampf(value, 0.0, 1.0)

func set_sensory(calm: bool, reduced: bool) -> void:
    calm_mode = calm
    reduced_motion = reduced

func set_runtime_scale(value: float) -> void:
    _runtime_scale = clampf(value, 0.55, 1.0)

func _process(delta: float) -> void:
    _accumulator += delta
    var target_hz: float = 8.0 if reduced_motion else maxf(8.0, redraw_hz * _runtime_scale)
    if _accumulator < 1.0 / target_hz:
        return
    _time += _accumulator * (0.26 if calm_mode else 0.48)
    _accumulator = 0.0
    queue_redraw()

func _draw() -> void:
    if size.x <= 1.0 or size.y <= 1.0:
        return
    var visible_ratio: float = 0.20 + progress * 0.80
    var active_count: int = clampi(int(round(float(_particles.size()) * _runtime_scale)), 8, _particles.size())
    for index in range(active_count):
        var particle: Dictionary = _particles[index]
        var x: float = float(particle.get("x", 0.5))
        var y: float = fmod(float(particle.get("y", 0.5)) + _time * float(particle.get("speed", 0.03)), 1.0)
        var phase: float = float(particle.get("phase", 0.0))
        var drift: float = sin(_time * 1.7 + phase) * 0.018
        var point: Vector2 = Vector2((x + drift) * size.x, y * size.y)
        var radius: float = float(particle.get("size", 1.5))
        var alpha: float = (0.035 + 0.10 * visible_ratio) * (0.55 + 0.45 * sin(_time * 2.0 + phase))
        match style:
            "ashes":
                draw_circle(point, radius * 0.75, Color(accent, alpha * 1.35))
            "party":
                var confetti_color: Color = accent if index % 2 == 0 else secondary
                draw_rect(Rect2(point, Vector2(radius * 1.8, radius * 0.65)), Color(confetti_color, alpha * 1.25), true)
            "uncertainty", "waves":
                draw_line(point - Vector2(radius * 4.0, 0.0), point + Vector2(radius * 4.0, 0.0), Color(accent, alpha * 0.70), maxf(1.0, radius * 0.45))
            "technophobia":
                draw_rect(Rect2(point, Vector2(radius * 4.0, maxf(1.0, radius * 0.55))), Color(secondary, alpha), true)
            "seed":
                draw_line(point, point + Vector2(sin(phase) * radius * 2.0, -radius * 4.0), Color(accent, alpha), maxf(1.0, radius * 0.35))
            "invaluable":
                draw_line(point - Vector2(radius * 2.0, radius * 2.0), point + Vector2(radius * 2.0, radius * 2.0), Color(accent, alpha), maxf(1.0, radius * 0.30))
            _:
                draw_circle(point, radius * 0.55, Color(accent, alpha))

func _hash01(a: int, b: int) -> float:
    var value: float = sin(float(a * 127 + b * 311) * 0.0179) * 43758.5453
    return value - floor(value)
