extends Control

var _accent: Color = Color("72afff")
var _next_accent: Color = Color("72afff")
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
    _accent = current
    _next_accent = current if next.a <= 0.0 else next
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

# Compatibility aliases for older tests/overlays. These no longer represent
# sliding panels: door_mix means the real hinged door opening amount.
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
    var speed: float = 0.65 if _reduced_motion else 4.8 + _warp_mix * 13.0
    _phase = fmod(_phase + delta * speed, 1000.0)
    queue_redraw()

func _draw() -> void:
    if not visible or size.x <= 1.0 or size.y <= 1.0:
        return

    var w: float = size.x
    var h: float = size.y
    var approach: float = _ease_in_acceleration(_approach_mix)
    var warp: float = _smooth01(_warp_mix)
    # First-person framing: the doorway already dominates the initial frame and
    # then crosses the viewport edges as the camera moves through it. This reads
    # as walking into a physical threshold instead of watching a door icon scale.
    var center: Vector2 = Vector2(
        w * (0.5 + 0.012 * sin(_phase * 0.11) * (1.0 - approach)),
        h * lerpf(0.545, 0.50, approach)
    )

    # Only the transition layer moves toward the viewer. The room artwork below
    # remains untouched, avoiding the rubber-sheet stretch of the old effect.
    var base_height: float = h * (0.90 if h >= w else 0.86)
    var camera_scale: float = lerpf(1.0, 3.85, pow(approach, 1.55))
    var doorway_height: float = base_height * camera_scale
    var doorway_width: float = doorway_height * 0.54
    var doorway: Rect2 = Rect2(
        center - Vector2(doorway_width, doorway_height) * 0.5,
        Vector2(doorway_width, doorway_height)
    )

    _draw_threshold_shadow(w, h, doorway, approach, warp)
    _draw_corridor_memory(w, h, doorway, approach, warp)
    _draw_doorway_frame(doorway, approach, warp)
    _draw_hinged_door(doorway, _smooth01(_door_open_mix), approach)

    if warp > 0.001:
        _draw_supersonic_tunnel(center, w, h, warp, approach)

    if _flash_mix > 0.001:
        var flash: float = pow(_smooth01(_flash_mix), 1.7)
        draw_rect(Rect2(Vector2.ZERO, size), Color(_accent.lerp(_next_accent, 0.5), 0.08 * flash), true)
        draw_circle(center, minf(w, h) * (0.12 + flash * 0.92), Color(Color.WHITE, 0.075 * flash))

