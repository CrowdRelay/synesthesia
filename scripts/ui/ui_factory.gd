extends RefCounted

const ViryaDesign := preload("res://scripts/ui/virya_design_tokens.gd")
const SignalBackdrop := preload("res://scripts/ui/signal_backdrop.gd")
const SignalGrain := preload("res://scripts/ui/signal_grain.gd")

const PANEL_COLOR: Color = Color("101715f2")
# Legacy finale opacity contract: 0.975; product surfaces now encode opacity directly.

static var _display_font: Font
static var _title_font: Font

const BUNDLED_DISPLAY_FONT_PATH := "res://assets/fonts/generated/SynesthesiaDisplay.ttf"
const BUNDLED_TITLE_FONT_PATH := "res://assets/fonts/generated/SynesthesiaTitle.ttf"


static func display_font() -> Font:
    if _display_font != null:
        return _display_font
    var bundled := _load_bundled_font(BUNDLED_DISPLAY_FONT_PATH)
    if bundled != null:
        _display_font = bundled
        return _display_font
    var font := SystemFont.new()
    font.font_names = PackedStringArray([
        "Impact",
        "Haettenschweiler",
        "Arial Black",
        "Rockwell Extra Bold",
        "DIN Condensed",
        "Avenir Next Condensed",
        "sans-serif",
    ])
    font.font_weight = 900
    font.font_stretch = 76
    font.allow_system_fallback = true
    font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
    _display_font = font
    return _display_font

static func title_font() -> Font:
    if _title_font != null:
        return _title_font
    var bundled := _load_bundled_font(BUNDLED_DISPLAY_FONT_PATH)
    if bundled != null:
        _title_font = bundled
        return _title_font
    var font := SystemFont.new()
    font.font_names = PackedStringArray([
        "Bebas Neue",
        "DIN Condensed",
        "Avenir Next Condensed",
        "Impact",
        "Arial Black",
        "sans-serif",
    ])
    font.font_weight = 900
    font.font_stretch = 74
    font.allow_system_fallback = true
    font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
    _title_font = font
    return _title_font

static func _load_bundled_font(path: String) -> Font:
    if not ResourceLoader.exists(path):
        return null
    var resource := load(path)
    if resource is Font:
        return resource as Font
    return null

static func release_runtime_caches() -> void:
    _display_font = null
    _title_font = null

static func apply_display_font(control: Control) -> void:
    control.add_theme_font_override("font", display_font())

static func apply_title_font(control: Control) -> void:
    control.add_theme_font_override("font", title_font())



static func menu_style(accent: Color) -> StyleBoxFlat:
    return ViryaDesign.surface(accent, true)

static func product_surface_style(accent: Color, strong: bool = false) -> StyleBoxFlat:
    return ViryaDesign.surface(accent, strong)

static func product_inset_style(accent: Color, emphasis: float = 0.12) -> StyleBoxFlat:
    return ViryaDesign.inset(accent, emphasis)

static func product_button(text_value: String, accent: Color, primary: bool = false) -> Button:
    var control := Button.new()
    control.text = text_value
    control.custom_minimum_size = Vector2(190.0, 54.0 if primary else 48.0)
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    control.mouse_filter = Control.MOUSE_FILTER_STOP
    control.focus_mode = Control.FOCUS_ALL
    control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    control.alignment = HORIZONTAL_ALIGNMENT_LEFT
    control.add_theme_font_size_override("font_size", 14 if primary else 12)
    var action_text := Color("07100e") if primary else ViryaDesign.TEXT
    control.add_theme_color_override("font_color", action_text)
    control.add_theme_color_override("font_hover_color", action_text if primary else Color.WHITE)
    control.add_theme_color_override("font_pressed_color", action_text if primary else Color.WHITE)
    control.add_theme_color_override("font_disabled_color", ViryaDesign.TEXT_DIM)
    control.add_theme_stylebox_override("normal", ViryaDesign.button(accent, "normal", primary))
    control.add_theme_stylebox_override("hover", ViryaDesign.button(accent, "hover", primary))
    control.add_theme_stylebox_override("pressed", ViryaDesign.button(accent, "pressed", primary))
    control.add_theme_stylebox_override("focus", ViryaDesign.button(accent, "focus", primary))
    control.add_theme_stylebox_override("disabled", ViryaDesign.button(accent, "disabled", primary))
    return control

