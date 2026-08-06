extends Control

const PaintRoomScript := preload("res://scripts/paint_room.gd")
const AudioDirectorScript := preload("res://scripts/audio_director.gd")
const HapticsScript := preload("res://scripts/haptics.gd")
const ProgressStoreScript := preload("res://scripts/progress_store.gd")
const RewardClientScript := preload("res://scripts/reward_client.gd")
const SnowShader := preload("res://shaders/visual_snow.gdshader")

const RELEASE_INDEX_PATH: String = "res://data/release_index.json"
const VERSION_PATH: String = "res://VERSION"
const FINAL_REVEAL_RATIO: float = 0.99
const PRIVATE_PANEL_COLOR: Color = Color("111a2af5")

var index_document: Dictionary = {}
var release_entries: Array = []
var manifest: Dictionary = {}
var album_state: Dictionary = {}
var current_room_index: int = 0
var current_coverage: float = 0.0
var room_started_ms: int = 0
var completion_announced: bool = false
var restoring_progress: bool = false
var transition_running: bool = false
var calm_mode: bool = true
var quiet_mode: bool = false
var haptics_enabled: bool = true

var room
var audio_director
var haptics
var reward_client

var room_layer: Control
var snow_overlay: ColorRect
var snow_material: ShaderMaterial
var top_title: Label
var top_subtitle: Label
var room_counter: Label
var progress_label: Label
var discovery_label: Label
var mode_button: Button
var quiet_button: Button
var haptics_button: Button
var completion_panel: PanelContainer
var intro_panel: PanelContainer
var reward_panel: PanelContainer
var transition_overlay: ColorRect
var save_timer: Timer
var reward_email: LineEdit
var reward_city: LineEdit
var reward_marketing: CheckBox
var reward_status: Label
var reward_claim_button: Button

func _ready() -> void:
    index_document = _load_json(RELEASE_INDEX_PATH)
    if index_document.is_empty():
        _show_fatal_error("Nie udało się wczytać ścieżki albumu.")
        return

    var raw_releases: Variant = index_document.get("releases", [])
    if raw_releases is Array:
        for value in raw_releases:
            if value is Dictionary and bool(value.get("available", true)):
                release_entries.append(value.duplicate(true))
    if release_entries.is_empty():
        _show_fatal_error("Nie znaleziono żadnego dostępnego pokoju.")
        return

    album_state = ProgressStoreScript.load_album()
    current_room_index = clampi(int(album_state.get("current_room_index", 0)), 0, release_entries.size() - 1)
    calm_mode = bool(album_state.get("calm_mode", true))
    quiet_mode = bool(album_state.get("quiet_mode", false))
    haptics_enabled = bool(album_state.get("haptics_enabled", true))
    if not album_state.has("started_at_unix"):
        album_state["started_at_unix"] = int(Time.get_unix_time_from_system())
    if not album_state.has("total_elapsed_ms"):
        album_state["total_elapsed_ms"] = 0

    _build_application_shell()
    _configure_reward_client()
    _load_room(current_room_index, true)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("Missing JSON: %s" % path)
        return {}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Cannot open JSON: %s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        return parsed
    push_error("JSON root is not an object: %s" % path)
    return {}

func _read_version() -> String:
    if not FileAccess.file_exists(VERSION_PATH):
        return "0.6.1"
    var file: FileAccess = FileAccess.open(VERSION_PATH, FileAccess.READ)
    if file == null:
        return "0.6.1"
    return file.get_as_text().strip_edges()

func _build_application_shell() -> void:
    room_layer = Control.new()
    room_layer.name = "RoomLayer"
    add_child(room_layer)
    room_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    _build_snow_overlay()
    _build_top_ui()
    _build_bottom_ui()
    _build_save_timer()

    transition_overlay = ColorRect.new()
    transition_overlay.name = "RoomTransition"
    transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    transition_overlay.color = Color(0.02, 0.025, 0.045, 0.0)
    transition_overlay.visible = false
    add_child(transition_overlay)
    transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_snow_overlay() -> void:
    snow_overlay = ColorRect.new()
    snow_overlay.name = "GentleVisualSnow"
    snow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    snow_overlay.color = Color.WHITE
    add_child(snow_overlay)
    snow_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    snow_material = ShaderMaterial.new()
    snow_material.shader = SnowShader
    snow_overlay.material = snow_material

