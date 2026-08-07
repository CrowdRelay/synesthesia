extends Control

const DOOR_DURATION: float = 0.72
const FADE_DURATION: float = 0.24

var _left: ColorRect
var _right: ColorRect
var _title: Label
var _glow: ColorRect

func _ready() -> void:
    name = "SynesthesiaBootSequence"
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 4096
    _build()
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.synesthesiaBootReady && window.synesthesiaBootReady();", true)
    call_deferred("_play")

func _build() -> void:
    var background := ColorRect.new()
    background.color = Color("050811")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    _title = Label.new()
    _title.text = "SYNESTHESIA"
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.add_theme_font_size_override("font_size", 30)
    _title.add_theme_color_override("font_color", Color("edf7ff"))
    _title.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _title.offset_top = 64.0
    _title.offset_bottom = 112.0
    add_child(_title)

    var subtitle := Label.new()
    subtitle.text = "VIRYA · ECHOES OF THE MODERN MIND"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 10)
    subtitle.add_theme_color_override("font_color", Color("8da2ba"))
    subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
    subtitle.offset_top = 118.0
    subtitle.offset_bottom = 148.0
    add_child(subtitle)

    _glow = ColorRect.new()
    _glow.color = Color("17304a")
    _glow.set_anchors_preset(Control.PRESET_CENTER)
    _glow.position = Vector2(-82.0, -230.0)
    _glow.size = Vector2(164.0, 460.0)
    add_child(_glow)

    _left = ColorRect.new()
    _left.color = Color("09101f")
    _left.set_anchors_preset(Control.PRESET_CENTER)
    _left.position = Vector2(-82.0, -230.0)
    _left.size = Vector2(81.0, 460.0)
    add_child(_left)

    _right = ColorRect.new()
    _right.color = Color("09101f")
    _right.set_anchors_preset(Control.PRESET_CENTER)
    _right.position = Vector2(1.0, -230.0)
    _right.size = Vector2(81.0, 460.0)
    add_child(_right)

    var seam := ColorRect.new()
    seam.color = Color("71dcff")
    seam.set_anchors_preset(Control.PRESET_CENTER)
    seam.position = Vector2(-1.0, -230.0)
    seam.size = Vector2(2.0, 460.0)
    seam.modulate.a = 0.38
    add_child(seam)

func _play() -> void:
    var duration := DOOR_DURATION
    var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(_left, "position:x", -size.x * 0.62, duration)
    tween.tween_property(_right, "position:x", size.x * 0.62, duration)
    tween.tween_property(_glow, "modulate:a", 0.0, duration * 0.72)
    tween.tween_property(_title, "modulate:a", 0.55, duration)
    await tween.finished
    var fade := create_tween()
    fade.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
    await fade.finished
    queue_free()
