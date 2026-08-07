extends Control

signal dismissed

const UIFactory := preload("res://scripts/ui/ui_factory.gd")

var _accent: Color = Color("72afff")
var _sheet: PanelContainer

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(room_index: int, room_total: int, room_name: String, intro_text: String, caption: String, accent: Color) -> void:
    _accent = accent
    _build(room_index, room_total, room_name, intro_text, caption)

func _build(room_index: int, room_total: int, room_name: String, intro_text: String, caption: String) -> void:
    var dim: ColorRect = ColorRect.new()
    dim.color = Color(0.01, 0.012, 0.022, 0.18)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var chapter: Label = Label.new()
    chapter.text = "%02d" % (room_index + 1)
    chapter.position = Vector2(18.0, 72.0)
    chapter.add_theme_font_size_override("font_size", 66)
    chapter.add_theme_color_override("font_color", Color(_accent, 0.40))
    chapter.add_theme_color_override("font_shadow_color", Color(Color.BLACK, 0.62))
    chapter.add_theme_constant_override("shadow_offset_x", 2)
    chapter.add_theme_constant_override("shadow_offset_y", 3)
    chapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(chapter)

    var chapter_meta: Label = Label.new()
    chapter_meta.text = "ROZDZIAŁ %02d / %02d" % [room_index + 1, room_total]
    chapter_meta.position = Vector2(24.0, 140.0)
    chapter_meta.add_theme_font_size_override("font_size", 10)
    chapter_meta.add_theme_color_override("font_color", Color("d9e8f8"))
    chapter_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(chapter_meta)

    _sheet = PanelContainer.new()
    _sheet.mouse_filter = Control.MOUSE_FILTER_STOP
    _sheet.add_theme_stylebox_override("panel", UIFactory.story_style(_accent, 0.94, false))
    add_child(_sheet)
    _layout_sheet()

    var content: VBoxContainer = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 7)
    _sheet.add_child(content)

    var eyebrow: Label = Label.new()
    eyebrow.text = caption if not caption.is_empty() else "VIRYA · SYNESTEZJA"
    eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    eyebrow.add_theme_font_size_override("font_size", 9)
    eyebrow.add_theme_color_override("font_color", _accent)
    content.add_child(eyebrow)

    var heading: Label = UIFactory.heading(room_name)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    heading.add_theme_font_size_override("font_size", 24)
    content.add_child(heading)

    var body: Label = UIFactory.body(intro_text)
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    body.add_theme_font_size_override("font_size", 12)
    body.custom_minimum_size = Vector2(430.0, 0.0)
    content.add_child(body)

    var hint: Label = Label.new()
    hint.text = "MALUJ SCENĘ  /  SZUM USTĘPUJE MUZYCE  /  99% OTWIERA DRZWI"
    hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hint.custom_minimum_size = Vector2(430.0, 0.0)
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 8)
    hint.add_theme_color_override("font_color", Color("8fa4bc"))
    content.add_child(hint)

    var button: Button = UIFactory.button("Zacznij odkrywać")
    button.pressed.connect(func() -> void: dismissed.emit())
    content.add_child(button)

    modulate.a = 0.0
    _sheet.position.y += 14.0
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.24)
    tween.tween_property(_sheet, "position:y", _sheet.position.y - 14.0, 0.30)

func _layout_sheet() -> void:
    if _sheet == null:
        return
    _sheet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    var viewport_size: Vector2 = get_viewport_rect().size
    var side: float = 18.0
    var height: float = minf(278.0, maxf(238.0, viewport_size.y * 0.29))
    _sheet.offset_left = side
    _sheet.offset_right = -side
    _sheet.offset_top = -height - 18.0
    _sheet.offset_bottom = -18.0
    _sheet.custom_minimum_size = Vector2(maxf(500.0, viewport_size.x - side * 2.0), height)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_layout_sheet")
