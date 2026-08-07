extends Node

signal budget_changed(scale: float, reason: String)

const SAMPLE_SECONDS: float = 1.5
const LOW_FPS: int = 47
const RECOVERY_FPS: int = 56
const MEMORY_SOFT_MB: float = 230.0

var profile_name: String = "balanced"
var _scale: float = 1.0
var _accumulator: float = 0.0
var _bad_samples: int = 0
var _good_samples: int = 0
var _warmup_samples: int = 2

func configure(profile: String) -> void:
    profile_name = profile
    _bad_samples = 0
    _good_samples = 0
    _warmup_samples = 2
    match profile_name:
        "battery":
            _set_scale(0.68, "battery-profile")
        "high":
            _set_scale(1.0, "high-profile")
        _:
            _set_scale(1.0, "balanced-start")
    set_process(profile_name == "balanced")

func get_scale() -> float:
    return _scale

func _process(delta: float) -> void:
    _accumulator += delta
    if _accumulator < SAMPLE_SECONDS:
        return
    _accumulator = 0.0
    if _warmup_samples > 0:
        _warmup_samples -= 1
        return

    var fps: int = Engine.get_frames_per_second()
    var memory_mb: float = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
    var memory_pressure: bool = memory_mb > MEMORY_SOFT_MB and memory_mb > 1.0
    if fps > 0 and (fps < LOW_FPS or memory_pressure):
        _bad_samples += 1
        _good_samples = 0
    elif fps >= RECOVERY_FPS and not memory_pressure:
        _good_samples += 1
        _bad_samples = maxi(0, _bad_samples - 1)
    else:
        _bad_samples = maxi(0, _bad_samples - 1)
        _good_samples = maxi(0, _good_samples - 1)

    if _bad_samples >= 2:
        _bad_samples = 0
        _good_samples = 0
        if _scale > 0.86:
            _set_scale(0.84, "frame-pressure")
        elif _scale > 0.70:
            _set_scale(0.68, "sustained-pressure")
    elif _good_samples >= 4:
        _good_samples = 0
        if _scale < 0.80:
            _set_scale(0.84, "recovery")
        elif _scale < 0.99:
            _set_scale(1.0, "recovery")

func _set_scale(value: float, reason: String) -> void:
    var next_scale: float = clampf(value, 0.60, 1.0)
    if is_equal_approx(next_scale, _scale):
        return
    _scale = next_scale
    budget_changed.emit(_scale, reason)
