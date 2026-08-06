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
    for index in range(7):
        if screens.has(index):
            continue
        var column: int = index % 3
        var row: int = int(index / 3)
        var rect: Rect2 = Rect2(44.0 + float(column) * 154.0, 140.0 + float(row) * 116.0, 112.0, 70.0)
        var jitter: float = sin(phase * 26.0 + float(index)) * (1.0 - progress) * 3.0
        rect.position.x += jitter
        canvas.draw_rect(rect, Color.BLACK.with_alpha(0.18), true)
        canvas.draw_rect(rect, accent.with_alpha(0.16 + (1.0 - progress) * 0.10), false, 1.6)
        if index % 2 == 0:
            canvas.draw_line(rect.position + Vector2(8.0, 22.0), rect.end - Vector2(8.0, 22.0), secondary.with_alpha(0.18), 2.0)

func on_paint(point_norm: Vector2, radius_norm: float, _progress: float) -> Array[Dictionary]:
    var screens_value: Variant = state.get("screens", [])
    var screens: Array = screens_value if screens_value is Array else []
    for index in range(7):
        if screens.has(index):
            continue
        var column: int = index % 3
        var row: int = int(index / 3)
        var target: Vector2 = Vector2((100.0 + float(column) * 154.0) / 540.0, (175.0 + float(row) * 116.0) / 960.0)
        if _near(point_norm, target, radius_norm + 0.10):
            screens.append(index)
            state["screens"] = screens
            return [{"kind": "screen", "index": index, "message": "Ekran wygaszony — sygnał wraca do Ciebie"}]
    return []
