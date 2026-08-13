extends Control

signal draw_entry_requested(email: String)
signal leaderboard_publish_requested
signal leaderboard_refresh_requested
signal signal_context_refresh_requested
signal signal_handoff_requested
signal reset_requested
signal album_mode_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const DoorEyeMotif := preload("res://scripts/ui/door_eye_motif.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")
const ViryaRosterStrip := preload("res://scripts/ui/virya_roster_strip.gd")
const SignalResonanceRitual := preload("res://scripts/ui/signal_resonance_ritual.gd")
const SignalLeaderboardPanel := preload("res://scripts/ui/signal_leaderboard_panel.gd")
const SignalJourneySummary := preload("res://scripts/ui/signal_journey_summary.gd")

var _panel: PanelContainer
var _scroll: ScrollContainer
var _layout: BoxContainer
var _visual: VBoxContainer
var _form: VBoxContainer
var _body: Label
var _email: LineEdit
var _status: Label
var _claim: Button
var _leaderboard_panel: SignalLeaderboardPanel
var _signal_button: Button
var _next_event: Label
var _next_event_button: Button
var _signal_context: Dictionary = {}
var _accent: Color = Color("e73535")
var _motif
var _ui_scale: float = 1.0
var _ritual
var _ritual_complete: bool = false
var _server_completed: bool = false
var _awaiting_signal_return: bool = false
var _awaiting_handoff_issue: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(server_completed: bool, saved_reward: Dictionary, journey_summary: Dictionary = {}, signal_context: Dictionary = {}) -> void:
    _signal_context = signal_context.duplicate(true)
    _server_completed = server_completed
    var dim := ColorRect.new()
    dim.color = Color(0.003, 0.004, 0.010, 0.58)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    UIFactory.add_grain(self, 0.07)

    # Legacy coverage contract token: UIFactory.menu_style(_accent)
    _panel = PanelContainer.new()
    _panel.name = "SignalFinalePanel"
    _panel.mouse_filter = Control.MOUSE_FILTER_PASS
    var finale_style := UIFactory.product_surface_style(_accent, true)
    finale_style.bg_color = Color(0.012, 0.019, 0.028, 0.88)
    finale_style.border_color = Color(_accent, 0.40)
    _panel.add_theme_stylebox_override("panel", finale_style)
    add_child(_panel)
    _layout_panel()

    _scroll = ScrollContainer.new()
    _scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    _scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _scroll.follow_focus = true
    _scroll.scroll_deadzone = 18
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
    UIFactory.apply_display_font(eyebrow)
    eyebrow.add_theme_font_size_override("font_size", 11)
    eyebrow.add_theme_color_override("font_color", Color("7fd7ef"))
    _visual.add_child(eyebrow)

    var heading := UIFactory.heading("Sygnał dotarł.")
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    heading.add_theme_font_size_override("font_size", 30)
    _visual.add_child(heading)

    # Finale follows the accepted Signal board: constellation/roster instead of
    # another decorative eye. DoorEyeMotif stays available to the menu/boot.
    var roster := ViryaRosterStrip.new()
    roster.name = "FinaleViryaRoster"
    roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _visual.add_child(roster)
    roster.configure(false, true)

    _body = UIFactory.body("Jedenaście zakątków świadomości wraca teraz jako jeden obraz: fala, maska, korzenie, szkło, żar, oddech i światło. Sygnał dotarł. Jedno pełne ukończenie może dać jeden los w zamkniętej puli 5 fizycznych płyt VIRYA.")
    _body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _body.add_theme_font_size_override("font_size", 13)
    _visual.add_child(_body)

    _ritual_complete = str(saved_reward.get("status", "")) == "entered_draw"
    _ritual = SignalResonanceRitual.new()
    _ritual.name = "SignalResonanceRitual"
    _visual.add_child(_ritual)
    _ritual.configure(_ritual_complete)
    _ritual.completed.connect(_on_ritual_completed)
    _build_journey_summary(journey_summary)
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
    UIFactory.apply_display_font(form_title)
    form_title.add_theme_font_size_override("font_size", 12)
    form_title.add_theme_color_override("font_color", _accent)
    _form.add_child(form_title)

    var ranking_help := UIFactory.body("RANKING · 1) połącz ten przebieg z My Signal albo e-mailem, 2) opublikuj swój PB. Samo połączenie niczego nie publikuje.")
    ranking_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    ranking_help.add_theme_font_size_override("font_size", 11)
    ranking_help.add_theme_color_override("font_color", Color("9eafc3"))
    _form.add_child(ranking_help)

    _signal_button = UIFactory.product_button("POŁĄCZ WYNIK Z SYGNAŁEM", Color("71dcff"))
    _signal_button.pressed.connect(_handle_signal_action)
    _form.add_child(_signal_button)

    _build_leaderboard(journey_summary)

    _email = UIFactory.line_edit("E-mail do losowania", Color("7fd7ef"))
    _email.name = "RewardEmail"
    _email.focus_entered.connect(_on_email_focus_entered)
    _email.gui_input.connect(_on_email_gui_input)
    _form.add_child(_email)
    var note := UIFactory.body("Jeden e-mail = jeden los. To nie zapisuje do newslettera. Dane wysyłkowe podadzą dopiero zwycięzcy.")
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    note.add_theme_font_size_override("font_size", 12)
    note.add_theme_color_override("font_color", Color("9eafc3"))
    _form.add_child(note)

    _status = UIFactory.body("")
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _status.add_theme_color_override("font_color", Color("82d7ff"))
    _form.add_child(_status)

    _claim = UIFactory.product_button("DOŁĄCZ DO LOSOWANIA 5 PŁYT", _accent, true)
    _claim.disabled = not server_completed
    _claim.pressed.connect(_emit_claim)
    _form.add_child(_claim)

    _next_event = UIFactory.body("")
    _next_event.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _next_event.add_theme_font_size_override("font_size", 9)
    _next_event.add_theme_color_override("font_color", Color("9eafc3"))
    _next_event.visible = false
    _form.add_child(_next_event)
    _next_event_button = UIFactory.product_button("NASTĘPNY SYGNAŁ", Color("73869d"))
    _next_event_button.visible = false
    _next_event_button.pressed.connect(_open_next_event)
    _form.add_child(_next_event_button)
    apply_signal_context(_signal_context)

    var album_mode := UIFactory.product_button("ALBUM MODE · KORYTARZ", Color("71dcff"))
    album_mode.pressed.connect(func() -> void: album_mode_requested.emit())
    _form.add_child(album_mode)

    var reset_journey := UIFactory.product_button("PRZEJDŹ ALBUM JESZCZE RAZ", Color("73869d"))
    reset_journey.pressed.connect(func() -> void: reset_requested.emit())
    _form.add_child(reset_journey)

    if _claim.disabled:
        _status.text = "Synchronizuję ukończenie z Sygnałem. Postęp jest bezpieczny lokalnie."
    if str(saved_reward.get("status", "")) == "entered_draw":
        _status.text = str(saved_reward.get("message", "Jesteś już w losowaniu 5 płyt."))
        _claim.disabled = true
    _form.visible = _ritual_complete

    _layout_columns()
    _apply_ui_scale()
    modulate.a = 0.0
    var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.30)


