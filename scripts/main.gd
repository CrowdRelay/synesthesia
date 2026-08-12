extends Control
const AudioDirectorScript := preload("res://scripts/audio_director.gd")
const PlayerFeedbackBridgeScript := preload("res://scripts/app/player_feedback_bridge.gd")
const MainRoomFlowScript := preload("res://scripts/app/main_room_flow.gd")
const MainSettingsFlowScript := preload("res://scripts/app/main_settings_flow.gd")
const MainRewardFlowScript := preload("res://scripts/app/main_reward_flow.gd")
const FatalErrorPresenter := preload("res://scripts/app/fatal_error_presenter.gd")
const HapticsScript := preload("res://scripts/haptics.gd")
const ProgressStoreScript := preload("res://scripts/progress_store.gd")
const RewardClientScript := preload("res://scripts/reward_client.gd")
const QualityManager := preload("res://scripts/app/quality_manager.gd")
const AppHudScript := preload("res://scripts/ui/app_hud.gd")
const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const TransitionDirectorScript := preload("res://scripts/app/transition_director.gd")
const AssetPreloaderScript := preload("res://scripts/app/asset_preloader.gd")
const DIAGNOSTICS_OVERLAY_PATH: String = "res://scripts/app/diagnostics_overlay.gd"
const AdaptivePerformanceScript := preload("res://scripts/app/adaptive_performance.gd")
const NativeExperienceSurfaceScript := preload("res://scripts/app/native_experience_surface.gd")
const InteractiveUiRootScript := preload("res://scripts/app/interactive_ui_root.gd")
const MenuRuntimeGuard := preload("res://scripts/app/menu_runtime_guard.gd")
const SoundscapeRuntime := preload("res://scripts/app/soundscape_runtime.gd")
const DebugProfile := preload("res://scripts/app/debug_profile.gd")
const ReleaseReader := preload("res://scripts/app/release_reader.gd")
const ProgressMetrics := preload("res://scripts/app/progress_metrics.gd")
const GameplayTelemetryScript := preload("res://scripts/app/gameplay_telemetry.gd")
const ChapterCardScript := preload("res://scripts/ui/chapter_card.gd")
const ExperienceIntroCardScript := preload("res://scripts/ui/experience_intro_card.gd")
const AlbumModeControllerScript := preload("res://scripts/app/album_mode_controller.gd")
const EchoArchive := preload("res://scripts/app/echo_archive.gd")
const CompletionCardScript := preload("res://scripts/ui/completion_card.gd")
const SettingsCardScript := preload("res://scripts/ui/settings_card.gd")
const ConfirmCardScript := preload("res://scripts/ui/confirm_card.gd")
const EchoesFinaleBackgroundScript := preload("res://scripts/ui/echoes_finale_background.gd")
const SignalFinaleCardScript := preload("res://scripts/ui/signal_finale_card.gd")
const BootSequenceScript := preload("res://scripts/ui/boot_sequence.gd")
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
var high_readability: bool = false
var haptics_enabled: bool = true
var quality_profile: String = "balanced"
var music_level: float = 1.0
var noise_level: float = 1.0
var quality: Dictionary = {}
var room
var audio_director
var menu_soundscape
var haptics
var reward_client
var completion_context: Dictionary = {}
var experience_surface
var game_surface: Control
var ui_root: Control
var room_layer: Control
var hud
var transition_director
var asset_preloader
var adaptive_performance
var gameplay_telemetry
var save_timer: Timer
var settings_dirty: bool = false
var intro_panel
var experience_intro_panel
var completion_panel
var confirmation_panel
var reward_panel
var finale_background
var settings_panel
var album_mode_controller
var room_flow: Node
var settings_flow: Node
var reward_flow: Node
func _ready() -> void:
    DebugProfile.fit_macos_window_to_screen()
    index_document = ReleaseReader.load_json(RELEASE_INDEX_PATH)
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
    high_readability = bool(album_state.get("high_readability", false))
    haptics_enabled = bool(album_state.get("haptics_enabled", true))
    quality_profile = str(album_state.get("quality_profile", QualityManager.recommended()))
    music_level = clampf(float(album_state.get("music_level", 1.0)), 0.0, 1.0)
    noise_level = clampf(float(album_state.get("noise_level", 1.0)), 0.0, 1.0)
    quality = QualityManager.resolve(quality_profile)
    Engine.max_fps = QualityManager.frame_cap(quality_profile)
    if not album_state.has("started_at_unix"):
        album_state["started_at_unix"] = int(Time.get_unix_time_from_system())
    if not album_state.has("total_elapsed_ms"):
        album_state["total_elapsed_ms"] = 0
    if str(album_state.get("journey_id", "")).is_empty():
        album_state["journey_id"] = ProgressStoreScript.new_journey_id()
        ProgressStoreScript.save_album(album_state)
    room_flow = MainRoomFlowScript.new(); room_flow.bind(self); add_child(room_flow)
    settings_flow = MainSettingsFlowScript.new(); settings_flow.bind(self); add_child(settings_flow)
    reward_flow = MainRewardFlowScript.new(); reward_flow.bind(self); add_child(reward_flow)
    _build_application_shell()
    _configure_reward_client()
    room_layer.visible = false
    _enter_main_menu_mode()
