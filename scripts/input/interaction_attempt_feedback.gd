extends RefCounted

signal missed(point: Vector2)
signal confirmed(point: Vector2, strength: float)

const PROGRESS_EPSILON: float = 0.0025
const MISS_COOLDOWN_MS: int = 650
const CONFIRM_COOLDOWN_MS: int = 90

var _generation: int = 0
var _stroke_generation: int = 0
var _stroke_progress: float = 0.0
var _last_progress: float = 0.0
var _last_miss_ms: int = -MISS_COOLDOWN_MS
var _last_confirm_ms: int = -CONFIRM_COOLDOWN_MS

func generation() -> int:
    return _generation

func success(point: Vector2, strength: float = 0.6, progress: float = -1.0) -> void:
    _generation += 1
    if progress >= 0.0:
        _last_progress = maxf(_last_progress, clampf(progress, 0.0, 1.0))
    var now_ms: int = Time.get_ticks_msec()
    if now_ms - _last_confirm_ms < CONFIRM_COOLDOWN_MS:
        return
    _last_confirm_ms = now_ms
    confirmed.emit(_clamp_point(point), clampf(strength, 0.0, 1.0))

func begin_stroke(progress: float) -> void:
    _stroke_generation = _generation
    _stroke_progress = clampf(progress, 0.0, 1.0)

func end_stroke(progress: float, point: Vector2) -> void:
    var current_progress: float = clampf(progress, 0.0, 1.0)
    var made_progress: bool = current_progress >= _stroke_progress + PROGRESS_EPSILON
    if made_progress:
        _last_progress = maxf(_last_progress, current_progress)
    if not made_progress and _generation == _stroke_generation:
        _emit_miss(point)

func note_gesture_batch(gestures: Array, generation_before: int, fallback: Vector2) -> void:
    if _generation != generation_before:
        return
    var completed: bool = false
    var point: Vector2 = fallback
    for gesture_value in gestures:
        var gesture: Dictionary = gesture_value if gesture_value is Dictionary else {}
        var kind: String = str(gesture.get("kind", ""))
        if kind in ["tap", "hold", "swipe", "two_finger_end"]:
            completed = true
            var point_value: Variant = gesture.get("point", fallback)
            point = point_value if point_value is Vector2 else fallback
    if completed:
        _emit_miss(point)

func _emit_miss(point: Vector2) -> void:
    var now_ms: int = Time.get_ticks_msec()
    if now_ms - _last_miss_ms < MISS_COOLDOWN_MS:
        return
    _last_miss_ms = now_ms
    missed.emit(_clamp_point(point))

func _clamp_point(point: Vector2) -> Vector2:
    return Vector2(clampf(point.x, 0.0, 1.0), clampf(point.y, 0.0, 1.0))
