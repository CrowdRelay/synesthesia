extends Control
const SIGNAL_GLITCH_TEXTURE := preload("res://assets/v2/fx/signal-glitch.png")
const SCRATCH_TEXTURE := preload("res://assets/v2/fx/surface-scratches.png")
const WARD_VOID := Color("070908")
const WARD_WALL := Color("b9b9aa")
const WARD_OIL := Color("31453f")
const WARD_LINE := Color("27322f")
const WARD_GLASS := Color("93c6c0")
const WARD_PAPER := Color("d8d5c7")
const WARD_RUST := Color("805642")
const WARD_RED := Color("8d3f43")
var _accent: Color = Color("84b4ac")
var _secondary: Color = Color("93c6c0")
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
    visibility_changed.connect(_sync_processing)
    _sync_processing()

func configure(style: String, accent: Color, secondary: Color) -> void:
    _style = style
    _accent = _clinical_accent(style, accent)
    _secondary = _clinical_secondary(style, secondary)
    queue_redraw()

func set_progress(value: float) -> void:
    var next: float = clampf(value, 0.0, 1.0)
    if is_equal_approx(next, _progress): return
    _progress = next
    if _reduced_motion: queue_redraw()

func set_cinematic(value: float) -> void:
    var next: float = clampf(value, 0.0, 1.0)
    if is_equal_approx(next, _cinematic): return
    _cinematic = next
    if _reduced_motion: queue_redraw()

func set_door_open_amount(value: float) -> void:
    var next: float = clampf(value, 0.0, 1.0)
    if is_equal_approx(next, _door_open): return
    _door_open = next
    if _reduced_motion: queue_redraw()

func set_reduced_motion(value: bool) -> void:
    if _reduced_motion == value: return
    _reduced_motion = value
    _sync_processing()
    queue_redraw()

func _sync_processing() -> void: set_process(is_visible_in_tree() and not _reduced_motion)
func set_runtime_scale(value: float) -> void: _runtime_scale = clampf(value, 0.55, 1.0)

func _process(delta: float) -> void:
    _phase = fmod(_phase + delta * (0.10 if _reduced_motion else 0.24), 1000.0)
    _redraw_accumulator += delta
    var hz: float = 7.0 if _reduced_motion else (12.0 + 7.0 * _cinematic) * _runtime_scale
    if _redraw_accumulator >= 1.0 / maxf(hz, 4.0):
        _redraw_accumulator = 0.0
        queue_redraw()

func _draw() -> void:
    if size.x <= 1.0 or size.y <= 1.0: return
    _draw_material_wash()
    _draw_ward_shell()
    _draw_room_signature()
    _draw_document_marks()
    if _door_open > 0.001: _draw_open_doorway()

func _draw_material_wash() -> void:
    var full := Rect2(Vector2.ZERO, size)
    var reveal: float = 0.28 + _progress * 0.08 + _cinematic * 0.05
    draw_rect(full, Color(WARD_VOID, 0.18), true)
    draw_rect(full, Color(WARD_OIL, reveal), true)
    draw_rect(Rect2(Vector2(0.0, size.y * 0.53), Vector2(size.x, size.y * 0.47)), Color(0.02, 0.035, 0.032, 0.24), true)
    draw_texture_rect(SCRATCH_TEXTURE, full, true, Color(0.80, 0.83, 0.78, 0.075 + _cinematic * 0.018))
    if _style == "technophobia":
        var glitch_alpha := 0.018 + (1.0 - _progress) * 0.055
        draw_texture_rect(SIGNAL_GLITCH_TEXTURE, full, true, Color(0.78, 0.90, 0.86, glitch_alpha))

