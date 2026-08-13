extends Node

const EXPERIENCE_INTRO_CARD_PATH: String = "res://scripts/ui/experience_intro_card.gd"
const MAIN_ROOM_FLOW_PATH: String = "res://scripts/app/main_room_flow.gd"

var app: Node
var _experience_intro_card_script: Script
var _experience_intro_request_started: bool = false

func bind(owner: Node) -> void:
    app = owner

func prime_after_first_frame() -> void:
    # First engine frame wins. Heavy menu/room script graphs are parsed only
    # while the branded boot is already visible.
    await RenderingServer.frame_post_draw
    if not _experience_intro_request_started and ResourceLoader.exists(EXPERIENCE_INTRO_CARD_PATH):
        _experience_intro_request_started = ResourceLoader.load_threaded_request(
            EXPERIENCE_INTRO_CARD_PATH, "", false, ResourceLoader.CACHE_MODE_REUSE
        ) == OK
    if app.asset_preloader != null:
        app.asset_preloader.queue_critical(MAIN_ROOM_FLOW_PATH)

func experience_intro_script() -> Script:
    if _experience_intro_card_script != null:
        return _experience_intro_card_script
    if _experience_intro_request_started:
        var deadline_ms: int = Time.get_ticks_msec() + 420
        var status: int = int(ResourceLoader.load_threaded_get_status(EXPERIENCE_INTRO_CARD_PATH))
        while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and Time.get_ticks_msec() < deadline_ms:
            await get_tree().process_frame
            status = int(ResourceLoader.load_threaded_get_status(EXPERIENCE_INTRO_CARD_PATH))
        if status == ResourceLoader.THREAD_LOAD_LOADED:
            var threaded: Resource = ResourceLoader.load_threaded_get(EXPERIENCE_INTRO_CARD_PATH)
            if threaded is Script:
                _experience_intro_card_script = threaded as Script
                return _experience_intro_card_script
    if ResourceLoader.exists(EXPERIENCE_INTRO_CARD_PATH):
        var fallback: Resource = load(EXPERIENCE_INTRO_CARD_PATH)
        if fallback is Script:
            _experience_intro_card_script = fallback as Script
    return _experience_intro_card_script

func ensure_room_flow() -> bool:
    if app.room_flow != null and is_instance_valid(app.room_flow):
        return true
    var resource: Resource = app.asset_preloader.take(MAIN_ROOM_FLOW_PATH) if app.asset_preloader != null else null
    if resource == null and ResourceLoader.exists(MAIN_ROOM_FLOW_PATH):
        resource = load(MAIN_ROOM_FLOW_PATH)
    if not resource is Script:
        return false
    app.room_flow = (resource as Script).new()
    app.room_flow.bind(app)
    app.add_child(app.room_flow)
    return true
