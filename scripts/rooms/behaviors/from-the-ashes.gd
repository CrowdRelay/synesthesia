extends "res://scripts/rooms/behavior_base.gd"

const CENTER := Vector2(0.50, 0.52)

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["swirl"] = 0.0
    state["last_angle"] = 0.0
    state["has_angle"] = false
    state["phoenix"] = false

func acts() -> Array[String]:
    return ["ZBIERZ POPIÓŁ", "ZAKRĘĆ ŻAREM", "WYPUSĆ SKRZYDŁA"]

func interaction_hint() -> String:
    if bool(state.get("phoenix", false)):
        return "SKRZYDŁA SĄ W RUCHU · POSZUKAJ ECH W POPIELE"
    if float(state.get("swirl", 0.0)) >= 0.42:
        return "ŻAR PAMIĘTA KSZTAŁT · WYPROWADŹ RUCH W GÓRĘ LUB KRĄŻ DALEJ"
    return "POPIÓŁ REAGUJE W CENTRUM · ZAKRĘĆ PALCEM PO OKRĘGU"

func hint_targets() -> Array[Dictionary]:
    if bool(state.get("phoenix", false)):
        return []
    return [{"point": CENTER, "kind": "swirl" if float(state.get("swirl", 0.0)) < 0.42 else "drag_up", "radius": 0.18}]

func captures_pointer_at(point_norm: Vector2) -> bool:
    return not bool(state.get("phoenix", false)) and _near(point_norm, CENTER, 0.30)

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#FF9E58")), Color("ff9e58"))
    var cinematic_t: float = cinematic_time()
    var swirl: float = clampf(float(state.get("swirl", 0.0)), 0.0, 1.0)
    var center: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.48)
    var wing_span: float = 44.0 + maxf(progress, swirl * 0.82) * 178.0
    var lift: float = progress * 72.0
    if cinematic_active():
        lift += minf(cinematic_t * 74.0, viewport_size.y * 0.40)
        center.x += sin(cinematic_t * 1.35) * 18.0
        wing_span += sin(cinematic_t * 5.2) * 22.0
    for side in [-1.0, 1.0]:
        var points: PackedVector2Array = PackedVector2Array()
        points.append(center + Vector2(0.0, 38.0 - lift))
        points.append(center + Vector2(side * wing_span * 0.48, -18.0 - lift + sin(phase * 3.0) * 5.0))
        points.append(center + Vector2(side * wing_span, 24.0 - lift))
        canvas.draw_polyline(points, Color(accent, 0.12 + progress * 0.22), 2.0 + progress * 2.5, true)
    for index in range(10):
        var angle: float = phase * (1.4 + swirl * 2.4) + float(index) * TAU / 10.0
        var radius: float = 32.0 + swirl * 62.0 + float(index % 3) * 8.0
        canvas.draw_circle(center + Vector2.from_angle(angle) * radius, 1.5 + float(index % 2), Color(accent, 0.07 + swirl * 0.09))
    if cinematic_active():
        for index in range(18):
            var seed: float = float(index) * 0.83
            var dust_y: float = center.y + 120.0 - fmod(cinematic_t * (34.0 + float(index % 5) * 7.0) + seed * 91.0, 210.0)
            var dust_x: float = center.x + sin(cinematic_t * 2.0 + seed) * (42.0 + float(index % 4) * 14.0)
            canvas.draw_circle(Vector2(dust_x, dust_y), 1.0 + float(index % 3), Color(accent, 0.08))

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point: Vector2 = _gesture_point(gesture)
    if kind == "drag" and point.distance_to(CENTER) < 0.28:
        var angle: float = (point - CENTER).angle()
        if bool(state.get("has_angle", false)):
            var previous: float = float(state.get("last_angle", angle))
            var diff: float = absf(wrapf(angle - previous, -PI, PI))
            var swirl: float = clampf(float(state.get("swirl", 0.0)) + diff / TAU * 0.46, 0.0, 1.0)
            state["swirl"] = swirl
            if swirl >= 0.78 and not bool(state.get("phoenix", false)):
                state["phoenix"] = true
                state["last_angle"] = angle
                return [_interaction_event("phoenix", 0, "Żar zebrał się w skrzydła — feniks rusza", CENTER, 0.14, 0.98)]
            if swirl >= 0.52 and not bool(state.get("ember_ready", false)):
                state["ember_ready"] = true
                state["last_angle"] = angle
                return [_interaction_event("ember", 0, "Popiół zaczął pamiętać kształt skrzydeł", CENTER, 0.10, 0.88)]
        state["has_angle"] = true
        state["last_angle"] = angle
    elif kind == "release":
        state["has_angle"] = false
    elif kind == "swipe" and float(state.get("swirl", 0.0)) >= 0.42 and not bool(state.get("phoenix", false)):
        var delta_value: Variant = gesture.get("delta", Vector2.ZERO)
        var delta: Vector2 = delta_value if delta_value is Vector2 else Vector2.ZERO
        if delta.y < -0.13 and _distance_to_segment(CENTER, _gesture_start(gesture), point) < 0.20:
            state["phoenix"] = true
            return [_interaction_event("phoenix", 0, "Feniks dostał kierunek — w górę", CENTER, 0.14, 0.98)]
    return []

func mechanic_progress() -> float:
    if bool(state.get("phoenix", false)):
        return 1.0
    return clampf(float(state.get("swirl", 0.0)) / 0.52 * 0.88, 0.0, 0.94)

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.72 and not bool(state.get("phoenix", false)) and _near(point_norm, Vector2(0.5, 0.48), radius_norm + 0.16):
        state["phoenix"] = true
        return [_interaction_event("phoenix", 0, "Feniks złapał oddech", Vector2(0.5, 0.48), 0.09, 0.90)]
    return []
