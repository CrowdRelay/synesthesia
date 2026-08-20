extends RefCounted

static var _display_name: String = ""

static func set_display_name(value: String) -> void:
    _display_name = value.strip_edges().left(24)

static func display_name() -> String:
    return _display_name

static func effective_name() -> String:
    return _display_name if not _display_name.is_empty() else "anonymous"
