extends Control

## Shared Synesthesia visual mark used by splash, menu, chapter rails and finale.
## The material layer is a reusable comic bitmap; blink, neural pulses and glitch
## stay procedural so the same eye remains alive in every viewport.

const DOOR_EYE_TEXTURE_PATH: String = "res://assets/branding/signal-glyph.webp"
const MENU_EYE_VIDEO_PATH: String = "res://assets/branding/signal-glyph-loop.ogv"
const MENU_EYE_POSTER_PATH: String = "res://assets/branding/menu-eye-poster.webp"
const MENU_EYE_VIDEO_SIZE: Vector2 = Vector2(848.0, 1104.0)

var _door_eye_texture: Texture2D
var _menu_eye_poster_texture: Texture2D
var _video_player: VideoStreamPlayer
var _last_video_position: float = 0.0
var _authored_video_armed: bool = false

var _accent: Color = Color("8c62ff")
var _secondary: Color = Color("ef6fbd")
var _profile: String = "menu"
var _phase: float = 0.0
var _blink: float = 0.0
var _blink_closing: bool = false
var _blink_active: bool = false
var _next_blink_at: float = 1.8
var _glitch: float = 0.0
var _open_mix: float = 0.0
var _reduced_motion: bool = false
var _pointer: Vector2 = Vector2(0.5, 0.5)
var _redraw_accumulator: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _door_eye_texture = _load_door_eye_texture()
    _menu_eye_poster_texture = _load_menu_eye_poster_texture()
    _build_video_player()
    visibility_changed.connect(_on_visibility_changed)
    _sync_processing()
    _sync_video_mode()
    queue_redraw()


func _build_video_player() -> void:
    _video_player = VideoStreamPlayer.new()
    _video_player.name = "MenuEyeAnimation"
    _video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _video_player.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
    _video_player.expand = true
    _video_player.loop = true
    _video_player.autoplay = false
    _video_player.buffering_msec = 180
    _video_player.volume_db = -80.0
    _video_player.visible = false
    # The authored eye video draws behind this Control's procedural neural/glitch
    # pass, but remains in the same canvas layer. This avoids the old negative-Z
    # path that could disappear behind menu panels on first presentation.
    _video_player.z_index = 0
    _video_player.show_behind_parent = true
    add_child(_video_player)

func _on_visibility_changed() -> void:
    _sync_processing()
    _sync_video_mode()
    if is_visible_in_tree() and _wants_authored_video() and _authored_video_armed:
        call_deferred("restart_authored_animation")

func arm_authored_animation(restart: bool = true) -> void:
    # Menu playback can start as soon as the menu exists. Splash playback is
    # deliberately armed only *after* the first rendered Godot frame so the
    # first-frame latency budget stays cheap while the user still sees the exact
    # authored menu-eye animation during the branded loading sequence.
    _authored_video_armed = true
    _sync_video_mode()
    _sync_video_geometry()
    if restart:
        call_deferred("restart_authored_animation")

func restart_authored_animation() -> void:
    if not is_inside_tree() or not is_visible_in_tree() or not _wants_authored_video() or not _authored_video_armed:
        return
    _sync_video_mode()
    _sync_video_geometry()
    if _video_player == null or _video_player.stream == null:
        return
    _video_player.stop()
    _video_player.play()
    _last_video_position = 0.0

func suspend_authored_animation(clear_stream: bool = false) -> void:
    # Used by the splash handoff: freeze on the exact authored poster while the
    # menu starts its own loop underneath, avoiding two active video decoders.
    _authored_video_armed = false
    if _video_player != null:
        _video_player.stop()
        _video_player.visible = false
        if clear_stream:
            _video_player.stream = null
    _last_video_position = 0.0
    queue_redraw()

func _wants_authored_video() -> bool:
    return (_profile == "menu" or _profile == "splash") and not _reduced_motion

func _video_is_active() -> bool:
    return _video_player != null and _video_player.visible and _video_player.stream != null and _video_player.is_playing()

