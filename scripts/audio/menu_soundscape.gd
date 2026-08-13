extends Node

const PINK_NOISE_PATH := "res://assets/audio/pink-noise-asmr-loop.ogg"
const TRACKS: Array[String] = [
    "res://assets/audio/wave-of-uncertainty-room-outro.mp3",
    "res://assets/audio/party-time-room-outro.mp3",
    "res://assets/audio/unmasked-room-outro.mp3",
    "res://assets/audio/the-calling-room-outro.mp3",
    "res://assets/audio/seed-of-doubt-room-outro.mp3",
    "res://assets/audio/hybrid-room-outro.mp3",
    "res://assets/audio/technophobia-room-outro.mp3",
    "res://assets/audio/invaluable-room-outro.mp3",
    "res://assets/audio/from-the-ashes-room-outro.mp3",
    "res://assets/audio/waves-room-outro.mp3",
    "res://assets/audio/rise-room-outro.mp3",
]

const SILENCE_DB := -60.0
const MENU_MUSIC_DB := -23.0
const MENU_NOISE_DB := -31.0
const OUTRO_MUSIC_DB := -17.0
const OUTRO_NOISE_DB := -35.0
const FADE_DB_PER_SECOND := 22.0

var _rng := RandomNumberGenerator.new()
var _music_player: AudioStreamPlayer
var _noise_player: AudioStreamPlayer
var _mode := "off"
var _menu_has_music := false
var _menu_roll_made := false
var _menu_track_index := -1
var _current_track_index := -1
var _music_level := 1.0
var _noise_level := 1.0
var _quiet := false
var _music_target_db := SILENCE_DB
var _noise_target_db := SILENCE_DB
var _pending_noise: bool = false
var _pending_track_index: int = -1
var _deferred_track_index: int = -1

func _ready() -> void:
    _rng.randomize()

    _music_player = AudioStreamPlayer.new()
    _music_player.name = "MenuViryaExcerpt"
    _music_player.bus = &"Room"
    _music_player.volume_db = SILENCE_DB
    add_child(_music_player)

    _noise_player = AudioStreamPlayer.new()
    _noise_player.name = "MenuPinkNoise"
    _noise_player.bus = &"Sensory"
    _noise_player.volume_db = SILENCE_DB
    add_child(_noise_player)
    # No decoder/resource work in _ready(): the first branded/menu frame wins.
    # enter_menu()/enter_outro() only issue threaded requests and attachment is
    # polled later from _process().
    set_process(false)

func set_user_levels(music_linear: float, noise_linear: float, quiet: bool) -> void:
    _music_level = clampf(music_linear, 0.0, 1.0)
    _noise_level = clampf(noise_linear, 0.0, 1.0)
    _quiet = quiet
    _refresh_targets()

func enter_menu() -> void:
    _mode = "menu"
    if not _menu_roll_made:
        _menu_roll_made = true
        _menu_has_music = _rng.randf() < 0.5
        if _menu_has_music:
            _menu_track_index = _start_random_track(-1)
    elif _menu_has_music and _menu_track_index >= 0 and _current_track_index != _menu_track_index:
        _start_track(_menu_track_index)
    _request_noise()
    _ensure_noise_playing()
    _refresh_targets()
    set_process(true)

func enter_outro() -> void:
    _mode = "outro"
    _start_random_track(_current_track_index)
    _request_noise()
    _ensure_noise_playing()
    _refresh_targets()
    set_process(true)

func leave_soundscape() -> void:
    _mode = "off"
    _deferred_track_index = -1
    _music_target_db = SILENCE_DB
    _noise_target_db = SILENCE_DB
    # Keep processing until pending threaded loads are drained and any audible
    # streams have faded out. No synchronous cleanup join on a transition.
    set_process(true)

func is_menu_music_active() -> bool:
    return _mode == "menu" and _menu_has_music and not _quiet

func _request_noise() -> void:
    if _noise_player.stream != null or _pending_noise or not ResourceLoader.exists(PINK_NOISE_PATH):
        return
    var error: Error = ResourceLoader.load_threaded_request(PINK_NOISE_PATH, "", false, ResourceLoader.CACHE_MODE_REUSE)
    if error == OK:
        _pending_noise = true

func _ensure_noise_playing() -> void:
    if _noise_player.stream != null and not _noise_player.playing and _mode != "off":
        _noise_player.play()

func _start_random_track(exclude_index: int) -> int:
    if TRACKS.is_empty():
        return -1
    var candidates: Array[int] = []
    for index in range(TRACKS.size()):
        if TRACKS.size() > 1 and index == exclude_index:
            continue
        if ResourceLoader.exists(TRACKS[index]):
            candidates.append(index)
    if candidates.is_empty():
        return -1
    var index: int = candidates[_rng.randi_range(0, candidates.size() - 1)]
    if not _start_track(index):
        return -1
    return index

