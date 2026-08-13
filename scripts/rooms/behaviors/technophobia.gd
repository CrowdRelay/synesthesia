extends "res://scripts/rooms/behavior_base.gd"
# Technophobia is the vertical slice for Synesthesia's exploration-first room
# design: discover physical causes of interference, manipulate them, then hear
# the mix react. Screen taps remain as a forgiving secondary interaction, but
# they cannot complete the room on their own.
const SCREEN_TARGETS: Array[Vector2] = [
    Vector2(0.185, 0.182), Vector2(0.470, 0.182), Vector2(0.756, 0.182),
    Vector2(0.185, 0.303), Vector2(0.470, 0.303), Vector2(0.756, 0.303),
    Vector2(0.185, 0.424),
]
const CABLE_SOURCES: Array[Vector2] = [
    Vector2(0.20, 0.35), Vector2(0.49, 0.35), Vector2(0.77, 0.35),
]
const CABLE_PLUGS: Array[Vector2] = [
    Vector2(0.28, 0.58), Vector2(0.51, 0.61), Vector2(0.73, 0.57),
]
const CABLE_COLORS: Array[Color] = [
    Color("ff5f7c"), Color("71dcff"), Color("a978ff"),
]
const BREAKER_TARGET := Vector2(0.18, 0.67)
const TUNER_TARGET := Vector2(0.76, 0.69)
const CABLE_GRAB_RADIUS: float = 0.075
const CABLE_RELEASE_DISTANCE: float = 0.145
const BREAKER_RADIUS: float = 0.090
const TUNER_RADIUS: float = 0.135
func configure(data: Dictionary) -> void:
    super.configure(data)
    state["screens"] = []
    state["cables_unplugged"] = []
    state["active_cable"] = -1
    state["cable_drag_point"] = Vector2.ZERO
    state["tension_bucket"] = -1
    state["snap_cable"] = -1
    state["snap_time"] = 0.0
    state["snap_from"] = Vector2.ZERO
    state["breaker_off"] = false
    state["signal_tune"] = 0.0
    state["signal_locked"] = false
    state["failed_pulls"] = 0
    state["tension_bucket"] = -1
func needs_tick() -> bool:
    return cinematic_active() or int(state.get("active_cable", -1)) >= 0 or int(state.get("snap_cable", -1)) >= 0
func advance(delta: float) -> void:
    super.advance(delta)
    var snap_index: int = int(state.get("snap_cable", -1))
    if snap_index >= 0:
        var snap_time: float = float(state.get("snap_time", 0.0)) + minf(delta, 0.08)
        state["snap_time"] = snap_time
        if snap_time >= 0.24:
            state["snap_cable"] = -1
            state["snap_time"] = 0.0
            state["snap_from"] = Vector2.ZERO
func acts() -> Array[String]:
    return ["ZNAJDŹ ŹRÓDŁA SZUMU", "ODŁĄCZ PRZECIĄŻENIE", "DOSTRÓJ WŁASNY SYGNAŁ"]
func interaction_hint() -> String:
    var unplugged: Array = state.get("cables_unplugged", [])
    if unplugged.size() < CABLE_PLUGS.size():
        return "ZNAJDŹ WTYCZKI · CHWYĆ I WYCIĄGNIJ KABEL"
    if not bool(state.get("breaker_off", false)):
        return "ZASILANIE NADAL BUczy · PRZYTRZYMAJ WYŁĄCZNIK"
    if not bool(state.get("signal_locked", false)):
        return "SZUM UCICHŁ · PRZESUWAJ TUNER, AŻ ZŁAPIESZ SYGNAŁ"
    return "SYGNAŁ CZYSTY · POSZUKAJ OSTATNICH ECH"
func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#6AB8FF")), Color("6ab8ff"))
    var secondary: Color = Color.from_string(str(room_data.get("secondary_color", "#FF5F7C")), Color("ff5f7c"))
    _render_screens(canvas, viewport_size, progress, phase, accent, secondary)
    _render_cables(canvas, viewport_size, phase, accent)
    _render_breaker(canvas, viewport_size, phase, accent, secondary)
    _render_tuner(canvas, viewport_size, phase, accent)
