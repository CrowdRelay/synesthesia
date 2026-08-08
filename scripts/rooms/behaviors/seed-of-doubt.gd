extends "res://scripts/rooms/behavior_base.gd"

const SEED_POINT := Vector2(0.50, 0.74)

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["seed"] = false
    state["growth"] = 0.0
    state["milestones"] = []

func acts() -> Array[String]:
    return ["ZNAJDŹ ZIARNO", "NARYSUJ KORZENIOM DROGĘ", "WYROŚNIJ PONAD WĄTPLIWOŚĆ"]

func interaction_hint() -> String:
    return "PRZYTRZYMAJ ZIARNO · PROWADŹ WZROST"

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#9DE66F")), Color("9de66f"))
    var effective: float = maxf(progress, float(state.get("growth", 0.0)))
    var root: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.74)
    var cinematic_t: float = cinematic_time()
    var twist: float = sin(cinematic_t * 1.45) * 24.0 if cinematic_active() else 0.0
    var trunk_top: Vector2 = root - Vector2(-twist * 0.28, viewport_size.y * (0.10 + effective * 0.43))
    canvas.draw_circle(root, 7.0 + effective * 4.0, Color(accent, 0.12 + effective * 0.18))
    canvas.draw_line(root, trunk_top, Color(accent, 0.15 + effective * 0.18), 4.0 + effective * 6.0)
    var branches: int = 2 + int(floor(effective * 9.0))
    for index in range(branches):
        var ratio: float = float(index + 1) / float(branches + 1)
        var branch_origin: Vector2 = root.lerp(trunk_top, ratio)
        var side: float = -1.0 if index % 2 == 0 else 1.0
        var sway: float = sin(phase * 2.0 + float(index)) * 4.0
        var branch_end: Vector2 = branch_origin + Vector2(side * (36.0 + ratio * 54.0) + sway, -28.0 - ratio * 38.0)
        canvas.draw_line(branch_origin, branch_end, Color(accent, 0.12 + effective * 0.20), 1.4 + effective * 2.2)

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point: Vector2 = _gesture_point(gesture)
    if kind == "hold" and not bool(state.get("seed", false)) and _near(point, SEED_POINT, 0.12):
        state["seed"] = true
        state["growth"] = maxf(float(state.get("growth", 0.0)), 0.12)
        return [_interaction_event("seed", 0, "Ziarno pękło — korzenie słyszą dotyk", SEED_POINT, 0.09, 0.88)]
    if kind == "drag" and bool(state.get("seed", false)):
        var delta_value: Variant = gesture.get("delta", Vector2.ZERO)
        var delta: Vector2 = delta_value if delta_value is Vector2 else Vector2.ZERO
        var growth: float = clampf(float(state.get("growth", 0.0)) + maxf(0.0, -delta.y) * 0.72 + absf(delta.x) * 0.11, 0.0, 1.0)
        state["growth"] = growth
        var milestones: Array = state.get("milestones", [])
        for index in range(3):
            var threshold: float = 0.32 + float(index) * 0.24
            if growth >= threshold and not milestones.has(index):
                milestones.append(index)
                state["milestones"] = milestones
                return [_interaction_event("root", index, "Korzeń znalazł następną szczelinę", point, 0.070 + float(index) * 0.012, 0.82)]
    if kind == "swipe" and bool(state.get("seed", false)) and float(state.get("growth", 0.0)) >= 0.58:
        var delta_value: Variant = gesture.get("delta", Vector2.ZERO)
        var delta: Vector2 = delta_value if delta_value is Vector2 else Vector2.ZERO
        if delta.y < -0.12 and not bool(state.get("crown", false)):
            state["crown"] = true
            state["growth"] = maxf(float(state.get("growth", 0.0)), 0.86)
            return [_interaction_event("seed", 9, "Korona wyszła ponad wątpliwość", point, 0.12, 0.94)]
    return []

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.30 and not bool(state.get("seed", false)) and _near(point_norm, SEED_POINT, radius_norm + 0.08):
        state["seed"] = true
        return [_interaction_event("seed", 0, "Ziarno pękło — korzenie już pracują", SEED_POINT, 0.075, 0.84)]
    return []