func _build_application_shell() -> void:
    experience_surface = NativeExperienceSurfaceScript.new()
    add_child(experience_surface)
    game_surface = experience_surface.get_content_surface()
    ui_root = InteractiveUiRootScript.new()
    add_child(ui_root)
    room_layer = Control.new()
    room_layer.name = "RoomLayer"
    game_surface.add_child(room_layer)
    room_layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
    experience_surface.content_geometry_changed.connect(_apply_native_geometry)
    _apply_native_geometry()
    hud = AppHudScript.new()
    hud.name = "AppHud"
    game_surface.add_child(hud)
    hud.settings_requested.connect(_show_settings)
    transition_director = TransitionDirectorScript.new()
    transition_director.name = "TransitionDirector"
    experience_surface.add_child(transition_director)
    transition_director.install(experience_surface)
    transition_director.set_memory_count(_array_value(album_state.get("completed_room_ids", [])).size())
    album_mode_controller = AlbumModeControllerScript.new()
    add_child(album_mode_controller)
    album_mode_controller.configure(ui_root, room_layer, hud, transition_director, release_entries)
    album_mode_controller.room_requested.connect(_enter_album_mode_room)
    album_mode_controller.corridor_requested.connect(_show_album_archive)
    album_mode_controller.finale_requested.connect(_show_reward_panel)
    album_mode_controller.menu_requested.connect(_show_experience_intro)
    asset_preloader = AssetPreloaderScript.new(); asset_preloader.name = "AssetPreloader"
    add_child(asset_preloader)
    adaptive_performance = AdaptivePerformanceScript.new(); adaptive_performance.name = "AdaptivePerformance"
    add_child(adaptive_performance)
    adaptive_performance.budget_changed.connect(_on_runtime_budget_changed)
    adaptive_performance.configure(quality_profile)
    gameplay_telemetry = GameplayTelemetryScript.new(); gameplay_telemetry.name = "GameplayTelemetry"
    add_child(gameplay_telemetry)
    menu_soundscape = SoundscapeRuntime.install(self, music_level, noise_level, quiet_mode)
    if ResourceLoader.exists(DIAGNOSTICS_OVERLAY_PATH):
        var diagnostics_script: Script = load(DIAGNOSTICS_OVERLAY_PATH) as Script
        if diagnostics_script != null:
            var diagnostics: Node = diagnostics_script.new(); diagnostics.name = "Diagnostics"
            add_child(diagnostics); diagnostics.configure(adaptive_performance, asset_preloader)
    save_timer = Timer.new()
    save_timer.name = "ProgressSaveTimer"
    save_timer.one_shot = true
    save_timer.wait_time = 1.15
    save_timer.timeout.connect(_save_progress)
    add_child(save_timer)
    var boot = BootSequenceScript.new()
    boot.configure(reduced_motion)
    ui_root.attach(boot, 100)
    boot.released.connect(_show_experience_intro)
func _apply_native_geometry() -> void:
    if experience_surface == null or room_layer == null:
        return
    var art_rect: Rect2 = experience_surface.get_art_cover_rect()
    room_layer.position = art_rect.position
    room_layer.size = art_rect.size
func _show_experience_intro() -> void:
    if experience_intro_panel != null:
        return
    _enter_main_menu_mode()
    if room == null and asset_preloader != null: asset_preloader.prepare(str((release_entries[current_room_index] as Dictionary).get("manifest", "")))
    experience_intro_panel = ExperienceIntroCardScript.new()
    experience_intro_panel.name = "ExperienceMenu"
    ui_root.attach(experience_intro_panel, 20)
    var reward_value: Variant = index_document.get("reward", {})
    var reward: Dictionary = reward_value if reward_value is Dictionary else {}
    var has_progress: bool = bool(album_state.get("experience_intro_seen", false)) or current_room_index > 0 or not _array_value(album_state.get("completed_room_ids", [])).is_empty()
    experience_intro_panel.configure(
        Color("E73535"),
        has_progress,
        bool(album_state.get("album_completed", false)),
        str(reward.get("api_url", "")),
        str(reward.get("policy_version", "virya-signal-2026-08")),
        experience_surface.get_render_label() if DebugProfile.is_local_desktop_debug() else "",
    )
    experience_intro_panel.begin_requested.connect(_begin_experience)
    experience_intro_panel.new_journey_requested.connect(_confirm_reset_album)
    experience_intro_panel.settings_requested.connect(_show_settings)
    experience_intro_panel.album_mode_requested.connect(_show_album_archive)
