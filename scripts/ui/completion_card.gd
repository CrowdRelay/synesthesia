extends Control

signal continue_requested
signal stay_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(title: String, message: String, next_label: String, accent: Color) -> void:
    var dim: ColorRect = ColorRect.new()
    dim.color = Color(0.008, 0.01, 0.018, 0.18)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_bottom", 16)
    add_child(margin)
    margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)

    var panel: PanelContainer = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UIFactory.panel_style(Color("090e18f2"), 22, accent.with_alpha(0.34)))
    margin.add_child(panel)

    var content: VBoxContainer = VBoxContainer.new()
    content.add_theme_constant_override("separation", 8)
    panel.add_child(content)

    var status: Label = Label.new()
    status.text = "SCENA ODSŁONIĘTA · SZUM 0% · MUZYKA 100%"
    status.add_theme_font_size_override("font_size", 9)
    status.add_theme_color_override("font_color", accent)
    content.add_child(status)

    var heading: Label = UIFactory.heading(title)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    heading.add_theme_font_size_override("font_size", 22)
    content.add_child(heading)

    var body: Label = UIFactory.body(message)
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    body.add_theme_font_size_override("font_size", 12)
    content.add_child(body)

    var next_button: Button = UIFactory.button(next_label)
    next_button.pressed.connect(func() -> void: continue_requested.emit())
    content.add_child(next_button)

    var stay: Button = UIFactory.button("Zostań i słuchaj")
    stay.pressed.connect(func() -> void: stay_requested.emit())
    content.add_child(stay)

    position.y = 24.0
    modulate.a = 0.0
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.26)
    tween.tween_property(self, "position:y", 0.0, 0.34)
