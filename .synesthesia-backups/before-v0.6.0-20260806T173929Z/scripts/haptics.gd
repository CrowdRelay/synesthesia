extends Node
class_name SynesthesiaHaptics

var enabled: bool = true
var calm_mode: bool = true
var calm_amplitude: float = 0.16
var full_amplitude: float = 0.34
var _last_tick_ms: int = 0

func configure(sensory: Dictionary) -> void:
    calm_amplitude = float(sensory.get("haptics_calm", 0.16))
    full_amplitude = float(sensory.get("haptics_full", 0.34))

func set_calm_mode(value: bool) -> void:
    calm_mode = value

func set_enabled(value: bool) -> void:
    enabled = value

func paint_tick(speed_normalized: float) -> void:
    if not enabled:
        return
    var now := Time.get_ticks_msec()
    var interval := 110 if calm_mode else 72
    if now - _last_tick_ms < interval:
        return
    _last_tick_ms = now
    var base := calm_amplitude if calm_mode else full_amplitude
    var amplitude := clampf(base * lerpf(0.65, 1.0, speed_normalized), 0.05, 0.55)
    Input.vibrate_handheld(9 if calm_mode else 13, amplitude)

func discovery() -> void:
    if not enabled:
        return
    var base := calm_amplitude if calm_mode else full_amplitude
    Input.vibrate_handheld(32 if calm_mode else 48, clampf(base * 1.35, 0.08, 0.62))
