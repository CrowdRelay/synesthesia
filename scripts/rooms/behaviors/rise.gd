extends "res://scripts/rooms/behavior_base.gd"

func acts() -> Array[String]:
    return ["WEJDŹ DO ATRIUM", "ODZYSKAJ PREZENCJĘ", "WYJDŹ DO ŚWIATŁA"]

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#FFD56D")), Color("ffd56d"))
    var center: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.18)
    var cinematic_t: float = cinematic_time()
    var rays: int = 7
    for index in range(rays):
        var ratio: float = float(index) / float(rays - 1)
        var target: Vector2 = Vector2(lerpf(viewport_size.x * 0.12, viewport_size.x * 0.88, ratio), viewport_size.y * 0.90)
        var cinematic_boost: float = clampf(cinematic_t / 2.2, 0.0, 1.0) * 0.11 if cinematic_active() else 0.0
        var glow: float = (0.02 + progress * 0.08 + cinematic_boost) * (0.82 + 0.18 * sin(phase * 1.6 + float(index)))
        canvas.draw_line(center, target, Color(accent, glow), 1.2 + progress * 1.8)
    var step_count: int = 3 + int(floor(progress * 8.0))
    for index in range(step_count):
        var y: float = viewport_size.y * (0.88 - float(index) * 0.055)
        var half_width: float = viewport_size.x * (0.45 - float(index) * 0.028)
        canvas.draw_line(Vector2(viewport_size.x * 0.5 - half_width, y), Vector2(viewport_size.x * 0.5 + half_width, y), Color(accent, 0.05 + progress * 0.07), 1.4)
    if cinematic_active():
        var rise_t: float = clampf(cinematic_t / 3.0, 0.0, 1.0)
        var person: Vector2 = Vector2(viewport_size.x * 0.5, lerpf(viewport_size.y * 0.67, viewport_size.y * 0.28, rise_t))
        var arm_raise: float = clampf(cinematic_t / 1.25, 0.0, 1.0)
        var shoulder: Vector2 = person + Vector2(0.0, 12.0)
        canvas.draw_circle(person - Vector2(0.0, 18.0), 11.0, Color(accent, 0.14))
        canvas.draw_line(person - Vector2(0.0, 6.0), person + Vector2(0.0, 40.0), Color(accent, 0.18), 5.0)
        canvas.draw_line(shoulder, shoulder + Vector2(-lerpf(20.0, 34.0, arm_raise), lerpf(14.0, -34.0, arm_raise)), Color(accent, 0.20), 4.0)
        canvas.draw_line(shoulder, shoulder + Vector2(lerpf(20.0, 34.0, arm_raise), lerpf(14.0, -34.0, arm_raise)), Color(accent, 0.20), 4.0)
        var window_glow: float = 0.07 + 0.12 * rise_t
        canvas.draw_circle(center, viewport_size.x * (0.16 + 0.07 * rise_t), Color(accent, window_glow))

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.78 and not bool(state.get("light", false)) and _near(point_norm, Vector2(0.5, 0.24), radius_norm + 0.18):
        state["light"] = true
        return [{"kind": "light", "index": 0, "message": "Światło nie oślepia — prowadzi"}]
    return []
