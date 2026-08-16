extends Control
# Legacy presentation contract token: UIFactory.story_style(_accent, 0.88, false)
signal settings_requested
const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const SettingsGearIcon := preload("res://scripts/ui/settings_gear_icon.gd")
const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")
const InteractionGuide := preload("res://scripts/app/interaction_guide.gd")
const HudLayoutFlowScript := preload("res://scripts/ui/hud_layout_flow.gd")
const MobileInstructionBuilder := preload("res://scripts/ui/mobile_instruction_builder.gd")
const HudToastControllerScript := preload("res://scripts/ui/hud_toast_controller.gd")
var header_row: HBoxContainer
var top_margin: MarginContainer
var top_panel: PanelContainer
var bottom_margin: MarginContainer
var bottom_panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var counter_label: Label
var split_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var act_label: Label
var brush_label: Label
var palette_row: HBoxContainer
var journey_row: HBoxContainer
var top_content: VBoxContainer
var bottom_content: VBoxContainer
var progress_row: HBoxContainer
var settings_button: Button
var instruction_label: Label
var mobile_instruction_panel: PanelContainer
var mobile_instruction_label: Label
var mobile_instruction_detail_label: Label
var mobile_meta_label: Label
var mobile_instruction_accent_bar: ColorRect
var top_accent_bar: ColorRect
var bottom_accent_bar: ColorRect
var toast_panel: PanelContainer
var toast_label: Label
var toast_accent_bar: ColorRect
var act_banner: PanelContainer
var act_banner_label: Label
var act_accent_bar: ColorRect
var _painting: bool = false
var _context_seen: bool = false
var _restore_timer: Timer
var _act_timer: Timer
var _toast_runtime: Node
var _interaction_guide: Node
var _room_index: int = 0
var _room_total: int = 11
var _echo_found: int = 0
var _echo_total: int = 0
var _resonance_chain: int = 0
var _current_act_index: int = 0
var _current_act_title: String = "ROZPOZNANIE"
var _accent: Color = Color("72afff")
var _ui_scale: float = 1.0
var _layout_flow: Node
func _ready() -> void:
    _layout_flow = HudLayoutFlowScript.new()
    _layout_flow.bind(self)
    add_child(_layout_flow)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_header_row()
    _build_top()
    _build_bottom()
    _build_mobile_instruction()
    _build_toast()
    _build_act_banner()
    _restore_timer = _timer(0.72, func() -> void: set_painting(false))
    _act_timer = _timer(1.65, _hide_act_banner)
    _toast_runtime = HudToastControllerScript.new()
    _toast_runtime.bind(self)
    add_child(_toast_runtime)
    _interaction_guide = InteractionGuide.new()
    _interaction_guide.hint_ready.connect(update_discovery)
    _interaction_guide.visual_hint_changed.connect(_forward_visual_hint)
    _interaction_guide.assist_level_changed.connect(_forward_assist_level)
    add_child(_interaction_guide)
    call_deferred("_apply_ui_scale")
func _forward_visual_hint(strength: float) -> void:
    var stage := get_tree().get_first_node_in_group("synesthesia_room_stage")
    if stage != null and stage.has_method("set_hint_strength"):
        stage.set_hint_strength(strength)
func _forward_assist_level(level: int) -> void:
    var stage := get_tree().get_first_node_in_group("synesthesia_room_stage")
    if stage != null and stage.has_method("set_assist_level"):
        stage.set_assist_level(level)
func suspend_for_menu() -> void:
    clear_transient_overlays()
    _interaction_guide.suspend()
    _painting = false
    if top_panel != null:
        top_panel.modulate.a = 1.0
    if bottom_panel != null:
        bottom_panel.modulate.a = 1.0
    visible = false
func resume_for_room() -> void:
    clear_transient_overlays()
    _interaction_guide.resume()
    visible = true
    _apply_ui_scale()
func clear_transient_overlays() -> void:
    if _restore_timer != null:
        _restore_timer.stop()
    if _act_timer != null:
        _act_timer.stop()
    if _toast_runtime != null:
        _toast_runtime.clear()
    if act_banner != null:
        act_banner.visible = false
        act_banner.modulate.a = 0.0
func _apply_ui_scale() -> void: _layout_flow._apply_ui_scale()
func _timer(wait: float, callback: Callable) -> Timer:
    var timer: Timer = Timer.new()
    timer.one_shot = true
    timer.wait_time = wait
    timer.timeout.connect(callback)
    add_child(timer)
    return timer
