extends Node

const SignalBreachBeat := preload("res://scripts/ui/signal_breach_beat.gd")
var app: Node

func bind(owner: Node) -> void: app = owner

func hero_beat_delay() -> float:
    var room_value: Variant = app.manifest.get("room", {})
    var room_data: Dictionary = room_value if room_value is Dictionary else {}
    match str(room_data.get("visual_style", "uncertainty")):
        "technophobia": return 2.20
        "unmasked": return 2.05
        "invaluable": return 2.10
        "seed": return 2.25
        "party": return 1.90
        "calling": return 2.20
        "ashes": return 2.35
        "waves": return 2.10
        "hybrid": return 1.95
        "rise": return 2.40
        _: return 1.90

func play_signal_breach() -> void:
    if app.ui_root == null: return
    var beat := SignalBreachBeat.new()
    beat.name = "SignalBreachBeat"
    app.ui_root.attach(beat, 95)
    beat.configure(app._accent_for_release(app.current_room_index), Color("e73535"))
    if app.haptics != null and app.haptics.has_method("special"): app.haptics.special("signal_breach")
    if app.audio_director != null and app.audio_director.has_method("play_interaction_sfx"): app.audio_director.play_interaction_sfx("signal_lock", 77)
