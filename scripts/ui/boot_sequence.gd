extends Control

signal released

const DoorEyeMotif := preload("res://scripts/ui/door_eye_motif.gd")
const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")
const BOOT_HOLD: float = 0.42
const DOOR_DURATION: float = 0.66
const FADE_DURATION: float = 0.22

var _motif
var _title: Label
var _render_label: Label
var _ui_scale: float = 1.0

func _ready() -> void:
    name = "SynesthesiaBootSequence"
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 100
    _build()
    call_deferred("_release_web_shell_after_first_frame")
    call_deferred("_play")

func _release_web_shell_after_first_frame() -> void:
    if not OS.has_feature("web"):
        return
    # The HTML shell must cover the browser until Godot has actually presented
    # one frame. main.gd still performs synchronous startup work after attaching
    # this node; releasing in _ready() exposed the stale native splash/canvas.
    await RenderingServer.frame_post_draw
    JavaScriptBridge.eval("window.synesthesiaBootReady && window.synesthesiaBootReady();", true)

func _build() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    _ui_scale = UiMetrics.scale_for_viewport(viewport_size)
    var background := ColorRect.new()
    background.color = Color("03050b")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    UIFactory.add_grain(self, 0.20)

    _title = Label.new()
    _title.text = "S Y N E S T H E S I A"
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.add_theme_font_size_override("font_size", 29)
    _title.add_theme_color_override("font_color", Color("edf7ff"))
    _title.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _title.offset_top = 52.0 * _ui_scale
    _title.offset_bottom = 102.0 * _ui_scale
    add_child(_title)

    var subtitle := Label.new()
    subtitle.text = "VIRYA · ECHOES OF THE MODERN MIND"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 9)
    subtitle.add_theme_color_override("font_color", Color("8da2ba"))
    subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
    subtitle.offset_top = 104.0 * _ui_scale
    subtitle.offset_bottom = 134.0 * _ui_scale
    add_child(subtitle)

    _motif = DoorEyeMotif.new()
    _motif.name = "BootDoorEye"
    _motif.set_anchors_preset(Control.PRESET_CENTER)
    var viewport := get_viewport_rect().size
    var motif_h := clampf(viewport.y * 0.52, 360.0, 690.0)
    var motif_w := motif_h * 0.72
    _motif.offset_left = -motif_w * 0.5
    _motif.offset_right = motif_w * 0.5
    _motif.offset_top = -motif_h * 0.46
    _motif.offset_bottom = motif_h * 0.54
    add_child(_motif)
    _motif.configure(Color("8c62ff"), "splash", Color("ef6fbd"))

    _render_label = Label.new()
    var native := get_viewport_rect().size
    _render_label.text = "ADAPTIVE NATIVE · %d×%d" % [roundi(native.x), roundi(native.y)]
    _render_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _render_label.add_theme_font_size_override("font_size", 8)
    _render_label.add_theme_color_override("font_color", Color("6f8197"))
    _render_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _render_label.offset_top = -64.0 * _ui_scale
    _render_label.offset_bottom = -38.0 * _ui_scale
    add_child(_render_label)
    UiMetrics.apply_tree(self, _ui_scale)

func _play() -> void:
    await get_tree().create_timer(BOOT_HOLD).timeout
    _motif.trigger_glitch(0.92)
    var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tween.tween_method(Callable(_motif, "set_open_mix"), 0.0, 1.0, DOOR_DURATION)
    tween.tween_property(_title, "modulate:a", 0.58, DOOR_DURATION)
    await tween.finished
    # Once the branded boot has finished its motion, let the menu underneath
    # receive input during the short visual fade. The boot is decorative now.
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
    var fade := create_tween()
    fade.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
    await fade.finished
    released.emit()
    queue_free()
