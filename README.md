# VIRYA: Synestezja — spokojny vertical slice

Samodzielny prototyp mobilnego doświadczenia w Godot 4.7.1. Katalog projektu celowo żyje pod `synesthesia/` i nie dotyka `virya-signal`, CrowdRelay, n8n ani istniejącego mail-flow.

## Co już działa

- dotykowe i myszkowe malowanie pokoju;
- zmienna szerokość śladu zależna od szybkości gestu;
- trzy ukryte znajdźki narracyjne;
- proceduralny, łagodny soundscape odsłaniany wraz z postępem;
- delikatna haptyka mobilna z cooldownem;
- `Tryb spokojny` oraz `Tryb pełny`;
- natychmiastowe `Uspokój pokój`, wyłączające haptykę i visual snow oraz ściszające audio;
- indeks wydań oraz manifest release packa przygotowany pod kolejne single;
- generator szkieletu następnego release packa;
- brak logowania, telemetryki, backendu i presji na ukończenie.

## Struktura

```text
synesthesia/
└── virya-synestezja/
    ├── data/release_index.json
    ├── data/releases/prototype/manifest.json
    ├── scenes/main.tscn
    ├── scripts/
    ├── shaders/
    ├── tools/new_release_pack.py
    └── validate.sh
```

## Uruchomienie

1. Otwórz katalog `virya-synestezja` w Godot 4.7.1.
2. Uruchom projekt (`F6` lub `F5`).
3. Maluj myszką albo palcem.

Projekt używa renderera **GL Compatibility**, żeby pierwszy wycinek był lekki także dla słabszych telefonów.

## Walidacja

```bash
./validate.sh
```

Walidator zawsze wykonuje testy offline. Gdy `godot` jest dostępny w `PATH`, dodatkowo ładuje scenę i skrypty w trybie headless.

Oczekiwane minimum:

```text
SYNESTHESIA_STATIC_VALIDATION=PASS
```

Z dostępnym Godotem pojawi się również:

```text
SYNESTHESIA_VALIDATION=PASS
SYNESTHESIA_GODOT_RUNTIME=PASS
```

## Dodanie następnego singla

```bash
python3 tools/new_release_pack.py brak-sygnalu \
  --title "VIRYA: Brak sygnału" \
  --room "Sala transmisji" \
  --activate
```

Polecenie tworzy nowy manifest oraz katalogi `audio/` i `textures/`, a potem dopisuje wydanie do `data/release_index.json`. Nie modyfikuje core gameplayu.

## Android i haptyka

Przy tworzeniu presetu eksportu Android zaznacz uprawnienie `VIBRATE`. Bez niego projekt nadal działa, lecz `Input.vibrate_handheld()` pozostaje bez efektu.

## Audio

Prototyp nie zawiera jeszcze muzyki Viryi. Soundscape jest generowany proceduralnie i celowo pozostaje cichy. Kolejny etap to zastąpienie jego warstw przygotowanymi stemami konkretnego utworu, z limiterem i pomiarem loudness.

## Granica bezpieczeństwa

Efekt visual snow jest powolny, ma niski kontrast i można wyłączyć go jednym przyciskiem. Nie ma stroboskopu, jumpscare’ów, wysokiej sinusoidy imitującej tinnitus ani nagłych skoków głośności.
