extends Node

signal cities_loaded(items: Array)
signal signup_finished(message: String)
signal request_failed(message: String)

var _api_url: String = ""
var _http: HTTPRequest
var _operation: String = ""

func _ready() -> void:
    _http = HTTPRequest.new()
    _http.name = "SignalSignupHttp"
    _http.timeout = 12.0
    _http.request_completed.connect(_on_request_completed)
    add_child(_http)

func configure(api_url: String) -> void:
    _api_url = api_url.trim_suffix("/")

func load_cities() -> void:
    if _api_url.is_empty() or _http == null:
        request_failed.emit("Sygnał jest chwilowo niedostępny.")
        return
    if not _operation.is_empty():
        return
    _operation = "cities"
    var error: Error = _http.request("%s/v1/public/cities?limit=100" % _api_url, PackedStringArray(["Accept: application/json"]), HTTPClient.METHOD_GET)
    if error != OK:
        _operation = ""
        request_failed.emit("Nie udało się pobrać listy miast.")

func signup(email: String, city_slug: String, policy_version: String) -> void:
    if _api_url.is_empty() or _http == null:
        request_failed.emit("Sygnał jest chwilowo niedostępny.")
        return
    if not _operation.is_empty():
        return
    var normalized_email: String = email.strip_edges().to_lower()
    var key: String = "synesthesia-signal-%s-%s" % [city_slug, normalized_email.sha256_text().substr(0, 20)]
    var body: String = JSON.stringify({
        "email": normalized_email,
        "city_slug": city_slug,
        "locale": TranslationServer.get_locale(),
        "consent": {
            "marketing": true,
            "policy_version": policy_version,
        },
    })
    _operation = "signup"
    var headers := PackedStringArray([
        "Accept: application/json",
        "Content-Type: application/json",
        "Idempotency-Key: %s" % key,
    ])
    var error: Error = _http.request("%s/v1/fans" % _api_url, headers, HTTPClient.METHOD_POST, body)
    if error != OK:
        _operation = ""
        request_failed.emit("Nie udało się włączyć Sygnału.")

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    var operation: String = _operation
    _operation = ""
    var parsed: Dictionary = {}
    if not body.is_empty():
        var decoded: Variant = JSON.parse_string(body.get_string_from_utf8())
        if decoded is Dictionary:
            parsed = decoded
    if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
        request_failed.emit(str(parsed.get("message", "Sygnał jest chwilowo niedostępny.")))
        return
    if operation == "cities":
        var raw: Variant = parsed.get("items", [])
        var items: Array = raw if raw is Array else []
        cities_loaded.emit(items)
        return
    if operation == "signup":
        var confirmation_required: bool = bool(parsed.get("confirmation_required", false))
        signup_finished.emit("Sprawdź e-mail i potwierdź Sygnał." if confirmation_required else "Sygnał jest już włączony.")
