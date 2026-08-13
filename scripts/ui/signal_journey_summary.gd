class_name SignalJourneySummary
extends PanelContainer

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const SignalLeaderboardPanel := preload("res://scripts/ui/signal_leaderboard_panel.gd")

func configure(summary: Dictionary, accent: Color) -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_theme_stylebox_override("panel", UIFactory.product_inset_style(accent, 0.24))
    var content := VBoxContainer.new()
    content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_theme_constant_override("separation", 4)
    add_child(content)

    var kicker := Label.new()
    kicker.text = "TWÓJ PRZEBIEG"
    UIFactory.apply_display_font(kicker)
    kicker.add_theme_font_size_override("font_size", 8)
    kicker.add_theme_color_override("font_color", accent)
    content.add_child(kicker)

    var rooms_done: int = maxi(0, int(summary.get("rooms_completed", 0)))
    var rooms_total: int = maxi(rooms_done, int(summary.get("rooms_total", rooms_done)))
    var echoes_found: int = maxi(0, int(summary.get("echoes_found", 0)))
    var echoes_total: int = maxi(echoes_found, int(summary.get("echoes_total", echoes_found)))
    var elapsed_ms: int = maxi(0, int(summary.get("elapsed_ms", 0)))
    var timed_run_complete: bool = bool(summary.get("timed_run_complete", false))
    var timed_rooms: int = maxi(0, int(summary.get("timed_rooms", 0)))
    var time_line := Label.new()
    time_line.text = "CZAS CAŁEGO ALBUMU · %s" % SignalLeaderboardPanel.format_time(elapsed_ms) if timed_run_complete else "CZAS RANKINGOWY · NIEPEŁNY POMIAR %d/%d" % [timed_rooms, rooms_total]
    UIFactory.apply_display_font(time_line)
    time_line.add_theme_font_size_override("font_size", 19)
    time_line.add_theme_color_override("font_color", Color("f2f8ff") if timed_run_complete else Color("f0cf88"))
    content.add_child(time_line)

    var personal_best_ms: int = maxi(0, int(summary.get("personal_best_total_ms", 0)))
    var completed_runs: int = maxi(0, int(summary.get("completed_runs_local", 0)))
    if personal_best_ms > 0:
        var pb := UIFactory.body("PB · %s%s" % [SignalLeaderboardPanel.format_time(personal_best_ms), " · %d przebiegów" % completed_runs if completed_runs > 1 else ""])
        pb.add_theme_font_size_override("font_size", 9)
        pb.add_theme_color_override("font_color", Color("f0cf88"))
        content.add_child(pb)

    var line := UIFactory.body("POKOJE %d/%d  ·  ECHA %d/%d" % [rooms_done, rooms_total, echoes_found, echoes_total])
    line.add_theme_font_size_override("font_size", 10)
    line.add_theme_color_override("font_color", Color("d9e8f4"))
    content.add_child(line)

    var marks_value: Variant = summary.get("journey_marks", [])
    if marks_value is Array and not (marks_value as Array).is_empty():
        var mark_labels: PackedStringArray = PackedStringArray()
        for value in marks_value as Array:
            mark_labels.append(str(value))
        var marks := UIFactory.body("ŚLADY · %s" % " · ".join(mark_labels))
        marks.add_theme_font_size_override("font_size", 9)
        marks.add_theme_color_override("font_color", Color("f0cf88"))
        content.add_child(marks)

    if echoes_total > 0 and echoes_found >= echoes_total:
        _add_full_resonance_secret(content)

    var unlock := UIFactory.body("Album Mode odblokowany · możesz wracać do dowolnego pokoju bez kasowania tej podróży.")
    unlock.add_theme_font_size_override("font_size", 9)
    unlock.add_theme_color_override("font_color", Color("8fdff0"))
    content.add_child(unlock)

func _add_full_resonance_secret(content: VBoxContainer) -> void:
    var secret_button := UIFactory.product_button("33/33 · ODSŁOŃ UKRYTY SYGNAŁ", Color("f0cf88"))
    content.add_child(secret_button)
    var secret := UIFactory.body("Wszystkie echa wróciły do jednego źródła. Pełny rezonans odblokował ukrytą wiadomość VIRYA — ten ślad istnieje tylko po znalezieniu wszystkiego.")
    secret.visible = false
    secret.modulate.a = 0.0
    secret.add_theme_font_size_override("font_size", 10)
    secret.add_theme_color_override("font_color", Color("f0cf88"))
    content.add_child(secret)
    secret_button.pressed.connect(func() -> void:
        if secret.visible:
            return
        secret.visible = true
        var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        tween.tween_property(secret, "modulate:a", 1.0, 0.34)
        secret_button.text = "PEŁNY REZONANS · 33/33"
    )
