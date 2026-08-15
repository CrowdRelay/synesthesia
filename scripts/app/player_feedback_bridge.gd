extends Node

var _hud
var _haptics
var _audio
var _room
var _resonance_chain: int = 0

func bind(room, hud, haptics, audio) -> void:
    _room = room
    _hud = hud
    _haptics = haptics
    _audio = audio
    room.interaction_missed.connect(_on_interaction_missed)
    room.interaction_confirmed.connect(_on_interaction_confirmed)
    room.interaction_motion.connect(_on_interaction_motion)

func _on_interaction_missed(_point: Vector2) -> void:
    _resonance_chain = 0
    if _hud != null and is_instance_valid(_hud):
        _hud.note_miss()
        if _hud.has_method("update_resonance_chain"):
            _hud.update_resonance_chain(0)

func _on_interaction_confirmed(_point: Vector2, strength: float) -> void:
    _resonance_chain = mini(6, _resonance_chain + 1)
    var chain_gain: float = float(_resonance_chain - 1) / 5.0
    var felt_strength: float = clampf(strength + chain_gain * 0.16, 0.0, 1.0)
    if _hud != null and is_instance_valid(_hud):
        _hud.note_success()
        if _hud.has_method("update_resonance_chain"):
            _hud.update_resonance_chain(_resonance_chain)
    if _haptics != null and is_instance_valid(_haptics):
        if _resonance_chain in [4, 6] and _haptics.has_method("special"):
            _haptics.special("resonance_chain", _resonance_chain)
        else:
            _haptics.confirmation(felt_strength)
    if _audio != null and is_instance_valid(_audio):
        _audio.play_confirmation_tick(felt_strength)
    if _resonance_chain in [4, 6] and _hud != null and is_instance_valid(_hud) and _hud.has_method("update_discovery"):
        _hud.update_discovery("REZONANS ×%d · %s" % [_resonance_chain, "PEŁNA FAZA" if _resonance_chain >= 6 else "UTRZYMAJ RYTM"])
    if _room != null and is_instance_valid(_room):
        _room.set("_interaction_energy", maxf(float(_room.get("_interaction_energy")), 0.24 + chain_gain * 0.34))

func _on_interaction_motion(kind: String, strength: float) -> void:
    if _haptics != null and is_instance_valid(_haptics) and _haptics.has_method("motion"):
        _haptics.motion(kind, strength)
    if _audio != null and is_instance_valid(_audio) and _audio.has_method("set_interaction_motion"):
        _audio.set_interaction_motion(kind, strength)
