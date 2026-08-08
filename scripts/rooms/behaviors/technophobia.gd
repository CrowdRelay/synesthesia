extends "res://scripts/rooms/behavior_base.gd"

const SCREEN_TARGETS: Array[Vector2] = [
    Vector2(0.185, 0.182), Vector2(0.470, 0.182), Vector2(0.756, 0.182),
    Vector2(0.185, 0.303), Vector2(0.470, 0.303), Vector2(0.756, 0.303), Vector2(0.185, 0.424),
]

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["screens"] = []
    state["signal_tune"] = 0.0
    state["signal_locked"] = false

func acts() -> Array[String]:
    return ["WEJDŹ W TRANSMISJĘ", "NAPRAW PĘKNIĘTE EKRANY", "DOSTRÓJ WŁASNY SYGNAŁ"]

func interaction_hint() -> String:
    return "DOTKNIJ EKRANÓW · ROZSUŃ SZUM"

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#6AB8FF")), Color("6ab8ff"))
    var secondary: Color = Color.from_string(str(room_data.get("secondary_color", "#FF5F7C")), Color("ff5f7c"))
    var screens: Array = state.get("screens", [])
    var cinematic_t: float = cinematic_time()
    for index in range(7):
        var column: int = index % 3
        var row: int = int(floor(float(index) / 3.0))
        var rect: Rect2 = Rect2(44.0 + float(column) * 154.0, 140.0 + float(row) * 116.0, 112.0, 70.0)
        var repaired: bool = screens.has(index)
        var jitter_strength: float = (1.0 - progress) * 3.0 if not repaired else 0.35
        if cinematic_active():
            jitter_strength = 4.0 + 7.0 * (0.5 + 0.5 * sin(cinematic_t * 7.0 + float(index)))
        rect.position.x += sin(phase * 26.0 + float(index)) * jitter_strength
        canvas.draw_rect(rect, Color(Color.BLACK, 0.12 if repaired else 0.18), true)
        canvas.draw_rect(rect, Color(accent, 0.28 if repaired else 0.16 + (1.0 - progress) * 0.10), false, 1.6)
        if repaired and not cinematic_active():
            canvas.draw_line(rect.position + Vector2(14.0, rect.size.y * 0.52), rect.end - Vector2(14.0, rect.size.y * 0.48), Color(accent, 0.30), 2.0)
        elif index % 2 == 0:
            canvas.draw_line(rect.position + Vector2(8.0, 22.0), rect.end - Vector2(8.0, 22.0), Color(secondary, 0.18), 2.0)
        if cinematic_active():
            var band_y: float = rect.position.y + fmod(cinematic_t * (42.0 + float(index) * 3.0), rect.size.y)
            canvas.draw_rect(Rect2(rect.position.x, band_y, rect.size.x, 3.0), Color(accent, 0.28), true)
    var tune: float = clampf(float(state.get("signal_tune", 0.0)), 0.0, 1.0)
    var dial_center: Vector2 = Vector2(viewport_size.x * 0.73, viewport_size.y * 0.58)
    canvas.draw_arc(dial_center, 34.0, PI * 0.18, PI * 1.82, 28, Color(accent, 0.12 + tune * 0.20), 2.0)
    var needle_angle: float = lerpf(PI * 0.82, PI * 2.18, tune)
    canvas.draw_line(dial_center, dial_center + Vector2.from_angle(needle_angle) * 28.0, Color(accent, 0.24 + tune * 0.32), 2.0)

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point: Vector2 = _gesture_point(gesture)
    match kind:
        "tap":
            return _repair_near(point, 0.12, 1)
        "swipe":
            return _repair_segment(_gesture_start(gesture), point)
        "two_finger":
            var spread_delta: float = absf(float(gesture.get("spread_delta", 0.0)))
            if spread_delta > 0.025:
                var tune: float = clampf(float(state.get("signal_tune", 0.0)) + spread_delta * 1.45, 0.0, 1.0)
                state["signal_tune"] = tune
                if tune >= 0.78 and not bool(state.get("signal_locked", false)):
                    state["signal_locked"] = true
                    return [_interaction_event("screen", 90, "Sygnał złapany — szum przestał wybierać częstotliwość", point, 0.12, 0.95)]
        "drag":
            if point.y > 0.48:
                var delta_value: Variant = gesture.get("delta", Vector2.ZERO)
                var delta: Vector2 = delta_value if delta_value is Vector2 else Vector2.ZERO
                state["signal_tune"] = clampf(float(state.get("signal_tune", 0.0)) + absf(delta.x) * 0.36, 0.0, 1.0)
    return []

func on_paint(point_norm: Vector2, radius_norm: float, _progress: float) -> Array[Dictionary]:
    return _repair_near(point_norm, radius_norm + 0.10, 1)

func _repair_near(point: Vector2, radius: float, limit: int) -> Array[Dictionary]:
    var events: Array[Dictionary] = []
    var screens: Array = state.get("screens", [])
    for index in range(SCREEN_TARGETS.size()):
        if screens.has(index) or not _near(point, SCREEN_TARGETS[index], radius):
            continue
        screens.append(index)
        events.append(_interaction_event("screen", index, "Ekran zsynchronizowany — jeden kanał mniej krzyczy", SCREEN_TARGETS[index], 0.082, 0.88))
        if events.size() >= limit:
            break
    state["screens"] = screens
    return events

func _repair_segment(start: Vector2, finish: Vector2) -> Array[Dictionary]:
    var events: Array[Dictionary] = []
    var screens: Array = state.get("screens", [])
    for index in range(SCREEN_TARGETS.size()):
        if screens.has(index) or _distance_to_segment(SCREEN_TARGETS[index], start, finish) > 0.09:
            continue
        screens.append(index)
        events.append(_interaction_event("screen", index, "Sygnał przechodzi przez ekran", SCREEN_TARGETS[index], 0.072, 0.86))
        if events.size() >= 3:
            break
    state["screens"] = screens
    return events
