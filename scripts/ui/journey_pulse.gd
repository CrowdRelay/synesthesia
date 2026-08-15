extends PanelContainer

const UIFactory := preload("res://scripts/ui/ui_factory.gd")

var _accent: Color = Color("e73535")

func configure(summary: Dictionary, accent: Color) -> void:
    _accent = accent
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_theme_stylebox_override("panel", UIFactory.product_inset_style(accent, 0.18))
    var stack := VBoxContainer.new()
    stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.add_theme_constant_override("separation", 5)
    add_child(stack)

    var eyebrow := _label("TWÓJ ŚLAD", 8, Color("8ba0b9"))
    stack.add_child(eyebrow)
    var rooms: int = maxi(0, int(summary.get("rooms_completed", 0)))
    var room_total: int = maxi(1, int(summary.get("rooms_total", 11)))
    var echoes: int = maxi(0, int(summary.get("echoes_found", 0)))
    var echo_total: int = maxi(0, int(summary.get("echoes_total", 0)))
    var primary := _label("POKOJE %d/%d · ECHA %d/%d" % [rooms, room_total, echoes, echo_total], 11, Color("eaf4ff"))
    stack.add_child(primary)

    var rail := HBoxContainer.new()
    rail.name = "JourneyPulseRail"
    rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rail.add_theme_constant_override("separation", 3)
    stack.add_child(rail)
    for index in range(room_total):
        var segment := ColorRect.new()
        segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
        segment.custom_minimum_size = Vector2(0.0, 3.0)
        segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        segment.color = Color(accent, 0.82 if index < rooms else (0.42 if index == rooms and rooms < room_total else 0.13))
        rail.add_child(segment)

    var detail_parts := PackedStringArray()
    var mastery: int = clampi(int(summary.get("mastery_average", 0)), 0, 100)
    if mastery > 0:
        detail_parts.append("REZONANS %d/100" % mastery)
    var s_rooms: int = maxi(0, int(summary.get("mastery_s_rooms", 0)))
    if s_rooms > 0:
        detail_parts.append("S ×%d" % s_rooms)
    var pb_ms: int = maxi(0, int(summary.get("personal_best_total_ms", 0)))
    if pb_ms > 0:
        detail_parts.append("PB %s" % _format_time(pb_ms))
    var detail := _label(" · ".join(detail_parts) if not detail_parts.is_empty() else "KAŻDY POKÓJ PAMIĘTA TWÓJ DOTYK", 8, Color("9fb3ca"))
    stack.add_child(detail)

func _label(text_value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text_value
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    UIFactory.apply_display_font(label)
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label

func _format_time(ms: int) -> String:
    var total_seconds: int = int(maxi(0, ms) / 1000)
    return "%d:%02d" % [int(total_seconds / 60), total_seconds % 60]
