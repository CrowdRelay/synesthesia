extends "res://scripts/rooms/behavior_base.gd"

const MASKS: Array[Vector2] = [Vector2(0.27, 0.31), Vector2(0.50, 0.24), Vector2(0.73, 0.32)]

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["cracks"] = [0.0, 0.0, 0.0]
    state["removed"] = []
    state["offsets"] = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
    state["active_mask"] = -1

func acts() -> Array[String]:
    return ["ZOBACZ MASKI", "PĘKNIJ CEREMONIĘ", "ZOSTAW TWARZ"]

func interaction_hint() -> String:
    var removed: Array = state.get("removed", [])
    if removed.size() >= MASKS.size():
        return "MASKI ZESZŁY · ZOSTAŁA OBECNOŚĆ"
    var cracks: Array = state.get("cracks", [0.0, 0.0, 0.0])
    for index in range(MASKS.size()):
        if not removed.has(index) and float(cracks[index]) >= 0.45:
            return "MASKA PĘKŁA · CHWYĆ JĄ I ZSUŃ ZE ŚCIANY"
    return "MASKI NIE SĄ TŁEM · DOTKNIJ JEDNEJ, ŻEBY PĘKŁA"

func hint_targets() -> Array[Dictionary]:
    var cracks: Array = state.get("cracks", [0.0, 0.0, 0.0])
    var removed: Array = state.get("removed", [])
    var targets: Array[Dictionary] = []
    for index in range(MASKS.size()):
        if removed.has(index):
            continue
        targets.append({
            "point": MASKS[index] + _offset(index),
            "kind": "drag" if float(cracks[index]) >= 0.45 else "tap",
            "radius": 0.10,
        })
    return targets

func captures_pointer_at(point_norm: Vector2) -> bool:
    return _mask_near(point_norm, 0.14) >= 0 or int(state.get("active_mask", -1)) >= 0

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
    var index: int = _mask_near(point, 0.13)
    var cracks: Array = state.get("cracks", [0.0, 0.0, 0.0])
    var removed: Array = state.get("removed", [])
    if kind in ["tap", "press"] and index >= 0 and not removed.has(index):
        if kind == "press":
            state["active_mask"] = index
        var previous: float = float(cracks[index])
        cracks[index] = minf(1.0, previous + (0.52 if kind == "tap" else 0.28))
        state["cracks"] = cracks
        if previous < 0.45 and float(cracks[index]) >= 0.45:
            return [_interaction_event("mask", index + 10, "Ornament pękł — teraz możesz zsunąć maskę", MASKS[index], 0.075, 0.84)]
    elif kind == "drag":
        var active := int(state.get("active_mask", -1))
        if active < 0:
            active = index
        if active >= 0 and active < MASKS.size() and float(cracks[active]) >= 0.45 and not removed.has(active):
            state["active_mask"] = active
            var delta_value: Variant = gesture.get("delta", Vector2.ZERO)
            var delta: Vector2 = delta_value if delta_value is Vector2 else Vector2.ZERO
            _shift_offset(active, delta * 0.88)
    elif kind == "release":
        var active := int(state.get("active_mask", -1))
        state["active_mask"] = -1
        if active >= 0 and active < MASKS.size() and not removed.has(active) and _offset(active).length() >= 0.065:
            removed.append(active)
            state["removed"] = removed
            return [_interaction_event("mask", active, "Maska zeszła ze ściany — została obecność", MASKS[active] + _offset(active), 0.115, 0.96)]
    elif kind == "swipe":
        var start_point: Vector2 = _gesture_start(gesture)
        for candidate in range(MASKS.size()):
            if removed.has(candidate) or float(cracks[candidate]) < 0.45:
                continue
            if _distance_to_segment(MASKS[candidate] + _offset(candidate), start_point, point) <= 0.12:
                removed.append(candidate)
                state["removed"] = removed
                state["active_mask"] = -1
                return [_interaction_event("mask", candidate, "Maska zeszła ze ściany — została obecność", MASKS[candidate], 0.115, 0.96)]
    return []

func mechanic_progress() -> float:
    var cracks: Array = state.get("cracks", [0.0, 0.0, 0.0])
    var removed: Array = state.get("removed", [])
    var score := 0.0
    for index in range(MASKS.size()):
        var crack := clampf(float(cracks[index]) if index < cracks.size() else 0.0, 0.0, 1.0)
        score += 1.0 if removed.has(index) else crack * 0.52
    return clampf(score / float(MASKS.size()), 0.0, 1.0)

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
