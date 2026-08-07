extends "res://scripts/rooms/behavior_base.gd"

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["duel"] = false
    state["duel_elapsed"] = 0.0

func acts() -> Array[String]:
    return ["STAŃ NA ULICY", "WYTRZYMAJ SPOJRZENIE", "ZAMALUJ DZIEDZICZONY AUTORYTET"]

func advance(delta: float) -> void:
    super.advance(delta)
    if bool(state.get("duel", false)):
        state["duel_elapsed"] = minf(float(state.get("duel_elapsed", 0.0)) + delta, 3.0)

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#F2B35D")), Color("f2b35d"))
    var opponent: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.46)
    var instability: float = maxf(0.0, progress - 0.48)
    var jitter: float = sin(phase * 18.0) * instability * 12.0
    canvas.draw_circle(opponent + Vector2(jitter, -22.0), 13.0, Color(Color.BLACK, 0.26 * (1.0 - progress * 0.75)))
    canvas.draw_line(opponent + Vector2(jitter, -8.0), opponent + Vector2(-jitter, 54.0), Color(accent, 0.10 + instability * 0.20), 6.0)
    if instability > 0.0:
        for index in range(5):
            var y: float = opponent.y - 38.0 + float(index) * 21.0
            canvas.draw_line(Vector2(opponent.x - 38.0 + jitter, y), Vector2(opponent.x + 42.0 - jitter, y), Color(accent, instability * 0.10), 2.0)
    if bool(state.get("duel", false)):
        var duel_t: float = float(state.get("duel_elapsed", 0.0))
        var draw_mix: float = clampf(duel_t / 0.34, 0.0, 1.0)
        var recoil: float = 0.0
        if duel_t > 0.34 and duel_t < 0.58:
            recoil = sin((duel_t - 0.34) / 0.24 * PI) * 18.0
        var grip: Vector2 = Vector2(lerpf(viewport_size.x * 1.08, viewport_size.x * 0.73, draw_mix) + recoil, viewport_size.y * 0.83)
        var muzzle: Vector2 = grip + Vector2(-70.0, -82.0)
        canvas.draw_line(grip, muzzle, Color(0.035, 0.028, 0.025, 0.82), 16.0)
        canvas.draw_line(grip + Vector2(2.0, 2.0), grip + Vector2(24.0, 38.0), Color(0.035, 0.028, 0.025, 0.82), 12.0)
        if duel_t > 0.36 and duel_t < 0.54:
            var flash: float = 1.0 - absf(duel_t - 0.45) / 0.09
            canvas.draw_circle(muzzle, 38.0 * flash, Color(accent, 0.13 * flash))
            for ray in range(8):
                canvas.draw_line(muzzle, muzzle + Vector2.from_angle(float(ray) * TAU / 8.0) * 56.0 * flash, Color(accent, 0.42 * flash), 2.4)

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.48 and not bool(state.get("duel", false)) and _near(point_norm, Vector2(0.5, 0.46), radius_norm + 0.13):
        state["duel"] = true
        state["duel_elapsed"] = 0.0
        return [{"kind": "duel", "index": 0, "message": "Przeciwnik traci kształt — własna droga zostaje"}]
    return []