func _build_top_ui() -> void:
    var margin: MarginContainer = MarginContainer.new()
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_theme_constant_override("margin_left", 24)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_right", 24)
    add_child(margin)
    margin.set_anchors_preset(Control.PRESET_TOP_WIDE)

    var panel: PanelContainer = PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", _panel_style(Color("0b101bd9"), 22))
    margin.add_child(panel)

    var content: VBoxContainer = VBoxContainer.new()
    content.add_theme_constant_override("separation", 4)
    panel.add_child(content)

    var header_row: HBoxContainer = HBoxContainer.new()
    header_row.add_theme_constant_override("separation", 8)
    content.add_child(header_row)

    top_title = Label.new()
    top_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_title.add_theme_font_size_override("font_size", 21)
    top_title.add_theme_color_override("font_color", Color("eef6ff"))
    header_row.add_child(top_title)

    room_counter = Label.new()
    room_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    room_counter.add_theme_font_size_override("font_size", 12)
    room_counter.add_theme_color_override("font_color", Color("78b9ff"))
    header_row.add_child(room_counter)

    top_subtitle = Label.new()
    top_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    top_subtitle.add_theme_font_size_override("font_size", 13)
    top_subtitle.add_theme_color_override("font_color", Color("b8c7dc"))
    content.add_child(top_subtitle)

    progress_label = Label.new()
    progress_label.text = "Pokój pozostaje cichy. Dotknij obrazu."
    progress_label.add_theme_font_size_override("font_size", 12)
    progress_label.add_theme_color_override("font_color", Color("7fb7ff"))
    content.add_child(progress_label)

func _build_bottom_ui() -> void:
    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_bottom", 16)
    add_child(margin)
    margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)

    var panel: PanelContainer = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _panel_style(Color("090d17e8"), 22))
    margin.add_child(panel)

    var content: VBoxContainer = VBoxContainer.new()
    content.add_theme_constant_override("separation", 8)
    panel.add_child(content)

    discovery_label = Label.new()
    discovery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    discovery_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    discovery_label.add_theme_font_size_override("font_size", 13)
    discovery_label.add_theme_color_override("font_color", Color("d6e7ff"))
    content.add_child(discovery_label)

    var buttons: HBoxContainer = HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 7)
    content.add_child(buttons)

    mode_button = _make_button("")
    mode_button.pressed.connect(_toggle_mode)
    buttons.add_child(mode_button)

    quiet_button = _make_button("")
    quiet_button.pressed.connect(_toggle_quiet)
    buttons.add_child(quiet_button)

    haptics_button = _make_button("")
    haptics_button.pressed.connect(_toggle_haptics)
    buttons.add_child(haptics_button)

    var reset_button: Button = _make_button("Od nowa")
    reset_button.pressed.connect(_reset_room)
    buttons.add_child(reset_button)

func _build_save_timer() -> void:
    save_timer = Timer.new()
    save_timer.name = "ProgressSaveTimer"
    save_timer.one_shot = true
    save_timer.wait_time = 1.0
    save_timer.timeout.connect(_save_progress)
    add_child(save_timer)

func _configure_reward_client() -> void:
    var reward_config_value: Variant = index_document.get("reward", {})
    if not reward_config_value is Dictionary:
        return
    var reward_config: Dictionary = reward_config_value
    if not bool(reward_config.get("enabled", false)):
        return

    reward_client = RewardClientScript.new()
    reward_client.name = "SynesthesiaRewardClient"
    add_child(reward_client)
    reward_client.configure(
        str(reward_config.get("api_url", "")),
        str(index_document.get("campaign_slug", "")),
        _read_version(),
        ProgressStoreScript.get_install_id(),
    )
    reward_client.restore_run(ProgressStoreScript.load_run())
    reward_client.run_started.connect(_on_run_started)
    reward_client.room_recorded.connect(_on_room_recorded)
    reward_client.album_recorded.connect(_on_album_recorded)
    reward_client.reward_claimed.connect(_on_reward_claimed)
    reward_client.request_failed.connect(_on_reward_request_failed)
    reward_client.start_run()

