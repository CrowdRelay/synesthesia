extends "res://scripts/rooms/behavior_base.gd"

# Kept as BALLOONS for save/audio compatibility; visually they are now fragile
# sensory membranes integrated with the Signal world, not glossy party props.
const BALLOONS: Array[Vector2] = [
    Vector2(0.19, 0.31), Vector2(0.37, 0.23), Vector2(0.59, 0.29),
    Vector2(0.78, 0.22), Vector2(0.28, 0.49), Vector2(0.69, 0.51),
]

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["popped"] = []
    state["offsets"] = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
    state["velocities"] = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
    state["burst_ages"] = [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0]
    state["motion_active"] = false

func acts() -> Array[String]:
    return ["WEJDŹ W PRZECIĄŻENIE", "PRZERWIJ POWŁOKI", "ODZYSKAJ CISZĘ"]

func interaction_hint() -> String:
    var popped: Array = state.get("popped", [])
    if popped.is_empty():
        return "POWŁOKI DRŻĄ W PÓŁMROKU · DOTKNIJ JEDNEJ"
    if popped.size() < BALLOONS.size():
        return "SZUKAJ NASTĘPNYCH POWŁOK · TAPNIJ LUB PRZETNIJ SWIPE'EM"
    return "BODŹCE PUŚCIŁY · POSZUKAJ ECH W OPADAJĄCYM PYLE"

func hint_targets() -> Array[Dictionary]:
    var popped: Array = state.get("popped", [])
    var targets: Array[Dictionary] = []
    for index in range(BALLOONS.size()):
        if not popped.has(index):
            targets.append({"point": BALLOONS[index] + _offset(index), "kind": "tap", "radius": 0.085})
        if targets.size() >= 3:
            break
    return targets

func captures_pointer_at(point_norm: Vector2) -> bool:
    var popped: Array = state.get("popped", [])
    for index in range(BALLOONS.size()):
        if not popped.has(index) and _near(point_norm, BALLOONS[index] + _offset(index), 0.13):
            return true
    return false

func needs_tick() -> bool:
    if cinematic_active() or bool(state.get("motion_active", false)):
        return true
    var ages: Array = state.get("burst_ages", [])
    for age_value in ages:
        var age := float(age_value)
        if age >= 0.0 and age < 0.72:
            return true
    return false

