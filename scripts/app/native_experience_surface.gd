extends Control

## Native-resolution shell. The root always matches the real viewport. UI uses
## the full available surface on phones and a centered portrait surface on wide
## screens. Album artwork itself stays 9:16 and is cover-fitted so it is never
## stretched; narrow/tall devices crop a little at the sides instead of
## upscaling a distorted logical canvas.

signal content_geometry_changed

const PORTRAIT_ASPECT: float = 9.0 / 16.0
const PHONE_ASPECT_CUTOFF: float = 0.72

var content_surface: Control
var ambient_left: ColorRect
var ambient_right: ColorRect
var _content_rect: Rect2 = Rect2()
var _art_cover_rect: Rect2 = Rect2()

func _ready() -> void:
    name = "NativeExperienceSurface"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build()
    get_viewport().size_changed.connect(_fit_to_viewport)
    _fit_to_viewport()
    call_deferred("_fit_to_viewport")

func _build() -> void:
    ambient_left = ColorRect.new()
    ambient_left.name = "AmbientLeft"
    ambient_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ambient_left.color = Color("03050b")
    add_child(ambient_left)

    ambient_right = ColorRect.new()
    ambient_right.name = "AmbientRight"
    ambient_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ambient_right.color = Color("03050b")
    add_child(ambient_right)

    content_surface = Control.new()
    content_surface.name = "AdaptiveExperienceSurface"
    content_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content_surface.clip_contents = true
    add_child(content_surface)

func get_content_surface() -> Control:
    return content_surface

func get_content_rect() -> Rect2:
    return _content_rect

func get_art_cover_rect() -> Rect2:
    return _art_cover_rect

func get_native_viewport_size() -> Vector2i:
    var viewport_size: Vector2 = get_viewport_rect().size
    return Vector2i(roundi(viewport_size.x), roundi(viewport_size.y))

func get_render_label() -> String:
    var native: Vector2i = get_native_viewport_size()
    var art: Vector2i = Vector2i(roundi(_art_cover_rect.size.x), roundi(_art_cover_rect.size.y))
    return "ADAPTIVE NATIVE %d×%d · ART %d×%d" % [native.x, native.y, art.x, art.y]

func _fit_to_viewport() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return
    # This Control is already PRESET_FULL_RECT. Writing size/position while
    # opposite anchors differ triggers Godot's override-after-_ready warning
    # and can briefly desynchronise GUI hit-testing from the adaptive surface.
    # Let anchors own the root geometry; only child surfaces are positioned.

    var viewport_aspect: float = viewport_size.x / viewport_size.y
    var target_size: Vector2
    # Portrait phones/tablets use every native screen pixel for UI. On wider
    # screens the immersive room stays portrait while menus can use the sides.
    if viewport_aspect <= PHONE_ASPECT_CUTOFF:
        target_size = viewport_size
    else:
        var target_height: float = viewport_size.y
        var target_width: float = target_height * PORTRAIT_ASPECT
        if target_width > viewport_size.x:
            target_width = viewport_size.x
            target_height = target_width / PORTRAIT_ASPECT
        target_size = Vector2(round(target_width), round(target_height))

    var target_position: Vector2 = ((viewport_size - target_size) * 0.5).round()
    _content_rect = Rect2(target_position, target_size)
    content_surface.position = target_position
    content_surface.size = target_size

    # Album art always keeps its source aspect. Cover-fit means a 390×844 phone
    # gets a ~475×844 art surface cropped symmetrically by the parent instead of
    # squeezing 9:16 into the taller viewport. Desktop 9:16 remains exactly 1:1.
    var content_aspect: float = target_size.x / target_size.y
    var art_size: Vector2
    if content_aspect < PORTRAIT_ASPECT:
        art_size = Vector2(round(target_size.y * PORTRAIT_ASPECT), target_size.y)
    else:
        art_size = Vector2(target_size.x, round(target_size.x / PORTRAIT_ASPECT))
    var art_position: Vector2 = ((target_size - art_size) * 0.5).round()
    _art_cover_rect = Rect2(art_position, art_size)

    ambient_left.position = Vector2.ZERO
    ambient_left.size = Vector2(maxf(0.0, target_position.x), viewport_size.y)
    ambient_right.position = Vector2(target_position.x + target_size.x, 0.0)
    ambient_right.size = Vector2(maxf(0.0, viewport_size.x - target_position.x - target_size.x), viewport_size.y)
    content_geometry_changed.emit()
