extends Control

const WARD_VOID := Color("070908")
const WARD_WALL := Color("b9b9aa")
const WARD_OIL := Color("31453f")
const WARD_LINE := Color("27322f")
const WARD_GLASS := Color("93c6c0")
const WARD_PAPER := Color("d8d5c7")
const WARD_RED := Color("8d3f43")

var _accent: Color = Color("84b4ac")
var _next_accent: Color = Color("84b4ac")
var _door_open_mix: float = 0.0
var _approach_mix: float = 0.0
var _warp_mix: float = 0.0
var _flash_mix: float = 0.0
var _phase: float = 0.0
var _reduced_motion: bool = false
var _memory_count: int = 0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
    visible = false
    visibility_changed.connect(_sync_processing)
    _sync_processing()

func _sync_processing() -> void:
    var active: bool = is_visible_in_tree()
    set_process(active)
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED if active else Control.MOUSE_BEHAVIOR_DISABLED

func set_accents(current: Color, next: Color = Color.TRANSPARENT) -> void:
    _accent = _clinicalize(current)
    _next_accent = _accent if next.a <= 0.0 else _clinicalize(next)
    queue_redraw()

func set_reduced_motion(value: bool) -> void:
    _reduced_motion = value

func set_memory_count(value: int) -> void:
    _memory_count = clampi(value, 0, 11)
    queue_redraw()

func set_door_open_mix(value: float) -> void:
    _door_open_mix = clampf(value, 0.0, 1.0)
    queue_redraw()

func set_approach_mix(value: float) -> void:
    _approach_mix = clampf(value, 0.0, 1.0)
    queue_redraw()

func set_warp_mix(value: float) -> void:
    _warp_mix = clampf(value, 0.0, 1.0)
    queue_redraw()

func set_flash_mix(value: float) -> void:
    _flash_mix = clampf(value, 0.0, 1.0)
    queue_redraw()

# Compatibility aliases retained for callers/tests; the visual is a physical
# ward threshold, not a portal or sliding-panel wipe.
func set_door_mix(value: float) -> void:
    set_door_open_mix(value)

func set_portal_mix(value: float) -> void:
    set_approach_mix(value)

func set_suck_mix(value: float) -> void:
    set_warp_mix(value)

func reset() -> void:
    _door_open_mix = 0.0
    _approach_mix = 0.0
    _warp_mix = 0.0
    _flash_mix = 0.0
    visible = false
    queue_redraw()

func _process(delta: float) -> void:
    if not visible:
        return
    var speed: float = 0.26 if _reduced_motion else 1.35 + _warp_mix * 5.2
    _phase = fmod(_phase + delta * speed, 1000.0)
    queue_redraw()

func _draw() -> void:
    if not visible or size.x <= 1.0 or size.y <= 1.0:
        return

    var w: float = size.x
    var h: float = size.y
    var approach: float = _ease_in_acceleration(_approach_mix)
    var warp: float = _smooth01(_warp_mix)
    var center := Vector2(
        w * (0.5 + 0.004 * sin(_phase * 0.17) * (1.0 - approach)),
        h * lerpf(0.535, 0.50, approach)
    )

    # Keep the existing camera-through-threshold mechanic. Only the transition
    # layer approaches the viewer; room artwork itself is never stretched.
    var base_height: float = h * (0.90 if h >= w else 0.86)
    var camera_scale: float = lerpf(1.0, 3.85, pow(approach, 1.55))
    var doorway_height: float = base_height * camera_scale
    var doorway_width: float = doorway_height * 0.54
    var doorway := Rect2(center - Vector2(doorway_width, doorway_height) * 0.5, Vector2(doorway_width, doorway_height))

    _draw_threshold_shadow(w, h, doorway, approach, warp)
    _draw_corridor_shell(w, h, doorway, approach, warp)
    _draw_corridor_memory(w, h, doorway, approach, warp)
    _draw_doorway_frame(doorway, approach, warp)
    _draw_hinged_door(doorway, _smooth01(_door_open_mix), approach)

    if warp > 0.001:
        _draw_supersonic_tunnel(center, w, h, warp, approach)

    if _flash_mix > 0.001:
        var flash: float = pow(_smooth01(_flash_mix), 1.7)
        draw_rect(Rect2(Vector2.ZERO, size), Color(WARD_PAPER, 0.10 * flash), true)
        draw_circle(center, minf(w, h) * (0.10 + flash * 0.82), Color(WARD_GLASS, 0.035 * flash))