func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point: Vector2 = _gesture_point(gesture)
    match kind:
        "press":
            return _begin_cable_pull(point)
        "drag":
            var cable_events := _drag_cable(point)
            if not cable_events.is_empty():
                return cable_events
            return _drag_tuner(point, gesture)
        "release":
            var release_events := _release_cable(point)
            if not release_events.is_empty():
                return release_events
        "hold":
            if _near(point, BREAKER_TARGET, BREAKER_RADIUS) and _breaker_available() and not bool(state.get("breaker_off", false)):
                state["breaker_off"] = true
                _silence_all_screens()
                return [_interaction_event("breaker", 0, "Główne zasilanie odcięte — ściana ekranów gaśnie", BREAKER_TARGET, 0.105, 0.96)]
        "tap":
            # Legacy/fallback screen repair remains intentionally available for
            # accessibility and keeps old save/test contracts valid.
            return _repair_near(point, 0.095, 1)
        "swipe":
            return _repair_segment(_gesture_start(gesture), point)
        "two_finger":
            # Two-finger spread is a secondary tuner gesture, useful on tablets.
            if bool(state.get("breaker_off", false)):
                var spread_delta: float = absf(float(gesture.get("spread_delta", 0.0)))
                if spread_delta > 0.018:
                    _advance_tune(spread_delta * 1.05)
                    return _maybe_lock_signal(point)
    return []
func hint_targets() -> Array[Dictionary]:
    var unplugged: Array = state.get("cables_unplugged", [])
    if unplugged.size() < CABLE_PLUGS.size():
        var targets: Array[Dictionary] = []
        for index in range(CABLE_PLUGS.size()):
            if not unplugged.has(index):
                targets.append({"point": CABLE_PLUGS[index], "kind": "pull", "radius": CABLE_GRAB_RADIUS})
        return targets
    if not bool(state.get("breaker_off", false)):
        return [{"point": BREAKER_TARGET, "kind": "hold", "radius": BREAKER_RADIUS}]
    if not bool(state.get("signal_locked", false)):
        return [{"point": TUNER_TARGET, "kind": "tune", "radius": TUNER_RADIUS}]
    return []
func mechanic_progress() -> float:
    if bool(state.get("signal_locked", false)):
        return 1.0
    var unplugged: Array = state.get("cables_unplugged", [])
    var cable_ratio: float = float(unplugged.size()) / float(CABLE_PLUGS.size())
    var breaker_ratio: float = 1.0 if bool(state.get("breaker_off", false)) else 0.0
    var tune: float = clampf(float(state.get("signal_tune", 0.0)), 0.0, 1.0)
    # Old V2 contract intentionally remains true while the new room requires
    # the physical cable/breaker path as well: state.get("screens", []).size() >= 5
    return clampf(cable_ratio * 0.48 + breaker_ratio * 0.22 + tune * 0.295, 0.0, 0.995)
func brush_assist_weight() -> float:
    # Painting can reveal details/find echoes, but cannot solve the room.
    return 0.14
func captures_pointer_at(point_norm: Vector2) -> bool:
    var unplugged: Array = state.get("cables_unplugged", [])
    for index in range(CABLE_PLUGS.size()):
        if not unplugged.has(index) and _near(point_norm, CABLE_PLUGS[index], CABLE_GRAB_RADIUS):
            return true
    if _breaker_available() and not bool(state.get("breaker_off", false)) and _near(point_norm, BREAKER_TARGET, BREAKER_RADIUS):
        return true
    if bool(state.get("breaker_off", false)) and not bool(state.get("signal_locked", false)) and _near(point_norm, TUNER_TARGET, TUNER_RADIUS):
        return true
    return int(state.get("active_cable", -1)) >= 0
func on_paint(point_norm: Vector2, radius_norm: float, _progress: float) -> Array[Dictionary]:
    # Painting only quiets individual screens. The puzzle still requires cables,
    # breaker and tuning, which prevents accidental completion by scribbling.
    return _repair_near(point_norm, radius_norm + 0.07, 1)
func _begin_cable_pull(point: Vector2) -> Array[Dictionary]:
    if int(state.get("active_cable", -1)) >= 0:
        return []
    var unplugged: Array = state.get("cables_unplugged", [])
    for index in range(CABLE_PLUGS.size()):
        if unplugged.has(index):
            continue
        if not _near(point, CABLE_PLUGS[index], CABLE_GRAB_RADIUS):
            continue
        state["active_cable"] = index
        state["snap_cable"] = -1
        state["snap_time"] = 0.0
        state["cable_drag_point"] = CABLE_PLUGS[index]
        return [_interaction_event("cable_grab", index, "Kabel napręża się pod palcem", point, 0.0, 0.0)]
    return []
