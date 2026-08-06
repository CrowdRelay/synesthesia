extends Control
class_name SynesthesiaPaintRoom

signal coverage_changed(value: float)
signal collectible_found(item: Dictionary)
signal paint_pulse(speed_normalized: float)
signal special_interaction(kind: String, index: int)

const GRID_WIDTH: int = 24
const GRID_HEIGHT: int = 36
const GRID_CELL_COUNT: int = GRID_WIDTH * GRID_HEIGHT
const MAX_SEGMENTS: int = 520
const MAX_BRUSH_STAMPS_PER_SEGMENT: int = 3
const COMIC_FRAME_WIDTH: float = 5.0
const MIN_STROKE_DISTANCE: float = 1.5
const ACTIVE_REDRAW_HZ: float = 60.0
const FULL_IDLE_REDRAW_HZ: float = 36.0
const CALM_IDLE_REDRAW_HZ: float = 24.0
const REDUCED_MOTION_REDRAW_HZ: float = 10.0
const BALLOON_COUNT: int = 18
const MIRROR_COUNT: int = 7

var manifest_room: Dictionary = {}
var palette: Array[Color] = []
var collectibles: Array[Dictionary] = []
var segments: Array[Dictionary] = []
var occupied: PackedByteArray = PackedByteArray()
var occupied_count: int = 0
var drawing: bool = false
var previous_point: Vector2 = Vector2.ZERO
var paint_color_index: int = 0
var calm_mode: bool = true
var interaction_enabled: bool = true
var visual_progress: float = 0.0
var motion_phase: float = 0.0
var cinematic_revealed: bool = false
var door_target_open: bool = false
var door_open_amount: float = 0.0
var balloons: Array[Dictionary] = []
var mirrors: Array[Dictionary] = []
var special_state: Dictionary = {}
var reduced_motion: bool = false
var redraw_accumulator: float = 0.0
var cached_base_color: Color = Color("101827")
var cached_floor_color: Color = Color("080c14")
var cached_accent_color: Color = Color("71afff")
var cached_secondary_color: Color = Color("ff6680")
var cached_visual_style: String = "uncertainty"
var cached_interaction: String = "paint"
var cached_completion_threshold: float = 0.44
var cached_brush_profile: String = "soft"
var cached_brush_min_width: float = 24.0
var cached_brush_max_width: float = 56.0
var cached_brush_opacity: float = 0.80
var cached_brush_texture: float = 0.48
var cached_brush_outline: float = 0.70
var cached_brush_spacing: float = 0.62
var cached_ink_strength: float = 0.72
var cached_halftone_strength: float = 0.24
var cached_caption: String = ""
var stroke_serial: int = 0
var special_last_hit_ms: Dictionary = {}

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    clip_contents = true
    occupied.resize(GRID_CELL_COUNT)
    occupied.fill(0)
    resized.connect(_on_resized)
    set_process(true)

func _process(delta: float) -> void:
    var target: float = 1.0 if door_target_open else 0.0
    var door_moving: bool = not is_equal_approx(door_open_amount, target)
    door_open_amount = move_toward(door_open_amount, target, delta * 0.72)

    var redraw_hz: float = CALM_IDLE_REDRAW_HZ if calm_mode else FULL_IDLE_REDRAW_HZ
    if drawing or door_moving:
        redraw_hz = ACTIVE_REDRAW_HZ
    elif reduced_motion:
        redraw_hz = REDUCED_MOTION_REDRAW_HZ

    redraw_accumulator += delta
    var redraw_interval: float = 1.0 / redraw_hz
    if redraw_accumulator < redraw_interval:
        return
    var motion_speed: float = 0.12 if calm_mode else 0.24
    if reduced_motion:
        motion_speed *= 0.35
    motion_phase = fmod(motion_phase + redraw_accumulator * motion_speed, 1000.0)
    redraw_accumulator = 0.0
    queue_redraw()

func configure(room_data: Dictionary, collectible_data: Array) -> void:
    manifest_room = room_data.duplicate(true)
    cached_base_color = Color.from_string(str(room_data.get("base_color", "#101827")), Color("101827"))
    cached_floor_color = Color.from_string(str(room_data.get("floor_color", "#080c14")), Color("080c14"))
    cached_accent_color = Color.from_string(str(room_data.get("accent_color", "#71AFFF")), Color("71afff"))
    cached_secondary_color = Color.from_string(str(room_data.get("secondary_color", "#FF6680")), Color("ff6680"))
    cached_visual_style = str(room_data.get("visual_style", "uncertainty"))
    cached_interaction = str(room_data.get("interaction", "paint"))
    cached_completion_threshold = maxf(0.1, float(room_data.get("completion_coverage", 0.44)))
    var brush_value: Variant = room_data.get("brush", {})
    var brush: Dictionary = brush_value if brush_value is Dictionary else {}
    cached_brush_profile = str(brush.get("profile", "soft"))
    cached_brush_min_width = clampf(float(brush.get("min_width", 24.0)), 12.0, 72.0)
    cached_brush_max_width = clampf(float(brush.get("max_width", 56.0)), cached_brush_min_width, 104.0)
    cached_brush_opacity = clampf(float(brush.get("opacity", 0.80)), 0.35, 1.0)
    cached_brush_texture = clampf(float(brush.get("texture", 0.48)), 0.0, 1.0)
    cached_brush_outline = clampf(float(brush.get("outline", 0.70)), 0.0, 1.0)
    cached_brush_spacing = clampf(float(brush.get("spacing", 0.62)), 0.30, 1.20)
    var art_value: Variant = room_data.get("art_direction", {})
    var art: Dictionary = art_value if art_value is Dictionary else {}
    cached_ink_strength = clampf(float(art.get("ink_strength", 0.72)), 0.0, 1.0)
    cached_halftone_strength = clampf(float(art.get("halftone_strength", 0.24)), 0.0, 0.75)
    cached_caption = str(art.get("caption", room_data.get("name", "")))
    palette.clear()
    var raw_palette: Variant = room_data.get("paint_palette", ["#72AFFF"])
    if raw_palette is Array:
        for raw_color in raw_palette:
            palette.append(Color.from_string(str(raw_color), Color("72afff")))
    if palette.is_empty():
        palette.append(Color("72afff"))

    collectibles.clear()
    for source in collectible_data:
        if not source is Dictionary:
            continue
        var item: Dictionary = source.duplicate(true)
        item["found"] = false
        collectibles.append(item)

    balloons = _build_balloons()
    mirrors = _build_mirrors()
    special_state = {}
    special_last_hit_ms = {}
    stroke_serial = 0
    cinematic_revealed = false
    door_target_open = false
    door_open_amount = 0.0
    queue_redraw()

func set_calm_mode(value: bool) -> void:
    if calm_mode == value:
        return
    calm_mode = value
    queue_redraw()

func set_reduced_motion(value: bool) -> void:
    if reduced_motion == value:
        return
    reduced_motion = value
    redraw_accumulator = 0.0
    queue_redraw()

func set_interaction_enabled(value: bool) -> void:
    interaction_enabled = value
    if not value:
        drawing = false

func set_cinematic_reveal(value: bool) -> void:
    cinematic_revealed = value
    queue_redraw()

func reveal_remaining_collectibles() -> Array[Dictionary]:
    var revealed: Array[Dictionary] = []
    for item in collectibles:
        if bool(item.get("found", false)):
            continue
        item["found"] = true
        var copy: Dictionary = item.duplicate(true)
        revealed.append(copy)
        collectible_found.emit(copy)
    return revealed

func set_door_open(value: bool) -> void:
    door_target_open = value

func get_door_open_amount() -> float:
    return door_open_amount

func reset_room() -> void:
    segments.clear()
    occupied.fill(0)
    occupied_count = 0
    paint_color_index = 0
    drawing = false
    visual_progress = 0.0
    cinematic_revealed = false
    door_target_open = false
    door_open_amount = 0.0
    balloons = _build_balloons()
    mirrors = _build_mirrors()
    special_state = {}
    special_last_hit_ms = {}
    stroke_serial = 0
    for item in collectibles:
        item["found"] = false
    coverage_changed.emit(0.0)
    queue_redraw()

func get_found_count() -> int:
    var count: int = 0
    for item in collectibles:
        if bool(item.get("found", false)):
            count += 1
    return count

func get_coverage() -> float:
    return float(occupied_count) / float(GRID_CELL_COUNT)

