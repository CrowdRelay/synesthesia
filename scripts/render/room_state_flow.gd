extends Node

const MechanicProgress := preload("res://scripts/rooms/mechanic_progress.gd")

var app: Control

func bind(owner: Control) -> void:
    app = owner

func reset_room() -> void:
    app.reveal_mask.clear()
    if app.behavior != null:
        app.behavior.configure(app.manifest_room)
    if app.interaction_router != null:
        app.interaction_router.reset()
    if app.interaction_runtime != null:
        app.interaction_runtime.reset()
    for item in app.collectibles:
        item["found"] = false
        item["semantic_ready"] = str(item.get("semantic_kind", "")).is_empty()
    app.set_cinematic_reveal(false, true)
    app._cinematic_elapsed = 0.0
    app.target_parallax = Vector2.ZERO
    app._brush_energy = 0.0
    app.composite_material.set_shader_parameter("completion_reveal", 0.0)
    app.composite_material.set_shader_parameter("brush_energy", 0.0)
    app.interaction_fx.clear()
    app.door_target_open = false
    app.door_open_amount = 0.0
    app.current_progress = 0.0
    app.current_act = -1
    app._set_progress_from_mask()
    app.coverage_changed.emit(0.0)
    app.queue_redraw()

func get_found_count() -> int:
    var count: int = 0
    for item in app.collectibles:
        if bool(item.get("found", false)):
            count += 1
    return count

func get_coverage() -> float: return app.reveal_mask.coverage() if app.reveal_mask != null else 0.0

func get_normalized_progress() -> float:
    if app.cinematic_revealed:
        return 1.0
    return MechanicProgress.resolve(clampf(get_coverage() / app.completion_threshold, 0.0, 1.0), app.behavior)

func get_current_act() -> int: return app.current_act

func export_state() -> Dictionary:
    var found_ids: Array[String] = []
    var semantic_ready_ids: Array[String] = []
    for item in app.collectibles:
        var item_id := str(item.get("id", ""))
        if bool(item.get("found", false)):
            found_ids.append(item_id)
        if not str(item.get("semantic_kind", "")).is_empty() and bool(item.get("semantic_ready", false)):
            semantic_ready_ids.append(item_id)
    return {
        "renderer": "mask-v2",
        "mask": app.reveal_mask.export_state(),
        "behavior": app.behavior.export_state() if app.behavior != null else {},
        "found_collectibles": found_ids,
        "semantic_ready_collectibles": semantic_ready_ids,
        "cinematic_revealed": app.cinematic_revealed,
        "door_open": app.door_target_open,
    }

func restore_state(saved: Dictionary) -> bool:
    if app.reveal_mask == null:
        return false
    var mask_value: Variant = saved.get("mask", saved)
    var mask_state: Dictionary = mask_value if mask_value is Dictionary else {}
    var brush_value: Variant = app.manifest_room.get("brush", {})
    var brush: Dictionary = brush_value if brush_value is Dictionary else {}
    var restored: bool = app.reveal_mask.restore_state(mask_state, str(brush.get("profile", "soft")))
    var found_lookup: Dictionary = {}
    var found_value: Variant = saved.get("found_collectibles", [])
    if found_value is Array:
        for raw_id in found_value:
            found_lookup[str(raw_id)] = true
    var semantic_lookup: Dictionary = {}
    var legacy_semantic_save: bool = not saved.has("semantic_ready_collectibles")
    var semantic_value: Variant = saved.get("semantic_ready_collectibles", [])
    if semantic_value is Array:
        for raw_id in semantic_value:
            semantic_lookup[str(raw_id)] = true
    for item in app.collectibles:
        var item_id := str(item.get("id", ""))
        item["found"] = bool(found_lookup.get(item_id, false))
        item["semantic_ready"] = legacy_semantic_save or str(item.get("semantic_kind", "")).is_empty() or bool(semantic_lookup.get(item_id, false)) or bool(item.get("found", false))
    var behavior_value: Variant = saved.get("behavior", saved.get("special_state", {}))
    if app.behavior != null and behavior_value is Dictionary:
        app.behavior.restore_state(behavior_value)
    app.cinematic_revealed = bool(saved.get("cinematic_revealed", false))
    app.door_target_open = bool(saved.get("door_open", false))
    app.door_open_amount = 1.0 if app.door_target_open else 0.0
    app._set_progress_from_mask()
    if app.cinematic_revealed:
        app.set_cinematic_reveal(true, true)
    app.queue_redraw()
    return restored

func reveal_remaining_collectibles() -> Array[Dictionary]:
    var revealed: Array[Dictionary] = []
    for item in app.collectibles:
        if bool(item.get("found", false)):
            continue
        item["found"] = true
        var copy: Dictionary = item.duplicate(true)
        revealed.append(copy)
        app.collectible_found.emit(copy)
    return revealed
