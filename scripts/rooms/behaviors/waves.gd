extends "res://scripts/rooms/behavior_base.gd"

const FIRST := Vector2(0.42, 0.58)
const SECOND := Vector2(0.58, 0.58)

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["presence"] = false
    state["closeness"] = 0.0

func acts() -> Array[String]:
    return ["ZOSTAŃ W PÓŁMROKU", "DOSTRZEŻ DRUGĄ OSOBĘ", "ZNAJDŹ WSPÓLNY RYTM"]

func interaction_hint() -> String:
    return "PRZYTRZYMAJ OBECNOŚĆ · ZBLIŻ DWA PUNKTY"

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#94A9FF")), Color("94a9ff"))
    var secondary: Color = Color.from_string(str(room_data.get("secondary_color", "#D890B8")), Color("d890b8"))
    var closeness: float = clampf(float(state.get("closeness", 0.0)), 0.0, 1.0)
    var bed: Rect2 = Rect2(viewport_size.x * 0.16, viewport_size.y * 0.60, viewport_size.x * 0.68, viewport_size.y * 0.18)
    canvas.draw_rect(bed, Color(accent, 0.04 + progress * 0.07), true)
    if progress > 0.26 or bool(state.get("presence", false)):
        var alpha: float = clampf((progress - 0.22) / 0.78 + closeness * 0.28, 0.0, 1.0)
        var first_norm: Vector2 = FIRST.lerp(Vector2(0.47, 0.58), closeness)
        var second_norm: Vector2 = SECOND.lerp(Vector2(0.53, 0.58), closeness)
        var first: Vector2 = Vector2(first_norm.x * viewport_size.x, first_norm.y * viewport_size.y)
        var second: Vector2 = Vector2(second_norm.x * viewport_size.x, second_norm.y * viewport_size.y)
        var breath: float = 1.0 + sin(phase * (1.6 + closeness * 0.5)) * 1.8
        canvas.draw_circle(first, 14.0 + breath, Color(accent, alpha * 0.10))
        canvas.draw_circle(second, 14.0 + breath, Color(secondary, alpha * 0.11))
        if closeness > 0.25:
            canvas.draw_line(first, second, Color(accent.lerp(secondary, 0.5), 0.035 + closeness * 0.08), 1.2)
    if cinematic_active():
        var cinematic_t: float = cinematic_time()
        var lamp: Vector2 = Vector2(viewport_size.x * 0.78, viewport_size.y * 0.47)
        var flicker_gate: float = 0.58 + 0.42 * sin(cinematic_t * 7.0) * sin(cinematic_t * 2.3 + 0.7)
        var lamp_alpha: float = 0.035 + 0.055 * maxf(0.0, flicker_gate)
        canvas.draw_circle(lamp, 78.0, Color(secondary, lamp_alpha))
        canvas.draw_circle(lamp, 12.0, Color(secondary, 0.18 + lamp_alpha))
        var window_rect: Rect2 = Rect2(viewport_size.x * 0.08, viewport_size.y * 0.16, viewport_size.x * 0.28, viewport_size.y * 0.30)
        for index in range(7):
            var y: float = window_rect.position.y + 24.0 + float(index) * 29.0
            var travel: float = fmod(cinematic_t * (38.0 + float(index) * 4.0) + float(index) * 41.0, window_rect.size.x + 90.0)
            var x: float = window_rect.end.x + 20.0 - travel
            canvas.draw_line(Vector2(x, y), Vector2(x - 34.0, y + sin(cinematic_t * 2.0 + float(index)) * 5.0), Color(accent, 0.055), 1.0)

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point: Vector2 = _gesture_point(gesture)
    if kind == "hold" and not bool(state.get("presence", false)) and (_near(point, FIRST, 0.14) or _near(point, SECOND, 0.14)):
        state["presence"] = true
        state["closeness"] = maxf(float(state.get("closeness", 0.0)), 0.24)
        return [_interaction_event("presence", 0, "Druga obecność odpowiedziała oddechem", point, 0.085, 0.78)]
    if kind == "two_finger":
        var spread_delta: float = float(gesture.get("spread_delta", 0.0))
        var closeness: float = clampf(float(state.get("closeness", 0.0)) + maxf(0.0, -spread_delta) * 1.8 + 0.008, 0.0, 1.0)
        state["closeness"] = closeness
        if closeness >= 0.72 and not bool(state.get("shared_rhythm", false)):
            state["shared_rhythm"] = true
            return [_interaction_event("presence", 1, "Dwa rytmy nie zniknęły — zaczęły oddychać obok siebie", Vector2(0.5, 0.58), 0.12, 0.88)]
    return []

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.42 and not bool(state.get("presence", false)) and _near(point_norm, SECOND, radius_norm + 0.12):
        state["presence"] = true
        return [_interaction_event("presence", 0, "Druga obecność przestała być tylko cieniem", SECOND, 0.075, 0.78)]
    return []