func _build_header_row() -> void: _layout_flow._build_header_row()
func _build_top() -> void: _layout_flow._build_top()
func _build_bottom() -> void: _layout_flow._build_bottom()
func _build_mobile_instruction() -> void: _layout_flow._build_mobile_instruction()
func _build_toast() -> void: _layout_flow._build_toast()
func _build_act_banner() -> void: _layout_flow._build_act_banner()
func _layout_story_overlays() -> void: _layout_flow._layout_story_overlays()
func _repair_runtime_refs() -> void: _layout_flow._repair_runtime_refs()
func _set_reveal_ui(normalized: float) -> void:
    _repair_runtime_refs()
    if is_instance_valid(progress_bar):
        progress_bar.value = clampf(normalized, 0.0, 1.0)
    if not is_instance_valid(progress_label):
        return
    if normalized >= 0.99:
        progress_label.text = "OTWARTE · tylko muzyka"
    elif normalized >= 0.70:
        progress_label.text = "MUZYKA"
    elif normalized >= 0.30:
        progress_label.text = "SYGNAŁ"
    else:
        progress_label.text = "SZUM"
func configure_room(title: String, subtitle: String, room_index: int, room_total: int, _album_progress: float, room_data: Dictionary, echo_total: int = 0) -> void:
    _repair_runtime_refs()
    clear_transient_overlays()
    _apply_ui_scale()
    _room_index = room_index
    _room_total = room_total
    _echo_found = 0
    _echo_total = maxi(0, echo_total)
    _resonance_chain = 0
    _current_act_index = 0
    _current_act_title = "ROZPOZNANIE"
    _context_seen = false
    top_panel.modulate.a = 1.0
    bottom_panel.modulate.a = 1.0
    title_label.text = title.trim_prefix("VIRYA: ")
    subtitle_label.text = subtitle
    subtitle_label.visible = true
    counter_label.text = "%02d / %02d" % [room_index + 1, room_total]
    if split_label != null:
        split_label.text = ""
        split_label.visible = false
    _set_reveal_ui(0.0)
    act_label.text = "AKT I · ROZPOZNANIE"
    _refresh_mobile_meta()
    _accent = Color.from_string(str(room_data.get("accent_color", "#72AFFF")), Color("72afff"))
    top_panel.add_theme_stylebox_override("panel", UIFactory.product_inset_style(_accent, 0.22))
    bottom_panel.add_theme_stylebox_override("panel", UIFactory.product_inset_style(_accent.lerp(Color("f0cf88"), 0.42), 0.18))
    top_accent_bar.color = _accent
    bottom_accent_bar.color = _accent.lerp(Color("f3d39d"), 0.42)
    progress_bar.add_theme_stylebox_override("fill", _bar_style(_accent))
    if toast_panel != null:
        toast_panel.add_theme_stylebox_override("panel", UIFactory.product_surface_style(_accent, true))
    if toast_accent_bar != null:
        toast_accent_bar.color = _accent
    if mobile_instruction_panel != null:
        mobile_instruction_panel.modulate.a = 1.0
        mobile_instruction_panel.add_theme_stylebox_override("panel", UIFactory.product_surface_style(_accent, true))
    if mobile_instruction_accent_bar != null:
        mobile_instruction_accent_bar.color = _accent
    _set_palette(room_data)
    var interaction := str(room_data.get("interaction", "paint"))
    instruction_label.text = _interaction_prompt(interaction)
    MobileInstructionBuilder.set_text(self, instruction_label.text)
    _interaction_guide.configure(interaction)
    var viewport_size: Vector2 = get_viewport_rect().size
    if viewport_size.y > viewport_size.x and viewport_size.x <= 900.0 * _ui_scale:
        _interaction_guide.boost_mobile_first_entry()
    _rebuild_journey()
    _hide_toast()
    _hide_act_banner()
func show_split_delta(delta_ms: int) -> void:
    if split_label == null:
        return
    var sign: String = "−" if delta_ms < 0 else "+"
    if delta_ms == 0:
        sign = "±"
    split_label.text = "SPLIT %s%s" % [sign, _format_split_time(absi(delta_ms))]
    split_label.add_theme_color_override("font_color", Color("8fe3b0") if delta_ms <= 0 else Color("f0cf88"))
    split_label.visible = true
    split_label.modulate.a = 0.0
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(split_label, "modulate:a", 0.82, 0.14)
    tween.tween_interval(1.25)
    tween.tween_property(split_label, "modulate:a", 0.0, 0.34)
    tween.tween_callback(func() -> void:
        if split_label != null:
            split_label.visible = false
    )