func _drag_cable(point: Vector2) -> Array[Dictionary]:
    var index := int(state.get("active_cable", -1))
    if index < 0 or index >= CABLE_PLUGS.size():
        return []
    state["cable_drag_point"] = _resisted_cable_point(index, point)
    var distance := point.distance_to(CABLE_PLUGS[index])
    var bucket := mini(4, int(floor(distance / 0.035)))
    var previous := int(state.get("tension_bucket", -1))
    if bucket > previous:
        state["tension_bucket"] = bucket
        return [_interaction_event("cable_tension", index * 10 + bucket, "", point, 0.0, 0.0)]
    return []
func _release_cable(point: Vector2) -> Array[Dictionary]:
    var index := int(state.get("active_cable", -1))
    if index < 0 or index >= CABLE_PLUGS.size():
        return []
    var visual_drag_value: Variant = state.get("cable_drag_point", CABLE_PLUGS[index])
    var visual_drag: Vector2 = visual_drag_value if visual_drag_value is Vector2 else CABLE_PLUGS[index]
    state["active_cable"] = -1
    state["cable_drag_point"] = Vector2.ZERO
    state["tension_bucket"] = -1
    var distance := point.distance_to(CABLE_PLUGS[index])
    if distance < CABLE_RELEASE_DISTANCE:
        state["failed_pulls"] = int(state.get("failed_pulls", 0)) + 1
        state["snap_cable"] = index
        state["snap_time"] = 0.0
        state["snap_from"] = visual_drag
        return [_interaction_event("cable_snap", index, "Za mało — kabel odbija. Wyciągnij dalej od gniazda", visual_drag, 0.0, 0.0)]
    var unplugged: Array = state.get("cables_unplugged", [])
    if unplugged.has(index):
        return []
    unplugged.append(index)
    state["cables_unplugged"] = unplugged
    _silence_screen_pair(index)
    var quiet_count: int = (state.get("screens", []) as Array).size()
    var message := "Wtyczka wyrwana — %d ekranów straciło szum" % quiet_count
    if unplugged.size() == CABLE_PLUGS.size():
        message = "Wszystkie przewody odpięte — znajdź główny wyłącznik"
    return [_interaction_event("cable_unplug", index, message, CABLE_PLUGS[index], 0.085, 0.92)]
func _drag_tuner(point: Vector2, gesture: Dictionary) -> Array[Dictionary]:
    if not bool(state.get("breaker_off", false)) or bool(state.get("signal_locked", false)):
        return []
    if not _near(point, TUNER_TARGET, TUNER_RADIUS):
        return []
    var delta_value: Variant = gesture.get("delta", Vector2.ZERO)
    var delta: Vector2 = delta_value if delta_value is Vector2 else Vector2.ZERO
    var amount: float = absf(delta.x) * 1.35 + absf(delta.y) * 0.38
    if amount <= 0.001:
        return []
    _advance_tune(amount)
    return _maybe_lock_signal(point)
func _advance_tune(amount: float) -> void:
    state["signal_tune"] = clampf(float(state.get("signal_tune", 0.0)) + amount, 0.0, 1.0)
func _maybe_lock_signal(point: Vector2) -> Array[Dictionary]:
    var tune := clampf(float(state.get("signal_tune", 0.0)), 0.0, 1.0)
    # Keep the old signal_tune/screens relationship for backwards-compatible
    # saves, while requiring the breaker as the new causal puzzle state.
    if tune >= 0.86 and state.get("screens", []).size() >= 5 and bool(state.get("breaker_off", false)) and not bool(state.get("signal_locked", false)):
        state["signal_locked"] = true
        return [_interaction_event("signal_lock", 90, "Sygnał złapany — szum znika, zostaje muzyka", point, 0.14, 1.0)]
    return []
func _breaker_available() -> bool:
    return (state.get("cables_unplugged", []) as Array).size() >= 2
func _silence_screen_pair(cable_index: int) -> void:
    var screens: Array = state.get("screens", [])
    var first := clampi(cable_index * 2, 0, SCREEN_TARGETS.size() - 1)
    var second := clampi(first + 1, 0, SCREEN_TARGETS.size() - 1)
    for screen_index in [first, second]:
        if not screens.has(screen_index):
            screens.append(screen_index)
    state["screens"] = screens
