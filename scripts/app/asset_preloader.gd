extends Node

var _queued: Dictionary = {}

func prepare(manifest_path: String) -> void:
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
    for path in [
        str(room.get("scene_path", "")),
        str(art.get("scene_image", "")),
        str(art.get("background_image", "")),
        str(art.get("subject_image", "")),
        str(art.get("foreground_image", "")),
        str(audio.get("completion_excerpt", "")),
    ]:
        if path.is_empty() or _queued.has(path) or not ResourceLoader.exists(path):
            continue
        var error: Error = ResourceLoader.load_threaded_request(path)
        if error == OK:
            _queued[path] = true

func take(path: String) -> Resource:
    if path.is_empty():
        return null
    if _queued.has(path):
        var status: int = int(ResourceLoader.load_threaded_get_status(path))
        if status == ResourceLoader.THREAD_LOAD_LOADED:
            _queued.erase(path)
            return ResourceLoader.load_threaded_get(path)
    if ResourceLoader.exists(path):
        return load(path)
    return null
