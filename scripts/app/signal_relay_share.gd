extends RefCounted

const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const RELAY_URL := "https://synesthesia.virya.music/?source=synesthesia-finale&relay=grassroots"
const RELAY_TITLE := "VIRYA — SYNESTHESIA"
const RELAY_TEXT := "Przeszedłem SYNESTHESIA VIRYA — jedenaście komnat zbudowanych z muzyki, obrazu i dotyku. Jeśli czujesz ten sygnał, sprawdź sam."

static func share() -> String:
    if OS.has_feature("web"):
        var has_share: Variant = JavaScriptBridge.eval("typeof navigator.share === 'function'", true)
        if bool(has_share):
            var payload := JSON.stringify({"title": RELAY_TITLE, "text": RELAY_TEXT, "url": RELAY_URL})
            JavaScriptBridge.eval("navigator.share(%s).catch(()=>{});" % payload, true)
            return "Otwieram udostępnianie · wybierz jedną osobę, której ten świat może naprawdę wejść pod skórę."
        var encoded_url := JSON.stringify(RELAY_URL)
        JavaScriptBridge.eval("if(navigator.clipboard){navigator.clipboard.writeText(%s).catch(()=>{});}" % encoded_url, true)
    DisplayServer.clipboard_set(RELAY_URL)
    return "Link do SYNESTHESIA skopiowany · podaj go dalej komuś, kto naprawdę może poczuć ten sygnał."

static func add_to(container: VBoxContainer, accent: Color, status: Label) -> void:
    if container == null:
        return
    var note := UIFactory.body("LATARNIK SYGNAŁU · zero spamu. Jeśli znasz jedną osobę, której ten świat naprawdę może się spodobać, podaj go dalej.")
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    note.add_theme_font_size_override("font_size", 10)
    note.add_theme_color_override("font_color", Color("9eafc3"))
    container.add_child(note)
    var button := UIFactory.product_button("PODAJ SYGNAŁ DALEJ", accent)
    button.name = "GrassrootsRelayShare"
    button.pressed.connect(func() -> void:
        if status != null:
            status.text = share()
    )
    container.add_child(button)