func _draw_ward_shell() -> void:
    var w := size.x
    var h := size.y
    var vanish := Vector2(w * 0.5, h * 0.42)
    var line := Color(WARD_LINE, 0.60)
    var wall_line := Color(WARD_WALL, 0.16)
    var floor_line := Color(_accent, 0.10 + _cinematic * 0.04)
    draw_rect(Rect2(Vector2.ZERO, Vector2(w, h * 0.53)), Color(WARD_WALL, 0.045), true)
    draw_rect(Rect2(Vector2(0.0, h * 0.51), Vector2(w, h * 0.035)), Color(WARD_OIL, 0.22), true)
    draw_line(Vector2(0.0, h * 0.545), Vector2(w, h * 0.545), line, 1.4)
    draw_line(Vector2(0.0, h * 0.835), Vector2(w, h * 0.835), Color(WARD_LINE, 0.72), 2.0)
    for side in [-1.0, 1.0]:
        var bottom := Vector2(w * (0.05 if side < 0.0 else 0.95), h)
        _stroke(vanish, bottom, floor_line, 1.0, int(11 + side * 3.0))
    for index in range(4):
        var ratio := float(index + 1) / 5.0
        var y := lerpf(h * 0.84, h, ratio)
        draw_line(Vector2(w * 0.08, y), Vector2(w * 0.92, y), Color(_accent, 0.035), 0.9)
    var breath := 0.5 + 0.5 * sin(_phase * TAU * 0.37)
    var lamp_w := w * 0.28
    var lamp_rect := Rect2(Vector2(w * 0.5 - lamp_w * 0.5, h * 0.055), Vector2(lamp_w, maxf(5.0, h * 0.010)))
    draw_rect(lamp_rect, Color(WARD_PAPER, 0.12 + breath * 0.025 + _cinematic * 0.02), true)
    draw_rect(lamp_rect.grow(2.0), Color(WARD_GLASS, 0.06), false, 1.0)
    var rail_y := h * 0.62
    draw_line(Vector2(w * 0.05, rail_y), Vector2(w * 0.95, rail_y), Color(WARD_WALL, 0.18), 3.2)
    draw_line(Vector2(w * 0.05, rail_y + 3.5), Vector2(w * 0.95, rail_y + 3.5), Color(WARD_LINE, 0.48), 1.0)
    draw_line(Vector2(w * 0.08, h * 0.10), Vector2(w * 0.08, h * 0.83), wall_line, 1.0)
    draw_line(Vector2(w * 0.92, h * 0.10), Vector2(w * 0.92, h * 0.83), wall_line, 1.0)

func _draw_room_signature() -> void:
    match _style:
        "uncertainty": _draw_observation_room()
        "party": _draw_activity_room()
        "unmasked": _draw_art_therapy_room()
        "calling": _draw_group_room()
        "seed": _draw_therapy_garden()
        "hybrid": _draw_diagnostic_corridor()
        "technophobia": _draw_observation_control()
        "invaluable": _draw_deposit_room()
        "ashes": _draw_charcoal_studio()
        "waves": _draw_shared_room()
        "rise": _draw_exit_stairwell()
        _: _draw_observation_room()

func _draw_observation_room() -> void:
    var w := size.x
    var h := size.y
    var glass := Rect2(Vector2(w * 0.19, h * 0.21), Vector2(w * 0.62, h * 0.22))
    draw_rect(glass, Color(WARD_GLASS, 0.055), true)
    draw_rect(glass, Color(WARD_GLASS, 0.22), false, 1.3)
    draw_line(glass.position + Vector2(0.0, glass.size.y * 0.5), Vector2(glass.end.x, glass.position.y + glass.size.y * 0.5), Color(WARD_LINE, 0.35), 1.0)
    var horizon := glass.position.y + glass.size.y * (0.46 + sin(_phase * 0.44) * 0.015)
    _stroke(Vector2(glass.position.x + 8.0, horizon), Vector2(glass.end.x - 8.0, horizon), Color(_accent, 0.32), 1.5, 7)
    _draw_chair(Vector2(w * 0.34, h * 0.73), w * 0.11, h * 0.10, 2)
    _draw_clipboard(Vector2(w * 0.65, h * 0.67), w * 0.12, h * 0.12, -0.05)