func _load_room(index: int, show_intro: bool) -> void:
    if index < 0 or index >= release_entries.size():
        _show_fatal_error("Próba wejścia do nieznanego pokoju.")
        return

    _remove_modal(intro_panel)
    intro_panel = null
    _remove_modal(completion_panel)
    completion_panel = null
    _clear_room_runtime()

    current_room_index = index
    album_state["current_room_index"] = current_room_index
    _save_album_state()

    var entry_value: Variant = release_entries[current_room_index]
    if not entry_value is Dictionary:
        _show_fatal_error("Nieprawidłowy wpis pokoju.")
        return
    var entry: Dictionary = entry_value
    var manifest_path: String = str(entry.get("manifest", ""))
    manifest = _load_json(manifest_path)
    if manifest.is_empty():
        _show_fatal_error("Nie udało się wczytać pokoju: %s" % str(entry.get("id", "?")))
        return

    var collectible_entries_value: Variant = manifest.get("collectibles", [])
    var collectible_entries: Array = collectible_entries_value if collectible_entries_value is Array else []

    room = PaintRoomScript.new()
    room.name = "PaintRoom"
    room_layer.add_child(room)
    room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    room.configure(manifest.get("room", {}), collectible_entries)
    room.coverage_changed.connect(_on_coverage_changed)
    room.collectible_found.connect(_on_collectible_found)
    room.paint_pulse.connect(_on_paint_pulse)
    room.special_interaction.connect(_on_special_interaction)

    audio_director = AudioDirectorScript.new()
    audio_director.name = "AudioDirector"
    add_child(audio_director)
    audio_director.configure(
        manifest.get("sensory", {}),
        manifest.get("audio", {}),
        maxi(1, collectible_entries.size()),
    )

    haptics = HapticsScript.new()
    haptics.name = "Haptics"
    add_child(haptics)
    haptics.configure(manifest.get("sensory", {}), str(manifest.get("room", {}).get("visual_style", "paint")))

    completion_announced = false
    current_coverage = 0.0
    room_started_ms = Time.get_ticks_msec()
    _update_room_copy()
    _apply_sensory_mode()
    call_deferred("_restore_room_after_layout", show_intro)

func _clear_room_runtime() -> void:
    if room != null and is_instance_valid(room):
        room.queue_free()
    room = null
    if audio_director != null and is_instance_valid(audio_director):
        audio_director.queue_free()
    audio_director = null
    if haptics != null and is_instance_valid(haptics):
        haptics.queue_free()
    haptics = null

func _restore_room_after_layout(show_intro: bool) -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    if room == null or not is_instance_valid(room):
        return

    var release_id: String = str(manifest.get("release_id", ""))
    var saved: Dictionary = ProgressStoreScript.load_release(release_id)
    restoring_progress = true
    var restored: bool = false
    if not saved.is_empty():
        var room_state_value: Variant = saved.get("room", {})
        if room_state_value is Dictionary:
            restored = bool(room.restore_state(room_state_value))
        completion_announced = bool(saved.get("completed", false))

    room.set_calm_mode(calm_mode)
    room.set_interaction_enabled(not completion_announced)
    audio_director.set_calm_mode(calm_mode)
    audio_director.set_quiet(quiet_mode)
    haptics.set_calm_mode(calm_mode)
    haptics.set_enabled(haptics_enabled and not quiet_mode)
    _apply_sensory_mode()

    if restored:
        current_coverage = float(room.get_coverage())
        var found: int = int(room.get_found_count())
        var normalized: float = float(room.get_normalized_progress())
        discovery_label.text = "%d/%d ślady · pokój pamięta poprzedni dotyk" % [found, _collectible_total()]
        progress_label.text = "%d%% obrazu odsłonięte" % mini(99, int(floor(normalized * 100.0)))
        audio_director.set_progress(normalized, found)

    if completion_announced:
        room.set_cinematic_reveal(true)
        room.set_door_open(true)
        snow_material.set_shader_parameter("intensity", 0.0)
        audio_director.reveal_release_excerpt()
        call_deferred("_show_completion_panel")
    elif saved.is_empty() and show_intro:
        _show_intro()
    else:
        room.set_interaction_enabled(true)

    restoring_progress = false

func _update_room_copy() -> void:
    top_title.text = str(manifest.get("title", "VIRYA: Synestezja"))
    top_subtitle.text = str(manifest.get("subtitle", ""))
    room_counter.text = "%02d / %02d" % [current_room_index + 1, release_entries.size()]
    progress_label.text = "0% obrazu odsłonięte · maluj bez pośpiechu"
    discovery_label.text = "0/%d ślady · odkrywaj obraz spod śniegu" % _collectible_total()

