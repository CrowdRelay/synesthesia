extends Node

const DoorTransitionLayerScript := preload("res://scripts/app/door_transition_layer.gd")

var overlay: ColorRect
var accent_line: ColorRect
var door_layer
var _accent: Color = Color("72afff")
var _next_accent: Color = Color("72afff")
var _reduced_motion: bool = false

func install(host: Control) -> void:
    overlay = ColorRect.new()
    overlay.name = "TransitionOverlay"
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.color = Color(0.008, 0.012, 0.022, 0.0)
    overlay.visible = false
    host.add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    accent_line = ColorRect.new()
    accent_line.name = "TransitionSignal"
    accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    accent_line.color = Color(_accent, 0.0)
    overlay.add_child(accent_line)
    accent_line.anchor_left = 0.10
    accent_line.anchor_right = 0.90
    accent_line.anchor_top = 0.5
    accent_line.anchor_bottom = 0.5
    accent_line.offset_top = -1.0
    accent_line.offset_bottom = 1.0

    door_layer = DoorTransitionLayerScript.new()
    door_layer.name = "InnerCorridorTransition"
    host.add_child(door_layer)
    door_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    door_layer.set_accents(_accent, _next_accent)

func set_accent(value: Color) -> void:
    _accent = value
    if accent_line != null:
        accent_line.color = Color(_accent, accent_line.color.a)
    if door_layer != null:
        door_layer.set_accents(_accent, _next_accent)

func set_next_accent(value: Color) -> void:
    _next_accent = value
    if door_layer != null:
        door_layer.set_accents(_accent, _next_accent)

func set_reduced_motion(value: bool) -> void:
    _reduced_motion = value
    if door_layer != null:
        door_layer.set_reduced_motion(value)

func fade_out(duration: float = 0.34) -> void:
    overlay.visible = true
    overlay.color = Color(overlay.color, 0.0)
    accent_line.color = Color(_accent, 0.0)
    accent_line.scale = Vector2(0.08, 1.0)
    accent_line.pivot_offset = Vector2(accent_line.size.x * 0.5, 1.0)
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(overlay, "color:a", 1.0, duration)
    tween.tween_property(accent_line, "color:a", 0.72, duration * 0.56)
    tween.tween_property(accent_line, "scale:x", 1.0, duration * 0.72)
    await tween.finished

func fade_in(duration: float = 0.34) -> void:
    overlay.visible = true
    overlay.color = Color(overlay.color, 1.0)
    accent_line.color = Color(_accent, 0.72)
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(overlay, "color:a", 0.0, duration)
    tween.tween_property(accent_line, "color:a", 0.0, duration * 0.68)
    tween.tween_property(accent_line, "scale:x", 0.12, duration * 0.72)
    await tween.finished
    overlay.visible = false

func travel_out() -> void:
    if door_layer == null:
        await fade_out(0.36)
        return
    overlay.visible = false
    door_layer.visible = true
    door_layer.set_accents(_accent, _next_accent)
    door_layer.set_door_mix(0.0)
    door_layer.set_portal_mix(0.0)
    var close_duration: float = 0.20 if _reduced_motion else 0.36
    var portal_duration: float = 0.10 if _reduced_motion else 0.18
    var close_tween: Tween = create_tween()
    close_tween.set_trans(Tween.TRANS_QUAD)
    close_tween.set_ease(Tween.EASE_IN_OUT)
    close_tween.tween_method(Callable(door_layer, "set_door_mix"), 0.0, 1.0, close_duration)
    await close_tween.finished
    var portal_tween: Tween = create_tween()
    portal_tween.set_trans(Tween.TRANS_SINE)
    portal_tween.set_ease(Tween.EASE_OUT)
    portal_tween.tween_method(Callable(door_layer, "set_portal_mix"), 0.0, 1.0, portal_duration)
    await portal_tween.finished

func travel_in() -> void:
    if door_layer == null:
        await fade_in(0.36)
        return
    door_layer.visible = true
    door_layer.set_door_mix(1.0)
    door_layer.set_portal_mix(1.0)
    var portal_duration: float = 0.10 if _reduced_motion else 0.17
    var open_duration: float = 0.22 if _reduced_motion else 0.40
    var portal_tween: Tween = create_tween()
    portal_tween.set_trans(Tween.TRANS_SINE)
    portal_tween.set_ease(Tween.EASE_IN)
    portal_tween.tween_method(Callable(door_layer, "set_portal_mix"), 1.0, 0.12, portal_duration)
    await portal_tween.finished
    var open_tween: Tween = create_tween()
    open_tween.set_parallel(true)
    open_tween.set_trans(Tween.TRANS_QUAD)
    open_tween.set_ease(Tween.EASE_OUT)
    open_tween.tween_method(Callable(door_layer, "set_door_mix"), 1.0, 0.0, open_duration)
    open_tween.tween_method(Callable(door_layer, "set_portal_mix"), 0.12, 0.0, open_duration * 0.62)
    await open_tween.finished
    door_layer.reset()
