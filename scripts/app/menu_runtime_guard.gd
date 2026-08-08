extends RefCounted

## Owns the cross-layer suspend/resume boundary around the main menu.
## Keeping this outside main.gd prevents room/HUD/audio/transition state from
## drifting apart and makes menu entry a single, cheap state transition.

static var _background_active: bool = false
static var _background_experience_mode: int = Node.PROCESS_MODE_INHERIT
static var _background_ui_mode: int = Node.PROCESS_MODE_INHERIT
static var _background_room_mode: int = Node.PROCESS_MODE_INHERIT
static var _background_room_visible: bool = true

static func suspend(room_layer: Control, room, hud, audio_director, transition_director, adaptive_performance = null) -> void:
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
    if adaptive_performance != null and is_instance_valid(adaptive_performance) and adaptive_performance.has_method("set_suspended"):
        adaptive_performance.set_suspended(true)

static func resume(room_layer: Control, hud, audio_director, adaptive_performance = null) -> void:
    if room_layer != null:
        room_layer.process_mode = Node.PROCESS_MODE_INHERIT
        room_layer.visible = true
    if hud != null and is_instance_valid(hud):
        hud.resume_for_room()
    if audio_director != null and is_instance_valid(audio_director) and audio_director.has_method("set_suspended"):
        audio_director.set_suspended(false)
    if adaptive_performance != null and is_instance_valid(adaptive_performance) and adaptive_performance.has_method("set_suspended"):
        adaptive_performance.set_suspended(false)

static func suspend_for_background(experience_surface: Node, ui_root: Node, room_layer: Control, audio_director, adaptive_performance = null) -> void:
    if _background_active:
        return
    _background_active = true
    if experience_surface != null:
        _background_experience_mode = experience_surface.process_mode
        experience_surface.process_mode = Node.PROCESS_MODE_DISABLED
    if ui_root != null:
        _background_ui_mode = ui_root.process_mode
        ui_root.process_mode = Node.PROCESS_MODE_DISABLED
    if room_layer != null:
        _background_room_mode = room_layer.process_mode
        _background_room_visible = room_layer.visible
        room_layer.process_mode = Node.PROCESS_MODE_DISABLED
    if audio_director != null and is_instance_valid(audio_director) and audio_director.has_method("set_suspended"):
        audio_director.set_suspended(true)
    if adaptive_performance != null and is_instance_valid(adaptive_performance) and adaptive_performance.has_method("set_suspended"):
        adaptive_performance.set_suspended(true)

static func resume_from_background(experience_surface: Node, ui_root: Node, room_layer: Control, audio_director, adaptive_performance = null) -> void:
    if not _background_active:
        return
    _background_active = false
    if experience_surface != null:
        experience_surface.process_mode = _background_experience_mode
    if ui_root != null:
        ui_root.process_mode = _background_ui_mode
    if room_layer != null:
        room_layer.process_mode = _background_room_mode
        room_layer.visible = _background_room_visible
    # If the room was already disabled (main menu), keep audio/adaptive asleep.
    if _background_room_mode != Node.PROCESS_MODE_DISABLED:
        if audio_director != null and is_instance_valid(audio_director) and audio_director.has_method("set_suspended"):
            audio_director.set_suspended(false)
        if adaptive_performance != null and is_instance_valid(adaptive_performance) and adaptive_performance.has_method("set_suspended"):
            adaptive_performance.set_suspended(false)
