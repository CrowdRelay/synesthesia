extends "res://scripts/rooms/behavior_base.gd"

func acts() -> Array[String]:
    return ["ODKRYJ ŻAR", "ZBUDUJ SKRZYDŁA", "POWSTAŃ Z POPIOŁU"]

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#FF9E58")), Color("ff9e58"))
    var cinematic_t: float = cinematic_time()
    var center: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.48)
    var wing_span: float = 44.0 + progress * 178.0
    var lift: float = progress * 72.0
    if cinematic_active():
        lift += minf(cinematic_t * 74.0, viewport_size.y * 0.40)
        center.x += sin(cinematic_t * 1.35) * 18.0
        wing_span += sin(cinematic_t * 5.2) * 22.0
    var sides: Array[float] = [-1.0, 1.0]
    for side in sides:
        var points: PackedVector2Array = PackedVector2Array()
        points.append(center + Vector2(0.0, 38.0 - lift))
        points.append(center + Vector2(side * wing_span * 0.48, -18.0 - lift + sin(phase * 3.0 + cinematic_t * 5.0) * (4.0 if not cinematic_active() else 13.0)))
        points.append(center + Vector2(side * wing_span, 24.0 - lift))
        canvas.draw_polyline(points, Color(accent, 0.12 + progress * 0.22), 2.0 + progress * 2.5, true)
    canvas.draw_circle(center + Vector2(0.0, 18.0 - lift), 8.0 + progress * 8.0, Color(accent, 0.12 + progress * 0.20))
    if cinematic_active():
        for index in range(18):
            var seed: float = float(index) * 0.83
            var dust_y: float = center.y + 120.0 - fmod(cinematic_t * (34.0 + float(index % 5) * 7.0) + seed * 91.0, 210.0)
            var dust_x: float = center.x + sin(cinematic_t * 2.0 + seed) * (42.0 + float(index % 4) * 14.0)
            canvas.draw_circle(Vector2(dust_x, dust_y), 1.0 + float(index % 3), Color(accent, 0.08))

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.72 and not bool(state.get("phoenix", false)) and _near(point_norm, Vector2(0.5, 0.48), radius_norm + 0.16):
        state["phoenix"] = true
        return [{"kind": "phoenix", "index": 0, "message": "Feniks złapał oddech"}]
    return []
