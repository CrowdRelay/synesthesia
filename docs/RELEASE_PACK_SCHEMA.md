# Release pack v1

`data/release_index.json` wskazuje aktywny lokalny rozdział. Każdy wpis prowadzi do `data/releases/<id>/manifest.json`.

Manifest zawiera:

- identyfikator wydania i wersję schematu;
- charakter pokoju i paletę;
- bezpieczne poziomy efektów sensorycznych;
- próg miękkiego ukończenia;
- znajdźki zapisane jako pozycje znormalizowane 0–1;
- deklarację źródła audio.

Docelowe rozszerzenie stemów, bez zmiany core:

```json
{
  "audio": {
    "mode": "stems",
    "stems": [
      {"id": "ambient", "path": "audio/ambient.ogg", "reveal": [0.0, 0.2]},
      {"id": "guitars", "path": "audio/guitars.ogg", "reveal": [0.2, 0.6]},
      {"id": "full_mix", "path": "audio/full_mix.ogg", "unlock": "completion"}
    ]
  },
  "content_signature": "ed25519:..."
}
```

Sieć i podpisy dochodzą dopiero wtedy, gdy lokalny release pack jest przyjemny, dostępny sensorycznie i stabilny.
