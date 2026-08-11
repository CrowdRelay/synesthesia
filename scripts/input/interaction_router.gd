extends RefCounted

const RustGestureBackend := preload("res://scripts/native/rust_gesture_backend.gd")

## Small allocation-conscious gesture recognizer for room-local normalized input.
## It intentionally produces semantic dictionaries instead of Nodes/signals so the
## RoomStage owns lifetime, save state and rendering. All thresholds use normalized
## room coordinates, which keeps behavior consistent across mobile/web/desktop.

const TAP_MAX_MS: int = 340
const HOLD_MS: int = 560
const TAP_DISTANCE: float = 0.042
const HOLD_DISTANCE: float = 0.055
const SWIPE_DISTANCE: float = 0.16
const SWIPE_MAX_MS: int = 950
const DRAG_MIN_STEP: float = 0.0035

var _native_backend: RefCounted = RustGestureBackend.new()
var _pointers: Dictionary = {}
var _active_points: Dictionary = {}
var _two_finger_start_spread: float = 0.0
var _two_finger_active: bool = false

func reset() -> void:
    _active_points.clear()
    _pointers.clear()
    if _native_backend.available():
        _native_backend.reset()
    _two_finger_start_spread = 0.0
    _two_finger_active = false

func active_pointer_count() -> int:
    return _active_points.size()

func has_pointer(pointer_id: int) -> bool:
    return _active_points.has(pointer_id)

func needs_tick() -> bool:
    return not _active_points.is_empty()

func single_pointer() -> Dictionary:
    if _active_points.size() != 1:
        return {}
    var raw_id: Variant = _active_points.keys()[0]
    return {"pointer_id": int(raw_id), "point": _point(_active_points.get(raw_id, Vector2(0.5, 0.5)))}

func pointer_down(pointer_id: int, point: Vector2, now_ms: int) -> Array:
    var p: Vector2 = _clamp_point(point)
    _active_points[pointer_id] = p
    if _native_backend.available():
        return _native_backend.pointer_down(pointer_id, p, now_ms)
    _pointers[pointer_id] = {
        "start": p,
        "last": p,
        "previous": p,
        "start_ms": now_ms,
        "last_ms": now_ms,
        "distance": 0.0,
        "hold_emitted": false,
    }
    var events: Array[Dictionary] = [_event("press", pointer_id, p, p, Vector2.ZERO, 0, 0.0, 0.0)]
    if _pointers.size() == 2:
        var pair: Array[Dictionary] = _two_pointer_states()
        if pair.size() == 2:
            _two_finger_start_spread = _point(pair[0].get("last", p)).distance_to(_point(pair[1].get("last", p)))
            _two_finger_active = true
            events.append(_two_finger_event("two_finger_start", now_ms))
    return events

func pointer_move(pointer_id: int, point: Vector2, now_ms: int) -> Array:
    var native_point: Vector2 = _clamp_point(point)
    if _active_points.has(pointer_id):
        _active_points[pointer_id] = native_point
    if _native_backend.available():
        return _native_backend.pointer_move(pointer_id, native_point, now_ms)
    if not _pointers.has(pointer_id):
        _active_points.erase(pointer_id)
        return []
    var state_value: Variant = _pointers[pointer_id]
    var state: Dictionary = state_value if state_value is Dictionary else {}
    var previous: Vector2 = _point(state.get("last", point))
    var current: Vector2 = native_point
    var step: Vector2 = current - previous
    var step_distance: float = step.length()
    state["previous"] = previous
    state["last"] = current
    state["distance"] = float(state.get("distance", 0.0)) + step_distance
    var previous_ms: int = int(state.get("last_ms", now_ms))
    state["last_ms"] = now_ms
    _pointers[pointer_id] = state

    var events: Array[Dictionary] = []
    if step_distance >= DRAG_MIN_STEP:
        var elapsed_ms: int = maxi(1, now_ms - int(state.get("start_ms", now_ms)))
        var step_ms: int = maxi(1, now_ms - previous_ms)
        var velocity: float = step_distance / (float(step_ms) / 1000.0)
        events.append(_event(
            "drag",
            pointer_id,
            _point(state.get("start", current)),
            current,
            step,
            elapsed_ms,
            float(state.get("distance", 0.0)),
            velocity,
        ))
    if _two_finger_active and _pointers.size() >= 2:
        events.append(_two_finger_event("two_finger", now_ms))
    return events

