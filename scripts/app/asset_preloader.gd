extends Node

const ReleaseReader := preload("res://scripts/app/release_reader.gd")

const MAX_QUEUED: int = 8
const DEFAULT_TRANSITION_WAIT_MS: int = 320

var _queued: Dictionary = {}
var _critical: Dictionary = {}
var _requests: int = 0
var _hits: int = 0
var _fallbacks: int = 0
var _blocking_takes: int = 0
var _max_block_ms: int = 0

func prepare(manifest_path: String) -> void:
    _prune_finished_failures()
    if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path):
        return
    var manifest: Dictionary = ReleaseReader.load_json(manifest_path)
    if manifest.is_empty():
        return
    var room_value: Variant = manifest.get("room", {})
    var room: Dictionary = room_value if room_value is Dictionary else {}
    var art_value: Variant = room.get("art_direction", {})
    var art: Dictionary = art_value if art_value is Dictionary else {}
    var audio_value: Variant = manifest.get("audio", {})
    var audio: Dictionary = audio_value if audio_value is Dictionary else {}
    var critical_paths: Array[String] = [
        str(room.get("scene_path", "")),
        str(art.get("scene_image", "")),
        str(art.get("background_image", "")),
        str(art.get("subject_image", "")),
        str(art.get("foreground_image", "")),
    ]
    for path in critical_paths:
        _queue(path, true)
    # Audio is intentionally non-critical: queue it during menu/room time, but
    # never let a decoder join delay the covered door transition.
    _queue(str(audio.get("ambience", "")), false)
    _queue(str(audio.get("completion_excerpt", "")), false)

func _queue(path: String, critical: bool) -> void:
    if _queued.size() >= MAX_QUEUED or path.is_empty() or _queued.has(path) or not ResourceLoader.exists(path):
        return
    var error: Error = ResourceLoader.load_threaded_request(path, "", false, ResourceLoader.CACHE_MODE_IGNORE)
    if error == OK:
        _queued[path] = Time.get_ticks_msec()
        if critical:
            _critical[path] = true
        _requests += 1

# Give an already-scheduled next room a short, frame-yielding grace period while
# the door warp covers the screen. This converts the common transition case from
# a main-thread load_threaded_get stall into non-blocking wait frames.
func wait_for_queued(max_wait_ms: int = DEFAULT_TRANSITION_WAIT_MS) -> void:
    if _queued.is_empty():
        return
    var deadline_ms: int = Time.get_ticks_msec() + maxi(0, max_wait_ms)
    while Time.get_ticks_msec() < deadline_ms:
        _prune_finished_failures()
        if not _has_in_progress(true):
            return
        await get_tree().process_frame

func is_queued(path: String) -> bool:
    return not path.is_empty() and _queued.has(path)

func take_if_ready(path: String) -> Resource:
    if path.is_empty() or not _queued.has(path):
        return null
    var status: int = int(ResourceLoader.load_threaded_get_status(path))
    if status == ResourceLoader.THREAD_LOAD_LOADED:
        var resource: Resource = ResourceLoader.load_threaded_get(path)
        _forget(path)
        if resource != null:
            _hits += 1
        return resource
    if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
        _forget(path)
    return null

func take(path: String) -> Resource:
    if path.is_empty():
        return null
    var ready: Resource = take_if_ready(path)
    if ready != null:
        return ready
    if _queued.has(path):
        var status: int = int(ResourceLoader.load_threaded_get_status(path))
        if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            # Keep the legacy correctness fallback for critical callers, but
            # measure every remaining blocking join. Deferred audio uses
            # take_if_ready() and never enters this path during room transition.
            var started_ms: int = Time.get_ticks_msec()
            var resource: Resource = ResourceLoader.load_threaded_get(path)
            var waited_ms: int = maxi(0, Time.get_ticks_msec() - started_ms)
            _forget(path)
            _blocking_takes += 1
            _max_block_ms = maxi(_max_block_ms, waited_ms)
            if resource != null:
                _hits += 1
                return resource
        else:
            _forget(path)
    if ResourceLoader.exists(path):
        _fallbacks += 1
        return load(path)
    return null

func queued_count() -> int:
    return _queued.size()

func snapshot() -> Dictionary:
    return {
        "queued": _queued.size(),
        "critical_queued": _critical.size(),
        "deferred_queued": maxi(0, _queued.size() - _critical.size()),
        "requests": _requests,
        "hits": _hits,
        "fallbacks": _fallbacks,
        "blocking_takes": _blocking_takes,
        "max_block_ms": _max_block_ms,
    }

func _has_in_progress(critical_only: bool = false) -> bool:
    for raw_path in _queued.keys():
        var path: String = str(raw_path)
        if critical_only and not _critical.has(path):
            continue
        if int(ResourceLoader.load_threaded_get_status(path)) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            return true
    return false

func _forget(path: String) -> void:
    _queued.erase(path)
    _critical.erase(path)

func _prune_finished_failures() -> void:
    var stale: Array[String] = []
    for raw_path in _queued.keys():
        var path: String = str(raw_path)
        var status: int = int(ResourceLoader.load_threaded_get_status(path))
        if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            stale.append(path)
    for path in stale:
        _forget(path)

func drain() -> void:
    var paths: Array = _queued.keys()
    for raw_path in paths:
        var path: String = str(raw_path)
        var status: int = int(ResourceLoader.load_threaded_get_status(path))
        if status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            ResourceLoader.load_threaded_get(path)
    _queued.clear()
    _critical.clear()

func _exit_tree() -> void:
    drain()
