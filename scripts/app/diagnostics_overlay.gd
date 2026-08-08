extends CanvasLayer

var label: Label
var enabled: bool = false
var _accumulator: float = 0.0
var _adaptive: Node
var _preloader: Node

func configure(adaptive: Node, preloader: Node) -> void:
    _adaptive = adaptive
    _preloader = preloader

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
    var runtime_line: String = ""
    if _adaptive != null and is_instance_valid(_adaptive) and _adaptive.has_method("snapshot"):
        var budget: Dictionary = _adaptive.snapshot()
        runtime_line = "\nQ %.2f · EMA %.1f · hitch %.0f%% · %s" % [
            float(budget.get("scale", 1.0)),
            float(budget.get("frame_ema_ms", frame_ms)),
            float(budget.get("hitch_ratio", 0.0)) * 100.0,
            str(budget.get("reason", "-")),
        ]
    var preload_line: String = ""
    if _preloader != null and is_instance_valid(_preloader) and _preloader.has_method("snapshot"):
        var preload_snapshot: Dictionary = _preloader.snapshot()
        preload_line = "\nPRE %d/%d crit · hit %d · wait %d/%dms" % [
            int(preload_snapshot.get("queued", 0)),
            int(preload_snapshot.get("critical_queued", 0)),
            int(preload_snapshot.get("hits", 0)),
            int(preload_snapshot.get("blocking_takes", 0)),
            int(preload_snapshot.get("max_block_ms", 0)),
        ]
    label.text = "FPS %d · %.2f ms\nRAM %.1f MB · draw %d%s%s" % [
        fps,
        frame_ms,
        memory_mb,
        draw_calls,
        runtime_line,
        preload_line,
    ]
