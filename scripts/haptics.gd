extends Node

var enabled: bool = true
var calm_mode: bool = true
var calm_amplitude: float = 0.16
var full_amplitude: float = 0.34
var room_style: String = "paint"
var _last_tick_ms: int = 0
var _last_tech_buzz_ms: int = 0
var _last_motion_ms: int = 0
var _pulse_generation: int = 0
var _semantic_quiet_until_ms: int = 0

func configure(sensory: Dictionary, style: String = "paint") -> void:
    _pulse_generation += 1
    calm_amplitude = clampf(float(sensory.get("haptics_calm", 0.16)), 0.04, 0.42)
    full_amplitude = clampf(float(sensory.get("haptics_full", 0.34)), 0.08, 0.72)
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
    if now < _semantic_quiet_until_ms:
        return
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

func motion(kind: String, strength: float) -> void:
    if not enabled:
        return
    var now := Time.get_ticks_msec()
    if now < _semantic_quiet_until_ms:
        return
    var amount := clampf(strength, 0.0, 1.0)
    var interval := 76 if calm_mode else 52
    if kind in ["heartbeat", "breath", "resonance"]:
        interval = 118 if calm_mode else 84
    if now - _last_motion_ms < interval:
        return
    _last_motion_ms = now
    var base := calm_amplitude if calm_mode else full_amplitude
    var scale := 0.24
    var duration := 5 if calm_mode else 7
    match kind:
        "tension": scale = 0.28 + amount * 0.38
        "glass_pressure": scale = 0.22 + amount * 0.28
        "heartbeat": scale = 0.30 + amount * 0.22; duration = 8
        "membrane": scale = 0.24 + amount * 0.32
        "resonance": scale = 0.20 + amount * 0.26; duration = 7
        "ember_flow": scale = 0.18 + amount * 0.24
        "breath": scale = 0.14 + amount * 0.20; duration = 6
        "frequency": scale = 0.22 + amount * 0.30
        "lift": scale = 0.20 + amount * 0.28
        "peel": scale = 0.26 + amount * 0.34
        _: scale = 0.18 + amount * 0.22
    Input.vibrate_handheld(duration, clampf(base * scale, 0.025, 0.26))

func discovery() -> void:
    if not enabled:
        return
    _begin_semantic_pattern(64)
    var base: float = calm_amplitude if calm_mode else full_amplitude
    Input.vibrate_handheld(30 if calm_mode else 46, clampf(base * 1.28, 0.08, 0.62))

func confirmation(strength: float = 0.6) -> void:
    if not enabled:
        return
    if Time.get_ticks_msec() < _semantic_quiet_until_ms:
        return
    var amount: float = clampf(strength, 0.2, 1.0)
    var base: float = calm_amplitude if calm_mode else full_amplitude
    var duration: int = roundi(lerpf(7.0, 16.0 if calm_mode else 22.0, amount))
    Input.vibrate_handheld(duration, clampf(base * lerpf(0.48, 0.92, amount), 0.04, 0.42))

