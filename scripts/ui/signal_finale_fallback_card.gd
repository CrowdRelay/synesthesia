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
const SignalFinaleLayout := preload("res://scripts/ui/signal_finale_layout.gd")

var _panel: PanelContainer
var _scroll: ScrollContainer
var _layout: VBoxContainer
var _visual: VBoxContainer
var _form: VBoxContainer
var _body: Label
var _motif
var _ui_scale: float = 1.0
var _email: LineEdit
var _status: Label
var _claim: Button
var _signal_button: Button
var _server_completed: bool = false
var _signal_link_retryable: bool = false
var _signal_context: Dictionary = {}

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(server_completed: bool, saved_reward: Dictionary, _journey_summary: Dictionary = {}, signal_context: Dictionary = {}, message: String = "") -> void:
    _server_completed = server_completed
    _signal_context = signal_context.duplicate(true)
    var dim := ColorRect.new()
    dim.color = Color(0.003, 0.004, 0.010, 0.72)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(dim)

    _panel = PanelContainer.new()
    _panel.name = "FinaleFallbackPanel"
    _panel.mouse_filter = Control.MOUSE_FILTER_PASS
    _panel.add_theme_stylebox_override("panel", UIFactory.product_surface_style(ViryaDesign.DANGER, true))
    add_child(_panel)
    SignalFinaleLayout.layout_panel(self)

    _scroll = ScrollContainer.new()
    _scroll.name = "FinaleFallbackScroll"
    # Keep touch drags and scroll-bar interaction at the scrolling boundary.
    # Form descendants explicitly pass their scroll events to this container.
    _scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    _scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _scroll.scroll_deadzone = SignalFinaleLayout.MOBILE_SCROLL_DEADZONE_PX
    _scroll.scroll_vertical_custom_step = 48.0
    _scroll.follow_focus = true
    _panel.add_child(_scroll)

    _layout = VBoxContainer.new()
    _layout.name = "FinaleFallbackStack"
    _layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _layout.add_theme_constant_override("separation", 12)
    _scroll.add_child(_layout)
    var stack := _layout
    var heading := UIFactory.heading("Sygnał dotarł.")
    stack.add_child(heading)
    var body := UIFactory.body("Jedenaście pokojów ukończone. Formularz pozostaje dostępny nawet wtedy, gdy rozszerzona warstwa finału nie może się uruchomić.")
    stack.add_child(body)

    _status = UIFactory.body(message)
    _status.add_theme_color_override("font_color", ViryaDesign.SIGNAL_HOT)
    stack.add_child(_status)

    _signal_button = UIFactory.product_button("POŁĄCZ WYNIK Z SYGNAŁEM", ViryaDesign.SIGNAL)
    _signal_button.pressed.connect(_handle_signal)
    stack.add_child(_signal_button)

    _email = UIFactory.line_edit("E-mail do losowania", ViryaDesign.SIGNAL_HOT)
    stack.add_child(_email)
    _email.focus_entered.connect(_on_email_focus_entered)
    _claim = UIFactory.product_button("DOŁĄCZ DO LOSOWANIA 5 PŁYT", ViryaDesign.DANGER, true)
    _claim.disabled = not server_completed
    _claim.pressed.connect(func() -> void: draw_entry_requested.emit(_email.text.strip_edges()))
    stack.add_child(_claim)

    var album_mode := UIFactory.product_button("KORYTARZ · POWTÓRKA POKOJU", ViryaDesign.SIGNAL)
    album_mode.pressed.connect(func() -> void: album_mode_requested.emit())
    stack.add_child(album_mode)
    var replay := UIFactory.product_button("PRZEJDŹ ALBUM JESZCZE RAZ", ViryaDesign.TEXT_DIM)
    replay.pressed.connect(func() -> void: reset_requested.emit())
    stack.add_child(replay)
    SignalFinaleLayout.prepare_scroll_content(_layout)
    SignalFinaleLayout.apply_ui_scale(self)
    call_deferred("_scroll_to_start")
    apply_signal_context(_signal_context)
    if str(saved_reward.get("status", "")) == "entered_draw":
        _status.text = str(saved_reward.get("message", "Jesteś już w losowaniu 5 płyt."))
        _claim.disabled = true

func is_ready_for_input() -> bool:
    return _email != null and _claim != null and is_inside_tree()

func set_status(text_value: String) -> void:
    if _status != null:
        _status.text = text_value

func set_claim_enabled(value: bool) -> void:
    if _claim != null:
        _claim.disabled = not value

func is_claim_enabled() -> bool:
    return _claim != null and not _claim.disabled

func set_server_completed(value: bool) -> void:
    _server_completed = value
    if value:
        _signal_link_retryable = false
    set_claim_enabled(value)
    apply_signal_context(_signal_context)

func set_signal_link_retryable(value: bool) -> void:
    _signal_link_retryable = value
    apply_signal_context(_signal_context)

func apply_signal_context(context: Dictionary) -> void:
    _signal_context = context.duplicate(true)
    if _signal_button == null:
        return
    var cta: Dictionary = SignalCtaState.resolve(
        bool(_signal_context.get("linked_to_fan", false)),
        _server_completed,
        _signal_link_retryable,
        "",
        false,
    )
    _signal_button.text = str(cta.get("text", ""))
    _signal_button.disabled = bool(cta.get("disabled", false))

func _handle_signal() -> void:
    if bool(_signal_context.get("linked_to_fan", false)):
        OS.shell_open(SignalCtaState.my_signal_url("", "synesthesia"))
    elif _server_completed:
        signal_handoff_requested.emit()
    elif _signal_link_retryable:
        _signal_link_retryable = false
        _signal_button.disabled = true
        set_status("Ponawiam synchronizację ukończenia z CrowdRelay…")
        signal_link_retry_requested.emit()
    else:
        set_status("Najpierw kończę synchronizację ukończenia z CrowdRelay.")

func is_leaderboard_publish_eligible() -> bool:
    return false
func set_leaderboard_items(_items: Array) -> void: pass
func set_leaderboard_publish_result(_context: Dictionary) -> void: pass
func set_leaderboard_status(_text_value: String) -> void: pass
func set_leaderboard_publish_enabled(_value: bool) -> void: pass

func _on_email_focus_entered() -> void:
    if _scroll != null and _email != null:
        call_deferred("_ensure_email_visible")

func _ensure_email_visible() -> void:
    if _scroll != null and _email != null:
        _scroll.ensure_control_visible(_email)

func _ensure_email_visible_after_layout() -> void:
    await get_tree().process_frame
    _ensure_email_visible()

func _scroll_to_start() -> void:
    if _scroll != null:
        _scroll.scroll_vertical = 0

func _layout_panel() -> void:
    SignalFinaleLayout.layout_panel(self)

func _layout_columns() -> void:
    if _layout != null:
        _layout.custom_minimum_size.x = 0.0
        SignalFinaleLayout.prepare_scroll_content(_layout)

func _apply_ui_scale() -> void:
    SignalFinaleLayout.apply_ui_scale(self)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_layout_panel")
        call_deferred("_layout_columns")
        call_deferred("_apply_ui_scale")
        if _email != null and _email.has_focus():
            call_deferred("_ensure_email_visible_after_layout")
