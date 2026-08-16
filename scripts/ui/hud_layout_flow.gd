extends Node
const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const SettingsGearIcon := preload("res://scripts/ui/settings_gear_icon.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")
const MobileInstructionBuilder := preload("res://scripts/ui/mobile_instruction_builder.gd")
const PORTRAIT_ASPECT_THRESHOLD: float = 0.82
const PORTRAIT_HEADER_HEIGHT: float = 172.0
const PORTRAIT_PANEL_HEIGHT: float = 152.0
var app: Control
func bind(owner: Control) -> void:
    app = owner
func _apply_ui_scale() -> void:
    var viewport_size: Vector2 = app.get_viewport_rect().size
    app._ui_scale = UiMetrics.scale_for_viewport(viewport_size)
    UiMetrics.apply_tree(app, app._ui_scale)
    var portrait: bool = viewport_size.x / maxf(1.0, viewport_size.y) <= PORTRAIT_ASPECT_THRESHOLD
    var header_height: float = PORTRAIT_HEADER_HEIGHT if portrait else 166.0
    var panel_height: float = PORTRAIT_PANEL_HEIGHT if portrait else 146.0
    if app.header_row != null:
        app.header_row.offset_left = 12.0 * app._ui_scale
        app.header_row.offset_right = -12.0 * app._ui_scale
        app.header_row.offset_top = 12.0 * app._ui_scale
        app.header_row.offset_bottom = header_height * app._ui_scale
    if app.top_panel != null:
        app.top_panel.custom_minimum_size.y = panel_height * app._ui_scale
    if app.bottom_panel != null:
        app.bottom_panel.custom_minimum_size.y = panel_height * app._ui_scale
    if app.instruction_label != null:
        app.instruction_label.custom_minimum_size.y = (34.0 if portrait else 22.0) * app._ui_scale
    if app.bottom_margin != null:
        app.bottom_margin.visible = not portrait
    if app.top_margin != null:
        app.top_margin.size_flags_stretch_ratio = 1.0 if portrait else 1.18
    if app.mobile_instruction_panel != null:
        app.mobile_instruction_panel.visible = portrait
    _layout_story_overlays()
    _apply_mobile_safe_area()
func _build_header_row() -> void:
    app.header_row = HBoxContainer.new()
    app.header_row.name = "HeaderRow"
    app.header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    app.header_row.add_theme_constant_override("separation", 8)
    add_child(app.header_row)
    app.header_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
    app.header_row.offset_left = 12.0
    app.header_row.offset_right = -12.0
    app.header_row.offset_top = 12.0
    app.header_row.offset_bottom = 166.0