func _silence_all_screens() -> void:
    var screens: Array = state.get("screens", [])
    for index in range(SCREEN_TARGETS.size()):
        if not screens.has(index):
            screens.append(index)
    state["screens"] = screens
func _repair_near(point: Vector2, radius: float, limit: int) -> Array[Dictionary]:
    var events: Array[Dictionary] = []
    var screens: Array = state.get("screens", [])
    for index in range(SCREEN_TARGETS.size()):
        if screens.has(index) or not _near(point, SCREEN_TARGETS[index], radius):
            continue
        screens.append(index)
        events.append(_interaction_event("screen", index, "Ekran uspokojony — ale źródło zakłóceń nadal pracuje", SCREEN_TARGETS[index], 0.050, 0.68))
        if events.size() >= limit:
            break
    state["screens"] = screens
    return events
func _repair_segment(start: Vector2, finish: Vector2) -> Array[Dictionary]:
    var events: Array[Dictionary] = []
    var screens: Array = state.get("screens", [])
    for index in range(SCREEN_TARGETS.size()):
        if screens.has(index) or _distance_to_segment(SCREEN_TARGETS[index], start, finish) > 0.075:
            continue
        screens.append(index)
        events.append(_interaction_event("screen", index, "Kanał ucichł na chwilę", SCREEN_TARGETS[index], 0.045, 0.62))
        if events.size() >= 2:
            break
    state["screens"] = screens
    return events
func _render_screens(canvas, viewport_size: Vector2, progress: float, phase: float, accent: Color, secondary: Color) -> void:
    var screens: Array = state.get("screens", [])
    var cinematic_t: float = cinematic_time()
    var cell_size := Vector2(viewport_size.x * 0.205, viewport_size.y * 0.070)
    for index in range(SCREEN_TARGETS.size()):
        var center := Vector2(SCREEN_TARGETS[index].x * viewport_size.x, SCREEN_TARGETS[index].y * viewport_size.y)
        var rect := Rect2(center - cell_size * 0.5, cell_size)
        var repaired: bool = screens.has(index)
        var jitter_strength: float = (1.0 - progress) * viewport_size.x * 0.0048 if not repaired else 0.35
        if cinematic_active():
            jitter_strength = viewport_size.x * (0.006 + 0.008 * (0.5 + 0.5 * sin(cinematic_t * 7.0 + float(index))))
        rect.position.x += sin(phase * 26.0 + float(index)) * jitter_strength
        var off_alpha := 0.055 if repaired else 0.17
        canvas.draw_rect(rect, Color(Color.BLACK, off_alpha), true)
        canvas.draw_rect(rect, Color(accent, 0.10 if repaired else 0.22), false, maxf(1.0, viewport_size.x * 0.0014))
        if repaired and not cinematic_active():
            var y := rect.get_center().y
            canvas.draw_line(Vector2(rect.position.x + rect.size.x * 0.12, y), Vector2(rect.end.x - rect.size.x * 0.12, y), Color(accent, 0.22), maxf(1.0, viewport_size.x * 0.0012))
            canvas.draw_circle(rect.get_center(), maxf(2.0, viewport_size.x * 0.004), Color("71dcff33"))
        else:
            var band_y := rect.position.y + fmod((phase * 210.0 + float(index) * 17.0), maxf(1.0, rect.size.y))
            canvas.draw_rect(Rect2(rect.position.x, band_y, rect.size.x, maxf(1.0, viewport_size.y * 0.0014)), Color(secondary, 0.18), true)
            for line_index in range(3):
                var line_y := rect.position.y + rect.size.y * (0.24 + float(line_index) * 0.22)
                var chop := 0.62 + 0.24 * sin(phase * (7.0 + line_index) + float(index))
                canvas.draw_line(Vector2(rect.position.x + rect.size.x * 0.08, line_y), Vector2(rect.position.x + rect.size.x * chop, line_y), Color(accent, 0.11), 1.0)