func _collectible_total() -> int:
    var entries_value: Variant = manifest.get("collectibles", [])
    if entries_value is Array:
        return maxi(1, entries_value.size())
    return 1

func _show_intro() -> void:
    if room == null:
        return
    room.set_interaction_enabled(false)
    intro_panel = _modal_panel(Vector2(560.0, 350.0))

    var content: VBoxContainer = VBoxContainer.new()
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 14)
    intro_panel.add_child(content)

    var heading: Label = _modal_heading(str(manifest.get("room", {}).get("name", "Pokój")))
    content.add_child(heading)

    var message: Label = _modal_text(str(manifest.get("intro", "Maluj bez pośpiechu. Obraz odpowie kolorem i dźwiękiem.")))
    content.add_child(message)

    var note: Label = _modal_text("Przy 99% cały filtr ustąpi naraz. Nie musisz szukać ostatniego piksela.")
    note.add_theme_color_override("font_color", Color("82bfff"))
    note.add_theme_font_size_override("font_size", 13)
    content.add_child(note)

    var enter_button: Button = _make_button("Wejdź bez pośpiechu")
    enter_button.pressed.connect(_dismiss_intro)
    content.add_child(enter_button)

func _dismiss_intro() -> void:
    _remove_modal(intro_panel)
    intro_panel = null
    if room != null:
        room.set_interaction_enabled(true)
    _schedule_save()

func _on_coverage_changed(value: float) -> void:
    if room == null:
        return
    current_coverage = value
    var normalized: float = float(room.get_normalized_progress())
    var display_percent: int = mini(99, int(floor(normalized * 100.0)))
    progress_label.text = "%d%% obrazu odsłonięte · śnieg ustępuje pod gestem" % display_percent
    if audio_director != null:
        audio_director.set_progress(normalized, int(room.get_found_count()))
    _update_global_snow(normalized)

    var reveal_at: float = float(manifest.get("room", {}).get("cinematic_reveal_at", FINAL_REVEAL_RATIO))
    if normalized >= reveal_at:
        _complete_current_room()
    _schedule_save()

func _on_collectible_found(item: Dictionary) -> void:
    if room == null:
        return
    var count: int = int(room.get_found_count())
    discovery_label.text = "%d/%d · %s — %s" % [
        count,
        _collectible_total(),
        str(item.get("title", "Ślad")),
        str(item.get("message", "")),
    ]
    if haptics != null:
        haptics.discovery()
    if audio_director != null:
        audio_director.set_progress(float(room.get_normalized_progress()), count)
    _schedule_save()

func _on_paint_pulse(speed_normalized: float) -> void:
    if haptics != null:
        haptics.paint_tick(speed_normalized)

func _on_special_interaction(kind: String, _index: int) -> void:
    if haptics == null:
        return
    haptics.special(kind)
    match kind:
        "balloon":
            discovery_label.text = "POP! Balon pękł · rób dalej kolorowy bałagan"
        "mirror":
            discovery_label.text = "Tafla pękła · odbicie traci władzę"
        "toast":
            discovery_label.text = "Toast uniesiony · czerwień została tylko w winie"
        "duel":
            discovery_label.text = "Przeciwnik traci kształt · własna droga zostaje"

func _complete_current_room() -> void:
    if completion_announced or room == null:
        return
    completion_announced = true
    room.set_interaction_enabled(false)
    room.set_cinematic_reveal(true)
    room.reveal_remaining_collectibles()
    room.set_door_open(true)
    current_coverage = float(room.get_coverage())
    progress_label.text = "100% · cały pokój odsłonił się naraz"
    discovery_label.text = "%d/%d ślady · drzwi są otwarte" % [_collectible_total(), _collectible_total()]
    snow_material.set_shader_parameter("intensity", 0.0)

    if audio_director != null:
        audio_director.set_progress(1.0, _collectible_total())
        audio_director.reveal_release_excerpt()
    if haptics != null:
        haptics.cinematic_reveal()

    var release_id: String = str(manifest.get("release_id", ""))
    var completed_ids: Array = _array_value(album_state.get("completed_room_ids", []))
    if not completed_ids.has(release_id):
        completed_ids.append(release_id)
    album_state["completed_room_ids"] = completed_ids
    album_state["current_room_index"] = current_room_index
    var room_elapsed: int = maxi(0, Time.get_ticks_msec() - room_started_ms)
    var elapsed_by_room_value: Variant = album_state.get("room_elapsed_ms", {})
    var elapsed_by_room: Dictionary = elapsed_by_room_value if elapsed_by_room_value is Dictionary else {}
    elapsed_by_room[release_id] = maxi(int(elapsed_by_room.get(release_id, 0)), room_elapsed)
    album_state["room_elapsed_ms"] = elapsed_by_room
    album_state["total_elapsed_ms"] = int(album_state.get("total_elapsed_ms", 0)) + room_elapsed
    if current_room_index == release_entries.size() - 1:
        album_state["album_completed"] = true
    _save_album_state()
    _save_progress()

    if reward_client != null and reward_client.has_run():
        reward_client.record_room(release_id, current_room_index, room_elapsed)
        if current_room_index == release_entries.size() - 1:
            reward_client.complete_album(int(album_state.get("total_elapsed_ms", 0)))

    call_deferred("_show_completion_panel")

