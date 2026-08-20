extends Node

signal cities_loaded(items: Array)
signal signup_finished(message: String)
signal request_failed(message: String)

const MAX_RESPONSE_BYTES: int = 524_288
const MAX_RETRY_ATTEMPTS: int = 3
const RETRY_BASE_SECONDS: float = 0.8
const RETRY_MAX_SECONDS: float = 6.0
const RETRY_JITTER_SECONDS: float = 0.35
const MAX_RETRY_AFTER_SECONDS: float = 8.0

var _api_url: String = ""
var _http: HTTPRequest
var _retry_timer: Timer
var _operation: String = ""
var _pending: Dictionary = {}
var _attempt: int = 0

func _ready() -> void:
    _ensure_http()

func _ensure_http() -> bool:
    if _http == null or not is_instance_valid(_http):
        _http = HTTPRequest.new()
        _http.name = "SignalSignupHttp"
        _http.timeout = 12.0
        _http.body_size_limit = MAX_RESPONSE_BYTES
        _http.request_completed.connect(_on_request_completed)
        add_child(_http)
    if _retry_timer == null or not is_instance_valid(_retry_timer):
        _retry_timer = Timer.new()
        _retry_timer.name = "SignalSignupRetry"
        _retry_timer.one_shot = true
        _retry_timer.timeout.connect(_on_retry_timeout)
        add_child(_retry_timer)
    return true

func configure(api_url: String) -> void:
    _api_url = api_url.trim_suffix("/")

func load_cities() -> void:
    if _api_url.is_empty() or not _ensure_http():
        request_failed.emit("Nie udało się uruchomić formularza Sygnału.")
        return
    if not _operation.is_empty():
        return
    _begin_request({
        "operation": "cities",
        "url": "%s/v1/public/cities?limit=100" % _api_url,
        "method": HTTPClient.METHOD_GET,
        "headers": PackedStringArray(["Accept: application/json"]),
        "body": "",
    })

func signup(email: String, city_slug: String, policy_version: String) -> void:
    if _api_url.is_empty() or not _ensure_http():
        request_failed.emit("Nie udało się uruchomić formularza Sygnału.")
        return
    if not _operation.is_empty():
        return
    var normalized_email: String = email.strip_edges().to_lower()
    var normalized_city: String = city_slug.strip_edges().to_lower()
    var normalized_policy: String = policy_version.strip_edges()
    if not _valid_email(normalized_email) or not _valid_slug(normalized_city) or normalized_policy.is_empty() or normalized_policy.length() > 128:
        request_failed.emit("Sprawdź e-mail i wybrane miasto.")
        return
    var key: String = "synesthesia-signal-%s-%s" % [normalized_city, normalized_email.sha256_text().substr(0, 20)]
    var body: String = JSON.stringify({
        "email": normalized_email,
        "city_slug": normalized_city,
        "locale": TranslationServer.get_locale(),
        "consent": {
            "marketing": true,
            "policy_version": normalized_policy,
        },
    })
    _begin_request({
        "operation": "signup",
        "url": "%s/v1/fans" % _api_url,
        "method": HTTPClient.METHOD_POST,
        "headers": PackedStringArray([
            "Accept: application/json",
            "Content-Type: application/json",
            "Idempotency-Key: %s" % key,
        ]),
        "body": body,
        "idempotency_key": key,
    })

func _begin_request(request_data: Dictionary) -> void:
    _operation = str(request_data.get("operation", ""))
    _pending = request_data.duplicate(true)
    _attempt = 0
    _send_pending()

