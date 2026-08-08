extends Control

signal begin_requested
signal new_journey_requested
signal settings_requested
signal album_mode_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const DoorEyeMotif := preload("res://scripts/ui/door_eye_motif.gd")
const SignalSignupClient := preload("res://scripts/app/signal_signup_client.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")

var _accent: Color = Color("8c62ff")
var _panel: PanelContainer
var _scroll: ScrollContainer
var _content_root: VBoxContainer
var _layout: BoxContainer
var _visual_column: VBoxContainer
var _action_column: VBoxContainer
var _description: Label
var _motif
var _signal_form: VBoxContainer
var _signal_email: LineEdit
var _signal_city: OptionButton
var _signal_consent: CheckBox
var _signal_status: Label
var _signal_submit: Button
var _signal_client
var _api_url: String = ""
var _policy_version: String = "virya-signal-2026-08"
var _has_progress: bool = false
var _album_completed: bool = false
var _render_label: String = ""
var _ui_scale: float = 1.0

func _ready() -> void:
    # This root is the modal input boundary. Children receive input first;
    # unclaimed clicks stop here instead of leaking into the room underneath.
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(accent: Color, has_progress: bool = false, album_completed: bool = false, api_url: String = "", policy_version: String = "virya-signal-2026-08", render_label: String = "ADAPTIVE NATIVE") -> void:
    _accent = accent
    _has_progress = has_progress
    _album_completed = album_completed
    _api_url = api_url
    _policy_version = policy_version
    _render_label = render_label
    _build()

func _build() -> void:
    var dim := ColorRect.new()
    dim.color = Color(0.003, 0.005, 0.011, 0.90)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    UIFactory.add_grain(self, 0.24)

    _panel = PanelContainer.new()
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

    _content_root = VBoxContainer.new()
    _content_root.mouse_filter = Control.MOUSE_FILTER_PASS
    _content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _content_root.add_theme_constant_override("separation", 12)
    _scroll.add_child(_content_root)

    var eyebrow := Label.new()
    eyebrow.text = "VIRYA · ECHOES OF THE MODERN MIND"
    eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    eyebrow.add_theme_font_size_override("font_size", 10)
    eyebrow.add_theme_color_override("font_color", _accent)
    UIFactory.apply_display_font(eyebrow)
    _content_root.add_child(eyebrow)

    var title := UIFactory.heading("SYNESTHESIA")
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 40)
    title.add_theme_constant_override("outline_size", 2)
    title.add_theme_color_override("font_outline_color", Color("05060af0"))
    title.add_theme_constant_override("shadow_offset_x", 2)
    title.add_theme_constant_override("shadow_offset_y", 3)
    title.add_theme_color_override("font_shadow_color", Color(_accent, 0.24))
    _content_root.add_child(title)

    _layout = BoxContainer.new()
    _layout.mouse_filter = Control.MOUSE_FILTER_PASS
    _layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _layout.add_theme_constant_override("separation", 26)
    _content_root.add_child(_layout)

    _visual_column = VBoxContainer.new()
    _visual_column.mouse_filter = Control.MOUSE_FILTER_PASS
    _visual_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _visual_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _visual_column.add_theme_constant_override("separation", 10)
    _layout.add_child(_visual_column)

    _motif = DoorEyeMotif.new()
    _motif.name = "MenuDoorEye"
    _motif.custom_minimum_size = Vector2(260.0, 330.0)
    _motif.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _motif.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _visual_column.add_child(_motif)
    _motif.configure(_accent, "menu", Color("ef6fbd"))
    _motif.call_deferred("restart_authored_animation")

    _description = UIFactory.body("Interaktywny album w 11 pokojach. Dotykasz, przesuwasz, przytrzymujesz i odsłaniasz świat ruchem dłoni, a szum ustępuje muzyce. To nie zagadka ani test — wejdź i sprawdź, jak pokój odpowiada.")
    _description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _description.add_theme_font_size_override("font_size", 13)
    _visual_column.add_child(_description)

    var render_hint := Label.new()
    render_hint.text = _render_label
    render_hint.add_theme_font_size_override("font_size", 8)
    render_hint.add_theme_color_override("font_color", Color("71849b"))
    _visual_column.add_child(render_hint)

    _action_column = VBoxContainer.new()
    _action_column.mouse_filter = Control.MOUSE_FILTER_PASS
    _action_column.custom_minimum_size = Vector2(320.0, 0.0)
    _action_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _action_column.add_theme_constant_override("separation", 10)
    _layout.add_child(_action_column)

    var menu_label := Label.new()
    menu_label.text = "WEJDŹ GŁĘBIEJ"
    UIFactory.apply_display_font(menu_label)
    menu_label.add_theme_font_size_override("font_size", 9)
    menu_label.add_theme_color_override("font_color", Color("99a9be"))
    _action_column.add_child(menu_label)

    var continue_label: String = "ZOBACZ FINAŁ" if _album_completed else ("KONTYNUUJ" if _has_progress else "WEJDŹ DO ŚRODKA")
    var continue_button := UIFactory.menu_button(continue_label, _accent, true)
    continue_button.pressed.connect(func() -> void: begin_requested.emit())
    _action_column.add_child(continue_button)

    var album_mode_button := UIFactory.menu_button("ALBUM MODE · KORYTARZ", Color("71dcff"))
    album_mode_button.visible = _album_completed
    album_mode_button.pressed.connect(func() -> void: album_mode_requested.emit())
    _action_column.add_child(album_mode_button)

    var new_button := UIFactory.menu_button("NOWA PODRÓŻ", _accent)
    new_button.visible = _has_progress or _album_completed
    new_button.pressed.connect(func() -> void: new_journey_requested.emit())
    _action_column.add_child(new_button)

    var settings_button := UIFactory.menu_button("USTAWIENIA", _accent)
    settings_button.pressed.connect(func() -> void: settings_requested.emit())
    _action_column.add_child(settings_button)

    var signal_button := UIFactory.menu_button("SYGNAŁ", Color("71dcff"))
    signal_button.tooltip_text = "Dołącz do Sygnału VIRYA bez udziału w losowaniu Synesthesii"
    signal_button.pressed.connect(_toggle_signal_form)
    _action_column.add_child(signal_button)

    var creators_button := UIFactory.menu_button("TWÓRCY", _accent)
    creators_button.pressed.connect(_show_creators)
    _action_column.add_child(creators_button)

    var exit_label: String = "WRÓĆ DO VIRYA.MUSIC" if OS.has_feature("web") else "WYJDŹ"
    var exit_button := UIFactory.menu_button(exit_label, Color("73869d"))
    exit_button.pressed.connect(_exit_requested)
    _action_column.add_child(exit_button)

    _build_signal_form()
    _layout_columns()
    _apply_ui_scale()

    modulate.a = 0.0
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.28)

