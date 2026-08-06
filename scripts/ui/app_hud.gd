extends Control

signal settings_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")

var top_margin: MarginContainer
var top_panel: PanelContainer
var bottom_margin: MarginContainer
var bottom_panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var counter_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var discovery_label: Label
var act_label: Label
var brush_label: Label
var palette_row: HBoxContainer
var settings_button: Button
var _painting: bool = false
var _restore_timer: Timer

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_top()
    _build_bottom()
    _restore_timer = Timer.new()
    _restore_timer.one_shot = true
    _restore_timer.wait_time = 1.15
    _restore_timer.timeout.connect(func() -> void: set_painting(false))
    add_child(_restore_timer)

func _build_top() -> void:
    top_margin = MarginContainer.new()
    top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top_margin.add_theme_constant_override("margin_left", 14)
    top_margin.add_theme_constant_override("margin_top", 14)
    top_margin.add_theme_constant_override("margin_right", 14)
    add_child(top_margin)
    top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)

    top_panel = PanelContainer.new()
    top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top_panel.add_theme_stylebox_override("panel", UIFactory.panel_style(Color("080d15d9"), 17))
    top_margin.add_child(top_panel)

    var content: VBoxContainer = VBoxContainer.new()
    content.add_theme_constant_override("separation", 4)
    top_panel.add_child(content)
    var row: HBoxContainer = HBoxContainer.new()
    content.add_child(row)
    title_label = Label.new()
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_label.add_theme_font_size_override("font_size", 18)
    title_label.add_theme_color_override("font_color", Color("f3f7ff"))
    row.add_child(title_label)
    counter_label = Label.new()
    counter_label.add_theme_font_size_override("font_size", 11)
    counter_label.add_theme_color_override("font_color", Color("8cc2ff"))
    row.add_child(counter_label)
    subtitle_label = Label.new()
    subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle_label.add_theme_font_size_override("font_size", 11)
    subtitle_label.add_theme_color_override("font_color", Color("b7c6d9"))
    content.add_child(subtitle_label)
    progress_bar = ProgressBar.new()
    progress_bar.min_value = 0.0
    progress_bar.max_value = 1.0
    progress_bar.show_percentage = false
    progress_bar.custom_minimum_size = Vector2(0.0, 5.0)
    content.add_child(progress_bar)
    progress_label = Label.new()
    progress_label.add_theme_font_size_override("font_size", 11)
    progress_label.add_theme_color_override("font_color", Color("8ec4ff"))
    content.add_child(progress_label)

func _build_bottom() -> void:
    bottom_margin = MarginContainer.new()
    bottom_margin.mouse_filter = Control.MOUSE_FILTER_PASS
    bottom_margin.add_theme_constant_override("margin_left", 12)
    bottom_margin.add_theme_constant_override("margin_right", 12)
    bottom_margin.add_theme_constant_override("margin_bottom", 12)
    add_child(bottom_margin)
    bottom_margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)

    bottom_panel = PanelContainer.new()
    bottom_panel.mouse_filter = Control.MOUSE_FILTER_PASS
    bottom_panel.add_theme_stylebox_override("panel", UIFactory.panel_style(Color("080d15e8"), 17))
    bottom_margin.add_child(bottom_panel)
    var content: VBoxContainer = VBoxContainer.new()
    content.add_theme_constant_override("separation", 5)
    bottom_panel.add_child(content)

    var primary_row: HBoxContainer = HBoxContainer.new()
    content.add_child(primary_row)
    act_label = Label.new()
    act_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    act_label.add_theme_font_size_override("font_size", 12)
    act_label.add_theme_color_override("font_color", Color("f4d8a2"))
    primary_row.add_child(act_label)
    settings_button = UIFactory.button("⚙", true)
    settings_button.custom_minimum_size = Vector2(44.0, 36.0)
    settings_button.mouse_filter = Control.MOUSE_FILTER_STOP
    settings_button.pressed.connect(func() -> void: settings_requested.emit())
    primary_row.add_child(settings_button)

    discovery_label = Label.new()
    discovery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    discovery_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    discovery_label.add_theme_font_size_override("font_size", 12)
    discovery_label.add_theme_color_override("font_color", Color("d8e8f8"))
    content.add_child(discovery_label)

    palette_row = HBoxContainer.new()
    palette_row.alignment = BoxContainer.ALIGNMENT_CENTER
    palette_row.add_theme_constant_override("separation", 4)
    content.add_child(palette_row)
    brush_label = Label.new()
    brush_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    brush_label.add_theme_font_size_override("font_size", 10)
    brush_label.add_theme_color_override("font_color", Color("9db1c9"))
    content.add_child(brush_label)

