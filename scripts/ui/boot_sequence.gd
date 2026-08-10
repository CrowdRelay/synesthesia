extends Control

signal released

const DoorEyeMotif := preload("res://scripts/ui/door_eye_motif.gd")
const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")
const MENU_WORLD_PATH: String = "res://assets/v2/branding/menu-world.webp"

# Keep startup branded but bounded. The authored Theora loop is armed only after
# the first real Godot frame, so these timings do not move decoder work back onto
# the critical first-frame path.
const BOOT_HOLD: float = 0.28
const EYE_REVEAL_DURATION: float = 0.50
const FADE_DURATION: float = 0.20

var _motif
var _title: Label
var _subtitle: Label
var _tagline: Label
var _load_label: Label
var _progress_fill: ColorRect
var _ui_scale: float = 1.0
var _reduced_motion: bool = false

func configure(reduced_motion: bool = false) -> void:
    _reduced_motion = reduced_motion

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
    # The browser shell and native engine splash both use a still taken from the
    # exact menu-eye loop. After one cheap Godot frame is actually on screen we
    # can safely arm the decoder and continue with the *same* art in motion.
    await RenderingServer.frame_post_draw
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.synesthesiaBootPrepareHandoff && window.synesthesiaBootPrepareHandoff();", true)
    if _motif != null and not _reduced_motion:
        _motif.arm_authored_animation(true)
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
    _title.offset_top = 46.0 * _ui_scale
    _title.offset_bottom = 104.0 * _ui_scale
    add_child(_title)

    _subtitle = Label.new()
    _subtitle.text = "VIRYA · ECHOES OF THE MODERN MIND"
    _subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _subtitle.add_theme_font_size_override("font_size", 9)
    _subtitle.add_theme_color_override("font_color", Color("a895b8"))
    UIFactory.apply_display_font(_subtitle)
    _subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _subtitle.offset_top = 108.0 * _ui_scale
    _subtitle.offset_bottom = 138.0 * _ui_scale
    add_child(_subtitle)

    _motif = DoorEyeMotif.new()
    _motif.name = "BootAuthoredEye"
    _motif.set_anchors_preset(Control.PRESET_CENTER)
    var motif_h: float = clampf(viewport_size.y * 0.57, 390.0 * _ui_scale, 720.0 * _ui_scale)
    var motif_w: float = motif_h * (848.0 / 1104.0)
    _motif.offset_left = -motif_w * 0.5
    _motif.offset_right = motif_w * 0.5
    _motif.offset_top = -motif_h * 0.47
    _motif.offset_bottom = motif_h * 0.53
    add_child(_motif)
    _motif.configure(Color("43d6df"), "splash", Color("e73535"))
    _motif.modulate.a = 0.36
    _motif.set_reduced_motion(_reduced_motion)

    _tagline = Label.new()
    _tagline.text = "SZUKAJ  ·  DOTKNIJ  ·  ODSZUM"
    _tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _tagline.add_theme_font_size_override("font_size", 9)
    _tagline.add_theme_color_override("font_color", Color("a895b8"))
    UIFactory.apply_display_font(_tagline)
    _tagline.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _tagline.offset_top = -96.0 * _ui_scale
    _tagline.offset_bottom = -66.0 * _ui_scale
    add_child(_tagline)

    _load_label = Label.new()
    _load_label.text = "URUCHAMIAM DOŚWIADCZENIE"
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
    progress_track.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    var line_half: float = minf(120.0 * _ui_scale, viewport_size.x * 0.22)
    progress_track.offset_left = viewport_size.x * 0.5 - line_half
    progress_track.offset_right = viewport_size.x * 0.5 + line_half
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
    await get_tree().create_timer(BOOT_HOLD).timeout
    if not _reduced_motion:
        _motif.trigger_glitch(0.36)
    var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tween.tween_method(Callable(_motif, "set_open_mix"), 0.12, 1.0, EYE_REVEAL_DURATION)
    tween.tween_property(_progress_fill, "scale:x", 1.0, EYE_REVEAL_DURATION)
    tween.tween_property(_title, "modulate:a", 0.84, EYE_REVEAL_DURATION)
    tween.tween_property(_load_label, "modulate:a", 0.58, EYE_REVEAL_DURATION)
    await tween.finished

    # The boot layer is decorative from here. Release the modal input boundary
    # before the visual fade so the menu underneath never feels sticky.
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
    # Freeze this splash on its authored poster, synchronously build the real
    # menu underneath, then fade *into* it. This removes the old black-frame
    # beat without ever running two Theora decoders at the same time.
    _motif.suspend_authored_animation(true)
    released.emit()
    var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    fade.tween_property(self, "modulate:a", 0.0, FADE_DURATION if not _reduced_motion else 0.08)
    await fade.finished
    queue_free()
