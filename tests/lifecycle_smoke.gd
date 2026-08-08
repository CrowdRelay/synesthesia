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
const NativeExperienceSurfaceScript := preload("res://scripts/app/native_experience_surface.gd")
const InteractiveUiRootScript := preload("res://scripts/app/interactive_ui_root.gd")
const TransitionDirectorScript := preload("res://scripts/app/transition_director.gd")
const BootSequenceScript := preload("res://scripts/ui/boot_sequence.gd")
const MANIFEST_PATH: String = "res://data/releases/wave-of-uncertainty/manifest.json"
const POP_PATH: String = "res://assets/audio/balloon-pop.mp3"

var _failed: bool = false
var _test_viewport: SubViewport
var _test_host: Control
var _viewport_mouse_entered: bool = false

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    # `godot --headless --script` creates a tiny 64x64 root Window. That is a
    # SceneTree-script harness detail, not a supported product viewport, and it
    # makes any meaningful text-width assertion impossible. Exercise desktop
    # layout at an explicit representative viewport instead of relying on the
    # headless default.
    await _set_test_viewport(Vector2i(1280, 720))

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
    pop_resource = null

    var settings = SettingsCardScript.new()
    _test_host.add_child(settings)
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
    }, "Zbalansowana", "0.12.9")
    await process_frame
    await process_frame
    _require_label_width(settings, "Dopasuj intensywność", 220.0, "settings")
    await _dispose_node(settings)

    var confirmation = ConfirmCardScript.new()
    _test_host.add_child(confirmation)
    confirmation.configure("Zagrać od nowa?", "Wyczyścimy lokalne malowanie, odkrycia i czasy wszystkich 11 pokojów. Ustawienia zostają.", "Tak, zacznij świeżą podróż")
    await process_frame
    await process_frame
    _require_label_width(confirmation, "Wyczyścimy lokalne", 220.0, "confirmation")
    await _dispose_node(confirmation)

    var chapter = ChapterCardScript.new()
    _test_host.add_child(chapter)
    chapter.configure(0, 11, "Komora przypływu", "Prowadź kolor przez spokojne fale i odsłaniaj pokój spod śniegu. Nie ma czasu ani jednej poprawnej drogi.", "OBSERWATORIUM FALI", Color("64e8d9"))
    await process_frame
    await process_frame
    _require_label_width(chapter, "Prowadź kolor", 360.0, "chapter")
    await _dispose_node(chapter)

    var experience = ExperienceIntroCardScript.new()
    _test_host.add_child(experience)
    experience.configure(Color("64e8d9"))
    await process_frame
    await process_frame
    _require_label_width(experience, "Interaktywny album", 260.0, "experience-menu")
    _require_button_width(experience, "WEJDŹ DO ŚRODKA", 220.0, "experience-menu-button")
    var begin_state := {"fired": false}
    experience.begin_requested.connect(func() -> void: begin_state["fired"] = true)
    await _click_button(experience, "WEJDŹ DO ŚRODKA", "experience-menu")
    if not bool(begin_state["fired"]):
        _fail("experience-menu real pointer click did not reach Button.pressed")
    await _dispose_node(experience)

    await _exercise_live_ui_stack()

    var hud = AppHudScript.new()
    _test_host.add_child(hud)
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
    hud.suspend_for_menu()
    await process_frame
    if hud.visible or hud.toast_panel.visible or hud.act_banner.visible:
        _fail("menu boundary left room HUD/toast visible")
    hud.resume_for_room()
    await process_frame
    if hud.toast_panel.visible or hud.act_banner.visible:
        _fail("room resume resurrected stale HUD/toast state")
    await _dispose_node(hud)

    var completion = CompletionCardScript.new()
    _test_host.add_child(completion)
    completion.configure("Pokój się otworzył", "Obraz oddycha, a muzyka została na pierwszym planie.", "Dalej · Party Time", Color("64e8d9"))
    await process_frame
    await process_frame
    _require_label_width(completion, "Obraz oddycha", 360.0, "completion")
    var stay_state := {"fired": false}
    var next_state := {"fired": false}
    completion.stay_requested.connect(func() -> void: stay_state["fired"] = true)
    completion.continue_requested.connect(func() -> void: next_state["fired"] = true)
    await _click_button(completion, "Zostań i słuchaj", "completion-listen")
    if not bool(stay_state["fired"]) or not completion.is_listen_mode():
        _fail("completion listen mode did not activate")
    _require_button_width(completion, "Dalej · Party Time", 220.0, "completion-listen-next")
    await _click_button(completion, "Dalej · Party Time", "completion-listen-next")
    if not bool(next_state["fired"]):
        _fail("completion listen mode lost its DALEJ action")
    await _dispose_node(completion)

    var cinematic = RoomVideoLayerScript.new()
    _test_host.add_child(cinematic)
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
    _test_host.add_child(finale_bg)
    finale_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    finale_bg.configure(false, false)
    await process_frame
    await _dispose_node(finale_bg)

    var finale = SignalFinaleCardScript.new()
    _test_host.add_child(finale)
    finale.configure(true, {})
    await process_frame
    await process_frame
    _require_label_width(finale, "Jedenaście zakątków", 360.0, "finale")
    await _dispose_node(finale)

    # Also exercise the compact portrait branch with a realistic small phone.
    # Portrait copy is allowed to be narrower than desktop, but it must remain
    # comfortably readable and must not collapse to the headless 64px geometry.
    await _set_test_viewport(Vector2i(390, 844))
    var portrait_chapter = ChapterCardScript.new()
    _test_host.add_child(portrait_chapter)
    portrait_chapter.configure(0, 11, "Komora przypływu", "Prowadź kolor przez spokojne fale i odsłaniaj pokój spod śniegu. Nie ma czasu ani jednej poprawnej drogi.", "OBSERWATORIUM FALI", Color("64e8d9"))
    await process_frame
    await process_frame
    _require_label_width(portrait_chapter, "Prowadź kolor", 220.0, "chapter-portrait")
    await _dispose_node(portrait_chapter)

    var portrait_finale = SignalFinaleCardScript.new()
    _test_host.add_child(portrait_finale)
    portrait_finale.configure(true, {})
    await process_frame
    await process_frame
    _require_label_width(portrait_finale, "Jedenaście zakątków", 220.0, "finale-portrait")
    await _dispose_node(portrait_finale)

    # Restore a landscape viewport for the remaining non-layout lifecycle checks.
    await _set_test_viewport(Vector2i(1280, 720))

    var doorway = DoorTransitionLayerScript.new()
    _test_host.add_child(doorway)
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
    reward.configure("", "", "0.12.9", "smoke")
    reward.shutdown()
    await _dispose_node(reward)

    await _dispose_node(audio)
    preloader.drain()
    await _dispose_node(preloader)
    if _test_viewport != null and is_instance_valid(_test_viewport):
        var viewport_parent := _test_viewport.get_parent()
        if viewport_parent != null:
            viewport_parent.remove_child(_test_viewport)
        _test_viewport.free()
        _test_viewport = null
        _test_host = null
    # Give VideoStream/AudioStream backends and deferred frees enough frames to
    # release engine-side objects before SceneTree.quit(). This keeps the
    # lifecycle smoke meaningful instead of ending with shutdown leak noise.
    await process_frame
    await process_frame
    await process_frame
    # Defer quit until _run() has returned so its local Resource references are
    # released before Godot performs leak checks during engine shutdown.
    call_deferred("_finish")


