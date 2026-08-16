extends Node

signal run_started(run_id: String, run_token: String, next_room_index: int)
signal room_recorded(room_id: String, next_room_index: int)
signal album_recorded(context: Dictionary)
signal draw_entered(status: String, message: String)
signal leaderboard_loaded(items: Array)
signal leaderboard_published(context: Dictionary)
signal request_failed(operation: String, message: String)
signal retry_scheduled(operation: String, attempt: int)
signal run_invalidated()

const MAX_QUEUE_SIZE: int = 32
const MAX_RETRY_ATTEMPTS: int = 3
const RETRY_BASE_SECONDS: float = 1.2
const MAX_RESPONSE_BYTES: int = 1_048_576

var _api_url: String = ""
var _campaign_slug: String = ""
var _app_version: String = ""
var _install_id: String = ""
var _attempt_id: String = ""
var _run_id: String = ""
var _run_token: String = ""
var _server_next_room_index: int = 0
var _http: HTTPRequest
var _queue: Array[Dictionary] = []
var _active: Dictionary = {}
var _busy: bool = false
var _retry_timer: Timer
var _retry_request: Dictionary = {}

func _ready() -> void:
    _http = HTTPRequest.new()
    _http.name = "SynesthesiaRewardHttp"
    _http.timeout = 15.0
    _http.body_size_limit = MAX_RESPONSE_BYTES
    _http.request_completed.connect(_on_request_completed)
    add_child(_http)

    _retry_timer = Timer.new()
    _retry_timer.name = "SynesthesiaRewardRetry"
    _retry_timer.one_shot = true
    _retry_timer.timeout.connect(_on_retry_timeout)
    add_child(_retry_timer)