func _draw_activity_room() -> void:
    var w := size.x
    var h := size.y
    _draw_table(Vector2(w * 0.50, h * 0.68), w * 0.25, h * 0.08)
    _draw_chair(Vector2(w * 0.27, h * 0.72), w * 0.095, h * 0.09, 3)
    _draw_chair(Vector2(w * 0.73, h * 0.72), w * 0.095, h * 0.09, 4)
    for index in range(6):
        var x := w * (0.20 + float(index) * 0.12)
        var y := h * (0.20 + float(index % 2) * 0.035)
        var r := clampf(w * (0.027 + float(index % 3) * 0.004), 8.0, 18.0)
        var c := _accent.lerp(WARD_PAPER, 0.30 + float(index % 2) * 0.24)
        draw_circle(Vector2(x, y), r, Color(c, 0.10), true)
        _wobbly_circle(Vector2(x, y), r, Color(c, 0.38), 1.2, 30, index + 9)
        _stroke(Vector2(x, y + r), Vector2(x + sin(float(index)) * 8.0, h * 0.35), Color(WARD_LINE, 0.28), 0.9, index + 31)
    for index in range(7):
        var p := Vector2(w * (0.22 + float(index) * 0.085), h * (0.55 + float(index % 3) * 0.025))
        draw_circle(p, 2.0 + float(index % 2), Color(_secondary, 0.26))

func _draw_art_therapy_room() -> void:
    var w := size.x
    var h := size.y
    var wall := Rect2(Vector2(w * 0.17, h * 0.18), Vector2(w * 0.66, h * 0.38))
    draw_rect(wall, Color(WARD_PAPER, 0.035), true)
    for index in range(5):
        var cx := w * (0.25 + float(index) * 0.125)
        var cy := h * (0.30 + float(index % 2) * 0.06)
        var rx := w * 0.045
        var ry := h * 0.050
        _wobbly_oval(Vector2(cx, cy), Vector2(rx, ry), Color(WARD_PAPER, 0.48), 1.5, index + 20)
        draw_line(Vector2(cx - rx * 0.72, cy - ry * 1.08), Vector2(cx + rx * 0.72, cy - ry * 1.08), Color(WARD_LINE, 0.42), 3.0)
        draw_line(Vector2(cx - rx * 0.72, cy + ry * 1.08), Vector2(cx + rx * 0.72, cy + ry * 1.08), Color(WARD_LINE, 0.24), 2.0)
    _draw_clipboard(Vector2(w * 0.69, h * 0.70), w * 0.12, h * 0.14, 0.03)

func _draw_group_room() -> void:
    var w := size.x
    var h := size.y
    _draw_table(Vector2(w * 0.50, h * 0.64), w * 0.29, h * 0.075)
    for index in range(5):
        var angle := PI * (0.15 + float(index) * 0.17)
        var p := Vector2(w * 0.5 + cos(angle) * w * 0.31, h * 0.64 + sin(angle) * h * 0.15)
        _draw_chair(p, w * 0.078, h * 0.072, index + 40)
    var cup := Vector2(w * 0.50, h * 0.60)
    _wobbly_circle(cup, minf(w, h) * 0.021, Color(WARD_RED, 0.62), 1.6, 24, 5)
    for ring in range(3): draw_arc(cup, 18.0 + float(ring) * 13.0, 0.0, TAU, 48, Color(WARD_RED, 0.08 - float(ring) * 0.012), 1.0)

func _draw_therapy_garden() -> void:
    var w := size.x
    var h := size.y
    for shelf in range(2):
        var y := h * (0.43 + float(shelf) * 0.13)
        draw_line(Vector2(w * 0.16, y), Vector2(w * 0.84, y), Color(WARD_LINE, 0.52), 2.0)
        for index in range(4):
            var x := w * (0.24 + float(index) * 0.17)
            var pot := Rect2(Vector2(x - w * 0.033, y - h * 0.055), Vector2(w * 0.066, h * 0.050))
            draw_rect(pot, Color(WARD_RUST, 0.15), true)
            draw_rect(pot, Color(WARD_RUST, 0.42), false, 1.0)
    var root := Vector2(w * 0.50, h * 0.82)
    for branch in range(7):
        var side := -1.0 if branch % 2 == 0 else 1.0
        var end := Vector2(w * (0.50 + side * (0.08 + float(branch) * 0.025)), h * (0.69 - float(branch) * 0.045))
        _stroke(root, end, Color(_accent, 0.30 + _progress * 0.20), 1.4 + float(branch % 3) * 0.4, branch + 70)
    draw_circle(root, clampf(w * 0.018, 6.0, 13.0), Color(_accent, 0.28 + _progress * 0.22))

