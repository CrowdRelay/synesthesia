extends RefCounted

signal reveal_changed(point: Vector2, radius: float)
signal special_interaction(kind: String, index: int)
signal feedback(message: String)

var _behavior
var _reveal_mask
var _interaction_fx
var _last_special_ms: Dictionary = {}

func configure(behavior, reveal_mask, interaction_fx) -> void:
    _behavior = behavior
    _reveal_mask = reveal_mask
    _interaction_fx = interaction_fx
    _last_special_ms.clear()

func reset() -> void:
    _last_special_ms.clear()

func handle_gestures(gestures: Array, progress: float) -> void:
    if _behavior == null or not _behavior.has_method("on_gesture"):
        return
    for gesture_value in gestures:
        var gesture: Dictionary = gesture_value if gesture_value is Dictionary else {}
        if gesture.is_empty():
            continue
        var kind: String = str(gesture.get("kind", ""))
        if kind.is_empty():
            continue
        var fallback: Vector2 = _point(gesture.get("point", Vector2(0.5, 0.5)))
        for event in _behavior.on_gesture(kind, gesture, progress):
            _dispatch(event, fallback)

func handle_paint(point: Vector2, radius: float, progress: float) -> void:
    if _behavior == null:
        return
    for event in _behavior.on_paint(point, radius, progress):
        _dispatch(event, point)

func _dispatch(event: Dictionary, fallback: Vector2) -> void:
    var kind: String = str(event.get("kind", "interaction"))
    var index: int = int(event.get("index", 0))
    var now_ms: int = Time.get_ticks_msec()
    var key: String = "%s:%d" % [kind, index]
    if now_ms - int(_last_special_ms.get(key, 0)) < 140:
        return
    _last_special_ms[key] = now_ms
    var point: Vector2 = _point(event.get("point", fallback))
    var radius: float = clampf(float(event.get("reveal_radius", 0.0)), 0.0, 0.18)
    if radius > 0.0 and _reveal_mask != null and _reveal_mask.apply_stamp({
        "position": point, "radius": radius, "rotation": 0.0,
        "strength": clampf(float(event.get("reveal_strength", 0.84)), 0.15, 1.0),
        "texture": 0.24, "seed": now_ms, "profile": "soft",
    }, true):
        reveal_changed.emit(point, radius)
    if _interaction_fx != null:
        _interaction_fx.spawn(point, kind)
    special_interaction.emit(kind, index)
    var message: String = str(event.get("message", ""))
    if not message.is_empty():
        feedback.emit(message)

func _point(value: Variant) -> Vector2:
    return value if value is Vector2 else Vector2(0.5, 0.5)
