extends Control
signal begin_requested
signal new_journey_requested
signal settings_requested
signal album_mode_requested
const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const ViryaDesign := preload("res://scripts/ui/virya_design_tokens.gd")
const DoorEyeMotif := preload("res://scripts/ui/door_eye_motif.gd")
const SignalSignupClient := preload("res://scripts/app/signal_signup_client.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")
const ViryaWorld := preload("res://scripts/app/virya_world.gd")
const ViryaRosterStrip := preload("res://scripts/ui/virya_roster_strip.gd")
const JourneyPulse := preload("res://scripts/ui/journey_pulse.gd")
const WebE2EProbe := preload("res://scripts/app/web_e2e_probe.gd")
const MENU_WORLD_PATH: String = "res://assets/v2/branding/menu-world.webp"

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
var _continue_button: Button
var _signal_client
var _api_url: String = ""
var _policy_version: String = "virya-signal-2026-08"
var _has_progress: bool = false
var _album_completed: bool = false
var _render_label: String = ""
var _journey_summary: Dictionary = {}
var _ui_scale: float = 1.0

func _ready() -> void:
    # Root is the modal input boundary; unclaimed clicks never reach the room.
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(accent: Color, has_progress: bool = false, album_completed: bool = false, api_url: String = "", policy_version: String = "virya-signal-2026-08", render_label: String = "", journey_summary: Dictionary = {}) -> void:
    _accent = accent
    _has_progress = has_progress
    _album_completed = album_completed
    _api_url = api_url
    _policy_version = policy_version
    _render_label = render_label
    _journey_summary = journey_summary.duplicate(true)
    _build()

