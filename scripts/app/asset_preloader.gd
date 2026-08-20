extends Node

const ReleaseReader := preload("res://scripts/app/release_reader.gd")

# Threaded ResourceLoader requests are cheap individually but too many concurrent
# image/audio decodes produce RAM/CPU spikes on phones. Keep the active window
# deliberately small; pending work is retained and critical assets always win.
const MAX_QUEUED_DESKTOP: int = 8
const MAX_QUEUED_WEB: int = 6
const MAX_QUEUED_MOBILE: int = 5
const MIN_QUEUED: int = 4
const DEFAULT_TRANSITION_WAIT_MS: int = 320
const RUNTIME_SUPPORT_PATHS: Array[String] = [
    "res://scripts/audio_director.gd",
    "res://scripts/haptics.gd",
    "res://scripts/app/player_feedback_bridge.gd",
    "res://scripts/ui/chapter_card.gd",
    "res://scripts/ui/completion_card.gd",
]

var _queued: Dictionary = {}
var _critical: Dictionary = {}
var _pending_critical: Array[String] = []
var _pending_deferred: Array[String] = []
var _pending_flags: Dictionary = {}
var _requests: int = 0
var _hits: int = 0
var _fallbacks: int = 0
var _blocking_takes: int = 0
var _max_block_ms: int = 0
var _dropped_requests: int = 0
var _runtime_support_primed: bool = false
var _active_limit: int = MAX_QUEUED_DESKTOP
var _runtime_scale: float = 1.0

func _ready() -> void:
    _active_limit = _platform_limit()

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

    # scene_image is authoritative for the psychiatric-ward redesign. A room
    # prewarms only its scene graph, behavior and authored scene as critical.
    # Ambience/outro stay deferred behind that work so the next room streams
    # during the current one without turning audio decode into a transition join.
    var critical_paths: Array[String] = [
        str(room.get("scene_path", "")),
        str(room.get("behavior_script", "")),
        str(art.get("scene_image", "")),
    ]
    for path in critical_paths:
        _queue(path, true)
    _queue(str(audio.get("ambience", "")), false)
    _queue(str(audio.get("completion_excerpt", "")), false)

func prime_runtime_support() -> void:
    if _runtime_support_primed:
        return
    _runtime_support_primed = true
    for path in RUNTIME_SUPPORT_PATHS:
        _queue(path, true)

func set_runtime_budget(scale: float) -> void:
    _runtime_scale = clampf(scale, 0.55, 1.0)
    var platform_limit: int = _platform_limit()
    _active_limit = clampi(roundi(lerpf(float(MIN_QUEUED), float(platform_limit), _runtime_scale)), MIN_QUEUED, platform_limit)
    _pump_queue()

func queue_deferred(path: String) -> void:
    _queue(path, false)

func queue_critical(path: String) -> void:
    _queue(path, true)

func _platform_limit() -> int:
    if OS.has_feature("mobile"):
        return MAX_QUEUED_MOBILE
    if OS.has_feature("web"):
        return MAX_QUEUED_WEB
    return MAX_QUEUED_DESKTOP

func _queue(path: String, critical: bool) -> void:
    if path.is_empty() or _queued.has(path) or _pending_flags.has(path) or not ResourceLoader.exists(path):
        return
    _pending_flags[path] = critical
    if critical:
        _pending_critical.append(path)
    else:
        _pending_deferred.append(path)
    _pump_queue()

func _pump_queue() -> void:
    while _queued.size() < _active_limit:
        var path: String = _pop_pending_path()
        if path.is_empty():
            return
        var critical: bool = bool(_pending_flags.get(path, false))
        _pending_flags.erase(path)
        if not ResourceLoader.exists(path):
            _dropped_requests += 1
            continue
        var error: Error = ResourceLoader.load_threaded_request(path, "", false, ResourceLoader.CACHE_MODE_REUSE)
        if error != OK:
            _dropped_requests += 1
            continue
        _queued[path] = Time.get_ticks_msec()
        if critical:
            _critical[path] = true
        _requests += 1

func _pop_pending_path() -> String:
    if not _pending_critical.is_empty():
        return _pending_critical.pop_front()
    if not _pending_deferred.is_empty():
        return _pending_deferred.pop_front()
    return ""

func wait_for_queued(max_wait_ms: int = DEFAULT_TRANSITION_WAIT_MS) -> void:
    if _queued.is_empty() and _pending_flags.is_empty():
        return
    var deadline_ms: int = Time.get_ticks_msec() + maxi(0, max_wait_ms)
    while Time.get_ticks_msec() < deadline_ms:
        _prune_finished_failures()
        _pump_queue()
        if not _has_in_progress(true):
            return
        await get_tree().process_frame

func is_queued(path: String) -> bool:
    return not path.is_empty() and (_queued.has(path) or _pending_flags.has(path))

func take_if_ready(path: String) -> Resource:
    if path.is_empty():
        return null
    if _pending_flags.has(path):
        return null
    if not _queued.has(path):
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
    elif _pending_flags.has(path):
        _remove_pending(path)
    if ResourceLoader.exists(path):
        _fallbacks += 1
        return load(path)
    return null

func queued_count() -> int:
    return _queued.size() + _pending_flags.size()

func snapshot() -> Dictionary:
    return {
        "queued": _queued.size(),
        "pending": _pending_flags.size(),
        "active_limit": _active_limit,
        "runtime_scale": _runtime_scale,
        "critical_queued": _critical.size() + _pending_critical.size(),
        "deferred_queued": maxi(0, _queued.size() - _critical.size()) + _pending_deferred.size(),
        "requests": _requests,
        "hits": _hits,
        "fallbacks": _fallbacks,
        "blocking_takes": _blocking_takes,
        "max_block_ms": _max_block_ms,
        "dropped_requests": _dropped_requests,
    }

func _has_in_progress(critical_only: bool = false) -> bool:
    if critical_only and not _pending_critical.is_empty():
        return true
    if not critical_only and not _pending_flags.is_empty():
        return true
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
    _pump_queue()

func _remove_pending(path: String) -> void:
    _pending_flags.erase(path)
    var critical_index: int = _pending_critical.find(path)
    if critical_index >= 0:
        _pending_critical.remove_at(critical_index)
    var deferred_index: int = _pending_deferred.find(path)
    if deferred_index >= 0:
        _pending_deferred.remove_at(deferred_index)

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
    _pending_critical.clear()
    _pending_deferred.clear()
    _pending_flags.clear()
    var paths: Array = _queued.keys()
    for raw_path in paths:
        var path: String = str(raw_path)
        var status: int = int(ResourceLoader.load_threaded_get_status(path))
        if status == ResourceLoader.THREAD_LOAD_LOADED:
            ResourceLoader.load_threaded_get(path)
    _queued.clear()
    _critical.clear()

func _exit_tree() -> void:
    drain()
