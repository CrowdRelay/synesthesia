class_name ProgressMetrics
extends RefCounted

const ProgressStoreScript := preload("res://scripts/progress_store.gd")
const ReleaseReader := preload("res://scripts/app/release_reader.gd")

static func resume_room_index(release_entries: Array, album_state: Dictionary, saved_index: int) -> int:
    # current_room_index is persisted while a room completes, but only advances
    # when the next room loads. A player who finishes a room and leaves at the
    # completion card (on web, an ordinary reload or a restored tab) would
    # otherwise be dropped back into the room they just finished. Resume at the
    # first room that is not yet completed, which also heals saves already
    # written that way. Once every room is completed the saved index stands, so
    # replaying a finished album still lands where the player left off.
    var completed: Array = _array_value(album_state.get("completed_room_ids", []))
    if completed.is_empty():
        return saved_index
    for index in range(saved_index, release_entries.size()):
        var entry_value: Variant = release_entries[index]
        var entry: Dictionary = entry_value if entry_value is Dictionary else {}
        # The release index calls it "id"; it is the same value the room manifest
        # exposes as release_id and the one recorded in completed_room_ids.
        if not completed.has(str(entry.get("id", ""))):
            return index
    return saved_index

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

static func menu_summary(release_entries: Array, album_state: Dictionary) -> Dictionary:
    # Startup/menu path must stay storage-light: album_state already contains the
    # echo archive and mastery memory, so never scan 11 room saves/manifests here.
    var archive_value: Variant = album_state.get("echo_archive", {})
    var archive: Dictionary = archive_value if archive_value is Dictionary else {}
    var echoes_found: int = 0
    for room_value in archive.values():
        if room_value is Dictionary: echoes_found += (room_value as Dictionary).size()
    var mastery := _mastery_summary(album_state)
    return {
        "rooms_completed": _array_value(album_state.get("completed_room_ids", [])).size(),
        "rooms_total": release_entries.size(),
        "echoes_found": echoes_found,
        "echoes_total": release_entries.size() * 3, # schema invariant: three authored echoes per room
        "personal_best_total_ms": validated_personal_best_total_ms(release_entries, album_state),
        "mastery_rooms": int(mastery.get("rooms", 0)),
        "mastery_s_rooms": int(mastery.get("s_rooms", 0)),
        "mastery_average": int(mastery.get("average", 0)),
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
    var mastery := _mastery_summary(album_state)
    var mastery_rooms: int = int(mastery.get("rooms", 0))
    var mastery_s_rooms: int = int(mastery.get("s_rooms", 0))
    var mastery_average: int = int(mastery.get("average", 0))
    var marks: Array[String] = []
    if rooms_completed >= release_entries.size() and not release_entries.is_empty():
        marks.append("PEŁNA ŚCIEŻKA")
    if echoes_total > 0 and echoes_found >= echoes_total:
        marks.append("PEŁNY REZONANS")
    elif echoes_found > 0:
        marks.append("WŁASNY ŚLAD")
    if mastery_rooms >= release_entries.size() and mastery_average >= 85 and not release_entries.is_empty():
        marks.append("MISTRZOSTWO REZONANSU")
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
        "mastery_rooms": mastery_rooms,
        "mastery_s_rooms": mastery_s_rooms,
        "mastery_average": mastery_average,
        "journey_marks": marks.slice(0, 3),
    }

static func _mastery_summary(album_state: Dictionary) -> Dictionary:
    var value: Variant = album_state.get("best_room_mastery", {})
    var mastery: Dictionary = value if value is Dictionary else {}
    var rooms := 0; var total := 0; var s_rooms := 0
    for room_value in mastery.values():
        if not room_value is Dictionary: continue
        var score: int = clampi(int((room_value as Dictionary).get("score", 0)), 0, 100)
        if score <= 0: continue
        rooms += 1; total += score
        if score >= 95: s_rooms += 1
    return {"rooms": rooms, "s_rooms": s_rooms, "average": int(round(float(total) / float(rooms))) if rooms > 0 else 0}

