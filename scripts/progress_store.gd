extends RefCounted

const SAVE_PATH: String = "user://synesthesia-progress-v4.json"
const PREVIOUS_PATHS: Array[String] = [
    "user://synesthesia-progress-v3.json",
    "user://synesthesia-progress-v2.json",
    "user://synesthesia-progress-v1.json",
]
const BACKUP_PATH: String = "user://synesthesia-progress-v4.backup.json"
const SCHEMA_VERSION: int = 4
const MAX_SAVE_BYTES: int = 24 * 1024 * 1024

static var _cached_document: Dictionary = {}
static var _cache_loaded: bool = false
static var _loaded_from_backup: bool = false
static var _ephemeral_install_id: String = ""

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
    var document: Dictionary = _document_for_write()
    var releases_value: Variant = document.get("releases", {})
    var releases: Dictionary = releases_value if releases_value is Dictionary else {}
    releases[release_id] = state.duplicate(true)
    document["releases"] = releases
    return _write_document(document)

static func save_checkpoint(release_id: String, release_state: Dictionary, album_state: Dictionary) -> bool:
    if release_id.is_empty():
        return false
    var document: Dictionary = _document_for_write()
    var releases_value: Variant = document.get("releases", {})
    var releases: Dictionary = releases_value if releases_value is Dictionary else {}
    releases[release_id] = release_state.duplicate(true)
    document["releases"] = releases
    document["album"] = album_state.duplicate(true)
    return _write_document(document)

static func clear_release(release_id: String) -> bool:
    if release_id.is_empty():
        return false
    var document: Dictionary = _document_for_write()
    var releases_value: Variant = document.get("releases", {})
    var releases: Dictionary = releases_value if releases_value is Dictionary else {}
    releases.erase(release_id)
    document["releases"] = releases
    return _write_document(document)

static func load_album() -> Dictionary:
    var album_value: Variant = _load_document().get("album", {})
    return album_value.duplicate(true) if album_value is Dictionary else {}

static func reconcile_album_timings(release_entries: Array, album_state: Dictionary) -> Dictionary:
    # Older generations could persist each room checkpoint correctly while the
    # album-level elapsed map stayed incomplete. Recover only matching completed
    # room checkpoints; reset_local_journey clears releases, so timings can never
    # leak across attempts.
    var result: Dictionary = album_state.duplicate(true)
    var completed_value: Variant = result.get("completed_room_ids", [])
    var completed: Array = completed_value if completed_value is Array else []
    var elapsed_value: Variant = result.get("room_elapsed_ms", {})
    var elapsed: Dictionary = elapsed_value.duplicate(true) if elapsed_value is Dictionary else {}
    var changed: bool = false
    for entry_value in release_entries:
        if not entry_value is Dictionary: continue
        var release_id: String = str((entry_value as Dictionary).get("id", ""))
        if release_id.is_empty() or not completed.has(release_id) or int(elapsed.get(release_id, 0)) > 0: continue
        var saved: Dictionary = load_release(release_id)
        var saved_ms: int = maxi(0, int(saved.get("elapsed_ms", 0)))
        if bool(saved.get("completed", false)) and saved_ms > 0:
            elapsed[release_id] = saved_ms
            changed = true
    if not changed: return result
    var total: int = 0
    for value in elapsed.values(): total += maxi(0, int(value))
    result["room_elapsed_ms"] = elapsed
    result["total_elapsed_ms"] = total
    save_album(result)
    return result

static func save_album(state: Dictionary) -> bool:
    var document: Dictionary = _document_for_write()
    document["album"] = state.duplicate(true)
    return _write_document(document)

static func load_run() -> Dictionary:
    var value: Variant = _load_document().get("run", {})
    return value.duplicate(true) if value is Dictionary else {}

static func save_run(state: Dictionary) -> bool:
    var document: Dictionary = _document_for_write()
    document["run"] = state.duplicate(true)
    return _write_document(document)

static func clear_run() -> bool:
    var document: Dictionary = _document_for_write()
    document["run"] = {}
    return _write_document(document)

static func load_reward() -> Dictionary:
    var value: Variant = _load_document().get("reward", {})
    return value.duplicate(true) if value is Dictionary else {}

static func save_reward(state: Dictionary) -> bool:
    var document: Dictionary = _document_for_write()
    document["reward"] = state.duplicate(true)
    return _write_document(document)

static func get_install_id() -> String:
    var persisted: Dictionary = _load_document()
    var current: String = str(persisted.get("install_id", ""))
    if not current.is_empty():
        _ephemeral_install_id = ""
        return current
    if not _ephemeral_install_id.is_empty():
        return _ephemeral_install_id
    var crypto: Crypto = Crypto.new()
    var random_bytes: PackedByteArray = crypto.generate_random_bytes(16)
    current = random_bytes.hex_encode()
    if current.is_empty():
        current = "%x-%x" % [Time.get_ticks_usec(), randi()]
    var document: Dictionary = persisted.duplicate(true)
    document["install_id"] = current
    if not _write_document(document):
        # Keep one stable identity for this process even when persistent storage
        # is unavailable. A later launch will generate a new one, as expected.
        _ephemeral_install_id = current
    return current

static func new_journey_id() -> String:
    var crypto: Crypto = Crypto.new()
    var random_bytes: PackedByteArray = crypto.generate_random_bytes(16)
    var value: String = random_bytes.hex_encode()
    if value.is_empty():
        value = "%x-%x" % [Time.get_ticks_usec(), randi()]
    return value

