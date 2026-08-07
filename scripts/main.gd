extends Control
const AudioDirectorScript := preload("res://scripts/audio_director.gd")
const HapticsScript := preload("res://scripts/haptics.gd")
const ProgressStoreScript := preload("res://scripts/progress_store.gd")
const RewardClientScript := preload("res://scripts/reward_client.gd")
const QualityManager := preload("res://scripts/app/quality_manager.gd")
const AppHudScript := preload("res://scripts/ui/app_hud.gd")
const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const TransitionDirectorScript := preload("res://scripts/app/transition_director.gd")
const AssetPreloaderScript := preload("res://scripts/app/asset_preloader.gd")
const DiagnosticsOverlayScript := preload("res://scripts/app/diagnostics_overlay.gd")
const AdaptivePerformanceScript := preload("res://scripts/app/adaptive_performance.gd")
const ChapterCardScript := preload("res://scripts/ui/chapter_card.gd")
const CompletionCardScript := preload("res://scripts/ui/completion_card.gd")
const SettingsCardScript := preload("res://scripts/ui/settings_card.gd")
const RoomStageScript := preload("res://scripts/render/room_stage.gd")
const RELEASE_INDEX_PATH: String = "res://data/release_index.json"
const VERSION_PATH: String = "res://VERSION"
const FINAL_REVEAL_RATIO: float = 0.99
var index_document: Dictionary = {}
var release_entries: Array = []
var manifest: Dictionary = {}
var album_state: Dictionary = {}
var current_room_index: int = 0
var current_coverage: float = 0.0
var room_started_ms: int = 0
var room_elapsed_before_start_ms: int = 0
var room_timer_running: bool = false
var completion_announced: bool = false
var restoring_progress: bool = false
var transition_running: bool = false
var calm_mode: bool = true
var quiet_mode: bool = false
var quiet_visuals: bool = false
var reduced_motion: bool = false
var haptics_enabled: bool = true
var quality_profile: String = "balanced"
var music_level: float = 1.0
var noise_level: float = 1.0
var quality: Dictionary = {}
var room
var audio_director
var haptics
var reward_client
var room_layer: Control
var hud
var transition_director
var asset_preloader
var adaptive_performance
var save_timer: Timer
var settings_dirty: bool = false
var intro_panel
var completion_panel
var reward_panel: PanelContainer
var settings_panel
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
    quiet_visuals = bool(album_state.get("quiet_visuals", false))
    reduced_motion = bool(album_state.get("reduced_motion", false))
    haptics_enabled = bool(album_state.get("haptics_enabled", true))
    quality_profile = str(album_state.get("quality_profile", QualityManager.recommended()))
    music_level = clampf(float(album_state.get("music_level", 1.0)), 0.0, 1.0)
    noise_level = clampf(float(album_state.get("noise_level", 1.0)), 0.0, 1.0)
    quality = QualityManager.resolve(quality_profile)
    if not album_state.has("started_at_unix"):
        album_state["started_at_unix"] = int(Time.get_unix_time_from_system())
    if not album_state.has("total_elapsed_ms"):
        album_state["total_elapsed_ms"] = 0
    _build_application_shell()
    _configure_reward_client()
    if bool(album_state.get("album_completed", false)):
        room_layer.visible = false
        call_deferred("_show_reward_panel")
    else:
        _load_room(current_room_index, true)
func _build_application_shell() -> void:
    room_layer = Control.new()
    room_layer.name = "RoomLayer"
    add_child(room_layer)
    room_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud = AppHudScript.new()
    hud.name = "AppHud"
    add_child(hud)
    hud.settings_requested.connect(_show_settings)
    transition_director = TransitionDirectorScript.new()
    transition_director.name = "TransitionDirector"
    add_child(transition_director)
    transition_director.install(self)
    asset_preloader = AssetPreloaderScript.new()
    asset_preloader.name = "AssetPreloader"
    add_child(asset_preloader)
    adaptive_performance = AdaptivePerformanceScript.new()
    adaptive_performance.name = "AdaptivePerformance"
    add_child(adaptive_performance)
    adaptive_performance.budget_changed.connect(_on_runtime_budget_changed)
    adaptive_performance.configure(quality_profile)
    var diagnostics: Node = DiagnosticsOverlayScript.new()
    diagnostics.name = "Diagnostics"
    add_child(diagnostics)
    save_timer = Timer.new()
    save_timer.name = "ProgressSaveTimer"
    save_timer.one_shot = true
    save_timer.wait_time = 1.15
    save_timer.timeout.connect(_save_progress)
    add_child(save_timer)
