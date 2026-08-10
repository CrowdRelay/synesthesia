extends Control

const SIGNAL_GLITCH_TEXTURE := preload("res://assets/v2/fx/signal-glitch.png")
const SCRATCH_TEXTURE := preload("res://assets/v2/fx/surface-scratches.png")

var _accent: Color = Color("72afff")
var _secondary: Color = Color("ff6680")
var _style: String = "uncertainty"
var _progress: float = 0.0
var _cinematic: float = 0.0
var _door_open: float = 0.0
var _reduced_motion: bool = false
var _phase: float = 0.0
var _runtime_scale: float = 1.0
var _redraw_accumulator: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func configure(style: String, accent: Color, secondary: Color) -> void:
    _style = style
    _accent = accent
    _secondary = secondary
    queue_redraw()

func set_progress(value: float) -> void:
    _progress = clampf(value, 0.0, 1.0)
    if _reduced_motion:
        queue_redraw()

func set_cinematic(value: float) -> void:
    _cinematic = clampf(value, 0.0, 1.0)
    if _reduced_motion:
        queue_redraw()

func set_door_open_amount(value: float) -> void:
    _door_open = clampf(value, 0.0, 1.0)
    if _reduced_motion:
        queue_redraw()

func set_reduced_motion(value: bool) -> void:
    _reduced_motion = value
    set_process(not _reduced_motion)
    queue_redraw()

func set_runtime_scale(value: float) -> void:
    _runtime_scale = clampf(value, 0.55, 1.0)

func _process(delta: float) -> void:
    var speed: float = 0.16 if _reduced_motion else 0.36
    _phase = fmod(_phase + delta * speed, 1000.0)
    _redraw_accumulator += delta
    var hz: float = 8.0 if _reduced_motion else (14.0 + 8.0 * _cinematic) * _runtime_scale
    if _redraw_accumulator >= 1.0 / maxf(hz, 4.0):
        _redraw_accumulator = 0.0
        queue_redraw()

func _draw() -> void:
    if size.x <= 1.0 or size.y <= 1.0:
        return
    _draw_material_overlays()
    _draw_chamber_shell()
    _draw_consciousness_marks()
    if _door_open > 0.001:
        _draw_open_doorway()

func _draw_material_overlays() -> void:
    var full := Rect2(Vector2.ZERO, size)
    draw_texture_rect(SCRATCH_TEXTURE, full, true, Color(0.76, 0.84, 0.91, 0.055 + _cinematic * 0.020))
    if _style == "technophobia":
        var glitch_alpha := 0.055 + (1.0 - _progress) * 0.085
        draw_texture_rect(SIGNAL_GLITCH_TEXTURE, full, true, Color(1.0, 1.0, 1.0, glitch_alpha))

func _draw_chamber_shell() -> void:
    # V2: the authored room art is the hero. The runtime shell is a restrained
    # signal-system frame, not a comic/board-game chamber painted over it.
    var w := size.x
    var h := size.y
    var edge_alpha := 0.13 + _progress * 0.05 + _cinematic * 0.06
    var border := Color(_accent, edge_alpha)
    var inset := clampf(minf(w, h) * 0.018, 8.0, 20.0)
    draw_rect(Rect2(Vector2(inset, inset), Vector2(w - inset * 2.0, h - inset * 2.0)), border, false, 1.0)

    var tick := clampf(minf(w, h) * 0.045, 14.0, 32.0)
    var c := Color(_secondary, edge_alpha * 0.82)
    draw_line(Vector2(inset, inset), Vector2(inset + tick, inset), c, 1.2)
    draw_line(Vector2(inset, inset), Vector2(inset, inset + tick), c, 1.2)
    draw_line(Vector2(w - inset, inset), Vector2(w - inset - tick, inset), c, 1.2)
    draw_line(Vector2(w - inset, inset), Vector2(w - inset, inset + tick), c, 1.2)
    draw_line(Vector2(inset, h - inset), Vector2(inset + tick, h - inset), c, 1.2)
    draw_line(Vector2(w - inset, h - inset), Vector2(w - inset - tick, h - inset), c, 1.2)

    # A very soft floor lattice binds all rooms to the accepted Signal board.
    var floor_y := h * 0.83
    for index in range(4):
        var ratio := float(index + 1) / 4.0
        var x := lerpf(w * 0.16, w * 0.84, ratio)
        draw_line(Vector2(x, floor_y), Vector2(w * 0.5 + (x - w * 0.5) * 1.8, h), Color(_accent, 0.022 + _cinematic * 0.018), 0.8)

