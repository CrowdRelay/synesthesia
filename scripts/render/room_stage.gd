extends Control

signal coverage_changed(value: float)
signal collectible_found(item: Dictionary)
signal paint_pulse(speed_normalized: float)
signal special_interaction(kind: String, index: int)
signal interaction_started
signal interaction_ended
signal act_changed(index: int, title: String)

const BrushEngineScript := preload("res://scripts/brush/brush_engine.gd")
const RevealMaskScript := preload("res://scripts/render/reveal_mask.gd")
const AtmosphereLayerScript := preload("res://scripts/render/atmosphere_layer.gd")
const CompositeShader := preload("res://shaders/room_composite.gdshader")

@export var room_id: String = ""

var manifest_room: Dictionary = {}
var sensory: Dictionary = {}
var quality: Dictionary = {}
var collectibles: Array[Dictionary] = []
var behavior
var brush_engine
var reveal_mask
var composite: TextureRect
var composite_material: ShaderMaterial
var atmosphere
var interaction_enabled: bool = true
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
var _phase: float = 0.0
var _redraw_accumulator: float = 0.0
var _upload_accumulator: float = 0.0
var _texture_upload_hz: float = 30.0
var _last_pulse_ms: int = 0
var _last_special_ms: Dictionary = {}

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    focus_mode = Control.FOCUS_NONE
    clip_contents = true
    _build_composite()
    set_process(true)

func _build_composite() -> void:
    composite = TextureRect.new()
    composite.name = "RoomComposite"
    composite.mouse_filter = Control.MOUSE_FILTER_IGNORE
    composite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    composite.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(composite)
    composite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    composite_material = ShaderMaterial.new()
    composite_material.shader = CompositeShader
    composite.material = composite_material

    atmosphere = AtmosphereLayerScript.new()
    atmosphere.name = "Atmosphere"
    atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(atmosphere)
    atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(room_data: Dictionary, collectible_data: Array, sensory_data: Dictionary = {}, quality_data: Dictionary = {}) -> void:
    manifest_room = room_data.duplicate(true)
    sensory = sensory_data.duplicate(true)
    quality = quality_data.duplicate(true)
    room_id = str(room_data.get("id", room_id))
    completion_threshold = clampf(float(room_data.get("completion_coverage", 0.44)), 0.20, 0.75)
    _texture_upload_hz = clampf(float(quality.get("texture_upload_hz", 30.0)), 12.0, 60.0)

    brush_engine = BrushEngineScript.new()
    var brush_value: Variant = room_data.get("brush", {})
    var brush: Dictionary = brush_value if brush_value is Dictionary else {}
    brush_engine.configure(brush)

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

    _configure_behavior(room_data)
    _configure_art(room_data)
    atmosphere.configure(
        str(room_data.get("visual_style", "uncertainty")),
        Color.from_string(str(room_data.get("accent_color", "#72AFFF")), Color("72afff")),
        Color.from_string(str(room_data.get("secondary_color", "#FF6680")), Color("ff6680")),
        quality,
    )
    _set_progress_from_mask()
    queue_redraw()

func _configure_behavior(room_data: Dictionary) -> void:
    behavior = null
    var behavior_path: String = str(room_data.get("behavior_script", ""))
    if behavior_path.is_empty() or not ResourceLoader.exists(behavior_path):
        push_warning("Missing room behavior: %s" % behavior_path)
        return
    var resource: Resource = load(behavior_path)
    if resource is Script:
        behavior = (resource as Script).new()
        behavior.configure(room_data)