func _start_track(index: int) -> bool:
    if index < 0 or index >= TRACKS.size() or not ResourceLoader.exists(TRACKS[index]):
        return false
    if _current_track_index == index and _music_player.stream != null:
        if _mode != "off" and not _music_player.playing:
            _play_attached_track(_music_player.stream as AudioStream, index)
        return true
    if _pending_track_index == index:
        return true
    # Keep only one outstanding music request. A mode change can happen while
    # the menu excerpt is still decoding on a slow phone; remember the newest
    # desired track rather than orphaning the original ResourceLoader request.
    if _pending_track_index >= 0:
        _deferred_track_index = index
        return true
    var error: Error = ResourceLoader.load_threaded_request(TRACKS[index], "", false, ResourceLoader.CACHE_MODE_REUSE)
    if error != OK:
        return false
    _pending_track_index = index
    return true

func _resolve_pending_audio() -> void:
    if _pending_noise:
        var noise_status: int = int(ResourceLoader.load_threaded_get_status(PINK_NOISE_PATH))
        if noise_status == ResourceLoader.THREAD_LOAD_LOADED:
            var noise_resource: Resource = ResourceLoader.load_threaded_get(PINK_NOISE_PATH)
            _pending_noise = false
            _attach_noise(noise_resource)
        elif noise_status == ResourceLoader.THREAD_LOAD_FAILED or noise_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            _pending_noise = false

    if _pending_track_index >= 0:
        var index: int = _pending_track_index
        var path: String = TRACKS[index]
        var track_status: int = int(ResourceLoader.load_threaded_get_status(path))
        if track_status == ResourceLoader.THREAD_LOAD_LOADED:
            var resource: Resource = ResourceLoader.load_threaded_get(path)
            _pending_track_index = -1
            var next_index: int = _deferred_track_index
            _deferred_track_index = -1
            if _mode != "off" and next_index < 0 and resource is AudioStream:
                _play_attached_track(resource as AudioStream, index)
            if _mode != "off" and next_index >= 0:
                _start_track(next_index)
        elif track_status == ResourceLoader.THREAD_LOAD_FAILED or track_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            _pending_track_index = -1
            var retry_index: int = _deferred_track_index
            _deferred_track_index = -1
            if _mode != "off" and retry_index >= 0:
                _start_track(retry_index)

func _attach_noise(resource: Resource) -> void:
    if not resource is AudioStream:
        return
    if resource is AudioStreamOggVorbis:
        var stream := resource as AudioStreamOggVorbis
        stream.loop = true
        stream.loop_offset = 0.0
    _noise_player.stream = resource as AudioStream
    _ensure_noise_playing()

func _play_attached_track(resource: AudioStream, index: int) -> void:
    if resource == null:
        return
    if resource is AudioStreamMP3:
        var stream := resource as AudioStreamMP3
        stream.loop = true
        stream.loop_offset = 0.0
    elif resource is AudioStreamOggVorbis:
        var ogg := resource as AudioStreamOggVorbis
        ogg.loop = true
        ogg.loop_offset = 0.0
    _current_track_index = index
    _music_player.stop()
    _music_player.stream = resource
    _music_player.volume_db = SILENCE_DB
    var from_position := 0.0
    var length := float(resource.get_length())
    if length > 28.0:
        from_position = _rng.randf_range(4.0, maxf(4.0, length - 18.0))
    _music_player.play(from_position)

func _refresh_targets() -> void:
    if _quiet or _mode == "off":
        _music_target_db = SILENCE_DB
        _noise_target_db = SILENCE_DB
        return
    var music_gain := linear_to_db(maxf(_music_level, 0.001)) if _music_level > 0.0 else SILENCE_DB
    var noise_gain := linear_to_db(maxf(_noise_level, 0.001)) if _noise_level > 0.0 else SILENCE_DB
    if _mode == "menu":
        _music_target_db = MENU_MUSIC_DB + music_gain if _menu_has_music and _music_level > 0.0 else SILENCE_DB
        _noise_target_db = MENU_NOISE_DB + noise_gain if _noise_level > 0.0 else SILENCE_DB
    elif _mode == "outro":
        _music_target_db = OUTRO_MUSIC_DB + music_gain if _music_level > 0.0 else SILENCE_DB
        _noise_target_db = OUTRO_NOISE_DB + noise_gain if _noise_level > 0.0 else SILENCE_DB

func _process(delta: float) -> void:
    _resolve_pending_audio()
    var step := FADE_DB_PER_SECOND * minf(delta, 0.1)
    if _music_player != null:
        _music_player.volume_db = move_toward(_music_player.volume_db, _music_target_db, step)
    if _noise_player != null:
        _noise_player.volume_db = move_toward(_noise_player.volume_db, _noise_target_db, step)

    if _mode == "off" and not _pending_noise and _pending_track_index < 0 and _music_player.volume_db <= SILENCE_DB + 0.2 and _noise_player.volume_db <= SILENCE_DB + 0.2:
        if _music_player.playing:
            _music_player.stop()
        if _noise_player.playing:
            _noise_player.stop()
        set_process(false)
