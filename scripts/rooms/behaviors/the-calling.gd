extends "res://scripts/rooms/behavior_base.gd"

# Save-state keys intentionally remain poured/toast/glass_position for migration
# compatibility with the V2 journey. Visually this is now a resonance ritual,
# not a literal wine-glass interaction.
const NODE_START := Vector2(0.34, 0.56)
const NODE_TARGET := Vector2(0.50, 0.56)
const CORE_POINT := Vector2(0.50, 0.62)
const WAVE_HEIGHTS := [3.0, 7.0, 12.0, 5.0, 15.0, 8.0, 4.0]

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["poured"] = false
    state["glass_dragging"] = false
    state["glass_position"] = [NODE_START.x, NODE_START.y]
    state["toast"] = false

func acts() -> Array[String]:
    return ["ZAJMIJ MIEJSCE", "OBUDŹ RDZEŃ", "ZSYNCHRONIZUJ RYTUAŁ"]

func interaction_hint() -> String:
    if not bool(state.get("poured", false)):
        return "RDZEŃ STOŁU MILCZY · PRZYTRZYMAJ CZERWONY PULS"
    if not bool(state.get("toast", false)):
        return "WĘZEŁ ODPOWIEDZIAŁ · PRZESUŃ GO DO ŚRODKA SIGILU"
    return "REZONANS ZAMKNIĘTY · POSZUKAJ ECH PRZY OŁTARZU"

func hint_targets() -> Array[Dictionary]:
    if not bool(state.get("poured", false)):
        return [{"point": CORE_POINT, "kind": "hold", "radius": 0.12}]
    if not bool(state.get("toast", false)):
        return [
            {"point": _node_position(), "kind": "drag", "radius": 0.10},
            {"point": NODE_TARGET, "kind": "target", "radius": 0.085},
        ]
    return []

func captures_pointer_at(point_norm: Vector2) -> bool:
    if not bool(state.get("poured", false)) and _near(point_norm, CORE_POINT, 0.16):
        return true
    if not bool(state.get("toast", false)) and (_near(point_norm, _node_position(), 0.14) or bool(state.get("glass_dragging", false))):
        return true
    return false

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var signal_color: Color = Color.from_string(str(room_data.get("secondary_color", "#A40F2D")), Color("a40f2d"))
    var pale: Color = Color.from_string(str(room_data.get("accent_color", "#D8D4C8")), Color("d8d4c8"))
    var center := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.62)
    var pulse := 0.5 + 0.5 * sin(phase * 2.1)

    # Candle/diagnostic pins: atmosphere, not props pasted on the scene.
    for index in range(6):
        var x := lerpf(viewport_size.x * 0.18, viewport_size.x * 0.82, float(index) / 5.0)
        var flicker := 0.65 + 0.35 * sin(phase * (2.3 + index * 0.08) + index * 1.7)
        canvas.draw_line(Vector2(x, viewport_size.y * 0.56), Vector2(x, viewport_size.y * 0.595), Color(pale, 0.035), 1.0)
        canvas.draw_circle(Vector2(x, viewport_size.y * 0.555), 1.8 + flicker * 1.8, Color(signal_color, 0.07 + flicker * 0.07))

    # Resonance basin and etched table rings.
    for ring_index in range(4):
        var rx := 34.0 + ring_index * 22.0 + pulse * 2.0
        canvas.draw_arc(center, rx, -2.85, -0.28, 34, Color(signal_color, 0.065 + progress * 0.05 - ring_index * 0.009), 1.0)
    var affordance := float(assist_level) * 0.035
    canvas.draw_arc(center, 22.0 + pulse * 1.5, -PI, 0.0, 28, Color(pale, 0.10 + affordance), 1.2 + float(assist_level) * 0.10)
    if bool(state.get("poured", false)):
        canvas.draw_circle(center - Vector2(0.0, 4.0), 8.0 + pulse * 1.2, Color(signal_color, 0.10 + pulse * 0.055))
        _draw_wave(canvas, center - Vector2(0.0, 5.0), signal_color, 0.16)

    if not cinematic_active() and not bool(state.get("toast", false)):
        var node_norm := _node_position()
        var node := Vector2(node_norm.x * viewport_size.x, node_norm.y * viewport_size.y)
        _draw_signal_node(canvas, node, signal_color, pale, 0.92 + float(assist_level) * 0.07)
        if bool(state.get("poured", false)):
            canvas.draw_line(node, center, Color(signal_color, 0.035), 1.0)
    elif bool(state.get("toast", false)) and not cinematic_active():
        _draw_signal_node(canvas, center - Vector2(0.0, 14.0), signal_color, pale, 0.58)

    if cinematic_active():
        var t := clampf(cinematic_time() / 1.25, 0.0, 1.0)
        var left := Vector2(viewport_size.x * lerpf(0.31, 0.47, t), viewport_size.y * 0.56)
        var right := Vector2(viewport_size.x * lerpf(0.69, 0.53, t), viewport_size.y * 0.56)
        _draw_signal_node(canvas, left, signal_color, pale, 0.42 + t * 0.25)
        _draw_signal_node(canvas, right, signal_color, pale, 0.42 + t * 0.25)
        var halo := clampf((t - 0.70) / 0.30, 0.0, 1.0)
        for r in range(3):
            canvas.draw_arc(center, 28.0 + r * 18.0 + halo * 24.0, -2.9, -0.2, 36, Color(pale, (0.045 + halo * 0.06) / float(r + 1)), 1.1)

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point := _gesture_point(gesture)
    if kind == "hold" and not bool(state.get("poured", false)) and _near(point, CORE_POINT, 0.15):
        state["poured"] = true
        return [_interaction_event("pour", 0, "Rdzeń rytuału odzyskał kolor", CORE_POINT, 0.085, 0.84)]
    if kind == "press" and _near(point, _node_position(), 0.12):
        state["glass_dragging"] = true
    elif kind == "drag" and bool(state.get("glass_dragging", false)):
        var next := point
        next.x = clampf(next.x, 0.27, 0.63)
        next.y = clampf(next.y, 0.45, 0.64)
        state["glass_position"] = [next.x, next.y]
    elif kind == "release" and bool(state.get("glass_dragging", false)):
        state["glass_dragging"] = false
        if bool(state.get("poured", false)) and _near(_node_position(), NODE_TARGET, 0.105) and not bool(state.get("toast", false)):
            state["toast"] = true
            state["glass_position"] = [NODE_TARGET.x, NODE_TARGET.y]
            return [_interaction_event("toast", 0, "Węzeł wszedł w fazę — rytuał wybrzmiał", NODE_TARGET, 0.12, 0.96)]
    return []