static func reset_local_journey() -> bool:
    var document: Dictionary = _document_for_write()
    var previous_album_value: Variant = document.get("album", {})
    var previous_album: Dictionary = previous_album_value if previous_album_value is Dictionary else {}
    var fresh: Dictionary = _blank_document()
    fresh["install_id"] = str(document.get("install_id", ""))
    # A replay is a real new attempt. Keep user settings/reward history, but never
    # reuse the old server run or its completion cursor.
    var previous_reward_value: Variant = document.get("reward", {})
    if previous_reward_value is Dictionary:
        fresh["reward"] = previous_reward_value.duplicate(true)
    var fresh_album_value: Variant = fresh.get("album", {})
    var fresh_album: Dictionary = fresh_album_value if fresh_album_value is Dictionary else {}
    for key in ["calm_mode", "quiet_mode", "quiet_visuals", "reduced_motion", "high_readability", "haptics_enabled", "quality_profile", "music_level", "noise_level", "personal_best_room_ms", "personal_best_total_ms", "completed_runs_local", "personal_best_act_splits_ms", "replay_unlocked"]:
        if previous_album.has(key):
            var value: Variant = previous_album[key]
            fresh_album[key] = value.duplicate(true) if value is Dictionary or value is Array else value
    var replay_unlocked: bool = bool(previous_album.get("replay_unlocked", false)) or bool(previous_album.get("album_completed", false))
    fresh_album["replay_unlocked"] = replay_unlocked
    fresh_album["replay_mode"] = replay_unlocked
    fresh_album["journey_id"] = new_journey_id()
    fresh_album["started_at_unix"] = int(Time.get_unix_time_from_system())
    fresh_album["total_elapsed_ms"] = 0
    fresh_album["server_recorded_room_ids"] = []
    fresh_album["server_album_completed"] = false
    fresh["album"] = fresh_album
    fresh["run"] = {}
    return _write_document(fresh)

static func reset_all() -> bool:
    var paths: Array[String] = [SAVE_PATH, BACKUP_PATH, "%s.tmp" % SAVE_PATH]
    paths.append_array(PREVIOUS_PATHS)
    for path in paths:
        if FileAccess.file_exists(path):
            var error: Error = DirAccess.remove_absolute(path)
            if error != OK:
                return false
    _cached_document = {}
    _cache_loaded = false
    _loaded_from_backup = false
    _ephemeral_install_id = ""
    return true

static func _document_for_write() -> Dictionary:
    # Dictionaries are reference types. Mutations must happen on a deep copy so
    # a failed disk commit cannot make the in-memory read cache claim success.
    return _load_document().duplicate(true)

static func _blank_document() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "install_id": "",
        "releases": {},
        "album": {
            "current_room_index": 0,
            "journey_id": "",
            "completed_room_ids": [],
            "server_recorded_room_ids": [],
            "pending_room_completions": [],
            "room_elapsed_ms": {},
            "personal_best_room_ms": {},
            "personal_best_act_splits_ms": {},
            "personal_best_total_ms": 0,
            "replay_unlocked": false,
            "replay_mode": false,
            "completed_runs_local": 0,
            "album_completed": false,
            "echo_archive": {},
            "calm_mode": true,
            "quiet_mode": false,
            "quiet_visuals": false,
            "reduced_motion": false,
            "high_readability": false,
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
    var parsed: Variant = _read_json_document(SAVE_PATH)
    if not parsed is Dictionary:
        var backup: Variant = _read_json_document(BACKUP_PATH)
        if backup is Dictionary:
            push_warning("Recovered Synestezja progress from last-good backup")
            parsed = backup
            _loaded_from_backup = true
        else:
            _cached_document = _blank_document()
            _cache_loaded = true
            return _cached_document
    var document: Dictionary = parsed
    if int(document.get("schema_version", 0)) != SCHEMA_VERSION:
        _cached_document = _migrate_document(document)
    else:
        _cached_document = _normalize_document(document)
    _cache_loaded = true
    if _loaded_from_backup:
        # Heal a corrupt current generation immediately. Otherwise a read-only
        # session would recover from BACKUP_PATH on every launch until gameplay
        # happened to trigger a later save. Failure is non-fatal: the valid
        # backup remains authoritative and in-memory state stays usable.
        var recovered: Dictionary = _cached_document.duplicate(true)
        if not _write_document(recovered):
            _cached_document = recovered
            _cache_loaded = true
            _loaded_from_backup = true
    return _cached_document


static func _read_json_document(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    if file.get_length() > MAX_SAVE_BYTES:
        push_warning("Ignoring oversized Synestezja progress file: %s" % path)
        return null
    return JSON.parse_string(file.get_as_text())

static func _migrate_previous() -> Dictionary:
    for source_path in PREVIOUS_PATHS:
        if not FileAccess.file_exists(source_path):
            continue
        var parsed: Variant = _read_json_document(source_path)
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
    var serialized: String = JSON.stringify(document)
    if serialized.to_utf8_buffer().size() > MAX_SAVE_BYTES:
        push_warning("Refusing oversized local Synestezja progress write")
        return false
    var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
    if file == null:
        push_warning("Could not write local Synestezja progress")
        return false
    file.store_string(serialized)
    file.flush()
    file.close()

    if _loaded_from_backup:
        # The current SAVE_PATH is known-bad. Preserve the valid last-good backup
        # instead of rotating the corrupt file over it.
        if FileAccess.file_exists(SAVE_PATH):
            var remove_error: Error = DirAccess.remove_absolute(SAVE_PATH)
            if remove_error != OK:
                push_warning("Could not remove corrupt Synestezja progress before recovery commit")
                DirAccess.remove_absolute(temporary_path)
                return false
    else:
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
    # Keep BACKUP_PATH as the previous known-good generation. It is tiny next
    # to the media payload and turns partial/corrupt saves into recoverable state.
    _loaded_from_backup = false
    _cached_document = document
    _cache_loaded = true
    if not str(document.get("install_id", "")).is_empty():
        _ephemeral_install_id = ""
    return true
