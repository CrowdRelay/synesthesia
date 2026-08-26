extends HBoxContainer

const ReleaseReader := preload("res://scripts/app/release_reader.gd")
const SignalAvatar := preload("res://scripts/ui/signal_avatar.gd")
const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const ROSTER_PATH := "res://data/virya_roster.json"

var _compact: bool = false
var _avatars: Array[Control] = []
var _avatar_base: float = 86.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    alignment = BoxContainer.ALIGNMENT_CENTER
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    resized.connect(_fit_avatars_to_width)

func configure(compact: bool = false, show_aliases: bool = true) -> void:
    _compact = compact
    _avatars.clear()
    _avatar_base = 58.0 if compact else 86.0
    add_theme_constant_override("separation", 8 if compact else 12)
    for child in get_children():
        child.queue_free()
    var roster := ReleaseReader.load_json(ROSTER_PATH)
    var members_value: Variant = roster.get("members", [])
    var members: Array = members_value if members_value is Array else []
    for value in members:
        if value is Dictionary:
            _add_member(value as Dictionary, show_aliases)
    # Narrow viewports must not inherit a hard sum-of-avatars minimum: the strip
    # sits inside scrollable cards (finale) whose content would otherwise push
    # the panel wider than the screen and shove CTAs off-view.
    call_deferred("_fit_avatars_to_width")

func _fit_avatars_to_width() -> void:
    if _avatars.is_empty():
        return
    var alive := _avatars.filter(func(a: Control) -> bool: return is_instance_valid(a))
    if alive.is_empty():
        return
    # Budget off the viewport, not this strip's own size: once the row is the
    # widest child, its allocated width IS its own minimum and the loop would
    # always return the base avatar size (the overflow that broke narrow
    # viewports). A viewport-relative budget keeps the sum under the screen.
    var viewport_x: float = get_viewport_rect().size.x
    var separation: float = float(get_theme_constant("separation"))
    # 96px reserves the page margin plus the hosting card's own stylebox
    # padding, so the row fits inside the narrowest hosted card, not just the
    # raw screen.
    var budget: float = maxf(140.0, viewport_x - 96.0)
    var per_avatar: float = floorf((budget - separation * float(alive.size() - 1)) / float(alive.size()))
    var fitted: float = clampf(per_avatar, 40.0, _avatar_base)
    for avatar in alive:
        if avatar.custom_minimum_size.x != fitted or avatar.custom_minimum_size.y != fitted:
            avatar.custom_minimum_size = Vector2(fitted, fitted)

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
    avatar.custom_minimum_size = Vector2(_avatar_base, _avatar_base)
    _avatars.append(avatar)
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

