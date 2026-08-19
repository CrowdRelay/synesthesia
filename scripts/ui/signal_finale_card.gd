extends Control

signal draw_entry_requested(email: String)
signal leaderboard_publish_requested
signal leaderboard_refresh_requested
signal signal_context_refresh_requested
signal signal_handoff_requested
signal signal_link_retry_requested
signal reset_requested
signal album_mode_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const ViryaDesign := preload("res://scripts/ui/virya_design_tokens.gd")
const WebE2EProbe := preload("res://scripts/app/web_e2e_probe.gd")
const DoorEyeMotif := preload("res://scripts/ui/door_eye_motif.gd")
const SignalFinaleLayout := preload("res://scripts/ui/signal_finale_layout.gd")
const ViryaRosterStrip := preload("res://scripts/ui/virya_roster_strip.gd")
const SignalResonanceRitual := preload("res://scripts/ui/signal_resonance_ritual.gd")
const SignalLeaderboardPanel := preload("res://scripts/ui/signal_leaderboard_panel.gd")
const SignalFinaleNextEvent := preload("res://scripts/ui/signal_finale_next_event.gd")
const SignalJourneySummary := preload("res://scripts/ui/signal_journey_summary.gd"); const SignalRelayShare := preload("res://scripts/app/signal_relay_share.gd")

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
var _accent: Color = ViryaDesign.DANGER
var _motif
var _ui_scale: float = 1.0
var _ritual
var _ritual_complete: bool = false
var _server_completed: bool = false
var _awaiting_signal_return: bool = false
var _awaiting_handoff_issue: bool = false
# The handoff is held locally, not read back out of _signal_context. The status
# refresh is read-only by contract and deliberately returns no code, so a card
# that trusted the last response alone erased a link the player was still using.
var _handoff_code: String = ""
var _handoff_issued_ms: int = 0
# Linking failed, as opposed to still being in flight. See SignalCtaState.
var _signal_link_retryable: bool = false
var _configured_for_input: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(server_completed: bool, saved_reward: Dictionary, journey_summary: Dictionary = {}, signal_context: Dictionary = {}) -> void:
    _signal_context = signal_context.duplicate(true)
    _server_completed = server_completed
    var dim := ColorRect.new()
    dim.color = Color(ViryaDesign.VOID, 0.72)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    UIFactory.add_grain(self, 0.07)

    # Legacy coverage contract token: UIFactory.menu_style(_accent)
    _panel = PanelContainer.new()
    _panel.name = "SignalFinalePanel"
    _panel.mouse_filter = Control.MOUSE_FILTER_PASS
    var finale_style := UIFactory.product_surface_style(_accent, true)
    finale_style.bg_color = Color(ViryaDesign.VOID, 0.94)
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
    _scroll.scroll_vertical_custom_step = 48.0
    _scroll.follow_focus = true
    _scroll.scroll_deadzone = SignalFinaleLayout.MOBILE_SCROLL_DEADZONE_PX
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
    eyebrow.text = "VIRYA // WYPIS Z ODDZIAŁU // FINAŁ"
    UIFactory.apply_display_font(eyebrow)
    eyebrow.add_theme_font_size_override("font_size", 11)
    eyebrow.add_theme_color_override("font_color", ViryaDesign.SIGNAL_HOT)
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
    memory_line.add_theme_color_override("font_color", ViryaDesign.SIGNAL_HOT)
    _visual.add_child(memory_line)

    _form = VBoxContainer.new()
    _form.custom_minimum_size = Vector2(340.0, 0.0)
    _form.size_flags_horizontal = Control.SIZE_FILL
    _form.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _form.add_theme_constant_override("separation", 9)
    _layout.add_child(_form)

    var form_title := Label.new()
    form_title.text = "WYPIS // SYGNAŁ DOTARŁ // 5 PŁYT"
    UIFactory.apply_display_font(form_title)
    form_title.add_theme_font_size_override("font_size", 12)
    form_title.add_theme_color_override("font_color", _accent)
    _form.add_child(form_title)

    var ranking_help := UIFactory.body("RANKING · 1) połącz ten przebieg z My Signal albo e-mailem, 2) opublikuj swój PB. Samo połączenie niczego nie publikuje.")
    ranking_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    ranking_help.add_theme_font_size_override("font_size", 11)
    ranking_help.add_theme_color_override("font_color", ViryaDesign.TEXT_MUTED)
    _form.add_child(ranking_help)

    _signal_button = UIFactory.product_button("POŁĄCZ WYNIK Z SYGNAŁEM", ViryaDesign.SIGNAL)
    _signal_button.pressed.connect(_handle_signal_action)
    _form.add_child(_signal_button)

    _build_leaderboard(journey_summary)

    _email = UIFactory.line_edit("E-mail do losowania", ViryaDesign.SIGNAL_HOT)
    _email.name = "RewardEmail"
    _email.focus_entered.connect(_on_email_focus_entered)
    _email.gui_input.connect(_on_email_gui_input)
    _form.add_child(_email)
    var note := UIFactory.body("Jeden e-mail = jeden los. To nie zapisuje do newslettera. Dane wysyłkowe podadzą dopiero zwycięzcy.")
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    note.add_theme_font_size_override("font_size", 12)
    note.add_theme_color_override("font_color", ViryaDesign.TEXT_MUTED)
    _form.add_child(note)

    _status = UIFactory.body("")
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _status.add_theme_color_override("font_color", ViryaDesign.SIGNAL_HOT)
    _form.add_child(_status)

    _claim = UIFactory.product_button("DOŁĄCZ DO LOSOWANIA 5 PŁYT", _accent, true)
    _claim.disabled = not server_completed or not _ritual_complete
    _claim.pressed.connect(_emit_claim)
    _form.add_child(_claim)

    _next_event = UIFactory.body("")
    _next_event.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _next_event.add_theme_font_size_override("font_size", 9)
    _next_event.add_theme_color_override("font_color", ViryaDesign.TEXT_MUTED)
    _next_event.visible = false
    _form.add_child(_next_event)
    _next_event_button = UIFactory.product_button("NASTĘPNY SYGNAŁ", ViryaDesign.TEXT_DIM)
    _next_event_button.visible = false
    _next_event_button.pressed.connect(_open_next_event)
    _form.add_child(_next_event_button)
    apply_signal_context(_signal_context)

    var album_mode := UIFactory.product_button("ALBUM MODE · KORYTARZ", ViryaDesign.SIGNAL)
    album_mode.pressed.connect(func() -> void: album_mode_requested.emit())
    _form.add_child(album_mode)

    var reset_journey := UIFactory.product_button("PRZEJDŹ ALBUM JESZCZE RAZ", ViryaDesign.TEXT_DIM)
    reset_journey.pressed.connect(func() -> void: reset_requested.emit())
    _form.add_child(reset_journey)
    SignalRelayShare.add_to(_form, ViryaDesign.SIGNAL, _status)

    if not _ritual_complete:
        _status.text = "Domknij 4 sygnały rezonansu — formularz i ranking możesz już przejrzeć."
    elif _claim.disabled:
        _status.text = "Synchronizuję ukończenie z Sygnałem. Postęp jest bezpieczny lokalnie."
    if str(saved_reward.get("status", "")) == "entered_draw":
        _status.text = str(saved_reward.get("message", "Jesteś już w losowaniu 5 płyt."))
        _claim.disabled = true
    _form.visible = true
    SignalFinaleLayout.prepare_scroll_content(_layout)
    _configured_for_input = _email != null and _claim != null and _form != null

    _layout_columns()
    _apply_ui_scale()
    call_deferred("_publish_e2e_actions")
    modulate.a = 0.0
    var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.30)


