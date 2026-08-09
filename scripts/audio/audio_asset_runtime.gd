extends Node

const SILENCE_DB: float = -60.0
const PINK_NOISE_PATH: String = "res://assets/audio/pink-noise-asmr-loop.ogg"
const AMBIENCE_PATHS: Dictionary = {
    "uncertainty": "res://assets/audio/ambience/uncertainty.ogg",
    "party": "res://assets/audio/ambience/party.ogg",
    "unmasked": "res://assets/audio/ambience/unmasked.ogg",
    "calling": "res://assets/audio/ambience/calling.ogg",
    "seed": "res://assets/audio/ambience/seed.ogg",
    "hybrid": "res://assets/audio/ambience/hybrid.ogg",
    "technophobia": "res://assets/audio/ambience/technophobia.ogg",
    "invaluable": "res://assets/audio/ambience/invaluable.ogg",
    "ashes": "res://assets/audio/ambience/ashes.ogg",
    "waves": "res://assets/audio/ambience/waves.ogg",
    "rise": "res://assets/audio/ambience/rise.ogg",
}

var app: Node
func bind(owner: Node) -> void:
    app = owner

func _load_audio_stream(path: String) -> AudioStream:
    if path.is_empty() or not ResourceLoader.exists(path):
        return null
    var resource: Resource = load(path)
    return resource as AudioStream if resource is AudioStream else null

func _stream_for_sfx(path: String) -> AudioStream:
    if path.is_empty():
        return null
    if app._sfx_streams.has(path):
        return app._sfx_streams[path] as AudioStream
    var stream: AudioStream = _load_audio_stream(path)
    if stream != null:
        app._sfx_streams[path] = stream
    return stream

func _load_room_ambience(audio: Dictionary, asset_source = null) -> void:
    if app._ambient_player == null:
        return
    app._ambient_player.stop()
    app._ambient_player.stream = null
    var path: String = str(audio.get("ambience", AMBIENCE_PATHS.get(app._visual_style, "")))
    if path.is_empty() or not ResourceLoader.exists(path):
        push_warning("Room ambience resource is missing: %s" % path)
        return
    var resource: Resource = null
    if asset_source != null and asset_source.has_method("is_queued") and asset_source.is_queued(path):
        if asset_source.has_method("take_if_ready"):
            resource = asset_source.take_if_ready(path)
        if resource == null:
            app._pending_ambience_path = path
            return
    elif asset_source != null and asset_source.has_method("take"):
        resource = asset_source.take(path)
    if resource == null:
        resource = load(path)
    _attach_ambience_stream(resource, path)

func _attach_ambience_stream(resource: Resource, path: String) -> bool:
    if not resource is AudioStream:
        push_warning("Room ambience resource is not an AudioStream: %s" % path)
        return false
    if resource is AudioStreamOggVorbis:
        var ogg_stream: AudioStreamOggVorbis = resource as AudioStreamOggVorbis
        ogg_stream.loop = true
        ogg_stream.loop_offset = 0.0
    elif resource is AudioStreamMP3:
        var mp3_stream: AudioStreamMP3 = resource as AudioStreamMP3
        mp3_stream.loop = true
        mp3_stream.loop_offset = 0.0
    app._ambient_player.stream = resource as AudioStream
    # Deterministic sub-percent variation keeps short ambience beds from feeling
    # mechanically identical without introducing runtime randomness or new assets.
    app._ambient_player.pitch_scale = 0.994 + float(abs(app._visual_style.hash()) % 13) * 0.001
    app._ambient_player.volume_db = SILENCE_DB
    app._ambient_player.play()
    return true

func _attach_music_stream(resource: Resource, excerpt_path: String) -> bool:
    if not resource is AudioStream:
        push_warning("Room music excerpt is not an AudioStream: %s" % excerpt_path)
        return false
    if resource is AudioStreamMP3:
        var mp3_stream: AudioStreamMP3 = resource as AudioStreamMP3
        mp3_stream.loop = true
        mp3_stream.loop_offset = 0.0
    elif resource is AudioStreamOggVorbis:
        var ogg_stream: AudioStreamOggVorbis = resource as AudioStreamOggVorbis
        ogg_stream.loop = true
        ogg_stream.loop_offset = 0.0
    app._music_player.stream = resource as AudioStream
    app._music_player.volume_db = SILENCE_DB
    app._music_player.play()
    app._music_available = true
    return true

func _resolve_pending_ambience() -> void:
    if app._pending_ambience_path.is_empty() or app._pending_asset_source == null:
        return
    if not is_instance_valid(app._pending_asset_source):
        app._pending_ambience_path = ""
        app._pending_excerpt_path = ""
        app._pending_asset_source = null
        return
    if not app._pending_asset_source.has_method("take_if_ready"):
        app._pending_ambience_path = ""
        return
    var resource: Resource = app._pending_asset_source.take_if_ready(app._pending_ambience_path)
    if resource == null:
        if app._pending_asset_source.has_method("is_queued") and app._pending_asset_source.is_queued(app._pending_ambience_path):
            return
        push_warning("Deferred room ambience failed to preload: %s" % app._pending_ambience_path)
        app._pending_ambience_path = ""
        _release_pending_asset_source_if_idle()
        return
    var path: String = str(app._pending_ambience_path)
    app._pending_ambience_path = ""
    _attach_ambience_stream(resource, path)
    _release_pending_asset_source_if_idle()

func _resolve_pending_excerpt() -> void:
    if app._pending_excerpt_path.is_empty() or app._pending_asset_source == null:
        return
    if not is_instance_valid(app._pending_asset_source):
        app._pending_excerpt_path = ""
        app._pending_ambience_path = ""
        app._pending_asset_source = null
        return
    var path: String = app._pending_excerpt_path
    var resource: Resource = null
    if app._pending_asset_source.has_method("take_if_ready"):
        resource = app._pending_asset_source.take_if_ready(path)
    if resource == null:
        if app._pending_asset_source.has_method("is_queued") and app._pending_asset_source.is_queued(path):
            return
        # A failed threaded request should not stall gameplay with an immediate
        # synchronous retry. Leave music unavailable; the sensory bed still works.
        push_warning("Deferred room music failed to preload: %s" % path)
        app._pending_excerpt_path = ""
        _release_pending_asset_source_if_idle()
        return
    app._pending_excerpt_path = ""
    _attach_music_stream(resource, path)
    _release_pending_asset_source_if_idle()

func _release_pending_asset_source_if_idle() -> void:
    if app._pending_excerpt_path.is_empty() and app._pending_ambience_path.is_empty():
        app._pending_asset_source = null

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
    app._noise_player.stream = resource as AudioStream
    app._noise_player.play()
