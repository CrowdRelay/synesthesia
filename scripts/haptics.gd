extends Node
class_name SynesthesiaHaptics

var enabled: bool = true
var calm_mode: bool = true
var calm_amplitude: float = 0.16
var full_amplitude: float = 0.34
var room_style: String = "paint"
var _last_tick_ms: int = 0
var _last_tech_buzz_ms: int = 0
var _pulse_generation: int = 0

func configure(sensory: Dictionary, style: String = "paint") -> void:
    _pulse_generation += 1
    calm_amplitude = float(sensory.get("haptics_calm", 0.16))
    full_amplitude = float(sensory.get("haptics_full", 0.34))
    room_style = style

func set_calm_mode(value: bool) -> void:
    calm_mode = value

func set_enabled(value: bool) -> void:
    if enabled == value:
        return
    enabled = value
    _pulse_generation += 1

func paint_tick(speed_normalized: float) -> void:
    if not enabled:
        return
    var now: int = Time.get_ticks_msec()
    var interval: int = 118 if calm_mode else 74
    if room_style == "technophobia":
        interval = 145 if calm_mode else 92
    if now - _last_tick_ms < interval:
        return
    _last_tick_ms = now
    var base: float = calm_amplitude if calm_mode else full_amplitude
    var amplitude: float = clampf(base * lerpf(0.62, 1.0, speed_normalized), 0.05, 0.55)
    var duration: int = 8 if calm_mode else 13
    if room_style == "waves" or room_style == "uncertainty":
        duration = 7 if calm_mode else 10
    Input.vibrate_handheld(duration, amplitude)

    if room_style == "technophobia" and now - _last_tech_buzz_ms > (720 if calm_mode else 430):
        _last_tech_buzz_ms = now
        _pulse_after_delay(24, 5 if calm_mode else 8, clampf(amplitude * 0.58, 0.04, 0.28))

func discovery() -> void:
    if not enabled:
        return
    var base: float = calm_amplitude if calm_mode else full_amplitude
    Input.vibrate_handheld(30 if calm_mode else 46, clampf(base * 1.28, 0.08, 0.62))

func special(kind: String) -> void:
    if not enabled:
        return
    var base: float = calm_amplitude if calm_mode else full_amplitude
    match kind:
        "balloon":
            Input.vibrate_handheld(18 if calm_mode else 27, clampf(base * 1.34, 0.10, 0.62))
            _pulse_after_delay(34, 7, clampf(base * 0.55, 0.05, 0.25))
        "mirror":
            Input.vibrate_handheld(12, clampf(base * 1.5, 0.10, 0.66))
            _pulse_after_delay(28, 21 if calm_mode else 30, clampf(base * 1.05, 0.08, 0.55))
        "toast":
            Input.vibrate_handheld(24 if calm_mode else 34, clampf(base * 0.9, 0.08, 0.42))
            _pulse_after_delay(95, 17, clampf(base * 0.62, 0.06, 0.30))
        "duel":
            Input.vibrate_handheld(42 if calm_mode else 58, clampf(base * 1.38, 0.12, 0.68))
            _pulse_after_delay(115, 26 if calm_mode else 38, clampf(base * 1.05, 0.10, 0.58))
        _:
            discovery()

func cinematic_reveal() -> void:
    if not enabled:
        return
    var base: float = calm_amplitude if calm_mode else full_amplitude
    Input.vibrate_handheld(28 if calm_mode else 40, clampf(base * 0.92, 0.08, 0.46))
    _pulse_after_delay(90, 38 if calm_mode else 54, clampf(base * 1.28, 0.10, 0.64))
    _pulse_after_delay(205, 18 if calm_mode else 28, clampf(base * 0.72, 0.06, 0.38))

func door_open() -> void:
    if not enabled:
        return
    var base: float = calm_amplitude if calm_mode else full_amplitude
    Input.vibrate_handheld(18, clampf(base * 0.72, 0.06, 0.34))
    _pulse_after_delay(110, 45 if calm_mode else 64, clampf(base * 1.18, 0.10, 0.62))

func _pulse_after_delay(delay_ms: int, duration_ms: int, amplitude: float) -> void:
    var tree: SceneTree = get_tree()
    if tree == null:
        return
    var generation: int = _pulse_generation
    await tree.create_timer(float(delay_ms) / 1000.0).timeout
    if enabled and generation == _pulse_generation and is_inside_tree():
        Input.vibrate_handheld(duration_ms, amplitude)
