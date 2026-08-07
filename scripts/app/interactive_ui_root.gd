extends Control

func _ready() -> void:
    name = "InteractiveUiRoot"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
    z_index = 1200
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func attach(control: Control, layer: int) -> Control:
    add_child(control)
    control.z_index = layer
    return control
