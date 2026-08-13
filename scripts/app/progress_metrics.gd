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
    var elapsed_value: Variant = album_state.get("room_elapsed_ms", {})
    var elapsed: Dictionary = elapsed_value if elapsed_value is Dictionary else {}
    var raw_elapsed_ms: int = sum_elapsed_ms(elapsed)
    var timed_rooms: int = timed_room_count(release_entries, album_state)
    var timed_run_complete: bool = has_complete_journey_timing(release_entries, album_state)
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
        # Never present a partial/migrated timer as a competitive album time.
        # raw_elapsed_ms remains available for diagnostics/local continuity only.
        "elapsed_ms": raw_elapsed_ms if timed_run_complete else 0,
        "raw_elapsed_ms": raw_elapsed_ms,
        "timed_rooms": timed_rooms,
        "timed_run_complete": timed_run_complete,
        "personal_best_total_ms": validated_personal_best_total_ms(release_entries, album_state),
        "completed_runs_local": maxi(0, int(album_state.get("completed_runs_local", 0))),
        "journey_marks": marks.slice(0, 3),
    }

static func record_personal_best(album_state: Dictionary, release_entries: Array, release_id: String, room_elapsed_ms: int, journey_completed: bool, journey_timed_complete: bool) -> Dictionary:
    # Local-only performance feedback: no network, no reward or eligibility input.
    var best_rooms_value: Variant = album_state.get("personal_best_room_ms", {})
    var best_rooms: Dictionary = best_rooms_value if best_rooms_value is Dictionary else {}
    var previous_room_best: int = maxi(0, int(best_rooms.get(release_id, 0)))
    var room_personal_best: bool = previous_room_best <= 0 or room_elapsed_ms < previous_room_best
    if room_personal_best:
        best_rooms[release_id] = room_elapsed_ms
    album_state["personal_best_room_ms"] = best_rooms
    _discard_impossible_total_pb(release_entries, album_state)
    var performance := {
        "room_elapsed_ms": room_elapsed_ms,
        "previous_room_best_ms": previous_room_best,
        "room_personal_best": room_personal_best,
        "journey_elapsed_ms": maxi(0, int(album_state.get("total_elapsed_ms", 0))),
        "journey_timed_complete": journey_timed_complete,
    }
    if journey_completed:
        album_state["completed_runs_local"] = maxi(0, int(album_state.get("completed_runs_local", 0))) + 1
        if journey_timed_complete:
            var total_elapsed: int = int(performance["journey_elapsed_ms"])
            var previous_total_best: int = maxi(0, int(album_state.get("personal_best_total_ms", 0)))
            var journey_personal_best: bool = previous_total_best <= 0 or total_elapsed < previous_total_best
            if journey_personal_best:
                album_state["personal_best_total_ms"] = total_elapsed
            performance["previous_total_best_ms"] = previous_total_best
            performance["journey_personal_best"] = journey_personal_best
    return performance

static func current_room_elapsed_ms(room_started_ms: int, room_elapsed_before_start_ms: int, room_timer_running: bool) -> int:
    if room_started_ms <= 0 or not room_timer_running:
        return room_elapsed_before_start_ms
    return room_elapsed_before_start_ms + maxi(0, Time.get_ticks_msec() - room_started_ms)

static func sum_elapsed_ms(elapsed: Dictionary) -> int:
    var total: int = 0
    for value in elapsed.values():
        total += maxi(0, int(value))
    return total

static func timed_room_count(release_entries: Array, album_state: Dictionary) -> int:
    var elapsed_value: Variant = album_state.get("room_elapsed_ms", {})
    var elapsed: Dictionary = elapsed_value if elapsed_value is Dictionary else {}
    var count: int = 0
    for entry_value in release_entries:
        if not entry_value is Dictionary:
            continue
        var release_id: String = str((entry_value as Dictionary).get("id", ""))
        if not release_id.is_empty() and int(elapsed.get(release_id, 0)) > 0:
            count += 1
    return count

static func has_complete_journey_timing(release_entries: Array, album_state: Dictionary) -> bool:
    if release_entries.is_empty():
        return false
    var completed_ids: Array = _array_value(album_state.get("completed_room_ids", []))
    return completed_ids.size() >= release_entries.size() and timed_room_count(release_entries, album_state) == release_entries.size()

static func validated_personal_best_total_ms(release_entries: Array, album_state: Dictionary) -> int:
    var stored: int = maxi(0, int(album_state.get("personal_best_total_ms", 0)))
    if stored <= 0:
        return 0
    var best_rooms_value: Variant = album_state.get("personal_best_room_ms", {})
    var best_rooms: Dictionary = best_rooms_value if best_rooms_value is Dictionary else {}
    var theoretical_floor: int = 0
    var covered: int = 0
    for entry_value in release_entries:
        if not entry_value is Dictionary:
            continue
        var release_id: String = str((entry_value as Dictionary).get("id", ""))
        var room_best: int = maxi(0, int(best_rooms.get(release_id, 0)))
        if room_best <= 0:
            continue
        covered += 1
        theoretical_floor += room_best
    # A total-run PB can never be faster than the sum of each room's individual
    # PB. This safely rejects the old "last room became total PB" save shape.
    if covered == release_entries.size() and stored < theoretical_floor:
        return 0
    return stored

static func looks_like_email(value: String) -> bool:
    var at: int = value.find("@")
    var dot: int = value.rfind(".")
    return at > 0 and dot > at + 1 and dot < value.length() - 1 and value.length() <= 254

static func _discard_impossible_total_pb(release_entries: Array, album_state: Dictionary) -> void:
    var stored: int = maxi(0, int(album_state.get("personal_best_total_ms", 0)))
    if stored > 0 and validated_personal_best_total_ms(release_entries, album_state) == 0:
        album_state["personal_best_total_ms"] = 0

static func _array_value(value: Variant) -> Array:
    return value.duplicate(true) if value is Array else []
