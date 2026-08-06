extends Control

const PaintRoomScript := preload("res://scripts/paint_room.gd")
const AudioDirectorScript := preload("res://scripts/audio_director.gd")
const HapticsScript := preload("res://scripts/haptics.gd")
const ProgressStoreScript := preload("res://scripts/progress_store.gd")
const SnowShader := preload("res://shaders/visual_snow.gdshader")
const RELEASE_INDEX_PATH := "res://data/release_index.json"

var manifest: Dictionary = {}
var room
var audio_director
var haptics
var snow_material: ShaderMaterial
var progress_label: Label
var discovery_label: Label
var mode_button: Button
var quiet_button: Button
var completion_panel: PanelContainer
var completion_label: Label
var calm_mode: bool = true
var quiet_mode: bool = false
var current_coverage: float = 0.0
var completion_announced: bool = false
var collectible_total: int = 0
var save_timer: Timer
var intro_panel: PanelContainer
var restoring_progress: bool = false

func _ready() -> void:
    var manifest_path: String = _resolve_active_manifest(RELEASE_INDEX_PATH)
    if manifest_path.is_empty():
        _show_fatal_error("Nie udało się odnaleźć aktywnego pokoju.")
        return

    manifest = _load_manifest(manifest_path)
    if manifest.is_empty():
        _show_fatal_error("Nie udało się wczytać pokoju.")
        return

    var collectible_entries: Array = manifest.get("collectibles", [])
    collectible_total = maxi(1, collectible_entries.size())
    calm_mode = str(manifest.get("sensory", {}).get("default_mode", "calm")) == "calm"
    _build_experience()

func _resolve_active_manifest(path: String) -> String:
    if not FileAccess.file_exists(path):
        push_error("Missing release index: %s" % path)
        return ""
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Cannot open release index: %s" % path)
        return ""
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        push_error("Release index is not a JSON object")
        return ""
    var index: Dictionary = parsed
    var active_id := str(index.get("active_release", ""))
    var releases: Array = index.get("releases", [])
    for release_value in releases:
        if not release_value is Dictionary:
            continue
        var release: Dictionary = release_value
        if str(release.get("id", "")) != active_id or not bool(release.get("available", true)):
            continue
        var manifest_path := str(release.get("manifest", ""))
        if manifest_path.begins_with("res://"):
            return manifest_path
    push_error("Active release is missing or unavailable: %s" % active_id)
    return ""

