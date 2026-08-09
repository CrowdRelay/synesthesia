extends RefCounted

static func show(host: Control, message: String) -> void:
    var label: Label = Label.new()
    label.text = message
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 21)
    host.add_child(label)
    label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
