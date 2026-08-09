class_name ProgressMetrics
extends RefCounted

const ProgressStoreScript := preload("res://scripts/progress_store.gd")
const ReleaseReader := preload("res://scripts/app/release_reader.gd")

static func experience_summary(release_entries: Array, current_room_index: int, album_state: Dictionary) -> Dictionary:
    var room_name: String = "kolejny pokój"
    if current_room_index >= 0 and current_room_index < release_entries.size():
        var entry_value: Variant = release_entries[current_room_index]
        if entry_value is Dictionary:
            var room_manifest: Dictionary = ReleaseReader.load_json(str((entry_value as Dictionary).get("manifest", "")))
            var room_value: Variant = room_manifest.get("room", {})
            if room_value is Dictionary:
                room_name = str((room_value as Dictionary).get("name", room_name))
    var completed_ids: Array = _array_value(album_state.get("completed_room_ids", []))
    var elapsed_value: Variant = album_state.get("room_elapsed_ms", {})
    var elapsed: Dictionary = elapsed_value if elapsed_value is Dictionary else {}
    return {
        "room_number": current_room_index + 1,
        "room_total": release_entries.size(),
        "room_name": room_name,
        "completed_count": completed_ids.size(),
        "elapsed_ms": sum_elapsed_ms(elapsed),
    }

static func completion_summary(release_entries: Array, album_state: Dictionary) -> Dictionary:
    var echoes_found: int = 0
    var echoes_total: int = 0
    for entry_value in release_entries:
        if not entry_value is Dictionary:
            continue
        var entry: Dictionary = entry_value as Dictionary
        var release_id: String = str(entry.get("id", ""))
        var room_manifest: Dictionary = ReleaseReader.load_json(str(entry.get("manifest", "")))
        var collectible_value: Variant = room_manifest.get("collectibles", [])
        if collectible_value is Array:
            echoes_total += (collectible_value as Array).size()
        var saved: Dictionary = ProgressStoreScript.load_release(release_id)
        var room_state_value: Variant = saved.get("room", {})
        if room_state_value is Dictionary:
            var found_value: Variant = (room_state_value as Dictionary).get("found_collectibles", [])
            if found_value is Array:
                echoes_found += (found_value as Array).size()
    var rooms_completed := _array_value(album_state.get("completed_room_ids", [])).size()
    var marks: Array[String] = []
    if rooms_completed >= release_entries.size() and not release_entries.is_empty():
        marks.append("PEŁNA ŚCIEŻKA")
    if echoes_total > 0 and echoes_found >= echoes_total:
        marks.append("PEŁNY REZONANS")
    elif echoes_found > 0:
        marks.append("WŁASNY ŚLAD")
    if bool(album_state.get("calm_mode", true)) or bool(album_state.get("quiet_visuals", false)):
        marks.append("WŁASNE TEMPO")
    return {
        "rooms_completed": rooms_completed,
        "rooms_total": release_entries.size(),
        "echoes_found": echoes_found,
        "echoes_total": echoes_total,
        "elapsed_ms": maxi(0, int(album_state.get("total_elapsed_ms", 0))),
        "journey_marks": marks.slice(0, 3),
    }

static func current_room_elapsed_ms(room_started_ms: int, room_elapsed_before_start_ms: int, room_timer_running: bool) -> int:
    if room_started_ms <= 0 or not room_timer_running:
        return room_elapsed_before_start_ms
    return room_elapsed_before_start_ms + maxi(0, Time.get_ticks_msec() - room_started_ms)

static func sum_elapsed_ms(elapsed: Dictionary) -> int:
    var total: int = 0
    for value in elapsed.values():
        total += maxi(0, int(value))
    return total

static func looks_like_email(value: String) -> bool:
    var at: int = value.find("@")
    var dot: int = value.rfind(".")
    return at > 0 and dot > at + 1 and dot < value.length() - 1 and value.length() <= 254

static func _array_value(value: Variant) -> Array:
    return value.duplicate(true) if value is Array else []