func _format_split_time(value_ms: int) -> String:
    var seconds: float = float(maxi(0, value_ms)) / 1000.0
    return "%.1fs" % seconds if seconds < 60.0 else "%d:%04.1f" % [int(seconds / 60.0), fmod(seconds, 60.0)]
func note_miss() -> void:
    if _interaction_guide != null:
        _interaction_guide.note_miss()
func prime_hint_after_resume() -> void:
    if _interaction_guide != null:
        _interaction_guide.prime_after_resume()
func note_success() -> void:
    if _interaction_guide != null:
        _interaction_guide.note_interaction()
func guidance_stats() -> Dictionary:
    if _interaction_guide != null:
        return _interaction_guide.get_stats()
    return {}
func enter_completion_beat() -> void:
    if _interaction_guide != null:
        _interaction_guide.suspend()
    set_painting(false)
    if instruction_label != null:
        instruction_label.text = "Komnata odpowiedziała. Przejście już czeka."
    MobileInstructionBuilder.set_text(self, "KOMNATA ODPOWIEDZIAŁA · PRZEJŚCIE CZEKA")
    # After full reveal the artwork, not the instrument panel, owns the screen.
    # Keep the navigation affordance readable while secondary HUD chrome recedes.
    subtitle_label.visible = false
    palette_row.visible = false
    brush_label.visible = false
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(top_panel, "modulate:a", 0.18, 0.48)
    tween.tween_property(bottom_panel, "modulate:a", 0.30, 0.48)
func update_reveal(normalized: float) -> void:
    _set_reveal_ui(normalized)
    _interaction_guide.note_progress(normalized)
func update_instruction(text_value: String) -> void:
    if instruction_label == null or text_value.strip_edges().is_empty():
        return
    instruction_label.text = text_value.strip_edges().to_upper()
    MobileInstructionBuilder.set_text(self, instruction_label.text)
func update_echo_count(found: int, total: int = -1) -> void:
    _echo_found = maxi(0, found)
    if total >= 0: _echo_total = maxi(0, total)
    _refresh_mobile_meta()
func update_resonance_chain(chain: int) -> void:
    var next_chain := clampi(chain, 0, 6)
    if next_chain != _resonance_chain:
        _resonance_chain = next_chain
        _refresh_mobile_meta()
func _refresh_mobile_meta() -> void:
    MobileInstructionBuilder.set_mobile_meta(self, _current_act_index, _current_act_title, _echo_found, _echo_total, _resonance_chain)
func update_discovery(text_value: String) -> void:
    if _toast_runtime != null:
        _toast_runtime.show(text_value)
func update_act(index: int, title: String) -> void:
    _current_act_index = clampi(index, 0, 2)
    _current_act_title = title
    act_label.text = "AKT %s · %s" % [_roman(index + 1), title]
    _refresh_mobile_meta()
    if index <= 0:
        return
    act_banner_label.text = "AKT %s  ·  %s" % [_roman(index + 1), title]
    act_banner.visible = true
    act_banner.modulate.a = 0.0
    act_banner.scale = Vector2(0.97, 0.97)
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(act_banner, "modulate:a", 1.0, 0.18)
    tween.tween_property(act_banner, "scale", Vector2.ONE, 0.22)
    _act_timer.start()
func set_painting(value: bool) -> void:
    if _painting == value:
        if value:
            _restore_timer.start()
        return
    _painting = value
    if value:
        _context_seen = true
        _interaction_guide.note_interaction()
        _restore_timer.start()
    # Gameplay owns the screen after the first interaction: HUD recedes to a
    # thin signal instrument instead of competing with room art.
    var target_alpha: float = 0.30 if value else (0.72 if _context_seen else 1.0)
    var target_bottom_alpha: float = 0.24 if value else (0.62 if _context_seen else 1.0)
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(top_panel, "modulate:a", target_alpha, 0.16)
    tween.tween_property(bottom_panel, "modulate:a", target_bottom_alpha, 0.16)
    if mobile_instruction_panel != null:
        var mobile_alpha: float = 0.38 if value else (0.70 if _context_seen else 1.0)
        tween.tween_property(mobile_instruction_panel, "modulate:a", mobile_alpha, 0.16)
    subtitle_label.visible = true
    palette_row.visible = true
    brush_label.visible = true
    instruction_label.visible = true
func show_final() -> void:
    _repair_runtime_refs()
    title_label.text = "Synestezja"
    subtitle_label.text = "Jedenaście pokojów. Jeden pełny Sygnał."
    subtitle_label.visible = true
    counter_label.text = "FINAŁ"
    _set_reveal_ui(1.0)
    if is_instance_valid(progress_label):
        progress_label.text = "Album odsłonięty"
    act_label.text = "CAŁE DOŚWIADCZENIE"
    _room_index = _room_total - 1
    _rebuild_journey(true)
    set_painting(false)
