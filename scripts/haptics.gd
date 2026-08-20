extends Node

var enabled: bool = true
var calm_mode: bool = true
var calm_amplitude: float = 0.16
var full_amplitude: float = 0.34
var room_style: String = "paint"
var _last_tick_ms: int = 0
var _last_tech_buzz_ms: int = 0
var _last_motion_ms: int = 0
var _last_confirmation_ms: int = 0
var _pulse_generation: int = 0
var _semantic_quiet_until_ms: int = 0

func configure(sensory: Dictionary, style: String = "paint") -> void:
    _pulse_generation += 1
    calm_amplitude = clampf(float(sensory.get("haptics_calm", 0.16)), 0.04, 0.42)
    full_amplitude = clampf(float(sensory.get("haptics_full", 0.34)), 0.08, 0.72)
    room_style = style
    _last_tick_ms = 0
    _last_motion_ms = 0
    _last_confirmation_ms = 0
    _semantic_quiet_until_ms = 0

func set_calm_mode(value: bool) -> void:
    calm_mode = value

func set_enabled(value: bool) -> void:
    if enabled == value:
        return
    enabled = value
    _pulse_generation += 1
    _semantic_quiet_until_ms = 0

func paint_tick(speed_normalized: float) -> void:
    if not enabled:
        return
    var now: int = Time.get_ticks_msec()
    if now < _semantic_quiet_until_ms:
        return
    var interval: int = 132 if calm_mode else 88
    if room_style == "technophobia":
        interval = 156 if calm_mode else 104
    elif room_style == "party":
        interval = 118 if calm_mode else 78
    if now - _last_tick_ms < interval:
        return
    _last_tick_ms = now
    var base: float = (calm_amplitude if calm_mode else full_amplitude) * _style_gain()
    var felt_speed: float = pow(clampf(speed_normalized, 0.0, 1.0), 0.82)
    var amplitude: float = clampf(base * lerpf(0.48, 0.92, felt_speed), 0.04, 0.48)
    var duration: int = 6 if calm_mode else 10
    if room_style == "waves" or room_style == "uncertainty":
        duration = 5 if calm_mode else 8
    Input.vibrate_handheld(duration, amplitude)

    # Technophobia keeps a dry electrical double-tick, but the secondary pulse
    # is sparse enough to read as a cable event rather than continuous buzzing.
    if room_style == "technophobia" and now - _last_tech_buzz_ms > (820 if calm_mode else 520):
        _last_tech_buzz_ms = now
        _pulse_after_delay(26, 4 if calm_mode else 6, clampf(amplitude * 0.52, 0.03, 0.22))

func motion(kind: String, strength: float) -> void:
    if not enabled:
        return
    var now := Time.get_ticks_msec()
    if now < _semantic_quiet_until_ms:
        return
    var amount := pow(clampf(strength, 0.0, 1.0), 1.18)
    if amount < 0.055:
        return
    var interval := 126 if calm_mode else 86
    if kind in ["heartbeat", "breath", "resonance"]:
        interval = 156 if calm_mode else 108
    if now - _last_motion_ms < interval:
        return
    _last_motion_ms = now
    var base := (calm_amplitude if calm_mode else full_amplitude) * _style_gain()
    var scale := 0.20
    var duration := 4 if calm_mode else 6
    match kind:
        "tension": scale = 0.24 + amount * 0.30
        "glass_pressure": scale = 0.18 + amount * 0.25
        "heartbeat": scale = 0.26 + amount * 0.20; duration = 7
        "membrane": scale = 0.20 + amount * 0.27
        "resonance": scale = 0.17 + amount * 0.24; duration = 6
        "ember_flow": scale = 0.15 + amount * 0.20
        "breath": scale = 0.11 + amount * 0.17; duration = 5
        "frequency": scale = 0.19 + amount * 0.26
        "lift": scale = 0.17 + amount * 0.24
        "peel": scale = 0.22 + amount * 0.29
        _: scale = 0.15 + amount * 0.19
    Input.vibrate_handheld(duration, clampf(base * scale, 0.02, 0.22))

func discovery() -> void:
    if not enabled:
        return
    _begin_semantic_pattern(72)
    var base: float = (calm_amplitude if calm_mode else full_amplitude) * _style_gain()
    Input.vibrate_handheld(24 if calm_mode else 36, clampf(base * 1.18, 0.07, 0.54))

