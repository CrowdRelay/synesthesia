extends SceneTree

const TITLE_FONT_PATH: String = "res://assets/fonts/generated/SynesthesiaTitle.ttf"
const POLISH_GLYPHS: String = "ĄĆĘŁŃÓŚŹŻąćęłńóśźż"
const SAMPLE: String = "Zażółć gęślą jaźń"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if not ResourceLoader.exists(TITLE_FONT_PATH):
        push_error("Bundled title font is missing: %s" % TITLE_FONT_PATH)
        quit(1)
        return
    var resource: Resource = load(TITLE_FONT_PATH)
    if not resource is Font:
        push_error("Bundled title resource is not a Font")
        quit(1)
        return
    var font := resource as Font
    var missing: PackedStringArray = []
    for index in range(POLISH_GLYPHS.length()):
        var codepoint: int = POLISH_GLYPHS.unicode_at(index)
        if not font.has_char(codepoint):
            missing.append("U+%04X" % codepoint)
    if not missing.is_empty():
        push_error("Title font misses Polish glyphs: %s" % ",".join(missing))
        quit(1)
        return
    print("SYNESTHESIA_FONT_GLYPHS=PASS sample=%s glyphs=%d" % [SAMPLE, POLISH_GLYPHS.length()])
    quit(0)