func _configure_art(room_data: Dictionary) -> void:
    var art_value: Variant = room_data.get("art_direction", {})
    var art: Dictionary = art_value if art_value is Dictionary else {}
    var scene_path: String = str(art.get("scene_image", ""))
    var background_path: String = str(art.get("background_image", ""))
    var subject_path: String = str(art.get("subject_image", ""))
    var foreground_path: String = str(art.get("foreground_image", ""))
    var scene_texture: Texture2D
    var background_texture: Texture2D
    var subject_texture: Texture2D
    var foreground_texture: Texture2D
    if ResourceLoader.exists(scene_path):
        var scene_resource: Resource = load(scene_path)
        if scene_resource is Texture2D:
            scene_texture = scene_resource as Texture2D
    if ResourceLoader.exists(background_path):
        var background_resource: Resource = load(background_path)
        if background_resource is Texture2D:
            background_texture = background_resource as Texture2D
    if ResourceLoader.exists(subject_path):
        var subject_resource: Resource = load(subject_path)
        if subject_resource is Texture2D:
            subject_texture = subject_resource as Texture2D
    if ResourceLoader.exists(foreground_path):
        var foreground_resource: Resource = load(foreground_path)
        if foreground_resource is Texture2D:
            foreground_texture = foreground_resource as Texture2D
    composite.texture = scene_texture
    composite_material.set_shader_parameter("background_texture", background_texture)
    composite_material.set_shader_parameter("subject_texture", subject_texture)
    composite_material.set_shader_parameter("foreground_texture", foreground_texture)
    composite_material.set_shader_parameter("reveal_mask", reveal_mask.texture())
    composite_material.set_shader_parameter("accent_color", Color.from_string(str(room_data.get("accent_color", "#72AFFF")), Color("72afff")))
    composite_material.set_shader_parameter("noise_tint", Color.from_string(str(sensory.get("visual_snow_tint", "#E5C9E8")), Color("e5c9e8")))
    composite_material.set_shader_parameter("scene_parallax", float(art.get("scene_parallax", 0.018)))
    composite_material.set_shader_parameter("background_parallax", float(art.get("background_parallax", 0.008)))
    composite_material.set_shader_parameter("subject_parallax", float(art.get("subject_parallax", 0.026)))
    composite_material.set_shader_parameter("foreground_parallax", float(art.get("foreground_parallax", 0.042)))
    composite_material.set_shader_parameter("halftone_strength", float(art.get("halftone_strength", 0.22)))
    composite_material.set_shader_parameter("ink_strength", float(art.get("ink_strength", 0.72)))
    composite_material.set_shader_parameter("scanline_strength", float(sensory.get("scanline_strength", 0.35)))
    composite_material.set_shader_parameter("roll_strength", float(sensory.get("roll_strength", 0.22)))
    composite_material.set_shader_parameter("horizontal_jitter", float(sensory.get("horizontal_jitter", 0.12)))
    composite_material.set_shader_parameter("motion", float(sensory.get("static_motion_calm", 0.18)))
    composite_material.set_shader_parameter("quality_level", int(quality.get("shader_quality", 1)))

func _process(delta: float) -> void:
    var target: float = 1.0 if door_target_open else 0.0
    door_open_amount = move_toward(door_open_amount, target, delta * 0.82)
    var motion_factor: float = 0.18 if reduced_motion else (0.58 if calm_mode else 0.90)
    smoothed_parallax = smoothed_parallax.lerp(target_parallax, clampf(delta * 4.5 * motion_factor, 0.0, 1.0))
    composite_material.set_shader_parameter("parallax", smoothed_parallax)

    _upload_accumulator += delta
    if _upload_accumulator >= 1.0 / _texture_upload_hz:
        _upload_accumulator = 0.0
        reveal_mask.upload_if_dirty()

    _phase = fmod(_phase + delta * (0.32 if calm_mode else 0.72), 1000.0)
    _redraw_accumulator += delta
    var redraw_hz: float = 10.0 if reduced_motion else (24.0 if calm_mode else 30.0)
    if drawing or not is_equal_approx(door_open_amount, target):
        redraw_hz = 45.0
    if _redraw_accumulator >= 1.0 / redraw_hz:
        _redraw_accumulator = 0.0
        queue_redraw()

