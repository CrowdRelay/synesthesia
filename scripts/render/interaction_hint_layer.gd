extends Control

var _interaction: String = "paint"
var _accent: Color = Color("72afff")
var _strength: float = 0.0
var _target_strength: float = 0.0
var _phase: float = 0.0
var _reduced_motion: bool = false
var _runtime_scale: float = 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(false)

func configure(interaction: String, accent: Color) -> void:
    _interaction = interaction
    _accent = accent
    _strength = 0.0
    _target_strength = 0.0
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
    var center := Vector2(size.x * 0.5, size.y * 0.56)
    var pulse: float = 0.5 if _reduced_motion else 0.5 + sin(_phase * 2.0) * 0.5
    var alpha: float = _strength * (0.10 + pulse * 0.08)
    var radius: float = minf(size.x, size.y) * (0.075 + pulse * 0.012)
    draw_arc(center, radius, 0.0, TAU, 40, Color(_accent, alpha), 2.0)
    match _interaction:
        "toast_table", "grow_tree", "western_duel", "intimate_bedroom":
            draw_circle(center, radius * 0.22, Color(_accent, alpha * 0.72))
        "raise_phoenix", "rise_atrium":
            draw_line(center + Vector2(0.0, radius * 0.55), center - Vector2(0.0, radius * 0.55), Color(_accent, alpha), 2.0)
        _:
            draw_line(center - Vector2(radius * 0.48, 0.0), center + Vector2(radius * 0.48, 0.0), Color(_accent, alpha), 2.0)
