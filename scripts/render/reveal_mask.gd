extends RefCounted

const COVERAGE_ALPHA: int = 54
const MAX_STAMP_HISTORY: int = 1200

var width: int = 270
var height: int = 480
var _alpha: PackedByteArray = PackedByteArray()
var _image: Image
var _texture: ImageTexture
var _covered_pixels: int = 0
var _dirty: bool = false
var _history: Array[Dictionary] = []

func configure(mask_width: int, mask_height: int) -> void:
    width = clampi(mask_width, 90, 540)
    height = clampi(mask_height, 160, 960)
    _alpha.resize(width * height)
    _alpha.fill(0)
    _image = Image.create(width, height, false, Image.FORMAT_L8)
    _image.fill(Color.BLACK)
    _texture = ImageTexture.create_from_image(_image)
    _covered_pixels = 0
    _history.clear()
    _dirty = false

func texture() -> Texture2D:
    return _texture

func clear() -> void:
    _alpha.fill(0)
    _image.fill(Color.BLACK)
    _covered_pixels = 0
    _history.clear()
    _dirty = true
    upload_if_dirty()

func apply_stamp(stamp: Dictionary, remember: bool = true) -> bool:
    var position_value: Variant = stamp.get("position", Vector2.ZERO)
    var position: Vector2 = position_value if position_value is Vector2 else Vector2.ZERO
    var radius_norm: float = clampf(float(stamp.get("radius", 0.04)), 0.004, 0.22)
    var radius_px: float = radius_norm * float(mini(width, height))
    var center_x: float = position.x * float(width - 1)
    var center_y: float = position.y * float(height - 1)
    var rotation: float = float(stamp.get("rotation", 0.0))
    var strength: float = clampf(float(stamp.get("strength", 0.82)), 0.05, 1.0)
    var texture_strength: float = clampf(float(stamp.get("texture", 0.5)), 0.0, 1.0)
    var seed: int = int(stamp.get("seed", 0))
    var profile: String = str(stamp.get("profile", "soft"))
    var stretch: Vector2 = _profile_stretch(profile)
    var extent_x: int = int(ceil(radius_px * stretch.x * 1.18))
    var extent_y: int = int(ceil(radius_px * stretch.y * 1.18))
    var min_x: int = maxi(0, int(floor(center_x)) - extent_x)
    var max_x: int = mini(width - 1, int(ceil(center_x)) + extent_x)
    var min_y: int = maxi(0, int(floor(center_y)) - extent_y)
    var max_y: int = mini(height - 1, int(ceil(center_y)) + extent_y)
    var cosine: float = cos(rotation)
    var sine: float = sin(rotation)
    var changed: bool = false

    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            var dx: float = float(x) - center_x
            var dy: float = float(y) - center_y
            var local_x: float = (dx * cosine + dy * sine) / maxf(radius_px * stretch.x, 0.01)
            var local_y: float = (-dx * sine + dy * cosine) / maxf(radius_px * stretch.y, 0.01)
            var distance: float = sqrt(local_x * local_x + local_y * local_y)
            if distance >= 1.0:
                continue
            var falloff: float = 1.0 - distance
            falloff = falloff * falloff * (3.0 - 2.0 * falloff)
            var grain: float = _grain(x, y, seed, profile)
            var textured: float = clampf(falloff * lerpf(1.0, grain, texture_strength), 0.0, 1.0)
            var value: int = clampi(int(round(255.0 * strength * textured)), 0, 255)
            var index: int = y * width + x
            var previous: int = int(_alpha[index])
            if value <= previous:
                continue
            if previous < COVERAGE_ALPHA and value >= COVERAGE_ALPHA:
                _covered_pixels += 1
            _alpha[index] = value
            var channel: float = float(value) / 255.0
            _image.set_pixel(x, y, Color(channel, channel, channel, 1.0))
            changed = true

    if changed:
        _dirty = true
        if remember:
            _history.append(_compact_stamp(stamp))
            if _history.size() > MAX_STAMP_HISTORY:
                _history = _history.slice(_history.size() - MAX_STAMP_HISTORY)
    return changed

func upload_if_dirty() -> bool:
    if not _dirty or _texture == null:
        return false
    _texture.update(_image)
    _dirty = false
    return true

func coverage() -> float:
    return float(_covered_pixels) / float(maxi(1, width * height))

