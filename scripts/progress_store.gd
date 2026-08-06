extends RefCounted

const SAVE_PATH: String = "user://synesthesia-progress-v4.json"
const PREVIOUS_PATHS: Array[String] = [
    "user://synesthesia-progress-v3.json",
    "user://synesthesia-progress-v2.json",
    "user://synesthesia-progress-v1.json",
]
const BACKUP_PATH: String = "user://synesthesia-progress-v4.backup.json"
const SCHEMA_VERSION: int = 4

static var _cached_document: Dictionary = {}
static var _cache_loaded: bool = false

static func load_release(release_id: String) -> Dictionary:
    if release_id.is_empty():
        return {}
    var document: Dictionary = _load_document()
    var releases_value: Variant = document.get("releases", {})
    if not releases_value is Dictionary:
        return {}
    var state_value: Variant = (releases_value as Dictionary).get(release_id, {})
    return state_value.duplicate(true) if state_value is Dictionary else {}

static func save_release(release_id: String, state: Dictionary) -> bool:
    if release_id.is_empty():
        return false
    var document: Dictionary = _load_document()
    var releases_value: Variant = document.get("releases", {})
    var releases: Dictionary = releases_value if releases_value is Dictionary else {}
    releases[release_id] = state.duplicate(true)
    document["releases"] = releases
    return _write_document(document)

static func save_checkpoint(release_id: String, release_state: Dictionary, album_state: Dictionary) -> bool:
    if release_id.is_empty():
        return false
    var document: Dictionary = _load_document()
    var releases_value: Variant = document.get("releases", {})
    var releases: Dictionary = releases_value if releases_value is Dictionary else {}
    releases[release_id] = release_state.duplicate(true)
    document["releases"] = releases
    document["album"] = album_state.duplicate(true)
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
    var album_value: Variant = _load_document().get("album", {})
    return album_value.duplicate(true) if album_value is Dictionary else {}

static func save_album(state: Dictionary) -> bool:
    var document: Dictionary = _load_document()
    document["album"] = state.duplicate(true)
    return _write_document(document)

static func load_run() -> Dictionary:
    var value: Variant = _load_document().get("run", {})
    return value.duplicate(true) if value is Dictionary else {}

static func save_run(state: Dictionary) -> bool:
    var document: Dictionary = _load_document()
    document["run"] = state.duplicate(true)
    return _write_document(document)

static func clear_run() -> bool:
    var document: Dictionary = _load_document()
    document["run"] = {}
    return _write_document(document)

static func load_reward() -> Dictionary:
    var value: Variant = _load_document().get("reward", {})
    return value.duplicate(true) if value is Dictionary else {}

static func save_reward(state: Dictionary) -> bool:
    var document: Dictionary = _load_document()
    document["reward"] = state.duplicate(true)
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
    for path in [SAVE_PATH, BACKUP_PATH]:
        if FileAccess.file_exists(path):
            var error: Error = DirAccess.remove_absolute(path)
            if error != OK:
                return false
    _cached_document = {}
    _cache_loaded = false
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
            "calm_mode": true,
            "quiet_mode": false,
            "quiet_visuals": false,
            "reduced_motion": false,
            "haptics_enabled": true,
            "quality_profile": "balanced",
            "music_level": 1.0,
            "noise_level": 1.0,
        },
        "run": {},
        "reward": {},
    }

static func _load_document() -> Dictionary:
    if _cache_loaded:
        return _cached_document
    _recover_backup_if_needed()
    if not FileAccess.file_exists(SAVE_PATH):
        _cached_document = _migrate_previous()
        _cache_loaded = true
        return _cached_document
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        _cached_document = _blank_document()
        _cache_loaded = true
        return _cached_document
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        _cached_document = _blank_document()
        _cache_loaded = true
        return _cached_document
    var document: Dictionary = parsed
    if int(document.get("schema_version", 0)) != SCHEMA_VERSION:
        _cached_document = _migrate_document(document)
    else:
        _cached_document = _normalize_document(document)
    _cache_loaded = true
    return _cached_document

static func _migrate_previous() -> Dictionary:
    for source_path in PREVIOUS_PATHS:
        if not FileAccess.file_exists(source_path):
            continue
        var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
        if file == null:
            continue
        var parsed: Variant = JSON.parse_string(file.get_as_text())
        if parsed is Dictionary:
            var migrated: Dictionary = _migrate_document(parsed)
            _write_document(migrated)
            return migrated
    return _blank_document()

static func _migrate_document(old_document: Dictionary) -> Dictionary:
    var document: Dictionary = _blank_document()
    for key in ["install_id", "releases", "album", "run", "reward"]:
        var value: Variant = old_document.get(key)
        if value == null:
            continue
        if value is Dictionary or value is Array:
            document[key] = value.duplicate(true)
        else:
            document[key] = value
    document["schema_version"] = SCHEMA_VERSION
    return _normalize_document(document)

static func _normalize_document(document: Dictionary) -> Dictionary:
    var blank: Dictionary = _blank_document()
    if not document.get("releases", {}) is Dictionary:
        document["releases"] = {}
    if not document.get("run", {}) is Dictionary:
        document["run"] = {}
    if not document.get("reward", {}) is Dictionary:
        document["reward"] = {}
    var album_value: Variant = document.get("album", {})
    var album: Dictionary = album_value if album_value is Dictionary else {}
    var blank_album_value: Variant = blank.get("album", {})
    var blank_album: Dictionary = blank_album_value if blank_album_value is Dictionary else {}
    for key in blank_album.keys():
        if not album.has(key):
            var default_value: Variant = blank_album[key]
            album[key] = default_value.duplicate(true) if default_value is Dictionary or default_value is Array else default_value
    document["album"] = album
    document["schema_version"] = SCHEMA_VERSION
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
    _cached_document = document
    _cache_loaded = true
    return true
