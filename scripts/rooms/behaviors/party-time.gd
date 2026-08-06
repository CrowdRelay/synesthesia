extends "res://scripts/rooms/behavior_base.gd"

const BALLOONS: Array[Vector2] = [
    Vector2(0.18, 0.30), Vector2(0.36, 0.22), Vector2(0.58, 0.28),
    Vector2(0.78, 0.20), Vector2(0.26, 0.48), Vector2(0.69, 0.50),
]

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["popped"] = []

func acts() -> Array[String]:
    return ["WEJDŹ NA IMPREZĘ", "PRZEBIJ POWŁOKĘ", "ZRÓB KOLOROWY BAŁAGAN"]

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#FFDB63")), Color("ffdb63"))
    var secondary: Color = Color.from_string(str(room_data.get("secondary_color", "#FF5EAA")), Color("ff5eaa"))
    var popped_value: Variant = state.get("popped", [])
    var popped: Array = popped_value if popped_value is Array else []
    for index in range(BALLOONS.size()):
        if popped.has(index):
            continue
        var center: Vector2 = Vector2(BALLOONS[index].x * viewport_size.x, BALLOONS[index].y * viewport_size.y)
        center.y += sin(phase * 4.0 + float(index)) * 5.0
        var color: Color = accent if index % 2 == 0 else secondary
        canvas.draw_circle(center, 13.0 + float(index % 3) * 2.0, color.with_alpha(0.20 + progress * 0.18))
        canvas.draw_line(center + Vector2(0.0, 14.0), center + Vector2(sin(float(index)) * 8.0, 45.0), color.with_alpha(0.18), 1.2)

func on_paint(point_norm: Vector2, radius_norm: float, _progress: float) -> Array[Dictionary]:
    var popped_value: Variant = state.get("popped", [])
    var popped: Array = popped_value if popped_value is Array else []
    for index in range(BALLOONS.size()):
        if popped.has(index):
            continue
        if _near(point_norm, BALLOONS[index], radius_norm + 0.055):
            popped.append(index)
            state["popped"] = popped
            return [{"kind": "balloon", "index": index, "message": "POP — scena nabiera koloru"}]
    return []
