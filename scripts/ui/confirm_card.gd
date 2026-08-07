extends Control

signal confirmed
signal cancelled

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(title: String, message: String, confirm_text: String) -> void:
    var dim: ColorRect = ColorRect.new()
    dim.color = Color(0.006, 0.009, 0.016, 0.72)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var ui_scale: float = UiMetrics.scale_for_viewport(get_viewport_rect().size)
    var panel: PanelContainer = UIFactory.modal(self, Vector2(490.0, 360.0) * ui_scale)
    var content: VBoxContainer = UIFactory.modal_content(panel, maxi(10, roundi(10.0 * ui_scale)))
    content.add_child(UIFactory.heading(title))
    content.add_child(UIFactory.body(message))
    var confirm_button: Button = UIFactory.button(confirm_text)
    confirm_button.pressed.connect(func() -> void:
        queue_free()
        confirmed.emit()
    )
    content.add_child(confirm_button)
    var cancel_button: Button = UIFactory.button("Anuluj")
    cancel_button.pressed.connect(func() -> void:
        queue_free()
        cancelled.emit()
    )
    content.add_child(cancel_button)
    UiMetrics.apply_tree(panel, ui_scale)
