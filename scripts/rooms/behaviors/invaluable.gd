extends "res://scripts/rooms/behavior_base.gd"

const MIRRORS: Array[Vector2] = [Vector2(0.22, 0.35), Vector2(0.50, 0.29), Vector2(0.78, 0.35), Vector2(0.38, 0.57), Vector2(0.64, 0.57)]

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["cracked"] = []

func acts() -> Array[String]:
    return ["WEJDŹ MIĘDZY ODBICIA", "ROZBIJ CUDZĄ MIARĘ", "ZOSTAW WŁASNĄ WARTOŚĆ"]

func render(canvas, viewport_size: Vector2, progress: float, _phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#BDD9FF")), Color("bdd9ff"))
    var cracked_value: Variant = state.get("cracked", [])
    var cracked: Array = cracked_value if cracked_value is Array else []
    for index in range(MIRRORS.size()):
        var center: Vector2 = Vector2(MIRRORS[index].x * viewport_size.x, MIRRORS[index].y * viewport_size.y)
        var rect: Rect2 = Rect2(center - Vector2(34.0, 58.0), Vector2(68.0, 116.0))
        canvas.draw_rect(rect, accent.with_alpha(0.08 + progress * 0.08), false, 1.4)
        if cracked.has(index):
            for branch in range(6):
                var angle: float = float(branch) * TAU / 6.0
                canvas.draw_line(center, center + Vector2.from_angle(angle) * 46.0, Color.WHITE.with_alpha(0.26), 1.0)

func on_paint(point_norm: Vector2, radius_norm: float, _progress: float) -> Array[Dictionary]:
    var cracked_value: Variant = state.get("cracked", [])
    var cracked: Array = cracked_value if cracked_value is Array else []
    for index in range(MIRRORS.size()):
        if cracked.has(index):
            continue
        if _near(point_norm, MIRRORS[index], radius_norm + 0.09):
            cracked.append(index)
            state["cracked"] = cracked
            return [{"kind": "mirror", "index": index, "message": "Tafla pękła — odbicie traci władzę"}]
    return []
