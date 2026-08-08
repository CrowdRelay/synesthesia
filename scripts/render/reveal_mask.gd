extends RefCounted

const COVERAGE_ALPHA: int = 54
const STATE_FORMAT: String = "png-mask-v2"
const MAX_ENCODED_STATE_CHARS: int = 1_000_000
const MAX_PNG_STATE_BYTES: int = 750_000
const GRAIN_DEFAULT: int = 0
const GRAIN_DRY_INK: int = 1
const GRAIN_GLITCH: int = 2
const GRAIN_GLASS: int = 3
const GRAIN_CONFETTI: int = 4
const GRAIN_EMBER: int = 5
const GRAIN_ORGANIC: int = 6

var width: int = 270
var height: int = 480
var _alpha: PackedByteArray = PackedByteArray()
var _image: Image
var _texture: ImageTexture
var _covered_pixels: int = 0
var _dirty: bool = false
var _revision: int = 0
var _cached_revision: int = -1
var _cached_state: Dictionary = {}
var _cached_png_bytes: int = 0
var _state_encode_count: int = 0

func configure(mask_width: int, mask_height: int) -> void:
    width = clampi(mask_width, 90, 540)
    height = clampi(mask_height, 160, 960)
    _alpha.resize(width * height)
    _alpha.fill(0)
    _image = Image.create(width, height, false, Image.FORMAT_L8)
    _sync_image_data()
    _texture = ImageTexture.create_from_image(_image)
    _covered_pixels = 0
    _dirty = false
    _revision = 0
    _invalidate_export_cache()
    _state_encode_count = 0

func texture() -> Texture2D:
    return _texture

func clear() -> void:
    _alpha.fill(0)
    _covered_pixels = 0
    _dirty = true
    _mark_changed()
    upload_if_dirty()

func apply_stamp(stamp: Dictionary, _remember: bool = true) -> bool:
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
    var grain_mode: int = _grain_mode(profile)
    var radius_x: float = maxf(radius_px * stretch.x, 0.01)
    var radius_y: float = maxf(radius_px * stretch.y, 0.01)
    var inverse_radius_x: float = 1.0 / radius_x
    var inverse_radius_y: float = 1.0 / radius_y
    var extent_x: int = int(ceil(radius_x * 1.18))
    var extent_y: int = int(ceil(radius_y * 1.18))
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
            var local_x: float = (dx * cosine + dy * sine) * inverse_radius_x
            var local_y: float = (-dx * sine + dy * cosine) * inverse_radius_y
            var distance_squared: float = local_x * local_x + local_y * local_y
            if distance_squared >= 1.0:
                continue
            var distance: float = sqrt(distance_squared)
            var falloff: float = 1.0 - distance
            falloff = falloff * falloff * (3.0 - 2.0 * falloff)
            var grain: float = _grain(x, y, seed, grain_mode)
            var textured: float = clampf(falloff * lerpf(1.0, grain, texture_strength), 0.0, 1.0)
            var value: int = clampi(int(round(255.0 * strength * textured)), 0, 255)
            var index: int = y * width + x
            var previous: int = int(_alpha[index])
            if value <= previous:
                continue
            if previous < COVERAGE_ALPHA and value >= COVERAGE_ALPHA:
                _covered_pixels += 1
            _alpha[index] = value
            changed = true

    if changed:
        _dirty = true
        _mark_changed()
    return changed

func upload_if_dirty() -> bool:
    if not _dirty or _texture == null:
        return false
    _sync_image_data()
    _texture.update(_image)
    _dirty = false
    return true

func coverage() -> float:
    return float(_covered_pixels) / float(maxi(1, width * height))

func export_state() -> Dictionary:
    _ensure_export_cache()
    return _cached_state.duplicate(true)

func restore_state(state: Dictionary, fallback_profile: String) -> bool:
    var state_format: String = str(state.get("format", ""))
    # A valid PNG fully replaces the mask, so do not upload an empty clear frame
    # first. Invalid/legacy formats still start from a known-empty mask.
    if state_format == STATE_FORMAT and _restore_png_state(state):
        return true
    clear()
    if state_format == "threshold-bitmap-v2-fallback" and _restore_threshold_runs(state):
        return true

    # v0.10/v0.9 migration: replay stored brush stamps once into the raster mask.
    var raw_stamps: Variant = state.get("stamps", [])
    if raw_stamps is Array and not raw_stamps.is_empty():
        var restored_stamps: int = 0
        for value in raw_stamps:
            if not value is Array or value.size() < 7:
                continue
            var profile: String = str(value[7]) if value.size() >= 8 else fallback_profile
            if apply_stamp({
                "position": Vector2(float(value[0]), float(value[1])),
                "radius": float(value[2]),
                "rotation": float(value[3]),
                "strength": float(value[4]),
                "texture": float(value[5]),
                "seed": int(value[6]),
                "profile": profile,
            }, false):
                restored_stamps += 1
        upload_if_dirty()
        return restored_stamps > 0

    # v0.9 legacy migration: convert segment endpoints into one-time mask stamps.
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
            for step_index in range(steps + 1):
                serial += 1
                apply_stamp({
                    "position": from_point.lerp(to_point, float(step_index) / float(steps)),
                    "radius": clampf(float(segment.get("width", 0.05)) * 0.5, 0.012, 0.11),
                    "rotation": (to_point - from_point).angle(),
                    "strength": 0.86,
                    "texture": 0.52,
                    "seed": serial,
                    "profile": str(segment.get("profile", fallback_profile)),
                }, false)
        upload_if_dirty()
        return serial > 0
    return false

func estimated_state_bytes() -> int:
    _ensure_export_cache()
    return _cached_png_bytes

func state_encode_count() -> int:
    return _state_encode_count

