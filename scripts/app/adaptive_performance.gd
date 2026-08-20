extends Node

signal budget_changed(scale: float, reason: String)

# Runtime quality is intentionally coarse-grained. We sample enough frames to
# distinguish a real sustained hitch from a single GC/asset transition spike,
# then hold the new tier for a cooldown window so quality cannot oscillate.
const SAMPLE_SECONDS: float = 0.75
const LOW_FPS: int = 47
const RECOVERY_FPS: int = 56
const BAD_FRAME_EMA_MS: float = 21.5
const RECOVERY_FRAME_EMA_MS: float = 18.5
const HITCH_FRAME_MS: float = 30.0
const HITCH_RATIO_BAD: float = 0.10
const HITCH_RATIO_RECOVERY: float = 0.025
const MEMORY_SOFT_MB: float = 230.0
const MEMORY_GROWTH_SOFT_MB: float = 96.0
const DOWNSHIFT_SAMPLES: int = 2
const RECOVERY_SAMPLES: int = 6
const CHANGE_COOLDOWN_SECONDS: float = 4.5
const EMA_ALPHA: float = 0.10
const RESUME_DELTA_SECONDS: float = 0.35

var profile_name: String = "balanced"
var _scale: float = 1.0
var _accumulator: float = 0.0
var _cooldown: float = 0.0
var _bad_samples: int = 0
var _good_samples: int = 0
var _warmup_samples: int = 2
var _sample_frames: int = 0
var _sample_hitches: int = 0
var _frame_ema_ms: float = 16.67
var _frame_peak_ms: float = 0.0
var _last_fps: int = 0
var _last_memory_mb: float = 0.0
var _memory_baseline_mb: float = 0.0
var _last_hitch_ratio: float = 0.0
var _last_reason: String = "boot"
var _suspended: bool = false

func configure(profile: String) -> void:
    profile_name = profile
    _reset_sampler()
    _memory_baseline_mb = _memory_mb()
    match profile_name:
        "battery":
            _set_scale(0.68, "battery-profile", false)
        "high":
            _set_scale(1.0, "high-profile", false)
        _:
            _set_scale(1.0, "balanced-start", false)
    _apply_streaming_budget()
    set_process(profile_name == "balanced" and not _suspended)

func set_suspended(value: bool) -> void:
    if _suspended == value:
        return
    _suspended = value
    set_process(profile_name == "balanced" and not value)
    if not value:
        _reset_after_resume()

func get_scale() -> float:
    return _scale

func snapshot() -> Dictionary:
    return {
        "profile": profile_name,
        "scale": _scale,
        "fps": _last_fps,
        "frame_ema_ms": _frame_ema_ms,
        "frame_peak_ms": _frame_peak_ms,
        "hitch_ratio": _last_hitch_ratio,
        "memory_mb": _last_memory_mb,
        "memory_baseline_mb": _memory_baseline_mb,
        "cooldown_seconds": _cooldown,
        "reason": _last_reason,
    }