func pointer_up(pointer_id: int, point: Vector2, now_ms: int) -> Array:
    var native_point: Vector2 = _clamp_point(point)
    if _native_backend.available():
        var native_events: Array = _native_backend.pointer_up(pointer_id, native_point, now_ms)
        _active_points.erase(pointer_id)
        return native_events
    if not _pointers.has(pointer_id):
        _active_points.erase(pointer_id)
        return []
    var state_value: Variant = _pointers[pointer_id]
    var state: Dictionary = state_value if state_value is Dictionary else {}
    var current: Vector2 = native_point
    var start: Vector2 = _point(state.get("start", current))
    var displacement: float = start.distance_to(current)
    var path_distance: float = maxf(float(state.get("distance", 0.0)), displacement)
    var elapsed_ms: int = maxi(0, now_ms - int(state.get("start_ms", now_ms)))
    var delta: Vector2 = current - start
    var elapsed_seconds: float = maxf(0.001, float(maxi(1, elapsed_ms)) / 1000.0)
    var path_velocity: float = path_distance / elapsed_seconds
    var swipe_velocity: float = displacement / elapsed_seconds
    var events: Array[Dictionary] = []

    # Match the Rust core exactly: travelled path rejects scribbles as taps,
    # while net displacement is what makes a gesture a directional swipe.
    if elapsed_ms <= TAP_MAX_MS and path_distance <= TAP_DISTANCE:
        events.append(_event("tap", pointer_id, start, current, delta, elapsed_ms, path_distance, path_velocity))
    elif elapsed_ms <= SWIPE_MAX_MS and displacement >= SWIPE_DISTANCE:
        events.append(_event("swipe", pointer_id, start, current, delta, elapsed_ms, displacement, swipe_velocity))
    events.append(_event("release", pointer_id, start, current, delta, elapsed_ms, path_distance, path_velocity))

    var was_two_finger: bool = _two_finger_active and _pointers.size() >= 2
    if was_two_finger:
        events.append(_two_finger_event("two_finger_end", now_ms))
    _pointers.erase(pointer_id)
    _active_points.erase(pointer_id)
    if _pointers.size() < 2:
        _two_finger_active = false
        _two_finger_start_spread = 0.0
    return events

func advance(now_ms: int) -> Array:
    if _native_backend.available():
        return _native_backend.advance(now_ms)
    var events: Array[Dictionary] = []
    var ids: Array = _pointers.keys()
    for raw_id in ids:
        var pointer_id: int = int(raw_id)
        var state_value: Variant = _pointers.get(pointer_id, {})
        var state: Dictionary = state_value if state_value is Dictionary else {}
        if bool(state.get("hold_emitted", false)):
            continue
        var elapsed_ms: int = now_ms - int(state.get("start_ms", now_ms))
        if elapsed_ms < HOLD_MS or float(state.get("distance", 0.0)) > HOLD_DISTANCE:
            continue
        state["hold_emitted"] = true
        _pointers[pointer_id] = state
        var start: Vector2 = _point(state.get("start", Vector2(0.5, 0.5)))
        var current: Vector2 = _point(state.get("last", start))
        events.append(_event("hold", pointer_id, start, current, current - start, elapsed_ms, float(state.get("distance", 0.0)), 0.0))
    return events

func _event(kind: String, pointer_id: int, start: Vector2, point: Vector2, delta: Vector2, duration_ms: int, distance: float, velocity: float) -> Dictionary:
    return {
        "kind": kind,
        "pointer_id": pointer_id,
        "start": start,
        "point": point,
        "delta": delta,
        "duration_ms": duration_ms,
        "distance": distance,
        "velocity": velocity,
        "pointer_count": _pointers.size(),
    }