func _sync_video_mode() -> void:
    if _video_player == null:
        return
    var should_play: bool = is_visible_in_tree() and _wants_authored_video() and _authored_video_armed and FileAccess.file_exists(MENU_EYE_VIDEO_PATH)
    if not should_play:
        _video_player.stop()
        _video_player.visible = false
        if _profile == "panel" or _reduced_motion:
            _video_player.stream = null
        _last_video_position = 0.0
        return
    if _video_player.stream == null:
        var theora := VideoStreamTheora.new()
        theora.file = MENU_EYE_VIDEO_PATH
        _video_player.stream = theora
    _video_player.visible = true
    _sync_video_geometry()
    if not _video_player.is_playing():
        _video_player.play()
        _last_video_position = 0.0

func _sync_video_geometry() -> void:
    if _video_player == null or size.x <= 2.0 or size.y <= 2.0:
        return
    var art: Rect2 = _fit_texture_rect(MENU_EYE_VIDEO_SIZE)
    _video_player.position = art.position
    _video_player.size = art.size

func _load_door_eye_texture() -> Texture2D:
    if not ResourceLoader.exists(DOOR_EYE_TEXTURE_PATH):
        push_error("Door-eye texture is not imported: %s" % DOOR_EYE_TEXTURE_PATH)
        return null
    var resource: Resource = load(DOOR_EYE_TEXTURE_PATH)
    if resource is Texture2D:
        return resource as Texture2D
    push_error("Door-eye resource is not Texture2D: %s" % DOOR_EYE_TEXTURE_PATH)
    return null

func _load_menu_eye_poster_texture() -> Texture2D:
    if not ResourceLoader.exists(MENU_EYE_POSTER_PATH):
        return null
    var resource: Resource = load(MENU_EYE_POSTER_PATH)
    if resource is Texture2D:
        return resource as Texture2D
    push_error("Menu-eye poster resource is not Texture2D: %s" % MENU_EYE_POSTER_PATH)
    return null

func configure(accent: Color, profile: String = "menu", secondary: Color = Color("ef6fbd")) -> void:
    _accent = accent
    _secondary = secondary
    _profile = profile
    # The normal menu can lazily start its authored loop when configured. The
    # splash is armed by BootSequence after the first actual frame is presented.
    _authored_video_armed = profile == "menu"
    _schedule_next_blink()
    _sync_video_mode()
    _sync_video_geometry()
    queue_redraw()

func set_reduced_motion(value: bool) -> void:
    _reduced_motion = value
    if value:
        _blink = 0.0
        _blink_closing = false
        _blink_active = false
        _glitch = 0.0
    _sync_processing()
    _sync_video_mode()
    queue_redraw()

func set_open_mix(value: float) -> void:
    _open_mix = clampf(value, 0.0, 1.0)
    queue_redraw()

func trigger_glitch(strength: float = 1.0) -> void:
    if _reduced_motion:
        return
    _glitch = maxf(_glitch, clampf(strength, 0.0, 1.0))
    queue_redraw()

func _process(delta: float) -> void:
    _phase = fmod(_phase + delta, 10000.0)
    if _video_is_active():
        # The authored asset is a frame-perfect ping-pong loop now. Keep the
        # procedural neural/glitch layer independent instead of hiding a hard
        # video reset with a forced glitch.
        _last_video_position = _video_player.stream_position
    if not _reduced_motion:
        if not _video_is_active() and not _blink_active:
            _next_blink_at -= delta
            if _next_blink_at <= 0.0:
                _blink_active = true
                _blink_closing = true
                _glitch = maxf(_glitch, 0.55 if _profile == "splash" else 0.18)
        if _blink_active:
            var target: float = 1.0 if _blink_closing else 0.0
            var blink_speed: float = 14.0 if _blink_closing else 9.0
            _blink = move_toward(_blink, target, delta * blink_speed)
            if _blink_closing and _blink >= 0.98:
                _blink_closing = false
            elif not _blink_closing and _blink <= 0.01:
                _blink = 0.0
                _blink_active = false
                _schedule_next_blink()
        _glitch = move_toward(_glitch, 0.0, delta * (4.8 if _profile == "splash" else 7.0))
        if _profile == "menu":
            var local_mouse: Vector2 = get_local_mouse_position()
            if Rect2(Vector2.ZERO, size).has_point(local_mouse) and size.x > 1.0 and size.y > 1.0:
                var target_pointer := Vector2(clampf(local_mouse.x / size.x, 0.0, 1.0), clampf(local_mouse.y / size.y, 0.0, 1.0))
                _pointer = _pointer.lerp(target_pointer, minf(1.0, delta * 6.0))
    _redraw_accumulator += delta
    var redraw_hz: float = 60.0 if _profile == "splash" else (24.0 if _video_is_active() else 36.0)
    if _redraw_accumulator >= 1.0 / redraw_hz:
        _redraw_accumulator = 0.0
        queue_redraw()

