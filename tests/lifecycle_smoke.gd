extends SceneTree

const AudioDirectorScript := preload("res://scripts/audio_director.gd")
const AssetPreloaderScript := preload("res://scripts/app/asset_preloader.gd")
const RewardClientScript := preload("res://scripts/reward_client.gd")
const SettingsCardScript := preload("res://scripts/ui/settings_card.gd")
const ConfirmCardScript := preload("res://scripts/ui/confirm_card.gd")
const ChapterCardScript := preload("res://scripts/ui/chapter_card.gd")
const AppHudScript := preload("res://scripts/ui/app_hud.gd")
const CompletionCardScript := preload("res://scripts/ui/completion_card.gd")
const SignalFinaleCardScript := preload("res://scripts/ui/signal_finale_card.gd")
const EchoesFinaleBackgroundScript := preload("res://scripts/ui/echoes_finale_background.gd")
const DoorTransitionLayerScript := preload("res://scripts/app/door_transition_layer.gd")
const MANIFEST_PATH: String = "res://data/releases/wave-of-uncertainty/manifest.json"
const POP_PATH: String = "res://assets/audio/balloon-pop.mp3"

var _failed: bool = false

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
    if file == null:
        _fail("cannot open manifest")
        _finish()
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        _fail("manifest is invalid")
        _finish()
        return
    var manifest: Dictionary = parsed

    var preloader = AssetPreloaderScript.new()
    get_root().add_child(preloader)
    preloader.prepare(MANIFEST_PATH)
    await process_frame

    var audio = AudioDirectorScript.new()
    get_root().add_child(audio)
    var collectibles_value: Variant = manifest.get("collectibles", [])
    var collectible_count: int = 1
    if collectibles_value is Array:
        collectible_count = maxi(1, collectibles_value.size())
    audio.configure(manifest.get("sensory", {}), manifest.get("audio", {}), collectible_count, preloader)
    await process_frame
    audio.set_progress(0.20, 1)
    await process_frame
    audio.play_interaction_sfx("balloon", 2)
    var pop_resource: Resource = load(POP_PATH)
    if not pop_resource is AudioStream:
        _fail("balloon pop did not load as AudioStream")

    var settings = SettingsCardScript.new()
    get_root().add_child(settings)
    settings.configure({
        "calm": true,
        "quiet": false,
        "quiet_visuals": false,
        "reduced_motion": false,
        "haptics": true,
        "music": 1.0,
        "noise": 1.0,
        "has_room": true,
        "album_completed": true,
    }, "Zbalansowana", "0.11.4")
    await process_frame
    await process_frame
    _require_label_width(settings, "Dopasuj intensywność", 220.0, "settings")
    settings.free()

    var confirmation = ConfirmCardScript.new()
    get_root().add_child(confirmation)
    confirmation.configure("Zagrać od nowa?", "Wyczyścimy lokalne malowanie, odkrycia i czasy wszystkich 11 pokojów. Ustawienia zostają.", "Tak, zacznij świeżą podróż")
    await process_frame
    await process_frame
    _require_label_width(confirmation, "Wyczyścimy lokalne", 220.0, "confirmation")
    confirmation.free()

    var chapter = ChapterCardScript.new()
    get_root().add_child(chapter)
    chapter.configure(0, 11, "Komora przypływu", "Prowadź kolor przez spokojne fale i odsłaniaj pokój spod śniegu. Nie ma czasu ani jednej poprawnej drogi.", "OBSERWATORIUM FALI", Color("64e8d9"))
    await process_frame
    await process_frame
    _require_label_width(chapter, "Prowadź kolor", 360.0, "chapter")
    chapter.free()

    var hud = AppHudScript.new()
    get_root().add_child(hud)
    hud.configure_room("Wave of Uncertainty", "Komora przypływu", 0, 11, 0.0, {"accent_color": "#64E8D9", "paint_palette": ["#64E8D9"], "brush": {"profile": "water"}})
    hud.update_act(1, "ODDECH MIĘDZY FALAMI")
    hud.update_discovery("POP! Balon pękł · scena nabiera koloru")
    await process_frame
    await process_frame
    _require_label_width(hud, "AKT II", 340.0, "act-banner")
    _require_label_width(hud, "POP! Balon", 340.0, "toast")
    hud.free()

    var completion = CompletionCardScript.new()
    get_root().add_child(completion)
    completion.configure("Pokój się otworzył", "Obraz oddycha, a muzyka została na pierwszym planie.", "Dalej · Party Time", Color("64e8d9"))
    await process_frame
    await process_frame
    _require_label_width(completion, "Obraz oddycha", 360.0, "completion")
    completion.free()

    var finale_bg = EchoesFinaleBackgroundScript.new()
    get_root().add_child(finale_bg)
    finale_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    finale_bg.configure(false, false)
    await process_frame
    finale_bg.free()

    var finale = SignalFinaleCardScript.new()
    get_root().add_child(finale)
    finale.configure(true, {})
    await process_frame
    await process_frame
    _require_label_width(finale, "Jedenaście zakątków", 360.0, "finale")
    finale.free()

    var doorway = DoorTransitionLayerScript.new()
    get_root().add_child(doorway)
    doorway.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    doorway.visible = true
    doorway.set_accents(Color("64e8d9"), Color("ff5eaa"))
    doorway.set_door_mix(0.75)
    doorway.set_portal_mix(0.55)
    await process_frame
    doorway.reset()
    doorway.free()

    var reward = RewardClientScript.new()
    get_root().add_child(reward)
    reward.configure("", "", "0.11.4", "smoke")
    reward.shutdown()
    reward.free()

    audio.free()
    preloader.drain()
    preloader.free()
    await process_frame
    _finish()

func _require_label_width(node: Node, prefix: String, minimum: float, context: String) -> void:
    var label: Label = _find_label_with_prefix(node, prefix)
    if label == null:
        _fail("%s label missing: %s" % [context, prefix])
    elif label.size.x < minimum:
        _fail("%s text collapsed horizontally: %.1f < %.1f" % [context, label.size.x, minimum])

func _find_label_with_prefix(node: Node, prefix: String) -> Label:
    if node is Label:
        var label: Label = node as Label
        if label.text.begins_with(prefix):
            return label
    for child in node.get_children():
        var found: Label = _find_label_with_prefix(child, prefix)
        if found != null:
            return found
    return null

func _fail(message: String) -> void:
    _failed = true
    push_error("Lifecycle smoke: %s" % message)

func _finish() -> void:
    if _failed:
        print("SYNESTHESIA_LIFECYCLE_SMOKE=FAIL")
        quit(1)
    else:
        print("SYNESTHESIA_LIFECYCLE_SMOKE=PASS audio=music+pink+pop layout=chapter+act+toast+finale doors=instanced preloader=drained http=cancelled")
        quit(0)
