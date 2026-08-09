extends RefCounted

var room_data: Dictionary = {}
var state: Dictionary = {}
var interaction_forgiveness: float = 1.12

func configure(data: Dictionary) -> void:
    room_data = data.duplicate(true)
    state = {}
    interaction_forgiveness = 1.12

func acts() -> Array[String]:
    return ["ROZPOZNANIE", "PRZEŁAMANIE", "TRANSFORMACJA"]

func particle_style() -> String:
    return str(room_data.get("visual_style", "uncertainty"))

## Short diegetic prompt. It is intentionally a verb, not a tutorial sentence.
func interaction_hint() -> String:
    return "DOTKNIJ ŚWIATA"

## V2 progression is mechanic-first: every room owns a different way of
## reducing interference. The reveal brush only assists/localizes the effect.
func mechanic_progress() -> float:
    return 0.0

func brush_assist_weight() -> float:
    return 0.22

## Painting remains a fallback/reveal layer for every room. Gesture-driven rooms
## can return semantic events from on_gesture without replacing the mask system.
func on_paint(_point_norm: Vector2, _radius_norm: float, _progress: float) -> Array[Dictionary]:
    return []

## Semantic gesture API. Gesture dictionaries are produced by InteractionRouter
## and always use normalized coordinates. Returned events may include:
## kind/index/message/reveal_radius/reveal_strength/point.
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

func set_assist_level(level: int) -> void:
    # Assist changes only invisible touch tolerance. Visual geometry and mechanic
    # state stay identical, so help can rise/fall without changing the room.
    interaction_forgiveness = [1.12, 1.18, 1.25, 1.32][clampi(level, 0, 3)]

func _near(point: Vector2, target: Vector2, radius: float) -> bool:
    # Touch targets are intentionally a little more forgiving than their visual
    # geometry. This keeps precision from becoming difficulty on small phones.
    var forgiving_radius: float = radius * interaction_forgiveness
    return point.distance_squared_to(target) <= forgiving_radius * forgiving_radius

func _gesture_point(gesture: Dictionary) -> Vector2:
    var value: Variant = gesture.get("point", Vector2(0.5, 0.5))
    return value if value is Vector2 else Vector2(0.5, 0.5)

func _gesture_start(gesture: Dictionary) -> Vector2:
    var value: Variant = gesture.get("start", _gesture_point(gesture))
    return value if value is Vector2 else _gesture_point(gesture)

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
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
        "point": point,
        "reveal_radius": reveal_radius,
        "reveal_strength": reveal_strength,
    }