func _build_signal_form() -> void:
    _signal_form = VBoxContainer.new()
    _signal_form.mouse_filter = Control.MOUSE_FILTER_PASS
    _signal_form.visible = false
    _signal_form.add_theme_constant_override("separation", 7)
    _action_column.add_child(_signal_form)

    var divider := HSeparator.new()
    _signal_form.add_child(divider)
    var heading := Label.new()
    heading.text = "WŁĄCZ SYGNAŁ"
    heading.add_theme_font_size_override("font_size", 10)
    heading.add_theme_color_override("font_color", Color("71dcff"))
    _signal_form.add_child(heading)

    var note := UIFactory.body("Koncerty, premiery i ważne wiadomości od VIRYA. Ten zapis nie daje losu w puli 5 płyt — los dostajesz tylko za ukończenie Synesthesii.")
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    note.add_theme_font_size_override("font_size", 10)
    _signal_form.add_child(note)

    _signal_email = UIFactory.line_edit("Twój e-mail", Color("71dcff"))
    _signal_form.add_child(_signal_email)

    _signal_city = UIFactory.option_button(Color("71dcff"))
    _signal_city.add_item("Wczytuję miasta…")
    _signal_city.disabled = true
    _signal_form.add_child(_signal_city)

    _signal_consent = UIFactory.check_box("Chcę otrzymywać informacje od VIRYA.", Color("71dcff"))
    _signal_form.add_child(_signal_consent)

    _signal_status = UIFactory.body("")
    _signal_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _signal_status.add_theme_font_size_override("font_size", 9)
    _signal_status.add_theme_color_override("font_color", Color("8ccfe8"))
    _signal_form.add_child(_signal_status)

    _signal_submit = UIFactory.menu_button("WŁĄCZ SYGNAŁ", Color("71dcff"), true)
    _signal_submit.pressed.connect(_submit_signal)
    _signal_form.add_child(_signal_submit)

    _signal_client = SignalSignupClient.new()
    _signal_client.name = "SignalSignupClient"
    add_child(_signal_client)
    _signal_client.configure(_api_url)
    _signal_client.cities_loaded.connect(_on_cities_loaded)
    _signal_client.signup_finished.connect(_on_signal_signup_finished)
    _signal_client.request_failed.connect(_on_signal_request_failed)

func _toggle_signal_form() -> void:
    _signal_form.visible = not _signal_form.visible
    if _signal_form.visible:
        _description.text = "Sygnał to bezpośrednie połączenie z VIRYA — bez bezdusznego feedu. Możesz dołączyć tutaj i od razu wrócić do albumu."
        if _signal_city.item_count <= 1:
            _signal_client.load_cities()
    else:
        _restore_description()
    _layout_panel()