func _build() -> void:
    UIFactory.add_signal_backdrop(self, MENU_WORLD_PATH, _accent, 0.48)
    UIFactory.add_grain(self, 0.08)

    _panel = PanelContainer.new()
    _panel.mouse_filter = Control.MOUSE_FILTER_PASS
    var panel_style := UIFactory.product_surface_style(ViryaDesign.SIGNAL, true)
    panel_style.bg_color = Color(ViryaDesign.VOID, 0.92)
    panel_style.border_color = Color(ViryaDesign.HAIRLINE, 0.96)
    _panel.add_theme_stylebox_override("panel", panel_style)
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
    eyebrow.text = "VIRYA // ODDZIAŁ SYNESTHESIA"
    eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    eyebrow.add_theme_font_size_override("font_size", 10)
    eyebrow.add_theme_color_override("font_color", ViryaDesign.SIGNAL_HOT)
    UIFactory.apply_display_font(eyebrow)
    _content_root.add_child(eyebrow)

    var title := UIFactory.heading("SYNESTHESIA")
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    title.add_theme_font_size_override("font_size", 40)
    UIFactory.apply_title_font(title)
    _content_root.add_child(title)

    var header_line := ColorRect.new()
    header_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header_line.color = Color(ViryaDesign.SIGNAL, 0.72)
    header_line.custom_minimum_size = Vector2(0.0, 1.0)
    header_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content_root.add_child(header_line)

    if not _journey_summary.is_empty():
        var journey_pulse := JourneyPulse.new()
        journey_pulse.name = "JourneyPulse"
        _content_root.add_child(journey_pulse)
        journey_pulse.configure(_journey_summary, _accent)

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
    _motif.custom_minimum_size = Vector2(220.0, 150.0)
    _motif.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _motif.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _visual_column.add_child(_motif)
    _motif.configure(_accent, "menu", Color("ef6fbd"))

    _description = UIFactory.body(_default_description())
    _description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _description.add_theme_font_size_override("font_size", 11)
    _visual_column.add_child(_description)

    var roster := ViryaRosterStrip.new()
    roster.name = "ViryaRosterV1"
    _visual_column.add_child(roster)
    roster.configure(true, true)

    if not _render_label.is_empty():
        var render_hint := Label.new()
        render_hint.text = _render_label
        UIFactory.apply_display_font(render_hint)
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
    menu_label.text = "WEJŚCIE // SESJA"
    UIFactory.apply_display_font(menu_label)
    menu_label.add_theme_font_size_override("font_size", 9)
    menu_label.add_theme_color_override("font_color", ViryaDesign.TEXT_MUTED)
    _action_column.add_child(menu_label)

    var continue_label: String = "ZOBACZ FINAŁ" if _album_completed else ("WRÓĆ DO WĘDRÓWKI" if _has_progress else "PRZEKROCZ PRÓG")
    _continue_button = UIFactory.product_button(continue_label, ViryaDesign.SIGNAL_HOT, true)
    _continue_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    _continue_button.pressed.connect(func() -> void: begin_requested.emit())
    _action_column.add_child(_continue_button)

    var album_mode_button := UIFactory.product_button("ALBUM MODE · KORYTARZ", ViryaDesign.SIGNAL)
    album_mode_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    album_mode_button.visible = _album_completed
    album_mode_button.pressed.connect(func() -> void: album_mode_requested.emit())
    _action_column.add_child(album_mode_button)

    var new_button := UIFactory.product_button("NOWA WĘDRÓWKA", _accent)
    new_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    new_button.visible = _has_progress or _album_completed
    new_button.pressed.connect(func() -> void: new_journey_requested.emit())
    _action_column.add_child(new_button)

    var utility_divider := UIFactory.signal_rule(_accent, 0.22)
    _action_column.add_child(utility_divider)
    var utility_label := Label.new()
    utility_label.text = "KARTA SESJI // SYGNAŁ // USTAWIENIA"
    UIFactory.apply_display_font(utility_label)
    utility_label.add_theme_font_size_override("font_size", 8)
    utility_label.add_theme_color_override("font_color", ViryaDesign.TEXT_DIM)
    _action_column.add_child(utility_label)

    var settings_button := UIFactory.product_button("USTAWIENIA", ViryaDesign.SIGNAL_DEEP)
    settings_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    settings_button.pressed.connect(func() -> void: settings_requested.emit())
    _action_column.add_child(settings_button)

    var signal_button := UIFactory.product_button("SYGNAŁ", ViryaDesign.SIGNAL)
    signal_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    signal_button.tooltip_text = "Dołącz do Sygnału VIRYA bez udziału w losowaniu Synesthesii"
    signal_button.pressed.connect(_toggle_signal_form)
    _action_column.add_child(signal_button)

    var creators_button := UIFactory.product_button("ZESPÓŁ VIRYA · ŚWIAT", ViryaDesign.SIGNAL_DEEP)
    creators_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    creators_button.tooltip_text = "TWÓRCY · persony · świat VIRYA"
    creators_button.pressed.connect(_show_creators)
    _action_column.add_child(creators_button)

    var exit_label: String = "WRÓĆ DO VIRYA.MUSIC" if OS.has_feature("web") else "WYJDŹ"
    var exit_button := UIFactory.product_button(exit_label, ViryaDesign.TEXT_DIM)
    exit_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    exit_button.pressed.connect(_exit_requested)
    _action_column.add_child(exit_button)

    # Accepted V2 board: actions read as a left-side navigation rail while the
    # world art remains visible as the hero, rather than living inside a giant card.
    _layout.move_child(_action_column, 0)
    _build_signal_form()
    _layout_columns()
    _apply_ui_scale()
    WebE2EProbe.control_action_deferred("menu", "continueRect", _continue_button, get_viewport_rect().size)

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

    var divider := UIFactory.signal_rule(ViryaDesign.SIGNAL, 0.24)
    _signal_form.add_child(divider)
    var heading := Label.new()
    heading.text = "SYGNAŁ // POŁĄCZENIE"
    heading.add_theme_font_size_override("font_size", 10)
    heading.add_theme_color_override("font_color", ViryaDesign.SIGNAL_HOT)
    _signal_form.add_child(heading)

    var note := UIFactory.body("Koncerty, premiery i ważne wiadomości od VIRYA. Ten zapis nie daje losu w puli 5 płyt — los dostajesz tylko za ukończenie Synesthesii.")
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    note.add_theme_font_size_override("font_size", 10)
    _signal_form.add_child(note)

    _signal_email = UIFactory.line_edit("Twój e-mail", ViryaDesign.SIGNAL)
    _signal_form.add_child(_signal_email)

    _signal_city = UIFactory.option_button(ViryaDesign.SIGNAL)
    _signal_city.add_item("Wczytuję miasta…")
    _signal_city.disabled = true
    _signal_form.add_child(_signal_city)

    _signal_consent = UIFactory.check_box("Chcę otrzymywać informacje od VIRYA.", ViryaDesign.SIGNAL)
    _signal_form.add_child(_signal_consent)

    _signal_status = UIFactory.body("")
    _signal_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _signal_status.add_theme_font_size_override("font_size", 9)
    _signal_status.add_theme_color_override("font_color", ViryaDesign.SIGNAL_HOT)
    _signal_form.add_child(_signal_status)

    _signal_submit = UIFactory.product_button("WŁĄCZ SYGNAŁ", ViryaDesign.SIGNAL, true)
    _signal_submit.pressed.connect(_submit_signal)
    _signal_form.add_child(_signal_submit)

    var my_signal_button := UIFactory.product_button("OTWÓRZ MÓJ SYGNAŁ", ViryaDesign.SIGNAL_DEEP)
    my_signal_button.tooltip_text = "Otwórz panel Virya Signal bezpośrednio"
    my_signal_button.pressed.connect(func() -> void:
        OS.shell_open(SignalCtaState.my_signal_url("", "synesthesia-menu"))
    )
    _signal_form.add_child(my_signal_button)

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
    _signal_status.text = "%s Możesz też otworzyć My Signal bezpośrednio poniżej." % message
    _signal_submit.disabled = false