func _draw_threshold_shadow(w: float, h: float, doorway: Rect2, approach: float, warp: float) -> void:
    var dim_alpha: float = 0.10 + approach * 0.22 + warp * 0.48
    draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(WARD_VOID, dim_alpha), true)
    var floor_y: float = minf(h, doorway.end.y)
    var floor := PackedVector2Array([
        Vector2(maxf(0.0, doorway.position.x), floor_y),
        Vector2(minf(w, doorway.end.x), floor_y),
        Vector2(w, h),
        Vector2(0.0, h),
    ])
    draw_colored_polygon(floor, Color(0.015, 0.024, 0.022, (0.10 + approach * 0.16) * (1.0 - warp * 0.32)))

func _draw_corridor_shell(w: float, h: float, doorway: Rect2, approach: float, warp: float) -> void:
    var vanish := doorway.get_center() + Vector2(0.0, doorway.size.y * 0.02)
    var shell_alpha := (0.12 + approach * 0.12) * (1.0 - warp * 0.48)
    draw_rect(Rect2(Vector2.ZERO, Vector2(w, h * 0.56)), Color(WARD_WALL, 0.018 + shell_alpha * 0.08), true)
    draw_rect(Rect2(Vector2(0.0, h * 0.52), Vector2(w, h * 0.045)), Color(WARD_OIL, 0.13 + shell_alpha * 0.30), true)
    draw_line(Vector2(0.0, h * 0.56), Vector2(w, h * 0.56), Color(WARD_LINE, 0.34 + shell_alpha), 1.4)
    draw_line(Vector2(0.0, h * 0.84), Vector2(w, h * 0.84), Color(WARD_LINE, 0.44), 2.0)

    for side in [-1.0, 1.0]:
        var x := w * (0.06 if side < 0.0 else 0.94)
        draw_line(Vector2(x, h), vanish, Color(WARD_GLASS, 0.055 + shell_alpha * 0.20), 1.0)

    # Repeating fluorescent fittings establish one continuous institution while
    # the camera accelerates. Their spacing, not neon streaks, sells movement.
    for index in range(4):
        var depth := float(index + 1) / 5.0
        var y := lerpf(h * 0.10, vanish.y, depth)
        var lamp_w := lerpf(w * 0.26, w * 0.08, depth)
        draw_line(Vector2(w * 0.5 - lamp_w * 0.5, y), Vector2(w * 0.5 + lamp_w * 0.5, y), Color(WARD_PAPER, 0.10 + shell_alpha * 0.32), 2.0)