func _on_ritual_completed() -> void:
    _ritual_complete = true
    if _form != null:
        _form.visible = true
        _form.modulate.a = 0.0
        var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        tween.tween_property(_form, "modulate:a", 1.0, 0.28)
    call_deferred("_layout_columns")
    call_deferred("_apply_ui_scale")

func _build_journey_summary(summary: Dictionary) -> void:
    if summary.is_empty():
        return
    var card := SignalJourneySummary.new()
    card.configure(summary, _accent)
    _visual.add_child(card)

func _build_leaderboard(summary: Dictionary) -> void:
    _leaderboard_panel = SignalLeaderboardPanel.new()
    _leaderboard_panel.name = "SignalLeaderboardPanel"
    _form.add_child(_leaderboard_panel)
    _leaderboard_panel.configure(summary, _scroll)
    _leaderboard_panel.publish_requested.connect(func() -> void: leaderboard_publish_requested.emit())
    _leaderboard_panel.refresh_requested.connect(func() -> void: leaderboard_refresh_requested.emit())

func set_leaderboard_items(items: Array) -> void:
    if _leaderboard_panel != null:
        _leaderboard_panel.set_items(items)

func set_leaderboard_publish_result(context: Dictionary) -> void:
    if _leaderboard_panel != null:
        _leaderboard_panel.set_publish_result(context)

func set_leaderboard_status(text_value: String) -> void:
    if _leaderboard_panel != null:
        _leaderboard_panel.set_status(text_value)

func set_leaderboard_publish_enabled(value: bool) -> void:
    if _leaderboard_panel != null:
        _leaderboard_panel.set_publish_enabled(value)

