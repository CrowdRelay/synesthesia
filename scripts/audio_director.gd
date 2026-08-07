extends Node

const PINK_NOISE_PATH: String = "res://assets/audio/pink-noise-asmr-loop.ogg"
const BALLOON_POP_PATH: String = "res://assets/audio/balloon-pop.mp3"
const SILENCE_DB: float = -60.0
const COMPLETION_THRESHOLD: float = 0.99
const MIN_FILTER_HZ: float = 820.0
const MAX_FILTER_HZ: float = 19500.0
const AMBIENCE_PATHS: Dictionary = {
    "uncertainty": "res://assets/audio/ambience/uncertainty.wav",
    "party": "res://assets/audio/ambience/party.wav",
    "unmasked": "res://assets/audio/ambience/unmasked.wav",
    "calling": "res://assets/audio/ambience/calling.wav",
    "seed": "res://assets/audio/ambience/seed.wav",
    "hybrid": "res://assets/audio/ambience/hybrid.wav",
    "technophobia": "res://assets/audio/ambience/technophobia.wav",
    "invaluable": "res://assets/audio/ambience/invaluable.wav",
    "ashes": "res://assets/audio/ambience/ashes.wav",
    "waves": "res://assets/audio/ambience/waves.wav",
    "rise": "res://assets/audio/ambience/rise.wav",
}
const INTERACTION_SFX: Dictionary = {
    "toast": "res://assets/audio/sfx/glass-clink.wav",
    "seed": "res://assets/audio/sfx/wood-creak.wav",
    "duel": "res://assets/audio/sfx/gunshot.wav",
    "mirror": "res://assets/audio/sfx/mirror-shatter.wav",
    "phoenix": "res://assets/audio/sfx/wing-whoosh.wav",
    "screen": "res://assets/audio/sfx/electric-bzz.wav",
    "mask": "res://assets/audio/sfx/mask-whisper.wav",
    "wave": "res://assets/audio/sfx/wave-slap.wav",
    "light": "res://assets/audio/sfx/light-rise.wav",
    "presence": "res://assets/audio/sfx/presence-wind.wav",
}
const CINEMATIC_SFX: Dictionary = {
    "uncertainty": "res://assets/audio/sfx/wave-slap.wav",
    "party": "res://assets/audio/sfx/light-rise.wav",
    "unmasked": "res://assets/audio/sfx/mask-whisper.wav",
    "calling": "res://assets/audio/sfx/glass-clink.wav",
    "seed": "res://assets/audio/sfx/wood-creak.wav",
    "hybrid": "res://assets/audio/sfx/presence-wind.wav",
    "technophobia": "res://assets/audio/sfx/electric-bzz.wav",
    "invaluable": "res://assets/audio/sfx/mirror-shatter.wav",
    "ashes": "res://assets/audio/sfx/wing-whoosh.wav",
    "waves": "res://assets/audio/sfx/presence-wind.wav",
    "rise": "res://assets/audio/sfx/light-rise.wav",
}

var _noise_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _music_lowpass: AudioEffectLowPassFilter
var _music_reverb: AudioEffectReverb
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_streams: Dictionary = {}
var _balloon_pop_stream: AudioStream
var _sfx_cursor: int = 0
var _visual_style: String = "uncertainty"
var _coverage_target: float = 0.0
var _coverage_smoothed: float = 0.0
var _collectibles_target: float = 0.0
var _collectibles_smoothed: float = 0.0
var _quiet_target: float = 0.0
var _quiet_smoothed: float = 0.0
var _calm_mode: bool = true
var _collectible_total: int = 1
var _pink_noise_start_db: float = -5.0
var _hidden_music_db: float = -44.0
var _completion_music_db: float = -8.0
var _music_available: bool = false
var _completion_active: bool = false
var _release_title: String = "VIRYA"
var _music_user_gain_db: float = 0.0
var _noise_user_gain_db: float = 0.0
var _lowpass_start_hz: float = 950.0
var _last_filter_hz: float = -1.0
var _last_reverb_wet: float = -1.0