func _render_cables(canvas, viewport_size: Vector2, phase: float, accent: Color) -> void:
    var unplugged: Array = state.get("cables_unplugged", [])
    var active := int(state.get("active_cable", -1))
    var drag_value: Variant = state.get("cable_drag_point", Vector2.ZERO)
    var drag_point: Vector2 = drag_value if drag_value is Vector2 else Vector2.ZERO
    var snap_index: int = int(state.get("snap_cable", -1))
    var snap_from_value: Variant = state.get("snap_from", Vector2.ZERO)
    var snap_from: Vector2 = snap_from_value if snap_from_value is Vector2 else Vector2.ZERO
    var snap_t: float = clampf(float(state.get("snap_time", 0.0)) / 0.24, 0.0, 1.0)
    var snap_ease: float = 1.0 - pow(1.0 - snap_t, 3.0)
    for index in range(CABLE_PLUGS.size()):
        var source := _px(CABLE_SOURCES[index], viewport_size)
        var plug_norm := CABLE_PLUGS[index]
        if index == active and drag_point != Vector2.ZERO:
            plug_norm = drag_point
        elif index == snap_index and snap_from != Vector2.ZERO:
            plug_norm = snap_from.lerp(CABLE_PLUGS[index], snap_ease)
        elif unplugged.has(index):
            var sway := Vector2(sin(phase * 3.1 + float(index)) * 0.022, 0.085 + 0.012 * cos(phase * 2.2 + float(index)))
            plug_norm += sway
        var plug := _px(plug_norm, viewport_size)
        var color := CABLE_COLORS[index] if index < CABLE_COLORS.size() else accent
        _draw_cable(canvas, source, plug, viewport_size, color, unplugged.has(index), index == active, phase + float(index))
        _draw_plug(canvas, plug, viewport_size, color, unplugged.has(index), index == active)
        if index == active:
            var tension: float = clampf(float(int(state.get("tension_bucket", 0))) / 4.0, 0.0, 1.0)
            var halo_radius: float = viewport_size.x * (0.014 + tension * 0.010)
            canvas.draw_arc(plug, halo_radius, -PI * 0.85, PI * 0.85, 24, Color(color, 0.16 + tension * 0.28), maxf(1.0, viewport_size.x * 0.0015))
            canvas.draw_line(plug, plug + (CABLE_PLUGS[index] - plug_norm).normalized() * viewport_size.x * (0.010 + tension * 0.012), Color(Color.WHITE, 0.10 + tension * 0.20), maxf(1.0, viewport_size.x * 0.0012))
        if not unplugged.has(index) and index != active:
            var pulse := 0.5 + 0.5 * sin(phase * 5.0 + float(index) * 1.8)
            canvas.draw_arc(plug, viewport_size.x * (0.018 + pulse * 0.003), 0.0, TAU, 28, Color(color, 0.10 + pulse * 0.11), maxf(1.0, viewport_size.x * 0.0012))
func _render_breaker(canvas, viewport_size: Vector2, phase: float, accent: Color, secondary: Color) -> void:
    var center := _px(BREAKER_TARGET, viewport_size)
    var available := _breaker_available()
    var off := bool(state.get("breaker_off", false))
    var box_size := Vector2(viewport_size.x * 0.115, viewport_size.y * 0.085)
    var rect := Rect2(center - box_size * 0.5, box_size)
    var border := Color(accent, 0.34 if available else 0.10)
    if off:
        border = Color("71dcff66")
    canvas.draw_rect(rect, Color("05080db8"), true)
    canvas.draw_rect(rect, border, false, maxf(1.0, viewport_size.x * 0.0014))
    var slot_x := center.x + (-box_size.x * 0.18 if off else box_size.x * 0.18)
    canvas.draw_line(Vector2(slot_x, center.y - box_size.y * 0.23), Vector2(slot_x, center.y + box_size.y * 0.23), Color(accent if off else secondary, 0.68 if available else 0.22), maxf(2.0, viewport_size.x * 0.0032))
    if available and not off:
        var pulse := 0.5 + 0.5 * sin(phase * 4.3)
        canvas.draw_arc(center, box_size.x * (0.60 + pulse * 0.05), 0.0, TAU, 28, Color(secondary, 0.08 + pulse * 0.08), 1.0)
