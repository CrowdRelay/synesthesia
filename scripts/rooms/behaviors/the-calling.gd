extends "res://scripts/rooms/behavior_base.gd"

func acts() -> Array[String]:
    return ["ZAJMIJ MIEJSCE", "ODZYSKAJ SPOJRZENIA", "UNIEŚ TOAST"]

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var wine: Color = Color.from_string(str(room_data.get("secondary_color", "#A40F2D")), Color("a40f2d"))
    var center: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.58)
    canvas.draw_line(center - Vector2(150.0, 0.0), center + Vector2(150.0, 0.0), Color(Color.WHITE, 0.08 + progress * 0.12), 4.0)
    var cinematic_t: float = cinematic_time()
    for index in range(5):
        var x: float = center.x + (float(index) - 2.0) * 54.0
        var lift: float = maxf(0.0, progress - 0.55) * 54.0 + sin(phase * 2.0 + float(index)) * 2.0
        if cinematic_active():
            lift += 8.0 + sin(cinematic_t * 1.8 + float(index)) * 4.0
        canvas.draw_line(Vector2(x, center.y - 34.0 - lift), Vector2(x, center.y - 12.0 - lift), Color(Color.WHITE, 0.16), 1.5)
        canvas.draw_circle(Vector2(x, center.y - 38.0 - lift), 6.0, Color(wine, 0.12 + progress * 0.22))
    if cinematic_active():
        var clink: float = clampf(cinematic_t / 0.75, 0.0, 1.0)
        var left_glass: Vector2 = center + Vector2(-36.0 + 24.0 * clink, -92.0 - 8.0 * sin(cinematic_t * 3.2))
        var right_glass: Vector2 = center + Vector2(36.0 - 24.0 * clink, -92.0 - 8.0 * sin(cinematic_t * 3.2 + 0.4))
        canvas.draw_line(left_glass, left_glass + Vector2(0.0, 26.0), Color(Color.WHITE, 0.24), 1.4)
        canvas.draw_line(right_glass, right_glass + Vector2(0.0, 26.0), Color(Color.WHITE, 0.24), 1.4)
        canvas.draw_circle(left_glass, 7.0, Color(wine, 0.20))
        canvas.draw_circle(right_glass, 7.0, Color(wine, 0.20))
        if cinematic_t > 0.45 and cinematic_t < 0.85:
            canvas.draw_circle((left_glass + right_glass) * 0.5, 22.0, Color(Color.WHITE, 0.035))

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.56 and not bool(state.get("toast", false)) and _near(point_norm, Vector2(0.5, 0.52), radius_norm + 0.16):
        state["toast"] = true
        return [{"kind": "toast", "index": 0, "message": "Toast uniesiony — czerwień została w winie"}]
    return []
