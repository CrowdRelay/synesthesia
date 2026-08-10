extends "res://scripts/rooms/behavior_base.gd"

const FIRST := Vector2(0.42, 0.58)
const SECOND := Vector2(0.58, 0.58)

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["presence"] = false
    state["closeness"] = 0.0
    state["active_presence"] = -1

func acts() -> Array[String]:
    return ["ZOSTAŃ W PÓŁMROKU", "USŁYSZ DRUGĄ FALĘ", "ZSYNCHRONIZUJ ODDECH"]

func interaction_hint() -> String:
    if bool(state.get("shared_rhythm", false)):
        return "FALE SĄ W FAZIE · POSZUKAJ ECH PRZY OKNIE"
    if bool(state.get("presence", false)):
        return "DRUGA FALA ODPOWIADA · ZBLIŻ REZONANSE"
    return "W PÓŁMROKU SĄ DWA REZONANSE · PRZYTRZYMAJ JEDEN"

func hint_targets() -> Array[Dictionary]:
    if bool(state.get("shared_rhythm", false)):
        return []
    if not bool(state.get("presence", false)):
        return [{"point": SECOND, "kind": "hold", "radius": 0.12}]
    var closeness := clampf(float(state.get("closeness", 0.0)), 0.0, 1.0)
    return [
        {"point": FIRST.lerp(Vector2(0.47, 0.58), closeness), "kind": "drag", "radius": 0.10},
        {"point": SECOND.lerp(Vector2(0.53, 0.58), closeness), "kind": "drag", "radius": 0.10},
    ]

func captures_pointer_at(point_norm: Vector2) -> bool:
    if bool(state.get("shared_rhythm", false)):
        return false
    var closeness := clampf(float(state.get("closeness", 0.0)), 0.0, 1.0)
    var first := FIRST.lerp(Vector2(0.47, 0.58), closeness)
    var second := SECOND.lerp(Vector2(0.53, 0.58), closeness)
    return _near(point_norm, first, 0.14) or _near(point_norm, second, 0.14) or int(state.get("active_presence", -1)) >= 0

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent := Color.from_string(str(room_data.get("accent_color", "#A5C2FF")), Color("a5c2ff"))
    var secondary := Color.from_string(str(room_data.get("secondary_color", "#E4A8C9")), Color("e4a8c9"))
    var closeness := clampf(float(state.get("closeness", 0.0)), 0.0, 1.0)

    # Curtains breathe continuously; no literal stick-figure overlays.
    for index in range(8):
        var base_x := viewport_size.x * (0.12 + float(index) * 0.108)
        var sway := sin(phase * (0.82 + index * 0.025) + index * 0.71) * (5.0 + progress * 2.0)
        canvas.draw_line(Vector2(base_x + sway, viewport_size.y * 0.13), Vector2(base_x - sway * 0.28, viewport_size.y * 0.72), Color(accent, 0.018 + progress * 0.014), 1.0)

    # Rain trails live only in the window plane.
    for index in range(10):
        var x := viewport_size.x * (0.24 + float(index) * 0.052)
        var travel := fmod(phase * (38.0 + index * 2.0) + index * 41.0, viewport_size.y * 0.42)
        var y := viewport_size.y * 0.18 + travel
        canvas.draw_line(Vector2(x, y), Vector2(x - 2.5, y + 19.0), Color(Color.WHITE, 0.018 + progress * 0.018), 1.0)

    if progress > 0.16 or bool(state.get("presence", false)):
        var alpha := clampf((progress - 0.14) / 0.86 + closeness * 0.28, 0.0, 1.0)
        var first_norm := FIRST.lerp(Vector2(0.47, 0.58), closeness)
        var second_norm := SECOND.lerp(Vector2(0.53, 0.58), closeness)
        var first := Vector2(first_norm.x * viewport_size.x, first_norm.y * viewport_size.y)
        var second := Vector2(second_norm.x * viewport_size.x, second_norm.y * viewport_size.y)
        var breath := 0.5 + 0.5 * sin(phase * (1.55 + closeness * 0.35))
        _draw_resonance(canvas, first, accent, alpha * 0.22, breath, 0.0)
        _draw_resonance(canvas, second, secondary, alpha * 0.22, breath, PI)
        if closeness > 0.16:
            var bridge := accent.lerp(secondary, 0.5)
            _draw_bridge_wave(canvas, first, second, bridge, 0.025 + closeness * 0.095, phase)

    if cinematic_active():
        var t := clampf(cinematic_time() / 1.6, 0.0, 1.0)
        var c := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.58)
        for ring in range(4):
            canvas.draw_arc(c, 24.0 + ring * 17.0 + t * 30.0, -2.7, 0.45, 32, Color(accent.lerp(secondary, 0.5), (0.09 - ring * 0.015) * (1.0 - t * 0.35)), 1.1)

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point := _gesture_point(gesture)
    var closeness := clampf(float(state.get("closeness", 0.0)), 0.0, 1.0)
    var first := FIRST.lerp(Vector2(0.47, 0.58), closeness)
    var second := SECOND.lerp(Vector2(0.53, 0.58), closeness)
    if kind == "hold" and not bool(state.get("presence", false)) and (_near(point, first, 0.15) or _near(point, second, 0.15)):
        state["presence"] = true
        state["closeness"] = maxf(closeness, 0.24)
        return [_interaction_event("presence", 0, "Druga fala odpowiedziała oddechem", point, 0.09, 0.82)]
    if kind == "press" and bool(state.get("presence", false)):
        if _near(point, first, 0.15): state["active_presence"] = 0
        elif _near(point, second, 0.15): state["active_presence"] = 1
    if kind == "drag" and bool(state.get("presence", false)) and int(state.get("active_presence", -1)) >= 0:
        var target := Vector2(0.50, 0.58)
        var before := point.distance_to(target)
        var dv: Variant = gesture.get("delta", Vector2.ZERO)
        var delta: Vector2 = dv if dv is Vector2 else Vector2.ZERO
        var projected := (point + delta).distance_to(target)
        var approach := maxf(0.0, before - projected) * 2.8 + delta.length() * 0.16
        state["closeness"] = clampf(closeness + approach, 0.0, 1.0)
    if kind == "release": state["active_presence"] = -1
    if kind == "two_finger":
        var spread_delta := float(gesture.get("spread_delta", 0.0))
        state["closeness"] = clampf(float(state.get("closeness", 0.0)) + maxf(0.0, -spread_delta) * 1.8 + 0.008, 0.0, 1.0)
    if float(state.get("closeness", 0.0)) >= 0.72 and bool(state.get("presence", false)) and not bool(state.get("shared_rhythm", false)):
        state["shared_rhythm"] = true
        state["active_presence"] = -1
        return [_interaction_event("presence", 1, "Dwa rezonanse weszły w jedną fazę", Vector2(0.5, 0.58), 0.13, 0.94)]
    return []