func _draw_corridor_memory(w: float, h: float, doorway: Rect2, approach: float, warp: float) -> void:
    if _memory_count <= 0 or warp > 0.82:
        return
    var alpha: float = (0.055 + approach * 0.045) * (1.0 - warp)
    var floor_y: float = minf(h * 0.94, doorway.end.y + h * 0.05)
    var center_x: float = doorway.get_center().x
    if _memory_count >= 1:
        for line in range(3):
            var y: float = floor_y - 20.0 - float(line) * 13.0
            draw_arc(Vector2(center_x - w * 0.28, y), 34.0 + float(line) * 9.0, 0.1, PI - 0.1, 20, Color(_accent, alpha), 1.0)
    if _memory_count >= 2:
        for dot in range(8):
            var p := Vector2(w * (0.12 + float(dot) * 0.095), floor_y - 52.0 - float(dot % 3) * 16.0)
            draw_circle(p, 2.0 + float(dot % 2), Color(_accent.lerp(Color("ef6fbd"), 0.45), alpha * 1.35))
    if _memory_count >= 3:
        var mask_center := Vector2(w * 0.19, h * 0.34)
        draw_arc(mask_center, 22.0, 0.15, PI - 0.15, 18, Color(_accent, alpha * 1.25), 1.5)
    if _memory_count >= 4:
        var glass := Vector2(w * 0.80, h * 0.42)
        draw_arc(glass, 15.0, 0.0, PI, 16, Color("b91346", alpha * 1.45), 1.2)
        draw_line(glass + Vector2(0.0, 15.0), glass + Vector2(0.0, 38.0), Color("b91346", alpha), 1.0)
    if _memory_count >= 5:
        var root := Vector2(center_x, floor_y - 4.0)
        for side in [-1.0, 1.0]:
            draw_polyline(PackedVector2Array([root, root + Vector2(side * 28.0, -18.0), root + Vector2(side * 52.0, -30.0)]), Color("72d79a", alpha), 1.2)
    if _memory_count >= 6:
        var aim := Vector2(w * 0.74, h * 0.30)
        draw_arc(aim, 16.0, 0.0, TAU, 18, Color("f4c36a", alpha), 1.0)
        draw_line(aim - Vector2(24.0, 0.0), aim + Vector2(24.0, 0.0), Color("f4c36a", alpha * 0.8), 1.0)
    if _memory_count >= 7:
        for screen in range(3):
            draw_rect(Rect2(Vector2(w * (0.11 + float(screen) * 0.07), h * 0.56), Vector2(30.0, 19.0)), Color("66c9ff", alpha * 0.8), false, 1.0)
    if _memory_count >= 8:
        var mirror := Vector2(w * 0.86, h * 0.60)
        for shard in range(5):
            draw_line(mirror, mirror + Vector2.from_angle(float(shard) * 1.31) * 34.0, Color("d4e4ff", alpha), 1.0)
    if _memory_count >= 9:
        for ash in range(9):
            draw_circle(Vector2(w * 0.42 + float(ash % 3) * 18.0, h * 0.26 + float(ash / 3) * 17.0), 1.5, Color("ff9e58", alpha * 1.2))
    if _memory_count >= 10:
        draw_circle(Vector2(w * 0.43, h * 0.68), 9.0, Color("94a9ff", alpha))
        draw_circle(Vector2(w * 0.57, h * 0.68), 9.0, Color("d890b8", alpha))
        draw_line(Vector2(w * 0.43, h * 0.68), Vector2(w * 0.57, h * 0.68), Color("b99bdc", alpha * 0.7), 1.0)
    if _memory_count >= 11:
        var light := Vector2(center_x, h * 0.15)
        for ray in range(5):
            draw_line(light, Vector2(w * (0.24 + float(ray) * 0.13), h * 0.78), Color("ffd56d", alpha * 0.75), 1.0)

func _draw_threshold_shadow(w: float, h: float, doorway: Rect2, approach: float, warp: float) -> void:
    var dim_alpha: float = 0.06 + approach * 0.17 + warp * 0.50
    draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.002, 0.004, 0.009, dim_alpha), true)

    var floor_y: float = minf(h, doorway.end.y)
    var left_bottom: Vector2 = Vector2(maxf(0.0, doorway.position.x), floor_y)
    var right_bottom: Vector2 = Vector2(minf(w, doorway.end.x), floor_y)
    var floor: PackedVector2Array = PackedVector2Array([
        left_bottom,
        right_bottom,
        Vector2(w, h),
        Vector2(0.0, h),
    ])
    draw_colored_polygon(floor, Color(0.004, 0.006, 0.011, (0.08 + approach * 0.12) * (1.0 - warp * 0.35)))

