extends Node

const AtmosphereLayerScript := preload("res://scripts/render/atmosphere_layer.gd")
const InteractionFxLayerScript := preload("res://scripts/render/interaction_fx_layer.gd")
const RoomDressingLayerScript := preload("res://scripts/render/room_dressing_layer.gd")
const RoomVideoLayerScript := preload("res://scripts/render/room_video_layer.gd")
const InteractionHintLayerScript := preload("res://scripts/render/interaction_hint_layer.gd")
const CompositeShader := preload("res://shaders/room_composite.gdshader")

var app: Control
func bind(owner: Control) -> void:
    app = owner

func _build_composite() -> void:
    app.composite = TextureRect.new()
    app.composite.name = "RoomComposite"
    app.composite.mouse_filter = Control.MOUSE_FILTER_IGNORE
    app.composite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    app.composite.stretch_mode = TextureRect.STRETCH_SCALE
    app.add_child(app.composite)
    app.composite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    app.composite_material = ShaderMaterial.new()
    app.composite_material.shader = CompositeShader
    app.composite.material = app.composite_material
    app.atmosphere = AtmosphereLayerScript.new()
    app.atmosphere.name = "Atmosphere"
    app.atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
    app.add_child(app.atmosphere)
    app.atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    app.room_dressing = RoomDressingLayerScript.new()
    app.room_dressing.name = "RoomDressing"
    app.room_dressing.mouse_filter = Control.MOUSE_FILTER_IGNORE
    app.add_child(app.room_dressing)
    app.room_dressing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    app.video_layer = RoomVideoLayerScript.new()
    app.video_layer.name = "RoomVideoLayer"
    app.add_child(app.video_layer)
    app.video_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    app.move_child(app.room_dressing, 1)
    app.move_child(app.video_layer, 2)
    app.move_child(app.atmosphere, 3)
    app.hint_layer = InteractionHintLayerScript.new()
    app.hint_layer.name = "InteractionHints"
    app.hint_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    app.add_child(app.hint_layer)
    app.hint_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    app.interaction_fx = InteractionFxLayerScript.new()
    app.interaction_fx.name = "InteractionFx"
    app.interaction_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
    app.add_child(app.interaction_fx)
    app.interaction_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _configure_behavior(room_data: Dictionary) -> void:
    app.behavior = null
    app._behavior_tick_gated = false
    var behavior_path: String = str(room_data.get("behavior_script", ""))
    if behavior_path.is_empty() or not ResourceLoader.exists(behavior_path):
        push_warning("Missing room app.behavior: %s" % behavior_path)
        return
    var resource: Resource = load(behavior_path)
    if resource is Script:
        app.behavior = (resource as Script).new()
        app.behavior.configure(room_data)
        app._behavior_tick_gated = app.behavior.has_method("needs_tick")

func _configure_art(room_data: Dictionary, asset_source = null) -> void:
    var art_value: Variant = room_data.get("art_direction", {})
    var art: Dictionary = art_value if art_value is Dictionary else {}
    var scene_texture: Texture2D = _take_texture(str(art.get("scene_image", "")), asset_source)
    var background_texture: Texture2D = _take_texture(str(art.get("background_image", "")), asset_source)
    var subject_texture: Texture2D = _take_texture(str(art.get("subject_image", "")), asset_source)
    var foreground_texture: Texture2D = _take_texture(str(art.get("foreground_image", "")), asset_source)
    app.composite.texture = scene_texture
    app.composite_material.set_shader_parameter("background_texture", background_texture)
    app.composite_material.set_shader_parameter("subject_texture", subject_texture)
    app.composite_material.set_shader_parameter("foreground_texture", foreground_texture)
    app.composite_material.set_shader_parameter("reveal_mask", app.reveal_mask.texture())
    app.composite_material.set_shader_parameter("accent_color", app._accent_color)
    app.composite_material.set_shader_parameter("noise_tint", Color.from_string(str(app.sensory.get("visual_snow_tint", "#E5C9E8")), Color("e5c9e8")))
    app.composite_material.set_shader_parameter("scene_parallax", float(art.get("scene_parallax", 0.018)))
    app.composite_material.set_shader_parameter("background_parallax", float(art.get("background_parallax", 0.008)))
    app.composite_material.set_shader_parameter("subject_parallax", float(art.get("subject_parallax", 0.026)))
    app.composite_material.set_shader_parameter("foreground_parallax", float(art.get("foreground_parallax", 0.042)))
    app.composite_material.set_shader_parameter("halftone_strength", float(art.get("halftone_strength", 0.22)))
    app.composite_material.set_shader_parameter("ink_strength", float(art.get("ink_strength", 0.72)))
    app.composite_material.set_shader_parameter("scanline_strength", float(app.sensory.get("scanline_strength", 0.35)))
    app.composite_material.set_shader_parameter("roll_strength", float(app.sensory.get("roll_strength", 0.22)))
    app.composite_material.set_shader_parameter("horizontal_jitter", float(app.sensory.get("horizontal_jitter", 0.12)))
    app.composite_material.set_shader_parameter("motion", float(app.sensory.get("static_motion_calm", 0.18)))
    app.composite_material.set_shader_parameter("quality_level", int(app.quality.get("shader_quality", 1)))
    app.composite_material.set_shader_parameter("film_grain_strength", float(art.get("film_grain_strength", 0.30)))
    app.composite_material.set_shader_parameter("completion_reveal", 0.0)
    app.composite_material.set_shader_parameter("completion_origin", Vector2(0.5, 0.5))
    app.composite_material.set_shader_parameter("brush_point", app.pointer_norm)
    app.composite_material.set_shader_parameter("brush_energy", 0.0)
    app.composite_material.set_shader_parameter("subject_lift", 0.0)
    app.composite_material.set_shader_parameter("runtime_scale", app._runtime_scale)
    app.composite_material.set_shader_parameter("cinematic_time", 0.0)
    app.composite_material.set_shader_parameter("unlock_motion", 0.0)
    app.composite_material.set_shader_parameter("unlock_profile", 0)

func _take_texture(path: String, asset_source = null) -> Texture2D:
    if path.is_empty():
        return null
    var resource: Resource = null
    if asset_source != null and asset_source.has_method("take"):
        resource = asset_source.take(path)
    if resource == null and ResourceLoader.exists(path):
        resource = load(path)
    return resource as Texture2D if resource is Texture2D else null
