extends RefCounted

var room_data: Dictionary = {}
var state: Dictionary = {}
var interaction_forgiveness: float = 1.12
var assist_level: int = 0
var resonance_memory_strength: float = 0.0

# Ward paintings are now the source of truth for physical prop placement. The
# room mechanics keep stable logical coordinates; these anchors adapt touch and
# haptic/event points to the authored compositions without changing save state.
const ART_ANCHORS := {
    "party-time": [
        [Vector2(0.19, 0.31), Vector2(0.22, 0.39)],
        [Vector2(0.37, 0.23), Vector2(0.27, 0.42)],
        [Vector2(0.59, 0.29), Vector2(0.23, 0.46)],
        [Vector2(0.78, 0.22), Vector2(0.45, 0.42)],
        [Vector2(0.28, 0.49), Vector2(0.20, 0.80)],
        [Vector2(0.69, 0.51), Vector2(0.82, 0.70)],
    ],
    "unmasked": [
        [Vector2(0.27, 0.31), Vector2(0.18, 0.32)],
        [Vector2(0.50, 0.24), Vector2(0.31, 0.28)],
        [Vector2(0.73, 0.32), Vector2(0.43, 0.36)],
    ],
    "the-calling": [
        [Vector2(0.34, 0.56), Vector2(0.33, 0.61)],
        [Vector2(0.50, 0.56), Vector2(0.50, 0.61)],
        [Vector2(0.50, 0.62), Vector2(0.50, 0.64)],
    ],
    "seed-of-doubt": [
        [Vector2(0.50, 0.74), Vector2(0.50, 0.70)],
        [Vector2(0.50, 0.30), Vector2(0.50, 0.27)],
    ],
    "hybrid": [
        [Vector2(0.50, 0.46), Vector2(0.50, 0.37)],
    ],
    "technophobia": [
        [Vector2(0.185, 0.182), Vector2(0.30, 0.555)],
        [Vector2(0.470, 0.182), Vector2(0.45, 0.485)],
        [Vector2(0.756, 0.182), Vector2(0.80, 0.525)],
        [Vector2(0.185, 0.303), Vector2(0.455, 0.548)],
        [Vector2(0.470, 0.303), Vector2(0.59, 0.525)],
        [Vector2(0.756, 0.303), Vector2(0.58, 0.575)],
        [Vector2(0.185, 0.424), Vector2(0.29, 0.555)],
        [Vector2(0.20, 0.35), Vector2(0.30, 0.575)],
        [Vector2(0.49, 0.35), Vector2(0.46, 0.575)],
        [Vector2(0.77, 0.35), Vector2(0.80, 0.575)],
        [Vector2(0.28, 0.58), Vector2(0.40, 0.62)],
        [Vector2(0.51, 0.61), Vector2(0.52, 0.64)],
        [Vector2(0.73, 0.57), Vector2(0.64, 0.62)],
        [Vector2(0.18, 0.67), Vector2(0.10, 0.40)],
        [Vector2(0.76, 0.69), Vector2(0.58, 0.59)],
    ],
    "invaluable": [
        [Vector2(0.22, 0.35), Vector2(0.40, 0.34)],
        [Vector2(0.50, 0.29), Vector2(0.50, 0.30)],
        [Vector2(0.78, 0.35), Vector2(0.60, 0.34)],
        [Vector2(0.38, 0.57), Vector2(0.44, 0.46)],
        [Vector2(0.64, 0.57), Vector2(0.56, 0.46)],
    ],
    "from-the-ashes": [
        [Vector2(0.50, 0.52), Vector2(0.50, 0.74)],
        [Vector2(0.50, 0.48), Vector2(0.50, 0.72)],
    ],
    "waves": [
        [Vector2(0.42, 0.58), Vector2(0.29, 0.61)],
        [Vector2(0.58, 0.58), Vector2(0.71, 0.61)],
        [Vector2(0.47, 0.58), Vector2(0.43, 0.61)],
        [Vector2(0.53, 0.58), Vector2(0.57, 0.61)],
    ],
    "rise": [
        [Vector2(0.50, 0.20), Vector2(0.50, 0.25)],
        [Vector2(0.50, 0.54), Vector2(0.50, 0.58)],
        [Vector2(0.50, 0.46), Vector2(0.50, 0.50)],
        [Vector2(0.50, 0.34), Vector2(0.50, 0.40)],
    ],
}

func configure(data: Dictionary) -> void:
    room_data = data.duplicate(true)
    state = {}
    interaction_forgiveness = 1.12
    assist_level = 0
    resonance_memory_strength = 0.0

func acts() -> Array[String]:
    return ["ROZPOZNANIE", "PRZEŁAMANIE", "TRANSFORMACJA"]

func particle_style() -> String:
    return str(room_data.get("visual_style", "uncertainty"))

func interaction_hint() -> String:
    return "DOTKNIJ ŚWIATA"

func hint_targets() -> Array[Dictionary]:
    return []

func mechanic_progress() -> float:
    return 0.0

func brush_assist_weight() -> float:
    return 0.22

func captures_pointer_at(_point_norm: Vector2) -> bool:
    return false

func on_paint(_point_norm: Vector2, _radius_norm: float, _progress: float) -> Array[Dictionary]:
    return []

