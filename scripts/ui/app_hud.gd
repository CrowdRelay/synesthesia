extends Control

signal settings_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const SettingsGearIcon := preload("res://scripts/ui/settings_gear_icon.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")

var header_row: HBoxContainer
var top_margin: MarginContainer
var top_panel: PanelContainer
var bottom_margin: MarginContainer
var bottom_panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var counter_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var act_label: Label
var brush_label: Label
var palette_row: HBoxContainer
var journey_row: HBoxContainer
var top_content: VBoxContainer
var bottom_content: VBoxContainer
var progress_row: HBoxContainer
var settings_button: Button
var instruction_label: Label
var top_accent_bar: ColorRect
var bottom_accent_bar: ColorRect
var toast_panel: PanelContainer
var toast_label: Label
var toast_accent_bar: ColorRect
var act_banner: PanelContainer
var act_banner_label: Label
var act_accent_bar: ColorRect
var _painting: bool = false
var _context_seen: bool = false
var _restore_timer: Timer
var _toast_timer: Timer
var _act_timer: Timer
var _room_index: int = 0
var _room_total: int = 11
var _accent: Color = Color("72afff")
var _ui_scale: float = 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_header_row()
    _build_top()
    _build_bottom()
    _build_toast()
    _build_act_banner()
    _restore_timer = _timer(0.72, func() -> void: set_painting(false))
    _toast_timer = _timer(2.7, _hide_toast)
    _act_timer = _timer(1.65, _hide_act_banner)
    call_deferred("_apply_ui_scale")
    call_deferred("_apply_mobile_safe_area")
    call_deferred("_layout_story_overlays")

func suspend_for_menu() -> void:
    clear_transient_overlays()
    _painting = false
    if top_panel != null:
        top_panel.modulate.a = 1.0
    if bottom_panel != null:
        bottom_panel.modulate.a = 1.0
    visible = false

func resume_for_room() -> void:
    clear_transient_overlays()
    visible = true
    _apply_ui_scale()

func clear_transient_overlays() -> void:
    if _restore_timer != null:
        _restore_timer.stop()
    if _toast_timer != null:
        _toast_timer.stop()
    if _act_timer != null:
        _act_timer.stop()
    if toast_panel != null:
        toast_panel.visible = false
        toast_panel.modulate.a = 0.0
    if act_banner != null:
        act_banner.visible = false
        act_banner.modulate.a = 0.0

func _apply_ui_scale() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    _ui_scale = UiMetrics.scale_for_viewport(viewport_size)
    UiMetrics.apply_tree(self, _ui_scale)
    if header_row != null:
        header_row.offset_left = 12.0 * _ui_scale
        header_row.offset_right = -12.0 * _ui_scale
        header_row.offset_top = 12.0 * _ui_scale
        header_row.offset_bottom = 166.0 * _ui_scale
    if top_panel != null:
        top_panel.custom_minimum_size.y = 146.0 * _ui_scale
    if bottom_panel != null:
        bottom_panel.custom_minimum_size.y = 146.0 * _ui_scale
    _layout_story_overlays()

func _timer(wait: float, callback: Callable) -> Timer:
    var timer: Timer = Timer.new()
    timer.one_shot = true
    timer.wait_time = wait
    timer.timeout.connect(callback)
    add_child(timer)
    return timer

func _build_header_row() -> void:
    header_row = HBoxContainer.new()
    header_row.name = "HeaderRow"
    header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header_row.add_theme_constant_override("separation", 8)
    add_child(header_row)
    header_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
    header_row.offset_left = 12.0
    header_row.offset_right = -12.0
    header_row.offset_top = 12.0
    header_row.offset_bottom = 166.0