func _draw_consciousness_marks() -> void:
    var w: float = size.x
    var h: float = size.y
    var pulse: float = 0.5 + 0.5 * sin(_phase * TAU)
    var alpha: float = (0.025 + _progress * 0.025 + _cinematic * 0.045) * (0.82 + pulse * 0.18)
    var line_color: Color = Color(_secondary, alpha)

    match _style:
        "technophobia":
            for index in range(4):
                var y: float = h * (0.16 + float(index) * 0.17)
                draw_line(Vector2(7.0, y), Vector2(28.0 + float(index % 2) * 7.0, y), line_color, 1.0)
                draw_line(Vector2(w - 7.0, y + 18.0), Vector2(w - 31.0, y + 18.0), line_color, 1.0)
        "uncertainty", "waves":
            for index in range(3):
                var center: Vector2 = Vector2(18.0, h * (0.28 + float(index) * 0.21))
                draw_arc(center, 24.0 + float(index) * 6.0, -PI * 0.42, PI * 0.42, 18, line_color, 1.0)
                draw_arc(Vector2(w - 18.0, center.y), 24.0 + float(index) * 6.0, PI * 0.58, PI * 1.42, 18, line_color, 1.0)
        "ashes", "rise":
            for index in range(3):
                var y: float = h - 38.0 - float(index) * 8.0
                draw_line(Vector2(w * 0.5, y), Vector2(w * (0.36 - float(index) * 0.025), h), line_color, 1.0)
                draw_line(Vector2(w * 0.5, y), Vector2(w * (0.64 + float(index) * 0.025), h), line_color, 1.0)
        _:
            var left: PackedVector2Array = PackedVector2Array()
            var right: PackedVector2Array = PackedVector2Array()
            for index in range(6):
                var y: float = h * (0.18 + float(index) * 0.11)
                var wobble: float = sin(_phase * 3.0 + float(index)) * (1.0 + _cinematic * 1.5)
                left.append(Vector2(8.0 + float(index % 2) * 7.0 + wobble, y))
                right.append(Vector2(w - 8.0 - float(index % 2) * 7.0 - wobble, y))
            draw_polyline(left, line_color, 0.9, true)
            draw_polyline(right, line_color, 0.9, true)

func _draw_open_doorway() -> void:
    var w: float = size.x
    var h: float = size.y
    var reveal: float = _smooth01(_door_open)
    var door_w: float = w * 0.58
    var door_h: float = h * 0.64
    var left: float = (w - door_w) * 0.5
    var top: float = h * 0.15
    var right: float = left + door_w
    var bottom: float = minf(h - 40.0, top + door_h)
    var glow: float = 0.10 + 0.16 * reveal + 0.035 * sin(_phase * 5.0)
    var c: Color = Color(_accent, glow)
    draw_line(Vector2(left, bottom), Vector2(left, top + 42.0), c, 1.6)
    draw_arc(Vector2(w * 0.5, top + 42.0), door_w * 0.5, PI, TAU, 28, c, 1.6)
    draw_line(Vector2(right, top + 42.0), Vector2(right, bottom), c, 1.6)
    draw_line(Vector2(left, bottom), Vector2(right, bottom), Color(_accent, glow * 0.72), 1.1)
    var threshold: float = lerpf(0.0, door_w * 0.42, reveal)
    draw_line(Vector2(w * 0.5 - threshold, bottom + 2.0), Vector2(w * 0.5 + threshold, bottom + 2.0), Color(_secondary, glow * 0.70), 1.4)

func _smooth01(value: float) -> float:
    var x: float = clampf(value, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)