func _ready() -> void:
    _noise_player = AudioStreamPlayer.new()
    _noise_player.name = "PinkNoiseASMR"
    _noise_player.bus = &"Sensory"
    _noise_player.volume_db = SILENCE_DB
    add_child(_noise_player)
    _load_noise_loop()

    _music_player = AudioStreamPlayer.new()
    _music_player.name = "RoomMusicReveal"
    _music_player.bus = &"Music"
    _music_player.volume_db = SILENCE_DB
    add_child(_music_player)

    _ambient_player = AudioStreamPlayer.new()
    _ambient_player.name = "ThematicRoomAmbience"
    _ambient_player.bus = &"Room"
    _ambient_player.volume_db = SILENCE_DB
    add_child(_ambient_player)

    _resolve_bus_effects()
    _build_sfx_pool()
    set_process(true)

func _build_sfx_pool() -> void:
    _balloon_pop_stream = _load_audio_stream(BALLOON_POP_PATH)
    for index in range(4):
        var player: AudioStreamPlayer = AudioStreamPlayer.new()
        player.name = "RoomSfx%d" % index
        player.bus = &"Room"
        player.volume_db = -10.0
        add_child(player)
        _sfx_players.append(player)

func _load_audio_stream(path: String) -> AudioStream:
    if path.is_empty() or not ResourceLoader.exists(path):
        return null
    var resource: Resource = load(path)
    return resource as AudioStream if resource is AudioStream else null

func _stream_for_sfx(path: String) -> AudioStream:
    if path.is_empty():
        return null
    if _sfx_streams.has(path):
        return _sfx_streams[path] as AudioStream
    var stream: AudioStream = _load_audio_stream(path)
    if stream != null:
        _sfx_streams[path] = stream
    return stream

func _play_sfx_stream(stream: AudioStream, pitch: float = 1.0, volume_db: float = -10.0) -> void:
    if stream == null or _sfx_players.is_empty():
        return
    var player: AudioStreamPlayer = _sfx_players[_sfx_cursor % _sfx_players.size()]
    _sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
    player.stop()
    player.stream = stream
    player.pitch_scale = clampf(pitch, 0.88, 1.12)
    player.volume_db = volume_db - (12.0 if _quiet_target > 0.5 else 0.0)
    player.play()

func play_interaction_sfx(kind: String, index: int = 0) -> void:
    if kind == "balloon":
        _play_sfx_stream(_balloon_pop_stream, 0.96 + float(index % 5) * 0.018, -9.0)
        return
    var path: String = str(INTERACTION_SFX.get(kind, ""))
    var volume: float = -12.0 if kind in ["duel", "mirror"] else -15.0
    _play_sfx_stream(_stream_for_sfx(path), 0.98 + float(index % 3) * 0.015, volume)

func play_cinematic_sfx() -> void:
    var path: String = str(CINEMATIC_SFX.get(_visual_style, ""))
    _play_sfx_stream(_stream_for_sfx(path), 1.0, -16.0)

func _load_noise_loop() -> void:
    if not ResourceLoader.exists(PINK_NOISE_PATH):
        push_warning("Pink-noise resource is missing: %s" % PINK_NOISE_PATH)
        return
    var resource: Resource = load(PINK_NOISE_PATH)
    if not resource is AudioStream:
        push_warning("Pink-noise loop is not an AudioStream")
        return
    if resource is AudioStreamOggVorbis:
        var ogg_stream: AudioStreamOggVorbis = resource as AudioStreamOggVorbis
        ogg_stream.loop = true
        ogg_stream.loop_offset = 0.0
    _noise_player.stream = resource as AudioStream
    _noise_player.play()

func _resolve_bus_effects() -> void:
    var bus_index: int = AudioServer.get_bus_index(&"Music")
    if bus_index < 0:
        return
    var lowpass: AudioEffect = AudioServer.get_bus_effect(bus_index, 0)
    if lowpass is AudioEffectLowPassFilter:
        _music_lowpass = lowpass as AudioEffectLowPassFilter
    var reverb: AudioEffect = AudioServer.get_bus_effect(bus_index, 1)
    if reverb is AudioEffectReverb:
        _music_reverb = reverb as AudioEffectReverb