func set_calm_mode(value: bool) -> void:
    calm_mode = value
    atmosphere.set_sensory(calm_mode, reduced_motion)
    composite_material.set_shader_parameter(
        "motion",
        float(sensory.get("static_motion_calm", 0.18)) if calm_mode else float(sensory.get("static_motion_full", 0.46)),
    )

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value
    atmosphere.set_sensory(calm_mode, reduced_motion)
    composite_material.set_shader_parameter("reduced_motion", value)

func set_quiet_visuals(value: bool) -> void:
    quiet_visuals = value
    composite_material.set_shader_parameter("quiet_visuals", value)

func set_interaction_enabled(value: bool) -> void:
    interaction_enabled = value
    if not value and drawing:
        _end_stroke()

func set_cinematic_reveal(value: bool) -> void:
    cinematic_revealed = value
    if value:
        current_progress = 1.0
        composite_material.set_shader_parameter("progress", 1.0)
        composite_material.set_shader_parameter("noise_intensity", 0.0)
        atmosphere.set_progress(1.0)
        _update_act(1.0)
    queue_redraw()

func set_door_open(value: bool) -> void:
    door_target_open = value

func get_door_open_amount() -> float:
    return door_open_amount

func reset_room() -> void:
    reveal_mask.clear()
    if behavior != null:
        behavior.configure(manifest_room)
    for item in collectibles:
        item["found"] = false
    cinematic_revealed = false
    door_target_open = false
    door_open_amount = 0.0
    current_progress = 0.0
    current_act = -1
    _set_progress_from_mask()
    coverage_changed.emit(0.0)
    queue_redraw()

func get_found_count() -> int:
    var count: int = 0
    for item in collectibles:
        if bool(item.get("found", false)):
            count += 1
    return count

func get_coverage() -> float:
    return reveal_mask.coverage() if reveal_mask != null else 0.0

func get_normalized_progress() -> float:
    return clampf(get_coverage() / completion_threshold, 0.0, 1.0)

func get_current_act() -> int:
    return current_act

func export_state() -> Dictionary:
    var found_ids: Array[String] = []
    for item in collectibles:
        if bool(item.get("found", false)):
            found_ids.append(str(item.get("id", "")))
    return {
        "renderer": "mask-v1",
        "mask": reveal_mask.export_state(),
        "behavior": behavior.export_state() if behavior != null else {},
        "found_collectibles": found_ids,
        "cinematic_revealed": cinematic_revealed,
        "door_open": door_target_open,
    }

func restore_state(saved: Dictionary) -> bool:
    if reveal_mask == null:
        return false
    var mask_value: Variant = saved.get("mask", saved)
    var mask_state: Dictionary = mask_value if mask_value is Dictionary else {}
    var brush_value: Variant = manifest_room.get("brush", {})
    var brush: Dictionary = brush_value if brush_value is Dictionary else {}
    var restored: bool = reveal_mask.restore_state(mask_state, str(brush.get("profile", "soft")))
    var found_lookup: Dictionary = {}
    var found_value: Variant = saved.get("found_collectibles", [])
    if found_value is Array:
        for raw_id in found_value:
            found_lookup[str(raw_id)] = true
    for item in collectibles:
        item["found"] = bool(found_lookup.get(str(item.get("id", "")), false))
    var behavior_value: Variant = saved.get("behavior", saved.get("special_state", {}))
    if behavior != null and behavior_value is Dictionary:
        behavior.restore_state(behavior_value)
    cinematic_revealed = bool(saved.get("cinematic_revealed", false))
    door_target_open = bool(saved.get("door_open", false))
    door_open_amount = 1.0 if door_target_open else 0.0
    _set_progress_from_mask()
    if cinematic_revealed:
        set_cinematic_reveal(true)
    queue_redraw()
    return restored

func reveal_remaining_collectibles() -> Array[Dictionary]:
    var revealed: Array[Dictionary] = []
    for item in collectibles:
        if bool(item.get("found", false)):
            continue
        item["found"] = true
        var copy: Dictionary = item.duplicate(true)
        revealed.append(copy)
        collectible_found.emit(copy)
    return revealed