func configure(api_url: String, campaign_slug: String, app_version: String, install_id: String, attempt_id: String = "legacy") -> void:
    _api_url = api_url.trim_suffix("/")
    _campaign_slug = campaign_slug
    _app_version = app_version
    _install_id = install_id
    _attempt_id = attempt_id if not attempt_id.is_empty() else "legacy"

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
        "attempt_id": _attempt_id,
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
        "idempotency_key": "synesthesia-start-%s-%s" % [_install_id, _attempt_id],
        "payload": {
            "campaign_slug": _campaign_slug,
            "install_id": _install_id,
            "app_version": _app_version,
            "attempt_id": _attempt_id,
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

func recover_album(completed_room_ids: Array) -> void:
    if not has_run():
        request_failed.emit("recover_album", "Brak aktywnego przebiegu Sygnału.")
        return
    _enqueue({
        "operation": "recover_album",
        "method": "POST",
        "path": "/v1/public/synesthesia/runs/%s/recover" % _run_id,
        "authorized": true,
        "idempotency_key": "synesthesia-recover-%s" % _run_id,
        "payload": {
            "completed_room_ids": completed_room_ids.duplicate(),
        },
    })

func refresh_completion_context(_total_elapsed_ms: int = 0) -> void:
    if not has_run():
        request_failed.emit("completion_context_refresh", "Brak aktywnego przebiegu Sygnału.")
        return
    # Read-only by contract. Status refresh must never rotate the short-lived
    # handoff that My Signal may be consuming in another tab/app.
    _enqueue({
        "operation": "completion_context_refresh",
        "method": "GET",
        "path": "/v1/public/synesthesia/runs/%s/context" % _run_id,
        "authorized": true,
        "idempotency_key": "",
        "payload": {},
    })

func request_handoff() -> void:
    if not has_run():
        request_failed.emit("handoff_issue", "Brak aktywnego przebiegu Sygnału.")
        return
    var nonce: String = "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
    _enqueue({
        "operation": "handoff_issue",
        "method": "POST",
        "path": "/v1/public/synesthesia/runs/%s/handoff" % _run_id,
        "authorized": true,
        "idempotency_key": "synesthesia-handoff-%s-%s" % [_run_id, nonce],
        "payload": {},
    })

func fetch_leaderboard(limit: int = 10) -> void:
    if _api_url.is_empty():
        request_failed.emit("leaderboard_load", "Top lista jest chwilowo niedostępna.")
        return
    _enqueue({
        "operation": "leaderboard_load",
        "method": "GET",
        "path": "/v1/public/synesthesia/leaderboard?limit=%d" % clampi(limit, 1, 50),
        "authorized": false,
        "idempotency_key": "leaderboard-load-%d" % clampi(limit, 1, 50),
        "payload": {},
    })

func publish_leaderboard() -> void:
    if not has_run():
        request_failed.emit("leaderboard_publish", "Najpierw kończę synchronizację przebiegu.")
        return
    _enqueue({
        "operation": "leaderboard_publish",
        "method": "POST",
        "path": "/v1/public/synesthesia/runs/%s/leaderboard" % _run_id,
        "authorized": true,
        "idempotency_key": "leaderboard-publish-%s" % _run_id,
        "payload": {},
    })

func enter_draw(email: String, policy_version: String) -> void:
    if not has_run():
        request_failed.emit("enter_draw", "Nie udało się połączyć ukończenia z losowaniem.")
        return
    _enqueue({
        "operation": "enter_draw",
        "path": "/v1/public/synesthesia/reward-claims",
        "authorized": true,
        "idempotency_key": "synesthesia-claim-%s" % _run_id,
        "payload": {
            "email": email.strip_edges(),
            "policy_version": policy_version,
            "locale": TranslationServer.get_locale(),
        },
    })

func _enqueue(request_data: Dictionary) -> void:
    var candidate: Dictionary = request_data.duplicate(true)
    candidate["attempt"] = maxi(0, int(candidate.get("attempt", 0)))
    var idempotency_key: String = str(candidate.get("idempotency_key", ""))
    if not idempotency_key.is_empty() and _contains_idempotency_key(idempotency_key):
        return
    if _queue.size() >= MAX_QUEUE_SIZE:
        request_failed.emit(str(candidate.get("operation", "request")), "Kolejka Sygnału jest pełna. Postęp pozostał zapisany lokalnie.")
        return
    _queue.append(candidate)
    _pump()

func _contains_idempotency_key(idempotency_key: String) -> bool:
    if str(_active.get("idempotency_key", "")) == idempotency_key:
        return true
    if str(_retry_request.get("idempotency_key", "")) == idempotency_key:
        return true
    for request_data in _queue:
        if str(request_data.get("idempotency_key", "")) == idempotency_key:
            return true
    return false

func _pump() -> void:
    if _busy or _queue.is_empty():
        return
    _active = _queue.pop_front()
    _busy = true
    var method_name: String = str(_active.get("method", "POST")).to_upper()
    var headers: PackedStringArray = PackedStringArray(["Accept: application/json"])
    if method_name != "GET":
        headers.append("Content-Type: application/json")
        var idempotency_key: String = str(_active.get("idempotency_key", ""))
        if not idempotency_key.is_empty():
            headers.append("Idempotency-Key: %s" % idempotency_key)
    if bool(_active.get("authorized", false)):
        headers.append("Authorization: Bearer %s" % _run_token)
    var body: String = "" if method_name == "GET" else JSON.stringify(_active.get("payload", {}))
    var url: String = "%s%s" % [_api_url, str(_active.get("path", ""))]
    var method: int = HTTPClient.METHOD_GET if method_name == "GET" else HTTPClient.METHOD_POST
    var error: Error = _http.request(url, headers, method, body)
    if error != OK:
        var active_copy: Dictionary = _active.duplicate(true)
        _busy = false
        _active = {}
        _handle_failure(active_copy, 0, "Nie udało się rozpocząć połączenia z Sygnałem.")

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
        if operation == "enter_draw" and response_code == 409:
            message = "Losowanie nie jest teraz otwarte. Ukończenie zostało zapisane — wróć w czasie trwania akcji."
        _handle_failure(active_copy, response_code, message)
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
        "complete_album", "recover_album", "completion_context_refresh", "handoff_issue":
            album_recorded.emit(parsed.duplicate(true))
        "enter_draw":
            draw_entered.emit(
                str(parsed.get("status", "entered_draw")),
                str(parsed.get("message", "Jesteś w losowaniu jednej z 5 płyt.")),
            )
        "leaderboard_load":
            var items_value: Variant = parsed.get("items", [])
            leaderboard_loaded.emit(items_value.duplicate(true) if items_value is Array else [])
        "leaderboard_publish":
            leaderboard_published.emit(parsed.duplicate(true))
        _:
            request_failed.emit(operation, "Nieznana odpowiedź Sygnału.")
    call_deferred("_pump")

func _handle_failure(request_data: Dictionary, response_code: int, message: String) -> void:
    if bool(request_data.get("authorized", false)) and (response_code == 401 or response_code == 404):
        _run_id = ""
        _run_token = ""
        _server_next_room_index = 0
        _queue.clear()
        _retry_request = {}
        run_invalidated.emit()
        call_deferred("start_run")
        return
    var attempt: int = maxi(0, int(request_data.get("attempt", 0)))
    if _is_transient_failure(response_code) and attempt < MAX_RETRY_ATTEMPTS:
        attempt += 1
        request_data["attempt"] = attempt
        _retry_request = request_data.duplicate(true)
        _busy = true
        var delay_seconds: float = RETRY_BASE_SECONDS * pow(2.0, float(attempt - 1))
        _retry_timer.start(delay_seconds)
        retry_scheduled.emit(str(request_data.get("operation", "request")), attempt)
        return
    request_failed.emit(str(request_data.get("operation", "request")), message)
    call_deferred("_pump")

func _is_transient_failure(response_code: int) -> bool:
    return response_code == 0 or response_code == 408 or response_code == 425 or response_code == 429 or response_code >= 500

func _on_retry_timeout() -> void:
    var request_data: Dictionary = _retry_request.duplicate(true)
    _retry_request = {}
    _busy = false
    if not request_data.is_empty():
        _queue.push_front(request_data)
    _pump()

func shutdown() -> void:
    _queue.clear()
    _active = {}
    _retry_request = {}
    _busy = false
    if _retry_timer != null and is_instance_valid(_retry_timer):
        _retry_timer.stop()
    if _http != null and is_instance_valid(_http):
        _http.cancel_request()

func _exit_tree() -> void:
    shutdown()