func _show_album_archive() -> void:
    if not bool(album_state.get("album_completed", false)):
        return
    _remove_modal(experience_intro_panel)
    experience_intro_panel = null
    _remove_modal(reward_panel)
    reward_panel = null
    if room != null and is_instance_valid(room):
        _clear_room_runtime()
    album_mode_controller.show_archive(album_state, current_room_index, finale_background)
func _enter_album_mode_room(index: int) -> void:
    if transition_running:
        return
    transition_running = true
    await album_mode_controller.enter_room(index, finale_background, Callable(self, "_load_room"))
    transition_running = false
func _begin_experience() -> void:
    if transition_running:
        return
    if gameplay_telemetry != null:
        gameplay_telemetry.begin_journey(
            _array_value(album_state.get("completed_room_ids", [])).size(),
            int(album_state.get("total_elapsed_ms", 0)),
        )
    if bool(album_state.get("album_completed", false)):
        _remove_modal(experience_intro_panel)
        experience_intro_panel = null
        _show_reward_panel()
        return
    if reward_client != null: reward_client.start_run()
    transition_running = true
    if transition_director != null:
        transition_director.set_next_accent(_accent_for_release(current_room_index))
        await transition_director.travel_out()
    _remove_modal(experience_intro_panel)
    experience_intro_panel = null
    album_state["experience_intro_seen"] = true
    _save_album_state()
    if room == null and asset_preloader != null: await asset_preloader.wait_for_queued()
    if room == null: _load_room(current_room_index, false)
    _resume_room_runtime()
    await get_tree().process_frame
    if transition_director != null:
        await transition_director.travel_in()
    if completion_announced:
        call_deferred("_show_completion_panel")
    elif room != null:
        room.set_interaction_enabled(true)
    transition_running = false
func _enter_main_menu_mode() -> void:
    _remove_modal(intro_panel)
    intro_panel = null
    _remove_modal(completion_panel)
    completion_panel = null
    SoundscapeRuntime.suspend_for_menu(menu_soundscape, room_layer, room, hud, audio_director, transition_director, adaptive_performance, music_level, noise_level, quiet_mode)
func _resume_room_runtime() -> void: SoundscapeRuntime.resume_room(menu_soundscape, room_layer, hud, audio_director, adaptive_performance)
func _configure_reward_client() -> void:
    reward_flow._configure_reward_client()
func _load_room(index: int, show_intro: bool) -> void:
    room_flow._load_room(index, show_intro)
func _instantiate_room(room_data: Dictionary):
    room_flow._instantiate_room(room_data)
func _preload_next_room() -> void:
    room_flow._preload_next_room()
func _clear_room_runtime() -> void:
    room_flow._clear_room_runtime()
func _restore_room_after_layout(show_intro: bool) -> void:
    room_flow._restore_room_after_layout(show_intro)
func _collectible_total() -> int:
    return room_flow._collectible_total()
func _show_intro() -> void:
    room_flow._show_intro()
func _dismiss_intro() -> void:
    room_flow._dismiss_intro()
func _on_coverage_changed(value: float) -> void:
    room_flow._on_coverage_changed(value)
func _on_collectible_found(item: Dictionary) -> void:
    room_flow._on_collectible_found(item)
func _on_act_changed(index: int, title: String) -> void:
    room_flow._on_act_changed(index, title)
func _on_paint_pulse(speed_normalized: float) -> void:
    room_flow._on_paint_pulse(speed_normalized)
func _on_special_interaction(kind: String, index: int) -> void:
    room_flow._on_special_interaction(kind, index)
func _complete_current_room() -> void:
    room_flow._complete_current_room()
func _show_completion_panel() -> void:
    room_flow._show_completion_panel()
func _transition_to_room(next_index: int) -> void:
    room_flow._transition_to_room(next_index)
func _transition_to_reward() -> void:
    room_flow._transition_to_reward()
func _accent_for_release(index: int) -> Color:
    if index < 0 or index >= release_entries.size():
        return Color("72afff")
    return ReleaseReader.accent_for_entry(release_entries[index])
func _show_settings() -> void:
    settings_flow._show_settings()
