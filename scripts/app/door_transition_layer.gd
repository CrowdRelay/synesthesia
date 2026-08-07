extends Control

var _accent: Color = Color("72afff")
var _next_accent: Color = Color("72afff")
var _door_mix: float = 0.0
var _portal_mix: float = 0.0
var _phase: float = 0.0
var _reduced_motion: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    visible = false
    set_process(true)

func set_accents(current: Color, next: Color = Color.TRANSPARENT) -> void:
    _accent = current
    _next_accent = current if next.a <= 0.0 else next
    queue_redraw()

func set_reduced_motion(value: bool) -> void:
    _reduced_motion = value

func set_door_mix(value: float) -> void:
    _door_mix = clampf(value, 0.0, 1.0)
    queue_redraw()

func set_portal_mix(value: float) -> void:
    _portal_mix = clampf(value, 0.0, 1.0)
    queue_redraw()

func reset() -> void:
    _door_mix = 0.0
    _portal_mix = 0.0
    visible = false
    queue_redraw()

func _process(delta: float) -> void:
    if not visible:
        return
    _phase = fmod(_phase + delta * (0.8 if _reduced_motion else 2.4), 1000.0)
    if _portal_mix > 0.001:
        queue_redraw()

func _draw() -> void:
    if size.x <= 1.0 or size.y <= 1.0 or (_door_mix <= 0.001 and _portal_mix <= 0.001):
        return
    var w: float = size.x
    var h: float = size.y
    var closed: float = _smooth01(_door_mix)
    var half_width: float = w * 0.5 * closed
    var door_color: Color = Color(0.006, 0.009, 0.016, 0.985)
    draw_rect(Rect2(0.0, 0.0, half_width, h), door_color, true)
    draw_rect(Rect2(w - half_width, 0.0, half_width, h), door_color, true)

    if half_width > 3.0:
        var edge_color: Color = Color(_accent, 0.18 + closed * 0.28)
        draw_line(Vector2(half_width, 0.0), Vector2(half_width, h), edge_color, 1.4)
        draw_line(Vector2(w - half_width, 0.0), Vector2(w - half_width, h), Color(_next_accent, edge_color.a), 1.4)
        for index in range(5):
            var ratio: float = float(index + 1) / 6.0
            var y: float = h * ratio
            var inset: float = 8.0 + 4.0 * sin(_phase + float(index))
            draw_line(Vector2(maxf(0.0, half_width - 28.0), y), Vector2(maxf(0.0, half_width - inset), y), Color(_accent, 0.06 + closed * 0.06), 0.8)
            draw_line(Vector2(minf(w, w - half_width + inset), y), Vector2(minf(w, w - half_width + 28.0), y), Color(_next_accent, 0.06 + closed * 0.06), 0.8)

    if _portal_mix <= 0.001:
        return
    var portal: float = _smooth01(_portal_mix)
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.003, 0.006, 0.014, 0.52 * portal), true)
    var center: Vector2 = size * 0.5
    var max_radius: float = minf(w, h) * 0.46
    var layers: int = 5 if _reduced_motion else 8
    for index in range(layers):
        var phase_offset: float = fmod(float(index) / float(layers) + _phase * 0.08, 1.0)
        var radius: float = lerpf(24.0, max_radius, phase_offset)
        var alpha: float = (1.0 - phase_offset) * 0.16 * portal
        var color: Color = Color(_accent.lerp(_next_accent, phase_offset), alpha)
        draw_arc(center, radius, 0.0, TAU, 40, color, 1.2)
    var slit: float = lerpf(2.0, w * 0.11, portal)
    draw_rect(Rect2(center.x - slit * 0.5, 0.0, slit, h), Color(_accent.lerp(_next_accent, 0.5), 0.055 * portal), true)
    for index in range(9):
        var angle: float = TAU * float(index) / 9.0 + _phase * 0.12
        var inner: Vector2 = center + Vector2.from_angle(angle) * 34.0
        var outer: Vector2 = center + Vector2.from_angle(angle) * max_radius
        draw_line(inner, outer, Color(_accent.lerp(_next_accent, float(index) / 8.0), 0.035 * portal), 0.8)

func _smooth01(value: float) -> float:
    var x: float = clampf(value, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)