func _build_top() -> void:
    top_margin = MarginContainer.new()
    top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
    top_margin.size_flags_stretch_ratio = 1.18
    header_row.add_child(top_margin)

    top_panel = PanelContainer.new()
    top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top_panel.custom_minimum_size = Vector2(0.0, 146.0)
    top_panel.add_theme_stylebox_override("panel", UIFactory.story_style(_accent, 0.88, false))
    top_margin.add_child(top_panel)

    var shell := HBoxContainer.new()
    shell.add_theme_constant_override("separation", 10)
    top_panel.add_child(shell)
    top_accent_bar = ColorRect.new()
    top_accent_bar.color = _accent
    top_accent_bar.custom_minimum_size = Vector2(3.0, 0.0)
    top_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shell.add_child(top_accent_bar)

    top_content = VBoxContainer.new()
    top_content.name = "TopContent"
    top_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    top_content.add_theme_constant_override("separation", 4)
    shell.add_child(top_content)
    var content: VBoxContainer = top_content

    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0.0, 30.0)
    row.add_theme_constant_override("separation", 7)
    content.add_child(row)

    counter_label = Label.new()
    counter_label.name = "RoomCounter"
    counter_label.custom_minimum_size = Vector2(48.0, 22.0)
    counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    counter_label.add_theme_font_size_override("font_size", 10)
    counter_label.add_theme_color_override("font_color", Color("88bfff"))
    row.add_child(counter_label)

    title_label = Label.new()
    title_label.name = "RoomTitle"
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    title_label.add_theme_font_size_override("font_size", 15)
    title_label.add_theme_color_override("font_color", Color("f4f7fb"))
    row.add_child(title_label)

    settings_button = UIFactory.button("", true)
    var settings_gear: Control = SettingsGearIcon.new()
    settings_gear.name = "SettingsGearIcon"
    settings_gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
    settings_gear.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    settings_button.add_child(settings_gear)
    settings_button.custom_minimum_size = Vector2(38.0, 30.0)
    settings_button.size_flags_horizontal = Control.SIZE_SHRINK_END
    settings_button.mouse_filter = Control.MOUSE_FILTER_STOP
    settings_button.tooltip_text = "Ustawienia doświadczenia"
    settings_button.pressed.connect(func() -> void: settings_requested.emit())
    row.add_child(settings_button)

    subtitle_label = Label.new()
    subtitle_label.name = "RoomSubtitle"
    subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    subtitle_label.custom_minimum_size = Vector2(0.0, 28.0)
    subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    subtitle_label.add_theme_font_size_override("font_size", 10)
    subtitle_label.add_theme_color_override("font_color", Color("b6c4d5"))
    content.add_child(subtitle_label)

    progress_row = HBoxContainer.new()
    progress_row.name = "RevealProgressRow"
    progress_row.custom_minimum_size = Vector2(0.0, 16.0)
    progress_row.add_theme_constant_override("separation", 7)
    content.add_child(progress_row)
    progress_bar = ProgressBar.new()
    progress_bar.name = "RevealProgress"
    progress_bar.min_value = 0.0
    progress_bar.max_value = 1.0
    progress_bar.show_percentage = false
    progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    progress_bar.custom_minimum_size = Vector2(0.0, 5.0)
    progress_bar.add_theme_stylebox_override("background", _bar_style(Color("0b1320d9")))
    progress_bar.add_theme_stylebox_override("fill", _bar_style(_accent))
    progress_row.add_child(progress_bar)
    progress_label = Label.new()
    progress_label.name = "RevealProgressLabel"
    progress_label.custom_minimum_size = Vector2(108.0, 16.0)
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    progress_label.add_theme_font_size_override("font_size", 9)
    progress_label.add_theme_color_override("font_color", Color("8ec4ff"))
    progress_row.add_child(progress_label)

    journey_row = HBoxContainer.new()
    journey_row.name = "JourneyRow"
    journey_row.custom_minimum_size = Vector2(0.0, 6.0)
    journey_row.alignment = BoxContainer.ALIGNMENT_CENTER
    journey_row.add_theme_constant_override("separation", 4)
    content.add_child(journey_row)

