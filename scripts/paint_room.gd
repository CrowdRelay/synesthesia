extends Control
class_name SynesthesiaPaintRoom

signal coverage_changed(value: float)
signal collectible_found(item: Dictionary)
signal paint_pulse(speed_normalized: float)

const GRID_WIDTH := 24
const GRID_HEIGHT := 36
const MAX_SEGMENTS := 1400

var manifest_room: Dictionary = {}
var palette: Array[Color] = []
var collectibles: Array[Dictionary] = []
var segments: Array[Dictionary] = []
var occupied := PackedByteArray()
var occupied_count: int = 0
var drawing: bool = false
var previous_point := Vector2.ZERO
var paint_color_index: int = 0
var calm_mode: bool = true
var interaction_enabled: bool = true
var visual_progress: float = 0.0
var glitch_phase: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    clip_contents = true
    occupied.resize(GRID_WIDTH * GRID_HEIGHT)
    resized.connect(queue_redraw)
    set_process(true)

func _process(delta: float) -> void:
    if visual_progress < 0.06:
        return
    glitch_phase = fmod(glitch_phase + delta * (0.17 if calm_mode else 0.36), 1000.0)
    queue_redraw()

func configure(room_data: Dictionary, collectible_data: Array) -> void:
    manifest_room = room_data.duplicate(true)
    palette.clear()
    for raw_color in room_data.get("paint_palette", ["#72AFFF"]):
        palette.append(Color.from_string(str(raw_color), Color("72afff")))
    if palette.is_empty():
        palette.append(Color("72afff"))

    collectibles.clear()
    for source in collectible_data:
        var item: Dictionary = source.duplicate(true)
        item["found"] = false
        collectibles.append(item)
    queue_redraw()

func set_calm_mode(value: bool) -> void:
    calm_mode = value

func set_interaction_enabled(value: bool) -> void:
    interaction_enabled = value
    if not value:
        drawing = false

func reset_room() -> void:
    segments.clear()
    occupied.fill(0)
    occupied_count = 0
    paint_color_index = 0
    drawing = false
    visual_progress = 0.0
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
    return float(occupied_count) / float(GRID_WIDTH * GRID_HEIGHT)

