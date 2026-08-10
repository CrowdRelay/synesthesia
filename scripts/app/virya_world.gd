extends RefCounted

const WORLD_PATH: String = "res://data/virya_world.json"
const ReleaseReader := preload("res://scripts/app/release_reader.gd")

static func load_world() -> Dictionary:
    var data := ReleaseReader.load_json(WORLD_PATH)
    return data if not data.is_empty() else {}

static func manifest_identity(manifest: Dictionary) -> Dictionary:
    var value: Variant = manifest.get("virya_identity", {})
    return value if value is Dictionary else {}

static func summary_text() -> String:
    var world := load_world()
    if world.is_empty():
        return "Synesthesia jest częścią ekosystemu VIRYA Signal i ma rosnąć razem z Viryatkowem."
    var tagline := str(world.get("tagline", "")).strip_edges()
    var visual_value: Variant = world.get("visual_bible", {})
    var visual: Dictionary = visual_value if visual_value is Dictionary else {}
    var north_star := str(visual.get("north_star", "")).strip_edges()
    var parts := PackedStringArray()
    if not tagline.is_empty():
        parts.append(tagline)
    if not north_star.is_empty():
        parts.append("Kierunek: %s" % north_star)
    return "\n\n".join(parts)

static func characters_blurb() -> String:
    var world := load_world()
    var characters_value: Variant = world.get("characters", [])
    if not characters_value is Array:
        return ""
    var lines := PackedStringArray()
    for value in characters_value:
        if value is Dictionary:
            var character: Dictionary = value
            lines.append("%s — %s" % [str(character.get("title", "Postać")), str(character.get("member_role", ""))])
    return "Postacie Viryatkowa:\n%s" % "\n".join(lines) if not lines.is_empty() else ""

static func identity_label(identity: Dictionary) -> String:
    if identity.is_empty():
        return ""
    var focus := str(identity.get("focus_title", "")).strip_edges()
    var role := str(identity.get("member_role", "")).strip_edges()
    if focus.is_empty():
        return role
    if role.is_empty():
        return focus
    return "%s · %s" % [focus, role]

static func identity_hook(identity: Dictionary) -> String:
    if identity.is_empty():
        return ""
    var story := str(identity.get("story_role", "")).strip_edges()
    var costume := str(identity.get("future_costume_hook", "")).strip_edges()
    if story.is_empty():
        return costume
    if costume.is_empty():
        return story
    return "%s · strój: %s" % [story, costume]
