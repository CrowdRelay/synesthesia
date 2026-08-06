extends Control
class_name SynesthesiaPaintRoom

signal coverage_changed(value: float)
signal collectible_found(item: Dictionary)
signal paint_pulse(speed_normalized: float)

const GRID_WIDTH := 24
const GRID_HEIGHT := 36

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

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    clip_contents = true
    occupied.resize(GRID_WIDTH * GRID_HEIGHT)
    resized.connect(queue_redraw)

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
    for item in collectibles:
        item["found"] = false
    coverage_changed.emit(0.0)
    queue_redraw()

func get_found_count() -> int:
    var count := 0
    for item in collectibles:
        if bool(item.get("found", false)):
            count += 1
    return count

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

    coverage_changed.emit(float(occupied_count) / float(GRID_WIDTH * GRID_HEIGHT))

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