func _build_top() -> void:
    app.top_margin = MarginContainer.new()
    app.top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    app.top_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    app.top_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
    app.top_margin.size_flags_stretch_ratio = 1.18
    app.header_row.add_child(app.top_margin)
    app.top_panel = PanelContainer.new()
    app.top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    app.top_panel.custom_minimum_size = Vector2(0.0, 146.0)
    app.top_panel.add_theme_stylebox_override("panel", UIFactory.product_inset_style(app._accent, 0.22))
    app.top_margin.add_child(app.top_panel)
    var shell := HBoxContainer.new()
    shell.add_theme_constant_override("separation", 10)
    app.top_panel.add_child(shell)
    app.top_accent_bar = ColorRect.new()
    app.top_accent_bar.color = app._accent
    app.top_accent_bar.custom_minimum_size = Vector2(3.0, 0.0)
    app.top_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shell.add_child(app.top_accent_bar)
    app.top_content = VBoxContainer.new()
    app.top_content.name = "TopContent"
    app.top_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    app.top_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    app.top_content.add_theme_constant_override("separation", 4)
    shell.add_child(app.top_content)
    var content: VBoxContainer = app.top_content
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0.0, 48.0)
    row.add_theme_constant_override("separation", 7)
    content.add_child(row)
    app.counter_label = Label.new()
    app.counter_label.name = "RoomCounter"
    app.counter_label.custom_minimum_size = Vector2(48.0, 22.0)
    app.counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    UIFactory.apply_display_font(app.counter_label)
    app.counter_label.add_theme_font_size_override("font_size", 10)
    app.counter_label.add_theme_color_override("font_color", Color("88bfff"))
    row.add_child(app.counter_label)
    app.split_label = Label.new()
    app.split_label.name = "SplitDelta"
    app.split_label.visible = false
    app.split_label.custom_minimum_size = Vector2(68.0, 22.0)
    app.split_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    UIFactory.apply_display_font(app.split_label)
    app.split_label.add_theme_font_size_override("font_size", 9)
    app.split_label.add_theme_color_override("font_color", Color("8fe3b0"))
    row.add_child(app.split_label)
    app.title_label = Label.new()
    app.title_label.name = "RoomTitle"
    app.title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    app.title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    app.title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    UIFactory.apply_title_font(app.title_label)
    app.title_label.add_theme_font_size_override("font_size", 15)
    app.title_label.add_theme_color_override("font_color", Color("f4f7fb"))
    row.add_child(app.title_label)
    app.settings_button = UIFactory.button("", true)
    var settings_gear: Control = SettingsGearIcon.new()
    settings_gear.name = "SettingsGearIcon"
    settings_gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
    settings_gear.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    app.settings_button.add_child(settings_gear)
    app.settings_button.custom_minimum_size = Vector2(48.0, 48.0)
    app.settings_button.size_flags_horizontal = Control.SIZE_SHRINK_END
    app.settings_button.mouse_filter = Control.MOUSE_FILTER_STOP
    app.settings_button.tooltip_text = "Ustawienia doświadczenia"
    app.settings_button.pressed.connect(func() -> void: app.settings_requested.emit())
    row.add_child(app.settings_button)
    app.subtitle_label = Label.new()
    app.subtitle_label.name = "RoomSubtitle"
    app.subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    app.subtitle_label.custom_minimum_size = Vector2(0.0, 28.0)
    app.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    app.subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    app.subtitle_label.add_theme_font_size_override("font_size", 10)
    app.subtitle_label.add_theme_color_override("font_color", Color("b6c4d5"))
    content.add_child(app.subtitle_label)
    app.progress_row = HBoxContainer.new()
    app.progress_row.name = "RevealProgressRow"
    app.progress_row.custom_minimum_size = Vector2(0.0, 16.0)
    app.progress_row.add_theme_constant_override("separation", 7)
    content.add_child(app.progress_row)
    app.progress_bar = ProgressBar.new()
    app.progress_bar.name = "RevealProgress"
    app.progress_bar.min_value = 0.0
    app.progress_bar.max_value = 1.0
    app.progress_bar.show_percentage = false
    app.progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    app.progress_bar.custom_minimum_size = Vector2(0.0, 5.0)
    app.progress_bar.add_theme_stylebox_override("background", _bar_style(Color("0b1320d9")))
    app.progress_bar.add_theme_stylebox_override("fill", _bar_style(app._accent))
    app.progress_row.add_child(app.progress_bar)
    app.progress_label = Label.new()
    app.progress_label.name = "RevealProgressLabel"
    app.progress_label.custom_minimum_size = Vector2(108.0, 16.0)
    app.progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    app.progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    UIFactory.apply_display_font(app.progress_label)
    app.progress_label.add_theme_font_size_override("font_size", 9)
    app.progress_label.add_theme_color_override("font_color", Color("8ec4ff"))
    app.progress_row.add_child(app.progress_label)
    app.journey_row = HBoxContainer.new()
    app.journey_row.name = "JourneyRow"
    app.journey_row.custom_minimum_size = Vector2(0.0, 6.0)
    app.journey_row.alignment = BoxContainer.ALIGNMENT_CENTER
    app.journey_row.add_theme_constant_override("separation", 4)
    content.add_child(app.journey_row)
