extends Node

var app: Control

func bind(owner: Control) -> void:
    app = owner

func _gui_input(event: InputEvent) -> void:
    if not app.interaction_enabled or app.interaction_router == null:
        return
    var touch_origin: Vector2 = app.get_global_rect().position
    var routed: Dictionary = app.interaction_router.route_input(event, app.size, Time.get_ticks_msec(), app.drawing, app._drawing_pointer_id, touch_origin)
    if not bool(routed.get("handled", false)):
        return
    var point_value: Variant = routed.get("point", app.pointer_norm)
    app.pointer_norm = point_value if point_value is Vector2 else app.pointer_norm
    app.target_parallax = (app.pointer_norm - Vector2(0.5, 0.5)) * 2.0
    if app.post_reveal_interaction:
        _handle_post_reveal_gestures(routed["gestures"])
        app.accept_event()
        app.queue_redraw()
        return
    _handle_gestures(routed["gestures"])
    match str(routed.get("stroke", "")):
        "begin":
            var prop_capture: bool = app.behavior != null and app.behavior.has_method("captures_pointer_at") and app.behavior.captures_pointer_at(app.pointer_norm)
            if not prop_capture:
                _begin_stroke(app.pointer_norm, int(routed.get("pointer_id", -1)))
        "continue": _continue_stroke(app.pointer_norm)
        "end": _end_stroke()
    app.accept_event()
    app.queue_redraw()

func _handle_post_reveal_gestures(gestures: Array) -> void:
    if gestures.is_empty():
        return
    var style: String = str(app.manifest_room.get("visual_style", "uncertainty"))
    for value in gestures:
        if not value is Dictionary:
            continue
        var gesture: Dictionary = value as Dictionary
        var kind: String = str(gesture.get("kind", ""))
        if kind not in ["tap", "press", "drag", "hold", "two_finger"]:
            continue
        var point_value: Variant = gesture.get("point", app.pointer_norm)
        var point: Vector2 = point_value if point_value is Vector2 else app.pointer_norm
        var velocity: float = clampf(float(gesture.get("velocity", 0.0)) * 0.72, 0.0, 1.0)
        var distance: float = clampf(float(gesture.get("distance", 0.0)) * 3.8, 0.0, 1.0)
        var strength: float = maxf(0.40 if kind in ["tap", "press"] else 0.24, maxf(velocity, distance))
        if kind == "hold":
            strength = maxf(strength, 0.68)
        app._interaction_energy = maxf(app._interaction_energy, strength)
        app._brush_energy = maxf(app._brush_energy, strength * 0.48)
        app.composite_material.set_shader_parameter("brush_point", point)
        if app.interaction_fx != null and kind in ["tap", "press", "hold"]:
            app.interaction_fx.spawn(point, "confirm")
        _check_collectibles(point, 0.045 + strength * 0.035)
        app.interaction_motion.emit(_motion_kind(style, kind), strength)

func _handle_gestures(gestures: Array) -> void:
    if app.interaction_runtime == null or gestures.is_empty():
        return
    var generation_before: int = app.attempt_feedback.generation()
    _emit_continuous_motion(gestures)
    app.interaction_runtime.handle_gestures(gestures, app.current_progress)
    _set_progress_from_mask()
    app.coverage_changed.emit(app.get_coverage())
    app.attempt_feedback.note_gesture_batch(gestures, generation_before, app.pointer_norm)

func _emit_continuous_motion(gestures: Array) -> void:
    var style := str(app.manifest_room.get("visual_style", "uncertainty"))
    for value in gestures:
        if not value is Dictionary:
            continue
        var gesture: Dictionary = value
        var kind := str(gesture.get("kind", ""))
        if kind not in ["press", "drag", "hold", "two_finger"]:
            continue
        var point_value: Variant = gesture.get("point", app.pointer_norm)
        var point: Vector2 = point_value if point_value is Vector2 else app.pointer_norm
        var captured: bool = app.behavior != null and app.behavior.has_method("captures_pointer_at") and app.behavior.captures_pointer_at(point)
        if not captured and kind != "two_finger":
            continue
        var velocity := clampf(float(gesture.get("velocity", 0.0)) * 0.65, 0.0, 1.0)
        var distance := clampf(float(gesture.get("distance", 0.0)) * 3.4, 0.0, 1.0)
        var strength := maxf(0.18 if kind == "press" else 0.0, maxf(velocity, distance))
        if kind == "hold":
            strength = maxf(strength, 0.58)
        app._interaction_energy = maxf(app._interaction_energy, strength)
        app.interaction_motion.emit(_motion_kind(style, kind), strength)

func _motion_kind(style: String, gesture_kind: String) -> String:
    match style:
        "technophobia": return "tension" if gesture_kind == "drag" else "electrical"
        "unmasked": return "peel"
        "invaluable": return "glass_pressure"
        "seed": return "heartbeat"
        "party": return "membrane"
        "calling": return "resonance"
        "ashes": return "ember_flow"
        "waves": return "breath"
        "hybrid": return "frequency"
        "rise": return "lift"
        _: return "wave_pressure"

func _on_runtime_special(kind: String, index: int) -> void:
    app.attempt_feedback.success(app.pointer_norm, 0.78)
    app.special_interaction.emit(kind, index)

func _on_attempt_confirmed(point: Vector2, strength: float) -> void:
    if app.interaction_fx != null:
        app.interaction_fx.spawn(point, "confirm")
    app.interaction_confirmed.emit(point, strength)

