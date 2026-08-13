class_name SignalLeaderboardPanel
extends VBoxContainer

signal publish_requested
signal refresh_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")

var _status: Label
var _list: VBoxContainer
var _publish: Button
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
    divider.modulate = Color(1.0, 1.0, 1.0, 0.16)
    add_child(divider)

    var title := Label.new()
    title.text = "TABLICA SYGNAŁU · TOP 10"
    UIFactory.apply_display_font(title)
    title.add_theme_font_size_override("font_size", 13)
    title.add_theme_color_override("font_color", Color("7fd7ef"))
    add_child(title)

    var own_time_text: String
    if _timed_run_complete:
        own_time_text = "TWÓJ CZAS CAŁEGO ALBUMU · %s" % format_time(maxi(0, int(summary.get("elapsed_ms", 0))))
    else:
        own_time_text = "WYNIK RANKINGOWY · BRAK PEŁNEGO POMIARU (%d/%d POKOI)" % [_timed_rooms, _room_total]
    var own_time := UIFactory.body(own_time_text)
    own_time.add_theme_font_size_override("font_size", 16)
    own_time.add_theme_color_override("font_color", Color("f2f8ff") if _timed_run_complete else Color("f0cf88"))
    add_child(own_time)

    _list = VBoxContainer.new()
    _list.name = "LeaderboardTop10"
    _list.add_theme_constant_override("separation", 3)
    add_child(_list)

    var privacy := UIFactory.body("Publikacja jest dobrowolna. CrowdRelay pokaże wyłącznie zamaskowany adres, np. woj••••, i Twój najlepszy pełny czas. Pełny e-mail, konto Signal i urządzenie nigdy nie trafiają na publiczną listę. Ranking nie wpływa na losowanie.")
    privacy.add_theme_font_size_override("font_size", 11)
    privacy.add_theme_color_override("font_color", Color("9eafc3"))
    add_child(privacy)

    _status = UIFactory.body(_default_status())
    _status.add_theme_font_size_override("font_size", 11)
    _status.add_theme_color_override("font_color", Color("82d7ff"))
    add_child(_status)

    _publish = UIFactory.product_button("OPUBLIKUJ MÓJ PB W TOP 10", Color("7fd7ef"))
    _publish.disabled = true
    _publish.pressed.connect(func() -> void: publish_requested.emit())
    add_child(_publish)

    var refresh := UIFactory.product_button("ODŚWIEŻ TOP 10", Color("73869d"))
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
        empty.add_theme_color_override("font_color", Color("9eafc3"))
        _list.add_child(empty)
    else:
        var index: int = 0
        for value in items:
            if not value is Dictionary:
                continue
            index += 1
            var item: Dictionary = value as Dictionary
            var rank: int = maxi(1, int(item.get("rank", index)))
            var name: String = str(item.get("display_name", "•••"))
            var elapsed_ms: int = maxi(0, int(item.get("elapsed_ms", 0)))
            var own: bool = rank == _own_rank and not _own_alias.is_empty() and name == _own_alias
            var row := Label.new()
            row.text = "%s%02d · %s · %s" % ["▶ " if own else "", rank, name.left(20), format_time(elapsed_ms)]
            UIFactory.apply_display_font(row)
            row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
            row.add_theme_font_size_override("font_size", 13 if own else (12 if rank <= 3 else 11))
            row.add_theme_color_override("font_color", Color("7fd7ef") if own else (Color("f0cf88") if rank <= 3 else Color("d9e8f4")))
            _list.add_child(row)
    if _own_rank > 0:
        set_status("TWÓJ RANK · #%d · PB %s" % [_own_rank, format_time(_own_best_elapsed_ms)])
    elif _timed_run_complete:
        set_status("TOP 10 aktualne · liczy się najlepszy pełny przebieg jednej osoby.")
    else:
        set_status(_default_status())

func set_publish_result(context: Dictionary) -> void:
    _own_rank = maxi(1, int(context.get("rank", 1)))
    _own_best_elapsed_ms = maxi(0, int(context.get("best_elapsed_ms", 0)))
    _own_alias = str(context.get("display_name", "•••"))
    var placement: String = "TOP 10" if _own_rank <= 10 else "poza TOP 10"
    set_status("Zapisane jako %s · #%d (%s) · PB %s" % [_own_alias, _own_rank, placement, format_time(_own_best_elapsed_ms)])

func set_status(text_value: String) -> void:
    if _status != null:
        _status.text = text_value

func set_publish_enabled(value: bool) -> void:
    if _publish == null:
        return
    _publish.disabled = not value or not _timed_run_complete
    if not _timed_run_complete:
        _status.text = _default_status()
    elif not value:
        _status.text = "Aby opublikować wynik: połącz ten przebieg z Sygnałem albo użyj e-maila do losowania. Po powrocie przycisk publikacji się odblokuje."

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