func _publish_e2e_actions() -> void:
    if not WebE2EProbe.enabled() or _signal_button == null or _claim == null: return
    await get_tree().process_frame
    var viewport := get_viewport_rect().size
    var signal_rect := _signal_button.get_global_rect()
    var claim_rect := _claim.get_global_rect()
    WebE2EProbe.emit("finale_actions", {
        "signalRect": {"x":signal_rect.position.x,"y":signal_rect.position.y,"w":signal_rect.size.x,"h":signal_rect.size.y},
        "claimRect": {"x":claim_rect.position.x,"y":claim_rect.position.y,"w":claim_rect.size.x,"h":claim_rect.size.y},
        "signalDisabled": _signal_button.disabled,
        "claimDisabled": _claim.disabled,
        "leaderboardPresent": _leaderboard_panel != null and _leaderboard_panel.is_visible_in_tree(),
        "viewportWidth": viewport.x,
        "viewportHeight": viewport.y,
    })

func is_ready_for_input() -> bool:
    return is_inside_tree() and _configured_for_input and _form != null and _form.visible and _email != null and _claim != null

func _scroll_to_start() -> void:
    if _scroll != null:
        _scroll.scroll_vertical = 0

func _on_ritual_completed() -> void:
    _ritual_complete = true
    set_claim_enabled(_server_completed)
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

## A fresh server context arrived. This is the only entry point allowed to move
## the handoff exchange forward; re-rendering alone goes through _refresh_cta().
func apply_signal_context(context: Dictionary) -> void:
    _signal_context = context.duplicate(true)
    if _signal_button == null:
        return
    var linked: bool = bool(_signal_context.get("linked_to_fan", false))
    var issued: String = str(_signal_context.get("handoff_code", "")).strip_edges()
    set_leaderboard_publish_enabled(linked)
    if SignalCtaState.is_usable_handoff(issued):
        _handoff_code = issued
        _handoff_issued_ms = Time.get_ticks_msec()
    if linked:
        # The code is spent. My Signal owns the link from here.
        _handoff_code = ""
        _awaiting_signal_return = false
        _awaiting_handoff_issue = false
    elif _awaiting_handoff_issue and SignalCtaState.is_usable_handoff(issued):
        _awaiting_handoff_issue = false
        _hand_over_to_signal()
    elif _awaiting_signal_return:
        # A check that came back unlinked must return the route, not leave the
        # player pressing a button that can only ever re-check.
        _awaiting_signal_return = false
        if _active_handoff().is_empty():
            set_status("Łącze wygasło. Kliknij, aby przygotować nowe i połączyć wynik.")
        else:
            set_status("Jeszcze nie widzę połączenia. Otwórz My Signal i zaloguj się tym samym łączem.")
    _refresh_cta()

    SignalFinaleNextEvent.apply(_next_event, _next_event_button, _signal_context)

