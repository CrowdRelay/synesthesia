extends RefCounted

static func apply(label: Label, button: Button, context: Dictionary) -> void:
    if label == null or button == null:
        return
    var event_value: Variant = context.get("next_event", {})
    var event: Dictionary = event_value if event_value is Dictionary else {}
    var slug: String = str(event.get("slug", ""))
    if slug.is_empty():
        label.visible = false
        button.visible = false
        return
    var city: String = str(event.get("city", ""))
    var venue: String = str(event.get("venue", ""))
    var place: String = city
    if not venue.is_empty():
        place = "%s · %s" % [place, venue] if not place.is_empty() else venue
    label.text = "Podróż nie kończy się tutaj. Następny fizyczny Sygnał%s." % (" · %s" % place if not place.is_empty() else "")
    button.text = "NASTĘPNY SYGNAŁ · %s" % str(event.get("title", slug)).to_upper()
    label.visible = true
    button.visible = true
