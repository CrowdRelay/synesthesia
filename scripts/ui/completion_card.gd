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

func configure(title: String, message: String, next_label: String, accent: Color, identity: Dictionary = {}, performance: Dictionary = {}, objective: String = "") -> void:
    _sheet = PanelContainer.new()
    _sheet.mouse_filter = Control.MOUSE_FILTER_PASS
    _sheet.add_theme_stylebox_override("panel", UIFactory.product_surface_style(accent, true))
    add_child(_sheet)

    _content = VBoxContainer.new()
    _content.mouse_filter = Control.MOUSE_FILTER_PASS
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 7)
    _sheet.add_child(_content)

    _status = Label.new()
    _status.text = "DRZWI OTWARTE · SZUM 0% · MUZYKA 100%"
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    UIFactory.apply_display_font(_status)
    _status.add_theme_font_size_override("font_size", 8)
    _status.add_theme_color_override("font_color", accent)
    _content.add_child(_status)

    _heading = UIFactory.heading(title)
    _heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _heading.add_theme_font_size_override("font_size", 20)
    _content.add_child(_heading)

    # Navigation/listen actions are the primary completion affordance. Put them
    # before optional identity/performance copy so text wrapping can never push
    # the buttons below the visible bottom edge on short/tall mobile viewports.
    _actions = VBoxContainer.new()
    _actions.mouse_filter = Control.MOUSE_FILTER_PASS
    _actions.alignment = BoxContainer.ALIGNMENT_CENTER
    _actions.add_theme_constant_override("separation", 7)
    _content.add_child(_actions)

    _next_button = UIFactory.product_button(next_label, accent, true)
    _next_button.name = "ContinueButton"
    _next_button.custom_minimum_size = Vector2(280.0, 54.0)
    _next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _next_button.pressed.connect(func() -> void: continue_requested.emit())
    _actions.add_child(_next_button)

    _stay_button = UIFactory.product_button("Zostań i słuchaj", Color("73869d"), false)
    _stay_button.name = "ListenButton"
    _stay_button.custom_minimum_size = Vector2(220.0, 40.0)
    _stay_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _stay_button.pressed.connect(_enter_listen_mode)
    _actions.add_child(_stay_button)

    _body = UIFactory.body(message)
    _body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _body.add_theme_font_size_override("font_size", 10)
    _content.add_child(_body)

    var identity_line := _identity_line(identity)
    if not identity_line.is_empty():
        var afterglow := Label.new()
        afterglow.text = identity_line
        afterglow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        afterglow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        UIFactory.apply_display_font(afterglow)
        afterglow.add_theme_font_size_override("font_size", 8)
        afterglow.add_theme_color_override("font_color", Color("f0cf88"))
        _content.add_child(afterglow)

    _add_performance_line(performance, accent)
    if not objective.strip_edges().is_empty():
        var objective_done := Label.new()
        objective_done.text = "CEL WYKONANY · %s" % objective.strip_edges().to_upper()
        objective_done.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        objective_done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        UIFactory.apply_display_font(objective_done)
        objective_done.add_theme_font_size_override("font_size", 8)
        objective_done.add_theme_color_override("font_color", Color("9fb3ca"))
        _content.add_child(objective_done)

    _refresh_layout()

    modulate.a = 0.0
    position.y = 10.0
    var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.20)
    tween.tween_property(self, "position:y", 0.0, 0.24)

