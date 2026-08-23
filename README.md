# Synesthesia

**Godot 4.7.1 + Rust hybrid runtime** for a portrait interactive-album adventure built around **Echoes Of The Modern Mind**.

Eleven explorable rooms turn an album into something you play rather than watch: each room has its own mechanic, reactive audio and haptics, and the journey resumes locally where you left it. Completing a run may enter a five-CD draw through the public CrowdRelay contract — the game itself stays autonomous at runtime and owns no fan, consent or fulfillment state.

GitHub reports this repo primarily as GDScript because scenes, UI and runtime orchestration stay in Godot. The performance-sensitive deterministic core is intentionally isolated in Rust rather than forcing a full-engine rewrite.

## Engineering snapshot

- **Narrow Rust boundary:** deterministic gameplay primitives live in pure `native/synesthesia-core`; `native/synesthesia-gdext` is a thin adapter into Godot.
- **Native Rust-primary builds:** macOS/Linux load GDExtension and Android packages an ARM64 Rust `.so`.
- **Web critical-path trade-off:** production Web uses the behavior-compatible GDScript recognizer instead of an experimental Emscripten side-module; Rust/WASM remains a fail-closed verification target.
- **Explicit runtime budgets:** current/next-room preloading, memory, idle work, shader activity and Web bundle size are contract-checked.
- **Adaptive degradation:** mask upload cadence, particles and motion are reduced before functionality is dropped under runtime pressure.
- **Immutable release path:** CI builds/verifies the Web artifact once, records source identity and deployment promotes that exact artifact rather than rebuilding it.
- **Cross-repo contract:** reward/run traffic uses the public CrowdRelay boundary and Synesthesia has an upstream compatibility gate against current `crowdrelay/main`.

See [`docs/RUST_HYBRID_ARCHITECTURE.md`](docs/RUST_HYBRID_ARCHITECTURE.md) for the Rust/Godot trade-offs.

## Features

The player promise is more game than reveal prototype:

```text
notice -> manipulate -> immediate audiovisual response -> changed world state -> optional echo -> payoff
```

- eleven rooms, each completed by its own mechanic; the paint mask remains an accessibility/reveal assist rather than the win condition;
- procedural living-world motion in every gameplay room, with only the authored finale retaining a lazy `720×1280 @ 24 fps` cinematic;
- reactive audio and haptics;
- resumable local progress, persisted as bounded PNG reveal masks;
- optional five-CD draw entry on completion;
- a Web boot shell that owns browser startup while native targets keep their branded splash.

### Runtime

- bootstrap reference `1080×1920`, runtime `stretch=disabled`;
- Web uses Godot Adaptive canvas sizing and the app shell reads the real viewport at runtime;
- current and next room assets are preloaded within explicit memory budgets;
- adaptive performance lowers mask upload cadence, particles and motion before dropping functionality.

The source art stays asymmetrical by intent: background 405×720, scene/subject 675×1200, foreground 540×960. Those are texture-source sizes, not the runtime viewport. The runtime fits/crops portrait art inside a native-resolution shell while UI remains pixel-sharp.

Video provenance for the finale cinematic is retained in `assets/video/manifest.json`. Removing the five retired room loops cut about 11.7 MiB from the source/Web pack and removed their decoder/shader startup cost. Runtime files are cache-first only inside the current fingerprinted deploy generation; the offline shell remains network-first and new deploys receive a new cache namespace plus one-time handoff.

### CrowdRelay integration

```text
start run -> room ledger x11 -> complete run -> optional five-CD draw entry
```

Campaign: `virya-synesthesia-album-v1`. Draw rules are server-enforced: 5 winners, 1 CD each, one completion/e-mail = one entry, no referral/check-in weighting. The draw does not set marketing consent and does not collect shipping data. Signal signup is a separate explicit flow through the normal `/fans` contract and never creates a Synesthesia draw entry.

## Tech stack

Godot 4.7.1 owns the editor, scenes, UI, audio, haptics and the GPU reveal renderer. Deterministic gameplay primitives live in the pure `native/synesthesia-core` Rust crate and are exposed through `native/synesthesia-gdext` (godot-rust 0.5.5); the first migrated slice is gesture recognition.

Native production builds are Rust-primary. Web production deliberately uses the behavior-compatible GDScript recognizer on the critical startup path while `synesthesia_gdext.wasm` remains a CI/verification target. `SYNESTHESIA_RUST_WEB_REQUIRED=1` exercises that Rust/WASM path explicitly.

GitHub Actions is the only Web builder: CI exports and verifies `build/web`, records a source-SHA manifest and deployment promotes the exact artifact to Netlify with `--no-build`. Build products remain ignored; a clean checkout does not require committed native binaries.

```text
assets/rooms/vertical/       layered portrait art
assets/branding/             native boot splash source/output
scenes/rooms/                one PackedScene per room
scripts/render/              GPU composite/reveal pipeline
scripts/rooms/behaviors/     per-room interactions
scripts/app/                 preload/quality/transition/diagnostics
scripts/ui/                  Signal UI, HUD, boot, Korytarz and finale
shaders/                     bounded canvas shaders
data/releases/               schema-v4 manifests
tests/                       static/runtime/visual contracts
web/                         PWA shell, CSP and pre-engine boot
native/                      pure Rust core + thin GDExtension adapter
```

New room packs must satisfy the schema encoded by `data/release_index.json`, `data/releases/*/manifest.json` and `tests/new_release_pack_contract.py`.

## Build and validation

```bash
./scripts/validate-fast.sh
./scripts/validate-source.sh
./validate.sh

./scripts/build-web-preview.sh
./scripts/build-android-apk.sh
./scripts/build-linux-release.sh

SYNESTHESIA_RUST_WEB_REQUIRED=1 ./scripts/build-web-preview.sh
```

For local macOS development:

```bash
./run-macos.sh
```

`validate.sh` covers static contracts, renderer/audio/memory budgets, visual snapshots, a clean Godot import and runtime instantiation. CI remains the authoritative Godot/compiler gate.

To share or review the repository without local caches:

```bash
./scripts/export-source.sh
```

The exporter uses `git archive`, records the exact SHA/ref and refuses dirty trees, generated build/cache paths or oversized tracked source blobs.

## Security and privacy

See [`SECURITY.md`](SECURITY.md). Run bearers are scoped to the Synesthesia lifecycle; reward entry stores only the minimum identity needed for a draw. No address, phone, location, marketing consent or gameplay brush data is sent with the draw entry.

VIRYA names, recordings and artwork remain with their respective rights holders.

## Mobile product QA

- [`docs/MOBILE_CLARITY.md`](docs/MOBILE_CLARITY.md) — renderer/UI invariants
- [`docs/MOBILE_PLAYTEST.md`](docs/MOBILE_PLAYTEST.md) — real-phone daylight/smudged-screen playtest
- [`docs/PRODUCT_READABILITY_PASS_2026-08-11.md`](docs/PRODUCT_READABILITY_PASS_2026-08-11.md) — current product-readability architecture and telemetry
