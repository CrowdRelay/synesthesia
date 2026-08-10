extends Control

signal finished

var _time: float = 0.0
var _duration: float = 1.55
var _accent: Color = Color("71dcff")
var _secondary: Color = Color("e73535")
var _label: Label

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 400
    _label = Label.new()
    _label.text = "SIGNAL BREACH · INTERFEJS NIE JEST JUŻ GRANICĄ"
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _label.add_theme_font_size_override("font_size", 11)
    _label.add_theme_color_override("font_color", Color("d9f7ff"))
    _label.set_anchors_preset(Control.PRESET_CENTER)
    _label.position = Vector2(-210, -16)
    _label.size = Vector2(420, 32)
    add_child(_label)
    set_process(true)

func configure(accent: Color, secondary: Color) -> void:
    _accent = accent
    _secondary = secondary

func _process(delta: float) -> void:
    _time += delta
    queue_redraw()
    var envelope := sin(clampf(_time / _duration, 0.0, 1.0) * PI)
    if _label != null:
        _label.modulate.a = envelope * 0.86
        _label.position.x = -210.0 + sin(_time * 18.0) * envelope * 4.0
    if _time >= _duration:
        set_process(false)
        finished.emit()
        queue_free()

func _draw() -> void:
    if size.x <= 2.0 or size.y <= 2.0:
        return
    var t := clampf(_time / _duration, 0.0, 1.0)
    var env := sin(t * PI)
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, env * 0.12), true)
    for i in range(14):
        var seed := float(i) * 1.73
        var y := size.y * fmod(0.11 + float(i) * 0.071 + sin(_time * 4.0 + seed) * 0.006, 1.0)
        var width := size.x * (0.14 + float(i % 5) * 0.12)
        var x := size.x * fmod(float(i) * 0.217 + _time * (0.08 + i % 3 * 0.025), 1.0)
        draw_line(Vector2(x - width * 0.5, y), Vector2(x + width * 0.5, y), Color(_secondary if i % 3 == 0 else _accent, env * (0.035 + i % 4 * 0.018)), 1.0 + float(i % 2))
    var center := size * 0.5
    for ring in range(4):
        var radius := minf(size.x, size.y) * (0.07 + float(ring) * 0.055 + env * 0.025)
        var phase := _time * (0.7 + ring * 0.16) * (-1.0 if ring % 2 else 1.0)
        draw_arc(center, radius, phase, phase + 4.8, 58, Color(_accent if ring % 2 else _secondary, env * 0.10), 1.0)
