extends "res://scripts/rooms/behavior_base.gd"

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["calmness"] = 0.0
    state["horizon"] = false

func acts() -> Array[String]:
    return ["USŁYSZ PRZYPŁYW", "PROWADŹ FALĘ", "ODZYSKAJ HORYZONT"]

func interaction_hint() -> String:
    return "PROWADŹ FALĘ W BOK · NIE WALCZ Z NIĄ"

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#64E8D9")), Color("64e8d9"))
    var calmness: float = clampf(float(state.get("calmness", 0.0)), 0.0, 1.0)
    var baseline: float = viewport_size.y * (0.60 - progress * 0.05)
    var cinematic_t: float = cinematic_time()
    var surge: float = clampf(cinematic_t / 1.2, 0.0, 1.0) if cinematic_active() else progress
    for index in range(5):
        var points: PackedVector2Array = PackedVector2Array()
        var direction: float = -1.0 if index % 2 == 0 else 1.0
        var lateral: float = direction * sin(phase * 3.4 + float(index) * 0.7) * (10.0 + surge * 28.0) * (1.0 - calmness * 0.45)
        for sample in range(24):
            var x: float = viewport_size.x * float(sample) / 23.0 + lateral
            var wave: float = sin(float(sample) * 0.58 + phase * (4.8 - calmness * 2.1) + float(index))
            var y: float = baseline + float(index) * 16.0 + wave * (8.0 + progress * 17.0) * (1.0 - calmness * 0.52)
            points.append(Vector2(x, y))
        canvas.draw_polyline(points, Color(accent, 0.09 + progress * 0.09 + calmness * 0.05), 1.3 + float(index) * 0.25, true)
    if calmness > 0.55:
        canvas.draw_line(Vector2(viewport_size.x * 0.14, viewport_size.y * 0.43), Vector2(viewport_size.x * 0.86, viewport_size.y * 0.43), Color(accent, 0.06 + calmness * 0.12), 1.0)

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point: Vector2 = _gesture_point(gesture)
    if kind == "drag" and point.y > 0.42:
        var delta_value: Variant = gesture.get("delta", Vector2.ZERO)
        var delta: Vector2 = delta_value if delta_value is Vector2 else Vector2.ZERO
        var calmness: float = clampf(float(state.get("calmness", 0.0)) + absf(delta.x) * 0.44, 0.0, 1.0)
        state["calmness"] = calmness
        if calmness >= 0.70 and not bool(state.get("horizon", false)):
            state["horizon"] = true
            return [_interaction_event("wave", 0, "Fala znalazła rytm — horyzont przestał uciekać", Vector2(0.5, 0.43), 0.11, 0.92)]
    if kind == "swipe" and not bool(state.get("horizon", false)):
        var delta_value: Variant = gesture.get("delta", Vector2.ZERO)
        var delta: Vector2 = delta_value if delta_value is Vector2 else Vector2.ZERO
        if absf(delta.x) > 0.18 and absf(delta.x) > absf(delta.y) * 1.5:
            state["calmness"] = maxf(float(state.get("calmness", 0.0)), 0.72)
            state["horizon"] = true
            return [_interaction_event("wave", 0, "Niepewność została falą, nie ścianą", Vector2(0.5, 0.43), 0.11, 0.92)]
    return []

func mechanic_progress() -> float:
    if bool(state.get("horizon", false)):
        return 1.0
    return clampf(float(state.get("calmness", 0.0)) / 0.72, 0.0, 0.94)

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.72 and not bool(state.get("horizon", false)) and point_norm.y < 0.44 + radius_norm:
        state["horizon"] = true
        return [_interaction_event("wave", 0, "Horyzont przestał się cofać", point_norm, 0.075, 0.84)]
    return []