func _gui_input(event: InputEvent) -> void:
    if not interaction_enabled or size.x <= 1.0 or size.y <= 1.0:
        return
    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event as InputEventScreenTouch
        pointer_norm = _normalized_point(touch.position)
        if touch.pressed:
            _begin_stroke(pointer_norm)
        else:
            _end_stroke()
        accept_event()
    elif event is InputEventScreenDrag:
        var drag: InputEventScreenDrag = event as InputEventScreenDrag
        pointer_norm = _normalized_point(drag.position)
        _continue_stroke(pointer_norm)
        accept_event()
    elif event is InputEventMouseButton:
        var button: InputEventMouseButton = event as InputEventMouseButton
        if button.button_index != MOUSE_BUTTON_LEFT:
            return
        pointer_norm = _normalized_point(button.position)
        if button.pressed:
            _begin_stroke(pointer_norm)
        else:
            _end_stroke()
        accept_event()
    elif event is InputEventMouseMotion:
        var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
        pointer_norm = _normalized_point(motion_event.position)
        target_parallax = (pointer_norm - Vector2(0.5, 0.5)) * 2.0
        if drawing:
            _continue_stroke(pointer_norm)
        queue_redraw()

func _begin_stroke(point_norm: Vector2) -> void:
    if drawing:
        return
    drawing = true
    interaction_started.emit()
    var stamps: Array[Dictionary] = brush_engine.begin(point_norm, Time.get_ticks_msec(), minf(size.x, size.y))
    _apply_stamps(stamps)

func _continue_stroke(point_norm: Vector2) -> void:
    if not drawing:
        return
    var stamps: Array[Dictionary] = brush_engine.sample(point_norm, Time.get_ticks_msec(), minf(size.x, size.y))
    _apply_stamps(stamps)

func _end_stroke() -> void:
    if not drawing:
        return
    drawing = false
    brush_engine.end()
    reveal_mask.upload_if_dirty()
    interaction_ended.emit()
    queue_redraw()

func _apply_stamps(stamps: Array[Dictionary]) -> void:
    if stamps.is_empty():
        return
    var changed: bool = false
    var last_speed: float = 0.0
    for stamp in stamps:
        if reveal_mask.apply_stamp(stamp, true):
            changed = true
        last_speed = float(stamp.get("speed", 0.0))
        var position_value: Variant = stamp.get("position", Vector2.ZERO)
        var position: Vector2 = position_value if position_value is Vector2 else Vector2.ZERO
        _check_collectibles(position, float(stamp.get("radius", 0.04)))
        _check_behavior(position, float(stamp.get("radius", 0.04)))
    if not changed:
        return
    _set_progress_from_mask()
    coverage_changed.emit(get_coverage())
    var now_ms: int = Time.get_ticks_msec()
    if now_ms - _last_pulse_ms >= 48:
        _last_pulse_ms = now_ms
        paint_pulse.emit(last_speed)

func _set_progress_from_mask() -> void:
    current_progress = get_normalized_progress()
    composite_material.set_shader_parameter("progress", current_progress)
    var base_noise: float = float(sensory.get("visual_snow_calm", 0.032)) if calm_mode else float(sensory.get("visual_snow_full", 0.064))
    composite_material.set_shader_parameter("noise_intensity", base_noise * (1.0 - current_progress) * 3.0)
    atmosphere.set_progress(current_progress)
    _update_act(current_progress)

func _update_act(progress_value: float) -> void:
    var next_act: int = 0
    if progress_value >= 0.70:
        next_act = 2
    elif progress_value >= 0.30:
        next_act = 1
    if next_act == current_act:
        return
    current_act = next_act
    var titles: Array[String] = behavior.acts() if behavior != null else ["ROZPOZNANIE", "PRZEŁAMANIE", "TRANSFORMACJA"]
    var title: String = titles[current_act] if current_act < titles.size() else "TRANSFORMACJA"
    act_changed.emit(current_act, title)

