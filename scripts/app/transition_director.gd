extends Node

var overlay: ColorRect

func install(host: Control) -> void:
    overlay = ColorRect.new()
    overlay.name = "TransitionOverlay"
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.color = Color(0.015, 0.02, 0.035, 0.0)
    overlay.visible = false
    host.add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func fade_out(duration: float = 0.48) -> void:
    overlay.visible = true
    overlay.color.a = 0.0
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(overlay, "color:a", 1.0, duration)
    await tween.finished

func fade_in(duration: float = 0.48) -> void:
    overlay.visible = true
    overlay.color.a = 1.0
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(overlay, "color:a", 0.0, duration)
    await tween.finished
    overlay.visible = false