func _build_bottom() -> void:
    bottom_margin = MarginContainer.new()
    bottom_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bottom_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
    bottom_margin.size_flags_stretch_ratio = 0.82
    header_row.add_child(bottom_margin)

    bottom_panel = PanelContainer.new()
    bottom_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom_panel.custom_minimum_size = Vector2(0.0, 146.0)
    bottom_panel.add_theme_stylebox_override("panel", UIFactory.story_style(Color("f3d39d"), 0.88, false))
    bottom_margin.add_child(bottom_panel)

    var shell := HBoxContainer.new()
    shell.add_theme_constant_override("separation", 10)
    bottom_panel.add_child(shell)
    bottom_accent_bar = ColorRect.new()
    bottom_accent_bar.color = Color("f3d39d")
    bottom_accent_bar.custom_minimum_size = Vector2(3.0, 0.0)
    bottom_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shell.add_child(bottom_accent_bar)

    bottom_content = VBoxContainer.new()
    bottom_content.name = "BottomContent"
    bottom_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bottom_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    bottom_content.add_theme_constant_override("separation", 5)
    shell.add_child(bottom_content)
    var content: VBoxContainer = bottom_content

    act_label = Label.new()
    act_label.name = "ActLabel"
    act_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    act_label.custom_minimum_size = Vector2(0.0, 24.0)
    act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    act_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    act_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    act_label.add_theme_font_size_override("font_size", 10)
    act_label.add_theme_color_override("font_color", Color("f0d39d"))
    content.add_child(act_label)

    instruction_label = Label.new()
    instruction_label.name = "InstructionLabel"
    instruction_label.text = "ODSŁANIAJ SCENĘ · SZUM → MUZYKA"
    instruction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    instruction_label.custom_minimum_size = Vector2(0.0, 22.0)
    instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    instruction_label.add_theme_font_size_override("font_size", 9)
    instruction_label.add_theme_color_override("font_color", Color("b5c3d4"))
    content.add_child(instruction_label)

    palette_row = HBoxContainer.new()
    palette_row.name = "PaletteRow"
    palette_row.custom_minimum_size = Vector2(0.0, 10.0)
    palette_row.alignment = BoxContainer.ALIGNMENT_BEGIN
    palette_row.add_theme_constant_override("separation", 4)
    content.add_child(palette_row)

    brush_label = Label.new()
    brush_label.name = "BrushLabel"
    brush_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    brush_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    brush_label.custom_minimum_size = Vector2(0.0, 28.0)
    brush_label.add_theme_font_size_override("font_size", 9)
    brush_label.add_theme_color_override("font_color", Color("8d9fb5"))
    content.add_child(brush_label)

func _build_toast() -> void:
    toast_panel = PanelContainer.new()
    toast_panel.visible = false
    toast_panel.modulate.a = 0.0
    toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    toast_panel.add_theme_stylebox_override("panel", UIFactory.story_style(_accent, 0.94, true))
    add_child(toast_panel)
    var row: HBoxContainer = HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 10)
    toast_panel.add_child(row)
    toast_accent_bar = ColorRect.new()
    toast_accent_bar.color = _accent
    toast_accent_bar.custom_minimum_size = Vector2(3.0, 28.0)
    toast_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(toast_accent_bar)
    toast_label = Label.new()
    toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    toast_label.custom_minimum_size = Vector2(360.0, 0.0)
    toast_label.add_theme_font_size_override("font_size", 11)
    toast_label.add_theme_color_override("font_color", Color("e6f1ff"))
    row.add_child(toast_label)

func _build_act_banner() -> void:
    act_banner = PanelContainer.new()
    act_banner.visible = false
    act_banner.modulate.a = 0.0
    act_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    act_banner.add_theme_stylebox_override("panel", UIFactory.story_style(Color("f3d39d"), 0.93, true))
    add_child(act_banner)
    var row: HBoxContainer = HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 10)
    act_banner.add_child(row)
    act_accent_bar = ColorRect.new()
    act_accent_bar.color = Color("f3d39d")
    act_accent_bar.custom_minimum_size = Vector2(3.0, 26.0)
    act_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(act_accent_bar)
    act_banner_label = Label.new()
    act_banner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    act_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    act_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    act_banner_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    act_banner_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    act_banner_label.custom_minimum_size = Vector2(360.0, 0.0)
    act_banner_label.add_theme_font_size_override("font_size", 10)
    act_banner_label.add_theme_color_override("font_color", Color("f7e7c7"))
    row.add_child(act_banner_label)
    _layout_story_overlays()

