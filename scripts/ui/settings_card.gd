extends Control

signal close_requested
signal reload_requested
signal reset_requested
signal reset_album_requested
signal calm_changed(value: bool)
signal quiet_changed(value: bool)
signal visuals_changed(value: bool)
signal motion_changed(value: bool)
signal readability_changed(value: bool)
signal haptics_changed(value: bool)
signal quality_cycle_requested
signal music_changed(value: float)
signal noise_changed(value: float)

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")

var _calm: bool = true
var _quiet: bool = false
var _quiet_visuals: bool = false
var _reduced_motion: bool = false
var _high_readability: bool = false
var _haptics: bool = true
var _quality_button: Button
var _panel: PanelContainer
var _content: VBoxContainer
var _close_x: Button
var _has_room: bool = true
var _album_completed: bool = false
var _ui_scale: float = 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
    set_process_input(true)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _input(event: InputEvent) -> void:
    # Web/touch fallback for the close affordance. ScrollContainer and browser
    # focus transitions can occasionally consume the Button GUI path; the
    # modal itself still receives viewport input, so a pointer inside the fixed
    # close rect must always close settings regardless of focus ownership.
    if _close_x == null or not is_instance_valid(_close_x) or not _close_x.is_visible_in_tree():
        return
    var pressed: bool = false
    var position := Vector2.ZERO
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        pressed = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
        position = mouse_event.position
    elif event is InputEventScreenTouch:
        var touch_event := event as InputEventScreenTouch
        pressed = touch_event.pressed
        position = touch_event.position
    if pressed and _close_x.get_global_rect().has_point(position):
        get_viewport().set_input_as_handled()
        close_requested.emit()

func _unhandled_key_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        close_requested.emit()

func configure(state: Dictionary, quality_label: String, version: String) -> void:
    _calm = bool(state.get("calm", true))
    _quiet = bool(state.get("quiet", false))
    _quiet_visuals = bool(state.get("quiet_visuals", false))
    _reduced_motion = bool(state.get("reduced_motion", false))
    _high_readability = bool(state.get("high_readability", false))
    _haptics = bool(state.get("haptics", true))
    _has_room = bool(state.get("has_room", true))
    _album_completed = bool(state.get("album_completed", false))
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
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    _panel = PanelContainer.new()
    _panel.mouse_filter = Control.MOUSE_FILTER_PASS
    var settings_style := UIFactory.product_surface_style(Color("43d6df"), true)
    settings_style.bg_color = Color(0.012, 0.020, 0.030, 0.94)
    _panel.add_theme_stylebox_override("panel", settings_style)
    add_child(_panel)
    _panel.set_anchors_preset(Control.PRESET_CENTER)
    var viewport_size: Vector2 = get_viewport_rect().size
    _ui_scale = UiMetrics.scale_for_viewport(viewport_size)

    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = 0
    scroll.vertical_scroll_mode = 1
    _panel.add_child(scroll)
    _content = VBoxContainer.new()
    _content.mouse_filter = Control.MOUSE_FILTER_PASS
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 8)
    scroll.add_child(_content)
    _layout_panel()

    # Keep the close affordance OUTSIDE PanelContainer/ScrollContainer. On touch
    # devices a direct root sibling has an unambiguous z-order and hit target, so
    # the scroll viewport can never intercept the X before Button._gui_input().
    _close_x = UIFactory.button("X", true)
    _close_x.name = "CloseSettingsX"
    _close_x.tooltip_text = "Wróć do malowania"
    _close_x.alignment = HORIZONTAL_ALIGNMENT_CENTER
    UIFactory.apply_display_font(_close_x)
    _close_x.custom_minimum_size = Vector2(56.0, 56.0) * _ui_scale
    _close_x.mouse_filter = Control.MOUSE_FILTER_STOP
    _close_x.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    _close_x.focus_mode = Control.FOCUS_ALL
    _close_x.z_index = 100
    add_child(_close_x)
    _close_x.pressed.connect(func() -> void: close_requested.emit())
    _layout_close_button()

    var eyebrow: Label = Label.new()
    eyebrow.text = "VIRYA · SYNESTEZJA"
    UIFactory.apply_display_font(eyebrow)
    eyebrow.add_theme_font_size_override("font_size", 9)
    eyebrow.add_theme_color_override("font_color", Color("79b7ff"))
    _content.add_child(eyebrow)
    var heading: Label = UIFactory.heading("Doświadczenie")
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _content.add_child(heading)
    var intro: Label = UIFactory.body("Dopasuj intensywność bez przerywania podróży. Zmiany sensoryczne działają od razu.")
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    intro.add_theme_font_size_override("font_size", 11)
    _content.add_child(intro)

    _content.add_child(_section("OBRAZ I RUCH"))
    var calm_button: Button = UIFactory.button(_calm_text())
    calm_button.pressed.connect(func() -> void:
        _calm = not _calm
        calm_button.text = _calm_text()
        calm_changed.emit(_calm)
    )
    _content.add_child(calm_button)

    var visual_button: Button = UIFactory.button(_visual_text())
    visual_button.pressed.connect(func() -> void:
        _quiet_visuals = not _quiet_visuals
        visual_button.text = _visual_text()
        visuals_changed.emit(_quiet_visuals)
    )
    _content.add_child(visual_button)

    var readability_button: Button = UIFactory.button(_readability_text())
    readability_button.pressed.connect(func() -> void:
        _high_readability = not _high_readability
        readability_button.text = _readability_text()
        readability_changed.emit(_high_readability)
    )
    _content.add_child(readability_button)

    var motion_button: Button = UIFactory.button(_motion_text())
    motion_button.pressed.connect(func() -> void:
        _reduced_motion = not _reduced_motion
        motion_button.text = _motion_text()
        motion_changed.emit(_reduced_motion)
    )
    _content.add_child(motion_button)

    _quality_button = UIFactory.button("Jakość: %s" % quality_label)
    _quality_button.pressed.connect(func() -> void: quality_cycle_requested.emit())
    _content.add_child(_quality_button)

    _content.add_child(_section("DŹWIĘK I DOTYK"))
    var quiet_button: Button = UIFactory.button(_quiet_text())
    quiet_button.pressed.connect(func() -> void:
        _quiet = not _quiet
        quiet_button.text = _quiet_text()
        quiet_changed.emit(_quiet)
    )
    _content.add_child(quiet_button)

    var haptic_button: Button = UIFactory.button(_haptic_text())
    haptic_button.pressed.connect(func() -> void:
        _haptics = not _haptics
        haptic_button.text = _haptic_text()
        haptics_changed.emit(_haptics)
    )
    _content.add_child(haptic_button)

    _content.add_child(_slider_row("Muzyka", music, music_changed))
    _content.add_child(_slider_row("Różowy szum", noise, noise_changed))

    if _has_room:
        _content.add_child(_section("POKÓJ"))
        var reload_button: Button = UIFactory.button("Zastosuj jakość i przeładuj pokój")
        reload_button.pressed.connect(func() -> void: reload_requested.emit())
        _content.add_child(reload_button)
        var reset_button: Button = UIFactory.button("Od nowa ten pokój…")
        reset_button.pressed.connect(func() -> void: reset_requested.emit())
        _content.add_child(reset_button)

    _content.add_child(_section("POSTĘP LOKALNY"))
    var reset_album_label: String = "Zagraj od nowa · wyczyść lokalną podróż…" if _album_completed else "Wyczyść całą lokalną podróż…"
    var reset_album_button: Button = UIFactory.button(reset_album_label)
    reset_album_button.pressed.connect(func() -> void: reset_album_requested.emit())
    _content.add_child(reset_album_button)
    var reset_note: Label = UIFactory.body("Reset czyści malowanie i czasy 11 pokojów. Nie cofa istniejącego wpisu do losowania ani stanu po stronie Sygnału.")
    reset_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    reset_note.add_theme_font_size_override("font_size", 10)
    reset_note.add_theme_color_override("font_color", Color("718398"))
    _content.add_child(reset_note)

    var note: Label = UIFactory.body("v%s · postęp zapisuje się lokalnie · brak stroboskopu" % version)
    note.add_theme_font_size_override("font_size", 9)
    note.add_theme_color_override("font_color", Color("718398"))
    _content.add_child(note)
    var close_button: Button = UIFactory.button("Wróć do malowania")
    close_button.pressed.connect(func() -> void: close_requested.emit())
    _content.add_child(close_button)

    modulate.a = 0.0
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.18)

