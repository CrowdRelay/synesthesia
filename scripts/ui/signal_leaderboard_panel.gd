class_name SignalLeaderboardPanel
extends VBoxContainer

signal publish_requested
signal refresh_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const ViryaDesign := preload("res://scripts/ui/virya_design_tokens.gd")
const LeaderboardIdentity := preload("res://scripts/ui/leaderboard_identity.gd")

var _status: Label
var _list: VBoxContainer
var _publish: Button
var _alias: LineEdit
var _own_alias: String = ""
var _own_rank: int = 0
var _own_best_elapsed_ms: int = 0
var _timed_run_complete: bool = false
var _timed_rooms: int = 0
var _room_total: int = 0

func configure(summary: Dictionary, _scroll: ScrollContainer) -> void:
    add_theme_constant_override("separation", 8)
    _timed_run_complete = bool(summary.get("timed_run_complete", false))
    _timed_rooms = maxi(0, int(summary.get("timed_rooms", 0)))
    _room_total = maxi(0, int(summary.get("rooms_total", 0)))

    var divider := HSeparator.new()
    divider.modulate = Color(1.0, 1.0, 1.0, 0.14)
    add_child(divider)

    var title := Label.new()
    title.text = "TABLICA ODDZIAŁU · TOP 10"
    UIFactory.apply_display_font(title)
    title.add_theme_font_size_override("font_size", 13)
    title.add_theme_color_override("font_color", ViryaDesign.SIGNAL_HOT)
    add_child(title)

    var own_time_text: String
    if _timed_run_complete:
        own_time_text = "TWÓJ CZAS CAŁEGO ALBUMU · %s" % format_time(maxi(0, int(summary.get("elapsed_ms", 0))))
    else:
        own_time_text = "WYNIK RANKINGOWY · BRAK PEŁNEGO POMIARU (%d/%d POKOI)" % [_timed_rooms, _room_total]
    var own_time := UIFactory.body(own_time_text)
    own_time.add_theme_font_size_override("font_size", 16)
    own_time.add_theme_color_override("font_color", ViryaDesign.TEXT if _timed_run_complete else ViryaDesign.WARNING)
    add_child(own_time)

    _list = VBoxContainer.new()
    _list.name = "LeaderboardTop10"
    _list.add_theme_constant_override("separation", 3)
    add_child(_list)

    _alias = UIFactory.line_edit("Nick / nazwa (opcjonalnie)", ViryaDesign.SIGNAL_HOT)
    _alias.name = "LeaderboardAlias"
    _alias.max_length = 24
    _alias.text = LeaderboardIdentity.display_name()
    _alias.text_changed.connect(func(value: String) -> void: LeaderboardIdentity.set_display_name(value))
    add_child(_alias)

    var privacy := UIFactory.body("Ranking nie wymaga maila ani konta Signal. Wpisz nick albo zostaw puste — wtedy wynik zapisze się jako „anonymous”. Ranking nie daje udziału w losowaniu 5 płyt.")
    privacy.add_theme_font_size_override("font_size", 11)
    privacy.add_theme_color_override("font_color", ViryaDesign.TEXT_MUTED)
    add_child(privacy)

    _status = UIFactory.body(_default_status())
    _status.add_theme_font_size_override("font_size", 11)
    _status.add_theme_color_override("font_color", ViryaDesign.SIGNAL_HOT)
    add_child(_status)

    _publish = UIFactory.product_button("ZAPISZ PB W TOP 10", ViryaDesign.SIGNAL_HOT)
    _publish.disabled = not _timed_run_complete
    _publish.pressed.connect(func() -> void:
        LeaderboardIdentity.set_display_name(_alias.text if _alias != null else "")
        publish_requested.emit()
    )
    add_child(_publish)

    var signal_note := UIFactory.body("Chcesz wejść do losowania 5 płyt i zostać w kontakcie z VIRYA? To osobny krok poniżej — tam potrzebny jest e-mail.")
    signal_note.add_theme_font_size_override("font_size", 10)
    signal_note.add_theme_color_override("font_color", ViryaDesign.TEXT_DIM)
    add_child(signal_note)

    var refresh := UIFactory.product_button("ODŚWIEŻ TOP 10", ViryaDesign.TEXT_DIM)
    refresh.pressed.connect(func() -> void: refresh_requested.emit())
    add_child(refresh)