func _exercise_live_ui_stack() -> void:
    # Reproduce the real runtime hierarchy, not only an isolated card. The
    # adaptive render surface, transition overlays, boot sequence and menu all
    # coexist briefly at startup; this is where a transparent blocker used to
    # make the beautiful menu behave like a static image.
    var shell := Control.new()
    shell.name = "LiveUiShell"
    shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _test_host.add_child(shell)

    var surface = NativeExperienceSurfaceScript.new()
    shell.add_child(surface)

    var ui_root = InteractiveUiRootScript.new()
    shell.add_child(ui_root)

    var transition = TransitionDirectorScript.new()
    surface.add_child(transition)
    transition.install(surface)

    # Startup is deliberately sequential: the branded boot owns the screen,
    # then frees its video/input layer before the menu (and its own eye video)
    # is instantiated. This prevents duplicate Theora decoders and invisible
    # startup overlays from competing with menu input.
    var boot = BootSequenceScript.new()
    ui_root.attach(boot, 100)
    var released_state := {"value": false}
    boot.released.connect(func() -> void: released_state["value"] = true)
    await create_timer(1.55).timeout
    await process_frame
    await process_frame
    if not bool(released_state["value"]):
        _fail("live-ui boot did not emit released")
    if is_instance_valid(boot):
        _fail("live-ui boot overlay still alive after release window")

    var menu = ExperienceIntroCardScript.new()
    ui_root.attach(menu, 20)
    menu.configure(Color("64e8d9"))
    var fired := {"value": false}
    menu.begin_requested.connect(func() -> void: fired["value"] = true)
    await process_frame
    await process_frame
    if menu.get_mouse_filter_with_override() != Control.MOUSE_FILTER_STOP:
        _fail("live-ui menu root mouse filter overridden: %d" % menu.get_mouse_filter_with_override())

    await _click_button(menu, "WEJDŹ DO ŚRODKA", "live-ui-stack")
    if not bool(fired["value"]):
        _fail("live-ui-stack pointer click did not reach menu Button.pressed")

    transition.queue_free()
    await _dispose_node(shell)