func configure(sensory: Dictionary, audio: Dictionary = {}, collectible_total: int = 1, asset_source = null, visual_style: String = "uncertainty") -> void:
    _collectible_total = maxi(1, collectible_total)
    _visual_style = visual_style
    _pink_noise_start_db = clampf(float(audio.get("pink_noise_start_db", -5.0)), -18.0, -3.0)
    _hidden_music_db = clampf(float(audio.get("hidden_music_db", -44.0)), -60.0, -24.0)
    _completion_music_db = clampf(float(audio.get("completion_volume_db", -8.0)), -18.0, -6.0)
    _lowpass_start_hz = clampf(float(audio.get("lowpass_start_hz", 950.0)), 600.0, 2500.0)
    _release_title = str(audio.get("title", "VIRYA"))
    _calm_mode = str(sensory.get("default_mode", "calm")) == "calm"
    _coverage_target = 0.0
    _coverage_smoothed = 0.0
    _collectibles_target = 0.0
    _collectibles_smoothed = 0.0
    _completion_active = false
    _music_available = false
    _load_room_ambience()

    var excerpt_path: String = str(audio.get("completion_excerpt", ""))
    if excerpt_path.is_empty() or not excerpt_path.begins_with("res://") or not ResourceLoader.exists(excerpt_path):
        push_warning("Room music resource is missing: %s" % excerpt_path)
        return
    var resource: Resource = null
    if asset_source != null and asset_source.has_method("take"):
        resource = asset_source.take(excerpt_path)
    if resource == null:
        resource = load(excerpt_path)
    if not resource is AudioStream:
        push_warning("Room music excerpt is not an AudioStream: %s" % excerpt_path)
        return
    if resource is AudioStreamMP3:
        var mp3_stream: AudioStreamMP3 = resource as AudioStreamMP3
        mp3_stream.loop = true
        mp3_stream.loop_offset = 0.0
    elif resource is AudioStreamOggVorbis:
        var ogg_stream: AudioStreamOggVorbis = resource as AudioStreamOggVorbis
        ogg_stream.loop = true
        ogg_stream.loop_offset = 0.0
    _music_player.stream = resource as AudioStream
    _music_player.volume_db = SILENCE_DB
    _music_player.play()
    _music_available = true
    _apply_filter(0.0)

func _load_room_ambience() -> void:
    if _ambient_player == null:
        return
    _ambient_player.stop()
    _ambient_player.stream = null
    var path: String = str(AMBIENCE_PATHS.get(_visual_style, ""))
    var stream: AudioStream = _load_audio_stream(path)
    if stream == null:
        push_warning("Room ambience resource is missing: %s" % path)
        return
    _ambient_player.stream = stream
    _ambient_player.volume_db = SILENCE_DB
    _ambient_player.play()

func set_progress(coverage: float, found_count: int) -> void:
    _coverage_target = clampf(coverage, 0.0, 1.0)
    _collectibles_target = clampf(float(found_count) / float(_collectible_total), 0.0, 1.0)
    if _coverage_target >= COMPLETION_THRESHOLD:
        _completion_active = true

func set_quiet(value: bool) -> void:
    _quiet_target = 1.0 if value else 0.0

func set_calm_mode(value: bool) -> void:
    _calm_mode = value

func set_user_levels(music_linear: float, noise_linear: float) -> void:
    _music_user_gain_db = linear_to_db(clampf(music_linear, 0.001, 1.0)) if music_linear > 0.0 else SILENCE_DB
    _noise_user_gain_db = linear_to_db(clampf(noise_linear, 0.0, 1.0)) if noise_linear > 0.0 else SILENCE_DB

func reveal_release_excerpt() -> bool:
    if not _music_available:
        return false
    _completion_active = true
    _coverage_target = 1.0
    if not _music_player.playing:
        _music_player.play()
    return true