func _layout_story_overlays() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return
    var side: float = clampf(viewport_size.x * 0.055, 22.0 * _ui_scale, 34.0 * _ui_scale)
    if toast_panel != null:
        toast_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
        toast_panel.offset_left = side
        toast_panel.offset_right = -side
        toast_panel.offset_top = -180.0 * _ui_scale
        toast_panel.offset_bottom = -108.0 * _ui_scale
        toast_panel.custom_minimum_size = Vector2(maxf(420.0 * _ui_scale, viewport_size.x - side * 2.0), 72.0 * _ui_scale)
        toast_label.custom_minimum_size = Vector2(maxf(360.0 * _ui_scale, viewport_size.x - side * 2.0 - 58.0 * _ui_scale), toast_label.custom_minimum_size.y)
    if act_banner != null:
        # Keep the act badge in its own top-right slot. It must never share the
        # vertical band occupied by the room instruction panel.
        var act_width: float = clampf(viewport_size.x * 0.43, 196.0 * _ui_scale, 250.0 * _ui_scale)
        var panel_bottom: float = 136.0 * _ui_scale
        if header_row != null and header_row.size.y > 1.0:
            panel_bottom = header_row.position.y + header_row.size.y
        var act_top: float = panel_bottom + 8.0 * _ui_scale
        act_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
        act_banner.offset_left = -side - act_width
        act_banner.offset_right = -side
        act_banner.offset_top = act_top
        act_banner.offset_bottom = act_top + 46.0 * _ui_scale
        act_banner.custom_minimum_size = Vector2(act_width, 46.0 * _ui_scale)
        act_banner_label.custom_minimum_size = Vector2(maxf(138.0 * _ui_scale, act_width - 36.0 * _ui_scale), 0.0)
        act_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _repair_runtime_refs() -> void:
    if not is_instance_valid(counter_label):
        counter_label = find_child("RoomCounter", true, false) as Label
    if not is_instance_valid(title_label):
        title_label = find_child("RoomTitle", true, false) as Label
    if not is_instance_valid(subtitle_label):
        subtitle_label = find_child("RoomSubtitle", true, false) as Label
    if not is_instance_valid(progress_row):
        progress_row = find_child("RevealProgressRow", true, false) as HBoxContainer
    if not is_instance_valid(progress_bar):
        progress_bar = find_child("RevealProgress", true, false) as ProgressBar
    if not is_instance_valid(progress_label):
        progress_label = find_child("RevealProgressLabel", true, false) as Label
    if not is_instance_valid(journey_row):
        journey_row = find_child("JourneyRow", true, false) as HBoxContainer
    if not is_instance_valid(act_label):
        act_label = find_child("ActLabel", true, false) as Label
    if not is_instance_valid(instruction_label):
        instruction_label = find_child("InstructionLabel", true, false) as Label
    if not is_instance_valid(palette_row):
        palette_row = find_child("PaletteRow", true, false) as HBoxContainer
    if not is_instance_valid(brush_label):
        brush_label = find_child("BrushLabel", true, false) as Label
    if not is_instance_valid(progress_bar) and is_instance_valid(progress_row):
        progress_bar = ProgressBar.new()
        progress_bar.name = "RevealProgress"
        progress_bar.min_value = 0.0
        progress_bar.max_value = 1.0
        progress_bar.show_percentage = false
        progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        progress_bar.custom_minimum_size = Vector2(0.0, 7.0)
        progress_bar.add_theme_stylebox_override("background", _bar_style(Color("0b1320d9")))
        progress_bar.add_theme_stylebox_override("fill", _bar_style(_accent))
        progress_row.add_child(progress_bar)

