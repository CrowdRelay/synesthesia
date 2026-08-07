extends Control

signal close_requested
signal reload_requested
signal reset_requested
signal calm_changed(value: bool)
signal quiet_changed(value: bool)
signal visuals_changed(value: bool)
signal motion_changed(value: bool)
signal haptics_changed(value: bool)
signal quality_cycle_requested
signal music_changed(value: float)
signal noise_changed(value: float)

const UIFactory := preload("res://scripts/ui/ui_factory.gd")

var _calm: bool = true
var _quiet: bool = false
var _quiet_visuals: bool = false
var _reduced_motion: bool = false
var _haptics: bool = true
var _quality_button: Button

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(state: Dictionary, quality_label: String, version: String) -> void:
    _calm = bool(state.get("calm", true))
    _quiet = bool(state.get("quiet", false))
    _quiet_visuals = bool(state.get("quiet_visuals", false))
    _reduced_motion = bool(state.get("reduced_motion", false))
    _haptics = bool(state.get("haptics", true))
    _build(
        clampf(float(state.get("music", 1.0)), 0.0, 1.0),
        clampf(float(state.get("noise", 1.0)), 0.0, 1.0),
        quality_label,
        version,
    )

func set_quality_label(value: String, pending_reload: bool = false) -> void:
    if _quality_button == null:
        return
    _quality_button.text = "Jakość: %s%s" % [value, " · zastosuj" if pending_reload else ""]

func _build(music: float, noise: float, quality_label: String, version: String) -> void:
    var dim: ColorRect = ColorRect.new()
    dim.color = Color(0.006, 0.009, 0.016, 0.66)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var panel: PanelContainer = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UIFactory.panel_style(Color("090f1bf8"), 24, Color("a8cfff31")))
    add_child(panel)
    panel.set_anchors_preset(Control.PRESET_CENTER)
    var viewport_size: Vector2 = get_viewport_rect().size
    var width: float = minf(510.0, maxf(300.0, viewport_size.x - 20.0))
    var height: float = minf(820.0, maxf(420.0, viewport_size.y - 20.0))
    panel.offset_left = -width * 0.5
    panel.offset_right = width * 0.5
    panel.offset_top = -height * 0.5
    panel.offset_bottom = height * 0.5

    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(scroll)
    var content: VBoxContainer = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 8)
    scroll.add_child(content)

    var eyebrow: Label = Label.new()
    eyebrow.text = "VIRYA · SYNESTEZJA"
    eyebrow.add_theme_font_size_override("font_size", 9)
    eyebrow.add_theme_color_override("font_color", Color("79b7ff"))
    content.add_child(eyebrow)
    var heading: Label = UIFactory.heading("Doświadczenie")
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    content.add_child(heading)
    var intro: Label = UIFactory.body("Dopasuj intensywność bez przerywania podróży. Zmiany sensoryczne działają od razu.")
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    intro.add_theme_font_size_override("font_size", 11)
    content.add_child(intro)

    content.add_child(_section("OBRAZ I RUCH"))
    var calm_button: Button = UIFactory.button(_calm_text())
    calm_button.pressed.connect(func() -> void:
        _calm = not _calm
        calm_button.text = _calm_text()
        calm_changed.emit(_calm)
    )
    content.add_child(calm_button)

    var visual_button: Button = UIFactory.button(_visual_text())
    visual_button.pressed.connect(func() -> void:
        _quiet_visuals = not _quiet_visuals
        visual_button.text = _visual_text()
        visuals_changed.emit(_quiet_visuals)
    )
    content.add_child(visual_button)

    var motion_button: Button = UIFactory.button(_motion_text())
    motion_button.pressed.connect(func() -> void:
        _reduced_motion = not _reduced_motion
        motion_button.text = _motion_text()
        motion_changed.emit(_reduced_motion)
    )
    content.add_child(motion_button)

    _quality_button = UIFactory.button("Jakość: %s" % quality_label)
    _quality_button.pressed.connect(func() -> void: quality_cycle_requested.emit())
    content.add_child(_quality_button)

    content.add_child(_section("DŹWIĘK I DOTYK"))
    var quiet_button: Button = UIFactory.button(_quiet_text())
    quiet_button.pressed.connect(func() -> void:
        _quiet = not _quiet
        quiet_button.text = _quiet_text()
        quiet_changed.emit(_quiet)
    )
    content.add_child(quiet_button)

    var haptic_button: Button = UIFactory.button(_haptic_text())
    haptic_button.pressed.connect(func() -> void:
        _haptics = not _haptics
        haptic_button.text = _haptic_text()
        haptics_changed.emit(_haptics)
    )
    content.add_child(haptic_button)

    content.add_child(_slider_row("Muzyka", music, music_changed))
    content.add_child(_slider_row("Różowy szum", noise, noise_changed))

    content.add_child(_section("POKÓJ"))
    var reload_button: Button = UIFactory.button("Zastosuj jakość i przeładuj pokój")
    reload_button.pressed.connect(func() -> void: reload_requested.emit())
    content.add_child(reload_button)
    var reset_button: Button = UIFactory.button("Od nowa ten pokój…")
    reset_button.pressed.connect(func() -> void: reset_requested.emit())
    content.add_child(reset_button)

    var note: Label = UIFactory.body("v%s · postęp zapisuje się lokalnie · brak stroboskopu" % version)
    note.add_theme_font_size_override("font_size", 9)
    note.add_theme_color_override("font_color", Color("718398"))
    content.add_child(note)
    var close_button: Button = UIFactory.button("Wróć do malowania")
    close_button.pressed.connect(func() -> void: close_requested.emit())
    content.add_child(close_button)

    modulate.a = 0.0
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.18)

func _section(text_value: String) -> Label:
    var label: Label = Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", 9)
    label.add_theme_color_override("font_color", Color("8fbef4"))
    return label

func _slider_row(label_text: String, value: float, signal_ref: Signal) -> VBoxContainer:
    var container: VBoxContainer = VBoxContainer.new()
    var label: Label = UIFactory.body("%s · %d%%" % [label_text, int(round(value * 100.0))])
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    label.add_theme_font_size_override("font_size", 11)
    container.add_child(label)
    var slider: HSlider = HSlider.new()
    slider.min_value = 0.0
    slider.max_value = 1.0
    slider.step = 0.05
    slider.value = value
    slider.custom_minimum_size = Vector2(0.0, 30.0)
    slider.value_changed.connect(func(next_value: float) -> void:
        label.text = "%s · %d%%" % [label_text, int(round(next_value * 100.0))]
        signal_ref.emit(next_value)
    )
    container.add_child(slider)
    return container

func _calm_text() -> String:
    return "Intensywność: %s" % ("spokojna" if _calm else "pełna")

func _quiet_text() -> String:
    return "Audio: %s" % ("uspokojone" if _quiet else "pełne")

func _visual_text() -> String:
    return "VSS: %s" % ("minimalne" if _quiet_visuals else "albumowe")

func _motion_text() -> String:
    return "Ruch: %s" % ("ograniczony" if _reduced_motion else "pełny")

func _haptic_text() -> String:
    return "Haptyka: %s" % ("włączona" if _haptics else "wyłączona")
