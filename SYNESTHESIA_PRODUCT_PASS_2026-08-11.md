# Synesthesia — mobile product pass (2026-08-11)

## Goal

Improve real-world phone readability and gameplay comprehension without weakening the existing art direction, renderer, performance budgets or build/CI safety.

## Delivered

- Fixed initial room-specific interaction hints being overwritten by generic HUD configuration.
- Rebuilt portrait chapter-card composition so copy uses full phone width and the eye motif becomes a compact title ornament.
- Rebuilt the bottom mobile instruction surface into a dominant action plus quieter semantic detail.
- Added authored per-room mobile readability profiles to all 11 rooms.
- Added persisted `Czytelność: kinowa / wysoka` without a second renderer or extra pass.
- Strengthened adaptive affordances for Party Time, Hybrid, The Calling and Invaluable.
- Extended existing assist logic with stronger bounded touch forgiveness and target radius after misses; assistance remains reversible.
- Fixed successful interactions not actually resetting the guidance system.
- Separated ordinary pointer activity from confirmed semantic success for correct first-success measurement.
- Added identity-free 5% sampled room-summary gameplay telemetry with no per-tap/per-miss requests.
- Stopped hint target refresh work while the hint layer is asleep and removed deep dictionary copies in target updates.
- Hoisted small render literals and reused the Waves bridge polyline buffer.
- Added `validate-fast.sh`; the full source suite remains canonical and runs fast preflight first.
- Removed duplicate full source validation from Android builds already triggered by a successful exact-SHA CI run; manual Android builds still validate fully.
- Added real-phone daylight/smudged-screen playtest protocol.

## Performance invariants

The readability path adds no texture fetches, no viewport, no extra render pass, no frame polling loop and no per-frame allocation requirement. Existing adaptive quality, memory, web bundle and hot-path budgets remain intact.

## Validation

- `SYNESTHESIA_FAST_VALIDATION=PASS`
- `SYNESTHESIA_STATIC_VALIDATION=PASS`
- `SYNESTHESIA_PERF_BUDGET=PASS`
- `SYNESTHESIA_RUNTIME_HOT_PATH=PASS`
- `SYNESTHESIA_FULL_ROOM_GAMEPLAY=PASS rooms=11`
- `SYNESTHESIA_MOBILE_CLARITY=PASS`
- `SYNESTHESIA_MOBILE_PRODUCT_READABILITY=PASS`
- `SYNESTHESIA_GAMEPLAY_TELEMETRY=PASS`
- `SYNESTHESIA_UI_PERFORMANCE=PASS`
- `SYNESTHESIA_ANDROID_PIPELINE=PASS`
- `SYNESTHESIA_VALIDATION_ENTRYPOINT=PASS`
- Broader canonical release contracts were also run; the single tool invocation reached its execution timeout late in the suite with no failure, and the remaining contracts were executed separately and passed.

Godot itself is not installed in the working environment, so `validate.sh` would skip the executable Godot import/GDScript/lifecycle stage here. Normal CI/device build remains the executable runtime gate.
