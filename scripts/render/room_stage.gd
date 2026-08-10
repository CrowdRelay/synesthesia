extends Control
signal coverage_changed(value: float)
signal collectible_found(item: Dictionary)
signal paint_pulse(speed_normalized: float)
signal special_interaction(kind: String, index: int)
signal interaction_feedback(message: String)
signal interaction_started
signal interaction_ended
signal interaction_missed(point: Vector2)
signal interaction_confirmed(point: Vector2, strength: float)
signal act_changed(index: int, title: String)
const BrushEngineScript := preload("res://scripts/brush/brush_engine.gd")
const InteractionRouterScript := preload("res://scripts/input/interaction_router.gd")
const RoomInteractionRuntimeScript := preload("res://scripts/input/room_interaction_runtime.gd")
const RoomInteractionFlowScript := preload("res://scripts/render/room_interaction_flow.gd")
const RoomStateFlowScript := preload("res://scripts/render/room_state_flow.gd")
const MechanicProgress := preload("res://scripts/rooms/mechanic_progress.gd")
const DebugProfile := preload("res://scripts/app/debug_profile.gd")
const RevealMaskScript := preload("res://scripts/render/reveal_mask.gd")
const AtmosphereLayerScript := preload("res://scripts/render/atmosphere_layer.gd")
const InteractionFxLayerScript := preload("res://scripts/render/interaction_fx_layer.gd")
const RoomDressingLayerScript := preload("res://scripts/render/room_dressing_layer.gd")
const RoomVideoLayerScript := preload("res://scripts/render/room_video_layer.gd")
const InteractionHintLayerScript := preload("res://scripts/render/interaction_hint_layer.gd")
const InteractionAttemptFeedbackScript := preload("res://scripts/input/interaction_attempt_feedback.gd")
const CompositeShader := preload("res://shaders/room_composite.gdshader")
const RoomVisualSetupScript := preload("res://scripts/render/room_visual_setup.gd")
@export var room_id: String = ""
var manifest_room: Dictionary = {}
var sensory: Dictionary = {}
var quality: Dictionary = {}
var collectibles: Array[Dictionary] = []
var behavior
var _behavior_tick_gated: bool = false
var brush_engine
var interaction_router
var interaction_runtime
var attempt_feedback
var reveal_mask
var composite: TextureRect
var composite_material: ShaderMaterial
var atmosphere
var interaction_fx
var room_dressing
var video_layer
var hint_layer
var world_micro_fx; var interaction_enabled: bool = true
var calm_mode: bool = true
var reduced_motion: bool = false
var quiet_visuals: bool = false
var cinematic_revealed: bool = false
var door_target_open: bool = false
var door_open_amount: float = 0.0
var completion_threshold: float = 0.44
var current_progress: float = 0.0
var current_act: int = -1
var pointer_norm: Vector2 = Vector2(0.5, 0.5)
var target_parallax: Vector2 = Vector2.ZERO
var smoothed_parallax: Vector2 = Vector2.ZERO
var drawing: bool = false
var _drawing_pointer_id: int = -999
var _phase: float = 0.0
var _redraw_accumulator: float = 0.0
var _upload_accumulator: float = 0.0
var _texture_upload_hz: float = 30.0
var _base_texture_upload_hz: float = 30.0
var _last_pulse_ms: int = 0
var _last_special_ms: Dictionary = {}
var _cinematic_mix: float = 0.0
var _cinematic_target: float = 0.0
var _brush_energy: float = 0.0
var _runtime_scale: float = 1.0
var _hint_refresh_accumulator: float = 0.0
var _last_parallax_sent: Vector2 = Vector2(99.0, 99.0)
var _last_coverage_emitted: float = -1.0
var _cinematic_elapsed: float = 0.0
var _unlock_profile: int = 0
var _accent_color: Color = Color("72afff")
var _interaction_flow: Node
var _state_flow: Node
var _visual_setup: Node
func _ready() -> void:
    _visual_setup = RoomVisualSetupScript.new(); _visual_setup.bind(self); add_child(_visual_setup)
    _interaction_flow = RoomInteractionFlowScript.new(); _interaction_flow.bind(self); add_child(_interaction_flow)
    _state_flow = RoomStateFlowScript.new(); _state_flow.bind(self); add_child(_state_flow)
    mouse_filter = Control.MOUSE_FILTER_STOP
    focus_mode = Control.FOCUS_NONE
    clip_contents = true
    add_to_group("synesthesia_room_stage")
    _build_composite()
    set_process(true)
