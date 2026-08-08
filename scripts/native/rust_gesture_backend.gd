extends RefCounted

## Native/WASM gesture backend. Production Web and Android builds are expected
## to load this extension; GDScript remains an explicit emergency fallback.

static var _runtime_reported: bool = false
var _backend: Object

func _init() -> void:
    if ClassDB.class_exists("SynesthesiaGestureCore"):
        _backend = ClassDB.instantiate("SynesthesiaGestureCore")
        _report_runtime_once()

func available() -> bool:
    return _backend != null

func reset() -> void:
    if _backend != null:
        _backend.call("reset")

func active_pointer_count() -> int:
    return int(_backend.call("active_pointer_count")) if _backend != null else 0

func has_pointer(pointer_id: int) -> bool:
    return bool(_backend.call("has_pointer", pointer_id)) if _backend != null else false

func single_pointer() -> Dictionary:
    if _backend == null:
        return {}
    var value: Variant = _backend.call("single_pointer")
    return value if value is Dictionary else {}

func pointer_down(pointer_id: int, point: Vector2, now_ms: int) -> Array:
    return _events(_backend.call(&"pointer_down", pointer_id, point, now_ms) if _backend != null else null)

func pointer_move(pointer_id: int, point: Vector2, now_ms: int) -> Array:
    return _events(_backend.call(&"pointer_move", pointer_id, point, now_ms) if _backend != null else null)

func pointer_up(pointer_id: int, point: Vector2, now_ms: int) -> Array:
    return _events(_backend.call(&"pointer_up", pointer_id, point, now_ms) if _backend != null else null)

func advance(now_ms: int) -> Array:
    return _events(_backend.call(&"advance", now_ms) if _backend != null else null)

func _events(value: Variant) -> Array:
    return value if value is Array else []

func _report_runtime_once() -> void:
    if _runtime_reported:
        return
    _runtime_reported = true
    var backend := "native"
    if OS.has_feature("web"):
        backend = "web-wasm"
    elif OS.has_feature("android"):
        backend = "android-native"
    print("SYNESTHESIA_RUST_RUNTIME=PASS backend=%s" % backend)