func _set_test_viewport(size: Vector2i) -> void:
    # Do not rely on the headless root Window geometry here. In `--headless
    # --script` the root window can report a requested logical size while
    # Controls still inherit the tiny default viewport. A dedicated SubViewport
    # makes get_viewport_rect() deterministic for the UI under test.
    if _test_viewport == null:
        _test_viewport = SubViewport.new()
        _test_viewport.name = "LifecycleViewport"
        _test_viewport.disable_3d = true
        _test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        get_root().add_child(_test_viewport)

        _test_host = Control.new()
        _test_host.name = "LifecycleHost"
        _test_host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
        _test_viewport.add_child(_test_host)

    _test_viewport.size = size
    _test_host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    _test_host.position = Vector2.ZERO
    _test_host.size = Vector2(float(size.x), float(size.y))

    # Container minimum-size propagation is deferred. Give the SubViewport and
    # nested Containers two frames before creating/asserting the next UI.
    await process_frame
    await process_frame

func _click_button(node: Node, prefix: String, context: String) -> void:
    var button: Button = _find_button_with_prefix(node, prefix)
    if button == null:
        _fail("%s click target missing: %s" % [context, prefix])
        return
    if _test_viewport == null:
        _fail("%s click target has no SubViewport" % context)
        return

    # Exercise Godot's actual GUI hit-testing path instead of emitting the
    # signal directly. This catches a full-screen ancestor accidentally using
    # MOUSE_FILTER_STOP, which blocks child _gui_input() in Godot 4.7.
    var center: Vector2 = button.get_global_rect().get_center()
    if not _viewport_mouse_entered:
        _test_viewport.notify_mouse_entered()
        _viewport_mouse_entered = true

    var motion := InputEventMouseMotion.new()
    motion.position = center
    motion.global_position = center
    _test_viewport.push_input(motion, true)
    await process_frame
    var hovered: Control = _test_viewport.gui_get_hovered_control()
    if hovered == null:
        _fail("%s pointer hover resolved to null at %s" % [context, str(center)])
    elif hovered != button and not button.is_ancestor_of(hovered):
        _fail("%s pointer hover stolen by %s instead of %s" % [context, str(hovered.get_path()), str(button.get_path())])

    var press := InputEventMouseButton.new()
    press.button_index = MOUSE_BUTTON_LEFT
    press.button_mask = MOUSE_BUTTON_MASK_LEFT
    press.position = center
    press.global_position = center
    press.pressed = true
    _test_viewport.push_input(press, true)
    await process_frame

    var release := InputEventMouseButton.new()
    release.button_index = MOUSE_BUTTON_LEFT
    release.button_mask = 0
    release.position = center
    release.global_position = center
    release.pressed = false
    _test_viewport.push_input(release, true)
    await process_frame

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
    # Smoke tests should tear objects down synchronously. queue_free() is ideal
    # in gameplay, but at process shutdown it can leave ObjectDB entries alive
    # until the final frame and trigger Godot's leak diagnostics.
    var parent := node.get_parent()
    if parent != null:
        parent.remove_child(node)
    node.free()
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
        var viewport := label.get_viewport_rect().size
        var root_window := get_root().size
        var parent_width := 0.0
        var custom_min := label.custom_minimum_size.x
        if label.get_parent() is Control:
            parent_width = (label.get_parent() as Control).size.x
        _fail("%s text collapsed horizontally: %.1f < %.1f viewport=%.0fx%.0f root=%.0fx%.0f parent=%.1f custom_min=%.1f" % [context, label.size.x, minimum, viewport.x, viewport.y, root_window.x, root_window.y, parent_width, custom_min])

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
        print("SYNESTHESIA_LIFECYCLE_SMOKE=PASS audio=music+pink+pop layout=chapter+act+toast+finale input=real-pointer-click video=lazy+unloaded doors=instanced preloader=drained http=cancelled")
        quit(0)
