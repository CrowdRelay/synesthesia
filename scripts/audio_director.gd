extends Node
const PINK_NOISE_PATH: String = "res://assets/audio/pink-noise-asmr-loop.ogg"
const BALLOON_POP_PATH: String = "res://assets/audio/balloon-pop.mp3"
const CONFIRM_SFX_PATH: String = "res://assets/audio/sfx/light-rise.wav"
const SILENCE_DB: float = -60.0
const COMPLETION_THRESHOLD: float = 0.99
const CONTROL_INTERVAL: float = 1.0 / 60.0
const MIN_FILTER_HZ: float = 820.0
const MAX_FILTER_HZ: float = 19500.0
const INTERACTION_SFX: Dictionary = {
    "toast": "res://assets/audio/sfx/resonance-lock.wav",
    "seed": "res://assets/audio/sfx/wood-creak.wav",
    "duel": "res://assets/audio/sfx/gunshot.wav",
    "mirror": "res://assets/audio/sfx/mirror-shatter.wav",
    "phoenix": "res://assets/audio/sfx/wing-whoosh.wav",
    "screen": "res://assets/audio/sfx/electric-bzz.wav",
    "mask": "res://assets/audio/sfx/mask-whisper.wav",
    "wave": "res://assets/audio/sfx/wave-slap.wav",
    "light": "res://assets/audio/sfx/light-rise.wav",
    "presence": "res://assets/audio/sfx/presence-wind.wav",
    "pour": "res://assets/audio/sfx/resonance-lock.wav",
    "root": "res://assets/audio/sfx/wood-creak.wav",
    "aim": "res://assets/audio/sfx/presence-wind.wav",
    "ember": "res://assets/audio/sfx/wing-whoosh.wav",
    "cable_grab": "res://assets/audio/sfx/cable-snap.wav",
    "cable_snap": "res://assets/audio/sfx/cable-snap.wav",
    "cable_unplug": "res://assets/audio/sfx/cable-unplug.wav",
    "breaker": "res://assets/audio/sfx/breaker-off.wav",
    "signal_lock": "res://assets/audio/sfx/signal-lock.wav",
    "echo_complete": "res://assets/audio/sfx/signal-lock.wav",
}
const INTERACTION_BLOOM: Dictionary = {
    "balloon": 0.42,
    "mask": 0.34,
    "toast": 0.48,
    "pour": 0.28,
    "seed": 0.30,
    "root": 0.36,
    "aim": 0.20,
    "duel": 0.54,
    "screen": 0.38,
    "mirror": 0.50,
    "ember": 0.32,
    "phoenix": 0.62,
    "presence": 0.24,
    "wave": 0.26,
    "light": 0.46,
    "cable_grab": 0.08,
    "cable_snap": 0.10,
    "cable_unplug": 0.42,
    "breaker": 0.58,
    "signal_lock": 0.72,
    "echo_complete": 0.78,
}
const AudioAssetRuntimeScript := preload("res://scripts/audio/audio_asset_runtime.gd")
const CINEMATIC_SFX: Dictionary = {
    "uncertainty": "res://assets/audio/sfx/wave-slap.wav",
    "party": "res://assets/audio/sfx/light-rise.wav",
    "unmasked": "res://assets/audio/sfx/mask-whisper.wav",
    "calling": "res://assets/audio/sfx/resonance-lock.wav",
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
var _interaction_bloom_target: float = 0.0
var _interaction_bloom_smoothed: float = 0.0
var _foreground_duck_target: float = 0.0
var _foreground_duck_smoothed: float = 0.0
var _transition_duck_target: float = 0.0
var _semantic_clearance: float = 0.0
var _motion_target: float = 0.0; var _motion_smoothed: float = 0.0; var _motion_profile: String = ""
var _suspended: bool = false
var _control_accumulator: float = 0.0
var _pending_excerpt_path: String = ""
var _pending_ambience_path: String = ""
var _pending_asset_source
var _asset_runtime: Node
func _ready() -> void:
    _asset_runtime = AudioAssetRuntimeScript.new(); _asset_runtime.bind(self); add_child(_asset_runtime)
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
    return _asset_runtime._load_audio_stream(path)
func _stream_for_sfx(path: String) -> AudioStream:
    return _asset_runtime._stream_for_sfx(path)
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
    _interaction_bloom_target = maxf(_interaction_bloom_target, float(INTERACTION_BLOOM.get(kind, 0.22)))
    var semantic_steps := {
        "cable_unplug": 0.075, "breaker": 0.10, "signal_lock": 0.16,
        "mask": 0.065, "mirror": 0.09, "seed": 0.055, "root": 0.07,
        "balloon": 0.045, "pour": 0.05, "toast": 0.09, "ember": 0.045,
        "phoenix": 0.13, "presence": 0.055, "wave": 0.055, "duel": 0.10,
        "light": 0.11, "screen": 0.04, "echo_complete": 0.12,
    }
    _semantic_clearance = clampf(_semantic_clearance + float(semantic_steps.get(kind, 0.0)), 0.0, 0.58)
    _foreground_duck_target = maxf(_foreground_duck_target, 0.72)
    if kind == "balloon":
        _play_sfx_stream(_balloon_pop_stream, 0.96 + float(index % 5) * 0.018, -9.0)
        return
    var path: String = str(INTERACTION_SFX.get(kind, ""))
    var volume: float = -12.0 if kind in ["duel", "mirror"] else -15.0
    _play_sfx_stream(_stream_for_sfx(path), 0.98 + float(index % 3) * 0.015, volume)
func set_interaction_motion(kind: String, strength: float) -> void:
    _motion_profile = kind; _motion_target = maxf(_motion_target, clampf(strength, 0.0, 1.0))
func play_confirmation_tick(strength: float = 0.6) -> void:
    var amount: float = clampf(strength, 0.2, 1.0)
    _foreground_duck_target = maxf(_foreground_duck_target, 0.44 + amount * 0.22)
    _play_sfx_stream(_stream_for_sfx(CONFIRM_SFX_PATH), 0.96 + amount * 0.045, -27.0 + amount * 4.0)
func begin_transition_out() -> void:
    _transition_duck_target = 1.0
func begin_transition_in() -> void:
    _transition_duck_target = 0.72
func end_transition_in() -> void:
    _transition_duck_target = 0.0
func play_cinematic_sfx() -> void:
    var path: String = str(CINEMATIC_SFX.get(_visual_style, ""))
    _play_sfx_stream(_stream_for_sfx(path), 1.0, -16.0)
func _load_noise_loop() -> void:
    _asset_runtime._load_noise_loop()
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
    _interaction_bloom_target = 0.0
    _interaction_bloom_smoothed = 0.0
    _completion_active = false
    _semantic_clearance = 0.0
    _motion_target = 0.0; _motion_smoothed = 0.0; _motion_profile = ""
    _music_available = false
    _pending_excerpt_path = ""
    _pending_ambience_path = ""
    _pending_asset_source = asset_source
    _load_room_ambience(audio, asset_source)
    var excerpt_path: String = str(audio.get("completion_excerpt", ""))
    if excerpt_path.is_empty() or not excerpt_path.begins_with("res://") or not ResourceLoader.exists(excerpt_path):
        push_warning("Room music resource is missing: %s" % excerpt_path)
        return
    var resource: Resource = null
    if asset_source != null and asset_source.has_method("is_queued") and asset_source.is_queued(excerpt_path):
        if asset_source.has_method("take_if_ready"):
            resource = asset_source.take_if_ready(excerpt_path)
        if resource == null:
            # The excerpt is intentionally deferred. Do not turn a non-critical
            # threaded audio decode into a room-transition main-thread join.
            _pending_excerpt_path = excerpt_path
            _pending_asset_source = asset_source
            _apply_filter(0.0)
            return
    elif asset_source != null and asset_source.has_method("take"):
        resource = asset_source.take(excerpt_path)
    if resource == null:
        resource = load(excerpt_path)
    _attach_music_stream(resource, excerpt_path)
    _apply_filter(0.0)
func _load_room_ambience(audio: Dictionary, asset_source = null) -> void:
    _asset_runtime._load_room_ambience(audio, asset_source)
func _attach_ambience_stream(resource: Resource, path: String) -> bool:
    return _asset_runtime._attach_ambience_stream(resource, path)
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
func _attach_music_stream(resource: Resource, excerpt_path: String) -> bool:
    return _asset_runtime._attach_music_stream(resource, excerpt_path)
func _resolve_pending_ambience() -> void:
    _asset_runtime._resolve_pending_ambience()
func _resolve_pending_excerpt() -> void:
    _asset_runtime._resolve_pending_excerpt()
func _release_pending_asset_source_if_idle() -> void:
    _asset_runtime._release_pending_asset_source_if_idle()
func set_suspended(value: bool) -> void:
    if _suspended == value:
        return
    _suspended = value
    set_process(not value)
    for player in [_noise_player, _music_player, _ambient_player]:
        if player != null and player.stream != null:
            player.stream_paused = value
    for player in _sfx_players:
        if player != null and player.stream != null:
            player.stream_paused = value
    _control_accumulator = 0.0
    if not value:
        # Apply targets on the next control tick instead of burning CPU behind menus.
        _last_filter_hz = -1.0
        _last_reverb_wet = -1.0
func reveal_release_excerpt() -> bool:
    _completion_active = true
    _coverage_target = 1.0
    # Completion can happen between 60 Hz audio-control ticks. If the deferred
    # worker already finished, attach it here without ever joining an in-flight
    # ResourceLoader request on the main thread.
    if not _music_available and not _pending_excerpt_path.is_empty():
        _resolve_pending_excerpt()
    if not _music_available:
        return false
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
    _control_accumulator += minf(delta, 0.10)
    if _control_accumulator < CONTROL_INTERVAL:
        return
    var control_delta: float = minf(_control_accumulator, 0.05)
    _control_accumulator = 0.0
    _resolve_pending_ambience()
    _resolve_pending_excerpt()
    _coverage_smoothed = move_toward(_coverage_smoothed, _coverage_target, control_delta * 0.72)
    _collectibles_smoothed = move_toward(_collectibles_smoothed, _collectibles_target, control_delta * 0.90)
    _quiet_smoothed = move_toward(_quiet_smoothed, _quiet_target, control_delta * 1.80)
    _interaction_bloom_target = move_toward(_interaction_bloom_target, 0.0, control_delta * 0.58)
    _interaction_bloom_smoothed = move_toward(_interaction_bloom_smoothed, _interaction_bloom_target, control_delta * 5.8)
    _motion_target = move_toward(_motion_target, 0.0, control_delta * 1.8); _motion_smoothed = move_toward(_motion_smoothed, _motion_target, control_delta * 7.0)
    _foreground_duck_target = move_toward(_foreground_duck_target, 0.0, control_delta * 2.8)
    _foreground_duck_smoothed = move_toward(_foreground_duck_smoothed, _foreground_duck_target, control_delta * 10.0)
    var reveal_mix: float = clampf(_coverage_smoothed, 0.0, 1.0)
    if _completion_active or _coverage_target >= COMPLETION_THRESHOLD:
        reveal_mix = 1.0
    var motion_reveal := _motion_smoothed * (0.045 if _motion_profile in ["breath", "heartbeat"] else 0.075)
    var music_ratio: float = clampf(reveal_mix + _semantic_clearance * (1.0 - reveal_mix) * 0.62 + motion_reveal, 0.0, 1.0)
    var noise_ratio: float = clampf((1.0 - reveal_mix) * (1.0 - _semantic_clearance * 0.82) * (1.0 - _motion_smoothed * 0.10), 0.0, 1.0)
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
        _noise_player.volume_db = move_toward(_noise_player.volume_db, noise_target_db, control_delta * 20.0)
    if _music_player != null and _music_available:
        if not _music_player.playing:
            _music_player.play()
        var music_target_db: float = SILENCE_DB
        if music_ratio > 0.0001:
            music_target_db = _completion_music_db + linear_to_db(music_ratio) + _music_user_gain_db + _interaction_bloom_smoothed * 2.4
        music_target_db -= quiet_cut_db + _foreground_duck_smoothed * 1.8 + _transition_duck_target * 4.5
        _music_player.volume_db = move_toward(_music_player.volume_db, music_target_db, control_delta * 17.0)
    if _ambient_player != null and _ambient_player.stream != null:
        if not _ambient_player.playing:
            _ambient_player.play()
        var ambient_target_db: float = (-31.0 if _calm_mode else -27.0) + reveal_mix * 2.5 + _interaction_bloom_smoothed * 1.2 - quiet_cut_db - _foreground_duck_smoothed * 4.0 - _transition_duck_target * 7.0
        _ambient_player.volume_db = move_toward(_ambient_player.volume_db, ambient_target_db, control_delta * 9.0)
    _apply_filter(reveal_mix)
func _apply_filter(reveal_mix: float) -> void:
    var clamped_mix: float = clampf(reveal_mix, 0.0, 1.0)
    if _music_lowpass != null:
        var reactive_mix: float = clampf(clamped_mix + _interaction_bloom_smoothed * 0.10 + _motion_smoothed * 0.045, 0.0, 1.0)
        var filter_curve: float = pow(reactive_mix, 0.72)
        var target_hz: float = lerpf(_lowpass_start_hz, MAX_FILTER_HZ, filter_curve)
        if _last_filter_hz < 0.0 or absf(target_hz - _last_filter_hz) >= 18.0:
            _last_filter_hz = target_hz
            _music_lowpass.cutoff_hz = target_hz
    if _music_reverb != null:
        var target_wet: float = lerpf(0.22, 0.035, clampf(clamped_mix + _interaction_bloom_smoothed * 0.06, 0.0, 1.0))
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