func get_normalized_progress() -> float:
    return clampf(get_coverage() / cached_completion_threshold, 0.0, 1.0)

func export_state() -> Dictionary:
    var occupied_cells: Array[int] = []
    for index in range(occupied.size()):
        if occupied[index] != 0:
            occupied_cells.append(index)

    var saved_segments: Array[Dictionary] = []
    if size.x > 1.0 and size.y > 1.0:
        var reference: float = maxf(1.0, minf(size.x, size.y))
        for segment in segments:
            var from_value: Variant = segment.get("from", Vector2.ZERO)
            var to_value: Variant = segment.get("to", Vector2.ZERO)
            var color_value: Variant = segment.get("color", Color("72afff"))
            var from: Vector2 = from_value if from_value is Vector2 else Vector2.ZERO
            var to: Vector2 = to_value if to_value is Vector2 else Vector2.ZERO
            var color: Color = color_value if color_value is Color else Color("72afff")
            saved_segments.append({
                "from": [from.x / size.x, from.y / size.y],
                "to": [to.x / size.x, to.y / size.y],
                "width": float(segment.get("width", 40.0)) / reference,
                "color": color.to_html(true),
                "profile": str(segment.get("profile", cached_brush_profile)),
                "seed": int(segment.get("seed", 0)),
                "speed": clampf(float(segment.get("speed", 0.0)), 0.0, 1.0),
            })

    var found_ids: Array[String] = []
    for item in collectibles:
        if bool(item.get("found", false)):
            found_ids.append(str(item.get("id", "")))

    var popped: Array[int] = []
    for index in range(balloons.size()):
        if bool(balloons[index].get("popped", false)):
            popped.append(index)
    var cracked: Array[int] = []
    for index in range(mirrors.size()):
        if float(mirrors[index].get("crack", 0.0)) >= 0.99:
            cracked.append(index)

    return {
        "occupied_cells": occupied_cells,
        "segments": saved_segments,
        "found_collectibles": found_ids,
        "paint_color_index": paint_color_index,
        "cinematic_revealed": cinematic_revealed,
        "door_open": door_target_open,
        "popped_balloons": popped,
        "cracked_mirrors": cracked,
        "special_state": special_state.duplicate(true),
    }

func restore_state(state: Dictionary) -> bool:
    if size.x <= 1.0 or size.y <= 1.0:
        return false

    segments.clear()
    occupied.fill(0)
    occupied_count = 0
    drawing = false

    var raw_cells: Variant = state.get("occupied_cells", [])
    if raw_cells is Array:
        for value in raw_cells:
            var index: int = int(value)
            if index >= 0 and index < occupied.size() and occupied[index] == 0:
                occupied[index] = 1
                occupied_count += 1

    var reference: float = maxf(1.0, minf(size.x, size.y))
    var raw_segments: Variant = state.get("segments", [])
    if raw_segments is Array:
        for value in raw_segments:
            if not value is Dictionary:
                continue
            var saved: Dictionary = value
            var raw_from: Variant = saved.get("from", [])
            var raw_to: Variant = saved.get("to", [])
            if not raw_from is Array or raw_from.size() != 2:
                continue
            if not raw_to is Array or raw_to.size() != 2:
                continue
            segments.append({
                "from": Vector2(float(raw_from[0]) * size.x, float(raw_from[1]) * size.y),
                "to": Vector2(float(raw_to[0]) * size.x, float(raw_to[1]) * size.y),
                "width": clampf(float(saved.get("width", 0.05)) * reference, 8.0, 104.0),
                "color": Color.from_string(str(saved.get("color", "72afffb8")), Color("72afffb8")),
                "profile": str(saved.get("profile", cached_brush_profile)),
                "seed": int(saved.get("seed", segments.size())),
                "speed": clampf(float(saved.get("speed", 0.0)), 0.0, 1.0),
            })

    var found_lookup: Dictionary = {}
    var raw_found: Variant = state.get("found_collectibles", [])
    if raw_found is Array:
        for value in raw_found:
            found_lookup[str(value)] = true
    for item in collectibles:
        item["found"] = found_lookup.has(str(item.get("id", "")))

    var raw_popped: Variant = state.get("popped_balloons", [])
    if raw_popped is Array:
        for value in raw_popped:
            var balloon_index: int = int(value)
            if balloon_index >= 0 and balloon_index < balloons.size():
                balloons[balloon_index]["popped"] = true
    var raw_cracked: Variant = state.get("cracked_mirrors", [])
    if raw_cracked is Array:
        for value in raw_cracked:
            var mirror_index: int = int(value)
            if mirror_index >= 0 and mirror_index < mirrors.size():
                mirrors[mirror_index]["crack"] = 1.0

    paint_color_index = posmod(int(state.get("paint_color_index", 0)), palette.size())
    cinematic_revealed = bool(state.get("cinematic_revealed", false))
    door_target_open = bool(state.get("door_open", false))
    door_open_amount = 1.0 if door_target_open else 0.0
    var raw_special: Variant = state.get("special_state", {})
    special_state = raw_special.duplicate(true) if raw_special is Dictionary else {}
    special_last_hit_ms = {}
    stroke_serial = segments.size()
    visual_progress = get_coverage()
    coverage_changed.emit(visual_progress)
    queue_redraw()
    return true

func _gui_input(event: InputEvent) -> void:
    if not interaction_enabled:
        return

    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        drawing = event.pressed
        if drawing:
            previous_point = event.position
            _paint_point(event.position, 0.0)
        else:
            paint_color_index = (paint_color_index + 1) % palette.size()
        accept_event()
        return

    if event is InputEventMouseMotion and drawing and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
        _paint_line(previous_point, event.position)
        previous_point = event.position
        accept_event()
        return

    if event is InputEventScreenTouch:
        drawing = event.pressed
        if drawing:
            previous_point = event.position
            _paint_point(event.position, 0.0)
        else:
            paint_color_index = (paint_color_index + 1) % palette.size()
        accept_event()
        return

    if event is InputEventScreenDrag and drawing:
        _paint_line(previous_point, event.position)
        previous_point = event.position
        accept_event()

func _paint_line(from: Vector2, to: Vector2) -> void:
    var distance: float = from.distance_to(to)
    if distance < MIN_STROKE_DISTANCE:
        return
    var speed_normalized: float = clampf(distance / 90.0, 0.0, 1.0)
    var width: float = lerpf(cached_brush_max_width, cached_brush_min_width, speed_normalized)
    if calm_mode:
        width *= 1.06
    var color: Color = palette[paint_color_index]
    color.a = cached_brush_opacity * (0.92 if calm_mode else 1.0)
    stroke_serial += 1
    segments.append({
        "from": from,
        "to": to,
        "width": width,
        "color": color,
        "profile": cached_brush_profile,
        "seed": stroke_serial,
        "speed": speed_normalized,
    })
    if segments.size() > MAX_SEGMENTS:
        segments.pop_front()

    var coverage_changed_now: bool = false
    var steps: int = maxi(1, int(ceil(distance / maxf(width * 0.35, 8.0))))
    for index in range(steps + 1):
        var point: Vector2 = from.lerp(to, float(index) / float(steps))
        if _mark_coverage(point, width * 0.52):
            coverage_changed_now = true
        _check_collectibles(point, width * 0.76)
        _check_special_interactions(point, width * 0.72)

    if coverage_changed_now:
        visual_progress = get_coverage()
        coverage_changed.emit(visual_progress)
    paint_pulse.emit(speed_normalized)
    queue_redraw()

func _paint_point(point: Vector2, speed_normalized: float) -> void:
    var width: float = cached_brush_max_width * (1.02 if calm_mode else 0.92)
    var color: Color = palette[paint_color_index]
    color.a = cached_brush_opacity * 0.94
    stroke_serial += 1
    segments.append({
        "from": point,
        "to": point,
        "width": width,
        "color": color,
        "profile": cached_brush_profile,
        "seed": stroke_serial,
        "speed": speed_normalized,
    })
    if segments.size() > MAX_SEGMENTS:
        segments.pop_front()
    var coverage_changed_now: bool = _mark_coverage(point, width * 0.52)
    _check_collectibles(point, width)
    _check_special_interactions(point, width)
    if coverage_changed_now:
        visual_progress = get_coverage()
        coverage_changed.emit(visual_progress)
    paint_pulse.emit(speed_normalized)
    queue_redraw()

