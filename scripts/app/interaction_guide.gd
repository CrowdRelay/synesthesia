extends Node

signal hint_ready(text: String)

const FIRST_IDLE_SECONDS := 7.5
const FOLLOWUP_IDLE_SECONDS := 11.0
const PROGRESS_EPSILON := 0.025

var _timer: Timer
var _interaction := "paint"
var _hint_level := 0
var _last_progress := 0.0
var _enabled := false

func _ready() -> void:
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_timeout)
    add_child(_timer)

func configure(interaction: String) -> void:
    _interaction = interaction
    _hint_level = 0
    _last_progress = 0.0
    _enabled = true
    _restart(FIRST_IDLE_SECONDS)

func suspend() -> void:
    _enabled = false
    if _timer != null:
        _timer.stop()

func resume() -> void:
    if _interaction.is_empty():
        return
    _enabled = true
    _restart(FIRST_IDLE_SECONDS)

func note_interaction() -> void:
    if not _enabled:
        return
    _restart(FOLLOWUP_IDLE_SECONDS)

func note_progress(normalized: float) -> void:
    if not _enabled:
        return
    var progress := clampf(normalized, 0.0, 1.0)
    if progress >= 0.99:
        suspend()
        return
    if progress >= _last_progress + PROGRESS_EPSILON:
        _last_progress = progress
        _restart(FOLLOWUP_IDLE_SECONDS)

func _restart(delay: float) -> void:
    if _timer == null or not _enabled:
        return
    _timer.start(delay)

func _on_timeout() -> void:
    if not _enabled:
        return
    var hints := _hints_for(_interaction)
    if hints.is_empty():
        return
    var index := mini(_hint_level, hints.size() - 1)
    hint_ready.emit(str(hints[index]))
    _hint_level += 1
    if _hint_level < hints.size():
        _restart(FOLLOWUP_IDLE_SECONDS)

func _hints_for(interaction: String) -> Array[String]:
    match interaction:
        "paint":
            return ["Spróbuj poprowadzić falę poziomo.", "Dłuższy ruch w bok uspokaja horyzont."]
        "pop_balloons":
            return ["Balony reagują na dotyk, nie tylko pędzel.", "Dotknij, przeciągnij albo przesuń szybko przez balon."]
        "venetian_masks":
            return ["Jedna z masek czeka na pęknięcie.", "Dotknij maski, a potem spróbuj zsunąć ją ruchem."]
        "toast_table":
            return ["Zatrzymaj palec przy butelce.", "Przytrzymaj, żeby nalać, potem przysuń kieliszek do toastu."]
        "grow_tree":
            return ["Ziarno potrzebuje chwili nacisku.", "Przytrzymaj ziarno i prowadź ruch ku górze."]
        "western_duel":
            return ["Cel staje się spokojniejszy, gdy go przytrzymasz.", "Przytrzymaj cel, ustaw ruch i puść bez pośpiechu."]
        "repair_glitches":
            return ["Każdy ekran można naprawić osobno.", "Dotykaj ekranów, a potem dostrój sygnał dłuższym ruchem."]
        "crack_mirrors":
            return ["Tafla pamięta pojedynczy dotyk.", "Pęknij lustro dotknięciem, potem zrzuć je zdecydowanym ruchem."]
        "raise_phoenix":
            return ["Popiół reaguje na ruch po okręgu.", "Zbierz energię krążąc palcem, potem wyprowadź ruch w górę."]
        "intimate_bedroom":
            return ["Druga obecność pojawia się po chwili kontaktu.", "Przytrzymaj obecność, potem zbliż dwa palce, aż oddechy się zsynchronizują."]
        "rise_atrium":
            return ["Finał przypomina gesty, które już znasz.", "Dotknij światła, przytrzymaj je i zakończ spokojnym ruchem w górę."]
        _:
            return ["Dotknij elementów sceny i poszukaj gestu właściwego dla tego pokoju."]