func set_items(items: Array) -> void:
    if _list == null:
        return
    for child in _list.get_children():
        child.queue_free()
    if items.is_empty():
        var empty := UIFactory.body("Pierwsza publiczna pozycja może być Twoja.")
        empty.add_theme_font_size_override("font_size", 11)
        empty.add_theme_color_override("font_color", ViryaDesign.TEXT_MUTED)
        _list.add_child(empty)
    else:
        var index: int = 0
        for value in items:
            if not value is Dictionary:
                continue
            index += 1
            var item: Dictionary = value as Dictionary
            var rank: int = maxi(1, int(item.get("rank", index)))
            var name: String = str(item.get("display_name", "anonymous"))
            var elapsed_ms: int = maxi(0, int(item.get("elapsed_ms", 0)))
            var own: bool = rank == _own_rank and not _own_alias.is_empty() and name == _own_alias
            var row := Label.new()
            row.text = "%s%02d · %s · %s" % ["▶ " if own else "", rank, name.left(24), format_time(elapsed_ms)]
            UIFactory.apply_display_font(row)
            row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
            row.add_theme_font_size_override("font_size", 13 if own else (12 if rank <= 3 else 11))
            row.add_theme_color_override("font_color", ViryaDesign.SIGNAL_HOT if own else (ViryaDesign.WARNING if rank <= 3 else ViryaDesign.TEXT))
            _list.add_child(row)
    if _own_rank > 0:
        set_status("TWÓJ RANK · #%d · PB %s" % [_own_rank, format_time(_own_best_elapsed_ms)])
    elif _timed_run_complete:
        set_status("TOP 10 aktualne · liczy się najlepszy pełny przebieg z tego urządzenia.")
    else:
        set_status(_default_status())

func set_publish_result(context: Dictionary) -> void:
    _own_rank = maxi(1, int(context.get("rank", 1)))
    _own_best_elapsed_ms = maxi(0, int(context.get("best_elapsed_ms", 0)))
    _own_alias = str(context.get("display_name", LeaderboardIdentity.effective_name()))
    var placement: String = "TOP 10" if _own_rank <= 10 else "poza TOP 10"
    set_status("Zapisane jako %s · #%d (%s) · PB %s" % [_own_alias, _own_rank, placement, format_time(_own_best_elapsed_ms)])

func set_status(text_value: String) -> void:
    if _status != null:
        _status.text = text_value

func set_publish_enabled(_value: bool) -> void:
    if _publish == null:
        return
    # Leaderboard identity is intentionally independent from Signal/e-mail.
    # Server completion + a full 11/11 timed run are the only gameplay gates.
    _publish.disabled = not _timed_run_complete
    if not _timed_run_complete:
        _status.text = _default_status()

func is_publish_eligible() -> bool:
    return _timed_run_complete

func _default_status() -> String:
    if _timed_run_complete:
        return "Ładuję TOP 10…"
    return "Ten zapis nie ma czasu wszystkich 11 pokojów, więc nie może trafić do rankingu. Uruchom „PRZEJDŹ ALBUM JESZCZE RAZ” — następny pełny przebieg będzie liczony łącznie."

static func format_time(elapsed_ms: int) -> String:
    var safe_ms: int = maxi(0, elapsed_ms)
    var total_seconds: int = int(safe_ms / 1000)
    var hours: int = int(total_seconds / 3600)
    var minutes: int = int((total_seconds % 3600) / 60)
    var seconds: int = total_seconds % 60
    var millis: int = safe_ms % 1000
    if hours > 0:
        return "%d:%02d:%02d.%03d" % [hours, minutes, seconds, millis]
    return "%02d:%02d.%03d" % [minutes, seconds, millis]
