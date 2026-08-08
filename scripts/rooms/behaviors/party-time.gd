extends "res://scripts/rooms/behavior_base.gd"

const BALLOONS: Array[Vector2] = [
    Vector2(0.18, 0.30), Vector2(0.36, 0.22), Vector2(0.58, 0.28),
    Vector2(0.78, 0.20), Vector2(0.26, 0.48), Vector2(0.69, 0.50),
]

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["popped"] = []
    state["offsets"] = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
    state["velocities"] = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]

func acts() -> Array[String]:
    return ["WEJDŹ NA IMPREZĘ", "PRZEBIJ POWŁOKĘ", "ZRÓB KOLOROWY BAŁAGAN"]

func interaction_hint() -> String:
    return "DOTKNIJ · ODEPCHNIJ · PRZEBIJ"

func advance(delta: float) -> void:
    super.advance(delta)
    var offsets: Array = state.get("offsets", [])
    var velocities: Array = state.get("velocities", [])
    if offsets.size() != BALLOONS.size() or velocities.size() != BALLOONS.size():
        return
    for index in range(BALLOONS.size()):
        var offset: Vector2 = _pair_vec(offsets[index])
        var velocity: Vector2 = _pair_vec(velocities[index])
        offset += velocity * delta
        offset = offset.lerp(Vector2.ZERO, clampf(delta * 1.6, 0.0, 1.0))
        velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 3.1, 0.0, 1.0))
        offset.x = clampf(offset.x, -0.11, 0.11)
        offset.y = clampf(offset.y, -0.08, 0.10)
        offsets[index] = [offset.x, offset.y]
        velocities[index] = [velocity.x, velocity.y]
    state["offsets"] = offsets
    state["velocities"] = velocities

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#FFDB63")), Color("ffdb63"))
    var secondary: Color = Color.from_string(str(room_data.get("secondary_color", "#FF5EAA")), Color("ff5eaa"))
    var popped: Array = state.get("popped", [])
    var cinematic_t: float = cinematic_time()
    for index in range(BALLOONS.size()):
        var color: Color = accent if index % 2 == 0 else secondary
        var balloon_norm: Vector2 = BALLOONS[index] + _offset(index)
        var base: Vector2 = Vector2(balloon_norm.x * viewport_size.x, balloon_norm.y * viewport_size.y)
        if cinematic_active():
            var delay: float = float(index) * 0.12
            var fly_t: float = maxf(0.0, cinematic_t - delay)
            var rise: float = minf(viewport_size.y * 0.82, fly_t * (74.0 + float(index % 3) * 15.0))
            var center: Vector2 = base + Vector2(sin(fly_t * 2.1 + float(index)) * 18.0, -rise)
            var alpha: float = clampf(1.0 - maxf(0.0, center.y * -1.0) / 180.0, 0.0, 1.0)
            canvas.draw_circle(center, 22.0 + float(index % 3) * 2.0, Color(color, 0.035 * alpha))
            canvas.draw_circle(center, 13.0 + float(index % 3) * 2.0, Color(color, 0.25 * alpha))
            canvas.draw_line(center + Vector2(0.0, 14.0), center + Vector2(sin(float(index)) * 8.0, 43.0), Color(color, 0.18 * alpha), 1.2)
            continue
        if popped.has(index):
            continue
        var center: Vector2 = base + Vector2(0.0, sin(phase * 4.0 + float(index)) * 5.0)
        canvas.draw_circle(center, 21.0 + float(index % 3) * 2.0, Color(color, 0.035 + progress * 0.04))
        canvas.draw_circle(center, 13.0 + float(index % 3) * 2.0, Color(color, 0.20 + progress * 0.18))
        canvas.draw_line(center + Vector2(0.0, 14.0), center + Vector2(sin(float(index)) * 8.0, 45.0), Color(color, 0.18), 1.2)
    if cinematic_active():
        var glow: float = 0.08 + 0.05 * (0.5 + 0.5 * sin(cinematic_t * 2.0))
        canvas.draw_circle(viewport_size * Vector2(0.5, 0.22), viewport_size.x * 0.32, Color(accent, glow))

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point: Vector2 = _gesture_point(gesture)
    match kind:
        "tap":
            return _pop_near(point, 0.105, 1)
        "swipe":
            return _pop_segment(_gesture_start(gesture), point, 0.09, 4)
        "drag":
            _push_near(point, gesture)
    return []

func on_paint(point_norm: Vector2, radius_norm: float, _progress: float) -> Array[Dictionary]:
    return _pop_near(point_norm, radius_norm + 0.055, 1)

func _pop_near(point: Vector2, radius: float, limit: int) -> Array[Dictionary]:
    var events: Array[Dictionary] = []
    var popped: Array = state.get("popped", [])
    for index in range(BALLOONS.size()):
        if popped.has(index):
            continue
        var target: Vector2 = BALLOONS[index] + _offset(index)
        if _near(point, target, radius):
            popped.append(index)
            events.append(_interaction_event("balloon", index, "POP — powłoka puściła", target, 0.085, 0.90))
            if events.size() >= limit:
                break
    state["popped"] = popped
    return events

func _pop_segment(start: Vector2, finish: Vector2, radius: float, limit: int) -> Array[Dictionary]:
    var events: Array[Dictionary] = []
    var popped: Array = state.get("popped", [])
    for index in range(BALLOONS.size()):
        if popped.has(index):
            continue
        var target: Vector2 = BALLOONS[index] + _offset(index)
        if _distance_to_segment(target, start, finish) <= radius:
            popped.append(index)
            events.append(_interaction_event("balloon", index, "POP — jeden ruch, kilka pęknięć", target, 0.078, 0.88))
            if events.size() >= limit:
                break
    state["popped"] = popped
    return events

func _push_near(point: Vector2, gesture: Dictionary) -> void:
    var offsets: Array = state.get("offsets", [])
    var velocities: Array = state.get("velocities", [])
    var delta_value: Variant = gesture.get("delta", Vector2.ZERO)
    var drag_delta: Vector2 = delta_value if delta_value is Vector2 else Vector2.ZERO
    if offsets.size() != BALLOONS.size() or velocities.size() != BALLOONS.size():
        return
    var popped: Array = state.get("popped", [])
    for index in range(BALLOONS.size()):
        if popped.has(index):
            continue
        var target: Vector2 = BALLOONS[index] + _pair_vec(offsets[index])
        if not _near(point, target, 0.14):
            continue
        var away: Vector2 = target - point
        if away.length_squared() < 0.0001:
            away = -drag_delta
        var impulse: Vector2 = away.normalized() * 0.13 + drag_delta * 3.4
        var velocity: Vector2 = _pair_vec(velocities[index]) + impulse
        velocities[index] = [velocity.x, velocity.y]
    state["velocities"] = velocities

func _offset(index: int) -> Vector2:
    var offsets: Array = state.get("offsets", [])
    return _pair_vec(offsets[index]) if index >= 0 and index < offsets.size() else Vector2.ZERO

func _pair_vec(value: Variant) -> Vector2:
    return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() >= 2 else Vector2.ZERO
