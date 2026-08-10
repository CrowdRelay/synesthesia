extends Node

var _hud
var _haptics
var _audio

func bind(room, hud, haptics, audio) -> void:
    _hud = hud
    _haptics = haptics
    _audio = audio
    room.interaction_missed.connect(_on_interaction_missed)
    room.interaction_confirmed.connect(_on_interaction_confirmed)
    room.interaction_motion.connect(_on_interaction_motion)

func _on_interaction_missed(_point: Vector2) -> void:
    if _hud != null and is_instance_valid(_hud):
        _hud.note_miss()

func _on_interaction_confirmed(_point: Vector2, strength: float) -> void:
    if _haptics != null and is_instance_valid(_haptics):
        _haptics.confirmation(strength)
    if _audio != null and is_instance_valid(_audio):
        _audio.play_confirmation_tick(strength)

func _on_interaction_motion(kind: String, strength: float) -> void:
    if _haptics != null and is_instance_valid(_haptics) and _haptics.has_method("motion"):
        _haptics.motion(kind, strength)
    if _audio != null and is_instance_valid(_audio) and _audio.has_method("set_interaction_motion"):
        _audio.set_interaction_motion(kind, strength)