func _draw_doorway_frame(doorway: Rect2, approach: float, warp: float) -> void:
    var frame_width: float = maxf(4.0, doorway.size.x * 0.035)
    var inner: Rect2 = doorway.grow(-frame_width)
    if inner.size.x <= 2.0 or inner.size.y <= 2.0:
        return

    var portal_color: Color = _accent.lerp(_next_accent, clampf(0.18 + warp * 0.62, 0.0, 1.0))
    draw_rect(inner, Color(0.001, 0.003, 0.007, 0.96), true)

    var portal_alpha: float = (0.035 + warp * 0.16) * (0.5 + _door_open_mix * 0.5)
    var portal_margin: float = maxf(3.0, inner.size.x * 0.035)
    draw_rect(inner.grow(-portal_margin), Color(portal_color, portal_alpha), true)

    var frame_dark: Color = Color(0.014, 0.015, 0.019, 0.995)
    draw_rect(Rect2(doorway.position, Vector2(frame_width, doorway.size.y)), frame_dark, true)
    draw_rect(Rect2(Vector2(doorway.end.x - frame_width, doorway.position.y), Vector2(frame_width, doorway.size.y)), frame_dark, true)
    draw_rect(Rect2(doorway.position, Vector2(doorway.size.x, frame_width)), frame_dark, true)

    var rim: Color = Color(_accent.lerp(_next_accent, warp), 0.13 + approach * 0.09 + warp * 0.16)
    draw_line(inner.position, Vector2(inner.end.x, inner.position.y), rim, maxf(1.0, frame_width * 0.12))
    draw_line(inner.position, Vector2(inner.position.x, inner.end.y), rim, maxf(1.0, frame_width * 0.12))
    draw_line(Vector2(inner.end.x, inner.position.y), inner.end, rim, maxf(1.0, frame_width * 0.12))

func _draw_hinged_door(doorway: Rect2, open_mix: float, approach: float) -> void:
    var frame_width: float = maxf(4.0, doorway.size.x * 0.035)
    var inner: Rect2 = doorway.grow(-frame_width)
    if inner.size.x <= 4.0 or inner.size.y <= 4.0:
        return

    # Perspective projection of a single physical door rotating around its
    # left hinge. The free edge contracts toward the hinge instead of sliding.
    var angle: float = open_mix * 1.47
    var projected_width: float = maxf(0.045, cos(angle))
    var depth: float = sin(angle)
    var hinge_top: Vector2 = inner.position
    var hinge_bottom: Vector2 = Vector2(inner.position.x, inner.end.y)
    var free_x: float = inner.position.x + inner.size.x * projected_width
    var vertical_skew: float = inner.size.y * 0.018 * depth
    var free_top: Vector2 = Vector2(free_x, inner.position.y + vertical_skew)
    var free_bottom: Vector2 = Vector2(free_x, inner.end.y - vertical_skew)

    var leaf: PackedVector2Array = PackedVector2Array([
        hinge_top,
        free_top,
        free_bottom,
        hinge_bottom,
    ])
    var leaf_color: Color = Color(0.014, 0.013, 0.016, 0.995)
    draw_colored_polygon(leaf, leaf_color)

    var thickness: float = maxf(2.0, inner.size.x * 0.012) * depth
    if thickness > 0.5:
        var edge: PackedVector2Array = PackedVector2Array([
            free_top,
            free_top + Vector2(thickness, thickness * 0.32),
            free_bottom + Vector2(thickness, -thickness * 0.32),
            free_bottom,
        ])
        draw_colored_polygon(edge, Color(0.055, 0.050, 0.056, 0.98))

    var edge_alpha: float = 0.13 + approach * 0.08
    draw_polyline(PackedVector2Array([hinge_top, free_top, free_bottom, hinge_bottom, hinge_top]), Color(_accent, edge_alpha), maxf(1.0, inner.size.x * 0.006), true)

    # Door panel relief follows the projected door surface.
    if projected_width > 0.12:
        _draw_projected_panel(inner, projected_width, vertical_skew, 0.10, 0.08, 0.80, 0.34)
        _draw_projected_panel(inner, projected_width, vertical_skew, 0.10, 0.56, 0.80, 0.31)
        _draw_projected_eye(inner, projected_width, vertical_skew, open_mix)

    var handle_ratio_x: float = 0.86
    var handle_ratio_y: float = 0.52
    var handle_x: float = lerpf(inner.position.x, free_x, handle_ratio_x)
    var top_y_at_handle: float = lerpf(inner.position.y, free_top.y, handle_ratio_x)
    var bottom_y_at_handle: float = lerpf(inner.end.y, free_bottom.y, handle_ratio_x)
    var handle_y: float = lerpf(top_y_at_handle, bottom_y_at_handle, handle_ratio_y)
    var handle_radius: float = clampf(inner.size.x * 0.015 * projected_width, 1.6, 6.0)
    draw_circle(Vector2(handle_x, handle_y), handle_radius, Color(0.82, 0.78, 0.69, 0.60))
    draw_circle(Vector2(handle_x, handle_y), maxf(1.0, handle_radius * 0.38), Color(_accent, 0.42))


