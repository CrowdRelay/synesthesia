extends "res://scripts/rooms/behavior_base.gd"

func acts() -> Array[String]:
    return ["ODKRYJ ŻAR", "ZBUDUJ SKRZYDŁA", "POWSTAŃ Z POPIOŁU"]

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#FF9E58")), Color("ff9e58"))
    var center: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.48)
    var wing_span: float = 44.0 + progress * 178.0
    var lift: float = progress * 72.0
    var sides: Array[float] = [-1.0, 1.0]
    for side in sides:
        var points: PackedVector2Array = PackedVector2Array()
        points.append(center + Vector2(0.0, 38.0 - lift))
        points.append(center + Vector2(side * wing_span * 0.48, -18.0 - lift + sin(phase * 3.0) * 4.0))
        points.append(center + Vector2(side * wing_span, 24.0 - lift))
        canvas.draw_polyline(points, accent.with_alpha(0.12 + progress * 0.22), 2.0 + progress * 2.5, true)
    canvas.draw_circle(center + Vector2(0.0, 18.0 - lift), 8.0 + progress * 8.0, accent.with_alpha(0.12 + progress * 0.20))

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.72 and not bool(state.get("phoenix", false)) and _near(point_norm, Vector2(0.5, 0.48), radius_norm + 0.16):
        state["phoenix"] = true
        return [{"kind": "phoenix", "index": 0, "message": "Feniks złapał oddech"}]
    return []