func set_signal_link_retryable(value: bool) -> void:
    _signal_link_retryable = value
    # A reported failure is the end of whatever attempt was in flight. Leaving
    # the issue latch armed lets an unrelated later context response open the
    # browser on its own, long after the press that asked for it.
    if value: _awaiting_handoff_issue = false
    _refresh_cta()

func set_server_completed(value: bool) -> void:
    _server_completed = value
    if value: _signal_link_retryable = false
    set_claim_enabled(value)
    _refresh_cta()

## Re-render the CTA from current state without advancing the exchange.
func _refresh_cta() -> void:
    if _signal_button == null:
        return
    var cta: Dictionary = SignalCtaState.resolve(
        bool(_signal_context.get("linked_to_fan", false)),
        _server_completed,
        _signal_link_retryable,
        _active_handoff(),
        _awaiting_signal_return,
    )
    _signal_button.disabled = bool(cta.get("disabled", false))
    _signal_button.text = str(cta.get("text", ""))

## The handoff this card may still hand to My Signal, or "" when there is none.
func _active_handoff() -> String:
    if not SignalCtaState.is_usable_handoff(_handoff_code):
        return ""
    if Time.get_ticks_msec() - _handoff_issued_ms >= SignalCtaState.HANDOFF_LOCAL_TTL_MS:
        return ""
    return _handoff_code

## A browser only honours window.open inside the click that asked for it, and
## the handoff answer lands one round trip after that click. Web therefore keeps
## the ready link on the button and opens it on the next press; native, where no
## popup blocker sits in the path, still hands the player straight over.
func _hand_over_to_signal() -> void:
    if OS.has_feature("web"):
        set_status("Bezpieczne łącze gotowe. Kliknij „OTWÓRZ MÓJ SYGNAŁ”, aby połączyć wynik z Sygnałem.")
        return
    _awaiting_signal_return = true
    set_status("Otwieram My Signal. Po zalogowaniu wróć tutaj i kliknij „SPRAWDŹ POŁĄCZENIE”.")
    call_deferred("_open_signal")

func is_leaderboard_publish_eligible() -> bool:
    return _leaderboard_panel != null and _leaderboard_panel.is_publish_eligible()

# The press must always do what the button says, so it reads the same state the
# label was resolved from and never a second, independently ordered rule.
func _handle_signal_action() -> void:
    if bool(_signal_context.get("linked_to_fan", false)):
        _open_signal()
        return
    if not _server_completed:
        if not _signal_link_retryable:
            set_status("Najpierw kończę synchronizację ukończenia z CrowdRelay.")
            return
        set_signal_link_retryable(false)
        set_status("Ponawiam synchronizację ukończenia z CrowdRelay…")
        signal_link_retry_requested.emit()
        return
    if _active_handoff().is_empty():
        # No usable link. Ask for one; the press that follows opens it, which is
        # also what keeps the browser tab inside a real user gesture on Web.
        _awaiting_handoff_issue = true
        _awaiting_signal_return = false
        _signal_button.disabled = true
        _signal_button.text = "PRZYGOTOWUJĘ BEZPIECZNE ŁĄCZE…"
        set_status("Przygotowuję krótkotrwałe, bezpieczne łącze do My Signal…")
        signal_handoff_requested.emit()
        return
    if _awaiting_signal_return:
        set_status("Sprawdzam, czy wynik jest już połączony z Twoim Sygnałem…")
        signal_context_refresh_requested.emit()
        return
    _awaiting_signal_return = true
    set_status("Otwieram My Signal. Po zalogowaniu wróć tutaj i kliknij „SPRAWDŹ POŁĄCZENIE”.")
    _open_signal()
    _refresh_cta()

func _open_signal() -> void:
    OS.shell_open(SignalCtaState.my_signal_url(_active_handoff()))

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
        _claim.disabled = not value or not _ritual_complete

func is_claim_enabled() -> bool:
    return _claim != null and not _claim.disabled

func _layout_panel() -> void:
    SignalFinaleLayout.layout_panel(self)
func _layout_columns() -> void:
    SignalFinaleLayout.layout_columns(self)
func _apply_ui_scale() -> void:
    SignalFinaleLayout.apply_ui_scale(self)
func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_layout_panel")
        call_deferred("_layout_columns")
        call_deferred("_apply_ui_scale")