func _show_completion_panel() -> void:
    await get_tree().create_timer(0.65).timeout
    if completion_panel != null or transition_running or reward_panel != null:
        return
    completion_panel = _modal_panel(Vector2(570.0, 330.0))

    var content: VBoxContainer = VBoxContainer.new()
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 13)
    completion_panel.add_child(content)

    content.add_child(_modal_heading(str(manifest.get("completion_title", "Pokój się otworzył"))))
    content.add_child(_modal_text(str(manifest.get("completion_message", "Obraz i muzyka zostały odsłonięte."))))

    var next_button: Button
    if current_room_index < release_entries.size() - 1:
        var next_entry_value: Variant = release_entries[current_room_index + 1]
        var next_name: String = "kolejnego pokoju"
        if next_entry_value is Dictionary:
            var next_manifest: Dictionary = _load_json(str(next_entry_value.get("manifest", "")))
            next_name = str(next_manifest.get("room", {}).get("name", "kolejnego pokoju"))
        next_button = _make_button("Przejdź przez drzwi · %s" % next_name)
        next_button.pressed.connect(func() -> void: _transition_to_room(current_room_index + 1))
    else:
        next_button = _make_button("Przejdź przez ostatnie drzwi")
        next_button.pressed.connect(_transition_to_reward)
    content.add_child(next_button)

    var stay_button: Button = _make_button("Zostań i słuchaj")
    stay_button.pressed.connect(func() -> void:
        _remove_modal(completion_panel)
        completion_panel = null
    )
    content.add_child(stay_button)

func _transition_to_room(next_index: int) -> void:
    if transition_running:
        return
    transition_running = true
    if haptics != null:
        haptics.door_open()
    _remove_modal(completion_panel)
    completion_panel = null
    await _fade_to_black()
    _load_room(next_index, true)
    await get_tree().process_frame
    await _fade_from_black()
    transition_running = false

func _transition_to_reward() -> void:
    if transition_running:
        return
    transition_running = true
    if haptics != null:
        haptics.door_open()
    _remove_modal(completion_panel)
    completion_panel = null
    await _fade_to_black()
    _clear_room_runtime()
    room_layer.visible = false
    await _fade_from_black()
    transition_running = false
    _show_reward_panel()

func _fade_to_black() -> void:
    transition_overlay.visible = true
    transition_overlay.color.a = 0.0
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(transition_overlay, "color:a", 1.0, 0.58)
    await tween.finished

func _fade_from_black() -> void:
    transition_overlay.visible = true
    transition_overlay.color.a = 1.0
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(transition_overlay, "color:a", 0.0, 0.58)
    await tween.finished
    transition_overlay.visible = false