func _mark_coverage(point: Vector2, radius: float) -> bool:
    if size.x <= 1.0 or size.y <= 1.0:
        return false
    var changed: bool = false
    var center_x: int = int(clampf(point.x / size.x, 0.0, 0.999) * GRID_WIDTH)
    var center_y: int = int(clampf(point.y / size.y, 0.0, 0.999) * GRID_HEIGHT)
    var radius_x: int = maxi(1, int(ceil(radius / size.x * GRID_WIDTH)))
    var radius_y: int = maxi(1, int(ceil(radius / size.y * GRID_HEIGHT)))

    for y in range(maxi(0, center_y - radius_y), mini(GRID_HEIGHT, center_y + radius_y + 1)):
        for x in range(maxi(0, center_x - radius_x), mini(GRID_WIDTH, center_x + radius_x + 1)):
            var normalized_dx: float = float(x - center_x) / float(radius_x)
            var normalized_dy: float = float(y - center_y) / float(radius_y)
            if normalized_dx * normalized_dx + normalized_dy * normalized_dy > 1.0:
                continue
            var cell_index: int = y * GRID_WIDTH + x
            if occupied[cell_index] == 0:
                occupied[cell_index] = 1
                occupied_count += 1
                changed = true
    return changed

func _check_collectibles(point: Vector2, radius: float) -> void:
    for item in collectibles:
        if bool(item.get("found", false)):
            continue
        var raw_position: Variant = item.get("position", [0.5, 0.5])
        if not raw_position is Array or raw_position.size() != 2:
            continue
        var target: Vector2 = Vector2(float(raw_position[0]) * size.x, float(raw_position[1]) * size.y)
        if point.distance_to(target) <= radius + 24.0:
            item["found"] = true
            collectible_found.emit(item.duplicate(true))

func _check_special_interactions(point: Vector2, radius: float) -> void:
    if cached_interaction == "pop_balloons":
        for index in range(balloons.size()):
            var balloon: Dictionary = balloons[index]
            if bool(balloon.get("popped", false)):
                continue
            var position: Vector2 = balloon.get("position", Vector2.ZERO)
            var balloon_radius: float = float(balloon.get("radius", 24.0))
            if point.distance_to(position) <= radius + balloon_radius:
                balloons[index]["popped"] = true
                special_interaction.emit("balloon", index)
    elif cached_interaction == "crack_mirrors":
        for index in range(mirrors.size()):
            var mirror: Dictionary = mirrors[index]
            var rect: Rect2 = mirror.get("rect", Rect2())
            if rect.grow(radius).has_point(point) and _special_hit_allowed("mirror-%d" % index, 95):
                var old_crack: float = float(mirror.get("crack", 0.0))
                var new_crack: float = minf(1.0, old_crack + 0.34)
                mirrors[index]["crack"] = new_crack
                if old_crack < 0.99 and new_crack >= 0.99:
                    special_interaction.emit("mirror", index)
    elif cached_interaction == "toast_table":
        if point.distance_to(Vector2(size.x * 0.5, size.y * 0.64)) <= radius + size.x * 0.12:
            if not bool(special_state.get("toast", false)):
                special_state["toast"] = true
                special_interaction.emit("toast", 0)
    elif cached_interaction == "western_duel":
        if point.distance_to(Vector2(size.x * 0.72, size.y * 0.45)) <= radius + size.x * 0.12 and _special_hit_allowed("duel", 140):
            var duel_hits: int = int(special_state.get("duel_hits", 0)) + 1
            special_state["duel_hits"] = duel_hits
            if duel_hits == 4:
                special_interaction.emit("duel", 0)

func _draw() -> void:
    var base: Color = cached_base_color
    var floor: Color = cached_floor_color
    var accent: Color = cached_accent_color
    var secondary: Color = cached_secondary_color
    var style: String = cached_visual_style

    _draw_gradient_background(base)
    _draw_room_shell(base, floor, accent)
    var door_rect: Rect2 = _door_rect()

    match style:
        "uncertainty":
            _draw_uncertainty_scene(base, accent, secondary)
        "party":
            _draw_party_scene(base, accent, secondary)
        "unmasked":
            _draw_unmasked_scene(base, accent, secondary)
        "calling":
            _draw_calling_scene(base, accent, secondary)
        "seed":
            _draw_seed_scene(base, accent, secondary)
        "hybrid":
            _draw_hybrid_scene(base, accent, secondary)
        "technophobia":
            _draw_technophobia_scene(base, accent, secondary)
        "invaluable":
            _draw_invaluable_scene(base, accent, secondary)
        "ashes":
            _draw_ashes_scene(base, accent, secondary)
        "waves":
            _draw_waves_scene(base, accent, secondary)
        "rise":
            _draw_rise_scene(base, accent, secondary)
        _:
            _draw_uncertainty_scene(base, accent, secondary)

    _render_comic_finish(base, accent, secondary, style)
    _draw_door(base, accent, door_rect)
    _draw_unrevealed_vss(base, accent, secondary, style)
    _draw_paint_segments()
    _render_brush_cursor(accent)
    _draw_collectibles(base, accent)

func _draw_gradient_background(base: Color) -> void:
    var bands: int = 30
    for index in range(bands):
        var t: float = float(index) / float(bands - 1)
        var band_color: Color = base.lightened(t * 0.11)
        draw_rect(Rect2(0.0, size.y * t, size.x, size.y / float(bands) + 2.0), band_color)

func _draw_room_shell(base: Color, floor: Color, accent: Color) -> void:
    var ceiling_y: float = size.y * 0.16
    var horizon_y: float = size.y * 0.73
    var back_left: float = size.x * 0.12
    var back_right: float = size.x * 0.88
    draw_colored_polygon(PackedVector2Array([
        Vector2(0.0, 0.0), Vector2(size.x, 0.0),
        Vector2(back_right, ceiling_y), Vector2(back_left, ceiling_y)
    ]), base.lightened(0.05))
    draw_colored_polygon(PackedVector2Array([
        Vector2(0.0, 0.0), Vector2(back_left, ceiling_y),
        Vector2(back_left, horizon_y), Vector2(0.0, size.y)
    ]), base.darkened(0.09))
    draw_colored_polygon(PackedVector2Array([
        Vector2(size.x, 0.0), Vector2(back_right, ceiling_y),
        Vector2(back_right, horizon_y), Vector2(size.x, size.y)
    ]), base.darkened(0.14))
    draw_rect(Rect2(back_left, ceiling_y, back_right - back_left, horizon_y - ceiling_y), base.lightened(0.018))
    draw_colored_polygon(PackedVector2Array([
        Vector2(0.0, size.y), Vector2(size.x, size.y),
        Vector2(back_right, horizon_y), Vector2(back_left, horizon_y)
    ]), floor)
    var shell_ink: Color = Color(0.008, 0.012, 0.022, 0.52 + cached_ink_strength * 0.28)
    draw_line(Vector2(back_left, ceiling_y), Vector2(back_left, horizon_y), shell_ink, 3.0, true)
    draw_line(Vector2(back_right, ceiling_y), Vector2(back_right, horizon_y), shell_ink, 3.0, true)
    draw_line(Vector2(back_left, horizon_y), Vector2(back_right, horizon_y), Color(accent, 0.18), 3.0, true)
    draw_line(Vector2(0.0, size.y), Vector2(back_left, horizon_y), shell_ink, 3.0, true)
    draw_line(Vector2(size.x, size.y), Vector2(back_right, horizon_y), shell_ink, 3.0, true)
    for perspective in range(1, 5):
        var ratio: float = float(perspective) / 5.0
        var floor_y: float = lerpf(horizon_y, size.y, ratio)
        draw_line(Vector2(size.x * (0.12 - ratio * 0.10), floor_y), Vector2(size.x * (0.88 + ratio * 0.10), floor_y), Color(accent, 0.025 + ratio * 0.018), 1.5, true)

func _door_rect() -> Rect2:
    var door_width: float = size.x * 0.22
    var door_height: float = size.y * 0.36
    return Rect2(size.x * 0.5 - door_width * 0.5, size.y * 0.73 - door_height, door_width, door_height)