func _draw_diagnostic_corridor() -> void:
    var w := size.x
    var h := size.y
    var vp := Vector2(w * 0.5, h * 0.35)
    for x in [0.12, 0.25, 0.75, 0.88]: draw_line(Vector2(w * x, h * 0.84), vp, Color(WARD_LINE, 0.34), 1.1)
    draw_line(Vector2(w * 0.14, h * 0.52), Vector2(w * 0.86, h * 0.52), Color(WARD_WALL, 0.22), 1.0)
    var fixation := Vector2(w * 0.50, h * 0.39)
    draw_arc(fixation, clampf(w * 0.04, 10.0, 24.0), 0.0, TAU, 32, Color(_accent, 0.42), 1.4)
    draw_line(fixation - Vector2(18.0, 0.0), fixation + Vector2(18.0, 0.0), Color(_accent, 0.32), 1.0)
    draw_line(fixation - Vector2(0.0, 18.0), fixation + Vector2(0.0, 18.0), Color(_accent, 0.32), 1.0)
    _draw_silhouette(Vector2(w * 0.27, h * 0.67), 0.78)
    _draw_silhouette(Vector2(w * 0.73, h * 0.67), 0.78)

func _draw_observation_control() -> void:
    var w := size.x
    var h := size.y
    var panel := Rect2(Vector2(w * 0.14, h * 0.22), Vector2(w * 0.72, h * 0.34))
    draw_rect(panel, Color(WARD_VOID, 0.26), true)
    draw_rect(panel, Color(WARD_LINE, 0.58), false, 1.5)
    for row in range(2):
        for col in range(3):
            var r := Rect2(Vector2(w * (0.19 + float(col) * 0.21), h * (0.27 + float(row) * 0.14)), Vector2(w * 0.15, h * 0.09))
            draw_rect(r, Color(WARD_GLASS, 0.055), true)
            draw_rect(r, Color(_accent, 0.28), false, 1.0)
            var scan := r.position.y + fmod(_phase * 18.0 + float(row * 5 + col) * 11.0, maxf(r.size.y, 1.0))
            draw_line(Vector2(r.position.x + 4.0, scan), Vector2(r.end.x - 4.0, scan), Color(_accent, 0.13), 1.0)
    var cable_start := Vector2(w * 0.73, h * 0.57)
    for cable in range(3):
        var end := Vector2(w * (0.27 + float(cable) * 0.18), h * 0.78)
        _stroke(cable_start + Vector2(float(cable) * 6.0, 0.0), end, Color(WARD_LINE, 0.60), 2.0, cable + 90)

func _draw_deposit_room() -> void:
    var w := size.x
    var h := size.y
    var lockers := Rect2(Vector2(w * 0.13, h * 0.18), Vector2(w * 0.34, h * 0.48))
    draw_rect(lockers, Color(WARD_OIL, 0.20), true)
    for row in range(4):
        for col in range(2):
            var r := Rect2(Vector2(lockers.position.x + lockers.size.x * float(col) * 0.5, lockers.position.y + lockers.size.y * float(row) * 0.25), Vector2(lockers.size.x * 0.5, lockers.size.y * 0.25))
            draw_rect(r, Color(WARD_LINE, 0.44), false, 1.0)
            draw_circle(Vector2(r.end.x - 8.0, r.position.y + r.size.y * 0.5), 1.8, Color(WARD_PAPER, 0.36))
    var mirror := Rect2(Vector2(w * 0.58, h * 0.22), Vector2(w * 0.24, h * 0.39))
    draw_rect(mirror, Color(WARD_GLASS, 0.045), true)
    draw_rect(mirror, Color(WARD_PAPER, 0.30), false, 1.2)
    var center := mirror.get_center()
    for shard in range(8):
        var angle := float(shard) * TAU / 8.0 + 0.12
        draw_line(center, center + Vector2.from_angle(angle) * minf(mirror.size.x, mirror.size.y) * (0.20 + float(shard % 3) * 0.07), Color(WARD_GLASS, 0.28 + _progress * 0.18), 1.0)