func _draw_projected_eye(inner: Rect2, projected_width: float, vertical_skew: float, open_mix: float) -> void:
    var center_x: float = inner.position.x + inner.size.x * projected_width * 0.52
    var x_ratio: float = 0.52
    var top_y: float = inner.position.y + vertical_skew * x_ratio
    var bottom_y: float = inner.end.y - vertical_skew * x_ratio
    var center := Vector2(center_x, lerpf(top_y, bottom_y, 0.42))
    var eye_w: float = inner.size.x * projected_width * 0.42
    var eye_h: float = inner.size.y * 0.075
    var blink_phase: float = fmod(_phase * 0.22 + open_mix * 0.35, 3.7)
    var blink: float = clampf(1.0 - absf(blink_phase - 1.85) * 9.0, 0.0, 1.0) if blink_phase > 1.72 and blink_phase < 1.98 else 0.0
    eye_h *= 1.0 - blink * 0.92
    if eye_h <= 1.0:
        return
    var left := center + Vector2(-eye_w * 0.5, 0.0)
    var right := center + Vector2(eye_w * 0.5, 0.0)
    var upper := PackedVector2Array([left, center + Vector2(-eye_w * 0.22, -eye_h * 0.55), center + Vector2(0.0, -eye_h * 0.62), center + Vector2(eye_w * 0.22, -eye_h * 0.55), right])
    var lower := PackedVector2Array([left, center + Vector2(-eye_w * 0.22, eye_h * 0.55), center + Vector2(0.0, eye_h * 0.62), center + Vector2(eye_w * 0.22, eye_h * 0.55), right])
    draw_polyline(upper, Color(0.94, 0.91, 1.0, 0.72), maxf(1.0, inner.size.x * 0.006), true)
    draw_polyline(lower, Color(0.94, 0.91, 1.0, 0.72), maxf(1.0, inner.size.x * 0.006), true)
    var iris: float = minf(eye_h * 0.72, eye_w * 0.13)
    draw_circle(center, iris, Color(_accent.lerp(_next_accent, open_mix), 0.44))
    draw_circle(center, iris * 0.35, Color(0.003, 0.004, 0.009, 0.96))
    var node_color := _accent.lerp(_next_accent, 0.55)
    draw_line(center + Vector2(-iris * 0.52, -iris * 0.10), center + Vector2(iris * 0.48, iris * 0.12), Color(node_color, 0.55), maxf(0.8, iris * 0.07))
    for offset in [Vector2(-0.40, -0.14), Vector2(-0.12, 0.24), Vector2(0.18, -0.22), Vector2(0.40, 0.12)]:
        draw_circle(center + offset * iris, maxf(1.0, iris * 0.075), Color(node_color, 0.72))

func _draw_projected_panel(inner: Rect2, projected_width: float, vertical_skew: float, x_ratio: float, y_ratio: float, width_ratio: float, height_ratio: float) -> void:
    var x0: float = inner.position.x + inner.size.x * projected_width * x_ratio
    var x1: float = inner.position.x + inner.size.x * projected_width * (x_ratio + width_ratio)
    var y0: float = inner.position.y + inner.size.y * y_ratio
    var y1: float = inner.position.y + inner.size.y * (y_ratio + height_ratio)
    var skew0: float = vertical_skew * (x_ratio + 0.1)
    var skew1: float = vertical_skew * (x_ratio + width_ratio)
    var panel: PackedVector2Array = PackedVector2Array([
        Vector2(x0, y0 + skew0),
        Vector2(x1, y0 + skew1),
        Vector2(x1, y1 - skew1),
        Vector2(x0, y1 - skew0),
        Vector2(x0, y0 + skew0),
    ])
    draw_polyline(panel, Color(_accent, 0.085), maxf(0.8, inner.size.x * 0.004), true)

