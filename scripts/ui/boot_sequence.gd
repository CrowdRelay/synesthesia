extends Control

signal released

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")
const MENU_WORLD_PATH: String = "res://assets/v2/branding/menu-world.webp"

# Keep startup branded but bounded. The same authored ward corridor is used by
# the native splash, Web shell, Godot boot and menu, so the handoff never jumps
# back to the retired sci-fi eye artwork.
const COLD_BOOT_HOLD: float = 0.16
const COLD_REVEAL_DURATION: float = 0.34
const COLD_FADE_DURATION: float = 0.14
const WARM_BOOT_HOLD: float = 0.025
const WARM_REVEAL_DURATION: float = 0.16
const WARM_FADE_DURATION: float = 0.09

var _title: Label
var _subtitle: Label
var _tagline: Label
var _load_label: Label
var _progress_fill: ColorRect
var _ui_scale: float = 1.0
var _reduced_motion: bool = false
var _warm_boot: bool = false

func configure(reduced_motion: bool = false) -> void:
    _reduced_motion = reduced_motion

func _ready() -> void:
    name = "SynesthesiaBootSequence"
    _warm_boot = _detect_warm_boot()
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 100
    _build()
    call_deferred("_release_web_shell_after_first_frame")
    call_deferred("_play")

func _release_web_shell_after_first_frame() -> void:
    # Release only after the first authored Godot frame is actually presented.
    # The browser shell and engine already show the same ward composition.
    await RenderingServer.frame_post_draw
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.synesthesiaBootReady && window.synesthesiaBootReady();", true)

func _build() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    _ui_scale = UiMetrics.scale_for_viewport(viewport_size)

    UIFactory.add_signal_backdrop(self, MENU_WORLD_PATH, Color("E73535"), 0.46, _reduced_motion)
    var background := ColorRect.new()
    background.color = Color(0.005, 0.008, 0.012, 0.22)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    UIFactory.add_grain(self, 0.06)

    _title = Label.new()
    _title.text = "SYNESTHESIA"
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.add_theme_font_size_override("font_size", 34)
    _title.add_theme_color_override("font_color", Color("f4eef8"))
    _title.add_theme_constant_override("outline_size", 2)
    _title.add_theme_color_override("font_outline_color", Color("05060ae8"))
    UIFactory.apply_display_font(_title)
    _title.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _title.offset_top = 154.0 * _ui_scale
    _title.offset_bottom = 212.0 * _ui_scale
    add_child(_title)

    _subtitle = Label.new()
    _subtitle.text = "VIRYA · ECHOES OF THE MODERN MIND"
    _subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _subtitle.add_theme_font_size_override("font_size", 9)
    _subtitle.add_theme_color_override("font_color", Color("a895b8"))
    UIFactory.apply_display_font(_subtitle)
    _subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _subtitle.offset_top = 216.0 * _ui_scale
    _subtitle.offset_bottom = 246.0 * _ui_scale
    add_child(_subtitle)

    _tagline = Label.new()
    _tagline.text = "NASŁUCHUJ  ·  DOTKNIJ  ·  ODSŁOŃ"
    _tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _tagline.add_theme_font_size_override("font_size", 9)
    _tagline.add_theme_color_override("font_color", Color("a895b8"))
    UIFactory.apply_display_font(_tagline)
    _tagline.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _tagline.offset_top = -96.0 * _ui_scale
    _tagline.offset_bottom = -66.0 * _ui_scale
    add_child(_tagline)

    _load_label = Label.new()
    _load_label.text = "WZNAWIAM SYGNAŁ" if _warm_boot else "URUCHAMIAM DOŚWIADCZENIE"
    _load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _load_label.add_theme_font_size_override("font_size", 7)
    _load_label.add_theme_color_override("font_color", Color("66778d"))
    UIFactory.apply_display_font(_load_label)
    _load_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _load_label.offset_top = -52.0 * _ui_scale
    _load_label.offset_bottom = -31.0 * _ui_scale
    add_child(_load_label)

    var progress_track := ColorRect.new()
    progress_track.color = Color("1d2633b8")
    progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
    progress_track.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    var line_half: float = minf(120.0 * _ui_scale, viewport_size.x * 0.22)
    progress_track.offset_left = -line_half
    progress_track.offset_right = line_half
    progress_track.offset_top = -24.0 * _ui_scale
    progress_track.offset_bottom = -21.0 * _ui_scale
    add_child(progress_track)

    _progress_fill = ColorRect.new()
    _progress_fill.color = Color("e73535")
    _progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _progress_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _progress_fill.scale = Vector2(0.08, 1.0)
    progress_track.add_child(_progress_fill)

    UiMetrics.apply_tree(self, _ui_scale)

func _play() -> void:
    var hold: float = WARM_BOOT_HOLD if _warm_boot else COLD_BOOT_HOLD
    var reveal_duration: float = WARM_REVEAL_DURATION if _warm_boot else COLD_REVEAL_DURATION
    var fade_duration: float = WARM_FADE_DURATION if _warm_boot else COLD_FADE_DURATION
    await get_tree().create_timer(hold).timeout
    var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(_progress_fill, "scale:x", 1.0, reveal_duration)
    tween.tween_property(_title, "modulate:a", 0.84, reveal_duration)
    tween.tween_property(_load_label, "modulate:a", 0.58, reveal_duration)
    await tween.finished

    # The boot layer is decorative from here. Release the modal input boundary
    # before the visual fade so the menu underneath never feels sticky.
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
    # Build the real menu underneath, then fade into the same corridor artwork.
    released.emit()
    var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    fade.tween_property(self, "modulate:a", 0.0, fade_duration if not _reduced_motion else minf(fade_duration, 0.07))
    await fade.finished
    queue_free()

func _detect_warm_boot() -> bool:
    if not OS.has_feature("web"):
        return false
    var value: Variant = JavaScriptBridge.eval("Boolean(window.synesthesiaWarmBoot)", true)
    return bool(value)
