extends RefCounted

## Owns the cross-layer suspend/resume boundary around the main menu.
## Keeping this outside main.gd prevents room/HUD/audio/transition state from
## drifting apart and makes menu entry a single, cheap state transition.

static func suspend(room_layer: Control, room, hud, audio_director, transition_director) -> void:
    if hud != null and is_instance_valid(hud):
        hud.suspend_for_menu()
    if room != null and is_instance_valid(room):
        room.set_interaction_enabled(false)
    if room_layer != null:
        room_layer.visible = false
        room_layer.process_mode = Node.PROCESS_MODE_DISABLED
    if audio_director != null and is_instance_valid(audio_director) and audio_director.has_method("set_suspended"):
        audio_director.set_suspended(true)
    if transition_director != null and transition_director.has_method("force_idle"):
        transition_director.force_idle()

static func resume(room_layer: Control, hud, audio_director) -> void:
    if room_layer != null:
        room_layer.process_mode = Node.PROCESS_MODE_INHERIT
        room_layer.visible = true
    if hud != null and is_instance_valid(hud):
        hud.resume_for_room()
    if audio_director != null and is_instance_valid(audio_director) and audio_director.has_method("set_suspended"):
        audio_director.set_suspended(false)
