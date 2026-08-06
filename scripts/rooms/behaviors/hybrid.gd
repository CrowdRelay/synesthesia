extends "res://scripts/rooms/behavior_base.gd"

func acts() -> Array[String]:
    return ["STAŃ NA ULICY", "WYTRZYMAJ SPOJRZENIE", "ZAMALUJ DZIEDZICZONY AUTORYTET"]

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#F2B35D")), Color("f2b35d"))
    var opponent: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.46)
    var instability: float = maxf(0.0, progress - 0.48)
    var jitter: float = sin(phase * 18.0) * instability * 12.0
    canvas.draw_circle(opponent + Vector2(jitter, -22.0), 13.0, Color.BLACK.with_alpha(0.26 * (1.0 - progress * 0.75)))
    canvas.draw_line(opponent + Vector2(jitter, -8.0), opponent + Vector2(-jitter, 54.0), accent.with_alpha(0.10 + instability * 0.20), 6.0)
    if instability > 0.0:
        for index in range(5):
            var y: float = opponent.y - 38.0 + float(index) * 21.0
            canvas.draw_line(Vector2(opponent.x - 38.0 + jitter, y), Vector2(opponent.x + 42.0 - jitter, y), accent.with_alpha(instability * 0.10), 2.0)

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.48 and not bool(state.get("duel", false)) and _near(point_norm, Vector2(0.5, 0.46), radius_norm + 0.13):
        state["duel"] = true
        return [{"kind": "duel", "index": 0, "message": "Przeciwnik traci kształt — własna droga zostaje"}]
    return []