func mechanic_progress() -> float:
    if bool(state.get("shared_rhythm", false)): return 1.0
    var closeness := clampf(float(state.get("closeness", 0.0)), 0.0, 1.0)
    var presence := 0.24 if bool(state.get("presence", false)) else 0.0
    return clampf(presence + closeness * 0.76, 0.0, 0.94)

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.42 and not bool(state.get("presence", false)) and _near(point_norm, SECOND, radius_norm + 0.12):
        state["presence"] = true
        return [_interaction_event("presence", 0, "Druga fala przestała być tylko szumem", SECOND, 0.075, 0.78)]
    return []

func _draw_resonance(canvas, center: Vector2, tint: Color, alpha: float, breath: float, phase_offset: float) -> void:
    var radius := 10.0 + breath * 4.0
    canvas.draw_arc(center, radius, -2.6 + phase_offset * 0.03, 0.35 + phase_offset * 0.03, 20, Color(tint, alpha), 1.2)
    canvas.draw_arc(center, radius + 7.0, 0.55, 3.55, 20, Color(tint, alpha * 0.42), 1.0)
    var heights := [3.0, 8.0, 13.0, 6.0, 11.0, 7.0, 3.0]
    for i in range(heights.size()):
        var x := center.x + (i - 3) * 3.4
        var h: float = heights[i] * (0.7 + breath * 0.3)
        canvas.draw_line(Vector2(x, center.y - h * 0.5), Vector2(x, center.y + h * 0.5), Color(tint, alpha * 0.70), 1.0)

func _draw_bridge_wave(canvas, a: Vector2, b: Vector2, tint: Color, alpha: float, phase: float) -> void:
    var points := PackedVector2Array()
    for i in range(22):
        var t := float(i) / 21.0
        var p := a.lerp(b, t)
        p.y += sin(t * TAU * 2.0 + phase * 2.2) * (2.0 + alpha * 22.0)
        points.append(p)
    canvas.draw_polyline(points, Color(tint, alpha), 1.1)