func _process(delta: float) -> void:
    # Browsers and mobile OSes can suspend the process for seconds. Treat the
    # first resume delta as a lifecycle discontinuity, not a performance hitch;
    # otherwise one background/foreground cycle poisons the EMA and quality
    # recovery for several seconds.
    if delta >= RESUME_DELTA_SECONDS:
        _reset_after_resume()
        return
    var frame_ms: float = clampf(delta * 1000.0, 0.0, 250.0)
    _frame_ema_ms = lerpf(_frame_ema_ms, frame_ms, EMA_ALPHA)
    _frame_peak_ms = maxf(_frame_peak_ms, frame_ms)
    _sample_frames += 1
    if frame_ms >= HITCH_FRAME_MS:
        _sample_hitches += 1

    _accumulator += delta
    _cooldown = maxf(0.0, _cooldown - delta)
    if _accumulator < SAMPLE_SECONDS:
        return
    _accumulator = 0.0

    _last_fps = Engine.get_frames_per_second()
    _last_memory_mb = _memory_mb()
    _last_hitch_ratio = float(_sample_hitches) / float(maxi(1, _sample_frames))
    var sample_peak_ms: float = _frame_peak_ms
    _sample_frames = 0
    _sample_hitches = 0
    _frame_peak_ms = 0.0

    if _warmup_samples > 0:
        _warmup_samples -= 1
        return

    var memory_limit_mb: float = maxf(MEMORY_SOFT_MB, _memory_baseline_mb + MEMORY_GROWTH_SOFT_MB)
    var memory_pressure: bool = _last_memory_mb > memory_limit_mb and _last_memory_mb > 1.0
    var frame_pressure: bool = (
        (_last_fps > 0 and _last_fps < LOW_FPS)
        or _frame_ema_ms > BAD_FRAME_EMA_MS
        or _last_hitch_ratio >= HITCH_RATIO_BAD
    )
    var healthy: bool = (
        _last_fps >= RECOVERY_FPS
        and _frame_ema_ms <= RECOVERY_FRAME_EMA_MS
        and _last_hitch_ratio <= HITCH_RATIO_RECOVERY
        and not memory_pressure
    )

    if frame_pressure or memory_pressure:
        _bad_samples += 1
        _good_samples = 0
    elif healthy:
        _good_samples += 1
        _bad_samples = maxi(0, _bad_samples - 1)
    else:
        _bad_samples = maxi(0, _bad_samples - 1)
        _good_samples = maxi(0, _good_samples - 1)

    if _cooldown > 0.0:
        return
    if _bad_samples >= DOWNSHIFT_SAMPLES:
        _bad_samples = 0
        _good_samples = 0
        if _scale > 0.86:
            _set_scale(0.84, _pressure_reason(memory_pressure, sample_peak_ms))
        elif _scale > 0.70:
            _set_scale(0.68, _pressure_reason(memory_pressure, sample_peak_ms))
    elif _good_samples >= RECOVERY_SAMPLES:
        _good_samples = 0
        if _scale < 0.80:
            _set_scale(0.84, "stable-recovery")
        elif _scale < 0.99:
            _set_scale(1.0, "stable-recovery")

func _pressure_reason(memory_pressure: bool, sample_peak_ms: float) -> String:
    if memory_pressure:
        return "memory-pressure"
    if _last_hitch_ratio >= HITCH_RATIO_BAD or sample_peak_ms >= HITCH_FRAME_MS * 1.6:
        return "frame-hitches"
    return "frame-pressure"

func _memory_mb() -> float:
    return float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0

func _reset_after_resume() -> void:
    _accumulator = 0.0
    _sample_frames = 0
    _sample_hitches = 0
    _frame_ema_ms = 16.67
    _frame_peak_ms = 0.0
    _last_hitch_ratio = 0.0
    _bad_samples = 0
    _good_samples = 0
    _warmup_samples = maxi(_warmup_samples, 1)
    _last_reason = "resume-warmup"

func _reset_sampler() -> void:
    _accumulator = 0.0
    _cooldown = 0.0
    _bad_samples = 0
    _good_samples = 0
    _warmup_samples = 2
    _sample_frames = 0
    _sample_hitches = 0
    _frame_ema_ms = 16.67
    _frame_peak_ms = 0.0
    _last_hitch_ratio = 0.0
    _last_fps = 0
    _last_memory_mb = _memory_mb()

func _set_scale(value: float, reason: String, start_cooldown: bool = true) -> void:
    var next_scale: float = clampf(value, 0.60, 1.0)
    _last_reason = reason
    if is_equal_approx(next_scale, _scale):
        _apply_streaming_budget()
        return
    _scale = next_scale
    if start_cooldown:
        _cooldown = CHANGE_COOLDOWN_SECONDS
    _apply_streaming_budget()
    budget_changed.emit(_scale, reason)

func _apply_streaming_budget() -> void:
    var parent := get_parent()
    if parent == null:
        return
    var preloader := parent.get_node_or_null("AssetPreloader")
    if preloader != null and preloader.has_method("set_runtime_budget"):
        preloader.set_runtime_budget(_scale)
