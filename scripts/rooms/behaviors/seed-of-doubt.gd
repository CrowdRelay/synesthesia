extends "res://scripts/rooms/behavior_base.gd"

func acts() -> Array[String]:
    return ["ZNAJDŹ ZIARNO", "POZWÓL KORZENIOM PĘKNĄĆ", "WYROŚNIJ PONAD WĄTPLIWOŚĆ"]

func render(canvas, viewport_size: Vector2, progress: float, phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#9DE66F")), Color("9de66f"))
    var root: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.74)
    var trunk_top: Vector2 = root - Vector2(0.0, viewport_size.y * (0.10 + progress * 0.43))
    canvas.draw_line(root, trunk_top, accent.with_alpha(0.15 + progress * 0.18), 4.0 + progress * 6.0)
    var branches: int = 2 + int(floor(progress * 9.0))
    for index in range(branches):
        var ratio: float = float(index + 1) / float(branches + 1)
        var branch_origin: Vector2 = root.lerp(trunk_top, ratio)
        var side: float = -1.0 if index % 2 == 0 else 1.0
        var sway: float = sin(phase * 2.0 + float(index)) * 4.0
        var branch_end: Vector2 = branch_origin + Vector2(side * (36.0 + ratio * 54.0) + sway, -28.0 - ratio * 38.0)
        canvas.draw_line(branch_origin, branch_end, accent.with_alpha(0.12 + progress * 0.20), 1.4 + progress * 2.2)

func on_paint(point_norm: Vector2, radius_norm: float, progress: float) -> Array[Dictionary]:
    if progress > 0.30 and not bool(state.get("seed", false)) and _near(point_norm, Vector2(0.5, 0.74), radius_norm + 0.08):
        state["seed"] = true
        return [{"kind": "seed", "index": 0, "message": "Ziarno pękło — korzenie już pracują"}]
    return []
