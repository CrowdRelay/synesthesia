extends "res://scripts/rooms/behavior_base.gd"

const MIRRORS: Array[Vector2] = [Vector2(0.22, 0.35), Vector2(0.50, 0.29), Vector2(0.78, 0.35), Vector2(0.38, 0.57), Vector2(0.64, 0.57)]

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["cracked"] = []
    state["shattered"] = []
    state["active_mirror"] = -1
    state["mirror_drag_start"] = Vector2.ZERO
    state["mirror_offsets"] = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]

func acts() -> Array[String]:
    return ["WEJDŹ MIĘDZY ODBICIA", "ROZBIJ CUDZĄ MIARĘ", "ZOSTAW WŁASNĄ WARTOŚĆ"]

func interaction_hint() -> String:
    var cracked: Array = state.get("cracked", [])
    var shattered: Array = state.get("shattered", [])
    if shattered.size() >= MIRRORS.size():
        return "ODBICIA STRACIŁY GŁOS · POSZUKAJ ECH"
    if cracked.size() > shattered.size():
        return "PĘKNIĘTA TAFLA NIE JEST JUŻ PRZYTWIERDZONA · ZRZUĆ JĄ RUCHEM"
    return "LUSTRA REAGUJĄ NA DOTYK · PUKNIJ W JEDNĄ TAFLĘ"

func hint_targets() -> Array[Dictionary]:
    var cracked: Array = state.get("cracked", [])
    var shattered: Array = state.get("shattered", [])
    var targets: Array[Dictionary] = []
    for index in range(MIRRORS.size()):
        if shattered.has(index):
            continue
        targets.append({"point": _art_offset_point(MIRRORS[index], MIRRORS[index] + _mirror_offset(index)), "kind": "swipe" if cracked.has(index) else "tap", "radius": 0.09})
        if targets.size() >= 3:
            break
    return targets

func captures_pointer_at(point_norm: Vector2) -> bool:
    return _mirror_near(point_norm, 0.14, true) >= 0 or int(state.get("active_mirror", -1)) >= 0

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#BDD9FF")), Color("bdd9ff"))
    var cracked: Array = state.get("cracked", [])
    var shattered: Array = state.get("shattered", [])
    var cinematic_t: float = cinematic_time()
    for index in range(MIRRORS.size()):
        var mirror_norm: Vector2 = _art_offset_point(MIRRORS[index], MIRRORS[index] + _mirror_offset(index))
        var center: Vector2 = Vector2(mirror_norm.x * viewport_size.x, mirror_norm.y * viewport_size.y)
        if cinematic_active() or shattered.has(index):
            var burst: float = minf(cinematic_t if cinematic_active() else 0.82, 1.6)
            for shard in range(10):
                var angle: float = float(shard) * TAU / 10.0 + float(index) * 0.41
                var speed: float = 48.0 + float((shard * 17 + index * 11) % 64)
                var distance: float = burst * speed
                var gravity: float = 54.0 * burst * burst
                var p: Vector2 = center + Vector2.from_angle(angle) * distance + Vector2(0.0, gravity)
                var tangent: Vector2 = Vector2.from_angle(angle + 0.7) * (6.0 + float(shard % 4) * 2.0)
                var alpha: float = clampf(1.0 - burst / 1.8, 0.0, 1.0)
                canvas.draw_line(p - tangent, p + tangent, Color(accent, 0.38 * alpha), 1.2)
            continue
        var rect: Rect2 = Rect2(center - Vector2(34.0, 58.0), Vector2(68.0, 116.0))
        var edge_alpha := 0.08 + progress * 0.08 + float(assist_level) * 0.035
        canvas.draw_rect(rect, Color(accent, edge_alpha), false, 1.4 + float(assist_level) * 0.12)
        var sweep: float = fmod(phase * 0.16 + float(index) * 0.21, 1.0)
        var sweep_x: float = lerpf(rect.position.x - 8.0, rect.end.x + 8.0, sweep)
        canvas.draw_line(Vector2(sweep_x - 8.0, rect.position.y + 7.0), Vector2(sweep_x + 10.0, rect.end.y - 7.0), Color(Color.WHITE, 0.025 + progress * 0.045), 1.0)
        if assist_level > 0 and not cracked.has(index):
            var glint_x := rect.position.x + rect.size.x * (0.30 + 0.12 * sin(float(index) * 1.7))
            canvas.draw_line(Vector2(glint_x, rect.position.y + 12.0), Vector2(glint_x + 14.0, rect.end.y - 16.0), Color(Color.WHITE, 0.035 * float(assist_level)), 1.0)
        if cracked.has(index):
            for branch in range(8):
                var angle: float = float(branch) * TAU / 8.0 + float(index) * 0.13
                canvas.draw_line(center, center + Vector2.from_angle(angle) * (34.0 + float(branch % 3) * 7.0), Color(Color.WHITE, 0.26), 1.0)