func _draw_charcoal_studio() -> void:
    var w := size.x
    var h := size.y
    var easel_top := Vector2(w * 0.44, h * 0.24)
    var easel_bottom := Vector2(w * 0.50, h * 0.72)
    _stroke(easel_top, Vector2(w * 0.35, h * 0.77), Color(WARD_LINE, 0.56), 2.0, 110)
    _stroke(easel_top, Vector2(w * 0.64, h * 0.77), Color(WARD_LINE, 0.56), 2.0, 111)
    _stroke(easel_top, easel_bottom, Color(WARD_LINE, 0.48), 1.6, 112)
    var page := Rect2(Vector2(w * 0.32, h * 0.29), Vector2(w * 0.36, h * 0.30))
    draw_rect(page, Color(WARD_PAPER, 0.055), true)
    draw_rect(page, Color(WARD_PAPER, 0.26), false, 1.0)
    var basin := Vector2(w * 0.50, h * 0.73)
    _wobbly_oval(basin, Vector2(w * 0.15, h * 0.035), Color(WARD_LINE, 0.50), 1.4, 120)
    for ash in range(13):
        var a := float(ash) * 1.77
        var r := 7.0 + float(ash % 4) * 6.0
        var p := basin + Vector2(cos(a) * r * 2.2, -abs(sin(a)) * r * 1.4)
        draw_circle(p, 1.2 + float(ash % 3) * 0.6, Color(WARD_PAPER, 0.12 + _progress * 0.10))

func _draw_shared_room() -> void:
    var w := size.x
    var h := size.y
    _draw_bed(Rect2(Vector2(w * 0.13, h * 0.57), Vector2(w * 0.31, h * 0.16)), 130)
    _draw_bed(Rect2(Vector2(w * 0.56, h * 0.57), Vector2(w * 0.31, h * 0.16)), 131)
    var window := Rect2(Vector2(w * 0.31, h * 0.18), Vector2(w * 0.38, h * 0.25))
    draw_rect(window, Color(WARD_GLASS, 0.055), true)
    draw_rect(window, Color(WARD_GLASS, 0.25), false, 1.2)
    for index in range(7):
        var x := lerpf(window.position.x + 7.0, window.end.x - 7.0, float(index) / 6.0)
        var drift := sin(_phase * 0.9 + float(index)) * 2.0
        draw_line(Vector2(x, window.position.y + 8.0), Vector2(x + drift, window.end.y - 8.0), Color(WARD_GLASS, 0.12), 0.9)
    var left := Vector2(w * 0.32, h * 0.62)
    var right := Vector2(w * 0.68, h * 0.62)
    draw_circle(left, 7.0, Color(_accent, 0.18))
    draw_circle(right, 7.0, Color(_secondary, 0.18))
    draw_line(left, right, Color(_accent.lerp(_secondary, 0.5), 0.15 + _progress * 0.16), 1.2)

func _draw_exit_stairwell() -> void:
    var w := size.x
    var h := size.y
    var door := Rect2(Vector2(w * 0.34, h * 0.17), Vector2(w * 0.32, h * 0.38))
    draw_rect(door, Color(WARD_PAPER, 0.07 + _cinematic * 0.08), true)
    draw_rect(door, Color(WARD_GLASS, 0.34), false, 1.5)
    var light := Rect2(Vector2(door.position.x + door.size.x * 0.20, door.position.y + door.size.y * 0.14), Vector2(door.size.x * 0.60, door.size.y * 0.22))
    draw_rect(light, Color(WARD_PAPER, 0.12 + _progress * 0.10 + _cinematic * 0.18), true)
    for step in range(5):
        var y := h * (0.58 + float(step) * 0.065)
        var half := w * (0.13 + float(step) * 0.045)
        draw_line(Vector2(w * 0.5 - half, y), Vector2(w * 0.5 + half, y), Color(WARD_LINE, 0.50), 2.0)
    draw_line(Vector2(w * 0.24, h * 0.76), Vector2(w * 0.38, h * 0.43), Color(WARD_WALL, 0.42), 2.4)
    draw_line(Vector2(w * 0.76, h * 0.76), Vector2(w * 0.62, h * 0.43), Color(WARD_WALL, 0.42), 2.4)

