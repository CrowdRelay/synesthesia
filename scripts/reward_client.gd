extends Node
class_name SynesthesiaRewardClient

signal run_started(run_id: String, run_token: String, next_room_index: int)
signal room_recorded(room_id: String, next_room_index: int)
signal album_recorded()
signal reward_claimed(status: String, message: String)
signal request_failed(operation: String, message: String)

var _api_url: String = ""
var _campaign_slug: String = ""
var _app_version: String = ""
var _install_id: String = ""
var _run_id: String = ""
var _run_token: String = ""
var _server_next_room_index: int = 0
var _http: HTTPRequest
var _queue: Array[Dictionary] = []
var _active: Dictionary = {}
var _busy: bool = false

func _ready() -> void:
    _http = HTTPRequest.new()
    _http.name = "SynesthesiaRewardHttp"
    _http.timeout = 15.0
    _http.request_completed.connect(_on_request_completed)
    add_child(_http)

func configure(api_url: String, campaign_slug: String, app_version: String, install_id: String) -> void:
    _api_url = api_url.trim_suffix("/")
    _campaign_slug = campaign_slug
    _app_version = app_version
    _install_id = install_id

func restore_run(run_state: Dictionary) -> void:
    _run_id = str(run_state.get("run_id", ""))
    _run_token = str(run_state.get("run_token", ""))
    _server_next_room_index = maxi(0, int(run_state.get("next_room_index", 0)))

func has_run() -> bool:
    return not _run_id.is_empty() and not _run_token.is_empty()

func get_run_state() -> Dictionary:
    return {
        "run_id": _run_id,
        "run_token": _run_token,
        "campaign_slug": _campaign_slug,
        "next_room_index": _server_next_room_index,
    }

func start_run() -> void:
    if _api_url.is_empty() or _campaign_slug.is_empty() or _install_id.is_empty():
        request_failed.emit("start_run", "Konfiguracja Sygnału jest niepełna.")
        return
    if has_run():
        run_started.emit(_run_id, _run_token, _server_next_room_index)
        return
    _enqueue({
        "operation": "start_run",
        "path": "/v1/public/synesthesia/runs",
        "authorized": false,
        "idempotency_key": "synesthesia-start-%s" % _install_id,
        "payload": {
            "campaign_slug": _campaign_slug,
            "install_id": _install_id,
            "app_version": _app_version,
            "locale": TranslationServer.get_locale(),
        },
    })

func record_room(room_id: String, room_index: int, elapsed_ms: int) -> void:
    if not has_run():
        request_failed.emit("record_room", "Brak aktywnego przebiegu Sygnału.")
        return
    _enqueue({
        "operation": "record_room",
        "room_id": room_id,
        "path": "/v1/public/synesthesia/runs/%s/rooms/%s" % [_run_id, room_id],
        "authorized": true,
        "idempotency_key": "synesthesia-room-%s-%s" % [_run_id, room_id],
        "payload": {
            "room_index": room_index,
            "client_elapsed_ms": maxi(0, elapsed_ms),
        },
    })

func complete_album(total_elapsed_ms: int) -> void:
    if not has_run():
        request_failed.emit("complete_album", "Brak aktywnego przebiegu Sygnału.")
        return
    _enqueue({
        "operation": "complete_album",
        "path": "/v1/public/synesthesia/runs/%s/complete" % _run_id,
        "authorized": true,
        "idempotency_key": "synesthesia-complete-%s" % _run_id,
        "payload": {
            "client_total_elapsed_ms": maxi(0, total_elapsed_ms),
        },
    })

func claim_reward(email: String, city_slug: String, marketing_consent: bool, policy_version: String) -> void:
    if not has_run():
        request_failed.emit("claim_reward", "Nie udało się połączyć ukończenia z nagrodą.")
        return
    _enqueue({
        "operation": "claim_reward",
        "path": "/v1/public/synesthesia/reward-claims",
        "authorized": true,
        "idempotency_key": "synesthesia-claim-%s" % _run_id,
        "payload": {
            "email": email.strip_edges(),
            "city_slug": city_slug,
            "marketing_consent": marketing_consent,
            "policy_version": policy_version,
            "locale": TranslationServer.get_locale(),
        },
    })

func _enqueue(request_data: Dictionary) -> void:
    _queue.append(request_data.duplicate(true))
    _pump()

func _pump() -> void:
    if _busy or _queue.is_empty():
        return
    _active = _queue.pop_front()
    _busy = true
    var headers: PackedStringArray = PackedStringArray([
        "Accept: application/json",
        "Content-Type: application/json",
        "Idempotency-Key: %s" % str(_active.get("idempotency_key", "")),
    ])
    if bool(_active.get("authorized", false)):
        headers.append("Authorization: Bearer %s" % _run_token)
    var body: String = JSON.stringify(_active.get("payload", {}))
    var url: String = "%s%s" % [_api_url, str(_active.get("path", ""))]
    var error: Error = _http.request(url, headers, HTTPClient.METHOD_POST, body)
    if error != OK:
        var operation: String = str(_active.get("operation", "request"))
        _busy = false
        _active = {}
        request_failed.emit(operation, "Nie udało się rozpocząć połączenia z Sygnałem.")
        call_deferred("_pump")

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    var operation: String = str(_active.get("operation", "request"))
    var active_copy: Dictionary = _active.duplicate(true)
    _busy = false
    _active = {}

    var parsed: Dictionary = {}
    if not body.is_empty():
        var decoded: Variant = JSON.parse_string(body.get_string_from_utf8())
        if decoded is Dictionary:
            parsed = decoded

    if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
        var message: String = str(parsed.get("message", "Sygnał jest chwilowo niedostępny. Postęp pozostał zapisany lokalnie."))
        request_failed.emit(operation, message)
        call_deferred("_pump")
        return

    match operation:
        "start_run":
            _run_id = str(parsed.get("run_id", ""))
            _run_token = str(parsed.get("run_token", ""))
            if _run_id.is_empty() or _run_token.is_empty():
                request_failed.emit(operation, "Serwer nie zwrócił poprawnego przebiegu.")
            else:
                _server_next_room_index = maxi(0, int(parsed.get("next_room_index", 0)))
                run_started.emit(_run_id, _run_token, _server_next_room_index)
        "record_room":
            _server_next_room_index = maxi(0, int(parsed.get("next_room_index", _server_next_room_index)))
            room_recorded.emit(str(active_copy.get("room_id", "")), _server_next_room_index)
        "complete_album":
            album_recorded.emit()
        "claim_reward":
            reward_claimed.emit(
                str(parsed.get("status", "pending_email")),
                str(parsed.get("message", "Sprawdź skrzynkę i potwierdź odbiór nagrody.")),
            )
        _:
            request_failed.emit(operation, "Nieznana odpowiedź Sygnału.")
    call_deferred("_pump")
