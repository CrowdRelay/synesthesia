extends RefCounted

# Shared visual language for Synesthesia, VIRYA Signal and the public VIRYA surfaces.
# The game keeps its comic texture in artwork and identity accents, while product
# UI uses calmer dark surfaces, thin signal lines and a restrained accent system.

const VOID: Color = Color("070A0F")
const SURFACE: Color = Color("0D131C")
const SURFACE_RAISED: Color = Color("121B27")
const SURFACE_SOFT: Color = Color("172231")
const TEXT: Color = Color("F3EEE6")
const TEXT_MUTED: Color = Color("A9B3C2")
const TEXT_DIM: Color = Color("738297")
const SIGNAL: Color = Color("71DCFF")
const ROSE: Color = Color("E35F83")
const MEMORY: Color = Color("F0CF88")
const SUCCESS: Color = Color("72D79A")
const HAIRLINE: Color = Color("A9C0DA2A")

const RADIUS_LARGE: float = 4.0
const RADIUS_MEDIUM: float = 3.0
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
    if primary:
        strength += 0.10
    var base := SURFACE_SOFT.lerp(accent, clampf(strength, 0.0, 0.52))
    style.bg_color = Color(base, 0.82 if state != "disabled" else 0.42)
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
    style.bg_color = Color("080D14F2")
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
