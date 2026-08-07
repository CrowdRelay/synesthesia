extends SceneTree

const AudioDirectorScript := preload("res://scripts/audio_director.gd")
const AssetPreloaderScript := preload("res://scripts/app/asset_preloader.gd")
const RewardClientScript := preload("res://scripts/reward_client.gd")
const SettingsCardScript := preload("res://scripts/ui/settings_card.gd")
const ConfirmCardScript := preload("res://scripts/ui/confirm_card.gd")
const ChapterCardScript := preload("res://scripts/ui/chapter_card.gd")
const ExperienceIntroCardScript := preload("res://scripts/ui/experience_intro_card.gd")
const AppHudScript := preload("res://scripts/ui/app_hud.gd")
const CompletionCardScript := preload("res://scripts/ui/completion_card.gd")
const SignalFinaleCardScript := preload("res://scripts/ui/signal_finale_card.gd")
const EchoesFinaleBackgroundScript := preload("res://scripts/ui/echoes_finale_background.gd")
const RoomVideoLayerScript := preload("res://scripts/render/room_video_layer.gd")
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
        call_deferred("_finish")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        _fail("manifest is invalid")
        call_deferred("_finish")
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
    audio.configure(manifest.get("sensory", {}), manifest.get("audio", {}), collectible_count, preloader, "uncertainty")
    await process_frame
    if not audio.reveal_release_excerpt():
        _fail("room music excerpt was not available after configure")
    audio.reset_release_excerpt()
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
    }, "Zbalansowana", "0.11.11")
    await process_frame
    await process_frame
    _require_label_width(settings, "Dopasuj intensywność", 220.0, "settings")
    await _dispose_node(settings)

    var confirmation = ConfirmCardScript.new()
    get_root().add_child(confirmation)
    confirmation.configure("Zagrać od nowa?", "Wyczyścimy lokalne malowanie, odkrycia i czasy wszystkich 11 pokojów. Ustawienia zostają.", "Tak, zacznij świeżą podróż")
    await process_frame
    await process_frame
    _require_label_width(confirmation, "Wyczyścimy lokalne", 220.0, "confirmation")
    await _dispose_node(confirmation)

    var chapter = ChapterCardScript.new()
    get_root().add_child(chapter)
    chapter.configure(0, 11, "Komora przypływu", "Prowadź kolor przez spokojne fale i odsłaniaj pokój spod śniegu. Nie ma czasu ani jednej poprawnej drogi.", "OBSERWATORIUM FALI", Color("64e8d9"))
    await process_frame
    await process_frame
    _require_label_width(chapter, "Prowadź kolor", 360.0, "chapter")
    await _dispose_node(chapter)

    var experience = ExperienceIntroCardScript.new()
    get_root().add_child(experience)
    experience.configure(Color("64e8d9"))
    await process_frame
    await process_frame
    _require_label_width(experience, "Synestezja to interaktywna", 320.0, "experience-intro")
    _require_button_width(experience, "WEJDŹ W SYNESTEZJĘ", 220.0, "experience-intro-button")
    await _dispose_node(experience)

    var hud = AppHudScript.new()
    get_root().add_child(hud)
    hud.configure_room("Wave of Uncertainty", "Komora przypływu", 0, 11, 0.0, {"accent_color": "#64E8D9", "paint_palette": ["#64E8D9"], "brush": {"profile": "water"}})
    hud.update_act(1, "ODDECH MIĘDZY FALAMI")
    hud.update_discovery("POP! Balon pękł · scena nabiera koloru")
    await process_frame
    await process_frame
    if hud.act_banner_label.size.x < 138.0:
        _fail("act-banner text collapsed horizontally")
    var top_rect: Rect2 = hud.top_panel.get_global_rect()
    var brush_rect: Rect2 = hud.bottom_panel.get_global_rect()
    if top_rect.intersects(brush_rect):
        _fail("persistent HUD cards overlap")
    if top_rect.position.x >= brush_rect.position.x:
        _fail("persistent HUD cards are not laid out left-to-right")
    if absf(top_rect.position.y - brush_rect.position.y) > 2.0:
        _fail("persistent HUD cards are not on the same header row")
    if hud.act_banner.get_global_rect().intersects(top_rect) or hud.act_banner.get_global_rect().intersects(brush_rect):
        _fail("act-banner overlaps shared header row")
    if hud.subtitle_label.size.y < 20.0 or hud.progress_label.size.y < 12.0 or hud.brush_label.size.y < 20.0:
        _fail("persistent HUD information collapsed vertically")
    hud.set_painting(true)
    await process_frame
    if not hud.subtitle_label.visible or not hud.palette_row.visible or not hud.brush_label.visible or not hud.instruction_label.visible:
        _fail("painting mode hid persistent HUD information")
    hud.set_painting(false)
    _require_label_alignment(hud, "AKT II", HORIZONTAL_ALIGNMENT_LEFT, "act-label")
    _require_label_width(hud, "POP! Balon", 340.0, "toast")
    await _dispose_node(hud)

    var completion = CompletionCardScript.new()
    get_root().add_child(completion)
    completion.configure("Pokój się otworzył", "Obraz oddycha, a muzyka została na pierwszym planie.", "Dalej · Party Time", Color("64e8d9"))
    await process_frame
    await process_frame
    _require_label_width(completion, "Obraz oddycha", 360.0, "completion")
    await _dispose_node(completion)

    var cinematic = RoomVideoLayerScript.new()
    get_root().add_child(cinematic)
    cinematic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cinematic.configure("uncertainty", false, false, true)
    if cinematic.has_stream_loaded():
        _fail("cinematic stream loaded before reveal")
    cinematic.set_cinematic(true, true)
    await process_frame
    if not cinematic.has_stream_loaded():
        _fail("cinematic stream did not lazy-load on reveal")
    cinematic.set_cinematic(false, true)
    if cinematic.has_stream_loaded():
        _fail("cinematic stream did not unload after reveal ended")
    await _dispose_node(cinematic)

    var finale_bg = EchoesFinaleBackgroundScript.new()
    get_root().add_child(finale_bg)
    finale_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    finale_bg.configure(false, false)
    await process_frame
    await _dispose_node(finale_bg)

    var finale = SignalFinaleCardScript.new()
    get_root().add_child(finale)
    finale.configure(true, {})
    await process_frame
    await process_frame
    _require_label_width(finale, "Jedenaście zakątków", 360.0, "finale")
    await _dispose_node(finale)

    var doorway = DoorTransitionLayerScript.new()
    get_root().add_child(doorway)
    doorway.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    doorway.visible = true
    doorway.set_accents(Color("64e8d9"), Color("ff5eaa"))
    doorway.set_door_mix(0.75)
    doorway.set_portal_mix(0.55)
    doorway.set_suck_mix(0.62)
    await process_frame
    doorway.reset()
    await _dispose_node(doorway)

    var reward = RewardClientScript.new()
    get_root().add_child(reward)
    reward.configure("", "", "0.11.11", "smoke")
    reward.shutdown()
    await _dispose_node(reward)

    await _dispose_node(audio)
    preloader.drain()
    await _dispose_node(preloader)
    # Give VideoStream/AudioStream backends and deferred frees enough frames to
    # release engine-side objects before SceneTree.quit(). This keeps the
    # lifecycle smoke meaningful instead of ending with shutdown leak noise.
    await process_frame
    await process_frame
    await process_frame
    # Defer quit until _run() has returned so its local Resource references are
    # released before Godot performs leak checks during engine shutdown.
    call_deferred("_finish")

