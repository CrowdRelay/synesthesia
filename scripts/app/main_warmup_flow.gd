extends Node

const DIAGNOSTICS_OVERLAY_PATH := "res://scripts/app/diagnostics_overlay.gd"
## Preloaded, not `load()`ed by path: `script_export_mode=2` compiles scripts to
## binary tokens, so a runtime lookup of a `.gd` path resolves in the editor and
## silently fails in an export -- which is exactly where this has to work.
const RoomAudioPackScript := preload("res://scripts/app/room_audio_pack.gd")

var app: Node
var _room_audio_pack: Node

func bind(owner: Node) -> void:
    app = owner

func warm_under_main_menu() -> void:
    # The actual menu frame is the priority. Only after it reaches the display
    # do room I/O, menu decoders and non-essential tooling start competing.
    await RenderingServer.frame_post_draw
    # Unconditional: the menu is on screen, the excerpts are not in the boot
    # pack, and whether the intro panel happens to be up says nothing about
    # whether the album will need its audio.
    _warm_room_audio_pack()
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

func _warm_room_audio_pack() -> void:
    # The outro excerpts are no longer in the boot pack, so the menu is on
    # screen before they exist. Fetch them here, under the menu, and tell the
    # soundscape once they land: its music roll happens once per run and would
    # otherwise stay quiet for having rolled too early.
    if _room_audio_pack != null and is_instance_valid(_room_audio_pack):
        return
    _room_audio_pack = RoomAudioPackScript.new()
    _room_audio_pack.name = "RoomAudioPack"
    app.add_child(_room_audio_pack)
    _room_audio_pack.mounted.connect(_on_room_audio_pack_mounted)

func _on_room_audio_pack_mounted() -> void:
    if app.menu_soundscape != null and is_instance_valid(app.menu_soundscape):
        app.menu_soundscape.notify_tracks_available()

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