func _build_composite() -> void:
    _visual_setup._build_composite()
func configure(room_data: Dictionary, collectible_data: Array, sensory_data: Dictionary = {}, quality_data: Dictionary = {}, asset_source = null) -> void:
    manifest_room = room_data.duplicate(true)
    sensory = sensory_data.duplicate(true)
    quality = quality_data.duplicate(true)
    room_id = str(room_data.get("id", room_id))
    completion_threshold = clampf(float(room_data.get("completion_coverage", 0.44)), 0.20, 0.75)
    _base_texture_upload_hz = clampf(float(quality.get("texture_upload_hz", 30.0)), 12.0, 60.0)
    _texture_upload_hz = _base_texture_upload_hz
    brush_engine = BrushEngineScript.new()
    var brush_value: Variant = room_data.get("brush", {})
    var brush: Dictionary = brush_value if brush_value is Dictionary else {}
    brush_engine.configure(DebugProfile.tune_debug_brush(brush))
    interaction_router = InteractionRouterScript.new()
    interaction_router.reset()
    reveal_mask = RevealMaskScript.new()
    reveal_mask.configure(
        int(quality.get("mask_width", 270)),
        int(quality.get("mask_height", 480)),
    )
    collectibles.clear()
    for value in collectible_data:
        if value is Dictionary:
            var item: Dictionary = value.duplicate(true)
            item["found"] = false
            collectibles.append(item)
    _accent_color = Color.from_string(str(room_data.get("accent_color", "#72AFFF")), Color("72afff"))
    var secondary_color: Color = Color.from_string(str(room_data.get("secondary_color", "#FF6680")), Color("ff6680"))
    _configure_behavior(room_data)
    _configure_art(room_data, asset_source)
    atmosphere.configure(
        str(room_data.get("visual_style", "uncertainty")),
        _accent_color,
        secondary_color,
        quality,
    )
    interaction_fx.configure(_accent_color, secondary_color)
    hint_layer.configure(str(room_data.get("interaction", "paint")), _accent_color)
    _refresh_hint_targets()
    interaction_fx.set_sensory(calm_mode, reduced_motion)
    interaction_runtime = RoomInteractionRuntimeScript.new()
    interaction_runtime.configure(behavior, reveal_mask, interaction_fx)
    interaction_runtime.reveal_changed.connect(_on_gesture_reveal_changed)
    interaction_runtime.special_interaction.connect(_on_runtime_special)
    interaction_runtime.feedback.connect(func(message: String) -> void: interaction_feedback.emit(message))
    attempt_feedback = InteractionAttemptFeedbackScript.new()
    attempt_feedback.missed.connect(func(point: Vector2) -> void: interaction_missed.emit(point))
    attempt_feedback.confirmed.connect(_on_attempt_confirmed)
    var visual_style: String = str(room_data.get("visual_style", "uncertainty"))
    room_dressing.configure(visual_style, _accent_color, secondary_color)
    if world_micro_fx != null:
        world_micro_fx.configure(visual_style, _accent_color, secondary_color, behavior)
    room_dressing.set_reduced_motion(reduced_motion)
    video_layer.configure(visual_style, reduced_motion, quiet_visuals, calm_mode)
    _unlock_profile = _unlock_profile_index(visual_style)
    composite_material.set_shader_parameter("unlock_profile", _unlock_profile)
    composite_material.set_shader_parameter("cinematic_time", 0.0)
    composite_material.set_shader_parameter("unlock_motion", 0.0)
    _set_progress_from_mask()
    queue_redraw()