func _ensure_export_cache() -> void:
    if _cached_revision == _revision and not _cached_state.is_empty():
        return
    _sync_image_data()
    var png: PackedByteArray = _image.save_png_to_buffer()
    _state_encode_count += 1
    if png.is_empty():
        _cached_state = {
            "format": "threshold-bitmap-v2-fallback",
            "mask_size": [width, height],
            "covered": _export_threshold_runs(),
        }
        _cached_png_bytes = _alpha.size()
    else:
        _cached_state = {
            "format": STATE_FORMAT,
            "mask_size": [width, height],
            "png_base64": Marshalls.raw_to_base64(png),
        }
        _cached_png_bytes = png.size()
    _cached_revision = _revision

func _mark_changed() -> void:
    _revision += 1
    _invalidate_export_cache()

func _invalidate_export_cache() -> void:
    _cached_revision = -1
    _cached_state.clear()
    _cached_png_bytes = 0

func _restore_png_state(state: Dictionary) -> bool:
    var encoded: String = str(state.get("png_base64", ""))
    if encoded.is_empty() or encoded.length() > MAX_ENCODED_STATE_CHARS:
        return false
    var png: PackedByteArray = Marshalls.base64_to_raw(encoded)
    if png.is_empty() or png.size() > MAX_PNG_STATE_BYTES:
        return false
    var restored: Image = Image.new()
    var error: Error = restored.load_png_from_buffer(png)
    if error != OK or restored.is_empty():
        return false
    var reusable_png: bool = (
        restored.get_format() == Image.FORMAT_L8
        and restored.get_width() == width
        and restored.get_height() == height
    )
    if restored.get_format() != Image.FORMAT_L8:
        restored.convert(Image.FORMAT_L8)
    if restored.get_width() != width or restored.get_height() != height:
        restored.resize(width, height, Image.INTERPOLATE_LANCZOS)
    _image = restored
    _alpha = _image.get_data()
    if _alpha.size() != width * height:
        return false
    _recount_coverage()
    _texture.update(_image)
    _dirty = false
    _mark_changed()
    if reusable_png:
        # The validated source bytes already represent this exact mask revision.
        # Reuse them until the next brush mutation instead of PNG-encoding again
        # on the first autosave after resume.
        _cached_state = {
            "format": STATE_FORMAT,
            "mask_size": [width, height],
            "png_base64": encoded,
        }
        _cached_png_bytes = png.size()
        _cached_revision = _revision
    return true

func _export_threshold_runs() -> Array:
    var runs: Array = []
    var index: int = 0
    while index < _alpha.size():
        if int(_alpha[index]) < COVERAGE_ALPHA:
            index += 1
            continue
        var start: int = index
        while index < _alpha.size() and int(_alpha[index]) >= COVERAGE_ALPHA:
            index += 1
        runs.append([start, index - start])
    return runs

func _restore_threshold_runs(state: Dictionary) -> bool:
    var runs_value: Variant = state.get("covered", [])
    if not runs_value is Array:
        return false
    var any_run: bool = false
    for raw_run in runs_value:
        if not raw_run is Array or raw_run.size() != 2:
            continue
        var start: int = clampi(int(raw_run[0]), 0, _alpha.size())
        var length: int = clampi(int(raw_run[1]), 0, _alpha.size() - start)
        for offset in range(length):
            _alpha[start + offset] = 255
        any_run = any_run or length > 0
    _recount_coverage()
    _dirty = true
    _mark_changed()
    upload_if_dirty()
    return any_run

func _sync_image_data() -> void:
    if _image == null:
        _image = Image.create(width, height, false, Image.FORMAT_L8)
    _image.set_data(width, height, false, Image.FORMAT_L8, _alpha)

func _recount_coverage() -> void:
    _covered_pixels = 0
    for value in _alpha:
        if int(value) >= COVERAGE_ALPHA:
            _covered_pixels += 1

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

func _grain_mode(profile: String) -> int:
    match profile:
        "dry_ink": return GRAIN_DRY_INK
        "glitch": return GRAIN_GLITCH
        "glass": return GRAIN_GLASS
        "confetti": return GRAIN_CONFETTI
        "ember": return GRAIN_EMBER
        "organic": return GRAIN_ORGANIC
        _: return GRAIN_DEFAULT

func _grain(x: int, y: int, seed: int, mode: int) -> float:
    # Select the profile once per stamp. Glitch/glass/organic never used the
    # old base hash, so avoid a per-pixel sine/hash that was pure dead work.
    match mode:
        GRAIN_GLITCH:
            var stripe_x: int = int(floor(float(x) / 5.0))
            var stripe_y: int = int(floor(float(y) / 2.0))
            var stripe: float = _hash01(stripe_x, stripe_y, seed + 91)
            return 0.18 + 0.82 * _threshold(stripe, 0.22)
        GRAIN_GLASS:
            return 0.50 + 0.50 * abs(sin(float(x + y + seed) * 0.31))
        GRAIN_ORGANIC:
            return 0.48 + 0.52 * (0.5 + 0.5 * sin(float(x * 3 + y * 2 + seed) * 0.11))

    var base: float = _hash01(x, y, seed)
    match mode:
        GRAIN_DRY_INK:
            return 0.30 + 0.70 * _threshold(base, 0.28)
        GRAIN_CONFETTI:
            return 0.35 + 0.65 * _threshold(base, 0.36)
        GRAIN_EMBER:
            return 0.38 + 0.62 * pow(base, 0.45)
        _:
            return 0.58 + 0.42 * base

func _threshold(value: float, edge: float) -> float:
    return 0.0 if value < edge else 1.0

func _hash01(x: int, y: int, seed: int) -> float:
    var value: float = sin(float(x * 127 + y * 311 + seed * 74) * 0.0171) * 43758.5453
    return value - floor(value)