func _draw_door(base: Color, accent: Color, rect: Rect2) -> void:
    draw_rect(rect.grow(6.0), Color(accent, 0.24), false, 3.0)
    var half_width: float = rect.size.x * 0.5
    var travel: float = half_width * 0.92 * door_open_amount
    var left_rect: Rect2 = Rect2(rect.position.x - travel, rect.position.y, half_width, rect.size.y)
    var right_rect: Rect2 = Rect2(rect.position.x + half_width + travel, rect.position.y, half_width, rect.size.y)
    var door_ink: Color = Color(0.006, 0.010, 0.020, 0.78)
    draw_rect(left_rect, base.darkened(0.25))
    draw_rect(right_rect, base.darkened(0.29))
    draw_rect(left_rect, door_ink, false, 4.0)
    draw_rect(right_rect, door_ink, false, 4.0)
    draw_line(Vector2(left_rect.end.x, rect.position.y), Vector2(left_rect.end.x, rect.end.y), Color(accent, 0.52), 2.5)
    draw_line(Vector2(right_rect.position.x, rect.position.y), Vector2(right_rect.position.x, rect.end.y), Color(accent, 0.52), 2.5)
    for hatch in range(4):
        var hatch_y: float = rect.position.y + rect.size.y * (0.18 + float(hatch) * 0.18)
        draw_line(Vector2(left_rect.position.x + 8.0, hatch_y), Vector2(left_rect.end.x - 8.0, hatch_y - 16.0), Color(accent, 0.055), 2.0, true)
        draw_line(Vector2(right_rect.position.x + 8.0, hatch_y - 16.0), Vector2(right_rect.end.x - 8.0, hatch_y), Color(accent, 0.055), 2.0, true)
    if door_open_amount > 0.04:
        var opening: Rect2 = Rect2(rect.position.x + half_width * (1.0 - door_open_amount), rect.position.y, rect.size.x * door_open_amount, rect.size.y)
        draw_rect(opening, Color("020306"))
        draw_rect(opening.grow(-8.0), Color(accent, 0.05 + door_open_amount * 0.12))
    if door_open_amount < 0.82:
        draw_circle(left_rect.position + Vector2(left_rect.size.x * 0.82, left_rect.size.y * 0.56), 4.0, Color(accent, 0.58))

func _draw_uncertainty_scene(base: Color, accent: Color, secondary: Color) -> void:
    for wave_index in range(7):
        var points: PackedVector2Array = PackedVector2Array()
        var y_base: float = size.y * (0.28 + float(wave_index) * 0.075)
        for step in range(25):
            var x: float = size.x * float(step) / 24.0
            var y: float = y_base + sin(float(step) * 0.56 + motion_phase * 3.0 + float(wave_index)) * (8.0 + float(wave_index) * 1.8)
            points.append(Vector2(x, y))
        draw_polyline(points, Color(accent if wave_index % 2 == 0 else secondary, 0.10 + float(wave_index) * 0.012), 2.0, true)
    draw_circle(Vector2(size.x * 0.5, size.y * 0.22), size.x * 0.075, Color(accent, 0.06))

func _draw_party_scene(base: Color, accent: Color, secondary: Color) -> void:
    for index in range(balloons.size()):
        var balloon: Dictionary = balloons[index]
        if bool(balloon.get("popped", false)):
            var position: Vector2 = balloon.get("position", Vector2.ZERO)
            for shard in range(6):
                var angle: float = TAU * float(shard) / 6.0
                var end: Vector2 = position + Vector2(cos(angle), sin(angle)) * (18.0 + float(shard % 2) * 8.0)
                draw_line(position, end, Color(balloon.get("color", accent), 0.50), 2.0, true)
            continue
        var position: Vector2 = balloon.get("position", Vector2.ZERO)
        var radius: float = float(balloon.get("radius", 24.0))
        var color: Color = balloon.get("color", accent)
        var float_offset: float = sin(motion_phase * 4.0 + float(index)) * 5.0
        position.y += float_offset
        draw_circle(position, radius, Color(color, 0.74))
        draw_circle(position - Vector2(radius * 0.28, radius * 0.28), radius * 0.16, Color.WHITE * Color(1,1,1,0.35))
        draw_line(position + Vector2(0.0, radius), position + Vector2(sin(float(index)) * 8.0, radius + 48.0), Color(color.darkened(0.30), 0.52), 1.4, true)
    for confetti in range(32):
        var x: float = _hash01(confetti, 3, 17) * size.x
        var y: float = fmod(_hash01(confetti, 7, 31) * size.y + motion_phase * (5.0 + float(confetti % 4)), size.y)
        var c: Color = palette[confetti % palette.size()]
        draw_rect(Rect2(x, y, 3.0 + float(confetti % 3), 7.0), Color(c, 0.22))

func _draw_unmasked_scene(base: Color, accent: Color, secondary: Color) -> void:
    var mask_positions: Array[Vector2] = [
        Vector2(0.22,0.33), Vector2(0.38,0.28), Vector2(0.62,0.28),
        Vector2(0.78,0.33), Vector2(0.30,0.52), Vector2(0.70,0.52)
    ]
    for index in range(mask_positions.size()):
        var pos: Vector2 = Vector2(mask_positions[index].x * size.x, mask_positions[index].y * size.y)
        var fade: float = clampf(1.0 - get_normalized_progress() * 0.72, 0.18, 1.0)
        _draw_venetian_mask(pos, size.x * 0.065, accent if index % 2 == 0 else secondary, fade, index)
    draw_line(Vector2(size.x*0.17,size.y*0.18), Vector2(size.x*0.83,size.y*0.18), Color(accent,0.22), 3.0)
    for index in range(mask_positions.size()):
        var p: Vector2 = Vector2(mask_positions[index].x * size.x, mask_positions[index].y * size.y)
        draw_line(Vector2(p.x,size.y*0.18), Vector2(p.x,p.y-size.x*0.05), Color(accent,0.12), 1.0)

func _draw_venetian_mask(center: Vector2, radius: float, color: Color, alpha: float, seed: int) -> void:
    var outline: PackedVector2Array = PackedVector2Array([
        center + Vector2(-radius, -radius*0.18),
        center + Vector2(-radius*0.65, radius*0.55),
        center + Vector2(0.0, radius*0.78),
        center + Vector2(radius*0.65, radius*0.55),
        center + Vector2(radius, -radius*0.18),
        center + Vector2(radius*0.52, -radius*0.62),
        center + Vector2(0.0, -radius*0.42),
        center + Vector2(-radius*0.52, -radius*0.62),
    ])
    draw_colored_polygon(outline, Color(color, 0.26 * alpha))
    draw_polyline(PackedVector2Array(Array(outline) + [outline[0]]), Color(color.lightened(0.28), 0.72 * alpha), 2.0, true)
    draw_ellipse(center + Vector2(-radius*0.40, -radius*0.03), radius*0.22, radius*0.11, Color(base_color_for_mask(),0.86))
    draw_ellipse(center + Vector2(radius*0.40, -radius*0.03), radius*0.22, radius*0.11, Color(base_color_for_mask(),0.86))
    for jewel in range(5):
        var angle: float = -PI*0.78 + float(jewel)*PI*0.39
        var jp: Vector2 = center + Vector2(cos(angle),sin(angle))*radius*0.72
        draw_circle(jp, 2.3 + float((seed+jewel)%2), Color(color.lightened(0.45),0.62*alpha))

func base_color_for_mask() -> Color:
    return cached_base_color.darkened(0.35)

func _draw_calling_scene(base: Color, accent: Color, secondary: Color) -> void:
    var table: Rect2 = Rect2(size.x*0.17,size.y*0.54,size.x*0.66,size.y*0.18)
    draw_ellipse(table.get_center(), table.size.x*0.52, table.size.y*0.52, Color(accent,0.14))
    draw_ellipse(table.get_center(), table.size.x*0.48, table.size.y*0.43, Color(base.lightened(0.18),0.88))
    var guests: Array[Vector2] = [Vector2(0.23,0.47),Vector2(0.36,0.40),Vector2(0.50,0.38),Vector2(0.64,0.40),Vector2(0.77,0.47)]
    for index in range(guests.size()):
        var p: Vector2 = Vector2(guests[index].x*size.x,guests[index].y*size.y)
        draw_circle(p, size.x*0.027, Color(accent,0.32))
        draw_rect(Rect2(p.x-size.x*0.025,p.y+size.x*0.022,size.x*0.05,size.y*0.095), Color(accent.darkened(0.38),0.70))
    var toast_active: bool = bool(special_state.get("toast", false)) or get_normalized_progress() > 0.72
    for index in range(5):
        var x: float = size.x*(0.29+float(index)*0.105)
        var glass_y: float = size.y*(0.57 - (0.035 if toast_active else 0.0))
        draw_line(Vector2(x,glass_y),Vector2(x,glass_y+34.0),Color(accent,0.65),2.0)
        draw_arc(Vector2(x,glass_y),8.0,0.0,TAU,20,Color(accent,0.55),1.5,true)
        draw_circle(Vector2(x,glass_y+3.0),5.6,Color(secondary,0.76))
    draw_rect(Rect2(size.x*0.43,size.y*0.20,size.x*0.14,size.y*0.17),Color(accent,0.045))