func _draw_document_marks() -> void:
    var w := size.x
    var h := size.y
    var alpha := 0.13 + _progress * 0.05
    var origin := Vector2(w * 0.10, h * 0.12)
    for index in range(4):
        var y := origin.y + float(index) * 7.0
        var length := w * (0.08 + float((index * 7) % 3) * 0.018)
        _stroke(Vector2(origin.x, y), Vector2(origin.x + length, y), Color(WARD_PAPER, alpha * (1.0 - float(index) * 0.12)), 0.8, index + 150)
    var right := Vector2(w * 0.86, h * 0.76)
    draw_rect(Rect2(right, Vector2(w * 0.045, h * 0.028)), Color(WARD_PAPER, 0.065), true)
    draw_rect(Rect2(right, Vector2(w * 0.045, h * 0.028)), Color(WARD_PAPER, 0.18), false, 0.8)

func _draw_open_doorway() -> void:
    var w := size.x
    var h := size.y
    var reveal := _smooth01(_door_open)
    var door_w := w * 0.48
    var door_h := h * 0.62
    var left := (w - door_w) * 0.5
    var top := h * 0.16
    var rect := Rect2(Vector2(left, top), Vector2(door_w, door_h))
    var light_alpha := 0.025 + reveal * 0.13
    draw_rect(rect, Color(WARD_PAPER, light_alpha), true)
    draw_rect(rect, Color(WARD_GLASS, 0.20 + reveal * 0.10), false, 1.6)
    var window := Rect2(Vector2(rect.position.x + rect.size.x * 0.23, rect.position.y + rect.size.y * 0.16), Vector2(rect.size.x * 0.54, rect.size.y * 0.16))
    draw_rect(window, Color(WARD_GLASS, 0.055 + reveal * 0.06), true)
    draw_rect(window, Color(WARD_GLASS, 0.22), false, 1.0)
    var handle := Vector2(rect.end.x - rect.size.x * 0.14, rect.position.y + rect.size.y * 0.55)
    draw_line(handle - Vector2(7.0, 0.0), handle + Vector2(7.0, 0.0), Color(WARD_PAPER, 0.38), 2.0)
    draw_line(Vector2(rect.position.x, rect.end.y + 3.0), Vector2(rect.end.x, rect.end.y + 3.0), Color(_accent, 0.14 + reveal * 0.12), 1.3)

func _draw_table(center: Vector2, half_w: float, half_h: float) -> void:
    _wobbly_oval(center, Vector2(half_w, half_h), Color(WARD_PAPER, 0.34), 1.5, 170)
    draw_line(center + Vector2(-half_w * 0.52, half_h * 0.62), center + Vector2(-half_w * 0.44, half_h * 2.5), Color(WARD_LINE, 0.48), 2.0)
    draw_line(center + Vector2(half_w * 0.52, half_h * 0.62), center + Vector2(half_w * 0.44, half_h * 2.5), Color(WARD_LINE, 0.48), 2.0)

func _draw_chair(center: Vector2, width: float, height: float, seed: int) -> void:
    var back_top := center - Vector2(width * 0.5, height)
    var back_right := center + Vector2(width * 0.5, -height)
    _stroke(back_top, back_right, Color(WARD_PAPER, 0.28), 1.4, seed)
    _stroke(back_top, center - Vector2(width * 0.42, 0.0), Color(WARD_LINE, 0.48), 1.6, seed + 1)
    _stroke(back_right, center + Vector2(width * 0.42, 0.0), Color(WARD_LINE, 0.48), 1.6, seed + 2)
    _stroke(center - Vector2(width * 0.42, 0.0), center + Vector2(width * 0.42, 0.0), Color(WARD_LINE, 0.52), 1.8, seed + 3)
    _stroke(center - Vector2(width * 0.34, -2.0), center + Vector2(-width * 0.28, height * 0.72), Color(WARD_LINE, 0.40), 1.4, seed + 4)
    _stroke(center + Vector2(width * 0.34, 2.0), center + Vector2(width * 0.28, height * 0.72), Color(WARD_LINE, 0.40), 1.4, seed + 5)

