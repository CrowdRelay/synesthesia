# Product readability pass — 2026-08-11

This pass treats Synesthesia as a mobile game rather than a visual demo.

## Player-facing changes

- Room-specific semantic instructions now survive initial HUD configuration.
- Portrait chapter cards use the full text width; the eye motif becomes a compact title ornament instead of a permanent side column.
- The mobile instruction surface has one dominant action line and one quieter detail line.
- Idle guidance escalates in layers: primary instruction, diegetic target cue, then explanatory toast.
- Success actually resets guidance; ordinary pointer activity only postpones it and no longer falsifies first-success telemetry.
- Touch forgiveness grows invisibly with assist level and recedes as the player makes progress.
- Each room owns a small `mobile_readability` profile for shadow lift, subject lift, visual-snow scale and vignette floor.
- `Party Time`, `Hybrid`, `The Calling` and `Invaluable` get stronger adaptive subject/interaction affordances when assistance rises.
- Settings include persisted `Czytelność: kinowa / wysoka`.

## Performance constraints

Readability stays inside the existing room-composite pass: no new texture fetches, viewports, render passes, polling loops or per-frame heap allocations were added. Hint-target refresh sleeps while guidance is inactive, dictionary deep copies were removed, small render literals were hoisted, and the Waves bridge polyline reuses a packed buffer.

## Measurement

Gameplay telemetry is sampled at 5% and sends one identity-free aggregate per completed/abandoned room. It includes first confirmed success, misses, hints, maximum assistance and minimum runtime quality scale. It never emits one request per tap or miss.

## Development loop

- `./scripts/validate-fast.sh` — source/gameplay/mobile/hot-path preflight.
- `./scripts/validate-source.sh` — canonical full source/release contract suite; runs the fast preflight first.
- Android builds triggered by a successful main CI run trust the exact CI-validated SHA; manual Android builds still run the canonical source suite.
