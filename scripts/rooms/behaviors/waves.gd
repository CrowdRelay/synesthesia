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
    if cinematic_active():
        var cinematic_t: float = cinematic_time()
        # Only the bedside lamp flickers; the room itself stays quiet and intimate.
        var lamp: Vector2 = Vector2(viewport_size.x * 0.78, viewport_size.y * 0.47)
        var flicker_gate: float = 0.58 + 0.42 * sin(cinematic_t * 7.0) * sin(cinematic_t * 2.3 + 0.7)
        var lamp_alpha: float = 0.035 + 0.055 * maxf(0.0, flicker_gate)
        canvas.draw_circle(lamp, 78.0, Color(secondary, lamp_alpha))
        canvas.draw_circle(lamp, 12.0, Color(secondary, 0.18 + lamp_alpha))
        # Wind is visible only at the window edge, never as a full-room effect.
        var window_rect: Rect2 = Rect2(viewport_size.x * 0.08, viewport_size.y * 0.16, viewport_size.x * 0.28, viewport_size.y * 0.30)
        for index in range(7):
            var y: float = window_rect.position.y + 24.0 + float(index) * 29.0
            var travel: float = fmod(cinematic_t * (38.0 + float(index) * 4.0) + float(index) * 41.0, window_rect.size.x + 90.0)
            var x: float = window_rect.end.x + 20.0 - travel
            canvas.draw_line(Vector2(x, y), Vector2(x - 34.0, y + sin(cinematic_t * 2.0 + float(index)) * 5.0), Color(accent, 0.055), 1.0)

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.42 and not bool(state.get("presence", false)) and _near(point_norm, Vector2(0.58, 0.58), radius_norm + 0.12):
        state["presence"] = true
        return [{"kind": "presence", "index": 0, "message": "Druga obecność przestała być tylko cieniem"}]
    return []
