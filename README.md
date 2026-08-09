# VIRYA: Synesthesia

Godot 4.7.1 portrait album experience for **Echoes Of The Modern Mind**. Eleven rooms reveal from visual noise into the full artwork/music while local progress remains resumable.

## Runtime

- bootstrap reference: `1080×1920`; runtime `stretch=disabled`;
- Web uses Godot Adaptive canvas sizing and the app shell reads the real viewport at runtime;
- desktop keeps the portrait room undistorted and uses side space for menu/finale UI; portrait phones use the full native viewport so the room never becomes a tiny centered postcard;
- HiDPI is enabled on Web/Android/iOS/desktop; UI and procedural eye/door graphics render at the target display resolution;
- current + next room assets are preloaded within explicit memory budgets;
- cinematic loops are encoded directly from the supplied native `720×1280 @ 24 fps` masters; the old 1.5× FHD upscale is removed, and ping-pong loops omit duplicated turn-around endpoints;
- adaptive performance lowers mask upload cadence, particles and motion before dropping functionality;
- room progress persists locally as bounded PNG reveal masks;
- the Web boot shell owns browser startup and suppresses the stock Godot image with a Web feature override; native targets can retain their branded splash;
- Android/PWA icons, menu, chapter rails, transitions and finale share the doorway + eye + neural-activation mark.

The source art stays asymmetrical by intent: background 405×720, scene/subject 675×1200, foreground 540×960. Those are texture-source sizes, not the runtime viewport. The runtime never stretches a fixed 540×960 application canvas; it fits/crops the portrait art inside a native-resolution shell while UI remains pixel-sharp.

The original video provenance is retained in `assets/video/manifest.json` (`source_resolution=720x1280`). Runtime files stay at source resolution and the complete cinematic pack is guarded below 24 MiB (over 40% below the former video payload). Web runtime files (`.pck/.wasm/.js`) use strict network-first + HTTP revalidation with CacheStorage fallback only after a real network/transient-origin failure. The cache namespace fingerprints the whole deploy surface, and returning clients perform a one-time clean worker/cache handoff when the deploy generation changes, preventing mixed-version PCK/WASM after a release while retaining offline recovery.

## CrowdRelay integration

Synesthesia is autonomous at runtime and integrates only through the public CrowdRelay contract:

```text
start run -> room ledger x11 -> complete run -> optional five-CD draw entry
```

Campaign: `virya-synesthesia-album-v1`.

Draw rules are server-enforced: 5 winners, 1 CD each, one completion/e-mail = one entry, no referral/check-in weighting. The five-CD draw does not set marketing consent and does not collect shipping data. The start menu also exposes a separate, explicit Signal signup (email + city + marketing consent) through the normal `/fans` contract; that signup never creates a Synesthesia draw entry.


## Rust hybrid core

Synesthesia uses Godot + Rust with a deliberately narrow boundary. The editor, scenes, UI, audio, haptics and GPU reveal renderer stay in Godot; deterministic gameplay primitives live in the pure `native/synesthesia-core` crate and are exposed through the thin `native/synesthesia-gdext` adapter. The first migrated slice is gesture recognition.

Native production builds are Rust-primary: macOS/Linux load the native GDExtension and Android packages an `arm64-v8a` `.so`. Web/Netlify deliberately uses the behavior-compatible GDScript recognizer in production so an experimental Emscripten side-module is not part of the browser's critical startup path. The Rust/WASM path (`synesthesia_gdext.wasm`) remains a fail-closed CI/verification target and can be enabled explicitly with `SYNESTHESIA_RUST_WEB_REQUIRED=1`. This keeps the Web experience resilient and also avoids paying the Rust+emsdk compile cost on every production Netlify build. A clean checkout still opens without committed native binaries because the descriptor and build products are generated locally and ignored by Git. See [`docs/RUST_HYBRID_ARCHITECTURE.md`](docs/RUST_HYBRID_ARCHITECTURE.md). Runtime budgets, idle-work rules and save/cache boundaries are documented in [`docs/PERFORMANCE_ARCHITECTURE.md`](docs/PERFORMANCE_ARCHITECTURE.md).

## Build and validation

```bash
# Fast canonical source/contracts gate (shared by CI, Netlify and Android)
./scripts/validate-source.sh

# Source gates + real Godot import/runtime smoke when Godot is installed
./validate.sh

# Production artifacts (Web uses GDScript gesture fallback; native stays Rust-primary)
./scripts/build-web-preview.sh
./scripts/build-android-apk.sh
# Linux x86_64 release runner only:
./scripts/build-linux-release.sh

# Explicit Rust/WASM Web verification path
SYNESTHESIA_RUST_WEB_REQUIRED=1 ./scripts/build-web-preview.sh
```

To share/review the repository without local build caches, use the clean-tree exporter instead of zipping the working directory:

```bash
./scripts/export-source.sh
```

It uses `git archive`, records the exact SHA/ref and refuses dirty trees, generated build/cache paths or oversized tracked source blobs. `native/target`, `.cache`, `.godot`, APK/WASM/native products and Godot template packs never belong in a source package.

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