func confirmation(strength: float = 0.6) -> void:
    if not enabled:
        return
    var now: int = Time.get_ticks_msec()
    if now < _semantic_quiet_until_ms:
        return
    var minimum_interval: int = 62 if calm_mode else 44
    if now - _last_confirmation_ms < minimum_interval:
        return
    _last_confirmation_ms = now
    var amount: float = pow(clampf(strength, 0.2, 1.0), 1.10)
    var base: float = (calm_amplitude if calm_mode else full_amplitude) * _style_gain()
    var duration: int = roundi(lerpf(6.0, 13.0 if calm_mode else 18.0, amount))
    Input.vibrate_handheld(duration, clampf(base * lerpf(0.42, 0.82, amount), 0.035, 0.36))

func special(kind: String, index: int = 0) -> void:
    if not enabled:
        return
    # Every authored pattern owns its delayed tail. A newer semantic event
    # cancels the previous tail and briefly suppresses paint/motion ticks, so
    # rapid room interactions stay crisp instead of becoming one long buzz.
    _begin_semantic_pattern(118)
    var base: float = (calm_amplitude if calm_mode else full_amplitude) * _style_gain()
    match kind:
        "balloon":
            Input.vibrate_handheld(15 if calm_mode else 23, clampf(base * 1.28, 0.09, 0.56))
            _pulse_after_delay(34, 6, clampf(base * 0.50, 0.04, 0.22))
        "mirror":
            Input.vibrate_handheld(10, clampf(base * 1.38, 0.09, 0.60))
            _pulse_after_delay(28, 18 if calm_mode else 26, clampf(base * 0.96, 0.07, 0.48))
        "toast":
            Input.vibrate_handheld(20 if calm_mode else 29, clampf(base * 0.84, 0.07, 0.38))
            _pulse_after_delay(95, 14, clampf(base * 0.56, 0.05, 0.26))
        "pour":
            Input.vibrate_handheld(8 if calm_mode else 12, clampf(base * 0.38, 0.035, 0.19))
            _pulse_after_delay(56, 7, clampf(base * 0.30, 0.03, 0.15))
        "duel":
            Input.vibrate_handheld(34 if calm_mode else 48, clampf(base * 1.28, 0.11, 0.60))
            _pulse_after_delay(115, 22 if calm_mode else 32, clampf(base * 0.96, 0.09, 0.50))
        "mask":
            Input.vibrate_handheld(12, clampf(base * 1.12, 0.07, 0.48))
            _pulse_after_delay(42, 9, clampf(base * 0.66, 0.05, 0.30))
        "screen":
            Input.vibrate_handheld(8, clampf(base * 0.76, 0.05, 0.34))
            _pulse_after_delay(31, 8, clampf(base * 0.60, 0.04, 0.27))
            _pulse_after_delay(70, 13, clampf(base * 0.94, 0.07, 0.42))
        "cable_grab":
            Input.vibrate_handheld(5, clampf(base * 0.26, 0.025, 0.13))
        "cable_tension":
            var bucket: int = clampi(index % 10, 0, 4)
            var tension: float = float(bucket) / 4.0
            var duration: int = roundi(lerpf(3.0, 7.0 if calm_mode else 10.0, tension))
            var amplitude: float = clampf(base * lerpf(0.15, 0.62, pow(tension, 1.25)), 0.02, 0.26)
            Input.vibrate_handheld(duration, amplitude)
            if bucket >= 3:
                _pulse_after_delay(24, 4 if calm_mode else 5, clampf(amplitude * 0.44, 0.02, 0.14))
        "cable_snap":
            Input.vibrate_handheld(6, clampf(base * 0.30, 0.025, 0.15))
        "cable_unplug":
            Input.vibrate_handheld(14 if calm_mode else 20, clampf(base * 0.82, 0.06, 0.38))
            _pulse_after_delay(46, 7, clampf(base * 0.38, 0.035, 0.19))
        "breaker":
            Input.vibrate_handheld(20 if calm_mode else 29, clampf(base * 0.94, 0.07, 0.44))
            _pulse_after_delay(76, 12, clampf(base * 0.60, 0.045, 0.28))
        "signal_lock":
            Input.vibrate_handheld(15 if calm_mode else 22, clampf(base * 0.66, 0.05, 0.32))
            _pulse_after_delay(86, 28 if calm_mode else 38, clampf(base * 1.04, 0.08, 0.50))
        "echo_complete":
            Input.vibrate_handheld(12 if calm_mode else 17, clampf(base * 0.50, 0.04, 0.26))
            _pulse_after_delay(66, 15, clampf(base * 0.74, 0.06, 0.36))
            _pulse_after_delay(132, 24 if calm_mode else 34, clampf(base * 1.02, 0.08, 0.50))
        "signal_breach":
            Input.vibrate_handheld(6, clampf(base * 0.30, 0.03, 0.17))
            _pulse_after_delay(54, 9, clampf(base * 0.56, 0.05, 0.28))
            _pulse_after_delay(122, 5, clampf(base * 0.38, 0.035, 0.19))
            _pulse_after_delay(188, 22 if calm_mode else 31, clampf(base * 0.92, 0.07, 0.44))
        "resonance_chain":
            var peak := index >= 6
            Input.vibrate_handheld(8 if calm_mode else 12, clampf(base * (0.50 if peak else 0.34), 0.035, 0.28))
            _pulse_after_delay(52, 15 if peak else 9, clampf(base * (0.86 if peak else 0.56), 0.05, 0.42))
        "seed":
            Input.vibrate_handheld(20 if calm_mode else 29, clampf(base * 0.82, 0.06, 0.38))
            _pulse_after_delay(84, 15, clampf(base * 0.64, 0.05, 0.30))
        "root":
            Input.vibrate_handheld(15 if calm_mode else 22, clampf(base * 0.50, 0.04, 0.26))
            _pulse_after_delay(72, 12, clampf(base * 0.43, 0.035, 0.22))
            _pulse_after_delay(132, 15, clampf(base * 0.56, 0.045, 0.28))
        "aim":
            Input.vibrate_handheld(6, clampf(base * 0.30, 0.025, 0.16))
        "ember":
            Input.vibrate_handheld(12 if calm_mode else 18, clampf(base * 0.43, 0.035, 0.22))
            _pulse_after_delay(58, 17, clampf(base * 0.52, 0.04, 0.26))
        "phoenix":
            Input.vibrate_handheld(27 if calm_mode else 38, clampf(base * 0.98, 0.08, 0.48))
            _pulse_after_delay(92, 36 if calm_mode else 48, clampf(base * 1.20, 0.10, 0.58))
        "presence":
            Input.vibrate_handheld(17 if calm_mode else 24, clampf(base * 0.60, 0.045, 0.29))
            _pulse_after_delay(128, 17, clampf(base * 0.47, 0.04, 0.23))
        "light":
            Input.vibrate_handheld(22 if calm_mode else 31, clampf(base * 0.76, 0.06, 0.36))
            _pulse_after_delay(72, 28, clampf(base * 0.92, 0.07, 0.44))
        "wave":
            Input.vibrate_handheld(14 if calm_mode else 20, clampf(base * 0.62, 0.045, 0.30))
            _pulse_after_delay(60, 23 if calm_mode else 32, clampf(base * 0.80, 0.06, 0.38))
        _:
            discovery()

func cinematic_reveal() -> void:
    if not enabled:
        return
    _begin_semantic_pattern(255)
    var base: float = (calm_amplitude if calm_mode else full_amplitude) * _style_gain()
    Input.vibrate_handheld(23 if calm_mode else 33, clampf(base * 0.84, 0.07, 0.40))
    _pulse_after_delay(90, 31 if calm_mode else 44, clampf(base * 1.16, 0.09, 0.56))
    _pulse_after_delay(205, 15 if calm_mode else 23, clampf(base * 0.66, 0.05, 0.32))

func door_open() -> void:
    if not enabled:
        return
    _begin_semantic_pattern(190)
    var base: float = (calm_amplitude if calm_mode else full_amplitude) * _style_gain()
    Input.vibrate_handheld(15, clampf(base * 0.66, 0.05, 0.30))
    _pulse_after_delay(110, 36 if calm_mode else 50, clampf(base * 1.06, 0.08, 0.52))

func _style_gain() -> float:
    match room_style:
        "uncertainty", "waves": return 0.78
        "seed", "rise": return 0.86
        "calling": return 0.90
        "technophobia": return 0.92
        "party": return 0.96
        _: return 1.0

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