func _show_reward_panel() -> void:
    if reward_panel != null:
        return
    top_title.text = "VIRYA: Synestezja"
    top_subtitle.text = "Jedenaście pokojów. Jeden pełny Sygnał."
    room_counter.text = "FINAŁ"
    progress_label.text = "Całe doświadczenie ukończone"
    discovery_label.text = "Nagroda jest przypisana do zweryfikowanego e-maila"
    snow_material.set_shader_parameter("intensity", 0.0)

    reward_panel = _modal_panel(Vector2(620.0, 650.0))
    var content: VBoxContainer = VBoxContainer.new()
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 11)
    reward_panel.add_child(content)

    content.add_child(_modal_heading("Twój Sygnał dotarł"))
    var message: Label = _modal_text(
        "Ukończyłeś cały album. Po potwierdzeniu e-maila otrzymujesz jedną płytę VIRYA na nasz koszt. " +
        "Dane wysyłkowe podasz dopiero w bezpiecznym formularzu z wiadomości."
    )
    content.add_child(message)

    reward_email = LineEdit.new()
    reward_email.placeholder_text = "E-mail do potwierdzenia nagrody"
    reward_email.custom_minimum_size = Vector2(0.0, 48.0)
    reward_email.add_theme_font_size_override("font_size", 15)
    content.add_child(reward_email)

    reward_city = LineEdit.new()
    reward_city.placeholder_text = "Miasto Sygnału, np. Wrocław"
    reward_city.custom_minimum_size = Vector2(0.0, 48.0)
    reward_city.add_theme_font_size_override("font_size", 15)
    content.add_child(reward_city)

    reward_marketing = CheckBox.new()
    reward_marketing.text = "Chcę dołączyć do Sygnału i otrzymywać informacje od VIRYA"
    reward_marketing.add_theme_font_size_override("font_size", 13)
    content.add_child(reward_marketing)

    var consent_note: Label = _modal_text("Zgoda marketingowa jest dobrowolna i oddzielona od odbioru płyty.")
    consent_note.add_theme_font_size_override("font_size", 12)
    consent_note.add_theme_color_override("font_color", Color("9db0c8"))
    content.add_child(consent_note)

    reward_status = Label.new()
    reward_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    reward_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    reward_status.add_theme_font_size_override("font_size", 13)
    reward_status.add_theme_color_override("font_color", Color("82bfff"))
    content.add_child(reward_status)

    reward_claim_button = _make_button("Odbierz płytę")
    reward_claim_button.pressed.connect(_submit_reward_claim)
    content.add_child(reward_claim_button)

    var replay_button: Button = _make_button("Wróć do pierwszego pokoju")
    replay_button.pressed.connect(_restart_album_view)
    content.add_child(replay_button)

    var saved_reward: Dictionary = ProgressStoreScript.load_reward()
    if str(saved_reward.get("status", "")).begins_with("pending"):
        reward_status.text = str(saved_reward.get("message", "Sprawdź skrzynkę i potwierdź nagrodę."))
        reward_claim_button.disabled = true

func _submit_reward_claim() -> void:
    if reward_client == null:
        reward_status.text = "Sygnał jest chwilowo niedostępny. Ukończenie pozostało zapisane lokalnie."
        return
    var email: String = reward_email.text.strip_edges()
    if not _looks_like_email(email):
        reward_status.text = "Podaj poprawny adres e-mail."
        return
    var city_slug: String = _slugify_city(reward_city.text)
    if reward_marketing.button_pressed and city_slug.is_empty():
        reward_status.text = "Przy zapisie do Sygnału podaj swoje miasto."
        return
    var reward_config: Dictionary = index_document.get("reward", {})
    reward_claim_button.disabled = true
    reward_status.text = "Łączę ukończenie z nagrodą…"
    reward_client.claim_reward(
        email,
        city_slug,
        reward_marketing.button_pressed,
        str(reward_config.get("policy_version", "virya-signal-2026-08")),
    )

func _looks_like_email(value: String) -> bool:
    var at: int = value.find("@")
    var dot: int = value.rfind(".")
    return at > 0 and dot > at + 1 and dot < value.length() - 1 and value.length() <= 254

func _slugify_city(value: String) -> String:
    var slug: String = value.strip_edges().to_lower()
    var replacements: Dictionary = {
        "ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n",
        "ó": "o", "ś": "s", "ż": "z", "ź": "z",
    }
    for source in replacements.keys():
        slug = slug.replace(str(source), str(replacements[source]))
    var output: String = ""
    var previous_dash: bool = false
    for index in range(slug.length()):
        var code: int = slug.unicode_at(index)
        var allowed: bool = (code >= 97 and code <= 122) or (code >= 48 and code <= 57)
        if allowed:
            output += String.chr(code)
            previous_dash = false
        elif not previous_dash and not output.is_empty():
            output += "-"
            previous_dash = true
    return output.trim_suffix("-")

func _restart_album_view() -> void:
    _remove_modal(reward_panel)
    reward_panel = null
    room_layer.visible = true
    _load_room(0, false)