static func product_chip(text_value: String, accent: Color) -> Label:
    var chip := Label.new()
    chip.text = text_value
    chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    chip.add_theme_font_size_override("font_size", 9)
    chip.add_theme_color_override("font_color", Color(accent, 0.96))
    chip.add_theme_stylebox_override("normal", ViryaDesign.chip(accent))
    apply_display_font(chip)
    return chip

static func clinical_eyebrow(text_value: String) -> Label:
    var label := section_label(text_value, ViryaDesign.SIGNAL_HOT)
    label.add_theme_font_size_override("font_size", 9)
    return label

static func section_label(text_value: String, accent: Color = ViryaDesign.SIGNAL) -> Label:
    var label := Label.new()
    label.text = text_value
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", 9)
    label.add_theme_color_override("font_color", Color(accent, 0.92))
    apply_display_font(label)
    return label

static func signal_rule(accent: Color, alpha: float = 0.42) -> ColorRect:
    var rule := ColorRect.new()
    rule.color = Color(accent, clampf(alpha, 0.04, 0.85))
    rule.custom_minimum_size = Vector2(0.0, 1.0)
    rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return rule

static func menu_button(text_value: String, accent: Color, primary: bool = false) -> Button:
    # Generic actions follow the same clean sans-serif vocabulary as Virya/Signal.
    return product_button(text_value, accent, primary)


static func panel_style(color: Color = PANEL_COLOR, radius: int = 18, border: Color = Color("dbeaff22")) -> StyleBoxFlat:
    var accent := border if border.a >= 0.12 else ViryaDesign.SIGNAL
    var style := ViryaDesign.surface(accent, false)
    style.bg_color = Color(color.r, color.g, color.b, clampf(color.a, 0.72, 0.98))
    style.border_color = Color(accent, clampf(maxf(border.a, 0.16), 0.16, 0.42))
    style.set_corner_radius_all(clampi(radius, 4, 14))
    return style

static func story_style(accent: Color, alpha: float = 0.93, compact: bool = false) -> StyleBoxFlat:
    var style := ViryaDesign.inset(accent, 0.24 if compact else 0.18)
    style.bg_color = Color(ViryaDesign.SURFACE, clampf(alpha, 0.74, 0.98))
    style.content_margin_left = 16.0 if compact else 20.0
    style.content_margin_top = 11.0 if compact else 15.0
    style.content_margin_right = 16.0 if compact else 20.0
    style.content_margin_bottom = 11.0 if compact else 15.0
    return style

static func finale_style(accent: Color) -> StyleBoxFlat:
    return ViryaDesign.surface(accent, true)

static func button(text_value: String, compact: bool = false) -> Button:
    var control := product_button(text_value, ViryaDesign.SIGNAL, false)
    control.custom_minimum_size = Vector2(100.0 if compact else 128.0, 42.0 if compact else 48.0)
    control.add_theme_font_size_override("font_size", 12 if compact else 13)
    return control

static func heading(text_value: String) -> Label:
    var label: Label = Label.new()
    label.text = text_value
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    # Content headings stay neutral for ecosystem consistency. The authored
    label.add_theme_font_size_override("font_size", 24)
    label.add_theme_color_override("font_color", Color("f4ead8"))
    label.add_theme_constant_override("outline_size", 1)
    label.add_theme_color_override("font_outline_color", Color("05060adc"))
    return label

