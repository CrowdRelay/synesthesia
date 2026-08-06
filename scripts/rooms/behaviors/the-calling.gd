extends "res://scripts/rooms/behavior_base.gd"

func acts() -> Array[String]:
    return ["ZAJMIJ MIEJSCE", "ODZYSKAJ SPOJRZENIA", "UNIEŚ TOAST"]

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var wine: Color = Color.from_string(str(room_data.get("secondary_color", "#A40F2D")), Color("a40f2d"))
    var center: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.58)
    canvas.draw_line(center - Vector2(150.0, 0.0), center + Vector2(150.0, 0.0), Color.WHITE.with_alpha(0.08 + progress * 0.12), 4.0)
    for index in range(5):
        var x: float = center.x + (float(index) - 2.0) * 54.0
        var lift: float = maxf(0.0, progress - 0.55) * 54.0 + sin(phase * 2.0 + float(index)) * 2.0
        canvas.draw_line(Vector2(x, center.y - 34.0 - lift), Vector2(x, center.y - 12.0 - lift), Color.WHITE.with_alpha(0.16), 1.5)
        canvas.draw_circle(Vector2(x, center.y - 38.0 - lift), 6.0, wine.with_alpha(0.12 + progress * 0.22))

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.56 and not bool(state.get("toast", false)) and _near(point_norm, Vector2(0.5, 0.52), radius_norm + 0.16):
        state["toast"] = true
        return [{"kind": "toast", "index": 0, "message": "Toast uniesiony — czerwień została w winie"}]
    return []