func _close_settings() -> void:
    settings_flow._close_settings()
func _mark_settings_dirty() -> void: settings_dirty = true
func _reload_current_room() -> void:
    settings_flow._reload_current_room()
func _confirm_reset_room() -> void:
    settings_flow._confirm_reset_room()
func _reset_room() -> void:
    settings_flow._reset_room()
func _confirm_reset_album() -> void:
    settings_flow._confirm_reset_album()
func _show_confirmation(title: String, message: String, confirm_text: String, action: Callable) -> void:
    settings_flow._show_confirmation(title, message, confirm_text, action)
func _reset_album_local() -> void:
    settings_flow._reset_album_local()
func _apply_sensory_mode() -> void:
    settings_flow._apply_sensory_mode()
func _apply_audio_levels() -> void:
    settings_flow._apply_audio_levels()
func _on_runtime_budget_changed(scale: float, _reason: String) -> void:
    settings_flow._on_runtime_budget_changed(scale, _reason)
    if gameplay_telemetry != null:
        gameplay_telemetry.note_quality_scale(scale)
func _schedule_save() -> void:
    settings_flow._schedule_save()
func _save_progress() -> void:
    settings_flow._save_progress()
func _populate_settings_state() -> void:
    settings_flow._populate_settings_state()
func _save_album_state() -> void:
    settings_flow._save_album_state()
func _prepare_finale_background() -> void:
    reward_flow._prepare_finale_background()
func _show_reward_panel() -> void:
    reward_flow._show_reward_panel()
func _submit_reward_claim_values(email: String) -> void:
    reward_flow._submit_reward_claim_values(email)
func _on_run_started(_run_id: String, _run_token: String, next_room_index: int) -> void:
    reward_flow._on_run_started(_run_id, _run_token, next_room_index)
func _sync_completed_rooms_to_server(next_room_index: int) -> void:
    reward_flow._sync_completed_rooms_to_server(next_room_index)
func _on_room_recorded(room_id_value: String, next_room_index: int) -> void:
    reward_flow._on_room_recorded(room_id_value, next_room_index)
func _on_album_recorded(context: Dictionary = {}) -> void:
    reward_flow._on_album_recorded(context)
func _on_draw_entered(status: String, message: String) -> void:
    reward_flow._on_draw_entered(status, message)
func _on_reward_request_failed(operation: String, message: String) -> void:
    reward_flow._on_reward_request_failed(operation, message)
func _on_reward_retry_scheduled(operation: String, attempt: int) -> void:
    reward_flow._on_reward_retry_scheduled(operation, attempt)
func _on_reward_run_invalidated() -> void:
    reward_flow._on_reward_run_invalidated()
func _array_value(value: Variant) -> Array:
    return value.duplicate(true) if value is Array else []
func _remove_modal(panel: Control) -> void:
    if panel != null and is_instance_valid(panel):
        panel.hide(); panel.queue_free()
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"ui_cancel") and _handle_back_request():
        get_viewport().set_input_as_handled()
func _handle_back_request() -> bool:
    if album_mode_controller != null and album_mode_controller.has_archive():
        album_mode_controller.close_archive()
        _show_experience_intro()
        return true
    if album_mode_controller != null and album_mode_controller.is_listening() and room != null and is_instance_valid(room):
        _show_album_archive()
        return true
    if experience_intro_panel != null:
        return true
    if confirmation_panel != null:
        _remove_modal(confirmation_panel)
        confirmation_panel = null
        return true
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
    if what == NOTIFICATION_WM_GO_BACK_REQUEST: _handle_back_request(); return
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        if room != null and is_instance_valid(room): _save_progress()
        else: _save_album_state()
    if what == NOTIFICATION_APPLICATION_PAUSED: MenuRuntimeGuard.suspend_for_background(experience_surface, ui_root, room_layer, audio_director, adaptive_performance)
    elif what == NOTIFICATION_APPLICATION_RESUMED: MenuRuntimeGuard.resume_from_background(experience_surface, ui_root, room_layer, audio_director, adaptive_performance); reward_flow.refresh_link_context_after_resume()
func _exit_tree() -> void:
    if save_timer != null and not save_timer.is_stopped():
        save_timer.stop()
    if reward_client != null and is_instance_valid(reward_client) and reward_client.has_method("shutdown"):
        reward_client.shutdown()
    if asset_preloader != null and is_instance_valid(asset_preloader) and asset_preloader.has_method("drain"): asset_preloader.drain()
    UIFactory.release_runtime_caches()
func _show_fatal_error(message: String) -> void:
    FatalErrorPresenter.show(self, message)
