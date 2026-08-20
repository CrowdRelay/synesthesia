extends Control

signal dismissed

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const DoorEyeMotif := preload("res://scripts/ui/door_eye_motif.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")

var _accent: Color = Color("84b4ac")
var _sheet: PanelContainer
var _row: HBoxContainer
var _content: VBoxContainer
var _body: Label
var _motif
var _timer: Timer
var _ui_scale: float = 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(room_index: int, room_total: int, room_name: String, intro_text: String, caption: String, accent: Color, identity: Dictionary = {}, objective: String = "", objective_steps: Array = []) -> void:
    _accent = _clinicalize(accent)
    _build(room_index, room_total, room_name, intro_text, caption, identity, objective, objective_steps)

func _build(room_index: int, room_total: int, room_name: String, intro_text: String, caption: String, identity: Dictionary, objective: String, objective_steps: Array) -> void:
    _sheet = PanelContainer.new()
    _sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _sheet.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
    _sheet.add_theme_stylebox_override("panel", UIFactory.product_inset_style(_accent, 0.24))
    add_child(_sheet)
    _layout_sheet()

    _row = HBoxContainer.new()
    _row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _row.add_theme_constant_override("separation", 10)
    _sheet.add_child(_row)

    _motif = DoorEyeMotif.new()
    _motif.custom_minimum_size = Vector2(82.0, 116.0)
    _motif.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    _row.add_child(_motif)
    _motif.configure(_accent, "panel", Color("98a5a0"))

    _content = VBoxContainer.new()
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 4)
    _content.size_flags_stretch_ratio = 1.0
    _row.add_child(_content)

    var eyebrow := Label.new()
    eyebrow.text = "ODDZIAŁ // SALA %02d / %02d  ·  %s" % [room_index + 1, room_total, caption if not caption.is_empty() else "VIRYA · SYNESTEZJA"]
    UIFactory.apply_display_font(eyebrow)
    eyebrow.add_theme_font_size_override("font_size", 9)
    eyebrow.add_theme_color_override("font_color", Color(_accent, 0.92))
    _content.add_child(eyebrow)

    var heading := UIFactory.heading(_ward_room_name(room_index, room_name))
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    heading.add_theme_font_size_override("font_size", 23)
    heading.add_theme_color_override("font_color", Color("eef4f1"))
    heading.add_theme_color_override("font_outline_color", Color("070908e8"))
    _content.add_child(heading)

    _body = UIFactory.body(_shorten(intro_text, 150))
    _body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _body.add_theme_font_size_override("font_size", 12)
    _body.add_theme_color_override("font_color", Color("b7c1bd"))
    _content.add_child(_body)

    var identity_line := _identity_line(identity)
    if not identity_line.is_empty():
        var guide := Label.new()
        guide.text = identity_line
        guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        UIFactory.apply_display_font(guide)
        guide.add_theme_font_size_override("font_size", 9)
        guide.add_theme_color_override("font_color", Color("a4aaa6"))
        _content.add_child(guide)

    var hint := Label.new()
    hint.text = "CEL · %s" % objective.strip_edges().to_upper() if not objective.strip_edges().is_empty() else "ROZEJRZYJ SIĘ · ODCZYTAJ ZNAKI · POZWÓL SZUMOWI OPAŚĆ"
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    UIFactory.apply_display_font(hint)
    hint.add_theme_font_size_override("font_size", 10)
    hint.add_theme_color_override("font_color", Color("93c6c0"))
    _content.add_child(hint)
    var step_line := _objective_step_line(objective_steps)
    if not step_line.is_empty():
        var steps_label := Label.new()
        steps_label.text = step_line
        steps_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        UIFactory.apply_display_font(steps_label)
        steps_label.add_theme_font_size_override("font_size", 9)
        steps_label.add_theme_color_override("font_color", Color(_accent, 0.78))
        _content.add_child(steps_label)

    _layout_sheet()
    _apply_ui_scale()

    modulate.a = 0.0
    position.y = 12.0
    var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.20)
    tween.tween_property(self, "position:y", 0.0, 0.26)

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.wait_time = 4.4
    _timer.timeout.connect(_fade_out)
    add_child(_timer)
    _timer.start()

