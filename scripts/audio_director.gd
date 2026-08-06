extends Node
class_name SynesthesiaAudioDirector

const MIX_RATE := 22050
const TAU_F := TAU

var _player: AudioStreamPlayer
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

func _ready() -> void:
    _player = AudioStreamPlayer.new()
    _player.name = "ProceduralSoundscape"
    _player.bus = &"Room"
    _player.volume_db = -7.0
    add_child(_player)

    var generator := AudioStreamGenerator.new()
    generator.mix_rate = MIX_RATE
    generator.buffer_length = 0.35
    _player.stream = generator
    _player.play()
    _playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
    set_process(true)

func configure(sensory: Dictionary, collectible_total: int = 1) -> void:
    _collectible_total = maxi(1, collectible_total)
    if _player != null:
        _player.volume_db = float(sensory.get("safe_audio_ceiling_db", -7.0))

func set_progress(coverage: float, found_count: int) -> void:
    _coverage_target = clampf(coverage, 0.0, 1.0)
    _collectibles_target = clampf(float(found_count) / float(_collectible_total), 0.0, 1.0)

func set_quiet(value: bool) -> void:
    _quiet_target = 1.0 if value else 0.0

func set_calm_mode(value: bool) -> void:
    _calm_mode = value

func _process(_delta: float) -> void:
    if _playback == null:
        return
    var frames := _playback.get_frames_available()
    for _frame in range(frames):
        _push_audio_frame()

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