func _layout_panel() -> void:
    if _panel == null:
        return
    var viewport := get_viewport_rect().size
    _ui_scale = UiMetrics.scale_for_viewport(viewport)
    var margin := UiMetrics.safe_margin(viewport, 10.0 * _ui_scale)
    var width := minf(510.0 * _ui_scale, maxf(300.0 * _ui_scale, viewport.x - margin * 2.0))
    var height := minf(820.0 * _ui_scale, maxf(420.0 * _ui_scale, viewport.y - margin * 2.0))
    _panel.offset_left = -width * 0.5
    _panel.offset_right = width * 0.5
    _panel.offset_top = -height * 0.5
    _panel.offset_bottom = height * 0.5
    if _content != null:
        _content.custom_minimum_size = Vector2(maxf(250.0 * _ui_scale, width - 48.0 * _ui_scale), 0.0)
    UiMetrics.apply_tree(_panel, _ui_scale)

func _layout_close_button() -> void:
    if _close_x == null:
        return
    var viewport: Vector2 = get_viewport_rect().size
    var insets: Vector4 = UiMetrics.safe_insets(viewport)
    var touch_size: float = 56.0 * _ui_scale
    var edge: float = 10.0 * _ui_scale
    _close_x.custom_minimum_size = Vector2(touch_size, touch_size)
    _close_x.add_theme_font_size_override("font_size", maxi(18, roundi(20.0 * _ui_scale)))
    _close_x.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _close_x.offset_left = -(insets.z + edge + touch_size)
    _close_x.offset_right = -(insets.z + edge)
    _close_x.offset_top = insets.y + edge
    _close_x.offset_bottom = insets.y + edge + touch_size

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_layout_panel")
        call_deferred("_layout_close_button")

func _section(text_value: String) -> Label:
    var label: Label = Label.new()
    label.text = text_value
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    UIFactory.apply_display_font(label)
    label.add_theme_font_size_override("font_size", 9)
    label.add_theme_color_override("font_color", Color("8fbef4"))
    return label

func _slider_row(label_text: String, value: float, signal_ref: Signal) -> VBoxContainer:
    var container: VBoxContainer = VBoxContainer.new()
    container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var label: Label = UIFactory.body("%s · %d%%" % [label_text, int(round(value * 100.0))])
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    label.add_theme_font_size_override("font_size", 11)
    container.add_child(label)
    var slider: HSlider = HSlider.new()
    slider.min_value = 0.0
    slider.max_value = 1.0
    slider.step = 0.05
    slider.value = value
    slider.custom_minimum_size = Vector2(0.0, 34.0 * _ui_scale)
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

func _readability_text() -> String:
    return "Czytelność: %s" % ("wysoka" if _high_readability else "kinowa")

func _motion_text() -> String:
    return "Ruch: %s" % ("ograniczony" if _reduced_motion else "pełny")

func _haptic_text() -> String:
    return "Haptyka: %s" % ("włączona" if _haptics else "wyłączona")
