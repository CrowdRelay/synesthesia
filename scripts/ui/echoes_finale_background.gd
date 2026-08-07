extends Control

const FINALE_TEXTURE_PATH: String = "res://assets/finale/echoes-finale.webp"
const FinaleShader := preload("res://shaders/echoes_finale.gdshader")

var _texture_rect: TextureRect
var _material: ShaderMaterial
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
    set_process(true)

func configure(reduced_motion: bool, quiet_visuals: bool) -> void:
    _reduced_motion = reduced_motion
    _quiet_visuals = quiet_visuals
    if _material != null:
        _material.set_shader_parameter("motion", 0.12 if _reduced_motion else 1.0)
        _material.set_shader_parameter("quiet_visuals", 1.0 if _quiet_visuals else 0.0)

func _process(delta: float) -> void:
    _phase = fmod(_phase + delta * (0.12 if _reduced_motion else 0.42), 1000.0)
    _redraw_accumulator += delta
    var hz: float = 6.0 if _reduced_motion else 18.0
    if _redraw_accumulator >= 1.0 / hz:
        _redraw_accumulator = 0.0
        queue_redraw()

func _draw() -> void:
    if size.x <= 1.0 or size.y <= 1.0:
        return
    var count: int = 8 if _reduced_motion else 22
    for index in range(count):
        var seed: float = float(index) * 17.173
        var x: float = size.x * (0.08 + fmod(seed * 0.071, 0.48))
        var base_y: float = size.y * (0.20 + fmod(seed * 0.137, 0.64))
        var drift: float = fmod(_phase * (10.0 + float(index % 5) * 1.7) + seed, size.x * 0.34)
        var y: float = base_y + sin(_phase * 1.7 + seed) * (2.0 if _reduced_motion else 7.0)
        var radius: float = 0.7 + float(index % 4) * 0.55
        var alpha: float = (0.035 + float(index % 3) * 0.012) * (0.35 if _quiet_visuals else 1.0)
        draw_circle(Vector2(x - drift, y), radius, Color(0.48, 0.84, 1.0, alpha))
