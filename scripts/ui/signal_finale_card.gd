extends Control

signal draw_entry_requested(email: String)
signal reset_requested
signal album_mode_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const DoorEyeMotif := preload("res://scripts/ui/door_eye_motif.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")

var _panel: PanelContainer
var _scroll: ScrollContainer
var _layout: BoxContainer
var _visual: VBoxContainer
var _form: VBoxContainer
var _body: Label
var _email: LineEdit
var _status: Label
var _claim: Button
var _accent: Color = Color("e35f83")
var _motif
var _ui_scale: float = 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(server_completed: bool, saved_reward: Dictionary) -> void:
    var dim := ColorRect.new()
    dim.color = Color(0.003, 0.004, 0.010, 0.76)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    UIFactory.add_grain(self, 0.20)

    _panel = PanelContainer.new()
    _panel.name = "SignalFinalePanel"
    _panel.mouse_filter = Control.MOUSE_FILTER_PASS
    _panel.add_theme_stylebox_override("panel", UIFactory.menu_style(_accent))
    add_child(_panel)
    _layout_panel()

    _scroll = ScrollContainer.new()
    _scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    _scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _panel.add_child(_scroll)

    _layout = BoxContainer.new()
    _layout.mouse_filter = Control.MOUSE_FILTER_PASS
    _layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _layout.add_theme_constant_override("separation", 24)
    _scroll.add_child(_layout)

    _visual = VBoxContainer.new()
    _visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _visual.add_theme_constant_override("separation", 10)
    _layout.add_child(_visual)

    var eyebrow := Label.new()
    eyebrow.text = "ECHOES OF THE MODERN MIND · FINAŁ"
    eyebrow.add_theme_font_size_override("font_size", 9)
    eyebrow.add_theme_color_override("font_color", Color("7fd7ef"))
    _visual.add_child(eyebrow)

    var heading := UIFactory.heading("Sygnał dotarł.")
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    heading.add_theme_font_size_override("font_size", 30)
    _visual.add_child(heading)

    _motif = DoorEyeMotif.new()
    _motif.custom_minimum_size = Vector2(260.0, 330.0)
    _motif.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _motif.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _visual.add_child(_motif)
    _motif.configure(_accent, "menu", Color("71dcff"))

    _body = UIFactory.body("Jedenaście zakątków świadomości wraca teraz jako jeden obraz: fala, maska, korzenie, szkło, żar, oddech i światło. Sygnał dotarł. Jedno pełne ukończenie może dać jeden los w zamkniętej puli 5 fizycznych płyt VIRYA.")
    _body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _body.add_theme_font_size_override("font_size", 11)
    _visual.add_child(_body)
    var memory_line := Label.new()
    memory_line.text = "FALA · KONFETTI · MASKA · WINO · KORZEŃ · POJEDYNEK · SYGNAŁ · LUSTRO · POPIÓŁ · ODDECH · ŚWIATŁO"
    memory_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    memory_line.add_theme_font_size_override("font_size", 8)
    memory_line.add_theme_color_override("font_color", Color("8fdff0"))
    _visual.add_child(memory_line)

    _form = VBoxContainer.new()
    _form.custom_minimum_size = Vector2(340.0, 0.0)
    _form.size_flags_horizontal = Control.SIZE_FILL
    _form.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _form.add_theme_constant_override("separation", 9)
    _layout.add_child(_form)

    var form_title := Label.new()
    form_title.text = "PROOF OF FAIR · 5 PŁYT"
    form_title.add_theme_font_size_override("font_size", 10)
    form_title.add_theme_color_override("font_color", _accent)
    _form.add_child(form_title)

    _email = UIFactory.line_edit("E-mail do losowania", Color("7fd7ef"))
    _form.add_child(_email)
    var note := UIFactory.body("Jeden e-mail = jeden los. To nie zapisuje do newslettera. Dane wysyłkowe podadzą dopiero zwycięzcy.")
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    note.add_theme_font_size_override("font_size", 10)
    note.add_theme_color_override("font_color", Color("9eafc3"))
    _form.add_child(note)

    _status = UIFactory.body("")
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _status.add_theme_color_override("font_color", Color("82d7ff"))
    _form.add_child(_status)

    _claim = UIFactory.menu_button("DOŁĄCZ DO LOSOWANIA 5 PŁYT", _accent, true)
    _claim.disabled = not server_completed
    _claim.pressed.connect(_emit_claim)
    _form.add_child(_claim)

    var signal_button := UIFactory.menu_button("WZMOCNIJ SYGNAŁ VIRYA", Color("71dcff"))
    signal_button.pressed.connect(func() -> void: OS.shell_open("https://virya.music/pl/signal/?source=synesthesia"))
    _form.add_child(signal_button)

    var album_mode := UIFactory.menu_button("ALBUM MODE · KORYTARZ", Color("71dcff"))
    album_mode.pressed.connect(func() -> void: album_mode_requested.emit())
    _form.add_child(album_mode)

    var reset_journey := UIFactory.menu_button("PRZEJDŹ ALBUM JESZCZE RAZ", Color("73869d"))
    reset_journey.pressed.connect(func() -> void: reset_requested.emit())
    _form.add_child(reset_journey)

    if _claim.disabled:
        _status.text = "Synchronizuję ukończenie z Sygnałem. Postęp jest bezpieczny lokalnie."
    if str(saved_reward.get("status", "")) == "entered_draw":
        _status.text = str(saved_reward.get("message", "Jesteś już w losowaniu 5 płyt."))
        _claim.disabled = true

    _layout_columns()
    _apply_ui_scale()
    modulate.a = 0.0
    var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.30)

