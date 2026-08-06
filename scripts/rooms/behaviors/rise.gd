extends "res://scripts/rooms/behavior_base.gd"

func acts() -> Array[String]:
    return ["WEJDŹ DO ATRIUM", "ODZYSKAJ PREZENCJĘ", "WYJDŹ DO ŚWIATŁA"]

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#FFD56D")), Color("ffd56d"))
    var center: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.18)
    var rays: int = 7
    for index in range(rays):
        var ratio: float = float(index) / float(rays - 1)
        var target: Vector2 = Vector2(lerpf(viewport_size.x * 0.12, viewport_size.x * 0.88, ratio), viewport_size.y * 0.90)
        var glow: float = (0.02 + progress * 0.08) * (0.82 + 0.18 * sin(phase * 1.6 + float(index)))
        canvas.draw_line(center, target, accent.with_alpha(glow), 1.2 + progress * 1.8)
    var step_count: int = 3 + int(floor(progress * 8.0))
    for index in range(step_count):
        var y: float = viewport_size.y * (0.88 - float(index) * 0.055)
        var half_width: float = viewport_size.x * (0.45 - float(index) * 0.028)
        canvas.draw_line(Vector2(viewport_size.x * 0.5 - half_width, y), Vector2(viewport_size.x * 0.5 + half_width, y), accent.with_alpha(0.05 + progress * 0.07), 1.4)

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.78 and not bool(state.get("light", false)) and _near(point_norm, Vector2(0.5, 0.24), radius_norm + 0.18):
        state["light"] = true
        return [{"kind": "light", "index": 0, "message": "Światło nie oślepia — prowadzi"}]
    return []