func _on_run_started(_run_id: String, _run_token: String, next_room_index: int) -> void:
    ProgressStoreScript.save_run(reward_client.get_run_state())
    _sync_completed_rooms_to_server(next_room_index)

func _sync_completed_rooms_to_server(next_room_index: int) -> void:
    if reward_client == null or not reward_client.has_run():
        return
    var completed_ids: Array = _array_value(album_state.get("completed_room_ids", []))
    var recorded_ids: Array = _array_value(album_state.get("server_recorded_room_ids", []))
    for index in range(next_room_index, release_entries.size()):
        var entry_value: Variant = release_entries[index]
        if not entry_value is Dictionary:
            continue
        var room_id: String = str(entry_value.get("id", ""))
        if completed_ids.has(room_id) and not recorded_ids.has(room_id):
            var elapsed_by_room_value: Variant = album_state.get("room_elapsed_ms", {})
            var elapsed_by_room: Dictionary = elapsed_by_room_value if elapsed_by_room_value is Dictionary else {}
            var elapsed_ms: int = maxi(0, int(elapsed_by_room.get(room_id, 0)))
            if elapsed_ms <= 0:
                break
            reward_client.record_room(room_id, index, elapsed_ms)
        else:
            break

func _on_room_recorded(room_id: String, next_room_index: int) -> void:
    var recorded_ids: Array = _array_value(album_state.get("server_recorded_room_ids", []))
    if not recorded_ids.has(room_id):
        recorded_ids.append(room_id)
    album_state["server_recorded_room_ids"] = recorded_ids
    _save_album_state()
    ProgressStoreScript.save_run(reward_client.get_run_state())
    _sync_completed_rooms_to_server(next_room_index)

func _on_album_recorded() -> void:
    album_state["server_album_completed"] = true
    _save_album_state()
    ProgressStoreScript.save_run(reward_client.get_run_state())

func _on_reward_claimed(status: String, message: String) -> void:
    ProgressStoreScript.save_reward({
        "status": status,
        "message": message,
        "claimed_at_unix": int(Time.get_unix_time_from_system()),
    })
    if reward_status != null:
        reward_status.text = message
    if reward_claim_button != null:
        reward_claim_button.disabled = true

func _on_reward_request_failed(operation: String, message: String) -> void:
    if operation == "claim_reward" and reward_status != null:
        reward_status.text = message
        if reward_claim_button != null:
            reward_claim_button.disabled = false

func _toggle_mode() -> void:
    calm_mode = not calm_mode
    _apply_sensory_mode()
    _save_album_state()
    _schedule_save()

func _toggle_quiet() -> void:
    quiet_mode = not quiet_mode
    _apply_sensory_mode()
    if quiet_mode:
        progress_label.text = "Pokój został uspokojony. Nadal możesz malować."
    _save_album_state()
    _schedule_save()

func _toggle_haptics() -> void:
    haptics_enabled = not haptics_enabled
    _apply_sensory_mode()
    _save_album_state()

func _apply_sensory_mode() -> void:
    if manifest.is_empty():
        return
    var sensory_value: Variant = manifest.get("sensory", {})
    var sensory: Dictionary = sensory_value if sensory_value is Dictionary else {}
    var normalized: float = 0.0
    if room != null and is_instance_valid(room):
        normalized = float(room.get_normalized_progress())
        room.set_calm_mode(calm_mode)
    if audio_director != null:
        audio_director.set_calm_mode(calm_mode)
        audio_director.set_quiet(quiet_mode)
    if haptics != null:
        haptics.set_calm_mode(calm_mode)
        haptics.set_enabled(haptics_enabled and not quiet_mode)

    mode_button.text = "Spokojny" if calm_mode else "Pełny"
    quiet_button.text = "Przywróć" if quiet_mode else "Uspokój"
    haptics_button.text = "Haptyka ✓" if haptics_enabled else "Haptyka —"

    if completion_announced or quiet_mode:
        snow_material.set_shader_parameter("intensity", 0.0)
    else:
        var base_snow: float = float(sensory.get("visual_snow_calm", 0.022)) if calm_mode else float(sensory.get("visual_snow_full", 0.055))
        snow_material.set_shader_parameter("intensity", base_snow * (1.0 - normalized * 0.72))
    snow_material.set_shader_parameter("motion", 0.10 if calm_mode else 0.28)