func _draw_corridor_memory(w: float, h: float, doorway: Rect2, approach: float, warp: float) -> void:
    if _memory_count <= 0 or warp > 0.84:
        return
    var alpha: float = (0.08 + approach * 0.05) * (1.0 - warp)
    var floor_y: float = minf(h * 0.94, doorway.end.y + h * 0.05)
    var center_x: float = doorway.get_center().x

    # Physical residue replaces floating UI glyphs. The corridor accumulates
    # material traces from rooms already completed.
    if _memory_count >= 1:
        for line in range(3):
            var y := floor_y - 18.0 - float(line) * 10.0
            _wobble_line(Vector2(center_x - w * 0.24, y), Vector2(center_x + w * 0.24, y + sin(float(line)) * 4.0), Color(WARD_GLASS, alpha), 0.9, line + 3)
    if _memory_count >= 2:
        for tape in range(4):
            var p := Vector2(w * (0.14 + float(tape) * 0.085), h * 0.60 + float(tape % 2) * 8.0)
            draw_rect(Rect2(p, Vector2(18.0, 3.0)), Color("b7a57a", alpha * 1.2), true)
    if _memory_count >= 3:
        var scrap := Vector2(w * 0.19, h * 0.35)
        _wobbly_oval(scrap, Vector2(22.0, 28.0), Color(WARD_PAPER, alpha * 1.3), 1.0, 8)
    if _memory_count >= 4:
        var ring := Vector2(w * 0.80, h * 0.43)
        draw_arc(ring, 15.0, 0.0, TAU, 28, Color(WARD_RED, alpha * 1.35), 1.1)
    if _memory_count >= 5:
        var root := Vector2(center_x, floor_y - 2.0)
        _wobble_line(root, root + Vector2(-54.0, -30.0), Color("7fa68d", alpha * 1.15), 1.2, 13)
        _wobble_line(root, root + Vector2(49.0, -33.0), Color("7fa68d", alpha * 1.15), 1.2, 14)
    if _memory_count >= 6:
        var mark := Vector2(w * 0.73, h * 0.31)
        draw_arc(mark, 15.0, 0.0, TAU, 28, Color(WARD_GLASS, alpha * 1.15), 1.0)
        draw_line(mark - Vector2(22.0, 0.0), mark + Vector2(22.0, 0.0), Color(WARD_GLASS, alpha), 0.8)
    if _memory_count >= 7:
        for cable in range(3):
            var start := Vector2(w * (0.12 + float(cable) * 0.055), h * 0.56)
            _wobble_line(start, start + Vector2(36.0 + float(cable) * 8.0, 58.0), Color(WARD_LINE, alpha * 1.8), 1.5, cable + 17)
    if _memory_count >= 8:
        var glass := Vector2(w * 0.86, h * 0.61)
        for shard in range(5):
            draw_line(glass, glass + Vector2.from_angle(float(shard) * 1.31) * 34.0, Color(WARD_GLASS, alpha * 1.35), 1.0)
    if _memory_count >= 9:
        for ash in range(9):
            draw_circle(Vector2(w * 0.42 + float(ash % 3) * 18.0, h * 0.27 + float(ash / 3) * 17.0), 1.4, Color("8b6960", alpha * 1.25))
    if _memory_count >= 10:
        var left := Vector2(w * 0.43, h * 0.69)
        var right := Vector2(w * 0.57, h * 0.69)
        draw_circle(left, 7.0, Color("829aa0", alpha))
        draw_circle(right, 7.0, Color(WARD_GLASS, alpha))
        draw_line(left, right, Color(WARD_GLASS, alpha * 0.72), 1.0)
    if _memory_count >= 11:
        var light := Vector2(center_x, h * 0.14)
        var exit := Rect2(light - Vector2(28.0, 9.0), Vector2(56.0, 18.0))
        draw_rect(exit, Color(WARD_PAPER, alpha * 0.62), true)
        draw_rect(exit, Color(WARD_GLASS, alpha), false, 1.0)

func _draw_doorway_frame(doorway: Rect2, approach: float, warp: float) -> void:
    var frame_width: float = maxf(4.0, doorway.size.x * 0.035)
    var inner: Rect2 = doorway.grow(-frame_width)
    if inner.size.x <= 2.0 or inner.size.y <= 2.0:
        return

    var room_light := _accent.lerp(_next_accent, clampf(0.18 + warp * 0.62, 0.0, 1.0))
    draw_rect(inner, Color(WARD_VOID, 0.97), true)
    draw_rect(inner.grow(-maxf(3.0, inner.size.x * 0.04)), Color(room_light, 0.025 + warp * 0.07), true)

    var frame_dark := Color("161b19")
    draw_rect(Rect2(doorway.position, Vector2(frame_width, doorway.size.y)), frame_dark, true)
    draw_rect(Rect2(Vector2(doorway.end.x - frame_width, doorway.position.y), Vector2(frame_width, doorway.size.y)), frame_dark, true)
    draw_rect(Rect2(doorway.position, Vector2(doorway.size.x, frame_width)), frame_dark, true)

    var rim := Color(WARD_GLASS, 0.12 + approach * 0.08 + warp * 0.11)
    draw_line(inner.position, Vector2(inner.end.x, inner.position.y), rim, maxf(1.0, frame_width * 0.12))
    draw_line(inner.position, Vector2(inner.position.x, inner.end.y), rim, maxf(1.0, frame_width * 0.12))
    draw_line(Vector2(inner.end.x, inner.position.y), inner.end, rim, maxf(1.0, frame_width * 0.12))

