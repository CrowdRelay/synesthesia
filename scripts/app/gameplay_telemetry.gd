extends Node

const ENDPOINT := "https://signal-api.virya.music/v1/public/telemetry/rum"
const SAMPLE_RATE := 0.05
const MAX_QUEUE := 4

var _room_id: String = ""
var _quality_min_scale: float = 1.0
var _sampled_native: bool = false
var _http: HTTPRequest
var _queue: Array[Dictionary] = []
var _busy: bool = false

func _ready() -> void:
    if OS.has_feature("web"):
        return
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    _sampled_native = rng.randf() < SAMPLE_RATE
    if not _sampled_native:
        return
    _http = HTTPRequest.new()
    _http.timeout = 4.0
    _http.request_completed.connect(_on_request_completed)
    add_child(_http)

func begin_journey(completed_rooms: int, elapsed_ms: int) -> void:
    var resumed: bool = completed_rooms > 0 or elapsed_ms > 0
    _emit_summary(
        "gameplay_journey_resumed_ms" if resumed else "gameplay_journey_started",
        maxi(0, elapsed_ms) if resumed else 1,
        {"completed_rooms": maxi(0, completed_rooms)},
        "/journey",
    )

func complete_journey(elapsed_ms: int, echoes_found: int, echoes_total: int) -> void:
    _emit_summary(
        "gameplay_journey_completed_ms",
        maxi(0, elapsed_ms),
        {"echoes_found": maxi(0, echoes_found), "echoes_total": maxi(0, echoes_total)},
        "/finale",
    )

func begin_room(room_id: String) -> void:
    _room_id = room_id
    _quality_min_scale = 1.0

func note_quality_scale(scale: float) -> void:
    if _room_id.is_empty():
        return
    _quality_min_scale = minf(_quality_min_scale, clampf(scale, 0.0, 1.0))

func complete_room(elapsed_ms: int, guidance: Dictionary) -> void:
    _finish("gameplay_room_completed_ms", elapsed_ms, guidance)

func abandon_room(elapsed_ms: int, guidance: Dictionary) -> void:
    _finish("gameplay_room_abandoned_ms", elapsed_ms, guidance)

func _finish(metric_key: String, elapsed_ms: int, guidance: Dictionary) -> void:
    if _room_id.is_empty() or elapsed_ms < 0:
        return
    var viewport := get_viewport().get_visible_rect().size
    var metadata := {
        "room_id": _room_id.left(64),
        "orientation": "portrait" if viewport.y >= viewport.x else "landscape",
        "platform": "web" if OS.has_feature("web") else ("android" if OS.has_feature("android") else "desktop"),
        "first_success_ms": int(guidance.get("first_success_ms", -1)),
        "miss_count": int(guidance.get("miss_count", 0)),
        "hint_count": int(guidance.get("hint_count", 0)),
        "max_assist_level": int(guidance.get("max_assist_level", 0)),
        "quality_min_scale": snappedf(_quality_min_scale, 0.01),
    }
    if OS.has_feature("web"):
        _dispatch_web(metric_key, elapsed_ms, metadata)
    elif _sampled_native:
        _enqueue_native(metric_key, elapsed_ms, metadata)
    _room_id = ""
    _quality_min_scale = 1.0

func _emit_summary(metric_key: String, value: int, metadata: Dictionary, route: String) -> void:
    if OS.has_feature("web"):
        _dispatch_web(metric_key, value, metadata)
    elif _sampled_native:
        _enqueue_native(metric_key, value, metadata, route)

func _dispatch_web(metric_key: String, value: int, metadata: Dictionary) -> void:
    var detail := JSON.stringify({"metricKey": metric_key, "value": value, "metadata": metadata})
    var js := "window.dispatchEvent(new CustomEvent('synesthesia:gameplay-metric',{detail:%s}));" % detail
    JavaScriptBridge.eval(js, true)

func _enqueue_native(metric_key: String, value: int, metadata: Dictionary, route_override: String = "") -> void:
    if _queue.size() >= MAX_QUEUE:
        _queue.pop_front()
    _queue.append({
        "surface": "synesthesia",
        "metric_key": metric_key,
        "value": value,
        "route": route_override if not route_override.is_empty() else "/room/%s" % _room_id.left(96),
        "device_class": "mobile" if OS.has_feature("android") else "desktop",
        "metadata": metadata,
        "observed_at": Time.get_datetime_string_from_system(true),
    })
    _pump()

func _pump() -> void:
    if _busy or _http == null or _queue.is_empty():
        return
    _busy = true
    var body := JSON.stringify(_queue[0])
    var error := _http.request(ENDPOINT, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body)
    if error != OK:
        _queue.pop_front()
        _busy = false
        call_deferred("_pump")

func _on_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
    if not _queue.is_empty():
        _queue.pop_front()
    _busy = false
    _pump()
