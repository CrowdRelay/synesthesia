extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    _failures.append(message)

func _journey_state() -> Dictionary:
    return {
        "completed_room_ids": ["wave-of-uncertainty", "party-time"],
        "room_elapsed_ms": {"wave-of-uncertainty": 90000, "party-time": 70000},
        "total_elapsed_ms": 160000,
        "completed_runs_local": 1,
        "album_completed": true,
        "replay_unlocked": true,
        "personal_best_room_ms": {"wave-of-uncertainty": 90000},
        "personal_best_total_ms": 160000,
        "best_room_mastery": {"wave-of-uncertainty": {"score": 88, "grade": "A"}},
    }

func _guidance(misses: int, hints: int, chain: int) -> Dictionary:
    return {"miss_count": misses, "hint_count": hints, "max_resonance_chain": chain}

func _check_journey_untouched(label: String, state: Dictionary) -> void:
    var reference := _journey_state()
    for key in ["completed_room_ids", "room_elapsed_ms", "total_elapsed_ms", "completed_runs_local", "personal_best_total_ms"]:
        if str(state.get(key)) != str(reference.get(key)):
            _fail("%s: rerun rewrote journey key %s -> %s" % [label, key, str(state.get(key))])

func _run() -> void:
    # 1. A faster attempt takes the room record.
    var faster := _journey_state()
    var result := ProgressMetrics.record_rerun_attempt(faster, "wave-of-uncertainty", 61000, 3, 3, _guidance(0, 0, 6))
    if int(faster["personal_best_room_ms"]["wave-of-uncertainty"]) != 61000:
        _fail("faster rerun did not become the new room record")
    if not bool(result.get("room_personal_best", false)) or not bool(result.get("rerun_improved", false)):
        _fail("faster rerun was not reported as an improvement: %s" % str(result))
    if int(faster["best_room_mastery"]["wave-of-uncertainty"]["score"]) <= 88:
        _fail("a clean fast rerun did not raise mastery: %s" % str(faster["best_room_mastery"]))
    _check_journey_untouched("faster", faster)

    # 2. A slower, sloppier attempt changes nothing at all.
    var slower := _journey_state()
    var slower_result := ProgressMetrics.record_rerun_attempt(slower, "wave-of-uncertainty", 240000, 0, 3, _guidance(9, 5, 0))
    if int(slower["personal_best_room_ms"]["wave-of-uncertainty"]) != 90000:
        _fail("slower rerun overwrote the room record")
    if int(slower["best_room_mastery"]["wave-of-uncertainty"]["score"]) != 88:
        _fail("weaker rerun lowered stored mastery: %s" % str(slower["best_room_mastery"]))
    if bool(slower_result.get("rerun_improved", true)):
        _fail("slower rerun was reported as an improvement")
    if int(slower_result.get("room_elapsed_ms", 0)) != 240000 or int(slower_result.get("previous_room_best_ms", 0)) != 90000:
        _fail("slower rerun lost the delta the result card shows: %s" % str(slower_result))
    _check_journey_untouched("slower", slower)

    # 3. Slower but better played: mastery improves, the time record stands.
    var mastery_only := _journey_state()
    var mastery_result := ProgressMetrics.record_rerun_attempt(mastery_only, "wave-of-uncertainty", 150000, 3, 3, _guidance(0, 0, 6))
    if int(mastery_only["personal_best_room_ms"]["wave-of-uncertainty"]) != 90000:
        _fail("a slower attempt took the time record on a mastery improvement")
    if int(mastery_only["best_room_mastery"]["wave-of-uncertainty"]["score"]) <= 88:
        _fail("better-played rerun did not raise mastery")
    if not bool(mastery_result.get("rerun_improved", false)):
        _fail("mastery-only improvement was not reported as an improvement")
    _check_journey_untouched("mastery-only", mastery_only)

    # 4. A room never played before still records from a rerun.
    var fresh := _journey_state()
    ProgressMetrics.record_rerun_attempt(fresh, "party-time", 45000, 2, 3, _guidance(1, 0, 4))
    if int(fresh["personal_best_room_ms"].get("party-time", 0)) != 45000:
        _fail("first recorded rerun of a room did not store its time")
    _check_journey_untouched("fresh-room", fresh)

    # 5. The finale summary must not shift because a rerun happened.
    var entries: Array = [{"id": "wave-of-uncertainty"}, {"id": "party-time"}]
    var before: int = ProgressMetrics.validated_personal_best_total_ms(entries, _journey_state())
    var after_state := _journey_state()
    ProgressMetrics.record_rerun_attempt(after_state, "wave-of-uncertainty", 61000, 3, 3, _guidance(0, 0, 6))
    var after: int = ProgressMetrics.validated_personal_best_total_ms(entries, after_state)
    if before != after:
        _fail("rerun changed the validated album PB: %d -> %d" % [before, after])

    if _failures.is_empty():
        print("SYNESTHESIA_ROOM_RERUN_SMOKE=PASS cases=5 writes=better-only journey=untouched")
        quit(0)
        return
    for failure in _failures:
        print("FAIL: %s" % failure)
    quit(1)
