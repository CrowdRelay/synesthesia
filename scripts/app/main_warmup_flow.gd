extends Node

const DIAGNOSTICS_OVERLAY_PATH := "res://scripts/app/diagnostics_overlay.gd"

var app: Node

func bind(owner: Node) -> void:
    app = owner

func warm_under_main_menu() -> void:
    # The actual menu frame is the priority. Only after it reaches the display
    # do room I/O, menu decoders and non-essential tooling start competing.
    await RenderingServer.frame_post_draw
    if app.experience_intro_panel == null or not is_instance_valid(app.experience_intro_panel):
        return
    if app.room == null and app.asset_preloader != null:
        app.asset_preloader.prepare(str((app.release_entries[app.current_room_index] as Dictionary).get("manifest", "")))
        app.asset_preloader.prime_runtime_support()
    app.SoundscapeRuntime.begin_menu_soundscape(app.menu_soundscape, app.music_level, app.noise_level, app.quiet_mode)
    # Reward state restoration is local-only and can be paid under the menu.
    # start_run() remains explicitly gated on pressing Start.
    app._configure_reward_client()
    call_deferred("install_diagnostics")

func install_diagnostics() -> void:
    if not OS.has_feature("editor") or not OS.get_cmdline_args().has("--synesthesia-debug"):
        return
    if app.get_node_or_null("Diagnostics") != null or not ResourceLoader.exists(DIAGNOSTICS_OVERLAY_PATH):
        return
    var diagnostics_script: Script = load(DIAGNOSTICS_OVERLAY_PATH) as Script
    if diagnostics_script == null:
        return
    var diagnostics: Node = diagnostics_script.new()
    diagnostics.name = "Diagnostics"
    app.add_child(diagnostics)
    diagnostics.configure(app.adaptive_performance, app.asset_preloader)