func _layout_sheet() -> void:
    if _sheet == null:
        return
    var viewport := get_viewport_rect().size
    _ui_scale = UiMetrics.scale_for_viewport(viewport)
    var safe := UiMetrics.safe_insets(viewport)
    var wide: bool = viewport.x >= 720.0 * _ui_scale and viewport.x / maxf(1.0, viewport.y) > 1.05
    if wide:
        _sheet.set_anchors_preset(Control.PRESET_CENTER_LEFT)
        var available := maxf(320.0 * _ui_scale, viewport.x - 56.0 * _ui_scale)
        var width := minf(available, clampf(viewport.x * 0.44, 520.0 * _ui_scale, 620.0 * _ui_scale))
        _sheet.offset_left = maxf(28.0 * _ui_scale, safe.x + 12.0 * _ui_scale)
        _sheet.offset_right = _sheet.offset_left + width
        _sheet.offset_top = -118.0 * _ui_scale
        _sheet.offset_bottom = 118.0 * _ui_scale
        var copy_width := minf(390.0 * _ui_scale, maxf(360.0 * _ui_scale, width - 126.0 * _ui_scale))
        _set_copy_minimum(copy_width)
        if _motif != null:
            _motif.custom_minimum_size = Vector2(82.0, 116.0) * _ui_scale
    else:
        _sheet.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
        _sheet.offset_left = maxf(12.0 * _ui_scale, safe.x + 8.0 * _ui_scale)
        _sheet.offset_right = -maxf(12.0 * _ui_scale, safe.z + 8.0 * _ui_scale)
        _sheet.offset_top = maxf(12.0 * _ui_scale, safe.y + 8.0 * _ui_scale)
        _sheet.offset_bottom = _sheet.offset_top + 274.0 * _ui_scale
        _set_copy_minimum(0.0)
        if _motif != null:
            _motif.custom_minimum_size = Vector2(84.0, 122.0) * _ui_scale

func _apply_ui_scale() -> void:
    if _sheet != null:
        UiMetrics.apply_tree(_sheet, _ui_scale)

func _set_copy_minimum(width: float) -> void:
    var minimum := Vector2(maxf(0.0, width), 0.0)
    if _content != null:
        _content.set_custom_minimum_size(minimum)
        _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if _body != null:
        _body.set_custom_minimum_size(minimum)
        _body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if _row != null:
        _row.queue_sort()
    if _sheet != null:
        _sheet.queue_sort()

func _fade_out() -> void:
    var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tween.tween_property(self, "modulate:a", 0.0, 0.24)
    tween.tween_property(self, "position:y", -8.0, 0.24)
    await tween.finished
    dismissed.emit()

func _shorten(value: String, limit: int) -> String:
    var text := value.strip_edges()
    if text.length() <= limit:
        return text
    var cropped := text.substr(0, limit)
    var last_space := cropped.rfind(" ")
    if last_space > limit / 2:
        cropped = cropped.substr(0, last_space)
    return "%s…" % cropped

func _objective_step_line(steps: Array) -> String:
    var labels := PackedStringArray()
    for value in steps:
        if not value is Dictionary: continue
        var verb := str((value as Dictionary).get("verb", "")).strip_edges()
        if not verb.is_empty(): labels.append(_verb_label(verb))
        if labels.size() >= 3: break
    return "GESTY · %s" % "  >  ".join(labels) if not labels.is_empty() else ""

func _verb_label(verb: String) -> String:
    var labels := {"tap":"DOTKNIJ", "hold":"PRZYTRZYMAJ", "drag":"PRZESUŃ", "drag_up":"UNIEŚ", "drag_horizontal":"PROWADŹ W BOK", "release":"PUŚĆ", "swirl":"ZAKRĘĆ", "swipe":"ZRZUĆ", "tap_or_swipe":"DOTKNIJ / PRZETNIJ"}
    return str(labels.get(verb, verb.replace("_", " ").to_upper()))

func _identity_line(identity: Dictionary) -> String:
    if identity.is_empty():
        return ""
    var focus := str(identity.get("focus_title", "")).strip_edges()
    var member_role := str(identity.get("member_role", "")).strip_edges()
    if focus.is_empty():
        return ""
    return "PRZEWODNIK · %s%s" % [focus, " · %s" % member_role if not member_role.is_empty() else ""]

func _ward_room_name(room_index: int, fallback: String) -> String:
    var names := [
        "SALA OBSERWACYJNA",
        "ŚWIETLICA TERAPII",
        "PRACOWNIA ARTETERAPII",
        "SALA TERAPII GRUPOWEJ",
        "OGRÓD TERAPEUTYCZNY",
        "KORYTARZ DIAGNOSTYCZNY",
        "DYŻURKA OBSERWACYJNA",
        "DEPOZYT RZECZY OSOBISTYCH",
        "PRACOWNIA PLASTYCZNA",
        "POKÓJ DWUOSOBOWY",
        "KLATKA WYJŚCIOWA",
    ]
    if room_index >= 0 and room_index < names.size():
        return str(names[room_index])
    return fallback

func _clinicalize(color: Color) -> Color:
    var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
    return Color(luminance, luminance, luminance, 1.0).lerp(Color("84b4ac"), 0.72)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_layout_sheet")
        call_deferred("_apply_ui_scale")
