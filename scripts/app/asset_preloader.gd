extends Node

const MAX_QUEUED: int = 8

var _queued: Dictionary = {}

func prepare(manifest_path: String) -> void:
    _prune_finished_failures()
    if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path):
        return
    var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return
    var manifest: Dictionary = parsed
    var room_value: Variant = manifest.get("room", {})
    var room: Dictionary = room_value if room_value is Dictionary else {}
    var art_value: Variant = room.get("art_direction", {})
    var art: Dictionary = art_value if art_value is Dictionary else {}
    var audio_value: Variant = manifest.get("audio", {})
    var audio: Dictionary = audio_value if audio_value is Dictionary else {}
    var paths: Array[String] = [
        str(room.get("scene_path", "")),
        str(art.get("scene_image", "")),
        str(art.get("background_image", "")),
        str(art.get("subject_image", "")),
        str(art.get("foreground_image", "")),
        str(audio.get("completion_excerpt", "")),
    ]
    for path in paths:
        if _queued.size() >= MAX_QUEUED:
            break
        if path.is_empty() or _queued.has(path) or not ResourceLoader.exists(path):
            continue
        var error: Error = ResourceLoader.load_threaded_request(path, "", false, ResourceLoader.CACHE_MODE_IGNORE)
        if error == OK:
            _queued[path] = Time.get_ticks_msec()

func take(path: String) -> Resource:
    if path.is_empty():
        return null
    if _queued.has(path):
        var status: int = int(ResourceLoader.load_threaded_get_status(path))
        if status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            var resource: Resource = ResourceLoader.load_threaded_get(path)
            _queued.erase(path)
            if resource != null:
                return resource
        else:
            _queued.erase(path)
    if ResourceLoader.exists(path):
        return load(path)
    return null

func queued_count() -> int:
    return _queued.size()

func _prune_finished_failures() -> void:
    var stale: Array[String] = []
    for raw_path in _queued.keys():
        var path: String = str(raw_path)
        var status: int = int(ResourceLoader.load_threaded_get_status(path))
        if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            stale.append(path)
    for path in stale:
        _queued.erase(path)

func drain() -> void:
    var paths: Array = _queued.keys()
    for raw_path in paths:
        var path: String = str(raw_path)
        var status: int = int(ResourceLoader.load_threaded_get_status(path))
        if status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            ResourceLoader.load_threaded_get(path)
    _queued.clear()

func _exit_tree() -> void:
    drain()
