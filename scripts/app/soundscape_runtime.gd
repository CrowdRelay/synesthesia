extends RefCounted

const MenuRuntimeGuard := preload("res://scripts/app/menu_runtime_guard.gd")
const MenuSoundscapeScript := preload("res://scripts/audio/menu_soundscape.gd")

static func install(parent: Node, music: float, noise: float, quiet: bool):
    var soundscape = MenuSoundscapeScript.new()
    soundscape.name = "MenuSoundscape"
    parent.add_child(soundscape)
    soundscape.set_user_levels(music, noise, quiet)
    return soundscape

static func suspend_for_menu(soundscape, room_layer, room, hud, audio_director, transition_director, adaptive_performance, music: float, noise: float, quiet: bool, start_audio: bool = true) -> void:
    MenuRuntimeGuard.suspend(room_layer, room, hud, audio_director, transition_director, adaptive_performance)
    soundscape.set_user_levels(music, noise, quiet)
    if start_audio:
        soundscape.enter_menu()
    else:
        # Boot/menu construction owns the first frame; audio starts only after
        # the actual menu has been presented.
        soundscape.leave_soundscape()

static func begin_menu_soundscape(soundscape, music: float, noise: float, quiet: bool) -> void:
    soundscape.set_user_levels(music, noise, quiet)
    soundscape.enter_menu()

static func resume_room(soundscape, room_layer, hud, audio_director, adaptive_performance) -> void:
    soundscape.leave_soundscape()
    MenuRuntimeGuard.resume(room_layer, hud, audio_director, adaptive_performance)

static func apply_audio_levels(soundscape, audio_director, music: float, noise: float, quiet: bool) -> void:
    if audio_director != null:
        audio_director.set_user_levels(music, noise)
    soundscape.set_user_levels(music, noise, quiet)

static func enter_outro(soundscape, music: float, noise: float, quiet: bool) -> void:
    soundscape.set_user_levels(music, noise, quiet)
    soundscape.enter_outro()