func _rebuild_journey(force_complete: bool = false) -> void:
    for child in journey_row.get_children():
        child.queue_free()
    for index in range(_room_total):
        var dot: ColorRect = ColorRect.new()
        var completed: bool = force_complete or index < _room_index
        var current: bool = not force_complete and index == _room_index
        dot.custom_minimum_size = Vector2((18.0 if current else 10.0) * _ui_scale, 2.0 * _ui_scale)
        if completed:
            dot.color = Color(_accent, 0.64)
        elif current:
            dot.color = _accent
        else:
            dot.color = Color("91a4b42f")
        dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        journey_row.add_child(dot)
func _set_palette(room_data: Dictionary) -> void:
    for child in palette_row.get_children():
        child.queue_free()
    var palette_value: Variant = room_data.get("paint_palette", [])
    if palette_value is Array:
        for raw_color in palette_value:
            var swatch: ColorRect = ColorRect.new()
            swatch.color = Color.from_string(str(raw_color), Color("72afff"))
            swatch.custom_minimum_size = Vector2(20.0 * _ui_scale, 3.0 * _ui_scale)
            swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
            palette_row.add_child(swatch)
    var brush_value: Variant = room_data.get("brush", {})
    var brush: Dictionary = brush_value if brush_value is Dictionary else {}
    brush_label.text = "ŚLAD DŁONI %s · GŁÓWNY RYTUAŁ ROZPRASZA SZUM" % _brush_name(str(brush.get("profile", "soft"))).to_upper()
func _interaction_prompt(interaction: String) -> String:
    var prompts: Dictionary = {
        "paint": "PROWADŹ FALĘ W BOK · NIE WALCZ Z NIĄ",
        "pop_balloons": "DOTKNIJ · ODEPCHNIJ · PRZEBIJ",
        "venetian_masks": "PUKNIJ W MASKĘ · ZSUŃ JĄ",
        "toast_table": "PRZYTRZYMAJ WINO · PRZYSUŃ KIELISZEK",
        "grow_tree": "PRZYTRZYMAJ ZIARNO · PROWADŹ WZROST",
        "western_duel": "PRZYTRZYMAJ CEL · PUŚĆ",
        "repair_glitches": "SZUKAJ ŹRÓDEŁ SZUMU · CHWYTAJ · ODŁĄCZAJ",
        "crack_mirrors": "PUKNIJ W TAFLĘ · ZRZUĆ JĄ RUCHEM",
        "raise_phoenix": "ZAKRĘĆ POPIOŁEM · UNIEŚ RUCH",
        "intimate_bedroom": "PRZYTRZYMAJ OBECNOŚĆ · ZBLIŻ DWA PUNKTY",
        "rise_atrium": "DOTKNIJ ŚWIATŁA · PRZYTRZYMAJ · UNIEŚ",
    }
    return str(prompts.get(interaction, "DOTKNIJ ŚWIATA · ZOSTAW ŚLAD · ODSŁOŃ PRZEJŚCIE"))
func _hide_toast() -> void:
    if _toast_runtime != null:
        _toast_runtime.hide()
func _hide_act_banner() -> void:
    if act_banner == null or not act_banner.visible:
        return
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.tween_property(act_banner, "modulate:a", 0.0, 0.24)
    tween.finished.connect(func() -> void: act_banner.visible = false)
func _apply_mobile_safe_area() -> void: _layout_flow._apply_mobile_safe_area()
func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_apply_ui_scale")
func _bar_style(color: Color) -> StyleBoxFlat: return _layout_flow._bar_style(color)
func _brush_name(profile: String) -> String:
    match profile:
        "water": return "PĘDZEL WODNY"
        "confetti": return "PĘDZEL KONFETTI"
        "ink": return "PĘDZEL ATRAMENTOWY"
        "wine": return "PĘDZEL KALIGRAFICZNY"
        "organic": return "PĘDZEL ORGANICZNY"
        "dry_ink": return "SUCHY TUSZ"
        "glitch": return "PĘDZEL GLITCH"
        "glass": return "PĘDZEL SZKLISTY"
        "ember": return "PĘDZEL ŻAROWY"
        "luminous": return "PĘDZEL ŚWIETLNY"
        _: return "MIĘKKI PĘDZEL"
func _roman(value: int) -> String:
    match value:
        1: return "I"
        2: return "II"
        _: return "III"