func _update_global_snow(normalized: float) -> void:
    if quiet_mode or completion_announced:
        snow_material.set_shader_parameter("intensity", 0.0)
        return
    var sensory: Dictionary = manifest.get("sensory", {})
    var base_snow: float = float(sensory.get("visual_snow_calm", 0.022)) if calm_mode else float(sensory.get("visual_snow_full", 0.055))
    snow_material.set_shader_parameter("intensity", base_snow * (1.0 - clampf(normalized, 0.0, 1.0) * 0.72))

func _reset_room() -> void:
    if room == null:
        return
    var release_id: String = str(manifest.get("release_id", ""))
    ProgressStoreScript.clear_release(release_id)
    var completed_ids: Array = _array_value(album_state.get("completed_room_ids", []))
    completed_ids.erase(release_id)
    album_state["completed_room_ids"] = completed_ids
    completion_announced = false
    _remove_modal(completion_panel)
    completion_panel = null
    room.reset_room()
    room.set_interaction_enabled(true)
    current_coverage = 0.0
    room_started_ms = Time.get_ticks_msec()
    discovery_label.text = "0/%d ślady · odkrywaj obraz spod śniegu" % _collectible_total()
    progress_label.text = "0% obrazu odsłonięte · maluj bez pośpiechu"
    if audio_director != null:
        audio_director.set_progress(0.0, 0)
        audio_director.reset_release_excerpt()
    _apply_sensory_mode()
    _save_album_state()

func _schedule_save() -> void:
    if restoring_progress or save_timer == null:
        return
    save_timer.start()

func _save_progress() -> void:
    if room == null or manifest.is_empty():
        return
    var release_id: String = str(manifest.get("release_id", ""))
    var elapsed_by_room_value: Variant = album_state.get("room_elapsed_ms", {})
    var elapsed_by_room: Dictionary = elapsed_by_room_value if elapsed_by_room_value is Dictionary else {}
    ProgressStoreScript.save_release(release_id, {
        "completed": completion_announced,
        "elapsed_ms": maxi(0, int(elapsed_by_room.get(release_id, 0))),
        "room": room.export_state(),
    })

func _save_album_state() -> void:
    album_state["current_room_index"] = current_room_index
    album_state["calm_mode"] = calm_mode
    album_state["quiet_mode"] = quiet_mode
    album_state["haptics_enabled"] = haptics_enabled
    ProgressStoreScript.save_album(album_state)

func _array_value(value: Variant) -> Array:
    return value.duplicate(true) if value is Array else []

func _modal_panel(size_value: Vector2) -> PanelContainer:
    var panel: PanelContainer = PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel", _panel_style(PRIVATE_PANEL_COLOR, 28))
    add_child(panel)
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.offset_left = -size_value.x * 0.5
    panel.offset_top = -size_value.y * 0.5
    panel.offset_right = size_value.x * 0.5
    panel.offset_bottom = size_value.y * 0.5
    return panel

func _modal_heading(text: String) -> Label:
    var label: Label = Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 27)
    label.add_theme_color_override("font_color", Color("eef6ff"))
    return label

func _modal_text(text: String) -> Label:
    var label: Label = Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 15)
    label.add_theme_color_override("font_color", Color("bed2ed"))
    return label

func _panel_style(color: Color, radius: int) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    style.content_margin_left = 17.0
    style.content_margin_right = 17.0
    style.content_margin_top = 14.0
    style.content_margin_bottom = 14.0
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = Color("72afff35")
    return style

func _make_button(text: String) -> Button:
    var button: Button = Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(0.0, 46.0)
    button.add_theme_font_size_override("font_size", 12)
    button.add_theme_color_override("font_color", Color("e7f2ff"))
    button.add_theme_stylebox_override("normal", _panel_style(Color("18243aeb"), 14))
    button.add_theme_stylebox_override("hover", _panel_style(Color("223655f4"), 14))
    button.add_theme_stylebox_override("pressed", _panel_style(Color("0e1728f4"), 14))
    return button

func _remove_modal(panel: Control) -> void:
    if panel != null and is_instance_valid(panel):
        panel.queue_free()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        _save_progress()
        _save_album_state()

func _show_fatal_error(message: String) -> void:
    var label: Label = Label.new()
    label.text = message
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 22)
    add_child(label)
    label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
