extends Control

var _texture: Texture2D
var _accent: Color = Color("71dcff")
var _phase: float = 0.0
var _compact: bool = false
var _reduced_motion: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func configure(texture_path: String, accent: Color, compact: bool = false, reduced_motion: bool = false) -> void:
    _accent = accent
    _compact = compact
    _reduced_motion = reduced_motion
    if ResourceLoader.exists(texture_path):
        var resource := load(texture_path)
        if resource is Texture2D:
            _texture = resource as Texture2D
    custom_minimum_size = Vector2(58.0, 58.0) if compact else Vector2(86.0, 86.0)
    set_process(not reduced_motion)
    queue_redraw()

func _process(delta: float) -> void:
    _phase = fmod(_phase + delta * 0.42, 1000.0)
    queue_redraw()

func _draw() -> void:
    var side := minf(size.x, size.y)
    if side <= 2.0:
        return
    var center := size * 0.5
    var radius := side * 0.44
    draw_circle(center, radius * 1.04, Color("030508ee"))
    if _texture != null:
        var rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
        draw_texture_rect(_texture, rect, false, Color.WHITE)
    var pulse := 0.5 if _reduced_motion else 0.5 + 0.5 * sin(_phase * TAU)
    draw_arc(center, radius, -PI * 0.92, PI * 0.92, 56, Color(_accent, 0.64), maxf(1.0, side * 0.012))
    draw_arc(center, radius * 1.08, PI * 0.18, PI * 1.18, 30, Color(_accent, 0.18 + pulse * 0.12), maxf(1.0, side * 0.008))
    _draw_waveform(center, radius, pulse)

func _draw_waveform(center: Vector2, radius: float, pulse: float) -> void:
    var points := PackedVector2Array()
    var count := 23 if _compact else 31
    for index in range(count):
        var t := float(index) / float(count - 1)
        var envelope := 1.0 - absf(t - 0.5) * 1.55
        envelope = clampf(envelope, 0.16, 1.0)
        var y := sin(t * TAU * 4.0 + _phase * 1.4) * radius * 0.11 * envelope
        y += sin(t * TAU * 9.0) * radius * 0.025
        points.append(center + Vector2((t - 0.5) * radius * 2.18, y))
    draw_polyline(points, Color(_accent, 0.52 + pulse * 0.15), maxf(1.0, radius * 0.018), true)
