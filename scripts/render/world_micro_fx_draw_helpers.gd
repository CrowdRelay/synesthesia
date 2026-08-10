extends RefCounted

static func draw_living_state(owner: Control, style: String, accent: Color, secondary: Color, alpha: float, live: float, t: float) -> void:
        var c := Vector2(owner.size.x * 0.5, owner.size.y * 0.52)
        match style:
            "technophobia":
                var sweep := fmod(t * 0.11, 1.0)
                var y := owner.size.y * lerpf(0.18, 0.72, sweep)
                owner.draw_line(Vector2(owner.size.x * 0.12, y), Vector2(owner.size.x * 0.88, y), Color(accent, alpha * live * 0.30), 1.0)
                for i in range(3):
                    var spark_phase := fmod(t * (0.19 + i * 0.04) + i * 0.37, 1.0)
                    if spark_phase < 0.055:
                        var p := Vector2(owner.size.x * (0.23 + i * 0.27), owner.size.y * (0.31 + i * 0.09))
                        owner.draw_line(p, p + Vector2(5.0 + i * 2.0, -7.0), Color(secondary, live * 0.32), 1.2)
                for i in range(4):
                    var p := Vector2(owner.size.x * (0.20 + i * 0.19), owner.size.y * (0.25 + float(i % 2) * 0.18))
                    owner.draw_arc(p, 6.0 + sin(t * 0.9 + i) * 2.0, -2.8, 2.8, 24, Color(Color.WHITE, alpha * live * 0.12), 1.0)
            "unmasked":
                var pulse := 0.5 + 0.5 * sin(t * 0.82)
                var hub := Vector2(owner.size.x * 0.5, owner.size.y * 0.43)
                owner.draw_arc(hub, owner.size.x * (0.11 + pulse * 0.012), -2.8, 2.8, 64, Color(secondary, alpha * live * 1.05), 1.6)
                owner.draw_arc(hub, owner.size.x * (0.16 + pulse * 0.010), -2.4, 2.4, 64, Color(accent, alpha * live * 0.42), 1.0)
                for i in range(13):
                    var p := Vector2(fmod(float(i) * 71.0 + t * (5.0 + i % 3), owner.size.x), fmod(float(i) * 113.0 - t * (7.0 + i % 4) + owner.size.y, owner.size.y))
                    owner.draw_circle(p, 0.7 + i % 2, Color(Color.WHITE, alpha * live * 0.24))
                for i in range(4):
                    var top := Vector2(owner.size.x * (0.24 + i * 0.17), owner.size.y * 0.19)
                    var sway := sin(t * (0.42 + i * 0.05) + i) * 9.0
                    owner.draw_line(top, top + Vector2(sway * 0.22, 72.0 + i * 9.0), Color(accent if i % 2 else secondary, alpha * live * 0.20), 1.0)
                for i in range(5):
                    var gleam := fmod(t * (0.10 + i * 0.02) + i * 0.28, 1.0)
                    var start := Vector2(owner.size.x * (0.22 + i * 0.14), owner.size.y * (0.30 + i * 0.018))
                    var end := start + Vector2(42.0, -55.0)
                    var p := start.lerp(end, gleam)
                    owner.draw_line(p - Vector2(5, 5), p + Vector2(5, 5), Color(Color.WHITE, alpha * live * 0.44), 1.1)
            "invaluable":
                for i in range(12):
                    var a := float(i) * 0.57 + t * (0.11 + i * 0.002)
                    var radius := owner.size.x * (0.10 + float(i % 4) * 0.042)
                    var p := c + Vector2.from_angle(a) * radius + Vector2(sin(t * 0.31 + i) * 4.0, cos(t * 0.24 + i * 0.6) * 3.0)
                    var glint := 0.30 + 0.70 * maxf(0.0, sin(t * (1.1 + i * 0.03) + i * 0.7))
                    var d := Vector2.from_angle(a + 0.92) * (6.0 + float(i % 3) * 3.0)
                    owner.draw_line(p - d, p + d, Color(accent, alpha * live * glint * 0.95), 1.2)
                    owner.draw_line(p - Vector2(d.y, -d.x) * 0.35, p + Vector2(d.y, -d.x) * 0.35, Color(Color.WHITE, alpha * live * glint * 0.34), 0.9)
                var sweep := fmod(t * 0.085, 1.0)
                var sx := lerpf(owner.size.x * 0.18, owner.size.x * 0.82, sweep)
                owner.draw_line(Vector2(sx - 26.0, owner.size.y * 0.28), Vector2(sx + 26.0, owner.size.y * 0.76), Color(Color.WHITE, alpha * live * 0.22 * (1.0 - abs(sweep - 0.5) * 1.6)), 1.8)
                var pulse := 0.5 + 0.5 * sin(t * 0.62)
                owner.draw_arc(c, owner.size.x * (0.09 + pulse * 0.018), -2.8, 2.8, 52, Color(secondary, alpha * live * 0.20), 1.0)
                for i in range(14):
                    var dust := Vector2(fmod(float(i) * 53.0 + t * (4.5 + i % 3), owner.size.x), fmod(float(i) * 89.0 - t * (6.0 + i % 4) + owner.size.y, owner.size.y))
                    owner.draw_circle(dust, 0.6 + float(i % 2) * 0.4, Color(Color.WHITE, alpha * live * 0.10))
            "seed":
                var crown_y := owner.size.y * 0.22
                for i in range(16):
                    var travel := fmod(t * (0.055 + i * 0.002) + i * 0.067, 1.0)
                    var p := Vector2(owner.size.x * 0.5 + sin(t * 0.7 + i) * (9.0 + i % 4 * 5.0), owner.size.y * lerpf(0.76, 0.18, travel))
                    owner.draw_circle(p, 1.0 + i % 2, Color(secondary if i % 3 == 0 else accent, alpha * live * (1.0 - travel * 0.45)))
                for i in range(4):
                    var side := -1.0 if i < 2 else 1.0
                    var root := Vector2(owner.size.x * 0.5 + side * 24.0, owner.size.y * (0.64 - float(i % 2) * 0.12))
                    owner.draw_arc(root, 18.0 + i * 6.0, PI * 0.15, PI * 0.85, 22, Color(accent, alpha * live * 0.18), 1.0)
                owner.draw_arc(Vector2(owner.size.x * 0.5, crown_y), 26.0 + sin(t * 0.8) * 6.0, 0.0, TAU, 34, Color(Color.WHITE, alpha * live * 0.12), 1.0)
            "party":
                for i in range(7):
                    var center := Vector2(owner.size.x * (0.14 + (i % 4) * 0.24), owner.size.y * (0.25 + (i / 4) * 0.34))
                    center += Vector2(sin(t * (0.27 + i * 0.015) + i) * 7.0, cos(t * 0.23 + i) * 9.0)
                    var shine := 0.5 + 0.5 * sin(t * 0.73 + i * 1.7)
                    owner.draw_arc(center, 18.0 + i % 3 * 4.0, -2.55, -1.15, 20, Color(Color.WHITE, alpha * live * shine * 0.62), 1.2)
                    owner.draw_arc(center, 16.0 + i % 3 * 4.0, 0.65, 1.95, 18, Color(accent, alpha * live * 0.20), 1.0)
                    owner.draw_line(center + Vector2(0, 18), center + Vector2(sin(t * 0.45 + i) * 14.0, 68.0), Color(secondary, alpha * live * 0.22), 1.0)
                for i in range(14):
                    var ribbon := Vector2(owner.size.x * (0.08 + float(i) / 13.0 * 0.84), fmod(float(i) * 33.0 + t * (9.0 + i % 3), owner.size.y))
                    owner.draw_line(ribbon, ribbon + Vector2(sin(t * 0.8 + i) * 7.0, 11.0), Color(accent if i % 2 else secondary, alpha * live * 0.22), 1.0)
                var beat := 0.5 + 0.5 * sin(t * 0.92)
                owner.draw_arc(c, 34.0 + beat * 14.0, -2.8, 2.8, 40, Color(secondary, alpha * live * 0.20), 1.0)
            "calling":
                var altar := Vector2(owner.size.x * 0.5, owner.size.y * 0.63)
                var ripple := fmod(t * 0.19, 1.0)
                owner.draw_arc(altar, owner.size.x * (0.08 + ripple * 0.25), 0.0, TAU, 72, Color(accent, alpha * live * (1.0 - ripple) * 0.92), 1.3)
                owner.draw_arc(altar, owner.size.x * (0.06 + fmod(t * 0.14 + 0.35, 1.0) * 0.18), 0.0, TAU, 72, Color(secondary, alpha * live * 0.30), 1.0)
                for uv in [Vector2(0.23,0.58), Vector2(0.34,0.67), Vector2(0.66,0.67), Vector2(0.77,0.58)]:
                    var p: Vector2 = uv * owner.size
                    var flicker := 0.55 + 0.45 * sin(t * 6.2 + p.x * 0.017) * sin(t * 1.7 + p.y * 0.013)
                    var flame := PackedVector2Array([p + Vector2(-2.6, 2.0), p + Vector2(0, -10.0 - flicker * 4.8), p + Vector2(2.6, 2.0)])
                    owner.draw_colored_polygon(flame, Color(secondary, alpha * live * (0.70 + flicker * 0.72)))
                    owner.draw_circle(p + Vector2(0, -2.0), 2.0 + flicker * 1.6, Color(Color.WHITE, alpha * live * 0.16))
                for i in range(9):
                    var ang := float(i) / 9.0 * TAU + t * 0.12
                    var p := altar + Vector2.from_angle(ang) * (28.0 + sin(t * 0.4 + i) * 10.0)
                    owner.draw_circle(p, 0.9 + i % 2 * 0.5, Color(accent, alpha * live * 0.28))
                for i in range(12):
                    var ember := Vector2(owner.size.x * (0.22 + float(i % 6) * 0.11), owner.size.y * (0.52 + float(i / 6) * 0.18))
                    ember += Vector2(sin(t * (0.8 + i * 0.08) + i) * 3.0, -fmod(t * (10.0 + i % 3), 18.0))
                    owner.draw_circle(ember, 0.6 + float(i % 2) * 0.4, Color(Color.WHITE, alpha * live * 0.12))
            "ashes":
                for i in range(22):
                    var y := fmod(t * (17.0 + i % 4 * 2.0) + i * 61.0, owner.size.y * 0.72)
                    var p := Vector2(owner.size.x * 0.5 + sin(t * 0.35 + i) * (25.0 + i % 5 * 14.0), owner.size.y * 0.86 - y)
                    owner.draw_circle(p, 0.8 + i % 3 * 0.45, Color(secondary, alpha * live * (0.35 + (i % 4) * 0.10)))
                owner.draw_arc(Vector2(owner.size.x * 0.5, owner.size.y * 0.43), 38.0 + sin(t * 0.52) * 6.0, -2.75, -0.32, 34, Color(secondary, alpha * live * 0.24), 1.2)
                owner.draw_arc(Vector2(owner.size.x * 0.5, owner.size.y * 0.43), 38.0 + sin(t * 0.52) * 6.0, 0.32, 2.75, 34, Color(secondary, alpha * live * 0.24), 1.2)
            "waves":
                for i in range(11):
                    var x := owner.size.x * (0.13 + i / 10.0 * 0.74) + sin(t * 0.21 + i) * 8.0
                    owner.draw_line(Vector2(x, owner.size.y * 0.16), Vector2(x + sin(t * 0.29 + i) * 9.0, owner.size.y * 0.82), Color(accent if i % 2 else secondary, alpha * live * 0.24), 1.0)
                var window_pulse := 0.5 + 0.5 * sin(t * 0.48)
                owner.draw_rect(Rect2(Vector2(owner.size.x * 0.34, owner.size.y * 0.18), Vector2(owner.size.x * 0.32, owner.size.y * 0.48)), Color(accent, alpha * live * window_pulse * 0.090), true)
                var mid := owner.size.y * 0.60
                for channel in range(2):
                    var points := PackedVector2Array()
                    for i in range(34):
                        var x0 := owner.size.x * float(i) / 33.0
                        var amp := 6.0 + channel * 3.0
                        var phase := t * (0.62 + channel * 0.06) + channel * 1.6
                        var y0 := mid + (channel * 14.0 - 7.0) + sin(float(i) * 0.58 + phase) * amp
                        points.append(Vector2(x0, y0))
                    owner.draw_polyline(points, Color(accent if channel == 0 else secondary, alpha * live * 0.34), 1.0)
                for i in range(18):
                    var rain := Vector2(owner.size.x * (0.18 + float(i % 8) * 0.08), fmod(float(i) * 57.0 + t * (18.0 + i % 3 * 3.0), owner.size.y))
                    owner.draw_line(rain, rain + Vector2(-2.0, 10.0), Color(Color.WHITE, alpha * live * 0.08), 1.0)
            "hybrid":
                for ring in range(6):
                    var r := 28.0 + ring * 23.0
                    var dir := -1.0 if ring % 2 else 1.0
                    var phase := t * (0.12 + ring * 0.015) * dir
                    owner.draw_arc(c, r, phase, phase + 4.9, 52, Color(accent if ring % 2 else secondary, alpha * live * 0.50), 1.0)
                    var tracer := c + Vector2.from_angle(phase + 1.2) * r
                    owner.draw_circle(tracer, 1.1 + float(ring % 2) * 0.6, Color(Color.WHITE, alpha * live * 0.18))
                owner.draw_circle(c, 6.0 + sin(t * 1.1) * 2.0, Color(accent, alpha * live * 0.12))
            "rise":
                for i in range(18):
                    var y := fmod(t * (12.0 + i % 4 * 1.5) + i * 53.0, owner.size.y * 0.76)
                    var x := owner.size.x * (0.30 + float(i % 7) / 6.0 * 0.40) + sin(t * 0.24 + i) * 4.0
                    owner.draw_circle(Vector2(x, owner.size.y * 0.88 - y), 0.8 + i % 2, Color(Color.WHITE, alpha * live * 0.35))
                for i in range(5):
                    var lane := owner.size.x * (0.38 + float(i) * 0.06)
                    owner.draw_line(Vector2(lane, owner.size.y * 0.84), Vector2(owner.size.x * 0.5, owner.size.y * 0.16), Color(accent, alpha * live * 0.12), 1.0)
            _:
                for i in range(5):
                    var y := owner.size.y * (0.28 + i * 0.10) + sin(t * 0.31 + i) * 4.0
                    owner.draw_line(Vector2(owner.size.x * 0.12, y), Vector2(owner.size.x * 0.88, y), Color(accent if i % 2 == 0 else secondary, alpha * live * 0.24), 1.0)
                var sweep0 := fmod(t * 0.09, 1.0)
                owner.draw_line(Vector2(owner.size.x * lerpf(0.18, 0.82, sweep0), owner.size.y * 0.22), Vector2(owner.size.x * lerpf(0.24, 0.88, sweep0), owner.size.y * 0.72), Color(Color.WHITE, alpha * live * 0.10), 1.0)