func _configure_behavior(room_data: Dictionary) -> void:
    _visual_setup._configure_behavior(room_data)
func _configure_art(room_data: Dictionary, asset_source = null) -> void:
    _visual_setup._configure_art(room_data, asset_source)
func _take_texture(path: String, asset_source = null) -> Texture2D:
    return _visual_setup._take_texture(path, asset_source)
func _process(delta: float) -> void:
    if behavior != null and (not _behavior_tick_gated or behavior.needs_tick()):
        behavior.advance(delta)
    _hint_refresh_accumulator += delta
    if _hint_refresh_accumulator >= 0.20:
        _hint_refresh_accumulator = 0.0
        _refresh_hint_targets()
    if world_micro_fx != null:
        world_micro_fx.set_progress(current_progress)
        world_micro_fx.set_pointer(pointer_norm)
        world_micro_fx.set_cinematic(_cinematic_mix)
    if interaction_enabled and interaction_router != null and interaction_router.needs_tick():
        _handle_gestures(interaction_router.advance(Time.get_ticks_msec()))
    var target: float = 1.0 if door_target_open else 0.0
    door_open_amount = move_toward(door_open_amount, target, delta * 0.82)
    if room_dressing != null:
        room_dressing.set_door_open_amount(door_open_amount)
    if cinematic_revealed:
        _cinematic_elapsed = fmod(_cinematic_elapsed + delta, 10000.0)
        var camera_amount: float = 0.045 if reduced_motion else (0.20 if calm_mode else 0.27)
        var camera_speed: float = 0.22 + float(_unlock_profile % 4) * 0.018
        target_parallax = Vector2(
            sin(_cinematic_elapsed * TAU * camera_speed) * camera_amount,
            sin(_cinematic_elapsed * TAU * camera_speed * 0.53 + 0.8) * camera_amount * 0.24
        )
        composite_material.set_shader_parameter("cinematic_time", _cinematic_elapsed)
    var motion_factor: float = 0.18 if reduced_motion else (0.58 if calm_mode else 0.90)
    smoothed_parallax = smoothed_parallax.lerp(target_parallax, clampf(delta * 4.5 * motion_factor, 0.0, 1.0))
    if smoothed_parallax.distance_squared_to(_last_parallax_sent) > 0.000001:
        _last_parallax_sent = smoothed_parallax
        composite_material.set_shader_parameter("parallax", smoothed_parallax)
    var next_cinematic_mix: float = move_toward(_cinematic_mix, _cinematic_target, delta * (1.05 if reduced_motion else 1.42))
    if not is_equal_approx(next_cinematic_mix, _cinematic_mix):
        _cinematic_mix = next_cinematic_mix
        composite_material.set_shader_parameter("completion_reveal", _cinematic_mix)
        composite_material.set_shader_parameter("unlock_motion", _cinematic_mix * (0.10 if reduced_motion else 1.0))
        if room_dressing != null: room_dressing.set_cinematic(_cinematic_mix)
    var next_brush_energy: float = move_toward(_brush_energy, 0.0, delta * (2.8 if calm_mode else 3.8))
    if not is_equal_approx(next_brush_energy, _brush_energy):
        _brush_energy = next_brush_energy
        composite_material.set_shader_parameter("brush_energy", _brush_energy)
    _upload_accumulator += delta
    if _upload_accumulator >= 1.0 / _texture_upload_hz:
        _upload_accumulator = 0.0
        reveal_mask.upload_if_dirty()
    _phase = fmod(_phase + delta * (0.32 if calm_mode else 0.72), 1000.0)
    _redraw_accumulator += delta
    var redraw_hz: float = 10.0 if reduced_motion else (24.0 if calm_mode else 30.0) * _runtime_scale
    if drawing or not is_equal_approx(door_open_amount, target):
        redraw_hz = maxf(24.0, 45.0 * _runtime_scale)
    if _redraw_accumulator >= 1.0 / redraw_hz:
        _redraw_accumulator = 0.0
        queue_redraw()
