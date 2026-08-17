class_name WebE2EProbe
extends RefCounted

const QUERY_FLAG := "virya_e2e"
const EVENT_NAME := "synesthesia:e2e-state"

static func enabled() -> bool:
    if not OS.has_feature("web"):
        return false
    var value: Variant = JavaScriptBridge.eval(
        "new URLSearchParams(location.search).get('%s') === '1'" % QUERY_FLAG,
        true,
    )
    return bool(value)

static func emit(kind: String, payload: Dictionary = {}) -> void:
    if not enabled():
        return
    var detail := payload.duplicate(true)
    detail["kind"] = kind
    var encoded := JSON.stringify(detail)
    JavaScriptBridge.eval(
        "window.dispatchEvent(new CustomEvent('%s',{detail:%s}));" % [EVENT_NAME, encoded],
        true,
    )

static func room_state(room_id: String, targets: Array, progress: float, coverage: float, interaction_enabled: bool, viewport: Vector2) -> void:
    if not enabled():
        return
    var encoded_targets: Array[Dictionary] = []
    for value in targets:
        if not value is Dictionary:
            continue
        var target: Dictionary = value
        var point_value: Variant = target.get("point", Vector2(0.5, 0.5))
        var point: Vector2 = point_value if point_value is Vector2 else Vector2(0.5, 0.5)
        encoded_targets.append({
            "x": clampf(point.x, 0.0, 1.0),
            "y": clampf(point.y, 0.0, 1.0),
            "kind": str(target.get("kind", "tap")),
            "radius": clampf(float(target.get("radius", 0.10)), 0.01, 0.50),
        })
    emit("room", {
        "roomId": room_id,
        "progress": progress,
        "coverage": coverage,
        "interactionEnabled": interaction_enabled,
        "targets": encoded_targets,
        "viewportWidth": viewport.x,
        "viewportHeight": viewport.y,
    })

static func control_action(kind: String, key: String, control: Control, viewport: Vector2, extra: Dictionary = {}) -> void:
    if not enabled() or control == null:
        return
    var rect := control.get_global_rect()
    var payload := extra.duplicate(true)
    payload[key] = {
        "x": rect.position.x,
        "y": rect.position.y,
        "w": rect.size.x,
        "h": rect.size.y,
    }
    payload["viewportWidth"] = viewport.x
    payload["viewportHeight"] = viewport.y
    emit(kind, payload)

static func control_action_deferred(kind: String, key: String, control: Control, viewport: Vector2, extra: Dictionary = {}) -> void:
    if not enabled() or control == null:
        return
    await control.get_tree().process_frame
    control_action(kind, key, control, viewport, extra)

static func audio_state(room_id: String, director) -> void:
    if not enabled() or director == null or not is_instance_valid(director) or not director.has_method("e2e_state"):
        return
    var payload: Dictionary = director.e2e_state()
    payload["roomId"] = room_id
    emit("audio", payload)
