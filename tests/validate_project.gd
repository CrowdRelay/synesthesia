extends SceneTree

const INDEX_PATH: String = "res://data/release_index.json"
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const NOISE_PATH: String = "res://assets/audio/pink-noise-asmr-loop.ogg"
const COMPOSITE_SHADER_PATH: String = "res://shaders/room_composite.gdshader"
const REVEAL_MASK_PATH: String = "res://scripts/render/reveal_mask.gd"
const EXPECTED_ROOM_COUNT: int = 11
const EXPECTED_SCHEMA: int = 4

var _failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _require_resource(MAIN_SCENE_PATH, "main scene")
    _require_resource(NOISE_PATH, "pink-noise loop")
    var noise_resource: Resource = load(NOISE_PATH)
    if not noise_resource is AudioStream:
        _fail("pink-noise loop is not an AudioStream")
    _require_resource(COMPOSITE_SHADER_PATH, "composite shader")
    _require_resource(REVEAL_MASK_PATH, "reveal mask")
    _validate_mask_roundtrip()

    var main_resource: Resource = load(MAIN_SCENE_PATH)
    if main_resource is PackedScene:
        var main_instance: Node = (main_resource as PackedScene).instantiate()
        main_instance.free()
    else:
        _fail("main scene is not a PackedScene")

    var index: Dictionary = _load_json(INDEX_PATH)
    if int(index.get("schema_version", 0)) != EXPECTED_SCHEMA:
        _fail("release index schema must equal %d" % EXPECTED_SCHEMA)
    var releases_value: Variant = index.get("releases", [])
    if not releases_value is Array:
        _fail("release index has no releases array")
        _finish()
        return
    var releases: Array = releases_value
    if releases.size() != EXPECTED_ROOM_COUNT:
        _fail("expected %d rooms, got %d" % [EXPECTED_ROOM_COUNT, releases.size()])

    for position in range(releases.size()):
        var entry_value: Variant = releases[position]
        if not entry_value is Dictionary:
            _fail("release entry %d is not an object" % position)
            continue
        var entry: Dictionary = entry_value
        var manifest_path: String = str(entry.get("manifest", ""))
        var manifest: Dictionary = _load_json(manifest_path)
        await _validate_room(position, str(entry.get("id", "")), manifest)

    _finish()

func _validate_room(position: int, expected_id: String, manifest: Dictionary) -> void:
    if manifest.is_empty():
        return
    if int(manifest.get("schema_version", 0)) != EXPECTED_SCHEMA:
        _fail("%s: schema must equal %d" % [expected_id, EXPECTED_SCHEMA])
    if str(manifest.get("release_id", "")) != expected_id:
        _fail("%s: release_id mismatch" % expected_id)
    if int(manifest.get("story_order", -1)) != position:
        _fail("%s: story_order mismatch" % expected_id)

    var room_value: Variant = manifest.get("room", {})
    var sensory_value: Variant = manifest.get("sensory", {})
    var collectibles_value: Variant = manifest.get("collectibles", [])
    var audio_value: Variant = manifest.get("audio", {})
    if not room_value is Dictionary or not sensory_value is Dictionary or not collectibles_value is Array or not audio_value is Dictionary:
        _fail("%s: malformed room contract" % expected_id)
        return
    var room_data: Dictionary = room_value
    var sensory: Dictionary = sensory_value
    var collectibles: Array = collectibles_value
    var audio: Dictionary = audio_value

    var scene_path: String = str(room_data.get("scene_path", ""))
    var behavior_path: String = str(room_data.get("behavior_script", ""))
    var art_value: Variant = room_data.get("art_direction", {})
    var art: Dictionary = art_value if art_value is Dictionary else {}
    var scene_image_path: String = str(art.get("scene_image", ""))
    var background_image_path: String = str(art.get("background_image", ""))
    var subject_image_path: String = str(art.get("subject_image", ""))
    var foreground_image_path: String = str(art.get("foreground_image", ""))
    var music_path: String = str(audio.get("completion_excerpt", ""))

    _require_resource(scene_path, "%s scene" % expected_id)
    _require_resource(behavior_path, "%s behavior" % expected_id)
    _require_resource(scene_image_path, "%s scene image" % expected_id)
    _require_resource(background_image_path, "%s background image" % expected_id)
    _require_resource(subject_image_path, "%s subject image" % expected_id)
    _require_resource(foreground_image_path, "%s foreground image" % expected_id)
    _require_resource(music_path, "%s music" % expected_id)

    var scene_image: Resource = load(scene_image_path)
    var background_image: Resource = load(background_image_path)
    var subject_image: Resource = load(subject_image_path)
    var foreground_image: Resource = load(foreground_image_path)
    var behavior_script: Resource = load(behavior_path)
    var music: Resource = load(music_path)
    if not scene_image is Texture2D:
        _fail("%s: scene image is not Texture2D" % expected_id)
    if not background_image is Texture2D:
        _fail("%s: background image is not Texture2D" % expected_id)
    if not subject_image is Texture2D:
        _fail("%s: subject image is not Texture2D" % expected_id)
    if not foreground_image is Texture2D:
        _fail("%s: foreground image is not Texture2D" % expected_id)
    if not behavior_script is Script:
        _fail("%s: behavior is not a Script" % expected_id)
    if not music is AudioStream:
        _fail("%s: music is not an AudioStream" % expected_id)

    var scene_resource: Resource = load(scene_path)
    if not scene_resource is PackedScene:
        _fail("%s: room scene is not PackedScene" % expected_id)
        return
    var room_node: Node = (scene_resource as PackedScene).instantiate()
    if str(room_node.get("room_id")) != expected_id:
        _fail("%s: scene room_id mismatch" % expected_id)
    if room_node is Control:
        var room_control: Control = room_node as Control
        # Validation owns the root size explicitly. Normalize the root anchors
        # before entering the tree so Godot does not override `size` after
        # _ready() and emit the non-equal-opposite-anchors warning.
        room_control.anchor_left = 0.0
        room_control.anchor_top = 0.0
        room_control.anchor_right = 0.0
        room_control.anchor_bottom = 0.0
        room_control.position = Vector2.ZERO
        room_control.size = Vector2(540.0, 960.0)
    get_root().add_child(room_node)
    await process_frame

    var quality: Dictionary = {
        "name": "validation",
        "mask_width": 90,
        "mask_height": 160,
        "particle_count": 12,
        "atmosphere_hz": 8.0,
        "shader_quality": 0,
        "texture_upload_hz": 12.0,
    }
    if not room_node.has_method("configure"):
        _fail("%s: room has no configure method" % expected_id)
    else:
        room_node.call("configure", room_data, collectibles, sensory, quality)
        await process_frame
        room_node.call("set_calm_mode", true)
        room_node.call("set_reduced_motion", true)
        room_node.call("set_runtime_budget", 0.68)
        room_node.call("set_quiet_visuals", true)
        room_node.call("set_interaction_enabled", true)
        _exercise_room_gesture_boundary(room_node)
        room_node.call("set_interaction_enabled", false)
        var exported_value: Variant = room_node.call("export_state")
        if not exported_value is Dictionary:
            _fail("%s: export_state is not a Dictionary" % expected_id)
        else:
            var restored_value: Variant = room_node.call("restore_state", exported_value)
            if not restored_value is bool:
                _fail("%s: restore_state must return bool" % expected_id)
        var progress_value: Variant = room_node.call("get_normalized_progress")
        if not progress_value is float and not progress_value is int:
            _fail("%s: normalized progress is not numeric" % expected_id)
        room_node.call("set_cinematic_reveal", true, true)
        if float(room_node.call("get_normalized_progress")) < 0.99:
            _fail("%s: cinematic reveal did not complete" % expected_id)

    room_node.queue_free()
    await process_frame


