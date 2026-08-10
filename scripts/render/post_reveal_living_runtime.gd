extends Node

# Owns the phase after a room is solved. The reveal animation has a short authored
# hero beat, then decays into a permanent low-energy living loop instead of
# freezing on the last frame. It only drives existing lightweight render layers.

var app: Control
var _enabled: bool = true
var _settle_delay: float = 2.0
var _target_strength: float = 0.78
var _reduced_strength: float = 0.18
var _elapsed: float = 0.0
var _living_time: float = 0.0
var _living_strength: float = 0.0
var _was_revealed: bool = false
var _instant_restore: bool = false

func bind(owner: Control) -> void:
    app = owner
    set_process(true)

func configure(room_data: Dictionary) -> void:
    var value: Variant = room_data.get("living_state", {})
    var cfg: Dictionary = value if value is Dictionary else {}
    _enabled = bool(cfg.get("enabled", true))
    _settle_delay = clampf(float(cfg.get("settle_delay", 2.0)), 0.8, 3.5)
    _target_strength = clampf(float(cfg.get("strength", 0.78)), 0.20, 1.0)
    _reduced_strength = clampf(float(cfg.get("reduced_motion_strength", 0.18)), 0.0, 0.35)
    _reset_runtime()

func _process(delta: float) -> void:
    if app == null or app.composite_material == null:
        return
    var revealed: bool = bool(app.cinematic_revealed)
    if not revealed or not _enabled:
        if _was_revealed or _living_strength > 0.001:
            _reset_runtime()
            _apply(0.0, 0.0, 0.0)
        _was_revealed = false
        return

    if not _was_revealed:
        _was_revealed = true
        _elapsed = 0.0
        _living_time = 0.0
        _living_strength = 0.0
        # Restored completed rooms are set to full reveal before the next frame.
        # Do not replay their completion beat every time Album Mode opens them.
        _instant_restore = float(app._cinematic_mix) >= 0.995 and float(app._cinematic_elapsed) <= 0.05
        if _instant_restore:
            _elapsed = _settle_delay + 0.6
            _living_strength = _effective_target()

    _elapsed += minf(delta, 0.10)
    var hero: float = 0.0
    if not _instant_restore and _elapsed < _settle_delay:
        var raw: float = clampf(_elapsed / _settle_delay, 0.0, 1.0)
        hero = raw * raw * (3.0 - 2.0 * raw)
    else:
        _living_time = fmod(_living_time + minf(delta, 0.10), 10000.0)
        _living_strength = move_toward(_living_strength, _effective_target(), delta * 0.52)

    _apply(hero, _living_strength, _living_time)

func _effective_target() -> float:
    if app != null and bool(app.reduced_motion):
        return _target_strength * _reduced_strength
    if app != null and bool(app.quiet_visuals):
        return _target_strength * 0.54
    return _target_strength

func _apply(hero: float, living: float, living_time: float) -> void:
    if app.world_micro_fx != null:
        app.world_micro_fx.set_cinematic(hero)
        if app.world_micro_fx.has_method("set_living_strength"):
            app.world_micro_fx.set_living_strength(living)
    if app.composite_material != null:
        app.composite_material.set_shader_parameter("living_strength", living)
        app.composite_material.set_shader_parameter("living_time", living_time)

func _reset_runtime() -> void:
    _elapsed = 0.0
    _living_time = 0.0
    _living_strength = 0.0
    _instant_restore = false