func _show_creators() -> void:
    _signal_form.visible = false
    var summary := ViryaWorld.summary_text()
    var characters := ViryaWorld.characters_blurb()
    _description.text = "%s\n\n%s" % [summary, characters] if not characters.is_empty() else summary

func _restore_description() -> void:
    _description.text = _default_description()

func _default_description() -> String:
    return "Jedenaście komnat jednego oddziału utkanych z obrazu, szumu i muzyki. Dotykaj znaków, prowadź światło i budź echa ruchem dłoni. To nie test ani diagnoza — każda komnata odpowiada inaczej, a za ostatnim progiem czeka Sygnał. Stała rama należy do VIRYA; wnętrze każdego pokoju ma własny język."

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
    var wide := viewport.x >= 760.0 * _ui_scale and viewport.x / maxf(1.0, viewport.y) >= 0.82
    if wide:
        var margin := UiMetrics.safe_margin(viewport, clampf(viewport.x * 0.028, 18.0 * _ui_scale, 54.0 * _ui_scale))
        var width := minf(520.0 * _ui_scale, viewport.x * 0.46)
        var height := minf(980.0 * _ui_scale, viewport.y - margin * 2.0)
        _panel.anchor_left = 0.0
        _panel.anchor_right = 0.0
        _panel.anchor_top = 0.5
        _panel.anchor_bottom = 0.5
        _panel.offset_left = margin
        _panel.offset_right = margin + width
        _panel.offset_top = -height * 0.5
        _panel.offset_bottom = height * 0.5
        _panel.custom_minimum_size = Vector2(width, height)
    else:
        var margin := UiMetrics.safe_margin(viewport, clampf(minf(viewport.x, viewport.y) * 0.035, 14.0 * _ui_scale, 38.0 * _ui_scale))
        var width := maxf(320.0 * _ui_scale, viewport.x - margin * 2.0)
        var height := minf(1050.0 * _ui_scale, maxf(560.0 * _ui_scale, viewport.y - margin * 2.0))
        _panel.set_anchors_preset(Control.PRESET_CENTER)
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
    # V2 menu is intentionally a navigation rail over world art on every aspect ratio.
    _layout.vertical = true
    if _action_column != null:
        _action_column.custom_minimum_size = Vector2(0.0, 0.0)
    if _visual_column != null:
        _visual_column.custom_minimum_size = Vector2(0.0, 180.0 * _ui_scale)
    if _motif != null:
        _motif.custom_minimum_size = Vector2(0.0, 120.0 * _ui_scale)

func _apply_ui_scale() -> void:
    if _panel != null: UiMetrics.apply_tree(_panel, _ui_scale)

func _looks_like_email(value: String) -> bool:
    var at: int = value.find("@")
    var dot: int = value.rfind(".")
    return at > 0 and dot > at + 1 and dot < value.length() - 1 and value.length() <= 254

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_layout_panel")