func _draw_clipboard(center: Vector2, width: float, height: float, tilt: float) -> void:
    draw_set_transform(center, tilt, Vector2.ONE)
    var local := Rect2(-Vector2(width, height) * 0.5, Vector2(width, height))
    draw_rect(local, Color(WARD_PAPER, 0.07), true)
    draw_rect(local, Color(WARD_PAPER, 0.30), false, 1.0)
    draw_rect(Rect2(Vector2(-width * 0.18, -height * 0.54), Vector2(width * 0.36, height * 0.09)), Color(WARD_LINE, 0.44), true)
    for index in range(4):
        var y := -height * 0.28 + float(index) * height * 0.15
        draw_line(Vector2(-width * 0.32, y), Vector2(width * (0.24 - float(index % 2) * 0.08), y), Color(WARD_LINE, 0.34), 0.8)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_silhouette(center: Vector2, scale: float) -> void:
    draw_circle(center - Vector2(0.0, 28.0 * scale), 9.0 * scale, Color(WARD_VOID, 0.26))
    var body := PackedVector2Array([
        center + Vector2(-11.0, -17.0) * scale,
        center + Vector2(11.0, -17.0) * scale,
        center + Vector2(15.0, 30.0) * scale,
        center + Vector2(-15.0, 30.0) * scale,
    ])
    draw_colored_polygon(body, Color(WARD_VOID, 0.23))
    draw_polyline(body, Color(WARD_PAPER, 0.12), 1.0, true)

func _draw_bed(rect: Rect2, seed: int) -> void:
    draw_rect(rect, Color(WARD_PAPER, 0.055), true)
    draw_rect(rect, Color(WARD_PAPER, 0.28), false, 1.2)
    var pillow := Rect2(rect.position + Vector2(rect.size.x * 0.06, rect.size.y * 0.12), Vector2(rect.size.x * 0.28, rect.size.y * 0.32))
    draw_rect(pillow, Color(WARD_PAPER, 0.08), true)
    _stroke(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x - 3.0, rect.end.y + rect.size.y * 0.45), Color(WARD_LINE, 0.48), 1.5, seed)
    _stroke(Vector2(rect.end.x, rect.end.y), Vector2(rect.end.x + 3.0, rect.end.y + rect.size.y * 0.45), Color(WARD_LINE, 0.48), 1.5, seed + 1)

func _stroke(a: Vector2, b: Vector2, color: Color, width: float, seed: int) -> void:
    var points := PackedVector2Array()
    var normal := Vector2(-(b - a).y, (b - a).x).normalized()
    for index in range(6):
        var t := float(index) / 5.0
        var jitter := sin(float(seed) * 1.73 + float(index) * 2.19) * 1.25
        points.append(a.lerp(b, t) + normal * jitter)
    draw_polyline(points, color, width, true)

func _wobbly_circle(center: Vector2, radius: float, color: Color, width: float, segments: int, seed: int) -> void:
    var points := PackedVector2Array()
    for index in range(segments + 1):
        var a := float(index) * TAU / float(segments)
        var wobble := 1.0 + sin(a * 3.0 + float(seed)) * 0.035 + sin(a * 7.0 + float(seed) * 0.31) * 0.018
        points.append(center + Vector2(cos(a), sin(a)) * radius * wobble)
    draw_polyline(points, color, width, true)

func _wobbly_oval(center: Vector2, radii: Vector2, color: Color, width: float, seed: int) -> void:
    var points := PackedVector2Array()
    var segments := 44
    for index in range(segments + 1):
        var a := float(index) * TAU / float(segments)
        var wobble := 1.0 + sin(a * 4.0 + float(seed) * 0.47) * 0.028
        points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y) * wobble)
    draw_polyline(points, color, width, true)

func _clinical_accent(style: String, fallback: Color) -> Color:
    match style:
        "calling": return Color("a66f68")
        "seed": return Color("7fa68d")
        "ashes": return Color("a47a61")
        "waves": return Color("829aa0")
        "rise": return Color("b5b39b")
        _: return Color("84b4ac") if fallback.a > 0.0 else WARD_GLASS

func _clinical_secondary(style: String, fallback: Color) -> Color:
    match style:
        "party": return Color("b7a57a")
        "unmasked": return Color("9e8b8b")
        "calling": return WARD_RED
        "invaluable": return Color("8fa4a6")
        "ashes": return Color("8b6960")
        _: return Color("98a5a0") if fallback.a > 0.0 else WARD_WALL

func _smooth01(value: float) -> float:
    var x: float = clampf(value, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)
