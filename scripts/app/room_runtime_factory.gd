extends RefCounted

const AUDIO_DIRECTOR_PATH := "res://scripts/audio_director.gd"
const HAPTICS_PATH := "res://scripts/haptics.gd"
const FEEDBACK_BRIDGE_PATH := "res://scripts/app/player_feedback_bridge.gd"
const CHAPTER_CARD_PATH := "res://scripts/ui/chapter_card.gd"
const COMPLETION_CARD_PATH := "res://scripts/ui/completion_card.gd"
const ROOM_STAGE_PATH := "res://scripts/render/room_stage.gd"

static var _scripts: Dictionary = {}

static func _script(path: String, asset_source = null) -> Script:
    if _scripts.has(path):
        return _scripts[path] as Script
    var resource: Resource = null
    if asset_source != null and asset_source.has_method("take"):
        resource = asset_source.take(path)
    if resource == null and ResourceLoader.exists(path):
        resource = load(path)
    if resource is Script:
        _scripts[path] = resource
        return resource as Script
    push_error("Synesthesia runtime script unavailable: %s" % path)
    return null

static func _new(path: String, asset_source = null):
    var script: Script = _script(path, asset_source)
    return script.new() if script != null else null

static func audio_director(asset_source = null): return _new(AUDIO_DIRECTOR_PATH, asset_source)
static func haptics(asset_source = null): return _new(HAPTICS_PATH, asset_source)
static func feedback_bridge(asset_source = null): return _new(FEEDBACK_BRIDGE_PATH, asset_source)
static func chapter_card(asset_source = null): return _new(CHAPTER_CARD_PATH, asset_source)
static func completion_card(asset_source = null): return _new(COMPLETION_CARD_PATH, asset_source)
static func room_stage(asset_source = null): return _new(ROOM_STAGE_PATH, asset_source)

static func release() -> void:
    _scripts.clear()
