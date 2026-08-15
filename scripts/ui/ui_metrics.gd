extends RefCounted

## Native-resolution UI density helper. Rendering stays 1:1 with the viewport;
## only typography, touch targets and spacing scale from the old 540x960 design
## reference. This avoids blurry canvas upscaling while keeping controls readable
## on FHD/HiDPI screens.

const REFERENCE_VIEWPORT: Vector2 = Vector2(540.0, 960.0)
const MIN_SCALE: float = 0.95
const MAX_SCALE: float = 2.0
const PORTRAIT_CONTENT_BOOST: float = 1.30
const PORTRAIT_ASPECT_THRESHOLD: float = 0.82
const MIN_LABEL_FONT_SIZE: int = 10
const MIN_INTERACTIVE_FONT_SIZE: int = 12
const LOCAL_DEBUG_MIN_SCALE: float = 1.30
const META_FONT_SIZE: StringName = &"syn_base_font_size"
const META_MIN_SIZE: StringName = &"syn_base_minimum_size"
const META_SEPARATION: StringName = &"syn_base_separation"

static func scale_for_viewport(viewport_size: Vector2) -> float:
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return 1.0
    var width_scale: float = viewport_size.x / REFERENCE_VIEWPORT.x
    var height_scale: float = viewport_size.y / REFERENCE_VIEWPORT.y
    var scale: float = clampf(minf(width_scale, height_scale), MIN_SCALE, MAX_SCALE)
    if OS.get_environment("SYNESTHESIA_LOCAL_DEBUG") == "1" and not OS.has_feature("web"):
        scale = maxf(scale, LOCAL_DEBUG_MIN_SCALE)
    return scale


static func safe_insets(viewport_size: Vector2) -> Vector4:
    # Return viewport-space left/top/right/bottom insets for mobile cutouts and
    # gesture areas. Keep this centralized so every interactive overlay uses the
    # same physical->viewport conversion instead of hand-rolling subtly different
    # notch math.
    if not OS.has_feature("mobile") or viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return Vector4.ZERO
    var screen_size: Vector2i = DisplayServer.screen_get_size()
    if screen_size.x <= 0 or screen_size.y <= 0:
        return Vector4.ZERO
    var safe: Rect2i = DisplayServer.get_display_safe_area()
    if safe.size.x <= 0 or safe.size.y <= 0:
        return Vector4.ZERO
    var scale_x: float = viewport_size.x / float(screen_size.x)
    var scale_y: float = viewport_size.y / float(screen_size.y)
    var left: float = maxf(0.0, float(safe.position.x) * scale_x)
    var top: float = maxf(0.0, float(safe.position.y) * scale_y)
    var right_px: int = maxi(0, screen_size.x - (safe.position.x + safe.size.x))
    var bottom_px: int = maxi(0, screen_size.y - (safe.position.y + safe.size.y))
    var right: float = maxf(0.0, float(right_px) * scale_x)
    var bottom: float = maxf(0.0, float(bottom_px) * scale_y)
    var cap: float = maxf(48.0, 72.0 * scale_for_viewport(viewport_size))
    return Vector4(minf(left, cap), minf(top, cap), minf(right, cap), minf(bottom, cap))

static func safe_margin(viewport_size: Vector2, base_margin: float) -> float:
    var safe := safe_insets(viewport_size)
    return maxf(base_margin, maxf(maxf(safe.x, safe.z), maxf(safe.y, safe.w)))

static func apply_tree(root: Node, scale: float) -> void:
    var safe_scale: float = clampf(scale, MIN_SCALE, MAX_SCALE)
    var content_scale: float = safe_scale
    if root is Control:
        var viewport_size: Vector2 = (root as Control).get_viewport().get_visible_rect().size
        var aspect: float = viewport_size.x / maxf(1.0, viewport_size.y)
        if aspect <= PORTRAIT_ASPECT_THRESHOLD:
            content_scale *= PORTRAIT_CONTENT_BOOST
    _apply_tree(root, safe_scale, content_scale)

static func _apply_tree(node: Node, scale: float, content_scale: float) -> void:
    _apply_node(node, scale, content_scale)
    for child in node.get_children():
        _apply_tree(child, scale, content_scale)

static func _apply_node(node: Node, scale: float, content_scale: float) -> void:
    if not node is Control:
        return
    var control := node as Control
    if bool(control.get_meta(&"syn_skip_ui_scale", false)):
        return

    if control is Label or control is BaseButton or control is LineEdit:
        if not control.has_meta(META_FONT_SIZE):
            control.set_meta(META_FONT_SIZE, maxi(8, control.get_theme_font_size("font_size")))
        var base_font: int = int(control.get_meta(META_FONT_SIZE, 12))
        var min_font_size: int = MIN_INTERACTIVE_FONT_SIZE if control is BaseButton or control is LineEdit else MIN_LABEL_FONT_SIZE
        control.add_theme_font_size_override("font_size", maxi(min_font_size, roundi(float(base_font) * content_scale)))

    if control is BaseButton or control is LineEdit:
        if not control.has_meta(META_MIN_SIZE):
            control.set_meta(META_MIN_SIZE, control.custom_minimum_size)
        var base_min: Vector2 = control.get_meta(META_MIN_SIZE, Vector2.ZERO)
        var min_height: float = 44.0 * content_scale
        var scaled_width: float = base_min.x * scale if base_min.x > 0.0 else 0.0
        var scaled_height: float = maxf(base_min.y * content_scale, min_height)
        control.custom_minimum_size = Vector2(scaled_width, scaled_height)

    if control is BoxContainer:
        var box := control as BoxContainer
        if not box.has_meta(META_SEPARATION):
            box.set_meta(META_SEPARATION, maxi(1, box.get_theme_constant("separation")))
        var base_separation: int = int(box.get_meta(META_SEPARATION, 4))
        box.add_theme_constant_override("separation", maxi(1, roundi(float(base_separation) * scale)))
