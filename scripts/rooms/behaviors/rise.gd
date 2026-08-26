extends "res://scripts/rooms/behavior_base.gd"

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["light_tap"] = false
    state["center_hold"] = false
    state["rise_swipe"] = false

func acts() -> Array[String]:
    return ["WEJDŹ DO ATRIUM", "ZBIERZ POZNANE GESTY", "WYJDŹ DO ŚWIATŁA"]

func interaction_hint() -> String:
    if bool(state.get("final_gesture", false)):
        return "ŚWIATŁO JEST OTWARTE · ZBIERZ OSTATNIE ECHA"
    if not bool(state.get("light_tap", false)):
        return "NA GÓRZE ATRIUM JEST ŚWIATŁO · DOTKNIJ GO"
    if not bool(state.get("center_hold", false)):
        return "ŚWIATŁO ODPOWIEDZIAŁO · PRZYTRZYMAJ ŚRODEK ATRIUM"
    return "ATRIUM TRZYMA CIĘŻAR · WYPROWADŹ RUCH W GÓRĘ"

func hint_targets() -> Array[Dictionary]:
    if bool(state.get("final_gesture", false)):
        return []
    if not bool(state.get("light_tap", false)):
        return [{"point": _art_point(Vector2(0.50, 0.20)), "kind": "tap", "radius": 0.14}]
    if not bool(state.get("center_hold", false)):
        return [{"point": _art_point(Vector2(0.50, 0.54)), "kind": "hold", "radius": 0.17}]
    return [{"point": _art_point(Vector2(0.50, 0.46)), "kind": "drag_up", "radius": 0.18}]

func captures_pointer_at(point_norm: Vector2) -> bool:
    if bool(state.get("final_gesture", false)):
        return false
    if not bool(state.get("light_tap", false)):
        return _near(point_norm, Vector2(0.50, 0.20), 0.20)
    if not bool(state.get("center_hold", false)):
        return _near(point_norm, Vector2(0.50, 0.54), 0.24)
    return point_norm.x >= 0.24 and point_norm.x <= 0.76

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#FFD56D")), Color("ffd56d"))
    var art_light := _art_point(Vector2(0.50, 0.20))
    var center := Vector2(viewport_size.x * art_light.x, viewport_size.y * art_light.y)
    var gestures := (float(bool(state.get("light_tap", false))) + float(bool(state.get("center_hold", false))) + float(bool(state.get("rise_swipe", false)))) / 3.0

    # Ascension is environmental: architectural light lanes and ascending motes live throughout the room.
    for index in range(7):
        var ratio := float(index) / 6.0
        var target := Vector2(lerpf(viewport_size.x * 0.14, viewport_size.x * 0.86, ratio), viewport_size.y * 0.91)
        var glow := (0.014 + progress * 0.052 + gestures * 0.068) * (0.84 + 0.16 * sin(phase * 1.3 + float(index)))
        canvas.draw_line(center, target, Color(accent, glow), 1.0 + gestures * 0.8)
    for index in range(18):
        var lane := float(index % 6) / 5.0
        var x := lerpf(viewport_size.x * 0.22, viewport_size.x * 0.78, lane)
        var travel := fmod(phase * (31.0 + float(index % 5) * 2.8) + float(index) * 43.0, viewport_size.y * 0.69)
        var y := viewport_size.y * 0.88 - travel
        var alpha := 0.016 + gestures * 0.027 + progress * 0.021
        canvas.draw_line(Vector2(x, y), Vector2(x + sin(phase + index) * 2.5, y - 10.0 - float(index % 3) * 4.0), Color(accent, alpha), 1.0)

    # Steps light up sequentially instead of drawing a character on top.
    var step_count := 3 + int(floor(maxf(progress, gestures * 0.88) * 8.0))
    for index in range(step_count):
        var y := viewport_size.y * (0.88 - float(index) * 0.055)
        var half_width := viewport_size.x * (0.43 - float(index) * 0.027)
        canvas.draw_line(Vector2(viewport_size.x * 0.5 - half_width, y), Vector2(viewport_size.x * 0.5 + half_width, y), Color(accent, 0.035 + progress * 0.050 + gestures * 0.025), 1.1)

    if cinematic_active():
        var rise_t := clampf(cinematic_time() / 3.0, 0.0, 1.0)
        var window_glow := 0.045 + 0.12 * rise_t
        for ring in range(5):
            var radius := viewport_size.x * (0.10 + float(ring) * 0.042 + rise_t * 0.025)
            canvas.draw_arc(center, radius, -2.75, -0.38, 42, Color(accent, window_glow / float(ring + 1)), 1.1)
        for lane in range(7):
            var xoff := (float(lane) - 3.0) * 13.0
            canvas.draw_line(Vector2(center.x + xoff, viewport_size.y * 0.80), Vector2(center.x + xoff * 0.22, viewport_size.y * lerpf(0.50, 0.15, rise_t)), Color(accent, 0.030 + rise_t * 0.072), 1.0)

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point: Vector2 = _gesture_point(gesture)
    var event: Dictionary = {}
    if kind == "tap" and not bool(state.get("light_tap", false)) and _near(point, Vector2(0.5, 0.20), 0.18):
        state["light_tap"] = true
        event = _interaction_event("light", 10, "Światło odpowiedziało na dotyk", Vector2(0.5, 0.20), 0.075, 0.78)
    elif kind == "hold" and not bool(state.get("center_hold", false)) and _near(point, Vector2(0.5, 0.54), 0.22):
        state["center_hold"] = true
        event = _interaction_event("light", 11, "Atrium utrzymało Twój ciężar", Vector2(0.5, 0.54), 0.09, 0.82)
    elif kind == "swipe" or kind == "release":
        # Under load (web/mobile main-thread pressure) an upward stroke often
        # outlives SWIPE_MAX_MS and degrades to a bare release event; both carry
        # the same net delta, so accept either. Without this the ascension
        # stroke becomes undeliverable exactly when the device struggles.
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

func mechanic_progress() -> float:
    if bool(state.get("final_gesture", false)):
        return 1.0
    var done := 0
    done += 1 if bool(state.get("light_tap", false)) else 0
    done += 1 if bool(state.get("center_hold", false)) else 0
    done += 1 if bool(state.get("rise_swipe", false)) else 0
    return clampf(float(done) / 3.0 * 0.94, 0.0, 0.94)

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.78 and not bool(state.get("fallback_light", false)) and _near(point_norm, Vector2(0.5, 0.24), radius_norm + 0.18):
        state["fallback_light"] = true
        return [_interaction_event("light", 0, "Światło nie oślepia — prowadzi", Vector2(0.5, 0.24), 0.085, 0.86)]
    return []
