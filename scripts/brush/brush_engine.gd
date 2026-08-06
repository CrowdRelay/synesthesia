extends RefCounted

const MAX_STAMPS_PER_SAMPLE: int = 4
const MIN_SAMPLE_DISTANCE_PX: float = 1.5

var profile: String = "soft"
var min_width_px: float = 22.0
var max_width_px: float = 58.0
var opacity: float = 0.82
var texture_strength: float = 0.52
var spacing_ratio: float = 0.58
var _last_point: Vector2 = Vector2.ZERO
var _last_time_ms: int = 0
var _drawing: bool = false
var _serial: int = 0

func configure(data: Dictionary) -> void:
    profile = str(data.get("profile", "soft"))
    min_width_px = clampf(float(data.get("min_width", 22.0)), 10.0, 80.0)
    max_width_px = clampf(float(data.get("max_width", 58.0)), min_width_px, 120.0)
    opacity = clampf(float(data.get("opacity", 0.82)), 0.25, 1.0)
    texture_strength = clampf(float(data.get("texture", 0.52)), 0.0, 1.0)
    spacing_ratio = clampf(float(data.get("spacing", 0.58)), 0.28, 1.1)

func begin(point_norm: Vector2, time_ms: int, reference_px: float) -> Array[Dictionary]:
    _drawing = true
    _last_point = point_norm
    _last_time_ms = time_ms
    return [_make_stamp(point_norm, 0.18, 0.0, reference_px)]

func sample(point_norm: Vector2, time_ms: int, reference_px: float) -> Array[Dictionary]:
    if not _drawing:
        return begin(point_norm, time_ms, reference_px)
    var distance_px: float = _last_point.distance_to(point_norm) * reference_px
    if distance_px < MIN_SAMPLE_DISTANCE_PX:
        return []
    var elapsed_ms: int = maxi(1, time_ms - _last_time_ms)
    var speed_px_s: float = distance_px * 1000.0 / float(elapsed_ms)
    var speed_normalized: float = clampf(speed_px_s / 1250.0, 0.0, 1.0)
    var width_px: float = lerpf(min_width_px, max_width_px, 0.20 + speed_normalized * 0.80)
    var spacing_px: float = maxf(3.0, width_px * spacing_ratio * 0.42)
    var steps: int = clampi(int(ceil(distance_px / spacing_px)), 1, MAX_STAMPS_PER_SAMPLE)
    var direction: Vector2 = point_norm - _last_point
    var angle: float = direction.angle()
    var result: Array[Dictionary] = []
    for step in range(1, steps + 1):
        var ratio: float = float(step) / float(steps)
        var position: Vector2 = _last_point.lerp(point_norm, ratio)
        result.append(_make_stamp(position, speed_normalized, angle, reference_px))
    _last_point = point_norm
    _last_time_ms = time_ms
    return result

func end() -> void:
    _drawing = false

func is_drawing() -> bool:
    return _drawing

func _make_stamp(position: Vector2, speed: float, angle: float, reference_px: float) -> Dictionary:
    _serial += 1
    var jitter: float = (_hash01(_serial, 17) - 0.5) * 0.34
    var scale_jitter: float = lerpf(0.90, 1.10, _hash01(_serial, 29))
    var width_px: float = lerpf(min_width_px, max_width_px, 0.20 + speed * 0.80) * scale_jitter
    return {
        "position": Vector2(clampf(position.x, 0.0, 1.0), clampf(position.y, 0.0, 1.0)),
        "radius": width_px * 0.5 / maxf(reference_px, 1.0),
        "rotation": angle + jitter,
        "strength": opacity,
        "texture": texture_strength,
        "speed": speed,
        "seed": _serial,
        "profile": profile,
    }

func _hash01(a: int, b: int) -> float:
    var value: float = sin(float(a * 127 + b * 311) * 0.0137) * 43758.5453
    return value - floor(value)