func _draw_seed_scene(base: Color, accent: Color, secondary: Color) -> void:
    var growth: float = get_normalized_progress()
    var root: Vector2 = Vector2(size.x*0.50,size.y*0.73)
    draw_circle(root, 9.0 + growth*7.0, Color(secondary,0.70))
    var trunk_top: Vector2 = root.lerp(Vector2(size.x*0.50,size.y*0.31),growth)
    draw_line(root,trunk_top,Color(accent.darkened(0.36),0.88),7.0+growth*8.0,true)
    if growth > 0.18:
        for branch in range(8):
            var t: float = 0.22 + float(branch%4)*0.16
            var start: Vector2 = root.lerp(trunk_top,t)
            var side: float = -1.0 if branch%2==0 else 1.0
            var length: float = size.x*(0.07+float(branch%3)*0.025)*smoothstep(0.18,0.75,growth)
            var end: Vector2 = start + Vector2(side*length,-length*(0.46+float(branch%2)*0.16))
            draw_line(start,end,Color(accent.darkened(0.28),0.76),4.0,true)
            if growth > 0.48:
                draw_circle(end,10.0+growth*12.0,Color(accent,0.14+growth*0.16))
    if growth > 0.65:
        for leaf in range(24):
            var angle: float = TAU*float(leaf)/24.0
            var radius: float = size.x*(0.09+_hash01(leaf,3,8)*0.10)*growth
            var p: Vector2 = trunk_top + Vector2(cos(angle)*radius,sin(angle)*radius*0.62)
            draw_circle(p,5.0+_hash01(leaf,9,2)*6.0,Color(accent if leaf%2==0 else secondary,0.24))
    for root_index in range(7):
        var angle: float = PI*0.10 + float(root_index)*PI*0.13
        var end: Vector2 = root + Vector2(cos(angle)*size.x*0.18,sin(angle)*size.y*0.12)*growth
        draw_line(root,end,Color(secondary.darkened(0.42),0.33),2.0,true)

func _draw_hybrid_scene(base: Color, accent: Color, secondary: Color) -> void:
    var horizon: float = size.y*0.61
    draw_circle(Vector2(size.x*0.22,size.y*0.30),size.x*0.11,Color(accent,0.12))
    for building in range(5):
        var bx: float = size.x*(0.04+float(building)*0.19)
        var bh: float = size.y*(0.17+float(building%3)*0.045)
        draw_rect(Rect2(bx,horizon-bh,size.x*0.15,bh),Color(base.darkened(0.17),0.92))
        draw_rect(Rect2(bx+size.x*0.025,horizon-bh+18.0,size.x*0.10,6.0),Color(accent,0.10))
    draw_colored_polygon(PackedVector2Array([Vector2(size.x*0.34,size.y),Vector2(size.x*0.66,size.y),Vector2(size.x*0.54,horizon),Vector2(size.x*0.46,horizon)]),Color(accent,0.055))
    var opponent: Vector2 = Vector2(size.x*0.72,size.y*0.48)
    var hits: float = minf(1.0,float(int(special_state.get("duel_hits",0)))/8.0 + get_normalized_progress()*0.58)
    var alpha: float = 0.72*(1.0-hits*0.78)
    draw_circle(opponent-Vector2(0.0,size.x*0.055),size.x*0.035,Color(secondary,alpha))
    draw_rect(Rect2(opponent.x-size.x*0.035,opponent.y-size.x*0.02,size.x*0.07,size.y*0.17),Color(secondary.darkened(0.36),alpha))
    draw_line(opponent+Vector2(-size.x*0.03,size.y*0.17),opponent+Vector2(-size.x*0.06,size.y*0.29),Color(secondary,alpha),5.0,true)
    draw_line(opponent+Vector2(size.x*0.03,size.y*0.17),opponent+Vector2(size.x*0.06,size.y*0.29),Color(secondary,alpha),5.0,true)
    draw_line(Vector2(size.x*0.66,opponent.y-size.x*0.095),Vector2(size.x*0.78,opponent.y-size.x*0.095),Color(secondary,alpha),7.0,true)
    for glitch in range(8):
        var gy: float = opponent.y-size.x*0.10+float(glitch)*size.y*0.027
        var shift: float = sin(motion_phase*4.0+float(glitch))*size.x*0.025*hits
        draw_rect(Rect2(opponent.x-size.x*0.055+shift,gy,size.x*0.11,3.0+float(glitch%3)),Color(accent,0.08+hits*0.20))
    var player: Vector2 = Vector2(size.x*0.27,size.y*0.52)
    draw_circle(player-Vector2(0.0,size.x*0.05),size.x*0.029,Color(accent,0.52))
    draw_rect(Rect2(player.x-size.x*0.03,player.y-size.x*0.02,size.x*0.06,size.y*0.15),Color(accent.darkened(0.40),0.74))

func _draw_technophobia_scene(base: Color, accent: Color, secondary: Color) -> void:
    var repair: float = get_normalized_progress()
    var fault: float = 1.0-repair
    for monitor_index in range(7):
        var col: int = monitor_index%3
        var row: int = monitor_index/3
        var rect: Rect2 = Rect2(size.x*(0.16+float(col)*0.25),size.y*(0.22+float(row)*0.15),size.x*0.18,size.y*0.10)
        draw_rect(rect.grow(3.0),Color(accent,0.12),false,2.0)
        draw_rect(rect,Color(base.darkened(0.32),0.88))
        for line_index in range(4):
            var jitter: float = sin(motion_phase*8.0+float(monitor_index*3+line_index))*size.x*0.018*fault
            draw_rect(Rect2(rect.position.x+9.0+jitter,rect.position.y+11.0+float(line_index)*13.0,rect.size.x*(0.25+_hash01(monitor_index,line_index,8)*0.55),2.0),Color(accent if line_index%2==0 else secondary,0.16+fault*0.22))
    for scan in range(22):
        var y: float = size.y*(0.17+float(scan)*0.027)
        var drift: float = sin(motion_phase*6.0+float(scan))*size.x*0.022*fault
        draw_rect(Rect2(size.x*0.08+drift,y,size.x*0.84,1.0+float(scan%2)),Color(accent,0.018+fault*0.035))
    if fault > 0.05:
        var font: Font = ThemeDB.fallback_font
        for z_index in range(8):
            var zx: float = size.x*(0.10+_hash01(z_index,4,1)*0.78)
            var zy: float = size.y*(0.20+_hash01(z_index,7,2)*0.48)
            var shift: float = sin(motion_phase*5.0+float(z_index))*9.0*fault
            draw_string(font,Vector2(zx+shift,zy),"ZZZ",HORIZONTAL_ALIGNMENT_LEFT,-1,13+z_index%3,Color(secondary,0.08+fault*0.20))
    for tear in range(9):
        var ty: float = size.y*(0.19+_hash01(tear,5,4)*0.48)
        var tx: float = size.x*(0.10+_hash01(tear,8,6)*0.55)
        var width: float = size.x*(0.12+_hash01(tear,2,9)*0.28)*fault
        var offset: float = sin(motion_phase*7.0+float(tear))*size.x*0.025*fault
        draw_rect(Rect2(tx+offset,ty,width,3.0+float(tear%4)),Color(secondary,0.06+fault*0.18))