func _check_collectibles(point_norm: Vector2, radius_norm: float) -> void:
    for item in collectibles:
        if bool(item.get("found", false)):
            continue
        var position_value: Variant = item.get("position", [])
        if not position_value is Array or position_value.size() != 2:
            continue
        var target: Vector2 = Vector2(float(position_value[0]), float(position_value[1]))
        if point_norm.distance_to(target) <= radius_norm + 0.065:
            item["found"] = true
            collectible_found.emit(item.duplicate(true))

func _check_behavior(point_norm: Vector2, radius_norm: float) -> void:
    if behavior == null:
        return
    var events: Array[Dictionary] = behavior.on_paint(point_norm, radius_norm, current_progress)
    for event in events:
        var kind: String = str(event.get("kind", "interaction"))
        var index: int = int(event.get("index", 0))
        var now_ms: int = Time.get_ticks_msec()
        var key: String = "%s:%d" % [kind, index]
        if now_ms - int(_last_special_ms.get(key, 0)) < 180:
            continue
        _last_special_ms[key] = now_ms
        special_interaction.emit(kind, index)

func _normalized_point(local_point: Vector2) -> Vector2:
    return Vector2(
        clampf(local_point.x / maxf(size.x, 1.0), 0.0, 1.0),
        clampf(local_point.y / maxf(size.y, 1.0), 0.0, 1.0),
    )

func _draw() -> void:
    if behavior != null:
        behavior.render(self, size, current_progress, _phase)
    _render_collectibles()
    _render_cursor()
    _render_doors()

func _render_collectibles() -> void:
    var accent: Color = Color.from_string(str(manifest_room.get("accent_color", "#72AFFF")), Color("72afff"))
    for item in collectibles:
        if bool(item.get("found", false)):
            continue
        var position_value: Variant = item.get("position", [])
        if not position_value is Array or position_value.size() != 2:
            continue
        var center: Vector2 = Vector2(float(position_value[0]) * size.x, float(position_value[1]) * size.y)
        var pulse: float = 0.5 + 0.5 * sin(_phase * 4.0 + float(center.x))
        draw_arc(center, 11.0 + pulse * 3.0, 0.0, TAU, 22, accent.with_alpha(0.10 + pulse * 0.08), 1.4)

func _render_cursor() -> void:
    if not interaction_enabled:
        return
    var brush_value: Variant = manifest_room.get("brush", {})
    var brush: Dictionary = brush_value if brush_value is Dictionary else {}
    var width_px: float = float(brush.get("min_width", 22.0)) * 0.55
    var center: Vector2 = Vector2(pointer_norm.x * size.x, pointer_norm.y * size.y)
    var accent: Color = Color.from_string(str(manifest_room.get("accent_color", "#72AFFF")), Color("72afff"))
    var polygon: PackedVector2Array = PackedVector2Array()
    for index in range(12):
        var angle: float = float(index) * TAU / 12.0
        var jitter: float = 0.82 + 0.18 * sin(float(index * 7) + _phase * 2.0)
        polygon.append(center + Vector2.from_angle(angle) * width_px * jitter)
    polygon.append(polygon[0])
    draw_polyline(polygon, accent.with_alpha(0.22), 1.2, true)

func _render_doors() -> void:
    if door_open_amount <= 0.001:
        return
    var remaining: float = 1.0 - door_open_amount
    var panel_width: float = size.x * 0.5 * remaining
    var door_color: Color = Color("05070be8")
    draw_rect(Rect2(0.0, 0.0, panel_width, size.y), door_color, true)
    draw_rect(Rect2(size.x - panel_width, 0.0, panel_width, size.y), door_color, true)
    if panel_width > 2.0:
        draw_line(Vector2(panel_width, 0.0), Vector2(panel_width, size.y), Color.WHITE.with_alpha(0.08), 1.0)
        draw_line(Vector2(size.x - panel_width, 0.0), Vector2(size.x - panel_width, size.y), Color.WHITE.with_alpha(0.08), 1.0)
