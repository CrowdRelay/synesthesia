# VIRYA: Synesthesia

Godot 4.7.1 portrait album experience for **Echoes Of The Modern Mind**. Eleven rooms reveal from visual noise into the full artwork/music while local progress remains resumable.

## Runtime

- logical layout: `540×960`, `canvas_items`;
- HiDPI enabled on Web/Android/iOS/desktop so 2D renders at the target display resolution;
- current + next room assets are preloaded within explicit memory budgets;
- adaptive performance lowers mask upload cadence, particles and motion before dropping functionality;
- room progress persists locally as bounded PNG reveal masks;
- custom native/Web boot uses the Synesthesia doorway sequence; no stock Godot splash is exposed;
- Android and PWA icons share the same doorway + spectral-signal mark.

The source art stays asymmetrical by intent: background 405×720, scene/subject 675×1200, foreground 540×960. Do not upscale source plates merely to inflate pixel count; the HiDPI canvas fixes UI/composite softness without multiplying texture memory.

## CrowdRelay integration

Synesthesia is autonomous at runtime and integrates only through the public CrowdRelay contract:

```text
start run -> room ledger x11 -> complete run -> optional five-CD draw entry
```

Campaign: `virya-synesthesia-album-v1`.

Draw rules are server-enforced: 5 winners, 1 CD each, one completion/e-mail = one entry, no referral/check-in weighting. The game does not set marketing consent and does not collect shipping data. A separate `Wzmocnij Sygnał VIRYA` action opens the normal Signal flow.

## Build and validation

```bash
./validate.sh
./scripts/build-web-preview.sh
./scripts/build-android-apk.sh
```

For local macOS development:

```bash
./run-macos.sh
```

`validate.sh` covers static contracts, renderer/audio/memory budgets, visual snapshots, a clean Godot import and runtime instantiation. CI is the authoritative Godot/compiler gate.

## Structure

```text
assets/rooms/vertical/       layered portrait art
assets/branding/             native boot splash source/output
scenes/rooms/                one PackedScene per room
scripts/render/              GPU composite/reveal pipeline
scripts/rooms/behaviors/     per-room interactions
scripts/app/                 preload/quality/transition/diagnostics
scripts/ui/                  HUD, doorway boot and finale
shaders/                     bounded canvas shaders
data/releases/               schema-v4 manifests
tests/                       static/runtime/visual contracts
web/                         PWA shell, CSP and pre-engine boot
```

New room packs must satisfy [`docs/RELEASE_PACK_SCHEMA.md`](docs/RELEASE_PACK_SCHEMA.md).

## Security and privacy

See [`SECURITY.md`](SECURITY.md). Run bearers are scoped to the Synesthesia lifecycle; reward entry stores only the minimum identity needed for a draw. No address, phone, location, marketing consent or gameplay brush data is sent with the draw entry.

VIRYA names, recordings and artwork remain with their respective rights holders.