# Legacy contract: kind == "tap" remains accepted through tap/press union.
func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point: Vector2 = _gesture_point(gesture)
    var cracked: Array = state.get("cracked", [])
    var shattered: Array = state.get("shattered", [])
    # Resolve against live (non-shattered) mirrors only: a shattered pane that
    # kept a drag offset must not shadow its living neighbour, or clustered
    # mirrors become unwinnable — every gesture resolves to the dead pane and
    # is dropped by the shattered guard.
    var index: int = _mirror_near(point, 0.12, true)
    if kind in ["tap", "press"] and index >= 0 and not shattered.has(index):
        if kind == "press":
            state["active_mirror"] = index
            state["mirror_drag_start"] = point
        if not cracked.has(index):
            cracked.append(index)
            state["cracked"] = cracked
            return [_interaction_event("mirror", index, "Pierwsza rysa — teraz możesz zrzucić taflę", MIRRORS[index], 0.09, 0.88)]
    if kind == "drag":
        var active := int(state.get("active_mirror", -1))
        if active >= 0 and active < MIRRORS.size() and cracked.has(active) and not shattered.has(active):
            var delta_value: Variant = gesture.get("delta", Vector2.ZERO)
            var delta: Vector2 = delta_value if delta_value is Vector2 else Vector2.ZERO
            _shift_mirror(active, delta * 0.44)
    if kind == "release":
        var active := int(state.get("active_mirror", -1))
        var start_value: Variant = state.get("mirror_drag_start", point)
        var start_point: Vector2 = start_value if start_value is Vector2 else point
        state["active_mirror"] = -1
        var displaced: float = _mirror_offset(active).length() if active >= 0 else 0.0
        if active >= 0 and active < MIRRORS.size() and cracked.has(active) and not shattered.has(active) and (point.distance_to(start_point) >= 0.10 or displaced >= 0.052):
            shattered.append(active)
            state["shattered"] = shattered
            _set_mirror_offset(active, Vector2.ZERO)
            return [_interaction_event("mirror", active + 20, "Tafla zeszła ze ściany — miara została bez głosu", MIRRORS[active] + _mirror_offset(active), 0.13, 0.98)]
        if active >= 0 and active < MIRRORS.size():
            _set_mirror_offset(active, _mirror_offset(active) * 0.22)
    if kind == "swipe":
        var start_point: Vector2 = _gesture_start(gesture)
        for candidate in range(MIRRORS.size()):
            if shattered.has(candidate) or not cracked.has(candidate):
                continue
            if _distance_to_segment(MIRRORS[candidate], start_point, point) <= 0.12:
                shattered.append(candidate)
                state["shattered"] = shattered
                _set_mirror_offset(candidate, Vector2.ZERO)
                return [_interaction_event("mirror", candidate + 20, "Tafla zeszła ze ściany — miara została bez głosu", MIRRORS[candidate], 0.13, 0.98)]
    return []

func mechanic_progress() -> float:
    var cracked: Array = state.get("cracked", [])
    var shattered: Array = state.get("shattered", [])
    var score := float(cracked.size()) * 0.42 + float(shattered.size()) * 0.58
    return clampf(score / float(MIRRORS.size()), 0.0, 1.0)

func on_paint(point_norm: Vector2, radius_norm: float, _progress: float) -> Array[Dictionary]:
    var cracked: Array = state.get("cracked", [])
    for index in range(MIRRORS.size()):
        if cracked.has(index):
            continue
        if _near(point_norm, MIRRORS[index], radius_norm + 0.09):
            cracked.append(index)
            state["cracked"] = cracked
            return [_interaction_event("mirror", index, "Tafla pękła — odbicie traci władzę", MIRRORS[index], 0.075, 0.82)]
    return []

func _mirror_near(point: Vector2, radius: float, ignore_shattered: bool = false) -> int:
    # Nearest match wins, not first index: mirrors cluster (0.22/0.50/0.78) and
    # drag offsets move them around, so a first-hit scan can resolve to a far
    # pane that merely happens to sit earlier in the array.
    var shattered: Array = state.get("shattered", []) if ignore_shattered else []
    var best := -1
    var best_distance := INF
    for index in range(MIRRORS.size()):
        if shattered.has(index):
            continue
        var placed: Vector2 = MIRRORS[index] + _mirror_offset(index)
        if _near(point, placed, radius):
            var distance := minf(
                point.distance_squared_to(placed),
                point.distance_squared_to(_art_point(placed)),
            )
            if distance < best_distance:
                best_distance = distance
                best = index
    return best

func _shift_mirror(index: int, delta: Vector2) -> void:
    var current := _mirror_offset(index) + delta
    current.x = clampf(current.x, -0.10, 0.10)
    current.y = clampf(current.y, -0.075, 0.12)
    _set_mirror_offset(index, current)

func _set_mirror_offset(index: int, value: Vector2) -> void:
    var offsets: Array = state.get("mirror_offsets", [])
    if index < 0 or index >= offsets.size():
        return
    offsets[index] = [value.x, value.y]
    state["mirror_offsets"] = offsets

func _mirror_offset(index: int) -> Vector2:
    var offsets: Array = state.get("mirror_offsets", [])
    if index < 0 or index >= offsets.size():
        return Vector2.ZERO
    var raw: Variant = offsets[index]
    return Vector2(float(raw[0]), float(raw[1])) if raw is Array and raw.size() >= 2 else Vector2.ZERO
func restore_state(saved: Dictionary) -> void:
    super.restore_state(saved)
    var offsets: Array = state.get("mirror_offsets", [])
    if offsets.size() != MIRRORS.size():
        state["mirror_offsets"] = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
    # Heals saves captured while a shattered pane could keep its drag offset:
    # the displaced ghost shadowed living neighbours and soft-locked the room.
    var shattered: Array = state.get("shattered", [])
    offsets = state.get("mirror_offsets", [])
    for index in range(offsets.size()):
        if shattered.has(index):
            offsets[index] = [0.0, 0.0]
    if not state.has("active_mirror"):
        state["active_mirror"] = -1
    if not state.has("mirror_drag_start"):
        state["mirror_drag_start"] = Vector2.ZERO