func _draw_hinged_door(doorway: Rect2, open_mix: float, approach: float) -> void:
    var frame_width: float = maxf(4.0, doorway.size.x * 0.035)
    var inner: Rect2 = doorway.grow(-frame_width)
    if inner.size.x <= 4.0 or inner.size.y <= 4.0:
        return

    # Perspective projection of one heavy institutional door rotating on its
    # left hinge. Keeping cos(angle) preserves the existing physical threshold.
    var angle: float = open_mix * 1.47
    var projected_width: float = maxf(0.045, cos(angle))
    var depth: float = sin(angle)
    var hinge_top := inner.position
    var hinge_bottom := Vector2(inner.position.x, inner.end.y)
    var free_x: float = inner.position.x + inner.size.x * projected_width
    var vertical_skew: float = inner.size.y * 0.018 * depth
    var free_top := Vector2(free_x, inner.position.y + vertical_skew)
    var free_bottom := Vector2(free_x, inner.end.y - vertical_skew)

    var leaf := PackedVector2Array([hinge_top, free_top, free_bottom, hinge_bottom])
    draw_colored_polygon(leaf, Color("283932"))
    draw_polyline(PackedVector2Array([hinge_top, free_top, free_bottom, hinge_bottom, hinge_top]), Color(WARD_GLASS, 0.17 + approach * 0.06), maxf(1.0, inner.size.x * 0.006), true)

    var thickness: float = maxf(2.0, inner.size.x * 0.012) * depth
    if thickness > 0.5:
        var edge := PackedVector2Array([
            free_top,
            free_top + Vector2(thickness, thickness * 0.32),
            free_bottom + Vector2(thickness, -thickness * 0.32),
            free_bottom,
        ])
        draw_colored_polygon(edge, Color("17211e"))

    if projected_width > 0.12:
        _draw_projected_window(inner, projected_width, vertical_skew)
        _draw_projected_ward_label(inner, projected_width, vertical_skew)

    var handle_x := lerpf(inner.position.x, free_x, 0.84)
    var handle_y := inner.position.y + inner.size.y * 0.55
    var handle := Vector2(handle_x, handle_y)
    draw_line(handle - Vector2(7.0 * projected_width, 0.0), handle + Vector2(7.0 * projected_width, 0.0), Color(WARD_PAPER, 0.50), maxf(1.0, inner.size.x * 0.008))

func _draw_projected_window(inner: Rect2, projected_width: float, skew: float) -> void:
    var x0 := inner.position.x + inner.size.x * 0.20 * projected_width
    var x1 := inner.position.x + inner.size.x * 0.80 * projected_width
    var y0 := inner.position.y + inner.size.y * 0.16 + skew * 0.35
    var y1 := inner.position.y + inner.size.y * 0.31 - skew * 0.35
    var glass := PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
    draw_colored_polygon(glass, Color(WARD_GLASS, 0.065))
    draw_polyline(PackedVector2Array([glass[0], glass[1], glass[2], glass[3], glass[0]]), Color(WARD_GLASS, 0.28), 1.0, true)
    for wire in range(3):
        var t := float(wire + 1) / 4.0
        draw_line(glass[0].lerp(glass[3], t), glass[1].lerp(glass[2], t), Color(WARD_LINE, 0.26), 0.7)