func _sync_processing() -> void:
    set_process(is_visible_in_tree() and not _reduced_motion)

func _schedule_next_blink() -> void:
    var base: float = 2.7 if _profile == "menu" else 1.8
    var spread: float = 3.1 if _profile == "menu" else 2.0
    _next_blink_at = base + fmod(absf(sin(_phase * 3.17 + 0.73)) * 997.0, spread)

func _draw() -> void:
    if size.x <= 2.0 or size.y <= 2.0:
        return
    var authored_profile: bool = _profile == "menu" or _profile == "splash"
    var base_texture: Texture2D = _menu_eye_poster_texture if authored_profile and _menu_eye_poster_texture != null else _door_eye_texture
    if base_texture == null:
        return
    var min_side: float = minf(size.x, size.y)
    var art: Rect2 = _fit_texture_rect(base_texture.get_size())
    var glow: float = 0.52 + 0.20 * sin(_phase * 1.15)
    var glitch_px: float = _glitch * maxf(2.0, min_side * 0.012)

    # A soft painted aura keeps the authored eye integrated with the current
    # accent. Splash/menu use a real frame from the exact same loop, so the
    # native pre-splash, first Godot frame and moving menu eye never jump art.
    for index in range(4):
        var grow: float = 5.0 + float(index) * 9.0
        draw_rect(art.grow(grow), Color(_accent, (0.050 - float(index) * 0.008) * glow), false, maxf(1.0, min_side * 0.0025))

    var art_alpha: float = 0.96 if _profile != "panel" else 0.84
    var open_bloom: float = 0.04 + _open_mix * 0.10
    if not _video_is_active():
        draw_texture_rect(base_texture, art, false, Color(1.0 + open_bloom, 1.0 + open_bloom * 0.35, 1.0 + open_bloom, art_alpha))
    draw_rect(art, Color(_accent, 0.16 + _open_mix * 0.08), false, maxf(1.0, min_side * 0.004))

    _draw_textured_eye_animation(art, min_side, glow)
    if _glitch > 0.02:
        _draw_texture_glitch(base_texture, art, glitch_px)

func _fit_texture_rect(texture_size: Vector2) -> Rect2:
    var aspect: float = texture_size.x / maxf(1.0, texture_size.y)
    var max_h: float = size.y * (0.96 if _profile != "panel" else 0.92)
    var max_w: float = size.x * (0.96 if _profile != "panel" else 0.94)
    var target_h: float = minf(max_h, max_w / aspect)
    var target_w: float = target_h * aspect
    if target_w > max_w:
        target_w = max_w
        target_h = target_w / aspect
    var position: Vector2 = ((size - Vector2(target_w, target_h)) * 0.5).round()
    return Rect2(position, Vector2(target_w, target_h).round())

