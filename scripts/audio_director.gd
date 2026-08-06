extends Node
class_name SynesthesiaAudioDirector

const MIX_RATE := 22050
const TAU_F := TAU

var _player: AudioStreamPlayer
var _release_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _time: float = 0.0
var _coverage_target: float = 0.0
var _coverage_smoothed: float = 0.0
var _collectibles_target: float = 0.0
var _collectibles_smoothed: float = 0.0
var _quiet_target: float = 0.0
var _quiet_smoothed: float = 0.0
var _calm_mode: bool = true
var _noise_seed: int = 19088743
var _noise_state: float = 0.0
var _collectible_total: int = 1
var _safe_ceiling_db: float = -7.0
var _release_volume_db: float = -12.0
var _release_available: bool = false
var _release_active: bool = false
var _release_title: String = "VIRYA"

func _ready() -> void:
    _player = AudioStreamPlayer.new()
    _player.name = "ProceduralSoundscape"
    _player.bus = &"Room"
    _player.volume_db = _safe_ceiling_db
    add_child(_player)

    var generator := AudioStreamGenerator.new()
    generator.mix_rate = MIX_RATE
    generator.buffer_length = 0.35
    _player.stream = generator
    _player.play()
    _playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback

    _release_player = AudioStreamPlayer.new()
    _release_player.name = "ReleaseExcerpt"
    _release_player.bus = &"Music"
    _release_player.volume_db = -60.0
    add_child(_release_player)
    set_process(true)

func configure(sensory: Dictionary, audio: Dictionary = {}, collectible_total: int = 1) -> void:
    _collectible_total = maxi(1, collectible_total)
    _safe_ceiling_db = float(sensory.get("safe_audio_ceiling_db", -7.0))
    _release_volume_db = minf(float(audio.get("completion_volume_db", -12.0)), -6.0)
    _release_title = str(audio.get("title", "VIRYA"))
    if _player != null:
        _player.volume_db = _safe_ceiling_db

    var excerpt_path := str(audio.get("completion_excerpt", ""))
    if excerpt_path.is_empty():
        return
    if not excerpt_path.begins_with("res://") or not FileAccess.file_exists(excerpt_path):
        push_warning("Completion excerpt is missing: %s" % excerpt_path)
        return
    var resource: Resource = load(excerpt_path)
    if resource is AudioStream:
        _release_player.stream = resource
        _release_available = true
    else:
        push_warning("Completion excerpt is not an AudioStream: %s" % excerpt_path)

func set_progress(coverage: float, found_count: int) -> void:
    _coverage_target = clampf(coverage, 0.0, 1.0)
    _collectibles_target = clampf(float(found_count) / float(_collectible_total), 0.0, 1.0)

func set_quiet(value: bool) -> void:
    _quiet_target = 1.0 if value else 0.0

func set_calm_mode(value: bool) -> void:
    _calm_mode = value

func reveal_release_excerpt() -> bool:
    if not _release_available or _release_active:
        return false
    _release_active = true
    _release_player.volume_db = -60.0
    _release_player.play()
    return true

func reset_release_excerpt() -> void:
    _release_active = false
    if _release_player != null:
        _release_player.stop()
        _release_player.volume_db = -60.0

func get_release_title() -> String:
    return _release_title

func _process(delta: float) -> void:
    if _playback != null:
        var frames: int = _playback.get_frames_available()
        for _frame in range(frames):
            _push_audio_frame()

    if _player != null:
        var procedural_target := _safe_ceiling_db - (13.0 if _release_active else 0.0)
        _player.volume_db = move_toward(_player.volume_db, procedural_target, delta * 16.0)

    if _release_player != null:
        var release_target := -60.0
        if _release_active:
            release_target = _release_volume_db - (18.0 if _quiet_target > 0.5 else 0.0)
        _release_player.volume_db = move_toward(_release_player.volume_db, release_target, delta * 18.0)
        if _release_active and not _release_player.playing:
            _release_active = false

func _push_audio_frame() -> void:
    _coverage_smoothed = lerpf(_coverage_smoothed, _coverage_target, 0.00055)
    _collectibles_smoothed = lerpf(_collectibles_smoothed, _collectibles_target, 0.0007)
    _quiet_smoothed = lerpf(_quiet_smoothed, _quiet_target, 0.0009)

    var ambient := sin(TAU_F * 55.0 * _time) * 0.060
    ambient += sin(TAU_F * 82.41 * _time + 0.7) * 0.030

    var first_layer := sin(TAU_F * 110.0 * _time + sin(_time * 0.17) * 0.18)
    first_layer *= 0.043 * smoothstep(0.04, 0.34, _coverage_smoothed)

    var second_layer := sin(TAU_F * 146.83 * _time + 1.2)
    second_layer += sin(TAU_F * 220.0 * _time + 0.2) * 0.42
    second_layer *= 0.028 * smoothstep(0.28, 0.74, _coverage_smoothed)

    var memory_layer := sin(TAU_F * 196.0 * _time + sin(_time * 0.23) * 0.3)
    memory_layer *= 0.025 * _collectibles_smoothed

    _noise_seed = int((_noise_seed * 1664525 + 1013904223) % 2147483647)
    var white := (float(_noise_seed) / 2147483647.0) * 2.0 - 1.0
    _noise_state = lerpf(_noise_state, white, 0.0035 if _calm_mode else 0.006)
    var soft_noise := _noise_state * (0.006 if _calm_mode else 0.011)
    soft_noise *= smoothstep(0.38, 0.85, _coverage_smoothed)

    var slow_breath := 0.76 + sin(TAU_F * 0.085 * _time) * 0.16
    var quiet_gain := lerpf(1.0, 0.18, _quiet_smoothed)
    var sample := (ambient + first_layer + second_layer + memory_layer + soft_noise)
    sample *= slow_breath * quiet_gain
    sample = clampf(sample, -0.22, 0.22)

    var drift := sin(_time * 0.31) * 0.08
    _playback.push_frame(Vector2(sample * (1.0 - drift), sample * (1.0 + drift)))
    _time += 1.0 / float(MIX_RATE)