func _exercise_room_gesture_boundary(room_node: Node) -> void:
    var press := InputEventMouseButton.new()
    press.button_index = MOUSE_BUTTON_LEFT
    press.button_mask = MOUSE_BUTTON_MASK_LEFT
    press.position = Vector2(270.0, 480.0)
    press.pressed = true
    room_node.call("_gui_input", press)
    var release := InputEventMouseButton.new()
    release.button_index = MOUSE_BUTTON_LEFT
    release.position = press.position
    release.pressed = false
    room_node.call("_gui_input", release)

func _validate_mask_roundtrip() -> void:
    var mask_script: Resource = load(REVEAL_MASK_PATH)
    if not mask_script is Script:
        _fail("reveal mask is not a Script")
        return
    var first: Variant = (mask_script as Script).new()
    first.configure(90, 160)
    first.apply_stamp({
        "position": Vector2(0.46, 0.52),
        "radius": 0.10,
        "rotation": 0.24,
        "strength": 0.88,
        "texture": 0.42,
        "seed": 17,
        "profile": "ink",
    }, true)
    var before: float = float(first.coverage())
    var state_value: Variant = first.export_state()
    if not state_value is Dictionary:
        _fail("mask export_state is not Dictionary")
        return
    var state: Dictionary = state_value
    if str(state.get("format", "")) != "png-mask-v2":
        _fail("mask state format is not png-mask-v2")
    var second: Variant = (mask_script as Script).new()
    second.configure(90, 160)
    if not bool(second.restore_state(state, "ink")):
        _fail("mask png roundtrip failed to restore")
        return
    var after: float = float(second.coverage())
    if absf(before - after) > 0.002:
        _fail("mask coverage changed after png roundtrip")
    if int(second.estimated_state_bytes()) <= 0:
        _fail("mask state byte estimate is empty")

func _load_json(path: String) -> Dictionary:
    if path.is_empty() or not FileAccess.file_exists(path):
        _fail("missing JSON: %s" % path)
        return {}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        _fail("cannot open JSON: %s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        return parsed
    _fail("JSON root is not an object: %s" % path)
    return {}

func _require_resource(path: String, label: String) -> void:
    if path.is_empty() or not ResourceLoader.exists(path):
        _fail("missing %s: %s" % [label, path])

func _fail(message: String) -> void:
    _failures.append(message)
    print("VALIDATION_FAIL: %s" % message)

func _finish() -> void:
    if _failures.is_empty():
        print("SYNESTHESIA_VALIDATION=PASS rooms=%d renderer=mask-gpu-v2 adaptive_native=true mask_snapshot=540x960 persistence=png-mask-v2" % EXPECTED_ROOM_COUNT)
        quit(0)
    else:
        print("SYNESTHESIA_VALIDATION=FAIL count=%d" % _failures.size())
        quit(1)
