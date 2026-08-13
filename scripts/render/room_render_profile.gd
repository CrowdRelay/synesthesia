extends RefCounted

static func unlock_index(style: String) -> int:
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

static func apply_readability(material: ShaderMaterial, profile: Dictionary, high_readability: bool, viewport_size: Vector2) -> void:
    if material == null:
        return
    var portrait_gain: float = 1.0 if viewport_size.y > viewport_size.x else (0.35 if OS.has_feature("mobile") else 0.0)
    var high_gain: float = 1.0 if high_readability else 0.0
    var shadow_lift := clampf(float(profile.get("shadow_lift", 0.35)) + high_gain * 0.16, 0.0, 1.0) * portrait_gain
    var subject_lift := clampf(float(profile.get("subject_lift", 0.50)) + high_gain * 0.18, 0.0, 1.0) * portrait_gain
    var highlight_lift := clampf(float(profile.get("highlight_lift", 0.46)) + high_gain * 0.14, 0.0, 1.0) * portrait_gain
    var noise_scale := clampf(float(profile.get("noise_scale", 0.88)) * (0.82 if high_readability else 1.0), 0.52, 1.0)
    var vignette_floor := clampf(float(profile.get("vignette_floor", 0.80)) + high_gain * 0.05, 0.72, 0.92)
    material.set_shader_parameter("readability_shadow_lift", shadow_lift)
    material.set_shader_parameter("readability_subject_lift", subject_lift)
    material.set_shader_parameter("readability_highlight_lift", highlight_lift)
    material.set_shader_parameter("readability_noise_scale", lerpf(1.0, noise_scale, portrait_gain))
    material.set_shader_parameter("readability_vignette_floor", lerpf(0.72, vignette_floor, portrait_gain))
