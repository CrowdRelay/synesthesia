extends RefCounted

const PANEL_COLOR: Color = Color("101724f2")
const COMIC_PANEL_TEXTURE_PATH: String = "res://assets/comic/panel_comic.webp"
const COMIC_COMPACT_TEXTURE_PATH: String = "res://assets/comic/panel_compact.webp"
const COMIC_BUTTON_TEXTURE_PATH: String = "res://assets/comic/button_comic.webp"
const COMIC_INPUT_TEXTURE_PATH: String = "res://assets/comic/input_comic.webp"
const PAPER_GRAIN_TEXTURE_PATH: String = "res://assets/comic/paper_grain.webp"

static var _texture_cache: Dictionary = {}
static var _display_font: Font
static var _title_font: Font

const BUNDLED_DISPLAY_FONT_PATH := "res://assets/fonts/generated/SynesthesiaDisplay.ttf"
const BUNDLED_TITLE_FONT_PATH := "res://assets/fonts/generated/SynesthesiaTitle.ttf"

static func _texture(path: String) -> Texture2D:
    var cached: Variant = _texture_cache.get(path)
    if cached is Texture2D:
        return cached as Texture2D
    if not ResourceLoader.exists(path):
        push_error("Comic UI texture is not imported: %s" % path)
        return null
    var resource: Resource = load(path)
    if not resource is Texture2D:
        push_error("Comic UI resource is not Texture2D: %s" % path)
        return null
    var texture := resource as Texture2D
    _texture_cache[path] = texture
    return texture


static func display_font() -> Font:
    if _display_font != null:
        return _display_font
    var bundled := _load_bundled_font(BUNDLED_DISPLAY_FONT_PATH)
    if bundled != null:
        _display_font = bundled
        return _display_font
    # Menu/UI face: deliberately poster-like and compressed rather than a clean
    # product/tech sans. The cascade stays system-only so the overlay ships no
    # font binaries and still degrades safely on Android/Web.
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
    var bundled := _load_bundled_font(BUNDLED_TITLE_FONT_PATH)
    if bundled != null:
        _title_font = bundled
        return _title_font
    # Main headings can be rougher than controls. On macOS this lands on a
    # hand-inked face; elsewhere it falls through to the heavy poster cascade.
    var font := SystemFont.new()
    font.font_names = PackedStringArray([
        "Chalkduster",
        "Trattatello",
        "Marker Felt",
        "Rockwell Extra Bold",
        "Impact",
        "Arial Black",
        "sans-serif",
    ])
    font.font_weight = 900
    font.font_stretch = 82
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

static func apply_display_font(control: Control) -> void:
    control.add_theme_font_override("font", display_font())

static func apply_title_font(control: Control) -> void:
    control.add_theme_font_override("font", title_font())

static func _comic_tint(accent: Color, strength: float, alpha: float) -> Color:
    var tint: Color = Color.WHITE.lerp(accent, clampf(strength, 0.0, 0.72))
    tint.a = clampf(alpha, 0.0, 1.0)
    return tint

static func _texture_style(
    texture: Texture2D,
    tint: Color,
    texture_margin: float,
    margin_left: float,
    margin_top: float,
    margin_right: float,
    margin_bottom: float
) -> StyleBoxTexture:
    var style := StyleBoxTexture.new()
    style.texture = texture
    style.texture_margin_left = texture_margin
    style.texture_margin_top = texture_margin
    style.texture_margin_right = texture_margin
    style.texture_margin_bottom = texture_margin
    style.content_margin_left = margin_left
    style.content_margin_top = margin_top
    style.content_margin_right = margin_right
    style.content_margin_bottom = margin_bottom
    style.modulate_color = tint
    return style

static func menu_style(accent: Color) -> StyleBoxTexture:
    return _texture_style(
        _texture(COMIC_PANEL_TEXTURE_PATH),
        _comic_tint(accent, 0.20, 0.985),
        48.0,
        26.0,
        24.0,
        26.0,
        24.0
    )

static func menu_button(text_value: String, accent: Color, primary: bool = false) -> Button:
    var control: Button = Button.new()
    control.text = text_value
    control.custom_minimum_size = Vector2(190.0, 58.0 if primary else 50.0)
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    control.mouse_filter = Control.MOUSE_FILTER_STOP
    control.focus_mode = Control.FOCUS_ALL
    control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    control.alignment = HORIZONTAL_ALIGNMENT_CENTER
    apply_display_font(control)
    control.add_theme_font_size_override("font_size", 15 if primary else 13)
    control.add_theme_color_override("font_color", Color("f4ead7"))
    control.add_theme_color_override("font_hover_color", Color("fff6e8"))
    control.add_theme_color_override("font_pressed_color", Color("fff9ef"))
    control.add_theme_constant_override("outline_size", 1)
    control.add_theme_color_override("font_outline_color", Color("05070bd8"))
    control.add_theme_stylebox_override("normal", _button_style(accent, 0.24 if primary else 0.14, 0.92))
    control.add_theme_stylebox_override("hover", _button_style(accent, 0.46 if primary else 0.34, 1.0))
    control.add_theme_stylebox_override("pressed", _button_style(accent.darkened(0.14), 0.52, 0.98))
    control.add_theme_stylebox_override("focus", _button_style(accent.lightened(0.10), 0.44, 1.0))
    control.add_theme_stylebox_override("disabled", _button_style(Color("58616f"), 0.08, 0.60))
    return control

