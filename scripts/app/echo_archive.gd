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
        "source": str(item.get("source", "VIRYA")),
        "source_role": str(item.get("source_role", "")),
        "echo_type": str(item.get("echo_type", "signal_trace")),
        "reward_hint": str(item.get("reward_hint", "")),
        "found_at_unix": int(Time.get_unix_time_from_system()),
    }
    archive[release_id] = room_archive
    album_state["echo_archive"] = archive

static func latest_echo(album_state: Dictionary, exclude_release_id: String = "") -> Dictionary:
    var archive_value: Variant = album_state.get("echo_archive", {})
    if not archive_value is Dictionary:
        return {}
    var latest: Dictionary = {}
    var latest_at: int = -1
    for release_id in (archive_value as Dictionary).keys():
        if str(release_id) == exclude_release_id:
            continue
        var room_value: Variant = (archive_value as Dictionary).get(release_id, {})
        if not room_value is Dictionary:
            continue
        for echo_value in (room_value as Dictionary).values():
            if not echo_value is Dictionary:
                continue
            var echo: Dictionary = echo_value as Dictionary
            var found_at := int(echo.get("found_at_unix", 0))
            if found_at >= latest_at:
                latest_at = found_at
                latest = echo.duplicate(true)
    return latest