static func body(text_value: String) -> Label:
    var label: Label = Label.new()
    label.text = text_value
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 14)
    label.add_theme_color_override("font_color", Color("d3c9b8"))
    return label

static func line_edit(placeholder: String, accent: Color = Color("72afff")) -> LineEdit:
    var field: LineEdit = LineEdit.new()
    field.placeholder_text = placeholder
    field.custom_minimum_size = Vector2(0.0, 48.0)
    field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    field.mouse_filter = Control.MOUSE_FILTER_STOP
    field.focus_mode = Control.FOCUS_ALL
    field.mouse_default_cursor_shape = Control.CURSOR_IBEAM
    field.virtual_keyboard_enabled = true
    field.virtual_keyboard_show_on_focus = true
    field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
    field.add_theme_font_size_override("font_size", 14)
    field.add_theme_color_override("font_color", Color("f2eadb"))
    field.add_theme_color_override("font_placeholder_color", Color("918d87"))
    field.add_theme_stylebox_override("normal", ViryaDesign.input(accent, false))
    field.add_theme_stylebox_override("focus", ViryaDesign.input(accent, true))
    return field

static func add_grain(host: Control, alpha: float = 0.16) -> Control:
    var grain: Control = SignalGrain.new()
    grain.name = "SignalGrain"
    grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
    host.add_child(grain)
    grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    grain.configure(clampf(alpha, 0.0, 0.42))
    return grain

static func add_signal_backdrop(host: Control, texture_path: String, accent: Color, dim_strength: float = 0.56, reduced_motion: bool = false) -> Control:
    var backdrop: Control = SignalBackdrop.new()
    backdrop.name = "SignalBackdrop"
    host.add_child(backdrop)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.configure(texture_path, accent, dim_strength, reduced_motion)
    host.move_child(backdrop, 0)
    return backdrop

static func option_button(accent: Color = Color("72afff")) -> OptionButton:
    var control := OptionButton.new()
    control.custom_minimum_size = Vector2(0.0, 46.0)
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    control.mouse_filter = Control.MOUSE_FILTER_STOP
    control.alignment = HORIZONTAL_ALIGNMENT_LEFT
    control.add_theme_font_size_override("font_size", 12)
    control.add_theme_color_override("font_color", Color("f2eadb"))
    control.add_theme_color_override("font_hover_color", Color("fff6e8"))
    control.add_theme_stylebox_override("normal", ViryaDesign.button(accent, "normal", false))
    control.add_theme_stylebox_override("hover", ViryaDesign.button(accent, "hover", false))
    control.add_theme_stylebox_override("pressed", ViryaDesign.button(accent, "pressed", false))
    control.add_theme_stylebox_override("focus", ViryaDesign.button(accent, "focus", false))
    return control

static func check_box(text_value: String, accent: Color = Color("72afff")) -> CheckBox:
    var control := CheckBox.new()
    control.text = text_value
    control.mouse_filter = Control.MOUSE_FILTER_STOP
    control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    control.add_theme_font_size_override("font_size", 10)
    control.add_theme_color_override("font_color", Color("d8cfbf"))
    control.add_theme_color_override("font_hover_color", Color("fff2dd"))
    control.add_theme_color_override("font_pressed_color", Color("fff7eb"))
    control.add_theme_stylebox_override("focus", ViryaDesign.inset(accent, 0.30))
    return control

static func modal(host: Control, requested_size: Vector2) -> PanelContainer:
    var panel: PanelContainer = PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
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
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
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
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    panel.add_child(scroll)
    var content: VBoxContainer = VBoxContainer.new()
    content.mouse_filter = Control.MOUSE_FILTER_PASS
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var panel_width: float = maxf(280.0, panel.offset_right - panel.offset_left)
    content.custom_minimum_size = Vector2(maxf(220.0, panel_width - 48.0), 0.0)
    content.add_theme_constant_override("separation", separation)
    scroll.add_child(content)
    return content