func _add_performance_line(performance: Dictionary, accent: Color) -> void:
    if performance.is_empty():
        return
    var grade := str(performance.get("grade", "")).strip_edges()
    if not grade.is_empty():
        var mastery := Label.new()
        var max_chain: int = clampi(int(performance.get("max_resonance_chain", 0)), 0, 6)
        var chain_suffix := " · ŁAŃCUCH ×%d" % max_chain if max_chain >= 2 else ""
        mastery.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        mastery.text = "REZONANS %s · %d/100%s%s" % [grade, clampi(int(performance.get("score", 0)), 0, 100), chain_suffix, " · NOWY PB" if bool(performance.get("mastery_personal_best", false)) else ""]
        UIFactory.apply_display_font(mastery)
        mastery.add_theme_font_size_override("font_size", 11)
        mastery.add_theme_color_override("font_color", Color("f0cf88") if grade == "S" or max_chain >= 6 else accent)
        _content.add_child(mastery)
    var elapsed_ms: int = maxi(0, int(performance.get("room_elapsed_ms", 0)))
    if elapsed_ms <= 0:
        return
    var previous_best: int = maxi(0, int(performance.get("previous_room_best_ms", 0)))
    var personal_best: bool = bool(performance.get("room_personal_best", false))
    var label := Label.new()
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    UIFactory.apply_display_font(label)
    label.add_theme_font_size_override("font_size", 10)
    label.add_theme_color_override("font_color", Color("f0cf88") if personal_best else accent)
    var suffix := "NOWY PB" if personal_best else "%s DO PB" % _signed_delta(elapsed_ms - previous_best)
    label.text = "CZAS POKOJU · %s · %s" % [_format_time(elapsed_ms), suffix]
    _content.add_child(label)

    if performance.has("journey_personal_best"):
        var journey_elapsed: int = maxi(0, int(performance.get("journey_elapsed_ms", 0)))
        var total_pb: bool = bool(performance.get("journey_personal_best", false))
        var total := Label.new()
        total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        UIFactory.apply_display_font(total)
        total.add_theme_font_size_override("font_size", 9)
        total.add_theme_color_override("font_color", Color("f0cf88") if total_pb else Color("9eafc3"))
        total.text = "PRZEBIEG · %s%s" % [_format_time(journey_elapsed), " · NOWY PB" if total_pb else ""]
        _content.add_child(total)

func _signed_delta(delta_ms: int) -> String:
    if delta_ms == 0:
        return "±00:00.000"
    return "%s%s" % ["+" if delta_ms > 0 else "−", _format_time(absi(delta_ms))]

func _format_time(elapsed_ms: int) -> String:
    var safe_ms: int = maxi(0, elapsed_ms)
    var total_seconds: int = int(safe_ms / 1000)
    var minutes: int = int(total_seconds / 60)
    var seconds: int = total_seconds % 60
    var millis: int = safe_ms % 1000
    return "%02d:%02d.%03d" % [minutes, seconds, millis]

func _enter_listen_mode() -> void:
    if _listening:
        return
    _listening = true
    if _body != null:
        _body.visible = false
    if _stay_button != null:
        _stay_button.visible = false
    if _status != null:
        _status.text = "PEŁNA MUZYKA · KOMNATA ODSŁONIĘTA"
    if _heading != null:
        _heading.text = "Zostań w echu — gdy poczujesz przejście, rusz dalej"
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
    var safe := UiMetrics.safe_insets(viewport)
    var margin: float = maxf(clampf(viewport.y * 0.016, 12.0, 26.0), safe.w + 8.0)
    var width: float = clampf(viewport.x * 0.88, 320.0, 760.0)
    var base_height: float = 150.0 if _listening else 220.0
    var natural_height: float = _sheet.get_combined_minimum_size().y
    var desired_height: float = maxf(base_height * _ui_scale, natural_height + 10.0 * _ui_scale)
    # Let wrapped copy grow the sheet instead of clipping the action stack. Keep
    # enough room above for the scene/HUD so completion still reads as a sheet.
    var max_height: float = maxf(190.0, viewport.y * (0.40 if _listening else 0.48))
    var height: float = minf(desired_height, max_height)
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

func _identity_line(identity: Dictionary) -> String:
    if identity.is_empty():
        return ""
    var focus := str(identity.get("focus_title", "")).strip_edges()
    return "ŚLAD VIRYATKOWA · %s" % focus if not focus.is_empty() else ""

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_refresh_layout")
