class_name SignalLeaderboardPanel
extends VBoxContainer

signal publish_requested
signal refresh_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")

var _status: Label
var _list: VBoxContainer
var _publish: Button

func configure(summary: Dictionary, _scroll: ScrollContainer) -> void:
    add_theme_constant_override("separation", 8)
    var divider := HSeparator.new()
    divider.modulate = Color(1.0, 1.0, 1.0, 0.16)
    add_child(divider)

    var title := Label.new()
    title.text = "TABLICA SYGNAŁU · TOP 10"
    UIFactory.apply_display_font(title)
    title.add_theme_font_size_override("font_size", 13)
    title.add_theme_color_override("font_color", Color("7fd7ef"))
    add_child(title)

    var own_time := UIFactory.body("TWÓJ CZAS · %s" % format_time(maxi(0, int(summary.get("elapsed_ms", 0)))))
    own_time.add_theme_font_size_override("font_size", 16)
    own_time.add_theme_color_override("font_color", Color("f2f8ff"))
    add_child(own_time)

    _list = VBoxContainer.new()
    _list.name = "LeaderboardTop10"
    _list.add_theme_constant_override("separation", 3)
    add_child(_list)

    var privacy := UIFactory.body("Publikacja jest dobrowolna. CrowdRelay pokaże wyłącznie zamaskowany adres, np. woj••••, i Twój najlepszy czas. Pełny e-mail, konto Signal i urządzenie nigdy nie trafiają na publiczną listę. Ranking nie wpływa na losowanie.")
    privacy.add_theme_font_size_override("font_size", 11)
    privacy.add_theme_color_override("font_color", Color("9eafc3"))
    add_child(privacy)

    _status = UIFactory.body("Ładuję TOP 10…")
    _status.add_theme_font_size_override("font_size", 11)
    _status.add_theme_color_override("font_color", Color("82d7ff"))
    add_child(_status)

    _publish = UIFactory.product_button("DODAJ ANONIMOWO DO TOP", Color("7fd7ef"))
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
            var row := Label.new()
            row.text = "%02d · %s · %s" % [rank, name.left(20), format_time(elapsed_ms)]
            UIFactory.apply_display_font(row)
            row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
            row.add_theme_font_size_override("font_size", 12 if rank <= 3 else 11)
            row.add_theme_color_override("font_color", Color("f0cf88") if rank <= 3 else Color("d9e8f4"))
            _list.add_child(row)
    set_status("TOP 10 aktualne · liczy się najlepszy przebieg jednej osoby.")

func set_publish_result(context: Dictionary) -> void:
    var rank: int = maxi(1, int(context.get("rank", 1)))
    var best_elapsed_ms: int = maxi(0, int(context.get("best_elapsed_ms", 0)))
    var alias: String = str(context.get("display_name", "•••"))
    set_status("Zapisane jako %s · miejsce #%d · PB %s" % [alias, rank, format_time(best_elapsed_ms)])

func set_status(text_value: String) -> void:
    if _status != null:
        _status.text = text_value

func set_publish_enabled(value: bool) -> void:
    if _publish != null:
        _publish.disabled = not value
        if not value:
            _status.text = "Połącz wynik z Sygnałem lub użyj e-maila do losowania, aby opublikować go anonimowo."

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