func export_state() -> Dictionary:
    var stamps: Array = []
    for stamp in _history:
        var position_value: Variant = stamp.get("position", Vector2.ZERO)
        var position: Vector2 = position_value if position_value is Vector2 else Vector2.ZERO
        stamps.append([
            snappedf(position.x, 0.0001),
            snappedf(position.y, 0.0001),
            snappedf(float(stamp.get("radius", 0.04)), 0.0001),
            snappedf(float(stamp.get("rotation", 0.0)), 0.001),
            snappedf(float(stamp.get("strength", 0.82)), 0.01),
            snappedf(float(stamp.get("texture", 0.5)), 0.01),
            int(stamp.get("seed", 0)),
            str(stamp.get("profile", "soft")),
        ])
    return {
        "format": "stamps-v1",
        "mask_size": [width, height],
        "stamps": stamps,
    }

func restore_state(state: Dictionary, fallback_profile: String) -> bool:
    clear()
    var raw_stamps: Variant = state.get("stamps", [])
    if raw_stamps is Array and not raw_stamps.is_empty():
        for value in raw_stamps:
            if not value is Array or value.size() < 7:
                continue
            var profile: String = str(value[7]) if value.size() >= 8 else fallback_profile
            apply_stamp({
                "position": Vector2(float(value[0]), float(value[1])),
                "radius": float(value[2]),
                "rotation": float(value[3]),
                "strength": float(value[4]),
                "texture": float(value[5]),
                "seed": int(value[6]),
                "profile": profile,
            }, true)
        upload_if_dirty()
        return true

    # v0.9 migration: convert stored segment endpoints into one-time mask stamps.
    var legacy_segments: Variant = state.get("segments", [])
    if legacy_segments is Array:
        var serial: int = 0
        for value in legacy_segments:
            if not value is Dictionary:
                continue
            var segment: Dictionary = value
            var raw_from: Variant = segment.get("from", [])
            var raw_to: Variant = segment.get("to", [])
            if not raw_from is Array or raw_from.size() != 2 or not raw_to is Array or raw_to.size() != 2:
                continue
            var from_point: Vector2 = Vector2(float(raw_from[0]), float(raw_from[1]))
            var to_point: Vector2 = Vector2(float(raw_to[0]), float(raw_to[1]))
            var distance: float = from_point.distance_to(to_point)
            var steps: int = clampi(int(ceil(distance / 0.025)), 1, 12)
            for step in range(steps + 1):
                serial += 1
                apply_stamp({
                    "position": from_point.lerp(to_point, float(step) / float(steps)),
                    "radius": clampf(float(segment.get("width", 0.05)) * 0.5, 0.012, 0.11),
                    "rotation": (to_point - from_point).angle(),
                    "strength": 0.86,
                    "texture": 0.52,
                    "seed": serial,
                    "profile": str(segment.get("profile", fallback_profile)),
                }, true)
        upload_if_dirty()
        return serial > 0
    return false

func _compact_stamp(stamp: Dictionary) -> Dictionary:
    return {
        "position": stamp.get("position", Vector2.ZERO),
        "radius": float(stamp.get("radius", 0.04)),
        "rotation": float(stamp.get("rotation", 0.0)),
        "strength": float(stamp.get("strength", 0.82)),
        "texture": float(stamp.get("texture", 0.5)),
        "seed": int(stamp.get("seed", 0)),
        "profile": str(stamp.get("profile", "soft")),
    }

func _profile_stretch(profile: String) -> Vector2:
    match profile:
        "water", "soft", "luminous":
            return Vector2(1.22, 0.88)
        "ink", "wine", "dry_ink":
            return Vector2(1.45, 0.62)
        "glitch":
            return Vector2(1.62, 0.52)
        "glass":
            return Vector2(1.36, 0.48)
        "organic":
            return Vector2(1.10, 0.78)
        "confetti", "ember":
            return Vector2(1.04, 0.86)
        _:
            return Vector2.ONE

func _grain(x: int, y: int, seed: int, profile: String) -> float:
    var base: float = _hash01(x, y, seed)
    match profile:
        "dry_ink":
            return 0.30 + 0.70 * step(0.28, base)
        "glitch":
            var stripe: float = _hash01(x / 5, y / 2, seed + 91)
            return 0.18 + 0.82 * step(0.22, stripe)
        "glass":
            return 0.50 + 0.50 * abs(sin(float(x + y + seed) * 0.31))
        "confetti":
            return 0.35 + 0.65 * step(0.36, base)
        "ember":
            return 0.38 + 0.62 * pow(base, 0.45)
        "organic":
            return 0.48 + 0.52 * (0.5 + 0.5 * sin(float(x * 3 + y * 2 + seed) * 0.11))
        _:
            return 0.58 + 0.42 * base

func _hash01(x: int, y: int, seed: int) -> float:
    var value: float = sin(float(x * 127 + y * 311 + seed * 74) * 0.0171) * 43758.5453
    return value - floor(value)
