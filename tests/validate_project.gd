extends SceneTree

const REQUIRED_MANIFEST_KEYS := ["schema_version", "release_id", "room", "sensory", "collectibles"]
const RELEASE_INDEX_PATH := "res://data/release_index.json"

func _init() -> void:
    var failures: Array[String] = []
    var manifest_path := _active_manifest_path(failures)
    if not manifest_path.is_empty():
        _validate_manifest(manifest_path, failures)

    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        failures.append("main scene cannot be loaded")

    if failures.is_empty():
        print("SYNESTHESIA_VALIDATION=PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("SYNESTHESIA_VALIDATION=FAIL count=%d" % failures.size())
        quit(1)

func _active_manifest_path(failures: Array[String]) -> String:
    if not FileAccess.file_exists(RELEASE_INDEX_PATH):
        failures.append("missing release index")
        return ""
    var file := FileAccess.open(RELEASE_INDEX_PATH, FileAccess.READ)
    var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
    if not parsed is Dictionary:
        failures.append("release index is not an object")
        return ""
    var index: Dictionary = parsed
    var active_id := str(index.get("active_release", ""))
    var releases: Array = index.get("releases", [])
    for release_value in releases:
        if not release_value is Dictionary:
            continue
        var release: Dictionary = release_value
        if str(release.get("id", "")) == active_id and bool(release.get("available", true)):
            var manifest_path := str(release.get("manifest", ""))
            if not FileAccess.file_exists(manifest_path):
                failures.append("active release manifest does not exist")
                return ""
            return manifest_path
    failures.append("active release is not indexed")
    return ""

func _validate_manifest(manifest_path: String, failures: Array[String]) -> void:
    var file := FileAccess.open(manifest_path, FileAccess.READ)
    var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
    if not parsed is Dictionary:
        failures.append("manifest is not an object")
        return
    var manifest: Dictionary = parsed
    for key in REQUIRED_MANIFEST_KEYS:
        if not manifest.has(key):
            failures.append("manifest missing %s" % key)
    var collectibles: Array = manifest.get("collectibles", [])
    if collectibles.is_empty():
        failures.append("active room must contain at least one collectible")
