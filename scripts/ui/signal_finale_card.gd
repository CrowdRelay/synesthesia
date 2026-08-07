extends Control

signal draw_entry_requested(email: String)
signal reset_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")

var _sheet: PanelContainer
var _email: LineEdit
var _status: Label
var _claim: Button
var _accent: Color = Color("e35f83")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(server_completed: bool, saved_reward: Dictionary) -> void:
    _sheet = UIFactory.bottom_sheet(self, 620.0, _accent)
    _sheet.name = "SignalFinaleSheet"
    var content: VBoxContainer = UIFactory.modal_content(_sheet, 9)
    content.custom_minimum_size = Vector2(maxf(content.custom_minimum_size.x, 470.0), content.custom_minimum_size.y)

    var eyebrow: Label = Label.new()
    eyebrow.text = "ECHOES OF THE MODERN MIND  ·  FINAŁ"
    eyebrow.add_theme_font_size_override("font_size", 9)
    eyebrow.add_theme_color_override("font_color", Color("7fd7ef"))
    content.add_child(eyebrow)

    var heading: Label = UIFactory.heading("Sygnał dotarł.")
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    heading.add_theme_font_size_override("font_size", 28)
    content.add_child(heading)

    var body: Label = UIFactory.body("Jedenaście zakątków świadomości zostało odsłoniętych. Możesz dołączyć do losowania 5 fizycznych płyt VIRYA — jedno pełne ukończenie daje jeden los.")
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    body.add_theme_font_size_override("font_size", 12)
    content.add_child(body)

    _email = UIFactory.line_edit("E-mail do losowania", Color("7fd7ef"))
    content.add_child(_email)
    var note: Label = UIFactory.body("Jeden e-mail = jeden los. To nie zapisuje Cię do newslettera. Dane wysyłkowe podadzą dopiero zwycięzcy, poza Synesthesią.")
    note.add_theme_font_size_override("font_size", 10)
    note.add_theme_color_override("font_color", Color("9eafc3"))
    content.add_child(note)

    _status = UIFactory.body("")
    _status.add_theme_color_override("font_color", Color("82d7ff"))
    content.add_child(_status)

    _claim = UIFactory.button("Dołącz do losowania 5 płyt")
    _claim.disabled = not server_completed
    _claim.pressed.connect(_emit_claim)
    content.add_child(_claim)
    var signal_button: Button = UIFactory.button("Wzmocnij Sygnał VIRYA", true)
    signal_button.pressed.connect(func() -> void: OS.shell_open("https://virya.music/pl/signal/?source=synesthesia"))
    content.add_child(signal_button)
    if _claim.disabled:
        _status.text = "Synchronizuję ukończenie z Sygnałem. Postęp jest bezpieczny lokalnie."

    var reset_journey: Button = UIFactory.button("Przejdź album jeszcze raz · reset lokalny…", true)
    reset_journey.pressed.connect(func() -> void: reset_requested.emit())
    content.add_child(reset_journey)

    if str(saved_reward.get("status", "")) == "entered_draw":
        _status.text = str(saved_reward.get("message", "Jesteś już w losowaniu 5 płyt."))
        _claim.disabled = true

    position.y = 20.0
    modulate.a = 0.0
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.32)
    tween.tween_property(self, "position:y", 0.0, 0.38)

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
