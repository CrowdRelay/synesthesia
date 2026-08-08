extends Control

signal room_requested(index: int)
signal finale_requested
signal close_requested

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")
const ReleaseReader := preload("res://scripts/app/release_reader.gd")

var _releases: Array = []
var _completed_ids: Array = []
var _echo_archive: Dictionary = {}
var _accent: Color = Color("72afff")
var _panel: PanelContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _ui_scale: float = 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
    focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(releases: Array, completed_ids: Array, echo_archive: Dictionary, accent: Color) -> void:
    _releases = releases.duplicate(true)
    _completed_ids = completed_ids.duplicate(true)
    _echo_archive = echo_archive.duplicate(true)
    _accent = accent
    _build()

func _build() -> void:
    var dim := ColorRect.new()
    dim.color = Color(0.002, 0.004, 0.009, 0.92)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    UIFactory.add_grain(self, 0.22)

    _panel = PanelContainer.new()
    _panel.mouse_filter = Control.MOUSE_FILTER_PASS
    _panel.add_theme_stylebox_override("panel", UIFactory.menu_style(_accent))
    add_child(_panel)

    _scroll = ScrollContainer.new()
    _scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _panel.add_child(_scroll)

    _content = VBoxContainer.new()
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 10)
    _scroll.add_child(_content)

    var eyebrow := Label.new()
    eyebrow.text = "VIRYA · SYNESTHESIA · PAMIĘĆ ALBUMU"
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    eyebrow.add_theme_font_size_override("font_size", 9)
    eyebrow.add_theme_color_override("font_color", _accent)
    UIFactory.apply_display_font(eyebrow)
    _content.add_child(eyebrow)

    var heading := UIFactory.heading("KORYTARZ")
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 34)
    _content.add_child(heading)

    var intro := UIFactory.body("Drzwi pamiętają wszystkie pokoje. W Album Mode nie ma zadania ani progu ukończenia — wybierz utwór, dotykaj świata i słuchaj pełnego miksu. Echa zostają w archiwum.")
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro.add_theme_font_size_override("font_size", 11)
    _content.add_child(intro)

    for index in range(_releases.size()):
        _add_room_entry(index)

    var finale := UIFactory.menu_button("WRÓĆ DO FINAŁU", Color("e35f83"), true)
    finale.pressed.connect(func() -> void: finale_requested.emit())
    _content.add_child(finale)

    var close := UIFactory.menu_button("WRÓĆ DO MENU", Color("73869d"))
    close.pressed.connect(func() -> void: close_requested.emit())
    _content.add_child(close)

    _layout_panel()
    _apply_ui_scale()
    modulate.a = 0.0
    create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).tween_property(self, "modulate:a", 1.0, 0.24)

func _add_room_entry(index: int) -> void:
    var entry_value: Variant = _releases[index]
    if not entry_value is Dictionary:
        return
    var entry: Dictionary = entry_value
    var manifest: Dictionary = ReleaseReader.load_json(str(entry.get("manifest", "")))
    var room_value: Variant = manifest.get("room", {})
    var room: Dictionary = room_value if room_value is Dictionary else {}
    var release_id: String = str(manifest.get("release_id", entry.get("id", "")))
    var room_accent := Color.from_string(str(room.get("accent_color", "#72AFFF")), _accent)

    var card := PanelContainer.new()
    card.mouse_filter = Control.MOUSE_FILTER_PASS
    card.add_theme_stylebox_override("panel", UIFactory.story_style(room_accent, 0.84, false))
    _content.add_child(card)

    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 4)
    card.add_child(body)

    var unlocked: bool = _completed_ids.has(release_id)
    var button_text: String = "%02d · %s" % [index + 1, str(room.get("name", release_id)).to_upper()]
    var button := UIFactory.menu_button(button_text, room_accent, index == 0)
    button.disabled = not unlocked
    button.tooltip_text = "Otwórz pokój w Album Mode" if unlocked else "Najpierw ukończ ten pokój"
    button.pressed.connect(Callable(self, "_emit_room").bind(index))
    body.add_child(button)

    var echo_titles := PackedStringArray()
    var collectibles_value: Variant = manifest.get("collectibles", [])
    var collectibles: Array = collectibles_value if collectibles_value is Array else []
    var archived_value: Variant = _echo_archive.get(release_id, {})
    var archived: Dictionary = archived_value if archived_value is Dictionary else {}
    for item_value in collectibles:
        if item_value is Dictionary:
            var item: Dictionary = item_value
            var item_id: String = str(item.get("id", ""))
            if unlocked or archived.has(item_id):
                echo_titles.append(str(item.get("title", "Echo")))
    var echo_count: int = echo_titles.size()
    var echo_text := Label.new()
    echo_text.text = "ECHA %d/%d  ·  %s" % [echo_count, collectibles.size(), " · ".join(echo_titles)]
    echo_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    echo_text.add_theme_font_size_override("font_size", 9)
    echo_text.add_theme_color_override("font_color", Color(room_accent, 0.78) if unlocked else Color("6f7b8b"))
    body.add_child(echo_text)

func _emit_room(index: int) -> void:
    room_requested.emit(index)

func _layout_panel() -> void:
    if _panel == null:
        return
    var viewport := get_viewport_rect().size
    _ui_scale = UiMetrics.scale_for_viewport(viewport)
    var margin := clampf(minf(viewport.x, viewport.y) * 0.035, 14.0 * _ui_scale, 44.0 * _ui_scale)
    var width := minf(860.0 * _ui_scale, maxf(320.0 * _ui_scale, viewport.x - margin * 2.0))
    var height := minf(900.0 * _ui_scale, maxf(500.0 * _ui_scale, viewport.y - margin * 2.0))
    _panel.set_anchors_preset(Control.PRESET_CENTER)
    _panel.offset_left = -width * 0.5
    _panel.offset_right = width * 0.5
    _panel.offset_top = -height * 0.5
    _panel.offset_bottom = height * 0.5

func _apply_ui_scale() -> void:
    if _panel != null:
        UiMetrics.apply_tree(_panel, _ui_scale)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_layout_panel")
        call_deferred("_apply_ui_scale")