func set_calm_mode(value: bool) -> void:
    calm_mode = value
    video_layer.set_calm_mode(value)
    atmosphere.set_sensory(calm_mode, reduced_motion)
    interaction_fx.set_sensory(calm_mode, reduced_motion)
    composite_material.set_shader_parameter(
        "motion",
        float(sensory.get("static_motion_calm", 0.18)) if calm_mode else float(sensory.get("static_motion_full", 0.46)),
    )
func set_reduced_motion(value: bool) -> void:
    reduced_motion = value
    video_layer.set_reduced_motion(value)
    atmosphere.set_sensory(calm_mode, reduced_motion)
    interaction_fx.set_sensory(calm_mode, reduced_motion)
    if hint_layer != null:
        hint_layer.set_reduced_motion(reduced_motion)
    if room_dressing != null:
        room_dressing.set_reduced_motion(reduced_motion)
    if world_micro_fx != null:
        world_micro_fx.set_reduced_motion(reduced_motion)
    composite_material.set_shader_parameter("reduced_motion", value)
func set_quiet_visuals(value: bool) -> void:
    quiet_visuals = value
    video_layer.set_quiet_visuals(value)
    composite_material.set_shader_parameter("quiet_visuals", value)
func set_interaction_enabled(value: bool) -> void:
    interaction_enabled = value
    if not value and drawing:
        _end_stroke()
    if not value and interaction_router != null:
        interaction_router.reset()
func set_cinematic_reveal(value: bool, instant: bool = false) -> void:
    var was_revealed: bool = cinematic_revealed
    cinematic_revealed = value
    if behavior != null and behavior.has_method("set_cinematic"):
        behavior.set_cinematic(value)
    video_layer.set_cinematic(value, instant)
    _cinematic_target = 1.0 if value else 0.0
    if value:
        if not was_revealed:
            _cinematic_elapsed = 0.0
        composite_material.set_shader_parameter("completion_origin", pointer_norm)
        if instant:
            _cinematic_mix = 1.0
            composite_material.set_shader_parameter("completion_reveal", 1.0)
        composite_material.set_shader_parameter("noise_intensity", 0.0)
        atmosphere.set_progress(1.0)
        _update_act(1.0)
    elif instant:
        _cinematic_mix = 0.0
        composite_material.set_shader_parameter("completion_reveal", 0.0)
    if instant:
        composite_material.set_shader_parameter("unlock_motion", _cinematic_mix * (0.10 if reduced_motion else 1.0))
        if room_dressing != null: room_dressing.set_cinematic(_cinematic_mix)
    queue_redraw()
func set_runtime_budget(scale: float) -> void:
    _runtime_scale = clampf(scale, 0.55, 1.0)
    video_layer.set_runtime_scale(_runtime_scale)
    composite_material.set_shader_parameter("runtime_scale", _runtime_scale)
    _texture_upload_hz = maxf(12.0, _base_texture_upload_hz * _runtime_scale)
    atmosphere.set_runtime_scale(_runtime_scale)
    if hint_layer != null:
        hint_layer.set_runtime_scale(_runtime_scale)
    if room_dressing != null:
        room_dressing.set_runtime_scale(_runtime_scale)
func set_assist_level(level: int) -> void:
    if behavior != null and behavior.has_method("set_assist_level"):
        behavior.set_assist_level(level)

func set_hint_strength(value: float) -> void:
    if hint_layer != null:
        _refresh_hint_targets()
        hint_layer.set_hint_strength(value)