func mechanic_progress() -> float:
    if bool(state.get("toast", false)):
        return 1.0
    var charged := 0.36 if bool(state.get("poured", false)) else 0.0
    var node := _node_position()
    var distance := clampf(node.distance_to(NODE_TARGET) / NODE_START.distance_to(NODE_TARGET), 0.0, 1.0)
    var approach := (1.0 - distance) * (0.56 if bool(state.get("poured", false)) else 0.16)
    return clampf(charged + approach, 0.0, 0.94)

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.62 and not bool(state.get("toast", false)) and _near(point_norm, NODE_TARGET, radius_norm + 0.14):
        state["poured"] = true
        state["toast"] = true
        state["glass_position"] = [NODE_TARGET.x, NODE_TARGET.y]
        return [_interaction_event("toast", 0, "Rytuał zsynchronizowany", NODE_TARGET, 0.09, 0.90)]
    return []

func _node_position() -> Vector2:
    var value: Variant = state.get("glass_position", [NODE_START.x, NODE_START.y])
    return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() >= 2 else NODE_START

func _draw_signal_node(canvas, center: Vector2, signal_color: Color, pale: Color, alpha_scale: float) -> void:
    canvas.draw_circle(center, 18.0, Color(2, 4, 7, 0.18 * alpha_scale))
    canvas.draw_arc(center, 15.0, -2.65, 0.35, 22, Color(signal_color, 0.26 * alpha_scale), 1.4)
    canvas.draw_arc(center, 10.0, 0.55, 3.70, 18, Color(pale, 0.12 * alpha_scale), 1.0)
    canvas.draw_circle(center, 2.3, Color(signal_color, 0.32 * alpha_scale))
    _draw_wave(canvas, center, signal_color, 0.16 * alpha_scale)

func _draw_wave(canvas, center: Vector2, color: Color, alpha: float) -> void:
    for index in range(WAVE_HEIGHTS.size()):
        var x := center.x + (index - 3) * 4.0
        var h: float = WAVE_HEIGHTS[index]
        canvas.draw_line(Vector2(x, center.y - h * 0.5), Vector2(x, center.y + h * 0.5), Color(color, alpha), 1.0)
