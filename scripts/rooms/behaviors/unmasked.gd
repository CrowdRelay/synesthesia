extends "res://scripts/rooms/behavior_base.gd"

const MASKS: Array[Vector2] = [Vector2(0.27, 0.31), Vector2(0.50, 0.24), Vector2(0.73, 0.32)]

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["cracks"] = [0.0, 0.0, 0.0]
    state["removed"] = []
    state["offsets"] = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]

func acts() -> Array[String]:
    return ["ZOBACZ MASKI", "PĘKNIJ CEREMONIĘ", "ZOSTAW TWARZ"]

func interaction_hint() -> String:
    return "PUKNIJ W MASKĘ · ZSUŃ JĄ ZE ŚCIANY"

func render(canvas, viewport_size: Vector2, progress: float, _phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#FFB970")), Color("ffb970"))
    var cracks: Array = state.get("cracks", [0.0, 0.0, 0.0])
    var removed: Array = state.get("removed", [])
    var cinematic_t: float = cinematic_time()
    for index in range(MASKS.size()):
        if removed.has(index) and not cinematic_active():
            continue
        var offset: Vector2 = _offset(index)
        var center: Vector2 = Vector2((MASKS[index].x + offset.x) * viewport_size.x, (MASKS[index].y + offset.y) * viewport_size.y)
        var radius: float = 27.0 + float(index) * 2.0
        canvas.draw_arc(center, radius, 0.08, PI - 0.08, 24, Color(accent, 0.13 + progress * 0.12), 2.2)
        canvas.draw_arc(center, radius * 0.72, PI + 0.15, TAU - 0.15, 20, Color(accent, 0.12), 1.7)
        var crack: float = float(cracks[index]) if index < cracks.size() else 0.0
        if crack > 0.0:
            for branch in range(5):
                var angle: float = float(branch) * 1.35 + 0.35
                canvas.draw_line(center, center + Vector2.from_angle(angle) * radius * crack, Color(Color.WHITE, 0.18 + crack * 0.24), 1.1)
        if cinematic_active():
            var eye_y: float = center.y - 4.0
            var eye_dx: float = 10.0 + float(index)
            var pulse: float = 0.70 + 0.30 * sin(cinematic_t * 4.0 + float(index) * 1.7)
            for side in [-1.0, 1.0]:
                var eye: Vector2 = Vector2(center.x + side * eye_dx, eye_y)
                canvas.draw_circle(eye, 8.0, Color(accent, 0.055 * pulse))
                canvas.draw_circle(eye, 2.4, Color(accent, 0.72 * pulse))
            if index != 1:
                var mouth_open: float = 2.0 + 5.0 * (0.5 + 0.5 * sin(cinematic_t * 1.7 + float(index) * 2.3))
                var mouth_center: Vector2 = center + Vector2(0.0, 13.0)
                canvas.draw_line(mouth_center + Vector2(-9.0, -mouth_open * 0.5), mouth_center + Vector2(9.0, mouth_open * 0.5), Color(Color.BLACK, 0.46), 2.0)
                canvas.draw_line(mouth_center + Vector2(-9.0, mouth_open * 0.5), mouth_center + Vector2(9.0, -mouth_open * 0.5), Color(Color.BLACK, 0.28), 1.4)

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point: Vector2 = _gesture_point(gesture)
    var index: int = _mask_near(point, 0.12)
    var cracks: Array = state.get("cracks", [0.0, 0.0, 0.0])
    var removed: Array = state.get("removed", [])
    if kind == "tap" and index >= 0 and not removed.has(index):
        var previous: float = float(cracks[index])
        cracks[index] = minf(1.0, previous + 0.50)
        state["cracks"] = cracks
        if previous < 0.5:
            return [_interaction_event("mask", index + 10, "Ornament pękł — rola przestaje być gładka", MASKS[index], 0.068, 0.80)]
    elif kind == "drag" and index >= 0 and float(cracks[index]) >= 0.45 and not removed.has(index):
        var delta_value: Variant = gesture.get("delta", Vector2.ZERO)
        var delta: Vector2 = delta_value if delta_value is Vector2 else Vector2.ZERO
        _shift_offset(index, delta * 0.72)
    elif kind == "swipe":
        var start: Vector2 = _gesture_start(gesture)
        for candidate in range(MASKS.size()):
            if removed.has(candidate) or float(cracks[candidate]) < 0.45:
                continue
            if _distance_to_segment(MASKS[candidate] + _offset(candidate), start, point) <= 0.11:
                removed.append(candidate)
                state["removed"] = removed
                return [_interaction_event("mask", candidate, "Maska zeszła ze ściany — została obecność", MASKS[candidate], 0.105, 0.94)]
    return []

func on_paint(point_norm: Vector2, radius_norm: float, _progress: float) -> Array[Dictionary]:
    var cracks: Array = state.get("cracks", [0.0, 0.0, 0.0])
    var removed: Array = state.get("removed", [])
    for index in range(MASKS.size()):
        if removed.has(index) or not _near(point_norm, MASKS[index] + _offset(index), radius_norm + 0.07):
            continue
        var previous: float = float(cracks[index])
        cracks[index] = minf(1.0, previous + 0.34)
        state["cracks"] = cracks
        if previous < 0.99 and float(cracks[index]) >= 0.99:
            return [_interaction_event("mask", index, "Maska pękła — została twarz", MASKS[index], 0.082, 0.88)]
    return []

func _mask_near(point: Vector2, radius: float) -> int:
    for index in range(MASKS.size()):
        if _near(point, MASKS[index] + _offset(index), radius):
            return index
    return -1

func _shift_offset(index: int, delta: Vector2) -> void:
    var offsets: Array = state.get("offsets", [])
    if index < 0 or index >= offsets.size():
        return
    var current: Vector2 = _pair_vec(offsets[index]) + delta
    current.x = clampf(current.x, -0.14, 0.14)
    current.y = clampf(current.y, -0.10, 0.16)
    offsets[index] = [current.x, current.y]
    state["offsets"] = offsets

func _offset(index: int) -> Vector2:
    var offsets: Array = state.get("offsets", [])
    return _pair_vec(offsets[index]) if index >= 0 and index < offsets.size() else Vector2.ZERO

func _pair_vec(value: Variant) -> Vector2:
    return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() >= 2 else Vector2.ZERO
