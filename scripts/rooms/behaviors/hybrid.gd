extends "res://scripts/rooms/behavior_base.gd"

const OPPONENT := Vector2(0.50, 0.46)

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["duel"] = false
    state["duel_elapsed"] = 0.0
    state["aim_locked"] = false
    state["aim_strength"] = 0.0

func acts() -> Array[String]:
    return ["STAŃ NA ULICY", "USTABILIZUJ CEL", "PUŚĆ CUDZY PLAN"]

func interaction_hint() -> String:
    return "PRZYTRZYMAJ CEL · PUŚĆ, GDY JESTEŚ GOTÓW"

func needs_tick() -> bool:
    return cinematic_active() or (bool(state.get("duel", false)) and float(state.get("duel_elapsed", 0.0)) < 3.0)

func advance(delta: float) -> void:
    super.advance(delta)
    if bool(state.get("duel", false)):
        state["duel_elapsed"] = minf(float(state.get("duel_elapsed", 0.0)) + delta, 3.0)

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#F2B35D")), Color("f2b35d"))
    var opponent: Vector2 = Vector2(viewport_size.x * OPPONENT.x, viewport_size.y * OPPONENT.y)
    var aim: float = float(state.get("aim_strength", 0.0))
    var instability: float = maxf(0.0, progress - 0.35) * (1.0 - aim * 0.72)
    var jitter: float = sin(phase * 18.0) * instability * 12.0
    canvas.draw_circle(opponent + Vector2(jitter, -22.0), 13.0, Color(Color.BLACK, 0.26 * (1.0 - progress * 0.75)))
    canvas.draw_line(opponent + Vector2(jitter, -8.0), opponent + Vector2(-jitter, 54.0), Color(accent, 0.10 + instability * 0.20), 6.0)
    if bool(state.get("aim_locked", false)) and not bool(state.get("duel", false)):
        var radius: float = lerpf(48.0, 24.0, clampf(aim, 0.0, 1.0))
        canvas.draw_arc(opponent, radius, 0.0, TAU, 32, Color(accent, 0.28), 1.6)
        canvas.draw_line(opponent - Vector2(radius + 12.0, 0.0), opponent - Vector2(radius - 5.0, 0.0), Color(accent, 0.30), 1.5)
        canvas.draw_line(opponent + Vector2(radius - 5.0, 0.0), opponent + Vector2(radius + 12.0, 0.0), Color(accent, 0.30), 1.5)
    if bool(state.get("duel", false)):
        var duel_t: float = float(state.get("duel_elapsed", 0.0))
        var draw_mix: float = clampf(duel_t / 0.34, 0.0, 1.0)
        var grip: Vector2 = Vector2(lerpf(viewport_size.x * 1.08, viewport_size.x * 0.73, draw_mix), viewport_size.y * 0.83)
        var muzzle: Vector2 = grip + Vector2(-70.0, -82.0)
        canvas.draw_line(grip, muzzle, Color(0.035, 0.028, 0.025, 0.82), 16.0)
        if duel_t > 0.36 and duel_t < 0.54:
            var flash: float = 1.0 - absf(duel_t - 0.45) / 0.09
            canvas.draw_circle(muzzle, 38.0 * flash, Color(accent, 0.13 * flash))

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point: Vector2 = _gesture_point(gesture)
    if kind == "hold" and not bool(state.get("duel", false)) and _near(point, OPPONENT, 0.16):
        state["aim_locked"] = true
        state["aim_strength"] = maxf(float(state.get("aim_strength", 0.0)), 0.72)
        return [_interaction_event("aim", 0, "Cel się uspokoił — decyzja należy do Ciebie", OPPONENT, 0.07, 0.74)]
    if kind == "drag" and bool(state.get("aim_locked", false)) and _near(point, OPPONENT, 0.20):
        state["aim_strength"] = clampf(float(state.get("aim_strength", 0.0)) + 0.025, 0.0, 1.0)
    if kind in ["release", "swipe"] and bool(state.get("aim_locked", false)) and not bool(state.get("duel", false)):
        if _near(point, OPPONENT, 0.22) or _distance_to_segment(OPPONENT, _gesture_start(gesture), point) < 0.13:
            state["duel"] = true
            state["duel_elapsed"] = 0.0
            return [_interaction_event("duel", 0, "Strzał jest wyborem — cudzy plan traci kształt", OPPONENT, 0.12, 0.96)]
    return []

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.58 and not bool(state.get("duel", false)) and _near(point_norm, OPPONENT, radius_norm + 0.13):
        state["duel"] = true
        state["duel_elapsed"] = 0.0
        return [_interaction_event("duel", 0, "Przeciwnik traci kształt — własna droga zostaje", OPPONENT, 0.095, 0.90)]
    return []
