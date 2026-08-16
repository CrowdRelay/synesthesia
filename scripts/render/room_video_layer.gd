extends Control

const POST_PROCESS_SHADER_PATH: String = "res://shaders/room_video_postprocess.gdshader"
const VIDEO_PATHS: Dictionary = {
    # Room motion is fully procedural. Keep only the authored finale clip;
    # dropping low-alpha room Theora layers removes decoder hitches and ~11.7 MiB
    # from the Web PCK without reducing interactive/living-world feedback.
    "finale": "res://assets/video/finale.ogv",
}
const PROCEDURAL_LIVING_STYLES: Array[String] = [
    "uncertainty", "party", "unmasked", "calling", "seed", "hybrid",
    "technophobia", "invaluable", "ashes", "waves", "rise",
]
# Procedural-living rooms must not repaint old props over the V5 authored scene.
const PROFILE_INDEX: Dictionary = {
    "uncertainty": 0, "party": 1, "unmasked": 2, "calling": 3,
    "seed": 4, "hybrid": 5, "technophobia": 6, "invaluable": 7,
    "ashes": 8, "waves": 9, "rise": 10, "finale": 11,
}

var _player: VideoStreamPlayer
var _material: ShaderMaterial
var _style: String = "uncertainty"
var _video_path: String = ""
var _cinematic: bool = false
var _reduced_motion: bool = false
var _quiet_visuals: bool = false
var _calm_mode: bool = true
var _runtime_scale: float = 1.0
var _entry_elapsed: float = 0.0
var _max_alpha: float = 1.0
var _fade_tween: Tween

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = true
    visible = false
    set_process(false)

func _ensure_player() -> bool:
    if _player != null:
        return true
    if _style != "finale" or not ResourceLoader.exists(POST_PROCESS_SHADER_PATH):
        return false
    var shader_resource: Resource = load(POST_PROCESS_SHADER_PATH)
    if not (shader_resource is Shader):
        push_warning("Finale video shader unavailable")
        return false
    _player = VideoStreamPlayer.new()
    _player.name = "CinematicVideo"
    _player.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _player.expand = true
    _player.loop = true
    _player.autoplay = false
    _player.buffering_msec = 220
    _player.volume_db = -80.0
    add_child(_player)
    _player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _material = ShaderMaterial.new()
    _material.shader = shader_resource as Shader
    _player.material = _material
    return true

func configure(style: String, reduced_motion: bool, quiet_visuals: bool, calm_mode: bool) -> void:
    _style = style
    _video_path = str(VIDEO_PATHS.get(_style, ""))
    _reduced_motion = reduced_motion
    _quiet_visuals = quiet_visuals
    _calm_mode = calm_mode
    if _style == "finale" and _ensure_player():
        _material.set_shader_parameter("profile", int(PROFILE_INDEX.get(_style, 0)))
        _sync_effect_strength()

func set_cinematic(value: bool, instant: bool = false) -> void:
    _cinematic = value
    if value and not _reduced_motion:
        _start_video(instant)
    else:
        _stop_video(true)

func set_reduced_motion(value: bool) -> void:
    _reduced_motion = value
    _sync_effect_strength()
    if value:
        _stop_video(true)
    elif _cinematic:
        _start_video(false)

func set_quiet_visuals(value: bool) -> void:
    _quiet_visuals = value
    _sync_effect_strength()

func set_calm_mode(value: bool) -> void:
    _calm_mode = value
    _sync_effect_strength()

func set_runtime_scale(value: float) -> void:
    var previous := _runtime_scale
    _runtime_scale = clampf(value, 0.55, 1.0)
    _sync_effect_strength()
    # Room motion is procedural and does not allocate a decoder. The finale is
    # the only authored video, and may stay enabled at every quality tier.
    if _style != "finale":
        _stop_video(true)
    elif _cinematic and previous < 0.72 and _runtime_scale >= 0.72 and not _reduced_motion:
        _start_video(false)

func set_max_alpha(value: float) -> void:
    _max_alpha = clampf(value, 0.65, 1.0)
    if _player != null and visible:
        _player.modulate.a = minf(_player.modulate.a, _v2_target_alpha())

func shutdown() -> void:
    _cinematic = false
    _stop_video(true)

func has_stream_loaded() -> bool:
    return _player != null and _player.stream != null


func _v2_target_alpha() -> float:
    return minf(_max_alpha, 0.78 if not _quiet_visuals else 0.42)

func _start_video(instant: bool) -> void:
    # Every gameplay room owns motion procedurally and ships no legacy clip.
    if _style in PROCEDURAL_LIVING_STYLES:
        return
    if _video_path.is_empty() or not _ensure_player():
        return
    if _player.stream == null:
        # Ogg Theora is a runtime file-backed VideoStream in Godot 4.x.
        # Constructing VideoStreamTheora explicitly avoids relying on the
        # importer/ResourceLoader path for the raw .ogv file.
        if not FileAccess.file_exists(_video_path):
            push_warning("Cinematic video file missing: %s" % _video_path)
            return
        var theora := VideoStreamTheora.new()
        theora.file = _video_path
        _player.stream = theora
    if _fade_tween != null and _fade_tween.is_valid():
        _fade_tween.kill()
    visible = true
    set_process(true)
    _entry_elapsed = 1.0 if instant else 0.0
    _material.set_shader_parameter("entry_strength", 0.0 if instant else 1.0)
    var target_alpha := _v2_target_alpha()
    _player.modulate.a = target_alpha if instant else 0.0
    _player.play()
    # Some backends need one process tick after assigning a file-backed
    # VideoStreamTheora before playback reports as active. Retry once without
    # keeping another stream resident.
    call_deferred("_ensure_playback_started")
    if not instant:
        _fade_tween = create_tween()
        _fade_tween.set_trans(Tween.TRANS_SINE)
        _fade_tween.set_ease(Tween.EASE_OUT)
        _fade_tween.tween_property(_player, "modulate:a", target_alpha, 0.34)


func _ensure_playback_started() -> void:
    if not _cinematic or _player == null or _player.stream == null:
        return
    if not _player.is_playing():
        _player.play()

func _stop_video(unload: bool) -> void:
    if _fade_tween != null and _fade_tween.is_valid():
        _fade_tween.kill()
    _fade_tween = null
    if _player != null:
        _player.stop()
        _player.modulate.a = 0.0
        if unload:
            _player.stream = null
    visible = false
    set_process(false)
    _entry_elapsed = 0.0
    if _material != null:
        _material.set_shader_parameter("entry_strength", 0.0)

func _sync_effect_strength() -> void:
    if _material == null:
        return
    var base: float = 0.68 if _calm_mode else 0.92
    base *= lerpf(0.72, 1.0, _runtime_scale)
    _material.set_shader_parameter("effect_strength", base)
    _material.set_shader_parameter("quiet_visuals", _quiet_visuals)
    _material.set_shader_parameter("reduced_motion", _reduced_motion)

func _process(delta: float) -> void:
    if not visible or not _cinematic or _material == null:
        return
    _entry_elapsed += delta
    var entry: float = clampf(1.0 - _entry_elapsed / 0.72, 0.0, 1.0)
    _material.set_shader_parameter("entry_strength", entry)

func _exit_tree() -> void:
    _cinematic = false
    _stop_video(true)