func _draw_supersonic_tunnel(center: Vector2, w: float, h: float, warp: float, approach: float) -> void:
    var radius_max: float = sqrt(w * w + h * h) * 0.62
    var streak_count: int = 18 if _reduced_motion else 52
    var speed: float = 0.32 + warp * 1.75

    # Radial velocity streaks accelerate outward as the camera is sucked
    # through the open doorway. They are deterministic and allocation-light.
    for index in range(streak_count):
        var seed: float = fmod(sin(float(index) * 91.173) * 43758.5453, 1.0)
        if seed < 0.0:
            seed += 1.0
        var angle: float = TAU * fmod(float(index) * 0.61803398875 + 0.07 * sin(float(index) * 1.7), 1.0)
        var travel: float = fmod(seed + _phase * 0.035 * speed, 1.0)
        var radial_curve: float = pow(travel, 1.65)
        var start_radius: float = lerpf(10.0, radius_max * 0.70, radial_curve)
        var streak_length: float = radius_max * (0.035 + warp * 0.24) * (0.35 + travel * 0.90)
        var start_point: Vector2 = center + Vector2.from_angle(angle) * start_radius
        var end_point: Vector2 = center + Vector2.from_angle(angle) * minf(radius_max, start_radius + streak_length)
        var color_mix: float = float(index) / float(maxi(1, streak_count - 1))
        var streak_color: Color = Color(_accent.lerp(_next_accent, color_mix), (0.035 + warp * 0.16) * (0.35 + travel * 0.65))
        draw_line(start_point, end_point, streak_color, 0.7 + warp * 2.1)

    var ring_count: int = 5 if _reduced_motion else 13
    for index in range(ring_count):
        var ratio: float = float(index) / float(maxi(1, ring_count - 1))
        var travel: float = fmod(ratio + _phase * (0.018 + warp * 0.075), 1.0)
        var ring_scale: float = pow(travel, 2.1)
        var ring_size: Vector2 = Vector2(w * 0.58, h * 0.70) * (0.08 + ring_scale * (1.45 + approach * 1.10))
        var ring: Rect2 = Rect2(center - ring_size * 0.5, ring_size)
        var alpha: float = (1.0 - travel) * (0.025 + warp * 0.11)
        _draw_rect_outline(ring, Color(_accent.lerp(_next_accent, ratio), alpha), 0.8 + warp * 1.4)

    var throat_radius: float = lerpf(minf(w, h) * 0.115, 4.0, warp)
    draw_circle(center, throat_radius, Color(_accent.lerp(_next_accent, 0.5), 0.045 + warp * 0.10))
    draw_circle(center, maxf(2.0, throat_radius * 0.28), Color(Color.WHITE, 0.03 + warp * 0.08))

    # Subtle side chromatic streaks read as speed without distorting the room.
    if not _reduced_motion and warp > 0.18:
        var chroma_alpha: float = (warp - 0.18) * 0.065
        draw_line(center + Vector2(-12.0, 0.0), Vector2(0.0, center.y), Color(0.20, 0.55, 1.0, chroma_alpha), 2.0)
        draw_line(center + Vector2(12.0, 0.0), Vector2(w, center.y), Color(1.0, 0.20, 0.45, chroma_alpha), 2.0)

func _draw_rect_outline(rect: Rect2, color: Color, width: float) -> void:
    draw_line(rect.position, Vector2(rect.end.x, rect.position.y), color, width)
    draw_line(Vector2(rect.end.x, rect.position.y), rect.end, color, width)
    draw_line(rect.end, Vector2(rect.position.x, rect.end.y), color, width)
    draw_line(Vector2(rect.position.x, rect.end.y), rect.position, color, width)

func _smooth01(value: float) -> float:
    var x: float = clampf(value, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)

func _ease_in_acceleration(value: float) -> float:
    var x: float = clampf(value, 0.0, 1.0)
    return pow(x, 2.55)