func _set_reveal_ui(normalized: float) -> void:
    _repair_runtime_refs()
    if is_instance_valid(progress_bar):
        progress_bar.value = clampf(normalized, 0.0, 1.0)
    if not is_instance_valid(progress_label):
        return
    var percent: int = 100 if normalized >= 0.99 else int(floor(normalized * 100.0))
    if normalized >= 0.99:
        progress_label.text = "100% · tylko muzyka"
    elif normalized >= 0.70:
        progress_label.text = "%d%% · muzyka prowadzi" % percent
    elif normalized >= 0.30:
        progress_label.text = "%d%% · sygnał wraca" % percent
    else:
        progress_label.text = "%d%% · szum prowadzi" % percent

func configure_room(title: String, subtitle: String, room_index: int, room_total: int, _album_progress: float, room_data: Dictionary) -> void:
    _repair_runtime_refs()
    clear_transient_overlays()
    _apply_ui_scale()
    _room_index = room_index
    _room_total = room_total
    _context_seen = false
    title_label.text = title.trim_prefix("VIRYA: ")
    subtitle_label.text = subtitle
    subtitle_label.visible = true
    counter_label.text = "%02d / %02d" % [room_index + 1, room_total]
    _set_reveal_ui(0.0)
    act_label.text = "AKT I · ROZPOZNANIE"
    _accent = Color.from_string(str(room_data.get("accent_color", "#72AFFF")), Color("72afff"))
    top_panel.add_theme_stylebox_override("panel", UIFactory.story_style(_accent, 0.88, false))
    bottom_panel.add_theme_stylebox_override("panel", UIFactory.story_style(_accent.lerp(Color("f3d39d"), 0.48), 0.88, false))
    top_accent_bar.color = _accent
    bottom_accent_bar.color = _accent.lerp(Color("f3d39d"), 0.42)
    progress_bar.add_theme_stylebox_override("fill", _bar_style(_accent))
    if toast_panel != null:
        toast_panel.add_theme_stylebox_override("panel", UIFactory.story_style(_accent, 0.94, true))
    if toast_accent_bar != null:
        toast_accent_bar.color = _accent
    _set_palette(room_data)
    _rebuild_journey()
    _hide_toast()
    _hide_act_banner()

func update_reveal(normalized: float) -> void:
    _set_reveal_ui(normalized)

func update_discovery(text_value: String) -> void:
    if text_value.is_empty() or not visible:
        return
    toast_label.text = text_value
    toast_panel.visible = true
    toast_panel.modulate.a = 0.0
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(toast_panel, "modulate:a", 1.0, 0.16)
    _toast_timer.start()

func update_act(index: int, title: String) -> void:
    act_label.text = "AKT %s · %s" % [_roman(index + 1), title]
    if index <= 0:
        return
    act_banner_label.text = "AKT %s  ·  %s" % [_roman(index + 1), title]
    act_banner.visible = true
    act_banner.modulate.a = 0.0
    act_banner.scale = Vector2(0.97, 0.97)
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(act_banner, "modulate:a", 1.0, 0.18)
    tween.tween_property(act_banner, "scale", Vector2.ONE, 0.22)
    _act_timer.start()

func set_painting(value: bool) -> void:
    if _painting == value:
        if value:
            _restore_timer.start()
        return
    _painting = value
    if value:
        _context_seen = true
        _restore_timer.start()
    var target_alpha: float = 0.82 if value else 1.0
    var target_bottom_alpha: float = 0.78 if value else 1.0
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(top_panel, "modulate:a", target_alpha, 0.16)
    tween.tween_property(bottom_panel, "modulate:a", target_bottom_alpha, 0.16)
    subtitle_label.visible = true
    palette_row.visible = true
    brush_label.visible = true
    instruction_label.visible = true