func _load_manifest(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("Missing release manifest: %s" % path)
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Cannot open release manifest: %s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        push_error("Release manifest is not a JSON object")
        return {}
    var data: Dictionary = parsed
    for required_key in ["schema_version", "release_id", "room", "sensory", "collectibles"]:
        if not data.has(required_key):
            push_error("Release manifest missing key: %s" % required_key)
            return {}
    return data

func _build_experience() -> void:
    room = PaintRoomScript.new()
    room.name = "PaintRoom"
    add_child(room)
    room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    room.configure(manifest["room"], manifest["collectibles"])
    room.coverage_changed.connect(_on_coverage_changed)
    room.collectible_found.connect(_on_collectible_found)
    room.paint_pulse.connect(_on_paint_pulse)

    _build_snow_overlay()
    _build_top_ui()
    _build_bottom_ui()
    _build_completion_panel()

    audio_director = AudioDirectorScript.new()
    audio_director.name = "AudioDirector"
    add_child(audio_director)
    var release_audio: Dictionary = manifest.get("audio", {})
    audio_director.configure(manifest["sensory"], release_audio, collectible_total)
    audio_director.set_calm_mode(calm_mode)

    haptics = HapticsScript.new()
    haptics.name = "Haptics"
    add_child(haptics)
    haptics.configure(manifest["sensory"])
    haptics.set_calm_mode(calm_mode)

    room.set_calm_mode(calm_mode)
    _build_save_timer()
    _apply_sensory_mode()
    call_deferred("_restore_or_introduce")

func _build_save_timer() -> void:
    save_timer = Timer.new()
    save_timer.name = "ProgressSaveTimer"
    save_timer.one_shot = true
    save_timer.wait_time = 1.2
    save_timer.timeout.connect(_save_progress)
    add_child(save_timer)

func _restore_or_introduce() -> void:
    await get_tree().process_frame
    var release_id: String = str(manifest.get("release_id", ""))
    var saved: Dictionary = ProgressStoreScript.load_release(release_id)
    if saved.is_empty():
        _show_intro()
        return

    restoring_progress = true
    calm_mode = bool(saved.get("calm_mode", calm_mode))
    quiet_mode = bool(saved.get("quiet_mode", false))
    completion_announced = bool(saved.get("completed", false))
    var room_state: Variant = saved.get("room", {})
    var restored: bool = false
    if room_state is Dictionary:
        restored = bool(room.restore_state(room_state))
    room.set_calm_mode(calm_mode)
    haptics.set_calm_mode(calm_mode)
    audio_director.set_calm_mode(calm_mode)
    haptics.set_enabled(not quiet_mode)
    audio_director.set_quiet(quiet_mode)
    _apply_sensory_mode()
    quiet_button.text = "Przywróć zmysły" if quiet_mode else "Uspokój pokój"
    if restored:
        var found: int = int(room.get_found_count())
        current_coverage = room.get_coverage()
        discovery_label.text = "%d/%d ślady · pokój pamięta Twój poprzedni dotyk" % [found, collectible_total]
        progress_label.text = "%d%% pokoju pamięta · możesz spokojnie kontynuować" % int(round(current_coverage * 100.0))
        audio_director.set_progress(current_coverage, found)
        _check_completion()
    restoring_progress = false

func _show_intro() -> void:
    room.set_interaction_enabled(false)
    intro_panel = PanelContainer.new()
    intro_panel.name = "GentleIntroduction"
    intro_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    intro_panel.add_theme_stylebox_override("panel", _panel_style(Color("111a2af7"), 28))
    add_child(intro_panel)
    intro_panel.set_anchors_preset(Control.PRESET_CENTER)
    intro_panel.offset_left = -270.0
    intro_panel.offset_top = -155.0
    intro_panel.offset_right = 270.0
    intro_panel.offset_bottom = 155.0

    var content := VBoxContainer.new()
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 14)
    intro_panel.add_child(content)

    var heading := Label.new()
    heading.text = str(manifest.get("room", {}).get("name", "Pokój pierwszy"))
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 28)
    heading.add_theme_color_override("font_color", Color("eef6ff"))
    content.add_child(heading)

    var message := Label.new()
    message.text = str(manifest.get("intro", "Dotykaj ścian i zostawiaj kolor. Dźwięk odpowie powoli.\nNie ma czasu, punktów ani właściwej drogi."))
    message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message.add_theme_font_size_override("font_size", 16)
    message.add_theme_color_override("font_color", Color("bed2ed"))
    content.add_child(message)

    var enter_button := _make_button("Wejdź bez pośpiechu")
    enter_button.pressed.connect(_dismiss_intro)
    content.add_child(enter_button)

func _dismiss_intro() -> void:
    if intro_panel != null:
        intro_panel.queue_free()
        intro_panel = null
    room.set_interaction_enabled(true)
    _schedule_save()

func _schedule_save() -> void:
    if restoring_progress or save_timer == null:
        return
    save_timer.start()

func _save_progress() -> void:
    if room == null or manifest.is_empty():
        return
    ProgressStoreScript.save_release(str(manifest.get("release_id", "")), {
        "calm_mode": calm_mode,
        "quiet_mode": quiet_mode,
        "completed": completion_announced,
        "room": room.export_state(),
    })

func _build_snow_overlay() -> void:
    var snow := ColorRect.new()
    snow.name = "GentleVisualSnow"
    snow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    snow.color = Color.WHITE
    add_child(snow)
    snow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    snow_material = ShaderMaterial.new()
    snow_material.shader = SnowShader
    snow.material = snow_material

