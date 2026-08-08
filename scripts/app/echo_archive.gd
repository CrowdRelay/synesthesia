extends RefCounted

static func remember(album_state: Dictionary, release_id: String, item: Dictionary, ordinal: int) -> void:
    var archive_value: Variant = album_state.get("echo_archive", {})
    var archive: Dictionary = archive_value if archive_value is Dictionary else {}
    var room_value: Variant = archive.get(release_id, {})
    var room_archive: Dictionary = room_value if room_value is Dictionary else {}
    var echo_id: String = str(item.get("id", "echo-%d" % ordinal))
    room_archive[echo_id] = {
        "title": str(item.get("title", "Echo")),
        "message": str(item.get("message", "")),
        "found_at_unix": int(Time.get_unix_time_from_system()),
    }
    archive[release_id] = room_archive
    album_state["echo_archive"] = archive
