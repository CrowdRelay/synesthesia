extends Node

## Installs gameplay-only subsystems after the main menu is already usable.
## All script graphs are requested in parallel, but AssetPreloader wins the
## installation race so the first room starts warming before HUD/telemetry/etc.

const HUD_PATH := "res://scripts/ui/app_hud.gd"
const TRANSITION_PATH := "res://scripts/app/transition_director.gd"
const ASSET_PRELOADER_PATH := "res://scripts/app/asset_preloader.gd"
const ADAPTIVE_PERFORMANCE_PATH := "res://scripts/app/adaptive_performance.gd"
const GAMEPLAY_TELEMETRY_PATH := "res://scripts/app/gameplay_telemetry.gd"
const ALBUM_MODE_PATH := "res://scripts/app/album_mode_controller.gd"
const MAIN_ROOM_FLOW_PATH := "res://scripts/app/main_room_flow.gd"
const RUNTIME_SCRIPT_LOAD_TIMEOUT_MS := 1_500
const RUNTIME_INSTALL_WAIT_TIMEOUT_MS := 10_000
const RUNTIME_PATHS: Array[String] = [
    ASSET_PRELOADER_PATH,
    HUD_PATH,
    TRANSITION_PATH,
    ALBUM_MODE_PATH,
    ADAPTIVE_PERFORMANCE_PATH,
    GAMEPLAY_TELEMETRY_PATH,
]

var app: Node
var _requested: Dictionary = {}
var _scripts: Dictionary = {}
var _installing: bool = false
var _ready: bool = false
var _failed: bool = false

func bind(owner: Node) -> void:
    app = owner

func prime_under_menu() -> void:
    # The actual menu frame wins over every gameplay subsystem.
    await RenderingServer.frame_post_draw
    await ensure_ready()

func ensure_ready() -> bool:
    if _ready:
        return true
    if _failed:
        return false
    if _installing:
        var install_deadline_ms: int = Time.get_ticks_msec() + RUNTIME_INSTALL_WAIT_TIMEOUT_MS
        while _installing and Time.get_ticks_msec() < install_deadline_ms:
            await get_tree().process_frame
        if _installing:
            push_error("Runtime installation timed out while waiting for the active installer")
            return false
        return _ready
    _installing = true
    _request_runtime_graphs()

    # Critical path: create the bounded preloader first, then immediately warm
    # the current room and orchestration script while other scripts parse.
    var preloader_script: Script = await _script(ASSET_PRELOADER_PATH)
    if preloader_script == null:
        return _finish(false)
    if app.asset_preloader == null:
        app.asset_preloader = preloader_script.new()
        app.asset_preloader.name = "AssetPreloader"
        app.add_child(app.asset_preloader)
    _prime_first_room()

    var hud_script: Script = await _script(HUD_PATH)
    var transition_script: Script = await _script(TRANSITION_PATH)
    var album_script: Script = await _script(ALBUM_MODE_PATH)
    var adaptive_script: Script = await _script(ADAPTIVE_PERFORMANCE_PATH)
    var telemetry_script: Script = await _script(GAMEPLAY_TELEMETRY_PATH)
    if hud_script == null or transition_script == null or album_script == null or adaptive_script == null or telemetry_script == null:
        return _finish(false)

    if app.hud == null:
        app.hud = hud_script.new()
        app.hud.name = "AppHud"
        app.game_surface.add_child(app.hud)
        app.hud.settings_requested.connect(app._show_settings)
        app.hud.suspend_for_menu()
    if app.transition_director == null:
        app.transition_director = transition_script.new()
        app.transition_director.name = "TransitionDirector"
        app.experience_surface.add_child(app.transition_director)
        app.transition_director.install(app.experience_surface)
        app.transition_director.set_replay_mode(bool(app.album_state.get("replay_mode", false)))
        app.transition_director.set_memory_count(app._array_value(app.album_state.get("completed_room_ids", [])).size())
    if app.album_mode_controller == null:
        app.album_mode_controller = album_script.new()
        app.add_child(app.album_mode_controller)
        app.album_mode_controller.configure(app.ui_root, app.room_layer, app.hud, app.transition_director, app.release_entries)
        app.album_mode_controller.room_requested.connect(app._enter_album_mode_room)
        app.album_mode_controller.corridor_requested.connect(app._show_album_archive)
        app.album_mode_controller.finale_requested.connect(app._show_reward_panel)
        app.album_mode_controller.menu_requested.connect(app._show_experience_intro)
    if app.adaptive_performance == null:
        app.adaptive_performance = adaptive_script.new()
        app.adaptive_performance.name = "AdaptivePerformance"
        app.add_child(app.adaptive_performance)
        app.adaptive_performance.budget_changed.connect(app._on_runtime_budget_changed)
        app.adaptive_performance.configure(app.quality_profile)
        app.adaptive_performance.set_suspended(true)
    if app.gameplay_telemetry == null:
        app.gameplay_telemetry = telemetry_script.new()
        app.gameplay_telemetry.name = "GameplayTelemetry"
        app.add_child(app.gameplay_telemetry)
    return _finish(true)

func _request_runtime_graphs() -> void:
    for path in RUNTIME_PATHS:
        if _requested.has(path) or not ResourceLoader.exists(path):
            continue
        _requested[path] = ResourceLoader.load_threaded_request(path, "", false, ResourceLoader.CACHE_MODE_REUSE) == OK

func _script(path: String) -> Script:
    if _scripts.has(path):
        return _scripts[path] as Script
    if not ResourceLoader.exists(path):
        return null
    if not bool(_requested.get(path, false)):
        var fallback: Resource = load(path)
        if fallback is Script:
            _scripts[path] = fallback
            return fallback as Script
        return null
    var deadline_ms: int = Time.get_ticks_msec() + RUNTIME_SCRIPT_LOAD_TIMEOUT_MS
    var status: int = int(ResourceLoader.load_threaded_get_status(path))
    while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and Time.get_ticks_msec() < deadline_ms:
        await get_tree().process_frame
        status = int(ResourceLoader.load_threaded_get_status(path))
    if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
        push_error("Runtime script load timed out: %s" % path)
        return null
    if status == ResourceLoader.THREAD_LOAD_LOADED:
        var resource: Resource = ResourceLoader.load_threaded_get(path)
        if resource is Script:
            _scripts[path] = resource
            return resource as Script
    return null

func _prime_first_room() -> void:
    if app.asset_preloader == null or app.release_entries.is_empty():
        return
    app.asset_preloader.queue_critical(MAIN_ROOM_FLOW_PATH)
    if app.room != null:
        return
    var entry_value: Variant = app.release_entries[app.current_room_index]
    if not entry_value is Dictionary:
        return
    app.asset_preloader.prepare(str((entry_value as Dictionary).get("manifest", "")))
    app.asset_preloader.prime_runtime_support()

func _finish(ok: bool) -> bool:
    _ready = ok
    _failed = not ok
    _installing = false
    return ok