func show_final() -> void:
    _repair_runtime_refs()
    title_label.text = "Synestezja"
    subtitle_label.text = "Jedenaście pokojów. Jeden pełny Sygnał."
    subtitle_label.visible = true
    counter_label.text = "FINAŁ"
    _set_reveal_ui(1.0)
    if is_instance_valid(progress_label):
        progress_label.text = "Album odsłonięty"
    act_label.text = "CAŁE DOŚWIADCZENIE"
    _room_index = _room_total - 1
    _rebuild_journey(true)
    set_painting(false)

func _rebuild_journey(force_complete: bool = false) -> void:
    for child in journey_row.get_children():
        child.queue_free()
    for index in range(_room_total):
        var dot: ColorRect = ColorRect.new()
        var completed: bool = force_complete or index < _room_index
        var current: bool = not force_complete and index == _room_index
        dot.custom_minimum_size = Vector2((18.0 if current else 10.0) * _ui_scale, 2.0 * _ui_scale)
        if completed:
            dot.color = Color(_accent, 0.64)
        elif current:
            dot.color = _accent
        else:
            dot.color = Color("91a4b42f")
        dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        journey_row.add_child(dot)

func _set_palette(room_data: Dictionary) -> void:
    for child in palette_row.get_children():
        child.queue_free()
    var palette_value: Variant = room_data.get("paint_palette", [])
    if palette_value is Array:
        for raw_color in palette_value:
            var swatch: ColorRect = ColorRect.new()
            swatch.color = Color.from_string(str(raw_color), Color("72afff"))
            swatch.custom_minimum_size = Vector2(20.0 * _ui_scale, 3.0 * _ui_scale)
            swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
            palette_row.add_child(swatch)
    var brush_value: Variant = room_data.get("brush", {})
    var brush: Dictionary = brush_value if brush_value is Dictionary else {}
    brush_label.text = "%s · przeciągnij palcem po szumie" % _brush_name(str(brush.get("profile", "soft")))

func _hide_toast() -> void:
    if toast_panel == null or not toast_panel.visible:
        return
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.tween_property(toast_panel, "modulate:a", 0.0, 0.22)
    tween.finished.connect(func() -> void: toast_panel.visible = false)

func _hide_act_banner() -> void:
    if act_banner == null or not act_banner.visible:
        return
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.tween_property(act_banner, "modulate:a", 0.0, 0.24)
    tween.finished.connect(func() -> void: act_banner.visible = false)

func _apply_mobile_safe_area() -> void:
    if not OS.has_feature("mobile"):
        return
    var safe: Rect2i = DisplayServer.get_display_safe_area()
    var screen_size: Vector2i = DisplayServer.screen_get_size()
    var viewport_size: Vector2 = get_viewport_rect().size
    if screen_size.x <= 0 or screen_size.y <= 0 or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return
    var scale_y: float = viewport_size.y / float(screen_size.y)
    var top_extra: int = clampi(int(round(float(safe.position.y) * scale_y)), 0, 48)
    if header_row != null:
        header_row.offset_top = 12.0 * _ui_scale + float(top_extra)
        header_row.offset_bottom = 166.0 * _ui_scale + float(top_extra)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_apply_ui_scale")
        call_deferred("_apply_mobile_safe_area")
        call_deferred("_layout_story_overlays")

func _bar_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = 3
    style.corner_radius_top_right = 3
    style.corner_radius_bottom_left = 3
    style.corner_radius_bottom_right = 3
    return style

func _brush_name(profile: String) -> String:
    match profile:
        "water": return "PĘDZEL WODNY"
        "confetti": return "PĘDZEL KONFETTI"
        "ink": return "PĘDZEL ATRAMENTOWY"
        "wine": return "PĘDZEL KALIGRAFICZNY"
        "organic": return "PĘDZEL ORGANICZNY"
        "dry_ink": return "SUCHY TUSZ"
        "glitch": return "PĘDZEL GLITCH"
        "glass": return "PĘDZEL SZKLISTY"
        "ember": return "PĘDZEL ŻAROWY"
        "luminous": return "PĘDZEL ŚWIETLNY"
        _: return "MIĘKKI PĘDZEL"

func _roman(value: int) -> String:
    match value:
        1: return "I"
        2: return "II"
        _: return "III"