func export_state() -> Dictionary:
    var occupied_cells: Array[int] = []
    for index in range(occupied.size()):
        if occupied[index] != 0:
            occupied_cells.append(index)

    var saved_segments: Array[Dictionary] = []
    if size.x > 1.0 and size.y > 1.0:
        var reference: float = maxf(1.0, minf(size.x, size.y))
        for segment in segments:
            var from: Vector2 = segment.get("from", Vector2.ZERO)
            var to: Vector2 = segment.get("to", Vector2.ZERO)
            var color: Color = segment.get("color", Color("72afff"))
            saved_segments.append({
                "from": [from.x / size.x, from.y / size.y],
                "to": [to.x / size.x, to.y / size.y],
                "width": float(segment.get("width", 40.0)) / reference,
                "color": color.to_html(true),
            })

    var found_ids: Array[String] = []
    for item in collectibles:
        if bool(item.get("found", false)):
            found_ids.append(str(item.get("id", "")))

    return {
        "occupied_cells": occupied_cells,
        "segments": saved_segments,
        "found_collectibles": found_ids,
        "paint_color_index": paint_color_index,
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
            if not raw_from is Array or raw_from.size() != 2 or not raw_to is Array or raw_to.size() != 2:
                continue
            segments.append({
                "from": Vector2(float(raw_from[0]) * size.x, float(raw_from[1]) * size.y),
                "to": Vector2(float(raw_to[0]) * size.x, float(raw_to[1]) * size.y),
                "width": clampf(float(saved.get("width", 0.05)) * reference, 8.0, 96.0),
                "color": Color.from_string(str(saved.get("color", "72afffb8")), Color("72afffb8")),
            })

    var found_lookup: Dictionary = {}
    var raw_found: Variant = state.get("found_collectibles", [])
    if raw_found is Array:
        for value in raw_found:
            found_lookup[str(value)] = true
    for item in collectibles:
        item["found"] = found_lookup.has(str(item.get("id", "")))

    paint_color_index = posmod(int(state.get("paint_color_index", 0)), palette.size())
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

    if event is InputEventScreenDrag:
        _paint_line(previous_point, event.position)
        previous_point = event.position
        accept_event()

func _paint_line(from: Vector2, to: Vector2) -> void:
    var distance := from.distance_to(to)
    var speed_normalized := clampf(distance / 90.0, 0.0, 1.0)
    var width := lerpf(54.0, 24.0, speed_normalized)
    if calm_mode:
        width *= 1.08
    var color := palette[paint_color_index]
    color.a = 0.72 if calm_mode else 0.82
    segments.append({"from": from, "to": to, "width": width, "color": color})
    if segments.size() > MAX_SEGMENTS:
        segments.pop_front()

    var steps := maxi(1, int(ceil(distance / maxf(width * 0.35, 8.0))))
    for index in range(steps + 1):
        var point := from.lerp(to, float(index) / float(steps))
        _mark_coverage(point, width * 0.52)
        _check_collectibles(point, width * 0.76)

    paint_pulse.emit(speed_normalized)
    queue_redraw()

func _paint_point(point: Vector2, speed_normalized: float) -> void:
    var width := 48.0 if calm_mode else 40.0
    var color := palette[paint_color_index]
    color.a = 0.74
    segments.append({"from": point, "to": point, "width": width, "color": color})
    if segments.size() > MAX_SEGMENTS:
        segments.pop_front()
    _mark_coverage(point, width * 0.52)
    _check_collectibles(point, width)
    paint_pulse.emit(speed_normalized)
    queue_redraw()

func _mark_coverage(point: Vector2, radius: float) -> void:
    if size.x <= 1.0 or size.y <= 1.0:
        return
    var center_x := int(clampf(point.x / size.x, 0.0, 0.999) * GRID_WIDTH)
    var center_y := int(clampf(point.y / size.y, 0.0, 0.999) * GRID_HEIGHT)
    var radius_x := maxi(1, int(ceil(radius / size.x * GRID_WIDTH)))
    var radius_y := maxi(1, int(ceil(radius / size.y * GRID_HEIGHT)))

    for y in range(maxi(0, center_y - radius_y), mini(GRID_HEIGHT, center_y + radius_y + 1)):
        for x in range(maxi(0, center_x - radius_x), mini(GRID_WIDTH, center_x + radius_x + 1)):
            var normalized_dx := float(x - center_x) / float(radius_x)
            var normalized_dy := float(y - center_y) / float(radius_y)
            if normalized_dx * normalized_dx + normalized_dy * normalized_dy > 1.0:
                continue
            var cell_index := y * GRID_WIDTH + x
            if occupied[cell_index] == 0:
                occupied[cell_index] = 1
                occupied_count += 1

    visual_progress = float(occupied_count) / float(GRID_WIDTH * GRID_HEIGHT)
    coverage_changed.emit(visual_progress)

func _check_collectibles(point: Vector2, radius: float) -> void:
    for item in collectibles:
        if bool(item.get("found", false)):
            continue
        var raw_position: Array = item.get("position", [0.5, 0.5])
        var target := Vector2(float(raw_position[0]) * size.x, float(raw_position[1]) * size.y)
        if point.distance_to(target) <= radius + 24.0:
            item["found"] = true
            collectible_found.emit(item.duplicate(true))

func _draw() -> void:
    var base := Color.from_string(str(manifest_room.get("base_color", "#101827")), Color("101827"))
    var floor := Color.from_string(str(manifest_room.get("floor_color", "#080c14")), Color("080c14"))
    var accent := Color.from_string(str(manifest_room.get("accent_color", "#71AFFF")), Color("71afff"))

    var bands := 28
    for index in range(bands):
        var t := float(index) / float(bands - 1)
        var band_color := base.lightened(t * 0.095)
        draw_rect(Rect2(0.0, size.y * t, size.x, size.y / float(bands) + 2.0), band_color)

    var ceiling_y := size.y * 0.17
    var horizon_y := size.y * 0.72
    var back_left := size.x * 0.14
    var back_right := size.x * 0.86

    # A quiet, slightly unreal clinical room built only from simple geometry.
    draw_colored_polygon(PackedVector2Array([
        Vector2(0.0, 0.0),
        Vector2(size.x, 0.0),
        Vector2(back_right, ceiling_y),
        Vector2(back_left, ceiling_y)
    ]), base.lightened(0.045))
    draw_colored_polygon(PackedVector2Array([
        Vector2(0.0, 0.0),
        Vector2(back_left, ceiling_y),
        Vector2(back_left, horizon_y),
        Vector2(0.0, size.y)
    ]), base.darkened(0.09))
    draw_colored_polygon(PackedVector2Array([
        Vector2(size.x, 0.0),
        Vector2(back_right, ceiling_y),
        Vector2(back_right, horizon_y),
        Vector2(size.x, size.y)
    ]), base.darkened(0.13))
    draw_rect(Rect2(back_left, ceiling_y, back_right - back_left, horizon_y - ceiling_y), base.lightened(0.02))
    draw_colored_polygon(PackedVector2Array([
        Vector2(0.0, size.y),
        Vector2(size.x, size.y),
        Vector2(back_right, horizon_y),
        Vector2(back_left, horizon_y)
    ]), floor)

    var vanishing := Vector2(size.x * 0.5, horizon_y)
    draw_line(Vector2(0.0, size.y), Vector2(back_left, horizon_y), accent.darkened(0.66), 2.0, true)
    draw_line(Vector2(size.x, size.y), Vector2(back_right, horizon_y), accent.darkened(0.66), 2.0, true)
    draw_line(Vector2(back_left, horizon_y), Vector2(back_right, horizon_y), accent.darkened(0.68), 2.0, true)
    draw_line(Vector2(back_left, ceiling_y), Vector2(back_left, horizon_y), accent.darkened(0.72), 2.0, true)
    draw_line(Vector2(back_right, ceiling_y), Vector2(back_right, horizon_y), accent.darkened(0.72), 2.0, true)

    # A door that may later lead to the next release. It is visual only in v0.1.
    var door_width := size.x * 0.22
    var door_height := size.y * 0.36
    var door_rect := Rect2(size.x * 0.5 - door_width * 0.5, horizon_y - door_height, door_width, door_height)
    draw_rect(door_rect.grow(5.0), accent.darkened(0.62))
    draw_rect(door_rect, base.darkened(0.23))
    draw_rect(Rect2(door_rect.position + Vector2(door_width * 0.14, door_height * 0.13), Vector2(door_width * 0.72, door_height * 0.20)), Color(accent, 0.10))
    draw_circle(door_rect.position + Vector2(door_width * 0.79, door_height * 0.56), 5.0, Color(accent, 0.58))

    # Soft ceiling fixture: no pulsing, flashing or strobe.
    var lamp_rect := Rect2(size.x * 0.34, size.y * 0.085, size.x * 0.32, 13.0)
    draw_rect(lamp_rect.grow(8.0), Color(accent, 0.035))
    draw_rect(lamp_rect, Color(accent.lightened(0.35), 0.30))

    _draw_technophobia_layer(base, accent, door_rect)

    # Sparse floor guides support depth without moving the camera.
    for guide in [0.18, 0.32, 0.68, 0.82]:
        var floor_x := size.x * float(guide)
        draw_line(Vector2(floor_x, size.y), vanishing, Color(accent, 0.08), 1.0, true)

    for segment in segments:
        var from: Vector2 = segment["from"]
        var to: Vector2 = segment["to"]
        var width: float = segment["width"]
        var color: Color = segment["color"]
        draw_line(from, to, color, width, true)
        draw_circle(from, width * 0.5, color)
        draw_circle(to, width * 0.5, color)
        draw_line(from, to, color.lightened(0.18), maxf(2.0, width * 0.11), true)

    for item in collectibles:
        var raw_position: Array = item.get("position", [0.5, 0.5])
        var target := Vector2(float(raw_position[0]) * size.x, float(raw_position[1]) * size.y)
        if bool(item.get("found", false)):
            draw_circle(target, 27.0, accent.darkened(0.18))
            draw_circle(target, 20.0, Color(base, 0.92))
            draw_arc(target, 34.0, 0.0, TAU, 40, Color(accent, 0.72), 2.0, true)
        else:
            draw_circle(target, 5.0, Color(accent, 0.09))

func _draw_technophobia_layer(base: Color, accent: Color, door_rect: Rect2) -> void:
    var anxiety := smoothstep(0.05, 0.72, visual_progress)
    if anxiety <= 0.0:
        return
    var calm_scale := 0.58 if calm_mode else 1.0
    var strength := anxiety * calm_scale
    var warning := Color("ff6680")

    # Slow scan lines and displaced fragments suggest an unstable interface.
    # Their opacity and movement are capped to avoid flashing or strobing.
    for index in range(11):
        var y := size.y * (0.18 + float(index) * 0.057)
        var drift := sin(glitch_phase * TAU + float(index) * 1.73) * size.x * 0.014 * strength
        var alpha := 0.018 + strength * (0.018 + float(index % 3) * 0.008)
        draw_rect(Rect2(size.x * 0.10 + drift, y, size.x * 0.80, 1.0 + float(index % 2)), Color(accent, alpha))

    var monitor := Rect2(size.x * 0.27, size.y * 0.245, size.x * 0.46, size.y * 0.155)
    draw_rect(monitor.grow(4.0), Color(accent, 0.035 + strength * 0.05), false, 2.0)
    draw_rect(monitor, Color(base.darkened(0.24), 0.68))
    for row in range(5):
        var row_y := monitor.position.y + 18.0 + float(row) * 18.0
        var width_factor := 0.28 + fmod(float(row) * 0.31 + visual_progress, 0.62)
        var row_shift := sin(glitch_phase * 2.1 + float(row)) * 9.0 * strength
        draw_rect(Rect2(monitor.position.x + 17.0 + row_shift, row_y, monitor.size.x * width_factor, 3.0), Color(accent, 0.12 + strength * 0.16))

    if visual_progress > 0.24:
        for index in range(5):
            var block_x := size.x * (0.15 + float(index) * 0.145)
            var block_y := size.y * (0.43 + float(index % 2) * 0.055)
            var shift := sin(glitch_phase * 1.4 + float(index) * 2.0) * 14.0 * strength
            draw_rect(Rect2(block_x + shift, block_y, size.x * 0.085, 5.0 + float(index % 3) * 3.0), Color(warning, 0.025 + strength * 0.055))

    # The door appears increasingly machine-read rather than physically open.
    var readout_y := door_rect.position.y + door_rect.size.y * 0.78
    for index in range(4):
        var x := door_rect.position.x + 12.0 + float(index) * door_rect.size.x * 0.20
        var height := door_rect.size.y * (0.04 + float(index % 2) * 0.025)
        draw_rect(Rect2(x, readout_y - height, 4.0, height), Color(accent, 0.12 + strength * 0.18))