func _require_button_width(node: Node, prefix: String, minimum: float, context: String) -> void:
    var button: Button = _find_button_with_prefix(node, prefix)
    if button == null:
        _fail("%s button missing: %s" % [context, prefix])
    elif button.size.x < minimum:
        _fail("%s button collapsed horizontally: %.1f < %.1f" % [context, button.size.x, minimum])

func _find_button_with_prefix(node: Node, prefix: String) -> Button:
    if node is Button:
        var button: Button = node as Button
        if button.text.begins_with(prefix):
            return button
    for child in node.get_children():
        var found: Button = _find_button_with_prefix(child, prefix)
        if found != null:
            return found
    return null

func _dispose_node(node: Node) -> void:
    if node == null or not is_instance_valid(node):
        return
    if node.has_method("shutdown"):
        node.call("shutdown")
    node.queue_free()
    await process_frame

func _require_label_alignment(node: Node, prefix: String, expected: int, context: String) -> void:
    var label: Label = _find_label_with_prefix(node, prefix)
    if label == null:
        _fail("%s label missing: %s" % [context, prefix])
    elif label.horizontal_alignment != expected:
        _fail("%s label alignment mismatch: %s" % [context, prefix])

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
        print("SYNESTHESIA_LIFECYCLE_SMOKE=PASS audio=music+pink+pop layout=chapter+act+toast+finale video=lazy+unloaded doors=instanced preloader=drained http=cancelled")
        quit(0)
