extends Node

const DoorTransitionLayerScript := preload("res://scripts/app/door_transition_layer.gd")
const DOOR_CLOSE_SFX: String = "res://assets/audio/sfx/door-close.wav"
const DOOR_OPEN_SFX: String = "res://assets/audio/sfx/door-open.wav"
const TELEPORT_SFX: String = "res://assets/audio/sfx/teleport-suck.wav"

var overlay: ColorRect
var accent_line: ColorRect
var door_layer
var transition_audio: AudioStreamPlayer
var _accent: Color = Color("72afff")
var _next_accent: Color = Color("72afff")
var _reduced_motion: bool = false

func install(host: Control) -> void:
    overlay = ColorRect.new()
    overlay.name = "TransitionOverlay"
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
    overlay.color = Color(0.008, 0.012, 0.022, 0.0)
    overlay.visible = false
    overlay.z_index = 930
    host.add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    accent_line = ColorRect.new()
    accent_line.name = "TransitionSignal"
    accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    accent_line.color = Color(_accent, 0.0)
    overlay.add_child(accent_line)
    accent_line.anchor_left = 0.10
    accent_line.anchor_right = 0.90
    accent_line.anchor_top = 0.5
    accent_line.anchor_bottom = 0.5
    accent_line.offset_top = -1.0
    accent_line.offset_bottom = 1.0

    door_layer = DoorTransitionLayerScript.new()
    door_layer.name = "SupersonicDoorTransition"
    host.add_child(door_layer)
    door_layer.z_index = 940
    door_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    door_layer.set_accents(_accent, _next_accent)

    transition_audio = AudioStreamPlayer.new()
    transition_audio.name = "DoorTransitionAudio"
    transition_audio.bus = &"Room"
    transition_audio.volume_db = -13.0
    add_child(transition_audio)

func _play_transition_sfx(path: String, volume_db: float = -13.0) -> void:
    if transition_audio == null or path.is_empty() or not ResourceLoader.exists(path):
        return
    var resource: Resource = load(path)
    if not resource is AudioStream:
        return
    transition_audio.stop()
    transition_audio.stream = resource as AudioStream
    transition_audio.volume_db = volume_db
    transition_audio.play()

func set_accent(value: Color) -> void:
    _accent = value
    if accent_line != null:
        accent_line.color = Color(_accent, accent_line.color.a)
    if door_layer != null:
        door_layer.set_accents(_accent, _next_accent)

func set_next_accent(value: Color) -> void:
    _next_accent = value
    if door_layer != null:
        door_layer.set_accents(_accent, _next_accent)

func set_reduced_motion(value: bool) -> void:
    _reduced_motion = value
    if door_layer != null:
        door_layer.set_reduced_motion(value)

func set_memory_count(value: int) -> void:
    if door_layer != null and door_layer.has_method("set_memory_count"):
        door_layer.set_memory_count(value)

func force_idle() -> void:
    if overlay != null:
        overlay.visible = false
        overlay.color = Color(overlay.color, 0.0)
        overlay.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
    if accent_line != null:
        accent_line.color = Color(_accent, 0.0)
    if door_layer != null:
        door_layer.reset()
    if transition_audio != null:
        transition_audio.stop()

func fade_out(duration: float = 0.34) -> void:
    overlay.visible = true
    overlay.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    overlay.color = Color(overlay.color, 0.0)
    accent_line.color = Color(_accent, 0.0)
    accent_line.scale = Vector2(0.08, 1.0)
    accent_line.pivot_offset = Vector2(accent_line.size.x * 0.5, 1.0)
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(overlay, "color:a", 1.0, duration)
    tween.tween_property(accent_line, "color:a", 0.72, duration * 0.56)
    tween.tween_property(accent_line, "scale:x", 1.0, duration * 0.72)
    await tween.finished

func fade_in(duration: float = 0.34) -> void:
    overlay.visible = true
    overlay.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    overlay.color = Color(overlay.color, 1.0)
    accent_line.color = Color(_accent, 0.72)
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(overlay, "color:a", 0.0, duration)
    tween.tween_property(accent_line, "color:a", 0.0, duration * 0.68)
    tween.tween_property(accent_line, "scale:x", 0.12, duration * 0.72)
    await tween.finished
    overlay.visible = false
    overlay.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED

