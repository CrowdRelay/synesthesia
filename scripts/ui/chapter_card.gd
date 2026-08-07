extends Control

signal dismissed

const UIFactory := preload("res://scripts/ui/ui_factory.gd")

var _accent: Color = Color("72afff")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(room_index: int, room_total: int, room_name: String, intro_text: String, caption: String, accent: Color) -> void:
    _accent = accent
    _build(room_index, room_total, room_name, intro_text, caption)

func _build(room_index: int, room_total: int, room_name: String, intro_text: String, caption: String) -> void:
    var dim: ColorRect = ColorRect.new()
    dim.color = Color(0.01, 0.012, 0.022, 0.42)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var chapter: Label = Label.new()
    chapter.text = "%02d" % (room_index + 1)
    chapter.position = Vector2(18.0, 76.0)
    chapter.add_theme_font_size_override("font_size", 72)
    chapter.add_theme_color_override("font_color", _accent.with_alpha(0.88))
    chapter.add_theme_color_override("font_shadow_color", Color.BLACK.with_alpha(0.72))
    chapter.add_theme_constant_override("shadow_offset_x", 2)
    chapter.add_theme_constant_override("shadow_offset_y", 3)
    chapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(chapter)

    var chapter_meta: Label = Label.new()
    chapter_meta.text = "ROZDZIAŁ %02d / %02d" % [room_index + 1, room_total]
    chapter_meta.position = Vector2(24.0, 148.0)
    chapter_meta.add_theme_font_size_override("font_size", 11)
    chapter_meta.add_theme_color_override("font_color", Color("d9e8f8"))
    chapter_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(chapter_meta)

    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_bottom", 18)
    add_child(margin)
    margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)

    var panel: PanelContainer = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UIFactory.panel_style(Color("090e18f5"), 22, _accent.with_alpha(0.30)))
    margin.add_child(panel)

    var content: VBoxContainer = VBoxContainer.new()
    content.add_theme_constant_override("separation", 9)
    panel.add_child(content)

    var eyebrow: Label = Label.new()
    eyebrow.text = caption if not caption.is_empty() else "VIRYA · SYNESTEZJA"
    eyebrow.add_theme_font_size_override("font_size", 10)
    eyebrow.add_theme_color_override("font_color", _accent)
    content.add_child(eyebrow)

    var heading: Label = UIFactory.heading(room_name)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    heading.add_theme_font_size_override("font_size", 26)
    content.add_child(heading)

    var body: Label = UIFactory.body(intro_text)
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    body.add_theme_font_size_override("font_size", 13)
    content.add_child(body)

    var hint: Label = Label.new()
    hint.text = "MALUJ SCENĘ · SZUM USTĘPUJE MUZYCE · 99% OTWIERA DRZWI"
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 9)
    hint.add_theme_color_override("font_color", Color("8fa4bc"))
    content.add_child(hint)

    var button: Button = UIFactory.button("Zacznij odkrywać")
    button.pressed.connect(func() -> void: dismissed.emit())
    content.add_child(button)

    modulate.a = 0.0
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.28)