func _load_json(path: String) -> Dictionary:
    if path.is_empty() or not FileAccess.file_exists(path):
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
        return "0.11.0"
    var file: FileAccess = FileAccess.open(VERSION_PATH, FileAccess.READ)
    return file.get_as_text().strip_edges() if file != null else "0.11.0"
func _configure_reward_client() -> void:
    var config_value: Variant = index_document.get("reward", {})
    if not config_value is Dictionary:
        return
    var config: Dictionary = config_value
    if not bool(config.get("enabled", false)):
        return
    reward_client = RewardClientScript.new()
    reward_client.name = "SynesthesiaRewardClient"
    add_child(reward_client)
    reward_client.configure(
        str(config.get("api_url", "")),
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
    reward_client.retry_scheduled.connect(_on_reward_retry_scheduled)
    reward_client.run_invalidated.connect(_on_reward_run_invalidated)
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
    manifest = _load_json(str(entry.get("manifest", "")))
    if manifest.is_empty():
        _show_fatal_error("Nie udało się wczytać pokoju: %s" % str(entry.get("id", "?")))
        return
    var room_value: Variant = manifest.get("room", {})
    var room_data: Dictionary = room_value if room_value is Dictionary else {}
    var collectible_value: Variant = manifest.get("collectibles", [])
    var collectible_entries: Array = collectible_value if collectible_value is Array else []
    room = _instantiate_room(room_data)
    room.name = "RoomStage"
    room_layer.add_child(room)
    room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    room.configure(room_data, collectible_entries, manifest.get("sensory", {}), quality, asset_preloader)
    if adaptive_performance != null:
        room.set_runtime_budget(float(adaptive_performance.get_scale()))
    var room_accent: Color = Color.from_string(str(room_data.get("accent_color", "#72AFFF")), Color("72afff"))
    if transition_director != null and transition_director.has_method("set_accent"):
        transition_director.set_accent(room_accent)
    room.coverage_changed.connect(_on_coverage_changed)
    room.collectible_found.connect(_on_collectible_found)
    room.paint_pulse.connect(_on_paint_pulse)
    room.special_interaction.connect(_on_special_interaction)
    room.interaction_started.connect(func() -> void: hud.set_painting(true))
    room.interaction_ended.connect(func() -> void: hud.set_painting(false))
    room.act_changed.connect(_on_act_changed)
    audio_director = AudioDirectorScript.new()
    audio_director.name = "AudioDirector"
    add_child(audio_director)
    audio_director.configure(manifest.get("sensory", {}), manifest.get("audio", {}), maxi(1, collectible_entries.size()), asset_preloader)
    audio_director.set_user_levels(music_level, noise_level)
    haptics = HapticsScript.new()
    haptics.name = "Haptics"
    add_child(haptics)
    haptics.configure(manifest.get("sensory", {}), str(room_data.get("visual_style", "paint")))

    completion_announced = false
    current_coverage = 0.0
    var elapsed_value: Variant = album_state.get("room_elapsed_ms", {})
    var elapsed: Dictionary = elapsed_value if elapsed_value is Dictionary else {}
    room_elapsed_before_start_ms = maxi(0, int(elapsed.get(str(manifest.get("release_id", "")), 0)))
    room_started_ms = Time.get_ticks_msec()
    room_timer_running = true

    hud.configure_room(
        str(manifest.get("title", "VIRYA: Synestezja")),
        str(manifest.get("subtitle", "")),
        current_room_index,
        release_entries.size(),
        float(current_room_index) / float(maxi(1, release_entries.size() - 1)),
        room_data,
    )
    _apply_sensory_mode()
    _preload_next_room()
    call_deferred("_restore_room_after_layout", show_intro)

func _instantiate_room(room_data: Dictionary):
    var scene_path: String = str(room_data.get("scene_path", ""))
    var resource: Resource = null
    if asset_preloader != null:
        resource = asset_preloader.take(scene_path)
    if resource == null and ResourceLoader.exists(scene_path):
        resource = load(scene_path)
    if resource is PackedScene:
        return (resource as PackedScene).instantiate()
    push_warning("Falling back to generic room stage: %s" % scene_path)
    return RoomStageScript.new()

func _preload_next_room() -> void:
    if asset_preloader == null or current_room_index + 1 >= release_entries.size():
        return
    var next_value: Variant = release_entries[current_room_index + 1]
    if next_value is Dictionary:
        asset_preloader.prepare(str(next_value.get("manifest", "")))

func _clear_room_runtime() -> void:
    if save_timer != null and not save_timer.is_stopped():
        save_timer.stop()
    if room != null and is_instance_valid(room):
        room.free()
    if audio_director != null and is_instance_valid(audio_director):
        audio_director.free()
    if haptics != null and is_instance_valid(haptics):
        haptics.free()
    room = null
    audio_director = null
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
        room_elapsed_before_start_ms = maxi(room_elapsed_before_start_ms, int(saved.get("elapsed_ms", 0)))

    _apply_sensory_mode()
    room.set_interaction_enabled(not completion_announced)
    if restored:
        current_coverage = float(room.get_coverage())
        var normalized: float = float(room.get_normalized_progress())
        var found: int = int(room.get_found_count())
        hud.update_reveal(normalized)
        hud.update_discovery("%d/%d ślady · pokój pamięta poprzedni dotyk" % [found, _collectible_total()])
        audio_director.set_progress(normalized, found)

    room_timer_running = not completion_announced
    if completion_announced:
        room.set_cinematic_reveal(true)
        room.set_door_open(true)
        audio_director.reveal_release_excerpt()
        call_deferred("_show_completion_panel")
    elif saved.is_empty() and show_intro:
        _show_intro()
    else:
        room.set_interaction_enabled(true)
    restoring_progress = false

func _collectible_total() -> int:
    var value: Variant = manifest.get("collectibles", [])
    if value is Array:
        return maxi(1, value.size())
    return 1

func _show_intro() -> void:
    if room == null:
        return
    room.set_interaction_enabled(false)
    intro_panel = ChapterCardScript.new()
    intro_panel.name = "ChapterCard"
    add_child(intro_panel)
    var room_value: Variant = manifest.get("room", {})
    var room_data: Dictionary = room_value if room_value is Dictionary else {}
    var art_value: Variant = room_data.get("art_direction", {})
    var art: Dictionary = art_value if art_value is Dictionary else {}
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#72AFFF")), Color("72afff"))
    intro_panel.configure(
        current_room_index,
        release_entries.size(),
        str(room_data.get("name", "Pokój")),
        str(manifest.get("intro", "Maluj bez pośpiechu. Obraz odpowie kolorem i dźwiękiem.")),
        str(art.get("caption", "VIRYA · SYNESTEZJA")),
        accent,
    )
    intro_panel.dismissed.connect(_dismiss_intro)

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
    hud.update_reveal(normalized)
    if audio_director != null:
        audio_director.set_progress(normalized, int(room.get_found_count()))
    var room_value: Variant = manifest.get("room", {})
    var room_data: Dictionary = room_value if room_value is Dictionary else {}
    var reveal_at: float = float(room_data.get("cinematic_reveal_at", FINAL_REVEAL_RATIO))
    if normalized >= reveal_at:
        _complete_current_room()
    _schedule_save()

func _on_collectible_found(item: Dictionary) -> void:
    if room == null:
        return
    var count: int = int(room.get_found_count())
    hud.update_discovery("%d/%d · %s — %s" % [count, _collectible_total(), str(item.get("title", "Ślad")), str(item.get("message", ""))])
    if haptics != null:
        haptics.discovery()
    if audio_director != null:
        audio_director.set_progress(float(room.get_normalized_progress()), count)
    _schedule_save()

func _on_act_changed(index: int, title: String) -> void:
    hud.update_act(index, title)
    if haptics != null and index > 0:
        haptics.discovery()

func _on_paint_pulse(speed_normalized: float) -> void:
    if haptics != null:
        haptics.paint_tick(speed_normalized)

func _on_special_interaction(kind: String, _index: int) -> void:
    if haptics != null:
        haptics.special(kind)
    var messages: Dictionary = {
        "balloon": "POP! Balon pękł · scena nabiera koloru",
        "mirror": "Tafla pękła · odbicie traci władzę",
        "toast": "Toast uniesiony · czerwień została w winie",
        "duel": "Przeciwnik traci kształt · własna droga zostaje",
        "mask": "Maska pękła · została twarz",
        "screen": "Ekran wygaszony · sygnał wraca do Ciebie",
        "seed": "Ziarno pękło · korzenie już pracują",
        "phoenix": "Feniks złapał oddech",
        "presence": "Druga obecność przestała być cieniem",
        "light": "Światło prowadzi dalej",
        "wave": "Horyzont przestał się cofać",
    }
    hud.update_discovery(str(messages.get(kind, "Scena odpowiedziała na gest")))

func _complete_current_room() -> void:
    if completion_announced or room == null:
        return
    var elapsed_at_completion: int = _current_room_elapsed_ms()
    completion_announced = true
    room_timer_running = false
    room.set_interaction_enabled(false)
    room.set_cinematic_reveal(true)
    room.reveal_remaining_collectibles()
    room.set_door_open(true)
    current_coverage = float(room.get_coverage())
    hud.update_reveal(1.0)
    hud.update_discovery("%d/%d ślady · drzwi są otwarte" % [_collectible_total(), _collectible_total()])
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
    var elapsed_value: Variant = album_state.get("room_elapsed_ms", {})
    var elapsed: Dictionary = elapsed_value if elapsed_value is Dictionary else {}
    elapsed[release_id] = maxi(int(elapsed.get(release_id, 0)), elapsed_at_completion)
    album_state["room_elapsed_ms"] = elapsed
    album_state["total_elapsed_ms"] = _sum_elapsed_ms(elapsed)
    room_elapsed_before_start_ms = elapsed_at_completion
    room_started_ms = Time.get_ticks_msec()
    if current_room_index == release_entries.size() - 1:
        album_state["album_completed"] = true
    _save_progress()

    if reward_client != null and reward_client.has_run():
        reward_client.record_room(release_id, current_room_index, elapsed_at_completion)
        if current_room_index == release_entries.size() - 1:
            reward_client.complete_album(int(album_state.get("total_elapsed_ms", 0)))
    call_deferred("_show_completion_panel")

func _show_completion_panel() -> void:
    await get_tree().create_timer(1.28).timeout
    if completion_panel != null or transition_running or reward_panel != null:
        return
    var room_value: Variant = manifest.get("room", {})
    var room_data: Dictionary = room_value if room_value is Dictionary else {}
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#72AFFF")), Color("72afff"))
    var next_label: String
    var next_index: int = current_room_index + 1
    if current_room_index < release_entries.size() - 1:
        var next_value: Variant = release_entries[next_index]
        var next_name: String = "kolejnego pokoju"
        if next_value is Dictionary:
            var next_manifest: Dictionary = _load_json(str(next_value.get("manifest", "")))
            var next_room_value: Variant = next_manifest.get("room", {})
            if next_room_value is Dictionary:
                next_name = str(next_room_value.get("name", next_name))
        next_label = "Dalej · %s" % next_name
    else:
        next_label = "Przejdź przez ostatnie drzwi"

    completion_panel = CompletionCardScript.new()
    completion_panel.name = "CompletionCard"
    add_child(completion_panel)
    completion_panel.configure(
        str(manifest.get("completion_title", "Pokój się otworzył")),
        str(manifest.get("completion_message", "Obraz i muzyka zostały odsłonięte.")),
        next_label,
        accent,
    )
    if current_room_index < release_entries.size() - 1:
        completion_panel.continue_requested.connect(func() -> void: _transition_to_room(next_index))
    else:
        completion_panel.continue_requested.connect(_transition_to_reward)
    completion_panel.stay_requested.connect(func() -> void:
        _remove_modal(completion_panel)
        completion_panel = null
    )

func _transition_to_room(next_index: int) -> void:
    if transition_running:
        return
    transition_running = true
    if haptics != null:
        haptics.door_open()
    _remove_modal(completion_panel)
    completion_panel = null
    await transition_director.fade_out()
    _load_room(next_index, true)
    await get_tree().process_frame
    await transition_director.fade_in()
    transition_running = false

func _transition_to_reward() -> void:
    if transition_running:
        return
    transition_running = true
    if haptics != null:
        haptics.door_open()
    _remove_modal(completion_panel)
    completion_panel = null
    await transition_director.fade_out()
    _clear_room_runtime()
    room_layer.visible = false
    await transition_director.fade_in()
    transition_running = false
    _show_reward_panel()

func _show_settings() -> void:
    if settings_panel != null:
        return
    if room != null:
        room.set_interaction_enabled(false)
    settings_panel = SettingsCardScript.new()
    settings_panel.name = "SettingsCard"
    add_child(settings_panel)
    settings_panel.configure({
        "calm": calm_mode,
        "quiet": quiet_mode,
        "quiet_visuals": quiet_visuals,
        "reduced_motion": reduced_motion,
        "haptics": haptics_enabled,
        "music": music_level,
        "noise": noise_level,
    }, str(quality.get("label", "Zbalansowana")), _read_version())
    settings_panel.close_requested.connect(_close_settings)
    settings_panel.reload_requested.connect(func() -> void:
        _close_settings()
        _reload_current_room()
    )
    settings_panel.reset_requested.connect(func() -> void:
        _close_settings()
        _confirm_reset_room()
    )
    settings_panel.calm_changed.connect(func(value: bool) -> void:
        calm_mode = value
        _apply_sensory_mode()
        _mark_settings_dirty()
    )
    settings_panel.quiet_changed.connect(func(value: bool) -> void:
        quiet_mode = value
        _apply_sensory_mode()
        _mark_settings_dirty()
    )
    settings_panel.visuals_changed.connect(func(value: bool) -> void:
        quiet_visuals = value
        _apply_sensory_mode()
        _mark_settings_dirty()
    )
    settings_panel.motion_changed.connect(func(value: bool) -> void:
        reduced_motion = value
        _apply_sensory_mode()
        _mark_settings_dirty()
    )
    settings_panel.haptics_changed.connect(func(value: bool) -> void:
        haptics_enabled = value
        _apply_sensory_mode()
        _mark_settings_dirty()
    )
    settings_panel.quality_cycle_requested.connect(func() -> void:
        quality_profile = QualityManager.next(quality_profile)
        quality = QualityManager.resolve(quality_profile)
        settings_panel.set_quality_label(str(quality.get("label", "Zbalansowana")), true)
        _mark_settings_dirty()
    )
    settings_panel.music_changed.connect(func(value: float) -> void:
        music_level = value
        _apply_audio_levels()
        _mark_settings_dirty()
    )
    settings_panel.noise_changed.connect(func(value: float) -> void:
        noise_level = value
        _apply_audio_levels()
        _mark_settings_dirty()
    )

func _close_settings() -> void:
    _remove_modal(settings_panel)
    settings_panel = null
    if settings_dirty:
        _save_album_state()
        settings_dirty = false
    if room != null and not completion_announced:
        room.set_interaction_enabled(true)

func _mark_settings_dirty() -> void:
    settings_dirty = true

func _reload_current_room() -> void:
    _save_progress()
    if adaptive_performance != null:
        adaptive_performance.configure(quality_profile)
    var index: int = current_room_index
    await transition_director.fade_out(0.28)
    _load_room(index, false)
    await get_tree().process_frame
    await transition_director.fade_in(0.28)

func _confirm_reset_room() -> void:
    var panel: PanelContainer = UIFactory.modal(self, Vector2(480.0, 290.0))
    panel.name = "ResetConfirmation"
    var content: VBoxContainer = UIFactory.modal_content(panel, 10)
    content.add_child(UIFactory.heading("Zacząć pokój od nowa?"))
    content.add_child(UIFactory.body("Zniknie tylko lokalny postęp bieżącego pokoju. Pozostałe rozdziały albumu zostają bez zmian."))
    var confirm: Button = UIFactory.button("Tak, wyczyść ten pokój")
    confirm.pressed.connect(func() -> void:
        _remove_modal(panel)
        _reset_room()
    )
    content.add_child(confirm)
    var cancel: Button = UIFactory.button("Anuluj")
    cancel.pressed.connect(func() -> void:
        _remove_modal(panel)
        if room != null and not completion_announced:
            room.set_interaction_enabled(true)
    )
    content.add_child(cancel)

func _reset_room() -> void:
    if room == null:
        return
    var release_id: String = str(manifest.get("release_id", ""))
    ProgressStoreScript.clear_release(release_id)
    var completed_ids: Array = _array_value(album_state.get("completed_room_ids", []))
    completed_ids.erase(release_id)
    album_state["completed_room_ids"] = completed_ids
    completion_announced = false
    var elapsed_value: Variant = album_state.get("room_elapsed_ms", {})
    var elapsed: Dictionary = elapsed_value if elapsed_value is Dictionary else {}
    elapsed[release_id] = 0
    album_state["room_elapsed_ms"] = elapsed
    album_state["total_elapsed_ms"] = _sum_elapsed_ms(elapsed)
    room_elapsed_before_start_ms = 0
    room_timer_running = true
    _remove_modal(completion_panel)
    completion_panel = null
    room.reset_room()
    room.set_interaction_enabled(true)
    current_coverage = 0.0
    room_started_ms = Time.get_ticks_msec()
    hud.update_reveal(0.0)
    hud.update_discovery("0/%d ślady · odkrywaj scenę spod szumu" % _collectible_total())
    if audio_director != null:
        audio_director.set_progress(0.0, 0)
        audio_director.reset_release_excerpt()
    _apply_sensory_mode()
    _save_album_state()

func _apply_sensory_mode() -> void:
    if room != null and is_instance_valid(room):
        room.set_calm_mode(calm_mode)
        room.set_reduced_motion(reduced_motion)
        room.set_quiet_visuals(quiet_visuals)
    if audio_director != null:
        audio_director.set_calm_mode(calm_mode)
        audio_director.set_quiet(quiet_mode)
        audio_director.set_user_levels(music_level, noise_level)
    if haptics != null:
        haptics.set_calm_mode(calm_mode)
        haptics.set_enabled(haptics_enabled and not quiet_mode)

func _apply_audio_levels() -> void:
    if audio_director != null:
        audio_director.set_user_levels(music_level, noise_level)

func _on_runtime_budget_changed(scale: float, _reason: String) -> void:
    if room != null and is_instance_valid(room):
        room.set_runtime_budget(scale)

func _schedule_save() -> void:
    if not restoring_progress and save_timer != null:
        save_timer.start()

func _save_progress() -> void:
    if room == null or manifest.is_empty():
        return
    var release_id: String = str(manifest.get("release_id", ""))
    var elapsed_value: Variant = album_state.get("room_elapsed_ms", {})
    var elapsed: Dictionary = elapsed_value if elapsed_value is Dictionary else {}
    var elapsed_ms: int = _current_room_elapsed_ms()
    elapsed[release_id] = maxi(int(elapsed.get(release_id, 0)), elapsed_ms)
    album_state["room_elapsed_ms"] = elapsed
    album_state["total_elapsed_ms"] = _sum_elapsed_ms(elapsed)
    _populate_settings_state()
    ProgressStoreScript.save_checkpoint(release_id, {
        "completed": completion_announced,
        "elapsed_ms": elapsed_ms,
        "room": room.export_state(),
    }, album_state)

func _populate_settings_state() -> void:
    album_state["current_room_index"] = current_room_index
    album_state["calm_mode"] = calm_mode
    album_state["quiet_mode"] = quiet_mode
    album_state["quiet_visuals"] = quiet_visuals
    album_state["reduced_motion"] = reduced_motion
    album_state["haptics_enabled"] = haptics_enabled
    album_state["quality_profile"] = quality_profile
    album_state["music_level"] = music_level
    album_state["noise_level"] = noise_level

func _save_album_state() -> void:
    _populate_settings_state()
    ProgressStoreScript.save_album(album_state)

func _show_reward_panel() -> void:
    if reward_panel != null:
        return
    hud.show_final()
    reward_panel = UIFactory.modal(self, Vector2(510.0, 720.0))
    var content: VBoxContainer = UIFactory.modal_content(reward_panel, 9)
    content.add_child(UIFactory.heading("Twój Sygnał dotarł"))
    content.add_child(UIFactory.body("Ukończyłeś cały album. Po potwierdzeniu e-maila otrzymujesz jedną płytę VIRYA na nasz koszt. Dane wysyłkowe podasz dopiero w bezpiecznym formularzu z wiadomości."))
    reward_email = LineEdit.new()
    reward_email.placeholder_text = "E-mail do potwierdzenia nagrody"
    reward_email.custom_minimum_size = Vector2(0.0, 46.0)
    content.add_child(reward_email)
    reward_city = LineEdit.new()
    reward_city.placeholder_text = "Miasto Sygnału, np. Wrocław"
    reward_city.custom_minimum_size = Vector2(0.0, 46.0)
    content.add_child(reward_city)
    reward_marketing = CheckBox.new()
    reward_marketing.text = "Chcę otrzymywać informacje od VIRYA"
    content.add_child(reward_marketing)
    var note: Label = UIFactory.body("Zgoda marketingowa jest dobrowolna i oddzielona od odbioru płyty.")
    note.add_theme_font_size_override("font_size", 11)
    content.add_child(note)
    reward_status = UIFactory.body("")
    reward_status.add_theme_color_override("font_color", Color("82bfff"))
    content.add_child(reward_status)
    reward_claim_button = UIFactory.button("Odbierz płytę")
    reward_claim_button.pressed.connect(_submit_reward_claim)
    reward_claim_button.disabled = not bool(album_state.get("server_album_completed", false))
    content.add_child(reward_claim_button)
    if reward_claim_button.disabled:
        reward_status.text = "Synchronizuję ukończenie z Sygnałem. Postęp jest bezpieczny lokalnie."
    var replay: Button = UIFactory.button("Wróć do pierwszego pokoju")
    replay.pressed.connect(_restart_album_view)
    content.add_child(replay)
    var saved_reward: Dictionary = ProgressStoreScript.load_reward()
    if str(saved_reward.get("status", "")).begins_with("pending"):
        reward_status.text = str(saved_reward.get("message", "Sprawdź skrzynkę i potwierdź nagrodę."))
        reward_claim_button.disabled = true

func _submit_reward_claim() -> void:
    if reward_client == null:
        reward_status.text = "Sygnał jest chwilowo niedostępny. Ukończenie pozostało zapisane lokalnie."
        return
    if not bool(album_state.get("server_album_completed", false)):
        reward_status.text = "Najpierw kończę synchronizację jedenastu pokojów."
        reward_claim_button.disabled = true
        _sync_completed_rooms_to_server(int(reward_client.get_run_state().get("next_room_index", 0)))
        return
    var email: String = reward_email.text.strip_edges()
    if not _looks_like_email(email):
        reward_status.text = "Podaj poprawny adres e-mail."
        return
    var city_slug: String = _slugify_city(reward_city.text)
    if reward_marketing.button_pressed and city_slug.is_empty():
        reward_status.text = "Przy zapisie do Sygnału podaj swoje miasto."
        return
    var config_value: Variant = index_document.get("reward", {})
    var config: Dictionary = config_value if config_value is Dictionary else {}
    reward_claim_button.disabled = true
    reward_status.text = "Łączę ukończenie z nagrodą…"
    reward_client.claim_reward(email, city_slug, reward_marketing.button_pressed, str(config.get("policy_version", "virya-signal-2026-08")))

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
    if next_room_index >= release_entries.size():
        if bool(album_state.get("album_completed", false)) and not bool(album_state.get("server_album_completed", false)):
            reward_client.complete_album(int(album_state.get("total_elapsed_ms", 0)))
        return
    for index in range(next_room_index, release_entries.size()):
        var entry_value: Variant = release_entries[index]
        if not entry_value is Dictionary:
            continue
        var room_id_value: String = str(entry_value.get("id", ""))
        if completed_ids.has(room_id_value) and not recorded_ids.has(room_id_value):
            var elapsed_value: Variant = album_state.get("room_elapsed_ms", {})
            var elapsed: Dictionary = elapsed_value if elapsed_value is Dictionary else {}
            var elapsed_ms: int = maxi(0, int(elapsed.get(room_id_value, 0)))
            if elapsed_ms <= 0:
                break
            reward_client.record_room(room_id_value, index, elapsed_ms)
        else:
            break

func _on_room_recorded(room_id_value: String, next_room_index: int) -> void:
    var recorded_ids: Array = _array_value(album_state.get("server_recorded_room_ids", []))
    if not recorded_ids.has(room_id_value):
        recorded_ids.append(room_id_value)
    album_state["server_recorded_room_ids"] = recorded_ids
    _save_album_state()
    ProgressStoreScript.save_run(reward_client.get_run_state())
    _sync_completed_rooms_to_server(next_room_index)

func _on_album_recorded() -> void:
    album_state["server_album_completed"] = true
    _save_album_state()
    ProgressStoreScript.save_run(reward_client.get_run_state())
    if reward_status != null:
        reward_status.text = "Ukończenie potwierdzone. Możesz odebrać płytę."
    if reward_claim_button != null:
        reward_claim_button.disabled = false

func _on_reward_claimed(status: String, message: String) -> void:
    ProgressStoreScript.save_reward({"status": status, "message": message, "claimed_at_unix": int(Time.get_unix_time_from_system())})
    if reward_status != null:
        reward_status.text = message
    if reward_claim_button != null:
        reward_claim_button.disabled = true

func _on_reward_request_failed(operation: String, message: String) -> void:
    if operation == "claim_reward" and reward_status != null:
        reward_status.text = message
        if reward_claim_button != null:
            reward_claim_button.disabled = false
    else:
        hud.update_discovery("Postęp jest bezpieczny lokalnie · synchronizacja wróci później")

func _on_reward_retry_scheduled(operation: String, attempt: int) -> void:
    var text_value: String = "Ponawiam połączenie z Sygnałem · próba %d/3" % attempt
    if operation == "claim_reward" and reward_status != null:
        reward_status.text = text_value
    else:
        hud.update_discovery(text_value)

func _on_reward_run_invalidated() -> void:
    ProgressStoreScript.clear_run()
    album_state["server_recorded_room_ids"] = []
    album_state["server_album_completed"] = false
    _save_album_state()
    if reward_status != null:
        reward_status.text = "Odnawiam bezpieczne połączenie z Sygnałem…"
    if reward_claim_button != null:
        reward_claim_button.disabled = true

func _looks_like_email(value: String) -> bool:
    var at: int = value.find("@")
    var dot: int = value.rfind(".")
    return at > 0 and dot > at + 1 and dot < value.length() - 1 and value.length() <= 254

func _slugify_city(value: String) -> String:
    var slug: String = value.strip_edges().to_lower()
    var replacements: Dictionary = {"ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n", "ó": "o", "ś": "s", "ż": "z", "ź": "z"}
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

func _array_value(value: Variant) -> Array:
    return value.duplicate(true) if value is Array else []

func _current_room_elapsed_ms() -> int:
    if room_started_ms <= 0 or not room_timer_running:
        return room_elapsed_before_start_ms
    return room_elapsed_before_start_ms + maxi(0, Time.get_ticks_msec() - room_started_ms)

func _sum_elapsed_ms(elapsed: Dictionary) -> int:
    var total: int = 0
    for value in elapsed.values():
        total += maxi(0, int(value))
    return total

func _remove_modal(panel: Control) -> void:
    if panel != null and is_instance_valid(panel):
        panel.queue_free()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"ui_cancel") and _handle_back_request():
        get_viewport().set_input_as_handled()

func _handle_back_request() -> bool:
    if settings_panel != null:
        _close_settings()
        return true
    if intro_panel != null:
        _dismiss_intro()
        return true
    if completion_panel != null:
        _remove_modal(completion_panel)
        completion_panel = null
        return true
    if reward_panel != null:
        return true
    if room != null and is_instance_valid(room):
        _show_settings()
        return true
    return false

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _handle_back_request()
        return
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        if room != null and is_instance_valid(room):
            _save_progress()
        else:
            _save_album_state()

func _show_fatal_error(message: String) -> void:
    var label: Label = Label.new()
    label.text = message
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 21)
    add_child(label)
    label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
