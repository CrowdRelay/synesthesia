extends RefCounted

const PANEL_COLOR: Color = Color("101724f2")

static func panel_style(color: Color = PANEL_COLOR, radius: int = 18) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    style.content_margin_left = 14.0
    style.content_margin_right = 14.0
    style.content_margin_top = 12.0
    style.content_margin_bottom = 12.0
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = Color("dbeaff22")
    return style

static func button(text_value: String, compact: bool = false) -> Button:
    var control: Button = Button.new()
    control.text = text_value
    control.custom_minimum_size = Vector2(92.0 if compact else 120.0, 40.0 if compact else 46.0)
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    control.add_theme_font_size_override("font_size", 12 if compact else 13)
    control.add_theme_color_override("font_color", Color("edf6ff"))
    control.add_theme_stylebox_override("normal", panel_style(Color("18243aeb"), 13))
    control.add_theme_stylebox_override("hover", panel_style(Color("223655f4"), 13))
    control.add_theme_stylebox_override("pressed", panel_style(Color("0e1728f4"), 13))
    return control

static func heading(text_value: String) -> Label:
    var label: Label = Label.new()
    label.text = text_value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 24)
    label.add_theme_color_override("font_color", Color("f2f7ff"))
    return label

static func body(text_value: String) -> Label:
    var label: Label = Label.new()
    label.text = text_value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 14)
    label.add_theme_color_override("font_color", Color("c1d3e9"))
    return label

static func modal(host: Control, requested_size: Vector2) -> PanelContainer:
    var panel: PanelContainer = PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel", panel_style(Color("0c121ef8"), 24))
    host.add_child(panel)
    panel.set_anchors_preset(Control.PRESET_CENTER)
    var viewport_size: Vector2 = host.get_viewport_rect().size
    var effective: Vector2 = Vector2(
        minf(requested_size.x, maxf(280.0, viewport_size.x - 20.0)),
        minf(requested_size.y, maxf(260.0, viewport_size.y - 20.0)),
    )
    panel.offset_left = -effective.x * 0.5
    panel.offset_top = -effective.y * 0.5
    panel.offset_right = effective.x * 0.5
    panel.offset_bottom = effective.y * 0.5
    return panel

static func modal_content(panel: PanelContainer, separation: int = 11) -> VBoxContainer:
    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(scroll)
    var content: VBoxContainer = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", separation)
    scroll.add_child(content)
    return content