func _render_tuner(canvas, viewport_size: Vector2, phase: float, accent: Color) -> void:
    var center := _px(TUNER_TARGET, viewport_size)
    var tune := clampf(float(state.get("signal_tune", 0.0)), 0.0, 1.0)
    var active := bool(state.get("breaker_off", false))
    var locked := bool(state.get("signal_locked", false))
    var radius := viewport_size.x * 0.060
    canvas.draw_arc(center, radius, PI * 0.18, PI * 1.82, 42, Color(accent, 0.08 + (0.20 if active else 0.0)), maxf(1.0, viewport_size.x * 0.0015))
    canvas.draw_arc(center, radius * 0.79, PI * 0.18, PI * (0.18 + 1.64 * tune), 36, Color(accent, 0.22 + tune * 0.46), maxf(1.0, viewport_size.x * 0.0022))
    var needle_angle := lerpf(PI * 0.82, PI * 2.18, tune)
    var needle_color := Color("72d79a") if locked else accent
    canvas.draw_line(center, center + Vector2.from_angle(needle_angle) * radius * 0.78, Color(needle_color, 0.32 + tune * 0.52), maxf(1.0, viewport_size.x * 0.0020))
    canvas.draw_circle(center, maxf(3.0, viewport_size.x * 0.006), Color(needle_color, 0.58 if active else 0.16))
    if active and not locked:
        var sweep := phase * 2.4
        canvas.draw_arc(center, radius * 1.18, sweep, sweep + PI * 0.65, 18, Color(accent, 0.11), 1.0)
func _draw_cable(canvas, start: Vector2, finish: Vector2, viewport_size: Vector2, color: Color, unplugged: bool, grabbed: bool, phase: float) -> void:
    var points := PackedVector2Array()
    var segments := 18
    var delta := finish - start
    var sag := viewport_size.y * (0.055 if unplugged else 0.035)
    if grabbed:
        var tension: float = clampf(float(int(state.get("tension_bucket", 0))) / 4.0, 0.0, 1.0)
        sag *= lerpf(0.56, 0.20, tension)
    for step in range(segments + 1):
        var t := float(step) / float(segments)
        var point := start.lerp(finish, t)
        point.y += sin(t * PI) * sag
        point.x += sin(t * TAU + phase * 1.8) * viewport_size.x * (0.0016 if grabbed else 0.0026) * sin(t * PI)
        points.append(point)
    canvas.draw_polyline(points, Color("020406dd"), maxf(4.0, viewport_size.x * 0.0075), true)
    canvas.draw_polyline(points, Color(color, 0.72 if grabbed else (0.38 if unplugged else 0.54)), maxf(1.5, viewport_size.x * 0.0032), true)
    if grabbed:
        canvas.draw_polyline(points, Color(color, 0.14), maxf(6.0, viewport_size.x * 0.011), true)
func _draw_plug(canvas, center: Vector2, viewport_size: Vector2, color: Color, unplugged: bool, grabbed: bool) -> void:
    var size_px := Vector2(viewport_size.x * 0.034, viewport_size.y * 0.022)
    var rect := Rect2(center - size_px * 0.5, size_px)
    canvas.draw_rect(rect, Color("070b11ee"), true)
    canvas.draw_rect(rect, Color(color, 0.62 if grabbed else 0.34), false, maxf(1.0, viewport_size.x * 0.0014))
    var pin_color := Color(color, 0.58 if not unplugged else 0.20)
    canvas.draw_line(Vector2(rect.end.x, center.y - size_px.y * 0.23), Vector2(rect.end.x + size_px.x * 0.22, center.y - size_px.y * 0.23), pin_color, maxf(1.0, viewport_size.x * 0.0015))
    canvas.draw_line(Vector2(rect.end.x, center.y + size_px.y * 0.23), Vector2(rect.end.x + size_px.x * 0.22, center.y + size_px.y * 0.23), pin_color, maxf(1.0, viewport_size.x * 0.0015))
func _resisted_cable_point(index: int, touch: Vector2) -> Vector2:
    var origin: Vector2 = CABLE_PLUGS[index]
    var delta: Vector2 = touch - origin
    var distance: float = delta.length()
    if distance <= 0.0001:
        return origin
    var tension: float = clampf(distance / (CABLE_RELEASE_DISTANCE * 1.35), 0.0, 1.0)
    # Visual plug travel deliberately lags behind the finger. The curve gets
    # stiffer near unplug distance, faking resistance without changing the
    # actual generous success threshold used by the gesture.
    var response: float = lerpf(0.92, 0.64, pow(tension, 1.35))
    var micro_drag: float = sin(distance * 173.0) * 0.0022 * tension
    return origin + delta * response + delta.normalized().orthogonal() * micro_drag
func _px(norm: Vector2, viewport_size: Vector2) -> Vector2:
    return Vector2(norm.x * viewport_size.x, norm.y * viewport_size.y)