static func _button_style(accent: Color, tint_strength: float, alpha: float) -> StyleBoxTexture:
    return _texture_style(
        _texture(COMIC_BUTTON_TEXTURE_PATH),
        _comic_tint(accent, tint_strength, alpha),
        18.0,
        14.0,
        9.0,
        14.0,
        9.0
    )

static func panel_style(color: Color = PANEL_COLOR, radius: int = 18, border: Color = Color("dbeaff22")) -> StyleBoxTexture:
    # Keep the old signature because many UI surfaces already call it. Radius is
    # intentionally ignored by the bitmap skin: the inked corners are authored
    # into the reusable 9-slice texture instead of being mathematically round.
    var accent: Color = border
    if accent.a < 0.12:
        accent = Color("8398b4")
    var alpha: float = clampf(color.a + 0.04, 0.70, 1.0)
    return _texture_style(
        _texture(COMIC_PANEL_TEXTURE_PATH),
        _comic_tint(accent, 0.12, alpha),
        48.0,
        18.0,
        16.0,
        18.0,
        16.0
    )

static func story_style(accent: Color, alpha: float = 0.93, compact: bool = false) -> StyleBoxTexture:
    var texture: Texture2D = _texture(COMIC_COMPACT_TEXTURE_PATH if compact else COMIC_PANEL_TEXTURE_PATH)
    var texture_margin: float = 34.0 if compact else 48.0
    return _texture_style(
        texture,
        _comic_tint(accent, 0.18 if compact else 0.14, clampf(alpha, 0.0, 1.0)),
        texture_margin,
        18.0 if compact else 22.0,
        11.0 if compact else 15.0,
        16.0 if compact else 20.0,
        11.0 if compact else 15.0
    )

static func finale_style(accent: Color) -> StyleBoxTexture:
    var alpha: float = 0.975
    return _texture_style(
        _texture(COMIC_PANEL_TEXTURE_PATH),
        _comic_tint(accent, 0.22, alpha),
        48.0,
        22.0,
        20.0,
        22.0,
        20.0
    )

static func button(text_value: String, compact: bool = false) -> Button:
    var control: Button = Button.new()
    control.text = text_value
    control.custom_minimum_size = Vector2(100.0 if compact else 128.0, 42.0 if compact else 48.0)
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    control.mouse_filter = Control.MOUSE_FILTER_STOP
    control.focus_mode = Control.FOCUS_ALL
    control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    control.alignment = HORIZONTAL_ALIGNMENT_CENTER
    apply_display_font(control)
    control.add_theme_font_size_override("font_size", 12 if compact else 13)
    control.add_theme_color_override("font_color", Color("f2eadb"))
    control.add_theme_color_override("font_disabled_color", Color("8d9aaa"))
    var neutral := Color("7f9fbd")
    control.add_theme_stylebox_override("normal", _button_style(neutral, 0.12, 0.90))
    control.add_theme_stylebox_override("hover", _button_style(Color("9bc6ef"), 0.30, 1.0))
    control.add_theme_stylebox_override("pressed", _button_style(Color("6e8fb2"), 0.26, 0.98))
    control.add_theme_stylebox_override("focus", _button_style(Color("b1d4f3"), 0.28, 1.0))
    control.add_theme_stylebox_override("disabled", _button_style(Color("55606d"), 0.05, 0.58))
    return control

static func heading(text_value: String) -> Label:
    var label: Label = Label.new()
    label.text = text_value
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    apply_title_font(label)
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
    field.add_theme_font_size_override("font_size", 13)
    field.add_theme_color_override("font_color", Color("f2eadb"))
    field.add_theme_color_override("font_placeholder_color", Color("918d87"))
    field.add_theme_stylebox_override("normal", _texture_style(_texture(COMIC_INPUT_TEXTURE_PATH), _comic_tint(accent, 0.08, 0.94), 24.0, 17.0, 9.0, 14.0, 9.0))
    field.add_theme_stylebox_override("focus", _texture_style(_texture(COMIC_INPUT_TEXTURE_PATH), _comic_tint(accent, 0.30, 1.0), 24.0, 17.0, 9.0, 14.0, 9.0))
    return field



static func add_grain(host: Control, alpha: float = 0.16) -> TextureRect:
    var grain := TextureRect.new()
    grain.name = "ComicPaperGrain"
    grain.texture = _texture(PAPER_GRAIN_TEXTURE_PATH)
    grain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    grain.stretch_mode = TextureRect.STRETCH_TILE
    grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
    grain.modulate = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 0.42))
    host.add_child(grain)
    grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    return grain

static func option_button(accent: Color = Color("72afff")) -> OptionButton:
    var control := OptionButton.new()
    control.custom_minimum_size = Vector2(0.0, 46.0)
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    control.mouse_filter = Control.MOUSE_FILTER_STOP
    control.alignment = HORIZONTAL_ALIGNMENT_CENTER
    apply_display_font(control)
    control.add_theme_font_size_override("font_size", 12)
    control.add_theme_color_override("font_color", Color("f2eadb"))
    control.add_theme_color_override("font_hover_color", Color("fff6e8"))
    control.add_theme_stylebox_override("normal", _button_style(accent, 0.09, 0.91))
    control.add_theme_stylebox_override("hover", _button_style(accent, 0.26, 1.0))
    control.add_theme_stylebox_override("pressed", _button_style(accent, 0.32, 0.98))
    control.add_theme_stylebox_override("focus", _button_style(accent, 0.30, 1.0))
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
    control.add_theme_stylebox_override("focus", _button_style(accent, 0.18, 0.46))
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