func _emit_claim() -> void:
    draw_entry_requested.emit(_email.text.strip_edges())

func set_status(text_value: String) -> void:
    if _status != null:
        _status.text = text_value

func set_claim_enabled(value: bool) -> void:
    if _claim != null:
        _claim.disabled = not value

func is_claim_enabled() -> bool:
    return _claim != null and not _claim.disabled

func _layout_panel() -> void:
    if _panel == null:
        return
    var viewport := get_viewport_rect().size
    _ui_scale = UiMetrics.scale_for_viewport(viewport)
    var margin := clampf(minf(viewport.x, viewport.y) * 0.035, 14.0 * _ui_scale, 46.0 * _ui_scale)
    var width := minf(1120.0 * _ui_scale, maxf(320.0 * _ui_scale, viewport.x - margin * 2.0))
    var height := minf(820.0 * _ui_scale, maxf(500.0 * _ui_scale, viewport.y - margin * 2.0))
    _panel.set_anchors_preset(Control.PRESET_CENTER)
    _panel.offset_left = -width * 0.5
    _panel.offset_right = width * 0.5
    _panel.offset_top = -height * 0.5
    _panel.offset_bottom = height * 0.5

func _layout_columns() -> void:
    if _layout == null:
        return
    var viewport := get_viewport_rect().size
    _ui_scale = UiMetrics.scale_for_viewport(viewport)
    var portrait_layout: bool = viewport.x < 900.0 * _ui_scale or viewport.x / maxf(1.0, viewport.y) < 0.95
    _layout.vertical = portrait_layout

    var margin := clampf(minf(viewport.x, viewport.y) * 0.035, 14.0 * _ui_scale, 46.0 * _ui_scale)
    var panel_width := minf(1120.0 * _ui_scale, maxf(320.0 * _ui_scale, viewport.x - margin * 2.0))
    var usable_width := maxf(272.0 * _ui_scale, panel_width - 48.0 * _ui_scale)
    _layout.custom_minimum_size.x = usable_width

    if _visual != null:
        _visual.custom_minimum_size.x = 0.0 if portrait_layout else 380.0 * _ui_scale
        _visual.size_flags_stretch_ratio = 1.25
    if _form != null:
        _form.custom_minimum_size.x = 0.0 if portrait_layout else 340.0 * _ui_scale
    if _body != null:
        _body.custom_minimum_size.x = 0.0 if portrait_layout else 360.0 * _ui_scale
    if _motif != null:
        _motif.custom_minimum_size = Vector2(0.0, 190.0 * _ui_scale) if portrait_layout else Vector2(260.0, 330.0) * _ui_scale

func _apply_ui_scale() -> void:
    if _panel != null:
        UiMetrics.apply_tree(_panel, _ui_scale)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_layout_panel")
        call_deferred("_layout_columns")
        call_deferred("_apply_ui_scale")