func _on_gesture_reveal_changed(point: Vector2, radius: float) -> void:
    app.attempt_feedback.success(point, 0.68)
    _check_collectibles(point, radius)
    app._brush_energy = maxf(app._brush_energy, 0.72)
    app.composite_material.set_shader_parameter("brush_point", point)
    _set_progress_from_mask()
    app._last_coverage_emitted = app.get_coverage()
    app.coverage_changed.emit(app._last_coverage_emitted)

func _begin_stroke(point_norm: Vector2, pointer_id: int = -1) -> void:
    if app.drawing:
        return
    app.drawing = true
    app._drawing_pointer_id = pointer_id
    app.attempt_feedback.begin_stroke(app.current_progress)
    app.interaction_started.emit()
    var stamps: Array[Dictionary] = app.brush_engine.begin(point_norm, Time.get_ticks_msec(), minf(app.size.x, app.size.y))
    _apply_stamps(stamps)

func _continue_stroke(point_norm: Vector2) -> void:
    if not app.drawing:
        return
    var stamps: Array[Dictionary] = app.brush_engine.sample(point_norm, Time.get_ticks_msec(), minf(app.size.x, app.size.y))
    _apply_stamps(stamps)

func _end_stroke() -> void:
    if not app.drawing:
        return
    app.drawing = false
    app._drawing_pointer_id = -999
    app.brush_engine.end()
    app.reveal_mask.upload_if_dirty()
    app.attempt_feedback.end_stroke(app.current_progress, app.pointer_norm)
    app.interaction_ended.emit()
    app.queue_redraw()

func _apply_stamps(stamps: Array[Dictionary]) -> void:
    if stamps.is_empty():
        return
    var changed: bool = false
    var last_speed: float = 0.0
    for stamp in stamps:
        if app.reveal_mask.apply_stamp(stamp, true):
            changed = true
        last_speed = float(stamp.get("speed", 0.0))
        var position_value: Variant = stamp.get("position", Vector2.ZERO)
        var position: Vector2 = position_value if position_value is Vector2 else Vector2.ZERO
        _check_collectibles(position, float(stamp.get("radius", 0.04)))
        _check_behavior(position, float(stamp.get("radius", 0.04)))
    if not changed:
        return
    app._brush_energy = maxf(app._brush_energy, 0.34 + last_speed * 0.66)
    app.composite_material.set_shader_parameter("brush_point", app.pointer_norm)
    _set_progress_from_mask()
    var coverage_value: float = app.get_coverage()
    app.attempt_feedback.success(app.pointer_norm, 0.34, app.current_progress)
    if app._last_coverage_emitted < 0.0 or absf(coverage_value - app._last_coverage_emitted) >= 0.0008 or app.current_progress >= 0.99:
        app._last_coverage_emitted = coverage_value
        app.coverage_changed.emit(coverage_value)
    var now_ms: int = Time.get_ticks_msec()
    if now_ms - app._last_pulse_ms >= 48:
        app._last_pulse_ms = now_ms
        app.paint_pulse.emit(last_speed)

func _set_progress_from_mask() -> void:
    app.current_progress = app.get_normalized_progress()
    app.composite_material.set_shader_parameter("progress", app.current_progress)
    app.composite_material.set_shader_parameter("subject_lift", pow(app.current_progress, 0.72))
    var base_noise: float = float(app.sensory.get("visual_snow_calm", 0.032)) if app.calm_mode else float(app.sensory.get("visual_snow_full", 0.064))
    # Keep the discovery veil atmospheric on small OLED screens without hiding
    # the authored targets. Progress clears it quickly as the artwork appears.
    app.composite_material.set_shader_parameter("noise_intensity", base_noise * (1.0 - app.current_progress) * 1.8)
    app.atmosphere.set_progress(app.current_progress)
    if app.room_dressing != null:
        app.room_dressing.set_progress(app.current_progress)
    _update_act(app.current_progress)

func _update_act(progress_value: float) -> void:
    var next_act: int = 0
    if progress_value >= 0.70:
        next_act = 2
    elif progress_value >= 0.30:
        next_act = 1
    if next_act == app.current_act:
        return
    app.current_act = next_act
    if app.current_act > 0:
        app.interaction_fx.spawn(Vector2(0.5, 0.46), "act")
    var titles: Array[String] = app.behavior.acts() if app.behavior != null else ["ROZPOZNANIE", "PRZEŁAMANIE", "TRANSFORMACJA"]
    var title: String = titles[app.current_act] if app.current_act < titles.size() else "TRANSFORMACJA"
    app.act_changed.emit(app.current_act, title)

func _check_collectibles(point_norm: Vector2, radius_norm: float) -> void:
    for item in app.collectibles:
        if bool(item.get("found", false)):
            continue
        var position_value: Variant = item.get("position", [])
        if not position_value is Array or position_value.size() != 2:
            continue
        var target: Vector2 = Vector2(float(position_value[0]), float(position_value[1]))
        var hit_radius: float = radius_norm + 0.065
        if point_norm.distance_squared_to(target) <= hit_radius * hit_radius:
            item["found"] = true
            app.interaction_fx.spawn(target, "discovery")
            app.attempt_feedback.success(target, 0.92)
            app.collectible_found.emit(item.duplicate(true))

func _check_behavior(point_norm: Vector2, radius_norm: float) -> void:
    if app.interaction_runtime != null:
        app.interaction_runtime.handle_paint(point_norm, radius_norm, app.current_progress)
