extends "res://scripts/rooms/behavior_base.gd"

const GLASS_START := Vector2(0.35, 0.49)
const GLASS_TARGET := Vector2(0.50, 0.49)
const BOTTLE_POINT := Vector2(0.57, 0.60)

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["poured"] = false
    state["glass_dragging"] = false
    state["glass_position"] = [GLASS_START.x, GLASS_START.y]
    state["toast"] = false

func acts() -> Array[String]:
    return ["ZAJMIJ MIEJSCE", "NALEJ WŁASNY KOLOR", "UNIEŚ TOAST"]

func interaction_hint() -> String:
    return "PRZYTRZYMAJ WINO · PRZYSUŃ KIELISZEK"

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var wine: Color = Color.from_string(str(room_data.get("secondary_color", "#A40F2D")), Color("a40f2d"))
    var center: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.58)
    canvas.draw_line(center - Vector2(150.0, 0.0), center + Vector2(150.0, 0.0), Color(Color.WHITE, 0.08 + progress * 0.12), 4.0)
    for index in range(5):
        var x: float = center.x + (float(index) - 2.0) * 54.0
        var lift: float = maxf(0.0, progress - 0.55) * 54.0 + sin(phase * 2.0 + float(index)) * 2.0
        canvas.draw_line(Vector2(x, center.y - 34.0 - lift), Vector2(x, center.y - 12.0 - lift), Color(Color.WHITE, 0.16), 1.5)
        canvas.draw_circle(Vector2(x, center.y - 38.0 - lift), 6.0, Color(wine, 0.12 + progress * 0.22))
    if not cinematic_active():
        var glass_norm: Vector2 = _glass_position()
        var glass: Vector2 = Vector2(glass_norm.x * viewport_size.x, glass_norm.y * viewport_size.y)
        canvas.draw_line(glass, glass + Vector2(0.0, 38.0), Color(Color.WHITE, 0.28), 2.0)
        canvas.draw_arc(glass, 12.0, 0.1, PI - 0.1, 18, Color(Color.WHITE, 0.22), 1.5)
        if bool(state.get("poured", false)):
            canvas.draw_circle(glass + Vector2(0.0, 3.0), 8.0, Color(wine, 0.30))
    else:
        var cinematic_t: float = cinematic_time()
        var clink: float = clampf(cinematic_t / 0.75, 0.0, 1.0)
        var left_glass: Vector2 = center + Vector2(-36.0 + 24.0 * clink, -92.0)
        var right_glass: Vector2 = center + Vector2(36.0 - 24.0 * clink, -92.0)
        canvas.draw_line(left_glass, left_glass + Vector2(0.0, 26.0), Color(Color.WHITE, 0.24), 1.4)
        canvas.draw_line(right_glass, right_glass + Vector2(0.0, 26.0), Color(Color.WHITE, 0.24), 1.4)
        canvas.draw_circle(left_glass, 7.0, Color(wine, 0.20))
        canvas.draw_circle(right_glass, 7.0, Color(wine, 0.20))

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point: Vector2 = _gesture_point(gesture)
    if kind == "hold" and not bool(state.get("poured", false)) and _near(point, BOTTLE_POINT, 0.15):
        state["poured"] = true
        return [_interaction_event("pour", 0, "Wino odzyskało kolor — tylko ono", BOTTLE_POINT, 0.085, 0.84)]
    if kind == "press" and _near(point, _glass_position(), 0.12):
        state["glass_dragging"] = true
    elif kind == "drag" and bool(state.get("glass_dragging", false)):
        var next: Vector2 = point
        next.x = clampf(next.x, 0.28, 0.58)
        next.y = clampf(next.y, 0.40, 0.58)
        state["glass_position"] = [next.x, next.y]
    elif kind == "release" and bool(state.get("glass_dragging", false)):
        state["glass_dragging"] = false
        if bool(state.get("poured", false)) and _near(_glass_position(), GLASS_TARGET, 0.105) and not bool(state.get("toast", false)):
            state["toast"] = true
            state["glass_position"] = [GLASS_TARGET.x, GLASS_TARGET.y]
            return [_interaction_event("toast", 0, "Szkło spotkało szkło — los nie musi być samotny", GLASS_TARGET, 0.12, 0.96)]
    return []

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.56 and not bool(state.get("toast", false)) and _near(point_norm, Vector2(0.5, 0.52), radius_norm + 0.16):
        state["toast"] = true
        return [_interaction_event("toast", 0, "Toast uniesiony — czerwień została w winie", Vector2(0.5, 0.52), 0.09, 0.90)]
    return []

func _glass_position() -> Vector2:
    var value: Variant = state.get("glass_position", [GLASS_START.x, GLASS_START.y])
    return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() >= 2 else GLASS_START