func _draw_textured_eye_animation(art: Rect2, min_side: float, glow: float) -> void:
    # Coordinates are authored against the reusable door-eye crop. The bitmap
    # carries material/ink detail; these overlays only animate it.
    var eye_center := art.position + art.size * Vector2(0.50, 0.505)
    var eye_size := art.size * Vector2(0.57, 0.235)
    var video_active: bool = _video_is_active()
    var lid_close: float = 0.0 if video_active else clampf(_blink, 0.0, 1.0)

    if video_active:
        # The user-authored clip owns eyelid anatomy. Keep only the live neural
        # pulse/glitch layer on top; no black procedural lid overlay.
        var animated_radius: float = minf(eye_size.x, eye_size.y) * 0.38
        _draw_brain_pulses(eye_center, animated_radius, glow * 0.72)
        return

    if lid_close > 0.01:
        var half_h: float = eye_size.y * 0.50
        var cover: float = half_h * pow(lid_close, 0.72)
        var x0: float = eye_center.x - eye_size.x * 0.52
        var x1: float = eye_center.x + eye_size.x * 0.52
        var ink := Color(0.010, 0.009, 0.013, 0.97)
        var upper := PackedVector2Array([
            Vector2(x0, eye_center.y - half_h),
            Vector2(x1, eye_center.y - half_h),
            Vector2(x1 - eye_size.x * 0.10, eye_center.y - half_h + cover),
            Vector2(eye_center.x, eye_center.y - half_h + cover * 1.08),
            Vector2(x0 + eye_size.x * 0.10, eye_center.y - half_h + cover),
        ])
        var lower := PackedVector2Array([
            Vector2(x0 + eye_size.x * 0.10, eye_center.y + half_h - cover),
            Vector2(eye_center.x, eye_center.y + half_h - cover * 1.08),
            Vector2(x1 - eye_size.x * 0.10, eye_center.y + half_h - cover),
            Vector2(x1, eye_center.y + half_h),
            Vector2(x0, eye_center.y + half_h),
        ])
        draw_colored_polygon(upper, ink)
        draw_colored_polygon(lower, ink)
        draw_polyline(PackedVector2Array([upper[4], upper[3], upper[2]]), Color(_secondary, 0.30), maxf(1.0, min_side * 0.003), true)
        draw_polyline(PackedVector2Array([lower[0], lower[1], lower[2]]), Color(_accent, 0.24), maxf(1.0, min_side * 0.003), true)

    if lid_close > 0.76:
        return

    var iris_radius: float = minf(eye_size.x, eye_size.y) * 0.30
    var pupil_offset := Vector2((_pointer.x - 0.5) * eye_size.x * 0.025, (_pointer.y - 0.5) * eye_size.y * 0.055)
    var iris_center: Vector2 = eye_center + pupil_offset
    # Moving micro-pupil/highlight is subtle enough not to fight the painted eye.
    draw_circle(iris_center, iris_radius * 0.22, Color(0.002, 0.003, 0.006, 0.72))
    draw_circle(iris_center + Vector2(-iris_radius * 0.15, -iris_radius * 0.17), maxf(1.0, iris_radius * 0.055), Color(0.94, 0.98, 1.0, 0.62))
    _draw_brain_pulses(iris_center, iris_radius * 1.28, glow)

func _draw_brain_pulses(center: Vector2, radius: float, glow: float) -> void:
    var nodes := [
        Vector2(-0.38, -0.18), Vector2(-0.13, 0.30), Vector2(0.12, -0.30), Vector2(0.39, 0.14), Vector2(0.02, -0.03)
    ]
    for index in range(nodes.size()):
        var node: Vector2 = center + nodes[index] * radius
        var pulse: float = 0.50 + 0.50 * sin(_phase * (1.15 + float(index) * 0.19) + float(index) * 0.8)
        var color: Color = _accent.lerp(_secondary, float(index) / maxf(1.0, float(nodes.size() - 1)))
        draw_circle(node, maxf(1.0, radius * (0.025 + pulse * 0.020)), Color(color, (0.38 + pulse * 0.52) * glow))

func _draw_texture_glitch(texture: Texture2D, art: Rect2, glitch_px: float) -> void:
    var tex_size: Vector2 = texture.get_size()
    var slices: int = 4
    for index in range(slices):
        var ratio: float = 0.18 + float(index) * 0.18 + 0.012 * sin(_phase * 37.0 + float(index))
        var height_ratio: float = 0.018 + _glitch * 0.018
        var dest := Rect2(
            Vector2(art.position.x + sin(_phase * 61.0 + float(index) * 2.3) * glitch_px * 2.2, art.position.y + art.size.y * ratio),
            Vector2(art.size.x, art.size.y * height_ratio)
        )
        var src := Rect2(
            Vector2(0.0, tex_size.y * ratio),
            Vector2(tex_size.x, tex_size.y * height_ratio)
        )
        draw_texture_rect_region(texture, dest, src, Color(1.0, 1.0, 1.0, 0.30 + _glitch * 0.34))
        draw_rect(dest, Color(_accent.lerp(_secondary, float(index) / float(slices)), 0.10 * _glitch), true)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_sync_video_geometry")

func _exit_tree() -> void:
    if _video_player != null:
        _video_player.stop()
        _video_player.stream = null
