# Architektura bez presji

## Zasada nadrzędna

Core aplikacji jest stabilnym, lokalnym shellem. Każdy kolejny singiel ma być osobnym release packiem, a nie forkiem gameplayu.

```text
synesthesia/
└── virya-synestezja/
    ├── scripts/                  # stabilny core interakcji
    ├── shaders/                  # łagodne efekty sensoryczne
    ├── data/release_index.json   # wybór aktywnego rozdziału
    └── data/releases/<release>/  # manifest, stemy i tekstury singla
```

## Pętla prototypu

1. Gest zostawia ślad.
2. Pokrycie ściany płynnie odsłania warstwy dźwięku.
3. Dotknięcie właściwego miejsca odkrywa ślad narracyjny.
4. Haptyka potwierdza gest, ale nie walczy o uwagę.
5. Ukończenie nie blokuje pokoju i nie wymusza CTA.

## Granice modułów

- `main.gd` wybiera aktywny release pack i spina interfejs.
- `paint_room.gd` obsługuje gest, ślad, pokrycie oraz znajdźki.
- `audio_director.gd` mapuje postęp na dźwięk.
- `haptics.gd` centralizuje limity haptyki i fallback.
- manifest opisuje klimat oraz treść, ale nie wykonuje kodu.

## Kolejność spokojnego rozwoju

1. Test odczucia na jednym Androidzie.
2. Zamiana proceduralnego audio na jeden prawdziwy zestaw stemów.
3. Pomiar głośności i testy słuchawkowe.
4. Natywny adapter bogatszej haptyki Android/iOS.
5. Narzędzie podglądu release packa dla zespołu.
6. Dopiero później podpisane paczki i opcjonalna synchronizacja z CrowdRelay.

Backend nie jest potrzebny, dopóki sam pokój nie daje radości bez żadnej promocji.