func _refresh_hint_targets() -> void:
    if hint_layer == null:
        return
    var targets: Array = []
    if behavior != null and behavior.has_method("hint_targets"):
        targets = behavior.hint_targets()
    hint_layer.set_targets(targets)
func get_interaction_hint() -> String:
    if behavior != null and behavior.has_method("interaction_hint"):
        return str(behavior.interaction_hint())
    return "DOTKNIJ ŚWIATA"
func set_door_open(value: bool) -> void: door_target_open = value
func get_door_open_amount() -> float: return door_open_amount
func reset_room() -> void:
    _state_flow.reset_room()
func get_found_count() -> int:
    return _state_flow.get_found_count()
func get_coverage() -> float:
    return _state_flow.get_coverage()
func get_normalized_progress() -> float:
    return _state_flow.get_normalized_progress()
func get_current_act() -> int:
    return _state_flow.get_current_act()
func export_state() -> Dictionary:
    return _state_flow.export_state()
func restore_state(saved: Dictionary) -> bool:
    return _state_flow.restore_state(saved)
func reveal_remaining_collectibles() -> Array[Dictionary]:
    return _state_flow.reveal_remaining_collectibles()
func _gui_input(event: InputEvent) -> void:
    _interaction_flow._gui_input(event)
func _handle_gestures(gestures: Array) -> void:
    _interaction_flow._handle_gestures(gestures)
func _on_runtime_special(kind: String, index: int) -> void:
    _interaction_flow._on_runtime_special(kind, index)
func _on_attempt_confirmed(point: Vector2, strength: float) -> void:
    _interaction_flow._on_attempt_confirmed(point, strength)
func _on_gesture_reveal_changed(point: Vector2, radius: float) -> void:
    _interaction_flow._on_gesture_reveal_changed(point, radius)
func _begin_stroke(point_norm: Vector2, pointer_id: int = -1) -> void:
    _interaction_flow._begin_stroke(point_norm, pointer_id)
func _continue_stroke(point_norm: Vector2) -> void:
    _interaction_flow._continue_stroke(point_norm)
func _end_stroke() -> void:
    _interaction_flow._end_stroke()
func _apply_stamps(stamps: Array[Dictionary]) -> void:
    _interaction_flow._apply_stamps(stamps)
func _set_progress_from_mask() -> void:
    _interaction_flow._set_progress_from_mask()
func _update_act(progress_value: float) -> void:
    _interaction_flow._update_act(progress_value)
func _check_collectibles(point_norm: Vector2, radius_norm: float) -> void:
    _interaction_flow._check_collectibles(point_norm, radius_norm)
func _check_behavior(point_norm: Vector2, radius_norm: float) -> void:
    _interaction_flow._check_behavior(point_norm, radius_norm)
func _draw() -> void:
    if behavior != null:
        behavior.render(self, size, current_progress, _phase)
    _render_collectibles()
    _render_cursor()
    _render_doors()
