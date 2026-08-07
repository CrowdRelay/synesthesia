extends Node

var overlay: ColorRect
var accent_line: ColorRect
var _accent: Color = Color("72afff")

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
    accent_line.color = _accent.with_alpha(0.0)
    overlay.add_child(accent_line)
    accent_line.anchor_left = 0.10
    accent_line.anchor_right = 0.90
    accent_line.anchor_top = 0.5
    accent_line.anchor_bottom = 0.5
    accent_line.offset_top = -1.0
    accent_line.offset_bottom = 1.0

func set_accent(value: Color) -> void:
    _accent = value
    if accent_line != null:
        accent_line.color = _accent.with_alpha(accent_line.color.a)

func fade_out(duration: float = 0.46) -> void:
    overlay.visible = true
    overlay.color.a = 0.0
    accent_line.color = _accent.with_alpha(0.0)
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

func fade_in(duration: float = 0.46) -> void:
    overlay.visible = true
    overlay.color.a = 1.0
    accent_line.color = _accent.with_alpha(0.72)
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(overlay, "color:a", 0.0, duration)
    tween.tween_property(accent_line, "color:a", 0.0, duration * 0.68)
    tween.tween_property(accent_line, "scale:x", 0.12, duration * 0.72)
    await tween.finished
    overlay.visible = false
