extends Control

signal draw_entry_requested(email: String)
signal leaderboard_publish_requested
signal leaderboard_refresh_requested
signal signal_context_refresh_requested
signal signal_handoff_requested
signal reset_requested
signal album_mode_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")

var _email: LineEdit
var _status: Label
var _claim: Button
var _signal_button: Button
var _server_completed: bool = false
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

    var panel := PanelContainer.new()
    panel.name = "FinaleFallbackPanel"
    panel.add_theme_stylebox_override("panel", UIFactory.product_surface_style(Color("e35f83"), true))
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.offset_left = -minf(330.0, get_viewport_rect().size.x * 0.44)
    panel.offset_right = minf(330.0, get_viewport_rect().size.x * 0.44)
    panel.offset_top = -260.0
    panel.offset_bottom = 260.0
    add_child(panel)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 12)
    panel.add_child(stack)
    var heading := UIFactory.heading("Sygnał dotarł.")
    stack.add_child(heading)
    var body := UIFactory.body("Jedenaście pokojów ukończone. Formularz pozostaje dostępny nawet wtedy, gdy rozszerzona warstwa finału nie może się uruchomić.")
    stack.add_child(body)

    _status = UIFactory.body(message)
    _status.add_theme_color_override("font_color", Color("82d7ff"))
    stack.add_child(_status)

    _signal_button = UIFactory.product_button("POŁĄCZ WYNIK Z SYGNAŁEM", Color("71dcff"))
    _signal_button.pressed.connect(_handle_signal)
    stack.add_child(_signal_button)

    _email = UIFactory.line_edit("E-mail do losowania", Color("7fd7ef"))
    stack.add_child(_email)
    _claim = UIFactory.product_button("DOŁĄCZ DO LOSOWANIA 5 PŁYT", Color("e35f83"), true)
    _claim.disabled = not server_completed
    _claim.pressed.connect(func() -> void: draw_entry_requested.emit(_email.text.strip_edges()))
    stack.add_child(_claim)

    var album_mode := UIFactory.product_button("ALBUM MODE · KORYTARZ", Color("71dcff"))
    album_mode.pressed.connect(func() -> void: album_mode_requested.emit())
    stack.add_child(album_mode)
    var replay := UIFactory.product_button("PRZEJDŹ ALBUM JESZCZE RAZ", Color("73869d"))
    replay.pressed.connect(func() -> void: reset_requested.emit())
    stack.add_child(replay)
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
    set_claim_enabled(value)
    apply_signal_context(_signal_context)

func apply_signal_context(context: Dictionary) -> void:
    _signal_context = context.duplicate(true)
    if _signal_button == null:
        return
    if bool(_signal_context.get("linked_to_fan", false)):
        _signal_button.text = "OTWÓRZ MÓJ SYGNAŁ"
        _signal_button.disabled = false
    else:
        _signal_button.text = "POŁĄCZ WYNIK Z SYGNAŁEM"
        _signal_button.disabled = not _server_completed

func _handle_signal() -> void:
    if bool(_signal_context.get("linked_to_fan", false)):
        OS.shell_open("https://virya.music/pl/my-signal/?source=synesthesia")
    elif _server_completed:
        signal_handoff_requested.emit()
    else:
        set_status("Najpierw kończę synchronizację ukończenia z CrowdRelay.")

func is_leaderboard_publish_eligible() -> bool:
    return false
func set_leaderboard_items(_items: Array) -> void: pass
func set_leaderboard_publish_result(_context: Dictionary) -> void: pass
func set_leaderboard_status(_text_value: String) -> void: pass
func set_leaderboard_publish_enabled(_value: bool) -> void: pass
