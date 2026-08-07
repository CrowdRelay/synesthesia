extends Control

const FINALE_TEXTURE_PATH: String = "res://assets/finale/echoes-finale.webp"
const FinaleShader := preload("res://shaders/echoes_finale.gdshader")
const RoomVideoLayerScript := preload("res://scripts/render/room_video_layer.gd")

var _texture_rect: TextureRect
var _material: ShaderMaterial
var _video_layer
var _phase: float = 0.0
var _reduced_motion: bool = false
var _quiet_visuals: bool = false
var _redraw_accumulator: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = true
    _texture_rect = TextureRect.new()
    _texture_rect.name = "EchoesCover"
    var texture_resource: Resource = load(FINALE_TEXTURE_PATH)
    if texture_resource is Texture2D:
        _texture_rect.texture = texture_resource as Texture2D
    else:
        push_error("Echoes finale texture failed to load")
    _texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
    _texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_texture_rect)
    _texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _material = ShaderMaterial.new()
    _material.shader = FinaleShader
    _texture_rect.material = _material
    _video_layer = RoomVideoLayerScript.new()
    _video_layer.name = "EchoesCinematicVideo"
    add_child(_video_layer)
    _video_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _video_layer.set_max_alpha(0.94)
    set_process(true)

func configure(reduced_motion: bool, quiet_visuals: bool) -> void:
    _reduced_motion = reduced_motion
    _quiet_visuals = quiet_visuals
    if _video_layer != null:
        _video_layer.configure("finale", _reduced_motion, _quiet_visuals, true)
        _video_layer.set_max_alpha(0.94)
        _video_layer.set_cinematic(true, false)
    if _material != null:
        _material.set_shader_parameter("motion", 0.12 if _reduced_motion else 1.0)
        _material.set_shader_parameter("quiet_visuals", 1.0 if _quiet_visuals else 0.0)

func _process(delta: float) -> void:
    _phase = fmod(_phase + delta * (0.14 if _reduced_motion else 0.78), 1000.0)
    _redraw_accumulator += delta
    var hz: float = 6.0 if _reduced_motion else 18.0
    if _redraw_accumulator >= 1.0 / hz:
        _redraw_accumulator = 0.0
        queue_redraw()

func _draw() -> void:
    if size.x <= 1.0 or size.y <= 1.0:
        return
    var count: int = 12 if _reduced_motion else 58
    for index in range(count):
        var seed: float = float(index) * 17.173
        var x: float = size.x * (0.08 + fmod(seed * 0.071, 0.48))
        var base_y: float = size.y * (0.20 + fmod(seed * 0.137, 0.64))
        var drift: float = fmod(_phase * (18.0 + float(index % 7) * 2.8) + seed, size.x * 0.54)
        var y: float = base_y + sin(_phase * 2.1 + seed) * (3.0 if _reduced_motion else 13.0)
        var radius: float = 0.7 + float(index % 5) * 0.62
        var alpha: float = (0.045 + float(index % 4) * 0.014) * (0.35 if _quiet_visuals else 1.0)
        draw_circle(Vector2(x - drift, y), radius, Color(0.48, 0.84, 1.0, alpha))
        if not _reduced_motion and index % 3 == 0:
            draw_line(Vector2(x - drift, y), Vector2(x - drift - 12.0 - float(index % 5) * 4.0, y + 1.5), Color(0.48, 0.84, 1.0, alpha * 0.42), 0.8)

func _exit_tree() -> void:
    if _video_layer != null and _video_layer.has_method("shutdown"):
        _video_layer.shutdown()
