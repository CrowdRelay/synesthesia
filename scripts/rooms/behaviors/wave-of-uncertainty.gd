extends "res://scripts/rooms/behavior_base.gd"

func acts() -> Array[String]:
    return ["USŁYSZ PRZYPŁYW", "WEJDŹ W FALĘ", "ODZYSKAJ HORYZONT"]

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#64E8D9")), Color("64e8d9"))
    var baseline: float = viewport_size.y * (0.60 - progress * 0.05)
    for index in range(5):
        var points: PackedVector2Array = PackedVector2Array()
        for sample in range(22):
            var x: float = viewport_size.x * float(sample) / 21.0
            var wave: float = sin(float(sample) * 0.58 + phase * 4.0 + float(index))
            var y: float = baseline + float(index) * 16.0 + wave * (8.0 + progress * 17.0)
            points.append(Vector2(x, y))
        canvas.draw_polyline(points, accent.with_alpha(0.08 + progress * 0.08), 1.3 + float(index) * 0.25, true)

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.72 and not bool(state.get("horizon", false)) and point_norm.y < 0.44 + radius_norm:
        state["horizon"] = true
        return [{"kind": "wave", "index": 0, "message": "Horyzont przestał się cofać"}]
    return []
