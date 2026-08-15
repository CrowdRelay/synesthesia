extends RefCounted

static func goal(room_data: Dictionary) -> String:
    var micro: Variant = room_data.get("micro_interactions", {})
    return str((micro as Dictionary).get("goal", "")).strip_edges() if micro is Dictionary else ""

static func steps(room_data: Dictionary) -> Array[Dictionary]:
    var micro: Variant = room_data.get("micro_interactions", {})
    if not micro is Dictionary:
        return []
    var raw_steps: Variant = (micro as Dictionary).get("steps", [])
    if not raw_steps is Array:
        return []
    var result: Array[Dictionary] = []
    for value in raw_steps:
        if not value is Dictionary:
            continue
        var step := value as Dictionary
        if str(step.get("verb", "")).strip_edges().is_empty():
            continue
        result.append(step.duplicate(true))
        if result.size() >= 3:
            break
    return result
