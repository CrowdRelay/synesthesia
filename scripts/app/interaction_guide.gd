extends Node

signal hint_ready(text: String)
signal visual_hint_changed(strength: float)
signal assist_level_changed(level: int)

const FIRST_IDLE_SECONDS := 2.8
const FOLLOWUP_IDLE_SECONDS := 11.0
const PROGRESS_EPSILON := 0.025
const MISS_COOLDOWN_MS := 650
const MISS_HINT_THRESHOLD := 2

var _timer: Timer
var _interaction := "paint"
var _hint_level := 0
var _last_progress := 0.0
var _enabled := false
var _miss_count := 0
var _last_miss_ms := 0
var _resume_boost_pending := false
var _assist_level := 0

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
    _miss_count = 0
    _resume_boost_pending = false
    _set_assist_level(0)
    visual_hint_changed.emit(0.62)
    _restart(FIRST_IDLE_SECONDS)

func suspend() -> void:
    _enabled = false
    visual_hint_changed.emit(0.0)
    if _timer != null:
        _timer.stop()

func resume() -> void:
    if _interaction.is_empty():
        return
    _enabled = true
    visual_hint_changed.emit(0.66 if _resume_boost_pending else 0.56)
    _restart(2.8 if _resume_boost_pending else FIRST_IDLE_SECONDS)
    _resume_boost_pending = false

func prime_after_resume() -> void:
    # A returning player may remember the room visually but forget its gesture.
    # The first hint arrives sooner once, without making new runs tutorial-heavy.
    _resume_boost_pending = true
    if _enabled:
        visual_hint_changed.emit(0.68)
        _restart(2.8)

func note_miss() -> void:
    if not _enabled:
        return
    var now_ms: int = Time.get_ticks_msec()
    if now_ms - _last_miss_ms < MISS_COOLDOWN_MS:
        return
    _last_miss_ms = now_ms
    _miss_count = mini(_miss_count + 1, 6)
    _set_assist_level(3 if _miss_count >= 6 else (2 if _miss_count >= 4 else (1 if _miss_count >= 2 else 0)))
    if _miss_count >= MISS_HINT_THRESHOLD:
        var strength: float = clampf(0.48 + float(_miss_count - MISS_HINT_THRESHOLD) * 0.10, 0.48, 0.86)
        visual_hint_changed.emit(strength)
        _restart(1.6 if _miss_count >= 4 else 2.6)

func note_interaction() -> void:
    if not _enabled:
        return
    visual_hint_changed.emit(0.06)
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
        _miss_count = maxi(0, _miss_count - 2)
        _set_assist_level(3 if _miss_count >= 6 else (2 if _miss_count >= 4 else (1 if _miss_count >= 2 else 0)))
        visual_hint_changed.emit(0.06)
        _restart(FOLLOWUP_IDLE_SECONDS)

func _restart(delay: float) -> void:
    if _timer == null or not _enabled:
        return
    var assist_scale: float = [1.0, 0.86, 0.72, 0.58][_assist_level]
    _timer.start(maxf(1.25, delay * assist_scale))

func _set_assist_level(level: int) -> void:
    var next_level := clampi(level, 0, 3)
    if next_level == _assist_level:
        return
    _assist_level = next_level
    assist_level_changed.emit(_assist_level)

func _on_timeout() -> void:
    if not _enabled:
        return
    var hints := _hints_for(_interaction)
    if hints.is_empty():
        return
    var index := mini(_hint_level, hints.size() - 1)
    hint_ready.emit(str(hints[index]))
    var miss_bonus: float = minf(0.18, float(_miss_count) * 0.035)
    visual_hint_changed.emit(clampf((0.62 if _hint_level == 0 else 0.84) + miss_bonus, 0.0, 0.94))
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
            return ["Nie wszystkie ekrany są problemem. Poszukaj przewodów, które je karmią.", "Chwyć świecącą wtyczkę i wyciągnij ją dalej od gniazda. Potem znajdź zasilanie."]
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