func reset_release_excerpt() -> void:
    _completion_active = false
    _coverage_target = 0.0
    _coverage_smoothed = 0.0
    if _music_player != null and _music_available:
        _music_player.stop()
        _music_player.volume_db = SILENCE_DB
        _music_player.play()
    _apply_filter(0.0)

func get_release_title() -> String:
    return _release_title

func _process(delta: float) -> void:
    _coverage_smoothed = move_toward(_coverage_smoothed, _coverage_target, delta * 0.72)
    _collectibles_smoothed = move_toward(_collectibles_smoothed, _collectibles_target, delta * 0.90)
    _quiet_smoothed = move_toward(_quiet_smoothed, _quiet_target, delta * 1.80)

    var reveal_mix: float = clampf(_coverage_smoothed, 0.0, 1.0)
    if _completion_active or _coverage_target >= COMPLETION_THRESHOLD:
        reveal_mix = 1.0
    var music_ratio: float = reveal_mix
    var noise_ratio: float = 1.0 - reveal_mix
    var quiet_cut_db: float = lerpf(0.0, 18.0, _quiet_smoothed)

    if _noise_player != null:
        if not _noise_player.playing and _noise_player.stream != null:
            _noise_player.play()
        var calm_cut_db: float = 5.0 if _calm_mode else 0.0
        var start_db: float = _pink_noise_start_db - calm_cut_db + _noise_user_gain_db
        var noise_target_db: float = SILENCE_DB
        if noise_ratio > 0.0001:
            noise_target_db = start_db + linear_to_db(noise_ratio)
        noise_target_db -= quiet_cut_db
        _noise_player.volume_db = move_toward(_noise_player.volume_db, noise_target_db, delta * 20.0)

    if _music_player != null and _music_available:
        if not _music_player.playing:
            _music_player.play()
        var music_target_db: float = SILENCE_DB
        if music_ratio > 0.0001:
            music_target_db = _completion_music_db + linear_to_db(music_ratio) + _music_user_gain_db
        music_target_db -= quiet_cut_db
        _music_player.volume_db = move_toward(_music_player.volume_db, music_target_db, delta * 17.0)

    if _ambient_player != null and _ambient_player.stream != null:
        if not _ambient_player.playing:
            _ambient_player.play()
        var ambient_target_db: float = (-31.0 if _calm_mode else -27.0) + reveal_mix * 2.5 - quiet_cut_db
        _ambient_player.volume_db = move_toward(_ambient_player.volume_db, ambient_target_db, delta * 9.0)

    _apply_filter(reveal_mix)

func _apply_filter(reveal_mix: float) -> void:
    var clamped_mix: float = clampf(reveal_mix, 0.0, 1.0)
    if _music_lowpass != null:
        var filter_curve: float = pow(clamped_mix, 0.72)
        var target_hz: float = lerpf(_lowpass_start_hz, MAX_FILTER_HZ, filter_curve)
        if _last_filter_hz < 0.0 or absf(target_hz - _last_filter_hz) >= 18.0:
            _last_filter_hz = target_hz
            _music_lowpass.cutoff_hz = target_hz
    if _music_reverb != null:
        var target_wet: float = lerpf(0.22, 0.035, clamped_mix)
        if _last_reverb_wet < 0.0 or absf(target_wet - _last_reverb_wet) >= 0.002:
            _last_reverb_wet = target_wet
            _music_reverb.wet = target_wet
            _music_reverb.room_size = lerpf(0.62, 0.34, clamped_mix)

func _exit_tree() -> void:
    set_process(false)
    if _noise_player != null:
        _noise_player.stop()
        _noise_player.stream = null
    if _music_player != null:
        _music_player.stop()
        _music_player.stream = null
    if _ambient_player != null:
        _ambient_player.stop()
        _ambient_player.stream = null
    for player in _sfx_players:
        if player != null:
            player.stop()
            player.stream = null
    _sfx_players.clear()
    _sfx_streams.clear()
    _balloon_pop_stream = null
    _music_lowpass = null
    _music_reverb = null