func on_gesture(_kind: String, _gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    return []

func render(_canvas, _viewport_size: Vector2, _progress: float, _phase: float) -> void:
    pass

func set_cinematic(value: bool) -> void:
    var previous: bool = bool(state.get("_cinematic", false))
    state["_cinematic"] = value
    if value and not previous:
        state["_cinematic_time"] = 0.0

func needs_tick() -> bool:
    return cinematic_active()

func advance(delta: float) -> void:
    if cinematic_active():
        state["_cinematic_time"] = float(state.get("_cinematic_time", 0.0)) + delta

func cinematic_active() -> bool:
    return bool(state.get("_cinematic", false))

func cinematic_time() -> float:
    return float(state.get("_cinematic_time", 0.0))

func export_state() -> Dictionary:
    return state.duplicate(true)

func restore_state(saved: Dictionary) -> void:
    state = saved.duplicate(true)

func set_resonance_memory(memory: Dictionary) -> void:
    if memory.is_empty():
        resonance_memory_strength = 0.0
        return
    var echo_type: String = str(memory.get("echo_type", "signal_trace"))
    resonance_memory_strength = 0.08 if echo_type in ["gesture_trace", "interaction_trace", "mechanic_trace"] else 0.06

func set_assist_level(level: int) -> void:
    assist_level = clampi(level, 0, 3)
    interaction_forgiveness = [1.12, 1.20, 1.30, 1.40][assist_level]

func _near(point: Vector2, target: Vector2, radius: float) -> bool:
    var forgiving_radius: float = radius * (interaction_forgiveness + resonance_memory_strength)
    var r2 := forgiving_radius * forgiving_radius
    return point.distance_squared_to(target) <= r2 or point.distance_squared_to(_art_point(target)) <= r2

func _gesture_point(gesture: Dictionary) -> Vector2:
    var value: Variant = gesture.get("point", Vector2(0.5, 0.5))
    var point: Vector2 = value if value is Vector2 else Vector2(0.5, 0.5)
    return _logic_point(point)

func _gesture_start(gesture: Dictionary) -> Vector2:
    var value: Variant = gesture.get("start", Vector2(0.5, 0.5))
    var point: Vector2 = value if value is Vector2 else _gesture_point(gesture)
    return _logic_point(point)

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
    return minf(_segment_distance(point, start, finish), _segment_distance(_art_point(point), _art_point(start), _art_point(finish)))

func _segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
    var segment: Vector2 = finish - start
    var length_squared: float = segment.length_squared()
    if length_squared <= 0.000001:
        return point.distance_to(start)
    var t: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
    return point.distance_to(start + segment * t)

func _interaction_event(kind: String, index: int, message: String, point: Vector2, reveal_radius: float = 0.075, reveal_strength: float = 0.84) -> Dictionary:
    return {
        "kind": kind,
        "index": index,
        "message": message,
        "point": _art_point(point),
        "reveal_radius": reveal_radius * (1.0 + resonance_memory_strength),
        "reveal_strength": clampf(reveal_strength + resonance_memory_strength * 0.50, 0.0, 1.0),
    }

func _anchor_pairs() -> Array:
    var value: Variant = ART_ANCHORS.get(str(room_data.get("id", "")), [])
    return value if value is Array else []

func _art_point(logic_point: Vector2) -> Vector2:
    var pairs := _anchor_pairs()
    if pairs.is_empty(): return logic_point
    var best_logic := Vector2.ZERO
    var best_art := Vector2.ZERO
    var best_distance := INF
    for pair_value in pairs:
        if not (pair_value is Array) or pair_value.size() < 2: continue
        var logic: Vector2 = pair_value[0]
        var art: Vector2 = pair_value[1]
        var distance := logic_point.distance_squared_to(logic)
        if distance < best_distance:
            best_distance = distance
            best_logic = logic
            best_art = art
    if best_distance > 0.055 * 0.055: return logic_point
    return (best_art + (logic_point - best_logic)).clamp(Vector2.ZERO, Vector2.ONE)

func _art_offset_point(logic_origin: Vector2, logic_point: Vector2) -> Vector2:
    return (_art_point(logic_origin) + (logic_point - logic_origin)).clamp(Vector2.ZERO, Vector2.ONE)

func _art_lerp_point(logic_start: Vector2, logic_finish: Vector2, weight: float) -> Vector2:
    return _art_point(logic_start).lerp(_art_point(logic_finish), clampf(weight, 0.0, 1.0))

func _logic_point(art_point: Vector2) -> Vector2:
    var pairs := _anchor_pairs()
    if pairs.is_empty(): return art_point
    var best_logic := Vector2.ZERO
    var best_art := Vector2.ZERO
    var best_distance := INF
    for pair_value in pairs:
        if not (pair_value is Array) or pair_value.size() < 2: continue
        var logic: Vector2 = pair_value[0]
        var art: Vector2 = pair_value[1]
        var distance := art_point.distance_squared_to(art)
        if distance < best_distance:
            best_distance = distance
            best_logic = logic
            best_art = art
    if best_distance > 0.22 * 0.22: return art_point
    return (best_logic + (art_point - best_art)).clamp(Vector2.ZERO, Vector2.ONE)
