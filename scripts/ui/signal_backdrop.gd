extends Control

var _texture_path: String = ""
var _accent: Color = Color("E73535")
var _secondary: Color = Color("43D6DF")
var _dim_strength: float = 0.56
var _reduced_motion: bool = false
var _texture_rect: TextureRect
var _phase: float = 0.0
var _redraw_accumulator: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    clip_contents = true

func configure(texture_path: String, accent: Color = Color("E73535"), dim_strength: float = 0.56, reduced_motion: bool = false) -> void:
    _texture_path = texture_path
    _accent = accent
    _dim_strength = clampf(dim_strength, 0.0, 0.92)
    _reduced_motion = reduced_motion
    _build()

func _build() -> void:
    if _texture_rect != null:
        _texture_rect.queue_free()
    _texture_rect = TextureRect.new()
    _texture_rect.name = "SignalWorldArt"
    var resource := load(_texture_path) if ResourceLoader.exists(_texture_path) else null
    if resource is Texture2D:
        _texture_rect.texture = resource as Texture2D
    _texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    _texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _texture_rect.modulate = Color(0.78, 0.83, 0.90, 1.0)
    add_child(_texture_rect)
    _texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _texture_rect.offset_left = -18.0
    _texture_rect.offset_top = -18.0
    _texture_rect.offset_right = 18.0
    _texture_rect.offset_bottom = 18.0

    var dim := ColorRect.new()
    dim.name = "SignalWorldDim"
    dim.color = Color(0.004, 0.007, 0.011, _dim_strength)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    set_process(not _reduced_motion)
    queue_redraw()

func _process(delta: float) -> void:
    _phase = fmod(_phase + delta, 10000.0)
    if _texture_rect != null:
        var dx := sin(_phase * 0.17) * 5.0
        var dy := cos(_phase * 0.11) * 4.0
        _texture_rect.offset_left = -18.0 + dx
        _texture_rect.offset_right = 18.0 + dx
        _texture_rect.offset_top = -18.0 + dy
        _texture_rect.offset_bottom = 18.0 + dy
    _redraw_accumulator += delta
    if _redraw_accumulator >= 1.0 / 12.0:
        _redraw_accumulator = 0.0
        queue_redraw()

func _draw() -> void:
    if size.x < 2.0 or size.y < 2.0:
        return
    var pulse := 0.5 + 0.5 * sin(_phase * 1.05)
    var center := Vector2(size.x * 0.67, size.y * 0.48)
    var base_radius := minf(size.x, size.y) * 0.075
    for index in range(6):
        var radius := base_radius * (1.0 + float(index) * 0.52)
        var alpha := (0.022 + pulse * 0.012) * (1.0 - float(index) * 0.09)
        var color := _accent if index % 2 == 0 else _secondary
        draw_arc(center, radius, -PI * 0.74 + float(index) * 0.13, PI * 0.42 + float(index) * 0.09, 40, Color(color, alpha), 1.0)
    draw_line(Vector2(center.x, size.y * 0.08), Vector2(center.x, size.y * 0.92), Color(_accent, 0.032 + pulse * 0.018), 1.0)

    # Sparse, calm waveform: enough to identify the Signal ecosystem without
    # turning the background into a HUD overlay.
    var points := PackedVector2Array()
    var y0 := size.y * 0.82
    var left := size.x * 0.08
    var right := size.x * 0.92
    for index in range(72):
        var t := float(index) / 71.0
        var x := lerpf(left, right, t)
        var envelope := sin(t * PI)
        var y := y0 + sin(t * TAU * 12.0 + _phase * 0.35) * 3.0 * envelope
        points.append(Vector2(x, y))
    draw_polyline(points, Color(_secondary, 0.075), 1.0, true)
