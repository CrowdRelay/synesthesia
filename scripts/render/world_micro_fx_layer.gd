extends Control

var style: String = "uncertainty"
var accent: Color = Color("71dcff")
var secondary: Color = Color("e73535")
var progress: float = 0.0
var pointer: Vector2 = Vector2(0.5, 0.5)
var reduced_motion: bool = false
var cinematic: float = 0.0
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
    queue_redraw()

func set_progress(value: float) -> void:
    progress = clampf(value, 0.0, 1.0)

func set_pointer(value: Vector2) -> void:
    pointer = value

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value

func set_cinematic(value: float) -> void:
    cinematic = clampf(value, 0.0, 1.0)

func _process(delta: float) -> void:
    if reduced_motion:
        return
    _time = fmod(_time + delta, 10000.0)
    _accum += delta
    if _accum >= 1.0 / 24.0:
        _accum = 0.0
        queue_redraw()

func _draw() -> void:
    if size.x <= 2.0 or size.y <= 2.0:
        return
    var p := pointer * size
    var pulse := 0.5 + 0.5 * sin(_time * 2.1)
    var alpha := 0.055 + progress * 0.035 + cinematic * 0.055
    # Signal rings are shared DNA, but each room gets a different physical motif.
    draw_arc(p, 18.0 + pulse * 7.0, -2.4, 2.25, 28, Color(accent, alpha * 1.7), 1.0)
    match style:
        "technophobia": _draw_tech(alpha)
        "unmasked": _draw_mask(alpha)
        "invaluable": _draw_glass(alpha)
        "seed": _draw_seed(alpha)
        "party": _draw_party(alpha)
        "ashes": _draw_ashes(alpha)
        "calling": _draw_calling(alpha)
        "waves": _draw_waves(alpha)
        "hybrid": _draw_hybrid(alpha)
        "rise": _draw_rise(alpha)
        _: _draw_uncertainty(alpha)

func _draw_tech(alpha: float) -> void:
    for i in range(6):
        var y := size.y * (0.16 + float(i) * 0.11)
        var jitter := sin(_time * 7.0 + float(i) * 1.7) * size.x * 0.006
        draw_line(Vector2(size.x * 0.08 + jitter, y), Vector2(size.x * 0.92 + jitter, y), Color(secondary, alpha * (0.32 + 0.08 * (i % 2))), 1.0)

func _draw_mask(alpha: float) -> void:
    var c := Vector2(size.x * 0.5, size.y * 0.43)
    for i in range(3):
        var r := 44.0 + float(i) * 22.0 + sin(_time * 0.9 + i) * 3.0
        draw_arc(c, r, -2.8, 2.8, 44, Color(secondary, alpha * (0.70 - i * 0.15)), 1.0)

func _draw_glass(alpha: float) -> void:
    var c := Vector2(size.x * 0.5, size.y * 0.52)
    for i in range(7):
        var a := float(i) / 7.0 * TAU + sin(_time * 0.35 + i) * 0.03
        var end := c + Vector2(cos(a), sin(a)) * minf(size.x, size.y) * (0.18 + 0.03 * (i % 3))
        draw_line(c, end, Color(accent if i % 2 == 0 else secondary, alpha * 0.68), 1.0)

func _draw_seed(alpha: float) -> void:
    var base := Vector2(size.x * 0.5, size.y * 0.76)
    var top := Vector2(size.x * 0.5 + sin(_time * 0.55) * 6.0, size.y * (0.56 - progress * 0.22))
    draw_line(base, top, Color(secondary, alpha * 1.7), 1.4)
    draw_circle(base, 4.0 + sin(_time * 2.4) * 1.2, Color(secondary, alpha * 2.2))

func _draw_party(alpha: float) -> void:
    for i in range(8):
        var x := size.x * (0.12 + 0.105 * i)
        var y := size.y * (0.70 - fmod(_time * (0.010 + i * 0.0018) + i * 0.12, 0.55))
        draw_circle(Vector2(x, y), 2.0 + float(i % 3), Color(accent if i % 2 == 0 else secondary, alpha * 0.85))

func _draw_ashes(alpha: float) -> void:
    for i in range(14):
        var a := _time * 0.22 + float(i) * 0.53
        var radius := 26.0 + float(i % 5) * 18.0
        var c := Vector2(size.x * 0.5, size.y * 0.55) + Vector2(cos(a), sin(a) * 0.55) * radius
        draw_circle(c, 1.2 + float(i % 3) * 0.55, Color(secondary, alpha * 1.1))

func _draw_calling(alpha: float) -> void:
    var y := size.y * 0.62
    var width := size.x * (0.22 + progress * 0.18)
    draw_line(Vector2(size.x * 0.5 - width, y), Vector2(size.x * 0.5 + width, y), Color(secondary, alpha * 0.9), 1.0)

func _draw_waves(alpha: float) -> void:
    var mid := size.y * 0.58
    var points := PackedVector2Array()
    for i in range(33):
        var x := size.x * float(i) / 32.0
        var y := mid + sin(float(i) * 0.72 + _time * 1.25) * (4.0 + progress * 6.0)
        points.append(Vector2(x, y))
    draw_polyline(points, Color(accent, alpha * 0.78), 1.0)

func _draw_hybrid(alpha: float) -> void:
    var c := Vector2(size.x * 0.5, size.y * 0.52)
    draw_arc(c, 54.0, _time * 0.20, _time * 0.20 + 4.7, 48, Color(secondary, alpha), 1.1)
    draw_line(c - Vector2(11, 0), c + Vector2(11, 0), Color(accent, alpha), 1.0)
    draw_line(c - Vector2(0, 11), c + Vector2(0, 11), Color(accent, alpha), 1.0)

func _draw_rise(alpha: float) -> void:
    var x := size.x * 0.5
    var y0 := size.y * 0.72
    var y1 := size.y * (0.28 - cinematic * 0.05)
    draw_line(Vector2(x, y0), Vector2(x, y1), Color(Color.WHITE, alpha * 0.80), 1.2)
    draw_circle(Vector2(x, y1), 3.0 + 3.0 * sin(_time * 1.4), Color(accent, alpha))

func _draw_uncertainty(alpha: float) -> void:
    for i in range(4):
        var y := size.y * (0.28 + 0.13 * i)
        var shift := sin(_time * (0.55 + i * 0.11)) * size.x * 0.014
        draw_line(Vector2(size.x * 0.15 + shift, y), Vector2(size.x * 0.85 - shift, y), Color(accent, alpha * 0.48), 1.0)