func _submit_signal() -> void:
    var email: String = _signal_email.text.strip_edges()
    if not _looks_like_email(email):
        _signal_status.text = "Podaj poprawny adres e-mail."
        return
    if _signal_city.disabled or _signal_city.selected < 0 or _signal_city.get_item_metadata(_signal_city.selected) == null:
        _signal_status.text = "Wybierz miasto."
        return
    if not _signal_consent.button_pressed:
        _signal_status.text = "Zaznacz zgodę, żeby włączyć Sygnał."
        return
    var city_slug: String = str(_signal_city.get_item_metadata(_signal_city.selected))
    if city_slug.is_empty():
        _signal_status.text = "Wybierz miasto."
        return
    _signal_submit.disabled = true
    _signal_status.text = "Wysyłam Sygnał…"
    _signal_client.signup(email, city_slug, _policy_version)

func _on_cities_loaded(items: Array) -> void:
    _signal_city.clear()
    _signal_city.add_item("Wybierz miasto")
    _signal_city.set_item_metadata(0, "")
    for value in items:
        if value is Dictionary:
            var slug: String = str(value.get("slug", ""))
            var name_value: String = str(value.get("name", ""))
            if slug.is_empty() or name_value.is_empty():
                continue
            _signal_city.add_item(name_value)
            _signal_city.set_item_metadata(_signal_city.item_count - 1, slug)
    _signal_city.disabled = _signal_city.item_count <= 1
    _signal_city.select(0)
    _signal_status.text = "" if not _signal_city.disabled else "Lista miast jest chwilowo niedostępna."

func _on_signal_signup_finished(message: String) -> void:
    _signal_status.text = message
    _signal_submit.disabled = true

func _on_signal_request_failed(message: String) -> void:
    _signal_status.text = message
    _signal_submit.disabled = false

func _show_creators() -> void:
    _signal_form.visible = false
    _description.text = "VIRYA · Echoes Of The Modern Mind. Muzyka staje się przestrzenią, a każdy pokój przekłada emocję utworu na obraz, ruch, dźwięk i dotyk. Synesthesia jest częścią ekosystemu VIRYA Signal."

func _restore_description() -> void:
    _description.text = "Interaktywny album w 11 pokojach. Dotykasz, przesuwasz, przytrzymujesz i odsłaniasz świat ruchem dłoni, a szum ustępuje muzyce. To nie zagadka ani test — wejdź i sprawdź, jak pokój odpowiada."

func _exit_requested() -> void:
    if OS.has_feature("web"):
        OS.shell_open("https://virya.music/?source=synesthesia-menu")
    else:
        get_tree().quit()

func _layout_panel() -> void:
    if _panel == null:
        return
    var viewport: Vector2 = get_viewport_rect().size
    _ui_scale = UiMetrics.scale_for_viewport(viewport)
    var margin: float = clampf(minf(viewport.x, viewport.y) * 0.035, 14.0 * _ui_scale, 46.0 * _ui_scale)
    _panel.set_anchors_preset(Control.PRESET_CENTER)
    # The old 860px cap came from the 540x960 design reference and made an
    # FHD-native window look like a tiny card. Scale the *layout metrics*, not
    # the rendered canvas, so text/buttons stay sharp at 1080x1920.
    var width: float = minf(1180.0 * _ui_scale, maxf(320.0 * _ui_scale, viewport.x - margin * 2.0))
    var height: float = minf(860.0 * _ui_scale, maxf(500.0 * _ui_scale, viewport.y - margin * 2.0))
    _panel.offset_left = -width * 0.5
    _panel.offset_right = width * 0.5
    _panel.offset_top = -height * 0.5
    _panel.offset_bottom = height * 0.5
    _panel.custom_minimum_size = Vector2(width, height)
    _layout_columns()
    _apply_ui_scale()

func _layout_columns() -> void:
    if _layout == null:
        return
    var viewport: Vector2 = get_viewport_rect().size
    var portrait_layout: bool = viewport.x < 820.0 * _ui_scale or viewport.x / maxf(1.0, viewport.y) < 0.82
    _layout.vertical = portrait_layout
    if _visual_column != null:
        _visual_column.custom_minimum_size = Vector2(0.0, 300.0 * _ui_scale if portrait_layout else 0.0)
    if _motif != null:
        _motif.custom_minimum_size = Vector2(0.0, 245.0 * _ui_scale) if portrait_layout else Vector2(340.0 * _ui_scale, 430.0 * _ui_scale)
    if _action_column != null:
        _action_column.custom_minimum_size = Vector2(0.0 if portrait_layout else 330.0 * _ui_scale, 0.0)

func _apply_ui_scale() -> void:
    if _panel == null:
        return
    UiMetrics.apply_tree(_panel, _ui_scale)

func _looks_like_email(value: String) -> bool:
    var at: int = value.find("@")
    var dot: int = value.rfind(".")
    return at > 0 and dot > at + 1 and dot < value.length() - 1 and value.length() <= 254

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_layout_panel")
