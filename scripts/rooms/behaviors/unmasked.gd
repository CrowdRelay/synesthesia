extends "res://scripts/rooms/behavior_base.gd"

const MASKS: Array[Vector2] = [Vector2(0.27, 0.31), Vector2(0.50, 0.24), Vector2(0.73, 0.32)]

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["cracks"] = [0.0, 0.0, 0.0]

func acts() -> Array[String]:
    return ["ZOBACZ MASKI", "PĘKNIJ CEREMONIĘ", "ZOSTAW TWARZ"]

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#FFB970")), Color("ffb970"))
    var cracks_value: Variant = state.get("cracks", [0.0, 0.0, 0.0])
    var cracks: Array = cracks_value if cracks_value is Array else [0.0, 0.0, 0.0]
    var cinematic_t: float = cinematic_time()
    for index in range(MASKS.size()):
        var center: Vector2 = Vector2(MASKS[index].x * viewport_size.x, MASKS[index].y * viewport_size.y)
        var radius: float = 27.0 + float(index) * 2.0
        canvas.draw_arc(center, radius, 0.08, PI - 0.08, 24, Color(accent, 0.13 + progress * 0.12), 2.2)
        canvas.draw_arc(center, radius * 0.72, PI + 0.15, TAU - 0.15, 20, Color(accent, 0.12), 1.7)
        var crack: float = float(cracks[index]) if index < cracks.size() else 0.0
        if crack > 0.0:
            for branch in range(3):
                var angle: float = float(branch) * 2.1 + 0.4
                canvas.draw_line(center, center + Vector2.from_angle(angle) * radius * crack, Color(Color.WHITE, 0.18 + crack * 0.24), 1.1)
        if cinematic_active():
            var eye_y: float = center.y - 4.0
            var eye_dx: float = 10.0 + float(index)
            var pulse: float = 0.70 + 0.30 * sin(cinematic_t * 4.0 + float(index) * 1.7)
            for side in [-1.0, 1.0]:
                var eye: Vector2 = Vector2(center.x + side * eye_dx, eye_y)
                canvas.draw_circle(eye, 8.0, Color(accent, 0.055 * pulse))
                canvas.draw_circle(eye, 2.4, Color(accent, 0.72 * pulse))
            if index != 1:
                var mouth_open: float = 2.0 + 5.0 * (0.5 + 0.5 * sin(cinematic_t * 1.7 + float(index) * 2.3))
                var mouth_center: Vector2 = center + Vector2(0.0, 13.0)
                canvas.draw_line(mouth_center + Vector2(-9.0, -mouth_open * 0.5), mouth_center + Vector2(9.0, mouth_open * 0.5), Color(Color.BLACK, 0.46), 2.0)
                canvas.draw_line(mouth_center + Vector2(-9.0, mouth_open * 0.5), mouth_center + Vector2(9.0, -mouth_open * 0.5), Color(Color.BLACK, 0.28), 1.4)

func on_paint(point_norm: Vector2, radius_norm: float, _progress: float) -> Array[Dictionary]:
    var cracks_value: Variant = state.get("cracks", [0.0, 0.0, 0.0])
    var cracks: Array = cracks_value if cracks_value is Array else [0.0, 0.0, 0.0]
    for index in range(MASKS.size()):
        if _near(point_norm, MASKS[index], radius_norm + 0.07):
            var previous: float = float(cracks[index])
            cracks[index] = minf(1.0, previous + 0.34)
            state["cracks"] = cracks
            if previous < 0.99 and float(cracks[index]) >= 0.99:
                return [{"kind": "mask", "index": index, "message": "Maska pękła — została twarz"}]
    return []