func _draw_invaluable_scene(base: Color, accent: Color, secondary: Color) -> void:
    for index in range(mirrors.size()):
        var mirror: Dictionary = mirrors[index]
        var rect: Rect2 = mirror.get("rect",Rect2())
        var crack: float = float(mirror.get("crack",0.0))
        draw_rect(rect.grow(4.0),Color(secondary,0.14),false,2.0)
        draw_rect(rect,Color(accent,0.09+get_normalized_progress()*0.08))
        var reflection: Rect2 = rect.grow(-8.0)
        draw_rect(reflection,Color(base.lightened(0.26),0.28*(1.0-crack)))
        if crack > 0.02:
            var center: Vector2 = rect.get_center()
            for branch in range(7):
                var angle: float = TAU*float(branch)/7.0+float(index)*0.29
                var length: float = minf(rect.size.x,rect.size.y)*(0.30+float(branch%3)*0.12)*crack
                var end: Vector2 = center+Vector2(cos(angle),sin(angle))*length
                draw_line(center,end,Color(accent.lightened(0.30),0.56),1.5,true)
                if crack > 0.55:
                    var fork: Vector2 = end+Vector2(cos(angle+0.7),sin(angle+0.7))*length*0.32
                    draw_line(end,fork,Color(accent,0.38),1.0,true)
        if crack >= 0.99:
            draw_colored_polygon(PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.get_center()]),Color(base,0.72))
    for shard in range(19):
        if get_normalized_progress() < 0.35:
            break
        var x: float = size.x*(0.12+_hash01(shard,4,5)*0.76)
        var y: float = size.y*(0.76+_hash01(shard,2,6)*0.15)
        draw_colored_polygon(PackedVector2Array([Vector2(x,y),Vector2(x+8.0,y+2.0),Vector2(x+3.0,y-7.0)]),Color(accent,0.20))

func _draw_ashes_scene(base: Color, accent: Color, secondary: Color) -> void:
    var rebirth: float = get_normalized_progress()
    for ash in range(48):
        var x: float = _hash01(ash,2,7)*size.x
        var y: float = fmod(_hash01(ash,5,9)*size.y+motion_phase*(3.0+float(ash%5)),size.y)
        draw_circle(Vector2(x,y),1.0+_hash01(ash,8,3)*2.2,Color(base.lightened(0.48),0.14*(1.0-rebirth*0.55)))
    var center: Vector2 = Vector2(size.x*0.5,size.y*0.49)
    if rebirth > 0.12:
        var body_top: Vector2 = center-Vector2(0.0,size.y*0.12*rebirth)
        draw_line(center+Vector2(0.0,size.y*0.16),body_top,Color(accent,0.32+rebirth*0.42),8.0,true)
        var wing_span: float = size.x*0.34*rebirth
        var left_tip: Vector2 = center+Vector2(-wing_span,-size.y*0.11*rebirth)
        var right_tip: Vector2 = center+Vector2(wing_span,-size.y*0.11*rebirth)
        draw_colored_polygon(PackedVector2Array([body_top,left_tip,center-Vector2(size.x*0.05,0.0)]),Color(accent,0.12+rebirth*0.35))
        draw_colored_polygon(PackedVector2Array([body_top,right_tip,center+Vector2(size.x*0.05,0.0)]),Color(secondary,0.12+rebirth*0.35))
        draw_line(body_top,left_tip,Color(accent.lightened(0.24),0.52),3.0,true)
        draw_line(body_top,right_tip,Color(secondary.lightened(0.18),0.52),3.0,true)
        draw_circle(body_top-Vector2(0.0,14.0),7.0+rebirth*4.0,Color(secondary,0.62))
    for ember in range(26):
        var angle: float = TAU*float(ember)/26.0+motion_phase*0.8
        var radius: float = size.x*(0.04+_hash01(ember,6,2)*0.26)*rebirth
        var p: Vector2 = center+Vector2(cos(angle)*radius,sin(angle)*radius*0.62)
        draw_circle(p,1.4+float(ember%3),Color(accent if ember%2==0 else secondary,0.16+rebirth*0.32))

func _draw_waves_scene(base: Color, accent: Color, secondary: Color) -> void:
    var window: Rect2 = Rect2(size.x*0.14,size.y*0.21,size.x*0.22,size.y*0.24)
    draw_rect(window.grow(4.0),Color(accent,0.12),false,2.0)
    draw_rect(window,Color("0a1020"))
    draw_circle(window.position+Vector2(window.size.x*0.68,window.size.y*0.34),window.size.x*0.17,Color(accent,0.18))
    var bed: Rect2 = Rect2(size.x*0.28,size.y*0.52,size.x*0.50,size.y*0.22)
    draw_rect(bed,Color(secondary,0.16))
    draw_colored_polygon(PackedVector2Array([bed.position,Vector2(bed.end.x,bed.position.y),Vector2(bed.end.x+size.x*0.04,bed.end.y),Vector2(bed.position.x-size.x*0.04,bed.end.y)]),Color(accent,0.13))
    draw_rect(Rect2(bed.position.x+18.0,bed.position.y+12.0,bed.size.x*0.34,bed.size.y*0.32),Color(accent.lightened(0.28),0.14))
    draw_rect(Rect2(bed.position.x+bed.size.x*0.52,bed.position.y+12.0,bed.size.x*0.34,bed.size.y*0.32),Color(secondary.lightened(0.22),0.14))
    var first: Vector2 = Vector2(bed.position.x+bed.size.x*0.41,bed.position.y+bed.size.y*0.48)
    var second: Vector2 = Vector2(bed.position.x+bed.size.x*0.61,bed.position.y+bed.size.y*0.49)
    draw_circle(first-Vector2(0.0,18.0),11.0,Color(accent,0.36))
    draw_circle(second-Vector2(0.0,18.0),11.0,Color(secondary,0.36))
    draw_line(first,first+Vector2(-26.0,38.0),Color(accent,0.26),11.0,true)
    draw_line(second,second+Vector2(26.0,38.0),Color(secondary,0.26),11.0,true)
    for wave in range(5):
        var y: float = size.y*(0.34+float(wave)*0.08)
        var pts: PackedVector2Array = PackedVector2Array()
        for step in range(18):
            var x: float = size.x*float(step)/17.0
            pts.append(Vector2(x,y+sin(float(step)*0.7+motion_phase*2.0+float(wave))*5.0))
        draw_polyline(pts,Color(accent if wave%2==0 else secondary,0.045),1.4,true)

func _draw_rise_scene(base: Color, accent: Color, secondary: Color) -> void:
    var progress: float = get_normalized_progress()
    for column in range(7):
        var x: float = size.x*(0.13+float(column)*0.123)
        var height: float = size.y*(0.28+float(column%3)*0.04)
        draw_rect(Rect2(x,size.y*0.66-height,size.x*0.055,height),Color(accent,0.06+progress*0.07))
        draw_rect(Rect2(x-5.0,size.y*0.66-height-8.0,size.x*0.055+10.0,8.0),Color(accent,0.11))
    var light_center: Vector2 = Vector2(size.x*0.5,size.y*0.20)
    for ring in range(8):
        draw_arc(light_center,size.x*(0.05+float(ring)*0.035),PI*0.15,PI*0.85,48,Color(accent if ring%2==0 else secondary,0.05+progress*0.025),3.0,true)
    draw_colored_polygon(PackedVector2Array([Vector2(size.x*0.36,size.y*0.66),Vector2(size.x*0.64,size.y*0.66),Vector2(size.x*0.54,size.y*0.22),Vector2(size.x*0.46,size.y*0.22)]),Color(accent,0.035+progress*0.08))

