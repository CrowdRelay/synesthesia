extends "res://scripts/rooms/behavior_base.gd"

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["screens"] = []

func acts() -> Array[String]:
    return ["WEJDŹ W TRANSMISJĘ", "ODŁĄCZ EKRANY", "NAPRAW WŁASNY SYGNAŁ"]

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#6AB8FF")), Color("6ab8ff"))
    var secondary: Color = Color.from_string(str(room_data.get("secondary_color", "#FF5F7C")), Color("ff5f7c"))
    var screens_value: Variant = state.get("screens", [])
    var screens: Array = screens_value if screens_value is Array else []
    var cinematic_t: float = cinematic_time()
    for index in range(7):
        if screens.has(index) and not cinematic_active():
            continue
        var column: int = index % 3
        var row: int = int(floor(float(index) / 3.0))
        var rect: Rect2 = Rect2(44.0 + float(column) * 154.0, 140.0 + float(row) * 116.0, 112.0, 70.0)
        var jitter_strength: float = (1.0 - progress) * 3.0
        if cinematic_active():
            jitter_strength = 4.0 + 7.0 * (0.5 + 0.5 * sin(cinematic_t * 7.0 + float(index)))
        var jitter: float = sin(phase * 26.0 + float(index)) * jitter_strength
        rect.position.x += jitter
        canvas.draw_rect(rect, Color(Color.BLACK, 0.18), true)
        canvas.draw_rect(rect, Color(accent, 0.16 + (1.0 - progress) * 0.10), false, 1.6)
        if index % 2 == 0:
            canvas.draw_line(rect.position + Vector2(8.0, 22.0), rect.end - Vector2(8.0, 22.0), Color(secondary, 0.18), 2.0)
        if cinematic_active():
            var band_y: float = rect.position.y + fmod(cinematic_t * (42.0 + float(index) * 3.0), rect.size.y)
            canvas.draw_rect(Rect2(rect.position.x, band_y, rect.size.x, 3.0), Color(accent, 0.28), true)
    if cinematic_active():
        for index in range(7):
            var y: float = fmod(cinematic_t * (73.0 + float(index) * 9.0) + float(index) * 117.0, viewport_size.y)
            var x_offset: float = sin(cinematic_t * 14.0 + float(index)) * 18.0
            canvas.draw_line(Vector2(0.0, y), Vector2(viewport_size.x + x_offset, y), Color(accent if index % 2 == 0 else secondary, 0.045), 1.0 + float(index % 3))

func on_paint(point_norm: Vector2, radius_norm: float, _progress: float) -> Array[Dictionary]:
    var screens_value: Variant = state.get("screens", [])
    var screens: Array = screens_value if screens_value is Array else []
    for index in range(7):
        if screens.has(index):
            continue
        var column: int = index % 3
        var row: int = int(floor(float(index) / 3.0))
        var target: Vector2 = Vector2((100.0 + float(column) * 154.0) / 540.0, (175.0 + float(row) * 116.0) / 960.0)
        if _near(point_norm, target, radius_norm + 0.10):
            screens.append(index)
            state["screens"] = screens
            return [{"kind": "screen", "index": index, "message": "Ekran wygaszony — sygnał wraca do Ciebie"}]
    return []