func travel_out() -> void:
    if door_layer == null:
        await fade_out(0.30)
        return

    # A real hinged door opens first. We then accelerate the camera through the
    # threshold. No room/artwork scale or panel wipe is used here.
    overlay.visible = false
    overlay.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
    door_layer.visible = true
    door_layer.set_accents(_accent, _next_accent)
    door_layer.set_door_open_mix(0.0)
    door_layer.set_approach_mix(0.0)
    door_layer.set_warp_mix(0.0)
    door_layer.set_flash_mix(0.0)

    _play_transition_sfx(DOOR_OPEN_SFX, -13.0)
    var door_duration: float = 0.18 if _reduced_motion else 0.34
    var threshold_tween: Tween = create_tween()
    threshold_tween.set_parallel(true)
    threshold_tween.set_trans(Tween.TRANS_CUBIC)
    threshold_tween.set_ease(Tween.EASE_OUT)
    threshold_tween.tween_method(Callable(door_layer, "set_door_open_mix"), 0.0, 1.0, door_duration)
    threshold_tween.tween_method(Callable(door_layer, "set_approach_mix"), 0.0, 0.18, door_duration)
    await threshold_tween.finished

    _play_transition_sfx(TELEPORT_SFX, -10.5)
    var boost_duration: float = 0.11 if _reduced_motion else 0.27
    var boost_tween: Tween = create_tween()
    boost_tween.set_parallel(true)
    boost_tween.set_trans(Tween.TRANS_EXPO)
    boost_tween.set_ease(Tween.EASE_IN)
    boost_tween.tween_method(Callable(door_layer, "set_approach_mix"), 0.18, 1.0, boost_duration)
    boost_tween.tween_method(Callable(door_layer, "set_warp_mix"), 0.0, 1.0, boost_duration)
    await boost_tween.finished

    var snap_duration: float = 0.035 if _reduced_motion else 0.065
    var snap_tween: Tween = create_tween()
    snap_tween.set_trans(Tween.TRANS_EXPO)
    snap_tween.set_ease(Tween.EASE_IN)
    snap_tween.tween_method(Callable(door_layer, "set_flash_mix"), 0.0, 1.0, snap_duration)
    await snap_tween.finished

func travel_in() -> void:
    if door_layer == null:
        await fade_in(0.30)
        return

    # The room has been swapped while the warp fills the viewport. We burst out
    # of the same open doorway and decelerate into the new room.
    door_layer.visible = true
    door_layer.set_door_open_mix(1.0)
    door_layer.set_approach_mix(1.0)
    door_layer.set_warp_mix(1.0)
    door_layer.set_flash_mix(1.0)

    var snap_release: float = 0.05 if _reduced_motion else 0.095
    var flash_tween: Tween = create_tween()
    flash_tween.set_trans(Tween.TRANS_EXPO)
    flash_tween.set_ease(Tween.EASE_OUT)
    flash_tween.tween_method(Callable(door_layer, "set_flash_mix"), 1.0, 0.0, snap_release)
    await flash_tween.finished

    var brake_duration: float = 0.12 if _reduced_motion else 0.25
    var brake_tween: Tween = create_tween()
    brake_tween.set_parallel(true)
    brake_tween.set_trans(Tween.TRANS_EXPO)
    brake_tween.set_ease(Tween.EASE_OUT)
    brake_tween.tween_method(Callable(door_layer, "set_warp_mix"), 1.0, 0.18, brake_duration)
    brake_tween.tween_method(Callable(door_layer, "set_approach_mix"), 1.0, 0.32, brake_duration)
    await brake_tween.finished

    var settle_duration: float = 0.10 if _reduced_motion else 0.24
    var settle_tween: Tween = create_tween()
    settle_tween.set_parallel(true)
    settle_tween.set_trans(Tween.TRANS_QUINT)
    settle_tween.set_ease(Tween.EASE_OUT)
    settle_tween.tween_method(Callable(door_layer, "set_warp_mix"), 0.18, 0.0, settle_duration)
    settle_tween.tween_method(Callable(door_layer, "set_approach_mix"), 0.32, 0.0, settle_duration)
    await settle_tween.finished

    # A quiet close behind the listener sells the physical doorway while the
    # visible door is already out of the camera's path.
    _play_transition_sfx(DOOR_CLOSE_SFX, -19.0)
    door_layer.reset()