func _build_bottom() -> void:
    app.bottom_margin = MarginContainer.new()
    app.bottom_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    app.bottom_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    app.bottom_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
    app.bottom_margin.size_flags_stretch_ratio = 0.82
    app.header_row.add_child(app.bottom_margin)
    app.bottom_panel = PanelContainer.new()
    app.bottom_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    app.bottom_panel.custom_minimum_size = Vector2(0.0, 146.0)
    app.bottom_panel.add_theme_stylebox_override("panel", UIFactory.product_inset_style(Color("f0cf88"), 0.18))
    app.bottom_margin.add_child(app.bottom_panel)
    var shell := HBoxContainer.new()
    shell.add_theme_constant_override("separation", 10)
    app.bottom_panel.add_child(shell)
    app.bottom_accent_bar = ColorRect.new()
    app.bottom_accent_bar.color = Color("f3d39d")
    app.bottom_accent_bar.custom_minimum_size = Vector2(3.0, 0.0)
    app.bottom_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shell.add_child(app.bottom_accent_bar)
    app.bottom_content = VBoxContainer.new()
    app.bottom_content.name = "BottomContent"
    app.bottom_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    app.bottom_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    app.bottom_content.add_theme_constant_override("separation", 5)
    shell.add_child(app.bottom_content)
    var content: VBoxContainer = app.bottom_content
    app.act_label = Label.new()
    app.act_label.name = "ActLabel"
    app.act_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    app.act_label.custom_minimum_size = Vector2(0.0, 24.0)
    app.act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    app.act_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    app.act_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    UIFactory.apply_display_font(app.act_label)
    app.act_label.add_theme_font_size_override("font_size", 10)
    app.act_label.add_theme_color_override("font_color", Color("f0d39d"))
    content.add_child(app.act_label)
    app.instruction_label = Label.new()
    app.instruction_label.name = "InstructionLabel"
    app.instruction_label.text = "ODSŁANIAJ SCENĘ · SZUM USTĘPUJE MUZYCE"
    app.instruction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    app.instruction_label.custom_minimum_size = Vector2(0.0, 22.0)
    app.instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    UIFactory.apply_display_font(app.instruction_label)
    app.instruction_label.add_theme_font_size_override("font_size", 9)
    app.instruction_label.add_theme_color_override("font_color", Color("b5c3d4"))
    content.add_child(app.instruction_label)
    app.palette_row = HBoxContainer.new()
    app.palette_row.name = "PaletteRow"
    app.palette_row.custom_minimum_size = Vector2(0.0, 10.0)
    app.palette_row.alignment = BoxContainer.ALIGNMENT_BEGIN
    app.palette_row.add_theme_constant_override("separation", 4)
    content.add_child(app.palette_row)
    app.brush_label = Label.new()
    app.brush_label.name = "BrushLabel"
    app.brush_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    app.brush_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    app.brush_label.custom_minimum_size = Vector2(0.0, 28.0)
    UIFactory.apply_display_font(app.brush_label)
    app.brush_label.add_theme_font_size_override("font_size", 9)
    app.brush_label.add_theme_color_override("font_color", Color("8d9fb5"))
    content.add_child(app.brush_label)
func _build_mobile_instruction() -> void:
    MobileInstructionBuilder.build(app, self)
func _build_toast() -> void:
    app.toast_panel = PanelContainer.new()
    app.toast_panel.visible = false
    app.toast_panel.modulate.a = 0.0
    app.toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    app.toast_panel.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
    app.toast_panel.add_theme_stylebox_override("panel", UIFactory.product_surface_style(app._accent, true))
    add_child(app.toast_panel)
    var row: HBoxContainer = HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 10)
    app.toast_panel.add_child(row)
    app.toast_accent_bar = ColorRect.new()
    app.toast_accent_bar.color = app._accent
    app.toast_accent_bar.custom_minimum_size = Vector2(3.0, 28.0)
    app.toast_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(app.toast_accent_bar)
    app.toast_label = Label.new()
    app.toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    app.toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    app.toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    app.toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    app.toast_label.custom_minimum_size = Vector2(360.0, 0.0)
    UIFactory.apply_display_font(app.toast_label)
    app.toast_label.add_theme_font_size_override("font_size", 11)
    app.toast_label.add_theme_color_override("font_color", Color("e6f1ff"))
    row.add_child(app.toast_label)
