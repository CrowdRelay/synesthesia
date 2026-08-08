extends "res://scripts/rooms/behavior_base.gd"

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["light_tap"] = false
    state["center_hold"] = false
    state["rise_swipe"] = false

func acts() -> Array[String]:
    return ["WEJDŹ DO ATRIUM", "ZBIERZ POZNANE GESTY", "WYJDŹ DO ŚWIATŁA"]

func interaction_hint() -> String:
    return "DOTKNIJ ŚWIATŁA · PRZYTRZYMAJ · UNIEŚ RUCH"

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#FFD56D")), Color("ffd56d"))
    var center: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.18)
    var gestures: float = (float(bool(state.get("light_tap", false))) + float(bool(state.get("center_hold", false))) + float(bool(state.get("rise_swipe", false)))) / 3.0
    for index in range(7):
        var ratio: float = float(index) / 6.0
        var target: Vector2 = Vector2(lerpf(viewport_size.x * 0.12, viewport_size.x * 0.88, ratio), viewport_size.y * 0.90)
        var glow: float = (0.02 + progress * 0.08 + gestures * 0.08) * (0.82 + 0.18 * sin(phase * 1.6 + float(index)))
        canvas.draw_line(center, target, Color(accent, glow), 1.2 + progress * 1.8 + gestures)
    var step_count: int = 3 + int(floor(maxf(progress, gestures * 0.88) * 8.0))
    for index in range(step_count):
        var y: float = viewport_size.y * (0.88 - float(index) * 0.055)
        var half_width: float = viewport_size.x * (0.45 - float(index) * 0.028)
        canvas.draw_line(Vector2(viewport_size.x * 0.5 - half_width, y), Vector2(viewport_size.x * 0.5 + half_width, y), Color(accent, 0.05 + progress * 0.07 + gestures * 0.03), 1.4)
    if cinematic_active():
        var rise_t: float = clampf(cinematic_time() / 3.0, 0.0, 1.0)
        var person: Vector2 = Vector2(viewport_size.x * 0.5, lerpf(viewport_size.y * 0.67, viewport_size.y * 0.28, rise_t))
        var arm_raise: float = clampf(cinematic_time() / 1.25, 0.0, 1.0)
        var shoulder: Vector2 = person + Vector2(0.0, 12.0)
        canvas.draw_circle(person - Vector2(0.0, 18.0), 11.0, Color(accent, 0.14))
        canvas.draw_line(person - Vector2(0.0, 6.0), person + Vector2(0.0, 40.0), Color(accent, 0.18), 5.0)
        canvas.draw_line(shoulder, shoulder + Vector2(-lerpf(20.0, 34.0, arm_raise), lerpf(14.0, -34.0, arm_raise)), Color(accent, 0.20), 4.0)
        canvas.draw_line(shoulder, shoulder + Vector2(lerpf(20.0, 34.0, arm_raise), lerpf(14.0, -34.0, arm_raise)), Color(accent, 0.20), 4.0)
        var window_glow: float = 0.07 + 0.12 * rise_t
        canvas.draw_circle(center, viewport_size.x * (0.16 + 0.07 * rise_t), Color(accent, window_glow))

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point: Vector2 = _gesture_point(gesture)
    var event: Dictionary = {}
    if kind == "tap" and not bool(state.get("light_tap", false)) and _near(point, Vector2(0.5, 0.20), 0.18):
        state["light_tap"] = true
        event = _interaction_event("light", 10, "Światło odpowiedziało na dotyk", Vector2(0.5, 0.20), 0.075, 0.78)
    elif kind == "hold" and not bool(state.get("center_hold", false)) and _near(point, Vector2(0.5, 0.54), 0.22):
        state["center_hold"] = true
        event = _interaction_event("light", 11, "Atrium utrzymało Twój ciężar", Vector2(0.5, 0.54), 0.09, 0.82)
    elif kind == "swipe" and not bool(state.get("rise_swipe", false)):
        var delta_value: Variant = gesture.get("delta", Vector2.ZERO)
        var delta: Vector2 = delta_value if delta_value is Vector2 else Vector2.ZERO
        if delta.y < -0.16:
            state["rise_swipe"] = true
            event = _interaction_event("light", 12, "Ruch poszedł w górę — niczego nie trzeba zdawać", point, 0.11, 0.90)
    var events: Array[Dictionary] = []
    if not event.is_empty():
        events.append(event)
    if bool(state.get("light_tap", false)) and bool(state.get("center_hold", false)) and bool(state.get("rise_swipe", false)) and not bool(state.get("final_gesture", false)):
        state["final_gesture"] = true
        events.append(_interaction_event("light", 99, "Wszystkie gesty spotkały się w jednym świetle", Vector2(0.5, 0.34), 0.16, 1.0))
    return events

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.78 and not bool(state.get("fallback_light", false)) and _near(point_norm, Vector2(0.5, 0.24), radius_norm + 0.18):
        state["fallback_light"] = true
        return [_interaction_event("light", 0, "Światło nie oślepia — prowadzi", Vector2(0.5, 0.24), 0.085, 0.86)]
    return []