func _build_top_ui() -> void:
    var margin := MarginContainer.new()
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_theme_constant_override("margin_left", 26)
    margin.add_theme_constant_override("margin_top", 24)
    margin.add_theme_constant_override("margin_right", 26)
    add_child(margin)
    margin.set_anchors_preset(Control.PRESET_TOP_WIDE)

    var panel := PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", _panel_style(Color("0b101bda"), 22))
    margin.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 5)
    panel.add_child(content)

    var title := Label.new()
    title.text = str(manifest.get("title", "VIRYA: Synestezja"))
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color("eef6ff"))
    content.add_child(title)

    var subtitle := Label.new()
    subtitle.text = str(manifest.get("subtitle", ""))
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.add_theme_font_size_override("font_size", 14)
    subtitle.add_theme_color_override("font_color", Color("b8c7dc"))
    content.add_child(subtitle)

    progress_label = Label.new()
    progress_label.text = "Pokój pozostaje cichy. Dotknij ściany."
    progress_label.add_theme_font_size_override("font_size", 13)
    progress_label.add_theme_color_override("font_color", Color("7fb7ff"))
    content.add_child(progress_label)

func _build_bottom_ui() -> void:
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 24)
    margin.add_theme_constant_override("margin_right", 24)
    margin.add_theme_constant_override("margin_bottom", 22)
    add_child(margin)
    margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)

    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _panel_style(Color("090d17e8"), 24))
    margin.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 10)
    panel.add_child(content)

    discovery_label = Label.new()
    discovery_label.text = "0/%d ślady · maluj bez pośpiechu" % collectible_total
    discovery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    discovery_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    discovery_label.add_theme_font_size_override("font_size", 14)
    discovery_label.add_theme_color_override("font_color", Color("d6e7ff"))
    content.add_child(discovery_label)

    var buttons := HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 10)
    content.add_child(buttons)

    mode_button = _make_button("")
    mode_button.pressed.connect(_toggle_mode)
    buttons.add_child(mode_button)

    quiet_button = _make_button("Uspokój pokój")
    quiet_button.pressed.connect(_toggle_quiet)
    buttons.add_child(quiet_button)

    var reset_button := _make_button("Od nowa")
    reset_button.pressed.connect(_reset_room)
    buttons.add_child(reset_button)

func _build_completion_panel() -> void:
    completion_panel = PanelContainer.new()
    completion_panel.visible = false
    completion_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    completion_panel.add_theme_stylebox_override("panel", _panel_style(Color("111a2af2"), 28))
    add_child(completion_panel)
    completion_panel.set_anchors_preset(Control.PRESET_CENTER)
    completion_panel.offset_left = -260.0
    completion_panel.offset_top = -115.0
    completion_panel.offset_right = 260.0
    completion_panel.offset_bottom = 115.0

    var content := VBoxContainer.new()
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 14)
    completion_panel.add_child(content)

    var heading := Label.new()
    heading.text = str(manifest.get("completion_title", "Pokój się otworzył"))
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 26)
    heading.add_theme_color_override("font_color", Color("eef6ff"))
    content.add_child(heading)

    completion_label = Label.new()
    completion_label.text = str(manifest.get("completion_message", "Nie wygrałeś. Nie przegrałeś. Zostawiłeś tu swój ślad."))
    completion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    completion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    completion_label.add_theme_font_size_override("font_size", 15)
    completion_label.add_theme_color_override("font_color", Color("bed2ed"))
    content.add_child(completion_label)

    var close_button := _make_button("Zostań i słuchaj")
    close_button.pressed.connect(func() -> void: completion_panel.visible = false)
    content.add_child(close_button)

