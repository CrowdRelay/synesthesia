extends RefCounted
class_name SynesthesiaProgressStore

const SAVE_PATH: String = "user://synesthesia-progress-v3.json"
const PREVIOUS_SAVE_PATH: String = "user://synesthesia-progress-v2.json"
const LEGACY_SAVE_PATH: String = "user://synesthesia-progress-v1.json"
const BACKUP_PATH: String = "user://synesthesia-progress-v3.backup.json"
const SCHEMA_VERSION: int = 3

static func load_release(release_id: String) -> Dictionary:
    if release_id.is_empty():
        return {}
    var document: Dictionary = _load_document()
    var releases_value: Variant = document.get("releases", {})
    if not releases_value is Dictionary:
        return {}
    var releases: Dictionary = releases_value
    var state_value: Variant = releases.get(release_id, {})
    if state_value is Dictionary:
        return state_value.duplicate(true)
    return {}

static func save_release(release_id: String, state: Dictionary) -> bool:
    if release_id.is_empty():
        return false
    var document: Dictionary = _load_document()
    var releases_value: Variant = document.get("releases", {})
    var releases: Dictionary = releases_value if releases_value is Dictionary else {}
    releases[release_id] = state.duplicate(true)
    document["releases"] = releases
    document["updated_at_unix"] = int(Time.get_unix_time_from_system())
    return _write_document(document)

static func clear_release(release_id: String) -> bool:
    if release_id.is_empty():
        return false
    var document: Dictionary = _load_document()
    var releases_value: Variant = document.get("releases", {})
    var releases: Dictionary = releases_value if releases_value is Dictionary else {}
    releases.erase(release_id)
    document["releases"] = releases
    return _write_document(document)

static func load_album() -> Dictionary:
    var document: Dictionary = _load_document()
    var album_value: Variant = document.get("album", {})
    if album_value is Dictionary:
        return album_value.duplicate(true)
    return {}

static func save_album(state: Dictionary) -> bool:
    var document: Dictionary = _load_document()
    document["album"] = state.duplicate(true)
    document["updated_at_unix"] = int(Time.get_unix_time_from_system())
    return _write_document(document)

static func load_run() -> Dictionary:
    var document: Dictionary = _load_document()
    var run_value: Variant = document.get("run", {})
    if run_value is Dictionary:
        return run_value.duplicate(true)
    return {}

static func save_run(state: Dictionary) -> bool:
    var document: Dictionary = _load_document()
    document["run"] = state.duplicate(true)
    document["updated_at_unix"] = int(Time.get_unix_time_from_system())
    return _write_document(document)

static func clear_run() -> bool:
    var document: Dictionary = _load_document()
    document["run"] = {}
    return _write_document(document)

static func load_reward() -> Dictionary:
    var document: Dictionary = _load_document()
    var reward_value: Variant = document.get("reward", {})
    if reward_value is Dictionary:
        return reward_value.duplicate(true)
    return {}

static func save_reward(state: Dictionary) -> bool:
    var document: Dictionary = _load_document()
    document["reward"] = state.duplicate(true)
    document["updated_at_unix"] = int(Time.get_unix_time_from_system())
    return _write_document(document)

static func get_install_id() -> String:
    var document: Dictionary = _load_document()
    var current: String = str(document.get("install_id", ""))
    if not current.is_empty():
        return current
    var crypto: Crypto = Crypto.new()
    var random_bytes: PackedByteArray = crypto.generate_random_bytes(16)
    current = random_bytes.hex_encode()
    if current.is_empty():
        current = "%x-%x" % [Time.get_ticks_usec(), randi()]
    document["install_id"] = current
    _write_document(document)
    return current

static func reset_all() -> bool:
    if FileAccess.file_exists(SAVE_PATH):
        var remove_error: Error = DirAccess.remove_absolute(SAVE_PATH)
        if remove_error != OK:
            return false
    return true

static func _blank_document() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "install_id": "",
        "releases": {},
        "album": {
            "current_room_index": 0,
            "completed_room_ids": [],
            "server_recorded_room_ids": [],
            "pending_room_completions": [],
            "room_elapsed_ms": {},
            "album_completed": false,
        },
        "run": {},
        "reward": {},
    }

static func _load_document() -> Dictionary:
    _recover_backup_if_needed()
    if not FileAccess.file_exists(SAVE_PATH):
        return _migrate_previous()
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return _blank_document()
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return _blank_document()
    var document: Dictionary = parsed
    if int(document.get("schema_version", 0)) != SCHEMA_VERSION:
        return _blank_document()
    if not document.get("releases", {}) is Dictionary:
        document["releases"] = {}
    if not document.get("album", {}) is Dictionary:
        document["album"] = _blank_document()["album"]
    if not document.get("run", {}) is Dictionary:
        document["run"] = {}
    if not document.get("reward", {}) is Dictionary:
        document["reward"] = {}
    return document

static func _migrate_previous() -> Dictionary:
    var document: Dictionary = _blank_document()
    for source_path in [PREVIOUS_SAVE_PATH, LEGACY_SAVE_PATH]:
        if not FileAccess.file_exists(source_path):
            continue
        var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
        if file == null:
            continue
        var parsed: Variant = JSON.parse_string(file.get_as_text())
        if not parsed is Dictionary:
            continue
        var old_document: Dictionary = parsed
        for key in ["install_id", "releases", "album", "run", "reward"]:
            var value: Variant = old_document.get(key)
            if value == null:
                continue
            if value is Dictionary or value is Array:
                document[key] = value.duplicate(true)
            else:
                document[key] = value
        _write_document(document)
        return document
    return document

static func _recover_backup_if_needed() -> void:
    if FileAccess.file_exists(SAVE_PATH) or not FileAccess.file_exists(BACKUP_PATH):
        return
    var recovery_error: Error = DirAccess.rename_absolute(BACKUP_PATH, SAVE_PATH)
    if recovery_error != OK:
        push_warning("Could not recover Synestezja progress backup")

static func _write_document(document: Dictionary) -> bool:
    document["schema_version"] = SCHEMA_VERSION
    document["updated_at_unix"] = int(Time.get_unix_time_from_system())
    var temporary_path: String = "%s.tmp" % SAVE_PATH
    if FileAccess.file_exists(temporary_path):
        DirAccess.remove_absolute(temporary_path)
    var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
    if file == null:
        push_warning("Could not write local Synestezja progress")
        return false
    file.store_string(JSON.stringify(document))
    file.close()

    if FileAccess.file_exists(BACKUP_PATH):
        DirAccess.remove_absolute(BACKUP_PATH)
    if FileAccess.file_exists(SAVE_PATH):
        var backup_error: Error = DirAccess.rename_absolute(SAVE_PATH, BACKUP_PATH)
        if backup_error != OK:
            push_warning("Could not create Synestezja progress backup")
            DirAccess.remove_absolute(temporary_path)
            return false

    var rename_error: Error = DirAccess.rename_absolute(temporary_path, SAVE_PATH)
    if rename_error != OK:
        push_warning("Could not commit local Synestezja progress")
        if FileAccess.file_exists(BACKUP_PATH):
            DirAccess.rename_absolute(BACKUP_PATH, SAVE_PATH)
        return false
    if FileAccess.file_exists(BACKUP_PATH):
        DirAccess.remove_absolute(BACKUP_PATH)
    return true
