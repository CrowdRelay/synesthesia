extends RefCounted

const UIFactory := preload("res://scripts/ui/ui_factory.gd")

static func build(app: Control, host: Node) -> void:
    app.mobile_instruction_panel = PanelContainer.new()
    app.mobile_instruction_panel.name = "MobileInstructionPanel"
    app.mobile_instruction_panel.visible = false
    app.mobile_instruction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    app.mobile_instruction_panel.add_theme_stylebox_override("panel", UIFactory.product_surface_style(app._accent, true))
    host.add_child(app.mobile_instruction_panel)

    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 10)
    app.mobile_instruction_panel.add_child(row)

    app.mobile_instruction_accent_bar = ColorRect.new()
    app.mobile_instruction_accent_bar.color = app._accent
    app.mobile_instruction_accent_bar.custom_minimum_size = Vector2(5.0, 48.0)
    app.mobile_instruction_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(app.mobile_instruction_accent_bar)

    var stack := VBoxContainer.new()
    stack.name = "MobileInstructionStack"
    stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    stack.add_theme_constant_override("separation", 2)
    row.add_child(stack)

    app.mobile_instruction_label = _label("MobileInstructionLabel", "ODSŁANIAJ SCENĘ", 17, Color("f3f8ff"), VERTICAL_ALIGNMENT_BOTTOM)
    stack.add_child(app.mobile_instruction_label)
    app.mobile_instruction_detail_label = _label("MobileInstructionDetailLabel", "SZUM USTĘPUJE MUZYCE", 11, Color("9fb2c9"), VERTICAL_ALIGNMENT_TOP)
    stack.add_child(app.mobile_instruction_detail_label)

static func _label(node_name: String, text_value: String, font_size: int, color: Color, alignment: VerticalAlignment) -> Label:
    var label := Label.new()
    label.name = node_name
    label.text = text_value
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.vertical_alignment = alignment
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    UIFactory.apply_display_font(label)
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label

static func set_text(app: Control, text_value: String) -> void:
    if app.mobile_instruction_label == null:
        return
    var normalized := text_value.strip_edges().to_upper()
    var parts := normalized.split(" · ", false, 2)
    app.mobile_instruction_label.text = str(parts[0]) if not parts.is_empty() else normalized
    if app.mobile_instruction_detail_label != null:
        app.mobile_instruction_detail_label.text = str(parts[1]) if parts.size() > 1 else ""
        app.mobile_instruction_detail_label.visible = not app.mobile_instruction_detail_label.text.is_empty()