func _two_finger_event(kind: String, now_ms: int) -> Dictionary:
    var pair: Array[Dictionary] = _two_pointer_states()
    if pair.size() < 2:
        return {"kind": kind, "point": Vector2(0.5, 0.5), "spread_delta": 0.0, "pointer_count": _pointers.size()}
    var a: Vector2 = _point(pair[0].get("last", Vector2(0.5, 0.5)))
    var b: Vector2 = _point(pair[1].get("last", Vector2(0.5, 0.5)))
    var spread: float = a.distance_to(b)
    return {
        "kind": kind,
        "point": (a + b) * 0.5,
        "start": (a + b) * 0.5,
        "delta": Vector2.ZERO,
        "duration_ms": 0,
        "distance": 0.0,
        "velocity": 0.0,
        "spread": spread,
        "spread_delta": spread - _two_finger_start_spread,
        "pointer_count": _pointers.size(),
        "time_ms": now_ms,
    }

func _two_pointer_states() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for raw_id in _pointers.keys():
        var value: Variant = _pointers[raw_id]
        if value is Dictionary:
            result.append(value)
        if result.size() == 2:
            break
    return result

func _point(value: Variant) -> Vector2:
    return value if value is Vector2 else Vector2(0.5, 0.5)

func _clamp_point(value: Vector2) -> Vector2:
    return Vector2(clampf(value.x, 0.0, 1.0), clampf(value.y, 0.0, 1.0))

## Translate a Godot GUI input event into normalized gesture + stroke commands.
## RoomStage remains responsible for the brush and render state.
func route_input(event: InputEvent, room_size: Vector2, now_ms: int, drawing: bool, drawing_pointer_id: int, touch_origin: Vector2 = Vector2.ZERO) -> Dictionary:
    if room_size.x <= 1.0 or room_size.y <= 1.0:
        return {}
    var result: Dictionary = {"handled": false, "stroke": "", "pointer_id": -999}
    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event as InputEventScreenTouch
        # ScreenTouch/ScreenDrag positions stay in viewport coordinates even
        # when delivered through Control._gui_input. The room may be a cropped
        # 9:16 cover rect with a negative origin on tall phones, so translate
        # into room-local coordinates before normalizing against the mask.
        var point: Vector2 = _normalize_local(touch.position - touch_origin, room_size)
        result["handled"] = true
        result["point"] = point
        result["pointer_id"] = touch.index
        if touch.pressed:
            result["gestures"] = pointer_down(touch.index, point, now_ms)
            result["stroke"] = "begin" if active_pointer_count() == 1 else ("end" if drawing else "")
        else:
            result["gestures"] = pointer_up(touch.index, point, now_ms)
            result["stroke"] = "end" if drawing_pointer_id == touch.index else ""
            if not drawing and active_pointer_count() == 1:
                var remaining: Dictionary = single_pointer()
                result["point"] = remaining.get("point", point)
                result["pointer_id"] = int(remaining.get("pointer_id", -999))
                result["stroke"] = "begin"
    elif event is InputEventScreenDrag:
        var drag: InputEventScreenDrag = event as InputEventScreenDrag
        var point: Vector2 = _normalize_local(drag.position - touch_origin, room_size)
        result["handled"] = true
        result["point"] = point
        result["pointer_id"] = drag.index
        result["gestures"] = pointer_move(drag.index, point, now_ms)
        result["stroke"] = "continue" if drawing and drawing_pointer_id == drag.index and active_pointer_count() == 1 else ""
    elif event is InputEventMouseButton:
        var button: InputEventMouseButton = event as InputEventMouseButton
        if button.button_index != MOUSE_BUTTON_LEFT:
            return result
        var point: Vector2 = _normalize_local(button.position, room_size)
        result["handled"] = true
        result["point"] = point
        result["pointer_id"] = -1
        if button.pressed:
            result["gestures"] = pointer_down(-1, point, now_ms)
            result["stroke"] = "begin"
        else:
            result["gestures"] = pointer_up(-1, point, now_ms)
            result["stroke"] = "end"
    elif event is InputEventMouseMotion:
        var motion: InputEventMouseMotion = event as InputEventMouseMotion
        var point: Vector2 = _normalize_local(motion.position, room_size)
        result["handled"] = true
        result["point"] = point
        result["pointer_id"] = -1
        result["gestures"] = pointer_move(-1, point, now_ms) if has_pointer(-1) else []
        result["stroke"] = "continue" if drawing else ""
    return result

func _normalize_local(point: Vector2, room_size: Vector2) -> Vector2:
    return Vector2(clampf(point.x / maxf(1.0, room_size.x), 0.0, 1.0), clampf(point.y / maxf(1.0, room_size.y), 0.0, 1.0))