func _render_comic_finish(base: Color, accent: Color, secondary: Color, style: String) -> void:
    var frame_color: Color = Color(0.008, 0.012, 0.024, 0.72 + cached_ink_strength * 0.20)
    draw_rect(Rect2(3.0, 3.0, maxf(0.0, size.x - 6.0), maxf(0.0, size.y - 6.0)), frame_color, false, COMIC_FRAME_WIDTH)
    draw_line(Vector2(size.x * 0.12, size.y * 0.16), Vector2(size.x * 0.88, size.y * 0.16), Color(accent, 0.18 + cached_ink_strength * 0.16), 2.0, true)

    var patch_alpha: float = cached_halftone_strength * (0.34 if calm_mode else 0.52)
    _render_halftone_patch(Vector2(size.x * 0.055, size.y * 0.205), 8, 5, maxf(8.0, size.x * 0.016), Color(accent, patch_alpha), 113)
    _render_halftone_patch(Vector2(size.x * 0.76, size.y * 0.69), 7, 5, maxf(8.0, size.x * 0.017), Color(secondary, patch_alpha * 0.78), 127)

    var caption_rect: Rect2 = Rect2(size.x * 0.055, size.y * 0.175, minf(size.x * 0.52, 360.0), 38.0)
    draw_rect(caption_rect.grow(3.0), frame_color)
    draw_rect(caption_rect, Color(accent.darkened(0.42), 0.90))
    draw_rect(Rect2(caption_rect.position, Vector2(7.0, caption_rect.size.y)), Color(accent, 0.92))
    var font: Font = ThemeDB.fallback_font
    draw_string(font, caption_rect.position + Vector2(18.0, 25.0), cached_caption.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, int(caption_rect.size.x - 24.0), 14, Color(0.95, 0.97, 1.0, 0.94))

    match style:
        "party":
            var party_center: Vector2 = Vector2(size.x * 0.50, size.y * 0.48)
            for ray in range(12):
                var ray_angle: float = TAU * float(ray) / 12.0
                draw_line(party_center + Vector2.from_angle(ray_angle) * size.x * 0.16, party_center + Vector2.from_angle(ray_angle) * size.x * 0.39, Color(accent if ray % 2 == 0 else secondary, 0.055), 3.0, true)
        "hybrid":
            var duel_target: Vector2 = Vector2(size.x * 0.72, size.y * 0.45)
            for speed_line in range(8):
                var edge: Vector2 = Vector2(0.0 if speed_line % 2 == 0 else size.x, size.y * (0.27 + float(speed_line) * 0.055))
                draw_line(edge, duel_target, Color(secondary, 0.035 + cached_ink_strength * 0.025), 2.0, true)
        "technophobia":
            for misregister in range(5):
                var y: float = size.y * (0.27 + float(misregister) * 0.095)
                var shift: float = sin(motion_phase * 7.0 + float(misregister)) * 12.0
                draw_line(Vector2(size.x * 0.10 + shift, y), Vector2(size.x * 0.90 + shift, y), Color(secondary, 0.055 + cached_ink_strength * 0.04), 2.0, true)
        "ashes", "rise":
            var radiant: Vector2 = Vector2(size.x * 0.50, size.y * 0.44)
            for ray in range(10):
                var ray_angle: float = TAU * float(ray) / 10.0 + motion_phase * 0.08
                draw_line(radiant + Vector2.from_angle(ray_angle) * size.x * 0.15, radiant + Vector2.from_angle(ray_angle) * size.x * 0.42, Color(accent, 0.035 + get_normalized_progress() * 0.035), 2.0, true)
        "waves", "uncertainty":
            for panel_wave in range(4):
                var wave_points: PackedVector2Array = PackedVector2Array()
                for step in range(15):
                    var x: float = size.x * float(step) / 14.0
                    var y: float = size.y * (0.78 + float(panel_wave) * 0.025) + sin(float(step) * 0.72 + motion_phase * 2.0 + float(panel_wave)) * 5.0
                    wave_points.append(Vector2(x, y))
                draw_polyline(wave_points, Color(accent if panel_wave % 2 == 0 else secondary, 0.05), 2.0, true)
        _:
            pass

func _render_halftone_patch(origin: Vector2, columns: int, rows: int, spacing: float, color: Color, seed: int) -> void:
    if cached_halftone_strength <= 0.01:
        return
    for row in range(rows):
        for column in range(columns):
            var visibility: float = _hash01(column, row, seed)
            if visibility < 0.24:
                continue
            var offset: Vector2 = Vector2(float(column) * spacing + float(row % 2) * spacing * 0.5, float(row) * spacing)
            var radius: float = maxf(1.0, spacing * (0.08 + visibility * 0.08))
            draw_circle(origin + offset, radius, Color(color, color.a * (0.56 + visibility * 0.44)))

func _draw_unrevealed_vss(base: Color, accent: Color, secondary: Color, style: String) -> void:
    if cinematic_revealed:
        return
    var cell_width: float = size.x / float(GRID_WIDTH)
    var cell_height: float = size.y / float(GRID_HEIGHT)
    var normalized: float = get_normalized_progress()
    var negative: Color = Color(1.0-base.r,1.0-base.g,1.0-base.b)
    var base_alpha: float = 0.30 if calm_mode else 0.43
    if style == "technophobia":
        base_alpha += 0.12
    elif style == "party":
        base_alpha -= 0.07

    # Merge adjacent covered cells into horizontal strips. The full-screen shader
    # still supplies fine grain, while CanvasItem draw calls drop dramatically.
    for y in range(GRID_HEIGHT):
        var run_start: int = -1
        for x in range(GRID_WIDTH + 1):
            var is_hidden: bool = false
            if x < GRID_WIDTH:
                is_hidden = occupied[y * GRID_WIDTH + x] == 0
            if is_hidden and run_start < 0:
                run_start = x
            elif not is_hidden and run_start >= 0:
                var run_length: int = x - run_start
                var noise: float = _hash01(run_start, y, int(motion_phase * 3.0))
                var slow: float = 0.84 + sin(motion_phase * 3.0 + float(y) * 0.19) * 0.09
                var tint: Color = negative.lerp(accent if y % 5 == 0 else secondary, 0.12 + noise * 0.08)
                var alpha: float = base_alpha * slow * (0.88 + noise * 0.14) * (1.0 - normalized * 0.18)
                var rect: Rect2 = Rect2(
                    float(run_start) * cell_width,
                    float(y) * cell_height,
                    float(run_length) * cell_width + 1.0,
                    cell_height + 1.0,
                )
                draw_rect(rect, Color(tint, alpha))
                var static_band: float = _hash01(y, int(motion_phase * 11.0), 137)
                if noise > 0.60:
                    draw_rect(Rect2(rect.position.x, rect.position.y + cell_height * static_band, rect.size.x, 1.0 + float(y % 2)), Color(1.0, 1.0, 1.0, 0.08 + noise * 0.05))
                if static_band > 0.84:
                    var spark_x: float = rect.position.x + rect.size.x * _hash01(run_start, y, 139)
                    draw_circle(Vector2(spark_x, rect.position.y + cell_height * 0.50), 1.4 + noise * 1.8, Color(accent.lightened(0.42), 0.16))
                run_start = -1

func _draw_paint_segments() -> void:
    for index in range(segments.size()):
        _render_brush_segment(segments[index], index)

func _render_brush_segment(segment: Dictionary, segment_index: int) -> void:
    var from_value: Variant = segment.get("from", Vector2.ZERO)
    var to_value: Variant = segment.get("to", Vector2.ZERO)
    var color_value: Variant = segment.get("color", Color("72afff"))
    var from: Vector2 = from_value if from_value is Vector2 else Vector2.ZERO
    var to: Vector2 = to_value if to_value is Vector2 else Vector2.ZERO
    var width: float = float(segment.get("width", 40.0))
    var color: Color = color_value if color_value is Color else Color("72afff")
    var profile: String = str(segment.get("profile", cached_brush_profile))
    var seed: int = int(segment.get("seed", segment_index))
    var speed: float = clampf(float(segment.get("speed", 0.0)), 0.0, 1.0)
    var delta: Vector2 = to - from
    var distance: float = delta.length()
    var angle: float = delta.angle() if distance > 0.5 else float(seed % 31) * 0.11
    var ink: Color = Color(0.012, 0.018, 0.03, color.a * cached_brush_outline * 0.72)

    if distance > 0.5:
        draw_line(from, to, ink, width * 1.10, true)
        draw_line(from, to, color, width * 0.88, true)
        var tangent: Vector2 = delta.normalized()
        var normal: Vector2 = Vector2(-tangent.y, tangent.x)
        var bristle_count: int = 2 if calm_mode else 3
        for bristle in range(bristle_count):
            var jitter: float = (_hash01(seed, bristle, 41) - 0.5) * width * cached_brush_texture * 0.72
            var taper: float = 0.08 + _hash01(seed, bristle, 57) * 0.10
            var streak_color: Color = color.lightened(0.12 + float(bristle) * 0.04)
            streak_color.a = color.a * (0.16 + cached_brush_texture * 0.22)
            draw_line(from + normal * jitter, to + normal * jitter * 0.55, streak_color, maxf(1.0, width * taper), true)

    var stamp_count: int = 1
    if distance > 0.5:
        stamp_count = clampi(int(ceil(distance / maxf(width * cached_brush_spacing, 10.0))) + 1, 2, MAX_BRUSH_STAMPS_PER_SEGMENT)
    for stamp_index in range(stamp_count):
        var ratio: float = 1.0 if stamp_count == 1 else float(stamp_index) / float(stamp_count - 1)
        var center: Vector2 = from.lerp(to, ratio)
        var stamp_seed: int = seed * 17 + stamp_index * 31
        var rotation_jitter: float = (_hash01(stamp_seed, 3, 71) - 0.5) * 0.34 * cached_brush_texture
        var scale_jitter: float = 0.88 + _hash01(stamp_seed, 5, 73) * 0.24
        _render_brush_stamp(center, width * scale_jitter, color, angle + rotation_jitter, profile, stamp_seed, speed)

