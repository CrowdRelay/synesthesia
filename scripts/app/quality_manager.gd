extends RefCounted

const ORDER: Array[String] = ["battery", "balanced", "high"]

static func recommended() -> String:
    if OS.has_feature("web") or OS.has_feature("mobile"):
        return "balanced"
    return "high"

static func frame_cap(profile_name: String) -> int:
    return 60 if profile_name == "battery" else 0

static func resolve(profile_name: String) -> Dictionary:
    match profile_name:
        "battery":
            return {
                "name": "battery",
                "label": "Bateria",
                "mask_width": 180,
                "mask_height": 320,
                "particle_count": 20,
                "atmosphere_hz": 12.0,
                "shader_quality": 0,
                "texture_upload_hz": 24.0,
            }
        "high":
            return {
                "name": "high",
                "label": "Wysoka",
                "mask_width": 360,
                "mask_height": 640,
                "particle_count": 72,
                "atmosphere_hz": 30.0,
                "shader_quality": 2,
                "texture_upload_hz": 45.0,
            }
        _:
            return {
                "name": "balanced",
                "label": "Zbalansowana",
                "mask_width": 270,
                "mask_height": 480,
                "particle_count": 42,
                "atmosphere_hz": 24.0,
                "shader_quality": 1,
                "texture_upload_hz": 30.0,
            }

static func next(profile_name: String) -> String:
    var index: int = ORDER.find(profile_name)
    if index < 0:
        return "balanced"
    return ORDER[(index + 1) % ORDER.size()]
