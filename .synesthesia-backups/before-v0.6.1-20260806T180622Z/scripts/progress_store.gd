extends RefCounted
class_name SynesthesiaProgressStore

const SAVE_PATH := "user://synesthesia-progress-v1.json"
const SCHEMA_VERSION := 1

static func load_release(release_id: String) -> Dictionary:
    if release_id.is_empty() or not FileAccess.file_exists(SAVE_PATH):
        return {}
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        push_warning("Could not open local progress file")
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        push_warning("Ignoring malformed local progress file")
        return {}
    var document: Dictionary = parsed
    if int(document.get("schema_version", 0)) != SCHEMA_VERSION:
        return {}
    var releases: Variant = document.get("releases", {})
    if not releases is Dictionary:
        return {}
    var state: Variant = releases.get(release_id, {})
    return state.duplicate(true) if state is Dictionary else {}

static func save_release(release_id: String, state: Dictionary) -> bool:
    if release_id.is_empty():
        return false
    var document: Dictionary = _load_document()
    var releases: Dictionary = document.get("releases", {})
    releases[release_id] = state.duplicate(true)
    document["schema_version"] = SCHEMA_VERSION
    document["releases"] = releases
    return _write_document(document)

static func clear_release(release_id: String) -> bool:
    if release_id.is_empty():
        return false
    var document: Dictionary = _load_document()
    var releases: Dictionary = document.get("releases", {})
    releases.erase(release_id)
    document["releases"] = releases
    return _write_document(document)

static func _load_document() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {"schema_version": SCHEMA_VERSION, "releases": {}}
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return {"schema_version": SCHEMA_VERSION, "releases": {}}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return {"schema_version": SCHEMA_VERSION, "releases": {}}
    var document: Dictionary = parsed
    if int(document.get("schema_version", 0)) != SCHEMA_VERSION:
        return {"schema_version": SCHEMA_VERSION, "releases": {}}
    if not document.get("releases", {}) is Dictionary:
        document["releases"] = {}
    return document

static func _write_document(document: Dictionary) -> bool:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("Could not write local progress file")
        return false
    file.store_string(JSON.stringify(document, "  "))
    return true
