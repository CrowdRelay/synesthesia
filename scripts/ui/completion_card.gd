extends Control

signal continue_requested
signal stay_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")

var _sheet: PanelContainer

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(title: String, message: String, next_label: String, accent: Color) -> void:
    var dim: ColorRect = ColorRect.new()
    dim.color = Color(0.008, 0.01, 0.018, 0.08)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    _sheet = UIFactory.bottom_sheet(self, 294.0, accent)
    _sheet.offset_left = 14.0
    _sheet.offset_right = -14.0
    _sheet.offset_bottom = -14.0
    _sheet.offset_top = -308.0

    var content: VBoxContainer = UIFactory.modal_content(_sheet, 7)
    content.custom_minimum_size = Vector2(470.0, content.custom_minimum_size.y)

    var status: Label = Label.new()
    status.text = "DRZWI OTWARTE  ·  SZUM 0%  ·  MUZYKA 100%"
    status.add_theme_font_size_override("font_size", 9)
    status.add_theme_color_override("font_color", accent)
    content.add_child(status)

    var heading: Label = UIFactory.heading(title)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    heading.add_theme_font_size_override("font_size", 21)
    content.add_child(heading)

    var body: Label = UIFactory.body(message)
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    body.add_theme_font_size_override("font_size", 11)
    body.custom_minimum_size = Vector2(430.0, 0.0)
    content.add_child(body)

    var actions: HBoxContainer = HBoxContainer.new()
    actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.add_theme_constant_override("separation", 8)
    content.add_child(actions)

    var stay: Button = UIFactory.button("Zostań i słuchaj", true)
    stay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stay.pressed.connect(func() -> void: stay_requested.emit())
    actions.add_child(stay)

    var next_button: Button = UIFactory.button(next_label, true)
    next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    next_button.pressed.connect(func() -> void: continue_requested.emit())
    actions.add_child(next_button)

    position.y = 18.0
    modulate.a = 0.0
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.26)
    tween.tween_property(self, "position:y", 0.0, 0.34)
