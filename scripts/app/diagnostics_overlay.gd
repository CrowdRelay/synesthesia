extends CanvasLayer

var label: Label
var enabled: bool = false
var _accumulator: float = 0.0

func _ready() -> void:
    enabled = OS.has_feature("editor") and OS.get_cmdline_args().has("--synesthesia-debug")
    label = Label.new()
    label.visible = enabled
    label.position = Vector2(8.0, 86.0)
    label.add_theme_font_size_override("font_size", 10)
    label.add_theme_color_override("font_color", Color("b8ffca"))
    label.add_theme_color_override("font_shadow_color", Color.BLACK)
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
    add_child(label)
    set_process(enabled)

func _process(delta: float) -> void:
    _accumulator += delta
    if _accumulator < 0.5:
        return
    _accumulator = 0.0
    var fps: int = Engine.get_frames_per_second()
    var frame_ms: float = float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
    var memory_mb: float = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
    var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    label.text = "FPS %d · %.2f ms\nRAM %.1f MB · draw %d" % [fps, frame_ms, memory_mb, draw_calls]