func advance(delta: float) -> void:
    super.advance(delta)
    var ages: Array = state.get("burst_ages", [])
    for index in range(ages.size()):
        var age := float(ages[index])
        if age >= 0.0 and age < 0.72:
            ages[index] = age + delta
    state["burst_ages"] = ages

    if not bool(state.get("motion_active", false)):
        return
    var offsets: Array = state.get("offsets", [])
    var velocities: Array = state.get("velocities", [])
    if offsets.size() != BALLOONS.size() or velocities.size() != BALLOONS.size():
        return
    var still_moving := false
    for index in range(BALLOONS.size()):
        var offset := _pair_vec(offsets[index])
        var velocity := _pair_vec(velocities[index])
        offset += velocity * delta
        offset = offset.lerp(Vector2.ZERO, clampf(delta * 1.4, 0.0, 1.0))
        velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 3.0, 0.0, 1.0))
        offset.x = clampf(offset.x, -0.10, 0.10)
        offset.y = clampf(offset.y, -0.07, 0.09)
        if offset.length_squared() < 0.00000008 and velocity.length_squared() < 0.0000008:
            offset = Vector2.ZERO
            velocity = Vector2.ZERO
        else:
            still_moving = true
        offsets[index] = [offset.x, offset.y]
        velocities[index] = [velocity.x, velocity.y]
    state["offsets"] = offsets
    state["velocities"] = velocities
    state["motion_active"] = still_moving

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent := Color.from_string(str(room_data.get("accent_color", "#B77BFF")), Color("b77bff"))
    var secondary := Color.from_string(str(room_data.get("secondary_color", "#FF4F7A")), Color("ff4f7a"))
    var popped: Array = state.get("popped", [])
    var ages: Array = state.get("burst_ages", [])
    var cinematic_t := cinematic_time()

    for index in range(BALLOONS.size()):
        var color: Color = accent if index % 2 == 0 else secondary
        var membrane_norm := BALLOONS[index] + _offset(index)
        var base := Vector2(membrane_norm.x * viewport_size.x, membrane_norm.y * viewport_size.y)
        if cinematic_active() and not popped.has(index):
            var delay := float(index) * 0.10
            var fly_t := maxf(0.0, cinematic_t - delay)
            var rise := minf(viewport_size.y * 0.78, fly_t * (52.0 + float(index % 3) * 11.0))
            var center := base + Vector2(sin(fly_t * 1.7 + float(index)) * 13.0, -rise)
            _draw_membrane(canvas, center, color, 0.60, float(index), phase + fly_t)
            continue
        if not popped.has(index):
            var center := base + Vector2(
                sin(phase * 1.25 + float(index) * 1.1) * 3.4,
                sin(phase * 1.65 + float(index) * 0.8) * 4.2
            )
            _draw_membrane(canvas, center, color, 0.72 + progress * 0.08, float(index), phase)
        if index < ages.size():
            var age := float(ages[index])
            if age >= 0.0 and age < 0.72:
                _draw_burst(canvas, base, color, age, index)

    # Ambient ribbons and confetti dust: asynchronous, restrained.
    for index in range(12):
        var x := viewport_size.x * (0.08 + float(index) * 0.075)
        var y := viewport_size.y * (0.18 + fmod(float(index) * 0.13 + phase * (0.017 + float(index % 3) * 0.004), 0.66))
        var color := accent if index % 3 else secondary
        canvas.draw_line(Vector2(x, y), Vector2(x + sin(phase + index) * 5.0, y + 11.0), Color(color, 0.025 + progress * 0.018), 1.0)

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point := _gesture_point(gesture)
    match kind:
        "tap": return _pop_near(point, 0.105, 1)
        "swipe": return _pop_segment(_gesture_start(gesture), point, 0.09, 4)
        "drag": _push_near(point, gesture)
    return []

func mechanic_progress() -> float:
    var popped: Array = state.get("popped", [])
    return clampf(float(popped.size()) / float(BALLOONS.size()), 0.0, 1.0)

func on_paint(_point_norm: Vector2, _radius_norm: float, _progress: float) -> Array[Dictionary]:
    return []

func _draw_membrane(canvas, center: Vector2, color: Color, alpha_scale: float, seed: float, phase: float) -> void:
    var breathe := 0.5 + 0.5 * sin(phase * (1.05 + seed * 0.035) + seed * 1.23)
    var radius := 10.0 + fmod(seed, 3.0) * 1.7 + breathe * 1.4
    canvas.draw_arc(center, radius + 4.0, -2.72, 0.18, 22, Color(color, 0.060 * alpha_scale), 1.0)
    canvas.draw_arc(center, radius, -2.58, 0.46, 22, Color(color, 0.24 * alpha_scale), 1.25)
    canvas.draw_arc(center + Vector2(-1.5, -1.5), maxf(5.0, radius - 4.0), -2.30, -0.72, 14, Color(Color.WHITE, 0.050 * alpha_scale), 0.8)
    canvas.draw_arc(center + Vector2(0.0, 2.5), radius * 0.78, 0.55, 2.52, 16, Color(color, 0.075 * alpha_scale), 0.8)
    var tail := center + Vector2(0.0, radius * 0.72)
    var previous := tail
    for j in range(1, 6):
        var next := tail + Vector2(sin(seed + float(j) * 0.82 + phase * 0.33) * (2.0 + j * 0.45), float(j) * 7.0)
        canvas.draw_line(previous, next, Color(color, 0.070 * alpha_scale), 0.8)
        previous = next
    canvas.draw_line(center + Vector2(-3.0, -3.0), center + Vector2(3.0, 5.0), Color(color, 0.095 * alpha_scale), 0.8)