func special(kind: String, index: int = 0) -> void:
    if not enabled:
        return
    # Every authored pattern owns its delayed tail. A newer semantic event
    # cancels the previous tail and briefly suppresses paint/motion ticks, so
    # rapid room interactions stay crisp instead of becoming one long buzz.
    _begin_semantic_pattern(118)
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
        "pour":
            Input.vibrate_handheld(10 if calm_mode else 15, clampf(base * 0.42, 0.04, 0.22))
            _pulse_after_delay(56, 8, clampf(base * 0.34, 0.04, 0.18))
        "duel":
            Input.vibrate_handheld(42 if calm_mode else 58, clampf(base * 1.38, 0.12, 0.68))
            _pulse_after_delay(115, 26 if calm_mode else 38, clampf(base * 1.05, 0.10, 0.58))
        "mask":
            Input.vibrate_handheld(14, clampf(base * 1.22, 0.08, 0.54))
            _pulse_after_delay(42, 11, clampf(base * 0.72, 0.06, 0.34))
        "screen":
            Input.vibrate_handheld(9, clampf(base * 0.82, 0.06, 0.38))
            _pulse_after_delay(31, 9, clampf(base * 0.66, 0.05, 0.30))
            _pulse_after_delay(70, 16, clampf(base * 1.04, 0.08, 0.48))
        "cable_grab":
            Input.vibrate_handheld(6, clampf(base * 0.30, 0.03, 0.16))
        "cable_tension":
            var bucket: int = clampi(index % 10, 0, 4)
            var tension: float = float(bucket) / 4.0
            var duration: int = roundi(lerpf(4.0, 9.0 if calm_mode else 13.0, tension))
            var amplitude: float = clampf(base * lerpf(0.18, 0.72, pow(tension, 1.25)), 0.025, 0.30)
            Input.vibrate_handheld(duration, amplitude)
            if bucket >= 3:
                _pulse_after_delay(24, 4 if calm_mode else 6, clampf(amplitude * 0.48, 0.025, 0.16))
        "cable_snap":
            Input.vibrate_handheld(7, clampf(base * 0.34, 0.03, 0.18))
        "cable_unplug":
            Input.vibrate_handheld(16 if calm_mode else 24, clampf(base * 0.88, 0.07, 0.44))
            _pulse_after_delay(46, 8, clampf(base * 0.42, 0.04, 0.22))
        "breaker":
            Input.vibrate_handheld(24 if calm_mode else 34, clampf(base * 1.02, 0.08, 0.50))
            _pulse_after_delay(76, 14, clampf(base * 0.66, 0.05, 0.32))
        "signal_lock":
            Input.vibrate_handheld(18 if calm_mode else 26, clampf(base * 0.72, 0.06, 0.36))
            _pulse_after_delay(86, 34 if calm_mode else 46, clampf(base * 1.16, 0.09, 0.58))
        "echo_complete":
            Input.vibrate_handheld(14 if calm_mode else 20, clampf(base * 0.56, 0.05, 0.30))
            _pulse_after_delay(66, 18, clampf(base * 0.82, 0.07, 0.42))
            _pulse_after_delay(132, 30 if calm_mode else 42, clampf(base * 1.12, 0.09, 0.56))
        "signal_breach":
            Input.vibrate_handheld(7, clampf(base * 0.34, 0.04, 0.20))
            _pulse_after_delay(54, 11, clampf(base * 0.62, 0.06, 0.32))
            _pulse_after_delay(122, 6, clampf(base * 0.42, 0.04, 0.22))
            _pulse_after_delay(188, 28 if calm_mode else 38, clampf(base * 1.02, 0.08, 0.52))
        "resonance_chain":
            var peak := index >= 6
            Input.vibrate_handheld(9 if calm_mode else 14, clampf(base * (0.54 if peak else 0.38), 0.04, 0.32))
            _pulse_after_delay(52, 18 if peak else 11, clampf(base * (0.96 if peak else 0.62), 0.06, 0.48))
        "seed":
            Input.vibrate_handheld(24 if calm_mode else 34, clampf(base * 0.88, 0.07, 0.42))
            _pulse_after_delay(84, 18, clampf(base * 0.70, 0.06, 0.34))
        "root":
            Input.vibrate_handheld(18 if calm_mode else 26, clampf(base * 0.56, 0.05, 0.30))
            _pulse_after_delay(72, 14, clampf(base * 0.48, 0.04, 0.26))
            _pulse_after_delay(132, 18, clampf(base * 0.62, 0.05, 0.32))
        "aim":
            Input.vibrate_handheld(7, clampf(base * 0.34, 0.03, 0.18))
        "ember":
            Input.vibrate_handheld(14 if calm_mode else 21, clampf(base * 0.48, 0.04, 0.26))
            _pulse_after_delay(58, 20, clampf(base * 0.58, 0.05, 0.30))
        "phoenix":
            Input.vibrate_handheld(32 if calm_mode else 46, clampf(base * 1.08, 0.09, 0.54))
            _pulse_after_delay(92, 44 if calm_mode else 58, clampf(base * 1.34, 0.11, 0.66))
        "presence":
            Input.vibrate_handheld(20 if calm_mode else 28, clampf(base * 0.66, 0.05, 0.32))
            _pulse_after_delay(128, 20, clampf(base * 0.52, 0.05, 0.26))
        "light":
            Input.vibrate_handheld(26 if calm_mode else 38, clampf(base * 0.84, 0.07, 0.40))
            _pulse_after_delay(72, 34, clampf(base * 1.02, 0.08, 0.50))
        "wave":
            Input.vibrate_handheld(16 if calm_mode else 24, clampf(base * 0.68, 0.05, 0.34))
            _pulse_after_delay(60, 28 if calm_mode else 40, clampf(base * 0.88, 0.07, 0.44))
        _:
            discovery()

func cinematic_reveal() -> void:
    if not enabled:
        return
    _begin_semantic_pattern(255)
    var base: float = calm_amplitude if calm_mode else full_amplitude
    Input.vibrate_handheld(28 if calm_mode else 40, clampf(base * 0.92, 0.08, 0.46))
    _pulse_after_delay(90, 38 if calm_mode else 54, clampf(base * 1.28, 0.10, 0.64))
    _pulse_after_delay(205, 18 if calm_mode else 28, clampf(base * 0.72, 0.06, 0.38))

func door_open() -> void:
    if not enabled:
        return
    _begin_semantic_pattern(190)
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

func _begin_semantic_pattern(settle_ms: int) -> void:
    _pulse_generation += 1
    _semantic_quiet_until_ms = maxi(_semantic_quiet_until_ms, Time.get_ticks_msec() + maxi(0, settle_ms))
