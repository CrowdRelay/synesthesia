# VIRYA: Synesthesia

Godot 4.7.1 portrait album experience for **Echoes Of The Modern Mind**. Eleven rooms reveal from visual noise into the full artwork/music while local progress remains resumable.

## Runtime

- bootstrap reference: `1080×1920`; runtime `stretch=disabled`;
- Web uses Godot Adaptive canvas sizing and the app shell reads the real viewport at runtime;
- desktop keeps the portrait room undistorted and uses side space for menu/finale UI; portrait phones use the full native viewport so the room never becomes a tiny centered postcard;
- HiDPI is enabled on Web/Android/iOS/desktop; UI and procedural eye/door graphics render at the target display resolution;
- current + next room assets are preloaded within explicit memory budgets;
- cinematic loops are runtime FHD `1080×1920 @ 24 fps`, deterministically upscaled 1.5× from the supplied 720×1280 masters with Lanczos + low-strength CAS; no frame interpolation or generative detail is used;
- adaptive performance lowers mask upload cadence, particles and motion before dropping functionality;
- room progress persists locally as bounded PNG reveal masks;
- custom native/Web boot uses the blinking doorway-eye sequence and resolves the native viewport while loading; no stock Godot splash is exposed;
- Android/PWA icons, menu, chapter rails, transitions and finale share the doorway + eye + neural-activation mark.

The source art stays asymmetrical by intent: background 405×720, scene/subject 675×1200, foreground 540×960. Those are texture-source sizes, not the runtime viewport. The runtime never stretches a fixed 540×960 application canvas; it fits/crops the portrait art inside a native-resolution shell while UI remains pixel-sharp.

The original video provenance is retained in `assets/video/manifest.json` (`source_resolution=720x1280`). Runtime files are FHD and the complete cinematic pack remains below 40 MiB. Web runtime files (`.pck/.wasm/.js`) use a versioned cache-first policy after the first successful load; navigation stays network-first.

## CrowdRelay integration

Synesthesia is autonomous at runtime and integrates only through the public CrowdRelay contract:

```text
start run -> room ledger x11 -> complete run -> optional five-CD draw entry
```

Campaign: `virya-synesthesia-album-v1`.

Draw rules are server-enforced: 5 winners, 1 CD each, one completion/e-mail = one entry, no referral/check-in weighting. The five-CD draw does not set marketing consent and does not collect shipping data. The start menu also exposes a separate, explicit Signal signup (email + city + marketing consent) through the normal `/fans` contract; that signup never creates a Synesthesia draw entry.

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
