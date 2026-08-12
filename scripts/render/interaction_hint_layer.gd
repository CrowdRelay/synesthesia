extends Control

# Diegetic assist only: normal play stays clean. After inactivity/misses the layer
# reveals the *actual* current interactive objects using the same signal language
# as the rest of VIRYA instead of a generic tutorial cursor.

var _interaction: String = "paint"
var _accent: Color = Color("72afff")
var _strength: float = 0.0
var _target_strength: float = 0.0
var _phase: float = 0.0
var _reduced_motion: bool = false
var _runtime_scale: float = 1.0
var _targets: Array[Dictionary] = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(false)

func configure(interaction: String, accent: Color) -> void:
    _interaction = interaction
    _accent = accent
    _strength = 0.0
    _target_strength = 0.0
    _targets.clear()
    queue_redraw()

func set_targets(value: Array) -> void:
    _targets.clear()
    for raw in value:
        if raw is Dictionary:
            _targets.append(raw as Dictionary)
    if _strength > 0.001:
        queue_redraw()

func set_hint_strength(value: float) -> void:
    _target_strength = clampf(value, 0.0, 1.0)
    if _target_strength > 0.001 or _strength > 0.001:
        set_process(true)
    queue_redraw()

func set_reduced_motion(value: bool) -> void:
    _reduced_motion = value

func set_runtime_scale(value: float) -> void:
    _runtime_scale = clampf(value, 0.55, 1.0)

func _process(delta: float) -> void:
    _strength = move_toward(_strength, _target_strength, delta * 2.8)
    if not _reduced_motion:
        _phase = fmod(_phase + delta * (1.2 * _runtime_scale), TAU)
    queue_redraw()
    if _strength <= 0.001 and _target_strength <= 0.001:
        set_process(false)

func _draw() -> void:
    if _strength <= 0.001 or size.x <= 1.0 or size.y <= 1.0:
        return
    var targets := _targets
    if targets.is_empty():
        targets = [{"point": _fallback_center(), "kind": _interaction, "radius": 0.075}]
    var limit := mini(targets.size(), 4)
    for index in range(limit):
        _draw_target(targets[index], index)

func _draw_target(target: Dictionary, index: int) -> void:
    var point_value: Variant = target.get("point", _fallback_center())
    var point_norm: Vector2 = point_value if point_value is Vector2 else _fallback_center()
    var center := Vector2(point_norm.x * size.x, point_norm.y * size.y)
    var kind := str(target.get("kind", _interaction))
    var radius_norm := clampf(float(target.get("radius", 0.075)), 0.035, 0.20)
    var base_radius := minf(size.x, size.y) * radius_norm
    var pulse: float = 0.5 if _reduced_motion else 0.5 + sin(_phase * 2.0 + float(index) * 1.47) * 0.5
    var portrait_gain: float = 1.16 if size.y > size.x else 1.0
    var alpha: float = clampf(_strength * (0.34 + pulse * 0.22) * portrait_gain, 0.0, 0.82)
    var radius := base_radius * (0.92 + pulse * 0.14) * portrait_gain

    # Thin concentric rings match the approved Signal mockup and never resemble
    # a mobile-game glowing hotspot.
    draw_arc(center, radius, -PI * 0.84, PI * 0.84, 36, Color(_accent, alpha), 1.55)
    draw_arc(center, radius * 0.68, PI * 0.18, PI * 1.82, 28, Color(Color.WHITE, alpha * 0.34), 1.1)
    _draw_gesture_glyph(center, radius, kind, alpha)

func _draw_gesture_glyph(center: Vector2, radius: float, kind: String, alpha: float) -> void:
    match kind:
        "drag_up":
            draw_line(center + Vector2(0.0, radius * 0.40), center - Vector2(0.0, radius * 0.42), Color(_accent, alpha * 0.90), 1.6)
            draw_line(center - Vector2(0.0, radius * 0.42), center + Vector2(-radius * 0.16, -radius * 0.20), Color(_accent, alpha * 0.90), 1.4)
            draw_line(center - Vector2(0.0, radius * 0.42), center + Vector2(radius * 0.16, -radius * 0.20), Color(_accent, alpha * 0.90), 1.4)
        "drag_horizontal", "tune":
            draw_line(center - Vector2(radius * 0.45, 0.0), center + Vector2(radius * 0.45, 0.0), Color(_accent, alpha * 0.88), 1.5)
            draw_circle(center, maxf(2.0, radius * 0.09), Color(Color.WHITE, alpha * 0.70))
        "pull", "drag":
            draw_line(center, center + Vector2(radius * 0.46, radius * 0.28), Color(_accent, alpha * 0.88), 1.5)
            draw_circle(center, maxf(2.0, radius * 0.10), Color(Color.WHITE, alpha * 0.66))
        "hold":
            draw_circle(center, radius * 0.16, Color(_accent, alpha * 0.42))
            draw_arc(center, radius * 0.31, -PI * 0.5, PI * 1.18, 22, Color(_accent, alpha * 0.78), 1.4)
        "swirl":
            draw_arc(center, radius * 0.34, -PI * 0.25, PI * 1.45, 26, Color(_accent, alpha * 0.88), 1.5)
        "target":
            draw_line(center - Vector2(radius * 0.28, 0.0), center + Vector2(radius * 0.28, 0.0), Color(_accent, alpha * 0.55), 1.0)
            draw_line(center - Vector2(0.0, radius * 0.28), center + Vector2(0.0, radius * 0.28), Color(_accent, alpha * 0.55), 1.0)
        _:
            draw_circle(center, maxf(2.0, radius * 0.10), Color(_accent, alpha * 0.62))

func _fallback_center() -> Vector2:
    if _interaction == "grow_tree":
        return Vector2(0.50, 0.74)
    if _interaction == "rise_atrium":
        return Vector2(0.50, 0.20)
    return Vector2(0.50, 0.56)