func _draw_burst(canvas, center: Vector2, color: Color, age: float, seed: int) -> void:
    var t := clampf(age / 0.72, 0.0, 1.0)
    var alpha := (1.0 - t) * 0.26
    for index in range(9):
        var angle := float(index) / 9.0 * TAU + float(seed) * 0.71
        var distance := lerpf(4.0, 42.0 + float(index % 3) * 7.0, t)
        var p := center + Vector2(cos(angle), sin(angle)) * distance
        var tangent := Vector2(-sin(angle), cos(angle))
        canvas.draw_line(p - tangent * 2.0, p + tangent * 3.0, Color(color, alpha), 1.0)
    canvas.draw_arc(center, 8.0 + t * 28.0, -2.7, 0.25, 24, Color(color, alpha * 0.75), 1.1)

func _pop_near(point: Vector2, radius: float, limit: int) -> Array[Dictionary]:
    var events: Array[Dictionary] = []
    var popped: Array = state.get("popped", [])
    for index in range(BALLOONS.size()):
        if popped.has(index): continue
        var target := BALLOONS[index] + _offset(index)
        if _near(point, target, radius):
            popped.append(index)
            _arm_burst(index)
            events.append(_interaction_event("balloon", index, "TRZASK — powłoka puściła", target, 0.085, 0.90))
            if events.size() >= limit: break
    state["popped"] = popped
    return events

func _pop_segment(start: Vector2, finish: Vector2, radius: float, limit: int) -> Array[Dictionary]:
    var events: Array[Dictionary] = []
    var popped: Array = state.get("popped", [])
    for index in range(BALLOONS.size()):
        if popped.has(index): continue
        var target := BALLOONS[index] + _offset(index)
        if _distance_to_segment(target, start, finish) <= radius:
            popped.append(index)
            _arm_burst(index)
            events.append(_interaction_event("balloon", index, "TRZASK — przeciążenie pękło", target, 0.078, 0.88))
            if events.size() >= limit: break
    state["popped"] = popped
    return events

func _arm_burst(index: int) -> void:
    var ages: Array = state.get("burst_ages", [])
    if index >= 0 and index < ages.size():
        ages[index] = 0.0
        state["burst_ages"] = ages

func _push_near(point: Vector2, gesture: Dictionary) -> void:
    var offsets: Array = state.get("offsets", [])
    var velocities: Array = state.get("velocities", [])
    var delta_value: Variant = gesture.get("delta", Vector2.ZERO)
    var drag_delta: Vector2 = delta_value if delta_value is Vector2 else Vector2.ZERO
    if offsets.size() != BALLOONS.size() or velocities.size() != BALLOONS.size(): return
    var popped: Array = state.get("popped", [])
    for index in range(BALLOONS.size()):
        if popped.has(index): continue
        var target := BALLOONS[index] + _pair_vec(offsets[index])
        if not _near(point, target, 0.14): continue
        var away := target - point
        if away.length_squared() < 0.0001: away = -drag_delta
        var impulse := away.normalized() * 0.11 + drag_delta * 3.1
        var velocity := _pair_vec(velocities[index]) + impulse
        velocities[index] = [velocity.x, velocity.y]
        state["motion_active"] = true
    state["velocities"] = velocities

func _offset(index: int) -> Vector2:
    var offsets: Array = state.get("offsets", [])
    return _pair_vec(offsets[index]) if index >= 0 and index < offsets.size() else Vector2.ZERO

func _pair_vec(value: Variant) -> Vector2:
    return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() >= 2 else Vector2.ZERO

func restore_state(saved: Dictionary) -> void:
    super.restore_state(saved)
    if not state.has("burst_ages"):
        state["burst_ages"] = [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0]
    var velocities: Array = state.get("velocities", [])
    var active := false
    for raw_velocity in velocities:
        if _pair_vec(raw_velocity).length_squared() >= 0.0000008:
            active = true
            break
    state["motion_active"] = bool(state.get("motion_active", false)) or active
