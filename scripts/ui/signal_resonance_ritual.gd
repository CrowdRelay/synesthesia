extends VBoxContainer

signal completed

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const ReleaseReader := preload("res://scripts/app/release_reader.gd")
const SignalAvatar := preload("res://scripts/ui/signal_avatar.gd")
const ROSTER_PATH := "res://data/virya_roster.json"

var _members: Array = []
var _activated: Array[String] = []
var _status: Label
var _row: HBoxContainer
var _done: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 8)

func configure(already_complete: bool = false) -> void:
    for child in get_children():
        child.queue_free()
    _activated.clear()
    _done = already_complete
    var roster := ReleaseReader.load_json(ROSTER_PATH)
    var value: Variant = roster.get("members", [])
    _members = value if value is Array else []

    var eyebrow := Label.new()
    eyebrow.text = "REZONANS · 4 SYGNAŁY · 1 TOŻSAMOŚĆ"
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    eyebrow.add_theme_font_size_override("font_size", 10)
    eyebrow.add_theme_color_override("font_color", Color("8fa4bc"))
    UIFactory.apply_display_font(eyebrow)
    add_child(eyebrow)

    var intro := UIFactory.body("Złóż cztery sygnały w całość. Każdy dotyk uruchamia osobny głos miksu — dopiero razem otwierają finał.")
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro.add_theme_font_size_override("font_size", 11)
    add_child(intro)

    _row = HBoxContainer.new()
    _row.alignment = BoxContainer.ALIGNMENT_CENTER
    _row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _row.add_theme_constant_override("separation", 8)
    add_child(_row)

    for index in range(_members.size()):
        var member_value: Variant = _members[index]
        if member_value is Dictionary:
            _add_member(index, member_value as Dictionary)

    _status = Label.new()
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status.add_theme_font_size_override("font_size", 10)
    _status.add_theme_color_override("font_color", Color("71dcff"))
    UIFactory.apply_display_font(_status)
    add_child(_status)
    _refresh_status()

func _add_member(index: int, member: Dictionary) -> void:
    var accent := Color.from_string(str(member.get("accent", "#71DCFF")), Color("71dcff"))
    var alias := str(member.get("alias", "VIRYA"))
    var role := str(member.get("role", "SYGNAŁ"))
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 3)
    _row.add_child(column)
    var avatar := SignalAvatar.new()
    avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    column.add_child(avatar)
    avatar.configure(str(member.get("avatar", "")), accent, true)
    var button := UIFactory.product_button("%s\n%s" % [role, alias], accent, false)
    button.name = "SignalMember%d" % index
    button.custom_minimum_size = Vector2(96.0, 56.0)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.disabled = _done
    button.pressed.connect(Callable(self, "_activate").bind(index, alias, accent, button, avatar))
    column.add_child(button)

func _activate(index: int, alias: String, accent: Color, button: Button, avatar: Control) -> void:
    if _done:
        return
    var key := str(index)
    if _activated.has(key):
        return
    _activated.append(key)
    button.disabled = true
    button.modulate = Color(accent, 0.72)
    if avatar != null:
        var pulse := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        pulse.tween_property(avatar, "scale", Vector2(1.09, 1.09), 0.13)
        pulse.tween_property(avatar, "modulate", Color(accent, 1.0), 0.13)
        await pulse.finished
        avatar.scale = Vector2.ONE
    _refresh_status(alias)
    if _activated.size() >= _members.size() and not _members.is_empty():
        _done = true
        _status.text = "SIGNAL COMPLETE · wszystkie cztery warstwy rezonują"
        var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        tween.tween_property(self, "modulate", Color(1.05, 1.05, 1.05, 1.0), 0.16)
        tween.tween_property(self, "scale", Vector2(1.015, 1.015), 0.16)
        await tween.finished
        scale = Vector2.ONE
        modulate = Color.WHITE
        completed.emit()

func _refresh_status(last_alias: String = "") -> void:
    if _status == null:
        return
    if _done:
        _status.text = "SIGNAL COMPLETE · rezonans gotowy"
        return
    if _activated.is_empty():
        _status.text = "DOTKNIJ CZTERECH SYGNAŁÓW"
        return
    _status.text = "%s · %d/4" % [last_alias.to_upper(), _activated.size()]
