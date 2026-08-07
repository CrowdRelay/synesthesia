extends RefCounted

static func load_json(path: String) -> Dictionary:
    if path.is_empty() or not FileAccess.file_exists(path):
        push_error("Missing JSON: %s" % path)
        return {}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Cannot open JSON: %s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        return parsed
    push_error("JSON root is not an object: %s" % path)
    return {}

static func read_text(path: String, fallback: String = "") -> String:
    if path.is_empty() or not FileAccess.file_exists(path):
        return fallback
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    return file.get_as_text().strip_edges() if file != null else fallback

static func accent_for_entry(entry_value: Variant, fallback: Color = Color("72afff")) -> Color:
    if not entry_value is Dictionary:
        return fallback
    var entry: Dictionary = entry_value
    var release_manifest: Dictionary = load_json(str(entry.get("manifest", "")))
    var room_value: Variant = release_manifest.get("room", {})
    if not room_value is Dictionary:
        return fallback
    return Color.from_string(str(room_value.get("accent_color", "#72AFFF")), fallback)