func _build_act_banner() -> void:
    app.act_banner = PanelContainer.new()
    app.act_banner.visible = false
    app.act_banner.modulate.a = 0.0
    app.act_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    app.act_banner.add_theme_stylebox_override("panel", UIFactory.product_surface_style(Color("f0cf88"), true))
    add_child(app.act_banner)
    var row: HBoxContainer = HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 10)
    app.act_banner.add_child(row)
    app.act_accent_bar = ColorRect.new()
    app.act_accent_bar.color = Color("f3d39d")
    app.act_accent_bar.custom_minimum_size = Vector2(3.0, 26.0)
    app.act_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(app.act_accent_bar)
    app.act_banner_label = Label.new()
    app.act_banner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    app.act_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    app.act_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    app.act_banner_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    app.act_banner_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    app.act_banner_label.custom_minimum_size = Vector2(360.0, 0.0)
    UIFactory.apply_display_font(app.act_banner_label)
    app.act_banner_label.add_theme_font_size_override("font_size", 10)
    app.act_banner_label.add_theme_color_override("font_color", Color("f7e7c7"))
    row.add_child(app.act_banner_label)
    _layout_story_overlays()
func _layout_story_overlays() -> void:
    var viewport_size: Vector2 = app.get_viewport_rect().size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return
    var side: float = clampf(viewport_size.x * 0.055, 22.0 * app._ui_scale, 34.0 * app._ui_scale)
    if app.mobile_instruction_panel != null and app.mobile_instruction_panel.visible:
        app.mobile_instruction_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
        app.mobile_instruction_panel.offset_left = side
        app.mobile_instruction_panel.offset_right = -side
        app.mobile_instruction_panel.offset_top = -132.0 * app._ui_scale
        app.mobile_instruction_panel.offset_bottom = -24.0 * app._ui_scale
        app.mobile_instruction_panel.custom_minimum_size = Vector2(maxf(360.0 * app._ui_scale, viewport_size.x - side * 2.0), 108.0 * app._ui_scale)
    if app.toast_panel != null:
        app.toast_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
        app.toast_panel.offset_left = side
        app.toast_panel.offset_right = -side
        app.toast_panel.offset_top = -180.0 * app._ui_scale
        app.toast_panel.offset_bottom = -108.0 * app._ui_scale
        app.toast_panel.custom_minimum_size = Vector2(maxf(420.0 * app._ui_scale, viewport_size.x - side * 2.0), 72.0 * app._ui_scale)
        app.toast_label.custom_minimum_size = Vector2(maxf(360.0 * app._ui_scale, viewport_size.x - side * 2.0 - 58.0 * app._ui_scale), app.toast_label.custom_minimum_size.y)
    if app.act_banner != null:
        # Keep the act badge in its own top-right slot. It must never share the
        # vertical band occupied by the room instruction panel.
        var act_width: float = clampf(viewport_size.x * 0.43, 196.0 * app._ui_scale, 250.0 * app._ui_scale)
        var panel_bottom: float = 136.0 * app._ui_scale
        if app.header_row != null and app.header_row.size.y > 1.0:
            panel_bottom = app.header_row.position.y + app.header_row.size.y
        var act_top: float = panel_bottom + 8.0 * app._ui_scale
        app.act_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
        app.act_banner.offset_left = -side - act_width
        app.act_banner.offset_right = -side
        app.act_banner.offset_top = act_top
        app.act_banner.offset_bottom = act_top + 46.0 * app._ui_scale
        app.act_banner.custom_minimum_size = Vector2(act_width, 46.0 * app._ui_scale)
        app.act_banner_label.custom_minimum_size = Vector2(maxf(138.0 * app._ui_scale, act_width - 36.0 * app._ui_scale), 0.0)
        app.act_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
