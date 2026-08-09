extends RefCounted

## Native-resolution UI density helper. Rendering stays 1:1 with the viewport;
## only typography, touch targets and spacing scale from the old 540x960 design
## reference. This avoids blurry canvas upscaling while keeping controls readable
## on FHD/HiDPI screens.

const REFERENCE_VIEWPORT: Vector2 = Vector2(540.0, 960.0)
const MIN_SCALE: float = 0.95
const MAX_SCALE: float = 2.0
const PORTRAIT_CONTENT_BOOST: float = 1.15
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

static func apply_tree(root: Node, scale: float) -> void:
    var safe_scale: float = clampf(scale, MIN_SCALE, MAX_SCALE)
    _apply_node(root, safe_scale)
    for child in root.get_children():
        apply_tree(child, safe_scale)

static func _apply_node(node: Node, scale: float) -> void:
    if not node is Control:
        return
    var control := node as Control
    if bool(control.get_meta(&"syn_skip_ui_scale", false)):
        return

    var content_scale: float = scale
    var viewport_size: Vector2 = control.get_viewport().get_visible_rect().size
    var aspect: float = viewport_size.x / maxf(1.0, viewport_size.y)
    if aspect <= PORTRAIT_ASPECT_THRESHOLD:
        # Boost only readable UI content on portrait devices. Panel geometry
        # keeps the proven native scale so larger type never creates overflow.
        content_scale *= PORTRAIT_CONTENT_BOOST

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
