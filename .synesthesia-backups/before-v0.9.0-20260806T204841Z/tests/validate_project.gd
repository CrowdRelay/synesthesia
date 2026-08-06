extends SceneTree

const RELEASE_INDEX_PATH: String = "res://data/release_index.json"
const REQUIRED_MANIFEST_KEYS: Array[String] = [
    "schema_version", "release_id", "room", "sensory", "collectibles", "audio"
]
const REQUIRED_SCRIPTS: Array[String] = [
    "res://scripts/main.gd",
    "res://scripts/paint_room.gd",
    "res://scripts/audio_director.gd",
    "res://scripts/haptics.gd",
    "res://scripts/progress_store.gd",
    "res://scripts/reward_client.gd",
]

func _init() -> void:
    var failures: Array[String] = []
    _validate_scripts(failures)
    _validate_scene(failures)
    _validate_album(failures)

    if failures.is_empty():
        print("SYNESTHESIA_VALIDATION=PASS")
        quit(0)
        return

    for failure in failures:
        push_error(failure)
    print("SYNESTHESIA_VALIDATION=FAIL count=%d" % failures.size())
    quit(1)

func _validate_scripts(failures: Array[String]) -> void:
    for path in REQUIRED_SCRIPTS:
        var script: Resource = load(path)
        if script == null:
            failures.append("script cannot be loaded: %s" % path)

func _validate_scene(failures: Array[String]) -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        failures.append("main scene cannot be loaded")
        return
    var instance: Node = scene.instantiate()
    if instance == null:
        failures.append("main scene cannot be instantiated")
    else:
        instance.free()

func _validate_album(failures: Array[String]) -> void:
    var index: Dictionary = _read_json(RELEASE_INDEX_PATH, failures)
    if index.is_empty():
        return
    var releases_value: Variant = index.get("releases", [])
    if not releases_value is Array:
        failures.append("release index does not contain an array")
        return
    var releases: Array = releases_value
    if releases.size() != 11:
        failures.append("album must contain exactly eleven rooms")
    for release_value in releases:
        if not release_value is Dictionary:
            failures.append("release index entry is not an object")
            continue
        var release: Dictionary = release_value
        var manifest_path: String = str(release.get("manifest", ""))
        var manifest: Dictionary = _read_json(manifest_path, failures)
        if manifest.is_empty():
            continue
        for key in REQUIRED_MANIFEST_KEYS:
            if not manifest.has(key):
                failures.append("%s missing %s" % [manifest_path, key])
        if int(manifest.get("schema_version", 0)) != 3:
            failures.append("%s has unsupported schema version" % manifest_path)
        var room_value: Variant = manifest.get("room", {})
        if room_value is Dictionary:
            var room: Dictionary = room_value
            if absf(float(room.get("cinematic_reveal_at", 0.0)) - 0.99) > 0.0001:
                failures.append("%s must reveal at 99 percent" % manifest_path)
        var audio_value: Variant = manifest.get("audio", {})
        if audio_value is Dictionary:
            var audio: Dictionary = audio_value
            var excerpt_path: String = str(audio.get("completion_excerpt", ""))
            if excerpt_path.is_empty() or not ResourceLoader.exists(excerpt_path):
                failures.append("missing audio excerpt: %s" % excerpt_path)
            else:
                var stream: Resource = load(excerpt_path)
                if not stream is AudioStream:
                    failures.append("excerpt is not AudioStream: %s" % excerpt_path)

func _read_json(path: String, failures: Array[String]) -> Dictionary:
    if path.is_empty() or not FileAccess.file_exists(path):
        failures.append("missing JSON: %s" % path)
        return {}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        failures.append("cannot open JSON: %s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        return parsed
    failures.append("JSON is not an object: %s" % path)
    return {}
