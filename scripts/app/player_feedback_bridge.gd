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

func _on_interaction_missed(_point: Vector2) -> void:
    if _hud != null and is_instance_valid(_hud):
        _hud.note_miss()

func _on_interaction_confirmed(_point: Vector2, strength: float) -> void:
    if _haptics != null and is_instance_valid(_haptics):
        _haptics.confirmation(strength)
    if _audio != null and is_instance_valid(_audio):
        _audio.play_confirmation_tick(strength)
