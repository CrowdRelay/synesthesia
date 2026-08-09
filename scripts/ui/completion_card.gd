extends Control

signal continue_requested
signal stay_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")

var _sheet: PanelContainer
var _content: VBoxContainer
var _body: Label
var _status: Label
var _heading: Label
var _actions: VBoxContainer
var _stay_button: Button
var _next_button: Button
var _ui_scale: float = 1.0
var _listening: bool = false

func _ready() -> void:
    # Only the visible bottom sheet owns pointer input. The full-screen host must
    # stay transparent so room/HUD controls above the sheet remain clickable.
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(title: String, message: String, next_label: String, accent: Color) -> void:
    _sheet = PanelContainer.new()
    _sheet.mouse_filter = Control.MOUSE_FILTER_PASS
    _sheet.add_theme_stylebox_override("panel", UIFactory.story_style(accent, 0.96, true))
    add_child(_sheet)

    _content = VBoxContainer.new()
    _content.mouse_filter = Control.MOUSE_FILTER_PASS
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 7)
    _sheet.add_child(_content)

    _status = Label.new()
    _status.text = "DRZWI OTWARTE · SZUM 0% · MUZYKA 100%"
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status.add_theme_font_size_override("font_size", 8)
    _status.add_theme_color_override("font_color", accent)
    _content.add_child(_status)

    _heading = UIFactory.heading(title)
    _heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _heading.add_theme_font_size_override("font_size", 20)
    _content.add_child(_heading)

    _body = UIFactory.body(message)
    _body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _body.add_theme_font_size_override("font_size", 10)
    _content.add_child(_body)

    _actions = VBoxContainer.new()
    _actions.mouse_filter = Control.MOUSE_FILTER_PASS
    _actions.alignment = BoxContainer.ALIGNMENT_CENTER
    _actions.add_theme_constant_override("separation", 7)
    _content.add_child(_actions)

    _next_button = UIFactory.menu_button(next_label, accent, true)
    _next_button.name = "ContinueButton"
    _next_button.custom_minimum_size = Vector2(280.0, 54.0)
    _next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _next_button.pressed.connect(func() -> void: continue_requested.emit())
    _actions.add_child(_next_button)

    _stay_button = UIFactory.button("Zostań i słuchaj", true)
    _stay_button.name = "ListenButton"
    _stay_button.custom_minimum_size = Vector2(220.0, 40.0)
    _stay_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _stay_button.pressed.connect(_enter_listen_mode)
    _actions.add_child(_stay_button)

    _refresh_layout()

    modulate.a = 0.0
    position.y = 10.0
    var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.20)
    tween.tween_property(self, "position:y", 0.0, 0.24)

func _enter_listen_mode() -> void:
    if _listening:
        return
    _listening = true
    if _body != null:
        _body.visible = false
    if _stay_button != null:
        _stay_button.visible = false
    if _status != null:
        _status.text = "PEŁNA MUZYKA · POKÓJ ODSŁONIĘTY"
    if _heading != null:
        _heading.text = "Zostań i słuchaj — kiedy chcesz, idź dalej"
    _refresh_layout()
    stay_requested.emit()

func is_listen_mode() -> bool:
    return _listening

func _refresh_layout() -> void:
    if _sheet == null:
        return
    var viewport := get_viewport_rect().size
    # Completion is intentionally calmer than the main menu. A 2x native UI
    # scale made this bottom sheet read like a zoomed modal on 1080x1920.
    _ui_scale = minf(UiMetrics.scale_for_viewport(viewport), 1.45)
    UiMetrics.apply_tree(_sheet, _ui_scale)
    _layout_sheet(viewport)

func _layout_sheet(viewport: Vector2 = get_viewport_rect().size) -> void:
    if _sheet == null:
        return
    var margin: float = clampf(viewport.y * 0.016, 12.0, 26.0)
    var width: float = clampf(viewport.x * 0.88, 320.0, 760.0)
    var base_height: float = 150.0 if _listening else 220.0
    var height: float = minf(base_height * _ui_scale, viewport.y * 0.34)
    height = maxf(height, 150.0 if _listening else 245.0)

    _sheet.anchor_left = 0.5
    _sheet.anchor_right = 0.5
    _sheet.anchor_top = 1.0
    _sheet.anchor_bottom = 1.0
    _sheet.offset_left = -width * 0.5
    _sheet.offset_right = width * 0.5
    _sheet.offset_top = -height - margin
    _sheet.offset_bottom = -margin

    if _content != null:
        _content.custom_minimum_size = Vector2(maxf(240.0, width - 42.0), 0.0)
    _sheet.queue_sort()

func _apply_ui_scale() -> void:
    # Kept for callers/tests; layout refresh owns scaling so custom minimum sizes
    # are never multiplied twice on native FHD/HiDPI viewports.
    _refresh_layout()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_refresh_layout")
