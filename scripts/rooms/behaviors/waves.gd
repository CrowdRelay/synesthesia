extends "res://scripts/rooms/behavior_base.gd"

func acts() -> Array[String]:
    return ["ZOSTAŃ W PÓŁMROKU", "DOSTRZEŻ DRUGĄ OSOBĘ", "POZWÓL CISZY BYĆ BLISKO"]

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#94A9FF")), Color("94a9ff"))
    var secondary: Color = Color.from_string(str(room_data.get("secondary_color", "#D890B8")), Color("d890b8"))
    var bed: Rect2 = Rect2(viewport_size.x * 0.16, viewport_size.y * 0.60, viewport_size.x * 0.68, viewport_size.y * 0.18)
    canvas.draw_rect(bed, Color(accent, 0.04 + progress * 0.07), true)
    canvas.draw_line(bed.position, bed.position + Vector2(bed.size.x, 0.0), Color(accent, 0.10), 1.5)
    if progress > 0.34:
        var alpha: float = (progress - 0.34) / 0.66
        var first: Vector2 = Vector2(viewport_size.x * 0.42, viewport_size.y * 0.58)
        var second: Vector2 = Vector2(viewport_size.x * 0.58, viewport_size.y * 0.58)
        canvas.draw_circle(first, 14.0, Color(accent, alpha * 0.10))
        canvas.draw_circle(second + Vector2(sin(phase) * 2.0, 0.0), 14.0, Color(secondary, alpha * 0.11))

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.42 and not bool(state.get("presence", false)) and _near(point_norm, Vector2(0.58, 0.58), radius_norm + 0.12):
        state["presence"] = true
        return [{"kind": "presence", "index": 0, "message": "Druga obecność przestała być tylko cieniem"}]
    return []