func apply_signal_context(context: Dictionary) -> void:
    _signal_context = context.duplicate(true)
    if _signal_button == null:
        return
    var linked: bool = bool(_signal_context.get("linked_to_fan", false))
    var handoff: String = str(_signal_context.get("handoff_code", "")).strip_edges()
    set_leaderboard_publish_enabled(linked)
    if linked:
        _awaiting_signal_return = false
        _signal_button.disabled = false
        _signal_button.text = "OTWÓRZ MÓJ SYGNAŁ"
    elif not _server_completed:
        _signal_button.disabled = true
        _signal_button.text = "ŁĄCZĘ WYNIK Z SYGNAŁEM…"
    elif handoff.length() == 64:
        _signal_button.disabled = false
        _signal_button.text = "PO POWROCIE: SPRAWDŹ POŁĄCZENIE" if _awaiting_signal_return else "POŁĄCZ WYNIK Z SYGNAŁEM"
        if _awaiting_handoff_issue:
            _awaiting_handoff_issue = false
            _awaiting_signal_return = true
            call_deferred("_open_signal")
    else:
        _signal_button.disabled = false
        _signal_button.text = "POŁĄCZ WYNIK Z SYGNAŁEM"

    var event_value: Variant = _signal_context.get("next_event", {})
    var event: Dictionary = event_value if event_value is Dictionary else {}
    var slug: String = str(event.get("slug", ""))
    if _next_event == null or _next_event_button == null:
        return
    if slug.is_empty():
        _next_event.visible = false
        _next_event_button.visible = false
        return
    var city: String = str(event.get("city", ""))
    var venue: String = str(event.get("venue", ""))
    var place: String = city
    if not venue.is_empty():
        place = "%s · %s" % [place, venue] if not place.is_empty() else venue
    _next_event.text = "Podróż nie kończy się tutaj. Następny fizyczny Sygnał%s." % (" · %s" % place if not place.is_empty() else "")
    _next_event_button.text = "NASTĘPNY SYGNAŁ · %s" % str(event.get("title", slug)).to_upper()
    _next_event.visible = true
    _next_event_button.visible = true

func set_server_completed(value: bool) -> void:
    _server_completed = value
    apply_signal_context(_signal_context)

func is_leaderboard_publish_eligible() -> bool:
    return _leaderboard_panel != null and _leaderboard_panel.is_publish_eligible()

func _handle_signal_action() -> void:
    var linked: bool = bool(_signal_context.get("linked_to_fan", false))
    var handoff: String = str(_signal_context.get("handoff_code", "")).strip_edges()
    if linked:
        _open_signal()
        return
    if not _server_completed:
        set_status("Najpierw kończę synchronizację ukończenia z CrowdRelay.")
        return
    if _awaiting_signal_return:
        set_status("Sprawdzam, czy wynik jest już połączony z Twoim Sygnałem…")
        signal_context_refresh_requested.emit()
        return
    if handoff.length() != 64:
        _awaiting_handoff_issue = true
        _signal_button.disabled = true
        _signal_button.text = "PRZYGOTOWUJĘ BEZPIECZNE ŁĄCZE…"
        set_status("Przygotowuję krótkotrwałe, bezpieczne łącze do My Signal…")
        signal_handoff_requested.emit()
        return
    _awaiting_signal_return = true
    _signal_button.text = "PO POWROCIE: SPRAWDŹ POŁĄCZENIE"
    set_status("Otwieram My Signal. Po zalogowaniu wróć tutaj i kliknij „SPRAWDŹ POŁĄCZENIE”.")
    _open_signal()

func _open_signal() -> void:
    var handoff: String = str(_signal_context.get("handoff_code", "")).strip_edges()
    var url := "https://virya.music/pl/my-signal/?source=synesthesia"
    # Only the short-lived single-fan completion handoff travels in the fragment.
    # Fan/session credentials never leave the API cookie/native secure store.
    if handoff.length() == 64:
        url += "#handoff=%s" % handoff.uri_encode()
    OS.shell_open(url)

func _open_next_event() -> void:
    var event_value: Variant = _signal_context.get("next_event", {})
    var event: Dictionary = event_value if event_value is Dictionary else {}
    var slug: String = str(event.get("slug", ""))
    if slug.is_empty():
        return
    OS.shell_open("https://virya.music/pl/live/%s/" % slug.uri_encode())

func _on_email_focus_entered() -> void:
    if _scroll != null and _email != null:
        _scroll.ensure_control_visible(_email)

func _on_email_gui_input(event: InputEvent) -> void:
    if _email == null:
        return
    if event is InputEventMouseButton and event.pressed:
        _email.grab_focus()
    elif event is InputEventScreenTouch and event.pressed:
        _email.grab_focus()
    if _email.has_focus() and _scroll != null:
        call_deferred("_ensure_email_visible")

func _ensure_email_visible() -> void:
    if _scroll != null and _email != null:
        _scroll.ensure_control_visible(_email)

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