static func room_mastery(found_echoes: int, total_echoes: int, guidance: Dictionary, performance: Dictionary) -> Dictionary:
    # Pure local score: optional exploration + interaction fluency. Accessibility
    # settings are intentionally not penalized and mastery never affects rewards.
    var echo_ratio: float = 1.0 if total_echoes <= 0 else clampf(float(found_echoes) / float(total_echoes), 0.0, 1.0)
    var misses: int = maxi(0, int(guidance.get("miss_count", 0)))
    var hints: int = maxi(0, int(guidance.get("hint_count", 0)))
    var max_chain: int = clampi(int(guidance.get("max_resonance_chain", 0)), 0, 6)
    var score: int = 70 + int(round(20.0 * echo_ratio))
    score += 5 if misses == 0 else -mini(15, misses * 3)
    score += 5 if hints == 0 else -mini(10, hints * 2)
    score += 5 if max_chain >= 6 else (3 if max_chain >= 4 else (1 if max_chain >= 2 else 0))
    var previous_best_ms: int = maxi(0, int(performance.get("previous_room_best_ms", 0)))
    if previous_best_ms > 0 and bool(performance.get("room_personal_best", false)):
        score += 5
    score = clampi(score, 0, 100)
    var grade: String = "S" if score >= 95 else ("A" if score >= 85 else ("B" if score >= 72 else "C"))
    return {
        "score": score,
        "grade": grade,
        "echo_ratio": echo_ratio,
        "miss_count": misses,
        "hint_count": hints,
        "max_resonance_chain": max_chain,
    }

static func record_room_mastery(album_state: Dictionary, release_id: String, mastery: Dictionary) -> Dictionary:
    var best_value: Variant = album_state.get("best_room_mastery", {})
    var best: Dictionary = best_value if best_value is Dictionary else {}
    var previous_value: Variant = best.get(release_id, {})
    var previous: Dictionary = previous_value if previous_value is Dictionary else {}
    var previous_score: int = maxi(0, int(previous.get("score", 0)))
    var score: int = clampi(int(mastery.get("score", 0)), 0, 100)
    var improved: bool = previous_score <= 0 or score > previous_score
    if improved:
        best[release_id] = {"score": score, "grade": str(mastery.get("grade", "C"))}
    album_state["best_room_mastery"] = best
    var result: Dictionary = mastery.duplicate(true)
    result["previous_best_mastery"] = previous_score
    result["mastery_personal_best"] = improved
    result["best_mastery"] = maxi(previous_score, score)
    return result

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

static func record_completion_performance(album_state: Dictionary, release_entries: Array, release_id: String, room_elapsed_ms: int, journey_completed: bool, journey_timed_complete: bool, found_echoes: int, total_echoes: int, guidance: Dictionary) -> Dictionary:
    var performance := record_personal_best(album_state, release_entries, release_id, room_elapsed_ms, journey_completed, journey_timed_complete)
    var mastery := record_room_mastery(album_state, release_id, room_mastery(found_echoes, total_echoes, guidance, performance))
    for key in mastery.keys():
        performance[key] = mastery[key]
    return performance

static func record_rerun_attempt(album_state: Dictionary, release_id: String, room_elapsed_ms: int, found_echoes: int, total_echoes: int, guidance: Dictionary) -> Dictionary:
    # A rerun is room-scoped by construction. It may take a room record or raise
    # room mastery, and it must never touch completed rooms, the album clock, the
    # local run counter or the album personal best: those belong to the run that
    # actually closed the album, and a consequence-free replay cannot rewrite it.
    # This deliberately does not reuse record_personal_best, which owns exactly
    # that journey-level bookkeeping.
    var best_rooms_value: Variant = album_state.get("personal_best_room_ms", {})
    var best_rooms: Dictionary = best_rooms_value if best_rooms_value is Dictionary else {}
    var previous_room_best: int = maxi(0, int(best_rooms.get(release_id, 0)))
    var room_personal_best: bool = previous_room_best <= 0 or room_elapsed_ms < previous_room_best
    if room_personal_best:
        best_rooms[release_id] = room_elapsed_ms
    album_state["personal_best_room_ms"] = best_rooms

    var performance := {
        "room_elapsed_ms": room_elapsed_ms,
        "previous_room_best_ms": previous_room_best,
        "room_personal_best": room_personal_best,
    }
    # Mastery is stored on its own better-only rule, so a sloppier replay of a
    # room cannot lower a grade the player already earned.
    var mastery := record_room_mastery(album_state, release_id, room_mastery(found_echoes, total_echoes, guidance, performance))
    for key in mastery.keys():
        performance[key] = mastery[key]
    performance["rerun_improved"] = room_personal_best or bool(mastery.get("mastery_personal_best", false))
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

static func all_rooms_completed(release_entries: Array, album_state: Dictionary) -> bool:
    # The journey is finished when every room is finished, not when the player
    # happens to be standing in the last one. Resuming, replaying or finishing
    # the rooms out of order all leave the final completion on some other index,
    # and keying the finale off current_room_index silently strands the player
    # in a completed world with the door open and nothing to advance to.
    if release_entries.is_empty():
        return false
    var completed: Array = _array_value(album_state.get("completed_room_ids", []))
    for entry_value in release_entries:
        var entry: Dictionary = entry_value if entry_value is Dictionary else {}
        if not completed.has(str(entry.get("id", ""))):
            return false
    return true

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
