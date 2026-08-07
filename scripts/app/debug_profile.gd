extends RefCounted

## Local desktop ergonomics only. Exported/web builds keep their normal adaptive
## viewport and brush balance. macOS debug runs use the largest portrait window
## that fits inside the current screen's usable height, centered and windowed.

const PORTRAIT_ASPECT: float = 9.0 / 16.0
const FHD_PORTRAIT: Vector2i = Vector2i(1080, 1920)
const WINDOW_MARGIN: Vector2i = Vector2i(24, 24)
const DEBUG_BRUSH_MULTIPLIER: float = 2.25

static func is_local_desktop_debug() -> bool:
    return OS.get_environment("SYNESTHESIA_LOCAL_DEBUG") == "1" and not OS.has_feature("web")

static func fit_macos_window_to_screen() -> void:
    if not is_local_desktop_debug() or not OS.has_feature("macos"):
        return
    var screen: int = DisplayServer.window_get_current_screen()
    var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
    if usable.size.x <= 0 or usable.size.y <= 0:
        return

    var max_width: int = maxi(1, usable.size.x - WINDOW_MARGIN.x * 2)
    var max_height: int = maxi(1, usable.size.y - WINDOW_MARGIN.y * 2)
    var target_height: int = mini(FHD_PORTRAIT.y, max_height)
    var target_width: int = roundi(float(target_height) * PORTRAIT_ASPECT)
    if target_width > max_width:
        target_width = max_width
        target_height = roundi(float(target_width) / PORTRAIT_ASPECT)

    var target_size := Vector2i(maxi(1, target_width), maxi(1, target_height))
    var target_position := usable.position + (usable.size - target_size) / 2
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
    DisplayServer.window_set_size(target_size)
    DisplayServer.window_set_position(target_position)

static func tune_debug_brush(raw_brush: Dictionary) -> Dictionary:
    var brush: Dictionary = raw_brush.duplicate(true)
    if is_local_desktop_debug():
        brush["min_width"] = float(brush.get("min_width", 22.0)) * DEBUG_BRUSH_MULTIPLIER
        brush["max_width"] = float(brush.get("max_width", 54.0)) * DEBUG_BRUSH_MULTIPLIER
    return brush