func _render_brush_stamp(center: Vector2, width: float, color: Color, angle: float, profile: String, seed: int, speed: float) -> void:
    var outline_color: Color = Color(0.01, 0.015, 0.028, color.a * cached_brush_outline * 0.82)
    if profile == "glitch":
        var block_width: float = width * (0.72 + speed * 0.34)
        var block_height: float = maxf(4.0, width * 0.22)
        for block in range(3):
            var offset: Vector2 = Vector2(
                (_hash01(seed, block, 81) - 0.5) * width * 0.74,
                (_hash01(seed, block, 83) - 0.5) * width * 0.50,
            )
            var rect: Rect2 = Rect2(center + offset - Vector2(block_width, block_height) * 0.5, Vector2(block_width, block_height))
            draw_rect(rect.grow(maxf(1.0, width * 0.035)), outline_color)
            draw_rect(rect, Color(color, color.a * (0.60 + float(block) * 0.10)))
        return

    var points: PackedVector2Array = _brush_shape(center, width, angle, profile, seed)
    if points.size() < 3:
        draw_circle(center, width * 0.45, color)
        return
    draw_colored_polygon(points, outline_color)
    var inner: PackedVector2Array = PackedVector2Array()
    for point in points:
        inner.append(center + (point - center) * 0.86)
    draw_colored_polygon(inner, color)

    if profile == "confetti":
        for fleck in range(3):
            var fleck_angle: float = angle + float(fleck) * 2.1 + _hash01(seed, fleck, 89)
            var fleck_center: Vector2 = center + Vector2.from_angle(fleck_angle) * width * (0.38 + float(fleck) * 0.12)
            draw_rect(Rect2(fleck_center - Vector2(width * 0.06, width * 0.03), Vector2(width * 0.12, width * 0.06)), Color(color.lightened(0.18), color.a * 0.78))
    elif profile == "organic":
        var stem: Vector2 = Vector2.from_angle(angle) * width * 0.46
        for branch in range(2):
            var branch_angle: float = angle + (-0.65 if branch == 0 else 0.65)
            draw_line(center, center + stem * 0.45 + Vector2.from_angle(branch_angle) * width * 0.23, Color(color.lightened(0.14), color.a * 0.54), maxf(1.0, width * 0.045), true)
    elif profile == "ember":
        draw_circle(center - Vector2.from_angle(angle) * width * 0.08, width * 0.13, Color(color.lightened(0.34), color.a * 0.82))
    elif profile == "glass":
        draw_line(center - Vector2.from_angle(angle) * width * 0.35, center + Vector2.from_angle(angle) * width * 0.35, Color.WHITE, maxf(1.0, width * 0.035), true)
    elif profile == "water" or profile == "soft" or profile == "luminous":
        draw_arc(center, width * 0.43, angle - 1.35, angle + 1.35, 18, Color(color.lightened(0.28), color.a * 0.30), maxf(1.0, width * 0.045), true)

func _brush_shape(center: Vector2, width: float, angle: float, profile: String, seed: int) -> PackedVector2Array:
    var points: PackedVector2Array = PackedVector2Array()
    var point_count: int = 10
    var stretch: Vector2 = Vector2(0.52, 0.42)
    if profile == "ink" or profile == "dry_ink" or profile == "wine":
        point_count = 8
        stretch = Vector2(0.56, 0.26 if profile == "wine" else 0.34)
    elif profile == "confetti":
        point_count = 12
        stretch = Vector2(0.50, 0.50)
    elif profile == "organic":
        point_count = 9
        stretch = Vector2(0.58, 0.34)
    elif profile == "glass":
        point_count = 6
        stretch = Vector2(0.60, 0.30)
    elif profile == "ember":
        point_count = 9
        stretch = Vector2(0.64, 0.33)
    elif profile == "luminous":
        point_count = 12
        stretch = Vector2(0.48, 0.48)

    for index in range(point_count):
        var theta: float = TAU * float(index) / float(point_count)
        var radial: float = 0.84 + (_hash01(seed, index, 97) - 0.5) * cached_brush_texture * 0.44
        if profile == "confetti" and index % 2 == 1:
            radial *= 0.46
        if profile == "glass" and index % 2 == 1:
            radial *= 0.54
        if profile == "ember" and index == 0:
            radial *= 1.44
        var local: Vector2 = Vector2(cos(theta) * width * stretch.x, sin(theta) * width * stretch.y) * radial
        points.append(center + local.rotated(angle))
    return points

func _render_brush_cursor(accent: Color) -> void:
    if not drawing or not interaction_enabled:
        return
    var radius: float = cached_brush_max_width * 0.52
    var points: PackedVector2Array = PackedVector2Array()
    for index in range(14):
        var theta: float = TAU * float(index) / 14.0
        var jitter: float = 0.90 + (_hash01(stroke_serial, index, 103) - 0.5) * 0.16
        points.append(previous_point + Vector2.from_angle(theta) * radius * jitter)
    points.append(points[0])
    draw_polyline(points, Color(accent.lightened(0.30), 0.48), 1.5, true)

func _draw_collectibles(base: Color, accent: Color) -> void:
    var font: Font = ThemeDB.fallback_font
    for item in collectibles:
        var raw_position: Variant = item.get("position",[0.5,0.5])
        if not raw_position is Array or raw_position.size()!=2:
            continue
        var target: Vector2 = Vector2(float(raw_position[0])*size.x,float(raw_position[1])*size.y)
        if bool(item.get("found",false)):
            draw_circle(target,27.0,accent.darkened(0.18))
            draw_circle(target,20.0,Color(base,0.92))
            draw_arc(target,34.0,0.0,TAU,40,Color(accent,0.72),2.0,true)
            var symbol: String = str(item.get("symbol","✦"))
            draw_string(font,target-Vector2(7.0,-6.0),symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(accent.lightened(0.35),0.92))
        else:
            draw_circle(target,5.0,Color(accent,0.09))

func _build_balloons() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for index in range(BALLOON_COUNT):
        var x: float = size.x*(0.10+_hash01(index,3,11)*0.80) if size.x>1.0 else 720.0*(0.10+_hash01(index,3,11)*0.80)
        var y: float = size.y*(0.20+_hash01(index,7,13)*0.48) if size.y>1.0 else 1280.0*(0.20+_hash01(index,7,13)*0.48)
        var color: Color = palette[index%palette.size()] if not palette.is_empty() else Color("ffda63")
        result.append({"position":Vector2(x,y),"radius":18.0+_hash01(index,5,17)*13.0,"color":color,"popped":false})
    return result

func _build_mirrors() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var width: float = size.x if size.x>1.0 else 720.0
    var height: float = size.y if size.y>1.0 else 1280.0
    for index in range(MIRROR_COUNT):
        var col: int = index%4
        var row: int = index/4
        var rect: Rect2 = Rect2(width*(0.10+float(col)*0.205),height*(0.22+float(row)*0.25),width*0.145,height*0.19)
        result.append({"rect":rect,"crack":0.0})
    return result

func _on_resized() -> void:
    if size.x <= 1.0 or size.y <= 1.0:
        return
    var popped_lookup: Dictionary = {}
    for index in range(balloons.size()):
        if bool(balloons[index].get("popped", false)):
            popped_lookup[index] = true
    var crack_lookup: Dictionary = {}
    for index in range(mirrors.size()):
        crack_lookup[index] = float(mirrors[index].get("crack", 0.0))

    balloons = _build_balloons()
    for index in range(balloons.size()):
        if popped_lookup.has(index):
            balloons[index]["popped"] = true
    mirrors = _build_mirrors()
    for index in range(mirrors.size()):
        if crack_lookup.has(index):
            mirrors[index]["crack"] = float(crack_lookup[index])
    queue_redraw()

func _special_hit_allowed(key: String, cooldown_ms: int) -> bool:
    var now: int = Time.get_ticks_msec()
    var previous: int = int(special_last_hit_ms.get(key, -cooldown_ms))
    if now - previous < cooldown_ms:
        return false
    special_last_hit_ms[key] = now
    return true

func _hash01(x: int, y: int, seed: int) -> float:
    var value: int = x*73856093
    value = value ^ (y*19349663)
    value = value ^ (seed*83492791)
    value = abs(value%10000)
    return float(value)/10000.0
