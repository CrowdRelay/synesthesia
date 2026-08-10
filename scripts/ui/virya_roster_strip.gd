extends HBoxContainer

const ReleaseReader := preload("res://scripts/app/release_reader.gd")
const SignalAvatar := preload("res://scripts/ui/signal_avatar.gd")
const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const ROSTER_PATH := "res://data/virya_roster.json"

var _compact: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    alignment = BoxContainer.ALIGNMENT_CENTER
    size_flags_horizontal = Control.SIZE_EXPAND_FILL

func configure(compact: bool = false, show_aliases: bool = true) -> void:
    _compact = compact
    add_theme_constant_override("separation", 8 if compact else 12)
    for child in get_children():
        child.queue_free()
    var roster := ReleaseReader.load_json(ROSTER_PATH)
    var members_value: Variant = roster.get("members", [])
    var members: Array = members_value if members_value is Array else []
    for value in members:
        if value is Dictionary:
            _add_member(value as Dictionary, show_aliases)

func _add_member(member: Dictionary, show_aliases: bool) -> void:
    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 2 if _compact else 4)
    add_child(column)
    var accent := Color.from_string(str(member.get("accent", "#71DCFF")), Color("71dcff"))
    var avatar := SignalAvatar.new()
    avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    column.add_child(avatar)
    avatar.configure(str(member.get("avatar", "")), accent, _compact)
    var role := Label.new()
    role.text = str(member.get("role", "VIRYA"))
    role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    role.add_theme_font_size_override("font_size", 8 if _compact else 10)
    role.add_theme_color_override("font_color", accent)
    UIFactory.apply_display_font(role)
    column.add_child(role)
    if show_aliases:
        var alias := Label.new()
        alias.text = str(member.get("alias", ""))
        alias.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        alias.add_theme_font_size_override("font_size", 8 if _compact else 9)
        alias.add_theme_color_override("font_color", Color("9ca8b8"))
        column.add_child(alias)
