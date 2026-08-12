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
    if bool(state.get("duel", false)):
        return "WYBÓR PADŁ · POSZUKAJ ŚLADÓW NA ULICY"
    if bool(state.get("aim_locked", false)):
        return "CEL JEST SPOKOJNY · PUŚĆ PALec, GDY DECYZJA JEST TWOJA"
    return "TO NIE CELOWNIK HUD · PRZYTRZYMAJ POSTAĆ W CENTRUM"

func hint_targets() -> Array[Dictionary]:
    if bool(state.get("duel", false)):
        return []
    return [{"point": OPPONENT, "kind": "hold" if not bool(state.get("aim_locked", false)) else "release", "radius": 0.13}]

func captures_pointer_at(point_norm: Vector2) -> bool:
    return not bool(state.get("duel", false)) and (_near(point_norm, OPPONENT, 0.18) or bool(state.get("aim_locked", false)))

func needs_tick() -> bool:
    return cinematic_active() or (bool(state.get("duel", false)) and float(state.get("duel_elapsed", 0.0)) < 3.0)

func advance(delta: float) -> void:
    super.advance(delta)
    if bool(state.get("duel", false)):
        state["duel_elapsed"] = minf(float(state.get("duel_elapsed", 0.0)) + delta, 3.0)

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#F2B35D")), Color("f2b35d"))
    var secondary: Color = Color.from_string(str(room_data.get("secondary_color", "#71DCFF")), Color("71dcff"))
    var core: Vector2 = Vector2(viewport_size.x * OPPONENT.x, viewport_size.y * OPPONENT.y)
    var aim: float = clampf(float(state.get("aim_strength", 0.0)), 0.0, 1.0)
    var duel_t: float = float(state.get("duel_elapsed", 0.0))
    var resolved: bool = bool(state.get("duel", false))

    # Hybrid is now a frequency core, not a stick-figure duel. Counter-rotating
    # rings stabilise as the player holds the centre; release collapses them into
    # a single authored pulse.
    for ring in range(6):
        var radius := 30.0 + float(ring) * 23.0
        var direction := -1.0 if ring % 2 else 1.0
        var rotation := phase * (0.23 + ring * 0.035) * direction
        var span := lerpf(4.15, 5.90, aim)
        var alpha := 0.065 + aim * 0.16 + progress * 0.035 + float(assist_level) * 0.018
        canvas.draw_arc(core, radius, rotation, rotation + span, 52, Color(accent if ring % 2 == 0 else secondary, alpha), 1.0 + aim * 0.55)
    if not resolved and assist_level > 0:
        canvas.draw_circle(core, 3.0 + float(assist_level), Color(Color.WHITE, 0.08 + float(assist_level) * 0.045))
    var instability := (1.0 - aim) * (0.5 + 0.5 * sin(phase * 9.0))
    for band in range(5):
        var y := core.y + (float(band) - 2.0) * 13.0
        var width := lerpf(92.0, 34.0, aim)
        var jitter := sin(phase * (8.0 + band) + band * 1.7) * 9.0 * instability
        canvas.draw_line(Vector2(core.x - width + jitter, y), Vector2(core.x + width - jitter, y), Color(secondary, 0.035 + aim * 0.075), 1.0)
    if bool(state.get("aim_locked", false)) and not resolved:
        var lock_radius := lerpf(54.0, 22.0, aim)
        canvas.draw_arc(core, lock_radius, -2.72, 2.72, 44, Color(accent, 0.18 + aim * 0.18), 1.4)
        canvas.draw_circle(core, 2.2 + aim * 2.8, Color(Color.WHITE, 0.24 + aim * 0.30))
    if resolved:
        var collapse := clampf(duel_t / 0.70, 0.0, 1.0)
        var flash := 1.0 - clampf(absf(duel_t - 0.34) / 0.24, 0.0, 1.0)
        canvas.draw_arc(core, lerpf(120.0, 34.0, collapse), 0.0, TAU, 64, Color(accent, 0.10 + flash * 0.25), 1.8)
        canvas.draw_circle(core, lerpf(4.0, 19.0, flash), Color(secondary, flash * 0.08))

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

func mechanic_progress() -> float:
    if bool(state.get("duel", false)):
        return 1.0
    return clampf(float(state.get("aim_strength", 0.0)) * 0.92, 0.0, 0.94)

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.58 and not bool(state.get("duel", false)) and _near(point_norm, OPPONENT, radius_norm + 0.13):
        state["duel"] = true
        state["duel_elapsed"] = 0.0
        return [_interaction_event("duel", 0, "Przeciwnik traci kształt — własna droga zostaje", OPPONENT, 0.095, 0.90)]
    return []
