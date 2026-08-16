extends RefCounted

const UIFactory := preload("res://scripts/ui/ui_factory.gd")

static func build(app: Control, host: Node) -> void:
    app.mobile_instruction_panel = PanelContainer.new()
    app.mobile_instruction_panel.name = "MobileInstructionPanel"
    app.mobile_instruction_panel.visible = false
    app.mobile_instruction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # The instruction is visual guidance, never an input surface. Disabling
    # recursive mouse handling lets room interactions pass through labels and
    # containers as well as the panel itself.
    app.mobile_instruction_panel.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
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

    app.mobile_meta_label = _label("MobileMetaLabel", "AKT I · ECHA 0/3", 9, Color("82a5c8"), VERTICAL_ALIGNMENT_BOTTOM)
    stack.add_child(app.mobile_meta_label)
    app.mobile_instruction_label = _label("MobileInstructionLabel", "ODSŁANIAJ SCENĘ", 17, Color("f3f8ff"), VERTICAL_ALIGNMENT_CENTER)
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
    var parts := normalized.split(" · ", false)
    var headline: String = str(parts[0]) if not parts.is_empty() else normalized
    var detail_parts := PackedStringArray()
    for index in range(1, parts.size()):
        detail_parts.append(str(parts[index]))
    var detail := " · ".join(detail_parts)

    # Replace both labels as one logical state. The old implementation had an
    # initialization path that only changed the headline and could leave stale
    # detail glyphs behind while a gesture changed (e.g. HOLD -> RELEASE).
    app.mobile_instruction_label.text = headline
    if app.mobile_instruction_detail_label != null:
        app.mobile_instruction_detail_label.text = detail
        app.mobile_instruction_detail_label.visible = not detail.is_empty()
        app.mobile_instruction_detail_label.queue_redraw()
    app.mobile_instruction_label.queue_redraw()
    if app.mobile_instruction_panel != null:
        app.mobile_instruction_panel.queue_redraw()
static func set_mobile_meta(app: Control, act_index: int, act_title: String, echo_found: int, echo_total: int, resonance_chain: int) -> void:
    if app.mobile_meta_label == null:
        return
    var act_roman: String = ["I", "II", "III"][clampi(act_index, 0, 2)]
    var parts := PackedStringArray(["AKT %s" % act_roman, "KROK %d/3" % (clampi(act_index, 0, 2) + 1)])
    if not act_title.strip_edges().is_empty():
        parts.append(act_title.strip_edges().to_upper())
    parts.append("ECHA %d/%d" % [maxi(0, echo_found), maxi(0, echo_total)])
    if resonance_chain >= 2:
        parts.append("REZONANS ×%d" % resonance_chain)
    app.mobile_meta_label.text = " · ".join(parts)
    app.mobile_meta_label.add_theme_color_override("font_color", Color("f0cf88") if resonance_chain >= 4 else Color("82a5c8"))