func _send_pending() -> void:
    if _pending.is_empty() or not _ensure_http():
        _fail_active("Nie udało się uruchomić połączenia z Sygnałem.")
        return
    var error: Error = _http.request(
        str(_pending.get("url", "")),
        _pending.get("headers", PackedStringArray()) as PackedStringArray,
        int(_pending.get("method", HTTPClient.METHOD_GET)),
        str(_pending.get("body", "")),
    )
    if error != OK:
        _handle_failure(0, PackedStringArray(), "Nie udało się rozpocząć połączenia z Sygnałem.")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    var parsed: Dictionary = {}
    if not body.is_empty():
        var decoded: Variant = JSON.parse_string(body.get_string_from_utf8())
        if decoded is Dictionary:
            parsed = decoded
    if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
        _handle_failure(response_code, headers, str(parsed.get("message", "Nie udało się połączyć z Sygnałem. Spróbuj ponownie.")))
        return

    var operation: String = _operation
    _clear_active()
    if operation == "cities":
        var raw: Variant = parsed.get("items", [])
        var items: Array = raw if raw is Array else []
        cities_loaded.emit(items)
        return
    if operation == "signup":
        var confirmation_required: bool = bool(parsed.get("confirmation_required", false))
        signup_finished.emit("Sprawdź e-mail i potwierdź Sygnał." if confirmation_required else "Sygnał jest już włączony.")

func _handle_failure(response_code: int, headers: PackedStringArray, message: String) -> void:
    if _is_transient_failure(response_code) and _attempt < MAX_RETRY_ATTEMPTS:
        _attempt += 1
        var delay_seconds: float = _retry_delay(_attempt, headers)
        _retry_timer.start(delay_seconds)
        return
    _fail_active(message)

func _retry_delay(attempt: int, headers: PackedStringArray) -> float:
    var retry_after: float = _retry_after_seconds(headers)
    if retry_after > 0.0:
        return minf(retry_after, MAX_RETRY_AFTER_SECONDS)
    var exponential: float = minf(RETRY_MAX_SECONDS, RETRY_BASE_SECONDS * pow(2.0, float(attempt - 1)))
    var seed: String = "%s:%s:%d:%d:%d" % [
        _operation,
        str(_pending.get("idempotency_key", "cities")),
        attempt,
        get_instance_id(),
        Time.get_ticks_msec(),
    ]
    var bucket: int = absi(seed.hash()) % 1000
    return exponential + (float(bucket) / 999.0) * RETRY_JITTER_SECONDS

func _retry_after_seconds(headers: PackedStringArray) -> float:
    for header in headers:
        var value: String = str(header)
        var split: int = value.find(":")
        if split <= 0:
            continue
        if value.substr(0, split).strip_edges().to_lower() != "retry-after":
            continue
        var raw: String = value.substr(split + 1).strip_edges()
        if raw.is_valid_int():
            return maxf(0.0, float(raw.to_int()))
    return 0.0

func _is_transient_failure(response_code: int) -> bool:
    return response_code == 0 or response_code == 408 or response_code == 425 or response_code == 429 or response_code >= 500

func _on_retry_timeout() -> void:
    if not _operation.is_empty() and not _pending.is_empty():
        _send_pending()

func _fail_active(message: String) -> void:
    _clear_active()
    request_failed.emit(message)

func _clear_active() -> void:
    _operation = ""
    _pending = {}
    _attempt = 0
    if _retry_timer != null and is_instance_valid(_retry_timer):
        _retry_timer.stop()

func _valid_email(value: String) -> bool:
    if value.length() < 3 or value.length() > 254 or value.contains(" ") or value.contains("\t") or value.contains("\n") or value.contains("\r"):
        return false
    var at: int = value.find("@")
    return at > 0 and at == value.rfind("@") and at < value.length() - 1 and value.substr(at + 1).contains(".")

func _valid_slug(value: String) -> bool:
    if value.is_empty() or value.length() > 96:
        return false
    for index in value.length():
        var code: int = value.unicode_at(index)
        var ascii_letter: bool = code >= 97 and code <= 122
        var digit: bool = code >= 48 and code <= 57
        if not ascii_letter and not digit and code != 45 and code != 95:
            return false
    return true

func shutdown() -> void:
    _clear_active()
    if _http != null and is_instance_valid(_http):
        _http.cancel_request()

func _exit_tree() -> void:
    shutdown()