func _draw_projected_ward_label(inner: Rect2, projected_width: float, skew: float) -> void:
    var x := inner.position.x + inner.size.x * 0.64 * projected_width
    var y := inner.position.y + inner.size.y * 0.39 - skew * 0.15
    var width := inner.size.x * 0.20 * projected_width
    var height := maxf(3.0, inner.size.y * 0.035)
    draw_rect(Rect2(Vector2(x, y), Vector2(width, height)), Color(WARD_PAPER, 0.10), true)
    draw_rect(Rect2(Vector2(x, y), Vector2(width, height)), Color(WARD_PAPER, 0.28), false, 0.8)

func _draw_supersonic_tunnel(center: Vector2, w: float, h: float, warp: float, approach: float) -> void:
    # Function name is retained for the transition contract, but the visual is
    # no longer sci-fi. It is the ward corridor stretching into fluorescent and
    # skirting lines as the camera crosses the threshold.
    var streak_count: int = 8 if _reduced_motion else 14
    var pulse := _smooth01(warp)
    for index in range(streak_count):
        var lane := float(index) / maxf(1.0, float(streak_count - 1))
        var side := -1.0 if index % 2 == 0 else 1.0
        var spread := lerpf(w * 0.08, w * 0.58, lane)
        var y := center.y + lerpf(-h * 0.28, h * 0.46, lane)
        var start := center + Vector2(side * spread * 0.18, (y - center.y) * 0.22)
        var end := Vector2(center.x + side * spread, y)
        draw_line(start, end, Color(WARD_GLASS, (0.018 + lane * 0.022) * pulse), 1.0 + lane * 0.8)

    for lamp in range(5):
        var depth := fmod(float(lamp) / 5.0 + _phase * 0.07, 1.0)
        var scale := pow(depth, 1.6)
        var y := lerpf(center.y - h * 0.18, h * 0.04, scale)
        var lamp_w := lerpf(w * 0.05, w * 0.42, scale)
        draw_line(Vector2(center.x - lamp_w * 0.5, y), Vector2(center.x + lamp_w * 0.5, y), Color(WARD_PAPER, (0.04 + scale * 0.10) * pulse), 1.2 + scale * 2.0)

    var floor_alpha := (0.025 + approach * 0.025) * pulse
    draw_line(Vector2(center.x - w * 0.07, center.y + h * 0.12), Vector2(w * 0.04, h), Color(WARD_LINE, floor_alpha), 1.2)
    draw_line(Vector2(center.x + w * 0.07, center.y + h * 0.12), Vector2(w * 0.96, h), Color(WARD_LINE, floor_alpha), 1.2)

func _wobble_line(a: Vector2, b: Vector2, color: Color, width: float, seed: int) -> void:
    var points := PackedVector2Array()
    var delta := b - a
    var normal := Vector2(-delta.y, delta.x).normalized()
    for index in range(6):
        var t := float(index) / 5.0
        var jitter := sin(float(seed) * 1.91 + float(index) * 2.13) * 1.1
        points.append(a.lerp(b, t) + normal * jitter)
    draw_polyline(points, color, width, true)

func _wobbly_oval(center: Vector2, radii: Vector2, color: Color, width: float, seed: int) -> void:
    var points := PackedVector2Array()
    var segments := 32
    for index in range(segments + 1):
        var a := float(index) * TAU / float(segments)
        var wobble := 1.0 + sin(a * 4.0 + float(seed) * 0.51) * 0.035
        points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y) * wobble)
    draw_polyline(points, color, width, true)

func _clinicalize(color: Color) -> Color:
    var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
    var neutral := Color(luminance, luminance, luminance, 1.0)
    return neutral.lerp(WARD_GLASS, 0.72)

func _ease_in_acceleration(value: float) -> float:
    var x := clampf(value, 0.0, 1.0)
    return x * x * x

func _smooth01(value: float) -> float:
    var x := clampf(value, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)
