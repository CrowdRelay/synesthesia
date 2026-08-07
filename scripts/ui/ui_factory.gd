extends RefCounted

const PANEL_COLOR: Color = Color("101724f2")

static func panel_style(color: Color = PANEL_COLOR, radius: int = 18, border: Color = Color("dbeaff22")) -> StyleBoxFlat:
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
    style.border_color = border
    return style

static func story_style(accent: Color, alpha: float = 0.93, compact: bool = false) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.038, 0.060, clampf(alpha, 0.0, 1.0))
    style.corner_radius_top_left = 5 if compact else 7
    style.corner_radius_top_right = 14 if compact else 18
    style.corner_radius_bottom_left = 14 if compact else 18
    style.corner_radius_bottom_right = 5 if compact else 7
    style.content_margin_left = 17.0 if compact else 20.0
    style.content_margin_right = 14.0 if compact else 18.0
    style.content_margin_top = 9.0 if compact else 13.0
    style.content_margin_bottom = 9.0 if compact else 13.0
    style.border_width_left = 3
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = Color(accent, 0.58 if compact else 0.48)
    return style

static func finale_style(accent: Color) -> StyleBoxFlat:
    var style: StyleBoxFlat = story_style(accent, 0.90, false)
    style.corner_radius_top_left = 26
    style.corner_radius_top_right = 26
    style.corner_radius_bottom_left = 0
    style.corner_radius_bottom_right = 0
    style.content_margin_left = 18.0
    style.content_margin_right = 18.0
    style.content_margin_top = 18.0
    style.content_margin_bottom = 18.0
    return style

static func button(text_value: String, compact: bool = false) -> Button:
    var control: Button = Button.new()
    control.text = text_value
    control.custom_minimum_size = Vector2(92.0 if compact else 120.0, 40.0 if compact else 46.0)
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    control.add_theme_font_size_override("font_size", 12 if compact else 13)
    control.add_theme_color_override("font_color", Color("edf6ff"))
    control.add_theme_stylebox_override("normal", panel_style(Color("18243aeb"), 13, Color("b9d9ff2b")))
    control.add_theme_stylebox_override("hover", panel_style(Color("223655f4"), 13, Color("d8eaff52")))
    control.add_theme_stylebox_override("pressed", panel_style(Color("0e1728f4"), 13, Color("7fbaff66")))
    control.add_theme_stylebox_override("focus", panel_style(Color("1b2a43f0"), 13, Color("8fc4ff99")))
    control.add_theme_stylebox_override("disabled", panel_style(Color("101722cc"), 13, Color("dbeaff12")))
    control.add_theme_color_override("font_disabled_color", Color("8d9aaa"))
    return control

static func heading(text_value: String) -> Label:
    var label: Label = Label.new()
    label.text = text_value
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 24)
    label.add_theme_color_override("font_color", Color("f2f7ff"))
    return label

static func body(text_value: String) -> Label:
    var label: Label = Label.new()
    label.text = text_value
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 14)
    label.add_theme_color_override("font_color", Color("c1d3e9"))
    return label

static func line_edit(placeholder: String, accent: Color = Color("72afff")) -> LineEdit:
    var field: LineEdit = LineEdit.new()
    field.placeholder_text = placeholder
    field.custom_minimum_size = Vector2(0.0, 46.0)
    field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    field.add_theme_font_size_override("font_size", 13)
    field.add_theme_color_override("font_color", Color("edf6ff"))
    field.add_theme_color_override("font_placeholder_color", Color("8798ae"))
    field.add_theme_stylebox_override("normal", story_style(Color(accent, 0.56), 0.80, true))
    field.add_theme_stylebox_override("focus", story_style(accent, 0.92, true))
    return field

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

static func bottom_sheet(host: Control, requested_height: float, accent: Color) -> PanelContainer:
    var panel: PanelContainer = PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel", finale_style(accent))
    host.add_child(panel)
    panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    var viewport_size: Vector2 = host.get_viewport_rect().size
    var height: float = minf(requested_height, maxf(360.0, viewport_size.y * 0.68))
    panel.offset_left = 10.0
    panel.offset_right = -10.0
    panel.offset_top = -height
    panel.offset_bottom = 0.0
    return panel

static func modal_content(panel: PanelContainer, separation: int = 11) -> VBoxContainer:
    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    panel.add_child(scroll)
    var content: VBoxContainer = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var panel_width: float = maxf(280.0, panel.offset_right - panel.offset_left)
    content.custom_minimum_size = Vector2(maxf(220.0, panel_width - 48.0), 0.0)
    content.add_theme_constant_override("separation", separation)
    scroll.add_child(content)
    return content