func _render_collectibles() -> void:
    for item in collectibles:
        if bool(item.get("found", false)):
            continue
        var position_value: Variant = item.get("position", [])
        if not position_value is Array or position_value.size() != 2:
            continue
        var point_norm := Vector2(float(position_value[0]), float(position_value[1]))
        var center := Vector2(point_norm.x * size.x, point_norm.y * size.y)
        var proximity := 1.0 - clampf(pointer_norm.distance_to(point_norm) / 0.22, 0.0, 1.0)
        var completion_boost := 1.0 if cinematic_revealed else 0.0
        var discovery_visibility := clampf(0.05 + proximity * 0.62 + current_progress * 0.10 + completion_boost * 0.42, 0.0, 1.0)
        if discovery_visibility < 0.08:
            continue
        var pulse: float = 0.5 if reduced_motion else 0.5 + 0.5 * sin(_phase * 3.4 + float(center.x) * 0.013)
        var alpha := discovery_visibility * (0.08 + pulse * 0.10)
        var radius := 10.0 + pulse * 3.0
        # Echoes read as signal anomalies, not collectible coins: broken ring,
        # short waveform and tiny center phase marker.
        draw_arc(center, radius, -PI * 0.82, -PI * 0.08, 10, Color(_accent_color, alpha), 1.2)
        draw_arc(center, radius, PI * 0.18, PI * 0.92, 10, Color(_accent_color, alpha), 1.2)
        var wave_alpha := alpha * (0.75 + completion_boost * 0.25)
        for wave_index in range(4):
            var x0 := center.x - 7.0 + float(wave_index) * 4.0
            var y0 := center.y + sin(float(wave_index) * 2.2 + _phase * 3.0) * 2.6
            var x1 := x0 + 3.0
            var y1 := center.y + sin(float(wave_index + 1) * 2.2 + _phase * 3.0) * 2.6
            draw_line(Vector2(x0, y0), Vector2(x1, y1), Color(Color.WHITE, wave_alpha * 0.72), 1.0)
        draw_circle(center, 1.5, Color(_accent_color, alpha * 0.92))

func _render_cursor() -> void:
    if not interaction_enabled:
        return
    var brush_value: Variant = manifest_room.get("brush", {})
    var brush: Dictionary = brush_value if brush_value is Dictionary else {}
    var width_px: float = float(brush.get("min_width", 22.0)) * 0.55
    var center: Vector2 = Vector2(pointer_norm.x * size.x, pointer_norm.y * size.y)
    if drawing:
        draw_circle(center, width_px * 1.55, Color(_accent_color, 0.035))
    var polygon: PackedVector2Array = PackedVector2Array()
    for index in range(12):
        var angle: float = float(index) * TAU / 12.0
        var jitter: float = 0.82 + 0.18 * sin(float(index * 7) + _phase * 2.0)
        polygon.append(center + Vector2.from_angle(angle) * width_px * jitter)
    polygon.append(polygon[0])
    draw_polyline(polygon, Color(_accent_color, 0.22), 1.2, true)
func _render_doors() -> void:
    if door_open_amount <= 0.001:
        return
    var pulse: float = 0.5 if reduced_motion else (0.5 + 0.5 * sin(_phase * 2.2))
    var center_x: float = size.x * 0.5
    var threshold_half: float = size.x * 0.18 * door_open_amount
    var bottom_y: float = size.y - 36.0
    var top_y: float = size.y * 0.66
    var alpha: float = 0.10 + door_open_amount * (0.15 + pulse * 0.05)
    draw_line(Vector2(center_x - threshold_half, bottom_y), Vector2(center_x + threshold_half, bottom_y), Color(_accent_color, alpha), 1.4)
    draw_line(Vector2(center_x - threshold_half, bottom_y), Vector2(center_x - threshold_half * 0.72, top_y), Color(_accent_color, alpha * 0.78), 1.2)
    draw_line(Vector2(center_x + threshold_half, bottom_y), Vector2(center_x + threshold_half * 0.72, top_y), Color(_accent_color, alpha * 0.78), 1.2)
    draw_line(Vector2(center_x - threshold_half * 0.72, top_y), Vector2(center_x + threshold_half * 0.72, top_y), Color(_accent_color, alpha * 0.60), 1.1)
    draw_circle(Vector2(center_x, lerpf(bottom_y, top_y, 0.46)), size.x * 0.075 * door_open_amount, Color(_accent_color, alpha * 0.07))
func _unlock_profile_index(style: String) -> int:
    match style:
        "uncertainty": return 0
        "party": return 1
        "unmasked": return 2
        "calling": return 3
        "seed": return 4
        "hybrid": return 5
        "technophobia": return 6
        "invaluable": return 7
        "ashes": return 8
        "waves": return 9
        "rise": return 10
        _: return 0