static func draw_hero_beat(owner: Control, style: String, accent: Color, secondary: Color, hero: float) -> void:
        # Completion is deliberately short and room-specific. Cinematic is a 0..1
        # eased mix driven by RoomStage; this layer supplies the authored visual beat.
        var c := Vector2(owner.size.x * 0.5, owner.size.y * 0.46)
        var t := hero
        match style:
            "technophobia":
                for row in range(6):
                    var on := 1.0 if t >= float(row) / 6.0 else 0.0
                    var y := owner.size.y * (0.18 + row * 0.08)
                    owner.draw_rect(Rect2(Vector2(owner.size.x * 0.10, y), Vector2(owner.size.x * 0.80, 2.0)), Color(accent, 0.10 * (1.0 - on)), true)
                owner.draw_arc(c, owner.size.x * (0.05 + t * 0.18), -2.7, 2.7, 64, Color(accent, 0.34 * t), 1.5)
            "unmasked":
                for i in range(12):
                    var a := float(i) / 12.0 * TAU
                    var p := c + Vector2.from_angle(a) * owner.size.x * (0.04 + t * 0.30)
                    owner.draw_line(c.lerp(p, 0.72), p, Color(secondary, 0.22 * (1.0 - t * 0.55)), 1.2)
            "invaluable":
                for i in range(18):
                    var a := float(i) * 2.1
                    var p := c + Vector2.from_angle(a) * owner.size.x * t * (0.08 + float(i % 5) * 0.025) + Vector2(0, owner.size.y * t * t * 0.05)
                    owner.draw_line(p, p + Vector2.from_angle(a + 0.8) * 14.0, Color(accent, 0.30 * (1.0 - t * 0.65)), 1.0)
            "seed":
                var top := Vector2(owner.size.x * 0.5, owner.size.y * 0.20)
                owner.draw_line(Vector2(owner.size.x * 0.5, owner.size.y * 0.78), top, Color(secondary, 0.20 + t * 0.48), 2.0)
                owner.draw_circle(top, owner.size.x * t * 0.18, Color(accent, 0.028 * t))
            "party":
                for i in range(22):
                    var a := float(i) * 1.7
                    var p := c + Vector2.from_angle(a) * owner.size.x * t * (0.05 + i % 6 * 0.018)
                    owner.draw_circle(p, 1.0 + i % 3, Color(secondary if i % 2 == 0 else accent, 0.24 * (1.0 - t * 0.6)))
            "calling":
                for ring in range(7):
                    owner.draw_arc(c, owner.size.x * (0.06 + ring * 0.035 + t * 0.05), -2.8 + t * ring * 0.07, 2.8 - t * ring * 0.05, 64, Color(accent if ring % 2 else secondary, 0.08 + t * 0.12), 1.0)
            "ashes":
                var wing := owner.size.x * (0.08 + t * 0.22)
                owner.draw_arc(c, wing, -2.95, -0.18, 48, Color(secondary, 0.12 + t * 0.30), 1.6)
                owner.draw_arc(c, wing, 0.18, 2.95, 48, Color(secondary, 0.12 + t * 0.30), 1.6)
            "waves":
                owner.draw_line(Vector2(owner.size.x * 0.18, c.y), Vector2(owner.size.x * 0.82, c.y), Color(accent, 0.10 + t * 0.30), 1.2)
                owner.draw_circle(c, owner.size.x * (0.03 + t * 0.17), Color(accent, 0.018 + t * 0.018))
            "hybrid":
                for ring in range(6):
                    var r := 32.0 + ring * 21.0
                    owner.draw_arc(c, r, t * (0.18 + ring * 0.02), t * (0.18 + ring * 0.02) + lerpf(4.0, TAU, t), 60, Color(accent if ring % 2 else secondary, 0.10 + t * 0.12), 1.2)
            "rise":
                owner.draw_rect(Rect2(Vector2.ZERO, owner.size), Color(Color.WHITE, t * t * 0.075), true)
                for i in range(9):
                    var x := owner.size.x * (0.18 + float(i) / 8.0 * 0.64)
                    owner.draw_line(Vector2(x, owner.size.y * 0.84), Vector2(owner.size.x * 0.5, owner.size.y * lerpf(0.38, 0.13, t)), Color(accent, 0.04 + t * 0.11), 1.0)
            _:
                for i in range(5):
                    var y := owner.size.y * (0.28 + i * 0.10)
                    owner.draw_line(Vector2(owner.size.x * 0.08, y), Vector2(owner.size.x * lerpf(0.30, 0.92, t), y), Color(accent, 0.08 + t * 0.12), 1.0)
