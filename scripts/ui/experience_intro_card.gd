extends Control

signal begin_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")

var _accent: Color = Color("64e8d9")
var _panel: PanelContainer
var _phase: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    z_index = 200
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    set_process(true)

func configure(accent: Color) -> void:
    _accent = accent
    _build()

func _build() -> void:
    var dim := ColorRect.new()
    dim.color = Color(0.006, 0.009, 0.016, 0.94)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    _panel = PanelContainer.new()
    _panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _panel.add_theme_stylebox_override("panel", UIFactory.story_style(_accent, 0.96, false))
    add_child(_panel)
    _layout_panel()

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 14)
    _panel.add_child(row)

    var accent_bar := ColorRect.new()
    accent_bar.color = _accent
    accent_bar.custom_minimum_size = Vector2(3.0, 0.0)
    accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(accent_bar)

    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 8)
    row.add_child(content)

    var eyebrow := Label.new()
    eyebrow.text = "VIRYA · SYNESTEZJA · 11 POKOJÓW"
    eyebrow.add_theme_font_size_override("font_size", 9)
    eyebrow.add_theme_color_override("font_color", _accent)
    content.add_child(eyebrow)

    var title := UIFactory.heading("WEJDŹ DO ŚRODKA")
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    title.add_theme_font_size_override("font_size", 26)
    content.add_child(title)

    var body := UIFactory.body("Synestezja to interaktywna podróż przez muzykę, obraz, szum i dotyk. Każdy pokój jest fragmentem stanu emocjonalnego ukrytego w naszych utworach. Nie rozwiązujesz zagadek — odsłaniasz scenę i pozwalasz, żeby sygnał wrócił.")
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    body.add_theme_font_size_override("font_size", 12)
    body.custom_minimum_size = Vector2(390.0, 0.0)
    content.add_child(body)

    var rule := Label.new()
    rule.text = "PRZESUWAJ PALCEM PO SZUMIE  /  IM WIĘCEJ ODSŁONISZ, TYM WIĘCEJ MUZYKI  /  DRZWI PROWADZĄ DALEJ"
    rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rule.add_theme_font_size_override("font_size", 8)
    rule.add_theme_color_override("font_color", Color("9db0c6"))
    content.add_child(rule)

    var meaning := Label.new()
    meaning.text = "To nie test i nie diagnoza. To sposób, żeby wejść do albumu od środka."
    meaning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    meaning.add_theme_font_size_override("font_size", 10)
    meaning.add_theme_color_override("font_color", Color("dce8f5"))
    content.add_child(meaning)

    var button := UIFactory.button("WEJDŹ W SYNESTEZJĘ")
    button.pressed.connect(func() -> void: begin_requested.emit())
    content.add_child(button)

    var footer := Label.new()
    footer.text = "SŁUCHAWKI ZALECANE · HAPTYKA OPCJONALNA · USTAWIENIA POD ZĘBATKĄ"
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_font_size_override("font_size", 8)
    footer.add_theme_color_override("font_color", Color("73869d"))
    content.add_child(footer)

    modulate.a = 0.0
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.30)

func _layout_panel() -> void:
    if _panel == null:
        return
    _panel.set_anchors_preset(Control.PRESET_CENTER)
    var viewport := get_viewport_rect().size
    var width := minf(500.0, maxf(300.0, viewport.x - 30.0))
    var height := minf(420.0, maxf(360.0, viewport.y * 0.46))
    _panel.offset_left = -width * 0.5
    _panel.offset_right = width * 0.5
    _panel.offset_top = -height * 0.04
    _panel.offset_bottom = height * 0.96
    _panel.custom_minimum_size = Vector2(width, height)

func _process(delta: float) -> void:
    _phase += delta
    queue_redraw()

func _draw() -> void:
    var viewport := get_viewport_rect().size
    var center := Vector2(viewport.x * 0.5, maxf(108.0, viewport.y * 0.16))
    var pulse := 0.65 + 0.20 * sin(_phase * 1.4)
    var door := Rect2(center - Vector2(58.0, 82.0), Vector2(116.0, 164.0))
    draw_rect(door, Color(0.012, 0.018, 0.030, 0.88), true)
    draw_rect(door, Color(_accent, 0.44 + pulse * 0.18), false, 2.0)
    draw_rect(door.grow(-11.0), Color(_accent, 0.13), false, 1.0)
    draw_line(Vector2(door.position.x + 13.0, door.end.y - 26.0), Vector2(door.end.x - 13.0, door.end.y - 26.0), Color(_accent, 0.20), 1.0)
    draw_circle(Vector2(door.end.x - 18.0, center.y + 8.0), 2.5, Color(_accent, 0.86))
    var glow := Color(_accent, 0.12 + pulse * 0.07)
    for index in range(4):
        var inset := float(index) * 12.0
        draw_rect(door.grow(22.0 + inset), glow, false, 1.0)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_layout_panel")