func configure_room(title: String, subtitle: String, room_index: int, room_total: int, album_progress: float, room_data: Dictionary) -> void:
    title_label.text = title
    subtitle_label.text = subtitle
    counter_label.text = "%02d / %02d" % [room_index + 1, room_total]
    progress_bar.value = album_progress
    progress_label.text = "0% · różowy szum prowadzi"
    discovery_label.text = "Odkrywaj scenę spod zakłóceń"
    act_label.text = "AKT I · ROZPOZNANIE"
    _set_palette(room_data)

func update_reveal(normalized: float) -> void:
    var percent: int = 100 if normalized >= 0.99 else int(floor(normalized * 100.0))
    progress_bar.value = normalized
    if normalized >= 0.99:
        progress_label.text = "100% · tylko muzyka"
    elif normalized >= 0.70:
        progress_label.text = "%d%% · muzyka przejęła scenę" % percent
    elif normalized >= 0.30:
        progress_label.text = "%d%% · utwór przebija się przez szum" % percent
    else:
        progress_label.text = "%d%% · różowy szum prowadzi" % percent

func update_discovery(text_value: String) -> void:
    discovery_label.text = text_value

func update_act(index: int, title: String) -> void:
    act_label.text = "AKT %s · %s" % [_roman(index + 1), title]

func set_painting(value: bool) -> void:
    if _painting == value:
        if value:
            _restore_timer.start()
        return
    _painting = value
    if value:
        _restore_timer.start()
    var target_alpha: float = 0.16 if value else 1.0
    var target_bottom_alpha: float = 0.36 if value else 1.0
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(top_panel, "modulate:a", target_alpha, 0.18)
    tween.tween_property(bottom_panel, "modulate:a", target_bottom_alpha, 0.18)
    subtitle_label.visible = not value
    palette_row.visible = not value
    brush_label.visible = not value
    discovery_label.visible = not value

func show_final() -> void:
    title_label.text = "VIRYA: Synestezja"
    subtitle_label.text = "Jedenaście pokojów. Jeden pełny Sygnał."
    counter_label.text = "FINAŁ"
    progress_bar.value = 1.0
    progress_label.text = "Całe doświadczenie ukończone"
    discovery_label.text = "Nagroda czeka na potwierdzenie e-maila"
    act_label.text = "ALBUM ODSŁONIĘTY"
    set_painting(false)

func _set_palette(room_data: Dictionary) -> void:
    for child in palette_row.get_children():
        child.queue_free()
    var palette_value: Variant = room_data.get("paint_palette", [])
    if palette_value is Array:
        for raw_color in palette_value:
            var swatch: ColorRect = ColorRect.new()
            swatch.color = Color.from_string(str(raw_color), Color("72afff"))
            swatch.custom_minimum_size = Vector2(23.0, 5.0)
            swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
            palette_row.add_child(swatch)
    var brush_value: Variant = room_data.get("brush", {})
    var brush: Dictionary = brush_value if brush_value is Dictionary else {}
    brush_label.text = "Pędzel: %s" % _brush_name(str(brush.get("profile", "soft")))

func _brush_name(profile: String) -> String:
    match profile:
        "water":
            return "wodny"
        "confetti":
            return "konfetti"
        "ink":
            return "atramentowy"
        "wine":
            return "kaligraficzny"
        "organic":
            return "organiczny"
        "dry_ink":
            return "suchy tusz"
        "glitch":
            return "glitch"
        "glass":
            return "szklisty"
        "ember":
            return "żarowy"
        "luminous":
            return "świetlny"
        _:
            return "miękki"

func _roman(value: int) -> String:
    match value:
        1:
            return "I"
        2:
            return "II"
        _:
            return "III"