func _panel_style(color: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    style.content_margin_left = 18.0
    style.content_margin_right = 18.0
    style.content_margin_top = 15.0
    style.content_margin_bottom = 15.0
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = Color("72afff35")
    return style

func _make_button(text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(0.0, 48.0)
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_color_override("font_color", Color("e7f2ff"))
    button.add_theme_stylebox_override("normal", _panel_style(Color("18243aeb"), 15))
    button.add_theme_stylebox_override("hover", _panel_style(Color("223655f4"), 15))
    button.add_theme_stylebox_override("pressed", _panel_style(Color("0e1728f4"), 15))
    return button

func _on_coverage_changed(value: float) -> void:
    current_coverage = value
    var percent: int = int(round(value * 100.0))
    progress_label.text = "%d%% pokoju reaguje · dźwięk odsłania się warstwami" % percent
    if audio_director != null:
        audio_director.set_progress(value, room.get_found_count())
    _check_completion()
    _schedule_save()

func _on_collectible_found(item: Dictionary) -> void:
    var count: int = int(room.get_found_count())
    discovery_label.text = "%d/%d · %s — %s" % [count, collectible_total, str(item.get("title", "Ślad")), str(item.get("message", ""))]
    if haptics != null:
        haptics.discovery()
    if audio_director != null:
        audio_director.set_progress(current_coverage, count)
    _check_completion()
    _schedule_save()

func _on_paint_pulse(speed_normalized: float) -> void:
    if haptics != null:
        haptics.paint_tick(speed_normalized)

func _toggle_mode() -> void:
    calm_mode = not calm_mode
    room.set_calm_mode(calm_mode)
    haptics.set_calm_mode(calm_mode)
    audio_director.set_calm_mode(calm_mode)
    _apply_sensory_mode()
    _schedule_save()

func _apply_sensory_mode() -> void:
    var sensory: Dictionary = manifest["sensory"]
    var snow: float = float(sensory.get("visual_snow_calm", 0.022)) if calm_mode else float(sensory.get("visual_snow_full", 0.055))
    snow_material.set_shader_parameter("intensity", snow if not quiet_mode else 0.0)
    snow_material.set_shader_parameter("motion", 0.12 if calm_mode else 0.32)
    mode_button.text = "Tryb spokojny" if calm_mode else "Tryb pełny"

func _toggle_quiet() -> void:
    quiet_mode = not quiet_mode
    haptics.set_enabled(not quiet_mode)
    audio_director.set_quiet(quiet_mode)
    snow_material.set_shader_parameter("intensity", 0.0 if quiet_mode else _current_snow_intensity())
    quiet_button.text = "Przywróć zmysły" if quiet_mode else "Uspokój pokój"
    progress_label.text = "Pokój został uspokojony. Nadal możesz malować." if quiet_mode else "%d%% pokoju reaguje" % int(round(current_coverage * 100.0))
    _schedule_save()

func _current_snow_intensity() -> float:
    var sensory: Dictionary = manifest["sensory"]
    return float(sensory.get("visual_snow_calm", 0.022)) if calm_mode else float(sensory.get("visual_snow_full", 0.055))

func _reset_room() -> void:
    ProgressStoreScript.clear_release(str(manifest.get("release_id", "")))
    completion_announced = false
    completion_panel.visible = false
    room.reset_room()
    discovery_label.text = "0/%d ślady · maluj bez pośpiechu" % collectible_total
    progress_label.text = "Pokój pozostaje cichy. Dotknij ściany."
    audio_director.set_progress(0.0, 0)
    audio_director.reset_release_excerpt()
    current_coverage = 0.0

func _check_completion() -> void:
    if completion_announced:
        return
    var threshold: float = float(manifest["room"].get("completion_coverage", 0.44))
    if current_coverage >= threshold and room.get_found_count() == collectible_total:
        completion_announced = true
        completion_panel.visible = true
        haptics.discovery()
        audio_director.reveal_release_excerpt()
        _schedule_save()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        _save_progress()

func _show_fatal_error(message: String) -> void:
    var label := Label.new()
    label.text = message
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 22)
    add_child(label)
    label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
