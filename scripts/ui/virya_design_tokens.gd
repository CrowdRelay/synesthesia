extends RefCounted

# Shared visual language for Synesthesia, VIRYA Signal and the public VIRYA surfaces.
# The game keeps its comic texture in artwork and identity accents, while product
# UI uses calmer dark surfaces, thin signal lines and a restrained accent system.

# Canonical VIRYA / Virya Signal V2 product chrome. Room artwork may use its
# own sensory palette; fixed navigation, forms and operational surfaces do not.
const VOID: Color = Color("070908")
const BG_RAISED: Color = Color("0B100F")
const SURFACE: Color = Color("101715")
const SURFACE_RAISED: Color = Color("16201D")
const SURFACE_SOFT: Color = Color("0B100F")
const TEXT: Color = Color("EEF4F1")
const TEXT_MUTED: Color = Color("98A5A0")
const TEXT_DIM: Color = Color("7D8A85")
const HAIRLINE: Color = Color("27322F")
const SIGNAL: Color = Color("84B4AC")
const SIGNAL_HOT: Color = Color("93C6C0")
const SIGNAL_DEEP: Color = Color("26655D")
const WARNING: Color = Color("F3C51A")
const DANGER: Color = Color("E73535")
const SUCCESS: Color = Color("70DB91")
# Sensory/story-only accents. Never use these as generic product chrome.
const ROSE: Color = Color("D87996")
const MEMORY: Color = WARNING

const RADIUS_LARGE: float = 6.0
const RADIUS_MEDIUM: float = 6.0
const RADIUS_SMALL: float = 2.0

static func surface(accent: Color = SIGNAL, strong: bool = false) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(SURFACE_RAISED if strong else SURFACE, 0.90 if strong else 0.84)
    style.border_color = Color(accent, 0.42 if strong else 0.24)
    style.set_border_width_all(1)
    style.set_corner_radius_all(roundi(RADIUS_LARGE))
    style.content_margin_left = 24.0
    style.content_margin_top = 22.0
    style.content_margin_right = 24.0
    style.content_margin_bottom = 22.0
    return style

static func inset(accent: Color = SIGNAL, emphasis: float = 0.12) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(SURFACE_SOFT, 0.58)
    style.border_color = Color(accent, clampf(emphasis, 0.08, 0.34))
    style.set_border_width_all(1)
    style.set_corner_radius_all(roundi(RADIUS_MEDIUM))
    style.content_margin_left = 16.0
    style.content_margin_top = 14.0
    style.content_margin_right = 16.0
    style.content_margin_bottom = 14.0
    return style

static func button(accent: Color, state: String, primary: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    var strength: float = 0.18
    var border_alpha: float = 0.32
    match state:
        "hover":
            strength = 0.16
            border_alpha = 0.62
        "pressed":
            strength = 0.22
            border_alpha = 0.74
        "focus":
            strength = 0.14
            border_alpha = 0.82
        "disabled":
            strength = 0.04
            border_alpha = 0.12
    if primary and state != "disabled":
        var primary_color := accent.lerp(Color.WHITE, 0.08 if state == "hover" else 0.0)
        style.bg_color = primary_color
        style.border_color = primary_color
    else:
        var base := SURFACE_SOFT.lerp(accent, clampf(strength, 0.0, 0.42))
        style.bg_color = Color(base, 0.86 if state != "disabled" else 0.42)
        style.border_color = Color(accent if state != "disabled" else TEXT_DIM, border_alpha)
    style.set_border_width_all(1)
    style.set_corner_radius_all(roundi(RADIUS_SMALL))
    style.content_margin_left = 16.0
    style.content_margin_top = 10.0
    style.content_margin_right = 16.0
    style.content_margin_bottom = 10.0
    return style

static func input(accent: Color, focused: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(VOID, 0.95)
    style.border_color = Color(accent, 0.68 if focused else 0.22)
    style.set_border_width_all(1 if not focused else 2)
    style.set_corner_radius_all(roundi(RADIUS_SMALL))
    style.content_margin_left = 16.0
    style.content_margin_top = 11.0
    style.content_margin_right = 14.0
    style.content_margin_bottom = 11.0
    return style

static func chip(accent: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(accent, 0.08)
    style.border_color = Color(accent, 0.30)
    style.set_border_width_all(1)
    style.set_corner_radius_all(999)
    style.content_margin_left = 11.0
    style.content_margin_top = 5.0
    style.content_margin_right = 11.0
    style.content_margin_bottom = 5.0
    return style
