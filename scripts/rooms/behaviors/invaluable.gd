extends "res://scripts/rooms/behavior_base.gd"

const MIRRORS: Array[Vector2] = [Vector2(0.22, 0.35), Vector2(0.50, 0.29), Vector2(0.78, 0.35), Vector2(0.38, 0.57), Vector2(0.64, 0.57)]

func configure(data: Dictionary) -> void:
    super.configure(data)
    state["cracked"] = []
    state["shattered"] = []

func acts() -> Array[String]:
    return ["WEJDŹ MIĘDZY ODBICIA", "ROZBIJ CUDZĄ MIARĘ", "ZOSTAW WŁASNĄ WARTOŚĆ"]

func interaction_hint() -> String:
    return "PUKNIJ W TAFLĘ · ZRZUĆ JĄ RUCHEM"

func render(canvas, viewport_size: Vector2, progress: float, _phase: float) -> void:
    var accent: Color = Color.from_string(str(room_data.get("accent_color", "#BDD9FF")), Color("bdd9ff"))
    var cracked: Array = state.get("cracked", [])
    var shattered: Array = state.get("shattered", [])
    var cinematic_t: float = cinematic_time()
    for index in range(MIRRORS.size()):
        var center: Vector2 = Vector2(MIRRORS[index].x * viewport_size.x, MIRRORS[index].y * viewport_size.y)
        if cinematic_active() or shattered.has(index):
            var burst: float = minf(cinematic_t if cinematic_active() else 0.82, 1.6)
            for shard in range(10):
                var angle: float = float(shard) * TAU / 10.0 + float(index) * 0.41
                var speed: float = 48.0 + float((shard * 17 + index * 11) % 64)
                var distance: float = burst * speed
                var gravity: float = 54.0 * burst * burst
                var p: Vector2 = center + Vector2.from_angle(angle) * distance + Vector2(0.0, gravity)
                var tangent: Vector2 = Vector2.from_angle(angle + 0.7) * (6.0 + float(shard % 4) * 2.0)
                var alpha: float = clampf(1.0 - burst / 1.8, 0.0, 1.0)
                canvas.draw_line(p - tangent, p + tangent, Color(accent, 0.38 * alpha), 1.2)
            continue
        var rect: Rect2 = Rect2(center - Vector2(34.0, 58.0), Vector2(68.0, 116.0))
        canvas.draw_rect(rect, Color(accent, 0.08 + progress * 0.08), false, 1.4)
        if cracked.has(index):
            for branch in range(8):
                var angle: float = float(branch) * TAU / 8.0 + float(index) * 0.13
                canvas.draw_line(center, center + Vector2.from_angle(angle) * (34.0 + float(branch % 3) * 7.0), Color(Color.WHITE, 0.26), 1.0)

func on_gesture(kind: String, gesture: Dictionary, _progress: float) -> Array[Dictionary]:
    var point: Vector2 = _gesture_point(gesture)
    var cracked: Array = state.get("cracked", [])
    var shattered: Array = state.get("shattered", [])
    var index: int = _mirror_near(point, 0.11)
    if index < 0:
        return []
    if kind == "tap" and not cracked.has(index) and not shattered.has(index):
        cracked.append(index)
        state["cracked"] = cracked
        return [_interaction_event("mirror", index, "Pierwsza rysa — odbicie nie jest wyrokiem", MIRRORS[index], 0.085, 0.86)]
    if kind == "swipe" and cracked.has(index) and not shattered.has(index):
        shattered.append(index)
        state["shattered"] = shattered
        return [_interaction_event("mirror", index + 20, "Tafla zeszła ze ściany — miara została bez głosu", MIRRORS[index], 0.12, 0.96)]
    return []

func mechanic_progress() -> float:
    var cracked: Array = state.get("cracked", [])
    var shattered: Array = state.get("shattered", [])
    var score := float(cracked.size()) * 0.42 + float(shattered.size()) * 0.58
    return clampf(score / float(MIRRORS.size()), 0.0, 1.0)

func on_paint(point_norm: Vector2, radius_norm: float, _progress: float) -> Array[Dictionary]:
    var cracked: Array = state.get("cracked", [])
    for index in range(MIRRORS.size()):
        if cracked.has(index):
            continue
        if _near(point_norm, MIRRORS[index], radius_norm + 0.09):
            cracked.append(index)
            state["cracked"] = cracked
            return [_interaction_event("mirror", index, "Tafla pękła — odbicie traci władzę", MIRRORS[index], 0.075, 0.82)]
    return []

func _mirror_near(point: Vector2, radius: float) -> int:
    for index in range(MIRRORS.size()):
        if _near(point, MIRRORS[index], radius):
            return index
    return -1
