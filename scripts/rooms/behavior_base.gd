extends RefCounted

var room_data: Dictionary = {}
var state: Dictionary = {}

func configure(data: Dictionary) -> void:
    room_data = data.duplicate(true)
    state = {}

func acts() -> Array[String]:
    return ["ROZPOZNANIE", "PRZEŁAMANIE", "TRANSFORMACJA"]

func particle_style() -> String:
    return str(room_data.get("visual_style", "uncertainty"))

func on_paint(_point_norm: Vector2, _radius_norm: float, _progress: float) -> Array[Dictionary]:
    return []

func render(_canvas, _viewport_size: Vector2, _progress: float, _phase: float) -> void:
    pass

func set_cinematic(value: bool) -> void:
    var previous: bool = bool(state.get("_cinematic", false))
    state["_cinematic"] = value
    if value and not previous:
        state["_cinematic_time"] = 0.0

func advance(delta: float) -> void:
    if bool(state.get("_cinematic", false)):
        state["_cinematic_time"] = float(state.get("_cinematic_time", 0.0)) + delta

func cinematic_active() -> bool:
    return bool(state.get("_cinematic", false))

func cinematic_time() -> float:
    return float(state.get("_cinematic_time", 0.0))

func export_state() -> Dictionary:
    return state.duplicate(true)

func restore_state(saved: Dictionary) -> void:
    state = saved.duplicate(true)

func _near(point: Vector2, target: Vector2, radius: float) -> bool:
    return point.distance_to(target) <= radius
