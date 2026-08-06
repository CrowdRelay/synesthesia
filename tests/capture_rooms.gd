extends SceneTree

const INDEX_PATH: String = "res://data/release_index.json"
const OUTPUT_DIR: String = "user://synesthesia-room-captures"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var index: Dictionary = _load_json(INDEX_PATH)
    var releases_value: Variant = index.get("releases", [])
    if not releases_value is Array:
        push_error("capture: release index has no releases array")
        quit(1)
        return
    var output_absolute: String = ProjectSettings.globalize_path(OUTPUT_DIR)
    var directory_error: Error = DirAccess.make_dir_recursive_absolute(output_absolute)
    if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
        push_error("capture: cannot create %s" % output_absolute)
        quit(1)
        return

    for entry_value in releases_value:
        if not entry_value is Dictionary:
            continue
        var entry: Dictionary = entry_value
        var manifest: Dictionary = _load_json(str(entry.get("manifest", "")))
        var room_value: Variant = manifest.get("room", {})
        var sensory_value: Variant = manifest.get("sensory", {})
        var collectibles_value: Variant = manifest.get("collectibles", [])
        if not room_value is Dictionary or not sensory_value is Dictionary or not collectibles_value is Array:
            push_error("capture: malformed manifest for %s" % str(entry.get("id", "unknown")))
            quit(1)
            return
        var room_data: Dictionary = room_value
        var scene_path: String = str(room_data.get("scene_path", ""))
        var packed_value: Resource = load(scene_path)
        if not packed_value is PackedScene:
            push_error("capture: cannot load %s" % scene_path)
            quit(1)
            return
        var room_node: Node = (packed_value as PackedScene).instantiate()
        get_root().add_child(room_node)
        if room_node is Control:
            var control: Control = room_node as Control
            control.size = Vector2(540.0, 960.0)
        await process_frame
        room_node.call("configure", room_data, collectibles_value, sensory_value, {
            "name": "capture", "mask_width": 270, "mask_height": 480,
            "particle_count": 42, "atmosphere_hz": 24.0,
            "shader_quality": 2, "texture_upload_hz": 30.0,
        })
        room_node.call("set_calm_mode", true)
        room_node.call("set_cinematic_reveal", true)
        await process_frame
        await process_frame
        var image: Image = get_root().get_texture().get_image()
        var room_id: String = str(entry.get("id", "room"))
        var save_error: Error = image.save_png("%s/%s.png" % [OUTPUT_DIR, room_id])
        if save_error != OK:
            push_error("capture: failed to save %s" % room_id)
            quit(1)
            return
        room_node.queue_free()
        await process_frame

    print("SYNESTHESIA_ROOM_CAPTURES=PASS output=%s" % output_absolute)
    quit(0)

func _load_json(path: String) -> Dictionary:
    if path.is_empty() or not FileAccess.file_exists(path):
        return {}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}