func _repair_runtime_refs() -> void:
    if not is_instance_valid(app.counter_label):
        app.counter_label = find_child("RoomCounter", true, false) as Label
    if not is_instance_valid(app.split_label):
        app.split_label = find_child("SplitDelta", true, false) as Label
    if not is_instance_valid(app.title_label):
        app.title_label = find_child("RoomTitle", true, false) as Label
    if not is_instance_valid(app.subtitle_label):
        app.subtitle_label = find_child("RoomSubtitle", true, false) as Label
    if not is_instance_valid(app.progress_row):
        app.progress_row = find_child("RevealProgressRow", true, false) as HBoxContainer
    if not is_instance_valid(app.progress_bar):
        app.progress_bar = find_child("RevealProgress", true, false) as ProgressBar
    if not is_instance_valid(app.progress_label):
        app.progress_label = find_child("RevealProgressLabel", true, false) as Label
    if not is_instance_valid(app.journey_row):
        app.journey_row = find_child("JourneyRow", true, false) as HBoxContainer
    if not is_instance_valid(app.act_label):
        app.act_label = find_child("ActLabel", true, false) as Label
    if not is_instance_valid(app.instruction_label):
        app.instruction_label = find_child("InstructionLabel", true, false) as Label
    if not is_instance_valid(app.mobile_instruction_panel):
        app.mobile_instruction_panel = find_child("MobileInstructionPanel", true, false) as PanelContainer
    if not is_instance_valid(app.mobile_instruction_label):
        app.mobile_instruction_label = find_child("MobileInstructionLabel", true, false) as Label
    if not is_instance_valid(app.palette_row):
        app.palette_row = find_child("PaletteRow", true, false) as HBoxContainer
    if not is_instance_valid(app.brush_label):
        app.brush_label = find_child("BrushLabel", true, false) as Label
    if not is_instance_valid(app.progress_bar) and is_instance_valid(app.progress_row):
        app.progress_bar = ProgressBar.new()
        app.progress_bar.name = "RevealProgress"
        app.progress_bar.min_value = 0.0
        app.progress_bar.max_value = 1.0
        app.progress_bar.show_percentage = false
        app.progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        app.progress_bar.custom_minimum_size = Vector2(0.0, 7.0)
        app.progress_bar.add_theme_stylebox_override("background", _bar_style(Color("0b1320d9")))
        app.progress_bar.add_theme_stylebox_override("fill", _bar_style(app._accent))
        app.progress_row.add_child(app.progress_bar)
func _apply_mobile_safe_area() -> void:
    if not OS.has_feature("mobile"):
        return
    var viewport_size: Vector2 = app.get_viewport_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return
    var insets: Vector4 = UiMetrics.safe_insets(viewport_size)
    var top_extra: float = insets.y
    var bottom_extra: float = insets.w
    if app.mobile_instruction_panel != null and app.mobile_instruction_panel.visible:
        app.mobile_instruction_panel.offset_bottom = -(24.0 * app._ui_scale + bottom_extra)
        app.mobile_instruction_panel.offset_top = app.mobile_instruction_panel.offset_bottom - 116.0 * app._ui_scale
        if app.toast_panel != null:
            app.toast_panel.offset_bottom = app.mobile_instruction_panel.offset_top - 6.0 * app._ui_scale
            app.toast_panel.offset_top = app.toast_panel.offset_bottom - 72.0 * app._ui_scale
    if app.header_row != null:
        app.header_row.offset_top = 12.0 * app._ui_scale + top_extra
        var portrait: bool = viewport_size.x / maxf(1.0, viewport_size.y) <= PORTRAIT_ASPECT_THRESHOLD
        var header_height: float = PORTRAIT_HEADER_HEIGHT if portrait else 166.0
        app.header_row.offset_bottom = header_height * app._ui_scale + top_extra
func _bar_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = 3
    style.corner_radius_top_right = 3
    style.corner_radius_bottom_left = 3
    style.corner_radius_bottom_right = 3
    return style
